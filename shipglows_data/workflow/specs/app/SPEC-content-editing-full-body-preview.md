---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-05-02"
created_at: "2026-05-02 06:03:02 UTC"
updated: "2026-05-02"
updated_at: "2026-05-02 06:03:02 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: bug
owner: "Diane"
confidence: medium
user_story: "En tant que créateur ContentGlowz, je veux éditer et publier le contenu complet proposé par l'IA, afin de ne jamais valider par erreur un simple aperçu tronqué."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter feed"
  - "app Flutter editor"
  - "app Riverpod providers"
  - "app ApiService offline cache/queue"
  - "lab FastAPI status router"
  - "lab status service"
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
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-editing-infrastructure.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "lib/data/models/content_item.dart:123 maps json['content_preview'] into ContentItem.body when json['body'] is absent."
  - "lib/presentation/screens/editor/editor_screen.dart:55 treats any non-empty item.body as already loaded and skips fetchContentBody."
  - "lib/providers/providers.dart:1620 publishes item.body through api.publishContent."
  - "lib/data/services/api_service.dart:1198 fetchContentBody already reads /api/status/content/{id}/body."
  - "lib/data/services/api_service.dart:1274 saveContentBody already writes /api/status/content/{id}/body and queues offline save_body."
  - "../lab/api/routers/status.py:366 has GET /body, PUT /body, GET /body/history with require_owned_content_record."
  - "../lab/status/service.py:450 creates content body versions and edit audit entries."
next_step: "/sf-verify content editing full body preview"
---

# Title

Content Editing Full Body Preview Reliability

## Status

Ready child spec, intended as Spec 1 under `SPEC-content-editing-infrastructure.md`. This is the first executable chantier because it protects the core edit/publish promise.

## User Story

En tant que créateur ContentGlowz, je veux éditer et publier le contenu complet proposé par l'IA, afin de ne jamais valider par erreur un simple aperçu tronqué.

## Minimal Behavior Contract

When a creator opens or publishes a proposed content item, the app must resolve the latest full body from the content body contract before editing or publishing; the feed preview may be displayed on cards but must never be treated as the editable or publishable body, and if the full body cannot be loaded, saved, authorized, or reconciled, the app must stop the action and show a recoverable error instead of falling back to preview text.

## Success Behavior

- Given `/api/status/content` returns an item with `content_preview` but no full body, when the feed renders, then the card shows the preview while `ContentItem.body` remains empty or explicitly non-authoritative.
- Given the creator opens the editor for a pending item, when the detail body endpoint succeeds, then the editor text field and Markdown preview use the latest body from `/api/status/content/{id}/body`.
- Given the creator saves changes, when the backend accepts the save, then `/api/status/content/{id}/body` creates a new body version and the app invalidates or refreshes the relevant content detail/feed state.
- Given the creator publishes from the feed without opening the editor, when the item has publishable channels, then `PendingContentNotifier.approve` resolves the latest full body before calling `/api/publish`.
- Given the creator publishes from the editor after editing, when save succeeds, then publish uses the saved full body, not stale provider state.

## Error Behavior

- If the full body endpoint returns 404 for a content item with a preview, the editor must show that the full content is unavailable and must not publish.
- If the full body endpoint returns 401/403 or ownership failure, the app must show a diagnostic/auth error and must not expose cached content from another user scope.
- If full body fetch times out or backend is unreachable, editor opening may show cached full body if available; otherwise it must show retry/degraded state and block publish.
- If body save queues offline, the editor may show pending sync, but publish remains blocked until the save is reconciled or a fresh server body is available.
- If title update succeeds but body save fails, the publish action must stop and keep the creator's current editor text visible for retry.
- If direct feed publish cannot load full body, the card must remain or be restored in the pending queue and the user must see a warning/error result.

## Problem

The current Flutter model conflates preview and body. `ContentItem.fromJson` fills `body` from `content_preview` when `body` is absent, and the editor treats a non-empty body as already loaded. Because feed list payloads are `ContentResponse` objects that include `content_preview` but not the latest full body, a creator can potentially edit or publish a truncated preview. This is a high-risk data/product bug because ContentGlowz's promise is human-controlled publication of complete content.

## Solution

Separate preview display data from authoritative body data, add a content detail path that always resolves the latest full body before editing/publishing, and update direct feed publish plus editor publish to use that resolved body. Preserve existing backend versioning and offline queue contracts; do not add new persistence tables unless target Turso verification proves the expected schema is absent.

## Scope In

