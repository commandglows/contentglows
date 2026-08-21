"""Storage-agnostic contracts for platform-level authorization."""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class PlatformAdminCapability(str, Enum):
    AI_USAGE_READ_ALL = "ai_usage:read_all"
    AI_USAGE_ADJUST = "ai_usage:adjust"
    AI_USAGE_REFUND = "ai_usage:refund"
    AI_USAGE_OVERRIDE = "ai_usage:override"


class PlatformAdminGrantStatus(str, Enum):
    ACTIVE = "active"
    REVOKED = "revoked"


class PlatformAdminAuditOutcome(str, Enum):
    ALLOWED = "allowed"
    DENIED = "denied"
    CONFLICT = "conflict"
    FAILED = "failed"


class PlatformAdminModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class PlatformAdminGrant(PlatformAdminModel):
    grant_id: str = Field(min_length=1, max_length=128, pattern=r"^\S+$")
    user_id: str = Field(min_length=1, max_length=128, pattern=r"^\S+$")
    capabilities: tuple[PlatformAdminCapability, ...] = Field(min_length=1)
    status: PlatformAdminGrantStatus = PlatformAdminGrantStatus.ACTIVE
    reason: str = Field(min_length=1, max_length=500)
    granted_by: str = Field(min_length=1, max_length=128, pattern=r"^\S+$")
    granted_at: datetime
    revoked_by: str | None = Field(default=None, min_length=1, max_length=128)
    revoked_at: datetime | None = None
    version: int = Field(default=1, ge=1)

    @field_validator("granted_at", "revoked_at")
    @classmethod
    def require_aware_timestamp(cls, value: datetime | None) -> datetime | None:
        if value is not None and (value.tzinfo is None or value.utcoffset() is None):
            raise ValueError("platform admin timestamps must be timezone-aware")
        return value

    @model_validator(mode="after")
    def validate_grant(self) -> "PlatformAdminGrant":
        if len(set(self.capabilities)) != len(self.capabilities):
            raise ValueError("platform admin capabilities must be unique")
        if self.status is PlatformAdminGrantStatus.ACTIVE:
            if self.revoked_by is not None or self.revoked_at is not None:
                raise ValueError("active grant cannot include revocation metadata")
        elif self.revoked_by is None or self.revoked_at is None:
            raise ValueError("revoked grant requires actor and timestamp")
        if self.revoked_at is not None and self.revoked_at < self.granted_at:
            raise ValueError("revocation cannot precede the grant")
        return self

    def allows(self, capability: PlatformAdminCapability) -> bool:
        return (
            self.status is PlatformAdminGrantStatus.ACTIVE
            and capability in self.capabilities
        )


class PlatformAdminAuditEvent(PlatformAdminModel):
    event_id: str = Field(min_length=1, max_length=128, pattern=r"^\S+$")
    idempotency_key: str = Field(min_length=1, max_length=128, pattern=r"^\S+$")
    actor_user_id: str = Field(min_length=1, max_length=128, pattern=r"^\S+$")
    grant_id: str | None = Field(default=None, min_length=1, max_length=128)
    grant_version: int | None = Field(default=None, ge=1)
    capability: PlatformAdminCapability
    action: str = Field(min_length=1, max_length=128, pattern=r"^[a-z0-9_.:-]+$")
    target_user_id: str | None = Field(default=None, min_length=1, max_length=128)
    target_project_id: str | None = Field(default=None, min_length=1, max_length=128)
    reason: str = Field(min_length=1, max_length=500)
    before_ref: str | None = Field(default=None, min_length=1, max_length=256)
    after_ref: str | None = Field(default=None, min_length=1, max_length=256)
    outcome: PlatformAdminAuditOutcome
    created_at: datetime

    @field_validator("created_at")
    @classmethod
    def require_aware_created_at(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("platform admin audit timestamp must be timezone-aware")
        return value

    @model_validator(mode="after")
    def validate_grant_reference(self) -> "PlatformAdminAuditEvent":
        if (self.grant_id is None) != (self.grant_version is None):
            raise ValueError("grant id and version must be supplied together")
        if self.outcome is PlatformAdminAuditOutcome.ALLOWED and self.grant_id is None:
            raise ValueError("allowed admin action requires grant evidence")
        return self


class AuthorizedPlatformAdmin(PlatformAdminModel):
    actor_user_id: str
    grant_id: str
    grant_version: int
    capability: PlatformAdminCapability
