from __future__ import annotations

from datetime import UTC, datetime, timedelta
import hashlib

import pytest

from api.services.object_storage import FakeObjectStorageProvider, UploadMode
from api.services.video_source_intake_store import VideoSourceIntakeStore
from api.services.video_source_media_reconciliation import (
    VideoSourceMediaReconciliationService,
)
from api.services.video_source_media_service import VideoSourceMediaService
from status.db import init_db
from utils.libsql_sync import create_connection
from utils.libsql_async import create_client


class _AssetWriter:
    def __init__(self) -> None:
        self.rollback_calls: list[dict] = []

    def attach(self, **kwargs):
        return "asset-1"

    def detach(self, **kwargs):
        return None

    def attach_preview(self, **kwargs):
        return "preview-1"

    def rollback(self, **kwargs):
        self.rollback_calls.append(kwargs)


async def _context(*, storage_clock=None):
    store = VideoSourceIntakeStore(db_client=create_client(url=":memory:"))
    await store.ensure_tables()
    storage = FakeObjectStorageProvider(max_proxy_bytes=1024, clock=storage_clock)
    writer = _AssetWriter()
    media = VideoSourceMediaService(storage=storage, store=store, asset_writer=writer)
    folder, _ = await store.create_or_open_folder(
        user_id="user-1", project_id="project-1", content_id="content-1"
    )
    payload = b"private-media-payload"
    session = await media.create_upload_session(
        folder_id=folder["id"], user_id="user-1", source_type="binary_image",
        file_name="private.png", mime_type="image/png", byte_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), expected_revision=0,
        idempotency_key="reconcile-1",
    )
    record = await store.get_upload_session(
        session_id=session.session_id, folder_id=folder["id"], user_id="user-1"
    )
    return media, store, storage, writer, folder, record, payload


def _locator_dict(locator) -> dict[str, str]:
    return {
        "provider": locator.provider,
        "namespace": locator.namespace,
        "object_key": locator.object_key,
        "version": locator.version,
        "checksum_sha256": locator.checksum_sha256,
    }


def test_status_init_applies_reconciliation_migration_idempotently():
    connection = create_connection(url=":memory:")

    init_db(connection)
    init_db(connection)

    columns = {
        row[1] for row in connection.execute(
            "PRAGMA table_info(video_source_upload_sessions)"
        ).fetchall()
    }
    assert {
        "cleanup_locators_json",
        "cleanup_asset_ids_json",
        "reconcile_attempts",
        "lease_token",
        "lease_expires_at",
        "last_reconcile_error",
    }.issubset(columns)


@pytest.mark.asyncio
async def test_cleanup_deletes_only_recorded_locator_and_recovers_source():
    media, store, storage, writer, folder, record, payload = await _context()
    cleanup_session = storage.create_upload_session(
        namespace="quarantine", content_type="image/png", expected_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), mode=UploadMode.PROXY,
    )
    locator = storage.upload_proxy(session=cleanup_session, source=payload)
    await store.mark_upload_cleanup_needed(
        session_id=record["id"], folder_id=folder["id"], user_id="user-1",
        cleanup_locators=[_locator_dict(locator)], cleanup_asset_ids=["asset-1"],
        error_code="object_cleanup_failed",
    )
    await store.update_source(
        folder_id=folder["id"], source_id=record["source_id"], user_id="user-1",
        status="orphan_cleanup_needed", error_code="orphan_cleanup_needed", retryable=True,
    )

    summary = await VideoSourceMediaReconciliationService(
        media_service=media, clock=lambda: datetime.now(UTC) + timedelta(seconds=1)
    ).run_batch()

    current = await store.get_upload_session(
        session_id=record["id"], folder_id=folder["id"], user_id="user-1"
    )
    source = await store.get_source(
        folder_id=folder["id"], source_id=record["source_id"], user_id="user-1"
    )
    assert summary.cleaned == 1
    assert current["status"] == "failed"
    assert current["cleanup_locators"] == []
    assert source["error_code"] == "upload_cleanup_completed"
    assert writer.rollback_calls[0]["asset_ids"] == ["asset-1"]
    assert locator.object_key not in storage._objects


