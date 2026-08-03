---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "app"
created: "2026-05-02"
created_at: "2026-05-02 06:03:02 UTC"
updated: "2026-05-02"
updated_at: "2026-05-02 06:03:02 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "En tant que créateur ContentGlowz, je veux pouvoir relire, personnaliser, versionner et publier les contenus proposés par l'IA, afin de garder ma voix et mon contrôle avant toute publication."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter feed"
  - "app Flutter editor"
  - "app offline sync"
  - "lab FastAPI status router"
  - "lab Turso/libSQL status storage"
  - "lab generation agents"
  - "lab publish router"
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "lib/presentation/screens/feed/feed_screen.dart: swipe right approves/publishes, left rejects, top opens editor."
  - "lib/presentation/screens/editor/editor_screen.dart: editor has title/body controllers, markdown preview, save before publish, platform preview, audit trail."
  - "lib/data/models/content_item.dart: ContentItem currently maps content_preview into body when body is missing."
  - "lib/data/services/api_service.dart: fetchContentBody/saveContentBody/fetchContentAuditTrail/updateContent/transitionContent already exist."
  - "lib/providers/providers.dart: PendingContentNotifier.approve currently publishes item.body."
  - "../lab/api/routers/status.py: exposes /api/status/content/{id}/body and /body/history with ownership checks."
  - "../lab/status/service.py: persists content body versions and content edit audit entries."
next_step: "/sf-ready content editing infrastructure"
---

# Title

Content Editing Infrastructure

## Status

Draft umbrella chantier. This parent spec defines the product and technical direction for reliable content editing. It should not be implemented as one monolithic change; child specs own executable slices.

## User Story

En tant que créateur ContentGlowz, je veux pouvoir relire, personnaliser, versionner et publier les contenus proposés par l'IA, afin de garder ma voix et mon contrôle avant toute publication.

## Minimal Behavior Contract

When ContentGlowz proposes a generated content item, the creator can skip it, open it for editing, save their changes, review the latest full version, and publish only that latest full version; if any load, save, authorization, sync, or publish step fails, the app must show a recoverable state and must never publish a preview, stale version, partial body, or content owned by another user.

## Success Behavior

- Given generated content is in `pending_review`, when the creator opens it from the feed, then the editor loads the authoritative full body and the visible title/body match the latest saved version.
- Given the creator edits and saves content, when the save succeeds, then a new body version and edit audit event exist in backend storage, local UI reflects the edit, and the item remains publishable.
- Given the creator publishes from the feed or editor, when publish succeeds, then the content sent to the publish router is the latest full body, not the feed preview.
- Given content is format-specific, when the editor opens it, then the UI exposes controls and previews that match `content_type` without losing the generic title/body lifecycle.
- Given backend availability is degraded, when the flow is offline-safe, then local cache/queue behavior remains visible and replayable; when the flow is externally visible, such as publish, it remains blocked or recoverable.

## Error Behavior

- If full body loading fails, the editor must show an explicit error/retry state and must not silently edit `content_preview` as if it were the full body.
- If saving fails online with validation/auth/ownership error, the app must show a diagnostic and preserve unsaved local text in the editor.
- If saving fails because the API is unreachable and the action is offline-safe, the save may queue through the existing offline queue and show entity sync status.
- If publishing cannot resolve the latest full body, connected account, authorized ownership, or publish endpoint, the app must not publish and must surface a warning/error result.
- If another user's `content_id` is supplied by URL manipulation, backend ownership checks must prevent access and the client must not expose cached cross-user data.

## Problem

ContentGlowz already has the high-level review loop: feed proposals, skip, edit, approve/publish, content body versioning, audit history, and generation agents. The fragile point is that the current client model can treat `content_preview` as `body`. That makes the whole creator-control promise unsafe: direct feed publish or editor save can potentially use a preview instead of the latest full content.

## Solution

Treat content editing as a staged infrastructure chantier. First, make the existing editor and publish path authoritative around full body vs preview. Then add format-aware editing controls, creator regeneration/versioning, and final publish validation in separate child specs.

## Scope In

- Define the durable parent direction for editing generated content across article, newsletter, social, short/reel, and video script formats.
- Split the chantier into child specs that can be readied, implemented, verified, and shipped independently.
- Preserve existing backend concepts: `content_records`, `content_bodies`, `content_edits`, `status_changes`, ownership checks, offline queue, and publish routing.
- Preserve human-in-the-loop positioning: the app helps creators personalize content before publication.
- Include explicit security, data, offline, audit, and publish consequences for all child specs.

## Scope Out

