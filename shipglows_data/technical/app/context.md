---
artifact: technical_context
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: app
created: "2026-04-26"
updated: "2026-08-09"
status: reviewed
source_skill: sf-docs
scope: technical
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
evidence:
  - "README.md"
  - "CLAUDE.md"
  - "lib/main.dart"
  - "lib/router.dart"
  - "lib/providers/providers.dart"
  - "lib/data/services/api_service.dart"
  - "lib/data/services/offline_storage_service.dart"
  - "lib/data/models/brand_profile.dart"
  - "lib/presentation/screens/branding/brand_profiles_screen.dart"
  - "shipglows_data/workflow/specs/app/architecture-cible-fastapi-clerk-flutter.md"
  - "shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md"
depends_on:
  - artifact: "README.md"
    artifact_version: "0.1.0"
    required_status: "reviewed"
  - artifact: "CLAUDE.md"
    artifact_version: "0.1.0"
    required_status: "reviewed"
supersedes: []
linked_systems:
  - "lab FastAPI"
  - "Clerk"
next_review: "2026-09-09"
next_step: "/sf-docs update shipglows_data/technical/app/context.md"
---

# shipglows_data/technical/app/context.md — app

## Product technical context
`app` is the primary Flutter application for ContentGlows. It hosts:
- Entry/auth gate (`/entry`, `/auth`).
- Authenticated shell and feature screens (`/feed`, `/projects`, `/drip`, `/settings`, etc.).
- Feature state orchestration via Riverpod providers and a FastAPI-backed `ApiService`.
- Project-scoped intelligence, capture, and timeline surfaces that depend on
  backend-owned data and render contracts.

## Source-of-truth stack
- **UI framework:** Flutter 3.11+
- **State layer:** Flutter Riverpod (single `providers.dart` root)
- **Routing:** GoRouter with refreshable auth redirect gate
- **Backend transport:** Dio client in `lib/data/services/api_service.dart`
- **Identity/auth:** Clerk web bridge (`contentglowsClerkBridge`) and tokens forwarded to FastAPI
- **Persistence:** SharedPreferences for prefs + offline cache/queue/id-mapping stores
- **Build chain:** Flutter web -> injected Clerk keys/runtime metadata via `build.sh` and `scripts/*`
- **Android release boundary:** APK release builds are CI-only on GitHub Actions/Blacksmith; this VM is not an approved release-build surface.

## Runtime domains
- **Authentication/session domain:**
  - Session restoration, token fetch, sign-out, and unauthorized response handling are centralized in provider notifiers.
- **Bootstrap/access domain:**
  - `AppAccessNotifier` computes stages (`restoringSession`, `signedOut`, `demo`, `apiUnavailable`, `bootstrapFailed`, `needsOnboarding`, `ready`).
- **Feature domains:**
  - Projects, workspace/settings, creator profile, personas, content pipeline, integrations, analytics-like views, feedback, affiliations/link management, webhooks, conversions, UTM templates.
  - `Affiliations / Link Management`: CRUD for affiliate links, slug-based public short links (`/r/{slug}`), click telemetry, and A/B destination rotation via `LinkVariant`. The public redirect endpoint is unauthenticated; analytics and variant management require Clerk auth.
  - `Project Intelligence V1`: read project intelligence status, source inventory, extracted facts, recommendations, provider readiness, upload text-like sources, remove sources, and convert recommendations into Idea Pool items.
  - `Video Timeline V1`: online-only timeline editing and preview/final render orchestration for `/editor/:id/video`, with `lab` as the public API boundary and the Remotion worker hidden behind backend contracts. Product execution reference: `shipglows_data/workflow/specs/monorepo/SPEC-professional-video-editor-capability-roadmap-2026-08-09.md` (Filmora/PixVerse-inspired, one-canonical-timeline approach).
  - `Brand Profiles`: project-scoped rule records loaded through `brandProfilesStateProvider` and changed through `BrandProfileController`. Settings exposes them at `/settings/branding`; saved rules can become the default for subsequent generations.
  - `Brand templates`: resolved blueprint instances generated from profiles (and optional saved blueprint selections) are immutable inputs to `generateBrandedVideoFromContent`; they drive automatic timeline assembly with format-specific derivation (reels, shorts, linkedin, youtube), and do not replace the timeline model.
  - Preview flow: completed content selection calls canonical branded-generation then opens `/editor/:id/video` so edits remain on the same timeline object.
  - Persona metadata in the preview content list is optional; if persona data is unavailable, selection still continues and only labels degrade.
  - Android local capture: screenshot/recording flows backed by MediaProjection and app-scoped storage.
- **Offline domain:**
  - Read-through cache + mutation queue + temp-ID reconciliation via offline stores and queue controller.

## Build/runtime environment matrix
- Required (or optional) defines and env:
  - Required for release flow: `API_BASE_URL`, `CLERK_PUBLISHABLE_KEY`.
  - App/marketing links: `APP_SITE_URL`, `APP_WEB_URL`.
  - Optional for feedback/admin logic: `FEEDBACK_ADMIN_EMAILS`.
  - Build metadata (defined in scripts and README): `BUILD_COMMIT_SHA`, `BUILD_ENVIRONMENT`, `BUILD_TIMESTAMP`.
- `server.js` serves SPA fallback plus `/sign-in|/sign-up|/sso-callback` directories.
- Vercel rewrites preserve auth and SPA paths; build scripts inject Dart defines and Clerk runtime assets.
- Android release proof comes from GitHub Actions artifacts/logs, not from local VM builds.

## Architecture flow (inferred)
1. App bootstrap (`main`) wires diagnostics + preference providers.
2. Router reads `appAccessStateProvider` and redirects based on auth/session stage.
3. Feature screens consume providers for typed async data.
4. Mutating actions go through `ApiService` (`_enqueueOfflineAction` or direct call depending connectivity/offline policy).
5. Offline controller schedules replay on startup, resume, login and manual trigger.
6. Diagnostics and diagnostics reports support incident copy/paste.

## Offline sync + queue context
- Store keys:
  - `offline_cache_v1`
  - `offline_queue_v1`
  - `offline_id_mappings_v1`
- Behavior:
  - Cache is user-scoped and stale-state visible in UI when fallback is active.
  - Queue actions are deduplicated and rewritten with temp-ID mappings on successful create responses.
  - Replay is best-effort with status transitions (`pending`, `retrying`, `blockedDependency`, `pausedAuth`, `failed`).

## External integration boundaries
- **ClerkJS routes** are generated in `web_auth/*` and injected into build output by scripts.
- **FastAPI** remains backend contract boundary; mobile/desktop-specific auth branches are not currently enabled by production code.
- **Feedback admin** uses backend endpoints with optional local draft/submission cache.
- **Project Intelligence** is project-scoped and backend-constrained; offline queue does not cover file/binary uploads for this surface.
- **Video Timeline** never calls the Remotion worker directly from Flutter; signed playback URLs are ephemeral response data and must not be persisted with their query tokens.
- **Brand Profiles** use the authenticated project-scoped FastAPI contract. The client may request a canonical branded generation with a saved `brand_profile_id`, but it must not treat an unsaved form as render input or retroactively alter an in-flight generation.
- **Brand template / blueprint flow** must remain rule-only: the app may choose profile/blueprint IDs and defaults, but only the backend-owned `/api/video-timelines/from-content/branded-generate` contract can create/update timeline draft content.

## Testing references
- `test/core` validates providers, retry behavior, queue mapping, project onboarding validation, AI guards.
- `test/presentation` validates selected UI/setting behavior and picker controller interactions.
- `flutter test` is the project-wide check for behavioral stability.
