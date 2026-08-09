from __future__ import annotations

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException, Response

from api.dependencies.auth import CurrentUser
from api.models.video_timeline import (
    BrandedVideoGenerateRequest,
    BrandedVideoFeedCandidateRequest,
    BrandedVideoTimelinePreviewRequest,
    BrandedVideoTimelineFromContentRequest,
    VideoTimelineDraftRequest,
    VideoTimelineFinalRenderRequest,
    VideoTimelineFromContentRequest,
    VideoTimelinePreviewApproveRequest,
    VideoTimelinePreviewRequest,
    VideoTimelineSwipePublishRequest,
    VideoTimelineVersionCreateRequest,
)
from api.routers import status as status_router
from api.routers import video_timelines as router
from api.services.branded_video_generation_store import BrandedVideoGenerationRunStore
from api.services.video_renderer_adapter import (
    UnavailableVideoRendererAdapter,
    VideoRenderDispatchResult,
    set_video_renderer_adapter_for_tests,
)
from api.services.video_timeline_store import VideoTimelineStore
from utils.libsql_async import create_client


class _FakeRenderer:
    def __init__(self, *, completed: bool = True):
        self.completed = completed

    async def request_render(self, *, job_id, render_mode, timeline_props, client_request_id=None):
        if not self.completed:
            return VideoRenderDispatchResult(
                job_id=job_id,
                status="queued",
                progress=0,
                message="Queued",
            )
        now = datetime.now(UTC)
        return VideoRenderDispatchResult(
            job_id=job_id,
            status="completed",
            progress=100,
            message="Completed",
            worker_job_id=job_id,
            artifact={
                "playback_url": f"https://api.example.test/artifact/{job_id}?token=redacted",
                "artifact_expires_at": (now + timedelta(hours=24)).isoformat(),
                "retention_expires_at": (now + timedelta(days=30)).isoformat(),
                "deletion_warning_at": (now + timedelta(days=27)).isoformat(),
                "byte_size": 123,
                "mime_type": "video/mp4",
                "file_name": f"{job_id}.mp4",
                "render_mode": render_mode,
            },
        )

    async def get_render_status(self, *, job_id):
        return VideoRenderDispatchResult(job_id=job_id, status="in_progress", progress=50)


class _FakeGcsRenderer:
    async def request_render(self, *, job_id, render_mode, timeline_props, client_request_id=None):
        return VideoRenderDispatchResult(
            job_id=job_id,
            status="queued",
            progress=0,
            message="Queued",
            worker_job_id=job_id,
        )

    async def get_render_status(self, *, job_id):
        return VideoRenderDispatchResult(
            job_id=job_id,
            status="completed",
            progress=100,
            message="Completed",
            worker_job_id=job_id,
            artifact={
                "provider": "gcs",
                "bucket": "private-render-bucket",
                "object_name": f"renders/previews/{job_id}.mp4",
                "artifact_path": f"renders/previews/{job_id}.mp4",
                "retention_expires_at": "2026-06-15T00:00:00+00:00",
                "deletion_warning_at": "2026-06-12T00:00:00+00:00",
                "byte_size": 456,
                "mime_type": "video/mp4",
                "file_name": f"{job_id}.mp4",
                "render_mode": "preview",
            },
        )


class _MismatchGcsRenderer:
    async def request_render(self, *, job_id, render_mode, timeline_props, client_request_id=None):
        return VideoRenderDispatchResult(
            job_id=job_id,
            status="completed",
            progress=100,
            message="Completed",
            worker_job_id=job_id,
            artifact={
                "provider": "gcs",
                "bucket": "private-render-bucket",
                "object_name": f"renders/previews/{job_id}-other.mp4",
                "artifact_path": f"renders/previews/{job_id}-other.mp4",
                "byte_size": 456,
                "mime_type": "video/mp4",
                "file_name": f"{job_id}-other.mp4",
                "render_mode": "preview",
            },
        )

    async def get_render_status(self, *, job_id):
        return VideoRenderDispatchResult(job_id=job_id, status="failed", progress=0)


@pytest.fixture
async def timeline_context(monkeypatch):
    from status import service as status_service_module
    from status import StatusService

    def _sqlite_conn(_db_path=None):
        import sqlite3

        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        return conn

    monkeypatch.setattr(status_service_module, "get_connection", _sqlite_conn)
    status_service = StatusService()
    store = VideoTimelineStore(db_client=create_client(url=":memory:"))
    generation_store = BrandedVideoGenerationRunStore(db_client=create_client(url=":memory:"))
    await store.ensure_tables()
    await generation_store.ensure_table()
    monkeypatch.setattr(router, "video_timeline_store", store)
    monkeypatch.setattr(router, "get_status_service", lambda: status_service)
    monkeypatch.setattr(
        "api.services.branded_video_generation_store.branded_video_generation_store",
        generation_store,
    )
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.branded_video_generation_store",
        generation_store,
    )
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.video_timeline_store",
        store,
    )
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(return_value=SimpleNamespace(id="content-1", title="Title", project_id="project-1")),
    )
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    set_video_renderer_adapter_for_tests(_FakeRenderer(completed=True))
    yield SimpleNamespace(
        store=store,
        generation_store=generation_store,
        status_service=status_service,
        user=CurrentUser(user_id="user-1", email="user@example.com", bearer_token="token"),
    )
    set_video_renderer_adapter_for_tests(None)


def _timeline_payload(text: str = "Visible title") -> dict:
    return {
        "schema_version": "1.0",
        "format_preset": "vertical_9_16",
        "fps": 30,
        "tracks": [{"id": "overlay", "type": "overlay", "order": 0, "exclusive": False}],
        "clips": [
            {
                "id": "title",
                "track_id": "overlay",
                "clip_type": "text",
                "start_frame": 0,
                "duration_frames": 120,
                "text": text,
            }
        ],
    }


