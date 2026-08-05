---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "contentglows"
created: "2026-05-13"
created_at: "2026-05-13 03:28:27 UTC"
updated: "2026-05-13"
updated_at: "2026-05-13 03:28:27 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlows authentifiee dans l'editeur video d'un contenu, je veux generer des clips video IA courts et du b-roll guide pour une scene ou un placement, afin d'enrichir mes videos sociales sans quitter le workflow Remotion/editor ni ouvrir un studio libre."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "worker"
  - "contentglows"
  - "Runway API"
  - "Luma Dream Machine API"
  - "Google Veo/Gemini API"
  - "Project Asset Library"
  - "Remotion video editor workflow"
  - "Social Placement Format Registry"
  - "AI Provider Benchmark Cost Quality Telemetry"
  - "AI Generation Quotas/Billing"
  - "Bunny Storage/CDN"
  - "Clerk"
  - "Turso/libSQL"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-social-placement-format-registry-2026-05-13.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/SPEC-ai-provider-benchmark-cost-quality-telemetry-2026-05-12.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "unknown"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-scene-motion-assistant-2026-05-12.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "contentglows/INSPIRATION.md"
    artifact_version: "unknown"
    required_status: "inspiration-only"
  - artifact: "contentglows/GUIDELINES.md"
    artifact_version: "unknown"
    required_status: "inspiration-only"
  - artifact: "Runway API docs"
    artifact_version: "official docs checked 2026-05-13: https://docs.dev.runwayml.com/guides/using-the-api, https://docs.dev.runwayml.com/guides/models/, https://docs.dev.runwayml.com/guides/pricing"
    required_status: "official"
  - artifact: "Luma Dream Machine API docs"
    artifact_version: "official docs checked 2026-05-13: https://docs.lumalabs.ai/docs/api, https://docs.lumalabs.ai/docs/video-generation"
    required_status: "official"
  - artifact: "Google Veo Gemini/Vertex AI docs"
    artifact_version: "official docs checked 2026-05-13: https://ai.google.dev/gemini-api/docs/video, https://cloud.google.com/vertex-ai/generative-ai/docs/video/generate-videos"
    required_status: "official"
supersedes: []
evidence:
  - "User confirmation 2026-05-13: create the remaining spec from contentglows inspiration, identified as AI video provider clips / b-roll generation."
  - "User direction across conversation: keep existing Flutter + FastAPI + Clerk + Turso + Bunny + Remotion stack; contentglows is inspiration only."
  - "User direction across conversation: guide users toward effective social content, not artistic playgrounds."
  - "contentglows/INSPIRATION.md lists Runway, Pika, Synthesia, HeyGen and Luma as AI video inspirations."
  - "contentglows/GUIDELINES.md requires standard generated output formats such as MP4, GIF/MP4 animation, preview when possible, and workflow between tools."
  - "Existing spec evidence: Remotion video editor is content-scoped at /editor/:id/video, guided storyboard, preview gate before final render/publication."
  - "Existing spec evidence: Unified Project Asset Library defines project assets across video, video_cover, render_output, background_config and governed reuse."
  - "Existing spec evidence: Social Placement Format Registry defines vertical_short_video, landscape_video, reel_cover and video_thumbnail placements but explicitly leaves generation of video assets to future workflows."
  - "Code evidence: lab/status/schemas.py already has ProjectAssetMediaKind.VIDEO and ProjectAssetLifecycleStatus; source enum lacks a dedicated AI video generation source."
  - "Code evidence: lab/api/services/project_asset_storage.py marks Bunny-backed video assets render_safe and provider temporary URLs not render_safe."
  - "Code evidence: lab/api/routers/reels.py downloads Instagram reels and uploads video/audio to Bunny, but is not a generation workflow and currently accepts user_id/Bunny credentials in request models."
  - "Code evidence: lab/api/services/image_generation_store.py and flux_image_generation.py provide the closest async provider/store pattern for generated media."
  - "Code evidence: lab/api/services/job_store.py provides a generic Turso-backed job table suitable for job state, but generated video history needs its own durable table."
  - "Fresh docs checked 2026-05-13: Runway API supports image-to-video/text-to-video through async task output, model list includes gen4.5/gen4_turbo/veo variants, and pricing is credit-per-second."
  - "Fresh docs checked 2026-05-13: Luma Dream Machine API supports text-to-video, image-to-video, aspect ratio, loop, keyframes, generation polling, callbacks and Ray 2 model options."
  - "Fresh docs checked 2026-05-13: Google Veo 3.1 via Gemini API supports long-running video generation, 8-second 720p/1080p outputs, native audio, image references and polling; Vertex AI docs add region/person-generation approval considerations."
next_step: "/sf-ready AI video b-roll generation workflow"
---

# Title

AI Video B-roll Generation Workflow

## Status

