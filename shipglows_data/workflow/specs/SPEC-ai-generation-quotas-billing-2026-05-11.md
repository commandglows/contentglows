---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.7"
project: "contentglows"
created: "2026-05-11"
created_at: "2026-05-11 15:02:22 UTC"
updated: "2026-08-20"
updated_at: "2026-08-21 13:12:20 UTC"
status: active
source_skill: sf-spec
source_model: "gpt-5.5"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que créatrice connectée à ContentGlows, je veux voir et respecter mes droits de génération IA avant de lancer des images, rendus ou uploads coûteux, afin de produire sans surprise de blocage ni coût opérateur non contrôlé."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "site"
  - "Image Robot"
  - "Flux/BFL"
  - "Bunny CDN"
  - "Remotion"
  - "Turso/libSQL"
  - "Clerk"
  - "OpenRouter BYOK"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/PRD-lifetime-deal-early-bird-payg.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/site/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Flux Image Robot spec explicitly scopes out V1 billing, quotas, and plan limits beyond provider cost metadata."
  - "Flux Image Robot spec requires authenticated-only access, project ownership, queue/job limits, provider timeout, input size limits, reference count limits, and normalized provider rate-limit handling as abuse controls."
  - "Official BFL FLUX.2 Pro API docs were checked on 2026-05-11 and return nullable cost/input_mp/output_mp fields."
  - "Lifetime Deal BYOK PRD says the product must not promise unlimited AI consumption and should separate platform access from variable provider usage."
  - "Strict BYOK spec says app-visible LLM actions use the requesting user's OpenRouter key; non-LLM services such as Bunny remain server-managed."
  - "lab/status/cost_tracker.py already persists estimated external API costs by project, job, job_type, pipeline, mode, provider, and time range."
  - "lab/api/services/job_store.py persists async jobs in Turso but does not store user_id/org_id or quota reservation data."
  - "app/lib/data/services/api_service.dart already maps structured API error envelopes with code, kind, provider, settingsPath, and retryable."
  - "app/lib/presentation/screens/settings/integrations_screen.dart already mentions BYOK versus ContentGlows-managed credits in AI runtime copy."
  - "site/src/components/Pricing.astro currently states that all plans include AI generation costs and no hidden fees, which may conflict with BYOK/PAYG and future managed-credit packaging."
  - "User decision 2026-05-11: quota enforcement must hard-block before provider calls when managed usage is insufficient."
  - "User decision 2026-05-11: future commercial model is pay-as-you-go for managed AI generation."
  - "User decision 2026-05-11: Lifetime Deal covers platform access with BYOK, not included operator-paid managed AI usage."
  - "User decision 2026-05-11: failed provider attempts should refund user-facing usage."
  - "User decision 2026-05-11: quota and PAYG limits are scoped by user."
  - "Official Turso/libSQL sources checked on 2026-08-20 document explicit BEGIN/COMMIT/ROLLBACK transactions, immediate write transactions, and Python connection commit semantics."
  - "Official Black Forest Labs API reference checked on 2026-08-21 documents submit-response cost in provider credits plus nullable input_mp and output_mp fields."
next_step: "/sf-start AI Generation Quotas, Billing, And Cost Controls"
---

# Title

AI Generation Quotas, Billing, And Cost Controls

## Status

Ready. This chantier defines the implementation foundation for usage accounting, entitlement checks, provider-cost tracking, quota enforcement, user-visible PAYG state, recoverable billing/quota errors, and admin/ops controls for managed AI generation. Product direction is fixed for V1: hard backend block before paid provider calls, pay-as-you-go managed usage, Lifetime Deal as platform/BYOK access without included managed AI credits, refund/release user-facing usage when the provider attempt fails, and user-scoped limits with project attribution. Exact customer-facing prices, checkout, invoices, taxes, public package names, and alert thresholds are explicitly out of scope for this chantier.

## User Story

En tant que créatrice connectée à ContentGlows, je veux voir et respecter mes droits de génération IA avant de lancer des images, rendus ou uploads coûteux, afin de produire sans surprise de blocage ni coût opérateur non contrôlé.

Secondary operator story: en tant qu'opératrice ContentGlows, je veux suivre les coûts Flux/Bunny/Remotion et agir sur les abus ou crédits problématiques, afin de protéger la marge, la disponibilité et les utilisateurs légitimes.

## Minimal Behavior Contract

When an authenticated user starts a managed AI generation action such as Flux image generation, future Remotion rendering, or a quota-governed upload/render step, ContentGlows resolves the user's PAYG entitlement/balance, estimates or reserves the required usage, checks user-scoped limits and abuse limits, and either creates a recoverable queued job with visible usage state or hard-blocks before any paid provider call. On completion, the system records actual provider cost and consumed units, reconciles reservations, and updates the app-facing usage display. If the provider fails, user-facing usage is refunded/released according to an auditable policy. The easy edge case to miss is concurrency: two simultaneous jobs must not both pass a limit check against stale remaining credits.

## Success Behavior