def _asset_timeline_payload(asset_id: str, *, clip_type: str = "image") -> dict:
    track_type = "audio" if clip_type in {"audio", "music"} else "visual"
    return {
        "schema_version": "1.0",
        "format_preset": "vertical_9_16",
        "fps": 30,
        "tracks": [{"id": "main", "type": track_type, "order": 0, "exclusive": False}],
        "clips": [
            {
                "id": "clip-asset",
                "track_id": "main",
                "clip_type": clip_type,
                "start_frame": 0,
                "duration_frames": 120,
                "asset_id": asset_id,
            }
        ],
    }


def _create_project_asset(
    ctx,
    *,
    media_kind: str = "image",
    mime_type: str = "image/png",
    storage_uri: str = "https://contentglows-test.b-cdn.net/assets/image.png?token=secret",
):
    return ctx.status_service.create_project_asset(
        project_id="project-1",
        user_id="user-1",
        media_kind=media_kind,
        source="manual_upload",
        mime_type=mime_type,
        file_name="asset.png",
        storage_uri=storage_uri,
    )


async def _create_timeline(ctx):
    response = Response()
    timeline = await router.create_or_load_video_timeline_from_content(
        VideoTimelineFromContentRequest(content_id="content-1"),
        response,
        current_user=ctx.user,
    )
    assert response.status_code == 201
    return timeline


@pytest.mark.asyncio
async def test_video_timeline_router_create_version_preview_approve_and_final(timeline_context):
    ctx = timeline_context
    timeline = await _create_timeline(ctx)

    draft = await router.save_video_timeline_draft(
        timeline.timeline_id,
        VideoTimelineDraftRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload("Edited title"),
        ),
        current_user=ctx.user,
    )
    assert draft.draft_revision == 1

    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=1,
            timeline=_timeline_payload("Edited title"),
            client_request_id="save-1",
        ),
        current_user=ctx.user,
    )
    assert version.renderer_props["composition_id"] == "ContentGlowsTimelineVideo"

    preview = await router.request_video_timeline_preview(
        timeline.timeline_id,
        version.version_id,
        VideoTimelinePreviewRequest(client_request_id="preview-1"),
        raw_request=None,
        current_user=ctx.user,
    )
    assert preview.status == "completed"
    assert preview.artifact is not None

    approved = await router.approve_video_timeline_preview(
        timeline.timeline_id,
        version.version_id,
        preview.job_id,
        VideoTimelinePreviewApproveRequest(approved=True),
        current_user=ctx.user,
    )
    assert approved.approved_preview_job_id == preview.job_id

    final = await router.request_video_timeline_final_render(
        timeline.timeline_id,
        version.version_id,
        VideoTimelineFinalRenderRequest(preview_job_id=preview.job_id, client_request_id="final-1"),
        raw_request=None,
        current_user=ctx.user,
    )
    assert final.render_mode == "final"


@pytest.mark.asyncio
async def test_video_timeline_swipe_publish_approves_preview_renders_final_and_calls_publish(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    timeline = await _create_timeline(ctx)
    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload("Edited title"),
            client_request_id="save-1",
        ),
        current_user=ctx.user,
    )
    preview = await router.request_video_timeline_preview(
        timeline.timeline_id,
        version.version_id,
        VideoTimelinePreviewRequest(client_request_id="preview-1"),
        raw_request=None,
        current_user=ctx.user,
    )

    async def _fake_publish(request, current_user):
        return SimpleNamespace(
            status="published",
            model_dump=lambda mode="json": {
                "success": True,
                "status": "published",
                "post_id": "post-video-1",
                "platform_urls": {"twitter": "https://x.example/post-video-1"},
                "platform_results": [],
                "error": None,
            },
        )

    monkeypatch.setattr(router, "publish_content", _fake_publish)

    result = await router.swipe_publish_video_timeline(
        timeline.timeline_id,
        version.version_id,
        VideoTimelineSwipePublishRequest(
            preview_job_id=preview.job_id,
            content="Launch faster with AI video",
            platforms=[{"platform": "twitter", "account_id": "local_acct_1"}],
            title="Launch faster",
            client_request_id="swipe-1",
        ),
        raw_request=None,
        current_user=ctx.user,
    )

    assert result.state == "published"
    assert result.final_job is not None
    assert result.final_job.render_mode == "final"
    assert result.final_job.status == "completed"
    assert result.publish_result is not None
    assert result.publish_result["post_id"] == "post-video-1"


@pytest.mark.asyncio
async def test_video_timeline_swipe_publish_returns_pending_when_final_not_ready(timeline_context, monkeypatch):
    ctx = timeline_context
    set_video_renderer_adapter_for_tests(_FakeRenderer(completed=False))
    timeline = await _create_timeline(ctx)
    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload("Edited title"),
            client_request_id="save-1",
        ),
        current_user=ctx.user,
    )
    preview = await router.request_video_timeline_preview(
        timeline.timeline_id,
        version.version_id,
        VideoTimelinePreviewRequest(client_request_id="preview-1"),
        raw_request=None,
        current_user=ctx.user,
    )
    completed_preview = await ctx.store.update_render_job(
        job_id=preview.job_id,
        user_id=ctx.user.user_id,
        status="completed",
        progress=100,
        message="Completed",
        artifact={
            "playback_url": "https://api.example.test/artifact/preview.mp4?token=redacted",
            "artifact_expires_at": datetime.now(UTC).isoformat(),
            "retention_expires_at": datetime.now(UTC).isoformat(),
            "deletion_warning_at": datetime.now(UTC).isoformat(),
            "byte_size": 123,
            "mime_type": "video/mp4",
            "file_name": "preview.mp4",
            "render_mode": "preview",
        },
    )
    assert completed_preview["status"] == "completed"

    async def _unexpected_publish(request, current_user):
        raise AssertionError("publish should not be called while final render is pending")

    monkeypatch.setattr(router, "publish_content", _unexpected_publish)
    result = await router.swipe_publish_video_timeline(
        timeline.timeline_id,
        version.version_id,
        VideoTimelineSwipePublishRequest(
            preview_job_id=preview.job_id,
            content="Launch faster with AI video",
            platforms=[{"platform": "twitter", "account_id": "local_acct_1"}],
            title="Launch faster",
            client_request_id="swipe-1",
        ),
        raw_request=None,
        current_user=ctx.user,
    )

    assert result.state == "final_pending"
    assert result.final_job is not None
    assert result.final_job.status == "queued"


