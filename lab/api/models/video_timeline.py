"""Canonical ContentGlows video timeline API models."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, model_validator


FormatPreset = Literal["vertical_9_16", "landscape_16_9"]
TrackType = Literal["visual", "overlay", "audio"]
ClipType = Literal["text", "image", "video", "audio", "music", "background", "render_output"]
RenderMode = Literal["preview", "final"]
RenderJobStatus = Literal["queued", "in_progress", "completed", "failed", "cancelled"]
TimelineStatus = Literal["missing", "queued", "in_progress", "completed", "failed", "cancelled", "stale"]
BrandedGenerationReadiness = Literal["preview_ready", "preview_pending", "blocked"]
BrandedFeedReadiness = Literal["ready_to_publish", "preparing", "blocked", "failed"]

FPS = 30
MAX_DURATION_FRAMES = 180 * FPS
MAX_TRACKS = 12
MAX_CLIPS = 100
MAX_TEXT_CHARS = 2_000

FORMAT_DIMENSIONS: dict[str, tuple[int, int]] = {
    "vertical_9_16": (1080, 1920),
    "landscape_16_9": (1920, 1080),
}


class TimelineErrorDetail(BaseModel):
    code: str
    message: str
    field: str | None = None
    retry_after_seconds: int | None = None


class VideoTimelineTrack(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(..., min_length=1, max_length=128)
    type: TrackType
    order: int = Field(..., ge=0)
    exclusive: bool = True
    muted: bool = False
    locked: bool = False


class VideoTimelineClip(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(..., min_length=1, max_length=128)
    track_id: str = Field(..., min_length=1, max_length=128)
    clip_type: ClipType
    start_frame: int = Field(..., ge=0)
    duration_frames: int = Field(..., gt=0)
    asset_id: str | None = Field(default=None, max_length=256)
    trim_start_frame: int = Field(default=0, ge=0)
    role: str | None = Field(default=None, max_length=128)
    text: str | None = Field(default=None, max_length=MAX_TEXT_CHARS)
    volume: float | None = Field(default=None, ge=0, le=2)
    style: dict[str, Any] = Field(default_factory=dict)
    metadata: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_clip_requirements(self) -> "VideoTimelineClip":
        if self.clip_type == "text":
            if not (self.text or "").strip():
                raise ValueError("text clips require non-empty text")
            if self.asset_id:
                raise ValueError("text clips must not reference an asset")
        if self.clip_type in {"image", "video", "audio", "music"} and not self.asset_id:
            raise ValueError(f"{self.clip_type} clips require asset_id")
        if self.clip_type == "render_output":
            raise ValueError("render_output clips are reserved for a follow-up spec")
        return self


class VideoTimelineDocument(BaseModel):
    model_config = ConfigDict(extra="forbid", validate_assignment=True)

    schema_version: Literal["1.0"] = "1.0"
    format_preset: FormatPreset = "vertical_9_16"
    fps: Literal[30] = FPS
    duration_frames: int | None = Field(default=None, gt=0, le=MAX_DURATION_FRAMES)
    tracks: list[VideoTimelineTrack] = Field(default_factory=list)
    clips: list[VideoTimelineClip] = Field(default_factory=list)
    audio: dict[str, Any] = Field(default_factory=dict)
    render_policy: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_timeline(self) -> "VideoTimelineDocument":
        if len(self.tracks) > MAX_TRACKS:
            raise ValueError(f"timeline supports at most {MAX_TRACKS} tracks")
        if len(self.clips) > MAX_CLIPS:
            raise ValueError(f"timeline supports at most {MAX_CLIPS} clips")

        track_ids = [track.id for track in self.tracks]
        if len(set(track_ids)) != len(track_ids):
            raise ValueError("track ids must be unique")
        clip_ids = [clip.id for clip in self.clips]
        if len(set(clip_ids)) != len(clip_ids):
            raise ValueError("clip ids must be unique")

        tracks_by_id = {track.id: track for track in self.tracks}
        if not tracks_by_id:
            raise ValueError("timeline requires at least one track")

        visible_end_frame = 0
        clips_by_track: dict[str, list[VideoTimelineClip]] = {}
        for clip in self.clips:
            track = tracks_by_id.get(clip.track_id)
            if not track:
                raise ValueError(f"clip '{clip.id}' references missing track '{clip.track_id}'")
            if track.type == "audio" and clip.clip_type not in {"audio", "music"}:
                raise ValueError("audio tracks only accept audio or music clips")
            if track.type != "audio" and clip.clip_type in {"audio", "music"}:
                raise ValueError("audio and music clips require an audio track")
            clips_by_track.setdefault(track.id, []).append(clip)
            if not track.muted and track.type in {"visual", "overlay"} and clip.clip_type in {
                "text",
                "image",
                "video",
                "background",
            }:
                visible_end_frame = max(visible_end_frame, clip.start_frame + clip.duration_frames)

        if visible_end_frame <= 0:
            raise ValueError("timeline requires at least one visible text, image, video, or background clip")
        if visible_end_frame > MAX_DURATION_FRAMES:
            raise ValueError("timeline duration exceeds 180 seconds")
        if self.duration_frames is not None and self.duration_frames < visible_end_frame:
            raise ValueError("duration_frames cannot be shorter than visible clips")
        if self.duration_frames is None:
            self.duration_frames = visible_end_frame

        for track in self.tracks:
            if not track.exclusive:
                continue
            ordered = sorted(clips_by_track.get(track.id, []), key=lambda clip: clip.start_frame)
            previous_end = -1
            for clip in ordered:
                if clip.start_frame < previous_end:
                    raise ValueError(f"clips overlap on exclusive track '{track.id}'")
                previous_end = clip.start_frame + clip.duration_frames

        return self


class VideoTimelineFromContentRequest(BaseModel):
    content_id: str = Field(..., min_length=1)
    format_preset: FormatPreset = "vertical_9_16"
    client_request_id: str | None = Field(default=None, max_length=128)


class BrandedVideoTimelineFromContentRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    content_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("contentId", "content_id"),
        serialization_alias="contentId",
    )
    brand_profile_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("brandProfileId", "brand_profile_id"),
        serialization_alias="brandProfileId",
    )
    blueprint_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("blueprintId", "blueprint_id"),
        serialization_alias="blueprintId",
    )
    format_preset: FormatPreset = Field(
        default="vertical_9_16",
        validation_alias=AliasChoices("formatPreset", "format_preset"),
        serialization_alias="formatPreset",
    )


class BrandedVideoTimelinePreviewRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    content_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("contentId", "content_id"),
        serialization_alias="contentId",
    )
    brand_profile_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("brandProfileId", "brand_profile_id"),
        serialization_alias="brandProfileId",
    )
    blueprint_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("blueprintId", "blueprint_id"),
        serialization_alias="blueprintId",
    )
    format_preset: FormatPreset = Field(
        default="vertical_9_16",
        validation_alias=AliasChoices("formatPreset", "format_preset"),
        serialization_alias="formatPreset",
    )
    client_request_id: str | None = Field(
        default=None,
        max_length=128,
        validation_alias=AliasChoices("clientRequestId", "client_request_id"),
        serialization_alias="clientRequestId",
    )


class BrandedVideoGenerateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    content_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("contentId", "content_id"),
        serialization_alias="contentId",
    )
    brand_profile_id: str | None = Field(
        default=None,
        min_length=1,
        validation_alias=AliasChoices("brandProfileId", "brand_profile_id"),
        serialization_alias="brandProfileId",
    )
    blueprint_id: str | None = Field(
        default=None,
        min_length=1,
        validation_alias=AliasChoices("blueprintId", "blueprint_id"),
        serialization_alias="blueprintId",
    )
    format_preset: FormatPreset = Field(
        default="vertical_9_16",
        validation_alias=AliasChoices("formatPreset", "format_preset"),
        serialization_alias="formatPreset",
    )
    trigger_source: str | None = Field(
        default=None,
        max_length=120,
        validation_alias=AliasChoices("triggerSource", "trigger_source"),
        serialization_alias="triggerSource",
    )
    client_request_id: str | None = Field(
        default=None,
        max_length=128,
        validation_alias=AliasChoices("clientRequestId", "client_request_id"),
        serialization_alias="clientRequestId",
    )


class VideoTimelineDraftRequest(BaseModel):
    base_version_id: str | None = None
    draft_revision: int = Field(..., ge=0)
    timeline: VideoTimelineDocument


class VideoTimelineVersionCreateRequest(BaseModel):
    base_version_id: str | None = None
    draft_revision: int = Field(..., ge=0)
    timeline: VideoTimelineDocument
    client_request_id: str | None = Field(default=None, max_length=128)


class VideoTimelinePreviewRequest(BaseModel):
    client_request_id: str | None = Field(default=None, max_length=128)


class VideoTimelinePreviewApproveRequest(BaseModel):
    approved: bool = True


class VideoTimelineFinalRenderRequest(BaseModel):
    preview_job_id: str = Field(..., min_length=1)
    client_request_id: str | None = Field(default=None, max_length=128)


class VideoTimelineValidationResult(BaseModel):
    valid: bool
    errors: list[TimelineErrorDetail] = Field(default_factory=list)


class VideoTimelineArtifact(BaseModel):
    playback_url: str
    artifact_expires_at: datetime
    retention_expires_at: datetime
    deletion_warning_at: datetime
    byte_size: int
    mime_type: str
    file_name: str
    render_mode: RenderMode


class VideoTimelineRenderJobResponse(BaseModel):
    job_id: str
    timeline_id: str
    version_id: str
    render_mode: RenderMode
    status: RenderJobStatus
    progress: int = Field(ge=0, le=100)
    message: str | None = None
    artifact: VideoTimelineArtifact | None = None
    stale: bool = False
    created_at: datetime
    updated_at: datetime


class VideoTimelineVersionResponse(BaseModel):
    version_id: str
    timeline_id: str
    version_number: int
    timeline: VideoTimelineDocument
    renderer_props: dict[str, Any]
    approved_preview_job_id: str | None = None
    preview_approved_at: datetime | None = None
    created_at: datetime


class VideoTimelineDraftResponse(BaseModel):
    timeline_id: str
    draft_revision: int
    latest_version_id: str | None = None
    timeline: VideoTimelineDocument
    validation: VideoTimelineValidationResult
    preview_status: TimelineStatus


class VideoTimelineResponse(BaseModel):
    timeline_id: str
    content_id: str
    project_id: str
    user_id: str
    format_preset: FormatPreset
    current_version_id: str | None = None
    draft_revision: int
    draft: VideoTimelineDocument
    latest_version: VideoTimelineVersionResponse | None = None
    preview_status: TimelineStatus = "missing"
    final_status: TimelineStatus = "missing"
    created_at: datetime
    updated_at: datetime


class BrandedVideoGenerationResponse(BaseModel):
    timeline: VideoTimelineResponse
    version: VideoTimelineVersionResponse
    preview_job: VideoTimelineRenderJobResponse
    readiness: BrandedGenerationReadiness
    blockers: list[str] = Field(default_factory=list)


class BrandedVideoFeedCandidateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    project_id: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("projectId", "project_id"),
        serialization_alias="projectId",
    )
    content_ids: list[str] = Field(
        default_factory=list,
        validation_alias=AliasChoices("contentIds", "content_ids"),
        serialization_alias="contentIds",
    )
    format_preset: FormatPreset = Field(
        default="vertical_9_16",
        validation_alias=AliasChoices("formatPreset", "format_preset"),
        serialization_alias="formatPreset",
    )
    limit: int = Field(default=20, ge=1, le=100)
    trigger_source: str | None = Field(
        default=None,
        max_length=120,
        validation_alias=AliasChoices("triggerSource", "trigger_source"),
        serialization_alias="triggerSource",
    )


class BrandedVideoFeedCandidateResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    content_id: str = Field(serialization_alias="contentId")
    project_id: str = Field(serialization_alias="projectId")
    format_preset: FormatPreset = Field(serialization_alias="formatPreset")
    readiness: BrandedFeedReadiness
    status: str
    blockers: list[str] = Field(default_factory=list)
    blocker_code: str | None = Field(default=None, serialization_alias="blockerCode")
    blocker_summary: str | None = Field(default=None, serialization_alias="blockerSummary")
    timeline_id: str | None = Field(default=None, serialization_alias="timelineId")
    version_id: str | None = Field(default=None, serialization_alias="versionId")
    preview_job_id: str | None = Field(default=None, serialization_alias="previewJobId")
    final_job_id: str | None = Field(default=None, serialization_alias="finalJobId")
    updated_at: datetime = Field(serialization_alias="updatedAt")
    completed_at: datetime | None = Field(default=None, serialization_alias="completedAt")


class BrandedVideoFeedCandidateListResponse(BaseModel):
    items: list[BrandedVideoFeedCandidateResponse] = Field(default_factory=list)


class VideoTimelinePublishPlatformTarget(BaseModel):
    platform: str = Field(..., min_length=1)
    account_id: str = Field(..., min_length=1)
    custom_content: str | None = None


class VideoTimelineSwipePublishRequest(BaseModel):
    preview_job_id: str | None = Field(default=None, min_length=1)
    content: str = Field(..., min_length=1, max_length=10000)
    platforms: list[VideoTimelinePublishPlatformTarget] = Field(..., min_length=1)
    title: str | None = Field(default=None, max_length=500)
    scheduled_for: str | None = None
    publish_now: bool = True
    tags: list[str] = Field(default_factory=list)
    client_request_id: str | None = Field(default=None, max_length=128)


class VideoTimelineSwipePublishResponse(BaseModel):
    state: Literal["published", "scheduled", "final_pending", "blocked"]
    version: VideoTimelineVersionResponse
    final_job: VideoTimelineRenderJobResponse | None = None
    publish_result: dict[str, Any] | None = None
    blockers: list[str] = Field(default_factory=list)


class ContentGlowsTimelineProps(BaseModel):
    model_config = ConfigDict(extra="forbid")

    composition_id: Literal["ContentGlowsTimelineVideo"] = "ContentGlowsTimelineVideo"
    timeline_id: str
    version_id: str
    format: dict[str, Any]
    tracks: list[dict[str, Any]]
    clips: list[dict[str, Any]]
    assets: dict[str, dict[str, Any]] = Field(default_factory=dict)