- Given a signed-in user with sufficient managed generation entitlement, when they request a Flux image generation from an owned project, then the backend creates a quota reservation before submitting to Flux and returns a job/generation response containing quota status, reservation id, estimated cost/units, and next polling path.
- Given the provider succeeds and Bunny upload succeeds, when the worker completes, then the usage ledger records actual consumed units, provider cost metadata, Bunny storage/transfer estimate when available, project/user scope, and links to the job/generation record.
- Given the provider exposes actual cost metadata, when reconciliation runs, then ContentGlows stores both estimated and actual cost without trusting client-sent cost fields.
- Given a user's quota is near exhaustion, when the app loads generation controls, then the UI shows remaining quota/credits, reset or renewal state if applicable, and disables or warns on actions that cannot be started.
- Given a quota block occurs, when the app receives the API response, then it displays a recoverable explanation with structured code, retryable flag, and an actionable destination to the existing AI runtime/settings surface or support/admin request flow; checkout links are not required by this chantier.
- Given admin/ops reviews usage, when they inspect a user/project/org, then they can see quota state, recent reservations, actual provider spend, failed/refunded jobs, manual overrides, and abuse flags.
- Given BYOK LLM actions run through the user's OpenRouter key, when they are outside managed provider billing, then they are tracked separately as BYOK usage metadata and are not charged against PAYG managed Flux/Bunny/Remotion usage.
- Given existing V1 abuse controls are still enabled, when quotas are added, then authenticated-only access, project ownership, queue limits, provider timeouts, input size limits, reference count limits, and normalized rate-limit handling remain active.

## Error Behavior

- If authentication is missing or invalid, return the existing Clerk `401` path before quota or provider logic.
- If the project is missing or not owned by the current user, return `403` or `404` using existing ownership conventions and do not reveal whether a quota exists for another tenant.
- If PAYG balance or managed usage entitlement is insufficient, return a structured `402` or `409` style error according to the chosen API convention, with code such as `ai_quota_exhausted`, provider/action metadata, current remaining units, required units if known, `retryable: false`, and no provider call.
- If a per-minute/day abuse or concurrency limit is hit, return `429` with `ai_generation_rate_limited`, retry-after metadata when available, and no paid provider call.
- If reservation succeeds but the job cannot be queued, release the reservation before returning failure.
- If the provider call starts and then fails before producing a durable Bunny asset, mark the reservation `released` or `refunded` for user-facing usage while preserving provider-cost evidence when operator spend occurred.
- If provider cost metadata is absent or malformed, store `actual_cost_unknown` and keep estimated cost separate; do not invent pricing from stale docs.
- If Bunny upload fails after Flux success, do not expose a temporary provider URL as a durable asset. The usage record must show provider spend occurred, no durable user asset was delivered, and the user-facing reservation remains released/refunded rather than consumed.
- If reconciliation runs twice, it must be idempotent and must not double-consume or double-refund credits.
- What must never happen: client-trusted credits, negative user-facing balances, cross-user/project/org usage leakage, paid provider calls after a hard quota block, raw provider secrets in logs, or silent "unlimited" usage for operator-paid providers.

## Problem

Flux Image Robot V1 intentionally excludes quota and billing enforcement while adding an operator-paid provider path with potentially material variable cost. ContentGlows also has BYOK commitments for app-visible LLM actions and existing copy that mixes subscription, BYOK, and "AI generation costs included" claims. The chosen direction is PAYG managed usage on top of platform/BYOK access; without a separate quota/billing/cost-control layer, future AI image generation, rendering, upload processing, and video workflows can create margin risk, inconsistent user promises, unclear refund behavior, and poor recoverability when users hit limits.

## Solution

Add a backend-owned entitlement and usage ledger that gates managed AI generation actions before paid provider calls, reserves PAYG usage atomically, reconciles actual provider cost after job completion, releases/refunds user-facing usage when the provider attempt fails, and exposes quota/balance state to the Flutter app and admin/ops surfaces. The implementation uses configurable internal managed-usage units and policy fixtures; exact customer-facing prices, payment-provider choices, invoices, taxes, public package names, and top-up purchase UX stay outside this chantier while the enforcement and accounting surface is made ready for them.

## Scope In

- Entitlement model for managed AI generation actions, including Flux image generation and future-compatible Remotion render/upload cost controls.
- Internal `managed_usage_unit` accounting for reservations, limits, refunds, and summaries. This is a configurable technical unit, not final public pricing terminology.
- Usage ledger with reservations, consumption, refunds/releases, provider cost metadata, and audit trail.
- Limit checks by user, with project recorded for attribution and org/workspace scope included only if the product introduces organizations before implementation.
- Preflight quota endpoint or response fields so the app can show current generation availability before a user starts a job.
- Backend enforcement before paid provider calls for Flux/BFL, Bunny-intensive upload/processing steps, and future Remotion render jobs.
- Actual-cost capture from Flux/BFL metadata where available, including cost/input_mp/output_mp fields.
- Estimated-cost capture for providers that do not return exact cost, with source and confidence marked.
- Recoverable API error envelope compatible with existing `ApiException` fields: `code`, `kind`, `provider`, `settingsPath`, `retryable`.
- Admin/ops APIs and minimal UI contract for viewing usage, reservations, costs, overrides, and suspicious usage.
- Documentation updates for pricing copy, BYOK/managed-credit distinction, environment variables, ops playbook, and user support language.
- Test coverage for atomic reservation, concurrency, provider failure, refund/retry policy, ownership, and app error mapping.

## Scope Out

- Choosing exact public plan names, public prices, PAYG unit price, included quantities if any, credit packs, overage price, currency, invoice wording, taxes, dunning, or minimum charge.
- Deciding final customer-facing terminology for PAYG units. Internally this chantier uses `managed_usage_unit` so enforcement can be implemented without committing public pricing language.
- Implementing checkout, Stripe/Polar integration, invoices, tax, accounting, payment recovery, or dunning.
- Changing the Flux Image Robot V1 provider implementation except where future integration points need to be named.
- Enforcing monetary quotas on BYOK OpenRouter LLM calls. BYOK flows may still have non-monetary abuse/rate limits, but they do not consume ContentGlows-managed PAYG units in this chantier.
- Anonymous/free public generation.
- Enterprise contract management, custom SLA, procurement workflows, or manual invoicing.
- Full data warehouse/BI pipeline; the first version may expose operational summaries from Turso/libSQL.

