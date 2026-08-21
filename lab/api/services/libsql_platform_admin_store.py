"""Injected-client libSQL adapter for platform authorization."""

from __future__ import annotations

from typing import Any, AsyncContextManager, Protocol

from api.models.platform_admin import (
    PlatformAdminAuditEvent,
    PlatformAdminAuditOutcome,
    PlatformAdminGrant,
)
from api.services.platform_admin_store import (
    PlatformAdminGrantMutation,
    PlatformAdminStoreConflictError,
    PlatformAdminStoreError,
)


class AsyncSQLResult(Protocol):
    rows: list[tuple[Any, ...]]


class AsyncSQLTransaction(Protocol):
    async def execute(
        self,
        statement: str,
        args: list[Any] | tuple[Any, ...] | None = None,
    ) -> AsyncSQLResult:
        ...


class AsyncSQLClient(Protocol):
    async def execute(
        self,
        statement: str,
        args: list[Any] | tuple[Any, ...] | None = None,
    ) -> AsyncSQLResult:
        ...

    def transaction(self) -> AsyncContextManager[AsyncSQLTransaction]:
        ...


_SCHEMA = (
    """
    CREATE TABLE IF NOT EXISTS platform_admin_grants (
        grant_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        version INTEGER NOT NULL,
        payload_json TEXT NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_platform_admin_grants_status
    ON platform_admin_grants(status, user_id)
    """,
    """
    CREATE TABLE IF NOT EXISTS platform_admin_audit (
        event_id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        actor_user_id TEXT NOT NULL,
        grant_id TEXT,
        capability TEXT NOT NULL,
        action TEXT NOT NULL,
        outcome TEXT NOT NULL,
        created_at TEXT NOT NULL,
        payload_json TEXT NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_platform_admin_audit_actor
    ON platform_admin_audit(actor_user_id, created_at)
    """,
)


