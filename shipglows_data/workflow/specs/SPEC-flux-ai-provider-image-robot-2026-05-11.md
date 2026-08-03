---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.1"
project: "contentglowz"
created: "2026-05-11"
created_at: "2026-05-11 13:15:23 UTC"
updated: "2026-05-24"
updated_at: "2026-05-24 00:00:00 UTC"
status: reviewed
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice connectee a un projet ContentGlowz, je veux generer des images IA coherentes avec les formats, personnages et caracteristiques de mon projet, afin d'alimenter mes articles, thumbnails et posts sans sortir du workflow existant."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "contentglowz/v0-flux-2-playground"
  - "api/images"
  - "agents/images"
  - "Bunny CDN"
  - "Clerk"
  - "Turso/libSQL"
depends_on:
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
  - artifact: "contentglowz/INSPIRATION.md"
    artifact_version: "unknown"
    required_status: "unknown"
  - artifact: "contentglowz/GUIDELINES.md"
    artifact_version: "unknown"
    required_status: "unknown"
supersedes: []
evidence:
  - "User decision 2026-05-11: keep existing Flutter + FastAPI + Clerk + Turso/Bunny stack; use contentglowz as inspiration, not as a stack migration."
  - "User decision 2026-05-11: choose spec 1, Provider Flux pour Image Robot."
  - "User decision 2026-05-11: no free playground and no anonymous generation for now."
  - "User decision 2026-05-11: image AI should serve blog images, thumbnails, and post visuals inside existing guided workflows; video images may come later."
  - "Audit evidence: lab already exposes Image Robot endpoints in api/routers/images.py and agents/images with Robolly/OpenAI/Bunny patterns."
  - "Audit evidence: contentglowz/v0-flux-2-playground uses FLUX.2 Pro prompt, aspect ratio, reference images, generated history, and image reuse concepts, but depends on Next/Supabase/Vercel Blob/Vercel OAuth."
  - "External docs checked 2026-05-11: Black Forest Labs FLUX.2 Pro API supports generation/editing task submission, input_image through input_image_8, width/height, seed, safety_tolerance and output_format."
  - "User decision 2026-05-11: validate stable flux-2-pro default, guided visual memory if aligned with Flux multi-reference docs, async content-queue execution, no V1 quotas, UI spec later, and product promise 'coherence visuelle guidee'."
next_step: "none"
---

# Title

Flux AI Provider For Image Robot

## Status

Closed after verification. This spec defines the backend foundation for AI-generated project images inside the existing ContentGlowz Image Robot. It intentionally avoids adding a free-form playground, Supabase, Vercel Blob, Vercel OAuth, or anonymous generation.

## User Story

En tant que creatrice connectee a un projet ContentGlowz, je veux generer des images IA coherentes avec les formats, personnages et caracteristiques de mon projet, afin d'alimenter mes articles, thumbnails et posts sans sortir du workflow existant.

## Minimal Behavior Contract

When an authenticated user or ContentGlowz automation schedules an image for a project using an Image Robot profile whose provider is `flux`, the backend validates project ownership, resolves the profile's guided format and project visual references, builds a structured prompt, optionally attaches up to eight approved project reference images as supported by Flux multi-reference generation/editing, enqueues an image generation job, and returns a durable job/generation record. The worker submits the request to Flux, uploads successful output to Bunny CDN, stores generation metadata, and makes the durable asset available to existing content publication workflows. If Flux is not configured, the provider rejects the job with a clear non-secret error and does not fall back silently to template generation. The easy edge case to miss is treating reference images as a playground upload instead of controlled project visual references, which would break consistency, privacy, and product guidance.

## Success Behavior

- Given an authenticated user owns a project or an authorized ContentGlowz automation is acting for that project, when generation is requested from a `flux` image profile for blog hero, OG card, thumbnail, or social visual, then the API creates a queued generation record with profile, provider, model, dimensions, seed if present, reference image IDs, and status metadata.
- Given a queued Flux generation succeeds, when the worker completes, then the generation record contains a Bunny CDN image URL, responsive/optimizer URLs where available, timing metadata, and status `completed`.
- Given a project has visual memory references, when the user generates an image with consistency enabled, then the backend passes only approved project reference images to Flux and records which references were used.
- Given the profile defines a target format, when generation runs, then the backend maps the format to explicit dimensions rather than exposing arbitrary free-form size controls.
- Given generation succeeds but CDN upload fails, then the API reports failure for the stored asset and does not return a transient provider URL as if it were durable.
- Given Flux credentials are missing, invalid, rate-limited, or the provider rejects the prompt, then the API returns a typed error suitable for the app UI and does not expose keys, raw tokens, or provider internals.
- Given the user refreshes image history for a project, then Flux generations appear alongside existing Image Robot results without requiring Supabase or local JSON as the source of truth.
- Given existing Robolly/OpenAI template/profile flows are used, when Flux is added, then those flows keep their current behavior and response contracts.

