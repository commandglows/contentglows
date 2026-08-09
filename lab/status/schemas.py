"""
Status Management Schemas

Pydantic models for the unified content lifecycle tracking system.
Reuses ContentType and SourceRobot from publishing_schemas.
"""

from pydantic import BaseModel, Field, validator
from typing import List, Dict, Any, Optional
from datetime import datetime
from enum import Enum

from agents.scheduler.schemas.publishing_schemas import ContentType, SourceRobot
class ContentLifecycleStatus(str, Enum):
    """
    Unified content lifecycle status.
    Replaces PublishingStatus with a complete lifecycle from creation to archival.
    """
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    GENERATED = "generated"
    PENDING_REVIEW = "pending_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    SCHEDULED = "scheduled"
    PUBLISHING = "publishing"
    PUBLISHED = "published"
    FAILED = "failed"
    ARCHIVED = "archived"


class ProjectStatus(str, Enum):
    """Project lifecycle status"""
    ONBOARDING = "onboarding"
    ACTIVE = "active"
    PAUSED = "paused"
    ARCHIVED = "archived"


# Valid state transitions matrix
VALID_TRANSITIONS: Dict[ContentLifecycleStatus, List[ContentLifecycleStatus]] = {
    ContentLifecycleStatus.TODO: [
        ContentLifecycleStatus.IN_PROGRESS,
        ContentLifecycleStatus.ARCHIVED,
    ],
    ContentLifecycleStatus.IN_PROGRESS: [
        ContentLifecycleStatus.GENERATED,
        ContentLifecycleStatus.FAILED,
    ],
    ContentLifecycleStatus.GENERATED: [
        ContentLifecycleStatus.PENDING_REVIEW,
        ContentLifecycleStatus.IN_PROGRESS,  # re-generation
    ],
    ContentLifecycleStatus.PENDING_REVIEW: [
        ContentLifecycleStatus.APPROVED,
        ContentLifecycleStatus.REJECTED,
        ContentLifecycleStatus.IN_PROGRESS,  # re-generation
    ],
    ContentLifecycleStatus.APPROVED: [
        ContentLifecycleStatus.SCHEDULED,
        ContentLifecycleStatus.PUBLISHING,
        ContentLifecycleStatus.ARCHIVED,
    ],
    ContentLifecycleStatus.REJECTED: [
        ContentLifecycleStatus.TODO,
        ContentLifecycleStatus.IN_PROGRESS,
        ContentLifecycleStatus.ARCHIVED,
    ],
    ContentLifecycleStatus.SCHEDULED: [
        ContentLifecycleStatus.PUBLISHING,
        ContentLifecycleStatus.APPROVED,
    ],
    ContentLifecycleStatus.PUBLISHING: [
        ContentLifecycleStatus.PUBLISHED,
        ContentLifecycleStatus.FAILED,
    ],
    ContentLifecycleStatus.PUBLISHED: [
        ContentLifecycleStatus.ARCHIVED,
    ],
    ContentLifecycleStatus.FAILED: [
        ContentLifecycleStatus.TODO,
        ContentLifecycleStatus.IN_PROGRESS,
        ContentLifecycleStatus.ARCHIVED,
    ],
    ContentLifecycleStatus.ARCHIVED: [
        ContentLifecycleStatus.TODO,
    ],
}


class ContentRecord(BaseModel):
    """
    Unified content record tracking a piece of content through its lifecycle.
    Evolves from ContentItem with additional review and sync fields.
    """
    id: str = Field(..., description="Unique content identifier")
    title: str = Field(..., description="Content title")
    content_type: ContentType = Field(..., description="Type of content")
    source_robot: SourceRobot = Field(..., description="Robot that created this content")
    status: ContentLifecycleStatus = Field(
        default=ContentLifecycleStatus.TODO,
        description="Current lifecycle status",
    )
    project_id: Optional[str] = Field(None, description="Associated project ID")
    user_id: Optional[str] = Field(None, description="Owner user ID from Clerk auth")
    content_path: Optional[str] = Field(None, description="File system path to content")
    content_preview: Optional[str] = Field(None, description="Short preview of the content (first ~500 chars)")
    content_hash: Optional[str] = Field(None, description="SHA-256 hash of content for deduplication")
    priority: int = Field(default=3, ge=1, le=5, description="Priority (1=lowest, 5=highest)")
    tags: List[str] = Field(default_factory=list, description="Content tags")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")
    target_url: Optional[str] = Field(None, description="Target URL after publishing")
    reviewer_note: Optional[str] = Field(None, description="Note from the reviewer")
    reviewed_by: Optional[str] = Field(None, description="Who reviewed this content")
    review_actor_type: Optional[str] = Field(None, description="Structured reviewer actor type")
    review_actor_id: Optional[str] = Field(None, description="Structured reviewer actor ID")
    review_actor_label: Optional[str] = Field(None, description="Structured reviewer actor label")
    review_actor_metadata: Optional[Dict[str, Any]] = Field(
        None,
        description="Structured reviewer actor metadata",
    )
    current_version: int = Field(default=0, description="Current content body version")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation timestamp")
    updated_at: datetime = Field(default_factory=datetime.utcnow, description="Last update timestamp")
    scheduled_for: Optional[datetime] = Field(None, description="Scheduled publish time")
    published_at: Optional[datetime] = Field(None, description="Actual publish time")
    synced_at: Optional[datetime] = Field(None, description="Last sync to Turso timestamp")

    @validator("priority")
    def validate_priority(cls, v):
        if not 1 <= v <= 5:
            raise ValueError("Priority must be between 1 and 5")
        return v

    class Config:
        use_enum_values = True


