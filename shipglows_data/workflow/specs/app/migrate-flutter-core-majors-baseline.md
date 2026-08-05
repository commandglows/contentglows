---
artifact: execution_log
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-04-27"
updated: "2026-04-27"
status: active
source_skill: sf-start
scope: "migrate-flutter-core-majors-baseline"
owner: "Diane"
confidence: medium
risk_level: "high"
security_impact: "low"
docs_impact: "yes"
depends_on:
  - artifact: "shipglows_data/workflow/specs/app/SPEC-migrate-flutter-core-majors.md"
    artifact_version: "1.1.0"
    required_status: "ready"
supersedes: []
evidence:
  - "Baseline execution log records toolchain, dirty worktree state, dependency matrix, and runtime smoke validation for SPEC-migrate-flutter-core-majors.md."
next_step: "/sf-start Migrate Flutter Core Majors: Riverpod, GoRouter, Google Fonts, Riverpod Codegen"
---

# Migrate Flutter Core Majors Baseline

## Baseline Commands

- `git status --short`: reviewed before dependency edits.
- `git diff --stat`: reviewed before dependency edits.
- `flutter --version`: Flutter `3.41.7` stable, Dart `3.11.5`.
- `flutter pub outdated --mode=null-safety`: failed because the option is no longer supported by the installed Flutter/Dart toolchain.
- `flutter pub outdated`: passed and produced the target matrix below.

## Dirty Worktree Before Migration Edits

The worktree was already dirty before dependency migration edits. Existing modifications must not be reverted or mixed into rollback decisions.

Tracked modified files observed:

- `.gitignore`
- `AGENT.md`
- `shipglows_data/technical/app/architecture.md`
- `AUDIT_LOG.md`
- `shipglows_data/branding/branding.md`
- `shipglows_data/editorial/app/content-map.md`
- `CONTEXT-FUNCTION-TREE.md`
- `shipglows_data/technical/app/context.md`
- `shipglows_data/gtm/app/gtm.md`
- `shipglows_data/product/app/product.md`
- `TASKS.md`
- `pubspec.lock`
- `pubspec.yaml`
- `shipglows_data/workflow/specs/app/PRD-lifetime-deal-early-bird-payg.md`
- `shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md`
- `shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md`
- `shipglows_data/workflow/specs/app/architecture-cible-fastapi-clerk-flutter.md`
- `shipglows_data/workflow/specs/app/feedback-admin-v1-contentglows.md`
- `shipglows_data/workflow/specs/app/feedback-backend-contract-fastapi.md`
- `shipglows_data/workflow/specs/app/foundation-scrollable-nav-affiliations.md`
- `shipglows_data/workflow/specs/app/late-integration-finalization.md`
- `shipglows_data/workflow/specs/app/spec-no-ui-jump-on-resume.md`

Untracked files/directories observed:

- `.fvmrc`
- `.github/`
- `shipglows_data/workflow/specs/app/SPEC-migrate-flutter-core-majors.md`

Additional files changed by this baseline job:

- `TASKS.md`
- `/home/claude/shipglows_data/TASKS.md`
- `shipglows_data/workflow/specs/app/SPEC-migrate-flutter-core-majors.md`
- `shipglows_data/workflow/specs/app/migrate-flutter-core-majors-baseline.md`

## Local Toolchain And SDK

- `.fvmrc`: Flutter `3.41.7`
- `flutter --version`: Flutter `3.41.7`, Dart `3.11.5`
- `pubspec.yaml` SDK constraint: `^3.11.3`
- `pubspec.lock` SDKs: Dart `>=3.11.3 <4.0.0`, Flutter `>=3.38.4`

## Direct Target Matrix

| Package | Current | Resolvable | Latest | Scope decision |
| --- | ---: | ---: | ---: | --- |
| `flutter_riverpod` | `2.6.1` | `3.3.1` | `3.3.1` | migrate in Riverpod runtime lot |
| `riverpod_annotation` | `2.6.1` | `4.0.2` | `4.0.2` | migrate in Riverpod codegen lot |
| `riverpod_generator` | `2.6.5` | `4.0.3` | `4.0.3` | migrate in Riverpod codegen lot |
| `go_router` | `14.8.1` | `17.2.2` | `17.2.2` | migrate after Riverpod validation gate |
| `google_fonts` | `6.3.3` | `8.0.2` | `8.0.2` | migrate after GoRouter validation gate |