Draft. This spec defines the missing AI video generation layer inspired by Runway, Pika, Luma, Synthesia and HeyGen, but scoped to ContentGlows's guided editor. V1 generates short b-roll/scene clips as project assets for the existing/future Remotion video editor and social placement registry. It is not a standalone AI video playground, avatar studio, prompt lab, or direct social publishing feature.

## User Story

En tant que creatrice ContentGlows authentifiee dans l'editeur video d'un contenu, je veux generer des clips video IA courts et du b-roll guide pour une scene ou un placement, afin d'enrichir mes videos sociales sans quitter le workflow Remotion/editor ni ouvrir un studio libre.

## Minimal Behavior Contract

From an owned content/video scene or a known social placement, ContentGlows lets an authenticated creator request a short AI-generated video clip using a guided preset such as b-roll, scene background, product/action cutaway, hook visual, transition clip or loopable ambiance. The backend validates project/content/video ownership, allowed placement, prompt policy, provider availability, quota/cost gate, reference assets and output format, then creates an async generation job. On success it downloads the provider result, stores it durably on Bunny, registers a `video` project asset, links it to the content/scene/placement as a candidate or primary asset, and exposes it to Remotion preview/render flows. If provider generation, moderation, quota, storage, ownership, reference validation or asset registration fails, the job ends in a recoverable failed state without using a provider-temporary URL as durable output. The easy edge case to miss is letting video generation become an unconstrained text-to-video toy: V1 accepts guided scene/placement intents and approved references, not arbitrary public URLs, avatar likeness promises, direct provider playground controls or final publishing bypasses.

## Success Behavior

- Given a creator is authenticated and owns a project/content item, when they open `/editor/:id/video` and select a scene or empty `vertical_short_video`/`landscape_video` placement, then the UI can show guided AI video generation actions.
- Given a scene has text, visual notes, format preset and optional project visual references, when the creator starts a b-roll generation, then the backend creates a `video_generation` record and a pollable job with project id, user id, content id, optional video project/version/scene id, placement id, provider, model, prompt hash, duration, aspect ratio and status `queued`.
- Given the selected provider is configured and quota policy allows the action, when the job runs, then the backend submits either text-to-video or image-to-video using only backend-approved prompt/reference inputs.
- Given an image reference is used for image-to-video, when the provider request is built, then the reference must be an active same-project asset or visual reference with a backend-resolved durable URL.
- Given generation succeeds, when the provider returns an output URL or file object, then ContentGlows downloads it server-side, verifies it is a supported video MIME/container, uploads it to Bunny, marks the generation `completed`, and stores only the durable Bunny URI as the project asset storage URI.
- Given Bunny upload and project asset registration succeed, when the editor refreshes, then the generated clip appears as a `ProjectAsset` with media kind `video`, source `ai_video_generation`, metadata for provider/model/duration/aspect ratio/placement/generation id, and safe preview/playback descriptors.
- Given the clip was generated for a scene, when the user applies it, then the video project version references the project asset id and invalidates stale Remotion previews.
- Given the clip was generated for a social placement, when publish preflight later runs, then the social placement registry can validate the asset against `vertical_short_video`, `landscape_video` or `reel_cover` rules.
- Given the provider reports cost or credits, when the generation completes or fails after submission, then normalized telemetry is emitted for benchmark/cost quality tracking without becoming the billing authority.
- Given a provider rejects moderation or safety policy, when the job finishes, then the UI receives a sanitized failure reason and can offer prompt adjustment or a non-AI fallback.
- Given a provider is disabled or not configured, when the user opens generation actions, then the UI shows the action as unavailable or routes to deterministic Remotion/image motion alternatives instead of presenting a broken flow.

## Error Behavior

- Missing or expired Clerk auth returns `401`; no provider call, job, asset, prompt or reference metadata is created.
- A foreign project, content record, video project, scene, placement, reference asset or generated asset returns ownership-safe `403`/`404` without leaking titles, prompts, storage paths, provider ids or signed URLs.
- Unsupported generation intents, placement ids, durations, aspect ratios, model ids, media types or provider names return `400`/`422` before any provider call.
- If the quota/billing preflight blocks the request, the backend records no provider job and returns a structured quota error.
- If provider credentials are missing, disabled, rate-limited, out of credits or region-gated, the job is not submitted or is marked `provider_unavailable` with a recoverable user/operator message.
- If a prompt or reference triggers provider safety/moderation rejection, the generation is marked failed with a sanitized `provider_safety_rejected` code and no asset is registered.
- If the provider response is malformed, lacks an output URL/file, returns a non-video MIME, returns an unsupported duration/container, or exceeds maximum download size, the generation is marked failed and the temporary output is discarded.
- If the provider succeeds but Bunny upload fails, the generation records `durable_output=false`, emits cost telemetry if applicable, and does not expose the provider URL as a reusable asset.
- If the project asset registration fails after Bunny upload, the generation is marked `asset_registration_failed`, stores repair metadata for ops, and the UI must not present the clip as selectable until repaired.
- If the user changes scene/version while a job runs, the completed asset remains a project asset candidate but is not silently attached to the newer scene/version.
- If two jobs target the same scene/placement, each stays a candidate until one is explicitly selected or set primary.
- What must never happen: provider secrets, polling URLs, signed Bunny URLs, raw private prompts, raw user reference URLs, local file paths, foreign assets, human likeness training claims, or provider temporary URLs reach Flutter logs, publish payloads or Remotion props as trusted data.

