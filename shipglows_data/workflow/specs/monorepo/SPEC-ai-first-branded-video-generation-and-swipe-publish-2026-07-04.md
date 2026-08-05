---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-07-04"
created_at: "2026-07-04 00:00:00 UTC"
updated: "2026-07-08"
updated_at: "2026-07-08 00:00:00 UTC"
status: reviewed
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlows authentifiee, je veux marquer un contenu comme complet, definir un rythme de generation, puis recevoir automatiquement en arriere-plan des videos brandees deja fabriquees a partir de mon contenu, de mes images, de mes videos et de mon branding, afin qu'elles apparaissent ensuite dans le feed pour que je puisse swiper pour publier ou ajuster rapidement si besoin."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "worker"
  - "Clerk auth"
  - "Turso/libSQL"
  - "Bunny Storage/CDN"
  - "Project Asset Library"
  - "Unified ContentGlows Video Timeline"
  - "Templates"
  - "Branding system"
  - "publish accounts"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-unified-contentglows-video-timeline-2026-05-14.md"
    artifact_version: "0.1.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ai-video-broll-generation-workflow-2026-05-13.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md"
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
  - "User direction 2026-07-04: the platform should propose already-made content by default, swipe to publish, with optional modification before publication."
  - "User direction 2026-07-04: give images and videos as inputs to AI and let it output a complete video that follows a specific branding."
  - "User direction 2026-07-04: editing should remain possible from the video editor or from the branding editor."
  - "Business and product docs were updated 2026-07-04 to shift canonical positioning from human-in-the-loop review-first to ready-made output with optional edits."
  - "The canonical video model already exists as one ContentGlows-owned timeline; this spec must not create a second competing editor model."
  - "User direction 2026-07-07: think DRY; manual video creation and feed-driven auto creation must share one video entrypoint, not two."
next_step: "/100-sg-spec AI-first branded video generation and swipe publish feed-semantic alignment"
---

## Title

AI-first branded video generation and swipe publish

## Status

Draft. This spec defines the target default experience for ContentGlows video: users provide source content, media assets and a brand system, ContentGlows assembles a ready-made branded video draft automatically, previews it through the existing render stack, and lets the user publish fast with a swipe-style confirmation or perform optional edits through the canonical video timeline or a dedicated branding editor. The product default is no longer "open an editor and start assembling." The default is "receive a finished draft, then approve, tweak, or regenerate." This revision also hardens the architecture rule that video creation has exactly one backend orchestration entrypoint regardless of whether the request starts from the feed, a content detail CTA, or a manual "create video" surface.

## User Story

En tant que creatrice ContentGlows authentifiee, je veux fournir du contenu, des images, des videos et un branding, puis recevoir automatiquement une video prete a publier que je peux swiper pour publier ou ajuster rapidement si besoin.

## Minimal Behavior Contract

Depuis un contenu appartenant au projet actif, avec des assets media eligibles et un profil de marque defini, ContentGlows attend d'abord un signal explicite de maturite du contenu, puis prepare automatiquement en arriere-plan un ou plusieurs drafts video brandes dans la timeline canonique, lance une preview serveur de ces versions, puis expose ces contenus deja fabriques dans le feed comme surfaces de decision. L'utilisateur peut alors publier d'un geste, modifier legerement, changer le branding apres validation reelle, ou regenerer avec des contraintes. Si le branding est incomplet, si les assets sont insuffisants, si la timeline auto-generee n'est pas valide, si le rendu echoue, si le publish preflight echoue ou si les droits d'acces ne correspondent pas au projet actif, l'utilisateur voit un etat recuperable avec explication courte et action suivante claire. Le cas facile a rater est la derive de modele: le "draft pret a publier" doit etre une version normale de la timeline ContentGlows, pas un objet cache ou un rendu jetable impossible a corriger.

## Success Behavior

