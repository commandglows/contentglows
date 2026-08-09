"""Authenticated placement-plan and publish-preflight endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import (
    require_active_publish_account,
    require_owned_content_record,
)
from api.models.social_placements import (
    PlacementPlan,
    PublishPreflightRequest,
    PublishPreflightResponse,
)
from api.services.social_placement_preflight import (
    build_placement_plan,
    run_publish_preflight,
)
from api.services.social_placement_registry import (
    REGISTRY_VERSION,
    RegistryLookupError,
    SUPPORTED_LOCALES,
    validate_platform_id,
)
from status.service import get_status_service


router = APIRouter(tags=["Social Placements"])


def _locale(value: str | None) -> str:
    locale = (value or "en").lower().split("-")[0]
    if locale not in SUPPORTED_LOCALES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "Unsupported locale", "supported_locales": list(SUPPORTED_LOCALES)},
        )
    return locale


async def _owned_content_or_404(content_id: str, current_user: CurrentUser, svc):
    try:
        content = await require_owned_content_record(content_id, current_user, svc)
    except HTTPException as exc:
        if exc.status_code in {403, 404}:
            raise HTTPException(status_code=404, detail="Content not found") from exc
        raise
    if getattr(content, "user_id", None) not in {None, current_user.user_id}:
        raise HTTPException(status_code=404, detail="Content not found")
    return content


def _canonical_platforms(values: list[str]) -> list[str]:
    try:
        return [validate_platform_id(value) for value in values]
    except RegistryLookupError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "PFL_UNSUPPORTED_PLATFORM",
                "registry_version": REGISTRY_VERSION,
                "supported_platform_ids": list(exc.supported_ids),
            },
        ) from exc


@router.get(
    "/api/content/{content_id}/placement-plan",
    response_model=PlacementPlan,
)
async def get_content_placement_plan(
    content_id: str,
    platform: list[str] = Query(..., min_length=1),
    locale: str | None = Query(None, max_length=35),
    current_user: CurrentUser = Depends(require_current_user),
):
    svc = get_status_service()
    content = await _owned_content_or_404(content_id, current_user, svc)
    platforms = _canonical_platforms(platform)
    return build_placement_plan(
        content=content,
        platform_ids=platforms,
        locale=_locale(locale),
    )


@router.post("/api/publish/preflight", response_model=PublishPreflightResponse)
async def publish_preflight(
    request: PublishPreflightRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    svc = get_status_service()
    content = await _owned_content_or_404(request.content_record_id, current_user, svc)
    platforms = _canonical_platforms([target.platform for target in request.platforms])
    for target, platform_id in zip(request.platforms, platforms):
        platform_alias = "twitter" if platform_id == "PLAT_X" else platform_id.removeprefix("PLAT_").lower()
        await require_active_publish_account(
            current_user=current_user,
            project_id=str(content.project_id),
            account_id=target.account_id,
            platform=platform_alias,
            provider="zernio",
        )
    return run_publish_preflight(
        status_service=svc,
        content=content,
        user_id=current_user.user_id,
        platform_ids=platforms,
        requested_registry_version=request.registry_version,
    ).response