## Problem

ContentGlows now has specs for images via Flux, the Remotion video editor, audio/music/backgrounds, motion presets, text-based media editing, social placements and provider telemetry. The remaining AI video inspiration from contentglows is the frontier-provider layer: Runway/Pika/Luma/Synthesia/HeyGen-style generated clips. If copied naively, it would create an expensive and risky prompt playground detached from the current product. What ContentGlows actually needs is narrower: generate short clips that help social videos perform, attach them to scenes/placements as governed project assets, and let Remotion compose the final video.

The existing codebase also has partial video concepts: Instagram reel import uploads video/audio to Bunny, project assets already support `video`, storage descriptors distinguish Bunny from provider-temporary URLs, and Flux image generation already shows a durable async provider/store pattern. But there is no AI video provider adapter, no generated video history store, no Bunny registration path for provider video outputs, no editor-linked b-roll action, and no contract tying generated clips to Remotion scenes or social placements.

## Solution

Create a backend-owned AI video generation subsystem with a provider adapter contract, a durable generation store, async job orchestration, Bunny upload, project asset registration, and Flutter/editor actions. V1 enables guided b-roll/clip generation with Runway as the first production adapter because current official docs expose model support, async tasks, text/image-to-video, pricing and task lifecycle. Luma and Google Veo are documented as future-compatible adapters in the provider registry, not V1 production defaults. Generated clips become normal project assets and are consumed by Remotion and social placement workflows through existing asset selection rules.

## Scope In

- Guided AI video generation from a content/video scene, storyboard slot, or social placement.
- V1 generation intents:
  - `scene_broll`
  - `hook_visual`
  - `background_loop`
  - `transition_clip`
  - `product_cutaway`
  - `concept_illustration`
  - `placement_video_candidate`
- V1 output surfaces:
  - Remotion scene visual layer candidate.
  - Remotion background/video layer candidate.
  - Social placement candidates for `vertical_short_video`, `landscape_video`, `reel_cover` when compatible.
  - Project asset library item with history, usage, tombstone and safe descriptors.
- V1 provider adapter: Runway API via server-side Python service, using configured model allowlist and async task polling.
- Provider registry entries for future Luma and Google Veo adapters, disabled until explicitly implemented and verified.
- Text-to-video and image-to-video request modes.
- Backend prompt builder that turns scene/content metadata into a provider prompt and keeps raw provider controls hidden from Flutter.
- Reference asset validation using same-project active project assets, Flux images, thumbnails, video covers or approved visual references.
- Async job state through the existing `job_store` plus a durable `VideoGeneration` table for generation history.
- Bunny upload of successful MP4 or provider-supported video outputs before any asset is exposed.
- Registration of generated output as `ProjectAssetMediaKind.VIDEO` with new source `ai_video_generation`.
- Usage linking to content/placement and, once video project target validation exists, video scene/version targets.
- Provider telemetry emission compatible with `SPEC-ai-provider-benchmark-cost-quality-telemetry-2026-05-12.md`.
- Quota/cost preflight hook compatible with `SPEC-ai-generation-quotas-billing-2026-05-11.md`.
- Flutter models, API calls, provider state and editor UI hooks for guided generation, polling, preview and attach/apply.
- Tests for auth, ownership, provider errors, quota block, reference validation, Bunny durability, asset registration, stale scene/version handling and diagnostics redaction.

## Scope Out

- Standalone AI video playground, public prompt lab, global studio route, or arbitrary model picker.
- Direct port of any contentglows prototype stack, Next.js route, Supabase, Vercel Blob, Vercel OAuth or client-side provider call.
- Full text-to-movie, multi-scene AI video planning, automatic final video generation, automatic edit assembly or one-click publish.
- Avatar/presenter generation, likeness cloning, talking-head workflows, Synthesia/HeyGen production integration or consent workflows. These require a separate avatar/likeness spec.
- Video-to-video editing, inpainting, upscale, extend/interpolate, camera-control expert mode, or professional VFX controls.
- Audio generation inside video provider outputs. If a provider returns native audio, V1 stores it as part of the clip but does not replace the AI audio/music spec.
- User-provided arbitrary public URL references.
- Training/fine-tuning/LoRA/identity models for video.
- Publishing generated clips directly to TikTok/Instagram/YouTube without Remotion/social placement validation.
- Automatic crop/reframe/transcode pipeline beyond basic validation and Bunny storage.
- Implementing Luma, Veo, Pika, Synthesia or HeyGen as production adapters in V1.
- Public claims that generated clips guarantee character consistency, legal safety, or platform acceptance.