- Given an authenticated user with an active project, owned content, eligible media assets and a selected brand profile, when the user marks a content item as complete and the schedule allows generation, then ContentGlows creates or refreshes branded drafts in the canonical video timeline in the background before the user acts.
- Given those ready-made drafts already exist, when the user opens the feed, then the app surfaces publish-ready video cards instead of asking the user to start a montage session.
- Given the brand profile contains approved defaults for typography, colors, logo treatment, caption style, intro/outro, CTA behavior, scene rhythm and transition family, when the auto-assembly runs, then those rules shape the generated scene order and visual treatment without requiring manual keyframe editing.
- Given the source content has text, assets and optional transcript or hook candidates, when the assembly runs, then the backend creates a complete first-cut timeline with scene sequencing, text overlays, media placements, audio defaults, caption defaults and export preset selection.
- Given a branded draft version is created, when preview is requested or auto-triggered under allowed cost rules, then the existing render stack produces a preview MP4 tied to that exact immutable timeline version.
- Given the preview completes and publish prerequisites pass, when the user reaches the final approval surface, then the app presents a compact review card with playback, key metadata, channel/format, and a swipe-to-publish confirmation.
- Given the user accepts the draft, when they complete the swipe action, then ContentGlows triggers the publish flow or queues the final publish action through the owned publish account path for the active project.
- Given the user wants changes, when they choose "Edit video", then the app opens the canonical `/editor/:id/video` timeline with the already-generated version loaded.
- Given the user wants systemic rather than one-off changes, when they choose "Edit branding", then the app opens a branding editor for that brand profile and can offer regeneration against the new rules.
- Given the user wants a new automatic cut, when they choose regenerate, then ContentGlows preserves explicit locks such as chosen assets, locked scenes, forbidden colors, fixed captions or CTA copy according to the request.
- Proof of success is a flow where a user can go from owned content plus brand inputs to a previewable, publishable video without doing manual montage first, while still keeping optional timeline and branding edits on the same canonical data.

## Error Behavior

- Missing, expired or invalid Clerk auth returns `401`; no draft, preview, render job or publish action is created.
- Foreign project, content, brand profile, asset, timeline or publish account returns `403` or `404` without leaking prompts, asset URLs, brand rules, preview artifacts or destination metadata.
- If the project has no usable brand profile and no safe default fallback, the auto-assembly is blocked with a clear "brand setup required" state and a path into the branding editor.
- If source content is too thin, missing transcript/body, or lacks enough eligible assets for the requested video archetype, the backend returns a typed insufficiency error and offers deterministic fallback paths rather than a broken draft.
- If auto-assembly generates an invalid timeline under current renderer limits, the draft is rejected before preview and the previous valid timeline remains active.
- If preview fails, the user may still edit or regenerate, but swipe-to-publish remains disabled until a current completed preview exists.
- If a publish account is missing, disconnected or not authorized for the active project, swipe-to-publish is unavailable and the UI routes to integration or export actions instead.
- If a user edits branding while another draft generation is in flight, stale draft results must not overwrite the newer brand revision.
- If a user edits the timeline after preview, that preview becomes stale and publish is blocked until a fresh preview completes for the new version.
- If regeneration is requested with locked constraints that cannot all be satisfied, the system returns a partial-constraint conflict instead of silently ignoring locks.
- What must never happen: a hidden non-canonical draft bypasses the timeline model, brand rules are applied from another project, a stale preview is published, a draft publishes to an unauthorized account, or the system claims "ready to publish" without a current valid preview.

## Problem

ContentGlows now has the foundations for a canonical video timeline, render preview/final workflows, templates, project assets and a stronger product promise around ready-made outputs. But the current direction of the video system still assumes too much manual assembly and too much editor-first thinking. That is the wrong default for the stated product goal.

Users do not want to spend time doing montage. They want the platform to output already-made, on-brand videos from their content and source assets. Editing must remain available, but as a correction layer. Without an explicit spec, the system risks drifting into a general-purpose editor, a disconnected AI playground, or a brittle set of one-off templates with no canonical tie to the timeline or publish flow.

There is also now a structural drift risk: if feed-driven generation and manual video creation keep separate backend orchestration paths, the product will accumulate two versions of "create a video" with diverging validation, branding behavior, preview semantics and publish readiness. That violates the DRY requirement and would make the app harder to maintain, explain and trust.

## Solution

Introduce an AI-first branded video generation workflow where the default path is:

1. let the user mark a content item as complete when they are done importing material for that project item,
2. choose or infer the brand profile and video archetype once the schedule allows generation,
3. auto-assemble a complete branded draft in the canonical timeline,
4. render preview for that exact timeline version,
5. place the finished output in the feed as a publish-ready card,
6. allow swipe-to-publish as the default decision surface,
7. allow optional edits either in the timeline editor or the branding editor after real validation,
8. allow regeneration with explicit constraints.

This keeps one canonical video model, one preview truth, and one publish gate, while shifting the product experience from "manual assembly first" to "publish-ready by default, delivered before the user asks."

