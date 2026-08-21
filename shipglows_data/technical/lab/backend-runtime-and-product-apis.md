---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "1.3.0"
project: lab
created: "2026-06-29"
updated: "2026-08-21"
status: reviewed
source_skill: sf-docs
scope: technical
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - FastAPI
  - Turso/libsql
  - Clerk
  - Remotion
  - Bunny
  - Google Search Console
  - Black Forest Labs
evidence:
  - lab/README.md
  - api/routers/
  - api/services/
  - api/routers/brand_profiles.py
  - api/models/brand_profile.py
  - api/models/ai_usage.py
  - api/services/ai_usage_service.py
  - api/services/ai_usage_policies.py
  - api/services/libsql_ai_usage_store.py
  - api/routers/ai_usage.py
  - api/migrations/005_video_timelines.sql
  - shipglows_data/technical/lab/architecture.md
depends_on:
  - shipglows_data/technical/lab/README.md
  - shipglows_data/technical/lab/architecture.md
  - shipglows_data/technical/worker/architecture.md
supersedes: []
next_review: "2026-09-29"
next_step: /sf-docs technical audit lab
---

# Backend Runtime and Product APIs

## Purpose

Preserve the durable backend contracts that were previously documented in `lab/README.md` before local docs were reduced to compatibility facades.

## Owned Files

- `api/routers/`
- `api/services/`
- `api/migrations/`
- `scheduler/`
- `status/`
- `agents/`

## Entrypoints

- `doppler run -- uvicorn api.main:app --reload --port 8000`
- `curl http://localhost:8000/health`
- Swagger: `http://localhost:8000/docs`
- Redoc: `http://localhost:8000/redoc`

## Runtime Notes

- `api/main.py` owns startup/shutdown lifecycle hooks and background scheduler initialization.
- Sentry initializes at API import time when `SENTRY_DSN` is set.
- `SENTRY_SEND_DEFAULT_PII` defaults to `false`.
- `SENTRY_TRACES_SAMPLE_RATE` defaults to `0.0`.
- `/health` exposes only redacted Sentry status: configured state, environment, release, and dist.
- CORS and authentication middleware are configured for Flutter, site, and dashboard clients.
- `ecosystem.config.cjs` describes the documented manual runtime setup; the hosted deployment provider is intentionally not asserted here.

## Production API Domain Migration

The public API should resolve to `https://api.contentglows.com`. `https://api.winflowz.com` may remain a temporary alias during DNS/client migration.

Migration checklist:

- Point DNS for `api.contentglows.com` to the server currently serving the Lab API.
- Keep Clerk validation aligned in production secrets:
  - `CLERK_JWT_ISSUER`
  - `CLERK_JWKS_URL`
  - optional aliases only if used: `CLERK_ISSUER`, `CLERK_AUDIENCE`, `CLERK_JWT_AUDIENCE`
- Keep the legacy API alias until all clients are rebuilt.
- Rebuild/redeploy clients with `API_BASE_URL=https://api.contentglows.com`.
- Verify `curl -i https://api.contentglows.com/health` returns FastAPI health JSON, not a Vercel `DEPLOYMENT_NOT_FOUND` response.

PM2 and live server mutation remain operator-only.

## Google Search Console OAuth

Required environment variables:

- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `GOOGLE_OAUTH_REDIRECT_URI` optional override; router callback URL is the fallback

Operational rules:

- Enable Google Search Console API in the Google Cloud project.
- Configure OAuth consent screen and callback at `/api/search-console/oauth/callback`.
- Search Console tokens are encrypted at rest.
- Search Console tokens must never be returned by API responses.

## Project Intelligence V1

Project Intelligence is project-scoped memory and recommendation infrastructure.

Routes:

- `GET /api/projects/{project_id}/intelligence/status`
- `POST /api/projects/{project_id}/intelligence/upload`
- `POST /api/projects/{project_id}/intelligence/sync`
- `GET /api/projects/{project_id}/intelligence/jobs`
- `GET /api/projects/{project_id}/intelligence/sources`
- `DELETE /api/projects/{project_id}/intelligence/sources/{source_id}`
- `GET /api/projects/{project_id}/intelligence/documents`
- `GET /api/projects/{project_id}/intelligence/facts`
- `GET /api/projects/{project_id}/intelligence/recommendations`
- `GET /api/projects/{project_id}/intelligence/provider-readiness`
- `POST /api/projects/{project_id}/intelligence/recommendations/{recommendation_id}/idea-pool`

V1 ingestion constraints:

- max 10 files per upload job
- max 10 MB per file
- text-like formats only: `text/plain`, `text/markdown`, `text/csv`, `application/json`, `text/html`, and markdown-like extensions
- one active ingestion/sync job per `userId + projectId`

Operational behavior:

- Deterministic cleaning, chunking, dedupe, and fact extraction work without AI credentials.
- Optional AI synthesis preflight routes through `ai_runtime_service`; intelligence routes/services must not read provider env directly.
- Source removal excludes derived evidence from reads and recommendation/Idea Pool actions.
- Startup ensures intelligence tables via `project_intelligence_store.ensure_tables()` when Turso is configured.
- Provider readiness is advisory metadata only. V1 does not auto fine-tune or deploy providers.

## Unified Project Asset Library

Project assets are backend-owned, project-scoped inventory for editor and generation workflows. This is not a public DAM, marketplace, arbitrary URL importer, or free provider playground.

Current backend routes live under `/api/projects/{project_id}/assets`:

- `GET /` lists owned project assets with filters for `media_kind`, `source`, `include_tombstoned`, `limit`, and `offset`.
- `GET /{asset_id}` returns one owned asset with a client-safe `storage_descriptor`; raw `storage_uri` is not returned as client authority.
- `GET /{asset_id}/usage` returns active usage links.
- `GET /{asset_id}/events` returns the asset audit/history stream.
- `POST /{asset_id}/eligibility` checks whether a guided action can use an asset without mutating usage state.
- `POST /{asset_id}/select` creates a usage link after server-side asset and target ownership validation.
- `POST /{asset_id}/primary` creates a primary usage link and clears previous primary state for the same target and placement.
- `POST /clear-primary` clears primary state for a target and placement.
- `POST /{asset_id}/preview-refresh` returns a refreshed safe descriptor; it does not sign or upload binaries.
- `POST /{asset_id}/tombstone` blocks future reuse while preserving history.
- `POST /{asset_id}/restore` restores a tombstoned asset within the retained metadata window.
- `GET /cleanup-report` reports tombstones eligible for cleanup, degraded assets, and active assets missing storage metadata. Physical deletion is not enabled by default.

Security and retention rules:

- Every route requires Clerk auth and project ownership.
- Asset selection validates both the asset and target server-side before mutation; Flutter state is not a permission boundary.
- `local_only`, degraded, tombstoned, stale, foreign, provider-temporary, or incompatible assets cannot be selected for publish, render, or reference actions.
- Tombstoned assets keep readable provenance for the 30-day history window and are hidden from default list calls.
- Storage descriptors redact signed query tokens and provider URLs.
- Bunny upload, delete, and signing remain owned by upload or media-generation features.

## Social Placement Registry and Publish Media Contract

The backend owns the versioned format, platform, and placement vocabulary. Stable IDs are persisted and never translated or silently renamed. V1 includes `FMT_*` content formats, `PLAT_*` platforms and these placement IDs: `PLC_BLOG_HERO`, `PLC_INLINE_IMAGE`, `PLC_SOCIAL_POST_IMAGE`, `PLC_LINK_THUMBNAIL`, `PLC_VIDEO_THUMBNAIL`, `PLC_VERTICAL_SHORT_VIDEO`, `PLC_LANDSCAPE_VIDEO`, `PLC_REEL_COVER`, `PLC_CAPTION_TRACK`, and `PLC_AUDIO_TRACK`.

