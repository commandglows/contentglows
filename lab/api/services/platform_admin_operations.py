"""Bounded, non-HTTP grant bootstrap and revocation operations."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Callable, Iterable

from api.models.platform_admin import (
    PlatformAdminAuditEvent,
    PlatformAdminAuditCapability,
    PlatformAdminAuthorityKind,
    PlatformAdminBootstrapAuthority,
    PlatformAdminCapability,
    PlatformAdminGrant,
    PlatformAdminGrantStatus,
)
from api.services.platform_admin_store import (
    PlatformAdminGrantMutation,
    PlatformAdminStore,
    PlatformAdminStoreConflictError,
)


class PlatformAdminOperationError(RuntimeError):
    """Raised when a bounded grant operation is invalid or conflicts."""


class PlatformAdminGrantOperations:
    def __init__(
        self,
        *,
        store: PlatformAdminStore,
        clock: Callable[[], datetime] | None = None,
        id_factory: Callable[[], str] | None = None,
    ) -> None:
        self._store = store
        self._clock = clock or (lambda: datetime.now(UTC))
        self._id_factory = id_factory or (lambda: str(uuid.uuid4()))

    async def grant(
        self,
        *,
        authority: PlatformAdminBootstrapAuthority,
        target_user_id: str,
        capabilities: Iterable[PlatformAdminCapability],
        reason: str,
    ) -> PlatformAdminGrant:
        now = self._require_authority(authority, target_user_id=target_user_id)
        reason = self._normalize_reason(reason)
        try:
            normalized_capabilities = tuple(
                PlatformAdminCapability(capability) for capability in capabilities
            )
        except ValueError as exc:
            raise PlatformAdminOperationError("unknown platform capability") from exc
        if not normalized_capabilities:
            raise PlatformAdminOperationError("at least one capability is required")
        if len(set(normalized_capabilities)) != len(normalized_capabilities):
            raise PlatformAdminOperationError("capabilities must be unique")
        replay = await self._replay(
            authority=authority,
            action="platform_admin.grant",
            target_user_id=target_user_id,
            reason=reason,
        )
        if replay is not None:
            if replay.capabilities != normalized_capabilities or replay.reason != reason:
                raise PlatformAdminOperationError(
                    "bootstrap operation conflicts with the existing grant"
                )
            return replay
        if await self._store.get_grant_by_user(target_user_id) is not None:
            raise PlatformAdminOperationError("target already has a platform grant")
        grant = PlatformAdminGrant(
            grant_id=self._id_factory(),
            user_id=target_user_id,
            capabilities=normalized_capabilities,
            reason=reason,
            granted_by=authority.actor_user_id,
            granted_at=now,
        )
        mutation = PlatformAdminGrantMutation(
            grant_after=grant,
            audit_event=self._audit(
                authority=authority,
                grant=grant,
                action="platform_admin.grant",
                reason=reason,
                now=now,
            ),
        )
        try:
            await self._store.apply_grant_mutation(mutation)
        except PlatformAdminStoreConflictError as exc:
            raise PlatformAdminOperationError("grant operation conflicted") from exc
        return grant

    async def revoke(
        self,
        *,
        authority: PlatformAdminBootstrapAuthority,
        target_user_id: str,
        reason: str,
    ) -> PlatformAdminGrant:
        now = self._require_authority(authority, target_user_id=target_user_id)
        reason = self._normalize_reason(reason)
        replay = await self._replay(
            authority=authority,
            action="platform_admin.revoke",
            target_user_id=target_user_id,
            reason=reason,
        )
        if replay is not None:
            if replay.status is not PlatformAdminGrantStatus.REVOKED:
                raise PlatformAdminOperationError(
                    "bootstrap operation conflicts with the existing grant"
                )
            return replay
        current = await self._store.get_grant_by_user(target_user_id)
        if current is None:
            raise PlatformAdminOperationError("target platform grant does not exist")
        if current.status is PlatformAdminGrantStatus.REVOKED:
            raise PlatformAdminOperationError("target platform grant is already revoked")
        revoked = PlatformAdminGrant.model_validate(
            current.model_dump()
            | {
                "status": PlatformAdminGrantStatus.REVOKED,
                "revoked_by": authority.actor_user_id,
                "revoked_at": now,
                "version": current.version + 1,
            }
        )
        mutation = PlatformAdminGrantMutation(
            grant_before=current,
            grant_after=revoked,
            audit_event=self._audit(
                authority=authority,
                grant=revoked,
                action="platform_admin.revoke",
                reason=reason,
                now=now,
                before=current,
            ),
        )
        try:
            await self._store.apply_grant_mutation(mutation)
        except PlatformAdminStoreConflictError as exc:
            raise PlatformAdminOperationError("revoke operation conflicted") from exc
        return revoked

    def _require_authority(
        self,
        authority: PlatformAdminBootstrapAuthority,
        *,
        target_user_id: str,
    ) -> datetime:
        now = self._clock()
        if now.tzinfo is None or now.utcoffset() is None:
            raise PlatformAdminOperationError("operation clock must be timezone-aware")
        if authority.issued_at > now:
            raise PlatformAdminOperationError("bootstrap authority is not active")
        if authority.expires_at <= now:
            raise PlatformAdminOperationError("bootstrap authority has expired")
        if (
            not target_user_id
            or target_user_id.strip() != target_user_id
            or any(character.isspace() for character in target_user_id)
            or len(target_user_id) > 128
        ):
            raise PlatformAdminOperationError("target user id is invalid")
        if authority.actor_user_id == target_user_id:
            raise PlatformAdminOperationError("bootstrap actor cannot target itself")
        return now

    async def _replay(
        self,
        *,
        authority: PlatformAdminBootstrapAuthority,
        action: str,
        target_user_id: str,
        reason: str,
    ) -> PlatformAdminGrant | None:
        event = await self._store.get_audit_event_by_idempotency_key(
            self._idempotency_key(authority)
        )
        if event is None:
            return None
        if (
            event.authority_kind is not PlatformAdminAuthorityKind.BOOTSTRAP_OPERATION
            or event.bootstrap_operation_id != authority.operation_id
            or event.actor_user_id != authority.actor_user_id
            or event.action != action
            or event.target_user_id != target_user_id
            or event.reason != reason
            or event.after_ref is None
        ):
            raise PlatformAdminOperationError(
                "bootstrap operation id belongs to another operation"
            )
        grant_id = self._grant_id_from_ref(event.after_ref)
        grant = await self._store.get_grant(grant_id)
        if (
            grant is None
            or grant.user_id != target_user_id
            or self._grant_ref(grant) != event.after_ref
        ):
            raise PlatformAdminOperationError("bootstrap audit has no matching grant")
        return grant

    def _audit(
        self,
        *,
        authority: PlatformAdminBootstrapAuthority,
        grant: PlatformAdminGrant,
        action: str,
        reason: str,
        now: datetime,
        before: PlatformAdminGrant | None = None,
    ) -> PlatformAdminAuditEvent:
        return PlatformAdminAuditEvent(
            event_id=self._id_factory(),
            idempotency_key=self._idempotency_key(authority),
            actor_user_id=authority.actor_user_id,
            authority_kind=PlatformAdminAuthorityKind.BOOTSTRAP_OPERATION,
            bootstrap_operation_id=authority.operation_id,
            capability=PlatformAdminAuditCapability.PLATFORM_ADMIN_BOOTSTRAP,
            action=action,
            target_user_id=grant.user_id,
            reason=reason,
            before_ref=(
                self._grant_ref(before) if before is not None else None
            ),
            after_ref=self._grant_ref(grant),
            outcome="allowed",
            created_at=now,
        )

    @staticmethod
    def _idempotency_key(authority: PlatformAdminBootstrapAuthority) -> str:
        return f"platform-admin-bootstrap:{authority.operation_id}"

    @staticmethod
    def _grant_ref(grant: PlatformAdminGrant) -> str:
        return f"platform_admin_grant:{grant.grant_id}:v{grant.version}"

    @staticmethod
    def _grant_id_from_ref(reference: str) -> str:
        parts = reference.split(":")
        if (
            len(parts) != 3
            or parts[0] != "platform_admin_grant"
            or not parts[1]
            or not parts[2].startswith("v")
            or not parts[2][1:].isdigit()
        ):
            raise PlatformAdminOperationError("bootstrap audit grant reference is invalid")
        return parts[1]

    @staticmethod
    def _normalize_reason(reason: str) -> str:
        normalized = reason.strip()
        if not normalized or len(normalized) > 500:
            raise PlatformAdminOperationError("operation reason is invalid")
        return normalized
