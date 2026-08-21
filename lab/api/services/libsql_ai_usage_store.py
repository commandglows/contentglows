"""libSQL adapter for the persistence-agnostic AI usage store port."""

from __future__ import annotations

import json
from typing import Any, AsyncContextManager, Protocol

from api.models.ai_usage import (
    AIEntitlement,
    AIUsageAction,
    AIUsageLedgerEntry,
    AIUsageLedgerEvent,
    AIUsageReservation,
    AIUsageReservationStatus,
    AIUsageScope,
)
from api.services.ai_usage_store import AIUsageMutation, AIUsageStoreConflictError


class AsyncSQLResult(Protocol):
    rows: list[tuple[Any, ...]]


class AsyncSQLClient(Protocol):
    async def execute(
        self,
        statement: str,
        args: list[Any] | tuple[Any, ...] | None = None,
    ) -> AsyncSQLResult:
        ...

    def transaction(self) -> AsyncContextManager["AsyncSQLTransaction"]:
        ...


class AsyncSQLTransaction(Protocol):
    async def execute(
        self,
        statement: str,
        args: list[Any] | tuple[Any, ...] | None = None,
    ) -> AsyncSQLResult:
        ...


_SCHEMA_STATEMENTS = (
    """
    CREATE TABLE IF NOT EXISTS ai_entitlements (
        entitlement_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        org_id TEXT,
        billing_mode TEXT NOT NULL,
        status TEXT NOT NULL,
        actions_json TEXT NOT NULL,
        valid_from TEXT NOT NULL,
        expires_at TEXT,
        payload_json TEXT NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_ai_entitlements_scope
    ON ai_entitlements(user_id, project_id, org_id, status, valid_from)
    """,
    """
    CREATE TABLE IF NOT EXISTS ai_usage_reservations (
        reservation_id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        entitlement_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        org_id TEXT,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        job_id TEXT,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_ai_reservations_scope
    ON ai_usage_reservations(user_id, project_id, org_id, status, created_at)
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_ai_reservations_entitlement
    ON ai_usage_reservations(entitlement_id, status, expires_at)
    """,
    """
    CREATE TABLE IF NOT EXISTS ai_usage_ledger (
        entry_id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        reservation_id TEXT,
        user_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        org_id TEXT,
        action TEXT NOT NULL,
        billing_mode TEXT NOT NULL,
        event TEXT NOT NULL,
        job_id TEXT,
        created_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_ai_usage_ledger_scope
    ON ai_usage_ledger(user_id, project_id, org_id, event, created_at)
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_ai_usage_ledger_reservation
    ON ai_usage_ledger(reservation_id, created_at)
    """,
    """
    CREATE TABLE IF NOT EXISTS ai_provider_costs (
        entry_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        org_id TEXT,
        provider TEXT NOT NULL,
        provider_action TEXT NOT NULL,
        provider_request_id TEXT,
        confidence TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_ai_provider_costs_scope
    ON ai_provider_costs(user_id, project_id, org_id, captured_at)
    """,
    """
    CREATE TABLE IF NOT EXISTS ai_admin_adjustments (
        entry_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        org_id TEXT,
        actor_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        unit_direction TEXT NOT NULL,
        units TEXT NOT NULL,
        created_at TEXT NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_ai_admin_adjustments_scope
    ON ai_admin_adjustments(user_id, project_id, org_id, created_at)
    """,
)

_ATOMIC_LEDGER_EVENTS = frozenset(
    {
        AIUsageLedgerEvent.RESERVED,
        AIUsageLedgerEvent.PROVIDER_STARTED,
        AIUsageLedgerEvent.CONSUMED,
        AIUsageLedgerEvent.RELEASED,
        AIUsageLedgerEvent.REFUNDED,
        AIUsageLedgerEvent.EXPIRED,
    }
)


