---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "contentglowz"
created: "2026-05-12"
created_at: "2026-05-12 20:35:56 UTC"
updated: "2026-05-12"
updated_at: "2026-05-12 20:35:56 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant qu'operatrice ContentGlowz, je veux comparer les providers IA sur cout, latence, fiabilite et qualite observable, afin de choisir les bons providers par workflow et proteger le PAYG sans exposer un benchmark public aux creatrices."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "contentglowz/v0-ai-image-generation-benchmark"
  - "Image Robot"
  - "Flux/BFL"
  - "OpenRouter BYOK"
  - "ElevenLabs"
  - "FAL"
  - "Bunny Storage/CDN"
  - "Remotion"
  - "AI Generation Quotas/Billing"
  - "Turso/libSQL"
  - "Clerk"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "in_progress"
  - artifact: "shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/business/project-competitors-and-inspirations.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "contentglowz/v0-ai-image-generation-benchmark"
    artifact_version: "local prototype"
    required_status: "inspiration-only"
  - artifact: "BFL pricing and FLUX.2 API docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "fal Model API pricing docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "OpenRouter API usage/cost docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "ElevenLabs usage/history docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
supersedes: []
evidence:
  - "User request 2026-05-12: create an internal spec for provider benchmark, provider choice, cost/latency/quality telemetry, useful for PAYG."
  - "Product context: contentglowz is inspiration only; keep the current Flutter/FastAPI/Clerk/Turso/Bunny stack."
  - "Product context: the benchmark should support efficient social-content workflows and operator decisions, not a public model playground."
  - "Prototype evidence: contentglowz/v0-ai-image-generation-benchmark compares model/provider, durationMs, cost, success and history across image generation providers."
  - "Prototype evidence: contentglowz/v0-ai-image-generation-benchmark/app/api/generate-single/route.ts measures request start/end time per model and calculates provider-specific cost, but returns base64 images and uses Next/FAL/Prodia/xAI directly."
  - "Prototype evidence: contentglowz/v0-ai-image-generation-benchmark/lib/pricing.ts hard-codes stale pricing tables; ContentGlowz must use versioned provider cost catalogs and actual provider metadata instead."
  - "Code evidence: lab/status/cost_tracker.py already persists DataForSEO-shaped estimated costs by project/job/pipeline/provider but is not a general AI provider telemetry ledger."
  - "Code evidence: lab/api/services/image_generation_store.py stores provider_cost and provider_metadata_json for ImageGeneration, but no benchmark run, quality signal, pricing-table version, or provider recommendation state."
  - "Code evidence: lab/api/services/flux_image_generation.py captures provider_request_id and provider_cost from BFL submit response, and lab/api/routers/images.py stores it after generation."
  - "Code evidence: lab/api/services/ai_entitlement_service.py is currently env/allowlist-backed and does not provide PAYG provider choice metrics."
  - "Code evidence: feedback admin uses an email allowlist pattern in lab/api/routers/feedback.py and app has a feedback admin screen that can inspire an internal admin-only surface."
  - "Fresh docs checked 2026-05-12: BFL pricing docs say FLUX.2 uses megapixel-based pricing and 1 credit equals $0.01 USD."
  - "Fresh docs checked 2026-05-12: BFL FLUX.2 Pro API response includes id, polling_url, nullable cost, input_mp and output_mp fields."
  - "Fresh docs checked 2026-05-12: fal Model API pricing docs say providers can charge by image, megapixel, video second, request or compute second, and expose programmatic pricing/usage APIs."
  - "Fresh docs checked 2026-05-12: OpenRouter docs expose response usage and a generation stats endpoint with token counts and cost after completion."
  - "Fresh docs checked 2026-05-12: ElevenLabs docs expose generated-item history fields and workspace usage analytics with success rate and average latency."
next_step: "/sf-ready AI Provider Benchmark Cost Quality Telemetry"
---

## Title

AI Provider Benchmark Cost Quality Telemetry

## Status

Draft. This spec defines an internal ContentGlowz layer for provider benchmarking, production telemetry, cost evidence, quality signals and provider-choice recommendations. V1 starts with image generation because Flux/Image Robot and the `contentglowz` benchmark inspiration are already concrete. The data model must be shared enough to extend later to audio, STT, video rendering and Remotion-related provider decisions without exposing a public model playground.

## User Story

En tant qu'operatrice ContentGlowz, je veux comparer les providers IA sur cout, latence, fiabilite et qualite observable, afin de choisir les bons providers par workflow et proteger le PAYG sans exposer un benchmark public aux creatrices.

## Minimal Behavior Contract

