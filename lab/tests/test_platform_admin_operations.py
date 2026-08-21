from datetime import UTC, datetime, timedelta

import pytest

from api.models.platform_admin import (
    PlatformAdminBootstrapAuthority,
    PlatformAdminCapability,
    PlatformAdminGrantStatus,
)
from api.services.libsql_platform_admin_store import LibsqlPlatformAdminStore
from api.services.platform_admin_operations import (
    PlatformAdminGrantOperations,
    PlatformAdminOperationError,
)
from utils.libsql_async import create_client


NOW = datetime(2026, 8, 21, 18, tzinfo=UTC)


async def _operations():
    store = LibsqlPlatformAdminStore(db_client=create_client(url=":memory:"))
    await store.ensure_schema()
    identifiers = iter(("grant-1", "event-1", "event-2", "unused"))
    operations = PlatformAdminGrantOperations(
        store=store,
        clock=lambda: NOW,
        id_factory=lambda: next(identifiers),
    )
    return store, operations


def _authority(operation_id: str = "operation-1") -> PlatformAdminBootstrapAuthority:
    return PlatformAdminBootstrapAuthority(
        actor_user_id="operator-1",
        operation_id=operation_id,
        issued_at=NOW,
        expires_at=NOW + timedelta(minutes=10),
    )


@pytest.mark.asyncio
async def test_grant_is_atomic_audited_and_idempotent():
    store, operations = await _operations()
    authority = _authority()
    grant = await operations.grant(
        authority=authority,
        target_user_id="user-1",
        capabilities=(
            PlatformAdminCapability.AI_USAGE_READ_ALL,
            PlatformAdminCapability.AI_USAGE_ADJUST,
        ),
        reason="  Initial support operations grant  ",
    )
    replay = await operations.grant(
        authority=authority,
        target_user_id="user-1",
        capabilities=grant.capabilities,
        reason="Initial support operations grant",
    )

    assert replay == grant
    assert grant.granted_by == "operator-1"
    event = await store.get_audit_event_by_idempotency_key(
        "platform-admin-bootstrap:operation-1"
    )
    assert event is not None
    assert event.bootstrap_operation_id == "operation-1"
    assert event.grant_id is None
    assert event.after_ref == "platform_admin_grant:grant-1:v1"


@pytest.mark.asyncio
async def test_operation_replay_cannot_change_target_capabilities_or_reason():
    _, operations = await _operations()
    authority = _authority()
    await operations.grant(
        authority=authority,
        target_user_id="user-1",
        capabilities=[PlatformAdminCapability.AI_USAGE_READ_ALL],
        reason="Initial support operations grant",
    )

    with pytest.raises(PlatformAdminOperationError, match="another operation"):
        await operations.grant(
            authority=authority,
            target_user_id="user-2",
            capabilities=[PlatformAdminCapability.AI_USAGE_READ_ALL],
            reason="Initial support operations grant",
        )
    with pytest.raises(PlatformAdminOperationError, match="existing grant"):
        await operations.grant(
            authority=authority,
            target_user_id="user-1",
            capabilities=[PlatformAdminCapability.AI_USAGE_ADJUST],
            reason="Initial support operations grant",
        )
    with pytest.raises(PlatformAdminOperationError, match="another operation"):
        await operations.grant(
            authority=authority,
            target_user_id="user-1",
            capabilities=[PlatformAdminCapability.AI_USAGE_READ_ALL],
            reason="Changed reason",
        )


@pytest.mark.asyncio
async def test_revoke_increments_version_and_is_idempotent():
    store, operations = await _operations()
    granted = await operations.grant(
        authority=_authority("grant-operation"),
        target_user_id="user-1",
        capabilities=[PlatformAdminCapability.AI_USAGE_OVERRIDE],
        reason="Initial support operations grant",
    )
    revoked = await operations.revoke(
        authority=_authority("revoke-operation"),
        target_user_id="user-1",
        reason="Operator access removed",
    )
    replay = await operations.revoke(
        authority=_authority("revoke-operation"),
        target_user_id="user-1",
        reason="Operator access removed",
    )

    assert granted.version == 1
    assert revoked.status is PlatformAdminGrantStatus.REVOKED
    assert revoked.version == 2
    assert replay == revoked
    assert await store.get_grant_by_user("user-1") == revoked


@pytest.mark.asyncio
async def test_expired_self_target_and_empty_capabilities_fail_before_writes():
    store, operations = await _operations()
    with pytest.raises(PlatformAdminOperationError, match="target itself"):
        await operations.grant(
            authority=_authority(),
            target_user_id="operator-1",
            capabilities=[PlatformAdminCapability.AI_USAGE_READ_ALL],
            reason="Invalid self grant",
        )
    with pytest.raises(PlatformAdminOperationError, match="expired"):
        await operations.grant(
            authority=PlatformAdminBootstrapAuthority(
                actor_user_id="operator-1",
                operation_id="expired-operation",
                issued_at=NOW - timedelta(minutes=10),
                expires_at=NOW,
            ),
            target_user_id="user-1",
            capabilities=[PlatformAdminCapability.AI_USAGE_READ_ALL],
            reason="Expired grant",
        )
    with pytest.raises(PlatformAdminOperationError, match="at least one"):
        await operations.grant(
            authority=_authority(),
            target_user_id="user-1",
            capabilities=[],
            reason="No capabilities",
        )
    assert await store.get_grant_by_user("user-1") is None