## Error Behavior

- If the user is not authenticated through Clerk, return `401` via existing `require_current_user` behavior.
- If the project does not exist or is not owned by the current user, return `404` or `403` using the existing ownership convention; never rely on the placeholder `default-user`.
- If a requested profile does not allow `flux`, return `400` with an unsupported provider/profile message.
- If a requested reference image belongs to another project or is not approved for visual memory, return `403`; never silently ignore an explicitly requested invalid reference.
- If `use_visual_memory` is true and the project has no approved references, continue text-to-image generation and return `references_used: []` plus `visual_memory_applied: false`.
- If the provider returns moderation or safety failure, mark the generation `failed` with `provider_safety_rejected` and store only minimal failure metadata.
- If provider output is empty, malformed, or not a supported image MIME type, mark the generation `failed` with `provider_invalid_output`.
- If Turso persistence fails after Bunny upload, return the image response with a visible `history_persisted: false` flag only if the generation asset is durable; otherwise return failure.
- What must never happen: anonymous generation in this feature, unverified user/project access, provider secrets in responses/logs, generated outputs stored only on third-party temporary URLs, image references copied across projects, or a new Next/Supabase subsystem.

## Problem

ContentGlowz already has Image Robot infrastructure, but it is centered on template-driven generation such as Robolly and profile-driven OpenAI image generation. The `contentglowz/v0-flux-2-playground` prototype shows a useful AI image workflow with prompt, ratio, reference images, history, and result reuse, but its implementation is not compatible with the production stack. Users need AI-generated visuals that match their project formats and recurring visual identity, without being pushed into an unguided playground.

## Solution

Extend `lab` Image Robot with a first-class `flux` provider that fits the existing profile, project, auth, Bunny CDN, queue, and app contracts. Add controlled project visual references for guided visual consistency across characters, products, brand traits, and recurring motifs. Expose the feature to `app` only through guided formats such as blog hero, OG/social card, thumbnail, and post visual.

## Scope In

- Add `flux` as an allowed image provider in Image Robot profiles.
- Implement a backend Flux provider service in `lab` that calls the configured BFL-compatible API.
- Support text-to-image and reference-guided generation for up to eight approved project reference images.
- Execute Flux generation asynchronously through the existing backend job/queue pattern so generated assets can feed content distribution and publication queues without requiring the user to wait on the request.
- Map guided profile formats to explicit dimensions for blog hero, OG/social card, thumbnail, and post visuals.
- Store generated assets in Bunny CDN and return optimizer/responsive URLs using the existing CDN manager path.
- Persist generation history and provider metadata in a project/user-scoped durable store.
- Add model, provider, prompt, resolved dimensions, seed, safety tolerance, output format, reference IDs, status, error category, provider cost if available, and timing metadata.
- Preserve existing `/api/images/generate-from-profile` semantics where possible and add only the fields needed for Flux.
- Add API tests for ownership, provider resolution, reference validation, provider error mapping, CDN upload failure, and history persistence.
- Add app-facing copy/state requirements so Flutter can present Flux as guided image generation, not a blank playground.

## Scope Out

- Anonymous/free public generation.
- Supabase, Vercel Blob, Vercel OAuth, or Next.js route migration from the prototype.
- A standalone playground screen with arbitrary model controls.
- Video image generation workflows; include only future-compatible metadata where cheap.
- Fine-tuning, LoRA training, custom model hosting, or local Flux inference.
- Full asset library UI for managing all project images; only the minimal visual memory/reference contract is included.
- Billing, quotas, and plan limits beyond recording cost metadata when the provider returns it.
- Automatic insertion into articles/posts; this provider returns durable generated assets for existing or future workflows to use.
- Flutter screen/UI implementation beyond typed API client methods and app-facing contract notes; a dedicated UI spec will own the guided screens.

## Constraints

