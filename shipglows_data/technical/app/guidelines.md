---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: app
created: "2026-04-25"
updated: "2026-07-18"
status: reviewed
source_skill: sf-docs
scope: guidelines
owner: "Diane"
confidence: low
risk_level: medium
security_impact: none
docs_impact: yes
linked_systems: []
evidence:
  - CLAUDE.md
  - shipglows_data/business/business.md
  - shipglows_data/branding/branding.md
depends_on:
  - shipglows_data/business/business.md@0.1.0
  - shipglows_data/branding/branding.md@0.1.0
supersedes: []
next_review: "2026-07-26"
next_step: /sf-docs audit shipglows_data/technical/app/guidelines.md
---
# Development Guidelines

## Scope

This document describes conventions for working in `app`, the Flutter user-facing application in the ContentGlowz ecosystem.

## Tech Stack

- **Flutter** (Dart 3.11+)
- **Riverpod** for state management
- **GoRouter** for navigation and guarded routes
- **Dio** for HTTP + FastAPI API calls
- **Clerk** for session tokens on web auth
- **SharedPreferences** for local cache and offline state

## Source Layout

- `lib/core/`: shared app primitives (app config, diagnostics, prefs providers, localization helpers).
- `lib/data/`: service layer and models (API clients, offline storage/queue, typed domain objects).
- `lib/providers/`: Riverpod providers/notifiers and cross-feature state composition.
- `lib/presentation/`: screens, widgets, theme, and route-facing UI.
- `test/`: unit and widget tests focused on routing, offline behavior, and critical state transitions.
- `shipglows_data/workflow/specs/app/`: product/engineering specs and migration notes.
- `web_auth/`: Clerk runtime assets copied into web builds.

## Architecture Rules

1. Keep API/state logic outside widgets where practical.
2. Prefer feature-level services and models in `lib/data` over ad-hoc `http` calls.
3. Use Riverpod providers for cross-feature side effects and cache lifecycles.
4. Never bypass `AppAccessState` for route gating; routing decisions should stay centralized.
5. Any mutation that has an offline path must explicitly define:
   - queue payload shape,
   - conflict/dependency behavior,
   - reconciliation strategy,
   - user-visible error status.

## Riverpod Migration Policy

- Keep existing manual providers (`StateProvider`, `StateNotifierProvider`) on Riverpod 3 legacy imports (`package:flutter_riverpod/legacy.dart`) unless a dedicated refactor is explicitly scoped.
- Do not introduce new Riverpod codegen (`@riverpod` + generated `.g.dart`) opportunistically during dependency bumps; treat codegen adoption as a separate planned migration.

## Offline and Sync Rules (Mandatory)

- Do not remove or bypass local cache reads when API data is unavailable for read operations.
- Respect sync status states and expose clear labels in UI surfaces.
- Queue entries that depend on unresolved IDs must remain blocked until mapping exists.
- Maintain idempotence and safe retries for local queue replay.
- Keep `OfflineQueueStorage`, `OfflineStorageService`, and local ID mapping logic aligned when changing action schemas.

## Authentication and Access

- Entry/auth routing is controlled by route guards (`AppAccessStage` transitions) and must stay consistent across shell and auth-related screens.
- Avoid forcing navigation into full app flows when bootstrap fails for non-recoverable reasons.
- Preserve the explicit separation between authenticated app mode, demo mode, and entry/auth screens.

## Native Platform Channels

- Keep native platform-channel APIs typed at the service/model boundary before they reach widgets.
- Android MediaProjection work must request fresh user consent per capture session.
- Screen capture and recording must run through foreground-service paths that match the declared Android service type.
- Do not run Android release APK builds on this VM. Local app validation is limited to bounded checks such as `flutter analyze` and `flutter test`; release APK generation belongs to GitHub Actions on the Blacksmith x64 runner path.
- Store captured media files only in app-scoped storage unless a separate export/save-to-gallery scope says otherwise.
- Persist only metadata and local file paths in SharedPreferences; never store binary capture data there.
- Backend capture asset contracts may store metadata and client asset IDs, but must not store device-local file paths as durable server truth.
- Keep backend upload, sync, retention, and storage-cost behavior out of local native capture work unless a separate upload/storage spec is ready.

## UX and Copy Standards

- Surface backend availability state early in flows where users may expect immediate write confirmation.
- Never hide failure states behind generic toasts; show actionable state in-context.
- Use explicit labels on retry/pause/dependency waits.
- Keep loading states concise and specific.
- Every user-triggered asynchronous action must acknowledge the tap immediately:
  disable duplicate submission, show an animated progress indicator, and replace
  the action label with the current step (for example, `Opening Google…`).
- Every page or card waiting on remote/session state must show an animated
  loading state. When progress is measurable (upload, generation, import), use
  a determinate progress indicator; otherwise use an indeterminate indicator
  with a clear status label.
- Never leave an indefinite loading state without a timeout, error/retry path,
  or diagnostics-safe explanation of what is still being checked.

## Testing Requirements

- Add/adjust tests for:
  - provider state transitions,
  - routing guard behavior for access states,
  - offline queueing/replay behavior,
  - bootstrap edge cases.
- Keep tests deterministic by stubbing API/queue/storage boundaries.

## Release Notes

- Update `CHANGELOG.md` for behavior changes, especially around auth and offline capabilities.
- Document newly introduced env vars and migration notes in `README.md` and `.env.example` (or supporting docs).

## Related Files

- `README.md` for quick start and runtime behavior summary.
- `SPEC-offline-sync-v2.md` for replay architecture and acceptance criteria.
- `CHANGELOG.md` for historical context.