@pytest.mark.asyncio
async def test_create_or_refresh_branded_video_timeline_draft_persists_canonical_draft(timeline_context, monkeypatch):
    ctx = timeline_context
    asset = _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_preview="A short summary that should appear inside the branded draft.",
            )
        ),
    )

    async def _brand_profile(*, brand_profile_id: str, user_id: str):
        assert brand_profile_id == "brand-1"
        assert user_id == "user-1"
        return {
            "id": "brand-1",
            "project_id": "project-1",
            "primary_colors": ["#FFFFFF", "#111111"],
            "secondary_colors": ["#FF4F00"],
            "font_heading": "Space Grotesk",
            "font_body": "Manrope",
            "motion_intensity": "medium",
            "transition_family": "swipe",
            "caption_style_defaults": {"textColor": "#FFFFFF"},
            "cta_defaults": {"primaryText": "Try it now"},
            "intro_module_enabled": True,
            "outro_module_enabled": True,
            "tone_keywords": ["clean"],
        }

    async def _blueprint(*, blueprint_id: str, user_id: str):
        assert blueprint_id == "blueprint-1"
        assert user_id == "user-1"
        return {
            "id": "blueprint-1",
            "project_id": "project-1",
            "brand_profile_id": "brand-1",
            "default_archetype": "ugc_ad",
            "scene_rules_json": {"sceneDurationFrames": 84},
            "cta_rules_json": {"durationFrames": 36},
        }

    monkeypatch.setattr(router.brand_profile_store, "get_brand_profile", _brand_profile)
    monkeypatch.setattr(router.brand_video_blueprint_store, "get_brand_video_blueprint", _blueprint)

    response = Response()
    timeline = await router.create_or_refresh_branded_video_timeline_draft(
        BrandedVideoTimelineFromContentRequest(
            contentId="content-1",
            brandProfileId="brand-1",
            blueprintId="blueprint-1",
        ),
        response,
        current_user=ctx.user,
    )

    assert response.status_code == 201
    assert timeline.draft_revision == 0
    assert any(clip.asset_id == asset.id for clip in timeline.draft.clips if clip.asset_id)
    assert any(clip.role == "hook_title" for clip in timeline.draft.clips)
    assert any(clip.role == "cta" for clip in timeline.draft.clips)


@pytest.mark.asyncio
async def test_create_branded_video_preview_generation_creates_version_and_preview(timeline_context, monkeypatch):
    ctx = timeline_context
    asset = _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_preview="A short summary that should appear inside the branded draft.",
            )
        ),
    )

    async def _brand_profile(*, brand_profile_id: str, user_id: str):
        return {
            "id": brand_profile_id,
            "project_id": "project-1",
            "primary_colors": ["#FFFFFF", "#111111"],
            "secondary_colors": ["#FF4F00"],
            "font_heading": "Space Grotesk",
            "font_body": "Manrope",
            "motion_intensity": "medium",
            "transition_family": "swipe",
            "caption_style_defaults": {"textColor": "#FFFFFF"},
            "cta_defaults": {"primaryText": "Try it now"},
            "intro_module_enabled": True,
            "outro_module_enabled": True,
            "tone_keywords": ["clean"],
        }

    async def _blueprint(*, blueprint_id: str, user_id: str):
        return {
            "id": blueprint_id,
            "project_id": "project-1",
            "brand_profile_id": "brand-1",
            "default_archetype": "ugc_ad",
            "scene_rules_json": {"sceneDurationFrames": 84},
            "cta_rules_json": {"durationFrames": 36},
            "revision": 7,
        }

    monkeypatch.setattr(router.brand_profile_store, "get_brand_profile", _brand_profile)
    monkeypatch.setattr(router.brand_video_blueprint_store, "get_brand_video_blueprint", _blueprint)

    response = Response()
    generation = await router.create_branded_video_preview_generation(
        BrandedVideoTimelinePreviewRequest(
            contentId="content-1",
            brandProfileId="brand-1",
            blueprintId="blueprint-1",
            clientRequestId="brand-run-1",
        ),
        response,
        raw_request=None,
        current_user=ctx.user,
    )

    assert response.status_code == 201
    assert generation.readiness == "preview_ready"
    assert generation.preview_job.status == "completed"
    assert generation.preview_job.artifact is not None
    assert generation.brand_template_id == "blueprint-1"
    assert generation.brand_template_revision == 7
    assert generation.brand_profile_id == "brand-1"
    assert generation.version.timeline_id == generation.timeline.timeline_id
    assert any(clip.asset_id == asset.id for clip in generation.timeline.draft.clips if clip.asset_id)


