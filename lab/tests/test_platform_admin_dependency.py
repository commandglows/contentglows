from datetime import UTC, datetime
from inspect import signature
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException

from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.platform_admin import (
    authorize_platform_capability,
    require_distinct_admin_target,
    require_platform_capability,
)
from api.models.platform_admin import PlatformAdminCapability, PlatformAdminGrant


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


def _provider(store):
    return AsyncMock(return_value=store)


def test_platform_capability_dependency_requires_authenticated_identity():
    dependency = require_platform_capability(
        PlatformAdminCapability.AI_USAGE_READ_ALL
    )
    current_user_parameter = signature(dependency).parameters["current_user"]
    assert current_user_parameter.default.dependency is require_current_user


@pytest.mark.asyncio
async def test_email_or_client_claim_never_substitutes_for_durable_grant():
    user = SimpleNamespace(
        user_id="user-1",
        email="admin@example.com",
        bearer_token="signed-token",
        metadata={"role": "platform_admin"},
        org_role="org:admin",
    )
    store = SimpleNamespace(get_grant_by_user=AsyncMock(return_value=None))

    with pytest.raises(HTTPException) as error:
        await authorize_platform_capability(
            capability=PlatformAdminCapability.AI_USAGE_ADJUST,
            current_user=user,
            store_provider=_provider(store),
        )

    assert error.value.status_code == 403
    assert error.value.detail == "Platform admin access denied."


@pytest.mark.asyncio
async def test_exact_capability_is_required_and_revocation_is_read_each_time():
    current_user = CurrentUser(user_id="user-1", bearer_token="signed-token")
    store = SimpleNamespace(
        get_grant_by_user=AsyncMock(
            side_effect=[
                _grant(),
                _grant(
                    status="revoked",
                    revoked_by="security-operator",
                    revoked_at=NOW,
                    version=2,
                ),
            ]
        )
    )
    provider = _provider(store)

    authorized = await authorize_platform_capability(
        capability=PlatformAdminCapability.AI_USAGE_ADJUST,
        current_user=current_user,
        store_provider=provider,
    )
    assert authorized.grant_version == 1

    with pytest.raises(HTTPException) as revoked_error:
        await authorize_platform_capability(
            capability=PlatformAdminCapability.AI_USAGE_ADJUST,
            current_user=current_user,
            store_provider=provider,
        )
    assert revoked_error.value.status_code == 403
    assert store.get_grant_by_user.await_count == 2


@pytest.mark.asyncio
async def test_wrong_capability_and_store_failure_fail_closed():
    current_user = CurrentUser(user_id="user-1", bearer_token="signed-token")
    wrong_capability_store = SimpleNamespace(
        get_grant_by_user=AsyncMock(return_value=_grant())
    )
    with pytest.raises(HTTPException) as forbidden:
        await authorize_platform_capability(
            capability=PlatformAdminCapability.AI_USAGE_REFUND,
            current_user=current_user,
            store_provider=_provider(wrong_capability_store),
        )
    assert forbidden.value.status_code == 403

    failing_store = SimpleNamespace(
        get_grant_by_user=AsyncMock(side_effect=RuntimeError("private database detail"))
    )
    with pytest.raises(HTTPException) as unavailable:
        await authorize_platform_capability(
            capability=PlatformAdminCapability.AI_USAGE_ADJUST,
            current_user=current_user,
            store_provider=_provider(failing_store),
        )
    assert unavailable.value.status_code == 503
    assert unavailable.value.detail == "Platform authorization is unavailable."
    assert "private database detail" not in unavailable.value.detail


@pytest.mark.asyncio
async def test_grant_from_another_tenant_is_rejected_even_if_store_returns_it():
    current_user = CurrentUser(user_id="user-1", bearer_token="signed-token")
    foreign_store = SimpleNamespace(
        get_grant_by_user=AsyncMock(return_value=_grant(user_id="user-2"))
    )
    with pytest.raises(HTTPException) as forbidden:
        await authorize_platform_capability(
            capability=PlatformAdminCapability.AI_USAGE_ADJUST,
            current_user=current_user,
            store_provider=_provider(foreign_store),
        )
    assert forbidden.value.status_code == 403


def test_self_targeting_is_denied_with_generic_response():
    admin = SimpleNamespace(actor_user_id="user-1")
    with pytest.raises(HTTPException) as error:
        require_distinct_admin_target(admin, target_user_id="user-1")
    assert error.value.status_code == 403
    assert error.value.detail == "Platform admin access denied."