## Constraints

- Backend is the source of truth for entitlement, reservation, consumption, refund, and admin override state.
- The Flutter app may display usage and request actions, but it must never decide whether a paid provider call is allowed.
- All usage records must be scoped to authenticated Clerk user id and project id. Org/workspace id may be nullable until the product has a real org model.
- Quota enforcement must happen before paid provider submission, not only after job completion.
- Reservations must be atomic enough to prevent concurrent overspend.
- Provider cost fields are evidence, not entitlement; a user cannot increase allowance by sending cost data.
- BYOK OpenRouter remains separate from ContentGlows-managed provider spend unless an explicit future business decision changes that.
- Existing abuse controls from the Flux spec remain required even when paid quotas exist.
- Pricing values from BFL/Bunny/Remotion docs are not hard-coded as business truth; provider price tables must be configurable and reviewable.
- If a provider does not expose exact cost, estimates must include provider, model/action, pricing table version, and confidence.
- The implementation must avoid adding a new database stack; use existing Turso/libSQL patterns.

## Dependencies

- Existing Flux foundation spec: `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`.
- Existing BYOK/product framing: `shipglows_data/workflow/specs/app/PRD-lifetime-deal-early-bird-payg.md`.
- Existing BYOK enforcement spec: `shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md`.
- Existing async persistence: `lab/api/services/job_store.py`.
- Existing provider error-normalization pattern: `lab/api/routers/publish.py`.
- Existing auth dependency: `lab/api/dependencies/auth.py`.
- Existing project ownership helpers in `lab/api/dependencies/ownership.py` and project store patterns.
- Existing cost table and helpers: `lab/status/cost_tracker.py` and `lab/api/migrations/004_status_lifecycle.sql`.
- Existing Flutter API error envelope parsing: `app/lib/data/services/api_service.dart`.
- Existing Riverpod provider wiring: `app/lib/providers/providers.dart`.
- Existing app AI runtime/BYOK copy: `app/lib/presentation/screens/settings/integrations_screen.dart`.
- Existing marketing pricing copy: `site/src/components/Pricing.astro`.
- Project language guidelines: `shipglows_data/technical/lab/guidelines.md`, `shipglows_data/technical/app/guidelines.md`, and `shipglows_data/technical/site/guidelines.md`.
- External docs freshness: `fresh-docs checked` for BFL FLUX.2 Pro on 2026-05-11. Official BFL API docs show the submit response includes nullable `cost`, `input_mp`, and `output_mp` fields. Bunny pricing, Remotion rendering pricing, and checkout provider docs are `fresh-docs not needed` for this chantier because exact provider price tables, render hosting pricing, and payment collection are out of scope; if a later implementation task adds hard-coded prices, checkout, invoices, taxes, or Remotion-specific billing, that work must run a new freshness check first.

## Invariants

- No paid managed provider call starts without an authenticated user, an owned project, and a successful entitlement decision.
- Each billable or quota-governed action has exactly one canonical usage event chain: requested, reserved, provider_started, completed/failed, consumed/released/refunded.
- Usage can be aggregated by user and project from day one; org/workspace aggregation is included only when a durable org id exists.
- Reservation and reconciliation are idempotent.
- Usage ledger records are append-friendly and auditable; destructive edits require an admin override record.
- Provider spend and user-facing credits are separate fields. One is operational cost; the other is product entitlement.
- Job status and usage status can diverge temporarily but must be reconcilable.
- The app must be able to explain quota blocks without inspecting raw provider errors.
- Admin overrides must name actor, reason, scope, amount/limit, expiry when applicable, and affected ledger entry.
- Docs and pricing copy must not promise "unlimited" or "all AI included"; Lifetime Deal is platform/BYOK access, and managed AI is PAYG.

## Links & Consequences

- `lab/api/services/job_store.py`: current jobs table lacks user/project indexes for quota reservation and owner-scoped queries. The future implementation may need a schema extension or a separate `ai_generation_jobs`/`usage_reservations` table instead of overloading `data`.
- `lab/status/cost_tracker.py`: existing `api_cost_log` is useful for operational cost summaries but is too DataForSEO-shaped for quota enforcement. The new ledger should either extend it carefully or create a dedicated `ai_usage_ledger` while continuing to feed cost summaries.
- `lab/api/routers/images.py`: Flux generation must call the quota service before provider submission and reconcile after completion.
- `lab/api/services/flux_image_generation.py`: should return normalized actual-cost metadata when BFL exposes it.
- `lab/agents/images/cdn_manager.py` and Bunny tools: upload/storage/optimizer usage may need cost events or estimates, especially for large uploads and generated variants.
- Future Remotion integration: render seconds, concurrency, output size, and failed renders must use the same reservation/reconciliation model.
- `app/lib/data/services/api_service.dart`: should add typed usage/quota models and preserve structured error mapping.
- `app/lib/providers/providers.dart`: should expose current quota/credit state, generation preflight state, and stale/refresh behavior through Riverpod.
- `app/lib/presentation/screens/settings/integrations_screen.dart`: existing AI runtime copy already distinguishes BYOK and managed credits, but it needs real usage state and actions.
- `site/src/components/Pricing.astro`: current "All plans include AI generation costs" copy is a product risk and must be revised before managed provider quotas are marketed.
- Analytics/ops: cost summaries become decision support for pricing and abuse response; logs must be useful without leaking user secrets or prompts unnecessarily.
- Support: quota and billing errors need stable codes so support can diagnose without raw database access.
- Language doctrine: stable ShipGlowz headings, acceptance criteria, stop conditions, metadata keys, and internal contracts remain in English. User-facing French copy must use natural accented French. Product copy must not mix BYOK, managed credits, and PAYG terminology casually in one visible sentence.