- Fix `ContentItem` parsing so `content_preview` does not become authoritative `body`.
- Add or refactor app state so `/editor/:id` loads content record metadata and latest full body through a dedicated detail provider/path.
- Ensure feed direct approve/publish fetches or otherwise resolves the latest full body before `/api/publish`.
- Ensure editor save-and-publish saves body first, refreshes local state, and publishes the saved full body.
- Preserve and test offline-safe body save queue behavior while keeping external publish online-only.
- Add frontend tests for parsing, editor load behavior, and publish body resolution.
- Add backend tests for body versioning/edit history or endpoint behavior where missing.

## Scope Out

- No multiformat editor UI beyond preserving existing generic metadata chips and platform preview.
- No AI regeneration/diff flow.
- No new rich text editor package.
- No publish channel expansion.
- No WordPress/Ghost auto-publish enablement.
- No schema redesign for `content_records`, `content_bodies`, or `content_edits`.
- No native auth or routing redesign.

## Constraints

- Use existing `ApiService` for HTTP, cache, queue, and ID mapping behavior.
- Keep state logic in providers/services rather than adding direct HTTP calls in widgets.
- Keep publish operations externally visible and therefore online-only.
- Keep local cache scoped by authenticated user via existing offline storage scope.
- Do not silently fall back from full body to preview in editor or publish paths.
- Any backend contract change requires checking Turso schema before commit/push; expected result is no migration.

## Dependencies

- App files:
  - `lib/data/models/content_item.dart`
  - `lib/data/services/api_service.dart`
  - `lib/providers/providers.dart`
  - `lib/presentation/screens/feed/feed_screen.dart`
  - `lib/presentation/screens/editor/editor_screen.dart`
  - `lib/presentation/screens/editor/platform_preview_sheet.dart`
  - `lib/data/services/offline_storage_service.dart`
- Backend files:
  - `../lab/api/routers/status.py`
  - `../lab/api/models/status.py`
  - `../lab/status/service.py`
  - `../lab/api/migrations/004_status_lifecycle.sql`
  - `../lab/api/routers/publish.py`
- Test areas:
  - `test/data/`
  - `test/presentation/screens/editor/`
  - `test/presentation/screens/feed/feed_screen_test.dart`
  - `../lab/tests/`
- Fresh external docs verdict: `fresh-docs not needed`; the fix is governed by local app/backend contracts and does not require new Flutter, Dio, Riverpod, FastAPI, Clerk, or external publish API semantics.

## Invariants

- `content_preview` is display-only summary/preview data.
- `ContentItem.body` is authoritative only when it came from a full body field or content body endpoint.
- Direct feed publish and editor publish must use the same full body resolution rule.
- Body saves create new versions in `content_bodies` and edit events in `content_edits`.
- Status transitions remain backend validated.
- Backend ownership checks remain required for content record, body, history, update, and publish access.
- Publish must not be replayed from offline queue as a client-side external side effect.

## Links & Consequences

- `FeedScreen` card previews still need text, so `summary`/preview display must remain available.
- `EditorScreen` can no longer depend on `pendingContentProvider` as its only source of truth.
- `PendingContentNotifier.approve` must be safe both for feed swipe and editor publish.
- `ApiService` cache keys for body/history must stay compatible with offline cache scope.
- `contentHistoryProvider` and pending queue invalidation must remain consistent after approve/reject/save.
- `PlatformPreviewSheet` should preview the resolved editor body, but must not decide what gets published.
- The backend schema already contains `content_bodies` and `content_edits`; implementation should verify production schema but no migration is expected.

## Documentation Coherence

- Update `CHANGELOG.md` after implementation with a short reliability note.
- Update `shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md` only if queue action schema, cache keys, or offline behavior changes.
- No `shipglows_data/product/app/product.md` change is required if this only fixes the existing promised behavior.
- No marketing-site copy change is required.
- If implementation discovers that publish behavior changes user-visible copy, update `lib/l10n/app_localizations.dart` consistently.

## Edge Cases

- Pending list has preview text but body endpoint has no version yet.
- Body endpoint has cached data that belongs to previous auth scope.
- Editor route is opened directly for an item not in the current pending provider.
- Feed is refreshed while editor is open and item disappears because another session approved/rejected it.
- Save body queues offline, but user immediately presses publish.
- Direct feed publish is attempted on an item with connected channels and empty `body`.
- Publish accounts are unavailable after content has been approved.
- Generated body is JSON-like text for social/short content, not Markdown article content.
- Title update and body save have different failure outcomes.

## Implementation Tasks

