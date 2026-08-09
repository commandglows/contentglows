"""Ahead-of-time branded video generation orchestration and feed readiness."""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException, status

from api.dependencies.auth import CurrentUser
from api.services.brand_profile_store import brand_profile_store
from api.services.brand_video_blueprint_store import brand_video_blueprint_store
from api.services.branded_video_assembly import assemble_branded_timeline_draft
from api.services.branded_video_generation_store import branded_video_generation_store
from api.services.remotion_timeline_props import TimelinePropsError, build_remotion_timeline_props
from api.services.user_data_store import user_data_store
from api.services.video_renderer_adapter import (
    VideoRenderDispatchResult,
    VideoRendererCapacityError,
    VideoRendererUnavailableError,
    get_video_renderer_adapter,
)
from api.services.video_timeline_store import (
    VideoTimelineConflictError,
    VideoTimelineNotFoundError,
    video_timeline_store,
)
from api.services.render_artifacts import (
    RenderArtifactError,
    build_expected_artifact,
    is_gcs_artifact,
)
from status.service import ContentNotFoundError, ProjectAssetEligibilityError


ACTIVE_RENDER_STATUSES = {"queued", "in_progress"}
RUN_IN_PROGRESS_STATUSES = {"queued", "preview_render", "final_render", "waiting_capacity"}
ELIGIBLE_VIDEO_CONTENT_TYPES = {"video_script", "reel", "short"}
READY_TO_PUBLISH = "ready_to_publish"
PREPARING = "preparing"
BLOCKED = "blocked"
FAILED = "failed"
RENDER_RETRY_AFTER_SECONDS = 60
PUBLISHABLE_PLATFORMS = {"twitter", "x", "linkedin", "instagram", "tiktok", "youtube"}
CLIP_ASSET_MEDIA_KINDS: dict[str, set[str]] = {
    "image": {"image", "thumbnail", "video_cover", "capture"},
    "video": {"video"},
    "audio": {"audio"},
    "music": {"music", "audio"},
    "background": {"background_config", "image", "thumbnail", "video_cover", "capture"},
}


@dataclass(slots=True)
class BrandedVideoFeedCandidate:
    content_id: str
    project_id: str
    brand_profile_id: str | None
    brand_template_id: str | None
    brand_template_revision: int | None
    format_preset: str
    readiness: str
    status: str
    blockers: list[str]
    blocker_code: str | None
    blocker_summary: str | None
    timeline_id: str | None
    version_id: str | None
    preview_job_id: str | None
    final_job_id: str | None
    updated_at: Any
    completed_at: Any