## Documentation Coherence

- Update product/pricing docs to distinguish BYOK usage, managed credits/PAYG usage, included plan limits if later approved, overages if later approved, and operator-paid provider costs without inventing exact prices in this chantier.
- Update `site/src/components/Pricing.astro` before launch of any managed-credit promise; current copy conflicts with the BYOK/PAYG strategy and future quota controls.
- Update `lab` environment/setup docs with required provider cost config, usage ledger migration, admin override env/roles, and reconciliation job behavior.
- Update app support/help copy for quota exhausted, payment required, rate limited, provider failed, retry available, and refund pending states.
- Add an ops playbook for manual adjustments, refund/retry review, anomalous spend, provider price changes, and cost reconciliation failures.
- Add changelog/release notes when enforcement moves from draft to active because user-visible generation availability will change.
- Language coherence: preserve English machine-stable section headings and code identifiers; use French with accents for user-facing app/site/support copy in this project context.

## Security And Abuse Requirements

- Authentication: only a valid Clerk-authenticated user can request managed AI preflight, reservation, generation, usage history, or user-scoped quota summaries.
- Authorization: project ownership must be checked server-side before entitlement details, reservations, usage history, or generation jobs are returned. Admin/ops endpoints require an explicit admin authorization dependency; if the repo lacks one when implementation reaches admin APIs, stop and create or attach an admin-auth spec.
- Input validation: prompts, image references, upload sizes, action names, model ids, project ids, pagination, date ranges, and admin adjustment amounts are untrusted. Use allowlisted action policies and existing Flux/Bunny limits; never trust client-sent units, costs, provider names, or plan ids.
- Workflow integrity: reservations, consumption, release, refund, stale-expiry, and admin adjustments must be idempotent and must reject replay or double-submission attempts that would double-consume or double-refund user-facing usage.
- Data exposure: user-visible responses may expose their own remaining units, reservation status, and support-safe cost state; they must not expose other users' balances, raw provider secrets, raw prompts in operator logs, or cross-tenant provider spend.
- Secrets and configuration: BFL, Bunny, Clerk, OpenRouter, and future payment secrets stay server-side and out of logs, ledger payloads, client models, and admin export views.
- External integrations: BFL/Bunny/Remotion metadata is evidence for reconciliation only. It cannot expand entitlement, override ownership, or authorize a provider call.
- Logging and errors: log request ids, user id, project id, action, reservation id, provider request id when safe, state transition, and error code. Do not log raw API keys, webhook secrets, signed asset URLs, or full prompt/reference payloads unless a separate privacy policy allows it.
- Availability and abuse: keep existing authenticated-only access, queue limits, provider timeouts, input size limits, reference count limits, rate-limit handling, and add user-scoped quota/rate checks before paid provider submission.
- Multi-tenant boundary: all entitlement, reservation, ledger, job, and admin views are scoped by Clerk user id plus project id, with nullable org id only for future migration.

## Edge Cases

- Two or more generation requests are submitted simultaneously and each appears affordable alone; only atomic reservation can prevent overspend.
- A job reserves credits, then the worker crashes before provider submission; reservation must expire or be released by reconciliation.
- A provider succeeds, but Bunny upload fails; provider cost exists but the user did not receive a durable asset.
- Provider returns `cost` but currency, billing basis, or precision changes; record raw metadata and pricing table version.
- Provider rate limit returns before any charge; quota should not be consumed, but abuse/rate counters may increment.
- User changes plan or receives admin credits while jobs are pending.
- User deletes a project with pending reservations or historical usage.
- A refund is granted after actual provider spend; user-facing entitlement and operator cost diverge intentionally.
- BYOK OpenRouter key is missing for LLM flows while managed Flux credits are available; the app must explain the correct missing resource.
- Lifetime Deal user has platform access but no operator-paid AI entitlement unless the offer explicitly includes it.
- Free/trial user tries to upload very large references or trigger many renders; upload/rate abuse controls must still work even if paid credits exist.
- Org/workspace support arrives later; historical user/project usage must remain attributable and migratable.
- A provider call times out locally but later completes remotely; reconciliation must use provider/job ids to avoid both exposing an orphan asset and issuing a double refund.
- A malicious client replays an old reservation id against a different project or action; the backend must reject mismatched user/project/action/scope before any state transition.

## Implementation Tasks

- [x] Task 1: Define the AI usage domain models
  - File: `lab/api/models/ai_usage.py`
  - Action: Add Pydantic models/enums for `AIUsageAction`, `AIUsageScope`, `AIEntitlement`, `AIUsageReservation`, `AIUsageLedgerEntry`, `AIQuotaStatus`, `AIQuotaError`, and provider-cost metadata.
  - User story link: Gives backend and app a shared language for available generation rights and recoverable errors.
  - Depends on: none.
  - Validate with: model validation tests for Flux image, Bunny upload, Remotion render, BYOK metadata, and quota error envelopes.
  - Notes: Do not encode plan prices or included quantities here. Code authored on 2026-08-20; automated execution remains deferred by the operator's no-local-build policy.

