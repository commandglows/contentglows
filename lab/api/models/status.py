"""Request/Response models for status management endpoints."""

from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime


class ActorResponse(BaseModel):
    """Structured audit actor returned by the API."""

    actor_type: str
    actor_id: str
    actor_label: str
    actor_metadata: Optional[Dict[str, Any]] = None


class CreateContentRequest(BaseModel):
    """Request to create a new content record."""
    title: str = Field(..., description="Content title")
    content_type: str = Field(..., description="Type of content (article, newsletter, seo-content, manual, image)")
    source_robot: str = Field(..., description="Robot that created this (seo, newsletter, article, manual, images)")
    status: str = Field(default="todo", description="Initial status")
    project_id: Optional[str] = Field(None, description="Associated project ID")
    content_path: Optional[str] = Field(None, description="File system path")
    content_preview: Optional[str] = Field(None, description="Short preview text")
    priority: int = Field(default=3, ge=1, le=5, description="Priority 1-5")
    tags: List[str] = Field(default_factory=list, description="Content tags")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")
    target_url: Optional[str] = Field(None, description="Target URL after publishing")


class UpdateContentRequest(BaseModel):
    """Request to update a content record (not status - use transition)."""
    title: Optional[str] = None
    content_path: Optional[str] = None
    content_preview: Optional[str] = None
    priority: Optional[int] = Field(None, ge=1, le=5)
    tags: Optional[List[str]] = None
    metadata: Optional[Dict[str, Any]] = None
    target_url: Optional[str] = None
    project_id: Optional[str] = None
    reviewer_note: Optional[str] = None
    reviewed_by: Optional[str] = None


class TransitionRequest(BaseModel):
    """Request to transition content to a new status."""
    to_status: str = Field(..., description="Target status")
    reason: Optional[str] = Field(None, description="Reason for the transition")


class ContentResponse(BaseModel):
    """Response representing a content record."""
    id: str
    title: str
    content_type: str
    source_robot: str
    status: str
    project_id: Optional[str]
    user_id: Optional[str] = None
    content_path: Optional[str]
    content_preview: Optional[str]
    content_hash: Optional[str]
    priority: int
    tags: List[str]
    metadata: Dict[str, Any]
    target_url: Optional[str]
    reviewer_note: Optional[str]
    reviewed_by: Optional[str]
    review_actor_type: Optional[str] = None
    review_actor_id: Optional[str] = None
    review_actor_label: Optional[str] = None
    review_actor_metadata: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime
    scheduled_for: Optional[datetime]
    published_at: Optional[datetime]
    synced_at: Optional[datetime]


class CreateContentAssetRequest(BaseModel):
    """Request to attach asset metadata to a content record."""
    client_asset_id: Optional[str] = None
    source: str = Field(default="device_capture")
    kind: str = Field(..., description="Asset kind: screenshot, recording, image, video, etc.")
    mime_type: str = Field(..., description="MIME type")
    file_name: Optional[str] = None
    byte_size: Optional[int] = Field(None, ge=0)
    width: Optional[int] = Field(None, ge=0)
    height: Optional[int] = Field(None, ge=0)
    duration_ms: Optional[int] = Field(None, ge=0)
    storage_uri: Optional[str] = None
    status: str = Field(default="local_only")
    metadata: Dict[str, Any] = Field(default_factory=dict)


class UpdateContentAssetRequest(BaseModel):
    """Request to update asset metadata."""
    storage_uri: Optional[str] = None
    status: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class ContentAssetResponse(BaseModel):
    """Response representing asset metadata attached to content."""
    id: str
    content_id: str
    project_id: str
    user_id: str
    client_asset_id: Optional[str]
    source: str
    kind: str
    mime_type: str
    file_name: Optional[str]
    byte_size: Optional[int]
    width: Optional[int]
    height: Optional[int]
    duration_ms: Optional[int]
    storage_uri: Optional[str]
    status: str
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime]


class StatusChangeResponse(BaseModel):
    """Response representing a status change in the audit trail."""
    id: str
    content_id: str
    from_status: str
    to_status: str
    changed_by: str
    actor_type: str
    actor_id: str
    actor_label: str
    actor_metadata: Optional[Dict[str, Any]] = None
    reason: Optional[str]
    timestamp: datetime


class StatsResponse(BaseModel):
    """Response with content statistics."""
    total: int
    by_status: Dict[str, int]


class ContentListResponse(BaseModel):
    """Response with a list of content records."""
    items: List[ContentResponse]
    total: int


class WorkDomainResponse(BaseModel):
    """Response representing a work domain state."""
    id: str
    project_id: str
    domain: str
    status: str
    last_run_at: Optional[datetime]
    last_run_status: Optional[str]
    items_pending: int
    items_completed: int
    metadata: Dict[str, Any]
    updated_at: datetime


class UpdateDomainRequest(BaseModel):
    """Request to update a work domain."""
    status: Optional[str] = None
    last_run_status: Optional[str] = None
    items_pending: Optional[int] = None
    items_completed: Optional[int] = None
    metadata: Optional[Dict[str, Any]] = None


