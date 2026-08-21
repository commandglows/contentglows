"""Reusable behavioral contract for AI usage store adapters."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

from api.models.ai_usage import (
    AIEntitlement,
    AIUsageAction,
    AIUsageLedgerEntry,
    AIUsageReservation,
    AIUsageScope,
    ProviderCostMetadata,
)
from api.services.ai_usage_store import (
    AIUsageMutation,
    AIUsageStore,
    AIUsageStoreConflictError,
)


NOW = datetime(2026, 8, 20, 12, tzinfo=timezone.utc)
SCOPE = AIUsageScope(user_id="user-1", project_id="project-1")


def entitlement(**changes) -> AIEntitlement:
    values = {
        "entitlement_id": "entitlement-1",
        "scope": SCOPE,
        "billing_mode": "managed",
        "actions": ["flux_image_generation", "bunny_upload"],
        "unit_limit": "100",
        "unit_reserved": "10",
        "unit_consumed": "20",
        "valid_from": NOW,
    }
    values.update(changes)
    return AIEntitlement(**values)


def reservation(**changes) -> AIUsageReservation:
    values = {
        "reservation_id": "reservation-1",
        "idempotency_key": "reserve-request-1",
        "entitlement_id": "entitlement-1",
        "scope": SCOPE,
        "action": "flux_image_generation",
        "billing_mode": "managed",
        "units": "5",
        "created_at": NOW,
        "updated_at": NOW,
        "expires_at": NOW + timedelta(minutes=15),
    }
    values.update(changes)
    return AIUsageReservation(**values)


async def create_held_reservation(
    store: AIUsageStore,
    *,
    before: AIEntitlement | None = None,
    held: AIUsageReservation | None = None,
) -> tuple[AIEntitlement, AIUsageReservation]:
    before = before or entitlement(unit_reserved="0", unit_consumed="0")
    held = held or reservation()
    await store.save_entitlement(before)
    after = AIEntitlement.model_validate(
        {
            **before.model_dump(),
            "unit_reserved": before.unit_reserved + held.units,
        }
    )
    requested = AIUsageLedgerEntry(
        entry_id=f"{held.reservation_id}-requested",
        idempotency_key=f"{held.idempotency_key}:requested",
        reservation_id=held.reservation_id,
        scope=held.scope,
        action=held.action,
        billing_mode=held.billing_mode,
        event="requested",
        created_at=NOW,
    )
    reserved = AIUsageLedgerEntry(
        entry_id=f"{held.reservation_id}-reserved",
        idempotency_key=f"{held.idempotency_key}:reserved",
        reservation_id=held.reservation_id,
        scope=held.scope,
        action=held.action,
        billing_mode=held.billing_mode,
        event="reserved",
        units=held.units,
        created_at=NOW,
    )
    await store.apply_mutation(
        AIUsageMutation(
            entitlement_before=before,
            entitlement_after=after,
            reservation_after=held,
            ledger_entries=(requested, reserved),
        )
    )
    return after, held


class AIUsageStoreContract:
    """Mixin every infrastructure adapter can reuse as its conformance suite."""

    async def make_store(self) -> AIUsageStore:
        raise NotImplementedError

    @pytest.mark.asyncio
    async def test_entitlements_roundtrip_with_scope_isolation(self):
        store = await self.make_store()
        record = entitlement()
        await store.save_entitlement(record)

        assert await store.get_entitlement("entitlement-1", scope=SCOPE) == record
        assert await store.get_entitlement(
            "entitlement-1",
            scope=AIUsageScope(user_id="user-2", project_id="project-1"),
        ) is None
        assert await store.get_entitlement(
            "entitlement-1",
            scope=AIUsageScope(user_id="user-1", project_id="project-2"),
        ) is None
        assert await store.get_entitlement(
            "entitlement-1",
            scope=AIUsageScope(user_id="user-1", project_id="project-1", org_id="org-1"),
        ) is None

        with pytest.raises(AIUsageStoreConflictError):
            await store.save_entitlement(
                entitlement(
                    scope=AIUsageScope(user_id="user-2", project_id="project-1")
                )
            )
        with pytest.raises(AIUsageStoreConflictError, match="atomic mutation"):
            await store.save_entitlement(
                entitlement(unit_reserved="11", unit_consumed="20")
            )

    @pytest.mark.asyncio
    async def test_entitlement_filter_precedes_limit(self):
        store = await self.make_store()
        await store.save_entitlement(entitlement(entitlement_id="entitlement-flux"))
        await store.save_entitlement(
            entitlement(
                entitlement_id="entitlement-render",
                actions=["remotion_render"],
                valid_from=NOW + timedelta(seconds=1),
            )
        )

        assert await store.list_entitlements(
            scope=SCOPE,
            action=AIUsageAction.FLUX_IMAGE_GENERATION,
            limit=1,
        ) == [entitlement(entitlement_id="entitlement-flux")]

    @pytest.mark.asyncio
    async def test_ledger_projects_costs_and_adjustments_without_duplicates(self):
        store = await self.make_store()
        await create_held_reservation(store)
        cost_entry = AIUsageLedgerEntry(
            entry_id="entry-cost-1",
            idempotency_key="cost-request-1",
            reservation_id="reservation-1",
            scope=SCOPE,
            action="flux_image_generation",
            billing_mode="managed",
            event="completed",
            provider_cost=ProviderCostMetadata(
                provider="bfl",
                provider_action="flux_image_generation",
                actual_cost="0.02",
                currency="USD",
                confidence="exact",
                captured_at=NOW,
            ),
            created_at=NOW,
        )
        adjustment = AIUsageLedgerEntry(
            entry_id="entry-adjustment-1",
            idempotency_key="adjustment-request-1",
            scope=SCOPE,
            action="flux_image_generation",
            billing_mode="managed",
            event="admin_adjustment",
            units="8",
            unit_direction="credit",
            actor_id="admin-1",
            reason="Restore usage after failed durable delivery",
            created_at=NOW + timedelta(seconds=1),
        )

        assert await store.append_ledger_entry(cost_entry) == cost_entry
        assert await store.append_ledger_entry(cost_entry) == cost_entry
        assert await store.append_ledger_entry(adjustment) == adjustment
        assert await store.list_provider_cost_entries(scope=SCOPE) == [cost_entry]
        assert await store.list_admin_adjustments(scope=SCOPE) == [adjustment]
        assert await store.list_ledger_entries(scope=SCOPE) == [adjustment, cost_entry]

        with pytest.raises(AIUsageStoreConflictError, match="atomic mutation"):
            await store.append_ledger_entry(
                AIUsageLedgerEntry(
                    entry_id="forged-consumption",
                    idempotency_key="forged-consumption",
                    reservation_id="reservation-1",
                    scope=SCOPE,
                    action="flux_image_generation",
                    billing_mode="managed",
                    event="consumed",
                    units="5",
                    created_at=NOW,
                )
            )

        with pytest.raises(AIUsageStoreConflictError, match="does not exist"):
            await store.append_ledger_entry(
                cost_entry.model_copy(
                    update={
                        "entry_id": "entry-orphan",
                        "idempotency_key": "cost-request-orphan",
                        "reservation_id": "missing-reservation",
                    }
                )
            )

    @pytest.mark.asyncio
    async def test_lists_reject_unbounded_limits(self):
        store = await self.make_store()

        with pytest.raises(ValueError, match="between 1 and 500"):
            await store.list_ledger_entries(scope=SCOPE, limit=0)

    @pytest.mark.asyncio
    async def test_atomic_mutation_compares_state_and_rolls_back_stale_writes(self):
        store = await self.make_store()
        before = entitlement(unit_reserved="0", unit_consumed="0")
        await store.save_entitlement(before)
        held = reservation(units="5")
        after = AIEntitlement.model_validate(
            {**before.model_dump(), "unit_reserved": Decimal("5")}
        )
        requested = AIUsageLedgerEntry(
            entry_id="entry-requested",
            idempotency_key="reserve-request-1:requested",
            reservation_id=held.reservation_id,
            scope=SCOPE,
            action=held.action,
            billing_mode=held.billing_mode,
            event="requested",
            created_at=NOW,
        )
        reserved = AIUsageLedgerEntry(
            entry_id="entry-reserved",
            idempotency_key="reserve-request-1:reserved",
            reservation_id=held.reservation_id,
            scope=SCOPE,
            action=held.action,
            billing_mode=held.billing_mode,
            event="reserved",
            units="5",
            created_at=NOW,
        )
        mutation = AIUsageMutation(
            entitlement_before=before,
            entitlement_after=after,
            reservation_after=held,
            ledger_entries=(requested, reserved),
        )

        assert await store.apply_mutation(mutation) == mutation
        assert await store.apply_mutation(mutation) == mutation
        assert await store.get_entitlement(before.entitlement_id, scope=SCOPE) == after

        competing_reservation = reservation(
            reservation_id="reservation-competing",
            idempotency_key="reserve-competing",
            units="6",
        )
        competing_after = AIEntitlement.model_validate(
            {**before.model_dump(), "unit_reserved": Decimal("6")}
        )
        competing_entry = AIUsageLedgerEntry(
            entry_id="entry-competing",
            idempotency_key="reserve-competing:reserved",
            reservation_id=competing_reservation.reservation_id,
            scope=SCOPE,
            action=competing_reservation.action,
            billing_mode=competing_reservation.billing_mode,
            event="reserved",
            units="6",
            created_at=NOW,
        )
        with pytest.raises(AIUsageStoreConflictError, match="concurrently"):
            await store.apply_mutation(
                AIUsageMutation(
                    entitlement_before=before,
                    entitlement_after=competing_after,
                    reservation_after=competing_reservation,
                    ledger_entries=(competing_entry,),
                )
            )
        assert await store.get_reservation(
            competing_reservation.reservation_id,
            scope=SCOPE,
        ) is None