## Constraints

- `lab` owns provider calls, prompt construction, auth, ownership, quota checks, storage, persistence and asset registration.
- `app` calls FastAPI only; it never calls Runway/Luma/Veo or stores provider secrets.
- The feature is online-only and asynchronous.
- Generated video outputs are durable only after Bunny upload and project asset registration.
- Provider-temporary URLs are never returned as reusable asset authority.
- V1 generated clips must be short and bounded: default 5 seconds, allowed 3-10 seconds unless the provider/model registry explicitly supports another range and cost policy accepts it.
- V1 formats are bounded to `vertical_9_16`, `landscape_16_9` and optionally `square_1_1` only if the social placement registry explicitly supports it; the product focus remains vertical first.
- V1 uses model/provider allowlists from backend config. Flutter cannot submit arbitrary model ids or advanced provider params.
- Reference images/videos must be backend-approved project assets with render-safe storage descriptors.
- Human likeness, real person avatar, child/person generation, celebrity/IP prompts and trademark-sensitive prompts must route through conservative validation and provider moderation. V1 should avoid avatar/likeness features entirely.
- Generated clip selection must remain candidate-first; replacing a scene/placement primary asset requires explicit user action or a deterministic server-side rule named in the request.
- If the base Remotion video project implementation is not yet available, V1 can register generated clips as content-level project asset candidates but cannot attach to `target_type=video_version`.
- No hard-coded public pricing claims in app copy; pricing/cost evidence belongs to quota/billing and provider telemetry specs.

## Dependencies

- Existing specs:
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-social-placement-format-registry-2026-05-13.md`
  - `shipglows_data/workflow/specs/SPEC-ai-provider-benchmark-cost-quality-telemetry-2026-05-12.md`
  - `shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md`
  - `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-scene-motion-assistant-2026-05-12.md`
- Existing backend patterns:
  - `lab/api/services/job_store.py`
  - `lab/api/services/image_generation_store.py`
  - `lab/api/services/flux_image_generation.py`
  - `lab/api/routers/images.py`
  - `lab/api/services/project_asset_storage.py`
  - `lab/status/schemas.py`
  - `lab/status/service.py`
  - `lab/api/routers/assets.py`
  - `lab/api/dependencies/auth.py`
  - `lab/api/dependencies/ownership.py`
- Existing app patterns:
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/data/models/project_asset.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - Future `/editor/:id/video` files from the Remotion video editor spec.
- External docs:
  - `fresh-docs checked`: Runway API getting started and model docs confirm server-side API usage, image-to-video/text-to-video examples, async task output, data URI/URL input modes, model allowlist and pricing by credits/second: `https://docs.dev.runwayml.com/guides/using-the-api`, `https://docs.dev.runwayml.com/guides/models/`, `https://docs.dev.runwayml.com/guides/pricing`.
  - `fresh-docs checked`: Luma Dream Machine API confirms direct Bearer API, text-to-video/image-to-video, Ray model ids, aspect ratio, loop, keyframes, generation polling, callbacks and generated asset URLs: `https://docs.lumalabs.ai/docs/api`, `https://docs.lumalabs.ai/docs/video-generation`.
  - `fresh-docs checked`: Google Veo docs confirm Gemini API long-running video generation, polling/download, 8-second 720p/1080p Veo 3.1 outputs, native audio and image reference support; Vertex AI docs add location/data-at-rest and person/child generation approval constraints: `https://ai.google.dev/gemini-api/docs/video`, `https://cloud.google.com/vertex-ai/generative-ai/docs/video/generate-videos`.
  - `fresh-docs gap`: Pika first-party production API docs were not confirmed in this run; Pika remains inspiration/out of V1.

## Invariants

- Every generated video belongs to one user and one project.
- A generated video is reusable only after Bunny storage and project asset registration succeed.
- Provider output URLs are temporary evidence, not durable app state.
- A generation job can complete without being attached to a scene; it remains a candidate project asset.
- A generated clip must never overwrite a scene asset automatically unless the request explicitly asks for `set_primary=true` and the backend validates the target.
- Scene/version attachment must use backend asset ids, not URLs.
- Provider telemetry and quota records must be linked by generation id/job id without storing provider secrets.
- Prompt hashes can be stored for dedupe/debug; raw prompts require careful retention and should be hidden from normal user logs.
- New provider sources must be added through backend allowlists and tests.
- Failed generations remain inspectable to the owner/operator with sanitized errors, but do not create selectable assets.
- Assets from generated video follow the same tombstone/history rules as the project asset library.

## Links & Consequences

