---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-07-08"
created_at: "2026-07-08 00:00:00 UTC"
updated: "2026-07-09"
updated_at: "2026-07-09 00:00:00 UTC"
status: ready
source_skill: 100-sg-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlowz authentifiee, je veux que mes videos branded soient preparees en amont et exposees au feed avec un etat simple prete, en cours ou bloquee, afin de swiper sur des contenus deja fabriques au lieu de lancer la preparation au dernier moment."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "worker"
  - "Turso/libSQL"
  - "Unified ContentGlowz Video Timeline"
  - "publish accounts"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "User direction 2026-07-08: videos should be generated before they are shown in the feed."
  - "Repo evidence: current branded generation is request/response on demand through POST /api/video-timelines/from-content/branded-generate."
  - "Repo evidence: no explicit generation-run persistence or ahead-of-time orchestrator exists yet."
next_step: "/102-sg-start ahead-of-time branded video generation runs and feed readiness"
---

## Title

Ahead-of-time branded video generation runs and feed readiness

## Status

Draft. This spec defines the missing orchestration substrate that prepares branded videos before users reach the feed. It introduces a durable generation-run service, a feed-facing readiness model, and background progression from content plus assets to a ready-to-publish video candidate without forcing the feed swipe path to do heavy preparation work.

## User Story

En tant que creatrice ContentGlowz authentifiee, je veux que mes videos branded soient preparees en amont et exposees au feed avec un etat simple prete, en cours ou bloquee, afin de swiper sur des contenus deja fabriques au lieu de lancer la preparation au dernier moment.

## Minimal Behavior Contract

Pour un contenu video-compatible appartenant au projet actif, ContentGlowz peut lancer ou reprendre un run de preparation durable qui assemble une timeline branded, cree les versions necessaires, gere preview et final render selon les capacites disponibles, puis expose un etat feed-simple `ready_to_publish`, `preparing`, `blocked` ou `failed` avec raisons compactes. Si la marque, les assets, la capacite de rendu, le contenu ou les comptes de publication ne permettent pas de finir le run, le systeme conserve un etat recuperable et observable plutot que de cacher l'echec derriere un simple fallback editeur.

## Success Behavior

- Given eligible video-first content exists in a project, when background preparation is scheduled, then ContentGlowz creates or reuses one idempotent branded-video generation run for that content plus format preset.
- Given the run starts, when brand defaults and render-safe assets are available, then the backend assembles or refreshes the canonical branded timeline draft and version without requiring a feed-triggered HTTP request from the user.
- Given preview and final render capacity are available, when the run progresses, then the system requests the necessary render jobs and tracks their result until the feed-facing state becomes `ready_to_publish` or a typed blocked state.
- Given the final artifact is current and publish prerequisites pass, when the feed queries candidates, then the item is exposed as `ready_to_publish` with stable identifiers for the content, timeline, version and final artifact.
- Given a run is already in progress or already ready, when another scheduler or UI trigger asks for preparation, then the system reuses or resumes the durable run instead of duplicating work.

## Error Behavior

- Missing auth or foreign project/content/brand ownership returns `401`, `403` or `404` and no background run is created.
- If no usable brand profile or blueprint exists, the run enters `blocked` with typed reason `brand_setup_required`.
- If render-safe asset resolution fails or content is too thin, the run enters `blocked` with deterministic blocker codes rather than silently fabricating a low-trust artifact.
- If renderer capacity is exhausted, the run remains queued or waiting instead of failing permanently.
- If preview or final render fails, the run records failure state and reason, preserves the last valid timeline/version context, and exposes a retryable blocked state to the feed.

## Problem

The repo already has branded assembly, timeline persistence, preview/final render jobs and swipe publish. What it does not have is the durable orchestration layer that prepares videos before the user reaches the feed. That gap causes the feed to remain partly trigger-based instead of consumption-first, which contradicts the product direction of ready-made content by default.

## Solution

Add a branded-video generation-run subsystem that sits above the canonical timeline and render-job layers. This subsystem owns run persistence, idempotent scheduling, capacity-aware progression, blocker reporting and the feed-facing readiness projection. The feed should consume this projection rather than initiating the heavy preparation path on swipe.

## Scope In

- Durable persistence for branded-video generation runs.
- A feed-facing readiness state model above timeline/render internals.
- Idempotent scheduling and resumption for one content plus format preset.
- Background progression through assemble, preview, finalize and readiness publication.
- Backend API surface to list or refresh ready-made feed candidates.