- [ ] Task 1: Split preview from authoritative body in the content model.
  - File: `lib/data/models/content_item.dart`
  - Action: Stop assigning `content_preview` to `body`; keep preview text in `summary` or an explicit preview field, and ensure `copyWith` preserves body only when a real body is provided.
  - User story link: Prevents preview text from masquerading as complete creator-editable content.
  - Depends on: None.
  - Validate with: New model tests for backend list payload, body payload, and demo payload parsing.
  - Notes: Preserve existing card rendering by using `summary`/preview fallback in `ContentCard`.

- [ ] Task 2: Add an authoritative content detail load path.
  - File: `lib/data/services/api_service.dart`
  - Action: Add or refine a method that can load content record metadata plus latest full body for an id, using `/api/status/content/{id}` and `/api/status/content/{id}/body`; keep cache keys user-scoped through existing mechanisms.
  - User story link: Lets editor and publish use the latest complete content, independent from the feed list.
  - Depends on: Task 1.
  - Validate with: API service tests using representative response maps or a fake transport/server.
  - Notes: If no body version exists, return a typed recoverable error/state rather than preview-as-body.

- [ ] Task 3: Add Riverpod detail state for editor and publish consumers.
  - File: `lib/providers/providers.dart`
  - Action: Add `contentDetailProvider` or equivalent provider family for `contentId`, plus invalidation hooks after save, update, approve, reject, and replay where applicable.
  - User story link: Gives `/editor/:id` and direct feed publish a stable source of latest body state.
  - Depends on: Task 2.
  - Validate with: Provider/unit tests for full body success, body unavailable, stale pending list, and auth/offline error mapping.
  - Notes: Keep provider code near existing content providers and reuse `apiServiceProvider`.

- [ ] Task 4: Refactor editor to depend on content detail, not feed list body.
  - File: `lib/presentation/screens/editor/editor_screen.dart`
  - Action: Load editor title/body from the detail provider; show loading/error/retry for full body; remove the non-empty preview shortcut that skips `fetchContentBody`.
  - User story link: Ensures creators edit the real full body before publication.
  - Depends on: Task 3.
  - Validate with: Widget test where pending item has non-empty preview and body endpoint returns a different full body.
  - Notes: Preserve Markdown preview, audit trail, discard dialog, platform preview, and bottom bar behavior.

- [ ] Task 5: Make direct feed approve/publish resolve latest full body.
  - File: `lib/providers/providers.dart`
  - Action: Update `PendingContentNotifier.approve` so that when publishable channels exist it resolves the latest full body before `api.publishContent`; restore the item to state or preserve previous state on full-body failure.
  - User story link: Prevents one-swipe publish from sending truncated preview text.
  - Depends on: Task 3.
  - Validate with: Provider test for direct approve publishing full body and refusing when body cannot be loaded.
  - Notes: Approval without publish channels may still transition to approved; if publish channels exist but body fails, avoid external publish.

- [ ] Task 6: Make editor save-and-publish use the saved full body.
  - File: `lib/presentation/screens/editor/editor_screen.dart`
  - Action: Save title/body in a recoverable order, update provider/local pending state, then publish using either a body override or a freshly resolved detail body.
  - User story link: Guarantees the creator's latest edits are what gets published.
  - Depends on: Tasks 4 and 5.
  - Validate with: Widget/provider test for edited text being sent to publish after save.
  - Notes: If save queues offline, block publish and show pending sync; do not publish stale server body.

- [ ] Task 7: Preserve preview rendering without body fallback.
  - File: `lib/presentation/screens/feed/content_card.dart`
  - Action: Render card body from `summary`/preview first, then body only when no preview exists; do not require `ContentItem.body` for card display.
  - User story link: Keeps feed UX intact while separating preview from full content.
  - Depends on: Task 1.
  - Validate with: Existing feed widget test plus a new preview-only item case.
  - Notes: Card rendering must stay compact and avoid layout regressions.

- [ ] Task 8: Add backend coverage for body versioning and edit history.
  - File: `../lab/tests/test_status_content_body.py`
  - Action: Add tests for `save_content_body`, `get_content_body`, `get_edit_history`, and ownership-guarded router behavior if practical with existing fixtures.
  - User story link: Proves saved creator edits are durable and auditable.
  - Depends on: Existing backend status service.
  - Validate with: `pytest tests/test_status_content_body.py` from `lab`.
  - Notes: If router auth fixtures are too heavy, cover `StatusService` first and add router ownership coverage in a follow-up.

- [ ] Task 9: Add Flutter regression tests.
  - File: `test/data/content_item_test.dart`
  - Action: Assert `content_preview` does not populate authoritative `body`.
  - User story link: Locks the core bug fix.
  - Depends on: Task 1.
  - Validate with: `flutter test test/data/content_item_test.dart`.
  - Notes: Include a real-body payload case.

