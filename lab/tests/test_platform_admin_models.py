from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError

from api.models.platform_admin import PlatformAdminAuditEvent, PlatformAdminGrant


NOW = datetime(2026, 8, 21, 17, tzinfo=UTC)


def test_grant_requires_unique_capabilities_and_consistent_revocation():
    with pytest.raises(ValidationError, match="unique"):
        PlatformAdminGrant(
            grant_id="grant-1",
            user_id="user-1",
            capabilities=["ai_usage:adjust", "ai_usage:adjust"],
            reason="Initial bounded operations grant",
            granted_by="bootstrap-operator",
            granted_at=NOW,
        )

    with pytest.raises(ValidationError, match="revocation"):
        PlatformAdminGrant(
            grant_id="grant-1",
            user_id="user-1",
            capabilities=["ai_usage:adjust"],
            status="revoked",
            reason="Initial bounded operations grant",
            granted_by="bootstrap-operator",
            granted_at=NOW,
        )


def test_allowed_audit_requires_versioned_grant_evidence():
    with pytest.raises(ValidationError, match="grant evidence"):
        PlatformAdminAuditEvent(
            event_id="event-1",
            idempotency_key="operation-1",
            actor_user_id="user-1",
            capability="ai_usage:adjust",
            action="ai_usage.adjust",
            target_user_id="user-2",
            target_project_id="project-1",
            reason="Support correction approved by operator",
            outcome="allowed",
            created_at=NOW,
        )


def test_revocation_cannot_precede_grant():
    with pytest.raises(ValidationError, match="precede"):
        PlatformAdminGrant(
            grant_id="grant-1",
            user_id="user-1",
            capabilities=["ai_usage:refund"],
            status="revoked",
            reason="Initial bounded operations grant",
            granted_by="bootstrap-operator",
            granted_at=NOW,
            revoked_by="security-operator",
            revoked_at=NOW - timedelta(seconds=1),
            version=2,
        )


def test_bootstrap_audit_requires_operation_evidence_not_a_fake_grant():
    event = PlatformAdminAuditEvent(
        event_id="event-1",
        idempotency_key="platform-admin-bootstrap:operation-1",
        actor_user_id="operator-1",
        authority_kind="bootstrap_operation",
        bootstrap_operation_id="operation-1",
        capability="platform_admin:bootstrap",
        action="platform_admin.grant",
        target_user_id="user-2",
        reason="Initial bounded operations grant",
        after_ref="platform_admin_grant:grant-1:v1",
        outcome="allowed",
        created_at=NOW,
    )
    assert event.grant_id is None

    with pytest.raises(ValidationError, match="cannot claim durable grant"):
        PlatformAdminAuditEvent.model_validate(
            event.model_dump()
            | {"grant_id": "forged-grant", "grant_version": 1}
        )
