"""Render artifact normalization and playback URL signing."""

from __future__ import annotations

import os
from datetime import UTC, datetime, timedelta
from typing import Any


DEFAULT_GCS_SIGNED_URL_TTL_SECONDS = 3600


class RenderArtifactError(RuntimeError):
    """Raised when artifact metadata cannot be trusted or signed."""


def _storage_mode() -> str:
    return (
        os.getenv("CONTENTGLOWS_RENDER_STORAGE")
        or "local"
    ).strip().lower() or "local"


def _gcs_bucket() -> str | None:
    return (os.getenv("GCS_RENDER_BUCKET") or "").strip() or None


def _gcs_prefix() -> str:
    prefix = (os.getenv("GCS_RENDER_PREFIX") or "renders").strip().strip("/")
    return prefix or "renders"


def _mode_folder(render_mode: str) -> str:
    return "finals" if render_mode == "final" else "previews"


def build_expected_artifact(job_id: str, render_mode: str) -> dict[str, Any] | None:
    """Build the deterministic artifact location persisted before dispatch."""
    if _storage_mode() != "gcs":
        return None
    bucket = _gcs_bucket()
    if not bucket:
        raise RenderArtifactError("GCS render bucket is not configured")
    object_name = f"{_gcs_prefix()}/{_mode_folder(render_mode)}/{job_id}.mp4"
    return {
        "provider": "gcs",
        "bucket": bucket,
        "object_name": object_name,
        "artifact_path": object_name,
        "file_name": f"{job_id}.mp4",
        "mime_type": "video/mp4",
        "render_mode": render_mode,
        "expected": True,
    }


def normalize_worker_artifact(
    artifact: dict[str, Any] | None,
    *,
    render_mode: str,
    expected_artifact: dict[str, Any] | None = None,
) -> dict[str, Any] | None:
    if not isinstance(artifact, dict):
        return None
    provider = str(artifact.get("provider") or (expected_artifact or {}).get("provider") or "local")
    artifact_path = artifact.get("artifactPath") or artifact.get("artifact_path")
    object_name = artifact.get("objectName") or artifact.get("object_name") or artifact_path
    if provider == "gcs":
        bucket = artifact.get("bucket") or (expected_artifact or {}).get("bucket") or _gcs_bucket()
        if not isinstance(bucket, str) or not bucket:
            return None
        if not isinstance(object_name, str) or not object_name:
            return None
        if expected_artifact:
            expected_bucket = expected_artifact.get("bucket")
            expected_object = expected_artifact.get("object_name") or expected_artifact.get("artifact_path")
            expected_mode = expected_artifact.get("render_mode")
            if bucket != expected_bucket or object_name != expected_object or render_mode != expected_mode:
                return None
        return {
            "provider": "gcs",
            "bucket": bucket,
            "object_name": object_name,
            "artifact_path": object_name,
            "retention_expires_at": artifact.get("retentionExpiresAt") or artifact.get("retention_expires_at"),
            "deletion_warning_at": artifact.get("deletionWarningAt") or artifact.get("deletion_warning_at"),
            "byte_size": int(artifact.get("byteSize") or artifact.get("byte_size") or 0),
            "mime_type": str(artifact.get("mimeType") or artifact.get("mime_type") or "video/mp4"),
            "file_name": str(artifact.get("fileName") or artifact.get("file_name") or f"{render_mode}.mp4"),
            "render_mode": render_mode,
            "expected": False,
        }
    if not isinstance(artifact_path, str) or not artifact_path:
        return None
    return {
        "provider": "local",
        "artifact_path": artifact_path,
        "retention_expires_at": artifact.get("retentionExpiresAt") or artifact.get("retention_expires_at"),
        "deletion_warning_at": artifact.get("deletionWarningAt") or artifact.get("deletion_warning_at"),
        "byte_size": int(artifact.get("byteSize") or artifact.get("byte_size") or 0),
        "mime_type": str(artifact.get("mimeType") or artifact.get("mime_type") or "video/mp4"),
        "file_name": str(artifact.get("fileName") or artifact.get("file_name") or f"{render_mode}.mp4"),
        "render_mode": render_mode,
    }


def is_gcs_artifact(artifact: dict[str, Any] | None) -> bool:
    return isinstance(artifact, dict) and artifact.get("provider") == "gcs"


def signed_gcs_playback_url(artifact: dict[str, Any]) -> tuple[str, datetime]:
    bucket_name = artifact.get("bucket")
    object_name = artifact.get("object_name") or artifact.get("artifact_path")
    if not isinstance(bucket_name, str) or not bucket_name:
        raise RenderArtifactError("GCS artifact bucket is missing")
    if not isinstance(object_name, str) or not object_name:
        raise RenderArtifactError("GCS artifact object is missing")

    try:
        from google.cloud import storage  # type: ignore
    except ImportError as exc:
        raise RenderArtifactError("google-cloud-storage is not installed") from exc

    ttl_seconds = int(os.getenv("GCS_SIGNED_URL_TTL_SECONDS") or DEFAULT_GCS_SIGNED_URL_TTL_SECONDS)
    if ttl_seconds <= 0:
        ttl_seconds = DEFAULT_GCS_SIGNED_URL_TTL_SECONDS
    expires_at = datetime.now(UTC) + timedelta(seconds=ttl_seconds)
    client = storage.Client()
    blob = client.bucket(bucket_name).blob(object_name)
    url = blob.generate_signed_url(
        version="v4",
        expiration=expires_at,
        method="GET",
        response_type=str(artifact.get("mime_type") or "video/mp4"),
    )
    return url, expires_at


def gcs_object_metadata(artifact: dict[str, Any]) -> dict[str, Any] | None:
    """Return GCS object metadata, or None when the expected object does not exist."""
    bucket_name = artifact.get("bucket")
    object_name = artifact.get("object_name") or artifact.get("artifact_path")
    if not isinstance(bucket_name, str) or not isinstance(object_name, str):
        return None
    try:
        from google.cloud import storage  # type: ignore
    except ImportError as exc:
        raise RenderArtifactError("google-cloud-storage is not installed") from exc
    blob = storage.Client().bucket(bucket_name).blob(object_name)
    if not blob.exists():
        return None
    blob.reload()
    size = int(getattr(blob, "size", 0) or 0)
    if size <= 0:
        return None
    return {
        "provider": "gcs",
        "bucket": bucket_name,
        "object_name": object_name,
        "artifact_path": object_name,
        "byte_size": size,
        "mime_type": getattr(blob, "content_type", None) or artifact.get("mime_type") or "video/mp4",
        "file_name": artifact.get("file_name") or object_name.rsplit("/", 1)[-1],
        "render_mode": artifact.get("render_mode"),
        "retention_expires_at": artifact.get("retention_expires_at"),
        "deletion_warning_at": artifact.get("deletion_warning_at"),
        "expected": False,
    }
