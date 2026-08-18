"""Link webhooks, conversions, and UTM templates."""

from __future__ import annotations

import logging
import secrets
from datetime import datetime
from typing import Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from api.dependencies.auth import CurrentUser, require_current_user
from api.models.link_webhooks import (
    LinkConversionCreateRequest,
    LinkConversionResponse,
    LinkWebhookCreateRequest,
    LinkWebhookDeliveryResponse,
    LinkWebhookResponse,
    LinkWebhookUpdateRequest,
    UtmTemplateCreateRequest,
    UtmTemplateResponse,
    UtmTemplateUpdateRequest,
)
from api.services.user_data_store import user_data_store

logger = logging.getLogger(__name__)

webhooks_router = APIRouter(prefix="/api/webhooks", tags=["Link Webhooks"])
conversions_router = APIRouter(prefix="/api/links/conversions", tags=["Link Conversions"])
utm_router = APIRouter(prefix="/api/utm", tags=["UTM Templates"])


# ─────────────────────────────────────────────────
# Webhooks CRUD
# ─────────────────────────────────────────────────

@webhooks_router.post("/links", response_model=LinkWebhookResponse, status_code=201)
async def create_link_webhook(
    request: Request,
    body: LinkWebhookCreateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> LinkWebhookResponse:
    webhook = await user_data_store.create_link_webhook(current_user.user_id, {
        "projectId": body.projectId,
        "url": body.url,
        "secret": body.secret or secrets.token_hex(16),
        "events": body.events or ["link.clicked"],
        "enabled": body.enabled,
    })
    return LinkWebhookResponse(**webhook)


@webhooks_router.get("/links", response_model=list[LinkWebhookResponse])
async def list_link_webhooks(
    projectId: str | None = Query(None),
    current_user: CurrentUser = Depends(require_current_user),
) -> list[LinkWebhookResponse]:
    webhooks = await user_data_store.list_link_webhooks(current_user.user_id, projectId)
    return [LinkWebhookResponse(**w) for w in webhooks]


@webhooks_router.get("/links/{webhook_id}", response_model=LinkWebhookResponse)
async def get_link_webhook(
    webhook_id: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> LinkWebhookResponse:
    webhook = await user_data_store.get_link_webhook(current_user.user_id, webhook_id)
    if not webhook:
        raise HTTPException(status_code=404, detail="Webhook not found")
    return LinkWebhookResponse(**webhook)


@webhooks_router.patch("/links/{webhook_id}", response_model=LinkWebhookResponse)
async def update_link_webhook(
    webhook_id: str,
    body: LinkWebhookUpdateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> LinkWebhookResponse:
    payload = body.model_dump(exclude_unset=True)
    webhook = await user_data_store.update_link_webhook(current_user.user_id, webhook_id, payload)
    if not webhook:
        raise HTTPException(status_code=404, detail="Webhook not found")
    return LinkWebhookResponse(**webhook)


@webhooks_router.delete("/links/{webhook_id}")
async def delete_link_webhook(
    webhook_id: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> dict:
    deleted = await user_data_store.delete_link_webhook(current_user.user_id, webhook_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Webhook not found")
    return {"success": True, "id": webhook_id}


@webhooks_router.get("/links/{webhook_id}/deliveries", response_model=list[LinkWebhookDeliveryResponse])
async def list_link_webhook_deliveries(
    webhook_id: str,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: CurrentUser = Depends(require_current_user),
) -> list[LinkWebhookDeliveryResponse]:
    webhook = await user_data_store.get_link_webhook(current_user.user_id, webhook_id)
    if not webhook:
        raise HTTPException(status_code=404, detail="Webhook not found")
    deliveries = await user_data_store.list_link_webhook_deliveries(current_user.user_id, webhook_id, limit, offset)
    return [LinkWebhookDeliveryResponse(**d) for d in deliveries]


# ─────────────────────────────────────────────────
# Public webhook receiver
# ─────────────────────────────────────────────────

class WebhookEvent(BaseModel):
    type: str
    data: dict[str, Any] = Field(default_factory=dict)


@webhooks_router.post("/links/public/{webhook_id}", include_in_schema=False)
async def public_webhook_receiver(webhook_id: str, request: Request):
    webhook = await user_data_store.get_link_webhook_by_public_id(webhook_id)
    if not webhook or not webhook.get("enabled"):
        raise HTTPException(status_code=404, detail="Webhook not found")

    event_type = request.headers.get("x-dub-event", "unknown")
    body = await request.body()
    body_text = body.decode("utf-8", errors="replace") if body else ""
    status_code = 200
    response_text = ""
    error = None
    delivered_at = datetime.now()

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(10.0)) as client:
            resp = await client.post(
                webhook["url"],
                content=body_text,
                headers={"Content-Type": "application/json", "User-Agent": "ContentGlows-Webhook/1.0"},
            )
            status_code = resp.status_code
            response_text = resp.text
    except Exception as exc:  # noqa: BLE001
        error = str(exc)
        status_code = 0

    await user_data_store.create_link_webhook_delivery({
        "webhookId": webhook["id"],
        "eventType": event_type,
        "url": webhook["url"],
        "statusCode": status_code,
        "requestBody": body_text[:2000],
        "responseBody": response_text[:2000] if response_text else None,
        "error": error,
        "deliveredAt": delivered_at.isoformat() if delivered_at else None,
    })

    return {"received": True}


# ─────────────────────────────────────────────────
# Conversions
# ─────────────────────────────────────────────────

@conversions_router.post("", response_model=LinkConversionResponse, status_code=201)
async def create_link_conversion(
    body: LinkConversionCreateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> LinkConversionResponse:
    conversion = await user_data_store.create_link_conversion(current_user.user_id, body.model_dump())
    return LinkConversionResponse(**conversion)


@conversions_router.get("", response_model=list[LinkConversionResponse])
async def list_link_conversions(
    linkId: str = Query(...),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: CurrentUser = Depends(require_current_user),
) -> list[LinkConversionResponse]:
    conversions = await user_data_store.list_link_conversions(current_user.user_id, linkId, limit, offset)
    return [LinkConversionResponse(**c) for c in conversions]


@conversions_router.get("/summary", response_model=dict)
async def get_link_conversion_summary(
    linkId: str = Query(...),
    current_user: CurrentUser = Depends(require_current_user),
) -> dict:
    summary = await user_data_store.get_link_conversion_summary(current_user.user_id, linkId)
    return summary


# ─────────────────────────────────────────────────
# UTM Templates
# ─────────────────────────────────────────────────

@utm_router.post("", response_model=UtmTemplateResponse, status_code=201)
async def create_utm_template(
    body: UtmTemplateCreateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> UtmTemplateResponse:
    template = await user_data_store.create_utm_template(current_user.user_id, body.model_dump())
    return UtmTemplateResponse(**template)


@utm_router.get("", response_model=list[UtmTemplateResponse])
async def list_utm_templates(
    projectId: str | None = Query(None),
    current_user: CurrentUser = Depends(require_current_user),
) -> list[UtmTemplateResponse]:
    templates = await user_data_store.list_utm_templates(current_user.user_id, projectId)
    return [UtmTemplateResponse(**t) for t in templates]


@utm_router.patch("/{template_id}", response_model=UtmTemplateResponse)
async def update_utm_template(
    template_id: str,
    body: UtmTemplateUpdateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> UtmTemplateResponse:
    template = await user_data_store.update_utm_template(current_user.user_id, template_id, body.model_dump(exclude_unset=True))
    if not template:
        raise HTTPException(status_code=404, detail="UTM template not found")
    return UtmTemplateResponse(**template)


@utm_router.delete("/{template_id}")
async def delete_utm_template(
    template_id: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> dict:
    deleted = await user_data_store.delete_utm_template(current_user.user_id, template_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="UTM template not found")
    return {"success": True, "id": template_id}