## Scope Out

- Feed card UI redesign details.
- Branding editor UI.
- Regeneration with locks.
- Broad scheduler infrastructure for non-video content types.

## Constraints

- The canonical video timeline remains the only editable video source of truth.
- Generation runs must wrap existing timeline/version/render primitives rather than replace them.
- Capacity limits already present in video render orchestration must remain enforceable and visible in run state.
- Feed readiness must be explainable in compact product terms, not raw renderer internals only.

## Test Contract

- Surface: backend service/router tests plus targeted app model/provider tests.
- Proof profile: scenario-first.
- Proof order:
  - backend generation-run persistence and state-transition tests
  - backend feed-readiness projection tests
  - targeted app model/provider parsing tests for candidate readiness
  - metadata lint for this spec after readiness mutation
- Required scenario ids:
  - `AOT-RUN-001` idempotent run creation and reuse
  - `AOT-RUN-002` blocked state when brand setup is missing
  - `AOT-RUN-003` queue or waiting state under render-capacity pressure
  - `AOT-RUN-004` feed readiness projection for ready, preparing and blocked states
  - `AOT-RUN-005` stale or superseded run does not keep claiming ready state after newer timeline activity
  - `AOT-RUN-006` final artifact and publish prerequisites are both required before `ready_to_publish`
- Required results:
  - durable run records survive beyond the initiating HTTP request and can be resumed or re-read safely
  - one content plus format preset does not create divergent active runs under repeated triggers
  - feed-facing state names are compact and product-usable, but remain traceable to lower-level timeline and render truth
  - ownership, blocker propagation, capacity waiting and stale-state demotion are asserted deterministically
- Exception with proof:
  - no full device/browser feed proof is required in `102-sg-start` for this substrate spec if backend and targeted app-layer evidence prove the durable run contract and readiness projection

## Dependencies

- `lab/api/services/branded_video_assembly.py`
- `lab/api/services/video_timeline_store.py`
- `lab/api/routers/video_timelines.py`
- `lab/api/services/job_store.py`
- `app/lib/data/models/content_item.dart`
- `app/lib/presentation/screens/feed/*`

## Invariants

- One content item plus format preset maps to one active canonical timeline path.
- A generation run may reference timelines and render jobs, but it never becomes a parallel editable media model.
- Feed readiness can only claim `ready_to_publish` when the current final artifact and publish prerequisites are both satisfied.

## Links & Consequences

- This spec is the substrate for the feed-native review-card spec.
- It must preserve ownership checks from existing brand, content and timeline routes.
- It changes product truth: the feed becomes a consumer of prepared candidates instead of a trigger surface for heavy generation.

## Documentation Coherence

- `shipglows_data/product/app/product.md` will need an update once this substrate ships, because the feed semantics change materially.
- Feed-facing labels and help copy must stay aligned with `shipglows_data/branding/branding.md` and avoid implying blind autopublish.

## Edge Cases

- Two schedulers ask to prepare the same content at the same time.
- A run becomes ready, then a newer timeline edit makes it stale.
- Renderer capacity is full for hours and the feed must still explain the waiting state.
- Brand profile changes between queued and assembling states.

## Implementation Tasks

- [ ] Tache 1: Add branded-video generation-run persistence.
  - Fichiers: new store/model under `lab/api/models/` and `lab/api/services/`, plus migration.
  - Action: create durable run records with state, blockers, timeline/version/job references, trigger source and timestamps.
  - Validate with: store and migration tests proving create/read/update, idempotent lookup by content plus format preset, and durable blocker persistence.

- [ ] Tache 2: Build the generation-run orchestration service.
  - Fichiers: new service under `lab/api/services/`, `lab/api/routers/video_timelines.py`.
  - Action: wrap existing branded assembly and render progression into idempotent state transitions.
  - Validate with: service tests for assemble -> preview -> final progression, blocked brand setup, capacity waiting, retry/resume and stale-state demotion.

- [ ] Tache 3: Expose feed-facing readiness projection.
  - Fichiers: backend router/read model, `app/lib/data/models/content_item.dart` or dedicated feed candidate model.
  - Action: publish compact states `ready_to_publish`, `preparing`, `blocked`, `failed` plus blocker summaries.
  - Validate with: router or projection tests asserting state mapping from run/timeline/render truth into feed-safe readiness labels and blocker summaries.

