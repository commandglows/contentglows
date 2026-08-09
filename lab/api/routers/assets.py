"""Unified project asset library endpoints."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import require_owned_project_id
from api.models.status import (
    AttachGlobalProjectAssetRequest,
    AssetTagModerationRequest,
    AssetUnderstandingJobResponse,
    AssetUnderstandingResultResponse,
    AssetUnderstandingStatusResponse,
    ClearProjectAssetPrimaryRequest,
    ClearProjectAssetPrimaryResponse,
    ProjectAssetRecommendationRequest,
    ProjectAssetRecommendationResponse,
    ProjectAssetCleanupReportResponse,
    ProjectAssetCategoryAssignmentRequest,
    ProjectAssetCategoryCatalogResponse,
    ProjectAssetEligibilityRequest,
    ProjectAssetEligibilityResponse,
    ProjectAssetEventResponse,
    ProjectAssetListResponse,
    ProjectAssetPrimaryRequest,
    ProjectAssetResponse,
    ProjectAssetUsageResponse,
    QueueAssetUnderstandingRequest,
    RetryAssetUnderstandingRequest,
    SelectProjectAssetRequest,
)
from api.services.project_asset_cleanup import build_project_asset_cleanup_report
from api.services.project_asset_storage import build_project_asset_storage_descriptor
from status.asset_categories import (
    get_project_asset_category_catalog,
    suggested_project_asset_export_file_name,
)
from status.service import (
    ContentNotFoundError,
    ProjectAssetEligibilityError,
    get_status_service,
)

router = APIRouter(prefix="/api/projects/{project_id}/assets", tags=["Project Assets"])


def _asset_to_response(asset) -> ProjectAssetResponse:
    payload = asset.model_dump()
    payload["suggested_export_file_name"] = suggested_project_asset_export_file_name(
        asset_id=payload["id"],
        category_id=payload.get("category_id"),
        subcategory_id=payload.get("subcategory_id"),
        original_file_name=payload.get("original_file_name"),
        file_name=payload.get("file_name"),
    )
    payload["storage_descriptor"] = build_project_asset_storage_descriptor(
        storage_uri=payload.get("storage_uri"),
        storage_locator=getattr(asset, "storage_locator", None),
        status=payload["status"],
        media_kind=payload["media_kind"],
        mime_type=payload.get("mime_type"),
    )
    payload["storage_uri"] = None
    payload["storage_locator"] = None
    return ProjectAssetResponse(**payload)


def _usage_to_response(usage) -> ProjectAssetUsageResponse:
    return ProjectAssetUsageResponse(**usage.model_dump())


def _event_to_response(event) -> ProjectAssetEventResponse:
    return ProjectAssetEventResponse(**event.model_dump())


def _understanding_job_to_response(job) -> AssetUnderstandingJobResponse:
    return AssetUnderstandingJobResponse(**job.model_dump())


def _understanding_result_to_response(result) -> AssetUnderstandingResultResponse:
    return AssetUnderstandingResultResponse(
        asset_id=result.asset_id,
        project_id=result.project_id,
        status="completed",
        summary=result.summary,
        tags=result.tags,
        segments=result.segments,
        source_attribution=result.source_attribution,
        credential_source=result.credential_source,
        provider=result.provider,
        error_code=None,
    )


@router.get("", response_model=ProjectAssetListResponse)
async def list_project_assets(
    project_id: str,
    media_kind: Optional[str] = Query(None),
    source: Optional[str] = Query(None),
    category_id: Optional[str] = Query(None),
    subcategory_id: Optional[str] = Query(None),
    include_tombstoned: bool = Query(False),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        items = svc.list_project_assets(
            project_id=project_id,
            user_id=current_user.user_id,
            media_kind=media_kind,
            source=source,
            category_id=category_id,
            subcategory_id=subcategory_id,
            include_tombstoned=include_tombstoned,
            limit=limit,
            offset=offset,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return ProjectAssetListResponse(items=[_asset_to_response(a) for a in items], total=len(items))


@router.get("/categories", response_model=ProjectAssetCategoryCatalogResponse)
async def get_project_asset_category_catalog_route(
    project_id: str,
    locale: Optional[str] = Query(None, max_length=35),
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    return ProjectAssetCategoryCatalogResponse(**get_project_asset_category_catalog(locale))


@router.get("/cleanup-report", response_model=ProjectAssetCleanupReportResponse)
async def get_project_asset_cleanup_report(
    project_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    items = svc.list_project_assets(
        project_id=project_id,
        user_id=current_user.user_id,
        include_tombstoned=True,
        limit=200,
        offset=0,
    )
    return ProjectAssetCleanupReportResponse(**build_project_asset_cleanup_report(items))


@router.get("/{asset_id}", response_model=ProjectAssetResponse)
async def get_project_asset_detail(
    project_id: str,
    asset_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        return _asset_to_response(
            svc.get_project_asset_detail(
                project_id=project_id,
                user_id=current_user.user_id,
                asset_id=asset_id,
            )
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))


@router.patch("/{asset_id}/category", response_model=ProjectAssetResponse)
async def assign_project_asset_category(
    project_id: str,
    asset_id: str,
    request: ProjectAssetCategoryAssignmentRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        asset = svc.assign_project_asset_category(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
            category_id=request.category_id,
            subcategory_id=request.subcategory_id,
        )
        return _asset_to_response(asset)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/{asset_id}/eligibility", response_model=ProjectAssetEligibilityResponse)
async def get_project_asset_eligibility(
    project_id: str,
    asset_id: str,
    request: ProjectAssetEligibilityRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    result = svc.get_project_asset_eligibility(
        project_id=project_id,
        user_id=current_user.user_id,
        asset_id=asset_id,
        usage_action=request.usage_action,
        target_type=request.target_type,
        target_id=request.target_id,
    )
    return ProjectAssetEligibilityResponse(**result)


@router.get("/{asset_id}/usage", response_model=list[ProjectAssetUsageResponse])
async def get_project_asset_usage(
    project_id: str,
    asset_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        items = svc.get_project_asset_usage(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return [_usage_to_response(i) for i in items]


@router.get("/{asset_id}/events", response_model=list[ProjectAssetEventResponse])
async def get_project_asset_events(
    project_id: str,
    asset_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        items = svc.get_project_asset_events(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return [_event_to_response(i) for i in items]


@router.post("/{asset_id}/select", response_model=ProjectAssetUsageResponse, status_code=201)
async def select_project_asset(
    project_id: str,
    asset_id: str,
    request: SelectProjectAssetRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        usage = svc.select_project_asset(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
            target_type=request.target_type,
            target_id=request.target_id,
            usage_action=request.usage_action,
            placement=request.placement,
            is_primary=request.is_primary,
            metadata=request.metadata,
        )
        return _usage_to_response(usage)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ProjectAssetEligibilityError as exc:
        raise HTTPException(status_code=409, detail=str(exc))


@router.post("/{asset_id}/primary", response_model=ProjectAssetUsageResponse, status_code=201)
async def set_project_asset_primary(
    project_id: str,
    asset_id: str,
    request: ProjectAssetPrimaryRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        usage = svc.set_project_asset_primary(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
            target_type=request.target_type,
            target_id=request.target_id,
            usage_action=request.usage_action,
            placement=request.placement,
            metadata=request.metadata,
        )
        return _usage_to_response(usage)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ProjectAssetEligibilityError as exc:
        raise HTTPException(status_code=409, detail=str(exc))


@router.post("/clear-primary", response_model=ClearProjectAssetPrimaryResponse)
async def clear_project_asset_primary(
    project_id: str,
    request: ClearProjectAssetPrimaryRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    changed = svc.clear_project_asset_primary(
        project_id=project_id,
        user_id=current_user.user_id,
        target_type=request.target_type,
        target_id=request.target_id,
        placement=request.placement,
    )
    return ClearProjectAssetPrimaryResponse(cleared_count=changed)


@router.post("/{asset_id}/preview-refresh", response_model=ProjectAssetResponse)
async def refresh_project_asset_preview(
    project_id: str,
    asset_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        return _asset_to_response(
            svc.get_project_asset_detail(
                project_id=project_id,
                user_id=current_user.user_id,
                asset_id=asset_id,
            )
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/{asset_id}/tombstone", response_model=ProjectAssetResponse)
async def tombstone_project_asset(
    project_id: str,
    asset_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        asset = svc.tombstone_project_asset(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
        )
        return _asset_to_response(asset)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/{asset_id}/restore", response_model=ProjectAssetResponse)
async def restore_project_asset(
    project_id: str,
    asset_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        asset = svc.restore_project_asset(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
        )
        return _asset_to_response(asset)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/{asset_id}/understanding/queue", response_model=AssetUnderstandingJobResponse, status_code=201)
async def queue_asset_understanding(
    project_id: str,
    asset_id: str,
    request: QueueAssetUnderstandingRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        job = svc.queue_asset_understanding_job(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
            idempotency_key=request.idempotency_key,
            provider=request.provider,
        )
        return _understanding_job_to_response(job)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/{asset_id}/understanding/status", response_model=AssetUnderstandingStatusResponse)
async def get_asset_understanding_status(
    project_id: str,
    asset_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        data = svc.get_latest_asset_understanding_status(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return AssetUnderstandingStatusResponse(
        job=_understanding_job_to_response(data["job"]) if data["job"] else None,
        result=_understanding_result_to_response(data["result"]) if data["result"] else None,
    )


@router.post("/{asset_id}/understanding/retry", response_model=AssetUnderstandingJobResponse)
async def retry_asset_understanding(
    project_id: str,
    asset_id: str,
    request: RetryAssetUnderstandingRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        job = svc.retry_asset_understanding_job(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
            job_id=request.job_id,
        )
        return _understanding_job_to_response(job)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/{asset_id}/understanding/tags/moderate", response_model=AssetUnderstandingStatusResponse)
async def moderate_asset_understanding_tags(
    project_id: str,
    asset_id: str,
    request: AssetTagModerationRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        data = svc.moderate_asset_understanding_tags(
            project_id=project_id,
            user_id=current_user.user_id,
            asset_id=asset_id,
            decisions=[item.model_dump() for item in request.decisions],
            manual_tags=request.manual_tags,
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return AssetUnderstandingStatusResponse(
        job=_understanding_job_to_response(data["job"]) if data["job"] else None,
        result=_understanding_result_to_response(data["result"]) if data["result"] else None,
    )


@router.post("/recommend", response_model=ProjectAssetRecommendationResponse)
async def recommend_project_assets(
    project_id: str,
    request: ProjectAssetRecommendationRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    items = svc.recommend_project_assets_for_brief(
        project_id=project_id,
        user_id=current_user.user_id,
        desired_tags=request.desired_tags,
        limit=request.limit,
        include_global_candidates=request.include_global_candidates,
    )
    return ProjectAssetRecommendationResponse(items=items)


@router.post("/attach-global", response_model=ProjectAssetResponse, status_code=201)
async def attach_global_project_asset(
    project_id: str,
    request: AttachGlobalProjectAssetRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    svc = get_status_service()
    try:
        asset = svc.attach_global_project_asset(
            project_id=project_id,
            user_id=current_user.user_id,
            global_asset_id=request.global_asset_id,
        )
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return _asset_to_response(asset)