It also imposes a stricter architectural rule: there is one video-generation orchestrator contract for the whole product. Feed cards, content detail CTAs, branding surfaces and manual video creation buttons may pass different intent hints, but they all call the same backend entrypoint and receive the same generation, readiness and publishability semantics.

## Scope In

- A canonical `BrandVideoBlueprint` concept that maps a brand profile to reusable video rules.
- Automatic draft assembly from owned content plus owned/eligible media assets.
- A `content complete` readiness gate that prevents premature generation while the user is still importing material.
- Scheduled background generation driven by project settings such as desired items per day or per week.
- Background generation of finished candidate videos before the user reaches the publish decision surface.
- Feed presentation of already-fabricated videos, not idea prompts or empty creation states.
- Branded defaults for:
  - layouts
  - typography
  - logo treatment
  - intro/outro modules
  - CTA modules
  - caption styling
  - transition family
  - motion intensity
  - scene grammar
  - export defaults by channel
- Video archetypes such as:
  - `ugc_ad`
  - `product_demo`
  - `faceless_reel`
  - `talking_head_highlight`
  - `testimonial_cut`
  - `recap`
- An auto-assembly service that outputs a normal ContentGlows timeline draft version rather than a parallel format.
- Preview orchestration tied to the current immutable timeline version.
- A compact approval surface in the app with playback, metadata, warnings and swipe-to-publish confirmation.
- Optional transitions into:
  - the canonical timeline editor for one-off edits
  - the branding editor for systemic edits
  - regeneration with constraints
- Brand-aware regeneration that can preserve locks such as:
  - selected assets
  - scene order
  - CTA copy
  - caption timing
  - excluded colors or styles
  - required scenes
- Publish preflight integration so swipe-to-publish checks preview freshness, channel readiness, duration/ratio constraints, destination authorization and project ownership.
- Server-side persistence for brand video blueprints, draft generation runs, regeneration constraints and publish decisions.
- Tests for ownership, stale preview blocking, brand revision conflicts, deterministic fallback behavior, publish preflight and regeneration lock preservation.

## Scope Out

- A second storyboard source of truth separate from the canonical timeline.
- A freeform professional editor as the default product entry point.
- A feed that asks the user to invent the content idea before generation.
- Automatic generation immediately on raw content import with no user readiness signal.
- Blind autopublish with no visible preview or approval state.
- Public claim that every output is perfect without review.
- Cross-project reusable public marketplace for brand kits in V1.
- Avatar/likeness generation, celebrity prompts or identity cloning.
- Direct provider-specific UI exposing arbitrary model controls to Flutter users.
- Full multi-user brand governance workflow with approvals, comments and audit permissions beyond project ownership.
- Autonomous campaign planning across many channels without explicit content or brand selection.
- Generic marketing-site copy overhaul in this spec; site changes follow product implementation.

## Constraints

- The canonical timeline remains the only editable video source of truth.
- There is exactly one backend entrypoint for "generate or refresh a branded video draft from content". UI surfaces may differ, but they must all call the same orchestration contract instead of creating parallel feed-specific or editor-specific generation paths.
- The branding editor does not own a second renderable model; it only edits brand rules that shape draft generation and regeneration.
- Any auto-generated draft must be persisted as a standard timeline version before preview or publish.
- Swipe-to-publish requires:
  - a completed preview for the current version,
  - a ready publish account for the target destination,
  - passing channel constraints,
  - ownership-safe project context.
- The system must not generate a finished draft while the user is still importing material unless the content has been explicitly marked complete.
- Changing branding only affects generation after the brand update has been validated and saved, not after a preview-only state.
- Background generation follows a project-level cadence setting and may enqueue the next candidate rather than run immediately.
- Auto-generation may be triggered by user action or safe product defaults, but expensive preview/render work must still respect quota, concurrency and provider policy constraints.
- The system must support incomplete projects gracefully:
  - if brand data is partial, use only safe defaults that are explicitly allowed;
  - if asset coverage is weak, degrade to simpler archetypes instead of fabricating unsupported complexity.
- Brand rules are project-scoped unless an explicit future org-level spec says otherwise.
- Regeneration must be explicit and traceable; it cannot silently mutate published or approved drafts.
- Publish must stay explainable:
  - the app shows why a draft is ready,
  - why it is blocked,
  - and what changed after regeneration or edit.
- The feed is a consumer surface for already prepared outputs; it does not itself decide when background generation should happen.
- Signed preview/final URLs, provider secrets and publish tokens must never be persisted in durable client state or visible diagnostics.
- The timeline editor remains an edit surface only. It must not become a second creation orchestrator with separate assembly logic.

