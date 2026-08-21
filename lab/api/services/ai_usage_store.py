"""Persistence-agnostic port for AI usage, entitlement, and quota records."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol, runtime_checkable

from api.models.ai_usage import (
    AIEntitlement,
    AIUsageAction,
    AIUsageLedgerEntry,
    AIUsageLedgerEvent,
    AIUsageReservation,
    AIUsageReservationStatus,
    AIUsageScope,
    validate_reservation_transition,
)


class AIUsageStoreError(RuntimeError):
    """Base error exposed by every AI usage store implementation."""


class AIUsageStoreConflictError(AIUsageStoreError):
    """Raised when a durable identity is reused for a different record."""


@dataclass(frozen=True)
class AIUsageMutation:
    """One atomic compare-and-set change expressed only in domain models."""

    ledger_entries: tuple[AIUsageLedgerEntry, ...]
    entitlement_before: AIEntitlement | None = None
    entitlement_after: AIEntitlement | None = None
    reservation_before: AIUsageReservation | None = None
    reservation_after: AIUsageReservation | None = None

    def __post_init__(self) -> None:
        if not self.ledger_entries:
            raise ValueError("an AI usage mutation requires at least one ledger entry")
        if len({entry.idempotency_key for entry in self.ledger_entries}) != len(
            self.ledger_entries
        ):
            raise ValueError("ledger idempotency keys must be unique within a mutation")
        if len({entry.entry_id for entry in self.ledger_entries}) != len(
            self.ledger_entries
        ):
            raise ValueError("ledger entry ids must be unique within a mutation")
        if (self.entitlement_before is None) != (self.entitlement_after is None):
            raise ValueError("entitlement compare-and-set requires before and after states")
        if self.reservation_before is not None and self.reservation_after is None:
            raise ValueError("reservation compare-and-set requires an after state")
        if (
            self.reservation_before is None
            and self.reservation_after is not None
            and self.entitlement_before is None
        ):
            raise ValueError("reservation creation requires an entitlement mutation")
        if self.entitlement_before is not None and self.entitlement_after is not None:
            if self.entitlement_before.entitlement_id != self.entitlement_after.entitlement_id:
                raise ValueError("an entitlement mutation cannot change identity")
            if self.entitlement_before.scope != self.entitlement_after.scope:
                raise ValueError("an entitlement mutation cannot change scope")
            mutable_entitlement_fields = {"unit_reserved", "unit_consumed"}
            if self.entitlement_before.model_dump(
                exclude=mutable_entitlement_fields
            ) != self.entitlement_after.model_dump(exclude=mutable_entitlement_fields):
                raise ValueError(
                    "an atomic usage mutation may only change entitlement counters"
                )
        if self.reservation_before is not None and self.reservation_after is not None:
            if self.reservation_before.reservation_id != self.reservation_after.reservation_id:
                raise ValueError("a reservation mutation cannot change identity")
            if self.reservation_before.scope != self.reservation_after.scope:
                raise ValueError("a reservation mutation cannot change scope")
            mutable_reservation_fields = {
                "status",
                "job_id",
                "updated_at",
                "provider_started_at",
            }
            if self.reservation_before.model_dump(
                exclude=mutable_reservation_fields
            ) != self.reservation_after.model_dump(exclude=mutable_reservation_fields):
                raise ValueError("a reservation transition changed immutable fields")
            if self.reservation_before.status is not self.reservation_after.status:
                validate_reservation_transition(
                    self.reservation_before.status,
                    self.reservation_after.status,
                )
        elif (
            self.reservation_after is not None
            and self.reservation_after.status is not AIUsageReservationStatus.RESERVED
        ):
            raise ValueError("a new reservation must start in reserved state")
        if self.entitlement_after is not None and self.reservation_after is not None:
            if self.reservation_after.entitlement_id != self.entitlement_after.entitlement_id:
                raise ValueError("reservation and entitlement identities must match")

        scope = self.ledger_entries[0].scope
        if any(entry.scope != scope for entry in self.ledger_entries):
            raise ValueError("all ledger entries in a mutation must share one scope")
        for record in (
            self.entitlement_before,
            self.entitlement_after,
            self.reservation_before,
            self.reservation_after,
        ):
            if record is not None and record.scope != scope:
                raise ValueError("all mutation records must share one scope")
        if self.reservation_after is not None:
            for entry in self.ledger_entries:
                if entry.reservation_id != self.reservation_after.reservation_id:
                    raise ValueError(
                        "reservation mutations require ledger entries for that reservation"
                    )
        _validate_balance_and_ledger(self)


@runtime_checkable
class AIUsageStore(Protocol):
    """Domain port for durable AI usage state.

    Implementations may use any durable backend or an in-memory test double.
    Callers only exchange validated domain models and never depend on storage
    records, provider SDKs, or infrastructure clients.
    """

    async def save_entitlement(self, entitlement: AIEntitlement) -> AIEntitlement:
        ...

    async def get_entitlement(
        self,
        entitlement_id: str,
        *,
        scope: AIUsageScope,
    ) -> AIEntitlement | None:
        ...

    async def list_entitlements(
        self,
        *,
        scope: AIUsageScope,
        action: AIUsageAction | None = None,
        limit: int = 100,
    ) -> list[AIEntitlement]:
        ...

    async def get_reservation(
        self,
        reservation_id: str,
        *,
        scope: AIUsageScope,
    ) -> AIUsageReservation | None:
        ...

    async def get_reservation_by_idempotency_key(
        self,
        idempotency_key: str,
        *,
        scope: AIUsageScope,
    ) -> AIUsageReservation | None:
        ...

    async def list_reservations(
        self,
        *,
        scope: AIUsageScope,
        status: AIUsageReservationStatus | None = None,
        limit: int = 100,
    ) -> list[AIUsageReservation]:
        ...

    async def append_ledger_entry(
        self,
        entry: AIUsageLedgerEntry,
    ) -> AIUsageLedgerEntry:
        """Append non-state evidence; reservation transitions use apply_mutation."""
        ...

    async def apply_mutation(self, mutation: AIUsageMutation) -> AIUsageMutation:
        ...

    async def list_ledger_entries(
        self,
        *,
        scope: AIUsageScope,
        event: AIUsageLedgerEvent | None = None,
        limit: int = 100,
    ) -> list[AIUsageLedgerEntry]:
        ...

    async def get_ledger_entry_by_idempotency_key(
        self,
        idempotency_key: str,
        *,
        scope: AIUsageScope,
    ) -> AIUsageLedgerEntry | None:
        ...

    async def list_provider_cost_entries(
        self,
        *,
        scope: AIUsageScope,
        limit: int = 100,
    ) -> list[AIUsageLedgerEntry]:
        ...

    async def list_admin_adjustments(
        self,
        *,
        scope: AIUsageScope,
        limit: int = 100,
    ) -> list[AIUsageLedgerEntry]:
        ...


def _validate_balance_and_ledger(mutation: AIUsageMutation) -> None:
    reservation = mutation.reservation_after
    if reservation is None:
        return
    events = {entry.event for entry in mutation.ledger_entries}
    before_entitlement = mutation.entitlement_before
    after_entitlement = mutation.entitlement_after
    before_reservation = mutation.reservation_before

    if before_reservation is None:
        if AIUsageLedgerEvent.RESERVED not in events:
            raise ValueError("reservation creation requires a reserved ledger event")
        _require_entitlement_delta(
            before_entitlement,
            after_entitlement,
            reserved_delta=reservation.units,
            consumed_delta=0,
        )
        return

    target = reservation.status
    expected_event = {
        AIUsageReservationStatus.PROVIDER_STARTED: AIUsageLedgerEvent.PROVIDER_STARTED,
        AIUsageReservationStatus.CONSUMED: AIUsageLedgerEvent.CONSUMED,
        AIUsageReservationStatus.RELEASED: AIUsageLedgerEvent.RELEASED,
        AIUsageReservationStatus.REFUNDED: AIUsageLedgerEvent.REFUNDED,
        AIUsageReservationStatus.EXPIRED: AIUsageLedgerEvent.EXPIRED,
    }.get(target)
    if expected_event is not None and expected_event not in events:
        raise ValueError(f"{target.value} transition requires a matching ledger event")
    if target is AIUsageReservationStatus.PROVIDER_STARTED:
        if before_entitlement is not None or after_entitlement is not None:
            raise ValueError("provider start must not change entitlement counters")
        return
    if target is AIUsageReservationStatus.CONSUMED:
        _require_entitlement_delta(
            before_entitlement,
            after_entitlement,
            reserved_delta=-reservation.units,
            consumed_delta=reservation.units,
        )
        return
    if target in {AIUsageReservationStatus.RELEASED, AIUsageReservationStatus.EXPIRED}:
        _require_entitlement_delta(
            before_entitlement,
            after_entitlement,
            reserved_delta=-reservation.units,
            consumed_delta=0,
        )
        return
    if target is AIUsageReservationStatus.REFUNDED:
        if before_reservation.status is AIUsageReservationStatus.CONSUMED:
            _require_entitlement_delta(
                before_entitlement,
                after_entitlement,
                reserved_delta=0,
                consumed_delta=-reservation.units,
            )
        else:
            _require_entitlement_delta(
                before_entitlement,
                after_entitlement,
                reserved_delta=-reservation.units,
                consumed_delta=0,
            )


def _require_entitlement_delta(
    before: AIEntitlement | None,
    after: AIEntitlement | None,
    *,
    reserved_delta: Decimal | int,
    consumed_delta: Decimal | int,
) -> None:
    if before is None or after is None:
        raise ValueError("reservation balance changes require entitlement states")
    if after.unit_reserved != before.unit_reserved + reserved_delta:
        raise ValueError("reservation mutation has an invalid reserved-unit delta")
    if after.unit_consumed != before.unit_consumed + consumed_delta:
        raise ValueError("reservation mutation has an invalid consumed-unit delta")