Authenticated routes:

- `GET /api/placement-registry?locale=en|fr` returns the complete localized registry and immutable registry version.
- `GET /api/content/{content_id}/placement-plan?platform=<value>` resolves an owned content item, canonical format/platform aliases, and required or recommended slots. Repeated `platform` query values are supported.
- `POST /api/publish/preflight` authorizes the content project and each publish account, resolves primary `project_asset_usages` server-side, and returns per-platform readiness, stable issue codes, sanitized slot summaries, and no storage URL.

New publish clients send `media_contract_version="asset_placements.v1"`. In this contract, `media` and `media_urls` are rejected with `PFL_LEGACY_CONFLICT`; the backend selects only canonical primary usages for the owned content and placement. Assets must be active, owner-scoped, media-compatible, and backed by a durable Bunny delivery descriptor. Blocking issues prevent every provider call.

The provider adapter sends Zernio `mediaItems`, built only from server-resolved token-free Bunny URLs. Each logical create-post attempt persists one UUID and sends it as `x-request-id`; reconciliation retries reuse it, and an `existingPost` response is treated as the original result. Publish metadata records stable asset/placement/platform IDs, registry version, media contract, sanitized media types and normalized provider results. It does not persist raw legacy URLs, signed delivery URLs, provider payloads, account IDs, auth tokens or provider error bodies.

Legacy compatibility is isolated: omitting `media_contract_version` while sending `media` or `media_urls` uses the raw-URL path only. Inputs must be public HTTP(S) image/video URLs, are never mixed with asset usages, and metadata records only `mediaContract="legacy_raw_urls"` plus a count and media types. New Flutter code must not use this path.

Registry rule provenance is platform-specific and versioned. Instagram numeric constraints remain advisory until direct official Meta documentation is refreshed; media-required behavior can still block when independently confirmed.

## Video Timeline and Remotion Rendering

The canonical roadmap for advanced visual editing is `shipglows_data/workflow/specs/monorepo/SPEC-professional-video-editor-capability-roadmap-2026-08-09.md` (Filmora/PixVerse-inspired, one-canonical-timeline stack, no second rendering engine).

## Brand Profiles and Canonical Branded Generation

Brand profiles are authenticated, project-scoped rule records. They provide saved visual and editorial defaults for future branded-video generation; they are not timelines, renderer props, or a second render engine.
For execution, a profile is resolved into a versioned brand template (blueprint) before assembly.

Authenticated routes live under `/api/brand-profiles`:

- `GET /api/brand-profiles?projectId=<id>` lists profiles only after project ownership succeeds.
- `POST /api/brand-profiles` creates a profile for an owned project.
- `GET`, `PATCH`, and `DELETE /api/brand-profiles/{brand_profile_id}` read or mutate only an owned profile.
- `GET /api/brand-video-blueprints` accepts `projectId` and optional `brandProfileId` to return active/resolved blueprints for the same project scope.
- A profile includes its `revision`, `is_default` state, and saved colors, font, logo, tone, CTA, caption, motion, transition, and intro/outro rule values.

One project can have multiple profiles but only one default. Deleting the current default is rejected with `409`; clients must explicitly set another profile as default first. A save changes later generation inputs only: it must not rewrite a timeline draft or requalify a generation already in progress.

The only brand-impact preview route is `POST /api/video-timelines/from-content/branded-generate`. It accepts an owned `content_id` with optional saved `brand_profile_id`, `blueprint_id`, `format_preset`, `trigger_source`, and `client_request_id`, and returns the canonical generation/timeline response with template provenance (`brand_profile_id`, blueprint identity/revision, resolved template fields used). Flutter uses this route from Branding after choosing completed content, then navigates to the canonical video editor for optional review. Neither Flutter nor the branding API creates a local render model.