## Planning Model

The product uses a project-scoped generation plan that controls how many ready-made items should be produced per day or per week. The plan can queue work in the background so generation remains calm and deterministic instead of blocking the user. A status cue such as "next content in 30 min" is allowed when it reflects the actual scheduler state, and it should always be derived from the same plan that drives generation.

Generation should be started by one of three durable signals only:

1. the user explicitly marks a content item as complete,
2. the user validates and saves a real branding change,
3. the background scheduler reaches the next planned generation slot.

Preview-only changes, raw imports, and feed refreshes are not generation triggers.

## Dependencies

- Canonical timeline spec:
  - `shipglows_data/workflow/specs/monorepo/SPEC-unified-contentglows-video-timeline-2026-05-14.md`
- Existing video generation/editor-related specs:
  - `shipglows_data/workflow/specs/monorepo/SPEC-ai-video-broll-generation-workflow-2026-05-13.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
- Canonical business and product truth:
  - `shipglows_data/business/business.md`
  - `shipglows_data/branding/branding.md`
  - `shipglows_data/product/app/product.md`
- Existing publish account and render job contracts in `lab`.

## Data Model Additions

### `BrandProfile`

Project-scoped brand identity and base rules.

Suggested fields:
- `id`
- `project_id`
- `name`
- `logo_asset_id`
- `primary_colors`
- `secondary_colors`
- `font_heading`
- `font_body`
- `tone_keywords`
- `cta_defaults`
- `caption_style_defaults`
- `motion_intensity`
- `transition_family`
- `intro_module_enabled`
- `outro_module_enabled`
- `updated_at`

### `BrandVideoBlueprint`

Project-scoped video system derived from a brand profile.

Suggested fields:
- `id`
- `project_id`
- `brand_profile_id`
- `name`
- `status`
- `default_archetype`
- `scene_rules_json`
- `layout_rules_json`
- `motion_rules_json`
- `caption_rules_json`
- `cta_rules_json`
- `audio_rules_json`
- `export_rules_json`
- `allowed_regeneration_locks_json`
- `revision`
- `created_at`
- `updated_at`

### `VideoDraftGenerationRun`

Tracks each automatic assembly or regeneration run.

Suggested fields:
- `id`
- `project_id`
- `content_id`
- `timeline_id`
- `result_timeline_version_id`
- `brand_profile_id`
- `brand_video_blueprint_id`
- `video_archetype`
- `trigger_source`
- `status`
- `constraint_locks_json`
- `warnings_json`
- `preview_job_id`
- `created_by`
- `created_at`
- `completed_at`

### `SwipePublishDecision`

Tracks final approval and publish intent.

Suggested fields:
- `id`
- `project_id`
- `content_id`
- `timeline_id`
- `timeline_version_id`
- `preview_job_id`
- `publish_account_id`
- `destination_channel`
- `status`
- `decision_source`
- `decided_by`
- `created_at`
- `published_at`

## API Shape

Expected new or expanded API family:

- `POST /api/brand-profiles`
- `PATCH /api/brand-profiles/{brand_profile_id}`
- `GET /api/brand-profiles/{brand_profile_id}`
- `POST /api/brand-video-blueprints`
- `PATCH /api/brand-video-blueprints/{blueprint_id}`
- `GET /api/brand-video-blueprints/{blueprint_id}`
- `POST /api/video-timelines/from-content/branded-generate`
- `POST /api/video-drafts/{draft_run_id}/regenerate`
- `GET /api/video-drafts/{draft_run_id}`
- `POST /api/video-timelines/{timeline_id}/preview`
- `POST /api/video-publish-decisions/{timeline_id}/swipe-publish`
- `GET /api/video-publish-decisions/{decision_id}`

Key request/response expectations:

- The branded generate route is the single orchestration entrypoint for initial video creation and refresh from content. It accepts ids and high-level intent, not raw arbitrary render JSON.
- All product surfaces that mean "make me a video" call this same route with optional `trigger_source` or `entry_surface` metadata such as `feed`, `content_detail`, `manual_create`, or `branding_regenerate`.
- Regeneration accepts explicit locks and optional requested changes.
- Swipe publish accepts only the current timeline id/version context and a destination account id; the server verifies preview freshness and authorization.
- All responses must be ownership-scoped and redact signed URLs/tokens from non-artifact contexts.
- The old plain `/api/video-timelines/from-content` bootstrap route may remain only as an internal/manual-edit compatibility helper if needed, but it is not an allowed product-level entrypoint for ready-made video creation once this chantier is implemented.

## App UX

Primary user flow:

1. user opens the feed, content detail, or a manual video creation CTA;
2. app shows selected brand profile and video archetype;
3. app calls the same branded generation orchestrator regardless of entry surface;
4. app shows progress and then preview;
5. app shows actions:
   - `Swipe to publish`
   - `Edit video`
   - `Edit branding`
   - `Regenerate`
6. app blocks publish if preview is stale or preflight fails.

The approval UI should stay compact and operational:

- preview player
- brand name
- archetype
- destination channel
- duration
- warnings
- last generated timestamp
- explicit state if user changes brand or timeline after preview

## Branding Editor UX

The branding editor is not Photoshop and not a timeline. It edits the system that controls future drafts.

V1 controls:
- fonts
- colors
- logo treatment
- lower-third style
- caption style
- intro/outro modules
- transition family
- motion intensity
- CTA style
- default archetypes per channel

V1 behavior:
- saves a new brand or blueprint revision;
- can trigger regeneration of the current draft using the new revision;
- never edits the timeline directly except through explicit regeneration or allowed derived updates.

## Timeline Editor UX

The timeline editor remains available for:

- changing scene order
- swapping assets
- editing text
- trimming clips
- adjusting captions
- locking scenes before regeneration

But it is not the default entry point for V1 of this product direction, and it is not allowed to own a separate video creation flow.

## Invariants

- There is one canonical video timeline per active draft context, not one hidden AI draft plus one user-edit draft.
- Every publishable video corresponds to a current immutable timeline version.
- Every swipe-to-publish action is bound to a fresh completed preview for that exact version.
- Brand revisions do not silently overwrite already-approved timeline versions.
- Regeneration never publishes automatically.
- Optional edits must not break the ability to reason about what brand rules or source assets produced the draft.

## Links & Consequences

- `lab/api/routers/video_timelines.py` already contains a branded generation split between `branded-draft` and `branded-preview`; this chantier must consolidate product callers onto one canonical generation contract instead of preserving that split as user-visible architecture.
- `lab/api/models/video_timeline.py` already defines branded request/response models and readiness states such as `preview_ready`; any implementation must extend these models carefully instead of creating a parallel DTO family.
- `lab/api/routers/brand_profiles.py` and `lab/api/routers/brand_video_blueprints.py` already expose project-scoped brand CRUD; the implementation should reuse those contracts and fill the missing app wiring before inventing additional brand endpoints.
- `lab/api/services/branded_video_assembly.py` and `lab/tests/test_branded_video_assembly.py` already establish a first deterministic assembly substrate; orchestration work should build on it rather than replacing it with ad hoc feed logic.
- `app/lib/providers/video_timeline_provider.dart` and `app/lib/presentation/screens/editor/video_timeline_screen.dart` still assume a manual timeline bootstrap path; changing the generation contract affects provider state, preview gating, and editor entry semantics.
- `app/lib/providers/providers.dart` and `app/lib/presentation/screens/feed/feed_screen.dart` still publish via the older content approval flow; once unified generation is wired, feed approval semantics must stop bypassing the canonical video readiness gate when the content path is video-first.
- Existing timeline render and artifact signing behavior in `lab/api/routers/video_timelines.py` and `lab/tests/test_video_timelines_router.py` is security-sensitive; route unification must preserve ownership checks, stale preview rejection, and signed artifact redaction.

## Documentation Coherence

- Product promise docs must continue to describe ContentGlows as `ready-made first, editable second`, not as a manual editor.
- The public blog article created for this architecture must stay aligned with the shipped sequencing: one generation engine, one editable timeline, one optional branding editor.
- App copy in feed/editor surfaces must avoid implying blind autopublish; `swipe to publish` still depends on a current preview and destination readiness.
- No broad marketing-site rewrite is required in this chantier beyond copy directly affected by the new feed/manual-create unification.

## Edge Cases

- Project has content but no brand profile.
- Project has a brand profile but no usable media assets.
- Brand profile changes while preview is rendering.
- User edits timeline after preview but before swipe action.
- User edits branding after preview but before swipe action.
- Destination publish account disconnects after preview.
- Auto-assembly produces too many scenes for duration cap.
- Locked scene order conflicts with requested archetype change.
- Chosen assets violate destination safe-zone or ratio constraints.
- Regeneration requested on a published draft.
- Two tabs attempt regeneration with different lock sets.

## Acceptance Criteria

- From a feed-triggered or manual-triggered video creation action, the app calls one shared branded generation backend contract and receives the same readiness model.
- The generated result is persisted as the normal canonical timeline draft for that content/project context, not as a hidden transient object.
- If the current preview is fresh and completed for the current version, the approval surface exposes swipe-to-publish; if the preview is stale or missing, publish is blocked with an explicit reason.
- Editing the timeline after generation keeps the canonical timeline flow intact and marks previous preview state stale.
- Editing the branding system updates future generation/regeneration behavior without introducing a second editable render model.
- Cross-project brand profile, blueprint, timeline, asset, or publish account references are refused server-side.
- Feed and manual create callers do not diverge in branding defaults, ownership checks, or preview/publish gating.

## Test Contract

- Surface: `local backend tests` plus `local Flutter provider/service tests`
- Proof profile: `exception-with-proof`
- Proof order:
  - backend route/service tests
  - Flutter API/provider tests
  - targeted metadata lint for the spec
- Required scenario ids:
  - `BV-READY-001` shared orchestrator path for `feed` and `manual_create`
  - `BV-READY-002` canonical timeline persistence after branded generation
  - `BV-READY-003` preview freshness blocks publish when stale or missing
  - `BV-READY-004` foreign project brand/blueprint references are rejected
  - `BV-READY-005` timeline edits stale previously approved preview
  - `BV-READY-006` feed wiring stops bypassing branded video readiness
- Required results:
  - deterministic backend assertions for ownership, routing, and readiness
  - Flutter-level evidence that the same API contract is used from both entry surfaces
  - no new parallel product-level video generation endpoint
- Exception with proof:
  - full end-to-end device publish proof is outside `102-sg-start`; local implementation may complete with automated route/provider evidence and explicit follow-up to `103-sg-verify`.

## Test Strategy

- Reuse and extend backend router coverage in `lab/tests/test_video_timelines_router.py`, `lab/tests/test_branded_video_assembly.py`, `lab/tests/test_brand_profiles_router.py`, and `lab/tests/test_brand_video_blueprints_router.py`.
- Add focused app-layer tests around `ApiService`, feed approval provider flow, and video timeline provider orchestration so DRY entrypoint guarantees are enforced in code, not only in prose.
- Prefer scenario-first verification for the feed/manual-create convergence because this chantier is mainly workflow integrity work across multiple surfaces.
- Keep proof local and deterministic for `102-sg-start`; defer browser/device/manual publish proof to `103-sg-verify`.

## Risks

- The largest delivery risk is preserving old feed publish shortcuts that bypass the new branded video readiness contract.
- There is moderate migration risk in consolidating branded draft and branded preview semantics without breaking existing timeline/editor assumptions.
- There is medium product risk if the branding editor is introduced too early as a second orchestration surface instead of remaining a rule editor.
- There is security risk if cross-project resource ownership checks regress while adding feed-driven generation.
- There is maintainability risk if route naming is unified superficially in the app while backend still preserves two materially different orchestration paths.

## Execution Notes

- Implementation should start from the existing backend substrate, not from a greenfield rewrite: branded assembly, brand profile/blueprint stores, and canonical video timeline routes already exist.
- Read order for execution:
  - `lab/api/models/video_timeline.py`
  - `lab/api/routers/video_timelines.py`
  - `lab/api/services/branded_video_assembly.py`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/providers/video_timeline_provider.dart`
  - affected feed/manual-create screens
