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
from api.services.ai_usage_policies import AIUsageFailureBehavior
from api.models.ai_usage import ProviderCostMetadata
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
            "estimated_units": kwargs.get("estimated_units"),
            "quota_status": kwargs.get("quota_status"),
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
@pytest.mark.parametrize(
    "provider_started, behavior, expected_method, expected_status",
    [
        (False, AIUsageFailureBehavior.REFUND, "release", "released"),
        (True, AIUsageFailureBehavior.RELEASE, "release", "released"),
        (True, AIUsageFailureBehavior.REFUND, "refund", "refunded"),
    ],
)
async def test_failed_flux_usage_applies_configured_settlement(
    provider_started,
    behavior,
    expected_method,
    expected_status,
):
    service = SimpleNamespace(release=AsyncMock(), refund=AsyncMock())

    status, outcome = await router._reconcile_failed_flux_usage(
        ai_usage_service=service,
        scope=AIUsageScope(user_id="user-1", project_id="project-1"),
        reservation_id="reservation-1",
        provider_started=provider_started,
        failure_behavior=behavior,
        provider_cost=None,
        reason="provider_failed",
    )

    assert status == expected_status
    assert outcome == expected_status
    getattr(service, expected_method).assert_awaited_once()


@pytest.mark.asyncio
async def test_failed_flux_usage_stays_recoverable_when_settlement_is_interrupted():
    service = SimpleNamespace(
        release=AsyncMock(side_effect=RuntimeError("worker interrupted")),
        refund=AsyncMock(),
    )

    status, outcome = await router._reconcile_failed_flux_usage(
        ai_usage_service=service,
        scope=AIUsageScope(user_id="user-1", project_id="project-1"),
        reservation_id="reservation-1",
        provider_started=False,
        failure_behavior=AIUsageFailureBehavior.RELEASE,
        provider_cost=None,
        reason="worker_interrupted",
    )

    assert status == "reconciliation_pending"
    assert outcome is None


@pytest.mark.asyncio
async def test_flux_worker_consumes_only_after_durable_bunny_asset(monkeypatch, tmp_path):
    local_path = tmp_path / "flux-result.jpg"
    local_path.write_bytes(b"image")
    cost = ProviderCostMetadata(
        provider="bfl",
        provider_action="flux_image_generation",
        model="flux-2-pro",
        provider_request_id="bfl-1",
        actual_cost="4.5",
        cost_unit="provider_credit",
        confidence="exact",
        captured_at=datetime.now(UTC),
    )
    result = SimpleNamespace(
        local_path=str(local_path),
        provider_request_id="bfl-1",
        provider_cost=4.5,
        provider_cost_metadata=cost,
        provider_metadata={"cost_evidence": cost.model_dump(mode="json", by_alias=True)},
        model="flux-2-pro",
        output_format="jpeg",
    )
    generator = SimpleNamespace(generate_to_file=lambda **kwargs: result)
    monkeypatch.setattr(router, "FluxImageGenerator", lambda model: generator)
    monkeypatch.setattr(router, "_record_generated_project_asset", lambda **kwargs: "asset-1")
    store = SimpleNamespace(
        mark_running=AsyncMock(),
        mark_completed=AsyncMock(),
        mark_failed=AsyncMock(),
        update_reconciliation=AsyncMock(),
    )
    monkeypatch.setattr(router, "image_generation_store", store)
    service = SimpleNamespace(
        mark_provider_started=AsyncMock(),
        consume=AsyncMock(),
        release=AsyncMock(),
        refund=AsyncMock(),
    )
    crew = SimpleNamespace(
        cdn_manager=SimpleNamespace(
            upload_with_optimizer=lambda **kwargs: {
                "success": True,
                "cdn_url": "https://assets.b-cdn.net/image.jpg",
                "primary_url": "https://assets.b-cdn.net/image-800.jpg",
                "responsive_urls": {"800": "https://assets.b-cdn.net/image-800.jpg"},
            }
        )
    )

    await router._run_flux_generation_job(
        crew=crew,
        generation_id="generation-1",
        job_id="job-1",
        project_id="project-1",
        user_id="user-1",
        profile_id="ai-blog-hero",
        image_type="hero_image",
        prompt="Hero",
        model="flux-2-pro",
        width=1280,
        height=720,
        seed=None,
        output_format="jpeg",
        safety_tolerance=2,
        reference_urls=[],
        file_name="hero.jpg",
        alt_text="Hero",
        path_type="articles",
        ai_usage_service=service,
        usage_scope=AIUsageScope(user_id="user-1", project_id="project-1"),
        reservation_id="reservation-1",
        failure_behavior=AIUsageFailureBehavior.REFUND,
    )

    service.mark_provider_started.assert_awaited_once()
    service.consume.assert_awaited_once_with(
        scope=AIUsageScope(user_id="user-1", project_id="project-1"),
        reservation_id="reservation-1",
        provider_cost=cost,
    )
    store.mark_completed.assert_awaited_once()
    assert any(
        call.kwargs.get("quota_status") == "consumed"
        for call in store.update_reconciliation.await_args_list
    )