class LibsqlAIUsageStore:
    """Infrastructure adapter backed by an injected libSQL-compatible client."""

    def __init__(self, *, db_client: AsyncSQLClient) -> None:
        self._db_client = db_client

    async def ensure_schema(self) -> None:
        """Create the adapter-owned schema without leaking it into the domain port."""
        for statement in _SCHEMA_STATEMENTS:
            await self._db_client.execute(statement)

    async def save_entitlement(self, entitlement: AIEntitlement) -> AIEntitlement:
        scope = entitlement.scope
        existing = await self._entitlement_by_id(entitlement.entitlement_id)
        if existing is not None and existing.scope != scope:
            raise AIUsageStoreConflictError(
                "entitlement id already belongs to a different scope"
            )
        if existing is not None and (
            existing.unit_reserved != entitlement.unit_reserved
            or existing.unit_consumed != entitlement.unit_consumed
        ):
            raise AIUsageStoreConflictError(
                "entitlement usage counters require an atomic mutation"
            )
        await self._db_client.execute(
            """
            INSERT INTO ai_entitlements (
                entitlement_id, user_id, project_id, org_id, billing_mode, status,
                actions_json, valid_from, expires_at, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(entitlement_id) DO UPDATE SET
                user_id = excluded.user_id,
                project_id = excluded.project_id,
                org_id = excluded.org_id,
                billing_mode = excluded.billing_mode,
                status = excluded.status,
                actions_json = excluded.actions_json,
                valid_from = excluded.valid_from,
                expires_at = excluded.expires_at,
                payload_json = excluded.payload_json
            WHERE ai_entitlements.user_id = excluded.user_id
              AND ai_entitlements.project_id = excluded.project_id
              AND (
                  (ai_entitlements.org_id IS NULL AND excluded.org_id IS NULL)
                  OR ai_entitlements.org_id = excluded.org_id
              )
            """,
            [
                entitlement.entitlement_id,
                scope.user_id,
                scope.project_id,
                scope.org_id,
                entitlement.billing_mode.value,
                entitlement.status.value,
                _json_value([action.value for action in entitlement.actions]),
                entitlement.valid_from.isoformat(),
                _optional_iso(entitlement.expires_at),
                entitlement.model_dump_json(),
            ],
        )
        saved = await self.get_entitlement(entitlement.entitlement_id, scope=scope)
        if saved != entitlement:
            raise AIUsageStoreConflictError(
                "entitlement id already belongs to a different scope"
            )
        return saved

    async def get_entitlement(
        self,
        entitlement_id: str,
        *,
        scope: AIUsageScope,
    ) -> AIEntitlement | None:
        result = await self._db_client.execute(
            """
            SELECT payload_json FROM ai_entitlements
            WHERE entitlement_id = ? AND user_id = ? AND project_id = ?
              AND ((org_id IS NULL AND ? IS NULL) OR org_id = ?)
            """,
            [entitlement_id, scope.user_id, scope.project_id, scope.org_id, scope.org_id],
        )
        return _one_model(result.rows, AIEntitlement)

    async def list_entitlements(
        self,
        *,
        scope: AIUsageScope,
        action: AIUsageAction | None = None,
        limit: int = 100,
    ) -> list[AIEntitlement]:
        _validate_limit(limit)
        action_filter = f'%"{action.value}"%' if action is not None else None
        result = await self._db_client.execute(
            """
            SELECT payload_json FROM ai_entitlements
            WHERE user_id = ? AND project_id = ?
              AND ((org_id IS NULL AND ? IS NULL) OR org_id = ?)
              AND (? IS NULL OR actions_json LIKE ?)
            ORDER BY valid_from DESC LIMIT ?
            """,
            [
                scope.user_id,
                scope.project_id,
                scope.org_id,
                scope.org_id,
                action_filter,
                action_filter,
                limit,
            ],
        )
        return _models(result.rows, AIEntitlement)

    async def get_reservation(
        self,
        reservation_id: str,
        *,
        scope: AIUsageScope,
    ) -> AIUsageReservation | None:
        result = await self._db_client.execute(
            """
            SELECT payload_json FROM ai_usage_reservations
            WHERE reservation_id = ? AND user_id = ? AND project_id = ?
              AND ((org_id IS NULL AND ? IS NULL) OR org_id = ?)
            """,
            [reservation_id, scope.user_id, scope.project_id, scope.org_id, scope.org_id],
        )
        return _one_model(result.rows, AIUsageReservation)

    async def get_reservation_by_idempotency_key(
        self,
        idempotency_key: str,
        *,
        scope: AIUsageScope,
    ) -> AIUsageReservation | None:
        reservation = await self._reservation_by_idempotency_key(idempotency_key)
        if reservation is None or reservation.scope != scope:
            return None
        return reservation

    async def list_reservations(
        self,
        *,
        scope: AIUsageScope,
        status: AIUsageReservationStatus | None = None,
        limit: int = 100,
    ) -> list[AIUsageReservation]:
        _validate_limit(limit)
        result = await self._db_client.execute(
            """
            SELECT payload_json FROM ai_usage_reservations
            WHERE user_id = ? AND project_id = ?
              AND ((org_id IS NULL AND ? IS NULL) OR org_id = ?)
              AND (? IS NULL OR status = ?)
            ORDER BY created_at DESC LIMIT ?
            """,
            [
                scope.user_id,
                scope.project_id,
                scope.org_id,
                scope.org_id,
                status.value if status else None,
                status.value if status else None,
                limit,
            ],
        )
        return _models(result.rows, AIUsageReservation)

    async def append_ledger_entry(
        self,
        entry: AIUsageLedgerEntry,
    ) -> AIUsageLedgerEntry:
        if entry.event in _ATOMIC_LEDGER_EVENTS:
            raise AIUsageStoreConflictError(
                "reservation state events require an atomic mutation"
            )
        existing = await self._ledger_by_idempotency_key(entry.idempotency_key)
        if existing is not None:
            stored = _same_or_conflict(existing, entry, "ledger entry")
            await self._repair_ledger_projections(stored)
            return stored
        if entry.reservation_id is not None:
            reservation = await self.get_reservation(
                entry.reservation_id,
                scope=entry.scope,
            )
            if reservation is None:
                raise AIUsageStoreConflictError(
                    "ledger reservation does not exist in the same scope"
                )
        scope = entry.scope
        try:
            await self._db_client.execute(
                """
                INSERT INTO ai_usage_ledger (
                    entry_id, idempotency_key, reservation_id, user_id, project_id,
                    org_id, action, billing_mode, event, job_id, created_at, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    entry.entry_id,
                    entry.idempotency_key,
                    entry.reservation_id,
                    scope.user_id,
                    scope.project_id,
                    scope.org_id,
                    entry.action.value,
                    entry.billing_mode.value,
                    entry.event.value,
                    entry.job_id,
                    entry.created_at.isoformat(),
                    entry.model_dump_json(),
                ],
            )
        except Exception:
            existing = await self._ledger_by_idempotency_key(entry.idempotency_key)
            if existing is not None:
                stored = _same_or_conflict(existing, entry, "ledger entry")
                await self._repair_ledger_projections(stored)
                return stored
            identity_owner = await self._ledger_by_id(entry.entry_id)
            if identity_owner is not None:
                raise AIUsageStoreConflictError(
                    "ledger entry id already belongs to a different record"
                ) from None
            raise
        await self._repair_ledger_projections(entry)
        return entry

    async def apply_mutation(self, mutation: AIUsageMutation) -> AIUsageMutation:
        if await self._mutation_already_applied(mutation):
            return mutation
        try:
            async with self._db_client.transaction() as transaction:
                await self._apply_entitlement_change(transaction, mutation)
                await self._apply_reservation_change(transaction, mutation)
                for entry in mutation.ledger_entries:
                    await self._insert_ledger_entry(transaction, entry)
                    await self._insert_ledger_projections(transaction, entry)
        except Exception:
            if await self._mutation_already_applied(mutation):
                return mutation
            raise
        return mutation

    async def list_ledger_entries(
        self,
        *,
        scope: AIUsageScope,
        event: AIUsageLedgerEvent | None = None,
        limit: int = 100,
    ) -> list[AIUsageLedgerEntry]:
        _validate_limit(limit)
        result = await self._db_client.execute(
            """
            SELECT payload_json FROM ai_usage_ledger
            WHERE user_id = ? AND project_id = ?
              AND ((org_id IS NULL AND ? IS NULL) OR org_id = ?)
              AND (? IS NULL OR event = ?)
            ORDER BY created_at DESC LIMIT ?
            """,
            [
                scope.user_id,
                scope.project_id,
                scope.org_id,
                scope.org_id,
                event.value if event else None,
                event.value if event else None,
                limit,
            ],
        )
        return _models(result.rows, AIUsageLedgerEntry)

    async def get_ledger_entry_by_idempotency_key(
        self,
        idempotency_key: str,
        *,
        scope: AIUsageScope,
    ) -> AIUsageLedgerEntry | None:
        entry = await self._ledger_by_idempotency_key(idempotency_key)
        if entry is None or entry.scope != scope:
            return None
        return entry

    async def list_provider_cost_entries(
        self,
        *,
        scope: AIUsageScope,
        limit: int = 100,
    ) -> list[AIUsageLedgerEntry]:
        _validate_limit(limit)
        result = await self._db_client.execute(
            """
            SELECT ledger.payload_json
            FROM ai_provider_costs AS costs
            JOIN ai_usage_ledger AS ledger ON ledger.entry_id = costs.entry_id
            WHERE costs.user_id = ? AND costs.project_id = ?
              AND ((costs.org_id IS NULL AND ? IS NULL) OR costs.org_id = ?)
            ORDER BY costs.captured_at DESC LIMIT ?
            """,
            [scope.user_id, scope.project_id, scope.org_id, scope.org_id, limit],
        )
        return _models(result.rows, AIUsageLedgerEntry)

    async def list_admin_adjustments(
        self,
        *,
        scope: AIUsageScope,
        limit: int = 100,
    ) -> list[AIUsageLedgerEntry]:
        _validate_limit(limit)
        result = await self._db_client.execute(
            """
            SELECT ledger.payload_json
            FROM ai_admin_adjustments AS adjustments
            JOIN ai_usage_ledger AS ledger ON ledger.entry_id = adjustments.entry_id
            WHERE adjustments.user_id = ? AND adjustments.project_id = ?
              AND ((adjustments.org_id IS NULL AND ? IS NULL) OR adjustments.org_id = ?)
            ORDER BY adjustments.created_at DESC LIMIT ?
            """,
            [scope.user_id, scope.project_id, scope.org_id, scope.org_id, limit],
        )
        return _models(result.rows, AIUsageLedgerEntry)

    async def _reservation_by_idempotency_key(
        self,
        idempotency_key: str,
    ) -> AIUsageReservation | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM ai_usage_reservations WHERE idempotency_key = ?",
            [idempotency_key],
        )
        return _one_model(result.rows, AIUsageReservation)

    async def _apply_entitlement_change(
        self,
        transaction: AsyncSQLTransaction,
        mutation: AIUsageMutation,
    ) -> None:
        before = mutation.entitlement_before
        after = mutation.entitlement_after
        if before is None or after is None:
            return
        await transaction.execute(
            """
            UPDATE ai_entitlements SET
                billing_mode = ?, status = ?, actions_json = ?, valid_from = ?,
                expires_at = ?, payload_json = ?
            WHERE entitlement_id = ? AND user_id = ? AND project_id = ?
              AND ((org_id IS NULL AND ? IS NULL) OR org_id = ?)
              AND payload_json = ?
            """,
            [
                after.billing_mode.value,
                after.status.value,
                _json_value([action.value for action in after.actions]),
                after.valid_from.isoformat(),
                _optional_iso(after.expires_at),
                after.model_dump_json(),
                before.entitlement_id,
                before.scope.user_id,
                before.scope.project_id,
                before.scope.org_id,
                before.scope.org_id,
                before.model_dump_json(),
            ],
        )
        if not await _changed_exactly_once(transaction):
            raise AIUsageStoreConflictError("entitlement state changed concurrently")

    async def _apply_reservation_change(
        self,
        transaction: AsyncSQLTransaction,
        mutation: AIUsageMutation,
    ) -> None:
        before = mutation.reservation_before
        after = mutation.reservation_after
        if after is None:
            return
        if before is None:
            await transaction.execute(
                """
                INSERT INTO ai_usage_reservations (
                    reservation_id, idempotency_key, entitlement_id, user_id,
                    project_id, org_id, action, status, job_id, expires_at,
                    created_at, updated_at, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                _reservation_values(after),
            )
            return
        await transaction.execute(
            """
            UPDATE ai_usage_reservations SET
                status = ?, job_id = ?, expires_at = ?, updated_at = ?,
                payload_json = ?
            WHERE reservation_id = ? AND user_id = ? AND project_id = ?
              AND ((org_id IS NULL AND ? IS NULL) OR org_id = ?)
              AND payload_json = ?
            """,
            [
                after.status.value,
                after.job_id,
                after.expires_at.isoformat(),
                after.updated_at.isoformat(),
                after.model_dump_json(),
                before.reservation_id,
                before.scope.user_id,
                before.scope.project_id,
                before.scope.org_id,
                before.scope.org_id,
                before.model_dump_json(),
            ],
        )
        if not await _changed_exactly_once(transaction):
            raise AIUsageStoreConflictError("reservation state changed concurrently")

    async def _insert_ledger_entry(
        self,
        transaction: AsyncSQLTransaction,
        entry: AIUsageLedgerEntry,
    ) -> None:
        scope = entry.scope
        await transaction.execute(
            """
            INSERT INTO ai_usage_ledger (
                entry_id, idempotency_key, reservation_id, user_id, project_id,
                org_id, action, billing_mode, event, job_id, created_at, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                entry.entry_id,
                entry.idempotency_key,
                entry.reservation_id,
                scope.user_id,
                scope.project_id,
                scope.org_id,
                entry.action.value,
                entry.billing_mode.value,
                entry.event.value,
                entry.job_id,
                entry.created_at.isoformat(),
                entry.model_dump_json(),
            ],
        )

    async def _insert_ledger_projections(
        self,
        transaction: AsyncSQLTransaction,
        entry: AIUsageLedgerEntry,
    ) -> None:
        scope = entry.scope
        cost = entry.provider_cost
        if cost is not None:
            await transaction.execute(
                """
                INSERT INTO ai_provider_costs (
                    entry_id, user_id, project_id, org_id, provider,
                    provider_action, provider_request_id, confidence,
                    captured_at, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    entry.entry_id,
                    scope.user_id,
                    scope.project_id,
                    scope.org_id,
                    cost.provider,
                    cost.provider_action,
                    cost.provider_request_id,
                    cost.confidence.value,
                    cost.captured_at.isoformat(),
                    cost.model_dump_json(),
                ],
            )
        if entry.event is AIUsageLedgerEvent.ADMIN_ADJUSTMENT:
            if entry.actor_id is None or entry.reason is None or entry.unit_direction is None:
                raise ValueError("admin adjustment is missing its audit fields")
            await transaction.execute(
                """
                INSERT INTO ai_admin_adjustments (
                    entry_id, user_id, project_id, org_id, actor_id, reason,
                    unit_direction, units, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    entry.entry_id,
                    scope.user_id,
                    scope.project_id,
                    scope.org_id,
                    entry.actor_id,
                    entry.reason,
                    entry.unit_direction.value,
                    str(entry.units),
                    entry.created_at.isoformat(),
                ],
            )

    async def _mutation_already_applied(self, mutation: AIUsageMutation) -> bool:
        stored_entries = [
            await self._ledger_by_idempotency_key(entry.idempotency_key)
            for entry in mutation.ledger_entries
        ]
        if not stored_entries or any(entry is None for entry in stored_entries):
            return False
        if any(
            not _same_ledger_operation(stored, incoming)
            for stored, incoming in zip(stored_entries, mutation.ledger_entries)
        ):
            raise AIUsageStoreConflictError(
                "mutation idempotency key belongs to a different ledger entry"
            )
        if mutation.entitlement_after is not None:
            stored_entitlement = await self._entitlement_by_id(
                mutation.entitlement_after.entitlement_id
            )
            if stored_entitlement != mutation.entitlement_after:
                return False
        if mutation.reservation_after is not None:
            stored_reservation = await self._reservation_by_id(
                mutation.reservation_after.reservation_id
            )
            if stored_reservation != mutation.reservation_after:
                return False
        return True

    async def _reservation_by_id(
        self,
        reservation_id: str,
    ) -> AIUsageReservation | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM ai_usage_reservations WHERE reservation_id = ?",
            [reservation_id],
        )
        return _one_model(result.rows, AIUsageReservation)

    async def _entitlement_by_id(self, entitlement_id: str) -> AIEntitlement | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM ai_entitlements WHERE entitlement_id = ?",
            [entitlement_id],
        )
        return _one_model(result.rows, AIEntitlement)

    async def _ledger_by_idempotency_key(
        self,
        idempotency_key: str,
    ) -> AIUsageLedgerEntry | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM ai_usage_ledger WHERE idempotency_key = ?",
            [idempotency_key],
        )
        return _one_model(result.rows, AIUsageLedgerEntry)

    async def _ledger_by_id(self, entry_id: str) -> AIUsageLedgerEntry | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM ai_usage_ledger WHERE entry_id = ?",
            [entry_id],
        )
        return _one_model(result.rows, AIUsageLedgerEntry)

    async def _save_provider_cost(self, entry: AIUsageLedgerEntry) -> None:
        cost = entry.provider_cost
        if cost is None:
            return
        scope = entry.scope
        await self._db_client.execute(
            """
            INSERT INTO ai_provider_costs (
                entry_id, user_id, project_id, org_id, provider, provider_action,
                provider_request_id, confidence, captured_at, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(entry_id) DO NOTHING
            """,
            [
                entry.entry_id,
                scope.user_id,
                scope.project_id,
                scope.org_id,
                cost.provider,
                cost.provider_action,
                cost.provider_request_id,
                cost.confidence.value,
                cost.captured_at.isoformat(),
                cost.model_dump_json(),
            ],
        )

    async def _repair_ledger_projections(self, entry: AIUsageLedgerEntry) -> None:
        """Complete derived indexes safely after an interrupted append retry."""
        if entry.provider_cost is not None:
            await self._save_provider_cost(entry)
        if entry.event is AIUsageLedgerEvent.ADMIN_ADJUSTMENT:
            await self._save_admin_adjustment(entry)

    async def _save_admin_adjustment(self, entry: AIUsageLedgerEntry) -> None:
        if entry.actor_id is None or entry.reason is None or entry.unit_direction is None:
            raise ValueError("admin adjustment is missing its audit fields")
        scope = entry.scope
        await self._db_client.execute(
            """
            INSERT INTO ai_admin_adjustments (
                entry_id, user_id, project_id, org_id, actor_id, reason,
                unit_direction, units, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(entry_id) DO NOTHING
            """,
            [
                entry.entry_id,
                scope.user_id,
                scope.project_id,
                scope.org_id,
                entry.actor_id,
                entry.reason,
                entry.unit_direction.value,
                str(entry.units),
                entry.created_at.isoformat(),
            ],
        )


def _validate_limit(limit: int) -> None:
    if limit < 1 or limit > 500:
        raise ValueError("limit must be between 1 and 500")


def _optional_iso(value: Any | None) -> str | None:
    return value.isoformat() if value is not None else None


def _json_value(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)


def _reservation_values(reservation: AIUsageReservation) -> list[Any]:
    scope = reservation.scope
    return [
        reservation.reservation_id,
        reservation.idempotency_key,
        reservation.entitlement_id,
        scope.user_id,
        scope.project_id,
        scope.org_id,
        reservation.action.value,
        reservation.status.value,
        reservation.job_id,
        reservation.expires_at.isoformat(),
        reservation.created_at.isoformat(),
        reservation.updated_at.isoformat(),
        reservation.model_dump_json(),
    ]


async def _changed_exactly_once(transaction: AsyncSQLTransaction) -> bool:
    result = await transaction.execute("SELECT changes()")
    return bool(result.rows and int(result.rows[0][0]) == 1)


def _models(rows: list[tuple[Any, ...]], model: Any) -> list[Any]:
    return [model.model_validate_json(row[0]) for row in rows]


def _one_model(rows: list[tuple[Any, ...]], model: Any) -> Any | None:
    if not rows:
        return None
    return model.model_validate_json(rows[0][0])


def _same_or_conflict(stored: Any, incoming: Any, label: str) -> Any:
    if stored == incoming:
        return stored
    raise AIUsageStoreConflictError(
        f"idempotency key already belongs to a different {label}"
    )


def _same_ledger_operation(
    stored: AIUsageLedgerEntry | None,
    incoming: AIUsageLedgerEntry,
) -> bool:
    if stored is None:
        return False
    excluded = {"entry_id", "created_at"}
    return stored.model_dump(exclude=excluded) == incoming.model_dump(exclude=excluded)