# ─── Content Body ─────────────────────────────────────


class SaveContentBodyRequest(BaseModel):
    """Request to save/update content body."""
    body: str = Field(..., description="Full markdown content body")
    edit_note: Optional[str] = Field(None, description="Note about the edit")


class ContentBodyResponse(BaseModel):
    """Response representing a content body version."""
    id: str
    content_id: str
    body: str
    version: int
    edited_by: Optional[str]
    actor_type: Optional[str] = None
    actor_id: Optional[str] = None
    actor_label: Optional[str] = None
    actor_metadata: Optional[Dict[str, Any]] = None
    edit_note: Optional[str]
    created_at: str


class ContentEditResponse(BaseModel):
    """Response representing a content edit history entry."""
    id: str
    content_id: str
    edited_by: str
    actor_type: str
    actor_id: str
    actor_label: str
    actor_metadata: Optional[Dict[str, Any]] = None
    edit_note: Optional[str]
    previous_version: int
    new_version: int
    created_at: str


class RegenerateRequest(BaseModel):
    """Request to send content back for re-generation."""
    instructions: Optional[str] = Field(None, description="Instructions for the robot")


class ScheduleContentRequest(BaseModel):
    """Request to schedule content for publishing."""
    scheduled_for: str = Field(..., description="ISO datetime for scheduled publishing")


# ─── Schedule Jobs ────────────────────────────────────


class CreateScheduleJobRequest(BaseModel):
    """Request to create a new schedule job."""
    project_id: Optional[str] = Field(None, description="Associated project ID")
    job_type: str = Field(..., description="Job type: newsletter, seo, article, short, social, or video")
    generator_id: Optional[str] = Field(None, description="Associated generator ID")
    configuration: Dict[str, Any] = Field(default_factory=dict, description="Job configuration")
    schedule: str = Field(..., description="Schedule: daily, weekly, monthly, or custom")
    cron_expression: Optional[str] = Field(None, description="Custom cron expression")
    schedule_day: Optional[int] = Field(None, description="Day for weekly (0-6) or monthly (1-28)")
    schedule_time: Optional[str] = Field(None, description="Time in HH:MM format")
    timezone: str = Field(default="UTC", description="Timezone")
    enabled: bool = Field(default=True, description="Whether job is enabled")
    next_run_at: Optional[str] = Field(None, description="Next run time (ISO datetime)")


class UpdateScheduleJobRequest(BaseModel):
    """Request to update a schedule job."""
    project_id: Optional[str] = None
    job_type: Optional[str] = None
    generator_id: Optional[str] = None
    configuration: Optional[Dict[str, Any]] = None
    schedule: Optional[str] = None
    cron_expression: Optional[str] = None
    schedule_day: Optional[int] = None
    schedule_time: Optional[str] = None
    timezone: Optional[str] = None
    enabled: Optional[bool] = None
    next_run_at: Optional[str] = None


class ScheduleJobResponse(BaseModel):
    """Response representing a schedule job."""
    id: str
    user_id: str
    project_id: Optional[str]
    job_type: str
    generator_id: Optional[str]
    configuration: Dict[str, Any]
    schedule: str
    cron_expression: Optional[str]
    schedule_day: Optional[int]
    schedule_time: Optional[str]
    timezone: str
    enabled: bool
    last_run_at: Optional[str]
    last_run_status: Optional[str]
    next_run_at: Optional[str]
    created_at: str
    updated_at: str


class ProjectAssetResponse(BaseModel):
    id: str
    project_id: str
    user_id: str
    source_asset_id: Optional[str] = None
    content_asset_id: Optional[str] = None
    media_kind: str
    source: str
    mime_type: Optional[str] = None
    file_name: Optional[str] = None
    original_file_name: Optional[str] = None
    category_id: Optional[str] = None
    subcategory_id: Optional[str] = None
    suggested_export_file_name: str
    storage_uri: Optional[str] = None
    storage_locator: Optional[Dict[str, Any]] = None
    storage_descriptor: Dict[str, Any] = Field(default_factory=dict)
    status: str
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime
    tombstoned_at: Optional[datetime] = None
    cleanup_eligible_at: Optional[datetime] = None


class ProjectAssetUsageResponse(BaseModel):
    id: str
    asset_id: str
    project_id: str
    user_id: str
    target_type: str
    target_id: str
    placement: Optional[str] = None
    usage_action: str
    is_primary: bool
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class ProjectAssetEventResponse(BaseModel):
    id: str
    asset_id: str
    project_id: str
    user_id: str
    event_type: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    placement: Optional[str] = None
    metadata: Dict[str, Any]
    created_at: datetime


class SelectProjectAssetRequest(BaseModel):
    target_type: str
    target_id: str
    usage_action: str
    placement: Optional[str] = None
    is_primary: bool = False
    metadata: Dict[str, Any] = Field(default_factory=dict)


class ProjectAssetEligibilityRequest(BaseModel):
    usage_action: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None


class ProjectAssetEligibilityResponse(BaseModel):
    asset_id: str
    usage_action: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    eligible: bool
    reason: Optional[str] = None


