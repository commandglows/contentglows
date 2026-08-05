---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-05-10"
created_at: "2026-05-10 22:28:27 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 06:22:56 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "medium"
user_story: "As a ContentGlows operator on mobile, I want the dashboard Flow home to show one clear action card at a time, so I can swipe to postpone or start the next useful action without CTA overload."
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "Flutter FeedScreen empty dashboard"
  - "pendingContentProvider"
  - "dripPlansProvider"
  - "offlineQueueEntriesProvider"
  - "contentHistoryProvider"
  - "GoRouter app routes"
depends_on:
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "app/lib/presentation/screens/feed/feed_screen.dart currently repeats Review creation settings in the hero and Next best actions."
  - "app/lib/presentation/screens/feed/feed_screen.dart currently shows empty status cards for pending review, drip plans, queued actions, and history even when counts are zero."
  - "app/pubspec.yaml already includes flutter_card_swiper and FeedScreen already uses it for review queue cards."
next_step: "/sf-verify shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md"
---

# Title

Mobile Flow Dashboard Swipe Actions

## Status

ready

## User Story

As a ContentGlows operator on mobile, I want the dashboard Flow home to show one clear action card at a time, so I can swipe to postpone or start the next useful action without CTA overload.

## Minimal Behavior Contract

When the Feed/Flow screen has no pending review content, the mobile dashboard renders a Tinder-like deck of onboarding and workspace action cards, one primary card at a time; swiping left dismisses the current action for the current session, swiping right launches that card's recommended route, and tappable buttons provide the same controls for users who cannot or do not want to swipe. If provider data fails or is still loading, the screen must remain usable with the base onboarding actions and must not show empty count cards; the easy-to-miss edge case is that upcoming/drip and review-status cards appear only when there is real content or queued work to act on.

## Success Behavior

On mobile widths below 640 px, an empty pending review queue shows a compact full-screen action deck instead of a long dashboard. The first visible card should be the setup/onboarding action that combines the current hero message with the duplicated "Review creation settings" CTA. Additional cards should represent distinct actions only: create first content, open templates, inspect upcoming content only when at least one drip plan exists, inspect sync queue only when at least one non-terminal queued action exists, and inspect published history only when at least one history item exists. Swiping left removes the card from the current deck and advances to the next action; swiping right navigates to that card's route. Desktop and tablet keep a card-based dashboard, but the mobile path must be the primary design.

## Error Behavior

If drip plans, offline queue, or history providers are loading or fail, the mobile deck must still render the base setup/create/templates cards and omit conditional count-based cards whose counts are unknown. If the deck is exhausted after left swipes, show a compact completion state with refresh and create-content options instead of a blank screen. If route navigation cannot proceed because the widget is unmounted, no state update or snackbar should be attempted.

## Problem

The current empty Feed/Flow dashboard creates mobile CTA overload. The same setup CTA appears in the hero and again in "Next best actions", status cards show zero-value information, and upcoming content cards appear even when nothing is scheduled. This weakens the product's "Swipe to Publish" value because the first authenticated dashboard experience reads like a static admin page instead of an action queue.

## Solution

Replace the mobile empty dashboard with a swipe-first action deck that reuses the existing `flutter_card_swiper` dependency and the Feed screen's existing action model. Keep desktop readable with a less full-screen card deck/grid, and filter all conditional cards so zero-count or unavailable data does not produce empty dashboard noise.

## Scope In

- Redesign `FeedScreen` empty-state dashboard only; pending content review cards stay unchanged.
- Build a mobile-first action deck for widths below 640 px.
- Inventory and deduplicate current CTAs into one card per action.
- Add left/right swipe behavior and equivalent buttons.
- Hide upcoming content, pending review, queue, and history cards unless they have actionable non-zero data.
- Update widget tests for mobile empty state, conditional card visibility, swipe/dismiss, and route navigation.
- Update changelog entry for the dashboard behavior change.

## Scope Out

- No redesign of login, entry, auth, onboarding, or marketing home pages.
- No backend changes, data migrations, or new API fields.
- No changes to pending content approval/publish swipe behavior when actual review items exist.
- No persistent dismiss state across app restarts; left-swipe dismissal is session-local only.
- No new package unless the existing `flutter_card_swiper` cannot support the empty dashboard deck.
- No final publication integration changes.

## Constraints

- Primary language in app copy remains English; French user-facing copy is not introduced in this Flutter screen.
- Existing `flutter_card_swiper` is already available and should be reused.
- Flutter/Riverpod state logic should stay inside `FeedScreen` or small private helpers unless real shared behavior emerges.
- Do not show cards for counts equal to zero.
- Do not introduce UI that depends on viewport-scaled font sizes.
- Keep touch targets at least 44 px and provide non-gesture button alternatives.
- Preserve pull-to-refresh behavior for pending content, drip plans, queue, and history.

## Dependencies