- Proof path choice for `102-sg-start`: `scenario-first`, because the main contract is one shared orchestration flow across surfaces.
- Preferred first slice: unify backend generation contract naming/behavior and wire one app caller path to it before expanding the approval UI.
- Stop if implementation reveals a real product decision not covered here, especially around publish-account routing, destination selection defaults, or whether feed approve should always imply video generation for every content type.

## Open Questions

None. This spec is ready only for the bounded first implementation slice that unifies the canonical generation entrypoint and app callers. Broader publish-surface redesign or full branding-editor UX depth remains future iteration work inside the listed scope order.

## Implementation Tasks

- [ ] Tache 1: Define canonical brand video data models.
  - Fichiers: `lab/api/models/brand_video.py`, migration file, store/service layer.
  - Action: Add `BrandProfile`, `BrandVideoBlueprint`, `VideoDraftGenerationRun`, and `SwipePublishDecision` models plus persistence.
  - Validate with: store tests for ownership, revisioning and serialization.

- [ ] Tache 2: Build one canonical branded generation orchestrator into the timeline flow.
  - Fichiers: `lab/api/services/video_draft_assembly.py` or equivalent, `lab/api/routers/video_timelines.py`, request/response models.
  - Action: Transform content, assets and blueprint rules into a valid timeline draft version behind a single backend entrypoint used by feed and manual video creation.
  - User story link: Receive a ready-made branded video without caring which UI surface triggered creation.
  - Depends on: Tache 1
  - Validate with: deterministic assembly tests for archetypes, asset fallback, duration caps, and shared behavior across `feed` and `manual_create` triggers.