- [x] Task 2: Create durable ledger and entitlement store
  - Files: `lab/api/services/ai_usage_store.py`, `lab/api/services/libsql_ai_usage_store.py`
  - Action: Define a persistence-agnostic `AIUsageStore` port, then implement an injected-client libSQL adapter with dedicated tables for entitlements, reservations, ledger entries, provider cost rows, and admin adjustments.
  - User story link: Makes quota state auditable and resilient across API restarts.
  - Depends on: Task 1.
  - Validate with: reusable adapter-contract tests for insert, list by user/project/org, idempotent schema setup, identity conflicts, provider-cost projections, and adjustment audit fields.
  - Notes: The domain port exposes only validated usage models and stable store errors; schema lifecycle and the database client remain adapter-owned. Dedicated tables preserve `api_cost_log` as an operational cost source rather than turning it into the enforcement ledger. Code authored on 2026-08-20; automated execution remains deferred by the operator's no-local policy.

- [x] Task 3: Add atomic reservation and reconciliation service
  - Files: `lab/api/services/ai_usage_service.py`, `lab/api/services/ai_usage_store.py`, `lab/api/services/libsql_ai_usage_store.py`, `lab/utils/libsql_async.py`
  - Action: Implement storage-agnostic preflight, reserve, mark_provider_started, consume, release, refund, expire_stale_reservations, and summarize usage. Express state changes as domain compare-and-set mutations; execute each entitlement/reservation/ledger/projection change in one serialized libSQL transaction.
  - User story link: Prevents simultaneous jobs from exceeding managed credits or limits.
  - Depends on: Task 2.
  - Validate with: reusable atomic adapter-contract tests plus focused concurrent reservation, idempotent reconciliation, stale expiry, tenant isolation, conflicting evidence, and negative-balance tests.
  - Notes: The domain service and store port contain no database client or SQL dependency. The adapter uses an injected transaction-capable client, `BEGIN IMMEDIATE`, payload compare-and-set predicates, rollback, and idempotency recovery; official Turso/libSQL sources document those transaction primitives. Code authored on 2026-08-20; repository-specific transaction behavior and tests remain unexecuted under the operator's no-local policy, so this task is implemented — unverified rather than verified.

- [x] Task 4: Define configurable action policies without choosing pricing
  - Files: `lab/api/services/ai_usage_policies.py`, `lab/tests/test_ai_usage_policies.py`
  - Action: Add an injected, immutable policy registry with typed resolution for action type, billing mode, provider, model, estimated internal `managed_usage_unit` amount, hard-limit behavior, provider-failure release/refund behavior, and admin override eligibility.
  - User story link: Allows PAYG enforcement to work without baking public prices into code.
  - Depends on: Task 3.
  - Validate with: authored tests for illustrative free/creator/pro-style fixtures, duplicate and unknown actions, missing policy resolution, and unsafe managed/BYOK combinations, without asserting real business prices.
  - Notes: The registry reads no environment or persistence state and exposes no price or currency field. Fixture names, providers, models, and unit values are illustrative; exact customer-facing commercial packages stay out of scope. Code authored on 2026-08-21; automated execution remains deferred by the operator's no-local policy, so this task is implemented — unverified.

- [x] Task 5: Gate Flux image generation before provider calls
  - Files: `lab/api/routers/images.py`, `lab/api/dependencies/ai_usage.py`, `lab/api/models/images.py`, `lab/api/services/image_generation_store.py`
  - Action: Lazily compose the usage service only for managed Flux, resolve the injected Flux policy, reserve units after auth/project/reference validation but before generation/job/task creation, attach the reservation id to generation and job metadata, and return quota state in the app-facing response.
  - User story link: Blocks unaffordable AI images before operator spend happens.
  - Depends on: Tasks 1-4 and the Flux provider implementation.
  - Validate with: authored API tests for enough quota, exhausted quota with no generation/provider task, foreign-project rejection before quota lookup, reservation linkage, and release when durable generation creation fails. Existing app-wide `429` rate limiting and provider `429` normalization remain covered by their existing paths.
  - Notes: Managed enforcement is fail-closed when database or policy configuration is absent/invalid. Runtime policy values are deployment-owned internal units supplied through configuration, not public prices. Robolly and OpenAI do not initialize the managed-usage runtime. Code authored on 2026-08-21; automated execution remains deferred by the operator's no-local policy, so this task is implemented — unverified.

- [x] Task 6: Capture Flux/BFL actual-cost metadata
  - Files: `lab/api/models/ai_usage.py`, `lab/api/services/flux_image_generation.py`
  - Action: Distinguish monetary costs from provider credits, then normalize BFL `cost`, `input_mp`, `output_mp`, model, request id, UTC timing fields, and duration into provider-cost metadata returned on success and retained on post-submit errors.
  - User story link: Lets users and ops compare estimated usage with actual provider spend.
  - Depends on: Task 5.
  - Validate with: authored mocked BFL responses for complete provider-credit evidence, missing cost, malformed/negative/non-finite values, submit error, and post-submit provider failure retaining known cost evidence.
  - Notes: Official BFL documentation identifies `cost` as credits, so the domain contract records `provider_credit` and forbids attaching a currency. No conversion table or customer-facing price is encoded. Code authored on 2026-08-21; automated execution remains deferred by the operator's no-local policy, so this task is implemented — unverified.