@pytest.mark.asyncio
async def test_reconciliation_lease_allows_only_one_worker():
    _media, store, _storage, _writer, _folder, record, _payload = await _context()
    now = datetime.now(UTC)

    first = await store.claim_upload_reconciliation(
        session_id=record["id"], expected_status="created", lease_token="worker-a",
        lease_expires_at=now + timedelta(minutes=1), now=now,
    )
    second = await store.claim_upload_reconciliation(
        session_id=record["id"], expected_status="created", lease_token="worker-b",
        lease_expires_at=now + timedelta(minutes=1), now=now,
    )

    assert first is True
    assert second is False


@pytest.mark.asyncio
async def test_expired_created_session_is_aborted_and_made_retryable():
    created_at = datetime(2000, 1, 1, tzinfo=UTC)
    media, store, _storage, _writer, folder, record, _payload = await _context(
        storage_clock=lambda: created_at
    )

    summary = await VideoSourceMediaReconciliationService(
        media_service=media, clock=lambda: created_at + timedelta(minutes=16)
    ).run_batch()

    current = await store.get_upload_session(
        session_id=record["id"], folder_id=folder["id"], user_id="user-1"
    )
    source = await store.get_source(
        folder_id=folder["id"], source_id=record["source_id"], user_id="user-1"
    )
    assert summary.expired == 1
    assert current["status"] == "expired"
    assert source["retryable"] is True


@pytest.mark.asyncio
async def test_stalled_processing_is_contained_without_deleting_unknown_objects():
    media, store, storage, _writer, folder, record, _payload = await _context()
    await store.update_upload_session(
        session_id=record["id"], folder_id=folder["id"], user_id="user-1",
        status="processing",
    )
    await store.db_client.execute(
        "UPDATE video_source_upload_sessions SET updated_at=? WHERE id=?",
        ["2000-01-01T00:00:00+00:00", record["id"]],
    )

    summary = await VideoSourceMediaReconciliationService(
        media_service=media, clock=lambda: datetime.now(UTC)
    ).run_batch()

    current = await store.get_upload_session(
        session_id=record["id"], folder_id=folder["id"], user_id="user-1"
    )
    source = await store.get_source(
        folder_id=folder["id"], source_id=record["source_id"], user_id="user-1"
    )
    assert summary.contained == 1
    assert current["status"] == "reconciliation_required"
    assert source["error_code"] == "stalled_processing_requires_review"
    assert len(storage._objects) == 0
    assert (await store.upload_reconciliation_health())["manual_review"] == 1


@pytest.mark.asyncio
async def test_cleanup_failure_exhausts_bounded_retries_without_sensitive_logs(caplog):
    media, store, storage, _writer, folder, record, payload = await _context()
    cleanup_session = storage.create_upload_session(
        namespace="quarantine", content_type="image/png", expected_size=len(payload),
        checksum_sha256=hashlib.sha256(payload).hexdigest(), mode=UploadMode.PROXY,
    )
    locator = storage.upload_proxy(session=cleanup_session, source=payload)
    await store.mark_upload_cleanup_needed(
        session_id=record["id"], folder_id=folder["id"], user_id="user-1",
        cleanup_locators=[_locator_dict(locator)], cleanup_asset_ids=[],
        error_code="object_cleanup_failed",
    )

    def fail_delete(_locator):
        raise RuntimeError("provider unavailable")

    storage.delete_version = fail_delete
    with caplog.at_level("INFO"):
        summary = await VideoSourceMediaReconciliationService(
            media_service=media, clock=lambda: datetime.now(UTC) + timedelta(seconds=1),
            max_attempts=1,
        ).run_batch()

    current = await store.get_upload_session(
        session_id=record["id"], folder_id=folder["id"], user_id="user-1"
    )
    assert summary.exhausted == 1
    assert current["status"] == "reconciliation_failed"
    assert locator.object_key not in caplog.text
    assert locator.checksum_sha256 not in caplog.text