@pytest.mark.asyncio
async def test_create_branded_video_preview_generation_is_idempotent_per_client_request(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_preview="A short summary that should appear inside the branded draft.",
            )
        ),
    )

    async def _brand_profile(*, brand_profile_id: str, user_id: str):
        return {
            "id": brand_profile_id,
            "project_id": "project-1",
            "primary_colors": ["#FFFFFF", "#111111"],
            "secondary_colors": ["#FF4F00"],
            "font_heading": "Space Grotesk",
            "font_body": "Manrope",
            "motion_intensity": "medium",
            "transition_family": "swipe",
            "caption_style_defaults": {"textColor": "#FFFFFF"},
            "cta_defaults": {"primaryText": "Try it now"},
            "intro_module_enabled": True,
            "outro_module_enabled": True,
            "tone_keywords": ["clean"],
        }

    async def _blueprint(*, blueprint_id: str, user_id: str):
        return {
            "id": blueprint_id,
            "project_id": "project-1",
            "brand_profile_id": "brand-1",
            "default_archetype": "ugc_ad",
            "scene_rules_json": {"sceneDurationFrames": 84},
            "cta_rules_json": {"durationFrames": 36},
            "revision": 4,
        }

    monkeypatch.setattr(router.brand_profile_store, "get_brand_profile", _brand_profile)
    monkeypatch.setattr(router.brand_video_blueprint_store, "get_brand_video_blueprint", _blueprint)

    first = await router.create_branded_video_preview_generation(
        BrandedVideoTimelinePreviewRequest(
            contentId="content-1",
            brandProfileId="brand-1",
            blueprintId="blueprint-1",
            clientRequestId="brand-run-1",
        ),
        Response(),
        raw_request=None,
        current_user=ctx.user,
    )
    second = await router.create_branded_video_preview_generation(
        BrandedVideoTimelinePreviewRequest(
            contentId="content-1",
            brandProfileId="brand-1",
            blueprintId="blueprint-1",
            clientRequestId="brand-run-1",
        ),
        Response(),
        raw_request=None,
        current_user=ctx.user,
    )

    assert first.timeline.timeline_id == second.timeline.timeline_id
    assert first.version.version_id == second.version.version_id
    jobs = await ctx.store.list_render_jobs(
        timeline_id=first.timeline.timeline_id,
        version_id=first.version.version_id,
        user_id=ctx.user.user_id,
        render_mode="preview",
    )
    assert len(jobs) == 1


@pytest.mark.asyncio
async def test_generate_branded_video_from_content_uses_project_defaults(timeline_context, monkeypatch):
    ctx = timeline_context
    asset = _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_preview="A short summary that should appear inside the branded draft.",
            )
        ),
    )

    async def _list_brand_profiles(*, user_id: str, project_id: str):
        assert user_id == "user-1"
        assert project_id == "project-1"
        return [
            {
                "id": "brand-1",
                "project_id": "project-1",
                "is_default": True,
                "primary_colors": ["#FFFFFF", "#111111"],
                "secondary_colors": ["#FF4F00"],
                "font_heading": "Space Grotesk",
                "font_body": "Manrope",
                "motion_intensity": "medium",
                "transition_family": "swipe",
                "caption_style_defaults": {"textColor": "#FFFFFF"},
                "cta_defaults": {"primaryText": "Try it now"},
                "intro_module_enabled": True,
                "outro_module_enabled": True,
                "tone_keywords": ["clean"],
            }
        ]

    async def _list_brand_video_blueprints(*, user_id: str, project_id: str, brand_profile_id: str | None = None):
        assert user_id == "user-1"
        assert project_id == "project-1"
        assert brand_profile_id == "brand-1"
        return [
            {
                "id": "blueprint-1",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
                "revision": 4,
            }
        ]

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _list_brand_profiles)
    monkeypatch.setattr(
        router.brand_video_blueprint_store,
        "list_brand_video_blueprints",
        _list_brand_video_blueprints,
    )

    response = Response()
    generation = await router.generate_branded_video_from_content(
        BrandedVideoGenerateRequest(
            contentId="content-1",
            triggerSource="manual_create",
            clientRequestId="brand-run-defaults-1",
        ),
        response,
        raw_request=None,
        current_user=ctx.user,
    )

    assert response.status_code == 201
    assert generation.readiness == "preview_ready"
    assert generation.preview_job.status == "completed"
    assert generation.brand_template_id == "blueprint-1"
    assert generation.brand_template_revision == 4
    assert generation.brand_profile_id == "brand-1"
    assert generation.version.timeline_id == generation.timeline.timeline_id
    assert any(clip.asset_id == asset.id for clip in generation.timeline.draft.clips if clip.asset_id)


@pytest.mark.asyncio
async def test_generate_branded_video_from_content_requires_brand_setup_when_missing_defaults(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_preview="A short summary that should appear inside the branded draft.",
            )
        ),
    )

    async def _list_brand_profiles(*, user_id: str, project_id: str):
        assert user_id == "user-1"
        assert project_id == "project-1"
        return []

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _list_brand_profiles)

    with pytest.raises(HTTPException) as exc_info:
        await router.generate_branded_video_from_content(
            BrandedVideoGenerateRequest(contentId="content-1"),
            Response(),
            raw_request=None,
            current_user=ctx.user,
        )

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "brand_setup_required"


@pytest.mark.asyncio
async def test_refresh_branded_video_feed_candidates_returns_ready_to_publish_candidate(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_type="video_script",
                content_preview="A short summary.",
                tags=["youtube"],
                metadata={"content_complete_at": "2026-07-08T00:00:00+00:00"},
                user_id="user-1",
            )
        ),
    )

    async def _list_brand_profiles(*, user_id: str, project_id: str):
        return [
            {
                "id": "brand-1",
                "project_id": "project-1",
                "is_default": True,
                "primary_colors": ["#FFFFFF", "#111111"],
                "secondary_colors": ["#FF4F00"],
                "font_heading": "Space Grotesk",
                "font_body": "Manrope",
                "motion_intensity": "medium",
                "transition_family": "swipe",
                "caption_style_defaults": {"textColor": "#FFFFFF"},
                "cta_defaults": {"primaryText": "Try it now"},
                "intro_module_enabled": True,
                "outro_module_enabled": True,
                "tone_keywords": ["clean"],
            }
        ]

    async def _list_brand_video_blueprints(*, user_id: str, project_id: str, brand_profile_id: str | None = None):
        return [
            {
                "id": "blueprint-1",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
                "revision": 9,
            }
        ]

    async def _get_brand_video_blueprint(*, blueprint_id: str, user_id: str):
        if blueprint_id == "blueprint-1":
            return {
                "id": "blueprint-1",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "revision": 9,
            }
        return None

    async def _list_publish_accounts(user_id: str, project_id: str, *, provider: str = "zernio", include_inactive: bool = False):
        return [{"id": "acct-1", "platform": "youtube", "status": "active"}]

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _list_brand_profiles)
    monkeypatch.setattr(router.brand_video_blueprint_store, "list_brand_video_blueprints", _list_brand_video_blueprints)
    monkeypatch.setattr(router.brand_video_blueprint_store, "get_brand_video_blueprint", _get_brand_video_blueprint)
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.brand_video_blueprint_store.get_brand_video_blueprint",
        _get_brand_video_blueprint,
    )
    monkeypatch.setattr("api.services.branded_video_generation_service.user_data_store.list_publish_accounts", _list_publish_accounts)

    response = await router.refresh_branded_video_feed_candidates(
        BrandedVideoFeedCandidateRequest(
            projectId="project-1",
            contentIds=["content-1"],
            triggerSource="feed_refresh",
        ),
        current_user=ctx.user,
    )

    assert len(response.items) == 1
    candidate = response.items[0]
    assert candidate.content_id == "content-1"
    assert candidate.readiness == "ready_to_publish"
    assert candidate.timeline_id is not None
    assert candidate.version_id is not None
    assert candidate.final_job_id is not None
    assert candidate.brand_profile_id == "brand-1"
    assert candidate.brand_template_id == "blueprint-1"
    assert candidate.brand_template_revision == 9