- [x] Task 7: Reconcile usage after Bunny upload and job completion
  - Files: `lab/api/routers/images.py`, `lab/api/services/image_generation_store.py`, `lab/api/models/images.py`
  - Action: Persist reservation id, estimated units, typed provider-cost evidence, Bunny asset metadata, quota state/outcome, reconciliation timestamp, and error code. Mark provider start immediately before BFL, consume only after a validated durable Bunny URL, and release/refund failures through the configured policy.
  - User story link: Ensures the visible generation history matches ledger state.
  - Depends on: Tasks 5-6.
  - Validate with: authored store/worker tests for durable Bunny success before consumption, provider-start settlement selection, Bunny failure refund without consumption, interrupted settlement remaining recoverable, durable reconciliation fields, and existing idempotent usage-service settlement contracts.
  - Notes: A durable asset with failed quota or history closure remains explicitly `reconciliation_pending`; it is never silently refunded after consumption. Temporary provider URLs are rejected as non-durable. Code authored on 2026-08-21; automated execution and schema application remain deferred by the operator's no-local policy, so this task is implemented — unverified.

- [ ] Task 8: Extend job metadata for owner-scoped quota operations
  - File: `lab/api/services/job_store.py`
  - Action: Add explicit user_id, project_id, org_id nullable, reservation_id, and cost-control status fields or document a separate job linkage table if direct migration is too risky.
  - User story link: Allows users and operators to inspect pending generation jobs and recover stuck reservations.
  - Depends on: Task 2.
  - Validate with: job store migration tests and owner-scoped query tests.
  - Notes: Preserve existing job consumers; do not break deployment/content-generation jobs.

- [ ] Task 9: Add usage/quota API routes
  - File: `lab/api/routers/ai_usage.py`
  - Action: Add authenticated endpoints for current quota summary, action preflight, usage history, pending reservations, and app-visible policy metadata. Add admin endpoints only behind an explicit admin authorization check.
  - User story link: Powers UI state before generation and gives support/ops visibility.
  - Depends on: Tasks 1-4 and Task 8.
  - Validate with: route tests for user isolation, project isolation, admin-only access, structured errors, and no secret leakage.
  - Notes: Use `require_current_user` and existing ownership helpers.

- [ ] Task 10: Add admin/ops adjustment and override flow
  - File: `lab/api/routers/admin_ai_usage.py`
  - Action: Add admin-only APIs for granting credits/units, setting temporary overrides, refunding failed jobs, viewing high-cost users/projects, and adding audit reasons.
  - User story link: Lets operators resolve support cases and abuse safely.
  - Depends on: Task 9.
  - Validate with: admin auth tests, non-admin rejection tests, adjustment audit tests, and idempotent refund tests.
  - Notes: If no admin role system is ready, implementation must stop and create/attach an admin-auth spec.

- [ ] Task 11: Wire Flutter usage models and API methods
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add typed methods for usage summary, action preflight, usage history, and quota-aware generation responses/errors.
  - User story link: Allows the app to show quota state and recoverable error actions.
  - Depends on: Task 9.
  - Validate with: Dart unit tests for JSON parsing, quota error mapping, retryable flags, and stale/offline behavior.
  - Notes: Reuse existing `ApiException` envelope fields.

- [ ] Task 12: Expose quota state through Riverpod
  - File: `app/lib/providers/providers.dart`
  - Action: Add providers/notifiers for AI usage summary, per-action preflight, refresh after generation completion, and stale state handling.
  - User story link: Keeps generation buttons, settings, and history in sync.
  - Depends on: Task 11.
  - Validate with: provider tests or smallest practical widget/provider tests.
  - Notes: Avoid making offline cache imply quota is current for paid actions.

- [ ] Task 13: Add app UI contract for generation state and quota errors
  - File: `app/lib/presentation/screens/settings/integrations_screen.dart`
  - Action: Show managed PAYG/BYOK state, current quota summary, error states, and entry points for existing AI runtime/settings or support/admin request flows. Do not add checkout UX in this chantier.
  - User story link: Makes generation limits visible before the user hits a hard block.
  - Depends on: Task 12.
  - Validate with: manual app smoke for enough quota, exhausted quota, BYOK missing, and provider failure.
  - Notes: Dedicated Image Robot UI files may be added by the Flux UI chantier; this task names settings as the existing place where AI runtime copy lives.

- [ ] Task 14: Update marketing and support copy
  - File: `site/src/components/Pricing.astro`
  - Action: Replace or conditionalize "All plans include AI generation costs" and align plan claims with the approved model: Lifetime Deal/platform access plus BYOK, with managed AI as PAYG and no promise of included operator-paid credits.
  - User story link: Prevents users from buying under a promise the product cannot enforce economically.
  - Depends on: Product decisions captured in this spec.
  - Validate with: content review and site build.
  - Notes: Do not invent exact public prices or plan quantities.

- [ ] Task 15: Add provider cost configuration documentation
  - File: `lab/README.md`
  - Action: Document provider-cost config, cost metadata sources, quota enforcement sequence, reconciliation job, admin override rules, and support error codes.
  - User story link: Makes the system operable and explainable.
  - Depends on: Tasks 1-10.
  - Validate with: doc review against implemented env vars/routes.
  - Notes: Include Flux/Bunny/Remotion freshness-check instructions for implementation time.

## Acceptance Criteria