The canonical video timeline lives in `lab`, not in Remotion or Flutter. The backend owns validation, immutable versions, asset eligibility, preview/final job gates, and signed artifact URLs. Remotion is an internal renderer adapter behind `worker`.

Timeline API routes live under `/api/video-timelines`:

- `POST /from-content` creates or loads the active timeline for an owned content item.
- `GET /{timeline_id}` returns the draft, latest version, and preview/final state.
- `PATCH /{timeline_id}/draft` saves a mutable draft with optimistic revision checks.
- `POST /{timeline_id}/versions` validates the draft, resolves render-safe assets, stores immutable renderer props, and records `video_version` asset usages.
- `POST /{timeline_id}/versions/{version_id}/preview` creates a preview job for the exact current version.
- `POST /{timeline_id}/versions/{version_id}/preview/{preview_job_id}/approve` approves a completed non-stale preview.
- `POST /{timeline_id}/versions/{version_id}/render-final` creates a final job only from the approved preview for that version.
- `GET /{timeline_id}/jobs/{job_id}` refreshes status and returns a short-lived signed artifact URL when completed.

Operational requirements:

- Turso/libSQL schema includes `api/migrations/005_video_timelines.sql`.
- Startup also ensures timeline tables and indexes idempotently.
- Required render env vars follow the worker contract:
  - `REMOTION_WORKER_URL`
  - `REMOTION_WORKER_TOKEN`
  - `CONTENTGLOWS_RENDER_DIR`
  - `RENDER_ARTIFACT_SIGNING_KEY`
- `BUNNY_CDN_HOSTNAME` is required when timeline assets are stored as `bunny://` URIs.
- Durable Bunny HTTP URLs are normalized without query strings before being sent to Remotion props.
- Provider-temporary, local-only, tombstoned, degraded, missing, foreign, or incompatible assets are rejected before version creation.
- Final render is blocked until the exact version has an approved completed preview.

## AI Asset Understanding Guardrails

Asset understanding/tagging is asynchronous and suggestion-only. It helps users find media; it does not auto-publish, auto-clear rights, or replace editor decisions.

Provider rules:

- BYOK is resolved first from the user credential store.
- Optional platform fallback may use `GEMINI_API_KEY` or `OPENAI_API_KEY` when enabled.
- If no credential is available, jobs return `provider_not_configured` and assets stay usable without AI tags.
- `ffprobe` and `ffmpeg` should be available on workers for deterministic media inspection.

Default guardrails, environment-overridable:

- `ASSET_UNDERSTANDING_MAX_IMAGE_BYTES`: 25 MB
- `ASSET_UNDERSTANDING_MAX_SOURCE_VIDEO_BYTES`: 500 MB
- `ASSET_UNDERSTANDING_MAX_SOURCE_VIDEO_SECONDS`: 1800 seconds
- `ASSET_UNDERSTANDING_MAX_PROVIDER_VIDEO_SECONDS`: 90 seconds
- `ASSET_UNDERSTANDING_MAX_PROVIDER_FRAMES`: 180
- `ASSET_UNDERSTANDING_MAX_AUDIO_SECONDS`: 120 seconds
- `ASSET_UNDERSTANDING_CONCURRENCY_PER_PROJECT`: 2
- `ASSET_UNDERSTANDING_CONCURRENCY_PER_USER`: 4
- `ASSET_UNDERSTANDING_DAILY_PLATFORM_QUOTA_IMAGES`: 100
- `ASSET_UNDERSTANDING_DAILY_PLATFORM_QUOTA_VIDEOS`: 25
- `ASSET_UNDERSTANDING_DAILY_BYOK_QUOTA_IMAGES`: 250
- `ASSET_UNDERSTANDING_DAILY_BYOK_QUOTA_VIDEOS`: 50

Privacy, retention, and attribution:

