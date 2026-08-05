"""Secure binary source upload, validation, canonicalization and asset linking."""

from __future__ import annotations

import asyncio
import hashlib
import io
import json
import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Protocol, Sequence

from PIL import Image, UnidentifiedImageError

from api.models.video_source_intake import (
    UploadPartInstruction,
    UploadSessionResponse,
    UploadedPartRequest,
    VideoSourceFolderResponse,
)
from api.services.object_storage import (
    ObjectStorageError,
    ObjectStorageProvider,
    StorageLocator,
    UploadedPart,
    UploadMode,
    UploadSession,
)
from api.services.media_preview import (
    BoundedObjectReader,
    GeneratedPreview,
    InternalMediaPreviewProvider,
    MediaPreviewProvider,
    PreviewStatus,
)
from api.services.s3_object_storage import S3ObjectStorageProvider
from api.services.video_source_intake_service import VideoSourceIntakeService
from api.services.video_source_intake_store import (
    IntakeConflictError,
    IntakeNotFoundError,
    VideoSourceIntakeStore,
    video_source_intake_store,
)
from status.schemas import StorageLocator as AssetStorageLocator
from status.service import get_status_service


MIB = 1024 * 1024
PROXY_MAX_BYTES = 10 * MIB
MULTIPART_PART_BYTES = 8 * MIB
MAX_DIMENSION = 4096
MAX_IMAGE_PIXELS = 16_000_000
MAX_DURATION_SECONDS = 180.0
ALLOWED_MEDIA: dict[str, dict[str, int]] = {
    "binary_image": {"image/jpeg": 10 * MIB, "image/png": 10 * MIB, "image/webp": 10 * MIB},
    "binary_video": {"video/mp4": 200 * MIB},
    "binary_audio": {
        "audio/mpeg": 50 * MIB,
        "audio/mp4": 50 * MIB,
        "audio/wav": 50 * MIB,
        "audio/x-wav": 50 * MIB,
    },
}


class VideoSourceMediaError(RuntimeError):
    def __init__(self, code: str, message: str, *, retryable: bool = False) -> None:
        super().__init__(message)
        self.code = code
        self.retryable = retryable


@dataclass(frozen=True, slots=True)
class ValidatedMedia:
    path: Path
    mime_type: str
    byte_size: int
    checksum_sha256: str
    metadata: dict[str, Any]


class ProjectAssetWriter(Protocol):
    def attach(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        source_type: str,
        file_name: str,
        mime_type: str,
        locator: StorageLocator,
        metadata: dict[str, Any],
    ) -> str: ...

    def detach(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        asset_id: str,
    ) -> None: ...

    def attach_preview(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        source_asset_id: str,
        locator: StorageLocator,
        metadata: dict[str, Any],
    ) -> str: ...

    def rollback(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        asset_ids: Sequence[str],
    ) -> None: ...