- [ ] CA 1: Given a signed-in user owns a project and has enough managed AI entitlement, when they request a Flux image, then a reservation is created before the provider call and the API returns job/generation metadata with quota status.
- [ ] CA 2: Given a signed-in user has no remaining hard-limit entitlement, when they request a managed Flux image, then the backend returns a structured quota error and no Flux request is sent.
- [ ] CA 3: Given two concurrent requests would exceed remaining quota together, when they are submitted, then at most one reserves successfully and the other receives a quota/rate error.
- [ ] CA 4: Given Flux succeeds and Bunny upload succeeds, when the job completes, then the ledger records consumed units, actual provider cost metadata when available, and the generation record links to the ledger/reservation.
- [ ] CA 5: Given Flux fails before a durable asset is produced, when reconciliation runs, then the reservation is released/refunded for user-facing usage and the outcome is visible in usage history.
- [ ] CA 6: Given Bunny upload fails after provider success, when the job completes as failed, then provider spend is recorded separately from user-facing refund/consume state.
- [ ] CA 7: Given a provider returns malformed or missing cost metadata, when completion is reconciled, then actual cost is marked unknown and estimated cost remains auditable.
- [ ] CA 8: Given a BYOK OpenRouter flow is triggered, when managed AI credits exist, then the BYOK missing/invalid key error remains separate from managed-credit quota errors.
- [ ] CA 9: Given a user tries to inspect another user's project usage, when the request is made, then the backend rejects it without leaking usage or entitlement state.
- [ ] CA 10: Given an admin grants or refunds credits, when the adjustment is applied, then an audit record stores actor, reason, scope, amount, and linked job/reservation when applicable.
- [ ] CA 11: Given the app loads AI runtime/settings, when quota data is available, then it shows current managed-credit state and distinguishes it from BYOK OpenRouter state.
- [ ] CA 12: Given quota data is stale/offline, when the user attempts a paid managed action, then the app does not assume cached quota authorizes the action; backend remains authoritative.
- [ ] CA 13: Given pricing copy is rendered on the public site, when managed quotas launch, then copy no longer promises unlimited or all-included AI costs and states the BYOK/platform versus PAYG-managed-AI distinction without inventing exact prices.
- [ ] CA 14: Given the reconciliation job is run twice for the same provider success, when both executions complete, then usage is consumed only once.
- [ ] CA 15: Given a stale reservation has passed its expiry without provider start, when cleanup runs, then it is released and visible as expired in admin/ops history.

## Test Strategy

- Backend unit tests for policy resolution, unit estimation, quota error envelopes, and provider-cost normalization.
- Backend store tests against SQLite/libSQL-compatible DB for migrations, atomic reservation, idempotent reconciliation, admin adjustments, and stale reservation expiry.
- Backend router tests for auth, project ownership, quota preflight, generation block, successful reservation, and admin-only access.
- Mocked provider tests for Flux success with cost metadata, Flux success without cost metadata, rate limit, safety rejection, timeout, and invalid output.
- Integration-style tests for Flux generation lifecycle: reserve, queue, provider_started, Bunny upload success/failure, consume/release/refund.
- Flutter unit tests for API parsing, `ApiException` mapping, quota status models, BYOK versus managed-credit errors, and retryable action labels.
- Flutter provider/widget smoke tests for settings/AI runtime state and generation button disabled/error states where the final UI lives.
- Manual ops QA with seeded users/projects: enough quota, exhausted quota, admin grant, admin refund, suspicious high-cost project, and stale reservation cleanup.
- Documentation review comparing pricing/site copy against the accepted product decisions captured in this spec.

## Risks

- High financial risk if provider calls can start before atomic quota reservation.
- High product risk if pricing copy promises unlimited or included AI while the backend enforces credits.
- High support risk if implementation diverges from the provider-failure release/refund rule or leaves post-provider durable-asset failures unexplained in usage history.
- Security risk if usage/admin endpoints leak cross-tenant cost or project information.
- Data integrity risk if `api_cost_log` is reused for enforcement without a separate immutable ledger.
- Concurrency risk because Turso/libSQL transaction behavior must be verified for reservation semantics.
- UX risk if BYOK errors and managed-credit errors look identical.
- Provider risk because BFL/Bunny/Remotion pricing and metadata can change; configs and docs need freshness checks at implementation time.
- Abuse risk remains even with paid credits; authenticated attackers can still use stolen accounts or payment abuse.

## Execution Notes

- Read these files first when implementing: `lab/status/cost_tracker.py`, `lab/api/services/job_store.py`, `lab/api/dependencies/auth.py`, `app/lib/data/services/api_service.dart`, and the current Flux implementation files.
- Start with the backend ledger and atomic reservation service before touching UI. UI state without enforcement creates false safety.
- Keep public pricing values out of code. Use configurable policy fixtures and explicit names such as `managed_image_generation_default`; the only required unit for this chantier is internal `managed_usage_unit`.
- Do not trust client-sent units, costs, provider names, or plan ids. The backend resolves all entitlement and cost policy.
- Preserve BYOK separation from the strict BYOK spec. User OpenRouter costs are not ContentGlows-managed credits by default.
- Freshness gate for this chantier: current official BFL docs were checked on 2026-05-11 and support nullable `cost`, `input_mp`, and `output_mp` response metadata. Bunny pricing, Remotion rendering cost model, and checkout provider docs are intentionally out of scope unless implementation adds hard-coded pricing, Remotion-specific billing enforcement, checkout, invoices, taxes, or dunning.
- Stop and create a separate admin-auth spec if no reliable admin authorization model exists when Task 10 begins.
- Stop and reroute to architecture review if libSQL cannot support safe atomic reservation semantics in the deployed environment.
- Language doctrine: preserve English stable headings, metadata keys, task/AC structure, and technical identifiers; write any French user-facing copy with accents and no casual English/French mixing.