ContentGlowz records a normalized internal telemetry event whenever an AI provider job is benchmarked or completed in production: provider, model, workflow action, input/output units, estimated cost, actual provider cost when available, latency split, success/failure, error code, output durability, quality signals and pricing-catalog version. Admin operators can run controlled benchmark suites on fixture prompts/assets and review scorecards by provider/action/profile. The system may recommend a default provider or flag regressions, but it must not automatically switch customer jobs to a new provider unless an explicit allowlisted rollout policy exists. If provider docs, price data, quality samples, ownership, quota or storage evidence is missing, the run is marked partial and no provider-choice change is applied. The easy edge case to miss is treating "quality" as a single subjective score: V1 must combine fixture review, output validation and real workflow acceptance signals, while keeping private prompts, assets and provider secrets out of logs and public analytics.

## Success Behavior

- Given an admin operator opens the internal benchmark surface, when they choose an image benchmark suite, then the app shows fixture suites, candidate providers/models, last run status, median/p95 latency, estimated and actual cost, success rate, quality score, sample output links when safe, and current recommendation.
- Given a benchmark run is started, when the backend validates admin access and provider availability, then it creates a benchmark run record with fixture ids, provider candidates, pricing catalog version, run mode, initiated_by user id, and a pollable status.
- Given benchmark candidates are image providers, when the runner executes, then each provider receives the same normalized prompt, format, dimensions, reference policy and safety settings compatible with that provider, and the system records start time, provider submission time, provider completion time, Bunny storage time, total time and normalized outcome.
- Given a provider returns exact cost metadata, when the run completes, then ContentGlowz records actual provider cost separately from estimated cost and marks the cost source as `provider_reported`.
- Given a provider does not return exact cost, when the run completes, then ContentGlowz computes an estimate from a versioned cost catalog and marks confidence and pricing source rather than inventing exact spend.
- Given benchmark output is durable and safe for internal review, when it is uploaded to Bunny, then the scorecard can display samples only to admin users and only via server-owned asset descriptors.
- Given an admin rates benchmark output, when they submit the rating, then the system stores rubric scores for social usefulness: prompt adherence, visual consistency, readability, artifact level, brand safety, format fit and publishability.
- Given production Image Robot generations complete, when telemetry is recorded, then the system adds non-sensitive production signals such as job success, provider latency, provider cost, output persisted, user kept as candidate, user promoted as primary, regenerated, tombstoned, or used in a placement.
- Given scorecards show a provider has degraded, when an operator reviews recommendations, then the system can flag `monitor`, `deprecate`, `canary`, or `preferred` for a workflow/profile without mutating running jobs automatically.
- Proof of success is a provider telemetry store, benchmark run history, quality rubric, scorecard API, admin-only UI, provider recommendation record, Flux/Image Robot instrumentation, and tests proving admin isolation, no secret leakage, idempotent metrics, partial run handling and PAYG-compatible cost evidence.

## Error Behavior

- Missing or invalid Clerk auth returns `401`; no benchmark run, telemetry export, scorecard or provider recommendation is returned.
- Non-admin users receive `403` for benchmark management, sample output access, provider recommendations and admin scorecards.
- If an owned production job emits telemetry, but the user/project cannot be resolved, the event is rejected or stored as quarantined ops-only data without appearing in user/project summaries.
- If a provider key is missing, disabled, rate-limited or rejected by entitlement policy, the benchmark candidate is marked `provider_unavailable`; other candidates may continue, and the run status becomes `partial` if at least one candidate completes.
- If quota/PAYG preflight blocks a production user action, the benchmark telemetry layer must record the block only as a non-provider event and must not create fake provider latency or cost.
- If provider output succeeds but Bunny upload fails, the run records provider spend and `durable_output=false`; quality review is disabled unless an explicit safe artifact exists.
- If pricing catalog lookup is stale, missing or mismatched with provider metadata, the event stores `estimated_cost_unknown` or `pricing_catalog_stale` and does not feed PAYG margin recommendations.
- If provider returns malformed cost, usage or timing metadata, the raw payload is redacted, stored only as sanitized metadata, and the event is marked `provider_metadata_invalid`.
- If an admin attempts to compare outputs from different prompts, dimensions or fixtures as one benchmark, the backend rejects the aggregation with `benchmark_fixture_mismatch`.
- If a quality rating is submitted for an output outside an admin-visible run, the backend rejects it and does not expose the asset.
- If two benchmark runs use the same idempotency key, the backend returns the existing run instead of duplicating provider calls.
- What must never happen: raw provider secrets, signed Bunny URLs, full private customer prompts, raw user reference images, provider polling URLs, bearer tokens, cross-tenant job ids or non-admin sample outputs in Flutter logs, analytics, public APIs or exports.

## Problem

The `contentglowz` image benchmark shows a useful product idea: compare model outputs, speed and costs side by side. In ContentGlowz, copying that as a user-facing playground would be the wrong product. The real need is internal: decide which provider/model should power each guided workflow, know actual cost and latency for PAYG, detect provider regressions, and collect quality evidence from real social-content outcomes. The current backend has partial pieces, including `api_cost_log`, `ImageGeneration.provider_cost`, Flux provider metadata and quota specs, but it lacks a normalized cross-provider telemetry contract, benchmark runs, quality scoring, pricing catalog versions and admin-only provider recommendations.