- `lab` is the source of truth for backend generation; `app` consumes FastAPI only.
- Authentication must use existing Clerk/FastAPI dependencies.
- Project access must use real current user identity, not the current `get_current_user_id()` placeholder in `api/routers/images.py`.
- Storage remains Bunny CDN.
- If Turso tables are introduced for history/visual memory, startup ensures or migrations must ship in the same implementation.
- Provider keys must live in environment variables and never be stored in project profiles.
- The app should expose guided presets and profile choices, not raw provider internals.
- V1 uses stable `flux-2-pro` by default for reproducibility. An environment override may point to another BFL-compatible model, but built-in profiles must not default to preview/latest endpoints.
- V1 uses asynchronous Image Robot jobs. The API request creates/returns a job or generation record; a backend worker performs provider polling with a strict timeout and records success/failure.
- V1 creates new Turso/libSQL tables for image generation history and project visual memory references; this is not optional.
- V1 has no per-plan quota or billing enforcement. Abuse controls are authenticated-only access, project ownership, queue/job limits, provider timeout, input size limits, reference count limits, and normalized provider rate-limit handling.

## Dependencies

- Existing backend router: `lab/api/routers/images.py`.
- Existing image models: `lab/api/models/images.py`.
- Existing OpenAI image service pattern: `lab/api/services/ai_image_generation.py`.
- Existing image profile store: `lab/api/services/image_profiles.py`.
- Existing Image Robot pipeline: `lab/agents/images/**`.
- Existing Bunny CDN manager: `lab/agents/images/cdn_manager.py`.
- Existing auth dependency: `lab/api/dependencies/auth.py`.
- Existing project store/ownership patterns: `lab/agents/seo/config/project_store.py` and ownership helpers where applicable.
- Existing Flutter API service/provider conventions: `app/lib/data/services/api_service.dart` and `app/lib/providers/providers.dart`.
- Fresh external docs: `fresh-docs checked`. Official Black Forest Labs docs were checked on 2026-05-11:
  - `https://docs.bfl.ai/flux_2/flux2_overview`
  - `https://docs.bfl.ml/api-reference/models/generate-or-edit-an-image-with-flux2-%5Bpro%5D`

## Invariants

- All generation belongs to a project and an authenticated user.
- A generated image returned to the app is durable only after Bunny CDN upload succeeds.
- Reference images used for consistency must be project-scoped and approved.
- Robolly and existing OpenAI profile behavior must remain backward compatible.
- Provider errors are normalized before reaching the app.
- The first implementation supports consistent visual direction through references and structured prompts, not through training or custom weights.

## Links & Consequences

- `lab/api/routers/images.py`: needs real current-user ownership checks before project-scoped image features can be trusted.
- `lab/api/models/images.py`: needs provider enum expansion, Flux request metadata, and response fields for history/persistence status.
- `lab/api/services/ai_image_generation.py`: remains the OpenAI provider helper. Flux uses a new `lab/api/services/flux_image_generation.py` service and `images.py` routes delegate by provider.
- `lab/api/services/image_profiles.py`: needs built-in Flux profiles for blog hero, social card, thumbnail, and post visual.
- `lab/agents/images/cdn_manager.py`: should remain the durable storage path; no Vercel Blob path is introduced.
- `app/lib/data/services/api_service.dart`: needs typed calls once the backend endpoint contract is ready.
- Turso/libSQL: V1 requires new durable tables for image generation history and project visual memory.
- Existing job/status systems: Flux generation should reuse or align with the current backend job pattern rather than creating a separate ad hoc polling loop.
- Docs/support: update backend setup docs with Flux env vars and Image Robot provider behavior.

## Documentation Coherence

- Update `lab` environment/setup documentation with required Flux variables, expected Bunny variables, and failure modes.
- Update Image Robot API docs or README to distinguish template providers from AI generative providers.
- Update app copy only after UI work begins, keeping wording guided by output type rather than model name.
- Add a short implementation note explaining that consistency V1 uses approved reference images and structured project prompts; fine-tuning is out of scope.

## Edge Cases

- A project has no visual memory references yet: generation still works from profile prompt and brand traits, with UI suggesting adding references later.
- A project has more than eight references: backend chooses the profile-approved priority order and records the selected references.
- A reference image is too large or unsupported: backend rejects it before provider call or uses a normalized Bunny/CDN source if already processed.
- Provider supports multiple Flux variants: V1 built-in profiles use stable `flux-2-pro`; an env override is allowed only as an operator-controlled deployment setting.
- The provider returns an async polling URL rather than final bytes immediately: the worker polls with a configurable strict timeout, persists `provider_timeout` failure metadata, and marks the job/generation failed if no durable Bunny asset is available.
- Flux can edit from references, but the user expects identical character consistency: spec language and UI must present it as consistency guidance, not a perfect identity guarantee.
- Generated images may include readable text: prompts should avoid relying on exact text unless the format needs it, and failures should be editable/regenerable later.

