"""Link management — public redirects + authenticated click analytics and variants."""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from api.dependencies.auth import CurrentUser, require_current_user
from api.models.affiliations import (
    AffiliateLinkCreateRequest,
    AffiliateLinkResponse,
    AffiliateLinkUpdateRequest,
)
from api.models.links import (
    LinkClickResponse,
    LinkClickSummary,
    LinkVariantCreateRequest,
    LinkVariantResponse,
    LinkVariantUpdateRequest,
)
from api.services.user_data_store import user_data_store

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────
# Public router — /r (no auth)
# ─────────────────────────────────────────────────

public_links_router = APIRouter(prefix="/r", tags=["Links (Public)"])


@public_links_router.get("/{slug}", include_in_schema=False)
async def redirect_by_slug(request: Request, slug: str):
    affiliation = await user_data_store.get_affiliation_by_slug(slug)
    if not affiliation:
        raise HTTPException(status_code=404, detail="Link not found")
    if affiliation.get("status") != "active":
        raise HTTPException(status_code=404, detail="Link not found")
    expires_at = affiliation.get("expiresAt")
    if expires_at and isinstance(expires_at, datetime) and expires_at < datetime.now():
        raise HTTPException(status_code=404, detail="Link expired")
    destination = affiliation["url"]
    variant_index = 0
    variants = await user_data_store.list_link_variants(affiliation["userId"], affiliation["id"])
    if variants:
        selected = _pick_variant(variants, request)
        if selected:
            destination = selected["url"]
            variant_index = variants.index(selected)
    try:
        await user_data_store.create_link_click({
            "linkId": affiliation["id"],
            "userId": affiliation["userId"],
            "projectId": affiliation.get("projectId"),
            "slug": slug,
            "destinationUrl": destination,
            "variantIndex": variant_index,
            "country": request.headers.get("cf-ipcountry") or request.headers.get("x-country"),
            "device": _parse_device(request.headers.get("user-agent", "")),
            "referrer": request.headers.get("referer"),
            "userAgent": request.headers.get("user-agent"),
        })
    except Exception:
        logger.exception("Failed to record link click for slug %s", slug)
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url=destination, status_code=302)


def _parse_device(user_agent: str) -> str | None:
    ua = user_agent.lower()
    if "mobile" in ua:
        return "mobile"
    if "tablet" in ua:
        return "tablet"
    if "bot" in ua or "spider" in ua:
        return "bot"
    return "desktop"


def _pick_variant(variants: list[dict[str, Any]], request: Request) -> dict[str, Any] | None:
    targeted = []
    for v in variants:
        if v.get("country") and request.headers.get("cf-ipcountry"):
            if v["country"].upper() == request.headers.get("cf-ipcountry", "").upper():
                targeted.append(v)
        elif v.get("device") and _parse_device(request.headers.get("user-agent", "")):
            if v["device"].lower() == _parse_device(request.headers.get("user-agent", "")):
                targeted.append(v)
    if targeted:
        total = sum(v.get("weight", 1) for v in targeted)
        if total <= 0:
            return targeted[0]
        import random
        r = random.uniform(0, total)
        cum = 0.0
        for v in targeted:
            cum += v.get("weight", 1)
            if r <= cum:
                return v
        return targeted[-1]
    total = sum(v.get("weight", 1) for v in variants)
    if total <= 0:
        return variants[0]
    import random
    r = random.uniform(0, total)
    cum = 0.0
    for v in variants:
        cum += v.get("weight", 1)
        if r <= cum:
            return v
    return variants[-1]


# ─────────────────────────────────────────────────
# Authenticated router — /api/links
# ─────────────────────────────────────────────────

links_router = APIRouter(prefix="/api/links", tags=["Links"])


@links_router.get("/clicks", response_model=list[LinkClickResponse], summary="List link clicks")
async def list_link_clicks(
    linkId: str = Query(...),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: CurrentUser = Depends(require_current_user),
) -> list[LinkClickResponse]:
    clicks = await user_data_store.list_link_clicks(current_user.user_id, linkId, limit, offset)
    return [LinkClickResponse(**c) for c in clicks]


@links_router.get("/clicks/summary", response_model=LinkClickSummary, summary="Link click summary")
async def get_link_click_summary(
    linkId: str = Query(...),
    current_user: CurrentUser = Depends(require_current_user),
) -> LinkClickSummary:
    summary = await user_data_store.get_link_click_summary(current_user.user_id, linkId)
    return LinkClickSummary(**summary)


@links_router.post("/variants", response_model=LinkVariantResponse, status_code=201, summary="Create link variant")
async def create_link_variant(
    linkId: str = Query(...),
    request: LinkVariantCreateRequest = ...,
    current_user: CurrentUser = Depends(require_current_user),
) -> LinkVariantResponse:
    existing = await user_data_store.get_affiliation(current_user.user_id, linkId)
    if not existing:
        raise HTTPException(status_code=404, detail="Affiliate link not found")
    variant = await user_data_store.create_link_variant(current_user.user_id, linkId, request.model_dump(exclude_unset=True))
    return LinkVariantResponse(**variant)


@links_router.get("/variants", response_model=list[LinkVariantResponse], summary="List link variants")
async def list_link_variants(
    linkId: str = Query(...),
    current_user: CurrentUser = Depends(require_current_user),
) -> list[LinkVariantResponse]:
    existing = await user_data_store.get_affiliation(current_user.user_id, linkId)
    if not existing:
        raise HTTPException(status_code=404, detail="Affiliate link not found")
    variants = await user_data_store.list_link_variants(current_user.user_id, linkId)
    return [LinkVariantResponse(**v) for v in variants]


@links_router.put("/variants/{variant_id}", response_model=LinkVariantResponse, summary="Update link variant")
async def update_link_variant(
    variant_id: str,
    request: LinkVariantUpdateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> LinkVariantResponse:
    variant = await user_data_store.update_link_variant(current_user.user_id, variant_id, request.model_dump(exclude_unset=True))
    if not variant:
        raise HTTPException(status_code=404, detail="Variant not found")
    return LinkVariantResponse(**variant)


@links_router.delete("/variants/{variant_id}", summary="Delete link variant")
async def delete_link_variant(
    variant_id: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> dict:
    deleted = await user_data_store.delete_link_variant(current_user.user_id, variant_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Variant not found")
    return {"success": True, "id": variant_id}
