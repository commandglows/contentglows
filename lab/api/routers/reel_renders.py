"""Reel render job API routes backed by the Remotion worker."""

from __future__ import annotations

import json
import os
import uuid
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import FileResponse

from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import require_owned_content_record
from api.models.reel_render import (
    ReelRenderCancelResponse,
    ReelRenderExportRequest,
    ReelRenderJobCreateRequest,
    ReelRenderJobResponse,
    ReelRenderArtifact,
)
from api.services.job_store import job_store
from api.services.remotion_render_client import (
    RemotionRenderResponseError,
    RemotionRenderUnavailableError,
    get_remotion_render_client,
)
from api.services.render_artifact_tokens import (
    RenderArtifactTokenError,
    issue_artifact_token,
    verify_artifact_token,
)
from api.services.render_artifacts import (
    RenderArtifactError,
    build_expected_artifact,
    gcs_object_metadata,
    is_gcs_artifact,
    normalize_worker_artifact,
    signed_gcs_playback_url,
)
from status.service import ContentNotFoundError, get_status_service

router = APIRouter(
    prefix="/api/reels/render-jobs",
    tags=["Reels Render Jobs"],
)

JOB_TYPE = "reel_render"
SUPPORTED_TEMPLATE_ID = "content-summary-v1"
ACTIVE_STATUSES = {"queued", "in_progress"}
TERMINAL_STATUSES = {"completed", "failed", "cancelled"}
MAX_SOURCE_CHARS = 20_000
MAX_PROPS_BYTES = 64 * 1024
RETRY_AFTER_SECONDS = 60


def _render_root_dir() -> Path:
    configured = os.getenv("CONTENTGLOWS_RENDER_DIR")
    if configured:
        return Path(configured).resolve()
    return (Path.cwd() / "renders").resolve()


def _read_limit(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        value = int(raw)
    except ValueError:
        return default
    return value if value > 0 else default


def _sanitize_worker_status(worker_status: str) -> str:
    mapping = {
        "queued": "queued",
        "in_progress": "in_progress",
        "in-progress": "in_progress",
        "running": "in_progress",
        "completed": "completed",
        "failed": "failed",
        "cancelled": "cancelled",
        "canceled": "cancelled",
    }
    return mapping.get(worker_status, "failed")


def _resolve_safe_artifact_path(root_dir: Path, artifact_path: str) -> Path:
    normalized = artifact_path.replace("\\", "/").strip()
    rel = PurePosixPath(normalized)
    if rel.is_absolute() or ".." in rel.parts:
        raise HTTPException(status_code=403, detail="Forbidden")
    if rel.suffix.lower() != ".mp4":
        raise HTTPException(status_code=403, detail="Forbidden")
    resolved = (root_dir / Path(*rel.parts)).resolve()
    if resolved != root_dir and root_dir not in resolved.parents:
        raise HTTPException(status_code=403, detail="Forbidden")
    return resolved


def _json_size_bytes(data: dict[str, Any]) -> int:
    compact = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    return len(compact.encode("utf-8"))


def _extract_body_for_render(content_id: str) -> str:
    status_service = get_status_service()
    body = status_service.get_content_body(content_id)
    if not body:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Content body is required for render",
        )
    content_body = (body.get("body") or "").strip()
    if not content_body:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Content body is required for render",
        )
    return content_body


def _summarize_points(body: str, *, max_points: int = 5) -> list[str]:
    lines = []
    for chunk in body.splitlines():
        candidate = chunk.strip(" -*\t")
        if len(candidate) >= 20:
            lines.append(candidate)
        if len(lines) >= max_points:
            break
    if not lines:
        sentences = [s.strip() for s in body.replace("\n", " ").split(".") if s.strip()]
        lines = sentences[:max_points]
    if not lines:
        lines = [body[:180]]
    return [line[:260] for line in lines]


def _build_input_props(*, title: str, body: str) -> tuple[dict[str, Any], bool]:
    truncated = len(body) > MAX_SOURCE_CHARS
    trimmed = body[:MAX_SOURCE_CHARS]
    props = {
        "title": title[:240],
        "hook": trimmed[:260],
        "key_points": _summarize_points(trimmed),
        "cta": "Follow for more.",
    }
    if _json_size_bytes(props) > MAX_PROPS_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Render props exceed 64KB limit",
        )
    return props, truncated