class ProjectAssetPrimaryRequest(BaseModel):
    target_type: str
    target_id: str
    usage_action: str
    placement: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class ClearProjectAssetPrimaryRequest(BaseModel):
    target_type: str
    target_id: str
    placement: Optional[str] = None


class ClearProjectAssetPrimaryResponse(BaseModel):
    cleared_count: int


class ProjectAssetCleanupItem(BaseModel):
    asset_id: str
    media_kind: str
    status: str
    cleanup_eligible_at: Optional[datetime] = None
    reason: Optional[str] = None


class ProjectAssetCleanupReportResponse(BaseModel):
    cleanup_eligible: List[ProjectAssetCleanupItem]
    degraded: List[ProjectAssetCleanupItem]
    missing_storage: List[ProjectAssetCleanupItem]
    physical_delete_allowed: bool


class ProjectAssetListResponse(BaseModel):
    items: List[ProjectAssetResponse]
    total: int


class ProjectAssetSubcategoryResponse(BaseModel):
    subcategory_id: str
    label: str


class ProjectAssetCategoryResponse(BaseModel):
    category_id: str
    label: str
    subcategories: List[ProjectAssetSubcategoryResponse] = Field(default_factory=list)


class ProjectAssetCategoryCatalogResponse(BaseModel):
    version: str
    locale: str
    supported_locales: List[str]
    categories: List[ProjectAssetCategoryResponse]


class ProjectAssetCategoryAssignmentRequest(BaseModel):
    category_id: Optional[str] = Field(default=None, max_length=64)
    subcategory_id: Optional[str] = Field(default=None, max_length=64)


class AssetSemanticTagResponse(BaseModel):
    key: str
    label: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    source: str = "ai_suggestion"
    accepted_by_user: bool = False
    rejected_by_user: bool = False


class AssetSceneSegmentResponse(BaseModel):
    start_seconds: float = Field(..., ge=0.0)
    end_seconds: float = Field(..., ge=0.0)
    label: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    suggested_placement: Optional[str] = None


class AssetSourceAttributionResponse(BaseModel):
    source_platform: Optional[str] = None
    source_url: Optional[str] = None
    creator_handle: Optional[str] = None
    creator_name: Optional[str] = None
    credit_text: Optional[str] = None
    rights_status: str = "unknown"
    credit_required: bool = False


class AssetUnderstandingResultResponse(BaseModel):
    asset_id: str
    project_id: str
    status: str
    summary: Optional[str] = None
    tags: List[AssetSemanticTagResponse] = Field(default_factory=list)
    segments: List[AssetSceneSegmentResponse] = Field(default_factory=list)
    source_attribution: Optional[AssetSourceAttributionResponse] = None
    credential_source: Optional[str] = None
    provider: Optional[str] = None
    error_code: Optional[str] = None


class QueueAssetUnderstandingRequest(BaseModel):
    idempotency_key: str = Field(..., min_length=3, max_length=128)
    provider: str = Field(default="gemini_compatible")


class RetryAssetUnderstandingRequest(BaseModel):
    job_id: str = Field(..., min_length=3, max_length=128)


class AssetUnderstandingJobResponse(BaseModel):
    id: str
    asset_id: str
    project_id: str
    user_id: str
    media_type: str
    provider: str
    credential_source: Optional[str] = None
    status: str
    idempotency_key: str
    retry_of_job_id: Optional[str] = None
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    attempts: int
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


class AssetUnderstandingStatusResponse(BaseModel):
    job: Optional[AssetUnderstandingJobResponse] = None
    result: Optional[AssetUnderstandingResultResponse] = None


class AssetTagModerationDecisionRequest(BaseModel):
    action: str = Field(..., pattern="^(accept|reject|edit)$")
    key: str = Field(..., min_length=1, max_length=64)
    label: str = Field(..., min_length=1, max_length=128)
    edited_label: Optional[str] = Field(default=None, max_length=128)


class AssetTagModerationRequest(BaseModel):
    decisions: List[AssetTagModerationDecisionRequest] = Field(default_factory=list)
    manual_tags: List[str] = Field(default_factory=list)


class ProjectAssetRecommendationRequest(BaseModel):
    desired_tags: List[str] = Field(default_factory=list)
    limit: int = Field(default=10, ge=1, le=25)
    include_global_candidates: bool = False


class ProjectAssetRecommendationItem(BaseModel):
    asset_id: str
    score: float
    candidate_type: str = "attached_project_asset"
    source_project_id: Optional[str] = None
    requires_project_attachment: bool = False
    fit_reasons: List[Dict[str, Any]] = Field(default_factory=list)
    suggested_placements: List[str] = Field(default_factory=list)
    source_attribution: Optional[AssetSourceAttributionResponse] = None
    warnings: List[str] = Field(default_factory=list)


class ProjectAssetRecommendationResponse(BaseModel):
    items: List[ProjectAssetRecommendationItem] = Field(default_factory=list)


class AttachGlobalProjectAssetRequest(BaseModel):
    global_asset_id: str = Field(..., min_length=3, max_length=128)