class BrandedVideoGenerationService:
    """Durable run orchestration over timeline/version/render primitives."""

    async def ensure_run(
        self,
        *,
        content_record: Any,
        current_user: CurrentUser,
        status_service: Any,
        format_preset: str = "vertical_9_16",
        trigger_source: str | None = None,
        brand_profile_id: str | None = None,
        blueprint_id: str | None = None,
    ) -> BrandedVideoFeedCandidate:
        run, _created = await branded_video_generation_store.create_or_get_run(
            user_id=current_user.user_id,
            project_id=content_record.project_id,
            content_id=content_record.id,
            format_preset=format_preset,
            trigger_source=trigger_source,
            brand_profile_id=brand_profile_id,
            blueprint_id=blueprint_id,
        )
        blueprint_revision: int | None = None
        try:
            if not self._is_eligible_video_content(content_record):
                return await self._set_run_state(
                    run=run,
                    current_user=current_user,
                    status="blocked",
                    readiness=BLOCKED,
                    blocker_code="video_content_required",
                    blocker_summary="Only video-compatible content can be prepared ahead of time.",
                    blockers=["video_content_required"],
                    brand_template_revision=blueprint_revision,
                )
            if not self._is_content_complete(content_record):
                return await self._set_run_state(
                    run=run,
                    current_user=current_user,
                    status="blocked",
                    readiness=BLOCKED,
                    blocker_code="content_completion_required",
                    blocker_summary="Complete the content body before preparing a branded video.",
                blockers=["content_completion_required"],
                brand_template_revision=blueprint_revision,
            )

            lock_existing_inputs = self._is_run_in_progress(run) and not _created and bool(run.get("blueprint_id"))

            if lock_existing_inputs:
                brand_profile, blueprint = await self._resolve_generation_inputs_for_in_progress_run(
                    run=run,
                    project_id=content_record.project_id,
                    current_user=current_user,
                )
            else:
                brand_profile, blueprint = await self._resolve_generation_inputs(
                    project_id=content_record.project_id,
                    current_user=current_user,
                    brand_profile_id=brand_profile_id,
                    blueprint_id=blueprint_id,
                )
                run = await branded_video_generation_store.update_run(
                    run_id=run["id"],
                    user_id=current_user.user_id,
                    brand_profile_id=brand_profile["id"],
                    blueprint_id=blueprint["id"],
                    trigger_source=trigger_source,
                )
            if isinstance(blueprint.get("revision"), int):
                blueprint_revision = int(blueprint["revision"])
            elif isinstance(blueprint.get("revision"), str) and str(blueprint["revision"]).isdigit():
                blueprint_revision = int(blueprint["revision"])

            project_assets = status_service.list_project_assets(
                project_id=content_record.project_id,
                user_id=current_user.user_id,
                limit=24,
                offset=0,
            )
            draft = assemble_branded_timeline_draft(
                content_record=content_record,
                brand_profile=brand_profile,
                blueprint=blueprint,
                project_assets=project_assets,
                format_preset=format_preset,
            )
            timeline = await self._create_or_refresh_timeline(
                current_user=current_user,
                content_record=content_record,
                draft=draft,
                format_preset=format_preset,
            )
            run = await branded_video_generation_store.update_run(
                run_id=run["id"],
                user_id=current_user.user_id,
                timeline_id=timeline["id"],
            )

            version = await self._create_or_refresh_version(
                run=run,
                timeline=timeline,
                draft=draft,
                current_user=current_user,
                status_service=status_service,
            )
            run = await branded_video_generation_store.update_run(
                run_id=run["id"],
                user_id=current_user.user_id,
                version_id=version["id"],
            )

            preview_job = await self._ensure_preview_job(
                run=run,
                timeline=timeline,
                version=version,
                current_user=current_user,
            )
            run = await branded_video_generation_store.update_run(
                run_id=run["id"],
                user_id=current_user.user_id,
                preview_job_id=preview_job["job_id"],
            )
            if preview_job["status"] in ACTIVE_RENDER_STATUSES:
                return await self._set_run_state(
                    run=run,
                    current_user=current_user,
                    status="preview_render",
                    readiness=PREPARING,
                    blocker_code=None,
                    blocker_summary=None,
                    blockers=[],
                    brand_template_revision=blueprint_revision,
                )
            if preview_job["status"] == "failed" or preview_job.get("stale"):
                return await self._set_run_state(
                    run=run,
                    current_user=current_user,
                    status="preview_failed",
                    readiness=FAILED,
                    blocker_code="preview_render_failed",
                    blocker_summary=preview_job.get("message") or "Preview render failed.",
                    blockers=["preview_render_failed"],
                    brand_template_revision=blueprint_revision,
                )

            if not version.get("approved_preview_job_id"):
                version = await video_timeline_store.approve_preview(
                    version_id=version["id"],
                    user_id=current_user.user_id,
                    preview_job_id=preview_job["job_id"],
                )

            final_job = await self._ensure_final_job(
                run=run,
                timeline=timeline,
                version=version,
                current_user=current_user,
            )
            run = await branded_video_generation_store.update_run(
                run_id=run["id"],
                user_id=current_user.user_id,
                final_job_id=final_job["job_id"],
            )
            if final_job["status"] in ACTIVE_RENDER_STATUSES:
                return await self._set_run_state(
                    run=run,
                    current_user=current_user,
                    status="final_render",
                    readiness=PREPARING,
                    blocker_code=None,
                    blocker_summary=None,
                    blockers=[],
                    brand_template_revision=blueprint_revision,
                )
            if final_job["status"] == "failed" or final_job.get("stale"):
                return await self._set_run_state(
                    run=run,
                    current_user=current_user,
                    status="final_failed",
                    readiness=FAILED,
                    blocker_code="final_render_failed",
                    blocker_summary=final_job.get("message") or "Final render failed.",
                    blockers=["final_render_failed"],
                    brand_template_revision=blueprint_revision,
                )

            ready, blockers, summary = await self._publish_prerequisites(
                content_record=content_record,
                current_user=current_user,
            )
            if not ready:
                return await self._set_run_state(
                    run=run,
                    current_user=current_user,
                    status="blocked",
                    readiness=BLOCKED,
                    blocker_code=blockers[0] if blockers else "publish_prerequisites_required",
                    blocker_summary=summary,
                    blockers=blockers or ["publish_prerequisites_required"],
                    brand_template_revision=blueprint_revision,
                )

            return await self._set_run_state(
                run=run,
                current_user=current_user,
                status="ready",
                readiness=READY_TO_PUBLISH,
                blocker_code=None,
                blocker_summary=None,
                blockers=[],
                brand_template_revision=blueprint_revision,
            )
        except HTTPException as exc:
            detail = exc.detail if isinstance(exc.detail, dict) else {"code": "generation_blocked", "message": str(exc.detail)}
            code = str(detail.get("code") or "generation_blocked")
            message = str(detail.get("message") or "Ahead-of-time generation blocked.")
            readiness = PREPARING if code == "render_capacity_waiting" else BLOCKED
            status_value = "waiting_capacity" if readiness == PREPARING else "blocked"
            return await self._set_run_state(
                run=run,
                current_user=current_user,
                status=status_value,
                readiness=readiness,
                blocker_code=code,
                blocker_summary=message if readiness == BLOCKED else None,
                blockers=[] if readiness == PREPARING else [code],
                last_error=message if readiness == BLOCKED else None,
                brand_template_revision=blueprint_revision,
            )
        except (
            ContentNotFoundError,
            ProjectAssetEligibilityError,
            TimelinePropsError,
            VideoTimelineConflictError,
            VideoTimelineNotFoundError,
            RuntimeError,
            RenderArtifactError,
        ) as exc:
            return await self._set_run_state(
                run=run,
                current_user=current_user,
                status="failed",
                readiness=FAILED,
                blocker_code="generation_failed",
                blocker_summary=str(exc),
                blockers=["generation_failed"],
                last_error=str(exc),
                brand_template_revision=blueprint_revision,
            )

    async def list_candidates(
        self,
        *,
        current_user: CurrentUser,
        project_id: str,
        content_ids: list[str] | None = None,
        limit: int = 50,
    ) -> list[BrandedVideoFeedCandidate]:
        runs = await branded_video_generation_store.list_by_project(
            user_id=current_user.user_id,
            project_id=project_id,
            content_ids=content_ids,
            limit=limit,
        )
        candidates: list[BrandedVideoFeedCandidate] = []
        for run in runs:
            candidates.append(
                await self._candidate_from_run(run, user_id=current_user.user_id)
            )
        return candidates

    async def _resolve_generation_inputs(
        self,
        *,
        project_id: str,
        current_user: CurrentUser,
        brand_profile_id: str | None,
        blueprint_id: str | None,
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        if brand_profile_id:
            brand_profile = await brand_profile_store.get_brand_profile(
                brand_profile_id=brand_profile_id,
                user_id=current_user.user_id,
            )
            if not brand_profile or brand_profile.get("project_id") != project_id:
                raise HTTPException(
                    status_code=404,
                    detail={"code": "brand_setup_required", "message": "Brand profile not found for this project."},
                )
        else:
            profiles = await brand_profile_store.list_brand_profiles(
                user_id=current_user.user_id,
                project_id=project_id,
            )
            brand_profile = next((profile for profile in profiles if profile.get("is_default")), profiles[0] if profiles else None)
            if not brand_profile:
                raise HTTPException(
                    status_code=409,
                    detail={"code": "brand_setup_required", "message": "Create a brand profile before preparing a branded video."},
                )

        if blueprint_id:
            blueprint = await brand_video_blueprint_store.get_brand_video_blueprint(
                blueprint_id=blueprint_id,
                user_id=current_user.user_id,
            )
            if not blueprint or blueprint.get("project_id") != project_id:
                raise HTTPException(
                    status_code=404,
                    detail={"code": "brand_blueprint_required", "message": "Brand video blueprint not found for this project."},
                )
        else:
            blueprints = await brand_video_blueprint_store.list_brand_video_blueprints(
                user_id=current_user.user_id,
                project_id=project_id,
                brand_profile_id=brand_profile["id"],
            )
            blueprint = next((entry for entry in blueprints if entry.get("status") == "active"), blueprints[0] if blueprints else None)
            if not blueprint:
                raise HTTPException(
                    status_code=409,
                    detail={"code": "brand_blueprint_required", "message": "Create a brand video blueprint before preparing a branded video."},
                )
        return brand_profile, blueprint

    async def _resolve_generation_inputs_for_in_progress_run(
        self,
        *,
        run: dict[str, Any],
        project_id: str,
        current_user: CurrentUser,
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        blueprint_id = run.get("blueprint_id")
        brand_profile_id = run.get("brand_profile_id")

        if not blueprint_id:
            return await self._resolve_generation_inputs(
                project_id=project_id,
                current_user=current_user,
                brand_profile_id=brand_profile_id,
                blueprint_id=None,
            )

        blueprint = await brand_video_blueprint_store.get_brand_video_blueprint(
            blueprint_id=blueprint_id,
            user_id=current_user.user_id,
        )
        if not blueprint or blueprint.get("project_id") != project_id:
            raise HTTPException(
                status_code=404,
                detail={
                    "code": "brand_blueprint_required",
                    "message": "Brand video blueprint used for this in-progress run is not available anymore.",
                },
            )
        if brand_profile_id and blueprint.get("brand_profile_id") and blueprint["brand_profile_id"] != brand_profile_id:
            raise HTTPException(
                status_code=409,
                detail={"code": "brand_setup_required", "message": "Brand profile changed for active in-progress run."},
            )

        if brand_profile_id:
            brand_profile = await brand_profile_store.get_brand_profile(
                brand_profile_id=brand_profile_id,
                user_id=current_user.user_id,
            )
            if not brand_profile or brand_profile.get("project_id") != project_id:
                raise HTTPException(
                    status_code=404,
                    detail={"code": "brand_setup_required", "message": "Brand profile used for this in-progress run is not available anymore."},
                )
        else:
            brand_profile = await brand_profile_store.get_brand_profile(
                brand_profile_id=blueprint.get("brand_profile_id"),
                user_id=current_user.user_id,
            )
            if not brand_profile or brand_profile.get("project_id") != project_id:
                raise HTTPException(
                    status_code=404,
                    detail={"code": "brand_setup_required", "message": "Brand profile used for this in-progress run is not available anymore."},
                )

        return brand_profile, blueprint

    def _is_run_in_progress(self, run: dict[str, Any]) -> bool:
        return run.get("status") in RUN_IN_PROGRESS_STATUSES

    async def _create_or_refresh_timeline(
        self,
        *,
        current_user: CurrentUser,
        content_record: Any,
        draft: dict[str, Any],
        format_preset: str,
    ) -> dict[str, Any]:
        timeline, created = await video_timeline_store.create_or_get_active(
            user_id=current_user.user_id,
            project_id=content_record.project_id,
            content_id=content_record.id,
            format_preset=format_preset,
            draft=draft,
        )
        if created or timeline["draft"] == draft:
            return timeline
        return await video_timeline_store.save_draft(
            timeline_id=timeline["id"],
            user_id=current_user.user_id,
            base_version_id=timeline.get("current_version_id"),
            draft_revision=int(timeline["draft_revision"]),
            timeline=draft,
        )

    async def _create_or_refresh_version(
        self,
        *,
        run: dict[str, Any],
        timeline: dict[str, Any],
        draft: dict[str, Any],
        current_user: CurrentUser,
        status_service: Any,
    ) -> dict[str, Any]:
        current_version_id = timeline.get("current_version_id")
        if run.get("version_id") and current_version_id == run["version_id"]:
            existing = await video_timeline_store.get_version(
                version_id=run["version_id"],
                user_id=current_user.user_id,
            )
            if existing.get("timeline") == draft:
                return existing
        render_assets = self._resolve_timeline_assets(
            timeline=draft,
            project_id=timeline["project_id"],
            user_id=current_user.user_id,
            status_service=status_service,
        )
        version_id = str(uuid.uuid4())
        props = build_remotion_timeline_props(
            timeline_id=timeline["id"],
            version_id=version_id,
            timeline=draft,
            assets=render_assets,
        )
        return await video_timeline_store.create_version(
            timeline_id=timeline["id"],
            user_id=current_user.user_id,
            version_id=version_id,
            base_version_id=timeline.get("current_version_id"),
            draft_revision=int(timeline["draft_revision"]),
            timeline=draft,
            renderer_props=props,
            client_request_id=f"{run['id']}:version:{timeline['draft_revision']}",
        )

    async def _ensure_preview_job(
        self,
        *,
        run: dict[str, Any],
        timeline: dict[str, Any],
        version: dict[str, Any],
        current_user: CurrentUser,
    ) -> dict[str, Any]:
        existing = await video_timeline_store.find_render_job(
            timeline_id=timeline["id"],
            version_id=version["id"],
            user_id=current_user.user_id,
            render_mode="preview",
            statuses=ACTIVE_RENDER_STATUSES.union({"completed", "failed"}),
        )
        if existing:
            return existing
        return await self._dispatch_render_job(
            timeline=timeline,
            version=version,
            render_mode="preview",
            current_user=current_user,
            client_request_id=f"{run['id']}:preview:{version['id']}",
        )

    async def _ensure_final_job(
        self,
        *,
        run: dict[str, Any],
        timeline: dict[str, Any],
        version: dict[str, Any],
        current_user: CurrentUser,
    ) -> dict[str, Any]:
        preview_job_id = version.get("approved_preview_job_id")
        existing = await video_timeline_store.find_render_job(
            timeline_id=timeline["id"],
            version_id=version["id"],
            user_id=current_user.user_id,
            render_mode="final",
            statuses=ACTIVE_RENDER_STATUSES.union({"completed", "failed"}),
            parent_preview_job_id=preview_job_id,
        )
        if existing:
            return existing
        return await self._dispatch_render_job(
            timeline=timeline,
            version=version,
            render_mode="final",
            current_user=current_user,
            client_request_id=f"{run['id']}:final:{version['id']}",
            parent_preview_job_id=preview_job_id,
        )

    async def _publish_prerequisites(
        self,
        *,
        content_record: Any,
        current_user: CurrentUser,
    ) -> tuple[bool, list[str], str | None]:
        platforms = self._content_publish_platforms(content_record)
        if not platforms:
            return False, ["publish_channel_required"], "Connect at least one publish channel before the feed can mark this video ready."
        try:
            accounts = await user_data_store.list_publish_accounts(
                current_user.user_id,
                content_record.project_id,
                provider="zernio",
            )
        except RuntimeError:
            return False, ["publish_accounts_unavailable"], "Publish account storage is unavailable."
        active_platforms = {str(account.get("platform") or "").lower() for account in accounts}
        missing = [platform for platform in platforms if platform not in active_platforms]
        if missing:
            return False, [f"publish_account_required:{platform}" for platform in missing], (
                "Connect an active publish account for: " + ", ".join(missing)
            )
        return True, [], None

    async def _dispatch_render_job(
        self,
        *,
        timeline: dict[str, Any],
        version: dict[str, Any],
        render_mode: str,
        current_user: CurrentUser,
        client_request_id: str | None,
        parent_preview_job_id: str | None = None,
    ) -> dict[str, Any]:
        await self._enforce_render_capacity(current_user)
        job_id = str(uuid.uuid4())
        expected_artifact = build_expected_artifact(job_id, render_mode)
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
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "render_capacity_waiting",
                    "message": "Render capacity is full. The run stays queued and can be resumed safely.",
                },
                headers={"Retry-After": str(RENDER_RETRY_AFTER_SECONDS)},
            ) from exc
        except VideoRendererUnavailableError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={"code": "worker_unavailable", "message": "Timeline renderer unavailable."},
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

    async def _enforce_render_capacity(self, current_user: CurrentUser) -> None:
        jobs = await video_timeline_store.list_active_render_jobs(limit=500)
        user_count = sum(1 for job in jobs if job["user_id"] == current_user.user_id)
        if user_count >= 1 or len(jobs) >= 3:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "render_capacity_waiting",
                    "message": "Render capacity is full. The run stays queued and can be resumed safely.",
                },
                headers={"Retry-After": str(RENDER_RETRY_AFTER_SECONDS)},
            )

    async def _set_run_state(
        self,
        *,
        run: dict[str, Any],
        current_user: CurrentUser,
        status: str,
        readiness: str,
        blocker_code: str | None,
        blocker_summary: str | None,
        blockers: list[str],
        last_error: str | None = None,
        brand_template_revision: int | None = None,
    ) -> BrandedVideoFeedCandidate:
        updated = await branded_video_generation_store.update_run(
            run_id=run["id"],
            user_id=current_user.user_id,
            status=status,
            readiness=readiness,
            blocker_code=blocker_code,
            blocker_summary=blocker_summary,
            blockers_json=json.dumps(blockers),
            completed_at=datetime.now(UTC).isoformat() if readiness == READY_TO_PUBLISH else None,
            last_error=last_error,
        )
        return await self._candidate_from_run(
            updated,
            user_id=current_user.user_id,
            brand_template_revision=brand_template_revision,
        )

    async def _candidate_from_run(
        self,
        run: dict[str, Any],
        *,
        user_id: str,
        brand_template_revision: int | None = None,
    ) -> BrandedVideoFeedCandidate:
        brand_template_id = run.get("blueprint_id")
        blueprint_revision: int | None = brand_template_revision
        if blueprint_revision is None and isinstance(brand_template_id, str) and brand_template_id:
            try:
                blueprint = await brand_video_blueprint_store.get_brand_video_blueprint(
                    blueprint_id=brand_template_id,
                    user_id=user_id,
                )
            except Exception:
                blueprint = None
            if blueprint:
                blueprint_value = blueprint.get("revision")
                if isinstance(blueprint_value, int):
                    blueprint_revision = blueprint_value
                elif isinstance(blueprint_value, str) and blueprint_value.isdigit():
                    blueprint_revision = int(blueprint_value)
        return BrandedVideoFeedCandidate(
            content_id=run["content_id"],
            project_id=run["project_id"],
            brand_profile_id=run.get("brand_profile_id"),
            brand_template_id=brand_template_id,
            brand_template_revision=blueprint_revision,
            format_preset=run["format_preset"],
            readiness=run["readiness"],
            status=run["status"],
            blockers=list(run.get("blockers") or []),
            blocker_code=run.get("blocker_code"),
            blocker_summary=run.get("blocker_summary"),
            timeline_id=run.get("timeline_id"),
            version_id=run.get("version_id"),
            preview_job_id=run.get("preview_job_id"),
            final_job_id=run.get("final_job_id"),
            updated_at=run.get("updated_at"),
            completed_at=run.get("completed_at"),
        )

    def _resolve_timeline_assets(
        self,
        *,
        timeline: dict[str, Any],
        project_id: str,
        user_id: str,
        status_service: Any,
    ) -> dict[str, dict[str, Any]]:
        from api.services.project_asset_storage import build_project_asset_storage_descriptor
        from urllib.parse import urlsplit, urlunsplit
        import os

        def bunny_host() -> str | None:
            configured = (os.getenv("BUNNY_CDN_HOSTNAME") or "").strip()
            if not configured:
                return None
            parsed = urlsplit(configured if "://" in configured else f"//{configured}")
            return (parsed.netloc or parsed.path).strip("/") or None

        def is_bunny_host(host: str) -> bool:
            lowered = host.lower()
            return lowered.endswith(".b-cdn.net") or lowered.endswith(".bunnycdn.com") or lowered == "storage.bunnycdn.com"

        assets: dict[str, dict[str, Any]] = {}
        for clip in timeline.get("clips", []):
            asset_id = clip.get("asset_id")
            if not asset_id:
                continue
            asset = status_service.get_project_asset_detail(
                project_id=project_id,
                user_id=user_id,
                asset_id=asset_id,
            )
            self._ensure_clip_asset_compatible(clip=clip, asset=asset)
            descriptor = build_project_asset_storage_descriptor(
                storage_uri=getattr(asset, "storage_uri", None),
                status=str(getattr(asset, "status", "") or ""),
                media_kind=str(getattr(asset, "media_kind", "") or ""),
                mime_type=getattr(asset, "mime_type", None),
            )
            if not descriptor["render_safe"]:
                raise ProjectAssetEligibilityError("Asset is not render-safe for video rendering")
            if descriptor["refresh_required"] and descriptor["state"] != "durable_bunny_http":
                raise ProjectAssetEligibilityError("Asset requires refresh before video rendering")
            storage_uri = getattr(asset, "storage_uri", None)
            if not isinstance(storage_uri, str) or not storage_uri.strip():
                raise ProjectAssetEligibilityError("Asset storage is missing")
            parsed = urlsplit(storage_uri.strip())
            scheme = parsed.scheme.lower()
            if scheme == "bunny":
                hostname = bunny_host()
                if not hostname or not parsed.path.lstrip("/"):
                    raise ProjectAssetEligibilityError("Bunny asset path is missing")
                render_url = f"https://{hostname}/{parsed.path.lstrip('/')}"
            elif scheme in {"http", "https"} and is_bunny_host(parsed.netloc):
                render_url = urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))
            else:
                raise ProjectAssetEligibilityError("Asset storage is not render-safe")
            assets[asset_id] = {
                "asset_id": asset_id,
                "media_kind": str(getattr(asset, "media_kind", "") or ""),
                "mime_type": getattr(asset, "mime_type", None),
                "file_name": getattr(asset, "file_name", None),
                "render_url": render_url,
            }
        return assets

    def _ensure_clip_asset_compatible(self, *, clip: dict[str, Any], asset: Any) -> None:
        clip_type = str(clip.get("clip_type") or "")
        media_kind = str(getattr(asset, "media_kind", "") or "")
        allowed = CLIP_ASSET_MEDIA_KINDS.get(clip_type)
        if allowed is None:
            if clip.get("asset_id"):
                raise ProjectAssetEligibilityError(f"Clip type '{clip_type}' cannot reference an asset")
            return
        if media_kind not in allowed:
            raise ProjectAssetEligibilityError(f"Incompatible media_kind '{media_kind}' for '{clip_type}' clip")

    def _content_publish_platforms(self, content_record: Any) -> list[str]:
        metadata = getattr(content_record, "metadata", {}) or {}
        raw_channels = metadata.get("channels") or metadata.get("publish_channels") or getattr(content_record, "tags", [])
        if not isinstance(raw_channels, list):
            return []
        normalized: list[str] = []
        for value in raw_channels:
            platform = str(value or "").strip().lower()
            if platform in PUBLISHABLE_PLATFORMS:
                normalized.append("twitter" if platform == "x" else platform)
        return list(dict.fromkeys(normalized))

    def _is_eligible_video_content(self, content_record: Any) -> bool:
        content_type = getattr(content_record, "content_type", "")
        normalized = str(getattr(content_type, "value", content_type) or "").strip().lower()
        return normalized in ELIGIBLE_VIDEO_CONTENT_TYPES

    def _is_content_complete(self, content_record: Any) -> bool:
        metadata = getattr(content_record, "metadata", {}) or {}
        return bool(metadata.get("content_complete") or metadata.get("content_complete_at"))


branded_video_generation_service = BrandedVideoGenerationService()
