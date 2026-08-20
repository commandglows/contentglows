---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.1"
project: "app"
created: "2026-05-10"
created_at: "2026-05-10 22:30:12 UTC"
updated: "2026-08-20"
updated_at: "2026-08-20 07:48:00 UTC"
status: active
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "En tant que createur ContentGlows, je veux un editeur riche universel pour modifier les articles, newsletters et scripts video avec les memes gestes de base, afin de garder le controle editorial sans apprendre un outil different par format."
risk_level: medium
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter editor"
  - "app Markdown preview"
  - "app Riverpod content detail state"
  - "app ApiService content body save/versioning"
  - "lab status body versioning"
  - "lab publish router"
depends_on:
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-editing-infrastructure.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "User chose option 1 on 2026-05-10: use a universal rich text editor, not format-specialized editors."
  - "lib/presentation/screens/editor/editor_screen.dart currently uses TextEditingController, TextField, and flutter_markdown preview."
  - "pubspec.yaml includes flutter_markdown but no rich text editor package such as Quill, Lexical, Slate, TipTap, ProseMirror, TinyMCE, or CKEditor."
  - "shipglows_data/workflow/specs/app/SPEC-content-editing-infrastructure.md plans a child spec for format-aware editor controls after the full-body reliability foundation."
next_step: "/sf-end content editor multiformat"
---

# Title

Content Editor Multiformat

## Status

Ready child spec. Product decision: V1 is a universal Markdown-backed rich text editor surface shared by articles, newsletters, and video scripts. Format-specific editors, structured scene builders, email-layout builders, arbitrary text colors, and platform-specific social composers remain out of scope for this first pass.

## User Story

En tant que createur ContentGlows, je veux un editeur riche universel pour modifier les articles, newsletters et scripts video avec les memes gestes de base, afin de garder le controle editorial sans apprendre un outil different par format.

## Minimal Behavior Contract

When a creator opens any editable text content, the app loads the authoritative full body, shows one common editing surface, lets the creator apply basic formatting through visible toolbar controls, saves the canonical text body through the existing versioned body endpoint, and previews the rendered result before publish. If formatting cannot be applied safely, saved, rendered, or published, the editor preserves the creator's text and shows a recoverable error instead of corrupting the body or silently dropping formatting.

## Success Behavior

- Given an article, newsletter, or video script opens in the editor, when full body loading succeeds, then the same universal editor surface is shown.
- Given the creator selects or positions text, when they use toolbar controls, then the body is updated with supported formatting syntax and the preview reflects the result.
- Given the creator uses bold, italic, heading, list, quote, link, and paragraph controls, when they save, then the saved body remains compatible with the existing Markdown preview and publish pipeline.
- Given the creator deletes a paragraph, when they save, then the removed paragraph is absent from the next loaded full body version.
- Given the creator publishes after editing, when save succeeds online, then publish uses the edited full body through the existing approve/publish flow.
- Given unsupported format-specific metadata exists, when the universal editor opens, then metadata chips and platform preview remain visible but are not converted into custom editable fields in V1.

## Error Behavior

- If full body loading fails, the editor keeps the existing retry/error behavior and does not open a blank editable body as if it were authoritative.
- If a toolbar operation cannot find a valid selection or insertion point, it must be a no-op or insert safe syntax at the cursor, never throw a UI error.
- If save queues offline, publish remains blocked until the body is saved online, matching the full-body reliability contract.
- If rendered preview cannot display a syntax feature, the editor should either avoid offering that feature or show a non-destructive fallback in raw text.
- If a body contains existing Markdown or JSON-like script text, toolbar operations must not rewrite the whole body or normalize unrelated formatting.
- If content belongs to another user or project, existing backend ownership checks remain authoritative and no cached cross-user body is shown.

## Problem

The app already has a generic editor screen with title/body text fields, Markdown preview, audit trail, and save/publish behavior. That gives creators a way to edit text, but it does not provide familiar rich editing controls such as bold, italic, lists, links, paragraph deletion, or structured formatting actions. The product risk is that users editing long articles, newsletters, and video scripts must manually type syntax or edit raw text, which weakens the human-in-the-loop promise.

## Solution

