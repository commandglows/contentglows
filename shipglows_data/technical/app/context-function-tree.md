---
artifact: artifact_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-04-26"
updated: "2026-04-27"
status: reviewed
source_skill: sf-docs
scope: function_tree
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: low
docs_impact: yes
evidence:
  - "lib/main.dart"
  - "lib/router.dart"
  - "lib/providers/providers.dart"
  - "lib/data/services/api_service.dart"
  - "lib/data/services/offline_storage_service.dart"
depends_on: []
supersedes: []
next_review: "2026-07-26"
next_step: "/sf-docs update shipglows_data/technical/app/context-function-tree.md"
---

# CONTEXT-FUNCTION-TREE.md — app

## `lib/main.dart`
- `main()`
  - Initializes Flutter + SharedPreferences + diagnostics.
  - Boots `ProviderScope` with overrides for prefs and diagnostics.
  - Renders `ContentGlowzApp`.
- `ContentGlowzApp`
  - Builds `MaterialApp.router`.
  - Reads language/theme providers.
  - Adds `_OfflineSyncBridge` overlay.
- `_OfflineSyncBridge` (`ConsumerStatefulWidget`)
  - `initState()` -> load queue state + trigger replay.
  - Timer every 30s with replay.
  - `didChangeAppLifecycleState` on resume.
  - Re-listens auth/queue changes to trigger replay.

## `lib/router.dart`
- `appRouterProvider`
- `createAppRouter`
- `resolveAppRedirect`
  - Input: URI + `AppAccessState`.
  - Rules: route redirection by access stage.
- `buildAppRoutes`
  - Route tree: `/entry`, `/auth`, `/feed`, `/calendar`, `/projects`, etc.
  - Most app screens nested under authenticated shell.

## `lib/providers/providers.dart`
- Base and configuration providers
  - `apiBaseUrlProvider`
  - `appLanguagePreferenceProvider`
  - `appThemePreferenceProvider`
  - `offlineStorageScopeProvider`
- Offline stores/state providers
  - `offlineCacheStoreProvider`
  - `offlineQueueStoreProvider`
  - `offlineIdMappingStoreProvider`
  - `offlineQueueEntriesProvider`
  - `offlineSyncStateProvider`
  - `offlineEntitySyncMapProvider`
- Core service providers
  - `apiServiceProvider`
  - `clerkAuthServiceProvider`
  - `feedbackServiceProvider`
- Session/access providers
  - `authSessionProvider` (`AuthSessionNotifier`)
    - methods: restore session, sign in/out, set authenticated session, demo onboarding flags, invalidate state.
  - `appAccessStateProvider` (`AppAccessNotifier`)
    - methods: `refresh()`, `_resolve()` with backend health/bootstrap checks.
- Offline controller
  - `offlineQueueControllerProvider` (`OfflineQueueController`)
    - `retryAll()`, `refresh()`
    - `markReplayError`, `replaceQueue`, temp-id rewrite and cache invalidation hooks.
- Domain data providers (sample)
  - Projects: `projectsStateProvider`, `projectsProvider`, `activeProjectProvider`, `activeProjectIdProvider`.
  - Settings: `currentUserSettingsProvider`.
  - Content: `pendingContentProvider`, `contentHistoryProvider`.
  - Creators: `creatorProfileProvider`.
  - Personas/Affiliations/Ideas: `personasProvider`, `affiliationsProvider`, `ideasProvider`.
  - Drip: `dripPlansProvider`, `dripStatsProvider`.
- Mutation controllers/notifiers
  - `CurrentUserSettings` update and theme/language sync
  - `PendingContentNotifier`
  - `ActiveProjectController` (`setActiveProject`, `clearActiveProject`)
  - `ProjectMutationController` (create/edit/archive/delete/update flows)

## `lib/core`
- `app_config.dart`
  - `AppConfig` + env defines + feedback-admin parsing.
- `app_diagnostics.dart`
  - `AppDiagnostics` with info/warning/error + `buildReport()`.
- `app_language.dart`, `app_theme_preference.dart`
  - Preference normalization and defaults.
- `project_onboarding_validation.dart`
  - URL and repo validation helpers.
- `shared_preferences_provider.dart`
  - SharedPreferences provider root.

## `lib/data/services`
- `api_service.dart`
  - `ApiException` + `ApiErrorType`
  - transport helpers, cache helpers (`_getCachedData`, `_writeCachedData`)
  - offline helpers (`_enqueueOfflineAction`, replay helpers, id mapping, queue status transitions)
  - Domain APIs: bootstrap, projects, settings, creator profile, content, personas, affiliations, ideas, drip, integrations, feedback.
- `offline_storage_service.dart`
  - `OfflineCacheStore`, `OfflineQueueStore`, `OfflineIdMappingStore`
  - cache store read/write/rewrite semantics by scope.
- `clerk_auth_service.dart`, `clerk_auth_service_web.dart`, `clerk_auth_service_android.dart`, `clerk_auth_service_stub.dart`
  - target-selected ClerkJS web bridge, Kotlin Android bridge, and signed-out fallback.

## `android/app/src/main/kotlin/com/contentglowz/contentglowz_app`
- `ContentGlowzApplication`
  - initializes Clerk Android once when a build-injected publishable key exists.
- `MainActivity` + `auth/ClerkAuthChannel`
  - keeps capture/media channels and exposes initialize, Google sign-in,
    restore, fresh token and sign-out to Flutter; Clerk SDK's
    `SSOReceiverActivity` receives its OAuth callback.
- `feedback_service.dart`, `feedback_local_store.dart`
  - feedback submit/list/review orchestration with local draft memory.
- `notification_service.dart`
  - Firebase stub/incomplete integration surface.

## `lib/presentation`
- `screens/app_shell.dart`
  - shell layout (desktop rail / mobile bottom nav)
  - degraded/offline banner and route awareness.
- `router entry screens`: `entry`, `auth`, `onboarding`.
- `feature screens`: `feed`, `projects`, `settings`, `drip`, `feedback`, `uptime`, plus analytics/research/tools screens.
- key status widgets:
  - `widgets/offline_sync_status_chip.dart`
  - `widgets/project_picker_action.dart`
  - `widgets/app_error_view.dart`

## Tests (`/test`)
- `core/` tests: auth access lifecycle, offline stores, route/adaptive behavior, AI guard behavior.
- `presentation/` tests: provider/controller widgets and settings/affiliations UI behavior.
- `widget_test.dart`: baseline theme persistence and app-level rendering smoke checks.