- Treat software-demo media as potentially sensitive because it may contain PII, tokens, or customer UI.
- Keep durable metadata minimal.
- Avoid storing raw OCR dumps, full transcripts, and provider raw payloads as user-facing truth.
- Preserve attribution for external/social assets via source attribution, creator URL, and credit text.
- Unknown rights must surface warnings.
- AI tags are suggestions until user acceptance.
- Low-confidence tags should not dominate recommendations.

## Image Robot AI Generation

Image Robot supports guided AI image generation through Black Forest Labs FLUX without adding a free-form playground. The entrypoint remains the existing profile workflow.

Routes and behavior:

- `POST /api/images/generate-from-profile` accepts `image_provider=flux` via a system or custom profile and queues async generation.
- Built-in Flux profiles cover blog hero, article section, social card, and thumbnail placements.
- `GET /api/images/generations?project_id=...` lists durable AI generation history.
- `GET /api/images/generations/{id}` returns one generation record.
- `GET /api/images/references`, `POST /api/images/references`, `PATCH /api/images/references`, and `DELETE /api/images/references` manage approved project visual references.
- Flux receives only same-project approved references, capped at 8.
- Successful Flux outputs are downloaded from BFL temporary signed result URLs, uploaded to Bunny CDN, persisted in `ImageGeneration`, and registered as project assets with source `image_robot`.

Required environment:

- `BFL_API_KEY`
- optional `BFL_IMAGE_MODEL`, default `flux-2-pro`
- optional `BFL_API_BASE_URL`, default `https://api.bfl.ai/v1`
- optional `BFL_SAFETY_TOLERANCE`, default `2`, server-side only

Startup ensures `ImageGeneration` and `ImageReference` tables when Turso is configured. If FLUX or Turso is not configured, the API returns an explicit error instead of falling back to Robolly/OpenAI.

## Managed AI Usage and Provider-Cost Controls

This subsystem accounts for internal usage units and provider-cost evidence. It
does not define public prices, checkout, invoices, taxes, or plan packaging.
Managed enforcement currently wraps the Flux path end to end. Other action
names can be configured and inspected, but they must not be described as
provider-enforced until their own call paths reserve and settle usage.

### Runtime configuration

The runtime is composed lazily. Non-managed routes do not require quota
configuration. A managed route fails closed with `503` when any required value
is absent or invalid:

- `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` select the durable libSQL store.
- `AI_USAGE_POLICIES_JSON` is a JSON list with exactly one policy per action.
- `AI_USAGE_RESERVATION_TTL_SECONDS` defaults to `900` and must be between `60`
  and `3600` seconds.

Policy fields:

- `action`: `flux_image_generation`, `bunny_upload`, `remotion_render`, or
  `byok_metadata`.
- `billing_mode`: `managed` or `byok`.
- `estimated_units`: internal decimal units, never a currency or public price.
- `limit_behavior`: currently only `hard_block`.
- `provider_failure_behavior`: `release` or `refund`.
- `provider` and `model`: required for managed policies and forbidden for BYOK
  metadata.
- `admin_override_eligible`: policy metadata only; it does not grant authority
  or expose an override route.

For the currently enforced Flux path, use provider `flux`, a configured model,
positive `estimated_units`, `hard_block`, and `refund`. Before provider start,
failed work releases reserved units. After provider start, `refund` returns the
user-facing units while retaining any provider-cost evidence. The example in
`lab/.env.example` deliberately keeps `estimated_units` as `REPLACE_ME`; a
deployment owner must choose internal units before enabling managed traffic.

A BYOK metadata policy must use action `byok_metadata`, zero units, no provider
or model, and no admin override eligibility. BYOK calls do not create managed
reservations or consume managed units.

The lazy runtime ensures its dedicated entitlement, reservation, ledger,
provider-cost, and adjustment tables. This is schema initialization, not proof
that an entitlement exists. There is currently no supported public or admin API
for granting managed units; privileged quota mutation remains disabled pending
the separate platform-admin security proof. Do not seed, edit, or repair quota
tables manually.

