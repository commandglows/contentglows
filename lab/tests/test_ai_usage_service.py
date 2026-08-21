from __future__ import annotations

import asyncio
import itertools
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

from api.models.ai_usage import (
    AIEntitlement,
    AIUsageAction,
    AIUsageReservationStatus,
    AIUsageScope,
    ProviderCostMetadata,
)
from api.services.ai_usage_service import (
    AIUsageQuotaRejected,
    AIUsageService,
    AIUsageTransitionConflict,
)
from api.services.libsql_ai_usage_store import LibsqlAIUsageStore
from utils.libsql_async import create_client


NOW = datetime(2026, 8, 20, 18, tzinfo=timezone.utc)
SCOPE = AIUsageScope(user_id="user-1", project_id="project-1")


class MutableClock:
    def __init__(self, now: datetime) -> None:
        self.now = now

    def __call__(self) -> datetime:
        return self.now


async def _setup(*, unit_limit: str = "10"):
    store = LibsqlAIUsageStore(db_client=create_client(url=":memory:"))
    await store.ensure_schema()
    await store.save_entitlement(
        AIEntitlement(
            entitlement_id="entitlement-1",
            scope=SCOPE,
            billing_mode="managed",
            actions=["flux_image_generation", "bunny_upload", "remotion_render"],
            unit_limit=unit_limit,
            valid_from=NOW - timedelta(days=1),
        )
    )
    clock = MutableClock(NOW)
    identifiers = (f"id-{index}" for index in itertools.count(1))
    service = AIUsageService(
        store=store,
        clock=clock,
        id_factory=lambda: next(identifiers),
    )
    return store, service, clock


@pytest.mark.asyncio
async def test_preflight_and_reserve_hard_block_before_overspend():
    store, service, _ = await _setup(unit_limit="4")

    blocked = await service.preflight(
        scope=SCOPE,
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        required_units=Decimal("5"),
    )
    assert blocked.allowed is False
    assert blocked.reason_code.value == "ai_quota_exhausted"
    with pytest.raises(AIUsageQuotaRejected):
        await service.reserve(
            scope=SCOPE,
            action=AIUsageAction.FLUX_IMAGE_GENERATION,
            units=Decimal("5"),
            idempotency_key="too-expensive",
            expires_in=timedelta(minutes=15),
        )
    assert await store.list_reservations(scope=SCOPE) == []


@pytest.mark.asyncio
async def test_concurrent_reservations_cannot_spend_the_same_balance():
    store, service, _ = await _setup(unit_limit="5")

    results = await asyncio.gather(
        service.reserve(
            scope=SCOPE,
            action=AIUsageAction.FLUX_IMAGE_GENERATION,
            units=Decimal("4"),
            idempotency_key="request-a",
            expires_in=timedelta(minutes=15),
        ),
        service.reserve(
            scope=SCOPE,
            action=AIUsageAction.FLUX_IMAGE_GENERATION,
            units=Decimal("4"),
            idempotency_key="request-b",
            expires_in=timedelta(minutes=15),
        ),
        return_exceptions=True,
    )

    assert sum(not isinstance(result, Exception) for result in results) == 1
    assert sum(isinstance(result, AIUsageQuotaRejected) for result in results) == 1
    reservations = await store.list_reservations(scope=SCOPE)
    assert len(reservations) == 1
    entitlement = await store.get_entitlement("entitlement-1", scope=SCOPE)
    assert entitlement is not None
    assert entitlement.unit_reserved == Decimal("4")
    assert entitlement.unit_remaining == Decimal("1")


