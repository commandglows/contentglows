"""Configuration-driven policies for managed AI usage actions.

Policies express internal enforcement units and provider routing metadata. They
deliberately do not model customer-facing plans, money, prices, or checkout.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from decimal import Decimal
from enum import Enum
from types import MappingProxyType
from typing import Any

from pydantic import ConfigDict, Field, model_validator

from api.models.ai_usage import (
    AIUsageAction,
    AIUsageBillingMode,
    AIUsageModel,
    Identifier,
    NonNegativeUnits,
)


class AIUsagePolicyError(ValueError):
    """Raised when policy configuration cannot be resolved safely."""


class AIUsageLimitBehavior(str, Enum):
    HARD_BLOCK = "hard_block"


class AIUsageFailureBehavior(str, Enum):
    RELEASE = "release"
    REFUND = "refund"


class AIUsageActionPolicy(AIUsageModel):
    """Validated enforcement policy for one usage action."""

    model_config = ConfigDict(frozen=True)

    action: AIUsageAction
    billing_mode: AIUsageBillingMode
    provider: Identifier | None = None
    model: str | None = Field(default=None, min_length=1, max_length=160)
    estimated_units: NonNegativeUnits
    limit_behavior: AIUsageLimitBehavior = AIUsageLimitBehavior.HARD_BLOCK
    provider_failure_behavior: AIUsageFailureBehavior
    admin_override_eligible: bool = False

    @model_validator(mode="after")
    def validate_policy(self) -> "AIUsageActionPolicy":
        if self.billing_mode is AIUsageBillingMode.BYOK:
            if self.action is not AIUsageAction.BYOK_METADATA:
                raise ValueError("BYOK policies only support byok_metadata")
            if self.provider is not None or self.model is not None:
                raise ValueError("BYOK metadata policy must not route a managed provider")
            if self.estimated_units != 0:
                raise ValueError("BYOK metadata policy must use zero managed usage units")
            if self.admin_override_eligible:
                raise ValueError("BYOK metadata policy cannot grant managed-unit overrides")
            return self

        if self.action is AIUsageAction.BYOK_METADATA:
            raise ValueError("managed policies cannot target byok_metadata")
        if self.provider is None:
            raise ValueError("managed policies require a provider")
        if self.estimated_units <= 0:
            raise ValueError("managed policies require positive estimated units")
        return self


class AIUsagePolicySet:
    """Immutable action-indexed policy registry built from injected config."""

    def __init__(self, policies: Iterable[AIUsageActionPolicy]) -> None:
        indexed: dict[AIUsageAction, AIUsageActionPolicy] = {}
        for policy in policies:
            if policy.action in indexed:
                raise AIUsagePolicyError(
                    f"duplicate AI usage policy for action: {policy.action.value}"
                )
            indexed[policy.action] = policy
        if not indexed:
            raise AIUsagePolicyError("at least one AI usage policy is required")
        self._policies = MappingProxyType(indexed)

    @classmethod
    def from_config(
        cls,
        config: Iterable[Mapping[str, Any]],
    ) -> "AIUsagePolicySet":
        """Parse a caller-owned config payload without reading global state."""
        return cls(AIUsageActionPolicy.model_validate(item) for item in config)

    def resolve(self, action: AIUsageAction | str) -> AIUsageActionPolicy:
        try:
            normalized_action = AIUsageAction(action)
        except ValueError as error:
            raise AIUsagePolicyError(f"unknown AI usage action: {action}") from error
        try:
            return self._policies[normalized_action]
        except KeyError as error:
            raise AIUsagePolicyError(
                f"AI usage policy is not configured for action: {normalized_action.value}"
            ) from error

    def estimated_units(self, action: AIUsageAction | str) -> Decimal:
        return self.resolve(action).estimated_units

    def all(self) -> tuple[AIUsageActionPolicy, ...]:
        return tuple(self._policies.values())
