"""Storage-agnostic quota reservation and reconciliation service."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Callable, Iterable

from api.models.ai_usage import (
    AIEntitlement,
    AIEntitlementStatus,
    AIQuotaErrorCode,
    AIQuotaStatus,
    AIUsageAction,
    AIUsageBillingMode,
    AIUsageLedgerEntry,
    AIUsageLedgerEvent,
    AIUsageReservation,
    AIUsageReservationStatus,
    AIUsageScope,
    ProviderCostMetadata,
    validate_reservation_transition,
)
from api.services.ai_usage_store import (
    AIUsageMutation,
    AIUsageStore,
    AIUsageStoreConflictError,
)


class AIUsageServiceError(RuntimeError):
    """Base error for quota workflow failures."""


class AIUsageQuotaRejected(AIUsageServiceError):
    """Raised when managed usage cannot be reserved before provider spend."""

    def __init__(self, status: AIQuotaStatus) -> None:
        super().__init__(
            status.reason_code.value if status.reason_code else "ai_quota_rejected"
        )
        self.status = status


class AIUsageTransitionConflict(AIUsageServiceError):
    """Raised when a reservation changed to an incompatible state."""


class AIUsageService:
    """Own quota decisions while delegating atomic durability to the store port."""

    def __init__(
        self,
        *,
        store: AIUsageStore,
        clock: Callable[[], datetime] | None = None,
        id_factory: Callable[[], str] | None = None,
    ) -> None:
        self._store = store
        self._clock = clock or (lambda: datetime.now(UTC))
        self._id_factory = id_factory or (lambda: str(uuid.uuid4()))

    async def preflight(
        self,
        *,
        scope: AIUsageScope,
        action: AIUsageAction,
        required_units: Decimal = Decimal("0"),
    ) -> AIQuotaStatus:
        if required_units < 0:
            raise ValueError("required_units must be non-negative")
        now = self._now()
        billing_mode = _billing_mode(action)
        entitlement = await self._active_entitlement(
            scope=scope,
            action=action,
            billing_mode=billing_mode,
            now=now,
        )
        if entitlement is None:
            return AIQuotaStatus(
                scope=scope,
                action=action,
                billing_mode=billing_mode,
                allowed=False,
                required_units=(
                    required_units
                    if billing_mode is AIUsageBillingMode.MANAGED
                    else Decimal("0")
                ),
                reason_code=AIQuotaErrorCode.ENTITLEMENT_MISSING,
                checked_at=now,
            )
        if billing_mode is AIUsageBillingMode.BYOK:
            return AIQuotaStatus(
                scope=scope,
                action=action,
                billing_mode=billing_mode,
                allowed=True,
                entitlement_id=entitlement.entitlement_id,
                checked_at=now,
            )

        remaining = entitlement.unit_remaining
        allowed = required_units <= remaining
        return AIQuotaStatus(
            scope=scope,
            action=action,
            billing_mode=billing_mode,
            allowed=allowed,
            entitlement_id=entitlement.entitlement_id if allowed else None,
            unit_limit=entitlement.unit_limit,
            unit_reserved=entitlement.unit_reserved,
            unit_consumed=entitlement.unit_consumed,
            unit_remaining=remaining,
            required_units=required_units,
            reason_code=None if allowed else AIQuotaErrorCode.EXHAUSTED,
            reset_at=entitlement.expires_at,
            checked_at=now,
        )

    async def reserve(
        self,
        *,
        scope: AIUsageScope,
        action: AIUsageAction,
        units: Decimal,
        idempotency_key: str,
        expires_in: timedelta,
        provider: str | None = None,
        model: str | None = None,
        job_id: str | None = None,
    ) -> AIUsageReservation:
        if units <= 0:
            raise ValueError("managed reservations require positive units")
        if expires_in <= timedelta(0):
            raise ValueError("reservation expiry must be positive")
        if action is AIUsageAction.BYOK_METADATA:
            raise ValueError("BYOK metadata does not create managed reservations")
        existing = await self._store.get_reservation_by_idempotency_key(
            idempotency_key,
            scope=scope,
        )
        if existing is not None:
            return _matching_reservation(
                existing,
                action=action,
                units=units,
                provider=provider,
                model=model,
                job_id=job_id,
            )

        status = await self.preflight(
            scope=scope,
            action=action,
            required_units=units,
        )
        if not status.allowed or status.entitlement_id is None:
            raise AIUsageQuotaRejected(status)
        entitlement = await self._store.get_entitlement(
            status.entitlement_id,
            scope=scope,
        )
        if entitlement is None:
            raise AIUsageTransitionConflict("entitlement disappeared after preflight")

        now = self._now()
        reservation = AIUsageReservation(
            reservation_id=self._id_factory(),
            idempotency_key=idempotency_key,
            entitlement_id=entitlement.entitlement_id,
            scope=scope,
            action=action,
            billing_mode=AIUsageBillingMode.MANAGED,
            units=units,
            provider=provider,
            model=model,
            job_id=job_id,
            created_at=now,
            updated_at=now,
            expires_at=now + expires_in,
        )
        updated_entitlement = _replace_entitlement(
            entitlement,
            unit_reserved=entitlement.unit_reserved + units,
        )
        mutation = AIUsageMutation(
            entitlement_before=entitlement,
            entitlement_after=updated_entitlement,
            reservation_after=reservation,
            ledger_entries=(
                self._ledger_entry(
                    reservation=reservation,
                    event=AIUsageLedgerEvent.REQUESTED,
                    units=Decimal("0"),
                    idempotency_key=f"{idempotency_key}:requested",
                    created_at=now,
                ),
                self._ledger_entry(
                    reservation=reservation,
                    event=AIUsageLedgerEvent.RESERVED,
                    units=units,
                    idempotency_key=f"{idempotency_key}:reserved",
                    created_at=now,
                ),
            ),
        )
        try:
            await self._store.apply_mutation(mutation)
        except AIUsageStoreConflictError:
            concurrent = await self._store.get_reservation_by_idempotency_key(
                idempotency_key,
                scope=scope,
            )
            if concurrent is not None:
                return _matching_reservation(
                    concurrent,
                    action=action,
                    units=units,
                    provider=provider,
                    model=model,
                    job_id=job_id,
                )
            refreshed = await self.preflight(
                scope=scope,
                action=action,
                required_units=units,
            )
            if not refreshed.allowed:
                raise AIUsageQuotaRejected(refreshed) from None
            raise AIUsageTransitionConflict("reservation lost a concurrent state race") from None
        return reservation

    async def mark_provider_started(
        self,
        *,
        scope: AIUsageScope,
        reservation_id: str,
    ) -> AIUsageReservation:
        return await self._transition_without_balance(
            scope=scope,
            reservation_id=reservation_id,
            target=AIUsageReservationStatus.PROVIDER_STARTED,
            event=AIUsageLedgerEvent.PROVIDER_STARTED,
        )

    async def consume(
        self,
        *,
        scope: AIUsageScope,
        reservation_id: str,
        provider_cost: ProviderCostMetadata | None = None,
    ) -> AIUsageReservation:
        return await self._settle(
            scope=scope,
            reservation_id=reservation_id,
            target=AIUsageReservationStatus.CONSUMED,
            balance_bucket="consumed",
            terminal_event=AIUsageLedgerEvent.COMPLETED,
            provider_cost=provider_cost,
        )

    async def release(
        self,
        *,
        scope: AIUsageScope,
        reservation_id: str,
        reason: str,
        provider_cost: ProviderCostMetadata | None = None,
    ) -> AIUsageReservation:
        return await self._settle(
            scope=scope,
            reservation_id=reservation_id,
            target=AIUsageReservationStatus.RELEASED,
            balance_bucket="released",
            terminal_event=AIUsageLedgerEvent.FAILED,
            provider_cost=provider_cost,
            reason=reason,
        )

    async def refund(
        self,
        *,
        scope: AIUsageScope,
        reservation_id: str,
        reason: str,
        provider_cost: ProviderCostMetadata | None = None,
    ) -> AIUsageReservation:
        return await self._settle(
            scope=scope,
            reservation_id=reservation_id,
            target=AIUsageReservationStatus.REFUNDED,
            balance_bucket="refunded",
            terminal_event=AIUsageLedgerEvent.FAILED,
            provider_cost=provider_cost,
            reason=reason,
        )

    async def expire_stale_reservations(
        self,
        *,
        scope: AIUsageScope,
        limit: int = 100,
    ) -> list[AIUsageReservation]:
        now = self._now()
        reservations = await self._store.list_reservations(
            scope=scope,
            status=AIUsageReservationStatus.RESERVED,
            limit=limit,
        )
        expired: list[AIUsageReservation] = []
        for reservation in reservations:
            if reservation.expires_at <= now:
                expired.append(
                    await self._settle(
                        scope=scope,
                        reservation_id=reservation.reservation_id,
                        target=AIUsageReservationStatus.EXPIRED,
                        balance_bucket="released",
                        terminal_event=AIUsageLedgerEvent.EXPIRED,
                    )
                )
        return expired

    async def summarize_usage(
        self,
        *,
        scope: AIUsageScope,
        actions: Iterable[AIUsageAction],
    ) -> list[AIQuotaStatus]:
        return [
            await self.preflight(scope=scope, action=action)
            for action in dict.fromkeys(actions)
        ]

    async def _transition_without_balance(
        self,
        *,
        scope: AIUsageScope,
        reservation_id: str,
        target: AIUsageReservationStatus,
        event: AIUsageLedgerEvent,
    ) -> AIUsageReservation:
        reservation = await self._required_reservation(reservation_id, scope=scope)
        if reservation.status is target:
            return reservation
        _require_transition(reservation.status, target)
        now = self._now()
        updated = _replace_reservation(
            reservation,
            status=target,
            updated_at=now,
            provider_started_at=now,
        )
        mutation = AIUsageMutation(
            reservation_before=reservation,
            reservation_after=updated,
            ledger_entries=(
                self._ledger_entry(
                    reservation=updated,
                    event=event,
                    units=Decimal("0"),
                    idempotency_key=f"{reservation.idempotency_key}:{event.value}",
                    created_at=now,
                ),
            ),
        )
        return await self._apply_transition(mutation, target=target)

    async def _settle(
        self,
        *,
        scope: AIUsageScope,
        reservation_id: str,
        target: AIUsageReservationStatus,
        balance_bucket: str,
        terminal_event: AIUsageLedgerEvent,
        provider_cost: ProviderCostMetadata | None = None,
        reason: str | None = None,
    ) -> AIUsageReservation:
        reservation = await self._required_reservation(reservation_id, scope=scope)
        if reservation.status is target:
            await self._validate_settlement_replay(
                reservation=reservation,
                target=target,
                provider_cost=provider_cost,
                reason=reason,
            )
            return reservation
        _require_transition(reservation.status, target)
        entitlement = await self._required_entitlement(reservation)
        now = self._now()
        provider_started_at = reservation.provider_started_at
        updated = _replace_reservation(
            reservation,
            status=target,
            updated_at=now,
            provider_started_at=provider_started_at,
        )
        entitlement_changes = _settled_entitlement_values(
            entitlement=entitlement,
            reservation=reservation,
            balance_bucket=balance_bucket,
        )
        updated_entitlement = _replace_entitlement(entitlement, **entitlement_changes)
        entries: list[AIUsageLedgerEntry] = []
        if terminal_event in {AIUsageLedgerEvent.COMPLETED, AIUsageLedgerEvent.FAILED}:
            entries.append(
                self._ledger_entry(
                    reservation=updated,
                    event=terminal_event,
                    units=Decimal("0"),
                    idempotency_key=(
                        f"{reservation.idempotency_key}:{target.value}:{terminal_event.value}"
                    ),
                    created_at=now,
                    provider_cost=provider_cost,
                    reason=reason,
                )
            )
        entries.append(
            self._ledger_entry(
                reservation=updated,
                event=_settlement_event(target),
                units=reservation.units,
                idempotency_key=f"{reservation.idempotency_key}:{target.value}",
                created_at=now,
                reason=reason,
            )
        )
        mutation = AIUsageMutation(
            entitlement_before=entitlement,
            entitlement_after=updated_entitlement,
            reservation_before=reservation,
            reservation_after=updated,
            ledger_entries=tuple(entries),
        )
        return await self._apply_transition(mutation, target=target)

    async def _apply_transition(
        self,
        mutation: AIUsageMutation,
        *,
        target: AIUsageReservationStatus,
    ) -> AIUsageReservation:
        try:
            await self._store.apply_mutation(mutation)
            if mutation.reservation_after is None:
                raise AIUsageTransitionConflict("mutation omitted reservation state")
            return mutation.reservation_after
        except AIUsageStoreConflictError:
            expected = mutation.reservation_after
            if expected is None:
                raise AIUsageTransitionConflict("mutation omitted reservation state") from None
            current = await self._store.get_reservation(
                expected.reservation_id,
                scope=expected.scope,
            )
            if current is not None and current.status is target:
                if await self._mutation_entries_match(mutation):
                    return current
                raise AIUsageTransitionConflict(
                    "reservation reached the target with different reconciliation evidence"
                ) from None
            raise AIUsageTransitionConflict("reservation changed concurrently") from None

    async def _mutation_entries_match(self, mutation: AIUsageMutation) -> bool:
        for incoming in mutation.ledger_entries:
            stored = await self._store.get_ledger_entry_by_idempotency_key(
                incoming.idempotency_key,
                scope=incoming.scope,
            )
            if stored is None or not _same_ledger_operation(stored, incoming):
                return False
        return True

    async def _validate_settlement_replay(
        self,
        *,
        reservation: AIUsageReservation,
        target: AIUsageReservationStatus,
        provider_cost: ProviderCostMetadata | None,
        reason: str | None,
    ) -> None:
        if provider_cost is None and reason is None:
            return
        terminal_event = {
            AIUsageReservationStatus.CONSUMED: AIUsageLedgerEvent.COMPLETED,
            AIUsageReservationStatus.RELEASED: AIUsageLedgerEvent.FAILED,
            AIUsageReservationStatus.REFUNDED: AIUsageLedgerEvent.FAILED,
        }.get(target)
        if terminal_event is None:
            return
        entry = await self._store.get_ledger_entry_by_idempotency_key(
            f"{reservation.idempotency_key}:{target.value}:{terminal_event.value}",
            scope=reservation.scope,
        )
        if entry is None:
            raise AIUsageTransitionConflict("reconciliation evidence is missing")
        if provider_cost is not None and entry.provider_cost != provider_cost:
            raise AIUsageTransitionConflict("provider cost evidence conflicts with prior replay")
        if reason is not None and entry.reason != reason:
            raise AIUsageTransitionConflict("reconciliation reason conflicts with prior replay")

    async def _active_entitlement(
        self,
        *,
        scope: AIUsageScope,
        action: AIUsageAction,
        billing_mode: AIUsageBillingMode,
        now: datetime,
    ) -> AIEntitlement | None:
        entitlements = await self._store.list_entitlements(
            scope=scope,
            action=action,
            limit=100,
        )
        for entitlement in entitlements:
            if entitlement.billing_mode is not billing_mode:
                continue
            if entitlement.status is not AIEntitlementStatus.ACTIVE:
                continue
            if entitlement.valid_from > now:
                continue
            if entitlement.expires_at is not None and entitlement.expires_at <= now:
                continue
            return entitlement
        return None

    async def _required_reservation(
        self,
        reservation_id: str,
        *,
        scope: AIUsageScope,
    ) -> AIUsageReservation:
        reservation = await self._store.get_reservation(reservation_id, scope=scope)
        if reservation is None:
            raise AIUsageTransitionConflict("reservation not found in scope")
        return reservation

    async def _required_entitlement(
        self,
        reservation: AIUsageReservation,
    ) -> AIEntitlement:
        entitlement = await self._store.get_entitlement(
            reservation.entitlement_id or "",
            scope=reservation.scope,
        )
        if entitlement is None:
            raise AIUsageTransitionConflict("reservation entitlement not found in scope")
        return entitlement

    def _ledger_entry(
        self,
        *,
        reservation: AIUsageReservation,
        event: AIUsageLedgerEvent,
        units: Decimal,
        idempotency_key: str,
        created_at: datetime,
        provider_cost: ProviderCostMetadata | None = None,
        reason: str | None = None,
    ) -> AIUsageLedgerEntry:
        return AIUsageLedgerEntry(
            entry_id=self._id_factory(),
            idempotency_key=idempotency_key,
            reservation_id=reservation.reservation_id,
            scope=reservation.scope,
            action=reservation.action,
            billing_mode=reservation.billing_mode,
            event=event,
            units=units,
            provider_cost=provider_cost,
            job_id=reservation.job_id,
            reason=reason,
            created_at=created_at,
        )

    def _now(self) -> datetime:
        now = self._clock()
        if now.tzinfo is None or now.utcoffset() is None:
            raise ValueError("AI usage service clock must return a timezone-aware datetime")
        return now


def _billing_mode(action: AIUsageAction) -> AIUsageBillingMode:
    if action is AIUsageAction.BYOK_METADATA:
        return AIUsageBillingMode.BYOK
    return AIUsageBillingMode.MANAGED


def _matching_reservation(
    reservation: AIUsageReservation,
    *,
    action: AIUsageAction,
    units: Decimal,
    provider: str | None,
    model: str | None,
    job_id: str | None,
) -> AIUsageReservation:
    if (
        reservation.action is not action
        or reservation.units != units
        or reservation.provider != provider
        or reservation.model != model
        or reservation.job_id != job_id
    ):
        raise AIUsageTransitionConflict(
            "idempotency key belongs to a different reservation request"
        )
    return reservation


def _same_ledger_operation(
    stored: AIUsageLedgerEntry,
    incoming: AIUsageLedgerEntry,
) -> bool:
    excluded = {"entry_id", "created_at"}
    return stored.model_dump(exclude=excluded) == incoming.model_dump(exclude=excluded)


def _replace_entitlement(
    entitlement: AIEntitlement,
    **changes: object,
) -> AIEntitlement:
    return AIEntitlement.model_validate({**entitlement.model_dump(), **changes})


def _replace_reservation(
    reservation: AIUsageReservation,
    **changes: object,
) -> AIUsageReservation:
    return AIUsageReservation.model_validate({**reservation.model_dump(), **changes})


def _settled_entitlement_values(
    *,
    entitlement: AIEntitlement,
    reservation: AIUsageReservation,
    balance_bucket: str,
) -> dict[str, Decimal]:
    if reservation.status is AIUsageReservationStatus.CONSUMED:
        reserved = entitlement.unit_reserved
        consumed = entitlement.unit_consumed
    else:
        reserved = entitlement.unit_reserved - reservation.units
        consumed = entitlement.unit_consumed
    if reserved < 0:
        raise AIUsageTransitionConflict("reservation would make reserved units negative")
    if balance_bucket == "consumed":
        consumed += reservation.units
    elif (
        balance_bucket == "refunded"
        and reservation.status is AIUsageReservationStatus.CONSUMED
    ):
        consumed -= reservation.units
    elif balance_bucket not in {"released", "refunded"}:
        raise ValueError("unknown settlement balance bucket")
    if consumed < 0:
        raise AIUsageTransitionConflict("refund would make consumed units negative")
    return {"unit_reserved": reserved, "unit_consumed": consumed}


def _settlement_event(target: AIUsageReservationStatus) -> AIUsageLedgerEvent:
    return {
        AIUsageReservationStatus.CONSUMED: AIUsageLedgerEvent.CONSUMED,
        AIUsageReservationStatus.RELEASED: AIUsageLedgerEvent.RELEASED,
        AIUsageReservationStatus.REFUNDED: AIUsageLedgerEvent.REFUNDED,
        AIUsageReservationStatus.EXPIRED: AIUsageLedgerEvent.EXPIRED,
    }[target]


def _require_transition(
    current: AIUsageReservationStatus,
    target: AIUsageReservationStatus,
) -> None:
    try:
        validate_reservation_transition(current, target)
    except ValueError as exc:
        raise AIUsageTransitionConflict(str(exc)) from exc