@pytest.mark.asyncio
async def test_reservation_and_reconciliation_are_idempotent():
    store, service, _ = await _setup()
    reservation = await service.reserve(
        scope=SCOPE,
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        units=Decimal("3"),
        idempotency_key="request-1",
        expires_in=timedelta(minutes=15),
        provider="bfl",
    )
    assert await service.reserve(
        scope=SCOPE,
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        units=Decimal("3"),
        idempotency_key="request-1",
        expires_in=timedelta(minutes=15),
        provider="bfl",
    ) == reservation

    started = await service.mark_provider_started(
        scope=SCOPE,
        reservation_id=reservation.reservation_id,
    )
    assert started.status is AIUsageReservationStatus.PROVIDER_STARTED
    assert await service.mark_provider_started(
        scope=SCOPE,
        reservation_id=reservation.reservation_id,
    ) == started

    consumed = await service.consume(
        scope=SCOPE,
        reservation_id=reservation.reservation_id,
        provider_cost=ProviderCostMetadata(
            provider="bfl",
            provider_action="flux_image_generation",
            actual_cost="0.02",
            currency="USD",
            confidence="exact",
            captured_at=NOW,
        ),
    )
    assert consumed.status is AIUsageReservationStatus.CONSUMED
    assert await service.consume(
        scope=SCOPE,
        reservation_id=reservation.reservation_id,
    ) == consumed
    with pytest.raises(AIUsageTransitionConflict, match="provider cost evidence"):
        await service.consume(
            scope=SCOPE,
            reservation_id=reservation.reservation_id,
            provider_cost=ProviderCostMetadata(
                provider="bfl",
                provider_action="flux_image_generation",
                actual_cost="0.03",
                currency="USD",
                confidence="exact",
                captured_at=NOW,
            ),
        )
    entitlement = await store.get_entitlement("entitlement-1", scope=SCOPE)
    assert entitlement is not None
    assert entitlement.unit_reserved == Decimal("0")
    assert entitlement.unit_consumed == Decimal("3")


@pytest.mark.asyncio
async def test_provider_failure_release_and_post_consumption_refund_restore_units():
    store, service, _ = await _setup()
    failed = await service.reserve(
        scope=SCOPE,
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        units=Decimal("2"),
        idempotency_key="failed-request",
        expires_in=timedelta(minutes=15),
    )
    await service.mark_provider_started(scope=SCOPE, reservation_id=failed.reservation_id)
    released = await service.release(
        scope=SCOPE,
        reservation_id=failed.reservation_id,
        reason="provider_failed_before_durable_asset",
    )
    assert released.status is AIUsageReservationStatus.RELEASED

    delivered = await service.reserve(
        scope=SCOPE,
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        units=Decimal("3"),
        idempotency_key="delivered-request",
        expires_in=timedelta(minutes=15),
    )
    await service.mark_provider_started(scope=SCOPE, reservation_id=delivered.reservation_id)
    await service.consume(scope=SCOPE, reservation_id=delivered.reservation_id)
    refunded = await service.refund(
        scope=SCOPE,
        reservation_id=delivered.reservation_id,
        reason="support_refund",
    )
    assert refunded.status is AIUsageReservationStatus.REFUNDED
    entitlement = await store.get_entitlement("entitlement-1", scope=SCOPE)
    assert entitlement is not None
    assert entitlement.unit_reserved == Decimal("0")
    assert entitlement.unit_consumed == Decimal("0")
    assert entitlement.unit_remaining == Decimal("10")


@pytest.mark.asyncio
async def test_stale_reservations_expire_without_cross_tenant_access():
    store, service, clock = await _setup()
    reservation = await service.reserve(
        scope=SCOPE,
        action=AIUsageAction.REMOTION_RENDER,
        units=Decimal("2"),
        idempotency_key="stale-request",
        expires_in=timedelta(minutes=5),
    )
    clock.now = NOW + timedelta(minutes=6)

    assert await service.expire_stale_reservations(
        scope=AIUsageScope(user_id="other-user", project_id="project-1")
    ) == []
    expired = await service.expire_stale_reservations(scope=SCOPE)
    assert [item.reservation_id for item in expired] == [reservation.reservation_id]
    assert expired[0].status is AIUsageReservationStatus.EXPIRED


@pytest.mark.asyncio
async def test_invalid_transition_and_idempotency_key_reuse_are_rejected():
    _, service, _ = await _setup()
    reservation = await service.reserve(
        scope=SCOPE,
        action=AIUsageAction.BUNNY_UPLOAD,
        units=Decimal("2"),
        idempotency_key="request-1",
        expires_in=timedelta(minutes=15),
    )
    with pytest.raises(AIUsageTransitionConflict, match="different reservation"):
        await service.reserve(
            scope=SCOPE,
            action=AIUsageAction.BUNNY_UPLOAD,
            units=Decimal("3"),
            idempotency_key="request-1",
            expires_in=timedelta(minutes=15),
        )
    await service.release(
        scope=SCOPE,
        reservation_id=reservation.reservation_id,
        reason="queue_failed",
    )
    with pytest.raises(AIUsageTransitionConflict, match="invalid reservation transition"):
        await service.mark_provider_started(
            scope=SCOPE,
            reservation_id=reservation.reservation_id,
        )