- [ ] Task 10: Add editor/feed publish regression tests.
  - File: `test/presentation/screens/editor/editor_screen_test.dart`
  - Action: Add tests for preview-only pending item loading full body, save-and-publish using edited body, and full-body load failure blocking publish.
  - User story link: Proves creators cannot publish preview accidentally through UI flows.
  - Depends on: Tasks 3-6.
  - Validate with: `flutter test test/presentation/screens/editor/editor_screen_test.dart`.
  - Notes: Reuse existing provider override style from `test/presentation/screens/feed/feed_screen_test.dart`.

- [ ] Task 11: Verify Turso migration requirement.
  - File: `../lab/api/migrations/004_status_lifecycle.sql`
  - Action: Check target schema has `content_bodies`, `content_edits`, and `content_records.current_version`; document whether migration is required.
  - User story link: Ensures full-body versioning exists in the durable environment.
  - Depends on: Backend access/config availability.
  - Validate with: `turso db shell contentglowz-prod2 ".schema content_bodies"` or equivalent targeted schema command.
  - Notes: Expected conclusion is "no migration required"; if false, stop and create a migration spec before implementation proceeds.

## Acceptance Criteria

- [ ] CA 1: Given a backend list payload with `content_preview: "Preview"` and no `body`, when parsed into `ContentItem`, then `body` is not `"Preview"` and preview text remains available for card display.
- [ ] CA 2: Given an editor opens a pending item whose card preview is `"Preview"` and body endpoint returns `"Full body"`, when loading completes, then the editor shows `"Full body"`.
- [ ] CA 3: Given body endpoint fails with no cached full body, when the editor opens, then the editor shows retry/error and publish is disabled or blocked.
- [ ] CA 4: Given a creator changes title/body and presses Save & Publish, when save succeeds, then publish receives the edited full body.
- [ ] CA 5: Given a creator swipes right from feed without opening editor, when publishable channels exist, then publish receives the latest full body loaded from the body endpoint.
- [ ] CA 6: Given full body cannot be loaded during feed publish, when the creator swipes right, then no external publish call is made and the item is not silently lost from the pending queue.
- [ ] CA 7: Given save body queues offline, when the creator attempts to publish immediately, then publish is blocked until the queued save is reconciled or the user retries after sync.
- [ ] CA 8: Given a content id owned by another user, when editor/detail/body/history/publish is requested, then backend ownership checks deny access and no cached cross-user body is shown.
- [ ] CA 9: Given a body is saved twice, when edit history is fetched, then the latest version increments and edit history includes both version transitions.
- [ ] CA 10: Given publish accounts are missing or unavailable, when content approval succeeds but external publish cannot proceed, then the user sees explicit approved-but-not-published messaging.

## Test Strategy

- Flutter model tests:
  - parse list payload with preview only,
  - parse full body payload,
  - preserve preview summary for card display.
- Flutter provider tests:
  - content detail success,
  - content detail unavailable,
  - direct approve resolves body before publish,
  - state restored on full-body failure.
- Flutter widget tests:
  - editor opens with full body despite preview,
  - editor blocks publish when body load fails,
  - save-and-publish uses edited text.
- Backend tests:
  - status service body versioning,
  - edit history,
  - optional router body endpoints with ownership guards.
- Manual QA:
  - create or use a generated pending item with a long body,
  - confirm feed card shows preview,
  - open editor and verify full body,
  - edit, save, publish,
  - verify published payload/log uses full edited body.
- Suggested commands:
  - `flutter test test/data/content_item_test.dart`
  - `flutter test test/presentation/screens/feed/feed_screen_test.dart`
  - `flutter test test/presentation/screens/editor/editor_screen_test.dart`
  - `pytest tests/test_status_content_body.py`

## Risks

- High: direct feed publish may currently send preview text; this spec must close that path.
- High: editor may currently skip `fetchContentBody` because preview-filled body is non-empty.
- Medium: adding a detail provider can create stale state if invalidation after save/approve/reject is incomplete.
- Medium: offline body saves can make publish ordering ambiguous.
- Medium: tests may need service/provider seams because `ApiService` currently owns Dio internally.
- Security: content body and history are user-owned and must not leak through cache or direct route access.

## Execution Notes

- Read first:
  - `lib/data/models/content_item.dart`
  - `lib/data/services/api_service.dart`
  - `lib/providers/providers.dart`
  - `lib/presentation/screens/editor/editor_screen.dart`
  - `../lab/api/routers/status.py`