## Solver-Visible Adjacent Changes

These are not first-lot targets, but the solver shows they may move when codegen is upgraded:

- `build_runner`: `2.5.4` -> resolvable/latest `2.14.1`
- `analyzer`: `7.6.0` -> resolvable `9.0.0`, latest `13.0.0`
- `source_gen`: `2.0.0` -> resolvable/latest `4.2.2`
- `build`: `2.5.4` -> resolvable/latest `4.0.6`
- `build_resolvers` and `build_runner_core` are discontinued transitives and should be reviewed in the codegen lot.

Do not include unrelated direct package majors such as `json_annotation` or `json_serializable` unless the solver forces them for the scoped migration.

## Rollback Checkpoints By Lot

1. Baseline and dirty worktree:
   - No app code edits.
   - Rollback scope: only this log/spec/task tracker edits if needed.
2. Riverpod runtime:
   - Expected files: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart` only if retry policy is required.
   - Validate: `flutter pub get`, then `flutter analyze`.
3. Riverpod API fixes:
   - Expected files: `lib/providers/providers.dart`, `lib/router.dart`, `lib/core/app_diagnostics.dart`, `lib/core/in_app_tour/in_app_tour_controller.dart`, affected `lib/presentation/**`, affected `test/**`.
   - Validate: state/access/offline/navigation targeted tests before continuing.
4. Riverpod annotation/generator:
   - Expected files: `pubspec.yaml`, `pubspec.lock`, generated files only if existing annotations prove they are required.
   - Validate: `dart run build_runner build --delete-conflicting-outputs` and no unintended Riverpod generated churn.
5. GoRouter:
   - Expected files: `pubspec.yaml`, `pubspec.lock`, `lib/router.dart`, route-related presentation files/tests only if APIs require it.
   - Validate: navigation and feed/projects route tests.
6. Google Fonts:
   - Expected files: `pubspec.yaml`, `pubspec.lock`, `lib/presentation/theme/app_theme.dart` only if API changes require it.
   - Validate: `flutter analyze`, `flutter test test/widget_test.dart`.
7. Full gate and docs:
   - Expected files: docs only after validation proves final package majors and Turso/no-backend conclusion.
   - Validate: `flutter analyze`, `flutter test`, `dart run build_runner build --delete-conflicting-outputs`, `flutter build web`, web smoke.

## Stop Conditions Confirmed

- Stop if `flutter pub get` requires prerelease versions, non-`https://pub.dev` sources, permanent overrides, SDK downgrades, or broad unrelated major drift.
- Stop if auth/access routing, degraded backend mode, offline replay, or diagnostics semantics need product decisions beyond preserving current behavior.
- Stop if any backend API, Turso schema, auth contract, storage payload, or permission behavior change appears.

## Sidecar Audit Summary

Riverpod read-only audit:

- Legacy provider imports are expected in `lib/providers/providers.dart` and `lib/core/in_app_tour/in_app_tour_controller.dart`.
- `AsyncValue.valueOrNull` is widespread, with highest-risk semantics in `lib/providers/providers.dart`, `lib/router.dart`, app shell/widgets, settings/feed/onboarding/drip screens, and `test/core/app_access_resume_test.dart`.
- `lib/core/app_diagnostics.dart` uses the Riverpod 2 `ProviderObserver.providerDidFail` signature and must preserve sanitized provider failure logging.
- No `@riverpod`, `riverpod_annotation`, or Riverpod `.g.dart` parts were found in `lib/` or `test/`.
- Highest-risk behavior to preserve: access/navigation resume states, degraded cached bootstrap behavior, offline queue replay, temp-ID reconciliation, and no duplicate replay from Riverpod automatic retry.

GoRouter read-only audit:

- Core navigation files are `lib/router.dart` and `lib/main.dart`.
- Most GoRouter 17.2.2 APIs used by the app still exist, including `GoRouter`, `MaterialApp.router(routerConfig:)`, `state.uri`, and `state.pathParameters`.
- Keep route gating centralized in `resolveAppRedirect`; do not move gating into `onEnter` without deliberate retesting.
- Preserve `/` -> `/entry`, public route limits, authenticated `/entry` -> `/feed`, no-jump resume states, degraded cached access, lowercase paths, and current query/path parameter behavior.
- Add or preserve a smoke case for `/Feed` versus `/feed` because GoRouter 15+ matching is case-sensitive by default.

## Riverpod Runtime And Codegen Lot Result

Completed on 2026-04-27:

- `flutter_riverpod`: `2.6.1` -> `3.3.1`
- `riverpod_annotation`: `2.6.1` -> `4.0.2`
- `riverpod_generator`: `2.6.5` -> `4.0.3`
- Solver-forced codegen stack updates included `build_runner 2.14.1`, `analyzer 9.0.0`, `source_gen 4.2.2`, and `json_serializable 6.11.4`.
- Removed discontinued transitive `build_resolvers` and `build_runner_core` from the resolved graph.
- Added Riverpod legacy imports for existing `StateProvider`/`StateNotifierProvider` usage.
- Replaced removed `AsyncValue.valueOrNull` reads with Riverpod 3 `AsyncValue.value`.
- Updated `AppDiagnosticsObserver.providerDidFail` to `ProviderObserverContext`.
- Imported Riverpod `misc.dart` where `FutureProviderFamily`/`Override` types are still referenced.
- `dart run build_runner build --delete-conflicting-outputs` wrote `0` outputs.

Validation:

- `flutter pub get`: pass.
- `flutter analyze`: pass.
- `flutter test test/navigation/resume_no_jump_test.dart test/core/app_access_resume_test.dart test/core/offline_sync_test.dart test/widget_test.dart test/core/app_theme_preference_test.dart`: pass.
- `dart run build_runner build --delete-conflicting-outputs`: pass, `0` outputs.

Documented exception before GoRouter:

- `riverpod_generator 4.0.3` is a stable direct dev dependency from `https://pub.dev`, but its own pubspec pins transitive `riverpod_analyzer_utils: 1.0.0-dev.9`.
- This violates the spec's literal "no prerelease" constraint even though it is imposed by the current stable Riverpod generator.
- Accepted by the maintainer on 2026-04-27 as a dev-only transitive exception, not as an application runtime dependency or a direct package choice.

## GoRouter Lot Result

Completed on 2026-04-27:

- `go_router`: `14.8.1` -> `17.2.2`
- `flutter pub get` changed only the `go_router` dependency during this lot.
- No production route, redirect, shell, query parameter, or UI call-site adaptation was required.
- Added a case-sensitive path sanity test proving `/Feed` does not match `/feed`.

Validation:

- `flutter pub get`: pass.
- `flutter analyze`: pass.
- `flutter test test/navigation/resume_no_jump_test.dart test/presentation/screens/feed/feed_screen_test.dart test/presentation/screens/projects/projects_screen_test.dart test/presentation/widgets/project_picker_action_test.dart`: pass.

## Google Fonts Lot Result

Completed on 2026-04-27:

- `google_fonts`: `6.3.3` -> `8.0.2`
- `flutter pub get` changed only the `google_fonts` dependency during this lot.
- `GoogleFonts.interTextTheme` compiled unchanged; no theme code adaptation was required.

Validation:

- `flutter pub get`: pass.
- `flutter analyze`: pass.
- `flutter test test/widget_test.dart test/core/app_theme_preference_test.dart`: pass.

## Full Automated Validation Result

Completed on 2026-04-27:

- `flutter analyze`: pass.
- `flutter test`: pass.
- `dart run build_runner build --delete-conflicting-outputs`: pass, `0` outputs.
- `flutter build web`: pass, built `build/web`.

Runtime smoke status:

- `./scripts/validate-clerk-runtime.sh`: blocked before serving because `CLERK_PUBLISHABLE_KEY` is not set in the local environment.
- Real Clerk/auth browser smoke remains pending.
