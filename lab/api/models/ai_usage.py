"""Typed contracts for managed AI usage, quotas, and provider-cost evidence."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


def _to_camel(value: str) -> str:
    head, *tail = value.split("_")
    return head + "".join(part.capitalize() for part in tail)


Identifier = Annotated[str, Field(min_length=1, max_length=128, pattern=r"^\S+$")]
NonNegativeUnits = Annotated[Decimal, Field(ge=0, max_digits=24, decimal_places=8)]
PositiveUnits = Annotated[Decimal, Field(gt=0, max_digits=24, decimal_places=8)]
NonNegativeCost = Annotated[Decimal, Field(ge=0, max_digits=24, decimal_places=8)]


class AIUsageAction(str, Enum):
    FLUX_IMAGE_GENERATION = "flux_image_generation"
    BUNNY_UPLOAD = "bunny_upload"
    REMOTION_RENDER = "remotion_render"
    BYOK_METADATA = "byok_metadata"


class AIUsageBillingMode(str, Enum):
    MANAGED = "managed"
    BYOK = "byok"


class AIEntitlementStatus(str, Enum):
    ACTIVE = "active"
    DISABLED = "disabled"
    EXPIRED = "expired"


class AIUsageReservationStatus(str, Enum):
    RESERVED = "reserved"
    PROVIDER_STARTED = "provider_started"
    CONSUMED = "consumed"
    RELEASED = "released"
    REFUNDED = "refunded"
    EXPIRED = "expired"


class AIUsageLedgerEvent(str, Enum):
    REQUESTED = "requested"
    RESERVED = "reserved"
    PROVIDER_STARTED = "provider_started"
    COMPLETED = "completed"
    FAILED = "failed"
    CONSUMED = "consumed"
    RELEASED = "released"
    REFUNDED = "refunded"
    EXPIRED = "expired"
    ADMIN_ADJUSTMENT = "admin_adjustment"


class AIUsageUnitDirection(str, Enum):
    DEBIT = "debit"
    CREDIT = "credit"


class ProviderCostConfidence(str, Enum):
    EXACT = "exact"
    ESTIMATED = "estimated"
    UNKNOWN = "unknown"


class ProviderCostUnit(str, Enum):
    CURRENCY = "currency"
    PROVIDER_CREDIT = "provider_credit"


class AIQuotaErrorCode(str, Enum):
    EXHAUSTED = "ai_quota_exhausted"
    RATE_LIMITED = "ai_generation_rate_limited"
    ENTITLEMENT_MISSING = "ai_entitlement_missing"
    RESERVATION_CONFLICT = "ai_reservation_conflict"
    SCOPE_INVALID = "ai_usage_scope_invalid"


class AIQuotaErrorKind(str, Enum):
    QUOTA = "quota"
    RATE_LIMIT = "rate_limit"
    ENTITLEMENT = "entitlement"
    CONFLICT = "conflict"


class AIUsageModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=_to_camel,
        extra="forbid",
        populate_by_name=True,
    )


class AIUsageScope(AIUsageModel):
    user_id: Identifier
    project_id: Identifier
    org_id: Identifier | None = None


class ProviderCostMetadata(AIUsageModel):
    provider: Identifier
    provider_action: Identifier
    model: str | None = Field(default=None, min_length=1, max_length=160)
    provider_request_id: str | None = Field(default=None, min_length=1, max_length=256)
    estimated_cost: NonNegativeCost | None = None
    actual_cost: NonNegativeCost | None = None
    cost_unit: ProviderCostUnit = ProviderCostUnit.CURRENCY
    currency: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")
    input_mp: Annotated[Decimal, Field(ge=0, max_digits=18, decimal_places=6)] | None = None
    output_mp: Annotated[Decimal, Field(ge=0, max_digits=18, decimal_places=6)] | None = None
    pricing_table_version: str | None = Field(default=None, min_length=1, max_length=128)
    confidence: ProviderCostConfidence = ProviderCostConfidence.UNKNOWN
    captured_at: datetime
    evidence: dict[str, Any] = Field(default_factory=dict)

    @field_validator("captured_at")
    @classmethod
    def require_aware_captured_at(cls, value: datetime) -> datetime:
        return _require_aware_datetime(value, "captured_at")

    @model_validator(mode="after")
    def validate_cost_evidence(self) -> "ProviderCostMetadata":
        has_cost = self.estimated_cost is not None or self.actual_cost is not None
        if self.cost_unit is ProviderCostUnit.CURRENCY:
            if has_cost and self.currency is None:
                raise ValueError("currency is required when a monetary provider cost is present")
        elif self.currency is not None:
            raise ValueError("provider-credit costs must not claim a currency")
        if self.confidence is ProviderCostConfidence.EXACT and self.actual_cost is None:
            raise ValueError("exact provider cost requires actual_cost")
        if self.confidence is ProviderCostConfidence.ESTIMATED:
            if self.estimated_cost is None:
                raise ValueError("estimated provider cost requires estimated_cost")
            if self.pricing_table_version is None:
                raise ValueError("estimated provider cost requires pricing_table_version")
            if self.actual_cost is not None:
                raise ValueError("estimated provider cost must not claim actual_cost")
        if self.confidence is ProviderCostConfidence.UNKNOWN and has_cost:
            raise ValueError("unknown provider cost must not include cost values")
        if self.actual_cost is not None and self.confidence is not ProviderCostConfidence.EXACT:
            raise ValueError("actual_cost requires exact confidence")
        return self


class AIEntitlement(AIUsageModel):
    entitlement_id: Identifier
    scope: AIUsageScope
    billing_mode: AIUsageBillingMode
    status: AIEntitlementStatus = AIEntitlementStatus.ACTIVE
    actions: list[AIUsageAction] = Field(min_length=1)
    unit_limit: NonNegativeUnits = Decimal("0")
    unit_reserved: NonNegativeUnits = Decimal("0")
    unit_consumed: NonNegativeUnits = Decimal("0")
    valid_from: datetime
    expires_at: datetime | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("valid_from", "expires_at")
    @classmethod
    def require_aware_timestamps(cls, value: datetime | None, info) -> datetime | None:
        if value is None:
            return None
        return _require_aware_datetime(value, info.field_name)

    @model_validator(mode="after")
    def validate_entitlement(self) -> "AIEntitlement":
        if len(set(self.actions)) != len(self.actions):
            raise ValueError("entitlement actions must be unique")
        if self.expires_at is not None and self.expires_at <= self.valid_from:
            raise ValueError("expires_at must be later than valid_from")
        if self.billing_mode is AIUsageBillingMode.BYOK:
            if self.actions != [AIUsageAction.BYOK_METADATA]:
                raise ValueError("BYOK entitlement only supports byok_metadata")
            if any((self.unit_limit, self.unit_reserved, self.unit_consumed)):
                raise ValueError("BYOK entitlement must not consume managed usage units")
        else:
            if AIUsageAction.BYOK_METADATA in self.actions:
                raise ValueError("managed entitlement must not include byok_metadata")
            if self.unit_reserved + self.unit_consumed > self.unit_limit:
                raise ValueError("reserved and consumed units exceed entitlement limit")
        return self

    @property
    def unit_remaining(self) -> Decimal:
        return self.unit_limit - self.unit_reserved - self.unit_consumed


class AIUsageReservation(AIUsageModel):
    reservation_id: Identifier
    idempotency_key: Identifier
    entitlement_id: Identifier | None = None
    scope: AIUsageScope
    action: AIUsageAction
    billing_mode: AIUsageBillingMode
    status: AIUsageReservationStatus = AIUsageReservationStatus.RESERVED
    units: NonNegativeUnits
    provider: Identifier | None = None
    model: str | None = Field(default=None, min_length=1, max_length=160)
    job_id: Identifier | None = None
    created_at: datetime
    updated_at: datetime
    expires_at: datetime
    provider_started_at: datetime | None = None

    @field_validator("created_at", "updated_at", "expires_at", "provider_started_at")
    @classmethod
    def require_aware_timestamps(cls, value: datetime | None, info) -> datetime | None:
        if value is None:
            return None
        return _require_aware_datetime(value, info.field_name)

    @model_validator(mode="after")
    def validate_reservation(self) -> "AIUsageReservation":
        _validate_mode_and_action(self.billing_mode, self.action)
        if self.billing_mode is AIUsageBillingMode.BYOK:
            raise ValueError("BYOK usage does not create managed reservations")
        if self.billing_mode is AIUsageBillingMode.MANAGED and self.units <= 0:
            raise ValueError("managed reservation requires positive units")
        if self.billing_mode is AIUsageBillingMode.MANAGED and self.entitlement_id is None:
            raise ValueError("managed reservation requires entitlement_id")
        if self.updated_at < self.created_at:
            raise ValueError("updated_at must not be earlier than created_at")
        if self.expires_at <= self.created_at:
            raise ValueError("expires_at must be later than created_at")
        if (
            self.status is AIUsageReservationStatus.RESERVED
            and self.provider_started_at is not None
        ):
            raise ValueError("reserved usage must not have provider_started_at")
        if (
            self.status is not AIUsageReservationStatus.RESERVED
            and self.provider_started_at is None
        ):
            if self.status in {
                AIUsageReservationStatus.PROVIDER_STARTED,
                AIUsageReservationStatus.CONSUMED,
                AIUsageReservationStatus.REFUNDED,
            }:
                raise ValueError(f"{self.status.value} reservation requires provider_started_at")
        return self


class AIUsageLedgerEntry(AIUsageModel):
    entry_id: Identifier
    idempotency_key: Identifier
    reservation_id: Identifier | None = None
    scope: AIUsageScope
    action: AIUsageAction
    billing_mode: AIUsageBillingMode
    event: AIUsageLedgerEvent
    units: NonNegativeUnits = Decimal("0")
    unit_direction: AIUsageUnitDirection | None = None
    provider_cost: ProviderCostMetadata | None = None
    job_id: Identifier | None = None
    actor_id: Identifier | None = None
    reason: str | None = Field(default=None, min_length=1, max_length=500)
    created_at: datetime
    metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("created_at")
    @classmethod
    def require_aware_created_at(cls, value: datetime) -> datetime:
        return _require_aware_datetime(value, "created_at")

    @model_validator(mode="after")
    def validate_ledger_entry(self) -> "AIUsageLedgerEntry":
        _validate_mode_and_action(self.billing_mode, self.action)
        if self.billing_mode is AIUsageBillingMode.BYOK and self.units != 0:
            raise ValueError("BYOK usage must not consume managed usage units")
        reservation_events = {
            AIUsageLedgerEvent.RESERVED,
            AIUsageLedgerEvent.PROVIDER_STARTED,
            AIUsageLedgerEvent.COMPLETED,
            AIUsageLedgerEvent.FAILED,
            AIUsageLedgerEvent.CONSUMED,
            AIUsageLedgerEvent.RELEASED,
            AIUsageLedgerEvent.REFUNDED,
            AIUsageLedgerEvent.EXPIRED,
        }
        unit_events = {
            AIUsageLedgerEvent.RESERVED,
            AIUsageLedgerEvent.CONSUMED,
            AIUsageLedgerEvent.RELEASED,
            AIUsageLedgerEvent.REFUNDED,
            AIUsageLedgerEvent.EXPIRED,
            AIUsageLedgerEvent.ADMIN_ADJUSTMENT,
        }
        if (
            self.billing_mode is AIUsageBillingMode.MANAGED
            and self.event in reservation_events
            and self.reservation_id is None
        ):
            raise ValueError(f"{self.event.value} event requires reservation_id")
        if self.billing_mode is AIUsageBillingMode.BYOK and self.reservation_id is not None:
            raise ValueError("BYOK ledger metadata must not reference a managed reservation")
        if self.event in unit_events and self.units <= 0:
            raise ValueError(f"{self.event.value} event requires positive units")
        if self.event is AIUsageLedgerEvent.ADMIN_ADJUSTMENT:
            if self.actor_id is None or self.reason is None or self.unit_direction is None:
                raise ValueError("admin adjustment requires actor_id, reason, and unit_direction")
        elif self.unit_direction is not None:
            raise ValueError("unit_direction is reserved for admin adjustments")
        if self.provider_cost is not None and self.event not in {
            AIUsageLedgerEvent.COMPLETED,
            AIUsageLedgerEvent.FAILED,
        }:
            raise ValueError("provider cost evidence belongs on completed or failed events")
        return self


class AIQuotaStatus(AIUsageModel):
    scope: AIUsageScope
    action: AIUsageAction
    billing_mode: AIUsageBillingMode
    allowed: bool
    entitlement_id: Identifier | None = None
    unit_limit: NonNegativeUnits = Decimal("0")
    unit_reserved: NonNegativeUnits = Decimal("0")
    unit_consumed: NonNegativeUnits = Decimal("0")
    unit_remaining: NonNegativeUnits = Decimal("0")
    required_units: NonNegativeUnits = Decimal("0")
    reason_code: AIQuotaErrorCode | None = None
    reset_at: datetime | None = None
    checked_at: datetime

    @field_validator("reset_at", "checked_at")
    @classmethod
    def require_aware_timestamps(cls, value: datetime | None, info) -> datetime | None:
        if value is None:
            return None
        return _require_aware_datetime(value, info.field_name)

    @model_validator(mode="after")
    def validate_quota_status(self) -> "AIQuotaStatus":
        _validate_mode_and_action(self.billing_mode, self.action)
        if self.billing_mode is AIUsageBillingMode.BYOK:
            if any(
                (
                    self.unit_limit,
                    self.unit_reserved,
                    self.unit_consumed,
                    self.unit_remaining,
                    self.required_units,
                )
            ):
                raise ValueError("BYOK quota status must not expose managed usage units")
        else:
            calculated_remaining = self.unit_limit - self.unit_reserved - self.unit_consumed
            if calculated_remaining < 0 or self.unit_remaining != calculated_remaining:
                raise ValueError("unit_remaining must match the non-negative entitlement balance")
            if self.allowed and self.entitlement_id is None:
                raise ValueError("allowed managed usage requires entitlement_id")
            if self.allowed and self.required_units > self.unit_remaining:
                raise ValueError("allowed usage cannot require more units than remain")
        if not self.allowed and self.reason_code is None:
            raise ValueError("blocked quota status requires reason_code")
        if self.allowed and self.reason_code is not None:
            raise ValueError("allowed quota status must not include reason_code")
        return self


class AIQuotaError(AIUsageModel):
    code: AIQuotaErrorCode
    kind: AIQuotaErrorKind
    message: str = Field(min_length=1, max_length=500)
    action: AIUsageAction
    billing_mode: AIUsageBillingMode
    provider: Identifier | None = None
    remaining_units: NonNegativeUnits | None = None
    required_units: PositiveUnits | None = None
    retryable: bool
    retry_after_seconds: int | None = Field(default=None, gt=0)
    settings_path: str | None = Field(default=None, min_length=1, max_length=256)
    details: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_error_envelope(self) -> "AIQuotaError":
        _validate_mode_and_action(self.billing_mode, self.action)
        expected_kind = {
            AIQuotaErrorCode.EXHAUSTED: AIQuotaErrorKind.QUOTA,
            AIQuotaErrorCode.RATE_LIMITED: AIQuotaErrorKind.RATE_LIMIT,
            AIQuotaErrorCode.ENTITLEMENT_MISSING: AIQuotaErrorKind.ENTITLEMENT,
            AIQuotaErrorCode.RESERVATION_CONFLICT: AIQuotaErrorKind.CONFLICT,
            AIQuotaErrorCode.SCOPE_INVALID: AIQuotaErrorKind.ENTITLEMENT,
        }[self.code]
        if self.kind is not expected_kind:
            raise ValueError(f"{self.code.value} requires kind {expected_kind.value}")
        if self.code is AIQuotaErrorCode.EXHAUSTED:
            if self.remaining_units is None or self.required_units is None:
                raise ValueError("quota exhaustion requires remaining_units and required_units")
            if self.required_units <= self.remaining_units:
                raise ValueError("quota exhaustion requires required_units above remaining_units")
            if self.retryable:
                raise ValueError("quota exhaustion is not retryable without an entitlement change")
        if self.code is AIQuotaErrorCode.RATE_LIMITED:
            if not self.retryable or self.retry_after_seconds is None:
                raise ValueError("rate limit errors require retryable and retry_after_seconds")
        elif self.retry_after_seconds is not None:
            raise ValueError("retry_after_seconds is reserved for rate limit errors")
        if self.code is AIQuotaErrorCode.ENTITLEMENT_MISSING and self.retryable:
            raise ValueError("missing entitlement is not retryable without user action")
        return self


_ALLOWED_RESERVATION_TRANSITIONS: dict[
    AIUsageReservationStatus,
    frozenset[AIUsageReservationStatus],
] = {
    AIUsageReservationStatus.RESERVED: frozenset(
        {
            AIUsageReservationStatus.PROVIDER_STARTED,
            AIUsageReservationStatus.RELEASED,
            AIUsageReservationStatus.EXPIRED,
        }
    ),
    AIUsageReservationStatus.PROVIDER_STARTED: frozenset(
        {
            AIUsageReservationStatus.CONSUMED,
            AIUsageReservationStatus.RELEASED,
            AIUsageReservationStatus.REFUNDED,
        }
    ),
    AIUsageReservationStatus.CONSUMED: frozenset({AIUsageReservationStatus.REFUNDED}),
    AIUsageReservationStatus.RELEASED: frozenset(),
    AIUsageReservationStatus.REFUNDED: frozenset(),
    AIUsageReservationStatus.EXPIRED: frozenset(),
}


def validate_reservation_transition(
    current: AIUsageReservationStatus,
    target: AIUsageReservationStatus,
) -> None:
    if target not in _ALLOWED_RESERVATION_TRANSITIONS[current]:
        raise ValueError(f"invalid reservation transition: {current.value} -> {target.value}")


def _validate_mode_and_action(
    billing_mode: AIUsageBillingMode,
    action: AIUsageAction,
) -> None:
    if billing_mode is AIUsageBillingMode.BYOK:
        if action is not AIUsageAction.BYOK_METADATA:
            raise ValueError("BYOK mode only supports byok_metadata")
        return
    if action is AIUsageAction.BYOK_METADATA:
        raise ValueError("managed mode must not use byok_metadata")


def _require_aware_datetime(value: datetime, field_name: str) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError(f"{field_name} must include a timezone")
    return value
