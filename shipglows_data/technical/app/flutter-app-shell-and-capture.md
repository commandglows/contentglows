---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: app
created: "2026-05-06"
updated: "2026-08-09"
status: draft
source_skill: sf-docs
scope: flutter-app-shell-and-capture
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - lib/main.dart
  - lib/router.dart
  - lib/providers/providers.dart
  - lib/data/services/api_service.dart
  - lib/data/services/capture_local_store.dart
  - lib/data/models/brand_profile.dart
  - lib/presentation/screens/branding/brand_profiles_screen.dart
  - android/app/src/main/kotlin/
  - test/
depends_on:
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "1.0.0"
    required_status: reviewed
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "Flutter source and Android native capture paths are present in app."
  - "Recent specs cover Android screen capture, local capture assets, offline sync, and content editing."
next_review: "2026-09-09"
next_step: "/sf-docs technical audit app"
---

# Technical Module Context: Flutter App Shell And Capture

## Purpose

This module covers the ContentGlows Flutter app shell, guarded routing, shared provider state, API/offline service layer, and Android capture integration. Agents should load it before changing app startup, navigation, pending content, project state, offline queues, or MediaProjection-related native code.

## Owned Files

| Path | Role | Edit notes |
| --- | --- | --- |
| `lib/main.dart` | App bootstrap | Keep diagnostics and provider initialization explicit. |
| `lib/router.dart` | Route graph and guards | Preserve auth, onboarding, demo, and resume behavior. |
| `lib/providers/providers.dart` | Shared Riverpod state | Avoid broad provider rewrites without focused regression tests. Brand profile mutations must invalidate the project-scoped profile state. |
| `lib/data/services/api_service.dart` | FastAPI client and offline queue | Keep auth, retry, payload, and cache semantics aligned with backend contracts. Canonical branded generation remains the only branding preview request. |
| `lib/data/models/brand_profile.dart` | Brand profile transport model and saved-rule draft | Keep revision/default fields and partial visual/editorial rules aligned with the API contract. |
| `lib/presentation/screens/branding/brand_profiles_screen.dart` | Settings-based brand-rule editor | Keep profile editing separate from timeline instance editing; preview only uses saved profiles and completed content. |
| `lib/data/services/capture_local_store.dart` | Local capture and content link storage | Do not treat local Android paths as durable backend truth. |
| `android/app/src/main/kotlin/**` | Android native bridge | Keep MediaProjection consent, foreground-service behavior, and platform-channel failures observable. |
| `test/**` | Regression coverage | Add focused tests when changing navigation, providers, offline sync, or capture state. |

## Entrypoints

- `flutter analyze`: static analysis for Dart and Flutter app code.
- `flutter test`: regression suite for app state, routing, widgets, and services.
- `lib/main.dart`: runtime app entry.
- `android/app/src/main/kotlin/**`: Android platform-channel entry for native capture behavior.

## Control Flow

```text
app start
  -> main.dart provider/app setup
  -> router.dart guarded route selection
  -> providers.dart state graph
  -> api_service.dart backend/offline operations
  -> capture_local_store.dart local capture metadata when capture flows are used

branding preview
  -> /settings/branding saved project profile
  -> select completed content and confirm an active blueprint
  -> api_service.dart canonical branded-generation request
  -> /editor/:id/video optional edit/review
```

## Invariants

- Auth, onboarding, and resume routing must not jump unexpectedly after app start or session restore.
- App access resolution is single-flight for the same auth session/backend pair: concurrent startup, resume, or manual refresh triggers must share one backend health/bootstrap pass instead of issuing duplicate auth-sensitive requests.
- Offline queues and local caches must not publish or discard user content silently.
- Local capture files remain device-local unless the user explicitly shares/exports or a future upload contract is implemented.
- Backend records must not store raw Android local filesystem paths as durable server truth.
- Android screen capture requires explicit system consent and must stop cleanly when consent, policy, or projection state changes.
- Brand profile edits are project-scoped saved rules for subsequent generations; they must not mutate a timeline draft or requalify an already-started generation.
- Branding preview calls the backend's canonical branded-generation route. The Flutter screen must not add a local renderer or a second video-creation route.

## Failure Modes

- Route guard regressions can strand users in onboarding or close the app unexpectedly.
- Duplicate app-access refreshes can create redundant `/health` and `/api/bootstrap` requests during Clerk restore, amplifying auth failures or causing visible auth churn.
- Provider/cache regressions can show stale project, content, or offline state.
- API payload drift can create backend records that the app cannot reconcile.
- MediaProjection changes can fail only on real Android devices, so emulator-only checks are not enough for final QA.

## Security Notes

- Treat auth tokens, API base URLs, local file paths, and capture metadata as sensitive operational context.
- Do not log secrets, raw tokens, or private local media paths.
- Screen capture is user-consented and Android-only in current specs; do not add silent or background capture behavior.

## Validation

```bash
flutter analyze
flutter test
```

For Android capture changes, add or request real-device QA for MediaProjection consent, stop, preview, discard, and share/export behavior.

## Reader Checklist

- `lib/router.dart` changed -> review route/resume invariants and navigation tests.
- `lib/providers/providers.dart` changed -> review provider state, offline sync, and cache invalidation.
- `lib/data/services/api_service.dart` changed -> review backend payloads, auth behavior, and offline queue semantics.
- Brand profile model, provider, Settings route, or branding screen changed -> review project ownership, default-profile protection, saved-versus-unsaved state, completed-content filtering, and canonical-generation handoff tests.
- `capture` or `android/` paths changed -> review screen-capture specs and require Android QA evidence.

## Maintenance Rule

Update this doc when app routing, provider invariants, API/offline contracts, Android capture behavior, or validation commands change.