- Implementation order:
  1. Model split.
  2. API/detail load path.
  3. Provider state.
  4. Editor refactor.
  5. Direct feed publish full-body resolution.
  6. Tests.
  7. Turso schema verification conclusion.
- Avoid:
  - treating preview as body anywhere,
  - publishing from stale provider state,
  - adding package dependencies,
  - changing generation agents,
  - client-side replay of external publish.
- Stop conditions:
  - target backend lacks `content_bodies` or `content_edits`,
  - ownership guards are not available on body/history routes,
  - implementation requires external publish API changes,
  - direct feed publish cannot safely restore pending state after body fetch failure.
- Fresh external docs: `fresh-docs not needed`; the work uses existing local HTTP endpoints, storage schema, and provider patterns.

## Open Questions

None for Spec 1. Decision: direct feed publish must pay the cost of resolving full body before publish because correctness is more important than one-swipe latency.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-02 06:03:02 UTC | sf-spec | GPT-5 Codex | Created Spec 1 for full body vs preview reliability | Draft saved | /sf-ready content editing full body preview |
| 2026-05-02 09:49:47 UTC | sf-ready | GPT-5 Codex | Evaluated structure, behavior, dependencies, adversarial gaps, and security posture | ready | /sf-start content editing full body preview |
| 2026-05-02 10:02:08 UTC | sf-start | GPT-5 Codex | Implemented full-body detail loading, publish body resolution, offline publish blocking, and regression coverage | implemented | /sf-verify content editing full body preview |
| 2026-05-02 10:12:28 UTC | sf-verify | GPT-5 Codex | Verified full-body preview reliability, fixed 403/404 body cache fallback, and found validation environment gaps | partial | Run Flutter/backend checks, then /sf-verify content editing full body preview |
| 2026-05-02 10:26:50 UTC | sf-check | GPT-5 Codex | Ran available syntax/dependency checks; Flutter, Dart, Pytest, pip-audit, and Turso CLI are unavailable in this shell | blocked | Install/use the project toolchains, then rerun /sf-check |
| 2026-05-02 13:58:45 UTC | sf-check | GPT-5 Codex | Reran Flutter checks through the provisioned voiceflowz Flox Flutter env; analyze and targeted Flutter tests passed, while backend Pytest, pip-audit, and Turso CLI remain unavailable | partial | Run backend Pytest and Turso schema verification, then /sf-verify content editing full body preview |
| 2026-05-02 14:27:54 UTC | sf-check | GPT-5 Codex | Installed project Flox tooling, reran Flutter analyze/tests and backend body tests; dependency audit and Turso schema proof remain blocked by resolver/auth | partial | Resolve dependency audit, authenticate Turso, then /sf-verify content editing full body preview |
| 2026-05-04 17:43:32 UTC | sf-build | GPT-5 Codex | Continued interrupted verification, fixed editor save/publish ordering, added editor regression coverage, and reran targeted Flutter/backend checks | partial | Resolve dependency audit, authenticate Turso, isolate unrelated dirty files, then rerun /sf-verify content editing full body preview |
| 2026-05-04 18:56:42 UTC | sf-build | GPT-5 Codex | Repaired lab Flox Python/Turso environment, verified backend body tests and dependency audit inside Flox, and confirmed Turso CLI availability | partial | Login to Turso and run schema verification, isolate unrelated dirty files, then rerun /sf-verify content editing full body preview |
| 2026-05-04 19:28:13 UTC | sf-build | GPT-5 Codex | Completed Turso schema proof with `TURSO_API_TOKEN`; production `content_records.current_version`, `content_bodies`, and `content_edits` exist | partial | Isolate unrelated dirty files, then rerun /sf-verify content editing full body preview |

## Current Chantier Flow

- sf-spec: done for Spec 1 draft.
- sf-ready: ready.
- sf-start: implemented.
- sf-verify: partial; code contract reviewed, body cache fallback tightened, editor save/publish ordering fixed, local targeted Flutter/backend tests pass, and Turso schema proof confirms required production tables/columns.
- sf-check: pass for required local checks; `flutter analyze`, targeted Flutter model/provider/editor/feed tests, backend body-history pytest, Flox `pip-audit -r requirements.txt`, and Turso schema proof pass.
- sf-build: partial; continued the lifecycle and verification evidence, but did not close or ship because proof and worktree gates remain unresolved.
- sf-end: not launched.
- sf-ship: not launched.

Next lifecycle command: isolate unrelated dirty files, then `/sf-verify content editing full body preview`.