## Product Decisions Captured

- Managed AI generation is pay-as-you-go.
- Quota/balance enforcement is a hard backend block before paid provider calls.
- Lifetime Deal users get platform access with BYOK; operator-paid managed AI usage is separate.
- Failed provider attempts refund/release user-facing usage.
- Quotas and PAYG limits are scoped by user; project attribution is still stored for reporting.

## Open Questions

None for this implementation-ready enforcement foundation. Exact public prices, payment collection, invoices, taxes, top-up purchase UX, public package names, final customer-facing unit terminology, and ops alert thresholds are intentionally in `Scope Out`; they require separate product/commercial specs before launch copy or checkout work.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 15:02:22 UTC | sf-spec | gpt-5.5 | Created draft spec for future AI generation quotas, billing, and cost controls. | Draft saved with product decisions captured as Open Questions. | `/sf-ready shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md` |
| 2026-05-11 15:38:45 UTC | sf-spec | GPT-5 Codex | Integrated product decisions for hard quota block, PAYG, LTD/BYOK separation, refund-on-failure, and user-scoped limits. | Draft updated; remaining blockers narrowed to unit/pricing/checkout/retry/ops details. | `/sf-ready shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md` |
| 2026-05-11 16:03:00 UTC | sf-ready | GPT-5 Codex | Ran strict readiness gate, resolved non-blocking commercial questions into Scope Out, clarified enforcement/refund/security/docs contracts, and checked BFL freshness evidence. | Ready. | `/sf-start AI Generation Quotas, Billing, And Cost Controls` |
| 2026-08-20 08:35:06 UTC | 001-sg-build | GPT-5 Codex | Implemented Task 1 domain contracts for managed/BYOK usage, entitlements, reservations, ledger events, quota states/errors, provider-cost evidence, and guarded reservation transitions, with focused validation tests. | Code authored; Python AST and diff integrity checks pass. Automated tests intentionally not run because the operator prohibited local builds, tests, and artifacts. | Run the focused model tests in authorized CI before starting the durable ledger/store task. |
| 2026-08-20 18:35:45 UTC | sg-development | GPT-5 Codex | Implemented Task 2 as a persistence-agnostic store port plus an injected-client libSQL adapter and reusable adapter-contract tests. | Implemented — unverified. Static boundary review and diff integrity pass; no build, test, analyzer, migration, or runtime workload was executed under the operator's no-local policy. | Implement Task 3 by extending the agnostic port with atomic compare-and-set reservation transitions after confirming the adapter transaction contract. |
| 2026-08-20 19:15:54 UTC | sg-development | GPT-5 Codex | Implemented Task 3 with storage-agnostic quota decisions, atomic domain mutations, serialized libSQL transactions, compare-and-set concurrency control, idempotent reconciliation, stale expiry, and focused contract tests. | Implemented — unverified. Static contract/diff review only; no build, test, analyzer, migration, provider call, or runtime workload was executed under the operator's no-local policy. | Run the focused store/service tests in an authorized environment before integrating configurable action policies in Task 4. |
| 2026-08-21 07:37:04 UTC | sg-development | GPT-5 Codex | Implemented Task 4 as an injected immutable action-policy registry with typed managed/BYOK invariants, provider/model routing metadata, internal usage-unit estimates, hard blocking, failure reconciliation behavior, and admin-override eligibility. | Implemented — unverified. Static contract/diff review only; no build, test, analyzer, provider call, or runtime workload was executed under the operator's no-local policy. | Run the focused policy tests in an authorized environment before wiring Flux preflight in Task 5. |
| 2026-08-21 11:40:54 UTC | sg-development | GPT-5 Codex | Implemented Task 5 with lazy runtime composition, owner-scoped Flux reservation before durable queue/provider work, structured quota errors, reservation linkage, configured model routing, and release on pre-queue failure. | Implemented — unverified. Static contract/diff review only; no build, test, analyzer, migration, provider call, background job, or runtime workload was executed under the operator's no-local policy. | Run focused route/store tests in an authorized environment before implementing provider-cost normalization in Task 6. |
| 2026-08-21 11:54:45 UTC | sg-development | GPT-5 Codex | Implemented Task 6 with explicit provider-credit cost units, strict BFL cost/megapixel normalization, unknown-cost evidence, request identifiers, UTC timing, duration, and evidence retention across post-submit failures. | Implemented — unverified. Static contract/diff review only; no build, test, analyzer, provider call, background job, or runtime workload was executed under the operator's no-local policy. | Run focused model/provider tests in an authorized environment before reconciling reservations and durable assets in Task 7. |
| 2026-08-21 13:12:20 UTC | sg-development | GPT-5 Codex | Implemented Task 7 with provider-start tracking, durable-Bunny consumption gating, policy-driven release/refund, provider-cost evidence persistence, explicit reconciliation outcomes, and recoverable pending states. | Implemented — unverified. Static contract/diff review only; no build, test, analyzer, schema application, provider/CDN call, background job, or runtime workload was executed under the operator's no-local policy. | Run focused store/worker tests in an authorized environment before extending owner-scoped job metadata and recovery queries in Task 8. |

## Current Chantier Flow

sf-spec ✅ -> sf-ready ✅ -> sf-start ◐ Tasks 1-7 code authored, execution deferred; Flux reservations now reconcile against durable Bunny outcomes -> sf-verify ⏳ -> sf-end ⏳ -> sf-ship ⏳