def _require_supported_request(request: ReelRenderJobCreateRequest) -> None:
    if request.template_id != SUPPORTED_TEMPLATE_ID:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported template_id",
        )
    if request.duration_seconds != 60:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="duration_seconds must be 60",
        )


def _as_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if not value:
        return datetime.now(UTC)
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return datetime.now(UTC)
    return datetime.now(UTC)


def _is_owned_job(job: dict[str, Any], user_id: str) -> bool:
    return job.get("user_id") == user_id and job.get("job_type") == JOB_TYPE


def _active_job_count(jobs: list[dict[str, Any]]) -> int:
    return sum(1 for job in jobs if job.get("status") in ACTIVE_STATUSES)


def _enforce_capacity(*, current_user: CurrentUser, jobs: list[dict[str, Any]]) -> None:
    max_user = _read_limit("RENDER_MAX_ACTIVE_PER_USER", 1)
    max_global = _read_limit("RENDER_MAX_ACTIVE_GLOBAL", 3)
    user_jobs = [
        job for job in jobs
        if job.get("user_id") == current_user.user_id and job.get("status") in ACTIVE_STATUSES
    ]
    if len(user_jobs) >= max_user or _active_job_count(jobs) >= max_global:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "message": "Render capacity reached",
                "retry_after_seconds": RETRY_AFTER_SECONDS,
            },
            headers={"Retry-After": str(RETRY_AFTER_SECONDS)},
        )


