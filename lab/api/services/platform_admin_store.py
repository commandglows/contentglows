"""Persistence-agnostic port for platform authorization state."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol, runtime_checkable

from api.models.platform_admin import (
    PlatformAdminAuditEvent,
    PlatformAdminAuditOutcome,
    PlatformAdminGrant,
)


class PlatformAdminStoreError(RuntimeError):
    """Base error exposed by platform authorization stores."""


class PlatformAdminStoreConflictError(PlatformAdminStoreError):
    """Raised when a compare-and-set or idempotency contract conflicts."""


@dataclass(frozen=True)
class PlatformAdminGrantMutation:
    """One grant compare-and-set coupled to immutable success audit evidence."""

    grant_after: PlatformAdminGrant
    audit_event: PlatformAdminAuditEvent
    grant_before: PlatformAdminGrant | None = None

    def __post_init__(self) -> None:
        if self.audit_event.outcome is not PlatformAdminAuditOutcome.ALLOWED:
            raise ValueError("grant mutation audit must record an allowed outcome")
        expected_after_ref = (
            f"platform_admin_grant:{self.grant_after.grant_id}:"
            f"v{self.grant_after.version}"
        )
        if self.audit_event.after_ref != expected_after_ref:
            raise ValueError("grant mutation audit must reference the resulting grant")
        if self.grant_before is None:
            if self.grant_after.version != 1:
                raise ValueError("new grant mutation must create version 1")
            return
        if (
            self.grant_before.grant_id != self.grant_after.grant_id
            or self.grant_before.user_id != self.grant_after.user_id
        ):
            raise ValueError("grant mutation cannot change identity")
        if self.grant_after.version != self.grant_before.version + 1:
            raise ValueError("grant mutation must increment version by one")
        expected_before_ref = (
            f"platform_admin_grant:{self.grant_before.grant_id}:"
            f"v{self.grant_before.version}"
        )
        if self.audit_event.before_ref != expected_before_ref:
            raise ValueError("grant mutation audit must reference the prior grant")


@runtime_checkable
class PlatformAdminStore(Protocol):
    async def get_grant(self, grant_id: str) -> PlatformAdminGrant | None:
        ...

    async def get_grant_by_user(self, user_id: str) -> PlatformAdminGrant | None:
        ...

    async def append_audit_event(
        self,
        event: PlatformAdminAuditEvent,
    ) -> PlatformAdminAuditEvent:
        ...

    async def apply_grant_mutation(
        self,
        mutation: PlatformAdminGrantMutation,
    ) -> PlatformAdminGrantMutation:
        ...

    async def get_audit_event_by_idempotency_key(
        self,
        idempotency_key: str,
    ) -> PlatformAdminAuditEvent | None:
        ...