- `lab/status/schemas.py`: add `ProjectAssetSource.AI_VIDEO_GENERATION` or equivalent stable source id.
- `lab/status/service.py`: generated video assets must pass existing project asset invariants and support `publish_media`/scene selection eligibility when durable.
- `lab/api/services/project_asset_storage.py`: Bunny-backed video descriptors are already render-safe; provider temporary video URLs remain unsafe.
- `lab/api/services/job_store.py`: can store job status, but not the durable generation history or full provider payload.
- `lab/api/routers/reels.py`: remains import/repurpose only; do not mix Instagram cookie/download behavior with AI video generation.
- `lab/api/main.py` and `api/routers/__init__.py`: need a new router registration.
- `app` editor/video surfaces gain a guided generate action, job polling and candidate attach flow.
- Remotion worker receives generated clips only through backend-validated asset descriptors from the video project model.
- Social placement preflight can later validate these assets for short/landscape placements.
- Cost/telemetry systems receive generation duration, provider/model, estimated/actual credits and success/failure signals.

## Documentation Coherence

- Update `lab/README.md` with AI video provider env vars, generation routes, durable Bunny rule, provider-temporary URL prohibition and project asset registration behavior.
- Update project asset docs to include `ai_video_generation` source and clip metadata fields.
- Update Remotion editor docs/spec notes so generated clips are treated as candidate scene assets, not final renders.
- Update social placement docs to name this workflow as the generator for `vertical_short_video` and `landscape_video` candidates.
- Add app copy/localization for guided video generation states: unavailable provider, queued, generating, uploading, ready as candidate, failed moderation, quota blocked, storage failed, attach to scene, set as placement candidate.
- Do not update public marketing/site copy until the feature is implemented and verified; avoid claiming full AI video creation before real end-to-end output exists.

## Edge Cases

- The provider returns a clip with audio. V1 may store it inside the video file, but the editor must not treat it as the authoritative narration/music track unless the audio spec explicitly consumes it.
- The provider returns a 16:9 output for a vertical request or vice versa. Backend marks the asset as incompatible for the requested placement unless a future transcode/reframe flow handles it.
- The selected reference image is tombstoned while the job is queued. Worker revalidates before provider submission and fails before spending provider credits.
- A generation finishes after the user deleted or changed the scene. The asset remains a project candidate but is not attached automatically.
- The same generated clip is useful for multiple scenes. Usage rows must record each scene/placement separately.
- Provider credits are consumed but provider result cannot be downloaded. Cost telemetry records spend evidence, generation fails, no asset is created.
- Runway changes model pricing or duration support. Provider registry and cost catalog must refresh; hard-coded UI labels cannot be the final source of truth.
- Luma/Veo adapters are added later with different callback/polling/region constraints. The provider interface must normalize status, output, cost and safety errors.
- User asks for an avatar, clone, public figure or real person. V1 blocks or reroutes; it does not silently pass likeness prompts to video providers.
- Large outputs exceed download/upload cap. The job fails with `output_too_large` and offers a shorter/lower preset if configured.

## Implementation Tasks

- [ ] Task 1: Add backend AI video models
  - File: `lab/api/models/ai_video.py`
  - Action: Define request/response models for guided video generation, generation records, job status, provider/model registry, placement/scene context, reference asset inputs, failure details and list responses.
  - User story link: Establishes the app/backend contract for guided b-roll generation.
  - Depends on: Existing project asset and image generation model patterns.
  - Validate with: Pydantic model tests in `lab/tests/test_ai_video_models.py`.
  - Notes: Include only guided fields: intent, format preset, duration, prompt instruction, content id, optional video project/version/scene id, placement id, reference asset ids, set_primary flag.

- [ ] Task 2: Add durable video generation store
  - File: `lab/api/services/video_generation_store.py`
  - Action: Create `VideoGeneration` table/store with create, mark running, mark completed, mark failed, list and get methods.
  - User story link: Lets users see async generation history and recover failed jobs.
  - Depends on: Task 1.
  - Validate with: `lab/tests/test_video_generation_store.py`.
  - Notes: Mirror the `ImageGenerationStore` pattern but store video-specific fields: duration_seconds, aspect_ratio, placement, scene ids, cdn_url, asset_id, provider_task_id, provider_cost, provider_metadata_json.

- [ ] Task 3: Ensure video generation tables on startup
  - File: `lab/api/main.py`
  - Action: Ensure `video_generation_store.ensure_tables()` runs idempotently when Turso is configured.
  - User story link: Keeps async history durable across deploys.
  - Depends on: Task 2.
  - Validate with: Startup smoke test or targeted unit test matching image generation startup behavior.
  - Notes: Follow existing non-critical migration logging style for ImageGeneration.

- [ ] Task 4: Add AI video provider source enum
  - File: `lab/status/schemas.py`
  - Action: Add `AI_VIDEO_GENERATION = "ai_video_generation"` to `ProjectAssetSource`.
  - User story link: Makes generated video clips first-class project assets.
  - Depends on: Task 2.
  - Validate with: `lab/tests/test_project_assets_service.py` plus new generated-video asset test.
  - Notes: Source id must be stable; do not overload `remotion_render` or `reels_import`.

