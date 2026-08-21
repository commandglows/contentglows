"""Image Robot API endpoints

Exposes the Image Robot Crew functionality via REST API for:
- Generating images for articles
- Uploading single images with optimization
- Checking Bunny Optimizer status
- Viewing generation history

IMPORTANT: Uses lazy imports for heavy dependencies.
"""

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from datetime import datetime, timedelta
import asyncio
import time
import json
import re
import logging
import uuid
from pathlib import Path
from typing import TYPE_CHECKING, Any, Dict, Optional
from urllib.parse import urlsplit

from api.models.images import (
    GenerateImagesRequest,
    GenerateImagesResponse,
    GeneratedImageResponse,
    UploadImageRequest,
    UploadImageResponse,
    OptimizerStatusResponse,
    ImageRobotHistoryResponse,
    ImageRobotHistoryItem,
    ImageProfileData,
    CreateImageProfileRequest,
    ListImageProfilesResponse,
    GenerateImageFromProfileRequest,
    GenerateImageFromProfileResponse,
    ImageGenerationListResponse,
    ImageGenerationRecord,
    ImageReferenceCreateRequest,
    ImageReferenceListResponse,
    ImageReferenceRecord,
    ImageReferenceUpdateRequest,
)
from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import require_owned_project_id
from api.dependencies import get_image_pipeline
from api.dependencies.ai_usage import (
    AIUsageRuntimeProvider,
    get_ai_usage_runtime_provider,
)
from api.models.ai_usage import (
    AIQuotaError,
    AIQuotaErrorCode,
    AIQuotaErrorKind,
    AIUsageAction,
    AIUsageBillingMode,
    AIUsageScope,
    ProviderCostMetadata,
)
from api.services.ai_usage_service import (
    AIUsageQuotaRejected,
    AIUsageService,
    AIUsageTransitionConflict,
)
from api.services.ai_usage_policies import AIUsageFailureBehavior
from api.services.ai_image_generation import generate_openai_image_to_file
from api.services.flux_image_generation import (
    DEFAULT_FLUX_MODEL,
    FluxImageGenerationError,
    FluxImageGenerator,
    image_type_dimensions,
)
from api.services.image_generation_store import image_generation_store
from api.services.image_profiles import ImageProfileStore
from api.services.job_store import job_store

# Type hint only - not loaded at runtime
if TYPE_CHECKING:
    from agents.images.image_crew import ImagePipeline

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/images",
    tags=["Image Robot"],
    responses={404: {"description": "Not found"}},
    dependencies=[Depends(require_current_user)],
)


def _sanitize_project_id(project_id: str) -> str:
    safe = re.sub(r"[^a-zA-Z0-9_-]+", "-", project_id).strip("-")
    return safe or "unknown-project"


async def _get_project_scoped_data_dir(
    crew: "ImagePipeline",
    project_id: str,
    current_user: CurrentUser,
) -> Path:
    """Resolve and ensure per-project image data directory."""
    if not project_id:
        raise HTTPException(status_code=400, detail="project_id is required")

    await require_owned_project_id(project_id, current_user)

    project_dir = Path(crew.data_dir) / "projects" / _sanitize_project_id(project_id)
    project_dir.mkdir(parents=True, exist_ok=True)
    return project_dir


def _append_history_item(history_file: Path, item: Dict[str, Any]) -> None:
    """Append one item to workflow history JSON."""
    history: list[Dict[str, Any]] = []
    if history_file.exists():
        try:
            with open(history_file, "r", encoding="utf-8") as handle:
                data = json.load(handle)
            if isinstance(data, list):
                history = data
        except Exception:
            history = []

    history.append(item)
    # Keep a bounded file size.
    if len(history) > 1000:
        history = history[-1000:]

    with open(history_file, "w", encoding="utf-8") as handle:
        json.dump(history, handle, indent=2, ensure_ascii=True)


