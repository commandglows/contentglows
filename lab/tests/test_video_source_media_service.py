from __future__ import annotations

import hashlib
import io

import pytest
from PIL import Image

import api.services.video_source_media_service as media_module
from api.services.object_storage import FakeObjectStorageProvider
from api.services.video_source_intake_store import (
    IntakeConflictError,
    IntakeNotFoundError,
    VideoSourceIntakeStore,
)
from api.services.video_source_media_service import VideoSourceMediaError, VideoSourceMediaService
from utils.libsql_async import create_client


class _AssetWriter:
    def __init__(self, *, fail: bool = False):
        self.fail = fail
        self.calls = []
        self.preview_calls = []
        self.detach_calls = []
        self.rollback_calls = []

    def attach(self, **kwargs):
        self.calls.append(kwargs)
        if self.fail:
            raise RuntimeError("database unavailable")
        return "asset-1"

    def detach(self, **kwargs):
        self.detach_calls.append(kwargs)

    def attach_preview(self, **kwargs):
        self.preview_calls.append(kwargs)
        return "preview-asset-1"

    def rollback(self, **kwargs):
        self.rollback_calls.append(kwargs)


def _png_bytes() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (4, 3), color=(120, 30, 220)).save(
        output,
        format="PNG",
        pnginfo=None,
    )
    return output.getvalue()


async def _context(*, writer=None):
    store = VideoSourceIntakeStore(db_client=create_client(url=":memory:"))
    await store.ensure_tables()
    storage = FakeObjectStorageProvider(max_proxy_bytes=10 * 1024 * 1024)
    writer = writer or _AssetWriter()
    service = VideoSourceMediaService(storage=storage, store=store, asset_writer=writer)
    folder, _ = await store.create_or_open_folder(
        user_id="user-1", project_id="project-1", content_id="content-1"
    )
    return service, store, storage, writer, folder


@pytest.mark.asyncio
async def test_proxy_image_upload_becomes_canonical_asset_without_provider_fields_in_response():
    service, store, _storage, writer, folder = await _context()
    payload = _png_bytes()
    checksum = hashlib.sha256(payload).hexdigest()

    session = await service.create_upload_session(
        folder_id=folder["id"],
        user_id="user-1",
        source_type="binary_image",
        file_name="campaign.png",
        mime_type="image/png",
        byte_size=len(payload),
        checksum_sha256=checksum,
        expected_revision=0,
        idempotency_key="image-1",
    )
    result = await service.upload_proxy(
        folder_id=folder["id"],
        session_id=session.session_id,
        user_id="user-1",
        payload=payload,
    )

    assert result.revision == 1
    assert result.sources[0].status == "ready"
    assert result.sources[0].asset_id == "asset-1"
    assert result.sources[0].safe_metadata["width"] == 4
    assert result.sources[0].safe_metadata["preview_status"] == "ready"
    assert result.sources[0].safe_metadata["preview_asset_id"] == "preview-asset-1"
    assert writer.calls[0]["locator"].namespace == "assets"
    assert writer.preview_calls[0]["locator"].namespace == "previews"
    assert "object_key" not in result.model_dump(mode="json")["sources"][0]
    persisted = await store.get_upload_session(
        session_id=session.session_id, folder_id=folder["id"], user_id="user-1"
    )
    assert persisted["status"] == "completed"


@pytest.mark.asyncio
async def test_upload_session_is_bound_to_owner_and_folder():
    service, _store, _storage, _writer, folder = await _context()
    payload = _png_bytes()
    session = await service.create_upload_session(
        folder_id=folder["id"],
        user_id="user-1",
        source_type="binary_image",
        file_name="campaign.png",
        mime_type="image/png",
        byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(),
        expected_revision=0,
        idempotency_key="image-1",
    )

    with pytest.raises(IntakeNotFoundError):
        await service.upload_proxy(
            folder_id=folder["id"],
            session_id=session.session_id,
            user_id="user-2",
            payload=payload,
        )


@pytest.mark.asyncio
async def test_abort_upload_is_idempotent_and_makes_source_retryable():
    service, store, storage, _writer, folder = await _context()
    payload = _png_bytes()
    session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="campaign.png", mime_type="image/png", byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), expected_revision=0,
        idempotency_key="abort-image-1",
    )

    first = await service.abort_upload(
        folder_id=folder["id"], session_id=session.session_id, user_id="user-1"
    )
    second = await service.abort_upload(
        folder_id=folder["id"], session_id=session.session_id, user_id="user-1"
    )

    persisted = await store.get_upload_session(
        session_id=session.session_id, folder_id=folder["id"], user_id="user-1"
    )
    assert persisted["status"] == "aborted"
    assert first.sources[0].error.code == "upload_aborted"
    assert first.sources[0].error.retryable is True
    assert second.sources[0].error.code == "upload_aborted"
    assert len(storage._objects) == 0