- [ ] Task 5: Implement provider registry and prompt policy
  - File: `lab/api/services/ai_video_provider_registry.py`
  - Action: Define allowed providers/models, V1 Runway defaults, disabled Luma/Veo future entries, duration/aspect ratio support, cost estimate metadata, intent allowlist and prompt safety policy.
  - User story link: Prevents free provider playground controls.
  - Depends on: Task 1.
  - Validate with: Unit tests for invalid model/provider/duration/aspect/intent rejection.
  - Notes: V1 default provider is Runway when `RUNWAYML_API_SECRET` is configured. Luma/Veo entries are explicit future compatibility, not production routes.

- [ ] Task 6: Implement Runway video provider client
  - File: `lab/api/services/runway_video_generation.py`
  - Action: Add server-side Runway client for text-to-video/image-to-video submission, polling, timeout, cancellation-safe errors, output download and sanitized metadata.
  - User story link: Produces the actual generated clip.
  - Depends on: Tasks 1, 5.
  - Validate with: `lab/tests/test_runway_video_generation.py` using mocked HTTP/SDK responses for success, timeout, failed task, moderation, missing output, non-video MIME and oversized download.
  - Notes: Use official API version header/config, strict timeouts, max download bytes and SSRF-safe public URL validation similar to Flux.

- [ ] Task 7: Add video output Bunny upload helper
  - File: `lab/api/services/ai_video_storage.py`
  - Action: Upload provider output file to Bunny using existing storage/CDN patterns or a small video-specific helper, return durable storage URI and metadata.
  - User story link: Makes provider results durable and reusable.
  - Depends on: Task 6.
  - Validate with: Storage helper tests and a mocked Bunny upload integration test.
  - Notes: Do not return provider temporary URLs as success. If existing Bunny upload code is image-specific, add a video-safe helper rather than mutating image-only assumptions.

- [ ] Task 8: Register generated clip as project asset
  - File: `lab/api/routers/ai_video.py`
  - Action: Add helper to create `ProjectAssetMediaKind.VIDEO` asset with source `ai_video_generation`, storage URI, MIME, duration/aspect metadata, generation id and provider metadata.
  - User story link: Makes generated clips available in project asset library and Remotion.
  - Depends on: Tasks 2, 4, 7.
  - Validate with: Router/job tests asserting completed generation has asset id and asset detail uses safe descriptor.
  - Notes: Record usage links only after asset creation succeeds.

- [ ] Task 9: Add AI video router
  - File: `lab/api/routers/ai_video.py`
  - Action: Expose authenticated endpoints to create generation job, get job/generation status, list generation history and optionally cancel queued/running jobs if provider supports cancellation.
  - User story link: Lets Flutter start/poll generation from editor flows.
  - Depends on: Tasks 1-8.
  - Validate with: `lab/tests/test_ai_video_router.py`.
  - Notes: Endpoints should be project/content scoped and must use existing ownership helpers; never accept user-supplied Bunny/provider credentials.

- [ ] Task 10: Register router
  - File: `lab/api/routers/__init__.py`
  - Action: Export `ai_video_router`.
  - User story link: Makes API reachable.
  - Depends on: Task 9.
  - Validate with: Import/smoke test.
  - Notes: Keep naming distinct from `reels_router`.

- [ ] Task 11: Include router in FastAPI app
  - File: `lab/api/main.py`
  - Action: Include `ai_video_router`.
  - User story link: Makes generation endpoints available to the app.
  - Depends on: Task 10.
  - Validate with: FastAPI route listing or test client endpoint existence.
  - Notes: Place near images/reels/video-related routers for readability.

- [ ] Task 12: Add quota and telemetry hooks
  - File: `lab/api/routers/ai_video.py`
  - Action: Call quota/cost preflight before provider submission where the quota service is available, and emit provider telemetry after submission/completion/failure.
  - User story link: Protects PAYG and operator cost visibility.
  - Depends on: Tasks 5-9 plus quota/benchmark specs.
  - Validate with: Tests proving provider client is not called on quota block and telemetry receives normalized events.
  - Notes: If quota/telemetry implementation is not ready, preserve typed hook points and fail closed for managed paid video generation unless the operator explicitly enables a dev mode.

- [ ] Task 13: Add Flutter AI video models
  - File: `app/lib/data/models/ai_video_generation.dart`
  - Action: Add Dart models for generation request, response, status, provider availability, failure details and generated asset metadata.
  - User story link: Lets the editor display jobs and generated candidates.
  - Depends on: Backend model contract.
  - Validate with: `app/test/data/ai_video_generation_test.dart`.
  - Notes: Be tolerant of unknown future provider fields.

- [ ] Task 14: Add Flutter API methods
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add methods to create AI video generation, poll status, list history and attach/set primary generated asset if the backend exposes those flows.
  - User story link: Connects UI to backend generation.
  - Depends on: Task 13.
  - Validate with: API service tests or provider tests using mock service.
  - Notes: Resolve local id mappings like existing project asset methods.

