from datetime import UTC, datetime

import pytest

from api.models.platform_admin import PlatformAdminAuditEvent, PlatformAdminGrant
from api.services.libsql_platform_admin_store import LibsqlPlatformAdminStore
from api.services.platform_admin_store import (
    PlatformAdminGrantMutation,
    PlatformAdminStoreConflictError,
    PlatformAdminStoreError,
)
from utils.libsql_async import create_client


NOW = datetime(2026, 8, 21, 17, tzinfo=UTC)


def _grant(**changes) -> PlatformAdminGrant:
    values = {
        "grant_id": "grant-1",
        "user_id": "user-1",
        "capabilities": ["ai_usage:read_all", "ai_usage:adjust"],
        "reason": "Initial bounded operations grant",
        "granted_by": "bootstrap-operator",
        "granted_at": NOW,
    }
    values.update(changes)
    return PlatformAdminGrant(**values)


def _audit(**changes) -> PlatformAdminAuditEvent:
    values = {
        "event_id": "event-1",
        "idempotency_key": "operation-1",
        "actor_user_id": "user-1",
        "grant_id": "operator-grant-1",
        "grant_version": 1,
        "capability": "ai_usage:adjust",
        "action": "ai_usage.adjust",
        "target_user_id": "user-2",
        "target_project_id": "project-1",
        "reason": "Support correction approved by operator",
        "outcome": "allowed",
        "after_ref": "platform_admin_grant:grant-1:v1",
        "created_at": NOW,
    }
    values.update(changes)
    return PlatformAdminAuditEvent(**values)


async def _store() -> LibsqlPlatformAdminStore:
    store = LibsqlPlatformAdminStore(db_client=create_client(url=":memory:"))
    await store.ensure_schema()
    return store


@pytest.mark.asyncio
async def test_grant_roundtrip_and_user_identity_are_unique():
    store = await _store()
    grant = _grant()
    mutation = PlatformAdminGrantMutation(
        grant_after=grant,
        audit_event=_audit(action="platform_admin.grant"),
    )
    assert await store.apply_grant_mutation(mutation) == mutation
    assert await store.get_grant("grant-1") == grant
    assert await store.get_grant_by_user("user-1") == grant

    with pytest.raises(PlatformAdminStoreConflictError, match="another actor"):
        await store.apply_grant_mutation(
            PlatformAdminGrantMutation(
                grant_after=_grant(grant_id="grant-2"),
                audit_event=_audit(
                    event_id="event-2",
                    idempotency_key="operation-2",
                    action="platform_admin.grant",
                    after_ref="platform_admin_grant:grant-2:v1",
                ),
            )
        )


@pytest.mark.asyncio
async def test_compare_and_set_revocation_rejects_stale_version():
    store = await _store()
    grant = _grant()
    await store.apply_grant_mutation(
        PlatformAdminGrantMutation(
            grant_after=grant,
            audit_event=_audit(action="platform_admin.grant"),
        )
    )
    revoked = _grant(
        status="revoked",
        revoked_by="security-operator",
        revoked_at=NOW,
        version=2,
    )
    revoke_mutation = PlatformAdminGrantMutation(
        grant_before=grant,
        grant_after=revoked,
        audit_event=_audit(
            event_id="event-2",
            idempotency_key="operation-2",
            grant_version=2,
            capability="ai_usage:override",
            action="platform_admin.revoke",
            before_ref="platform_admin_grant:grant-1:v1",
            after_ref="platform_admin_grant:grant-1:v2",
        ),
    )
    assert await store.apply_grant_mutation(revoke_mutation) == revoke_mutation

    with pytest.raises(PlatformAdminStoreConflictError, match="version conflict"):
        await store.apply_grant_mutation(
            PlatformAdminGrantMutation(
                grant_before=grant,
                grant_after=_grant(version=2),
                audit_event=_audit(
                    event_id="event-3",
                    idempotency_key="operation-3",
                    grant_version=2,
                    action="platform_admin.update",
                    before_ref="platform_admin_grant:grant-1:v1",
                    after_ref="platform_admin_grant:grant-1:v2",
                ),
            )
        )


@pytest.mark.asyncio
async def test_audit_append_is_idempotent_and_rejects_conflicting_replay():
    store = await _store()
    event = _audit(grant_id=None, grant_version=None, outcome="denied")
    assert await store.append_audit_event(event) == event
    assert await store.append_audit_event(event) == event
    assert await store.get_audit_event_by_idempotency_key("operation-1") == event

    with pytest.raises(PlatformAdminStoreConflictError, match="idempotency"):
        await store.append_audit_event(
            _audit(
                event_id="event-2",
                grant_id=None,
                grant_version=None,
                outcome="conflict",
            )
        )


@pytest.mark.asyncio
async def test_grant_change_and_success_audit_are_atomic_and_idempotent():
    store = await _store()
    grant = _grant()
    mutation = PlatformAdminGrantMutation(
        grant_after=grant,
        audit_event=_audit(
            action="platform_admin.grant",
            target_user_id="user-1",
        ),
    )
    assert await store.apply_grant_mutation(mutation) == mutation
    assert await store.apply_grant_mutation(mutation) == mutation
    assert await store.get_grant("grant-1") == grant
    assert await store.get_audit_event_by_idempotency_key("operation-1") == mutation.audit_event


@pytest.mark.asyncio
async def test_conflicting_audit_rolls_back_grant_creation():
    store = await _store()
    await store.append_audit_event(
        _audit(
            idempotency_key="existing-operation",
            grant_id=None,
            grant_version=None,
            outcome="conflict",
        )
    )
    mutation = PlatformAdminGrantMutation(
        grant_after=_grant(),
        audit_event=_audit(action="platform_admin.grant"),
    )

    with pytest.raises(PlatformAdminStoreError, match="mutation failed"):
        await store.apply_grant_mutation(mutation)
    assert await store.get_grant("grant-1") is None
