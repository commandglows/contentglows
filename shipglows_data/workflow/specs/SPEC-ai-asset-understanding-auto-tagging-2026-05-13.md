---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-13"
created_at: "2026-05-13 08:15:03 UTC"
updated: "2026-05-14"
updated_at: "2026-05-14 12:06:00 UTC"
status: reviewed
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "medium"
user_story: "En tant que creatrice ContentGlowz, je veux que mes images et videos de projet soient comprises, taguees et recommandees automatiquement, afin de retrouver des illustrations et b-rolls pertinents pour mes futurs contenus sans trier toute ma mediatheque a la main."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "Unified Project Asset Library"
  - "lab/status"
  - "api/projects/{project_id}/assets"
  - "Content editor"
  - "Capture assets"
  - "Bunny CDN"
  - "Clerk"
  - "Turso/libSQL or status DB migrations"
  - "future provider research"
  - "Global Asset Library"
  - "Provider credentials and BYOK settings"
depends_on:
  - artifact: "lab/CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "app/CLAUDE.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "partial-shipped"
  - artifact: "Gemini API video understanding docs"
    artifact_version: "2026-05-07"
    required_status: "official"
  - artifact: "OpenAI images/vision docs"
    artifact_version: "current-2026-05-13"
    required_status: "official"
  - artifact: "OpenAI speech-to-text docs"
    artifact_version: "current-2026-05-13"
    required_status: "official"
supersedes: []
evidence:
  - "User decision 2026-05-13: 'birogues' means b-rolls."
  - "User decision 2026-05-13: V1 must analyze uploaded project assets, app captures, and imported social videos used as illustrations."
  - "User example 2026-05-13: for a kung-fu video, an Instagram-style clip of a deer jumping may be a relevant eye-catching illustration if credited."
  - "User decision 2026-05-13: the engine should generally understand what happens in each video, not only detect specific SaaS signup steps."
  - "User decision 2026-05-13: prefer BYOK and run a dedicated provider exploration; likely free or low-cost options should be considered."
  - "User decision 2026-05-13: detection quality determines how visible/editable the tags are, but assets need tags for future project association."
  - "User decision 2026-05-13: V1 needs both a global reusable asset library and project-level asset views/attachments."
  - "User decision 2026-05-13: provider credentials must support both platform/global keys and user BYOK keys, like the rest of the product."
  - "User decision 2026-05-13: implementation should be compatible with Gemini."
  - "Code evidence: lab already exposes project assets through api/routers/assets.py and status.service project_assets records with metadata, events and usages."
  - "Code evidence: app already has ProjectAsset models, ApiService methods, Riverpod state and a reusable ProjectAssetPicker."
next_step: "/sf-ship shipglows_data/workflow/specs/SPEC-ai-asset-understanding-auto-tagging-2026-05-13.md"
---

# Title

AI Asset Understanding Auto Tagging

## Status

Closed after final verification. This spec defines the product and technical contract for understanding, tagging and recommending project image/video assets. It extends the existing Unified Project Asset Library into a two-level library: a user/workspace-scoped reusable asset library plus project-level asset attachments/views. It does not introduce a public DAM or free-form provider playground.

## User Story

En tant que creatrice ContentGlowz, je veux que mes images et videos de projet soient comprises, taguees et recommandees automatiquement, afin de retrouver des illustrations et b-rolls pertinents pour mes futurs contenus sans trier toute ma mediatheque a la main.

## Minimal Behavior Contract

When an image or video asset is added, imported, captured, attached to a project, or explicitly re-analyzed, ContentGlowz stores or reuses a user/workspace-scoped canonical asset, links it to the current project when applicable, and creates an authenticated async understanding job subject to strict cost/privacy guardrails. The job extracts safe media signals, resolves a provider credential from user BYOK first and platform/global key second, asks a Gemini-compatible analyzer to summarize what the asset depicts, stores normalized tags, scene segments, b-roll or illustration placements, confidence scores and source-credit metadata, and makes those signals searchable from the global library and recommendable inside authorized project workflows. If analysis is unavailable, unsafe, too large, unsupported, quota-limited, or low-confidence, the asset remains usable but is marked with a recoverable understanding status instead of receiving misleading tags. The easy edge case to miss is social or third-party footage: recommendations may say a deer-jumping clip fits a kung-fu video as an eye-catching illustration, but they must preserve source attribution/credit warnings and must not invent legal permission.

## Success Behavior