### Enforcement sequence

The Flux path applies this order:

1. authenticate the user and verify project ownership;
2. resolve the server-owned action policy and required units;
3. atomically reserve units before queueing or calling BFL;
4. persist the reservation on the generation and generic job records;
5. mark `provider_started` immediately before the provider call;
6. capture provider-cost evidence from the BFL submit response;
7. upload the completed output to a durable Bunny URL;
8. consume units only after durable delivery;
9. release before provider start, or refund after provider start when the
   policy requires it;
10. retain `reconciliation_pending` when settlement or history persistence is
    interrupted.

Reservations and settlements are idempotent and scoped by user plus project.
Compare-and-set store mutations prevent concurrent double spend. A reservation
TTL does not itself run cleanup: `expire_stale_reservations` exists in the
service, but no production scheduler is currently wired to call it. Pending
states therefore require inspection and an authorized reconciliation path;
they must not be reported as automatically healed.

### Provider-cost evidence

BFL `cost`, `input_mp`, and `output_mp` values are normalized without currency
conversion. Evidence records include:

- provider `bfl`, action, model, and provider request ID;
- `actual_cost` when BFL supplies it, with `cost_unit=provider_credit`;
- input/output megapixels when supplied;
- confidence `exact` when cost exists, otherwise `unknown` with no fabricated
  value;
- an aware UTC capture timestamp and explicit unknown-value flags.

Provider credits are not euros or dollars. Never convert them to money without
a separately versioned pricing source. Raw provider responses, keys, signed
URLs, and secrets are not part of the app-visible policy projection.

Before enforcing `bunny_upload` or `remotion_render`, re-check the current
official provider billing contract and record its retrieval date, unit,
currency or credit semantics, rounding, minimums, and missing-value behavior.
Then add a normalized cost adapter, immutable evidence tests, reserve-before-
spend wiring, and idempotent settlement on that exact call path. A policy entry
alone does not make either action enforced. For Flux, repeat the same freshness
check before changing model routing or interpreting BFL credits; never reuse an
old pricing table as current truth.

### Authenticated read routes

All routes require authentication. Project routes verify ownership before
reading runtime state:

- `GET /api/ai-usage/summary?project_id=<id>` returns server-resolved status for
  every configured policy.
- `POST /api/ai-usage/preflight` accepts only `projectId` and `action`; clients
  cannot choose required units.
- `GET /api/ai-usage/history?project_id=<id>&event=<event>&limit=<1..100>`
  returns the scoped ledger.
- `GET /api/ai-usage/reservations/pending?project_id=<id>&limit=<1..100>`
  returns `reserved` and `provider_started` reservations.
- `GET /api/ai-usage/policies` returns action, billing mode, estimated units,
  limit behavior, and failure behavior. Provider, model, and override metadata
  stay private.

There are no admin mutation routes in this subsystem. Capability names in the
platform-admin model are contracts, not proof that quota grants, refunds, or
overrides are callable.

### Support and reconciliation guide

Structured quota errors use these stable codes:

- `ai_quota_exhausted`: managed balance is below required units; HTTP `402`,
  not retryable without an entitlement change.
- `ai_entitlement_missing`: no active matching entitlement; HTTP `402`, not
  retryable until entitlement state changes.
- `ai_reservation_conflict`: concurrent reservation state changed; HTTP `409`,
  retryable after refreshing current state.
- `ai_usage_scope_invalid`: user/project/org scope is invalid; do not retry
  until the caller scope is corrected.
- `ai_generation_rate_limited`: wait for the supplied retry window when this
  code is emitted by a provider-integrated action.

Configuration failures currently return a plain `503` detail rather than a
structured quota envelope. `provider_not_configured` identifies missing BFL
credentials on Flux generation and must not be treated as exhausted quota.

For a support case:

1. confirm the authenticated project and action;
2. read summary, history, and pending reservations through the owner-scoped
   routes;