- [ ] Tache 3: Add branding editor API contracts.
  - Fichiers: new `lab/api/routers/brand_video.py` or equivalent.
  - Action: Add CRUD for brand profiles and blueprints with revision safety.
  - Validate with: auth and ownership API tests.

- [ ] Tache 4: Add regeneration-with-constraints workflow.
  - Fichiers: assembly service, request models, timeline/version glue.
  - Action: Support explicit lock preservation and explainable regeneration warnings.
  - Validate with: tests for preserved assets/scenes/captions and typed constraint conflicts.

- [ ] Tache 5: Add swipe-to-publish server contract.
  - Fichiers: publish router/service area in `lab`.
  - Action: Add preflight validation and publish decision recording tied to exact timeline version and preview job.
  - Validate with: tests for stale preview rejection, foreign account refusal, and successful publish decision creation.

- [ ] Tache 6: Unify Flutter video creation callers on the same orchestrator.
  - Fichiers: `app/lib/data/services/api_service.dart`, `app/lib/providers/providers.dart`, `app/lib/providers/video_timeline_provider.dart`, feed/content-detail/manual-create surfaces.
  - Action: Replace feed-specific or editor-specific video creation calls with the single branded generation endpoint while preserving per-surface intent metadata.
  - User story link: The user should get the same ready-made video behavior whether they start from the feed or manually request a video.
  - Depends on: Tache 2
  - Validate with: Flutter/provider tests proving feed swipe and manual video create both hit the same API contract and receive the same readiness model.