@pytest.mark.asyncio
async def test_completed_content_branded_feed_preview_and_publish_share_one_canonical_run(
    timeline_context, monkeypatch
):
    """Prove the operator journey without calling an external publisher."""
    ctx = timeline_context
    _create_project_asset(ctx)
    content = ctx.status_service.create_content(
        title="Launch faster",
        content_type="video_script",
        source_robot="manual",
        status="approved",
        project_id="project-1",
        user_id="user-1",
        content_preview="A complete script ready for its branded video.",
        tags=["youtube"],
    )

    async def _owned_content(content_id, current_user, status_service):
        assert content_id == content.id
        assert current_user.user_id == "user-1"
        return status_service.get_content(content_id)

    monkeypatch.setattr(status_router, "get_status_service", lambda: ctx.status_service)
    monkeypatch.setattr(status_router, "require_owned_content_record", _owned_content)
    completed = await status_router.complete_content(content.id, current_user=ctx.user)
    assert completed.metadata["content_complete"] is True

    monkeypatch.setattr(router, "require_owned_content_record", _owned_content)

    async def _profiles(*, user_id: str, project_id: str):
        return [
            {
                "id": "brand-1",
                "project_id": project_id,
                "is_default": True,
                "primary_colors": ["#FFFFFF", "#111111"],
                "secondary_colors": ["#FF4F00"],
                "font_heading": "Space Grotesk",
                "font_body": "Manrope",
                "motion_intensity": "medium",
                "transition_family": "swipe",
                "caption_style_defaults": {"textColor": "#FFFFFF"},
                "cta_defaults": {"primaryText": "Try it now"},
                "intro_module_enabled": True,
                "outro_module_enabled": True,
                "tone_keywords": ["clean"],
            }
        ]

    async def _blueprints(*, user_id: str, project_id: str, brand_profile_id: str | None = None):
        return [
            {
                "id": "blueprint-1",
                "project_id": project_id,
                "brand_profile_id": brand_profile_id,
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
                "revision": 5,
            }
        ]

    async def _get_blueprint(*, blueprint_id: str, user_id: str):
        if blueprint_id == "blueprint-1":
            return {
                "id": "blueprint-1",
                "project_id": project_id,
                "brand_profile_id": "brand-1",
                "revision": 5,
            }
        return None

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _profiles)
    monkeypatch.setattr(router.brand_video_blueprint_store, "list_brand_video_blueprints", _blueprints)
    monkeypatch.setattr(router.brand_video_blueprint_store, "get_brand_video_blueprint", _get_blueprint)
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.brand_video_blueprint_store.get_brand_video_blueprint",
        _get_blueprint,
    )
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.user_data_store.list_publish_accounts",
        AsyncMock(return_value=[{"id": "acct-1", "platform": "youtube", "status": "active"}]),
    )

    candidates = await router.refresh_branded_video_feed_candidates(
        BrandedVideoFeedCandidateRequest(projectId="project-1", contentIds=[content.id]),
        current_user=ctx.user,
    )
    candidate = candidates.items[0]
    assert candidate.readiness == "ready_to_publish"
    assert candidate.timeline_id and candidate.version_id
    assert candidate.preview_job_id and candidate.final_job_id
    assert candidate.brand_profile_id == "brand-1"
    assert candidate.brand_template_id == "blueprint-1"
    assert candidate.brand_template_revision == 5

    version = await ctx.store.get_version(version_id=candidate.version_id, user_id=ctx.user.user_id)
    assert version["approved_preview_job_id"] == candidate.preview_job_id

    async def _fake_publish(request, current_user):
        assert request.content_record_id == content.id
        assert request.media[0].type == "video"
        return SimpleNamespace(
            status="published",
            model_dump=lambda mode="json": {"success": True, "status": "published", "post_id": "test-post-1"},
        )

    monkeypatch.setattr(router, "publish_content", _fake_publish)
    published = await router.swipe_publish_video_timeline(
        candidate.timeline_id,
        candidate.version_id,
        VideoTimelineSwipePublishRequest(
            preview_job_id=candidate.preview_job_id,
            content="Launch faster with AI video",
            platforms=[{"platform": "youtube", "account_id": "acct-1"}],
            title=content.title,
            client_request_id="single-journey-publish-1",
        ),
        raw_request=None,
        current_user=ctx.user,
    )
    assert published.state == "published"
    assert published.final_job is not None and published.final_job.status == "completed"
    assert published.publish_result["post_id"] == "test-post-1"