class ContentAssetStatus(str, Enum):
    """Metadata state for assets attached to a content record."""
    LOCAL_ONLY = "local_only"
    PENDING_UPLOAD = "pending_upload"
    UPLOADED = "uploaded"
    DELETED = "deleted"


class ProjectAssetMediaKind(str, Enum):
    IMAGE = "image"
    AUDIO = "audio"
    MUSIC = "music"
    VIDEO = "video"
    THUMBNAIL = "thumbnail"
    VIDEO_COVER = "video_cover"
    BACKGROUND_CONFIG = "background_config"
    RENDER_OUTPUT = "render_output"
    CAPTURE = "capture"


class ProjectAssetSource(str, Enum):
    DEVICE_CAPTURE = "device_capture"
    IMAGE_ROBOT = "image_robot"
    MANUAL_UPLOAD = "manual_upload"
    VISUAL_REFERENCE = "visual_reference"
    VIDEO_AUDIO_AI = "video_audio_ai"
    VIDEO_MUSIC_AI = "video_music_ai"
    REMOTION_BACKGROUND = "remotion_background"
    REMOTION_RENDER = "remotion_render"
    REELS_IMPORT = "reels_import"
    CONTENT_ASSET = "content_asset"


class ProjectAssetLifecycleStatus(str, Enum):
    ACTIVE = "active"
    LOCAL_ONLY = "local_only"
    DEGRADED = "degraded"
    TOMBSTONED = "tombstoned"


class StorageLocator(BaseModel):
    """Durable provider-neutral object identity; never a delivery URL."""

    provider: str = Field(..., min_length=1, max_length=32)
    namespace: str = Field(..., min_length=1, max_length=255)
    object_key: str = Field(..., min_length=1, max_length=1024)
    version: Optional[str] = Field(default=None, max_length=512)
    checksum_sha256: str = Field(..., pattern=r"^[a-fA-F0-9]{64}$")


class AssetCredentialSource(str, Enum):
    USER_BYOK = "user_byok"
    PLATFORM = "platform"