## Implementation Tasks

- [x] Task 1: Fix Image Robot project ownership foundation
  - File: `lab/api/routers/images.py`
  - Action: Replace the `get_current_user_id()` placeholder with the authenticated `CurrentUser` from `require_current_user` in project-scoped endpoints and helpers.
  - User story link: Prevents generated assets and references from crossing project/user boundaries.
  - Depends on: none.
  - Validate with: backend tests for owned, missing, and foreign project IDs.

- [x] Task 2: Define durable image generation and visual memory schema
  - File: `lab/api/models/images.py`
  - Action: Add request/response models for `flux` provider metadata, generation history items, visual memory references, normalized provider errors, and explicit fields: `generation_id`, `history_persisted`, `provider_used`, `model`, `dimensions`, `seed`, `reference_ids`, `visual_memory_applied`, `references_used`, `provider_metadata`, and `error_code`.
  - User story link: Makes Flux outputs traceable and project-scoped.
  - Depends on: Task 1.
  - Validate with: model validation tests for provider, ratios/dimensions, references, and error categories.

- [x] Task 3: Add Turso persistence for image generations and references
  - File: `lab/api/services/image_generation_store.py`
  - Action: Create a store with idempotent startup ensure or migration for `ImageGeneration` and `ImageReference` tables. `ImageGeneration` stores `id`, `project_id`, `user_id`, `profile_id`, `provider`, `model`, `status`, `job_id`, `prompt`, `prompt_hash`, `width`, `height`, `seed`, `output_format`, `cdn_url`, `primary_url`, `responsive_urls_json`, `reference_ids_json`, `visual_memory_applied`, `provider_cost`, `provider_request_id`, `error_code`, `error_message`, `created_at`, `updated_at`, `started_at`, and `completed_at`. `ImageReference` stores `id`, `project_id`, `user_id`, `cdn_url`, `primary_url`, `mime_type`, `width`, `height`, `label`, `reference_type`, `approved`, `created_at`, and `updated_at`.
  - User story link: Gives users durable history and project consistency memory.
  - Depends on: Task 2.
  - Validate with: repository/store tests against SQLite/libSQL test DB.

- [x] Task 4: Implement Flux provider service
  - File: `lab/api/services/flux_image_generation.py`
  - Action: Submit Flux generation/edit requests with prompt, dimensions, optional seed, output format, safety tolerance, and up to eight approved Bunny-backed references; poll from the worker with strict timeout; download only from allowed provider result URLs or provider base64 payloads; normalize provider errors.
  - User story link: Adds AI-native image generation without changing the app stack.
  - Depends on: Task 2.
  - Validate with: mocked HTTP tests for success, async polling, safety rejection, rate limit, invalid output, timeout, and missing API key.

- [x] Task 5: Integrate Flux into profile-based generation
  - File: `lab/api/routers/images.py`
  - Action: Extend `/api/images/generate-from-profile` or add a narrowly compatible endpoint so `image_provider: flux` creates a queued generation, persists initial history, and returns job/generation metadata. Worker completion generates via Flux, uploads via Bunny, persists final history, and exposes the existing response shape plus Flux metadata through status/history endpoints.
  - User story link: Keeps AI images inside the current Image Robot flow.
  - Depends on: Tasks 1, 3, and 4.
  - Validate with: API tests for profile resolution, Bunny upload, persisted history, and backward compatibility with Robolly/OpenAI.

- [x] Task 6: Harden image ingestion into Bunny
  - File: `lab/agents/images/tools/bunny_cdn_tools.py`
  - Action: Add safe ingestion constraints used by Flux output/reference flows: allowlisted source types, MIME allowlist, maximum byte size, request timeout, no arbitrary internal/private URL fetching, and streaming or bounded download behavior.
  - User story link: Prevents provider/reference image handling from becoming an SSRF or resource-exhaustion path.
  - Depends on: Task 4.
  - Validate with: tests for rejected private URLs, unsupported MIME types, oversize responses, and successful local/provider-safe uploads.