@pytest.mark.asyncio
async def test_processing_session_rejects_second_completion_before_asset_side_effects():
    service, store, _storage, writer, folder = await _context()
    payload = _png_bytes()
    session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="campaign.png", mime_type="image/png", byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), expected_revision=0,
        idempotency_key="concurrent-image-1",
    )
    await store.update_upload_session(
        session_id=session.session_id, folder_id=folder["id"], user_id="user-1",
        status="processing",
    )

    with pytest.raises(IntakeConflictError) as error:
        await service.upload_proxy(
            folder_id=folder["id"], session_id=session.session_id,
            user_id="user-1", payload=payload,
        )

    assert error.value.code == "upload_completion_in_progress"
    assert writer.calls == []


@pytest.mark.asyncio
async def test_expired_session_is_persisted_and_source_becomes_retryable():
    service, store, _storage, _writer, folder = await _context()
    payload = _png_bytes()
    session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="campaign.png", mime_type="image/png", byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), expected_revision=0,
        idempotency_key="expired-image-1",
    )
    await store.db_client.execute(
        "UPDATE video_source_upload_sessions SET expires_at=? WHERE id=?",
        ["2000-01-01T00:00:00+00:00", session.session_id],
    )

    with pytest.raises(IntakeConflictError) as error:
        await service.upload_proxy(
            folder_id=folder["id"], session_id=session.session_id,
            user_id="user-1", payload=payload,
        )

    persisted = await store.get_upload_session(
        session_id=session.session_id, folder_id=folder["id"], user_id="user-1"
    )
    source = (await store.list_sources(folder_id=folder["id"], user_id="user-1"))[0]
    assert error.value.code == "upload_session_expired"
    assert persisted["status"] == "expired"
    assert source["error_code"] == "upload_session_expired"
    assert source["retryable"] is True


@pytest.mark.asyncio
async def test_multipart_part_is_signed_only_after_checksum_and_size_are_bound(monkeypatch):
    monkeypatch.setattr(media_module, "PROXY_MAX_BYTES", 1)
    service, _store, _storage, _writer, folder = await _context()
    payload = _png_bytes()
    checksum = hashlib.sha256(payload).hexdigest()
    session = await service.create_upload_session(
        folder_id=folder["id"],
        user_id="user-1",
        source_type="binary_image",
        file_name="campaign.png",
        mime_type="image/png",
        byte_size=len(payload),
        checksum_sha256=checksum,
        expected_revision=0,
        idempotency_key="multipart-image-1",
    )

    assert session.strategy == "multipart"
    assert len(session.parts) == 1
    assert session.parts[0].upload_url is None
    assert session.parts[0].headers == {}

    signed = await service.sign_upload_part(
        folder_id=folder["id"],
        session_id=session.session_id,
        user_id="user-1",
        part_number=1,
        checksum_sha256=checksum,
        size_bytes=len(payload),
    )

    assert signed.upload_url and signed.upload_url.startswith("https://")
    assert signed.headers["x-amz-checksum-sha256"] == checksum

    with pytest.raises(VideoSourceMediaError) as error:
        await service.sign_upload_part(
            folder_id=folder["id"],
            session_id=session.session_id,
            user_id="user-1",
            part_number=1,
            checksum_sha256=checksum,
            size_bytes=len(payload) - 1,
        )
    assert error.value.code == "invalid_upload_part_size"


@pytest.mark.asyncio
async def test_mime_mismatch_marks_only_source_failed_and_cleans_quarantine():
    service, store, storage, _writer, folder = await _context()
    payload = b"not a png but same declared length"
    session = await service.create_upload_session(
        folder_id=folder["id"],
        user_id="user-1",
        source_type="binary_image",
        file_name="campaign.png",
        mime_type="image/png",
        byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(),
        expected_revision=0,
        idempotency_key="image-1",
    )

    with pytest.raises(VideoSourceMediaError) as error:
        await service.upload_proxy(
            folder_id=folder["id"],
            session_id=session.session_id,
            user_id="user-1",
            payload=payload,
        )

    assert error.value.code == "mime_mismatch"
    sources = await store.list_sources(folder_id=folder["id"], user_id="user-1")
    assert sources[0]["status"] == "failed"
    assert sources[0]["error_code"] == "mime_mismatch"
    assert len(storage._objects) == 0