@pytest.mark.asyncio
async def test_refresh_branded_video_feed_candidates_keeps_existing_template_while_in_progress(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_type="video_script",
                content_preview="A short summary.",
                tags=["youtube"],
                metadata={"content_complete_at": "2026-07-08T00:00:00+00:00"},
                user_id="user-1",
            )
        ),
    )

    async def _list_brand_profiles(*, user_id: str, project_id: str):
        return [
            {
                "id": "brand-1",
                "project_id": "project-1",
                "is_default": True,
                "primary_colors": ["#FFFFFF"],
                "secondary_colors": ["#FF4F00"],
                "font_heading": "Space Grotesk",
                "font_body": "Manrope",
                "motion_intensity": "medium",
                "transition_family": "swipe",
                "caption_style_defaults": {"textColor": "#FFFFFF"},
                "cta_defaults": {"primaryText": "Try it now"},
                "intro_module_enabled": True,
                "outro_module_enabled": True,
                "tone_keywords": ["clean"],
            }
        ]

    blueprints_call_count = {"n": 0}

    async def _list_brand_video_blueprints(*, user_id: str, project_id: str, brand_profile_id: str | None = None):
        blueprints_call_count["n"] += 1
        if blueprints_call_count["n"] >= 2:
            return [
                {
                    "id": "blueprint-2",
                    "project_id": "project-1",
                    "brand_profile_id": "brand-1",
                    "status": "active",
                    "default_archetype": "ugc_ad",
                    "scene_rules_json": {"sceneDurationFrames": 84},
                    "cta_rules_json": {"durationFrames": 36},
                    "revision": 2,
                }
            ]
        return [
            {
                "id": "blueprint-1",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
                "revision": 1,
            }
        ]

    async def _brand_profile(*, brand_profile_id: str, user_id: str):
        assert brand_profile_id == "brand-1"
        return {
            "id": "brand-1",
            "project_id": "project-1",
            "is_default": True,
            "primary_colors": ["#FFFFFF"],
            "secondary_colors": ["#FF4F00"],
            "font_heading": "Space Grotesk",
            "font_body": "Manrope",
            "motion_intensity": "medium",
            "transition_family": "swipe",
            "caption_style_defaults": {"textColor": "#FFFFFF"},
            "cta_defaults": {"primaryText": "Try it now"},
            "intro_module_enabled": True,
            "outro_module_enabled": True,
            "tone_keywords": ["clean"],
        }

    async def _get_brand_video_blueprint(*, blueprint_id: str, user_id: str):
        if blueprint_id == "blueprint-1":
            return {
                "id": "blueprint-1",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
                "layout_rules_json": {},
                "motion_rules_json": {},
                "caption_rules_json": {},
                "audio_rules_json": {},
                "export_rules_json": {},
                "revision": 1,
            }
        if blueprint_id == "blueprint-2":
            return {
                "id": "blueprint-2",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
                "layout_rules_json": {},
                "motion_rules_json": {},
                "caption_rules_json": {},
                "audio_rules_json": {},
                "export_rules_json": {},
                "revision": 2,
            }
        return None

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _list_brand_profiles)
    monkeypatch.setattr(router.brand_profile_store, "get_brand_profile", _brand_profile)
    monkeypatch.setattr(router.brand_video_blueprint_store, "list_brand_video_blueprints", _list_brand_video_blueprints)
    monkeypatch.setattr(router.brand_video_blueprint_store, "get_brand_video_blueprint", _get_brand_video_blueprint)
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.brand_video_blueprint_store.get_brand_video_blueprint",
        _get_brand_video_blueprint,
    )

    set_video_renderer_adapter_for_tests(_FakeRenderer(completed=False))
    first = await router.refresh_branded_video_feed_candidates(
        BrandedVideoFeedCandidateRequest(
            projectId="project-1",
            contentIds=["content-1"],
            triggerSource="feed_refresh",
        ),
        current_user=ctx.user,
    )
    assert len(first.items) == 1
    first_item = first.items[0]
    assert first_item.status == "preview_render"
    assert first_item.brand_template_id == "blueprint-1"
    assert first_item.brand_template_revision == 1

    second = await router.refresh_branded_video_feed_candidates(
        BrandedVideoFeedCandidateRequest(
            projectId="project-1",
            contentIds=["content-1"],
            triggerSource="feed_refresh",
        ),
        current_user=ctx.user,
    )
    assert len(second.items) == 1
    second_item = second.items[0]
    assert second_item.status == "preview_render"
    assert second_item.brand_template_id == "blueprint-1"
    assert second_item.brand_template_revision == 1
    assert second_item.timeline_id == first_item.timeline_id
    assert second_item.version_id == first_item.version_id


@pytest.mark.asyncio
async def test_refresh_branded_video_feed_candidates_blocks_when_brand_setup_missing(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_type="video_script",
                content_preview="A short summary.",
                tags=["youtube"],
                metadata={"content_complete_at": "2026-07-08T00:00:00+00:00"},
                user_id="user-1",
            )
        ),
    )

    async def _list_brand_profiles(*, user_id: str, project_id: str):
        return []

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _list_brand_profiles)

    response = await router.refresh_branded_video_feed_candidates(
        BrandedVideoFeedCandidateRequest(projectId="project-1", contentIds=["content-1"]),
        current_user=ctx.user,
    )

    assert response.items[0].readiness == "blocked"
    assert response.items[0].blocker_code == "brand_setup_required"


@pytest.mark.asyncio
async def test_refresh_branded_video_feed_candidates_waits_under_render_capacity_pressure(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_type="video_script",
                content_preview="A short summary.",
                tags=["youtube"],
                metadata={"content_complete_at": "2026-07-08T00:00:00+00:00"},
                user_id="user-1",
            )
        ),
    )

    async def _list_brand_profiles(*, user_id: str, project_id: str):
        return [
            {
                "id": "brand-1",
                "project_id": "project-1",
                "is_default": True,
                "primary_colors": ["#FFFFFF"],
                "secondary_colors": ["#FF4F00"],
                "font_heading": "Space Grotesk",
                "font_body": "Manrope",
                "motion_intensity": "medium",
                "transition_family": "swipe",
                "caption_style_defaults": {"textColor": "#FFFFFF"},
                "cta_defaults": {"primaryText": "Try it now"},
                "intro_module_enabled": True,
                "outro_module_enabled": True,
                "tone_keywords": ["clean"],
            }
        ]

    async def _list_brand_video_blueprints(*, user_id: str, project_id: str, brand_profile_id: str | None = None):
        return [
            {
                "id": "blueprint-1",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
            }
        ]

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _list_brand_profiles)
    monkeypatch.setattr(router.brand_video_blueprint_store, "list_brand_video_blueprints", _list_brand_video_blueprints)
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.BrandedVideoGenerationService._enforce_render_capacity",
        AsyncMock(side_effect=HTTPException(status_code=429, detail={"code": "render_capacity_waiting", "message": "Render capacity is full. The run stays queued and can be resumed safely."})),
    )

    response = await router.refresh_branded_video_feed_candidates(
        BrandedVideoFeedCandidateRequest(projectId="project-1", contentIds=["content-1"]),
        current_user=ctx.user,
    )

    assert response.items[0].readiness == "preparing"
    assert response.items[0].status == "waiting_capacity"