- Given an owned project asset is an image, capture, thumbnail, video, video cover, render output, or imported social video, when analysis is requested, then the backend creates an `asset_understanding` job scoped to the project/user and records status `queued`.
- Given an asset already exists in the user's global library, when it is attached to a new project, then ContentGlowz reuses the canonical asset understanding result and records a project-level attachment/usage rather than duplicating the media or re-running analysis by default.
- Given the job runs on an image, when the analyzer succeeds, then the asset receives normalized visual tags, detected objects/scene concepts, suggested placements such as `illustration`, `thumbnail_candidate`, `visual_reference_candidate`, and confidence metadata.
- Given the job runs on a video, when the analyzer succeeds, then the asset receives video-level tags plus timestamped scene segments with start/end seconds, short labels, b-roll or illustration suitability, and confidence metadata.
- Given a video has audio or visible UI text, when the analyzer supports audio/vision/OCR, then the stored result may include safe high-level cues such as "signup flow", "dashboard", "waterfall", "animal movement", "martial arts motion", or "software demo", but not full sensitive OCR dumps by default.
- Given the asset came from a social network or external creator, when it is recommended, then the response includes `source_attribution`, `credit_text` and a rights/reuse warning if permission is unknown.
- Given the user or automation asks for assets for a future content brief, when tags exist, then the recommendation endpoint returns ranked owned project assets with fit reasons, suggested usage (`b_roll`, `illustration`, `background_visual`, `thumbnail_candidate`) and warnings.
- Given the request allows reusable assets, when recommendations run for a project, then ranking can include assets from the same user's global library that are not yet attached to that project, but the response must mark them as `candidate_global_asset` and require explicit attachment before use.
- Given both user BYOK and platform provider credentials exist, when an understanding job runs, then the user BYOK credential is used first; if it is absent or disabled, the platform/global credential may be used; if neither is configured, the job returns `provider_not_configured`.
- Given tags are low-confidence, when they are shown in the app, then they appear as suggestions rather than accepted user tags and do not dominate recommendations.
- Given a user accepts, edits, or rejects AI tags, when the asset is reloaded, then accepted user tags are preserved and AI suggestions remain traceable separately.

## Error Behavior

- If the user is unauthenticated, return `401` through the existing Clerk dependency.
- If the project or asset is not owned by the current user, return `403` or `404` using existing ownership conventions and do not reveal whether another user's asset exists.
- If the media is unsupported, missing storage, tombstoned, local-only without upload, too large, or cannot be sampled, mark understanding `failed` or `degraded` with a typed non-secret error and keep existing asset usability unchanged.
- If the analyzer provider is not configured, create no misleading tags; return `provider_not_configured` or leave the job `blocked` with a visible setup status.
- If media or job volume exceeds configured guardrails, do not call the provider; mark the job `skipped_limit_exceeded`, `quota_exceeded`, or `needs_trim` with recoverable non-secret details.
- If the provider times out or returns malformed output, mark the job failed with normalized error metadata and allow retry.
- If generated tags include unsafe, private, or copyrighted claims beyond the evidence, discard or downgrade them; never store provider raw payloads as user-facing truth.
- If source attribution is missing for third-party/social footage, recommendations must include `rights_status: unknown` and `credit_required: true` instead of silently treating the asset as free to reuse.
- What must never happen: cross-project asset leakage, automatic use of third-party media without attribution warning, provider keys in logs/responses, storing raw frame images/OCR transcripts unnecessarily, or auto-publishing an asset purely because AI recommended it.

## Problem

ContentGlowz now has a unified project asset layer, but assets are still mostly passive files. The system does not know whether a video shows a SaaS signup, a waterfall, a person demonstrating a product, a deer jumping, an abstract background, or a useful b-roll segment. This blocks future workflows from automatically choosing relevant visuals for articles, social posts, reels, thumbnails, or video scenes.

## Solution

Add an AI asset-understanding layer on top of Project Asset Library. The backend keeps a canonical user/workspace asset record for reusable media, links those assets to projects through project-level attachments/usages, runs async analysis jobs, stores normalized tags/segments/credit metadata, and exposes search/recommendation APIs. The Flutter app surfaces suggested tags and recommendation reasons inside the existing asset picker/library, with confidence and attribution warnings. Provider choice remains pluggable and BYOK-friendly, but V1 implementation must include a Gemini-compatible adapter path because official Gemini docs support audio+visual video analysis and timestamps; OpenAI vision/speech-to-text remain useful fallback hooks for image/frame/audio workflows.

## Scope In

- Analyze existing and future project assets with media kinds `image`, `thumbnail`, `video_cover`, `video`, `render_output`, and `capture`.
- Add a user/workspace-scoped global asset library record for reusable images/videos, plus project-level attachment/usage records so the same understood asset can be reused in future projects without duplicating media.
- Support assets from manual upload, app capture, generated assets, render outputs, and imported social videos already registered as project assets.
- Add project-scoped async understanding jobs with retryable statuses.
- Extract deterministic media metadata before AI analysis: MIME type, duration, dimensions, file size when available, representative frames/thumbnails, and optional audio track presence.
- Store normalized AI tags, user-accepted tags, rejected tags, scene segments, suggested placements, confidence scores, summary, and provider metadata.
- Store source attribution fields for third-party/social media: platform, original URL, creator handle/name, credit text, imported URL, rights/reuse status, and notes.
- Add recommendation API for a content/video brief that returns ranked project assets and, when explicitly allowed, candidate global-library assets with fit reasons.
- Add provider credential resolution supporting both user BYOK and platform/global credentials.
- Add configurable guardrails for video length, sampled duration, frame count, file size, concurrency, daily quotas, retry, timeout and provider-cost control.
- Add Flutter typed models/API methods and minimal picker/library display for suggested tags, accepted tags, understanding status, and recommendation warnings.
- Preserve the existing asset picker selection model; recommendations help choose assets but do not auto-select or auto-publish.

