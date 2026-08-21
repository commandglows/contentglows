from types import SimpleNamespace
from unittest.mock import AsyncMock
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from fastapi import BackgroundTasks, HTTPException

from api.dependencies.auth import CurrentUser
from api.models.images import GenerateImageFromProfileRequest, ImageReferenceCreateRequest
from api.models.ai_usage import (
    AIQuotaErrorCode,
    AIQuotaStatus,
    AIUsageAction,
    AIUsageBillingMode,
    AIUsageScope,
)
from api.services.ai_usage_service import AIUsageQuotaRejected
from api.routers import images as router


def _unvalidated_generate_request(**kwargs):
    if hasattr(GenerateImageFromProfileRequest, "model_construct"):
        return GenerateImageFromProfileRequest.model_construct(**kwargs)
    return GenerateImageFromProfileRequest.construct(**kwargs)


class _FakeImageGenerationStore:
    def __init__(self):
        self.create_calls = 0

    async def ensure_tables(self):
        return None

    async def list_references(self, **kwargs):
        return []

    async def create_generation(self, **kwargs):
        self.create_calls += 1
        return {
            "id": "generation-1",
            "project_id": kwargs["project_id"],
            "user_id": kwargs["user_id"],
            "profile_id": kwargs["profile_id"],
            "provider": "flux",
            "model": kwargs["model"],
            "status": "queued",
            "job_id": kwargs["job_id"],
            "reservation_id": kwargs["reservation_id"],
            "prompt": kwargs["prompt"],
            "prompt_hash": "hash",
            "width": kwargs["width"],
            "height": kwargs["height"],
            "seed": kwargs["seed"],
            "output_format": kwargs["output_format"],
            "cdn_url": None,
            "primary_url": None,
            "responsive_urls": {},
            "reference_ids": kwargs["reference_ids"],
            "visual_memory_applied": kwargs["visual_memory_applied"],
            "provider_cost": None,
            "provider_request_id": None,
            "error_code": None,
            "error_message": None,
            "asset_id": None,
            "provider_metadata": {},
            "created_at": "2026-05-12T00:00:00",
            "updated_at": "2026-05-12T00:00:00",
            "started_at": None,
            "completed_at": None,
        }


def _usage_runtime(*, reserve_side_effect=None):
    service = SimpleNamespace(
        reserve=AsyncMock(
            return_value=SimpleNamespace(reservation_id="reservation-1"),
            side_effect=reserve_side_effect,
        ),
        release=AsyncMock(),
        preflight=AsyncMock(
            return_value=SimpleNamespace(
                model_dump=lambda **kwargs: {
                    "allowed": True,
                    "unitRemaining": "7.5",
                }
            )
        ),
    )
    runtime = SimpleNamespace(
        service=service,
        policies=SimpleNamespace(
            resolve=lambda action: SimpleNamespace(
                provider="flux",
                model="flux-2-pro",
                estimated_units=Decimal("2.5"),
            )
        ),
        reservation_ttl_seconds=900,
    )
    return runtime


def _usage_provider(runtime):
    return AsyncMock(return_value=runtime)


@pytest.mark.asyncio
async def test_generate_from_flux_profile_queues_background_job(monkeypatch, tmp_path):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    generation_store = _FakeImageGenerationStore()
    monkeypatch.setattr(router, "image_generation_store", generation_store)
    monkeypatch.setattr(router, "_flux_api_key_configured", lambda: True)
    monkeypatch.setattr(router.job_store, "db_client", None)

    background_tasks = BackgroundTasks()
    response = await router.generate_image_from_profile(
        request=GenerateImageFromProfileRequest(
            project_id="project-1",
            profile_id="ai-blog-hero",
            title_text="Launch story",
            use_visual_memory=True,
        ),
        background_tasks=background_tasks,
        crew=SimpleNamespace(data_dir=tmp_path),
        current_user=CurrentUser(user_id="user-1", bearer_token="token"),
        ai_usage_provider=_usage_provider(_usage_runtime()),
    )

    assert response.success is True
    assert response.provider_used == "flux"
    assert response.status == "queued"
    assert response.generation_id == "generation-1"
    assert response.model == "flux-2-pro"
    assert response.reservation_id == "reservation-1"
    assert response.quota_status["allowed"] is True
    assert generation_store.create_calls == 1
    assert len(background_tasks.tasks) == 1


