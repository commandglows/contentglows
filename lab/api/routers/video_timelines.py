"""Authenticated API for canonical ContentGlows video timelines."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import FileResponse

from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import require_owned_content_record, require_owned_project_id
from api.models.video_timeline import (
    BrandedVideoGenerateRequest,
    BrandedVideoFeedCandidateListResponse,
    BrandedVideoFeedCandidateRequest,
    BrandedVideoFeedCandidateResponse,
    BrandedVideoGenerationResponse,
    BrandedVideoTimelinePreviewRequest,
    BrandedVideoTimelineFromContentRequest,
    TimelineErrorDetail,
    VideoTimelineDraftRequest,
    VideoTimelineDraftResponse,
    VideoTimelineFinalRenderRequest,
    VideoTimelineFromContentRequest,
    VideoTimelinePreviewApproveRequest,
    VideoTimelinePreviewRequest,
    VideoTimelineSwipePublishRequest,
    VideoTimelineSwipePublishResponse,
    VideoTimelineRenderJobResponse,
    VideoTimelineResponse,
    VideoTimelineValidationResult,
    VideoTimelineVersionCreateRequest,
    VideoTimelineVersionResponse,
)
from api.services.branded_video_generation_service import branded_video_generation_service
from api.routers.publish import PublishMediaItem, PublishRequest, publish_content
from api.services.project_asset_storage import (
    ProjectAssetDeliveryError,
    build_project_asset_storage_descriptor,
    resolve_project_asset_delivery_url,
)
from api.services.brand_profile_store import brand_profile_store
from api.services.brand_video_blueprint_store import brand_video_blueprint_store
from api.services.branded_video_assembly import assemble_branded_timeline_draft
from api.services.remotion_timeline_props import TimelinePropsError, build_remotion_timeline_props
from api.services.video_renderer_adapter import (
    VideoRendererCapacityError,
    VideoRenderDispatchResult,
    VideoRendererUnavailableError,
    get_video_renderer_adapter,
)
from api.services.video_timeline_store import (
    VideoTimelineConflictError,
    VideoTimelineNotFoundError,
    video_timeline_store,
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
    signed_gcs_playback_url,
)
from status.service import ContentNotFoundError, ProjectAssetEligibilityError, get_status_service

router = APIRouter(prefix="/api/video-timelines", tags=["Video Timelines"])

ACTIVE_RENDER_STATUSES = {"queued", "in_progress"}
RENDER_RETRY_AFTER_SECONDS = 60
CLIP_ASSET_MEDIA_KINDS: dict[str, set[str]] = {
    "image": {"image", "thumbnail", "video_cover", "capture"},
    "video": {"video"},
    "audio": {"audio"},
    "music": {"music", "audio"},
    "background": {"background_config", "image", "thumbnail", "video_cover", "capture"},
}


def _render_root_dir() -> Path:
    import os

    configured = os.getenv("CONTENTGLOWS_RENDER_DIR")
    if configured:
        return Path(configured).resolve()
    return (Path.cwd() / "renders").resolve()


def _resolve_safe_artifact_path(root_dir: Path, artifact_path: str) -> Path:
    normalized = artifact_path.replace("\\", "/").strip()
    rel = PurePosixPath(normalized)
    if rel.is_absolute() or ".." in rel.parts:
        raise HTTPException(status_code=403, detail=_detail("forbidden", "Forbidden"))
    if rel.suffix.lower() != ".mp4":
        raise HTTPException(status_code=403, detail=_detail("forbidden", "Forbidden"))
    resolved = (root_dir / Path(*rel.parts)).resolve()
    if resolved != root_dir and root_dir not in resolved.parents:
        raise HTTPException(status_code=403, detail=_detail("forbidden", "Forbidden"))
    return resolved


def _as_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return datetime.now(UTC)
    return datetime.now(UTC)


def _detail(
    code: str,
    message: str,
    *,
    field: str | None = None,
    retry_after_seconds: int | None = None,
) -> dict[str, Any]:
    return TimelineErrorDetail(
        code=code,
        message=message,
        field=field,
        retry_after_seconds=retry_after_seconds,
    ).model_dump()


def _field_value(value: Any) -> Any:
    return getattr(value, "value", value)


def _resolve_project_asset_render_url(asset: Any) -> str:
    try:
        return resolve_project_asset_delivery_url(
            getattr(asset, "storage_uri", None),
            getattr(asset, "storage_locator", None),
        )
    except ProjectAssetDeliveryError as exc:
        raise ProjectAssetEligibilityError(str(exc)) from exc


def _ensure_clip_asset_compatible(*, clip: dict[str, Any], asset: Any) -> None:
    clip_type = str(clip.get("clip_type") or "")
    media_kind = str(_field_value(getattr(asset, "media_kind", "")) or "")
    allowed = CLIP_ASSET_MEDIA_KINDS.get(clip_type)
    if allowed is None:
        if clip.get("asset_id"):
            raise ProjectAssetEligibilityError(f"Clip type '{clip_type}' cannot reference an asset")
        return
    if media_kind not in allowed:
        raise ProjectAssetEligibilityError(
            f"Incompatible media_kind '{media_kind}' for '{clip_type}' clip"
        )
    if media_kind == "render_output" and not bool(getattr(asset, "metadata", {}).get("render_output_safe")):
        raise ProjectAssetEligibilityError("render_output assets require explicit render_output_safe metadata")


def _resolve_timeline_assets(
    *,
    timeline: dict[str, Any],
    project_id: str,
    user_id: str,
    status_service: Any,
) -> dict[str, dict[str, Any]]:
    assets: dict[str, dict[str, Any]] = {}
    for clip in timeline.get("clips", []):
        asset_id = clip.get("asset_id")
        if not asset_id:
            continue
        try:
            asset = status_service.get_project_asset_detail(
                project_id=project_id,
                user_id=user_id,
                asset_id=asset_id,
            )
            _ensure_clip_asset_compatible(clip=clip, asset=asset)
            descriptor = build_project_asset_storage_descriptor(
                storage_uri=getattr(asset, "storage_uri", None),
                status=str(_field_value(getattr(asset, "status", "")) or ""),
                media_kind=str(_field_value(getattr(asset, "media_kind", "")) or ""),
                mime_type=getattr(asset, "mime_type", None),
            )
            if not descriptor["render_safe"]:
                raise ProjectAssetEligibilityError("Asset is not render-safe for video rendering")
            if descriptor["refresh_required"] and descriptor["state"] != "durable_bunny_http":
                raise ProjectAssetEligibilityError("Asset requires refresh before video rendering")
            render_url = _resolve_project_asset_render_url(asset)
        except (ContentNotFoundError, ProjectAssetEligibilityError) as exc:
            raise HTTPException(
                status_code=400,
                detail=_detail("asset_not_eligible", str(exc), field=f"clips.{clip.get('id')}.asset_id"),
            ) from exc
        assets[asset_id] = {
            "asset_id": asset_id,
            "media_kind": str(_field_value(getattr(asset, "media_kind", "")) or ""),
            "mime_type": getattr(asset, "mime_type", None),
            "file_name": getattr(asset, "file_name", None),
            "render_url": render_url,
        }
    return assets


def _usage_already_recorded(
    *,
    status_service: Any,
    project_id: str,
    user_id: str,
    asset_id: str,
    target_id: str,
    usage_action: str,
    placement: str,
) -> bool:
    try:
        usages = status_service.get_project_asset_usage(
            project_id=project_id,
            user_id=user_id,
            asset_id=asset_id,
        )
    except (AttributeError, ContentNotFoundError):
        return False
    return any(
        usage.target_type == "video_version"
        and usage.target_id == target_id
        and usage.usage_action == usage_action
        and usage.placement == placement
        for usage in usages
    )


def _record_timeline_asset_usages(
    *,
    status_service: Any,
    timeline_record: dict[str, Any],
    version: dict[str, Any],
) -> None:
    clips = version.get("timeline", {}).get("clips", [])
    if not any(clip.get("asset_id") for clip in clips):
        return
    mirror_target = getattr(status_service, "ensure_video_version_usage_target", None)
    if callable(mirror_target):
        mirror_target(timeline=timeline_record, version=version)

    for clip in clips:
        asset_id = clip.get("asset_id")
        if not asset_id:
            continue
        placement = str(clip.get("id") or asset_id)
        for usage_action in ("select_for_video_version", "use_in_remotion_render"):
            if _usage_already_recorded(
                status_service=status_service,
                project_id=timeline_record["project_id"],
                user_id=timeline_record["user_id"],
                asset_id=asset_id,
                target_id=version["id"],
                usage_action=usage_action,
                placement=placement,
            ):
                continue
            status_service.select_project_asset(
                project_id=timeline_record["project_id"],
                user_id=timeline_record["user_id"],
                asset_id=asset_id,
                target_type="video_version",
                target_id=version["id"],
                usage_action=usage_action,
                placement=placement,
                metadata={
                    "timeline_id": timeline_record["id"],
                    "clip_id": placement,
                    "clip_type": clip.get("clip_type"),
                },
            )


def _raise(
    status_code: int,
    code: str,
    message: str,
    *,
    field: str | None = None,
    headers: dict[str, str] | None = None,
    retry_after_seconds: int | None = None,
) -> None:
    raise HTTPException(
        status_code=status_code,
        detail=_detail(
            code,
            message,
            field=field,
            retry_after_seconds=retry_after_seconds,
        ),
        headers=headers,
    )


def _initial_timeline(*, title: str, format_preset: str) -> dict[str, Any]:
    safe_title = (title or "Untitled video").strip()[:2_000] or "Untitled video"
    return {
        "schema_version": "1.0",
        "format_preset": format_preset,
        "fps": 30,
        "duration_frames": 150,
        "tracks": [
            {
                "id": "track-text",
                "type": "overlay",
                "order": 0,
                "exclusive": False,
                "muted": False,
                "locked": False,
            }
        ],
        "clips": [
            {
                "id": "clip-title",
                "track_id": "track-text",
                "clip_type": "text",
                "start_frame": 0,
                "duration_frames": 150,
                "text": safe_title,
                "role": "title",
                "style": {"align": "center"},
                "metadata": {},
            }
        ],
    }


async def _require_brand_profile_for_project(
    *,
    brand_profile_id: str,
    project_id: str,
    current_user: CurrentUser,
) -> dict[str, Any]:
    profile = await brand_profile_store.get_brand_profile(
        brand_profile_id=brand_profile_id,
        user_id=current_user.user_id,
    )
    if not profile:
        _raise(404, "brand_profile_not_found", "Brand profile not found")
    if profile["project_id"] != project_id:
        _raise(409, "brand_profile_project_mismatch", "Brand profile does not belong to this project")
    return profile


async def _require_blueprint_for_brand_profile(
    *,
    blueprint_id: str,
    project_id: str,
    brand_profile_id: str,
    current_user: CurrentUser,
) -> dict[str, Any]:
    blueprint = await brand_video_blueprint_store.get_brand_video_blueprint(
        blueprint_id=blueprint_id,
        user_id=current_user.user_id,
    )
    if not blueprint:
        _raise(404, "brand_blueprint_not_found", "Brand video blueprint not found")
    if blueprint["project_id"] != project_id:
        _raise(409, "brand_blueprint_project_mismatch", "Brand video blueprint does not belong to this project")
    if blueprint["brand_profile_id"] != brand_profile_id:
        _raise(409, "brand_blueprint_profile_mismatch", "Brand video blueprint does not match this brand profile")
    return blueprint


async def _require_timeline(timeline_id: str, current_user: CurrentUser) -> dict[str, Any]:
    try:
        timeline = await video_timeline_store.get_timeline(
            timeline_id=timeline_id,
            user_id=current_user.user_id,
        )
    except VideoTimelineNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail=_detail("not_found", "Timeline not found"),
        ) from exc
    await require_owned_project_id(timeline["project_id"], current_user)
    return timeline


async def _require_version(
    *,
    timeline_id: str,
    version_id: str,
    current_user: CurrentUser,
) -> dict[str, Any]:
    timeline = await _require_timeline(timeline_id, current_user)
    try:
        version = await video_timeline_store.get_version(
            version_id=version_id,
            user_id=current_user.user_id,
        )
    except VideoTimelineNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail=_detail("not_found", "Timeline version not found"),
        ) from exc
    if version["timeline_id"] != timeline["id"]:
        _raise(404, "not_found", "Timeline version not found")
    return version


def _version_response(version: dict[str, Any]) -> VideoTimelineVersionResponse:
    return VideoTimelineVersionResponse(
        version_id=version["id"],
        timeline_id=version["timeline_id"],
        version_number=int(version["version_number"]),
        timeline=version["timeline"],
        renderer_props=version.get("renderer_props") or {},
        approved_preview_job_id=version.get("approved_preview_job_id"),
        preview_approved_at=version.get("preview_approved_at"),
        created_at=version["created_at"],
    )


def _artifact_response_payload(
    job: dict[str, Any],
    request: Request | None,
) -> dict[str, Any] | None:
    artifact = job.get("artifact")
    if not isinstance(artifact, dict):
        return None
    if isinstance(artifact.get("playback_url"), str):
        return artifact
    artifact_path = artifact.get("artifact_path")
    if not isinstance(artifact_path, str) or not artifact_path:
        return None
    if job.get("status") != "completed" or request is None:
        return None
    if artifact.get("expected"):
        return None
    if is_gcs_artifact(artifact):
        try:
            playback_url, expires_at = signed_gcs_playback_url(artifact)
        except RenderArtifactError as exc:
            raise HTTPException(
                status_code=503,
                detail=_detail("internal_error", "Artifact signing unavailable"),
            ) from exc
        return {
            "playback_url": playback_url,
            "artifact_expires_at": expires_at,
            "retention_expires_at": _as_datetime(artifact.get("retention_expires_at")),
            "deletion_warning_at": _as_datetime(artifact.get("deletion_warning_at")),
            "byte_size": int(artifact.get("byte_size") or 0),
            "mime_type": str(artifact.get("mime_type") or "video/mp4"),
            "file_name": str(artifact.get("file_name") or f"{job['job_id']}.mp4"),
            "render_mode": job["render_mode"],
        }
    try:
        token, expires_at = issue_artifact_token(
            job_id=job["job_id"],
            render_mode=job["render_mode"],
            artifact_path=artifact_path,
            timeline_id=job["timeline_id"],
            version_id=job["version_id"],
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=_detail("internal_error", "Artifact signing unavailable"),
        ) from exc
    base_url = str(
        request.url_for(
            "get_video_timeline_artifact",
            timeline_id=job["timeline_id"],
            job_id=job["job_id"],
        )
    )
    return {
        "playback_url": f"{base_url}?token={token}",
        "artifact_expires_at": expires_at,
        "retention_expires_at": _as_datetime(artifact.get("retention_expires_at")),
        "deletion_warning_at": _as_datetime(artifact.get("deletion_warning_at")),
        "byte_size": int(artifact.get("byte_size") or 0),
        "mime_type": str(artifact.get("mime_type") or "video/mp4"),
        "file_name": str(artifact.get("file_name") or f"{job['job_id']}.mp4"),
        "render_mode": job["render_mode"],
    }


def _job_response(job: dict[str, Any], request: Request | None = None) -> VideoTimelineRenderJobResponse:
    return VideoTimelineRenderJobResponse(
        job_id=job["job_id"],
        timeline_id=job["timeline_id"],
        version_id=job["version_id"],
        render_mode=job["render_mode"],
        status=job["status"],
        progress=int(job.get("progress") or 0),
        message=job.get("message"),
        artifact=_artifact_response_payload(job, request),
        stale=bool(job.get("stale")),
        created_at=job["created_at"],
        updated_at=job["updated_at"],
    )


def _feed_candidate_response(candidate: Any) -> BrandedVideoFeedCandidateResponse:
    return BrandedVideoFeedCandidateResponse(
        content_id=candidate.content_id,
        project_id=candidate.project_id,
        brand_profile_id=candidate.brand_profile_id,
        brand_template_id=candidate.brand_template_id,
        brand_template_revision=candidate.brand_template_revision,
        format_preset=candidate.format_preset,
        readiness=candidate.readiness,
        status=candidate.status,
        blockers=list(candidate.blockers),
        blocker_code=candidate.blocker_code,
        blocker_summary=candidate.blocker_summary,
        timeline_id=candidate.timeline_id,
        version_id=candidate.version_id,
        preview_job_id=candidate.preview_job_id,
        final_job_id=candidate.final_job_id,
        updated_at=_as_datetime(candidate.updated_at),
        completed_at=_as_datetime(candidate.completed_at) if candidate.completed_at else None,
    )


def _branded_generation_readiness(
    preview_job: VideoTimelineRenderJobResponse,
) -> tuple[str, list[str]]:
    if preview_job.status == "completed" and preview_job.artifact is not None and not preview_job.stale:
        return "preview_ready", []
    if preview_job.status in {"queued", "in_progress"}:
        return "preview_pending", []
    blocker = preview_job.message or "preview_render_unavailable"
    return "blocked", [blocker]


async def _resolve_default_brand_profile_for_project(
    *,
    project_id: str,
    current_user: CurrentUser,
) -> dict[str, Any]:
    profiles = await brand_profile_store.list_brand_profiles(
        user_id=current_user.user_id,
        project_id=project_id,
    )
    for profile in profiles:
        if profile.get("is_default"):
            return profile
    if profiles:
        return profiles[0]
    _raise(409, "brand_setup_required", "Create a brand profile before generating a branded video")


async def _resolve_default_blueprint_for_brand_profile(
    *,
    project_id: str,
    brand_profile_id: str,
    current_user: CurrentUser,
) -> dict[str, Any]:
    blueprints = await brand_video_blueprint_store.list_brand_video_blueprints(
        user_id=current_user.user_id,
        project_id=project_id,
        brand_profile_id=brand_profile_id,
    )
    for blueprint in blueprints:
        if blueprint.get("status") == "active":
            return blueprint
    if blueprints:
        return blueprints[0]
    _raise(409, "brand_blueprint_required", "Create a brand video blueprint before generating a branded video")


async def _resolve_branded_generation_inputs(
    *,
    project_id: str,
    current_user: CurrentUser,
    brand_profile_id: str | None,
    blueprint_id: str | None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    if brand_profile_id:
        brand_profile = await _require_brand_profile_for_project(
            brand_profile_id=brand_profile_id,
            project_id=project_id,
            current_user=current_user,
        )
    else:
        brand_profile = await _resolve_default_brand_profile_for_project(
            project_id=project_id,
            current_user=current_user,
        )

    if blueprint_id:
        blueprint = await _require_blueprint_for_brand_profile(
            blueprint_id=blueprint_id,
            project_id=project_id,
            brand_profile_id=brand_profile["id"],
            current_user=current_user,
        )
    else:
        blueprint = await _resolve_default_blueprint_for_brand_profile(
            project_id=project_id,
            brand_profile_id=brand_profile["id"],
            current_user=current_user,
        )
    return brand_profile, blueprint


def _publish_state_for_final_job(job: VideoTimelineRenderJobResponse) -> tuple[str, list[str]]:
    if job.status == "completed" and job.artifact is not None and not job.stale:
        return "published", []
    if job.status in {"queued", "in_progress"}:
        return "final_pending", []
    blocker = job.message or "final_render_unavailable"
    return "blocked", [blocker]


async def _latest_status(timeline: dict[str, Any], render_mode: str) -> str:
    version_id = timeline.get("current_version_id")
    if not version_id:
        return "missing"
    jobs = await video_timeline_store.list_render_jobs(
        timeline_id=timeline["id"],
        version_id=version_id,
        user_id=timeline["user_id"],
        render_mode=render_mode,
    )
    if not jobs:
        return "missing"
    latest = jobs[0]
    if latest.get("stale"):
        return "stale"
    return latest["status"]


async def _timeline_response(timeline: dict[str, Any]) -> VideoTimelineResponse:
    latest_version = None
    if timeline.get("current_version_id"):
        try:
            latest_version = await video_timeline_store.get_version(
                version_id=timeline["current_version_id"],
                user_id=timeline["user_id"],
            )
        except VideoTimelineNotFoundError:
            latest_version = None

    return VideoTimelineResponse(
        timeline_id=timeline["id"],
        content_id=timeline["content_id"],
        project_id=timeline["project_id"],
        user_id=timeline["user_id"],
        format_preset=timeline["format_preset"],
        current_version_id=timeline.get("current_version_id"),
        draft_revision=int(timeline["draft_revision"]),
        draft=timeline["draft"],
        latest_version=_version_response(latest_version) if latest_version else None,
        preview_status=await _latest_status(timeline, "preview"),
        final_status=await _latest_status(timeline, "final"),
        created_at=timeline["created_at"],
        updated_at=timeline["updated_at"],
    )


async def _enforce_render_capacity(current_user: CurrentUser) -> None:
    jobs = await video_timeline_store.list_active_render_jobs(limit=500)
    user_count = sum(1 for job in jobs if job["user_id"] == current_user.user_id)
    if user_count >= 1 or len(jobs) >= 3:
        _raise(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "render_capacity_exhausted",
            "Render capacity reached",
            headers={"Retry-After": str(RENDER_RETRY_AFTER_SECONDS)},
            retry_after_seconds=RENDER_RETRY_AFTER_SECONDS,
        )


async def _dispatch_render_job(
    *,
    timeline: dict[str, Any],
    version: dict[str, Any],
    render_mode: str,
    current_user: CurrentUser,
    client_request_id: str | None,
    parent_preview_job_id: str | None = None,
) -> dict[str, Any]:
    await _enforce_render_capacity(current_user)
    job_id = str(uuid.uuid4())
    try:
        expected_artifact = build_expected_artifact(job_id, render_mode)
    except RenderArtifactError as exc:
        raise HTTPException(
            status_code=503,
            detail=_detail("worker_unavailable", "Timeline renderer storage is not configured"),
        ) from exc
    job = await video_timeline_store.create_render_job(
        job_id=job_id,
        timeline_id=timeline["id"],
        version_id=version["id"],
        user_id=current_user.user_id,
        project_id=timeline["project_id"],
        render_mode=render_mode,
        status="queued",
        progress=0,
        message="Queued",
        artifact=expected_artifact,
        parent_preview_job_id=parent_preview_job_id,
        client_request_id=client_request_id,
    )
    adapter = get_video_renderer_adapter()
    try:
        result = await adapter.request_render(
            job_id=job_id,
            render_mode=render_mode,
            timeline_props=version["renderer_props"],
            client_request_id=client_request_id,
        )
    except VideoRendererCapacityError as exc:
        await video_timeline_store.update_render_job(
            job_id=job_id,
            user_id=current_user.user_id,
            status="failed",
            progress=0,
            message="Render capacity reached",
        )
        _raise(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "render_capacity_exhausted",
            "Render capacity reached",
            headers={"Retry-After": str(RENDER_RETRY_AFTER_SECONDS)},
            retry_after_seconds=RENDER_RETRY_AFTER_SECONDS,
        )
    except VideoRendererUnavailableError as exc:
        await video_timeline_store.update_render_job(
            job_id=job_id,
            user_id=current_user.user_id,
            status="failed",
            progress=0,
            message="Timeline renderer unavailable",
        )
        raise HTTPException(
            status_code=503,
            detail=_detail("worker_unavailable", "Timeline renderer unavailable"),
        ) from exc

    status_value = result.status
    message = result.message
    artifact = result.artifact or expected_artifact
    if result.artifact and expected_artifact and is_gcs_artifact(result.artifact):
        expected_object = expected_artifact.get("object_name") or expected_artifact.get("artifact_path")
        actual_object = result.artifact.get("object_name") or result.artifact.get("artifact_path")
        if (
            result.artifact.get("bucket") != expected_artifact.get("bucket")
            or actual_object != expected_object
            or result.artifact.get("render_mode") != render_mode
        ):
            result = VideoRenderDispatchResult(
                job_id=result.job_id,
                status="failed",
                progress=0,
                message="render_artifact_unavailable",
                worker_job_id=result.worker_job_id,
                artifact=None,
            )
            status_value = result.status
            message = result.message
            artifact = expected_artifact
    if result.status == "completed" and result.artifact is None and expected_artifact:
        status_value = "failed"
        message = "render_artifact_unavailable"

    if result.job_id != job_id:
        status_value = "failed"
        message = "Timeline renderer returned mismatched job id"
        artifact = expected_artifact

    return await video_timeline_store.update_render_job(
        job_id=job["job_id"],
        user_id=current_user.user_id,
        status=status_value,
        progress=result.progress,
        message=message,
        artifact=artifact,
        worker_job_id=result.worker_job_id,
    )


@router.post("/from-content", response_model=VideoTimelineResponse)
async def create_or_load_video_timeline_from_content(
    request: VideoTimelineFromContentRequest,
    response: Response,
    current_user: CurrentUser = Depends(require_current_user),
):
    status_service = get_status_service()
    owned_record = await require_owned_content_record(
        content_id=request.content_id,
        current_user=current_user,
        status_service=status_service,
    )
    draft = _initial_timeline(title=owned_record.title, format_preset=request.format_preset)
    try:
        timeline, created = await video_timeline_store.create_or_get_active(
            user_id=current_user.user_id,
            project_id=owned_record.project_id,
            content_id=request.content_id,
            format_preset=request.format_preset,
            draft=draft,
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=_detail("internal_error", "Video timeline store unavailable"),
        ) from exc
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    return await _timeline_response(timeline)


@router.post("/from-content/branded-draft", response_model=VideoTimelineResponse)
async def create_or_refresh_branded_video_timeline_draft(
    request: BrandedVideoTimelineFromContentRequest,
    response: Response,
    current_user: CurrentUser = Depends(require_current_user),
):
    status_service = get_status_service()
    owned_record = await require_owned_content_record(
        content_id=request.content_id,
        current_user=current_user,
        status_service=status_service,
    )
    brand_profile = await _require_brand_profile_for_project(
        brand_profile_id=request.brand_profile_id,
        project_id=owned_record.project_id,
        current_user=current_user,
    )
    blueprint = await _require_blueprint_for_brand_profile(
        blueprint_id=request.blueprint_id,
        project_id=owned_record.project_id,
        brand_profile_id=brand_profile["id"],
        current_user=current_user,
    )
    project_assets = status_service.list_project_assets(
        project_id=owned_record.project_id,
        user_id=current_user.user_id,
        limit=24,
        offset=0,
    )
    branded_draft = assemble_branded_timeline_draft(
        content_record=owned_record,
        brand_profile=brand_profile,
        blueprint=blueprint,
        project_assets=project_assets,
        format_preset=request.format_preset,
    )
    try:
        timeline, created = await video_timeline_store.create_or_get_active(
            user_id=current_user.user_id,
            project_id=owned_record.project_id,
            content_id=request.content_id,
            format_preset=request.format_preset,
            draft=branded_draft,
        )
        if not created:
            timeline = await video_timeline_store.save_draft(
                timeline_id=timeline["id"],
                user_id=current_user.user_id,
                base_version_id=timeline.get("current_version_id"),
                draft_revision=int(timeline["draft_revision"]),
                timeline=branded_draft,
            )
    except VideoTimelineConflictError as exc:
        raise HTTPException(
            status_code=409,
            detail=_detail("timeline_conflict", str(exc), field="draft_revision"),
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=_detail("internal_error", "Video timeline store unavailable"),
        ) from exc
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    return await _timeline_response(timeline)


async def _generate_branded_video_preview(
    *,
    content_id: str,
    brand_profile_id: str | None,
    blueprint_id: str | None,
    format_preset: str,
    client_request_id: str | None,
    response: Response,
    raw_request: Request | None,
    current_user: CurrentUser,
) -> BrandedVideoGenerationResponse:
    status_service = get_status_service()
    owned_record = await require_owned_content_record(
        content_id=content_id,
        current_user=current_user,
        status_service=status_service,
    )
    brand_profile, blueprint = await _resolve_branded_generation_inputs(
        project_id=owned_record.project_id,
        current_user=current_user,
        brand_profile_id=brand_profile_id,
        blueprint_id=blueprint_id,
    )
    project_assets = status_service.list_project_assets(
        project_id=owned_record.project_id,
        user_id=current_user.user_id,
        limit=24,
        offset=0,
    )
    branded_draft = assemble_branded_timeline_draft(
        content_record=owned_record,
        brand_profile=brand_profile,
        blueprint=blueprint,
        project_assets=project_assets,
        format_preset=format_preset,
    )
    try:
        timeline, created = await video_timeline_store.create_or_get_active(
            user_id=current_user.user_id,
            project_id=owned_record.project_id,
            content_id=content_id,
            format_preset=format_preset,
            draft=branded_draft,
        )
        if not created:
            timeline = await video_timeline_store.save_draft(
                timeline_id=timeline["id"],
                user_id=current_user.user_id,
                base_version_id=timeline.get("current_version_id"),
                draft_revision=int(timeline["draft_revision"]),
                timeline=branded_draft,
            )
        render_assets = _resolve_timeline_assets(
            timeline=branded_draft,
            project_id=timeline["project_id"],
            user_id=current_user.user_id,
            status_service=status_service,
        )
        version_id = str(uuid.uuid4())
        props = build_remotion_timeline_props(
            timeline_id=timeline["id"],
            version_id=version_id,
            timeline=branded_draft,
            assets=render_assets,
        )
        version = await video_timeline_store.create_version(
            timeline_id=timeline["id"],
            user_id=current_user.user_id,
            version_id=version_id,
            base_version_id=timeline.get("current_version_id"),
            draft_revision=int(timeline["draft_revision"]),
            timeline=branded_draft,
            renderer_props=props,
            client_request_id=client_request_id,
        )
    except TimelinePropsError as exc:
        raise HTTPException(
            status_code=400,
            detail=_detail("invalid_timeline", str(exc), field="timeline"),
        ) from exc
    except (ContentNotFoundError, ProjectAssetEligibilityError) as exc:
        raise HTTPException(
            status_code=400,
            detail=_detail("asset_not_eligible", str(exc), field="timeline.clips"),
        ) from exc
    except VideoTimelineConflictError as exc:
        raise HTTPException(
            status_code=409,
            detail=_detail("timeline_conflict", str(exc), field="draft_revision"),
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=_detail("internal_error", "Video timeline store unavailable"),
        ) from exc

    try:
        _record_timeline_asset_usages(
            status_service=status_service,
            timeline_record=timeline,
            version=version,
        )
    except (ContentNotFoundError, ProjectAssetEligibilityError) as exc:
        raise HTTPException(
            status_code=400,
            detail=_detail("asset_not_eligible", str(exc), field="timeline.clips"),
        ) from exc

    existing = await video_timeline_store.find_render_job(
        timeline_id=timeline["id"],
        version_id=version["id"],
        user_id=current_user.user_id,
        render_mode="preview",
        statuses=ACTIVE_RENDER_STATUSES.union({"completed"}),
    )
    if existing:
        preview_job = _job_response(existing, raw_request)
    else:
        job = await _dispatch_render_job(
            timeline=await video_timeline_store.get_timeline(
                timeline_id=timeline["id"],
                user_id=current_user.user_id,
            ),
            version=version,
            render_mode="preview",
            current_user=current_user,
            client_request_id=client_request_id,
        )
        preview_job = _job_response(job, raw_request)

    readiness, blockers = _branded_generation_readiness(preview_job)
    blueprint_revision: int | None = None
    blueprint_value = blueprint.get("revision")
    if isinstance(blueprint_value, int):
        blueprint_revision = blueprint_value
    elif isinstance(blueprint_value, str) and blueprint_value.isdigit():
        blueprint_revision = int(blueprint_value)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    return BrandedVideoGenerationResponse(
        brand_profile_id=brand_profile["id"],
        brand_template_id=blueprint.get("id"),
        brand_template_revision=blueprint_revision,
        timeline=await _timeline_response(
            await video_timeline_store.get_timeline(
                timeline_id=timeline["id"],
                user_id=current_user.user_id,
            )
        ),
        version=_version_response(version),
        preview_job=preview_job,
        readiness=readiness,
        blockers=blockers,
    )


@router.post("/from-content/branded-preview", response_model=BrandedVideoGenerationResponse)
async def create_branded_video_preview_generation(
    request: BrandedVideoTimelinePreviewRequest,
    response: Response,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    return await _generate_branded_video_preview(
        content_id=request.content_id,
        brand_profile_id=request.brand_profile_id,
        blueprint_id=request.blueprint_id,
        format_preset=request.format_preset,
        client_request_id=request.client_request_id,
        response=response,
        raw_request=raw_request,
        current_user=current_user,
    )


@router.post("/from-content/branded-generate", response_model=BrandedVideoGenerationResponse)
async def generate_branded_video_from_content(
    request: BrandedVideoGenerateRequest,
    response: Response,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    return await _generate_branded_video_preview(
        content_id=request.content_id,
        brand_profile_id=request.brand_profile_id,
        blueprint_id=request.blueprint_id,
        format_preset=request.format_preset,
        client_request_id=request.client_request_id,
        response=response,
        raw_request=raw_request,
        current_user=current_user,
    )


@router.post("/feed-candidates/refresh", response_model=BrandedVideoFeedCandidateListResponse)
async def refresh_branded_video_feed_candidates(
    request: BrandedVideoFeedCandidateRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(request.project_id, current_user)
    status_service = get_status_service()
    requested_ids = request.content_ids
    if requested_ids:
        owned_records = [
            await require_owned_content_record(
                content_id=content_id,
                current_user=current_user,
                status_service=status_service,
            )
            for content_id in requested_ids[: request.limit]
        ]
    else:
        owned_records = [
            record
            for record in status_service.list_content(
                project_ids=[request.project_id],
                limit=request.limit,
                offset=0,
            )
            if record.user_id == current_user.user_id
        ]
    candidates = []
    for record in owned_records:
        candidate = await branded_video_generation_service.ensure_run(
            content_record=record,
            current_user=current_user,
            status_service=status_service,
            format_preset=request.format_preset,
            trigger_source=request.trigger_source or "feed_refresh",
        )
        metadata = dict(getattr(record, "metadata", {}) or {})
        metadata.update(
            {
                "video_generation_state": candidate.status,
                "video_generation_readiness": candidate.readiness,
                "video_generation_blockers": list(candidate.blockers),
                "video_generation_blocker_code": candidate.blocker_code,
                "video_generation_blocker_summary": candidate.blocker_summary,
                "video_generation_timeline_id": candidate.timeline_id,
                "video_generation_version_id": candidate.version_id,
                "video_generation_preview_job_id": candidate.preview_job_id,
                "video_generation_final_job_id": candidate.final_job_id,
                "video_generation_brand_profile_id": candidate.brand_profile_id,
                "video_generation_brand_template_id": candidate.brand_template_id,
                "video_generation_brand_template_revision": candidate.brand_template_revision,
                "video_generation_updated_at": _as_datetime(candidate.updated_at).isoformat(),
                "video_generation_ready_at": _as_datetime(candidate.completed_at).isoformat()
                if candidate.completed_at
                else None,
            }
        )
        try:
            status_service.update_content(record.id, metadata=metadata)
        except ContentNotFoundError:
            pass
        candidates.append(_feed_candidate_response(candidate))
    return BrandedVideoFeedCandidateListResponse(items=candidates)


@router.get("/feed-candidates", response_model=BrandedVideoFeedCandidateListResponse)
async def list_branded_video_feed_candidates(
    project_id: str = Query(..., min_length=1),
    format_preset: str = Query("vertical_9_16"),
    limit: int = Query(20, ge=1, le=100),
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    candidates = await branded_video_generation_service.list_candidates(
        current_user=current_user,
        project_id=project_id,
        limit=limit,
    )
    filtered = [candidate for candidate in candidates if candidate.format_preset == format_preset]
    return BrandedVideoFeedCandidateListResponse(
        items=[_feed_candidate_response(candidate) for candidate in filtered]
    )


@router.get("/{timeline_id}", response_model=VideoTimelineResponse)
async def get_video_timeline(
    timeline_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    timeline = await _require_timeline(timeline_id, current_user)
    return await _timeline_response(timeline)


@router.patch("/{timeline_id}/draft", response_model=VideoTimelineDraftResponse)
async def save_video_timeline_draft(
    timeline_id: str,
    request: VideoTimelineDraftRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await _require_timeline(timeline_id, current_user)
    try:
        timeline = await video_timeline_store.save_draft(
            timeline_id=timeline_id,
            user_id=current_user.user_id,
            base_version_id=request.base_version_id,
            draft_revision=request.draft_revision,
            timeline=request.timeline.model_dump(mode="json"),
        )
    except VideoTimelineConflictError as exc:
        raise HTTPException(
            status_code=409,
            detail=_detail("timeline_conflict", str(exc), field="draft_revision"),
        ) from exc
    return VideoTimelineDraftResponse(
        timeline_id=timeline["id"],
        draft_revision=int(timeline["draft_revision"]),
        latest_version_id=timeline.get("current_version_id"),
        timeline=timeline["draft"],
        validation=VideoTimelineValidationResult(valid=True),
        preview_status=await _latest_status(timeline, "preview"),
    )


@router.post("/{timeline_id}/versions", response_model=VideoTimelineVersionResponse, status_code=201)
async def create_video_timeline_version(
    timeline_id: str,
    request: VideoTimelineVersionCreateRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    timeline = await _require_timeline(timeline_id, current_user)
    status_service = get_status_service()
    version_id = str(uuid.uuid4())
    timeline_payload = request.timeline.model_dump(mode="json")
    try:
        render_assets = _resolve_timeline_assets(
            timeline=timeline_payload,
            project_id=timeline["project_id"],
            user_id=current_user.user_id,
            status_service=status_service,
        )
        props = build_remotion_timeline_props(
            timeline_id=timeline_id,
            version_id=version_id,
            timeline=timeline_payload,
            assets=render_assets,
        )
        version = await video_timeline_store.create_version(
            timeline_id=timeline_id,
            user_id=current_user.user_id,
            version_id=version_id,
            base_version_id=request.base_version_id,
            draft_revision=request.draft_revision,
            timeline=timeline_payload,
            renderer_props=props,
            client_request_id=request.client_request_id,
        )
    except TimelinePropsError as exc:
        raise HTTPException(
            status_code=400,
            detail=_detail("invalid_timeline", str(exc), field="timeline"),
        ) from exc
    except VideoTimelineConflictError as exc:
        raise HTTPException(
            status_code=409,
            detail=_detail("timeline_conflict", str(exc), field="base_version_id"),
        ) from exc
    if version["timeline_id"] != timeline["id"]:
        _raise(404, "not_found", "Timeline version not found")
    try:
        _record_timeline_asset_usages(
            status_service=status_service,
            timeline_record=timeline,
            version=version,
        )
    except (ContentNotFoundError, ProjectAssetEligibilityError) as exc:
        raise HTTPException(
            status_code=400,
            detail=_detail("asset_not_eligible", str(exc), field="timeline.clips"),
        ) from exc
    return _version_response(version)


@router.post(
    "/{timeline_id}/versions/{version_id}/preview",
    response_model=VideoTimelineRenderJobResponse,
    status_code=202,
)
async def request_video_timeline_preview(
    timeline_id: str,
    version_id: str,
    request: VideoTimelinePreviewRequest,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    timeline = await _require_timeline(timeline_id, current_user)
    version = await _require_version(
        timeline_id=timeline_id,
        version_id=version_id,
        current_user=current_user,
    )
    if timeline.get("current_version_id") != version_id:
        _raise(409, "preview_stale", "Preview requires the current timeline version")
    existing = await video_timeline_store.find_render_job(
        timeline_id=timeline_id,
        version_id=version_id,
        user_id=current_user.user_id,
        render_mode="preview",
        statuses=ACTIVE_RENDER_STATUSES.union({"completed"}),
    )
    if existing:
        return _job_response(existing, raw_request)
    job = await _dispatch_render_job(
        timeline=timeline,
        version=version,
        render_mode="preview",
        current_user=current_user,
        client_request_id=request.client_request_id,
    )
    return _job_response(job, raw_request)


@router.post(
    "/{timeline_id}/versions/{version_id}/preview/{preview_job_id}/approve",
    response_model=VideoTimelineVersionResponse,
)
async def approve_video_timeline_preview(
    timeline_id: str,
    version_id: str,
    preview_job_id: str,
    request: VideoTimelinePreviewApproveRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await _require_version(timeline_id=timeline_id, version_id=version_id, current_user=current_user)
    if not request.approved:
        _raise(400, "invalid_timeline", "Preview approval must be true", field="approved")
    try:
        version = await video_timeline_store.approve_preview(
            version_id=version_id,
            user_id=current_user.user_id,
            preview_job_id=preview_job_id,
        )
    except (VideoTimelineConflictError, VideoTimelineNotFoundError) as exc:
        raise HTTPException(
            status_code=409,
            detail=_detail("preview_stale", "Preview cannot be approved"),
        ) from exc
    if version["timeline_id"] != timeline_id:
        _raise(404, "not_found", "Timeline version not found")
    return _version_response(version)


@router.post(
    "/{timeline_id}/versions/{version_id}/render-final",
    response_model=VideoTimelineRenderJobResponse,
    status_code=202,
)
async def request_video_timeline_final_render(
    timeline_id: str,
    version_id: str,
    request: VideoTimelineFinalRenderRequest,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    timeline = await _require_timeline(timeline_id, current_user)
    version = await _require_version(
        timeline_id=timeline_id,
        version_id=version_id,
        current_user=current_user,
    )
    if timeline.get("current_version_id") != version_id:
        _raise(409, "preview_stale", "Final render requires the current timeline version")
    if version.get("approved_preview_job_id") != request.preview_job_id:
        _raise(409, "preview_stale", "Final render requires an approved preview")
    existing = await video_timeline_store.find_render_job(
        timeline_id=timeline_id,
        version_id=version_id,
        user_id=current_user.user_id,
        render_mode="final",
        statuses=ACTIVE_RENDER_STATUSES.union({"completed"}),
        parent_preview_job_id=request.preview_job_id,
    )
    if existing:
        return _job_response(existing, raw_request)
    job = await _dispatch_render_job(
        timeline=timeline,
        version=version,
        render_mode="final",
        current_user=current_user,
        client_request_id=request.client_request_id,
        parent_preview_job_id=request.preview_job_id,
    )
    return _job_response(job, raw_request)


@router.post(
    "/{timeline_id}/versions/{version_id}/swipe-publish",
    response_model=VideoTimelineSwipePublishResponse,
)
async def swipe_publish_video_timeline(
    timeline_id: str,
    version_id: str,
    request: VideoTimelineSwipePublishRequest,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    timeline = await _require_timeline(timeline_id, current_user)
    version = await _require_version(
        timeline_id=timeline_id,
        version_id=version_id,
        current_user=current_user,
    )
    if timeline.get("current_version_id") != version_id:
        _raise(409, "preview_stale", "Swipe publish requires the current timeline version")

    approved_preview_job_id = version.get("approved_preview_job_id")
    if not approved_preview_job_id:
        if not request.preview_job_id:
            _raise(409, "preview_stale", "Swipe publish requires an approved preview", field="preview_job_id")
        try:
            version = await video_timeline_store.approve_preview(
                version_id=version_id,
                user_id=current_user.user_id,
                preview_job_id=request.preview_job_id,
            )
        except (VideoTimelineConflictError, VideoTimelineNotFoundError) as exc:
            raise HTTPException(
                status_code=409,
                detail=_detail("preview_stale", "Preview cannot be approved"),
            ) from exc
        approved_preview_job_id = version.get("approved_preview_job_id")

    existing_final = await video_timeline_store.find_render_job(
        timeline_id=timeline_id,
        version_id=version_id,
        user_id=current_user.user_id,
        render_mode="final",
        statuses=ACTIVE_RENDER_STATUSES.union({"completed"}),
        parent_preview_job_id=approved_preview_job_id,
    )
    if existing_final:
        final_job = _job_response(existing_final, raw_request)
    else:
        dispatched = await _dispatch_render_job(
            timeline=timeline,
            version=version,
            render_mode="final",
            current_user=current_user,
            client_request_id=request.client_request_id,
            parent_preview_job_id=approved_preview_job_id,
        )
        final_job = _job_response(dispatched, raw_request)

    state, blockers = _publish_state_for_final_job(final_job)
    if state != "published":
        return VideoTimelineSwipePublishResponse(
            state=state,
            version=_version_response(version),
            final_job=final_job,
            publish_result=None,
            blockers=blockers,
        )

    artifact = final_job.artifact
    if artifact is None or not artifact.playback_url:
        return VideoTimelineSwipePublishResponse(
            state="blocked",
            version=_version_response(version),
            final_job=final_job,
            publish_result=None,
            blockers=["final_artifact_unavailable"],
        )

    publish_request = PublishRequest(
        content=request.content,
        platforms=[
            {
                "platform": target.platform,
                "account_id": target.account_id,
                "custom_content": target.custom_content,
            }
            for target in request.platforms
        ],
        title=request.title,
        media=[
            PublishMediaItem(
                type="video",
                url=artifact.playback_url,
            )
        ],
        scheduled_for=request.scheduled_for,
        publish_now=request.publish_now,
        tags=request.tags,
        content_record_id=timeline["content_id"],
    )
    publish_result = await publish_content(publish_request, current_user=current_user)
    state = "scheduled" if publish_result.status == "scheduled" else "published"
    return VideoTimelineSwipePublishResponse(
        state=state,
        version=_version_response(version),
        final_job=final_job,
        publish_result=publish_result.model_dump(mode="json"),
        blockers=[],
    )


@router.get("/{timeline_id}/jobs/{job_id}", response_model=VideoTimelineRenderJobResponse)
async def get_video_timeline_render_job(
    timeline_id: str,
    job_id: str,
    raw_request: Request,
    current_user: CurrentUser = Depends(require_current_user),
):
    await _require_timeline(timeline_id, current_user)
    try:
        job = await video_timeline_store.get_job(job_id=job_id, user_id=current_user.user_id)
    except VideoTimelineNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail=_detail("not_found", "Render job not found"),
        ) from exc
    if job["timeline_id"] != timeline_id:
        _raise(404, "not_found", "Render job not found")

    if job["status"] in ACTIVE_RENDER_STATUSES:
        adapter = get_video_renderer_adapter()
        try:
            result = await adapter.get_render_status(job_id=job_id)
        except VideoRendererUnavailableError:
            result = None
        if result:
            artifact = result.artifact
            status_value = result.status
            message = result.message
            artifact_mismatch = False
            if artifact and is_gcs_artifact(artifact) and is_gcs_artifact(job.get("artifact")):
                expected = job["artifact"]
                expected_object = expected.get("object_name") or expected.get("artifact_path")
                actual_object = artifact.get("object_name") or artifact.get("artifact_path")
                if (
                    artifact.get("bucket") != expected.get("bucket")
                    or actual_object != expected_object
                    or artifact.get("render_mode") != job.get("render_mode")
                ):
                    artifact = None
                    status_value = "failed"
                    message = "render_artifact_unavailable"
                    artifact_mismatch = True
            if (
                not artifact_mismatch
                and result.status == "completed"
                and artifact is None
                and is_gcs_artifact(job.get("artifact"))
            ):
                try:
                    artifact = gcs_object_metadata(job["artifact"])
                except RenderArtifactError:
                    artifact = None
                if artifact is None:
                    status_value = "failed"
                    message = "render_artifact_unavailable"
            job = await video_timeline_store.update_render_job(
                job_id=job_id,
                user_id=current_user.user_id,
                status=status_value,
                progress=result.progress,
                message=message,
                artifact=artifact or job.get("artifact"),
                worker_job_id=result.worker_job_id,
            )
    return _job_response(job, raw_request)


@router.get("/{timeline_id}/jobs/{job_id}/artifact", name="get_video_timeline_artifact")
async def get_video_timeline_artifact(
    timeline_id: str,
    job_id: str,
    token: str = Query(..., min_length=1),
):
    job = await video_timeline_store.get_job_for_signed_artifact(job_id=job_id)
    if not job or job.get("timeline_id") != timeline_id or job.get("status") != "completed":
        raise HTTPException(status_code=404, detail=_detail("not_found", "Not found"))

    artifact = job.get("artifact")
    artifact_path = artifact.get("artifact_path") if isinstance(artifact, dict) else None
    if not isinstance(artifact_path, str) or not artifact_path:
        raise HTTPException(status_code=404, detail=_detail("not_found", "Not found"))
    if is_gcs_artifact(artifact):
        raise HTTPException(status_code=404, detail=_detail("not_found", "Not found"))

    try:
        verify_artifact_token(
            token=token,
            job_id=job_id,
            render_mode=job["render_mode"],
            artifact_path=artifact_path,
            timeline_id=timeline_id,
            version_id=job["version_id"],
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=_detail("internal_error", "Artifact signing unavailable"),
        ) from exc
    except RenderArtifactTokenError as exc:
        raise HTTPException(status_code=403, detail=_detail("forbidden", "Forbidden")) from exc

    artifact_file = _resolve_safe_artifact_path(_render_root_dir(), artifact_path)
    if not artifact_file.exists() or artifact_file.stat().st_size <= 0:
        raise HTTPException(status_code=404, detail=_detail("not_found", "Not found"))
    return FileResponse(
        path=str(artifact_file),
        media_type=str(artifact.get("mime_type") or "video/mp4"),
        filename=str(artifact.get("file_name") or artifact_file.name),
    )