## Solution

Create an internal AI provider benchmark and telemetry subsystem. It records normalized production metrics from AI provider jobs, runs controlled benchmark suites against fixture prompts/assets, stores versioned cost catalog evidence, captures quality signals through admin rubrics and workflow outcomes, and exposes admin-only scorecards and provider recommendations. V1 instruments Image Robot/Flux first and defines extension points for OpenRouter, ElevenLabs/STT, audio/music and Remotion/render workflows.

## Scope In

- Internal admin/ops provider benchmark surface; no public benchmark page and no creator model playground.
- V1 benchmark domain starts with image generation and Image Robot profiles: blog hero, thumbnail, social visual and post visual.
- Shared telemetry schema for future AI provider actions: image generation, LLM planning, TTS/dialogue, music, STT/transcription and render-adjacent media workflows.
- Production telemetry event recording for provider calls, cost evidence, latency, status, normalized error, durable output and workflow outcome signals.
- Controlled benchmark suites with fixture prompts, dimensions, reference images, allowed providers/models, expected format and social-content objective.
- Versioned provider cost catalog with pricing unit, provider/model/action, currency, source URL, last_checked_at, confidence, effective window and operator override fields.
- Actual-cost recording when a provider returns trustworthy cost metadata; estimated-cost calculation only when cost catalog is current and confidence is explicit.
- Latency breakdown fields: queue wait if known, backend preflight, provider submit, provider processing/polling, download, Bunny upload, total job duration and user-visible ready time.
- Reliability metrics: success rate, timeout rate, provider rejection, safety rejection, malformed output, CDN failure, retry outcome and partial completion.
- Quality rubric for admin review and fixture output: prompt adherence, social usefulness, readability, composition/format fit, visual consistency, artifact severity, brand safety and publishability.
- Passive workflow quality signals: generated output kept as candidate, promoted as primary, reused in project asset library, regenerated, tombstoned, blocked before publish or manually replaced.
- Provider recommendation state per workflow/action/profile, such as `preferred`, `canary`, `fallback`, `monitor`, `deprecated`, with reason and evidence window.
- Admin-only APIs and minimal Flutter/admin UI contract for scorecards, run history, recommendations and provider regression warnings.
- Tests for admin auth, tenant isolation, telemetry redaction, idempotency, partial runs, cost-source confidence, quality rating and Flux/Image Robot instrumentation.

## Scope Out

- Public model leaderboard, public benchmark marketing page, creator-facing playground, arbitrary model picker or provider marketing comparison.
- Porting Next.js, Supabase, Vercel OAuth, Vercel Blob, FAL/Prodia/xAI prototype code directly into production.
- Automatic provider switching for live customer jobs without an explicit rollout policy and operator confirmation.
- Exact public pricing, credit pack pricing, checkout, invoices, taxes or payment-provider logic. Those remain owned by the quota/billing spec and future commercial specs.
- Full BI warehouse, external analytics platform, long-term data lake or ML-based automatic quality judge in V1.
- Storing private user prompts or private media samples in benchmark fixtures without explicit admin-selected sanitization.
- Benchmarking every provider in the market. V1 benchmarks providers already integrated or explicitly under evaluation for ContentGlowz.
- Replacing `SPEC-ai-generation-quotas-billing-2026-05-11.md`; this spec supplies telemetry evidence and recommendations, not entitlement enforcement.
- Replacing app-visible BYOK policies. BYOK OpenRouter usage remains separate from operator-paid managed usage unless a future spec changes it.
- Legal/compliance guarantee for generated content quality, copyright or caption accuracy.

## Constraints

- This is an internal product/ops feature. Creator UX should remain guided by content outcome, not by provider/model controls.
- Admin/ops access must use an explicit backend authorization dependency. The feedback admin allowlist can inspire V1, but a general admin dependency should be created or reused deliberately.
- Flutter and any admin UI call FastAPI only. They never call providers, Bunny internals or Remotion worker directly.
- Backend is the source of truth for provider telemetry, benchmark runs, cost catalog, quality ratings and recommendations.
- Cost and quality data are evidence, not billing authority. PAYG enforcement still depends on the quota/billing ledger.
- Provider pricing must be versioned and reviewable. Do not hard-code prototype pricing tables as current truth.
- Production telemetry may store prompt hashes and derived workflow outcomes by default; full prompts/assets require explicit sample-retention policy and admin-only access.
- Provider responses are untrusted until normalized and redacted. Raw payloads with secrets, URLs or user content must not be logged.
- Every production telemetry event must be scoped by user_id/project_id/content_id/job_id where available, while admin benchmark fixtures can use an internal fixture scope.
- Benchmark suites must use idempotency keys and run limits to prevent accidental cost spikes.
- If a provider returns actual cost in credits or provider-specific units, conversion to USD must cite the pricing catalog version; do not assume credits always map the same way unless official docs and account terms support it.
- Fresh-docs checked providers are evidence for the spec date only. Implementation must refresh provider docs before introducing new hard-coded pricing, usage APIs or provider adapters.