- [x] Task 7: Add guided Flux profiles
  - File: `lab/api/services/image_profiles.py`
  - Action: Add built-in profiles for AI blog hero, AI social card, AI thumbnail, and AI post visual with `image_provider: flux`, guided base prompts, path types, and format defaults.
  - User story link: Prevents the feature from becoming an unguided playground.
  - Depends on: Task 5.
  - Validate with: profile listing tests and generated prompt snapshots.

- [x] Task 8: Add project visual memory endpoints
  - File: `lab/api/routers/images.py`
  - Action: Add authenticated endpoints to list/add/remove/approve project reference images. References must be durable Bunny assets with DB ownership metadata before they can be sent to Flux.
  - User story link: Enables consistent recurring characters, products, and visual traits per project.
  - Depends on: Tasks 3 and 6.
  - Validate with: ownership tests, MIME/size validation tests, and cross-project rejection tests.

- [x] Task 9: Prepare Flutter API integration contract
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add typed client methods for listing Flux-capable profiles, queueing generation from a profile, reading generation status/history, and selecting visual memory references. Do not add the final screen flow in this spec.
  - User story link: Allows the app to consume the backend without a separate web playground.
  - Depends on: Task 5 and Task 8.
  - Validate with: Dart unit tests for request serialization, response parsing, and error mapping.

- [x] Task 10: Document configuration and operations
  - File: `lab/README.md`, `lab/.env.example`
  - Action: Document Flux env vars, Bunny dependency, safety/error behavior, and the V1 consistency model.
  - User story link: Makes the feature operable and debuggable.
  - Depends on: Tasks 4 and 5.
  - Validate with: docs review and config validation test if available.

## Acceptance Criteria

- Authenticated or authorized automation generation from a `flux` profile creates a project-scoped queued generation record.
- Completed Flux jobs produce a Bunny CDN image URL for an owned project.
- Generated image history is durable and project-scoped.
- Reference-guided generation uses only approved references from the same project.
- Blog hero, social/OG card, thumbnail, and post visual profiles are available without exposing raw provider controls.
- Existing Robolly and OpenAI image flows still pass their tests and contracts.
- Provider failures are visible to the app as normalized errors.
- CDN upload failure returns `cdn_upload_failed` and no durable image URL.
- Turso persistence failure after a successful Bunny upload returns a durable asset response with `history_persisted: false`; persistence failure before durable asset creation returns failure.
- Provider safety rejection, rate limit, timeout, invalid output, and not-configured cases return normalized error codes.
- Visual memory endpoints reject cross-project references and only approved references can be sent to Flux.
- The backend does not expose raw provider controls such as arbitrary dimensions, preview/latest model selection, safety tolerance, or arbitrary provider URLs through the app-facing profile flow.
- Logs include generation ID, project ID, provider, model, status, and normalized error category, but never provider keys, raw base64 images, or reference image payloads.
- No anonymous generation or public demo path is introduced.
- Turso migration/ensure is required for V1 and is implemented in the same change as the API code.

## Test Strategy

- Python unit tests for model validation and profile provider selection.
- Python service tests with mocked Flux API responses.
- FastAPI route tests for auth, ownership, successful generation, provider failures, Bunny upload failures, and history persistence.
- Job/worker tests for queued, running, completed, failed, timeout, and retry-safe status transitions.
- Store tests for Turso/libSQL schema and project-scoped queries.
- Bunny ingestion safety tests for URL allowlist behavior, MIME validation, size caps, and timeout handling.
- Dart tests for API client parsing once Flutter integration starts.
- Manual smoke after implementation: create/select project, generate AI blog hero from profile, verify CDN URL, verify history, verify references are scoped.

## Risks

- Provider cost can grow if authenticated users repeatedly generate images; V1 records cost metadata and rate-limit/provider errors but does not implement billing quotas.
- Async jobs can accumulate if provider latency spikes; V1 must bound worker polling, persist failure states, and avoid unbounded queue fan-out.
- Visual consistency through references may be imperfect; UI and docs must not promise exact character identity.
- Bunny ingestion can become an SSRF/resource-exhaustion vector if arbitrary URLs are accepted; V1 requires hardened ingestion before Flux/reference flows are enabled.
- New Turso tables can break startup if migrations are not idempotent; V1 requires defensive startup ensure or migration in the same change.
- Existing Robolly/OpenAI image flows can regress if provider branching is too broad; tests must cover backward compatibility.

## Execution Notes