## Scope Out

- Building a public DAM, team marketplace, or external-facing media portal.
- Scraping or downloading social network content directly from arbitrary URLs.
- Proving copyright/licensing ownership automatically.
- Auto-publishing third-party assets without user/editor validation.
- Full video editing, trimming, rendering, Remotion scene assembly, or audio generation.
- Fine-tuning a custom video-understanding model.
- Face recognition, identity matching, biometric classification, or sensitive-person inference.
- Storing full OCR transcripts, full audio transcripts, or sampled frame images as durable user-facing metadata by default.
- Cross-user, cross-workspace, team-shared, or public asset recommendations unless a future brand/team library spec explicitly authorizes it.

## Constraints

- Extend the existing `project_assets` domain rather than creating a disconnected library: V1 may add a canonical global asset table, but project asset records remain the user-facing project attachment/selection surface.
- All analysis is scoped by `user_id` or workspace owner plus optional `project_id`; project recommendations may only read project assets plus explicitly allowed global-library assets owned by the same user/workspace.
- Provider credentials are server-side platform/global credentials or user BYOK credential references; raw keys are never stored in asset metadata, result metadata, logs, or API responses.
- Credential resolution order is user BYOK first, then platform/global key if enabled for the user/workspace, then `provider_not_configured`.
- Provider selection is an operator/configuration concern; app users see guided analysis states and recommendations, not raw model/provider controls.
- Imported social-media assets must carry attribution metadata before they can be recommended without a warning.
- Understanding results are probabilistic. UI copy must present AI tags as suggestions until user accepted.
- Long videos must be sampled or clipped with bounded cost/time. Do not send unbounded media to any provider.
- V1 default guardrails are configurable but must ship with safe defaults:
  - `ASSET_UNDERSTANDING_MAX_IMAGE_BYTES`: 25 MB.
  - `ASSET_UNDERSTANDING_MAX_SOURCE_VIDEO_BYTES`: 500 MB for local inspection; larger videos become `needs_trim`.
  - `ASSET_UNDERSTANDING_MAX_SOURCE_VIDEO_SECONDS`: 1800 seconds for local inspection; longer videos become `needs_trim`.
  - `ASSET_UNDERSTANDING_MAX_PROVIDER_VIDEO_SECONDS`: 90 seconds of sampled clips per job.
  - `ASSET_UNDERSTANDING_MAX_PROVIDER_FRAMES`: 180 frames per job.
  - `ASSET_UNDERSTANDING_MAX_PROVIDER_FPS`: 1 FPS, reduced automatically to stay under frame and sampled-duration caps.
  - `ASSET_UNDERSTANDING_MAX_AUDIO_SECONDS`: 120 seconds of sampled audio/transcription cues per job.
  - `ASSET_UNDERSTANDING_CONCURRENCY_PER_PROJECT`: 2 running jobs.
  - `ASSET_UNDERSTANDING_CONCURRENCY_PER_USER`: 4 running jobs.
  - `ASSET_UNDERSTANDING_DAILY_PLATFORM_QUOTA`: 100 images and 25 videos per user/day when using platform credentials.
  - `ASSET_UNDERSTANDING_DAILY_BYOK_QUOTA`: 250 images and 50 videos per user/day by default, still operator-configurable to protect infrastructure.
  - `ASSET_UNDERSTANDING_PROVIDER_TIMEOUT_SECONDS`: 120 for images and 600 for videos.
  - `ASSET_UNDERSTANDING_MAX_RETRIES`: 2 with exponential backoff and idempotency keys.
- Sensitive software-demo footage may contain PII, emails, tokens, or customer data. The analysis pipeline must minimize raw content retention.
- V1 is asynchronous. The asset detail response can show the latest result, but request paths must not block on full video analysis.

## Dependencies