class StatusProjectAssetWriter:
    def attach(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        source_type: str,
        file_name: str,
        mime_type: str,
        locator: StorageLocator,
        metadata: dict[str, Any],
    ) -> str:
        service = get_status_service()
        service.ensure_video_source_folder_usage_target(
            project_id=project_id, user_id=user_id, folder_id=folder_id
        )
        media_kind = {
            "binary_image": "image",
            "binary_video": "video",
            "binary_audio": "audio",
        }[source_type]
        asset = service.create_project_asset(
            project_id=project_id,
            user_id=user_id,
            media_kind=media_kind,
            source="manual_upload",
            mime_type=mime_type,
            file_name=file_name,
            storage_locator=AssetStorageLocator.model_validate(locator, from_attributes=True),
            metadata={**metadata, "video_source_id": source_id},
        )
        try:
            service.select_project_asset(
                project_id=project_id,
                user_id=user_id,
                asset_id=asset.id,
                target_type="video_source_folder",
                target_id=folder_id,
                usage_action="attach_video_source",
                metadata={"source_id": source_id},
            )
        except Exception:
            service.tombstone_project_asset(
                project_id=project_id,
                user_id=user_id,
                asset_id=asset.id,
            )
            raise
        return asset.id

    def detach(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        asset_id: str,
    ) -> None:
        get_status_service().unlink_video_source_usages(
            project_id=project_id,
            user_id=user_id,
            folder_id=folder_id,
            source_id=source_id,
        )

    def attach_preview(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        source_asset_id: str,
        locator: StorageLocator,
        metadata: dict[str, Any],
    ) -> str:
        service = get_status_service()
        asset = service.create_project_asset(
            project_id=project_id,
            user_id=user_id,
            media_kind="thumbnail",
            source="manual_upload",
            mime_type=str(metadata.get("content_type") or "image/webp"),
            file_name=f"preview-{source_id}.webp",
            storage_locator=AssetStorageLocator.model_validate(locator, from_attributes=True),
            source_asset_id=source_asset_id,
            metadata={**metadata, "video_source_id": source_id, "derived_role": "preview"},
        )
        try:
            service.select_project_asset(
                project_id=project_id,
                user_id=user_id,
                asset_id=asset.id,
                target_type="video_source_folder",
                target_id=folder_id,
                usage_action="attach_video_source",
                metadata={"source_id": source_id, "derived_role": "preview"},
            )
        except Exception:
            service.tombstone_project_asset(
                project_id=project_id, user_id=user_id, asset_id=asset.id
            )
            raise
        return asset.id

    def rollback(
        self,
        *,
        user_id: str,
        project_id: str,
        folder_id: str,
        source_id: str,
        asset_ids: Sequence[str],
    ) -> None:
        service = get_status_service()
        service.unlink_video_source_usages(
            project_id=project_id,
            user_id=user_id,
            folder_id=folder_id,
            source_id=source_id,
        )
        for asset_id in asset_ids:
            service.tombstone_project_asset(
                project_id=project_id, user_id=user_id, asset_id=asset_id
            )


class ImagePreviewGenerator:
    """Create a sanitized bounded WebP thumbnail; non-images use metadata fallback."""

    def generate(
        self,
        *,
        source: StorageLocator,
        media_kind: str,
        metadata: dict[str, Any],
        reader: BoundedObjectReader,
    ) -> GeneratedPreview | None:
        if media_kind != "image":
            return None
        size_bytes = metadata.get("size_bytes")
        if not isinstance(size_bytes, int) or size_bytes <= 0:
            return None
        payload = reader.read(0, size_bytes - 1)
        try:
            with Image.open(io.BytesIO(payload)) as image:
                image.thumbnail((512, 512), Image.Resampling.LANCZOS)
                output = io.BytesIO()
                converted = image.convert("RGB")
                converted.save(output, format="WEBP", quality=82, method=6)
                width, height = converted.size
        except (UnidentifiedImageError, OSError, ValueError):
            return None
        return GeneratedPreview(
            content=output.getvalue(),
            content_type="image/webp",
            width=width,
            height=height,
        )