def _artifact_from_job(job: dict[str, Any], request: Request) -> ReelRenderArtifact | None:
    if job.get("status") != "completed":
        return None
    if is_gcs_artifact(job.get("artifact")):
        artifact = job["artifact"]
        if artifact.get("expected"):
            return None
        try:
            artifact_url, artifact_expires_at = signed_gcs_playback_url(artifact)
        except RenderArtifactError as exc:
            raise HTTPException(status_code=503, detail="Artifact signing unavailable") from exc
        return ReelRenderArtifact(
            artifact_url=artifact_url,
            artifact_expires_at=artifact_expires_at,
            retention_expires_at=_as_datetime(artifact.get("retention_expires_at")),
            deletion_warning_at=_as_datetime(artifact.get("deletion_warning_at")),
            byte_size=int(artifact.get("byte_size") or 0),
            mime_type=str(artifact.get("mime_type") or "video/mp4"),
            render_mode=job["render_mode"],
            file_name=str(artifact.get("file_name") or f"{job['job_id']}.mp4"),
        )
    artifact_path = job.get("artifact_path")
    if not isinstance(artifact_path, str) or not artifact_path:
        return None

    artifact_url_base = str(request.url_for("get_reel_render_artifact", job_id=job["job_id"]))
    try:
        token, artifact_expires_at = issue_artifact_token(
            job_id=job["job_id"],
            render_mode=job["render_mode"],
            artifact_path=artifact_path,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Artifact signing unavailable") from exc
    artifact_url = f"{artifact_url_base}?token={token}"

    retention_expires_at = _as_datetime(job.get("retention_expires_at"))
    deletion_warning_at = _as_datetime(job.get("deletion_warning_at"))
    return ReelRenderArtifact(
        artifact_url=artifact_url,
        artifact_expires_at=artifact_expires_at,
        retention_expires_at=retention_expires_at,
        deletion_warning_at=deletion_warning_at,
        byte_size=int(job.get("artifact_byte_size") or 0),
        mime_type=str(job.get("artifact_mime_type") or "video/mp4"),
        render_mode=job["render_mode"],
        file_name=str(job.get("artifact_file_name") or f"{job['job_id']}.mp4"),
    )


def _to_job_response(job: dict[str, Any], request: Request) -> ReelRenderJobResponse:
    return ReelRenderJobResponse(
        job_id=job["job_id"],
        job_type=job["job_type"],
        status=job.get("status", "queued"),
        progress=int(job.get("progress") or 0),
        message=job.get("message"),
        content_id=job["content_id"],
        project_id=job["project_id"],
        template_id=job["template_id"],
        render_mode=job["render_mode"],
        duration_seconds=int(job.get("duration_seconds") or 60),
        parent_preview_job_id=job.get("parent_preview_job_id"),
        worker_job_id=job.get("worker_job_id"),
        artifact=_artifact_from_job(job, request),
        created_at=_as_datetime(job.get("created_at")),
        updated_at=_as_datetime(job.get("updated_at")),
    )


async def _load_owned_job_or_404(job_id: str, current_user: CurrentUser) -> dict[str, Any]:
    job = await job_store.get(job_id)
    if not job or not _is_owned_job(job, current_user.user_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    content_id = job.get("content_id")
    if not isinstance(content_id, str) or not content_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    try:
        await require_owned_content_record(
            content_id=content_id,
            current_user=current_user,
            status_service=get_status_service(),
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found") from exc
    return job


async def _sync_job_from_worker(job: dict[str, Any]) -> dict[str, Any]:
    worker_job_id = job.get("worker_job_id")
    if not isinstance(worker_job_id, str) or not worker_job_id:
        return job
    if job.get("status") in TERMINAL_STATUSES:
        return job

    try:
        client = get_remotion_render_client()
        worker_payload = await client.get_render(worker_job_id)
    except RemotionRenderUnavailableError:
        return {
            **job,
            "message": job.get("message") or "Render status temporarily unavailable",
        }
    except RemotionRenderResponseError as exc:
        await job_store.update(
            job["job_id"],
            status="failed",
            progress=0,
            message=str(exc),
        )
        updated = await job_store.get(job["job_id"])
        return updated or job

    worker_status = _sanitize_worker_status(str(worker_payload.get("status", "")))
    update_fields: dict[str, Any] = {
        "status": worker_status,
        "progress": int(worker_payload.get("progress") or 0),
        "message": worker_payload.get("message"),
    }

    if worker_status == "completed":
        artifact = worker_payload.get("artifact")
        if not isinstance(artifact, dict):
            expected = job.get("artifact") if is_gcs_artifact(job.get("artifact")) else None
            try:
                reconstructed = gcs_object_metadata(expected) if expected else None
            except RenderArtifactError:
                reconstructed = None
            if reconstructed:
                update_fields.update(
                    artifact=reconstructed,
                    artifact_path=reconstructed["artifact_path"],
                    artifact_byte_size=int(reconstructed.get("byte_size") or 0),
                    artifact_mime_type=str(reconstructed.get("mime_type") or "video/mp4"),
                    artifact_file_name=str(reconstructed.get("file_name") or f"{job['job_id']}.mp4"),
                )
            else:
                update_fields["status"] = "failed"
                update_fields["message"] = "render_artifact_unavailable"
        else:
            normalized_artifact = normalize_worker_artifact(
                artifact,
                render_mode=str(job.get("render_mode") or "preview"),
                expected_artifact=job.get("artifact") if is_gcs_artifact(job.get("artifact")) else None,
            )
            artifact_path = normalized_artifact.get("artifact_path") if normalized_artifact else None
            if not isinstance(artifact_path, str) or not artifact_path:
                update_fields["status"] = "failed"
                update_fields["message"] = "Worker completed without artifact path"
            elif is_gcs_artifact(normalized_artifact):
                update_fields.update(
                    artifact=normalized_artifact,
                    artifact_path=artifact_path,
                    artifact_byte_size=int(normalized_artifact.get("byte_size") or 0),
                    artifact_mime_type=str(normalized_artifact.get("mime_type") or "video/mp4"),
                    artifact_file_name=str(normalized_artifact.get("file_name") or f"{job['job_id']}.mp4"),
                    retention_expires_at=normalized_artifact.get("retention_expires_at"),
                    deletion_warning_at=normalized_artifact.get("deletion_warning_at"),
                )
            else:
                safe_path = _resolve_safe_artifact_path(_render_root_dir(), artifact_path)
                if not safe_path.exists() or safe_path.stat().st_size <= 0:
                    update_fields["status"] = "failed"
                    update_fields["message"] = "Rendered artifact is missing or empty"
                else:
                    update_fields.update(
                        artifact_path=artifact_path,
                        artifact_byte_size=int(normalized_artifact.get("byte_size") or safe_path.stat().st_size),
                        artifact_mime_type=str(normalized_artifact.get("mime_type") or "video/mp4"),
                        artifact_file_name=str(normalized_artifact.get("file_name") or safe_path.name),
                        retention_expires_at=normalized_artifact.get("retention_expires_at"),
                        deletion_warning_at=normalized_artifact.get("deletion_warning_at"),
                    )

    await job_store.update(job["job_id"], **update_fields)
    updated = await job_store.get(job["job_id"])
    return updated or job


@router.post(
    "",
    response_model=ReelRenderJobResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def create_reel_render_job(
    request: ReelRenderJobCreateRequest,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    _require_supported_request(request)

    status_service = get_status_service()
    owned_record = await require_owned_content_record(
        content_id=request.content_id,
        current_user=current_user,
        status_service=status_service,
    )
    if not owned_record.title:
        raise HTTPException(status_code=400, detail="Content title is required")

    jobs = await job_store.list_by_type(JOB_TYPE, limit=500)
    for candidate in jobs:
        if (
            candidate.get("user_id") == current_user.user_id
            and candidate.get("content_id") == request.content_id
            and candidate.get("template_id") == request.template_id
            and candidate.get("render_mode") == "preview"
            and candidate.get("status") in ACTIVE_STATUSES
        ):
            return _to_job_response(candidate, raw_request)

    _enforce_capacity(current_user=current_user, jobs=jobs)

    body = _extract_body_for_render(request.content_id)
    input_props, truncated = _build_input_props(title=owned_record.title, body=body)
    now = datetime.utcnow().isoformat()
    job_id = str(uuid.uuid4())
    try:
        expected_artifact = build_expected_artifact(job_id, "preview")
    except RenderArtifactError as exc:
        raise HTTPException(status_code=503, detail="Render storage unavailable") from exc
    await job_store.upsert(
        job_id=job_id,
        job_type=JOB_TYPE,
        status="queued",
        progress=0,
        message="Queued",
        user_id=current_user.user_id,
        content_id=request.content_id,
        project_id=owned_record.project_id,
        template_id=request.template_id,
        render_mode="preview",
        duration_seconds=request.duration_seconds,
        client_request_id=request.client_request_id,
        parent_preview_job_id=None,
        metadata={"content_truncated": truncated},
        artifact=expected_artifact,
        input_props=input_props,
        requested_at=now,
    )

    try:
        client = get_remotion_render_client()
        worker_payload = await client.create_render(
            {
                "jobId": job_id,
                "renderMode": "preview",
                "durationSeconds": request.duration_seconds,
                "templateId": request.template_id,
                "compositionId": "ReelFromContent",
                "inputProps": input_props,
            }
        )
    except RemotionRenderUnavailableError as exc:
        await job_store.update(
            job_id,
            status="failed",
            progress=0,
            message="Render worker unavailable",
        )
        raise HTTPException(status_code=503, detail="Render worker unavailable") from exc
    except RemotionRenderResponseError as exc:
        await job_store.update(
            job_id,
            status="failed",
            progress=0,
            message=str(exc),
        )
        raise HTTPException(status_code=502, detail="Render worker rejected request") from exc

    await job_store.update(
        job_id,
        status=_sanitize_worker_status(str(worker_payload.get("status", "queued"))),
        progress=int(worker_payload.get("progress") or 0),
        worker_job_id=str(worker_payload.get("workerJobId") or job_id),
        message=worker_payload.get("message") or "Queued",
    )
    job = await job_store.get(job_id)
    if not job:
        raise HTTPException(status_code=500, detail="Failed to persist render job")
    return _to_job_response(job, raw_request)


@router.get("/{job_id}", response_model=ReelRenderJobResponse)
async def get_reel_render_job(
    job_id: str,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    job = await _load_owned_job_or_404(job_id, current_user)
    job = await _sync_job_from_worker(job)
    return _to_job_response(job, raw_request)


@router.post(
    "/{preview_job_id}/export",
    response_model=ReelRenderJobResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def export_reel_render_job(
    preview_job_id: str,
    request: ReelRenderExportRequest,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    preview_job = await _load_owned_job_or_404(preview_job_id, current_user)
    if preview_job.get("render_mode") != "preview":
        raise HTTPException(status_code=400, detail="Export requires a preview job")
    preview_job = await _sync_job_from_worker(preview_job)
    if preview_job.get("status") != "completed":
        raise HTTPException(status_code=400, detail="Preview job must be completed")

    jobs = await job_store.list_by_type(JOB_TYPE, limit=500)
    for candidate in jobs:
        if (
            candidate.get("parent_preview_job_id") == preview_job_id
            and candidate.get("render_mode") == "final"
            and candidate.get("status") in ACTIVE_STATUSES.union({"completed"})
        ):
            return _to_job_response(candidate, raw_request)

    _enforce_capacity(current_user=current_user, jobs=jobs)

    input_props = preview_job.get("input_props")
    if not isinstance(input_props, dict):
        raise HTTPException(status_code=400, detail="Preview job props are unavailable")
    if _json_size_bytes(input_props) > MAX_PROPS_BYTES:
        raise HTTPException(status_code=400, detail="Render props exceed 64KB limit")

    job_id = str(uuid.uuid4())
    try:
        expected_artifact = build_expected_artifact(job_id, "final")
    except RenderArtifactError as exc:
        raise HTTPException(status_code=503, detail="Render storage unavailable") from exc
    await job_store.upsert(
        job_id=job_id,
        job_type=JOB_TYPE,
        status="queued",
        progress=0,
        message="Queued",
        user_id=current_user.user_id,
        content_id=preview_job["content_id"],
        project_id=preview_job["project_id"],
        template_id=preview_job["template_id"],
        render_mode="final",
        duration_seconds=int(preview_job.get("duration_seconds") or 60),
        client_request_id=request.client_request_id,
        parent_preview_job_id=preview_job_id,
        artifact=expected_artifact,
        input_props=input_props,
    )

    try:
        client = get_remotion_render_client()
        worker_payload = await client.create_render(
            {
                "jobId": job_id,
                "renderMode": "final",
                "durationSeconds": int(preview_job.get("duration_seconds") or 60),
                "templateId": preview_job["template_id"],
                "compositionId": "ReelFromContent",
                "inputProps": input_props,
            }
        )
    except RemotionRenderUnavailableError as exc:
        await job_store.update(
            job_id,
            status="failed",
            progress=0,
            message="Render worker unavailable",
        )
        raise HTTPException(status_code=503, detail="Render worker unavailable") from exc
    except RemotionRenderResponseError as exc:
        await job_store.update(
            job_id,
            status="failed",
            progress=0,
            message=str(exc),
        )
        raise HTTPException(status_code=502, detail="Render worker rejected request") from exc

    await job_store.update(
        job_id,
        status=_sanitize_worker_status(str(worker_payload.get("status", "queued"))),
        progress=int(worker_payload.get("progress") or 0),
        worker_job_id=str(worker_payload.get("workerJobId") or job_id),
        message=worker_payload.get("message") or "Queued",
    )
    job = await job_store.get(job_id)
    if not job:
        raise HTTPException(status_code=500, detail="Failed to persist render job")
    return _to_job_response(job, raw_request)


@router.delete("/{job_id}", response_model=ReelRenderCancelResponse)
async def cancel_reel_render_job(
    job_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    job = await _load_owned_job_or_404(job_id, current_user)
    if job.get("status") not in ACTIVE_STATUSES:
        raise HTTPException(status_code=400, detail="Job is not cancellable")

    try:
        client = get_remotion_render_client()
        worker_payload = await client.cancel_render(str(job.get("worker_job_id") or job_id))
    except RemotionRenderUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Render worker unavailable") from exc
    except RemotionRenderResponseError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    status_value = _sanitize_worker_status(str(worker_payload.get("status", "cancelled")))
    message = worker_payload.get("message") or "Cancelled"
    await job_store.update(job_id, status=status_value, message=message)
    refreshed = await job_store.get(job_id) or job
    return ReelRenderCancelResponse(
        job_id=job_id,
        status=refreshed.get("status", "cancelled"),
        message=refreshed.get("message"),
    )


@router.get("/{job_id}/artifact", name="get_reel_render_artifact")
async def get_reel_render_artifact(
    job_id: str,
    token: str = Query(..., min_length=1),
):
    job = await job_store.get(job_id)
    if not job or job.get("job_type") != JOB_TYPE:
        raise HTTPException(status_code=404, detail="Not found")
    artifact_path = job.get("artifact_path")
    render_mode = job.get("render_mode")
    if job.get("status") != "completed" or not isinstance(artifact_path, str) or not isinstance(render_mode, str):
        raise HTTPException(status_code=404, detail="Not found")
    if is_gcs_artifact(job.get("artifact")):
        raise HTTPException(status_code=404, detail="Not found")

    try:
        verify_artifact_token(
            token=token,
            job_id=job_id,
            render_mode=render_mode,
            artifact_path=artifact_path,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Artifact signing unavailable") from exc
    except RenderArtifactTokenError as exc:
        raise HTTPException(status_code=403, detail="Forbidden") from exc

    artifact_file = _resolve_safe_artifact_path(_render_root_dir(), artifact_path)
    if not artifact_file.exists() or artifact_file.stat().st_size <= 0:
        raise HTTPException(status_code=404, detail="Not found")

    return FileResponse(
        path=str(artifact_file),
        media_type=str(job.get("artifact_mime_type") or "video/mp4"),
        filename=str(job.get("artifact_file_name") or artifact_file.name),
    )
