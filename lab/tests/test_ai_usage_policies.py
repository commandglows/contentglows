"""Authored contract tests for configuration-driven AI usage policies."""

from decimal import Decimal

import pytest
from pydantic import ValidationError

from api.models.ai_usage import AIUsageAction, AIUsageBillingMode
from api.services.ai_usage_policies import (
    AIUsageActionPolicy,
    AIUsageFailureBehavior,
    AIUsageLimitBehavior,
    AIUsagePolicyError,
    AIUsagePolicySet,
)


ILLUSTRATIVE_POLICY_FIXTURES = {
    "free": [
        {
            "action": "byok_metadata",
            "billing_mode": "byok",
            "estimated_units": "0",
            "provider_failure_behavior": "release",
        }
    ],
    "creator": [
        {
            "action": "flux_image_generation",
            "billing_mode": "managed",
            "provider": "sample-image-provider",
            "model": "sample-fast-model",
            "estimated_units": "2.5",
            "limit_behavior": "hard_block",
            "provider_failure_behavior": "release",
            "admin_override_eligible": True,
        },
        {
            "action": "bunny_upload",
            "billing_mode": "managed",
            "provider": "sample-media-provider",
            "estimated_units": "0.25",
            "provider_failure_behavior": "release",
        },
    ],
    "pro": [
        {
            "action": "remotion_render",
            "billing_mode": "managed",
            "provider": "sample-render-provider",
            "model": "sample-hd-renderer",
            "estimated_units": "7.75",
            "provider_failure_behavior": "refund",
            "admin_override_eligible": True,
        }
    ],
}


@pytest.mark.parametrize("fixture_name", ["free", "creator", "pro"])
def test_illustrative_policy_fixtures_resolve_without_commercial_prices(fixture_name):
    policies = AIUsagePolicySet.from_config(ILLUSTRATIVE_POLICY_FIXTURES[fixture_name])

    for configured in ILLUSTRATIVE_POLICY_FIXTURES[fixture_name]:
        policy = policies.resolve(configured["action"])
        assert policy.estimated_units == Decimal(configured["estimated_units"])
        assert policy.limit_behavior is AIUsageLimitBehavior.HARD_BLOCK
        assert not hasattr(policy, "price")
        assert not hasattr(policy, "currency")


def test_policy_set_resolves_provider_model_failure_and_override_behavior():
    policies = AIUsagePolicySet.from_config(ILLUSTRATIVE_POLICY_FIXTURES["pro"])

    policy = policies.resolve(AIUsageAction.REMOTION_RENDER)

    assert policy.billing_mode is AIUsageBillingMode.MANAGED
    assert policy.provider == "sample-render-provider"
    assert policy.model == "sample-hd-renderer"
    assert policy.provider_failure_behavior is AIUsageFailureBehavior.REFUND
    assert policy.admin_override_eligible is True
    assert policies.estimated_units(policy.action) == Decimal("7.75")
    with pytest.raises(ValidationError, match="frozen"):
        policy.estimated_units = Decimal("1")


def test_policy_set_rejects_duplicate_missing_and_unknown_actions():
    duplicate = ILLUSTRATIVE_POLICY_FIXTURES["creator"][:1] * 2
    with pytest.raises(AIUsagePolicyError, match="duplicate"):
        AIUsagePolicySet.from_config(duplicate)

    policies = AIUsagePolicySet.from_config(ILLUSTRATIVE_POLICY_FIXTURES["free"])
    with pytest.raises(AIUsagePolicyError, match="not configured"):
        policies.resolve(AIUsageAction.FLUX_IMAGE_GENERATION)
    with pytest.raises(AIUsagePolicyError, match="unknown"):
        policies.resolve("unknown_action")
    with pytest.raises(AIUsagePolicyError, match="at least one"):
        AIUsagePolicySet([])


@pytest.mark.parametrize(
    "overrides, message",
    [
        ({"estimated_units": "0"}, "positive estimated units"),
        ({"provider": None}, "require a provider"),
        ({"billing_mode": "byok"}, "only support byok_metadata"),
    ],
)
def test_managed_policy_rejects_unsafe_configuration(overrides, message):
    config = {
        "action": "flux_image_generation",
        "billing_mode": "managed",
        "provider": "sample-image-provider",
        "estimated_units": "1",
        "provider_failure_behavior": "release",
        **overrides,
    }

    with pytest.raises(ValidationError, match=message):
        AIUsageActionPolicy.model_validate(config)


@pytest.mark.parametrize(
    "overrides, message",
    [
        ({"estimated_units": "1"}, "zero managed usage units"),
        ({"provider": "managed-provider"}, "must not route"),
        ({"admin_override_eligible": True}, "cannot grant"),
    ],
)
def test_byok_policy_rejects_managed_usage_configuration(overrides, message):
    config = {
        "action": "byok_metadata",
        "billing_mode": "byok",
        "estimated_units": "0",
        "provider_failure_behavior": "release",
        **overrides,
    }

    with pytest.raises(ValidationError, match=message):
        AIUsageActionPolicy.model_validate(config)