- No direct implementation in this umbrella spec.
- No rewrite of the generation agents.
- No replacement of Turso/libSQL storage.
- No automatic publication without human review.
- No native-only mobile auth redesign.
- No binary media upload replay in offline mode.
- No WordPress/Ghost auto-publish support unless a later child spec explicitly scopes it.

## Constraints

- Follow `app` architecture: UI in `lib/presentation`, data models/services in `lib/data`, app state in `lib/providers`.
- Use existing `ApiService`, Riverpod providers, and offline storage patterns instead of ad-hoc HTTP calls from widgets.
- Keep Clerk/FastAPI ownership boundaries intact; never trust client-side `content_id` alone.
- Keep publish operations online-only unless a future spec defines a safe server-side scheduling contract.
- Do not introduce new rich text packages until the format-aware editor spec proves the need.
- Any change touching status storage must explicitly decide whether a Turso migration is required.

## Dependencies

- Local code contracts:
  - `lib/data/models/content_item.dart`
  - `lib/data/services/api_service.dart`
  - `lib/providers/providers.dart`
  - `lib/presentation/screens/feed/feed_screen.dart`
  - `lib/presentation/screens/editor/editor_screen.dart`
  - `../lab/api/routers/status.py`
  - `../lab/status/service.py`
  - `../lab/api/migrations/004_status_lifecycle.sql`
- Existing specs:
  - `shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md`
  - `shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md`
  - `shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md`
  - `shipglows_data/workflow/specs/app/late-integration-finalization.md`
- Fresh external docs verdict: `fresh-docs not needed` for this umbrella because decisions are governed by existing local Flutter/FastAPI/Turso contracts and no external API behavior is being changed.

## Invariants

- Feed previews are not authoritative publish/edit bodies.
- Latest full body is the only acceptable source for publish content.
- Body saves create versions and edit audit events.
- Status transitions remain validated by backend lifecycle rules.
- Owned content records are required before body/history/update/publish access.
- Offline queue semantics remain explicit and visible.
- User-facing copy must stay transparent rather than imply fully autonomous publishing.

## Links & Consequences

- Feed direct publish depends on the same authoritative full body resolution as editor publish.
- Editor detail loading must become independent from the feed list's preview payload.
- Offline queue and cache keys for content body/history remain part of the user trust model.
- Publish flow must continue to separate approval success from external publish success.
- Backend status APIs already support the core persistence model, so child specs should prefer contract tightening and tests before schema changes.
- Existing platform preview can evolve, but must not become the source of truth for publish content.

## Documentation Coherence

- Update `CHANGELOG.md` when child specs ship user-visible behavior.
- Update `shipglows_data/product/app/product.md` only if the public product promise changes beyond reliable editing.
- Update `shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md` only if queue payloads, cache keys, or offline support semantics change.
- Update `shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md` only if format metadata contracts change.
- No marketing-site copy change is required for Spec 1; later format-aware editing may require a site/product copy alignment pass.

## Edge Cases

- Feed item has non-empty `content_preview` but no loaded full body.
- Creator opens `/editor/:id` directly after the feed queue changed or was refreshed.
- Creator edits while backend is unavailable, then publishes before replay completes.
- Body save succeeds but title update fails, or title update succeeds but body save fails.
- Direct feed publish happens for an item with publish channels but no body in the feed payload.
- Content was approved/rejected/published in another session while editor is open.
- User manipulates URL to another user's content id.
- Generated social/short bodies are JSON-like strings while article bodies are Markdown.

## Implementation Tasks

- [ ] Task 1: Ready and implement Spec 1, full body vs preview reliability.
  - File: `shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md`
  - Action: Run `/sf-ready`, then `/sf-start` only after readiness passes.
  - User story link: Prevents accidental preview editing or preview publishing.
  - Depends on: This umbrella spec.
  - Validate with: Spec 1 acceptance criteria and tests.
  - Notes: This is the mandatory foundation before format-aware UI.

- [ ] Task 2: Create child spec for format-aware editor controls.
  - File: `shipglows_data/workflow/specs/app/SPEC-content-editor-multiformat.md`
  - Action: Specify article/newsletter/social/short/reel/video-script editor surfaces, metadata editing, and platform previews.
  - User story link: Lets each creator add their own voice in the format they will actually publish.
  - Depends on: Spec 1 shipped or verified.
  - Validate with: `/sf-ready content editor multiformat`.
  - Notes: Do not add rich text dependencies until this spec proves need and scope.