- [ ] Task 15: Add AI video provider state
  - File: `app/lib/providers/providers.dart`
  - Action: Add a notifier for AI video generation state scoped to active project/content/video context, with stale-response protection.
  - User story link: Supports async progress in the editor.
  - Depends on: Task 14.
  - Validate with: Provider tests for queue/running/completed/failed, project switch and stale scene/version.
  - Notes: Reuse the revision pattern from `ProjectAssetLibraryNotifier`.

- [ ] Task 16: Add editor generation UI hook
  - File: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add guided entry points for eligible content before the full video editor exists, or link to `/editor/:id/video` when available.
  - User story link: Keeps generation in the existing editor workflow.
  - Depends on: Tasks 13-15 and route availability.
  - Validate with: Editor widget tests for available/unavailable provider, job status and generated candidate display.
  - Notes: Do not create a landing page or global playground.

- [ ] Task 17: Add video editor scene/placement integration
  - File: `app/lib/presentation/screens/editor/video_editor_screen.dart`
  - Action: Add scene-level "generate b-roll" actions, show job progress, preview generated clip, and attach generated project asset to current scene/placement.
  - User story link: Makes generated clips useful in Remotion scene composition.
  - Depends on: Remotion video editor implementation and Tasks 13-15.
  - Validate with: Video editor widget tests once the screen exists.
  - Notes: If the video editor file path differs when implemented, update this task path during `/sf-ready` or `/sf-start`.

- [ ] Task 18: Update project asset picker filters
  - File: `app/lib/presentation/widgets/project_asset_picker.dart`
  - Action: Ensure generated video assets can be filtered/selected for video placements and scene targets.
  - User story link: Lets users reuse generated clips instead of regenerating.
  - Depends on: Task 8 and existing asset library.
  - Validate with: Project asset picker widget tests for `media_kind=video`, `source=ai_video_generation` and placement compatibility.
  - Notes: Keep tombstoned/local/degraded behavior unchanged.

- [ ] Task 19: Add backend tests
  - File: `lab/tests/test_ai_video_router.py`
  - Action: Cover auth, ownership, create job, provider unavailable, quota blocked, invalid reference, success with Bunny/project asset, provider failure, stale target, and redaction.
  - User story link: Proves backend behavior end to end without real provider calls.
  - Depends on: Tasks 1-12.
  - Validate with: `python -m pytest lab/tests/test_ai_video_models.py lab/tests/test_video_generation_store.py lab/tests/test_runway_video_generation.py lab/tests/test_ai_video_router.py`.
  - Notes: Use mocked provider and Bunny upload.

- [ ] Task 20: Add Flutter tests
  - File: `app/test/data/ai_video_generation_test.dart`
  - Action: Add model/provider/widget tests for generation payloads, job status and editor UI states.
  - User story link: Protects guided app behavior.
  - Depends on: Tasks 13-18.
  - Validate with: `flutter test app/test/data/ai_video_generation_test.dart app/test/presentation/screens/editor/editor_screen_test.dart`.
  - Notes: Add video editor-specific widget tests once that screen exists.

- [ ] Task 21: Update docs
  - File: `lab/README.md`
  - Action: Document AI video generation routes, Runway env vars, provider registry, Bunny durability, project asset source, quota/telemetry hooks and security constraints.
  - User story link: Keeps future implementation and ops aligned.
  - Depends on: Tasks 1-12.
  - Validate with: Manual documentation review.
  - Notes: Avoid public marketing claims.

## Acceptance Criteria

- [ ] CA 1: Given an authenticated user owns a content item, when they request `scene_broll` generation for a valid scene/placement, then the backend creates a queued generation and returns a pollable status.
- [ ] CA 2: Given a request references a foreign project asset, when generation is requested, then the backend rejects before provider call and leaks no asset metadata.
- [ ] CA 3: Given Runway is not configured, when generation is requested, then the backend returns a typed provider unavailable error and no job is submitted.
- [ ] CA 4: Given quota preflight blocks managed video generation, when generation is requested, then the provider client is not called.
- [ ] CA 5: Given a valid image-to-video request uses an active same-project image asset, when the job runs, then the provider payload uses only backend-resolved durable reference data.
- [ ] CA 6: Given the provider returns a successful MP4 result, when Bunny upload succeeds, then a completed generation record and `video` project asset with source `ai_video_generation` are created.
- [ ] CA 7: Given the provider returns a temporary URL, when job completes, then Flutter receives only a durable Bunny/project asset descriptor after upload, not the temporary URL.
- [ ] CA 8: Given Bunny upload fails after provider success, when the job completes, then no selectable project asset is created and the generation shows a recoverable storage failure.
- [ ] CA 9: Given the generated clip was targeted to a stale scene/version, when the job completes, then it remains a candidate asset and is not silently attached to the newer version.
- [ ] CA 10: Given a completed generated clip is applied to a scene, when the video project is saved, then stale Remotion previews are invalidated.
- [ ] CA 11: Given a generated clip is selected for `vertical_short_video`, when social publish preflight runs, then the asset is validated as a video placement candidate through the social placement registry.
- [ ] CA 12: Given provider safety rejection, when the job fails, then the UI shows a sanitized failure and can offer prompt adjustment without exposing provider internals.
- [ ] CA 13: Given telemetry hooks are active, when a provider job succeeds or fails after submission, then cost/latency/status metadata is recorded without secrets.
- [ ] CA 14: Given the user tombstones a generated video asset, when the editor opens, then the clip is hidden from default picker results and cannot be reused for new scenes/placements.
- [ ] CA 15: Given Flutter changes active project/content while polling, when the old job finishes, then stale responses do not mutate the new context.

