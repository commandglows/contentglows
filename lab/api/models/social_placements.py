"""Typed API contracts for placement planning and publish preflight."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


IssueSeverity = Literal["warning", "blocking"]


class PlacementIssue(BaseModel):
    code: str
    severity: IssueSeverity
    platform_id: str
    placement_id: str | None = None
    asset_id: str | None = None
    message: str


class PlacementSlot(BaseModel):
    placement_id: str
    label: str
    required: bool = False
    recommended: bool = False
    media_kinds: list[str] = Field(default_factory=list)
    provider_media_intent: str = ""
    rule_strictness: str = "advisory"
    selected_asset_id: str | None = None
    state: str = "missing"
    issues: list[PlacementIssue] = Field(default_factory=list)


class PlatformPlacementPlan(BaseModel):
    platform_id: str
    label: str
    can_publish: bool = True
    slots: list[PlacementSlot] = Field(default_factory=list)
    issues: list[PlacementIssue] = Field(default_factory=list)


class PlacementPlan(BaseModel):
    registry_version: str
    content_id: str
    format_id: str
    locale: str
    platforms: list[PlatformPlacementPlan]


class PublishPlatformTarget(BaseModel):
    platform: str
    account_id: str = Field(..., min_length=1)


class PublishPreflightRequest(BaseModel):
    content_record_id: str = Field(..., min_length=1)
    platforms: list[PublishPlatformTarget] = Field(..., min_length=1)
    registry_version: str | None = None


class ProviderMediaItemSummary(BaseModel):
    type: Literal["image", "video"]
    placement_id: str
    asset_id: str


class PublishPlatformPreflight(BaseModel):
    platform_id: str
    can_publish: bool
    slots: list[PlacementSlot] = Field(default_factory=list)
    issues: list[PlacementIssue] = Field(default_factory=list)
    media_items: list[ProviderMediaItemSummary] = Field(default_factory=list)


class PublishPreflightResponse(BaseModel):
    can_publish: bool
    registry_version: str
    content_id: str
    format_id: str
    platforms: list[PublishPlatformPreflight]
    issues: list[PlacementIssue] = Field(default_factory=list)


class ResolvedProviderMediaItem(BaseModel):
    """Internal-only resolved descriptor; URLs never appear in public responses."""

    type: Literal["image", "video"]
    url: str
    platform_id: str
    placement_id: str
    asset_id: str
    metadata: dict[str, Any] = Field(default_factory=dict)