@pytest.mark.asyncio
async def test_refresh_branded_video_feed_candidates_requires_publish_prerequisites(
    timeline_context, monkeypatch
):
    ctx = timeline_context
    _create_project_asset(ctx)
    monkeypatch.setattr(
        router,
        "require_owned_content_record",
        AsyncMock(
            return_value=SimpleNamespace(
                id="content-1",
                title="Launch faster",
                project_id="project-1",
                content_type="video_script",
                content_preview="A short summary.",
                tags=[],
                metadata={"content_complete_at": "2026-07-08T00:00:00+00:00"},
                user_id="user-1",
            )
        ),
    )

    async def _list_brand_profiles(*, user_id: str, project_id: str):
        return [
            {
                "id": "brand-1",
                "project_id": "project-1",
                "is_default": True,
                "primary_colors": ["#FFFFFF"],
                "secondary_colors": ["#FF4F00"],
                "font_heading": "Space Grotesk",
                "font_body": "Manrope",
                "motion_intensity": "medium",
                "transition_family": "swipe",
                "caption_style_defaults": {"textColor": "#FFFFFF"},
                "cta_defaults": {"primaryText": "Try it now"},
                "intro_module_enabled": True,
                "outro_module_enabled": True,
                "tone_keywords": ["clean"],
            }
        ]

    async def _list_brand_video_blueprints(*, user_id: str, project_id: str, brand_profile_id: str | None = None):
        return [
            {
                "id": "blueprint-1",
                "project_id": "project-1",
                "brand_profile_id": "brand-1",
                "status": "active",
                "default_archetype": "ugc_ad",
                "scene_rules_json": {"sceneDurationFrames": 84},
                "cta_rules_json": {"durationFrames": 36},
            }
        ]

    monkeypatch.setattr(router.brand_profile_store, "list_brand_profiles", _list_brand_profiles)
    monkeypatch.setattr(router.brand_video_blueprint_store, "list_brand_video_blueprints", _list_brand_video_blueprints)
    monkeypatch.setattr(
        "api.services.branded_video_generation_service.user_data_store.list_publish_accounts",
        AsyncMock(return_value=[]),
    )

    response = await router.refresh_branded_video_feed_candidates(
        BrandedVideoFeedCandidateRequest(projectId="project-1", contentIds=["content-1"]),
        current_user=ctx.user,
    )

    assert response.items[0].readiness == "blocked"
    assert response.items[0].blocker_code == "publish_channel_required"


@pytest.mark.asyncio
async def test_video_timeline_version_resolves_render_safe_assets_and_records_usages(timeline_context):
    ctx = timeline_context
    timeline = await _create_timeline(ctx)
    asset = _create_project_asset(ctx)

    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_asset_timeline_payload(asset.id),
            client_request_id="asset-save-1",
        ),
        current_user=ctx.user,
    )

    descriptor = version.renderer_props["assets"][asset.id]
    assert descriptor["render_url"] == "https://contentglows-test.b-cdn.net/assets/image.png"
    assert "storage_uri" not in descriptor

    usages = ctx.status_service.get_project_asset_usage(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )
    assert {(usage.target_id, usage.usage_action, usage.placement) for usage in usages} == {
        (version.version_id, "select_for_video_version", "clip-asset"),
        (version.version_id, "use_in_remotion_render", "clip-asset"),
    }

    await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_asset_timeline_payload(asset.id),
            client_request_id="asset-save-1",
        ),
        current_user=ctx.user,
    )
    assert len(
        ctx.status_service.get_project_asset_usage(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
        )
    ) == 2


@pytest.mark.asyncio
async def test_video_timeline_version_rejects_provider_temporary_asset_before_create(timeline_context):
    ctx = timeline_context
    timeline = await _create_timeline(ctx)
    asset = _create_project_asset(
        ctx,
        storage_uri="https://provider.example.com/tmp/image.png?token=secret",
    )

    with pytest.raises(HTTPException) as exc:
        await router.create_video_timeline_version(
            timeline.timeline_id,
            VideoTimelineVersionCreateRequest(
                base_version_id=None,
                draft_revision=0,
                timeline=_asset_timeline_payload(asset.id),
            ),
            current_user=ctx.user,
        )

    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "asset_not_eligible"
    persisted = await ctx.store.get_timeline(timeline_id=timeline.timeline_id, user_id=ctx.user.user_id)
    assert persisted["current_version_id"] is None


@pytest.mark.asyncio
async def test_video_timeline_router_returns_stable_conflict_error(timeline_context):
    ctx = timeline_context
    timeline = await _create_timeline(ctx)

    await router.save_video_timeline_draft(
        timeline.timeline_id,
        VideoTimelineDraftRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload("Edited title"),
        ),
        current_user=ctx.user,
    )

    with pytest.raises(HTTPException) as exc:
        await router.save_video_timeline_draft(
            timeline.timeline_id,
            VideoTimelineDraftRequest(
                base_version_id=None,
                draft_revision=0,
                timeline=_timeline_payload("Stale write"),
            ),
            current_user=ctx.user,
        )

    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "timeline_conflict"