## Dependencies

- Existing Flux/Image Robot foundation: `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`.
- Existing PAYG/quota foundation: `shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md`.
- Existing BYOK/runtime foundation: `shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md` and `shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md`.
- Future audio and transcription specs:
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md`
- Local inspiration only:
  - `contentglowz/v0-ai-image-generation-benchmark/lib/types.ts`
  - `contentglowz/v0-ai-image-generation-benchmark/lib/models.ts`
  - `contentglowz/v0-ai-image-generation-benchmark/lib/pricing.ts`
  - `contentglowz/v0-ai-image-generation-benchmark/app/api/generate-single/route.ts`
  - `contentglowz/v0-ai-image-generation-benchmark/components/benchmark/*`
- Existing backend files to read first:
  - `lab/status/cost_tracker.py`
  - `lab/api/services/image_generation_store.py`
  - `lab/api/services/flux_image_generation.py`
  - `lab/api/routers/images.py`
  - `lab/api/services/job_store.py`
  - `lab/api/services/ai_entitlement_service.py`
  - `lab/api/services/ai_runtime_service.py`
  - `lab/api/routers/feedback.py`
- Existing app files to read first:
  - `app/lib/router.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/screens/settings/settings_screen.dart`
  - `app/lib/presentation/screens/feedback/feedback_admin_screen.dart`
- Fresh external docs checked:
  - `fresh-docs checked`: BFL pricing docs at `https://docs.bfl.ml/quick_start/pricing`.
  - `fresh-docs checked`: BFL FLUX.2 Pro API docs at `https://docs.bfl.ml/api-reference/models/generate-or-edit-an-image-with-flux2-%5Bpro%5D`.
  - `fresh-docs checked`: fal Model APIs pricing docs at `https://fal.ai/docs/documentation/model-apis/pricing`.
  - `fresh-docs checked`: OpenRouter API overview/cost stats at `https://openrouter.ai/docs/api/reference/overview/`.
  - `fresh-docs checked`: ElevenLabs history endpoint at `https://elevenlabs.io/docs/api-reference/history/list`.
  - `fresh-docs checked`: ElevenLabs usage analytics overview at `https://elevenlabs.io/docs/overview/administration/usage-analytics`.

## Invariants

- Benchmark and provider telemetry are internal, admin-scoped and not creator-facing by default.
- Every benchmark run has a fixture suite, provider candidates, pricing catalog version, initiated_by, status and cost guardrail.
- Every provider result has a normalized event, even on failure, timeout, rejection or partial output.
- Estimated cost, actual provider cost, user-facing PAYG units and operator invoice reconciliation remain distinct fields.
- Quality scores must name their source: admin rubric, automated validation, workflow acceptance, user feedback, or unknown.
- Quality scorecards cannot compare outputs unless fixture, prompt variant, dimensions, action, reference policy and output target are compatible.
- Provider recommendations are advisory until an explicit rollout config applies them.
- Production telemetry cannot leak private content across users/projects or into public analytics.
- Output samples are visible only to admins and only after durable safe storage or explicit fixture ownership is confirmed.
- Pricing catalogs expire or become stale; stale cost catalogs cannot drive provider recommendations or PAYG margin alerts.
- BYOK OpenRouter telemetry may record technical usage metadata for diagnostics, but it must not be charged as managed provider spend.

## Links & Consequences

- `lab/status/cost_tracker.py`: existing `api_cost_log` should remain compatible but is too DataForSEO-shaped for AI provider benchmark evidence. New tables should feed summaries rather than mutate that table into the source of truth.
- `lab/api/services/image_generation_store.py`: `provider_cost` and `provider_metadata_json` should be augmented or mirrored into provider telemetry with pricing source, actual/estimated split and quality outcome.
- `lab/api/services/flux_image_generation.py`: already captures BFL provider_request_id and cost; implementation should add input/output megapixel metadata and latency timing where available.
- `lab/api/routers/images.py`: production Image Robot routes should emit telemetry events when queued, provider started, provider completed, CDN uploaded, failed, selected, promoted or tombstoned.
- `SPEC-ai-generation-quotas-billing-2026-05-11.md`: quota/PAYG enforcement can consume telemetry for margin analysis and provider evidence, but must not depend on non-idempotent benchmark runs.
- `app`: admin UI can reuse settings/admin patterns, but must not add benchmark controls to the normal creator editor.
- `site`: no public copy change in V1. If marketing later claims faster/cheaper/better provider choices, it must cite an approved public-safe summary, not raw internal telemetry.
- Ops/support: provider regressions, cost spikes and quality drops become diagnosable without raw provider dashboards or database access.

## Documentation Coherence

- Update `lab/README.md` or env docs with benchmark provider configuration, cost catalog review process, admin auth requirement and telemetry redaction policy.
- Update `app/README.md` only if an internal admin UI ships, describing admin-only access and no public model picker.
- Update `.env.example` when benchmark provider flags, max run cost, sample retention or admin allowlist variables are introduced.
- Add an ops playbook for refreshing provider prices, running benchmark suites, reviewing quality, changing provider recommendation state and responding to provider regressions.
- Add changelog entries when telemetry starts influencing provider selection or PAYG margin alerts.
- Do not add public marketing claims about benchmark results, provider superiority or price savings in this chantier.

## Edge Cases

- Provider A returns a durable output while Provider B fails; run is partial and can still update reliability metrics, but not a full quality comparison.
- Provider returns actual cost in credits; conversion to USD depends on official provider docs and account terms.
- Provider docs change after a benchmark run; historical runs keep the pricing catalog version used at the time.
- A benchmark fixture references a private project asset; backend must reject it unless it is copied into an internal fixture scope with explicit admin action.
- A production generation is successful but user discards it; quality signal should count as weak negative outcome, not a provider failure.
- User promotes a generated image as primary then later tombstones it; telemetry should keep both events with timestamps rather than overwriting quality history.
- Provider latency is dominated by queue wait; benchmark scorecards should separate queue wait from processing where provider data allows.
- Provider succeeds but produces wrong dimensions or unsafe format; output is failure for ContentGlowz even if provider billed success.
- A provider result is visually good but too expensive for PAYG margin; recommendation may be `premium/canary` rather than default.
- A cheap provider is fast but produces unreadable thumbnails; social-quality rubric should prevent it from becoming preferred for thumbnails.
- An admin manually rates the wrong fixture; rating must be tied to run_result_id and reversible/auditable.
- A repeated benchmark uses cached provider output or idempotency replay; run result must disclose cache/replay status.
- Concurrent benchmark runs exceed cost guardrail; backend must queue, cap, or reject before provider calls.
- BYOK user calls through OpenRouter return token/cost stats; telemetry may record usage for diagnostics, but managed PAYG summaries must keep it separate.

## Implementation Tasks

- [ ] Task 1: Define provider telemetry and benchmark models
  - Fichier : `lab/api/models/ai_provider_benchmark.py`
  - Action : Add Pydantic models/enums for provider action, provider candidate, benchmark suite, fixture, run, run result, latency breakdown, cost evidence, quality rubric, workflow outcome signal, recommendation state and admin-safe response envelopes.
  - User story link : Gives operators a stable contract for comparing provider cost, speed, reliability and quality.
  - Depends on : Existing Flux and PAYG specs.
  - Validate with : model tests for image fixture, production event, partial run, stale pricing catalog, admin rating and redacted response.
  - Notes : Keep actual cost, estimated cost, PAYG units and invoice reconciliation distinct.

- [ ] Task 2: Add Turso/libSQL benchmark and telemetry store
  - Fichier : `lab/api/services/ai_provider_telemetry_store.py`
  - Action : Create idempotent schema ensures or migrations for provider_cost_catalogs, provider_telemetry_events, benchmark_suites, benchmark_fixtures, benchmark_runs, benchmark_results, quality_ratings, workflow_outcome_events and provider_recommendations.
  - User story link : Makes benchmark history and provider evidence durable and auditable.
  - Depends on : Task 1.
  - Validate with : store tests for empty DB startup, upgraded DB, run/result persistence, recommendation history, tenant/admin filters and no destructive migrations.
  - Notes : Follow ContentGlowz Turso migration guardrails during implementation.

- [ ] Task 3: Create versioned provider cost catalog service
  - Fichier : `lab/api/services/ai_provider_cost_catalog.py`
  - Action : Implement provider/model/action pricing lookup with unit, currency, source URL, effective timestamps, confidence, stale policy, operator override and exact/estimated cost calculation helpers.
  - User story link : Prevents stale hard-coded prototype pricing from driving PAYG/provider choices.
  - Depends on : Task 2.
  - Validate with : tests for BFL credit conversion, megapixel estimate, FAL per-output unit, OpenRouter token cost evidence, stale catalog rejection and unknown-cost fallback.
  - Notes : Do not call live provider pricing APIs in unit tests; use fixtures and cite source metadata.

- [ ] Task 4: Add telemetry recording service
  - Fichier : `lab/api/services/ai_provider_telemetry.py`
  - Action : Implement safe event recording for provider_started, provider_completed, provider_failed, durable_output_ready, quota_blocked, user_kept_candidate, user_promoted_primary, regenerated and tombstoned outcomes.
  - User story link : Feeds scorecards from real workflow evidence without exposing private content.
  - Depends on : Tasks 1-3.
  - Validate with : tests for idempotency keys, redaction, missing project quarantine, BYOK separation, partial cost evidence and event aggregation.
  - Notes : Store prompt_hash by default; full prompts require explicit fixture/sample retention policy.

- [ ] Task 5: Instrument Flux/Image Robot production events
  - Fichier : `lab/api/routers/images.py`
  - Action : Emit telemetry around queueing, provider start, provider completion, CDN upload, normalized provider failure, generation selection, primary promotion and tombstone/restore when available.
  - User story link : Provides the first real provider decision evidence for image workflows.
  - Depends on : Task 4 and Flux implementation.
  - Validate with : route tests proving telemetry emitted on success, provider failure, Bunny failure, quota block and no provider call on unauthorized/foreign project.
  - Notes : Preserve existing Image Robot response contracts.

- [ ] Task 6: Extend Flux provider metadata capture
  - Fichier : `lab/api/services/flux_image_generation.py`
  - Action : Normalize BFL cost, input_mp, output_mp, provider_request_id, model, dimensions and latency checkpoints into admin-safe metadata for telemetry.
  - User story link : Lets operators compare actual BFL cost and speed against other candidates.
  - Depends on : Task 4.
  - Validate with : mocked BFL responses with cost present, cost absent, input/output MP present, malformed metadata, provider rejection and timeout.
  - Notes : Do not log polling_url or signed output URLs.

- [ ] Task 7: Add benchmark runner
  - Fichier : `lab/api/services/ai_provider_benchmark_runner.py`
  - Action : Implement controlled async benchmark execution for image fixtures, provider candidates, idempotency keys, max-run-cost guardrail, per-provider timeout, partial-result handling and Bunny sample storage when safe.
  - User story link : Enables deliberate provider comparisons without public playground behavior.
  - Depends on : Tasks 2-6.
  - Validate with : runner tests for identical fixture execution, partial run, max cost block, idempotent replay, provider unavailable, storage failure and per-provider timeout.
  - Notes : V1 may support BFL/Flux first; add only evaluated providers through explicit adapters.

- [ ] Task 8: Add provider adapter interface for benchmark candidates
  - Fichier : `lab/api/services/ai_provider_benchmark_adapters.py`
  - Action : Define small adapter protocol for image generation benchmark candidates and implement the existing Flux/BFL adapter; leave FAL/OpenRouter/ElevenLabs adapters as explicit future additions unless approved.
  - User story link : Keeps benchmark extensible without porting prototype provider code.
  - Depends on : Task 7.
  - Validate with : adapter contract tests and Flux adapter fixture tests.
  - Notes : Do not add provider sprawl in V1; provider candidates must be configured and allowlisted.

- [ ] Task 9: Add admin-only benchmark APIs
  - Fichier : `lab/api/routers/ai_provider_benchmarks.py`
  - Action : Add endpoints for admin capability, list suites, start run, get run, list scorecards, submit quality rating, update recommendation and list cost catalog freshness.
  - User story link : Gives operators a controlled way to inspect and act on benchmark evidence.
  - Depends on : Tasks 1-8.
  - Validate with : FastAPI tests for non-admin rejection, admin success, no secret/sample leakage, idempotent start, recommendation audit and pagination.
  - Notes : If no general admin dependency exists, create a narrow allowlist dependency and record that as debt.

- [ ] Task 10: Feed benchmark evidence into PAYG/admin summaries
  - Fichier : `lab/status/cost_tracker.py`
  - Action : Add read-only aggregation helpers or adapters that combine existing cost summaries with AI provider telemetry without making `api_cost_log` the benchmark source of truth.
  - User story link : Makes provider cost evidence useful for PAYG and margin review.
  - Depends on : Tasks 2-4.
  - Validate with : aggregation tests for provider/action/date/project filters, actual vs estimated costs and BYOK exclusion.
  - Notes : Preserve DataForSEO cost tracking compatibility.

- [ ] Task 11: Add Flutter admin data models and API methods
  - Fichier : `app/lib/data/models/ai_provider_benchmark.dart`
  - Action : Add Dart models for scorecards, runs, results, quality ratings, recommendations, cost freshness and admin capability; add matching ApiService methods.
  - User story link : Lets the internal admin UI consume the backend safely.
  - Depends on : Task 9.
  - Validate with : Dart parsing tests for scorecard, partial run, redacted sample and non-admin capability.
  - Notes : Also update `app/lib/data/services/api_service.dart`.

- [ ] Task 12: Add Riverpod controller for admin provider benchmarks
  - Fichier : `app/lib/providers/ai_provider_benchmark_provider.dart`
  - Action : Add provider/notifier for admin capability, scorecard filters, run polling, quality rating submit, recommendation update and stale response handling.
  - User story link : Keeps admin benchmark state isolated from creator workflows.
  - Depends on : Task 11.
  - Validate with : provider tests for capability false, run polling, project switch, partial run and recommendation update.
  - Notes : Do not add normal creator navigation.

- [ ] Task 13: Add internal admin benchmark screen
  - Fichier : `app/lib/presentation/screens/settings/ai_provider_benchmark_admin_screen.dart`
  - Action : Build a dense admin screen with provider scorecards, benchmark run history, cost/latency/reliability/quality breakdowns, fixture output review, quality rating controls and recommendation state.
  - User story link : Gives operators a practical decision surface for provider choice.
  - Depends on : Task 12.
  - Validate with : widget tests for non-admin block, scorecard loading, partial run, sample redaction, rating form and mobile/desktop layout.
  - Notes : Keep UI internal and utilitarian; no public leaderboard treatment.

- [ ] Task 14: Register admin route behind capability
  - Fichier : `app/lib/router.dart`
  - Action : Add an internal route for the benchmark admin screen and a settings entry visible only when admin capability is true.
  - User story link : Keeps the benchmark accessible to operators but invisible to normal creators.
  - Depends on : Task 13.
  - Validate with : route tests/manual smoke for admin and non-admin users.
  - Notes : Reuse the feedback admin access pattern where appropriate.

- [ ] Task 15: Document operations and redaction policy
  - Fichier : `lab/README.md`
  - Action : Document benchmark env vars, admin auth, provider cost catalog refresh, max-run-cost guardrails, sample retention, redaction rules and provider recommendation workflow.
  - User story link : Makes benchmark evidence maintainable and safe.
  - Depends on : Backend tasks.
  - Validate with : docs review and `rg` for forbidden claims such as public leaderboard, guaranteed cheapest provider or automatic provider switching.
  - Notes : Also update `.env.example`, `app/README.md` if UI ships, and changelog.

## Acceptance Criteria

- [ ] CA 1: Given a non-admin authenticated user, when they call any benchmark admin endpoint or route, then they receive `403` or no visible admin entry and no provider evidence leaks.
- [ ] CA 2: Given an admin user, when they open the benchmark surface, then they can view image provider scorecards with cost, latency, reliability, quality and recommendation state.
- [ ] CA 3: Given a benchmark run is started with an idempotency key, when the same request is submitted again, then no duplicate provider calls are created and the existing run is returned.
- [ ] CA 4: Given provider candidates use the same fixture, when the run completes, then scorecards compare only compatible prompt, dimensions, action, references and output target.
- [ ] CA 5: Given one provider fails and another succeeds, when the run completes, then status is `partial`, successful results remain reviewable and failed provider errors are normalized.
- [ ] CA 6: Given BFL returns cost/input_mp/output_mp, when telemetry is persisted, then those fields are stored as provider-reported evidence with pricing catalog version.
- [ ] CA 7: Given a provider has no exact cost, when estimation is possible from a fresh catalog, then estimated cost is stored with source and confidence, separate from actual cost.
- [ ] CA 8: Given the pricing catalog is stale, when a run completes, then provider recommendation updates are blocked or flagged until pricing is refreshed.
- [ ] CA 9: Given a benchmark output is not durably stored, when an admin opens sample review, then no broken temporary provider URL is displayed.
- [ ] CA 10: Given an admin quality-rates an output, when saved, then rubric scores and reviewer metadata are auditable and tied to the run result.
- [ ] CA 11: Given production Flux generation completes, when the user keeps/promotes/regenerates/tombstones the output, then workflow outcome events are recorded without storing full private prompt text in analytics.
- [ ] CA 12: Given a provider has high latency or failure rate over the evidence window, when scorecards are computed, then reliability/latency regressions are visible and recommendation state can be changed by an admin.
- [ ] CA 13: Given a provider is recommended as `preferred`, when live generation runs, then no automatic provider switch happens unless an explicit allowlisted rollout policy exists.
- [ ] CA 14: Given logs and Flutter diagnostics are inspected after benchmark runs, then no provider keys, signed Bunny URLs, provider polling URLs, full private prompts or raw provider payloads appear.
- [ ] CA 15: Given BYOK OpenRouter usage is recorded, when managed PAYG summaries are viewed, then BYOK usage is separated from operator-paid provider spend.
- [ ] CA 16: Given cost telemetry feeds PAYG review, when actual provider cost and user-facing units differ, then both are visible as distinct fields and neither overwrites the other.
- [ ] CA 17: Given max-run-cost guardrail would be exceeded, when an admin starts a benchmark run, then backend blocks before provider calls.
- [ ] CA 18: Given official provider docs are refreshed, when the cost catalog changes, then future runs cite the new catalog version while old runs retain historical source metadata.

## Test Strategy

- Backend model tests for telemetry events, benchmark run/result shapes, cost evidence, quality rubric, recommendation states and redacted admin responses.
- Store tests with SQLite/libSQL-compatible clients for schema initialization, benchmark persistence, idempotent run start, scorecard aggregation, recommendation history and pricing catalog staleness.
- Service tests for cost catalog lookup, actual vs estimated cost, stale catalog block, BFL credit conversion, megapixel estimates and unknown-cost fallback.
- Telemetry tests for production Image Robot events, BYOK separation, no full prompt logging, missing project quarantine and duplicate event idempotency.
- Benchmark runner tests with mocked provider adapters for success, partial failure, timeout, max-run-cost block, Bunny upload failure and sample visibility.
- FastAPI route tests for admin capability, non-admin rejection, list/start/get runs, submit rating, update recommendation, scorecards and pagination.
- Flutter model/API tests for admin capability, scorecards, partial runs, redacted samples, cost freshness and recommendation updates.
- Flutter provider/widget tests for internal admin surface, filters, run polling, quality rating, non-admin state and mobile/desktop layout.
- Manual QA: run a small image benchmark fixture against a mocked or staging provider, review samples, rate quality, update recommendation to monitor, confirm creator editor remains unchanged.

## Risks

- Cost risk: benchmarks can burn provider credits. Mitigate with admin-only access, max-run-cost guardrails, suite size limits and staging mocks by default.
- Privacy risk: production prompts/assets can leak through telemetry. Mitigate with prompt hashes, redaction, admin-only samples and no full private prompt storage by default.
- Product risk: users may expect model choice if benchmark UI leaks. Mitigate by keeping it admin-only and not adding creator-facing provider controls.
- Decision risk: quality scores can be subjective. Mitigate with explicit rubric, multiple signal sources and no automatic provider switching.
- Provider drift risk: prices and APIs change. Mitigate with versioned catalog, freshness checks and stale-catalog gates.
- Data model risk: `api_cost_log`, usage ledger and benchmark telemetry can diverge. Mitigate by keeping sources distinct and aggregating read-only summaries.
- Security risk: provider metadata may contain sensitive URLs or ids. Mitigate with normalized/redacted payloads and explicit forbidden fields in tests.
- Scope risk: adding FAL/Prodia/xAI directly from the prototype would create provider sprawl. Mitigate by starting with integrated providers and adding candidate adapters only through explicit review.

## Execution Notes

- Read first:
  - `contentglowz/v0-ai-image-generation-benchmark/lib/types.ts`
  - `contentglowz/v0-ai-image-generation-benchmark/app/api/generate-single/route.ts`
  - `lab/status/cost_tracker.py`
  - `lab/api/services/image_generation_store.py`
  - `lab/api/services/flux_image_generation.py`
  - `lab/api/routers/images.py`
  - `shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md`
- Implementation order: backend models, store, cost catalog, telemetry recorder, Flux instrumentation, benchmark runner, admin API, app admin models/provider/UI, docs.
- Provider policy V1: instrument current Flux/BFL first. Do not add FAL, Prodia, xAI, OpenAI or ElevenLabs adapters in this implementation unless explicitly approved in `/sf-ready` or a follow-up spec.
- Quality policy V1: combine admin rubric scores and workflow outcome signals; do not introduce an automated LLM/image judge as authority.
- Recommendation policy V1: recommendations are advisory states; provider switching remains manual/config-gated.
- Validation commands expected after implementation:
  - `python3 -m pytest tests/test_ai_provider_benchmark_models.py tests/test_ai_provider_telemetry_store.py tests/test_ai_provider_benchmark_runner.py tests/test_ai_provider_benchmarks_router.py`
  - `flutter test test/data/ai_provider_benchmark_test.dart test/providers/ai_provider_benchmark_provider_test.dart test/presentation/ai_provider_benchmark_admin_screen_test.dart`
- Stop and reroute if implementation requires public benchmark UI, arbitrary provider marketplace, automatic provider switch, full private prompt retention, live-provider tests in CI, hard-coded current prices without source version, or checkout/pricing changes.
- Fresh external docs verdict: `fresh-docs checked` for BFL, fal, OpenRouter and ElevenLabs provider cost/usage evidence on 2026-05-12. Refresh docs before adding hard-coded provider price tables or new provider adapters.

## Open Questions

None blocking for this draft. Assumptions captured for readiness: V1 is admin/internal only; V1 instruments Flux/BFL image generation first; quality uses admin rubric plus workflow outcome signals; provider recommendations are advisory and do not automatically switch live jobs; future FAL/OpenRouter/ElevenLabs adapters require explicit approval.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-12 20:35:56 UTC | sf-spec | GPT-5 Codex | Created internal spec for provider benchmark, cost/latency/quality telemetry and provider-choice evidence from contentglowz benchmark inspiration, repo scan and official provider docs. | Draft saved. | /sf-ready AI Provider Benchmark Cost Quality Telemetry |

## Current Chantier Flow

- sf-spec: done
- sf-ready: not launched
- sf-start: not launched
- sf-verify: not launched
- sf-end: not launched
- sf-ship: not launched

Prochaine commande: `/sf-ready AI Provider Benchmark Cost Quality Telemetry`