- [ ] Tache 7: Add compact app approval flow on top of the unified orchestrator.
  - Fichiers: `app/lib/presentation/screens/editor/`, feed review surfaces, related providers/services.
  - Action: Show generated draft preview and actions for publish, edit video, edit branding and regenerate without introducing a second product flow.
  - User story link: Approve fast, edit optionally, publish safely.
  - Depends on: Tache 5, Tache 6
  - Validate with: Flutter state tests for ready, blocked, stale and regenerated flows.

- [ ] Tache 8: Add branding editor app surface.
  - Fichiers: new branding editor route/screen/provider models in `app`.
  - Action: Support editing blueprint rules and rerunning current draft generation.
  - User story link: Make systemic brand changes without manually remaking the video.
  - Depends on: Tache 3, Tache 6
  - Validate with: form state and API interaction tests.

- [ ] Tache 9: Keep docs and promise aligned.
  - Fichiers: product/branding/site docs and user-facing copy.
  - Action: Ensure implementation language uses `ready-made`, `optional edits`, and `swipe to publish` consistently without implying blind autopilot.
  - User story link: The user must understand the default automation path without being misled about blind autopilot.
  - Depends on: Tache 6, Tache 7
  - Validate with: docs audit and UX copy review.

## Validation Notes

- Targeted metadata validation passes for this artifact:
  - `python3 /home/claude/shipglowz/tools/shipglowz_metadata_lint.py shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md`
