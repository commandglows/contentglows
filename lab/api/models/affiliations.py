"""Models for link management endpoints."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class LinkClickResponse(BaseModel):
    id: str
    linkId: str
    userId: str
    projectId: str | None = None
    slug: str
    destinationUrl: str
    variantIndex: int = 0
    country: str | None = None
    device: str | None = None
    referrer: str | None = None
    userAgent: str | None = None
    createdAt: datetime


class LinkClickSummary(BaseModel):
    totalClicks: int
    countries: list[dict[str, Any]] = Field(default_factory=list)
    devices: list[dict[str, Any]] = Field(default_factory=list)
    referrers: list[dict[str, Any]] = Field(default_factory=list)
    daily: list[dict[str, Any]] = Field(default_factory=list)


class LinkVariantResponse(BaseModel):
    id: str
    linkId: str
    userId: str
    url: str
    weight: int = 1
    country: str | None = None
    device: str | None = None
    language: str | None = None
    createdAt: datetime
    updatedAt: datetime


class LinkVariantCreateRequest(BaseModel):
    url: str
    weight: int = 1
    country: str | None = None
    device: str | None = None
    language: str | None = None


class LinkVariantUpdateRequest(BaseModel):
    url: str | None = None
    weight: int | None = None
    country: str | None = None
    device: str | None = None
    language: str | None = None


class AffiliateLinkResponse(BaseModel):
    id: str
    userId: str
    projectId: str | None = None
    name: str
    url: str
    slug: str | None = None
    description: str | None = None
    contactUrl: str | None = None
    loginUrl: str | None = None
    researchSummary: str | None = None
    researchedAt: datetime | None = None
    category: str | None = None
    commission: str | None = None
    keywords: list[str] = Field(default_factory=list)
    status: str = "active"
    notes: str | None = None
    expiresAt: datetime | None = None
    createdAt: datetime
    updatedAt: datetime
    clickCount: int = 0


class AffiliateLinkCreateRequest(BaseModel):
    projectId: str | None = None
    name: str
    url: str
    slug: str | None = None
    description: str | None = None
    contactUrl: str | None = None
    loginUrl: str | None = None
    category: str | None = None
    commission: str | None = None
    keywords: list[str] | None = None
    status: str | None = None
    notes: str | None = None
    expiresAt: str | None = None


class AffiliateLinkUpdateRequest(BaseModel):
    name: str | None = None
    url: str | None = None
    slug: str | None = None
    description: str | None = None
    contactUrl: str | None = None
    loginUrl: str | None = None
    category: str | None = None
    commission: str | None = None
    keywords: list[str] | None = None
    status: str | None = None
    notes: str | None = None
    expiresAt: str | None = None