3. correlate `reservationId`, `jobId`, provider request ID, quota status, and
   provider-cost confidence without copying secrets or signed URLs;
4. distinguish provider failure from quota rejection and from
   `reconciliation_pending`;
5. never edit balances directly or claim a refund succeeded from a failed job
   status alone.

The service settlement operations are replay-safe only when invoked through an
authorized, scope-checked reconciliation flow with matching evidence. Until
the admin/reconciliation route and its security proof exist, escalate pending
mutations rather than changing durable records manually.

## Project Selection Contract

- Active project selection for a signed-in user is persisted in `UserSettings.projectSelectionMode` and `UserSettings.defaultProjectId`.
- `projectSelectionMode` supports `auto`, `selected`, and `none`.
- `GET /api/me` and `GET /api/bootstrap` resolve project context from that pair.
- `none` returns no default project.
- `selected` uses only the explicit `defaultProjectId` if it is still active.
- `auto` uses the explicit default first, then falls back to the first active project.
- `Project.isDefault` may still exist in stored rows for backward compatibility, but it is no longer the source of truth for Flutter routing.
- Project create/update payloads now use canonical `source_url`; legacy `github_url` and `url` aliases remain accepted.

Supported project routes used by the app:

- `GET /api/projects`
- `POST /api/projects`
- `GET /api/projects/{id}`
- `PATCH /api/projects/{id}`
- `POST /api/projects/{id}/archive`
- `POST /api/projects/{id}/unarchive`
- `DELETE /api/projects/{id}`
- `POST /api/projects/onboard`
- `POST /api/projects/{id}/analyze`
- `POST /api/projects/{id}/confirm`

`DELETE /api/projects/{id}` marks rows as deleted with `deletedAt`; it does not physically remove rows.

## Link Management and Affiliate Redirects

Link management expands the affiliations CRM into an active shortener, click telemetry, and A/B destination rotation surface.

### Schema

`AffiliateLink` gains a `slug TEXT` column with a unique `(userId, slug)` partial index. Slugs are stored lowercase and must be unique per user.

Two new tables are introduced by `api/migrations/008_link_management.sql`:

- `LinkClick` — one row per public redirect: `id`, `linkId`, `userId`, `projectId`, `slug`, `destinationUrl`, `variantIndex`, `country`, `device`, `referrer`, `userAgent`, `createdAt`.
- `LinkVariant` — A/B rotation and targeting rules per link: `id`, `linkId`, `userId`, `url`, `weight`, `country`, `device`, `language`, `createdAt`, `updatedAt`.

### Public redirect

- `GET /r/{slug}` — unauthenticated.
- Returns `302` to the active `AffiliateLink.url`.
- If `LinkVariant` rows exist for the link, one is selected by weight, then by `country`/`device` targeting when headers match; otherwise falls back to weighted random.
- Logs one `LinkClick` row with `country` from `cf-ipcountry`/`x-country`, `device` parsed from `user-agent`, and `referer`.
- Returns `404` when the slug is missing, the link is not `active`, or `expiresAt` is in the past.

### Authenticated analytics and variants

Routes live under `/api/links` and require Clerk auth plus ownership checks:

- `GET /api/links/clicks?linkId=...&limit=...&offset=...` — raw click events for an owned link.
- `GET /api/links/clicks/summary?linkId=...` — aggregated totals plus top `countries`, `devices`, `referrers`, and 30-day `daily` series.
- `POST /api/links/variants?linkId=...` — create a variant with `url`, `weight`, optional `country`/`device`/`language`.
- `GET /api/links/variants?linkId=...` — list variants for an owned link.
- `PUT /api/links/variants/{variant_id}` — update variant fields.
- `DELETE /api/links/variants/{variant_id}` — remove a variant.

### Flutter surface

