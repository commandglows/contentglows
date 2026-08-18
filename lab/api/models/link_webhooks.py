"""Models for link webhooks and conversions."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class LinkWebhookResponse(BaseModel):
    id: str
    userId: str
    projectId: str | None = None
    url: str
    secret: str | None = None
    events: list[str] = Field(default_factory=list)
    enabled: bool = True
    createdAt: datetime
    updatedAt: datetime


class LinkWebhookCreateRequest(BaseModel):
    projectId: str | None = None
    url: str
    secret: str | None = None
    events: list[str] | None = None
    enabled: bool | None = None


class LinkWebhookUpdateRequest(BaseModel):
    url: str | None = None
    secret: str | None = None
    events: list[str] | None = None
    enabled: bool | None = None


class LinkWebhookDeliveryResponse(BaseModel):
    id: str
    webhookId: str
    eventType: str
    url: str
    statusCode: int | None = None
    requestBody: str | None = None
    responseBody: str | None = None
    error: str | None = None
    deliveredAt: datetime | None = None
    createdAt: datetime


class LinkConversionResponse(BaseModel):
    id: str
    linkId: str
    userId: str
    projectId: str | None = None
    type: str
    revenue: float | None = None
    currency: str | None = None
    partnerId: str | None = None
    metadata: dict[str, Any] | None = None
    createdAt: datetime


class LinkConversionCreateRequest(BaseModel):
    linkId: str
    type: str
    revenue: float | None = None
    currency: str | None = None
    partnerId: str | None = None
    metadata: dict[str, Any] | None = None


class UtmTemplateResponse(BaseModel):
    id: str
    userId: str
    projectId: str | None = None
    name: str
    utmSource: str | None = None
    utmMedium: str | None = None
    utmCampaign: str | None = None
    utmTerm: str | None = None
    utmContent: str | None = None
    createdAt: datetime
    updatedAt: datetime


class UtmTemplateCreateRequest(BaseModel):
    projectId: str | None = None
    name: str
    utmSource: str | None = None
    utmMedium: str | None = None
    utmCampaign: str | None = None
    utmTerm: str | None = None
    utmContent: str | None = None


class UtmTemplateUpdateRequest(BaseModel):
    name: str | None = None
    utmSource: str | None = None
    utmMedium: str | None = None
    utmCampaign: str | None = None
    utmTerm: str | None = None
    utmContent: str | None = None