def _sanitize_filename(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    if not normalized:
        return "image"
    return normalized[:120]


def _ensure_extension(file_name: str, image_format: str = "jpg") -> str:
    if "." in Path(file_name).name:
        return file_name
    safe_ext = image_format.lower() if image_format else "jpg"
    if safe_ext not in {"jpg", "jpeg", "png", "webp", "avif"}:
        safe_ext = "jpg"
    return f"{file_name}.{safe_ext}"


def _build_profile_file_name(
    profile_id: str,
    title_text: str,
    image_format: str = "jpg",
) -> str:
    ts = int(time.time())
    base = f"{_sanitize_filename(profile_id)}-{_sanitize_filename(title_text)}-{ts}"
    return _ensure_extension(base[:180], image_format=image_format)


def _map_optimizer_image_type(image_type: str) -> str:
    mapping = {
        "hero_image": "hero",
        "section_image": "section",
        "thumbnail": "thumbnail",
        "og_card": "hero",
    }
    return mapping.get(image_type, "hero")


def _build_ai_prompt(
    profile: Dict[str, Any],
    title_text: str,
    subtitle_text: Optional[str] = None,
    custom_prompt: Optional[str] = None,
) -> str:
    """Build a visual prompt for AI image providers."""
    if custom_prompt:
        return custom_prompt.strip()

    parts: list[str] = []
    base_prompt = (profile.get("base_prompt") or "").strip()
    if base_prompt:
        parts.append(base_prompt)

    parts.append(f"Main subject/text concept: {title_text.strip()}")
    if subtitle_text:
        parts.append(f"Secondary concept: {subtitle_text.strip()}")

    tags = profile.get("tags") or []
    if tags:
        parts.append(f"Keywords: {', '.join(str(t) for t in tags)}")

    image_type = profile.get("image_type", "hero_image")
    if image_type == "og_card":
        parts.append("Composition: social card style, strong readability, clean hierarchy.")
    elif image_type == "thumbnail":
        parts.append("Composition: bold thumbnail style with high contrast and clear focal point.")
    elif image_type == "section_image":
        parts.append("Composition: supportive editorial section illustration.")
    else:
        parts.append("Composition: hero image style, editorial quality.")

    return " ".join(parts)


def _is_durable_bunny_url(value: str) -> bool:
    parsed = urlsplit(value)
    if parsed.scheme not in {"http", "https"}:
        return False
    host = (parsed.netloc or "").lower()
    return (
        host.endswith(".b-cdn.net")
        or host.endswith(".bunnycdn.com")
        or host == "storage.bunnycdn.com"
    )


def _configured_flux_model() -> str:
    import os

    return os.getenv("BFL_IMAGE_MODEL") or os.getenv("FLUX_IMAGE_MODEL") or DEFAULT_FLUX_MODEL


def _configured_flux_safety_tolerance() -> int:
    import os

    raw_value = os.getenv("BFL_SAFETY_TOLERANCE") or os.getenv("FLUX_SAFETY_TOLERANCE") or "2"
    try:
        return max(0, min(5, int(raw_value)))
    except ValueError:
        return 2


def _flux_api_key_configured() -> bool:
    import os

    return bool(os.getenv("BFL_API_KEY") or os.getenv("BLACK_FOREST_LABS_API_KEY"))


async def _ensure_image_generation_store() -> None:
    try:
        await image_generation_store.ensure_tables()
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


def _quota_http_error(rejection: AIUsageQuotaRejected, *, provider: str) -> HTTPException:
    status = rejection.status
    code = status.reason_code or AIQuotaErrorCode.RESERVATION_CONFLICT
    kind = {
        AIQuotaErrorCode.EXHAUSTED: AIQuotaErrorKind.QUOTA,
        AIQuotaErrorCode.ENTITLEMENT_MISSING: AIQuotaErrorKind.ENTITLEMENT,
        AIQuotaErrorCode.RESERVATION_CONFLICT: AIQuotaErrorKind.CONFLICT,
        AIQuotaErrorCode.SCOPE_INVALID: AIQuotaErrorKind.ENTITLEMENT,
        AIQuotaErrorCode.RATE_LIMITED: AIQuotaErrorKind.RATE_LIMIT,
    }[code]
    error = AIQuotaError(
        code=code,
        kind=kind,
        message=(
            "Managed AI usage quota is exhausted."
            if code is AIQuotaErrorCode.EXHAUSTED
            else "Managed AI usage entitlement is unavailable."
        ),
        action=status.action,
        billing_mode=AIUsageBillingMode.MANAGED,
        provider=provider,
        remaining_units=(
            status.unit_remaining if code is AIQuotaErrorCode.EXHAUSTED else None
        ),
        required_units=(
            status.required_units if code is AIQuotaErrorCode.EXHAUSTED else None
        ),
        retryable=False,
        settings_path="/settings/ai-runtime",
    )
    return HTTPException(
        status_code=402,
        detail=error.model_dump(mode="json", by_alias=True),
    )


def _quota_conflict_http_error(*, provider: str) -> HTTPException:
    error = AIQuotaError(
        code=AIQuotaErrorCode.RESERVATION_CONFLICT,
        kind=AIQuotaErrorKind.CONFLICT,
        message="Managed AI usage reservation changed concurrently.",
        action=AIUsageAction.FLUX_IMAGE_GENERATION,
        billing_mode=AIUsageBillingMode.MANAGED,
        provider=provider,
        retryable=True,
        settings_path="/settings/ai-runtime",
    )
    return HTTPException(
        status_code=409,
        detail=error.model_dump(mode="json", by_alias=True),
    )


def _generation_record(data: Dict[str, Any]) -> ImageGenerationRecord:
    return ImageGenerationRecord(**data)


def _reference_record(data: Dict[str, Any]) -> ImageReferenceRecord:
    return ImageReferenceRecord(**data)


async def _resolve_flux_references(
    *,
    request: GenerateImageFromProfileRequest,
    current_user: CurrentUser,
) -> list[Dict[str, Any]]:
    if request.reference_ids:
        references: list[Dict[str, Any]] = []
        for reference_id in request.reference_ids[:8]:
            ref = await image_generation_store.get_reference(
                reference_id,
                project_id=request.project_id,
                user_id=current_user.user_id,
            )
            if not ref:
                raise HTTPException(status_code=404, detail=f"Visual reference not found: {reference_id}")
            if not ref.get("approved"):
                raise HTTPException(status_code=403, detail=f"Visual reference is not approved: {reference_id}")
            references.append(ref)
        return references

    if not request.use_visual_memory:
        return []

    return await image_generation_store.list_references(
        project_id=request.project_id,
        user_id=current_user.user_id,
        approved_only=True,
        limit=8,
    )


async def _update_job_safely(job_id: str, **fields: Any) -> None:
    try:
        if job_store.db_client:
            await job_store.update(job_id, **fields)
    except Exception as exc:
        logger.warning(f"Failed to update image generation job {job_id}: {exc}")


def _record_generated_project_asset(
    *,
    project_id: str,
    user_id: str,
    generation_id: str,
    profile_id: str,
    image_type: str,
    model: str,
    file_name: str,
    cdn_url: str,
    primary_url: Optional[str],
    responsive_urls: Dict[str, str],
    output_format: str,
) -> Optional[str]:
    try:
        from status.schemas import ProjectAssetMediaKind, ProjectAssetSource
        from status.service import get_status_service

        media_kind = (
            ProjectAssetMediaKind.THUMBNAIL.value
            if image_type == "thumbnail"
            else ProjectAssetMediaKind.IMAGE.value
        )
        mime_format = "jpeg" if output_format == "jpg" else output_format
        asset = get_status_service().create_project_asset(
            project_id=project_id,
            user_id=user_id,
            media_kind=media_kind,
            source=ProjectAssetSource.IMAGE_ROBOT.value,
            mime_type=f"image/{mime_format}",
            file_name=file_name,
            storage_uri=cdn_url,
            source_asset_id=generation_id,
            metadata={
                "provider": "flux",
                "model": model,
                "generation_id": generation_id,
                "profile_id": profile_id,
                "primary_url": primary_url,
                "responsive_urls": responsive_urls,
            },
        )
        return asset.id
    except Exception as exc:
        logger.warning(f"Failed to register generated image as project asset: {exc}")
        return None


async def _reconcile_failed_flux_usage(
    *,
    ai_usage_service: AIUsageService,
    scope: AIUsageScope,
    reservation_id: str,
    provider_started: bool,
    failure_behavior: AIUsageFailureBehavior,
    provider_cost: ProviderCostMetadata | None,
    reason: str,
) -> tuple[str, str | None]:
    """Settle a failed generation idempotently or leave recoverable state."""
    try:
        if provider_started and failure_behavior is AIUsageFailureBehavior.REFUND:
            await ai_usage_service.refund(
                scope=scope,
                reservation_id=reservation_id,
                reason=reason,
                provider_cost=provider_cost,
            )
            return "refunded", "refunded"
        await ai_usage_service.release(
            scope=scope,
            reservation_id=reservation_id,
            reason=reason,
            provider_cost=provider_cost,
        )
        return "released", "released"
    except Exception:
        logger.exception("Flux failure usage reconciliation is pending")
        return "reconciliation_pending", None


async def _run_flux_generation_job(
    *,
    crew: "ImagePipeline",
    generation_id: str,
    job_id: str,
    project_id: str,
    user_id: str,
    profile_id: str,
    image_type: str,
    prompt: str,
    model: str,
    width: int,
    height: int,
    seed: Optional[int],
    output_format: str,
    safety_tolerance: int,
    reference_urls: list[str],
    file_name: str,
    alt_text: str,
    path_type: str,
    ai_usage_service: AIUsageService,
    usage_scope: AIUsageScope,
    reservation_id: str,
    failure_behavior: AIUsageFailureBehavior,
) -> None:
    local_path: Optional[str] = None
    provider_started = False
    provider_cost_evidence = None
    try:
        await image_generation_store.mark_running(generation_id, user_id=user_id)
        await ai_usage_service.mark_provider_started(
            scope=usage_scope,
            reservation_id=reservation_id,
        )
        provider_started = True
        await image_generation_store.update_reconciliation(
            generation_id,
            user_id=user_id,
            quota_status="provider_started",
        )
        await _update_job_safely(
            job_id,
            status="running",
            progress=10,
            message="Flux generation started",
            cost_control_status="provider_started",
        )
        generator = FluxImageGenerator(model=model)
        result = await asyncio.to_thread(
            generator.generate_to_file,
            prompt=prompt,
            width=width,
            height=height,
            seed=seed,
            output_format=output_format,
            reference_urls=reference_urls,
            safety_tolerance=safety_tolerance,
        )
        local_path = result.local_path
        provider_cost_evidence = result.provider_cost_metadata
        await image_generation_store.mark_running(
            generation_id,
            user_id=user_id,
            provider_request_id=result.provider_request_id,
            provider_cost=result.provider_cost,
            provider_metadata=result.provider_metadata,
        )
        await _update_job_safely(
            job_id,
            status="running",
            progress=70,
            message="Uploading generated image",
            cost_control_status="provider_started",
        )
        upload_result = await asyncio.to_thread(
            crew.cdn_manager.upload_with_optimizer,
            source=local_path,
            file_name=file_name,
            alt_text=alt_text,
            path_type=path_type,
            image_type=_map_optimizer_image_type(image_type),
        )
        if not upload_result.get("success"):
            raise FluxImageGenerationError(
                "cdn_upload_failed",
                upload_result.get("error", "Bunny CDN upload failed."),
                provider_request_id=result.provider_request_id,
                provider_metadata=result.provider_metadata,
                provider_cost_metadata=result.provider_cost_metadata,
            )

        cdn_url = upload_result.get("cdn_url")
        if not cdn_url or not _is_durable_bunny_url(str(cdn_url)):
            raise FluxImageGenerationError(
                "cdn_asset_not_durable",
                "Bunny CDN did not return a durable image URL.",
                provider_request_id=result.provider_request_id,
                provider_metadata=result.provider_metadata,
                provider_cost_metadata=result.provider_cost_metadata,
            )

        responsive_urls = {str(k): v for k, v in upload_result.get("responsive_urls", {}).items()}
        asset_id = _record_generated_project_asset(
            project_id=project_id,
            user_id=user_id,
            generation_id=generation_id,
            profile_id=profile_id,
            image_type=image_type,
            model=result.model,
            file_name=file_name,
            cdn_url=str(cdn_url),
            primary_url=upload_result.get("primary_url"),
            responsive_urls=responsive_urls,
            output_format=result.output_format,
        )
        serialized_cost = (
            provider_cost_evidence.model_dump(mode="json", by_alias=True)
            if provider_cost_evidence is not None
            else None
        )
        await image_generation_store.update_reconciliation(
            generation_id,
            user_id=user_id,
            quota_status="reconciliation_pending",
            provider_cost_evidence=serialized_cost,
        )
        try:
            await ai_usage_service.consume(
                scope=usage_scope,
                reservation_id=reservation_id,
                provider_cost=provider_cost_evidence,
            )
        except Exception:
            logger.exception("Flux asset is durable but usage reconciliation is pending")
            await _update_job_safely(
                job_id,
                status="reconciliation_pending",
                progress=95,
                message="Flux image stored; usage reconciliation pending",
                generation_id=generation_id,
                asset_id=asset_id,
                reservation_id=reservation_id,
                cost_control_status="reconciliation_pending",
            )
            return
        try:
            await image_generation_store.mark_completed(
                generation_id,
                user_id=user_id,
                cdn_url=str(cdn_url),
                primary_url=upload_result.get("primary_url"),
                responsive_urls=responsive_urls,
                asset_id=asset_id,
                provider_request_id=result.provider_request_id,
                provider_cost=result.provider_cost,
                provider_metadata=result.provider_metadata,
            )
            await image_generation_store.update_reconciliation(
                generation_id,
                user_id=user_id,
                quota_status="consumed",
                quota_outcome="consumed",
                provider_cost_evidence=serialized_cost,
                reconciled=True,
            )
        except Exception:
            logger.exception("Flux usage consumed but generation history reconciliation is pending")
            await _update_job_safely(
                job_id,
                status="reconciliation_pending",
                progress=95,
                message="Flux image stored; history reconciliation pending",
                generation_id=generation_id,
                asset_id=asset_id,
                reservation_id=reservation_id,
                quota_outcome="consumed",
                cost_control_status="reconciliation_pending",
            )
            return
        await _update_job_safely(
            job_id,
            status="completed",
            progress=100,
            message="Flux image generated",
            generation_id=generation_id,
            asset_id=asset_id,
            reservation_id=reservation_id,
            cost_control_status="consumed",
        )
    except FluxImageGenerationError as exc:
        provider_cost_evidence = exc.provider_cost_metadata or provider_cost_evidence
        quota_status, quota_outcome = await _reconcile_failed_flux_usage(
            ai_usage_service=ai_usage_service,
            scope=usage_scope,
            reservation_id=reservation_id,
            provider_started=provider_started,
            failure_behavior=failure_behavior,
            provider_cost=provider_cost_evidence,
            reason=exc.code,
        )
        await image_generation_store.mark_failed(
            generation_id,
            user_id=user_id,
            error_code=exc.code,
            reservation_id=reservation_id,
            cost_control_status=quota_status,
            error_message=exc.message,
            provider_request_id=exc.provider_request_id,
            provider_metadata=exc.provider_metadata,
        )
        await image_generation_store.update_reconciliation(
            generation_id,
            user_id=user_id,
            quota_status=quota_status,
            quota_outcome=quota_outcome,
            provider_cost_evidence=(
                provider_cost_evidence.model_dump(mode="json", by_alias=True)
                if provider_cost_evidence is not None
                else None
            ),
            reconciled=quota_status != "reconciliation_pending",
        )
        await _update_job_safely(
            job_id,
            status="failed",
            progress=100,
            message=exc.message,
            generation_id=generation_id,
            error_code=exc.code,
        )
    except Exception as exc:
        logger.exception("Unexpected Flux image generation job failure")
        quota_status, quota_outcome = await _reconcile_failed_flux_usage(
            ai_usage_service=ai_usage_service,
            scope=usage_scope,
            reservation_id=reservation_id,
            provider_started=provider_started,
            failure_behavior=failure_behavior,
            provider_cost=provider_cost_evidence,
            reason="internal_error",
        )
        await image_generation_store.mark_failed(
            generation_id,
            user_id=user_id,
            error_code="internal_error",
            reservation_id=reservation_id,
            cost_control_status=quota_status,
            error_message=str(exc),
        )
        await image_generation_store.update_reconciliation(
            generation_id,
            user_id=user_id,
            quota_status=quota_status,
            quota_outcome=quota_outcome,
            provider_cost_evidence=(
                provider_cost_evidence.model_dump(mode="json", by_alias=True)
                if provider_cost_evidence is not None
                else None
            ),
            reconciled=quota_status != "reconciliation_pending",
        )
        await _update_job_safely(
            job_id,
            status="failed",
            progress=100,
            message="Flux image generation failed",
            generation_id=generation_id,
            error_code="internal_error",
        )
    finally:
        if local_path:
            try:
                path = Path(local_path)
                if path.exists():
                    path.unlink()
            except Exception:
                pass


@router.post(
    "/generate",
    response_model=GenerateImagesResponse,
    summary="Generate images for article",
    description="""
    Generate optimized images for a blog article using the Image Robot Crew.

    **What it does:**
    - Analyzes article content to determine visual strategy
    - Generates images via Robolly API
    - Uploads to Bunny CDN with optional Optimizer URLs
    - Returns markdown with images inserted

    **Strategy types:**
    - `minimal`: Hero image only (fastest)
    - `standard`: Hero + OG card (default)
    - `hero+sections`: Hero + section images
    - `rich`: All image types including thumbnails

    **Returns:**
    - Generated image URLs with responsive variants
    - Updated markdown with images inserted
    - OG image URL for social sharing
    - Processing statistics
    """
)
async def generate_images(
    request: GenerateImagesRequest,
    crew: "ImagePipeline" = Depends(get_image_pipeline),
    current_user: CurrentUser = Depends(require_current_user),
) -> GenerateImagesResponse:
    """Generate images for an article via Image Robot Crew"""
    start_time = time.time()

    try:
        logger.info(f"Generating images for article: {request.article_title}")
        scoped_data_dir: Optional[Path] = None
        if request.project_id:
            scoped_data_dir = await _get_project_scoped_data_dir(
                crew=crew,
                project_id=request.project_id,
                current_user=current_user,
            )

        # Call the Image Robot Crew
        result = crew.process(
            article_content=request.article_content,
            article_title=request.article_title,
            article_slug=request.article_slug,
            strategy_type=request.strategy_type,
            style_guide=request.style_guide,
            generate_responsive=request.generate_responsive,
            path_type=request.path_type
        )

        # Convert to response format
        images = []
        for img_result in result.images:
            images.append(GeneratedImageResponse(
                success=img_result.success,
                image_type=img_result.image_type,
                primary_url=img_result.primary_cdn_url,
                responsive_urls=img_result.responsive_urls,
                alt_text=img_result.alt_text,
                file_name=img_result.file_name,
                file_size_kb=img_result.generated.file_size_kb if img_result.generated else None,
                error=img_result.errors[0] if img_result.errors else None
            ))

        processing_time_ms = int((time.time() - start_time) * 1000)

        # Persist per-project (or global) history item.
        try:
            history_dir = scoped_data_dir or Path(crew.data_dir)
            history_file = history_dir / "workflow_history.json"
            _append_history_item(
                history_file=history_file,
                item={
                    "workflow_id": f"img_{int(time.time() * 1000)}",
                    "timestamp": datetime.utcnow().isoformat(),
                    "article_title": request.article_title,
                    "article_slug": request.article_slug,
                    "total_images": result.total_images,
                    "successful_images": result.successful_images,
                    "failed_images": result.failed_images,
                    "processing_time_ms": processing_time_ms,
                    "cdn_urls_count": len(result.cdn_urls) if result.cdn_urls else 0,
                    "total_cdn_size_kb": result.total_cdn_size_kb,
                },
            )
        except Exception as history_err:
            logger.warning(f"Failed to write image history: {history_err}")

        return GenerateImagesResponse(
            success=result.successful_images > 0,
            total_images=result.total_images,
            successful_images=result.successful_images,
            failed_images=result.failed_images,
            images=images,
            markdown_with_images=result.markdown_with_images,
            og_image_url=result.og_image_url,
            total_cdn_size_kb=result.total_cdn_size_kb,
            processing_time_ms=processing_time_ms,
            strategy_used=result.strategy.strategy_type
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Image generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Image generation failed: {str(e)}"
        )


@router.post(
    "/upload",
    response_model=UploadImageResponse,
    summary="Upload single image to CDN",
    description="""
    Upload a single image to Bunny CDN with optimization.

    **What it does:**
    - Downloads image from source URL
    - Uploads to Bunny CDN storage
    - Generates Optimizer URLs for responsive variants

    **Returns:**
    - CDN URL of uploaded image
    - Optimizer URL with transformation params
    - Responsive variant URLs
    """
)
async def upload_image(
    request: UploadImageRequest,
    crew: "ImagePipeline" = Depends(get_image_pipeline)
) -> UploadImageResponse:
    """Upload a single image with optimization"""
    try:
        logger.info(f"Uploading image: {request.file_name}")

        # Use CDN Manager directly for single uploads
        cdn_manager = crew.cdn_manager

        result = cdn_manager.upload_with_optimizer(
            source=str(request.source_url),
            file_name=request.file_name,
            alt_text=request.alt_text,
            image_type=request.image_type,
            path_type=request.path_type
        )

        if not result.get("success"):
            return UploadImageResponse(
                success=False,
                error=result.get("error", "Upload failed")
            )

        return UploadImageResponse(
            success=True,
            cdn_url=result.get("cdn_url"),
            optimizer_url=result.get("optimizer_url"),
            responsive_urls=result.get("responsive_urls", {}),
            file_size_kb=result.get("file_size_kb"),
            content_type=result.get("content_type"),
            storage_path=result.get("storage_path")
        )

    except Exception as e:
        logger.error(f"Image upload failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Image upload failed: {str(e)}"
        )


@router.get(
    "/optimizer/status",
    response_model=OptimizerStatusResponse,
    summary="Check Bunny Optimizer status",
    description="""
    Check the status of Bunny CDN Optimizer.

    **What it checks:**
    - Whether optimizer is enabled in config
    - CDN hostname configuration
    - Optionally verifies transformation works

    **Returns:**
    - Enabled status
    - Hostname and configuration
    - Verification result if test URL provided
    """
)
async def get_optimizer_status(
    test_url: str = None,
    crew: "ImagePipeline" = Depends(get_image_pipeline)
) -> OptimizerStatusResponse:
    """Check Bunny Optimizer configuration and status"""
    try:
        from agents.images.config.image_config import BUNNY_CONFIG

        optimizer_config = BUNNY_CONFIG.get("optimizer", {})
        enabled = optimizer_config.get("enabled", False)
        hostname = BUNNY_CONFIG.get("storage", {}).get("hostname", "")

        # Base response
        response = OptimizerStatusResponse(
            enabled=enabled,
            config_enabled=enabled,
            hostname=hostname if hostname else None,
            message="Bunny Optimizer is " + ("enabled" if enabled else "disabled"),
            supported_formats=optimizer_config.get("formats", ["webp", "avif", "jpeg", "png"]),
            default_quality=optimizer_config.get("default_quality", 85)
        )

        # Optionally verify with a test URL
        if test_url and enabled and hostname:
            try:
                from agents.images.tools.bunny_optimizer_tools import generate_optimized_url

                transformed_result = generate_optimized_url(
                    base_url=test_url,
                    width=800,
                    quality=85,
                    format="webp"
                )
                transformed = transformed_result.get("url", test_url)
                response.verified = True
                response.test_url = test_url
                response.transformed_url = transformed
                response.message = "Bunny Optimizer is enabled and verified"
            except Exception as e:
                response.verified = False
                response.message = f"Bunny Optimizer enabled but verification failed: {e}"

        return response

    except Exception as e:
        logger.error(f"Optimizer status check failed: {e}")
        return OptimizerStatusResponse(
            enabled=False,
            config_enabled=False,
            message=f"Failed to check optimizer status: {str(e)}"
        )


@router.get(
    "/history",
    response_model=ImageRobotHistoryResponse,
    summary="Get generation history",
    description="""
    Get recent image generation history.

    **Returns:**
    - List of recent generation jobs
    - Statistics for each job
    """
)
async def get_generation_history(
    limit: int = 20,
    project_id: Optional[str] = Query(
        default=None,
        description="Optional project id for project-scoped history",
    ),
    crew: "ImagePipeline" = Depends(get_image_pipeline),
    current_user: CurrentUser = Depends(require_current_user),
) -> ImageRobotHistoryResponse:
    """Get recent image generation history"""
    try:
        if project_id:
            scoped_dir = await _get_project_scoped_data_dir(
                crew=crew,
                project_id=project_id,
                current_user=current_user,
            )
            history_file = scoped_dir / "workflow_history.json"
        else:
            history_file = Path(crew.data_dir) / "workflow_history.json"

        if not history_file.exists():
            return ImageRobotHistoryResponse(items=[], total_count=0)

        with open(history_file, 'r') as f:
            history = json.load(f)

        # Get most recent items
        items = [
            ImageRobotHistoryItem(**item)
            for item in history[-limit:]
        ]
        items.reverse()  # Most recent first

        return ImageRobotHistoryResponse(
            items=items,
            total_count=len(history)
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get history: {e}")
        return ImageRobotHistoryResponse(items=[], total_count=0)


@router.get(
    "/generations",
    response_model=ImageGenerationListResponse,
    summary="List AI image generation records",
)
async def list_ai_image_generations(
    project_id: str = Query(..., description="Project id used to scope AI image history"),
    limit: int = Query(30, ge=1, le=100),
    current_user: CurrentUser = Depends(require_current_user),
) -> ImageGenerationListResponse:
    await require_owned_project_id(project_id, current_user)
    await _ensure_image_generation_store()
    items = await image_generation_store.list_generations(
        project_id=project_id,
        user_id=current_user.user_id,
        limit=limit,
    )
    records = [_generation_record(item) for item in items]
    return ImageGenerationListResponse(items=records, total_count=len(records))


@router.get(
    "/generations/{generation_id}",
    response_model=ImageGenerationRecord,
    summary="Get an AI image generation record",
)
async def get_ai_image_generation(
    generation_id: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> ImageGenerationRecord:
    await _ensure_image_generation_store()
    generation = await image_generation_store.get_generation(
        generation_id,
        user_id=current_user.user_id,
    )
    if not generation:
        raise HTTPException(status_code=404, detail="Image generation not found")
    await require_owned_project_id(generation["project_id"], current_user)
    return _generation_record(generation)


@router.get(
    "/references",
    response_model=ImageReferenceListResponse,
    summary="List project visual references",
)
async def list_visual_references(
    project_id: str = Query(..., description="Project id used to scope visual references"),
    approved_only: bool = Query(False),
    limit: int = Query(50, ge=1, le=100),
    current_user: CurrentUser = Depends(require_current_user),
) -> ImageReferenceListResponse:
    await require_owned_project_id(project_id, current_user)
    await _ensure_image_generation_store()
    items = await image_generation_store.list_references(
        project_id=project_id,
        user_id=current_user.user_id,
        approved_only=approved_only,
        limit=limit,
    )
    records = [_reference_record(item) for item in items]
    return ImageReferenceListResponse(items=records, total_count=len(records))


@router.post(
    "/references",
    response_model=ImageReferenceRecord,
    status_code=201,
    summary="Register a project visual reference",
)
async def create_visual_reference(
    request: ImageReferenceCreateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> ImageReferenceRecord:
    await require_owned_project_id(request.project_id, current_user)
    if not _is_durable_bunny_url(str(request.cdn_url)):
        raise HTTPException(status_code=400, detail="Visual reference must be a durable Bunny CDN URL")
    if request.primary_url and not _is_durable_bunny_url(str(request.primary_url)):
        raise HTTPException(status_code=400, detail="Visual reference preview must be a durable Bunny CDN URL")
    await _ensure_image_generation_store()
    reference = await image_generation_store.create_reference(
        project_id=request.project_id,
        user_id=current_user.user_id,
        cdn_url=str(request.cdn_url),
        primary_url=str(request.primary_url) if request.primary_url else None,
        mime_type=request.mime_type,
        width=request.width,
        height=request.height,
        label=request.label,
        reference_type=request.reference_type,
        approved=request.approved,
    )
    return _reference_record(reference)


@router.patch(
    "/references/{reference_id}",
    response_model=ImageReferenceRecord,
    summary="Update a project visual reference",
)
async def update_visual_reference(
    reference_id: str,
    request: ImageReferenceUpdateRequest,
    project_id: str = Query(..., description="Project id used to scope visual references"),
    current_user: CurrentUser = Depends(require_current_user),
) -> ImageReferenceRecord:
    await require_owned_project_id(project_id, current_user)
    await _ensure_image_generation_store()
    existing = await image_generation_store.get_reference(
        reference_id,
        project_id=project_id,
        user_id=current_user.user_id,
    )
    if not existing:
        raise HTTPException(status_code=404, detail="Visual reference not found")
    updated = await image_generation_store.update_reference(
        reference_id,
        project_id=project_id,
        user_id=current_user.user_id,
        approved=request.approved,
        label=request.label,
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Visual reference not found")
    return _reference_record(updated)


@router.delete(
    "/references/{reference_id}",
    summary="Delete a project visual reference",
)
async def delete_visual_reference(
    reference_id: str,
    project_id: str = Query(..., description="Project id used to scope visual references"),
    current_user: CurrentUser = Depends(require_current_user),
) -> Dict[str, Any]:
    await require_owned_project_id(project_id, current_user)
    await _ensure_image_generation_store()
    existing = await image_generation_store.get_reference(
        reference_id,
        project_id=project_id,
        user_id=current_user.user_id,
    )
    if not existing:
        raise HTTPException(status_code=404, detail="Visual reference not found")
    await image_generation_store.delete_reference(
        reference_id,
        project_id=project_id,
        user_id=current_user.user_id,
    )
    return {"success": True, "reference_id": reference_id}


@router.get(
    "/profiles",
    response_model=ListImageProfilesResponse,
    summary="List image generation profiles",
    description="""
    Return system and custom profiles for image generation.

    These profiles define defaults for:
    - Image type (hero, OG, section, thumbnail)
    - Style guide
    - CDN path
    - Optional template overrides
    """
)
async def list_image_profiles(
    project_id: str = Query(
        ...,
        description="Project id used to scope image profiles",
    ),
    crew: "ImagePipeline" = Depends(get_image_pipeline),
    current_user: CurrentUser = Depends(require_current_user),
) -> ListImageProfilesResponse:
    """List available image profiles (system + custom)."""
    try:
        scoped_dir = await _get_project_scoped_data_dir(
            crew=crew,
            project_id=project_id,
            current_user=current_user,
        )
        store = ImageProfileStore(scoped_dir)
        items = [ImageProfileData(**profile) for profile in store.list_profiles()]
        return ListImageProfilesResponse(items=items, total_count=len(items))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to list image profiles: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list profiles: {str(e)}")


@router.post(
    "/profiles",
    response_model=ImageProfileData,
    summary="Create or update custom image profile",
    description="""
    Create or update a custom generation profile.

    Notes:
    - System profiles cannot be overwritten.
    - Custom profiles are persisted in `data/images/projects/{project_id}/image_profiles.json`.
    """
)
async def upsert_image_profile(
    request: CreateImageProfileRequest,
    project_id: str = Query(
        ...,
        description="Project id used to scope image profiles",
    ),
    crew: "ImagePipeline" = Depends(get_image_pipeline),
    current_user: CurrentUser = Depends(require_current_user),
) -> ImageProfileData:
    """Create or update a custom profile."""
    try:
        scoped_dir = await _get_project_scoped_data_dir(
            crew=crew,
            project_id=project_id,
            current_user=current_user,
        )
        store = ImageProfileStore(scoped_dir)
        saved = store.save_custom_profile(request.dict())
        return ImageProfileData(**saved)
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Failed to save image profile: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save profile: {str(e)}")


@router.delete(
    "/profiles/{profile_id}",
    summary="Delete custom image profile",
    description="""
    Delete a custom profile by id.

    Notes:
    - System profiles cannot be deleted.
    """
)
async def delete_image_profile(
    profile_id: str,
    project_id: str = Query(
        ...,
        description="Project id used to scope image profiles",
    ),
    crew: "ImagePipeline" = Depends(get_image_pipeline),
    current_user: CurrentUser = Depends(require_current_user),
) -> Dict[str, Any]:
    """Delete a custom profile."""
    try:
        scoped_dir = await _get_project_scoped_data_dir(
            crew=crew,
            project_id=project_id,
            current_user=current_user,
        )
        store = ImageProfileStore(scoped_dir)
        deleted = store.delete_custom_profile(profile_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Profile not found")
        return {"success": True, "profile_id": profile_id}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/generate-from-profile",
    response_model=GenerateImageFromProfileResponse,
    summary="Generate image on-the-fly from profile",
    description="""
    Generate one image immediately from a pre-registered profile.

	    Workflow:
	    1. Resolve profile defaults (type/style/path/template)
	    2. Generate image via resolved provider (Robolly or OpenAI)
	    3. Upload original to Bunny CDN
	    4. Return optimizer-based responsive URLs
	    """
)
async def generate_image_from_profile(
    request: GenerateImageFromProfileRequest,
    background_tasks: BackgroundTasks,
    crew: "ImagePipeline" = Depends(get_image_pipeline),
    current_user: CurrentUser = Depends(require_current_user),
    ai_usage_provider: AIUsageRuntimeProvider = Depends(get_ai_usage_runtime_provider),
) -> GenerateImageFromProfileResponse:
    """Generate one image from a saved profile."""
    try:
        scoped_dir = await _get_project_scoped_data_dir(
            crew=crew,
            project_id=request.project_id,
            current_user=current_user,
        )
        store = ImageProfileStore(scoped_dir)
        profile = store.get_profile(request.profile_id)
        if not profile:
            raise HTTPException(status_code=404, detail="Profile not found")

        resolved_style = request.style_guide_override or profile.get("style_guide", "brand_primary")
        resolved_path = request.path_type_override or profile.get("path_type", "articles")
        resolved_template = request.template_id_override or profile.get("template_id")
        profile_provider = profile.get("image_provider", "robolly")
        resolved_provider = request.provider_override or profile_provider
        if resolved_provider == "flux" and profile_provider != "flux":
            raise HTTPException(status_code=400, detail="Profile does not allow Flux generation")
        image_type = profile.get("image_type", "hero_image")
        prompt_used: Optional[str] = None
        temp_local_path: Optional[str] = None

        if resolved_provider == "robolly":
            from agents.images.schemas.image_schemas import ImageBrief, ImageType

            brief = ImageBrief(
                image_type=ImageType(image_type),
                title_text=request.title_text,
                subtitle_text=request.subtitle_text,
                template_id=resolved_template,
                context_keywords=profile.get("tags", []),
            )

            generation_result = crew.generator.generate_from_brief(
                brief=brief,
                style_guide=resolved_style,
            )

            if not generation_result.get("success"):
                return GenerateImageFromProfileResponse(
                    success=False,
                    profile=ImageProfileData(**profile),
                    image_type=image_type,
                    provider_used=resolved_provider,
                    style_guide_used=resolved_style,
                    path_type_used=resolved_path,
                    error=generation_result.get("error", "Generation failed"),
                )

            generated = generation_result.get("generated", {})
            source_url = generated.get("original_url")
            if not source_url:
                return GenerateImageFromProfileResponse(
                    success=False,
                    profile=ImageProfileData(**profile),
                    image_type=image_type,
                    provider_used=resolved_provider,
                    style_guide_used=resolved_style,
                    path_type_used=resolved_path,
                    error="Generated image URL missing",
                )
        elif resolved_provider == "openai":
            prompt_used = _build_ai_prompt(
                profile=profile,
                title_text=request.title_text,
                subtitle_text=request.subtitle_text,
                custom_prompt=request.custom_prompt,
            )
            ai_result = generate_openai_image_to_file(
                prompt=prompt_used,
                image_type=image_type,
            )
            temp_local_path = ai_result.get("local_path")
            if not temp_local_path:
                return GenerateImageFromProfileResponse(
                    success=False,
                    profile=ImageProfileData(**profile),
                    image_type=image_type,
                    provider_used=resolved_provider,
                    prompt_used=prompt_used,
                    style_guide_used=resolved_style,
                    path_type_used=resolved_path,
                    error="AI image generation returned no local file",
                )
            generation_result = {"total_time_ms": None}
            generated = {
                "original_url": temp_local_path,
                "robolly_render_id": None,
                "format": "png",
            }
            source_url = temp_local_path
        elif resolved_provider == "flux":
            ai_usage = await ai_usage_provider()
            await _ensure_image_generation_store()
            prompt_used = _build_ai_prompt(
                profile=profile,
                title_text=request.title_text,
                subtitle_text=request.subtitle_text,
                custom_prompt=request.custom_prompt,
            )
            width, height = image_type_dimensions(image_type)
            storage_format = "jpg" if request.output_format == "jpeg" else request.output_format
            resolved_file_name = request.file_name or _build_profile_file_name(
                profile_id=request.profile_id,
                title_text=request.title_text,
                image_format=storage_format,
            )
            resolved_file_name = _ensure_extension(resolved_file_name, image_format=storage_format)
            resolved_alt_text = (
                request.alt_text
                or profile.get("default_alt_text")
                or f"{profile.get('name', 'Image')} - {request.title_text}"
            )
            if not _flux_api_key_configured():
                return GenerateImageFromProfileResponse(
                    success=False,
                    profile=ImageProfileData(**profile),
                    image_type=image_type,
                    file_name=resolved_file_name,
                    alt_text=resolved_alt_text,
                    provider_used=resolved_provider,
                    prompt_used=prompt_used,
                    style_guide_used=resolved_style,
                    path_type_used=resolved_path,
                    status="failed",
                    model=_configured_flux_model(),
                    width=width,
                    height=height,
                    seed=request.seed,
                    error_code="provider_not_configured",
                    error="BFL_API_KEY is not configured.",
                )

            references = await _resolve_flux_references(
                request=request,
                current_user=current_user,
            )
            reference_ids = [str(ref["id"]) for ref in references]
            reference_urls = [str(ref["cdn_url"]) for ref in references]
            visual_memory_applied = bool(reference_urls)
            job_id = f"flux_image_{uuid.uuid4()}"
            try:
                policy = ai_usage.policies.resolve(AIUsageAction.FLUX_IMAGE_GENERATION)
            except ValueError as exc:
                raise HTTPException(
                    status_code=503,
                    detail="Flux usage policy is not configured.",
                ) from exc
            if policy.provider != "flux" or not policy.model:
                raise HTTPException(
                    status_code=503,
                    detail="Flux usage policy provider/model configuration is invalid.",
                )
            model = policy.model
            scope = AIUsageScope(
                user_id=current_user.user_id,
                project_id=request.project_id,
            )
            try:
                reservation = await ai_usage.service.reserve(
                    scope=scope,
                    action=AIUsageAction.FLUX_IMAGE_GENERATION,
                    units=policy.estimated_units,
                    idempotency_key=f"flux:{current_user.user_id}:{job_id}",
                    expires_in=timedelta(seconds=ai_usage.reservation_ttl_seconds),
                    provider=policy.provider,
                    model=policy.model,
                    job_id=job_id,
                )
            except AIUsageQuotaRejected as exc:
                raise _quota_http_error(exc, provider="flux") from exc
            except AIUsageTransitionConflict as exc:
                raise _quota_conflict_http_error(provider="flux") from exc
            try:
                generation = await image_generation_store.create_generation(
                    project_id=request.project_id,
                    user_id=current_user.user_id,
                    profile_id=request.profile_id,
                    provider="flux",
                    model=model,
                    job_id=job_id,
                    reservation_id=reservation.reservation_id,
                    estimated_units=str(policy.estimated_units),
                    quota_status="reserved",
                    prompt=prompt_used,
                    width=width,
                    height=height,
                    seed=request.seed,
                    output_format=request.output_format,
                    reference_ids=reference_ids,
                    visual_memory_applied=visual_memory_applied,
                )
            except Exception as exc:
                await ai_usage.service.release(
                    scope=scope,
                    reservation_id=reservation.reservation_id,
                    reason="flux_generation_record_failed",
                )
                raise HTTPException(
                    status_code=503,
                    detail="Flux generation could not be queued.",
                ) from exc
            try:
                if job_store.db_client:
                    await job_store.upsert(
                        job_id,
                        "image_generation",
                        status="queued",
                        progress=0,
                        message="Queued Flux image generation",
                        generation_id=generation["id"],
                        project_id=request.project_id,
                        user_id=current_user.user_id,
                        reservation_id=reservation.reservation_id,
                        cost_control_status="reserved",
                    )
            except Exception as exc:
                logger.warning(f"Failed to persist Flux job row: {exc}")
            try:
                background_tasks.add_task(
                    _run_flux_generation_job,
                    crew=crew,
                    generation_id=generation["id"],
                    job_id=job_id,
                    project_id=request.project_id,
                    user_id=current_user.user_id,
                    profile_id=request.profile_id,
                    image_type=image_type,
                    prompt=prompt_used,
                    model=model,
                    width=width,
                    height=height,
                    seed=request.seed,
                    output_format=request.output_format,
                    safety_tolerance=_configured_flux_safety_tolerance(),
                    reference_urls=reference_urls,
                    file_name=resolved_file_name,
                    alt_text=resolved_alt_text,
                    path_type=resolved_path,
                    ai_usage_service=ai_usage.service,
                    usage_scope=scope,
                    reservation_id=reservation.reservation_id,
                    failure_behavior=policy.provider_failure_behavior,
                )
            except Exception as exc:
                await ai_usage.service.release(
                    scope=scope,
                    reservation_id=reservation.reservation_id,
                    reason="flux_background_task_failed",
                )
                raise HTTPException(
                    status_code=503,
                    detail="Flux generation could not be queued.",
                ) from exc
            quota_status = await ai_usage.service.preflight(
                scope=scope,
                action=AIUsageAction.FLUX_IMAGE_GENERATION,
            )
            return GenerateImageFromProfileResponse(
                success=True,
                profile=ImageProfileData(**profile),
                image_type=image_type,
                file_name=resolved_file_name,
                alt_text=resolved_alt_text,
                provider_used=resolved_provider,
                prompt_used=prompt_used,
                style_guide_used=resolved_style,
                path_type_used=resolved_path,
                generation_id=generation["id"],
                job_id=job_id,
                reservation_id=reservation.reservation_id,
                quota_status=quota_status.model_dump(mode="json", by_alias=True),
                status=generation["status"],
                model=model,
                width=width,
                height=height,
                seed=request.seed,
                reference_ids=reference_ids,
                visual_memory_applied=visual_memory_applied,
                references_used=len(reference_urls),
                history_persisted=True,
            )
        else:
            return GenerateImageFromProfileResponse(
                success=False,
                profile=ImageProfileData(**profile),
                image_type=image_type,
                provider_used=resolved_provider,
                style_guide_used=resolved_style,
                path_type_used=resolved_path,
                error=f"Unsupported image provider: {resolved_provider}",
            )

        image_format = generated.get("format", "jpg")
        resolved_file_name = request.file_name or _build_profile_file_name(
            profile_id=request.profile_id,
            title_text=request.title_text,
            image_format=image_format,
        )
        resolved_file_name = _ensure_extension(resolved_file_name, image_format=image_format)

        resolved_alt_text = (
            request.alt_text
            or profile.get("default_alt_text")
            or f"{profile.get('name', 'Image')} - {request.title_text}"
        )

        upload_result = crew.cdn_manager.upload_with_optimizer(
            source=source_url,
            file_name=resolved_file_name,
            alt_text=resolved_alt_text,
            path_type=resolved_path,
            image_type=_map_optimizer_image_type(image_type),
        )

        if not upload_result.get("success"):
            return GenerateImageFromProfileResponse(
                success=False,
                profile=ImageProfileData(**profile),
                image_type=image_type,
                source_image_url=source_url,
                render_id=generated.get("robolly_render_id"),
                file_name=resolved_file_name,
                alt_text=resolved_alt_text,
                provider_used=resolved_provider,
                prompt_used=prompt_used,
                style_guide_used=resolved_style,
                path_type_used=resolved_path,
                generation_time_ms=generation_result.get("total_time_ms"),
                error=upload_result.get("error", "Upload failed"),
            )

        responsive_urls = {
            str(k): v for k, v in upload_result.get("responsive_urls", {}).items()
        }

        return GenerateImageFromProfileResponse(
            success=True,
            profile=ImageProfileData(**profile),
            image_type=image_type,
            source_image_url=source_url,
            cdn_url=upload_result.get("cdn_url"),
            primary_url=upload_result.get("primary_url"),
            responsive_urls=responsive_urls,
            render_id=generated.get("robolly_render_id"),
            file_name=resolved_file_name,
            alt_text=resolved_alt_text,
            provider_used=resolved_provider,
            prompt_used=prompt_used,
            style_guide_used=resolved_style,
            path_type_used=resolved_path,
            storage_path=upload_result.get("storage_path"),
            generation_time_ms=generation_result.get("total_time_ms"),
            upload_time_ms=upload_result.get("upload_time_ms"),
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Profile generation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Profile generation failed: {str(e)}")
    finally:
        # Best-effort cleanup for temporary AI files.
        try:
            if "temp_local_path" in locals() and temp_local_path:
                path = Path(temp_local_path)
                if path.exists():
                    path.unlink()
        except Exception:
            pass


@router.post(
    "/quick-generate",
    response_model=GenerateImagesResponse,
    summary="Quick generate hero image only",
    description="""
    Fast image generation with hero image only.

    This is a convenience endpoint for quick generation
    without responsive variants. Good for previews.
    """
)
async def quick_generate_images(
    request: GenerateImagesRequest,
    crew: "ImagePipeline" = Depends(get_image_pipeline),
    current_user: CurrentUser = Depends(require_current_user),
) -> GenerateImagesResponse:
    """Quick image generation (hero only, no responsive)"""
    start_time = time.time()

    try:
        logger.info(f"Quick generating image for: {request.article_title}")
        scoped_data_dir: Optional[Path] = None
        if request.project_id:
            scoped_data_dir = await _get_project_scoped_data_dir(
                crew=crew,
                project_id=request.project_id,
                current_user=current_user,
            )

        result = crew.quick_process(
            article_content=request.article_content,
            article_title=request.article_title,
            article_slug=request.article_slug,
            hero_only=True
        )

        images = []
        for img_result in result.images:
            images.append(GeneratedImageResponse(
                success=img_result.success,
                image_type=img_result.image_type,
                primary_url=img_result.primary_cdn_url,
                responsive_urls=img_result.responsive_urls,
                alt_text=img_result.alt_text,
                file_name=img_result.file_name,
                error=img_result.errors[0] if img_result.errors else None
            ))

        processing_time_ms = int((time.time() - start_time) * 1000)

        try:
            history_dir = scoped_data_dir or Path(crew.data_dir)
            history_file = history_dir / "workflow_history.json"
            _append_history_item(
                history_file=history_file,
                item={
                    "workflow_id": f"img_{int(time.time() * 1000)}",
                    "timestamp": datetime.utcnow().isoformat(),
                    "article_title": request.article_title,
                    "article_slug": request.article_slug,
                    "total_images": result.total_images,
                    "successful_images": result.successful_images,
                    "failed_images": result.failed_images,
                    "processing_time_ms": processing_time_ms,
                    "cdn_urls_count": len(result.cdn_urls) if result.cdn_urls else 0,
                    "total_cdn_size_kb": result.total_cdn_size_kb,
                },
            )
        except Exception as history_err:
            logger.warning(f"Failed to write quick image history: {history_err}")

        return GenerateImagesResponse(
            success=result.successful_images > 0,
            total_images=result.total_images,
            successful_images=result.successful_images,
            failed_images=result.failed_images,
            images=images,
            markdown_with_images=result.markdown_with_images,
            og_image_url=result.og_image_url,
            total_cdn_size_kb=result.total_cdn_size_kb,
            processing_time_ms=processing_time_ms,
            strategy_used="minimal"
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Quick image generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Quick image generation failed: {str(e)}"
        )