- `AffiliateLink` gains `slug`, `clickCount`, `variants`, `isExpired`, and `shortLink`.
- `affiliation_form_sheet.dart` exposes a `slug` input.
- `affiliations_screen.dart` shows an expired badge, disables tap when expired, and displays `slug` plus click count.
- New API methods: `fetchLinkClicks`, `fetchLinkClickSummary`, `createLinkVariant`, `fetchLinkVariants`, `updateLinkVariant`, `deleteLinkVariant`.

## Link Webhooks, Conversions, and UTM Templates

### Webhooks

Authenticated routes under `/api/webhooks/links`:

- `POST /` creates a webhook with `url`, optional `secret`, `events` list, and `enabled` flag. Default events: `["link.clicked"]`.
- `GET /` lists webhooks for the authenticated user, optionally filtered by `projectId`.
- `GET /{webhook_id}` returns one owned webhook.
- `PATCH /{webhook_id}` updates `url`, `secret`, `events`, or `enabled`.
- `DELETE /{webhook_id}` removes a webhook.
- `GET /{webhook_id}/deliveries` returns recent delivery attempts with status code, request/response bodies, and errors.

Public receiver:

- `POST /r/webhooks/public/{webhook_id}` accepts inbound webhook payloads, validates the webhook exists and is enabled, forwards the request to the stored `url`, and records the delivery result in `LinkWebhookDelivery`.

### Conversions

Authenticated routes under `/api/links/conversions`:

- `POST /` records a conversion event for an owned link. Payload includes `linkId`, `type` (`lead`/`sale`/`custom`), optional `revenue`, `currency`, `partnerId`, and arbitrary `metadata`.
- `GET /?linkId=...` lists conversions for an owned link.
- `GET /summary?linkId=...` returns aggregated totals: `totalConversions`, `totalRevenue`, and breakdown `byType`.

### UTM Templates

Authenticated routes under `/api/utm`:

- `POST /` creates a named UTM template with optional `utmSource`, `utmMedium`, `utmCampaign`, `utmTerm`, `utmContent`.
- `GET /` lists templates for the authenticated user, optionally filtered by `projectId`.
- `PATCH /{template_id}` updates template fields.
- `DELETE /{template_id}` removes a template.

UTM templates are intended for campaign standardization; they do not automatically mutate existing links unless explicitly applied during link creation or update flows.

## Remotion Render Artifacts

`lab` remains the authenticated boundary for video preview/final renders. Flutter polls backend render jobs and receives `artifact.playback_url`; it never calls the Remotion worker, Cloud Run, or GCS directly.

Local mode uses the existing HMAC-protected artifact route backed by `CONTENTGLOWS_RENDER_DIR`. Production mode uses a private GCS bucket:

- `CONTENTGLOWS_RENDER_STORAGE=gcs`
- `REMOTION_WORKER_URL`
- `REMOTION_WORKER_TOKEN`
- `GCS_RENDER_BUCKET`
- `GCS_RENDER_PREFIX`, default `renders`
- `GCS_SIGNED_URL_TTL_SECONDS`, default `3600`

The backend persists the deterministic expected object key before dispatching a render. If worker memory loses a completed job after restart, the backend can reconcile from the expected GCS object; if the object is missing, the job fails with `render_artifact_unavailable` and no playback URL is returned.

Signed GCS playback URLs are bearer-like secrets. Do not copy query strings such as `X-Goog-Signature` into support tickets, diagnostics, or logs.

## Reader Checklist

- Read this file before changing project intelligence, project assets, brand profiles, branded generation, video timeline, render artifact, image generation, GSC OAuth, project-selection, link management, affiliate redirects, webhooks, conversion tracking, UTM templates, or link behavior.
- Cross-check worker render behavior with `shipglows_data/technical/worker/architecture.md`.
- Update this file when a README-local backend contract would otherwise be reintroduced.

## Maintenance Rule

Keep durable backend API and runtime contracts here or in a narrower `shipglows_data/technical/lab/*` module. Local `lab/README.md` stays a facade only.