class MediaValidator:
    """Fail-closed media validator and metadata scrubber."""

    def validate_and_sanitize(
        self, *, raw_path: Path, source_type: str, declared_mime: str
    ) -> ValidatedMedia:
        limits = ALLOWED_MEDIA.get(source_type)
        max_bytes = limits.get(declared_mime) if limits else None
        size = raw_path.stat().st_size
        if max_bytes is None:
            raise VideoSourceMediaError("unsupported_media_type", "This file type is not supported.")
        if size <= 0:
            raise VideoSourceMediaError("empty_file", "The selected file is empty.")
        if size > max_bytes:
            raise VideoSourceMediaError("file_too_large", "The selected file exceeds the allowed size.")
        signature = raw_path.read_bytes()[:32]
        if not _signature_matches(source_type, declared_mime, signature):
            raise VideoSourceMediaError("mime_mismatch", "The file content does not match its declared type.")
        if source_type == "binary_image":
            return self._sanitize_image(raw_path=raw_path, declared_mime=declared_mime)
        return self._sanitize_av(
            raw_path=raw_path, source_type=source_type, declared_mime=declared_mime
        )

    def _sanitize_image(self, *, raw_path: Path, declared_mime: str) -> ValidatedMedia:
        output = raw_path.with_name(f"sanitized-{raw_path.name}")
        try:
            with Image.open(raw_path) as image:
                image.verify()
            with Image.open(raw_path) as image:
                width, height = image.size
                if width <= 0 or height <= 0 or width > MAX_DIMENSION or height > MAX_DIMENSION:
                    raise VideoSourceMediaError("invalid_dimensions", "Image dimensions are not supported.")
                if width * height > MAX_IMAGE_PIXELS:
                    raise VideoSourceMediaError("image_pixel_limit", "The decoded image is too large.")
                save_format = {"image/jpeg": "JPEG", "image/png": "PNG", "image/webp": "WEBP"}[declared_mime]
                sanitized = image.convert("RGB") if save_format == "JPEG" else image.copy()
                save_options = {"quality": 92} if save_format in {"JPEG", "WEBP"} else {}
                sanitized.save(output, format=save_format, **save_options)
        except VideoSourceMediaError:
            raise
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise VideoSourceMediaError("media_decode_failed", "The image could not be decoded.") from exc
        return _validated(output, declared_mime, {"width": width, "height": height})

    def _sanitize_av(
        self, *, raw_path: Path, source_type: str, declared_mime: str
    ) -> ValidatedMedia:
        if not shutil.which("ffprobe") or not shutil.which("ffmpeg"):
            raise VideoSourceMediaError(
                "media_inspection_unavailable",
                "Media validation is temporarily unavailable.",
                retryable=True,
            )
        probe = _probe_media(raw_path)
        streams = probe.get("streams") or []
        duration = _duration_seconds(probe)
        if duration is None or duration <= 0 or duration > MAX_DURATION_SECONDS:
            raise VideoSourceMediaError("invalid_duration", "Media duration must be at most 180 seconds.")
        has_video = any(stream.get("codec_type") == "video" for stream in streams)
        has_audio = any(stream.get("codec_type") == "audio" for stream in streams)
        if source_type == "binary_video" and not has_video:
            raise VideoSourceMediaError("video_stream_required", "The MP4 has no readable video stream.")
        if source_type == "binary_audio" and not has_audio:
            raise VideoSourceMediaError("audio_stream_required", "The file has no readable audio stream.")
        output = raw_path.with_name(f"sanitized-{raw_path.name}")
        command = ["ffmpeg", "-v", "error", "-y", "-i", str(raw_path), "-map_metadata", "-1"]
        if source_type == "binary_audio":
            command.extend(["-vn"])
        command.extend(["-c", "copy", str(output)])
        completed = subprocess.run(command, capture_output=True, timeout=90)
        if completed.returncode != 0 or not output.exists():
            raise VideoSourceMediaError("media_sanitization_failed", "Private media metadata could not be removed.")
        sanitized_probe = _probe_media(output)
        width, height = _video_dimensions(sanitized_probe)
        metadata: dict[str, Any] = {"duration_seconds": duration}
        if width is not None and height is not None:
            metadata.update({"width": width, "height": height})
        return _validated(output, declared_mime, metadata)