- `app/lib/presentation/screens/feed/feed_screen.dart`
- `app/test/presentation/screens/feed/feed_screen_test.dart`
- `app/lib/l10n/app_localizations.dart` if new visible strings require localization entries
- `app/CHANGELOG.md`
- Fresh external docs verdict: fresh-docs not needed because the implementation reuses the existing Flutter framework patterns and the already-installed `flutter_card_swiper` usage present in `FeedScreen`; no new SDK, package, backend service, auth flow, or API behavior is introduced.

## Invariants

- Pending review content still renders the existing content card swiper and existing approve/reject/edit behavior.
- The setup route keeps the existing active-project-aware behavior: edit mode when an active project exists, create mode otherwise.
- The refresh action still invalidates pending content, drip plans, queue entries, and history.
- Conditional cards must be derived from provider values and never from stale hardcoded counts.
- Swipe right must execute the exact same action as the card's primary button.
- Swipe left must not call backend mutations.

## Links & Consequences

- Feed onboarding becomes the first expression of "Swipe to Publish"; this affects product promise and should be reflected in changelog.
- App accessibility is affected because swipe is a gesture-heavy pattern; buttons and semantic labels are required.
- Existing widget tests that assert the old "Next best actions" and visible drip card behavior must be rewritten.
- `app_localizations.dart` may need extra entries if new labels are not already present in the translation map.
- Design token usage should stay aligned with `AppTheme`, `AppSpacing`, and `AppRadii`.

## Documentation Coherence

- Update `app/CHANGELOG.md` with an app behavior entry.
- README, SETUP, env docs, pricing, and backend docs are not affected because this is a client-side dashboard presentation change.
- No marketing site update is required in this implementation pass, but future product copy can cite the dashboard as proof of "Swipe to Publish" only after browser/device proof passes.

## Edge Cases

- No pending review items and no conditional counts: show only setup, create content, and templates cards.
- Drip count equals zero: no upcoming content queue card.
- Queued action count equals zero: no sync queue card.
- Published count equals zero: no history card.
- All cards dismissed left in one session: show a compact all-caught-up state with create and refresh actions.
- Provider loading/error states: omit count-dependent cards until known, and do not crash.
- Narrow 320 px viewport: card content, buttons, and labels must not overflow.
- Keyboard/screen-reader users: action buttons must expose the same actions as swipe.

## Implementation Tasks

- [x] Task 1: Introduce action-card data model and conditional inventory.
  - File: `app/lib/presentation/screens/feed/feed_screen.dart`
  - Action: Add a private `_DashboardAction` model with title, subtitle/body copy, icon, color, route action, primary label, optional metric, and stable id; build a deduplicated action list from provider counts.
  - User story link: One clear card per useful action.
  - Depends on: None.
  - Validate with: Widget tests asserting no duplicate setup CTA and no zero-count conditional cards.
  - Notes: Keep it private to `feed_screen.dart`.

- [x] Task 2: Replace mobile empty dashboard with swipe deck.
  - File: `app/lib/presentation/screens/feed/feed_screen.dart`
  - Action: Add mobile deck state, render one full-height card stack for compact widths, wire left swipe to session dismissal and right swipe to the action route.
  - User story link: Swipe left to postpone, swipe right to start.
  - Depends on: Task 1.
  - Validate with: Widget tests for left swipe removing first card and right swipe navigating to onboarding.
  - Notes: Reuse `CardSwiper` where practical; if programmatic test stability requires a simpler gesture detector around one card, preserve equivalent behavior and keep the pending-content swiper untouched.

- [x] Task 3: Provide accessible buttons and exhausted-deck state.
  - File: `app/lib/presentation/screens/feed/feed_screen.dart`
  - Action: Add visible bottom controls for Later and Start, plus an all-caught-up state with refresh and create-content actions when every card is dismissed.
  - User story link: Users can act without gesture-only interaction.
  - Depends on: Task 2.
  - Validate with: Widget tests tapping buttons on a 320 px viewport with no overflow exceptions.

- [x] Task 4: Keep desktop/tablet concise without mobile full-screen behavior.
  - File: `app/lib/presentation/screens/feed/feed_screen.dart`
  - Action: Replace the old hero + action cards + status cards with a desktop-friendly card deck/grid that uses the same filtered action inventory and no zero-count status cards.
  - User story link: Desktop still has action clarity without mobile full-screen dominance.
  - Depends on: Task 1.
  - Validate with: Existing wide widget pump still finds one setup action and conditional cards only when applicable.

- [x] Task 5: Update localization strings if needed.
  - File: `app/lib/l10n/app_localizations.dart`
  - Action: Add English-to-French entries for any new strings introduced by the redesign.
  - User story link: Visible copy remains coherent across supported locales.
  - Depends on: Tasks 2-4.
  - Validate with: `flutter test test/presentation/screens/feed/feed_screen_test.dart`.