@pytest.mark.asyncio
async def test_flux_quota_block_creates_no_generation_or_provider_task(monkeypatch, tmp_path):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    generation_store = _FakeImageGenerationStore()
    monkeypatch.setattr(router, "image_generation_store", generation_store)
    monkeypatch.setattr(router, "_flux_api_key_configured", lambda: True)
    status = AIQuotaStatus(
        scope=AIUsageScope(user_id="user-1", project_id="project-1"),
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        billing_mode=AIUsageBillingMode.MANAGED,
        allowed=False,
        unit_limit=Decimal("10"),
        unit_reserved=Decimal("2"),
        unit_consumed=Decimal("8"),
        unit_remaining=Decimal("0"),
        required_units=Decimal("2.5"),
        reason_code=AIQuotaErrorCode.EXHAUSTED,
        checked_at=datetime.now(UTC),
    )
    runtime = _usage_runtime(reserve_side_effect=AIUsageQuotaRejected(status))
    background_tasks = BackgroundTasks()

    with pytest.raises(HTTPException) as exc:
        await router.generate_image_from_profile(
            request=GenerateImageFromProfileRequest(
                project_id="project-1",
                profile_id="ai-blog-hero",
                title_text="Blocked launch story",
            ),
            background_tasks=background_tasks,
            crew=SimpleNamespace(data_dir=tmp_path),
            current_user=CurrentUser(user_id="user-1", bearer_token="token"),
            ai_usage_provider=_usage_provider(runtime),
        )

    assert exc.value.status_code == 402
    assert exc.value.detail["code"] == "ai_quota_exhausted"
    assert generation_store.create_calls == 0
    assert background_tasks.tasks == []


@pytest.mark.asyncio
async def test_foreign_project_is_rejected_before_quota_lookup(monkeypatch, tmp_path):
    monkeypatch.setattr(
        router,
        "require_owned_project_id",
        AsyncMock(side_effect=HTTPException(status_code=404, detail="Project not found")),
    )
    usage_provider = _usage_provider(_usage_runtime())

    with pytest.raises(HTTPException) as exc:
        await router.generate_image_from_profile(
            request=GenerateImageFromProfileRequest(
                project_id="foreign-project",
                profile_id="ai-blog-hero",
                title_text="Foreign project",
            ),
            background_tasks=BackgroundTasks(),
            crew=SimpleNamespace(data_dir=tmp_path),
            current_user=CurrentUser(user_id="user-1", bearer_token="token"),
            ai_usage_provider=usage_provider,
        )

    assert exc.value.status_code == 404
    usage_provider.assert_not_awaited()


@pytest.mark.asyncio
async def test_generation_record_failure_releases_reservation(monkeypatch, tmp_path):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    generation_store = _FakeImageGenerationStore()
    generation_store.create_generation = AsyncMock(side_effect=RuntimeError("write failed"))
    monkeypatch.setattr(router, "image_generation_store", generation_store)
    monkeypatch.setattr(router, "_flux_api_key_configured", lambda: True)
    runtime = _usage_runtime()

    with pytest.raises(HTTPException) as exc:
        await router.generate_image_from_profile(
            request=GenerateImageFromProfileRequest(
                project_id="project-1",
                profile_id="ai-blog-hero",
                title_text="Queue failure",
            ),
            background_tasks=BackgroundTasks(),
            crew=SimpleNamespace(data_dir=tmp_path),
            current_user=CurrentUser(user_id="user-1", bearer_token="token"),
            ai_usage_provider=_usage_provider(runtime),
        )

    assert exc.value.status_code == 503
    runtime.service.release.assert_awaited_once_with(
        scope=AIUsageScope(user_id="user-1", project_id="project-1"),
        reservation_id="reservation-1",
        reason="flux_generation_record_failed",
    )


@pytest.mark.asyncio
async def test_generate_from_non_flux_profile_rejects_flux_override(monkeypatch, tmp_path):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))

    with pytest.raises(HTTPException) as exc:
        await router.generate_image_from_profile(
            request=_unvalidated_generate_request(
                project_id="project-1",
                profile_id="blog-hero",
                title_text="Launch story",
                subtitle_text=None,
                file_name=None,
                alt_text=None,
                custom_prompt=None,
                provider_override="flux",
                style_guide_override=None,
                path_type_override=None,
                template_id_override=None,
                reference_ids=[],
                use_visual_memory=True,
                seed=None,
                output_format="jpeg",
            ),
            background_tasks=BackgroundTasks(),
            crew=SimpleNamespace(data_dir=tmp_path),
            current_user=CurrentUser(user_id="user-1", bearer_token="token"),
        )

    assert exc.value.status_code == 400
    assert "does not allow Flux" in exc.value.detail


def test_generate_request_hides_raw_flux_provider_controls():
    schema_fn = (
        GenerateImageFromProfileRequest.model_json_schema
        if hasattr(GenerateImageFromProfileRequest, "model_json_schema")
        else GenerateImageFromProfileRequest.schema
    )
    properties = schema_fn().get("properties", {})

    assert "safety_tolerance" not in properties
    assert "flux" not in repr(properties.get("provider_override", {}))


@pytest.mark.asyncio
async def test_create_visual_reference_rejects_non_bunny_url(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))

    with pytest.raises(HTTPException) as exc:
        await router.create_visual_reference(
            request=ImageReferenceCreateRequest(
                project_id="project-1",
                cdn_url="https://example.com/ref.jpg",
            ),
            current_user=CurrentUser(user_id="user-1", bearer_token="token"),
        )

    assert exc.value.status_code == 400