@pytest.mark.asyncio
async def test_video_timeline_preview_fails_cleanly_without_renderer(timeline_context):
    ctx = timeline_context
    set_video_renderer_adapter_for_tests(UnavailableVideoRendererAdapter())
    timeline = await _create_timeline(ctx)
    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload(),
        ),
        current_user=ctx.user,
    )

    with pytest.raises(HTTPException) as exc:
        await router.request_video_timeline_preview(
            timeline.timeline_id,
            version.version_id,
            VideoTimelinePreviewRequest(),
            raw_request=None,
            current_user=ctx.user,
        )

    assert exc.value.status_code == 503
    assert exc.value.detail["code"] == "worker_unavailable"


@pytest.mark.asyncio
async def test_video_timeline_gcs_artifact_is_signed_by_backend(timeline_context, monkeypatch):
    ctx = timeline_context
    monkeypatch.setenv("CONTENTGLOWS_RENDER_STORAGE", "gcs")
    monkeypatch.setenv("GCS_RENDER_BUCKET", "private-render-bucket")
    monkeypatch.setenv("GCS_RENDER_PREFIX", "renders")
    signed_calls = []

    def _fake_sign(artifact):
        signed_calls.append(artifact)
        return (
            f"https://storage.googleapis.test/{artifact['bucket']}/{artifact['object_name']}?X-Goog-Signature=redacted",
            datetime(2026, 5, 14, tzinfo=UTC) + timedelta(hours=1),
        )

    monkeypatch.setattr(router, "signed_gcs_playback_url", _fake_sign)
    set_video_renderer_adapter_for_tests(_FakeGcsRenderer())
    timeline = await _create_timeline(ctx)
    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload(),
        ),
        current_user=ctx.user,
    )

    preview = await router.request_video_timeline_preview(
        timeline.timeline_id,
        version.version_id,
        VideoTimelinePreviewRequest(),
        raw_request=None,
        current_user=ctx.user,
    )
    assert preview.status == "queued"
    stored = await ctx.store.get_job(job_id=preview.job_id, user_id=ctx.user.user_id)
    assert stored["artifact"]["provider"] == "gcs"
    assert stored["artifact"]["object_name"] == f"renders/previews/{preview.job_id}.mp4"

    refreshed = await router.get_video_timeline_render_job(
        timeline.timeline_id,
        preview.job_id,
        raw_request=SimpleNamespace(
            url_for=lambda *args, **kwargs: "https://api.example.test/local-artifact"
        ),
        current_user=ctx.user,
    )

    assert refreshed.status == "completed"
    assert refreshed.artifact is not None
    assert refreshed.artifact.playback_url.startswith("https://storage.googleapis.test/")
    assert signed_calls[0]["provider"] == "gcs"


@pytest.mark.asyncio
async def test_video_timeline_persists_expected_gcs_artifact_before_dispatch(timeline_context, monkeypatch):
    ctx = timeline_context
    monkeypatch.setenv("CONTENTGLOWS_RENDER_STORAGE", "gcs")
    monkeypatch.setenv("GCS_RENDER_BUCKET", "private-render-bucket")
    monkeypatch.setenv("GCS_RENDER_PREFIX", "renders")
    timeline = await _create_timeline(ctx)
    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload(),
        ),
        current_user=ctx.user,
    )

    class _AssertingRenderer:
        async def request_render(self, *, job_id, render_mode, timeline_props, client_request_id=None):
            persisted = await ctx.store.get_job(job_id=job_id, user_id=ctx.user.user_id)
            assert persisted["artifact"]["provider"] == "gcs"
            assert persisted["artifact"]["object_name"] == f"renders/previews/{job_id}.mp4"
            return VideoRenderDispatchResult(
                job_id=job_id,
                status="queued",
                progress=0,
                message="Queued",
                worker_job_id=job_id,
            )

        async def get_render_status(self, *, job_id):
            return VideoRenderDispatchResult(job_id=job_id, status="queued", progress=0)

    set_video_renderer_adapter_for_tests(_AssertingRenderer())
    preview = await router.request_video_timeline_preview(
        timeline.timeline_id,
        version.version_id,
        VideoTimelinePreviewRequest(),
        raw_request=None,
        current_user=ctx.user,
    )

    assert preview.status == "queued"


@pytest.mark.asyncio
async def test_video_timeline_rejects_mismatched_gcs_artifact(timeline_context, monkeypatch):
    ctx = timeline_context
    monkeypatch.setenv("CONTENTGLOWS_RENDER_STORAGE", "gcs")
    monkeypatch.setenv("GCS_RENDER_BUCKET", "private-render-bucket")
    monkeypatch.setenv("GCS_RENDER_PREFIX", "renders")
    set_video_renderer_adapter_for_tests(_MismatchGcsRenderer())
    timeline = await _create_timeline(ctx)
    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload(),
        ),
        current_user=ctx.user,
    )

    preview = await router.request_video_timeline_preview(
        timeline.timeline_id,
        version.version_id,
        VideoTimelinePreviewRequest(),
        raw_request=None,
        current_user=ctx.user,
    )

    assert preview.status == "failed"
    assert preview.message == "render_artifact_unavailable"
    assert preview.artifact is None


@pytest.mark.asyncio
async def test_video_timeline_render_capacity_returns_429(timeline_context):
    ctx = timeline_context
    timeline = await _create_timeline(ctx)
    version = await router.create_video_timeline_version(
        timeline.timeline_id,
        VideoTimelineVersionCreateRequest(
            base_version_id=None,
            draft_revision=0,
            timeline=_timeline_payload(),
        ),
        current_user=ctx.user,
    )
    await ctx.store.create_render_job(
        job_id="active-final",
        timeline_id=timeline.timeline_id,
        version_id=version.version_id,
        user_id=ctx.user.user_id,
        project_id="project-1",
        render_mode="final",
        status="queued",
    )

    with pytest.raises(HTTPException) as exc:
        await router.request_video_timeline_preview(
            timeline.timeline_id,
            version.version_id,
            VideoTimelinePreviewRequest(),
            raw_request=None,
            current_user=ctx.user,
        )

    assert exc.value.status_code == 429
    assert exc.value.headers["Retry-After"] == "60"
    assert exc.value.detail["code"] == "render_capacity_exhausted"