class AssetUnderstandingStatus(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    BLOCKED = "blocked"
    DEGRADED = "degraded"
    PROVIDER_NOT_CONFIGURED = "provider_not_configured"
    SKIPPED_LIMIT_EXCEEDED = "skipped_limit_exceeded"
    QUOTA_EXCEEDED = "quota_exceeded"
    NEEDS_TRIM = "needs_trim"


class ProjectAssetRecord(BaseModel):
    id: str
    project_id: str
    user_id: str
    source_asset_id: Optional[str] = None
    content_asset_id: Optional[str] = None
    media_kind: ProjectAssetMediaKind
    source: ProjectAssetSource
    mime_type: Optional[str] = None
    file_name: Optional[str] = None
    original_file_name: Optional[str] = None
    category_id: Optional[str] = None
    subcategory_id: Optional[str] = None
    storage_uri: Optional[str] = None
    storage_locator: Optional[StorageLocator] = None
    status: ProjectAssetLifecycleStatus = ProjectAssetLifecycleStatus.ACTIVE
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    tombstoned_at: Optional[datetime] = None
    cleanup_eligible_at: Optional[datetime] = None

    class Config:
        use_enum_values = True


class ProjectAssetUsageRecord(BaseModel):
    id: str
    asset_id: str
    project_id: str
    user_id: str
    target_type: str
    target_id: str
    placement: Optional[str] = None
    usage_action: str
    is_primary: bool = False
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    deleted_at: Optional[datetime] = None


class ProjectAssetEventRecord(BaseModel):
    id: str
    asset_id: str
    project_id: str
    user_id: str
    event_type: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    placement: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class AssetSemanticTag(BaseModel):
    key: str
    label: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    source: str = "ai_suggestion"
    accepted_by_user: bool = False
    rejected_by_user: bool = False


class AssetSceneSegment(BaseModel):
    start_seconds: float = Field(..., ge=0.0)
    end_seconds: float = Field(..., ge=0.0)
    label: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    suggested_placement: Optional[str] = None


class AssetSourceAttribution(BaseModel):
    source_platform: Optional[str] = None
    source_url: Optional[str] = None
    creator_handle: Optional[str] = None
    creator_name: Optional[str] = None
    credit_text: Optional[str] = None
    rights_status: str = "unknown"
    credit_required: bool = False


class AssetUnderstandingJobRecord(BaseModel):
    id: str
    asset_id: str
    project_id: str
    user_id: str
    media_type: str
    provider: str
    credential_source: Optional[str] = None
    status: AssetUnderstandingStatus
    idempotency_key: str
    retry_of_job_id: Optional[str] = None
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    attempts: int = 0
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        use_enum_values = True


class AssetUnderstandingResultRecord(BaseModel):
    id: str
    job_id: str
    asset_id: str
    project_id: str
    user_id: str
    provider: str
    credential_source: Optional[str] = None
    summary: Optional[str] = None
    source_attribution: AssetSourceAttribution = Field(default_factory=AssetSourceAttribution)
    tags: List[AssetSemanticTag] = Field(default_factory=list)
    segments: List[AssetSceneSegment] = Field(default_factory=list)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class ContentAssetRecord(BaseModel):
    """Metadata for a client or stored asset attached to a content record."""
    id: str = Field(..., description="Unique asset metadata identifier")
    content_id: str = Field(..., description="Associated content record ID")
    project_id: str = Field(..., description="Associated project ID")
    user_id: str = Field(..., description="Owner user ID from Clerk auth")
    client_asset_id: Optional[str] = Field(None, description="Client-side asset ID")
    source: str = Field(default="device_capture", description="Asset source")
    kind: str = Field(..., description="Asset kind, e.g. screenshot or recording")
    mime_type: str = Field(..., description="Asset MIME type")
    file_name: Optional[str] = Field(None, description="Display filename")
    byte_size: Optional[int] = Field(None, description="File size in bytes")
    width: Optional[int] = Field(None, description="Pixel width")
    height: Optional[int] = Field(None, description="Pixel height")
    duration_ms: Optional[int] = Field(None, description="Duration for time-based media")
    storage_uri: Optional[str] = Field(None, description="Future cloud storage URI")
    status: ContentAssetStatus = Field(
        default=ContentAssetStatus.LOCAL_ONLY,
        description="Asset storage/sync state",
    )
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    deleted_at: Optional[datetime] = None

    class Config:
        use_enum_values = True


class StatusChange(BaseModel):
    """Audit trail entry for a status transition."""
    id: str = Field(..., description="Unique change identifier")
    content_id: str = Field(..., description="Content record ID")
    from_status: ContentLifecycleStatus = Field(..., description="Previous status")
    to_status: ContentLifecycleStatus = Field(..., description="New status")
    changed_by: str = Field(..., description="Who triggered the change (robot name or user)")
    actor_type: str = Field(..., description="Structured actor type")
    actor_id: str = Field(..., description="Structured actor ID")
    actor_label: str = Field(..., description="Structured actor label")
    actor_metadata: Optional[Dict[str, Any]] = Field(
        None,
        description="Structured actor metadata",
    )
    reason: Optional[str] = Field(None, description="Reason for the transition")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="When the change occurred")

    class Config:
        use_enum_values = True


class WorkDomainRecord(BaseModel):
    """Tracks the state of a work domain (SEO, Newsletter, etc.) for a project."""
    id: str = Field(..., description="Unique record identifier")
    project_id: str = Field(..., description="Associated project ID")
    domain: str = Field(..., description="Work domain name (seo, newsletter, images, scheduler)")
    status: str = Field(default="idle", description="Domain status (idle, running, paused, error)")
    last_run_at: Optional[datetime] = Field(None, description="Last execution timestamp")
    last_run_status: Optional[str] = Field(None, description="Last execution result")
    items_pending: int = Field(default=0, description="Items waiting to be processed")
    items_completed: int = Field(default=0, description="Items completed")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional domain metadata")
    updated_at: datetime = Field(default_factory=datetime.utcnow, description="Last update timestamp")

    class Config:
        use_enum_values = True