- [ ] Tache 4: Add candidate listing and refresh hooks.
  - Fichiers: backend route, app API/provider integration.
  - Action: let the feed query prepared candidates and optionally request a safe refresh without duplicating runs.
  - Validate with: targeted app provider/model tests for candidate parsing, refresh-trigger deduplication and non-video items remaining outside this substrate.

## Acceptance Criteria

- A branded-video generation run is persisted and recoverable independently from the requesting UI session.
- The feed can distinguish prepared, preparing and blocked video candidates without launching the heavy pipeline on swipe.
- Duplicate preparation requests for the same content plus format do not create divergent active runs.
- Capacity backpressure is represented as a non-terminal state rather than a silent failure.

## Test Strategy

- Add backend tests around run state transitions and idempotency.
- Reuse current branded assembly and timeline router tests for lower-level proofs.
- Add targeted app tests for readiness parsing and feed-provider selection behavior.
- Prefer a dedicated backend read model for feed candidates over leaking raw timeline internals into `ContentItem` if the product states would become ambiguous.
- Keep the first implementation bounded to deterministic progression and product-readable readiness states; defer broader scheduling infrastructure until the durable contract is proven locally.

## Risks

- The largest risk is introducing a background orchestration layer that duplicates existing timeline or render-job truth.
- There is also operational risk if queueing is added without a clear capacity and retry policy.

## Execution Notes

- Prefer reusing the current timeline uniqueness invariant in `video_timeline_store` instead of inventing a second identity model.
- The first bounded implementation can keep scheduling local to `lab` if it remains durable and idempotent; a separate queue worker is optional only if quality is equivalent.
- Read order for implementation:
  - `lab/api/services/video_timeline_store.py`
  - `lab/api/routers/video_timelines.py`
  - `lab/api/services/branded_video_assembly.py`
  - `lab/api/services/job_store.py`
  - `app/lib/data/models/content_item.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/screens/feed/*`
- Stop and reroute to a follow-up spec if the clean implementation requires a generic cross-domain scheduler that would also govern non-video workloads; this spec owns durable video-run orchestration, not a monorepo-wide job platform.
- Stop and reroute if the candidate projection cannot be expressed cleanly without first deciding whether it extends `ContentItem` or introduces a dedicated feed candidate DTO; make that contract explicit rather than mixing ambiguous states into the existing generic content model.
- Proof path choice for `102-sg-start`: `scenario-first`, because the main risk is workflow integrity across persistence, orchestration and feed-readiness projection rather than isolated algorithm correctness only.

## Open Questions

None. The operator direction is explicit: generation should happen before feed display when possible, not at swipe time.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-08 00:00:00 UTC | 100-sg-spec | GPT-5 Codex | Created a dedicated foundation spec for durable ahead-of-time branded-video generation runs and feed readiness projection. | draft | /101-sg-ready ahead-of-time branded video generation runs and feed readiness |
| 2026-07-08 00:00:00 UTC | 100-sg-spec | GPT-5 Codex | Refined the foundation contract to add complete proof ordering, task-level validation, and bounded execution notes before readiness handoff. | ready | /102-sg-start ahead-of-time branded video generation runs and feed readiness |
| 2026-07-09 00:00:00 UTC | 102-sg-start | GPT-5 Codex | Implemented durable branded-video generation runs, feed-candidate refresh/list routes, scheduler handoff, and app-side readiness consumption for swipe publish. | implemented | /103-sg-verify ahead-of-time branded video generation runs and feed readiness |
| 2026-07-11 20:27:48 UTC | 103-sg-verify | GPT-5 Codex | Verified durable persistence, scoped ownership, idempotent reuse, state transitions, capacity waiting, scheduler handoff, feed refresh/list projection, and Flutter readiness consumption. Backend targeted tests: 23 passed; Flutter targeted tests: 22 passed; Dart analyze and Python imports passed. | verified | /104-sg-end ahead-of-time branded video generation runs and feed readiness |
| 2026-07-11 20:35:00 UTC | 104-sg-end | gpt-5.5 | Closed bookkeeping after successful substrate verification; hosted/production proof remains explicitly outside this spec. | closed | /005-sg-ship ahead-of-time branded video generation runs and feed readiness |

## Current Chantier Flow

- 100-sg-spec: completed
- 101-sg-ready: ready
- 102-sg-start: implemented
- 103-sg-verify: verified
- 104-sg-end: closed
- 005-sg-ship: pending