Add a universal rich editing toolbar and editing behavior on top of the existing editor screen and canonical body lifecycle. V1 is Markdown-backed and must use the existing `TextField`, `TextEditingController`, and `flutter_markdown` preview contracts rather than introducing a dedicated rich-text document model or new editor package.

## Scope In

- One shared editor toolbar for article, newsletter, and video script text bodies.
- Basic formatting: bold, italic, headings, bulleted list, numbered list, quote, inline code or code block where appropriate, link insertion, undo/redo if feasible through controller history or a small local history stack.
- Paragraph operations: split paragraph, delete current paragraph, move paragraph up/down if low-risk, and clear formatting for the current selection.
- Preview remains available and uses the same edited body.
- Save continues through `ApiService.saveContentBody`.
- Publish continues through `PendingContentNotifier.approve` after an online save.
- Tests for toolbar transforms, editor widget behavior, and publish-after-edit.
- Accessibility labels/tooltips for toolbar controls.

## Scope Out

- No separate article/newsletter/video-script editor in V1.
- No drag-and-drop layout builder.
- No email template designer, MJML editor, or newsletter block builder.
- No video scene timeline, shot list manager, teleprompter, or caption editor.
- No arbitrary user-defined text colors in V1. Color/highlight support requires a later spec or explicit renderer/publish decision.
- No AI regeneration, diff review, or prompt-based rewrite flow.
- No backend schema migration unless implementation discovers that body versioning is missing in the target environment.
- No automatic conversion of existing bodies to a new rich text document format.

## Constraints

- Preserve the full-body vs preview invariant from `SPEC-content-editing-full-body-preview.md`.
- Keep the canonical saved body compatible with current backend `content_bodies` versioning.
- Keep external publish online-only.
- Do not add a rich text dependency in V1.
- Do not change the canonical persisted body format away from Markdown-compatible plain text.
- Toolbar buttons must be stable size and usable on mobile and desktop.
- The editor must not hide the raw content so completely that Markdown/script text becomes unrecoverable.

## Dependencies

- App files:
  - `lib/presentation/screens/editor/editor_screen.dart`
  - `lib/presentation/screens/editor/platform_preview_sheet.dart`
  - `lib/data/models/content_item.dart`
  - `lib/data/services/api_service.dart`
  - `lib/providers/providers.dart`
  - `lib/l10n/app_localizations.dart`
  - `pubspec.yaml`
- Tests:
  - `test/presentation/screens/editor/editor_screen_test.dart`
  - `test/data/content_item_test.dart`
  - New focused tests for formatting transforms if helpers are extracted.
- Backend contracts:
  - `../lab/api/routers/status.py`
  - `../lab/status/service.py`
- Fresh external docs verdict: `fresh-docs not needed` for V1 because it uses existing local Flutter `TextField`, `TextEditingController`, and `flutter_markdown` contracts and does not add a new framework, SDK, service, or package. A later dependency-based editor must run a fresh docs/license/platform check in a separate readiness pass.

## Invariants

- `content_preview` remains display-only and never becomes the editable body.
- `ContentItem.body` in the editor is the authoritative full body.
- The saved body is the publish body after successful online save.
- Formatting actions are local text transforms until save.
- Preview is a rendering aid, not the source of truth.
- Body version history and edit audit events stay intact.
- Cross-user and cross-project ownership remains enforced by the backend.

## Links & Consequences

- The toolbar should be implemented as a small reusable widget/helper near the editor, not as ad-hoc formatting code spread through the screen.
- Formatting transforms should be testable without pumping the whole app.
- `flutter_markdown` currently renders preview; unsupported syntax should not appear as toolbar controls unless rendering/publishing is confirmed.
- Platform preview should receive the edited body, not a separately transformed representation.
- If color support is later required, the team must choose whether color is semantic Markdown/HTML, platform metadata, or an editor-only annotation in a separate spec. V1 must not invent this silently.

## Documentation Coherence

- Update `CHANGELOG.md` after the feature ships.
- Update `app/README.md` only if user-facing editing behavior is documented there.
- Update localization strings for toolbar labels and dialogs.
- No marketing-site copy change is required until the feature is actually implemented and verified.

## Edge Cases