class VideoSourceMediaService:
    def __init__(
        self,
        *,
        storage: ObjectStorageProvider,
        store: VideoSourceIntakeStore = video_source_intake_store,
        asset_writer: ProjectAssetWriter | None = None,
        validator: MediaValidator | None = None,
        preview_provider: MediaPreviewProvider | None = None,
    ) -> None:
        self.storage = storage
        self.store = store
        self.asset_writer = asset_writer or StatusProjectAssetWriter()
        self.validator = validator or MediaValidator()
        self.preview_provider = preview_provider or InternalMediaPreviewProvider(
            storage=storage,
            generator=ImagePreviewGenerator(),
            max_probe_bytes=10 * MIB,
        )

    def issue_preview_url(
        self, *, project_id: str, user_id: str, source: dict[str, Any]
    ) -> str | None:
        """Issue an ephemeral URL only for the derived preview owned by this source."""
        preview_asset_id = (source.get("safe_metadata") or {}).get("preview_asset_id")
        if not isinstance(preview_asset_id, str) or not source.get("asset_id"):
            return None
        if not isinstance(self.storage, S3ObjectStorageProvider):
            return None
        asset = get_status_service().get_project_asset_detail(
            project_id=project_id, user_id=user_id, asset_id=preview_asset_id
        )
        if (
            asset.media_kind != "thumbnail"
            or asset.source_asset_id != source["asset_id"]
            or asset.storage_locator is None
        ):
            return None
        locator = StorageLocator.model_validate(asset.storage_locator.model_dump())
        return self.storage.presign_private_read(locator=locator)

    async def create_upload_session(
        self,
        *,
        folder_id: str,
        user_id: str,
        source_type: str,
        file_name: str,
        mime_type: str,
        byte_size: int,
        checksum_sha256: str,
        expected_revision: int,
        idempotency_key: str,
        replace_source_id: str | None = None,
    ) -> UploadSessionResponse:
        _validate_declared_media(source_type=source_type, mime_type=mime_type, byte_size=byte_size)
        replay = await self.store.find_upload_session_by_idempotency(
            folder_id=folder_id, user_id=user_id, idempotency_key=idempotency_key
        )
        if replay:
            public = self._restore_public_session(replay)
            await self._restore_provider_session(public, replay["provider_state"])
            return await self._session_response(session=public, source_id=replay["source_id"])
        if replace_source_id:
            replaced = await self.store.get_source(
                folder_id=folder_id, source_id=replace_source_id, user_id=user_id
            )
            if replaced is None or not str(replaced["source_type"]).startswith("binary_"):
                raise IntakeNotFoundError("Source to replace not found")
            if replaced["status"] in {"removed", "superseded"}:
                raise IntakeConflictError("source_not_active", "The source can no longer be replaced.")
        source, replayed = await self.store.add_source(
            folder_id=folder_id,
            user_id=user_id,
            source_type=source_type,
            status="pending_validation",
            idempotency_key=idempotency_key,
            expected_revision=expected_revision,
            safe_metadata={"file_name": file_name, "mime_type": mime_type, "byte_size": byte_size},
            replacement_of_source_id=replace_source_id,
        )
        if replayed:
            replay = await self.store.find_upload_session_by_idempotency(
                folder_id=folder_id, user_id=user_id, idempotency_key=idempotency_key
            )
            if replay:
                public = self._restore_public_session(replay)
                await self._restore_provider_session(public, replay["provider_state"])
                return await self._session_response(session=public, source_id=replay["source_id"])
            raise IntakeConflictError("upload_session_incomplete", "The previous upload session is unavailable.")
        mode = UploadMode.PROXY if byte_size <= PROXY_MAX_BYTES else UploadMode.MULTIPART
        try:
            session = await asyncio.to_thread(
                self.storage.create_upload_session,
                namespace="quarantine",
                content_type=mime_type,
                expected_size=byte_size,
                checksum_sha256=checksum_sha256.lower(),
                mode=mode,
                expires_in=900,
            )
            provider_state = await self._export_provider_session(session)
            await self.store.create_upload_session_record(
                session_id=session.session_id,
                source_id=source["id"],
                folder_id=folder_id,
                user_id=user_id,
                source_type=source_type,
                file_name=file_name,
                mime_type=mime_type,
                byte_size=byte_size,
                checksum_sha256=checksum_sha256.lower(),
                provider_namespace=session.namespace,
                provider_state=provider_state,
                mode=session.mode.value,
                expires_at=session.expires_at.isoformat(),
                idempotency_key=idempotency_key,
            )
        except Exception:
            if "session" in locals():
                try:
                    await asyncio.to_thread(self.storage.abort_upload, session)
                except Exception:
                    pass
            await self.store.update_source(
                folder_id=folder_id,
                source_id=source["id"],
                user_id=user_id,
                status="failed",
                error_code="upload_session_failed",
                retryable=True,
            )
            raise
        return await self._session_response(session=session, source_id=source["id"])

    async def upload_proxy(
        self, *, folder_id: str, session_id: str, user_id: str, payload: bytes
    ) -> VideoSourceFolderResponse:
        record, session = await self._load_session(
            folder_id=folder_id, session_id=session_id, user_id=user_id, expected_mode=UploadMode.PROXY
        )
        locator = await asyncio.to_thread(self.storage.upload_proxy, session=session, source=payload)
        return await self._finalize_locator(record=record, session=session, raw_locator=locator)

    async def complete_multipart(
        self,
        *,
        folder_id: str,
        session_id: str,
        user_id: str,
        parts: Sequence[UploadedPartRequest],
    ) -> VideoSourceFolderResponse:
        record, session = await self._load_session(
            folder_id=folder_id, session_id=session_id, user_id=user_id, expected_mode=UploadMode.MULTIPART
        )
        receipts = [
            UploadedPart(
                part_number=part.part_number,
                etag=part.etag,
                checksum_sha256=part.checksum_sha256.lower(),
                size_bytes=part.size_bytes,
            )
            for part in parts
        ]
        locator = await asyncio.to_thread(self.storage.complete_upload, session=session, parts=receipts)
        return await self._finalize_locator(record=record, session=session, raw_locator=locator)

    async def sign_upload_part(
        self,
        *,
        folder_id: str,
        session_id: str,
        user_id: str,
        part_number: int,
        checksum_sha256: str,
        size_bytes: int,
    ) -> UploadPartInstruction:
        _, session = await self._load_session(
            folder_id=folder_id,
            session_id=session_id,
            user_id=user_id,
            expected_mode=UploadMode.MULTIPART,
        )
        part_count = (session.expected_size + MULTIPART_PART_BYTES - 1) // MULTIPART_PART_BYTES
        if part_number < 1 or part_number > part_count:
            raise VideoSourceMediaError(
                "invalid_upload_part", "The multipart part number is invalid."
            )
        expected_size = min(
            MULTIPART_PART_BYTES,
            session.expected_size - (part_number - 1) * MULTIPART_PART_BYTES,
        )
        if size_bytes != expected_size:
            raise VideoSourceMediaError(
                "invalid_upload_part_size", "The multipart part size is invalid."
            )
        operation = await asyncio.to_thread(
            self.storage.presign_upload_part,
            session=session,
            part_number=part_number,
            checksum_sha256=checksum_sha256.lower(),
            size_bytes=size_bytes,
            expires_in=300,
        )
        return UploadPartInstruction(
            part_number=part_number,
            upload_url=operation.url,
            expires_at=operation.expires_at,
            size_bytes=size_bytes,
            headers=dict(operation.headers),
        )

    async def _load_session(
        self, *, folder_id: str, session_id: str, user_id: str, expected_mode: UploadMode
    ) -> tuple[dict[str, Any], UploadSession]:
        record = await self.store.get_upload_session(
            session_id=session_id, folder_id=folder_id, user_id=user_id
        )
        if record is None:
            raise IntakeNotFoundError("Upload session not found")
        if record["status"] == "completed" and record["locator"]:
            raise IntakeConflictError("upload_already_completed", "This upload is already complete.")
        if datetime.fromisoformat(record["expires_at"]) <= datetime.now(UTC):
            raise IntakeConflictError("upload_session_expired", "This upload session has expired.")
        session = self._restore_public_session(record)
        if session.mode is not expected_mode:
            raise IntakeConflictError("upload_mode_mismatch", "This upload instruction cannot be used here.")
        await self._restore_provider_session(session, record["provider_state"])
        return record, session

    async def _finalize_locator(
        self, *, record: dict[str, Any], session: UploadSession, raw_locator: StorageLocator
    ) -> VideoSourceFolderResponse:
        await self.store.update_upload_session(
            session_id=record["id"], folder_id=record["folder_id"], user_id=record["user_id"],
            status="processing", locator=_locator_dict(raw_locator),
        )
        await self.store.update_source(
            folder_id=record["folder_id"], source_id=record["source_id"], user_id=record["user_id"],
            status="processing",
        )
        canonical: StorageLocator | None = None
        preview_locator: StorageLocator | None = None
        asset_ids: list[str] = []
        try:
            with tempfile.TemporaryDirectory(prefix="video-source-intake-") as temp_dir:
                raw_path = Path(temp_dir) / _safe_temp_name(record["file_name"])
                await asyncio.to_thread(self._download_to_path, raw_locator, raw_path)
                validated = await asyncio.to_thread(
                    self.validator.validate_and_sanitize,
                    raw_path=raw_path,
                    source_type=record["source_type"],
                    declared_mime=record["mime_type"],
                )
                canonical = await asyncio.to_thread(self._upload_canonical, validated)
            asset_id = await asyncio.to_thread(
                self.asset_writer.attach,
                user_id=record["user_id"],
                project_id=record["project_id"],
                folder_id=record["folder_id"],
                source_id=record["source_id"],
                source_type=record["source_type"],
                file_name=record["file_name"],
                mime_type=validated.mime_type,
                locator=canonical,
                metadata={**validated.metadata, "byte_size": validated.byte_size},
            )
            asset_ids.append(asset_id)
            safe_metadata = {
                **validated.metadata,
                "byte_size": validated.byte_size,
                "mime_type": validated.mime_type,
                "file_name": record["file_name"],
            }
            media_kind = {
                "binary_image": "image",
                "binary_video": "video",
                "binary_audio": "audio",
            }[record["source_type"]]
            preview = await asyncio.to_thread(
                self.preview_provider.create_preview,
                source=canonical,
                media_kind=media_kind,
                metadata={
                    **validated.metadata,
                    "size_bytes": validated.byte_size,
                    "content_type": validated.mime_type,
                },
            )
            safe_metadata["preview_status"] = preview.status.value
            if preview.status is PreviewStatus.READY and preview.locator is not None:
                preview_locator = preview.locator
                try:
                    preview_asset_id = await asyncio.to_thread(
                        self.asset_writer.attach_preview,
                        user_id=record["user_id"],
                        project_id=record["project_id"],
                        folder_id=record["folder_id"],
                        source_id=record["source_id"],
                        source_asset_id=asset_id,
                        locator=preview_locator,
                        metadata=dict(preview.safe_metadata),
                    )
                except Exception:
                    try:
                        await asyncio.to_thread(self.storage.delete_version, preview_locator)
                    except Exception:
                        pass
                    preview_locator = None
                    safe_metadata["preview_status"] = PreviewStatus.METADATA_FALLBACK.value
                    safe_metadata["preview_error_code"] = "preview_asset_persistence_failed"
                else:
                    asset_ids.append(preview_asset_id)
                    safe_metadata["preview_asset_id"] = preview_asset_id
            elif preview.error_code:
                safe_metadata["preview_error_code"] = preview.error_code
            await self.store.update_upload_session(
                session_id=record["id"],
                folder_id=record["folder_id"],
                user_id=record["user_id"],
                status="completed",
                locator=_locator_dict(canonical),
            )
            await self.store.update_source(
                folder_id=record["folder_id"],
                source_id=record["source_id"],
                user_id=record["user_id"],
                status="ready",
                asset_id=asset_id,
                safe_metadata=safe_metadata,
            )
        except (VideoSourceMediaError, ObjectStorageError) as exc:
            rollback_failed = not await self._rollback_assets(record=record, asset_ids=asset_ids)
            await self._compensate(
                record=record,
                raw_locator=raw_locator,
                canonical=canonical,
                preview_locator=preview_locator,
                error=exc,
                cleanup_failed=rollback_failed,
            )
            raise
        except Exception as exc:
            rollback_failed = not await self._rollback_assets(record=record, asset_ids=asset_ids)
            await self._compensate(
                record=record,
                raw_locator=raw_locator,
                canonical=canonical,
                preview_locator=preview_locator,
                error=exc,
                cleanup_failed=rollback_failed,
            )
            raise VideoSourceMediaError(
                "asset_persistence_failed", "The file could not be attached. It is safe to retry.", retryable=True
            ) from exc
        try:
            await asyncio.to_thread(self.storage.delete_version, raw_locator)
        except Exception:
            pass
        source = await self.store.get_source(
            folder_id=record["folder_id"], source_id=record["source_id"], user_id=record["user_id"]
        )
        if source and source.get("replacement_of_source_id"):
            replaced = await self.store.get_source(
                folder_id=record["folder_id"],
                source_id=source["replacement_of_source_id"],
                user_id=record["user_id"],
            )
            await self.store.supersede_source(
                folder_id=record["folder_id"],
                source_id=source["replacement_of_source_id"],
                replacement_source_id=record["source_id"],
                user_id=record["user_id"],
            )
            if replaced and replaced.get("asset_id"):
                await asyncio.to_thread(
                    self.asset_writer.detach,
                    user_id=record["user_id"],
                    project_id=record["project_id"],
                    folder_id=record["folder_id"],
                    source_id=replaced["id"],
                    asset_id=replaced["asset_id"],
                )
        intake = VideoSourceIntakeService(store=self.store)
        response = await intake.get_folder(folder_id=record["folder_id"], user_id=record["user_id"])
        if response is None:
            raise RuntimeError("Source folder disappeared after upload finalization")
        return response

    async def _compensate(
        self, *, record: dict[str, Any], raw_locator: StorageLocator,
        canonical: StorageLocator | None, preview_locator: StorageLocator | None,
        error: Exception, cleanup_failed: bool = False,
    ) -> None:
        for locator in [preview_locator, canonical, raw_locator]:
            if locator is None:
                continue
            try:
                await asyncio.to_thread(self.storage.delete_version, locator)
            except Exception:
                cleanup_failed = True
        code = getattr(error, "code", "media_processing_failed")
        await self.store.update_upload_session(
            session_id=record["id"], folder_id=record["folder_id"], user_id=record["user_id"],
            status="orphan_cleanup_needed" if cleanup_failed else "failed",
        )
        await self.store.update_source(
            folder_id=record["folder_id"], source_id=record["source_id"], user_id=record["user_id"],
            status="orphan_cleanup_needed" if cleanup_failed else "failed",
            error_code="orphan_cleanup_needed" if cleanup_failed else str(code),
            retryable=bool(getattr(error, "retryable", False) or cleanup_failed),
        )

    async def _rollback_assets(
        self, *, record: dict[str, Any], asset_ids: Sequence[str]
    ) -> bool:
        if not asset_ids:
            return True
        try:
            await asyncio.to_thread(
                self.asset_writer.rollback,
                user_id=record["user_id"],
                project_id=record["project_id"],
                folder_id=record["folder_id"],
                source_id=record["source_id"],
                asset_ids=list(reversed(asset_ids)),
            )
        except Exception:
            return False
        return True

    async def _session_response(self, *, session: UploadSession, source_id: str) -> UploadSessionResponse:
        if session.mode is UploadMode.PROXY:
            return UploadSessionResponse(
                session_id=session.session_id,
                source_id=source_id,
                strategy="proxy",
                upload_url=f"uploads/{session.session_id}/content",
                expires_at=session.expires_at,
            )
        part_count = (session.expected_size + MULTIPART_PART_BYTES - 1) // MULTIPART_PART_BYTES
        instructions: list[UploadPartInstruction] = []
        for part_number in range(1, part_count + 1):
            size_bytes = min(
                MULTIPART_PART_BYTES,
                session.expected_size - (part_number - 1) * MULTIPART_PART_BYTES,
            )
            instructions.append(
                UploadPartInstruction(
                    part_number=part_number,
                    size_bytes=size_bytes,
                )
            )
        return UploadSessionResponse(
            session_id=session.session_id,
            source_id=source_id,
            strategy="multipart",
            parts=instructions,
            expires_at=session.expires_at,
        )

    async def _export_provider_session(self, session: UploadSession) -> dict[str, Any]:
        exporter = getattr(self.storage, "export_session_state", None)
        if exporter is None:
            return {}
        return dict(await asyncio.to_thread(exporter, session))

    async def _restore_provider_session(self, session: UploadSession, state: dict[str, Any]) -> None:
        restorer = getattr(self.storage, "restore_session", None)
        if restorer is not None and state:
            await asyncio.to_thread(restorer, session, state)

    def _restore_public_session(self, record: dict[str, Any]) -> UploadSession:
        return UploadSession(
            session_id=record["id"],
            provider=self.storage.provider_name,
            mode=UploadMode(record["mode"]),
            namespace=record["provider_namespace"],
            content_type=record["mime_type"],
            expected_size=record["byte_size"],
            checksum_sha256=record["checksum_sha256"],
            expires_at=datetime.fromisoformat(record["expires_at"]),
        )

    def _download_to_path(self, locator: StorageLocator, output: Path) -> None:
        stat = self.storage.stat(locator)
        with output.open("wb") as stream:
            start = 0
            while start < stat.size_bytes:
                end = min(stat.size_bytes - 1, start + MULTIPART_PART_BYTES - 1)
                stream.write(self.storage.read_range(locator, start=start, end=end))
                start = end + 1

    def _upload_canonical(self, media: ValidatedMedia) -> StorageLocator:
        mode = UploadMode.PROXY if media.byte_size <= PROXY_MAX_BYTES else UploadMode.MULTIPART
        session = self.storage.create_upload_session(
            namespace="assets",
            content_type=media.mime_type,
            expected_size=media.byte_size,
            checksum_sha256=media.checksum_sha256,
            mode=mode,
            expires_in=900,
        )
        if mode is UploadMode.PROXY:
            with media.path.open("rb") as stream:
                return self.storage.upload_proxy(session=session, source=stream)
        parts: list[UploadedPart] = []
        with media.path.open("rb") as stream:
            part_number = 1
            while chunk := stream.read(MULTIPART_PART_BYTES):
                parts.append(self.storage.upload_part(session=session, part_number=part_number, source=chunk))
                part_number += 1
        return self.storage.complete_upload(session=session, parts=parts)