- Global `shipglows_data/workflow/specs` metadata lint still fails as of `2026-07-04`, but due to pre-existing invalid artifacts outside this chantier, not due to this spec.
- Historical invalid specs currently reported by the global lint:
  - `shipglows_data/workflow/specs/SPEC-ai-asset-understanding-auto-tagging-2026-05-13.md`
  - `shipglows_data/workflow/specs/app/SPEC-contentglows-app-dependency-hygiene-and-reproducible-flutter-install-2026-06-12.md`
  - `shipglows_data/workflow/specs/app/SPEC-record-package-migration-flutter-3-41.md`
  - `shipglows_data/workflow/specs/app/android-back-history-outside-onboarding-2026-05-16.md`
  - `shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md`
  - `shipglows_data/workflow/specs/lab/SPEC-google-search-console-intelligence.md`
  - `shipglows_data/workflow/specs/lab/SPEC-project-intelligence-engine-data-layer-2026-05-13.md`
  - `shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-cloud-run-gcs-render-deployment-2026-05-14.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-unified-contentglows-video-timeline-2026-05-14.md`
  - `shipglows_data/workflow/specs/site/SPEC-bilingual-fr-en-blog-routing-and-locale-metadata-2026-06-12.md`
  - `shipglows_data/workflow/specs/site/SPEC-bilingual-fr-en-routing-seo-metadata-core-pages-2026-06-12.md`

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-04 00:00:00 UTC | sf-spec | GPT-5 Codex | Created canonical draft spec for AI-first branded video generation, preview, swipe-to-publish, optional editing, and brand-driven regeneration. | implemented; targeted metadata lint passes, global specs lint still blocked by pre-existing invalid artifacts outside this chantier | /101-sf-ready AI-first branded video generation and swipe publish |
| 2026-07-04 00:00:00 UTC | 007-sf-content | GPT-5 Codex | Added a public French blog article on the site to explain the target architecture and user flow without overclaiming shipped behavior. | implemented | /103-sf-verify AI-first branded video generation and swipe publish public content alignment |
| 2026-07-07 00:00:00 UTC | 100-sg-spec | GPT-5 Codex | Updated the spec to require one single video creation entrypoint shared by feed-driven and manual video creation flows, removing product-level allowance for parallel orchestration paths. | implemented | /101-sg-ready AI-first branded video generation and swipe publish |
| 2026-07-07 00:00:00 UTC | 101-sg-ready | GPT-5 Codex | Completed readiness review, aligned the spec with the existing backend/frontend substrate, added missing proof and execution sections, and approved a bounded first implementation slice around the unified video generation entrypoint. | ready | /102-sg-start AI-first branded video generation and swipe publish |
| 2026-07-07 00:00:00 UTC | 102-sg-start | GPT-5 Codex | Implemented the first bounded slice of the unified orchestration path: added a canonical `branded-generate` backend route with default brand/blueprint inference, wired the manual timeline load path to it in Flutter, and added targeted backend coverage. | partial | /102-sg-start AI-first branded video generation and swipe publish Tache 6 feed wiring and approval flow |
| 2026-07-07 00:00:00 UTC | 102-sg-start | GPT-5 Codex | Extended the same chantier slice into the feed: video/reel/short approval now routes through the canonical branded generation plus `swipe-publish` flow, restores the queue item when final render or blockers prevent immediate publish, and opens the canonical video editor fallback instead of the generic editor. | partial | /102-sg-start AI-first branded video generation and swipe publish Tache 6 feed wiring and approval flow |
| 2026-07-08 00:00:00 UTC | 100-sg-spec | GPT-5 Codex | Clarified the product contract so the default feed model is pre-generated branded content presented as ready-made publish cards, not idea prompts or a montage-first creation flow. | implemented | /102-sg-start AI-first branded video generation and swipe publish feed as decision surface for finished content |
| 2026-07-08 00:00:00 UTC | 100-sg-spec | GPT-5 Codex | Tightened the scheduling contract so generation begins only after explicit content-complete, validated branding, or planner-driven cadence signals; raw imports and preview-only changes are not triggers. | implemented | /102-sg-start AI-first branded video generation and swipe publish background planning model |
| 2026-07-08 00:00:00 UTC | 101-sg-ready | GPT-5 Codex | Verified the spec against the real repo substrate: canonical branded generation route, brand profile/blueprint CRUD, drip scheduling, and feed/manual caller wiring are present enough for a bounded first implementation slice. | ready | /102-sg-start AI-first branded video generation and swipe publish |
| 2026-07-08 00:00:00 UTC | 101-sg-ready | GPT-5 Codex | Re-reviewed the spec against the live repo and found blocking gaps: feed is still a review queue, there is no explicit content-complete gate, scheduler-driven video generation is absent, and branding save/preview semantics are not yet separate. | not ready | /100-sg-spec AI-first branded video generation and swipe publish repo-alignment fixes |
| 2026-07-08 00:00:00 UTC | 101-sg-ready | GPT-5 Codex | Re-reviewed after the repo alignment pass: the explicit content-complete gate and scheduler-backed branded generation now exist, but the main feed is still structurally and textually a review queue rather than a publish-ready video decision surface, so the product contract is not yet fully aligned. | not ready | /100-sg-spec AI-first branded video generation and swipe publish feed-semantic alignment |

## Current Chantier Flow

- 100-sf-spec: completed
- 101-sg-ready: reviewed
- 102-sg-start: partial
- 103-sg-verify: pending
- 104-sg-end: pending
- 005-sg-ship: pending