- Selection starts or ends inside Markdown delimiters.
- Applying bold to already-bold text.
- Empty selection with toolbar action.
- Multi-paragraph selection.
- Paragraph deletion at start/end of document.
- List toggling on an already-list item.
- Link insertion with invalid or empty URL.
- Generated JSON-like social or short content where Markdown formatting may be undesirable.
- Very long article body causing slow rebuilds or cursor jumps.
- Mobile keyboard covers toolbar or bottom publish actions.
- Save succeeds but metadata update fails.
- Save queues offline and publish is attempted immediately.

## Implementation Tasks

- [ ] Task 1: Confirm V1 body format and dependency choice.
  - File: `pubspec.yaml`
  - Action: Decide between existing Markdown-backed `TextField` toolbar and adding a rich text package. If adding a package, run fresh docs/license/platform review first.
  - User story link: Keeps the editor universal without risking storage or publish compatibility.
  - Validate with: documented decision in the implementation notes or PR.

- [ ] Task 2: Extract formatting transforms into testable helpers.
  - File: `lib/presentation/screens/editor/editor_formatting.dart`
  - Action: Add pure helpers for wrapping selection, toggling headings/lists/quotes, inserting links, deleting paragraphs, and clearing basic Markdown formatting.
  - User story link: Makes toolbar behavior predictable for all content types.
  - Validate with: new unit tests for each transform and edge case.

- [ ] Task 3: Add a universal editor toolbar.
  - File: `lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add stable icon buttons for bold, italic, heading, list, quote, link, delete paragraph, preview/edit toggle, and optional undo/redo.
  - User story link: Gives creators familiar formatting controls without format-specific editors.
  - Validate with: widget tests for visible toolbar and text mutation.

- [ ] Task 4: Add link insertion UI.
  - File: `lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add a small dialog for URL and optional label, applying a Markdown link to selection or cursor.
  - User story link: Lets articles/newsletters/scripts include references without manual syntax.
  - Validate with: widget test for selected text -> Markdown link.

- [ ] Task 5: Preserve preview and publish contracts.
  - File: `lib/presentation/screens/editor/editor_screen.dart`
  - Action: Ensure preview uses the edited body, save uses `saveContentBody`, and publish remains blocked after queued offline save.
  - User story link: Keeps rich editing tied to reliable publication.
  - Validate with: existing save-and-publish test plus a formatted body case.

- [ ] Task 6: Add localization and accessibility labels.
  - File: `lib/l10n/app_localizations.dart`
  - Action: Add toolbar labels/tooltips and link dialog strings.
  - User story link: Makes controls discoverable and usable.
  - Validate with: widget tests can find tooltips; manual keyboard/screen-reader spot check.

- [ ] Task 7: Add mobile/desktop visual QA.
  - File: `test/presentation/screens/editor/editor_screen_test.dart`
  - Action: Add layout smoke tests or manual QA notes for narrow and desktop widths.
  - User story link: Ensures the universal toolbar does not crowd out writing.
  - Validate with: Flutter widget test and manual QA on app web/mobile viewport.

## Acceptance Criteria

- [ ] CA 1: Given a full body is loaded, when the editor opens, then a universal formatting toolbar is visible for articles, newsletters, and video scripts.
- [ ] CA 2: Given text is selected, when Bold is pressed, then the selected text is formatted and preview renders it as bold.
- [ ] CA 3: Given text is selected, when Italic is pressed, then the selected text is formatted and preview renders it as italic.
- [ ] CA 4: Given the cursor is inside a paragraph, when Delete paragraph is pressed, then only that paragraph is removed.
- [ ] CA 5: Given a link is inserted, when save and preview run, then the body stores safe link syntax and the preview shows a link.
- [ ] CA 6: Given formatted text is saved online, when the editor is reopened, then the formatted full body is loaded from the body endpoint.
- [ ] CA 7: Given formatted edits are saved and published, when publish is called, then it receives the edited formatted body.
- [ ] CA 8: Given save queues offline, when the creator tries to publish, then publish is blocked until online save reconciliation.
- [ ] CA 9: Given unsupported color formatting is requested, when V1 ships, then either color is absent from the toolbar or supported by a documented renderer/publish decision.
- [ ] CA 10: Given a long body, when toolbar actions run, then cursor/selection remains usable and the editor does not jump unexpectedly.