def _validate_declared_media(*, source_type: str, mime_type: str, byte_size: int) -> None:
    max_bytes = ALLOWED_MEDIA.get(source_type, {}).get(mime_type)
    if max_bytes is None:
        raise VideoSourceMediaError("unsupported_media_type", "This file type is not supported.")
    if byte_size <= 0:
        raise VideoSourceMediaError("empty_file", "The selected file is empty.")
    if byte_size > max_bytes:
        raise VideoSourceMediaError("file_too_large", "The selected file exceeds the allowed size.")


def _signature_matches(source_type: str, mime_type: str, value: bytes) -> bool:
    if source_type == "binary_image":
        return {
            "image/jpeg": value.startswith(b"\xff\xd8\xff"),
            "image/png": value.startswith(b"\x89PNG\r\n\x1a\n"),
            "image/webp": value.startswith(b"RIFF") and value[8:12] == b"WEBP",
        }.get(mime_type, False)
    if source_type == "binary_video":
        return len(value) >= 12 and value[4:8] == b"ftyp"
    if mime_type in {"audio/wav", "audio/x-wav"}:
        return value.startswith(b"RIFF") and value[8:12] == b"WAVE"
    if mime_type == "audio/mp4":
        return len(value) >= 12 and value[4:8] == b"ftyp"
    return value.startswith(b"ID3") or (len(value) >= 2 and value[0] == 0xFF and value[1] & 0xE0 == 0xE0)