- Existing backend asset router: `lab/api/routers/assets.py`.
- Existing project asset schemas: `lab/status/schemas.py` and `lab/api/models/status.py`.
- Existing status service and migrations: `lab/status/service.py`, `lab/status/db.py`.
- Existing or new provider credential settings service for user BYOK and platform/global provider keys.
- Existing Flutter asset models/API/provider/picker:
  - `app/lib/data/models/project_asset.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
- Existing capture flows:
  - `app/lib/presentation/screens/capture/capture_screen.dart`
  - `app/lib/data/models/capture_asset.dart`
- Media tooling: use proven tools such as `ffprobe`/`ffmpeg` for duration, frame extraction, audio extraction and thumbnail sampling. Reuse `lab/agents/reels/audio_extractor.py` patterns where appropriate.
- Fresh external docs checked:
  - Gemini API video understanding docs, last updated 2026-05-07: supports video inputs, audio+visual processing, timestamps, clipping and FPS customization. `fresh-docs checked`.
  - OpenAI Images/Vision docs, current 2026-05-13: supports image input analysis through vision-capable models. `fresh-docs checked`.
  - OpenAI Speech-to-text docs, current 2026-05-13: supports transcriptions/translations and current transcribe models with file limits. `fresh-docs checked`.

## Invariants

- Asset understanding belongs to one owned canonical global asset and may be referenced by multiple owned project attachments/usages.
- Project-level recommendation results must never include another user/workspace's global assets.
- A global-library candidate cannot be used in a project workflow until it is explicitly attached to that project or selected through an API path that creates the attachment atomically.
- AI tags never replace user-accepted tags without explicit action.
- Recommendation ranking must always include enough reason/warning metadata for the user to understand why an asset appeared.
- Third-party/social source attribution is preserved through analysis, recommendation and selection.
- Tombstoned/degraded/local-only assets cannot be recommended for publishable usage unless the response explicitly marks them unavailable/historical.
- Provider raw responses, base64 frames, and secrets are not exposed through API responses.
- Provider calls must be idempotent per asset/version/job request so replay or double-submit cannot create duplicate charged jobs beyond the configured retry policy.
- Existing asset list/detail/select/tombstone/restore behavior remains backward compatible.

## Links & Consequences

- `lab/status/db.py`: needs idempotent tables/indexes for canonical global assets, project asset attachments/usages, understanding jobs, results, tags, segments, quotas and recommendation events.
- `lab/status/service.py`: needs canonical asset upsert/link helpers, asset-understanding create/update/list helpers, quota checks and event recording.
- `lab/api/models/status.py`: needs request/response models for global assets, project attachments, analysis jobs, tags, segments, attribution, credential source, quotas and recommendations.
- `lab/api/routers/assets.py`: needs endpoints under `/api/projects/{project_id}/assets/{asset_id}/understanding` and `/api/projects/{project_id}/assets/recommend`.
- `lab/api/services/*`: needs an analyzer service with provider adapters, credential resolution, guardrail enforcement and deterministic media extraction.
- `app/lib/data/models/project_asset.dart`: needs typed understanding metadata or dedicated models.
- `app/lib/data/services/api_service.dart`: needs typed calls for queue/status/accept-tags/recommendations.
- `app/lib/providers/providers.dart`: needs state methods that avoid stale active-project updates, following the existing asset-library guard pattern.
- `app/lib/presentation/widgets/project_asset_picker.dart`: can show AI tag chips, accepted tags, confidence, fit reasons and credit warnings.
- Docs: backend README and app support copy must distinguish "AI suggested tags" from user-confirmed tags, explain global-vs-project library behavior, document BYOK/platform credential resolution, quotas and legal rights.

## Documentation Coherence

- Update `lab/README.md` with asset understanding setup, provider env/BYOK requirements, job behavior, retention and attribution rules.
- Update app docs or support copy when the picker starts showing AI tags/recommendations.
- Add operational notes for ffmpeg availability, provider cost/time limits, default guardrail env vars, BYOK/platform credential precedence and quota behavior.
- Add a short privacy note: software-demo video analysis may contain sensitive screen content; raw frames/OCR should not be stored as durable metadata.
- Changelog should describe this as asset understanding/tagging, not as guaranteed semantic search or automatic copyright clearance.

## Edge Cases

- A waterfall/animal/cascade clip is visually relevant to a martial-arts video but has no legal permission metadata.
- A global-library asset is relevant to a new project but is not yet attached to that project.
- A software demo shows a signup flow but also includes private email/token text.
- A fast-moving short video changes scenes faster than 1 FPS sampling can capture.
- A long imported video exceeds provider upload limits and needs clipping/sampling.
- A silent video still needs visual understanding.
- An audio-only or music asset is present in the asset library but outside this visual understanding V1.
- An asset is re-analyzed after the user edited tags; user tags must not be overwritten.
- Provider returns plausible but wrong labels; low-confidence or user-rejected tags should not dominate recommendations.
- Imported source URL expires or is removed, but the durable asset remains in Bunny.
- Same visual appears as multiple assets; V1 may not dedupe unless metadata hash exists.
- A user clicks re-analyze repeatedly or two ingestion paths schedule the same asset simultaneously; idempotency and concurrency controls must prevent duplicate active provider jobs.
- A user BYOK key fails after the platform key is available; the failure must be attributed to the chosen credential source and must not silently charge the platform key unless fallback is explicitly allowed by configuration.

## Implementation Tasks

- [ ] Task 1: Define asset understanding schemas and metadata contract
  - File: `lab/api/models/status.py`, `lab/status/schemas.py`
  - Action: Add models/enums for `GlobalAsset`, `ProjectAssetAttachment`, `AssetUnderstandingStatus`, `AssetUnderstandingJob`, `AssetUnderstandingResult`, `AssetSemanticTag`, `AssetSceneSegment`, `AssetSourceAttribution`, `AssetCredentialSource`, `AssetUnderstandingQuota`, `AssetRecommendationRequest`, and `AssetRecommendationResponse`.
  - User story link: Gives the system a durable vocabulary for "what is in this asset" and how it can be reused.
  - Depends on: existing Project Asset Library.
  - Validate with: schema/model tests for tags, segments, confidence bounds, attribution and recommendation response shape.

- [ ] Task 2: Add persistence and indexes
  - File: `lab/status/db.py`, `lab/status/service.py`
  - Action: Add idempotent tables for canonical global assets, project asset attachments/usages, understanding jobs/results/tags/segments, source attribution, quota counters and idempotency keys; index by user/workspace/project/asset/status/tag/placement/confidence.
  - User story link: Makes tags searchable and reusable across future projects/content workflows.
  - Depends on: Task 1.
  - Validate with: migration/ensure tests and status service unit tests.

- [ ] Task 3: Add deterministic media inspection service
  - File: `lab/api/services/asset_media_inspection.py`
  - Action: Implement bounded ffprobe/ffmpeg-based inspection for images/videos: duration, dimensions, representative frame plan, audio presence, size limits, configured guardrails and safe temp cleanup.
  - User story link: Provides reliable non-AI signals and bounded inputs for video understanding.
  - Depends on: Task 2.
  - Validate with: tests using tiny fixture images/videos or mocked subprocess output.

- [ ] Task 4: Add provider adapter interface and BYOK-compatible analyzer
  - File: `lab/api/services/asset_understanding.py`
  - Action: Add provider-neutral analyzer interface, credential-resolution service, and a Gemini-compatible reference adapter for video+image understanding behind user BYOK and platform/global credentials; include OpenAI vision+speech fallback hooks for image/frame/audio workflows without exposing raw provider controls.
  - User story link: Lets the engine understand videos/images while preserving provider flexibility.
  - Depends on: Task 3.
  - Validate with: mocked provider tests for image tags, video timeline, malformed JSON, timeout, provider_not_configured and rate-limit errors.

- [ ] Task 5: Implement async analysis job lifecycle
  - File: `lab/api/routers/assets.py`, `lab/status/service.py`, `lab/api/services/asset_understanding.py`
  - Action: Add queue/retry/status endpoints for asset understanding and run background jobs that enforce idempotency, quotas, concurrency, guardrails and credential source before persisting normalized results and asset events.
  - User story link: Allows uploads/captures/social imports to be analyzed without blocking the user.
  - Depends on: Tasks 2-4.
  - Validate with: FastAPI route tests for owned/missing/foreign asset, queued/running/completed/failed states and idempotent re-analysis.

- [ ] Task 6: Normalize AI tags, scene segments and attribution
  - File: `lab/api/services/asset_understanding_normalizer.py`
  - Action: Convert provider output into allowed tags, placements, confidence scores, scene start/end seconds, fit summaries, `rights_status`, and `credit_required` warnings; reject raw transcripts/frame payloads.
  - User story link: Makes analysis safe and useful for recommendations rather than opaque provider text.
  - Depends on: Task 4.
  - Validate with: unit tests for social attribution, low-confidence downgrade, unsafe/OCR redaction and segment validation.

- [ ] Task 7: Add recommendation endpoint
  - File: `lab/api/routers/assets.py`, `lab/api/services/asset_recommendations.py`
  - Action: Add `POST /api/projects/{project_id}/assets/recommend` that accepts a content/video brief, target placement, optional tags and an `include_global_candidates` flag, then ranks owned project assets plus eligible same-user global-library candidates by accepted tags, AI suggestions, segments, media kind, source attribution and eligibility.
  - User story link: Enables "this deer jumping video is a good illustration for the kung-fu video" with reasons and credit warning.
  - Depends on: Tasks 2 and 6.
  - Validate with: tests for ranking, project scoping, tombstoned/degraded filtering, unknown-rights warning and no cross-project leakage.

- [ ] Task 8: Add user tag acceptance/edit/reject APIs
  - File: `lab/api/routers/assets.py`, `lab/status/service.py`
  - Action: Add endpoints to accept suggested tags, add manual tags, reject bad tags, attach global assets to projects, and preserve user tags across re-analysis.
  - User story link: Lets detection quality improve through user control instead of blindly trusting AI.
  - Depends on: Tasks 2 and 6.
  - Validate with: route/service tests proving user tags survive re-analysis and rejected tags stop influencing recommendations.

- [ ] Task 9: Add Flutter models and API methods
  - File: `app/lib/data/models/project_asset.dart`, `app/lib/data/services/api_service.dart`
  - Action: Add typed global asset, project attachment, understanding status/result/tag/segment/recommendation/quota models and API methods for queue/status/accept/reject/attach-global/recommend.
  - User story link: Lets the app consume the new backend contract without parsing raw metadata maps.
  - Depends on: Tasks 1, 5, 7 and 8.
  - Validate with: Dart model parsing tests and API payload serialization tests.

- [ ] Task 10: Extend provider state and asset picker UI
  - File: `app/lib/providers/providers.dart`, `app/lib/presentation/widgets/project_asset_picker.dart`
  - Action: Surface project assets and optional global candidates, suggested tags, accepted tags, understanding status, scene labels, recommendation fit reasons, quota/provider setup states and credit warnings; keep edits project-stale safe.
  - User story link: Makes the understanding visible and usable in current content workflows.
  - Depends on: Task 9.
  - Validate with: provider tests for stale project changes and widget tests for tags/warnings/recommendation display.

- [ ] Task 11: Wire ingestion triggers conservatively
  - File: `lab/status/service.py`, relevant upload/capture/import integration points
  - Action: Upsert canonical global assets, attach them to projects, and trigger or schedule analysis for new eligible assets from manual upload, capture attachment, Image Robot output, render output and social import registration; do not block asset creation when analysis is unavailable.
  - User story link: Ensures assets become useful automatically after they enter the library.
  - Depends on: Tasks 5 and 6.
  - Validate with: integration tests proving asset creation can succeed while analysis queues or degrades separately.

- [ ] Task 12: Document operations, privacy and attribution
  - File: `lab/README.md`, optional app support docs
  - Action: Document provider/BYOK config, ffmpeg requirements, source attribution rules, retention limits, retry behavior, and "AI tags are suggestions" language.
  - User story link: Keeps operators and users from mistaking AI tags for legal clearance or perfect understanding.
  - Depends on: all backend tasks.
  - Validate with: docs review and setup sanity checks.

## Acceptance Criteria

- [ ] CA 1: Given an owned image asset, when analysis is queued, then the API returns a user/workspace-scoped canonical asset, optional project attachment, queued job and no cross-user/workspace data.
- [ ] CA 2: Given an owned video asset, when analysis completes, then the result includes video-level tags and at least one timestamped scene segment when the provider returns segmentable content.
- [ ] CA 3: Given an asset has no configured analyzer provider, when analysis is requested, then the asset remains usable and the job exposes `provider_not_configured` without fake tags.
- [ ] CA 3a: Given both user BYOK and platform credentials are configured, when analysis runs, then the job records `credential_source=user_byok`; given user BYOK is absent and platform fallback is enabled, then it records `credential_source=platform`.
- [ ] CA 4: Given a social/imported asset has creator attribution, when it is recommended, then the response includes credit text and source metadata.
- [ ] CA 5: Given a social/imported asset lacks known permission, when it is recommended, then `rights_status=unknown` and `credit_required=true` are visible.
- [ ] CA 6: Given a kung-fu content brief and a deer-jumping video tagged as animal/motion/jump/nature, when recommendations run, then that asset can rank as `illustration` or `b_roll` with a fit reason and attribution warning.
- [ ] CA 6a: Given the deer-jumping video exists only in the user's global library, when project recommendations run with `include_global_candidates=true`, then it can appear as `candidate_global_asset` and must require explicit project attachment before publishable use.
- [ ] CA 7: Given a software signup recording, when analysis succeeds, then tags may include high-level concepts such as `software_demo`, `signup_flow`, `form`, or `dashboard` without storing full OCR text.
- [ ] CA 8: Given AI tags are low-confidence, when the app renders them, then they appear as suggestions and do not become accepted tags automatically.
- [ ] CA 9: Given the user accepts, edits, or rejects a tag, when the asset is re-analyzed, then user decisions remain preserved.
- [ ] CA 10: Given a tombstoned, degraded, local-only, or missing-storage asset, when recommendations run, then it is excluded or clearly marked unavailable according to existing eligibility rules.
- [ ] CA 11: Given a foreign project asset ID, when any understanding/status/recommendation/tag action is attempted, then the API returns 403/404 and writes no job/result.
- [ ] CA 12: Given provider output includes raw base64 frames, raw transcripts, prompt text or unexpected payloads, when normalized, then only allowed safe fields are persisted.
- [ ] CA 13: Given the active project changes in Flutter during a recommendation/tag mutation, when the response returns, then state is not applied to the new project context.
- [ ] CA 14: Given existing asset library list/detail/select flows are used, when understanding is added, then previous response contracts remain backward compatible.
- [ ] CA 15: Given a video exceeds configured duration, file-size, sampled-duration, frame-count or quota guardrails, when analysis is requested, then no provider call is made and the job exposes `needs_trim`, `skipped_limit_exceeded` or `quota_exceeded`.
- [ ] CA 16: Given duplicate analysis requests for the same asset/version arrive concurrently, when jobs are queued, then at most one active provider job is created and other requests reuse the existing job/status.

## Test Strategy

- Python schema tests for understanding models, confidence bounds, attribution enums and response serialization.
- Python migration/service tests for job/result/tag/segment persistence and indexes.
- Mocked provider tests for video timeline, image tags, invalid provider JSON, timeout, rate limit, provider_not_configured and unsafe payload stripping.
- Route tests for ownership, queued analysis, status reads, tag accept/reject, global-asset attachment, recommendations and attribution warnings.
- Quota/guardrail tests for max bytes, duration, frame count, sampled seconds, provider timeout, retry count, duplicate submission, per-project concurrency, per-user concurrency and daily platform/BYOK quota.
- Credential-resolution tests for user BYOK precedence, platform fallback, disabled fallback, missing provider and no secret leakage in errors/log-like payloads.
- Recommendation ranking tests with controlled asset fixtures: SaaS demo, waterfall, deer jump, martial arts, generic abstract background.
- Flutter Dart model tests for parsing understanding/recommendation payloads.
- Flutter provider tests for project-stale guards and error states.
- Flutter widget tests for suggested tags, accepted tags, confidence warnings and credit warnings in the picker.
- Manual smoke: add/import one software demo video and one eye-catching nature/social clip, run analysis, request recommendations for a content/video brief, verify tags/reasons/warnings.

## Risks

- Provider quality risk: video understanding can miss fast actions, hallucinate labels or overstate relevance. Mitigation: confidence scores, suggested-vs-accepted tags, user reject/edit controls and no auto-publish.
- Legal risk: social media footage may require permission beyond credit. Mitigation: preserve attribution, show unknown-rights warnings, never infer legal clearance.
- Privacy risk: software demos can contain emails, tokens or customer data. Mitigation: avoid durable raw OCR/transcript/frame storage by default, redact provider metadata, project-scope all reads.
- Cost/performance risk: long videos are expensive. Mitigation: async jobs, sampling, clipping, size limits, provider timeouts and retry/backoff.
- Data-model risk: JSON-only metadata would be hard to search and project-only assets would block future reuse. Mitigation: canonical global asset records, project attachments/usages, normalized tag/segment tables plus summary metadata on assets.
- Product risk: users may trust AI tags too much. Mitigation: UI labels suggestions clearly and keeps accepted user tags separate.
- Implementation risk: provider exploration may choose a different first adapter. Mitigation: keep analyzer interface provider-neutral and Gemini-compatible adapter replaceable.

## Execution Notes

- Read first:
  - `lab/api/routers/assets.py`
  - `lab/status/schemas.py`
  - `lab/status/service.py`
  - `lab/status/db.py`
  - `app/lib/data/models/project_asset.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
  - `lab/agents/reels/audio_extractor.py`
- Implement backend data contract before provider calls.
- Implement global asset identity and project attachment semantics before recommendation ranking. A project recommendation must be able to distinguish `attached_project_asset` from `candidate_global_asset`.
- Implement credential resolution and guardrail enforcement before the Gemini-compatible adapter can call any external provider.
- Keep analyzer prompts structured and require JSON output. Normalize and validate every provider response before persistence.
- Use one video per provider request when possible; for long/fast videos prefer representative clips or configurable FPS rather than full unbounded upload. The V1 defaults are 500 MB/1800 seconds max source inspection, 90 seconds sampled provider video, 180 frames, 1 FPS cap, 120 seconds sampled audio, 2 running jobs per project, 4 running jobs per user, 100 images plus 25 videos per user/day on platform credentials, 250 images plus 50 videos per user/day on BYOK, 120s image provider timeout, 600s video provider timeout, and 2 retries.
- Do not add broad social scraping. Imported social clips must already exist as project assets with attribution metadata.
- Do not expose provider model, FPS, clipping or safety controls in the app UI during V1.
- Stop and reroute if implementation needs a full rights-management system, cross-user/team libraries, social download/scraping, Remotion render integration, or unbounded provider analysis.
- Suggested validation commands:
  - `python3 -m pytest lab/tests/test_asset_understanding*.py lab/tests/test_project_assets*.py`
  - `python3 -m py_compile lab/api/services/asset_understanding.py lab/api/services/asset_media_inspection.py`
  - `flutter test test/data/project_asset_test.dart test/providers/project_asset_provider_test.dart test/presentation/project_asset_picker_test.dart`
  - `flutter analyze lib/data/models/project_asset.dart lib/data/services/api_service.dart lib/providers/providers.dart lib/presentation/widgets/project_asset_picker.dart`

## Open Questions

None for the product/data contract. Provider market selection remains a separate exploration for long-term optimization, but V1 implementation is defined as provider-neutral with a Gemini-compatible adapter path, user BYOK plus platform/global credential support, and explicit guardrails for cost, privacy, concurrency and quota.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-13 08:15:03 UTC | sf-spec | GPT-5 Codex | Created draft spec from user decisions about b-rolls, social illustration videos, project asset tags, BYOK preference, and existing Project Asset Library code scan. | Draft saved. | /sf-ready AI Asset Understanding Auto Tagging |
| 2026-05-13 08:52:11 UTC | sf-ready | GPT-5 Codex | Evaluated readiness against user story, security, external-doc freshness, execution clarity and adversarial failure modes. | Not ready: scope across future projects and cost/abuse guardrails need explicit decisions before implementation. | /sf-spec AI Asset Understanding Auto Tagging readiness gaps |
| 2026-05-13 09:07:22 UTC | sf-spec | GPT-5 Codex | Integrated readiness-gap decisions: global plus project libraries, user BYOK plus platform credentials, Gemini-compatible implementation, and concrete V1 cost/privacy guardrails. | Draft updated. | /sf-ready AI Asset Understanding Auto Tagging |
| 2026-05-14 09:20:35 UTC | sf-ready | GPT-5 Codex | Re-evaluated readiness after global-vs-project scope and cost/abuse guardrails were clarified. | Ready: product/data contract, security guardrails, external-doc freshness, tasks and acceptance criteria are implementable. | /sf-start AI Asset Understanding Auto Tagging |
| 2026-05-14 10:02:27 UTC | sf-start | GPT-5 Codex | Implemented first execution slice: provider contract scaffolding, BYOK/platform credential resolution order, typed guardrails and targeted tests; no real provider calls wired yet. | Partial: foundations are in place for secure/mockable understanding jobs before external provider integration. | Continue `/sf-start AI Asset Understanding Auto Tagging` with persistence + job lifecycle + routes |
| 2026-05-14 11:21:53 UTC | sf-start | GPT-5 Codex | Implemented backend persistence and lifecycle slice for asset understanding: idempotent jobs/quota tables, queue-status-retry + minimal recommend routes, and strict provider output normalizer with targeted tests. | Partial: backend tranche shipped and tested; worker execution, richer recommendation semantics, and user tag moderation endpoints remain for next slices. | Continue `/sf-start AI Asset Understanding Auto Tagging` with worker execution + moderation/recommendation hardening |
| 2026-05-14 11:26:58 UTC | sf-start | GPT-5 Codex | Implemented worker execution path (queued->running->completed/failed), retry cap/backoff metadata, concurrency cap gating, tag moderation endpoints (accept/edit/reject + manual tags), preservation of user tag decisions on reanalysis, and recommendation hardening (placements/fit reasons/rights warnings). | Partial: tranche backend livree et testee; `include_global_candidates` est expose mais reste sans effet tant que la couche canonical global library n'est pas branchee dans ce service. | Continue `/sf-start AI Asset Understanding Auto Tagging` vers branchement global candidates + intégration app Flutter tranche dédiée |
| 2026-05-14 11:30:29 UTC | sf-start | GPT-5 Codex | Implemented backend global-library candidate sourcing and explicit attach flow: recommendations now include same-user cross-project candidates only when `include_global_candidates=true`, with `candidate_global_asset` marker and `requires_project_attachment`; added ownership-safe attach endpoint/service to clone a global asset into the target project atomically, plus targeted router/service tests. | Partial: backend global-candidates + attach tranche delivered and validated; Flutter integration and full verification/closeout slices remain. | Continue `/sf-verify AI Asset Understanding Auto Tagging` |
| 2026-05-14 11:35:53 UTC | sf-start | GPT-5 Codex | Implemented Flutter integration slice for asset understanding auto-tagging: added typed Dart models for understanding/job/recommendation candidate fields and warnings, ApiService methods for queue/status/retry/moderate/recommend/attach-global, provider actions/state wiring with stale-project guards, and minimal ProjectAssetPicker UI signals (understanding status, suggested/accepted tags, fit reasons/warnings, global candidate marker + attach CTA). | Partial: app tranche delivered and compile/test validated; chantier still awaits cross-slice verification and lifecycle close/ship skills. | Continue `/sf-verify AI Asset Understanding Auto Tagging` |
| 2026-05-14 11:37:56 UTC | sf-verify | GPT-5 Codex | Verified delivered slices against security/privacy/ownership/quotas/idempotency/global-candidate attach/stale-guard criteria, ran targeted backend+Flutter checks, and reviewed code/test evidence. | Partial: core backend+Flutter contract is validated, but closeout is blocked by remaining spec gaps (missing `asset_media_inspection.py` tranche, docs coherence not completed, and one suggested Flutter widget test path absent). | Continue `/sf-start AI Asset Understanding Auto Tagging` for remaining spec tasks, then rerun `/sf-verify AI Asset Understanding Auto Tagging` |
| 2026-05-14 11:41:44 UTC | sf-start | GPT-5 Codex | Resolved sf-verify blockers: added deterministic `asset_media_inspection.py` service (typed errors, ffprobe/ffmpeg inspection, bounded sampling plan, mockable subprocess runner, temp cleanup), backend tests with subprocess mocks, canonical Flutter widget test path, and README ops/privacy/BYOK/guardrails guidance. | Partial: blocker tranche implemented and targeted validations queued; lifecycle verify/end/ship remains. | Continue `/sf-verify AI Asset Understanding Auto Tagging` |
| 2026-05-14 11:43:38 UTC | sf-verify | GPT-5 Codex | Re-ran strict blocker verification against spec: confirmed `asset_media_inspection.py` exists and compiles, Flutter widget picker test path exists and passes, README ops/privacy/BYOK/guardrails guidance is present; executed targeted backend and Flutter checks requested by scope. | Verified: previous verify blockers are resolved with green evidence (`pytest` 46 passed, `py_compile` ok, targeted `flutter test` passed, targeted `flutter analyze` clean). | Continue `/sf-end AI Asset Understanding Auto Tagging` |
| 2026-05-14 11:44:50 UTC | sf-end | GPT-5 Codex | Closed lifecycle after green final `sf-verify`, aligned chantier tracking state, and recorded tracker/changelog closeout for AI asset understanding/tagging/recommendation scope. | closed | /sf-ship shipglows_data/workflow/specs/SPEC-ai-asset-understanding-auto-tagging-2026-05-13.md |
| 2026-05-14 12:06:00 UTC | sf-ship | GPT-5 Codex | Quick ship scoped to AI asset understanding chantier only: staged chantier files, reused latest green `sf-verify` evidence, committed, and pushed to `origin/main`. | shipped | none |

## Current Chantier Flow

sf-spec: done
sf-ready: ready
sf-start: completed
sf-verify: verified
sf-end: closed
sf-ship: shipped
