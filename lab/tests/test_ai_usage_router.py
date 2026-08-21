from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from api.dependencies.auth import CurrentUser, require_current_user
from api.models.ai_usage import (
    AIQuotaStatus,
    AIUsageAction,
    AIUsageLedgerEntry,
    AIUsageReservation,
    AIUsageScope,
)
from api.routers import ai_usage as router
from api.services.ai_usage_policies import AIUsageActionPolicy, AIUsagePolicySet


NOW = datetime(2026, 8, 21, 14, tzinfo=UTC)
USER = CurrentUser(user_id="user-1", bearer_token="test-token")
SCOPE = AIUsageScope(user_id="user-1", project_id="project-1")


def _policy() -> AIUsageActionPolicy:
    return AIUsageActionPolicy(
        action="flux_image_generation",
        billing_mode="managed",
        provider="internal-provider",
        model="internal-model",
        estimated_units="2.5",
        limit_behavior="hard_block",
        provider_failure_behavior="release",
        admin_override_eligible=True,
    )


def _quota() -> AIQuotaStatus:
    return AIQuotaStatus(
        scope=SCOPE,
        action="flux_image_generation",
        billing_mode="managed",
        allowed=True,
        entitlement_id="entitlement-1",
        unit_limit="10",
        unit_reserved="1",
        unit_consumed="2",
        unit_remaining="7",
        required_units="2.5",
        checked_at=NOW,
    )


def _runtime(*, quota=None, entries=None, reservations=None):
    service = SimpleNamespace(preflight=AsyncMock(return_value=quota or _quota()))
    store = SimpleNamespace(
        list_ledger_entries=AsyncMock(return_value=entries or []),
        list_reservations=AsyncMock(side_effect=reservations or [[], []]),
    )
    return SimpleNamespace(
        service=service,
        store=store,
        policies=AIUsagePolicySet([_policy()]),
        reservation_ttl_seconds=900,
    )


def _provider(runtime):
    return AsyncMock(return_value=runtime)


def test_all_usage_routes_require_authentication_and_expose_no_admin_route():
    paths = set()
    for route in router.router.routes:
        paths.add(route.path)
        assert any(
            dependency.call is require_current_user
            for dependency in route.dependant.dependencies
        )
    assert not any("admin" in path for path in paths)


@pytest.mark.asyncio
async def test_preflight_uses_server_policy_units_and_owner_scope(monkeypatch):
    require_owner = AsyncMock(return_value="project-1")
    monkeypatch.setattr(router, "require_owned_project_id", require_owner)
    runtime = _runtime()

    response = await router.preflight_usage(
        router.AIUsagePreflightRequest(
            project_id="project-1",
            action="flux_image_generation",
        ),
        current_user=USER,
        runtime_provider=_provider(runtime),
    )

    require_owner.assert_awaited_once_with("project-1", USER)
    runtime.service.preflight.assert_awaited_once_with(
        scope=SCOPE,
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        required_units=Decimal("2.5"),
    )
    assert response.quota.allowed is True
    public_policy = response.policy.model_dump(by_alias=True)
    assert "provider" not in public_policy
    assert "model" not in public_policy
    assert "adminOverrideEligible" not in public_policy


@pytest.mark.asyncio
async def test_foreign_project_stops_before_runtime_access(monkeypatch):
    async def reject_project(project_id, current_user):
        raise HTTPException(status_code=403, detail="Forbidden")

    monkeypatch.setattr(router, "require_owned_project_id", reject_project)
    provider = _provider(_runtime())

    with pytest.raises(HTTPException) as error:
        await router.get_usage_summary(
            project_id="foreign-project",
            current_user=USER,
            runtime_provider=provider,
        )

    assert error.value.status_code == 403
    provider.assert_not_awaited()


@pytest.mark.asyncio
async def test_history_is_scoped_to_authenticated_user_and_project(monkeypatch):
    monkeypatch.setattr(
        router,
        "require_owned_project_id",
        AsyncMock(return_value="project-1"),
    )
    entry = AIUsageLedgerEntry(
        entry_id="entry-1",
        idempotency_key="entry-key-1",
        reservation_id="reservation-1",
        scope=SCOPE,
        action="flux_image_generation",
        billing_mode="managed",
        event="completed",
        created_at=NOW,
    )
    runtime = _runtime(entries=[entry])

    response = await router.get_usage_history(
        project_id="project-1",
        event=None,
        limit=25,
        current_user=USER,
        runtime_provider=_provider(runtime),
    )

    runtime.store.list_ledger_entries.assert_awaited_once_with(
        scope=SCOPE,
        event=None,
        limit=25,
    )
    assert response.entries == [entry]


@pytest.mark.asyncio
async def test_pending_reservations_include_only_recoverable_states(monkeypatch):
    monkeypatch.setattr(
        router,
        "require_owned_project_id",
        AsyncMock(return_value="project-1"),
    )
    reserved = AIUsageReservation(
        reservation_id="reservation-1",
        idempotency_key="request-1",
        entitlement_id="entitlement-1",
        scope=SCOPE,
        action="flux_image_generation",
        billing_mode="managed",
        status="reserved",
        units="2.5",
        created_at=NOW,
        updated_at=NOW,
        expires_at=NOW + timedelta(minutes=15),
    )
    started = AIUsageReservation(
        reservation_id="reservation-2",
        idempotency_key="request-2",
        entitlement_id="entitlement-1",
        scope=SCOPE,
        action="flux_image_generation",
        billing_mode="managed",
        status="provider_started",
        units="2.5",
        created_at=NOW,
        updated_at=NOW + timedelta(seconds=1),
        expires_at=NOW + timedelta(minutes=15),
        provider_started_at=NOW,
    )
    runtime = _runtime(reservations=[[reserved], [started]])

    response = await router.get_pending_reservations(
        project_id="project-1",
        limit=10,
        current_user=USER,
        runtime_provider=_provider(runtime),
    )

    assert [item.reservation_id for item in response.reservations] == [
        "reservation-2",
        "reservation-1",
    ]
    assert {
        call.kwargs["status"].value
        for call in runtime.store.list_reservations.await_args_list
    } == {"reserved", "provider_started"}


def test_preflight_rejects_unknown_actions_with_structured_validation_error():
    with pytest.raises(ValidationError):
        router.AIUsagePreflightRequest(
            project_id="project-1",
            action="unknown-paid-action",
        )