## Test Strategy

- Backend unit tests:
  - Provider registry rejects invalid provider/model/duration/aspect/intent.
  - Prompt/reference validator rejects foreign, tombstoned, local-only and provider-temporary assets.
  - Runway client normalizes success, timeout, failed task, safety rejection, malformed response, non-video MIME and oversized output.
  - Video generation store handles create/running/completed/failed/list/get.
- Backend integration tests:
  - Router checks Clerk auth and project/content ownership.
  - Quota block prevents provider submission.
  - Provider success creates Bunny durable output, generation history and project asset.
  - Provider success plus Bunny failure creates no selectable asset.
  - Stale target handling keeps candidate un-attached.
- Flutter tests:
  - Models parse queued/running/completed/failed status.
  - Provider state ignores stale project/content responses.
  - Editor shows provider unavailable, quota blocked, generating, ready candidate and failed states.
  - Project asset picker can show generated video assets by media kind/source.
- Manual QA:
  - Generate a 5s vertical b-roll clip from a text-only short scene.
  - Generate a clip from a Flux-created image reference.
  - Attach generated clip to a Remotion scene and confirm preview invalidation.
  - Try unsupported avatar/likeness prompt and confirm safe rejection.

## Risks

- AI video is expensive and slow. Mitigation: quota/cost preflight, short bounded durations, async jobs, provider telemetry, and no hidden auto-generation.
- Provider APIs and pricing change quickly. Mitigation: backend provider registry, official docs freshness checks, versioned cost catalog and no hard-coded public price promises.
- Generated clips may be off-brand or inconsistent. Mitigation: prefer image-to-video from approved project references, candidate-first attachment, and no guarantee of identity consistency.
- Likeness/legal safety risk is higher for video. Mitigation: V1 excludes avatar/likeness workflows and blocks/reroutes risky prompts.
- Provider temporary URLs can leak private data or expire. Mitigation: server-side download, Bunny upload, redacted metadata, no temporary URL as asset authority.
- Long-running jobs create stale editor state. Mitigation: version/scene context checks and candidate-only completion when context changes.
- Remotion/video editor may not be implemented when this spec starts. Mitigation: allow content-level candidate assets first, but defer scene attachment until video project target validation exists.

## Execution Notes

- Read first:
  - `lab/api/services/image_generation_store.py`
  - `lab/api/services/flux_image_generation.py`
  - `lab/api/routers/images.py`
  - `lab/api/services/project_asset_storage.py`
  - `lab/status/service.py`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
- Implementation order:
  - Models/store/provider registry.
  - Runway provider client with mocked tests.
  - Router/job orchestration and Bunny/project asset registration.
  - Quota/telemetry hooks.
  - Flutter models/API/provider.
  - Editor/video editor UI hooks.
  - Docs.
- Provider choice:
  - V1 production adapter is Runway because official docs currently cover direct API usage, async tasks, text/image-to-video, model list and pricing.
  - Luma and Google Veo are documented future adapters because their official docs confirm compatible async video generation patterns, but implementation stays out of V1 to limit provider surface.
  - Pika remains inspiration only until first-party production docs are confirmed.
- Stop conditions:
  - If no safe server-side Bunny upload path exists for video, stop before exposing provider outputs.
  - If quota/billing enforcement is not ready and operator-paid video generation would run in production, block production enablement or require explicit dev-only flag.
  - If the app requires avatar/presenter generation, create a separate likeness/avatar consent spec before implementation.
  - If Remotion scene target validation is unavailable, implement content-level project asset candidate generation only.

## Open Questions

None blocking for the draft. Assumption locked for V1: generated AI video clips are short, guided, candidate-first assets for Remotion/social placements; Runway is the first production adapter; Luma/Veo are future adapter candidates; avatar/likeness workflows are out of scope.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-13 03:28:27 UTC | sf-spec | GPT-5 Codex | Created AI video b-roll generation workflow spec from contentglows AI video inspirations, existing Remotion/asset/social specs, local code scan and fresh provider docs. | Draft spec saved. | /sf-ready AI video b-roll generation workflow |

## Current Chantier Flow

- sf-spec: done for this draft.
- sf-ready: not launched.
- sf-start: not launched.
- sf-verify: not launched.
- sf-end: not launched.
- sf-ship: not launched.
- Next command: `/sf-ready AI video b-roll generation workflow`.