- [x] Task 6: Rewrite focused widget tests.
  - File: `app/test/presentation/screens/feed/feed_screen_test.dart`
  - Action: Replace assertions tied to the old dashboard with tests for filtered cards, action navigation, mobile dismissal, narrow viewport, and unchanged pending-content swiper.
  - User story link: Verifies the redesigned mobile dashboard behavior.
  - Depends on: Tasks 1-5.
  - Validate with: `flutter test test/presentation/screens/feed/feed_screen_test.dart`.

- [x] Task 7: Add changelog note.
  - File: `app/CHANGELOG.md`
  - Action: Add an Unreleased entry describing the mobile Flow dashboard swipe-action redesign.
  - User story link: Documents the user-visible behavior change.
  - Depends on: Implementation complete.
  - Validate with: Manual read.

## Acceptance Criteria

- On a 320 px wide viewport with no pending content, the Feed/Flow screen shows one dominant action card, not a long list of CTA cards.
- The setup action appears once, combining the old hero/setup CTA and duplicated "Review creation settings" action.
- "Upcoming content queue" appears only when `dripPlansProvider` has one or more plans.
- No pending review/status card with value `0` is shown when there are no pending items.
- Swiping or dragging left on the current mobile action card dismisses it for the current screen session and advances to the next card without navigation.
- Swiping or dragging right on the current mobile action card navigates to the card's recommended route.
- Dragging horizontally gives visible motion feedback before release: the current card translates with the pointer, rotates slightly, exposes a direction label, and exits the deck before the action is applied.
- Dashboard action cards use a filled visual template with icon-led explanation rows, short copywriting, and fixed bottom action controls so the mobile card feels intentionally full rather than sparse.
- Pending content cards expose a format-aware review template so articles, newsletters, shorts, videos, and social posts show the specific checks the user should validate before swiping.
- Visible buttons provide the same Later and Start actions.
- Pending content items still use the existing content review swiper and are not replaced by onboarding cards.
- No overflow or layout exception occurs on a 320 x 720 test viewport.

## Test Strategy

- Run `flutter test test/presentation/screens/feed/feed_screen_test.dart` from `app`.
- Run `flutter analyze` from `app` if local Flutter tooling is healthy.
- Widget tests should cover empty deck mobile, conditional drip visibility, active-project setup routing, button fallback, swipe/dismiss behavior, and pending-content preservation.
- Manual browser/device proof is recommended after implementation because the design goal is mobile visual quality.

## Risks

- `flutter_card_swiper` may be awkward for an empty dashboard deck in widget tests; mitigation is to use the package only if it remains stable, otherwise implement equivalent left/right drag behavior locally for the onboarding deck while preserving the existing review swiper.
- CTA filtering could accidentally hide a useful recovery action; mitigation is to keep base setup/create/templates cards always available.
- Gesture-first UI can hurt accessibility; mitigation is visible buttons and semantic labels.
- Desktop could regress if the old dashboard is removed without replacement; mitigation is a shared filtered action inventory rendered differently by width.

## Execution Notes

Read `app/lib/presentation/screens/feed/feed_screen.dart` first, especially `_FeedEmptyDashboard`, `_HeroCard`, `_ActionCard`, `_StatusCard`, and the existing pending-content swiper. Keep the implementation scoped to this file plus tests/localization/changelog. Prefer private widgets and helpers over new shared abstractions. Use `LayoutBuilder` to branch mobile vs non-mobile. Keep all provider refresh invalidations intact. Stop if the redesign requires persistent dismiss state, backend task state, or new content scheduling semantics; those are out of scope.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-10 | sf-spec | GPT-5 Codex | Created spec for mobile Flow dashboard swipe-action redesign. | reviewed | /sf-ready shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |
| 2026-05-10 | sf-ready | GPT-5 Codex | Checked structure, behavior contract, implementation tasks, acceptance criteria, security posture, and open questions. | ready | /sf-start shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |
| 2026-05-10 | sf-start | GPT-5 Codex | Implemented the mobile swipe-action deck, filtered dashboard action inventory, localization entries, tests, and changelog note. | implemented | /sf-verify shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |
| 2026-05-10 | sf-design | GPT-5 Codex | Orchestrated the dashboard redesign from spec-first gate through local design implementation and checks. | implemented | /sf-verify shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |
| 2026-05-11 | sf-design | GPT-5 Codex | Added live swipe animation feedback with translation, rotation, directional labels, and exit motion before start/later callbacks. | implemented | /sf-verify shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |
| 2026-05-11 | sf-design | GPT-5 Codex | Enriched onboarding action cards with icon-led copy blocks and added format-aware review templates for pending content cards. | implemented | /sf-verify shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |
| 2026-05-11 | sf-design | GPT-5 Codex | Fixed left-swipe completion so the next card starts with a fresh deck state instead of inheriting the outgoing card transform. | implemented | /sf-verify shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |

## Current Chantier Flow

sf-spec ✅ -> sf-ready ✅ -> sf-start ✅ -> sf-verify ⏳ -> sf-end ⏳ -> sf-ship ⏳