class LibsqlPlatformAdminStore:
    def __init__(self, *, db_client: AsyncSQLClient) -> None:
        self._db_client = db_client

    async def ensure_schema(self) -> None:
        for statement in _SCHEMA:
            await self._db_client.execute(statement)

    async def get_grant(self, grant_id: str) -> PlatformAdminGrant | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM platform_admin_grants WHERE grant_id = ?",
            [grant_id],
        )
        return self._one(result.rows, PlatformAdminGrant)

    async def get_grant_by_user(self, user_id: str) -> PlatformAdminGrant | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM platform_admin_grants WHERE user_id = ?",
            [user_id],
        )
        return self._one(result.rows, PlatformAdminGrant)

    async def append_audit_event(
        self,
        event: PlatformAdminAuditEvent,
    ) -> PlatformAdminAuditEvent:
        if event.outcome is PlatformAdminAuditOutcome.ALLOWED:
            raise PlatformAdminStoreConflictError(
                "allowed audit evidence requires an atomic domain mutation"
            )
        existing = await self.get_audit_event_by_idempotency_key(event.idempotency_key)
        if existing is not None:
            if existing != event:
                raise PlatformAdminStoreConflictError(
                    "admin audit idempotency key belongs to another event"
                )
            return existing
        try:
            await self._db_client.execute(
                """
                INSERT INTO platform_admin_audit (
                    event_id, idempotency_key, actor_user_id, grant_id,
                    capability, action, outcome, created_at, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    event.event_id,
                    event.idempotency_key,
                    event.actor_user_id,
                    event.grant_id,
                    event.capability.value,
                    event.action,
                    event.outcome.value,
                    event.created_at.isoformat(),
                    event.model_dump_json(),
                ],
            )
        except Exception:
            existing_identity = await self._get_audit_event(event.event_id)
            if existing_identity is not None and existing_identity != event:
                raise PlatformAdminStoreConflictError(
                    "admin audit identity belongs to another event"
                ) from None
            raise
        stored = await self.get_audit_event_by_idempotency_key(event.idempotency_key)
        if stored != event:
            raise PlatformAdminStoreConflictError("admin audit write conflicted")
        return stored

    async def apply_grant_mutation(
        self,
        mutation: PlatformAdminGrantMutation,
    ) -> PlatformAdminGrantMutation:
        if await self._mutation_applied(mutation):
            return mutation
        try:
            async with self._db_client.transaction() as transaction:
                await self._write_grant_mutation(transaction, mutation)
                await self._insert_audit(transaction, mutation.audit_event)
        except PlatformAdminStoreConflictError:
            if await self._mutation_applied(mutation):
                return mutation
            raise
        except Exception as exc:
            if await self._mutation_applied(mutation):
                return mutation
            raise PlatformAdminStoreError("platform admin mutation failed") from exc
        if not await self._mutation_applied(mutation):
            raise PlatformAdminStoreConflictError(
                "admin grant mutation did not persist atomically"
            )
        return mutation

    async def get_audit_event_by_idempotency_key(
        self,
        idempotency_key: str,
    ) -> PlatformAdminAuditEvent | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM platform_admin_audit WHERE idempotency_key = ?",
            [idempotency_key],
        )
        return self._one(result.rows, PlatformAdminAuditEvent)

    async def _get_audit_event(
        self,
        event_id: str,
    ) -> PlatformAdminAuditEvent | None:
        result = await self._db_client.execute(
            "SELECT payload_json FROM platform_admin_audit WHERE event_id = ?",
            [event_id],
        )
        return self._one(result.rows, PlatformAdminAuditEvent)

    async def _mutation_applied(self, mutation: PlatformAdminGrantMutation) -> bool:
        grant = await self.get_grant(mutation.grant_after.grant_id)
        audit = await self.get_audit_event_by_idempotency_key(
            mutation.audit_event.idempotency_key
        )
        if grant is None and audit is None:
            return False
        if grant == mutation.grant_after and audit == mutation.audit_event:
            return True
        if audit is not None:
            raise PlatformAdminStoreConflictError(
                "admin mutation idempotency key belongs to another operation"
            )
        return False

    async def _write_grant_mutation(
        self,
        transaction: AsyncSQLTransaction,
        mutation: PlatformAdminGrantMutation,
    ) -> None:
        after = mutation.grant_after
        before = mutation.grant_before
        if before is None:
            existing_id = await transaction.execute(
                "SELECT grant_id FROM platform_admin_grants WHERE grant_id = ? OR user_id = ?",
                [after.grant_id, after.user_id],
            )
            if existing_id.rows:
                raise PlatformAdminStoreConflictError(
                    "platform grant identity belongs to another actor"
                )
            await transaction.execute(
                """
                INSERT INTO platform_admin_grants (
                    grant_id, user_id, status, version, payload_json
                ) VALUES (?, ?, ?, ?, ?)
                """,
                [
                    after.grant_id,
                    after.user_id,
                    after.status.value,
                    after.version,
                    after.model_dump_json(),
                ],
            )
            return
        current_result = await transaction.execute(
            "SELECT payload_json FROM platform_admin_grants WHERE grant_id = ?",
            [before.grant_id],
        )
        current = self._one(current_result.rows, PlatformAdminGrant)
        if current != before:
            raise PlatformAdminStoreConflictError("platform grant version conflict")
        await transaction.execute(
            """
            UPDATE platform_admin_grants SET
                status = ?, version = ?, payload_json = ?
            WHERE grant_id = ? AND user_id = ? AND version = ? AND payload_json = ?
            """,
            [
                after.status.value,
                after.version,
                after.model_dump_json(),
                before.grant_id,
                before.user_id,
                before.version,
                before.model_dump_json(),
            ],
        )

    @staticmethod
    async def _insert_audit(
        transaction: AsyncSQLTransaction,
        event: PlatformAdminAuditEvent,
    ) -> None:
        await transaction.execute(
            """
            INSERT INTO platform_admin_audit (
                event_id, idempotency_key, actor_user_id, grant_id,
                capability, action, outcome, created_at, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                event.event_id,
                event.idempotency_key,
                event.actor_user_id,
                event.grant_id,
                event.capability.value,
                event.action,
                event.outcome.value,
                event.created_at.isoformat(),
                event.model_dump_json(),
            ],
        )

    @staticmethod
    def _one(rows: list[tuple], model_type):
        if not rows:
            return None
        return model_type.model_validate_json(rows[0][0])