def _validated(path: Path, mime_type: str, metadata: dict[str, Any]) -> ValidatedMedia:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(MIB):
            digest.update(chunk)
    return ValidatedMedia(
        path=path,
        mime_type=mime_type,
        byte_size=path.stat().st_size,
        checksum_sha256=digest.hexdigest(),
        metadata=metadata,
    )


def _probe_media(path: Path) -> dict[str, Any]:
    completed = subprocess.run(
        ["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)],
        capture_output=True, text=True, timeout=45,
    )
    if completed.returncode != 0:
        raise VideoSourceMediaError("media_decode_failed", "The media file could not be decoded.")
    try:
        return json.loads(completed.stdout or "{}")
    except json.JSONDecodeError as exc:
        raise VideoSourceMediaError("media_decode_failed", "The media file could not be decoded.") from exc


def _duration_seconds(probe: dict[str, Any]) -> float | None:
    raw = (probe.get("format") or {}).get("duration")
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def _video_dimensions(probe: dict[str, Any]) -> tuple[int | None, int | None]:
    for stream in probe.get("streams") or []:
        if stream.get("codec_type") == "video":
            try:
                return int(stream.get("width")), int(stream.get("height"))
            except (TypeError, ValueError):
                return None, None
    return None, None


def _safe_temp_name(value: str) -> str:
    cleaned = "".join(char if char.isalnum() or char in {".", "-", "_"} else "_" for char in value)
    return cleaned[:120] or "source.bin"


def _locator_dict(locator: StorageLocator) -> dict[str, str]:
    return {
        "provider": locator.provider,
        "namespace": locator.namespace,
        "object_key": locator.object_key,
        "version": locator.version,
        "checksum_sha256": locator.checksum_sha256,
    }


_media_service: VideoSourceMediaService | None = None


def get_video_source_media_service() -> VideoSourceMediaService:
    global _media_service
    if _media_service is not None:
        return _media_service
    provider = os.getenv("OBJECT_STORAGE_PROVIDER", "s3").strip().lower()
    if provider != "s3":
        raise RuntimeError("Unsupported canonical object storage provider")
    bucket = os.getenv("CONTENTGLOWS_S3_BUCKET", "").strip()
    if not bucket:
        raise RuntimeError("CONTENTGLOWS_S3_BUCKET is required for binary source uploads")
    storage = S3ObjectStorageProvider(
        bucket=bucket,
        region_name=os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION"),
        endpoint_url=os.getenv("CONTENTGLOWS_S3_ENDPOINT_URL") or None,
        key_prefix=os.getenv("CONTENTGLOWS_S3_KEY_PREFIX", "contentglows"),
        server_side_encryption=os.getenv("CONTENTGLOWS_S3_SSE", "AES256"),
        kms_key_id=os.getenv("CONTENTGLOWS_S3_KMS_KEY_ID") or None,
    )
    _media_service = VideoSourceMediaService(storage=storage)
    return _media_service


def set_video_source_media_service_for_tests(service: VideoSourceMediaService | None) -> None:
    global _media_service
    _media_service = service