@pytest.mark.asyncio
async def test_asset_persistence_failure_compensates_canonical_and_raw_objects():
    writer = _AssetWriter(fail=True)
    service, store, storage, _writer, folder = await _context(writer=writer)
    payload = _png_bytes()
    session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="campaign.png", mime_type="image/png", byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), expected_revision=0,
        idempotency_key="image-1",
    )

    with pytest.raises(VideoSourceMediaError) as error:
        await service.upload_proxy(
            folder_id=folder["id"], session_id=session.session_id,
            user_id="user-1", payload=payload,
        )

    assert error.value.code == "asset_persistence_failed"
    assert len(storage._objects) == 0
    source = (await store.list_sources(folder_id=folder["id"], user_id="user-1"))[0]
    assert source["status"] == "failed"


@pytest.mark.asyncio
async def test_failed_compensation_persists_exact_reconciliation_plan():
    writer = _AssetWriter(fail=True)
    service, store, storage, _writer, folder = await _context(writer=writer)
    payload = _png_bytes()
    session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="campaign.png", mime_type="image/png", byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), expected_revision=0,
        idempotency_key="cleanup-plan-1",
    )

    def fail_delete(_locator):
        raise RuntimeError("provider unavailable")

    storage.delete_version = fail_delete
    with pytest.raises(VideoSourceMediaError):
        await service.upload_proxy(
            folder_id=folder["id"], session_id=session.session_id,
            user_id="user-1", payload=payload,
        )

    persisted = await store.get_upload_session(
        session_id=session.session_id, folder_id=folder["id"], user_id="user-1"
    )
    source = (await store.list_sources(folder_id=folder["id"], user_id="user-1"))[0]
    assert persisted["status"] == "orphan_cleanup_needed"
    assert len(persisted["cleanup_locators"]) == 2
    assert {item["namespace"] for item in persisted["cleanup_locators"]} == {
        "assets", "quarantine"
    }
    assert source["status"] == "orphan_cleanup_needed"


@pytest.mark.asyncio
async def test_source_persistence_failure_rolls_back_assets_and_all_object_versions():
    service, store, storage, writer, folder = await _context()
    payload = _png_bytes()
    session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="campaign.png", mime_type="image/png", byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), expected_revision=0,
        idempotency_key="image-1",
    )
    original_update = store.update_source

    async def fail_ready_update(**kwargs):
        if kwargs.get("status") == "ready":
            raise RuntimeError("database unavailable after asset attach")
        return await original_update(**kwargs)

    store.update_source = fail_ready_update

    with pytest.raises(VideoSourceMediaError) as error:
        await service.upload_proxy(
            folder_id=folder["id"], session_id=session.session_id,
            user_id="user-1", payload=payload,
        )

    assert error.value.code == "asset_persistence_failed"
    assert len(storage._objects) == 0
    assert writer.rollback_calls[0]["asset_ids"] == ["preview-asset-1", "asset-1"]
    source = (await store.list_sources(folder_id=folder["id"], user_id="user-1"))[0]
    assert source["status"] == "failed"


@pytest.mark.asyncio
async def test_successful_replacement_supersedes_old_source_without_deleting_asset():
    service, store, _storage, writer, folder = await _context()
    first_payload = _png_bytes()
    first_session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="first.png", mime_type="image/png", byte_size=len(first_payload),
        checksum_sha256=hashlib.sha256(first_payload).hexdigest(), expected_revision=0,
        idempotency_key="image-1",
    )
    first_result = await service.upload_proxy(
        folder_id=folder["id"], session_id=first_session.session_id,
        user_id="user-1", payload=first_payload,
    )
    old_source_id = first_result.sources[0].id

    replacement_payload = _png_bytes()
    replacement_session = await service.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="replacement.png", mime_type="image/png",
        byte_size=len(replacement_payload),
        checksum_sha256=hashlib.sha256(replacement_payload).hexdigest(),
        expected_revision=1, idempotency_key="image-2",
        replace_source_id=old_source_id,
    )
    result = await service.upload_proxy(
        folder_id=folder["id"], session_id=replacement_session.session_id,
        user_id="user-1", payload=replacement_payload,
    )

    assert result.revision == 2
    assert len(result.sources) == 1
    assert result.sources[0].id != old_source_id
    history = await store.list_sources(
        folder_id=folder["id"], user_id="user-1", include_removed=True
    )
    old = next(source for source in history if source["id"] == old_source_id)
    assert old["status"] == "superseded"
    assert len(writer.calls) == 2
    assert len(writer.preview_calls) == 2
    assert writer.detach_calls[-1]["source_id"] == old_source_id