- Read first: `lab/api/routers/images.py`, `lab/api/models/images.py`, `lab/api/dependencies/auth.py`, `lab/api/dependencies/ownership.py`, `lab/api/services/image_profiles.py`, `lab/api/services/ai_image_generation.py`, `lab/agents/images/cdn_manager.py`, `lab/agents/images/tools/bunny_cdn_tools.py`, and `app/lib/data/services/api_service.dart`.
- Implement in the task order listed above. Do not start Flux provider calls before project ownership and persistence contracts are fixed.
- Use stable `flux-2-pro` as the default model. Environment override is allowed for operators, but the app-facing flow must not expose model switching in V1.
- Use asynchronous Image Robot jobs for V1. The request path must not wait for Flux output; workers may poll Flux with a strict timeout and must persist terminal state.
- Add tests with mocked external HTTP calls; do not call live Flux or Bunny APIs in unit tests.
- Keep provider-specific code in `flux_image_generation.py`; do not turn the existing OpenAI helper into a broad abstraction unless needed for a small local interface.
- Create or update Turso/libSQL ensure logic in the same implementation batch as the store and route code.
- Stop conditions: unresolved ownership behavior, missing migration/ensure, unsafe Bunny ingestion, live-provider-only tests, or any need to expose a free-form playground.

## Rollout Plan

- Ship backend provider behind an environment/config gate.
- Enable built-in Flux profiles only when `BFL_API_KEY` or the chosen provider key is present.
- Keep existing Image Robot providers enabled.
- Release Flutter UI separately after backend contract passes `/sf-ready` and implementation verification.
- Monitor provider errors, generation latency, CDN upload failures, and storage history persistence.

## Security & Privacy

- Flux API keys remain server-side only.
- Reference images must be project-scoped and should not be sent to Flux unless the user or automation intentionally uses the visual reference feature.
- Logs must include generation IDs and error categories, not raw base64 images or secrets.
- History stores prompts and image URLs, so access must be owner/project scoped.
- Safety rejection and moderation failures must not store unsafe generated content.

## Open Questions

None. V1 decisions: stable `flux-2-pro` by default with server-side env override only; visual consistency is presented as "coherence visuelle guidee" using Flux-supported multi-reference inputs rather than fine-tuning; visual references use new minimal Image Robot endpoints backed by Bunny + Turso ownership metadata; generation uses asynchronous backend jobs because ContentGlowz's primary workflow distributes queued content instead of making users wait; no per-plan quotas in V1 beyond authenticated-only access, queue/input limits, timeout, and normalized provider rate-limit handling.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 13:15:23 UTC | sf-spec | GPT-5 Codex | Created draft spec from contentglowz Flux audit and user decisions. | Draft spec created. | /sf-ready shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md |
| 2026-05-11 13:24:28 UTC | sf-ready | GPT-5 Codex + subagents | Ran readiness review, resolved blocking open decisions, added required sections, and tightened security/persistence contracts. | Ready after spec update. | /sf-start shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md |
| 2026-05-11 13:31:15 UTC | sf-ready | GPT-5 Codex | Applied product decisions from user: async queued generation, Flux multi-reference visual guidance, no V1 quotas, UI spec later, and "coherence visuelle guidee" promise. | Ready after product-decision update. | /sf-start shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md |
| 2026-05-12 18:53:40 UTC | sf-start | GPT-5 Codex | Implemented Flux Image Robot backend foundation, visual references, Bunny hardening, project asset registration, Flutter API contract, docs, and tests. | Implementation complete pending verification. | /sf-verify shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md |
| 2026-05-13 04:59:01 UTC | sf-verify | GPT-5 Codex | Verified Flux Image Robot against spec, checked current BFL docs, fixed guided-profile/raw-control gaps and Flux-safe dimensions, then ran targeted backend and Flutter checks. | verified | /sf-end shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md |
| 2026-05-13 07:44:18 UTC | sf-end | GPT-5 Codex | Closed the verified Flux Image Robot chantier, updated tracker/changelog bookkeeping, and prepared the spec for shipping. | closed | /sf-ship shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md |
| 2026-05-13 07:46:41 UTC | sf-ship | GPT-5 Codex | Shipped the scoped Flux Image Robot chantier with explicit staging, targeted backend and Flutter checks, and push to origin/main. | shipped | none |

## Current Chantier Flow

sf-spec: completed
sf-ready: ready
sf-start: completed
sf-verify: verified
sf-end: closed
sf-ship: shipped
