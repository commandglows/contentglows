from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest
from pydantic import ValidationError

from api.models.ai_usage import (
    AIEntitlement,
    AIQuotaError,
    AIQuotaStatus,
    AIUsageAction,
    AIUsageBillingMode,
    AIUsageLedgerEntry,
    AIUsageLedgerEvent,
    AIUsageReservation,
    AIUsageReservationStatus,
    AIUsageScope,
    AIUsageUnitDirection,
    ProviderCostMetadata,
    validate_reservation_transition,
)


NOW = datetime(2026, 8, 20, 8, tzinfo=timezone.utc)
SCOPE = AIUsageScope(user_id="user-1", project_id="project-1")


def test_scope_rejects_empty_and_undeclared_identity_fields():
    with pytest.raises(ValidationError):
        AIUsageScope(user_id="", project_id="project-1")
    with pytest.raises(ValidationError):
        AIUsageScope(user_id="user-1", project_id="project-1", forged_user_id="user-2")


def test_managed_entitlement_exposes_non_negative_remaining_units():
    entitlement = AIEntitlement(
        entitlement_id="entitlement-1",
        scope=SCOPE,
        billing_mode="managed",
        actions=["flux_image_generation", "bunny_upload", "remotion_render"],
        unit_limit="100",
        unit_reserved="15",
        unit_consumed="35",
        valid_from=NOW,
    )

    assert entitlement.unit_remaining == Decimal("50")
    payload = entitlement.model_dump(mode="json", by_alias=True)
    assert payload["billingMode"] == "managed"
    assert payload["scope"]["projectId"] == "project-1"

    with pytest.raises(ValidationError, match="exceed entitlement limit"):
        AIEntitlement.model_validate(
            {
                **entitlement.model_dump(),
                "unit_reserved": Decimal("70"),
            }
        )


def test_byok_entitlement_never_contains_managed_units():
    entitlement = AIEntitlement(
        entitlement_id="entitlement-byok",
        scope=SCOPE,
        billing_mode="byok",
        actions=["byok_metadata"],
        valid_from=NOW,
    )
    assert entitlement.unit_remaining == 0

    with pytest.raises(ValidationError, match="must not consume managed usage units"):
        AIEntitlement(
            entitlement_id="entitlement-byok",
            scope=SCOPE,
            billing_mode="byok",
            actions=["byok_metadata"],
            unit_limit="1",
            valid_from=NOW,
        )


@pytest.mark.parametrize(
    ("action", "provider"),
    [
        ("flux_image_generation", "bfl"),
        ("bunny_upload", "bunny"),
        ("remotion_render", "remotion"),
    ],
)
def test_managed_reservations_cover_costly_provider_actions(action, provider):
    reservation = AIUsageReservation(
        reservation_id=f"reservation-{provider}",
        idempotency_key=f"request-{provider}",
        entitlement_id="entitlement-1",
        scope=SCOPE,
        action=action,
        billing_mode="managed",
        units="2.5",
        provider=provider,
        created_at=NOW,
        updated_at=NOW,
        expires_at=NOW + timedelta(minutes=15),
    )

    assert reservation.units == Decimal("2.5")


def test_managed_reservation_requires_positive_units():
    with pytest.raises(ValidationError, match="requires positive units"):
        AIUsageReservation(
            reservation_id="reservation-1",
            idempotency_key="request-1",
            entitlement_id="entitlement-1",
            scope=SCOPE,
            action="flux_image_generation",
            billing_mode="managed",
            units="0",
            created_at=NOW,
            updated_at=NOW,
            expires_at=NOW + timedelta(minutes=15),
        )


def test_reservation_rejects_naive_time_and_invalid_state_transitions():
    with pytest.raises(ValidationError, match="must include a timezone"):
        AIUsageReservation(
            reservation_id="reservation-1",
            idempotency_key="request-1",
            entitlement_id="entitlement-1",
            scope=SCOPE,
            action="flux_image_generation",
            billing_mode="managed",
            units="1",
            created_at=datetime(2026, 8, 20, 8),
            updated_at=NOW,
            expires_at=NOW + timedelta(minutes=15),
        )

    validate_reservation_transition(
        AIUsageReservationStatus.RESERVED,
        AIUsageReservationStatus.PROVIDER_STARTED,
    )
    with pytest.raises(ValueError, match="consumed -> provider_started"):
        validate_reservation_transition(
            AIUsageReservationStatus.CONSUMED,
            AIUsageReservationStatus.PROVIDER_STARTED,
        )