- [ ] Task 3: Create child spec for creator regeneration and version review.
  - File: `shipglows_data/workflow/specs/app/SPEC-content-regeneration-loop.md`
  - Action: Specify instruction-based regeneration, diff/version review, audit trail, and no-overwrite behavior.
  - User story link: Gives creators a controlled way to ask the AI for changes without losing their own edits.
  - Depends on: Spec 1 shipped; format metadata decisions known enough to avoid conflicting body formats.
  - Validate with: `/sf-ready content regeneration loop`.
  - Notes: Must preserve latest human edits and use explicit actor metadata for AI actions.

- [ ] Task 4: Create child spec for publish-after-edit validation.
  - File: `shipglows_data/workflow/specs/app/SPEC-content-publish-after-edit.md`
  - Action: Specify final preflight, connected account checks, platform constraints, error handling, and final confirmation behavior.
  - User story link: Makes publication reliable after creator edits.
  - Depends on: Spec 1 shipped; may depend on format-aware metadata.
  - Validate with: `/sf-ready content publish after edit`.
  - Notes: Keep external publish online-only unless server-side scheduling is explicitly scoped.

- [ ] Task 5: Update tracking and documentation as child specs ship.
  - File: `CHANGELOG.md`
  - Action: Add user-visible editing reliability and format editor notes only after implementation.
  - User story link: Keeps operator-facing documentation aligned with actual shipped behavior.
  - Depends on: Each child spec implementation.
  - Validate with: `/sf-verify` for each child chantier.
  - Notes: `sf-spec` does not edit `TASKS.md`; task tracking can reference this umbrella later via a separate lifecycle step.

## Acceptance Criteria

- [ ] CA 1: Given this umbrella spec, when an agent plans editing work, then it can identify the child spec order and does not implement the whole chantier at once.
- [ ] CA 2: Given Spec 1 is complete, when a creator publishes from feed or editor, then the latest full body is used and preview fallback is impossible.
- [ ] CA 3: Given later specs begin, when they change editor UI or publish behavior, then they preserve the full-body, ownership, audit, and offline invariants from this umbrella.
- [ ] CA 4: Given backend or auth is unavailable, when editing work is implemented, then user-visible degraded/offline behavior remains explicit and recoverable.
- [ ] CA 5: Given a manipulated `content_id`, when any child flow requests record/body/history/publish, then backend ownership checks prevent cross-user access.

## Test Strategy

- Parent spec validation is mainly via `/sf-ready` and child spec readiness.
- Child specs must include frontend widget/provider tests, backend status service/router tests, and at least one manual QA path.
- Regression coverage must include direct feed publish, editor save-and-publish, direct `/editor/:id`, offline save queueing, and ownership denial.
- Validation commands should include Flutter tests for touched app files and backend pytest for touched FastAPI/status files.

## Risks

- High data risk: publishing the preview instead of full content violates the product promise.
- Medium product risk: one generic editor may not fit structured social/video payloads.
- Medium offline risk: queued body saves can conflict with server-side changes if not surfaced clearly.
- Medium integration risk: publish may approve a record even if external publish fails; messaging must stay explicit.
- Security risk: content body/history are user-owned data and must remain behind backend ownership checks.

## Execution Notes

- Read first:
  - `shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md`
  - `lib/data/models/content_item.dart`
  - `lib/data/services/api_service.dart`
  - `lib/providers/providers.dart`
  - `lib/presentation/screens/editor/editor_screen.dart`
- Implementation order:
  1. Ship Spec 1.
  2. Specify and ship format-aware editor controls.
  3. Specify and ship regeneration/version review.
  4. Specify and ship publish preflight.
- Avoid:
  - moving API calls into widgets,
  - bypassing `ApiService`,
  - making publish offline by client replay,
  - adding rich text dependencies before the multiformat spec.
- Stop conditions:
  - Turso schema is missing expected body/version tables in the target environment,
  - backend ownership checks are absent for a required endpoint,
  - publishing requires external API behavior not represented by local tests/specs.
- Fresh external docs: `fresh-docs not needed`; this parent is governed by local contracts and does not change SDK/API semantics.

## Open Questions

None for the umbrella. The chosen direction is to use a parent-plus-child-spec structure, with Spec 1 as the required foundation.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-02 06:03:02 UTC | sf-spec | GPT-5 Codex | Created umbrella chantier spec for ContentGlowz editing infrastructure | Draft saved | /sf-ready content editing infrastructure |

## Current Chantier Flow

- sf-spec: done for umbrella draft.
- sf-ready: not launched.
- sf-start: not launched.
- sf-verify: not launched.
- sf-end: not launched.
- sf-ship: not launched.

Next lifecycle command: `/sf-ready content editing infrastructure`.