## Test Strategy

- Unit tests for formatting helpers:
  - wrap selection in bold/italic,
  - toggle heading/list/quote,
  - insert link,
  - delete current paragraph,
  - no-op on invalid selection.
- Widget tests for editor:
  - toolbar renders,
  - toolbar mutates body controller,
  - preview reflects formatted text,
  - save-and-publish sends formatted edited body,
  - offline queued save blocks publish.
- Regression tests:
  - content preview still does not populate authoritative body,
  - direct editor load still uses `contentDetailProvider`.
- Manual QA:
  - article, newsletter, and video script body,
  - mobile and desktop viewport,
  - keyboard focus and toolbar behavior,
  - platform preview after formatting.

## Risks

- Medium: A Markdown-backed toolbar may feel less rich than a true WYSIWYG editor.
- Medium: Future rich text package adoption could create storage, licensing, web/mobile, or rendering drift, so it is intentionally excluded from V1.
- Medium: Color support can break publish consistency if represented differently per platform, so it is intentionally excluded from V1.
- Medium: Toolbar layout can crowd mobile editing.
- Security: Link insertion can introduce unsafe URLs if later rendered in external contexts without sanitization.
- Data risk: Format transforms must be local and minimal to avoid rewriting long generated bodies unexpectedly.

## Execution Notes

- V1 implementation approach: use a Markdown-backed toolbar on the existing `TextField`, `TextEditingController`, and `flutter_markdown` preview.
- Do not implement arbitrary colors in V1.
- Read first: `lib/presentation/screens/editor/editor_screen.dart`, `lib/presentation/screens/editor/platform_preview_sheet.dart`, `lib/providers/providers.dart`, `lib/data/services/api_service.dart`, and `test/presentation/screens/editor/editor_screen_test.dart`.
- Suggested validation commands: `flutter test test/presentation/screens/editor/editor_screen_test.dart` and `flutter test test/data/content_item_test.dart` from `app`.
- Stop conditions: if the existing text controller cannot support stable selection transforms, if `flutter_markdown` cannot render an offered toolbar feature, if a new package becomes necessary, or if storage format changes become necessary.
- Keep helper functions pure and heavily tested before wiring UI buttons.
- If implementation later needs a new package, stop and create a follow-up spec or readiness note with official docs, license, platform support, and migration/storage implications.
- Preserve `SPEC-content-editing-full-body-preview.md` behavior before starting rich editing work.

## Open Questions

None. V1 excludes color/highlight controls and targets article, newsletter, and video script text bodies. Social/short JSON-like bodies keep the current generic text editor behavior unless a later spec expands the universal toolbar to those formats.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-10 22:30:12 UTC | sf-spec | GPT-5 Codex | Created child spec after user selected universal rich text editor option | Draft saved | /sf-ready content editor multiformat |
| 2026-05-10 22:34:47 UTC | continue | GPT-5 Codex | Routed current chantier to readiness gate and resolved V1 ambiguities | Spec hardened | /sf-ready content editor multiformat |
| 2026-05-10 22:34:47 UTC | sf-ready | GPT-5 Codex | Evaluated readiness after resolving open questions, dependency choice, and validation notes | ready | /sf-start content editor multiformat |
| 2026-05-10 22:34:47 UTC | sf-start | GPT-5 Codex | Implemented universal Markdown-backed editor toolbar, formatting helpers, i18n labels, and targeted tests | implemented | /sf-verify content editor multiformat |
| 2026-05-10 22:51:12 UTC | sf-verify | GPT-5 Codex | Verified implementation against story, tests, and spec contract; found non-blocking gaps in error observability, French accents, and remote-mode evidence | partial | /sf-start content editor multiformat |
| 2026-05-11 05:42:40 UTC | sf-verify | GPT-5 Codex | Re-verified after fixes: URL-empty feedback now visible, FR accents corrected, development mode documented, tests passing | verified | /sf-end content editor multiformat |

## Current Chantier Flow

- sf-spec: done.
- sf-ready: done.
- sf-start: implemented.
- sf-verify: verified.
- sf-end: not launched.
- sf-ship: not launched.

Next lifecycle command: `/sf-end content editor multiformat`.