@pytest.mark.asyncio
async def test_bunny_failure_refunds_without_consuming(monkeypatch, tmp_path):
    local_path = tmp_path / "flux-result.jpg"
    local_path.write_bytes(b"image")
    cost = ProviderCostMetadata(
        provider="bfl",
        provider_action="flux_image_generation",
        model="flux-2-pro",
        provider_request_id="bfl-2",
        actual_cost="3.5",
        cost_unit="provider_credit",
        confidence="exact",
        captured_at=datetime.now(UTC),
    )
    result = SimpleNamespace(
        local_path=str(local_path),
        provider_request_id="bfl-2",
        provider_cost=3.5,
        provider_cost_metadata=cost,
        provider_metadata={},
        model="flux-2-pro",
        output_format="jpeg",
    )
    monkeypatch.setattr(
        router,
        "FluxImageGenerator",
        lambda model: SimpleNamespace(generate_to_file=lambda **kwargs: result),
    )
    store = SimpleNamespace(
        mark_running=AsyncMock(),
        mark_completed=AsyncMock(),
        mark_failed=AsyncMock(),
        update_reconciliation=AsyncMock(),
    )
    monkeypatch.setattr(router, "image_generation_store", store)
    service = SimpleNamespace(
        mark_provider_started=AsyncMock(),
        consume=AsyncMock(),
        release=AsyncMock(),
        refund=AsyncMock(),
    )
    crew = SimpleNamespace(
        cdn_manager=SimpleNamespace(
            upload_with_optimizer=lambda **kwargs: {
                "success": False,
                "error": "Bunny unavailable",
            }
        )
    )
    scope = AIUsageScope(user_id="user-1", project_id="project-1")

    await router._run_flux_generation_job(
        crew=crew,
        generation_id="generation-2",
        job_id="job-2",
        project_id="project-1",
        user_id="user-1",
        profile_id="ai-blog-hero",
        image_type="hero_image",
        prompt="Hero",
        model="flux-2-pro",
        width=1280,
        height=720,
        seed=None,
        output_format="jpeg",
        safety_tolerance=2,
        reference_urls=[],
        file_name="hero.jpg",
        alt_text="Hero",
        path_type="articles",
        ai_usage_service=service,
        usage_scope=scope,
        reservation_id="reservation-2",
        failure_behavior=AIUsageFailureBehavior.REFUND,
    )

    service.consume.assert_not_awaited()
    service.refund.assert_awaited_once_with(
        scope=scope,
        reservation_id="reservation-2",
        reason="cdn_upload_failed",
        provider_cost=cost,
    )
    store.mark_failed.assert_awaited_once()
    assert any(
        call.kwargs.get("quota_status") == "refunded"
        for call in store.update_reconciliation.await_args_list
    )


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