def test_provider_cost_metadata_keeps_exact_estimated_and_unknown_distinct():
    exact = ProviderCostMetadata(
        provider="bfl",
        provider_action="flux_image_generation",
        model="flux-2-pro",
        actual_cost="0.05",
        currency="USD",
        input_mp="1.2",
        output_mp="2.4",
        confidence="exact",
        captured_at=NOW,
    )
    estimated = ProviderCostMetadata(
        provider="bunny",
        provider_action="bunny_upload",
        estimated_cost="0.01",
        currency="USD",
        pricing_table_version="bunny-2026-08",
        confidence="estimated",
        captured_at=NOW,
    )
    unknown = ProviderCostMetadata(
        provider="remotion",
        provider_action="remotion_render",
        confidence="unknown",
        captured_at=NOW,
        evidence={"reason": "provider_cost_missing"},
    )

    assert exact.actual_cost == Decimal("0.05")
    assert estimated.estimated_cost == Decimal("0.01")
    assert unknown.actual_cost is None

    with pytest.raises(ValidationError, match="currency is required"):
        ProviderCostMetadata(
            provider="bfl",
            provider_action="flux_image_generation",
            actual_cost="0.05",
            confidence="exact",
            captured_at=NOW,
        )
    with pytest.raises(ValidationError):
        ProviderCostMetadata(
            provider="bfl",
            provider_action="flux_image_generation",
            actual_cost="-0.01",
            currency="USD",
            confidence="exact",
            captured_at=NOW,
        )


def test_ledger_requires_reservation_and_audited_admin_adjustment():
    with pytest.raises(ValidationError, match="consumed event requires reservation_id"):
        AIUsageLedgerEntry(
            entry_id="entry-1",
            idempotency_key="entry-request-1",
            scope=SCOPE,
            action="flux_image_generation",
            billing_mode="managed",
            event="consumed",
            units="1",
            created_at=NOW,
        )

    adjustment = AIUsageLedgerEntry(
        entry_id="entry-adjustment-1",
        idempotency_key="adjustment-request-1",
        scope=SCOPE,
        action="flux_image_generation",
        billing_mode="managed",
        event=AIUsageLedgerEvent.ADMIN_ADJUSTMENT,
        units="10",
        unit_direction=AIUsageUnitDirection.CREDIT,
        actor_id="admin-1",
        reason="Support refund for failed durable delivery",
        created_at=NOW,
    )
    assert adjustment.unit_direction is AIUsageUnitDirection.CREDIT


def test_failed_provider_event_can_record_cost_without_consuming_units():
    cost = ProviderCostMetadata(
        provider="bfl",
        provider_action="flux_image_generation",
        actual_cost="0.02",
        currency="USD",
        confidence="exact",
        captured_at=NOW,
    )
    entry = AIUsageLedgerEntry(
        entry_id="entry-failed-1",
        idempotency_key="failed-request-1",
        reservation_id="reservation-1",
        scope=SCOPE,
        action="flux_image_generation",
        billing_mode="managed",
        event="failed",
        units="0",
        provider_cost=cost,
        created_at=NOW,
    )

    assert entry.units == 0
    assert entry.provider_cost.actual_cost == Decimal("0.02")


def test_byok_ledger_metadata_is_separate_from_managed_usage():
    entry = AIUsageLedgerEntry(
        entry_id="entry-byok-1",
        idempotency_key="byok-request-1",
        scope=SCOPE,
        action=AIUsageAction.BYOK_METADATA,
        billing_mode=AIUsageBillingMode.BYOK,
        event=AIUsageLedgerEvent.COMPLETED,
        units="0",
        created_at=NOW,
        metadata={"provider": "openrouter"},
    )
    assert entry.units == 0

    with pytest.raises(ValidationError, match="must not consume managed usage units"):
        AIUsageLedgerEntry(
            **{
                **entry.model_dump(),
                "units": Decimal("1"),
            }
        )


def test_quota_status_rejects_false_availability_and_negative_balance_math():
    allowed = AIQuotaStatus(
        scope=SCOPE,
        action="flux_image_generation",
        billing_mode="managed",
        allowed=True,
        entitlement_id="entitlement-1",
        unit_limit="10",
        unit_reserved="2",
        unit_consumed="3",
        unit_remaining="5",
        required_units="4",
        checked_at=NOW,
    )
    assert allowed.allowed is True

    with pytest.raises(ValidationError, match="cannot require more units"):
        AIQuotaStatus(
            **{
                **allowed.model_dump(),
                "required_units": Decimal("6"),
            }
        )
    with pytest.raises(ValidationError, match="requires reason_code"):
        AIQuotaStatus(
            **{
                **allowed.model_dump(),
                "allowed": False,
                "entitlement_id": None,
            }
        )


def test_quota_error_envelopes_are_recoverable_and_consistent():
    exhausted = AIQuotaError(
        code="ai_quota_exhausted",
        kind="quota",
        message="Managed AI usage is exhausted.",
        action="flux_image_generation",
        billing_mode="managed",
        provider="bfl",
        remaining_units="1",
        required_units="2",
        retryable=False,
        settings_path="/settings?section=ai-runtime",
    )
    payload = exhausted.model_dump(mode="json", by_alias=True)
    assert payload["remainingUnits"] == "1"
    assert payload["settingsPath"] == "/settings?section=ai-runtime"

    with pytest.raises(ValidationError, match="require retryable"):
        AIQuotaError(
            code="ai_generation_rate_limited",
            kind="rate_limit",
            message="Too many concurrent generations.",
            action="remotion_render",
            billing_mode="managed",
            retryable=False,
        )

    with pytest.raises(ValidationError, match="requires kind quota"):
        AIQuotaError(
            code="ai_quota_exhausted",
            kind="rate_limit",
            message="Managed AI usage is exhausted.",
            action="flux_image_generation",
            billing_mode="managed",
            remaining_units="1",
            required_units="2",
            retryable=False,
        )
