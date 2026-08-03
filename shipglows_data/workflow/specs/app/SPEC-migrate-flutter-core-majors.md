---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: "app"
created: "2026-04-27"
updated: "2026-04-27"
status: ready
source_skill: sf-spec
scope: "migration"
owner: "Diane"
confidence: medium
user_story: "En tant que mainteneur de ContentGlowz, je veux migrer les dépendances Flutter coeur vers leurs versions majeures actuelles par lots sûrs, afin de réduire la dette de maintenance sans casser l'accès, l'état applicatif, la navigation ni le build web."
risk_level: "high"
security_impact: "low, mitigated by preserving server-side/auth contracts, validating guarded routes, avoiding prereleases/untrusted sources, and keeping diagnostics sanitized"
docs_impact: "yes"
linked_systems:
  - "Flutter web app"
  - "Riverpod state graph"
  - "GoRouter guarded navigation"
  - "Clerk web auth runtime"
  - "FastAPI API_BASE_URL"
  - "shared_preferences local/offline storage"
  - "pub.dev hosted dependencies"
depends_on:
  - artifact: "CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "CLAUDE.md"
  - "shipglows_data/technical/app/guidelines.md"
  - "shipglows_data/business/business.md"
  - "shipglows_data/branding/branding.md"
  - "pubspec.yaml"
  - "pubspec.lock"
  - "lib/main.dart"
  - "lib/router.dart"
  - "lib/providers/providers.dart"
  - "lib/core/app_diagnostics.dart"
  - "lib/core/in_app_tour/in_app_tour_controller.dart"
  - "lib/presentation/theme/app_theme.dart"
  - "test/navigation/resume_no_jump_test.dart"
  - "test/core/app_access_resume_test.dart"
  - "test/core/offline_sync_test.dart"
  - "test/widget_test.dart"
  - "test/presentation/screens/feed/feed_screen_test.dart"
  - "test/presentation/screens/projects/projects_screen_test.dart"
  - "test/presentation/widgets/project_picker_action_test.dart"
next_step: "/sf-start Migrate Flutter Core Majors: Riverpod, GoRouter, Google Fonts, Riverpod Codegen"
---

# Title

Migrate Flutter Core Majors: Riverpod, GoRouter, Google Fonts, Riverpod Codegen

# Status

Ready. This spec resolves the readiness gaps found on 2026-04-27: open hypotheses are closed, metadata is coherent with local docs, current official dependency docs are named, codegen major policy is explicit, and security impact is treated as low but real because the migration touches auth-adjacent route/state behavior and hosted packages.

Implementation status on 2026-04-27: verified. Docs/changelog are updated, runtime Clerk web smoke was manually validated after `CLERK_PUBLISHABLE_KEY` was supplied, generated `build/web` artifacts were cleaned from the diff because Vercel owns the production build, and final rollback/security review found no backend/Turso change, no concrete secret committed, no non-pub.dev package source, and only the documented dev transitive `riverpod_analyzer_utils 1.0.0-dev.9` exception required by stable `riverpod_generator 4.0.3`.

# User Story

En tant que mainteneur de ContentGlowz, je veux migrer les dépendances Flutter coeur vers leurs versions majeures actuelles par lots sûrs, afin de réduire la dette de maintenance sans casser l'accès, l'état applicatif, la navigation ni le build web.

# Minimal Behavior Contract

Quand le mainteneur déclenche la migration des dépendances coeur, l'application doit continuer à accepter les mêmes sessions, préférences locales, routes protégées, états offline et thèmes qu'avant; elle doit produire un lockfile résolu, un build web fonctionnel et des tests verts qui prouvent que l'accès, la navigation et l'état applicatif n'ont pas régressé. Si un package, une API ou le solveur casse un lot, ce lot doit s'arrêter avec une erreur observable et rollbackable sans polluer les autres lots. L'edge case le plus facile à rater est Riverpod 3: les providers legacy, `AsyncValue.valueOrNull`, l'observer de diagnostics, l'automatic retry et la pause des listeners peuvent compiler partiellement tout en modifiant les flows d'accès, de replay offline ou de redirection.

# Success Behavior

- Précondition: le travail démarre dans `/home/claude/contentglowz/app` après lecture du worktree sale; les changements existants non liés ne sont pas revert.
- Action: le mainteneur exécute la migration par lots ordonnés: baseline, Riverpod runtime, Riverpod API fixes, annotation/generator, GoRouter, Google Fonts, full validation, docs.
- Résultat utilisateur/opérateur: l'application démarre avec `ProviderScope`, `ContentGlowzApp`, `MaterialApp.router`, thème light/dark, localizations, offline sync bridge et in-app tour overlay.
- Résultat système: `pubspec.yaml` et `pubspec.lock` résolvent les majors stables compatibles, sans prerelease et sans dependency override permanent.
- Les routes `/`, `/entry`, `/auth`, `/feed`, `/settings`, `/projects`, `/onboarding`, `/editor/:id`, `/feedback`, `/feedback-admin`, `/settings/integrations`, `/angles`, `/templates` et `/drip` conservent leurs contrats de navigation.
- Le no-jump sur resume reste garanti: `restoringSession`, `checkingBackend` et `checkingWorkspace` ne redirigent pas hors des routes utilisables en cours.
- Le mode backend indisponible/degrade garde les utilisateurs authentifiés avec bootstrap cache sur une route utilisable au lieu de hard-fail.
- Les providers Riverpod manuels continuent de fonctionner via imports legacy si nécessaire; aucune conversion massive vers `@riverpod`/Notifier codegen n'est introduite.
- `AppDiagnosticsObserver` continue de journaliser les erreurs providers avec un nom de provider utile et sans exposer de bearer token, clé Clerk complète ou donnée sensible.
- Les tests d'overrides Riverpod et les routers de tests restent compatibles.
- `GoogleFonts.interTextTheme` compile et ne rend pas les tests dépendants du réseau.
- Preuve de succès: `flutter analyze`, `flutter test`, les tests ciblés de route/state/offline/theme, `dart run build_runner build --delete-conflicting-outputs`, `flutter build web`, et un smoke web passent.
- Succès silencieux interdit: chaque lot doit laisser une preuve observable dans les commandes de validation, le diff, ou la note de migration/changelog.

# Error Behavior

- Si `flutter pub get` échoue avant édition applicative, ne pas modifier le code; réduire le lot, noter le conflit exact et stopper.
- Si un lot échoue après édition, rollback uniquement les fichiers touchés par ce lot via patch inverse ciblé ou commit dédié; ne jamais utiliser `git reset --hard` ni checkout large.
- Si le solveur impose une version prerelease, une source non `https://pub.dev`, un override permanent, ou une baisse incompatible de SDK, stopper et rerouter vers décision mainteneur.
- Si Riverpod 3 casse `StateProvider` ou `StateNotifierProvider`, importer `package:flutter_riverpod/legacy.dart` dans les fichiers concernés et ne pas refactorer vers Notifier sauf nécessité de compilation prouvée.
- Si Riverpod 3 supprime `AsyncValue.valueOrNull`, remplacer par `.value` uniquement après audit des loading/error semantics; les routes et écrans doivent conserver le même comportement en loading/error.
- Si automatic retry Riverpod rend les erreurs auth/access/offline ambiguës, désactiver ou borner le retry globalement dans `ProviderScope`/tests ou par provider, puis documenter le choix dans le lot.
- Si `ProviderObserver` ne compile plus, adapter `AppDiagnosticsObserver.providerDidFail` à `ProviderObserverContext` et ignorer les doublons `ProviderException` si la nouvelle API les expose comme dépendances déjà loggées.
- Si GoRouter modifie une signature ou un comportement de matching, corriger production et tests en conservant `state.uri`, `state.pathParameters`, chemins lowercase et garde centralisée dans `resolveAppRedirect`.
- Si Google Fonts casse le build web, l'asset loading ou les tests, garder le lot isolé; utiliser le fallback local/asset documenté ou rollback le lot.
- En cas d'erreur, l'utilisateur/opérateur doit avoir une sortie de commande, un diagnostic ou une note de stop condition; aucun échec silencieux n'est accepté.
- Ce qui ne doit jamais arriver: routes protégées accessibles par contournement, redirection loop, session prête renvoyée vers `/entry`, replay offline répété sans auth valide, lockfile venant d'une source non approuvée, secret complet loggué, ou backend/Turso modifié par cette migration.

# Problem

`app` dépend de packages coeur qui ont plusieurs majors plus récents que les versions verrouillées:

- `flutter_riverpod` est déclaré/verrouillé en `2.6.1`; pub.dev affiche `3.3.1` stable au 2026-04-27.
- `riverpod_annotation` est déclaré/verrouillé en `2.6.1`; pub.dev affiche `4.0.2` stable au 2026-04-27.
- `riverpod_generator` est déclaré en `2.6.5`; pub.dev affiche `4.0.3` stable au 2026-04-27.
- `go_router` est déclaré/verrouillé en `14.8.1`; pub.dev affiche `17.2.2` stable au 2026-04-27.
- `google_fonts` est déclaré/verrouillé en `6.3.3`; pub.dev affiche `8.0.2` stable au 2026-04-27.

Le risque principal n'est pas le bump de versions, mais l'effet croisé sur les surfaces centrales: bootstrap, auth/session restore, guarded navigation, offline replay, provider invalidation, diagnostics, test overrides, codegen transitive dependencies et build web.

# Solution

Exécuter une migration full par lots strictement ordonnés avec validation et stop condition après chaque lot. La politique de version est: viser les dernières versions stables compatibles au moment de l'implémentation, sans prerelease, en acceptant que `flutter_riverpod` soit en 3.x pendant que `riverpod_annotation`/`riverpod_generator` soient en 4.x si pub.dev et le solveur confirment cette combinaison; ne pas forcer artificiellement le même major entre runtime et codegen.

# Scope In

- Mettre à jour `pubspec.yaml` et `pubspec.lock` pour `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `go_router`, `google_fonts`.
- Ajuster `build_runner`, `analyzer`, `source_gen`, `riverpod_analyzer_utils` ou autres dépendances dev uniquement si le solveur/codegen l'exige.
- Adapter imports Riverpod legacy dans `lib/providers/providers.dart`, `lib/core/in_app_tour/in_app_tour_controller.dart` et tout autre fichier utilisant `StateProvider`/`StateNotifierProvider`.
- Adapter tous les usages de `AsyncValue.valueOrNull` dans `lib/` et `test/` en préservant loading/error semantics.
- Adapter `AppDiagnosticsObserver` à la signature Riverpod 3 avec `ProviderObserverContext`.
- Évaluer et configurer explicitement le retry Riverpod si les providers d'accès, d'auth, de bootstrap ou offline ne doivent pas retry par défaut.
- Adapter les tests `ProviderContainer`, `overrideWith`, `overrideWithValue`, async/family providers et listeners.
- Vérifier qu'il n'existe pas de `@riverpod` ni de `part '*.g.dart'` Riverpod; ne pas introduire de generated providers.
- Adapter GoRouter production/tests si signatures ou matching changent.
- Valider `GoogleFonts.interTextTheme` dans `lib/presentation/theme/app_theme.dart`.
- Mettre à jour `CHANGELOG.md` et `shipglows_data/technical/app/guidelines.md` seulement si la migration change commandes, contraintes, imports legacy ou politique codegen.

# Scope Out

- Ne pas refactorer toute la couche state vers `@riverpod`, `Notifier`, mutations ou persistence Riverpod.
- Ne pas activer les fonctionnalités expérimentales Riverpod offline/mutations.
- Ne pas changer routes, noms de chemins, guards, deep links ou contrats d'accès.
- Ne pas migrer Clerk, Dio, shared_preferences, Flutter SDK, Flutter framework, API backend ou packages non listés sauf contrainte transitive obligatoire.
- Ne pas toucher au backend FastAPI, Turso/libSQL, tables, migrations SQL, payloads API ou contrats d'auth.
- Ne pas modifier le design system au-delà d'un ajustement nécessaire à Google Fonts.
- Ne pas supprimer `riverpod_annotation`/`riverpod_generator`; ils restent des dépendances à migrer même si le codegen Riverpod n'est pas utilisé aujourd'hui.

# Constraints

- Respecter `CLAUDE.md`: ne pas hard-fail l'accès app quand FastAPI est indisponible; conserver cached reads/offline mode.
- Respecter `shipglows_data/technical/app/guidelines.md`: ne jamais bypasser `AppAccessState` pour le route gating.
- Collaboration concurrente: relire `git status --short` avant chaque lot et ne pas revert des changements d'autres agents.
- Les lots doivent être petits, validés et rollbackables.
- Les versions exactes doivent être confirmées par `flutter pub outdated`, `flutter pub get` et docs officielles actuelles pendant l'implémentation.
- Toute source package doit rester `https://pub.dev`; pas de path/git dependency ni prerelease.
- Le build web doit rester compatible avec `web_auth/`, Clerk runtime, `shared_preferences` web et `./scripts/validate-clerk-runtime.sh`.
- Les diagnostics ne doivent pas logguer de bearer token complet, clé Clerk complète, ou contenu utilisateur sensible.
- Turso migration attendue: non, parce que la migration est Flutter/frontend dependencies only; si un payload, persistence path ou backend flow change, stopper et appliquer la décision Turso avant ship.

# Dependencies

Local packages currently declared:

- `flutter_riverpod: ^2.6.1`
- `riverpod_annotation: ^2.6.1`
- `go_router: ^14.8.1`
- `google_fonts: ^6.3.3`
- `build_runner: ^2.5.4`
- `riverpod_generator: ^2.6.5`

Locked versions observed:

- `flutter_riverpod 2.6.1`
- `riverpod 2.6.1`
- `riverpod_annotation 2.6.1`
- `riverpod_generator 2.6.5`
- `riverpod_analyzer_utils 0.5.10`
- `go_router 14.8.1`
- `google_fonts 6.3.3`
- `analyzer 7.6.0`
- `flutter_lints 6.0.0`

Fresh external docs verdict: fresh-docs checked on 2026-04-27.

- `flutter_riverpod`: pub.dev versions page shows latest stable `3.3.1`, minimum Dart SDK `3.7`; official changelog and Riverpod migration docs identify relevant breaks: legacy provider imports, `AsyncValue.valueOrNull` removed, `AsyncValue.value` null-on-error, `ProviderObserverContext`, automatic retry, paused listeners, provider update filtering by `==`, ref lifecycle changes, and `ProviderException`.
- `riverpod_annotation`: pub.dev versions page shows latest stable `4.0.2`, minimum Dart SDK `3.7`.
- `riverpod_generator`: pub.dev versions page shows latest stable `4.0.3`, minimum Dart SDK `3.7`; prerelease `4.0.4-dev.1` exists and must not be selected.
- `go_router`: pub.dev versions page shows latest stable `17.2.2`, minimum Dart SDK `3.9`; changelog notes breaking changes in 16.x/17.x around typed routes, case-sensitive matching and ShellRoute observer notifications.
- `google_fonts`: pub.dev page shows latest stable `8.0.2`; docs state support for HTTP fetching, caching and asset bundling; changelog notes WOFF2/WOFF bundled web font changes and font catalog additions/removals.

Official sources consulted:

- https://pub.dev/packages/flutter_riverpod/versions
- https://pub.dev/packages/flutter_riverpod/changelog
- https://riverpod.dev/docs/whats_new
- https://riverpod.dev/docs/3.0_migration
- https://pub.dev/packages/riverpod_annotation/versions
- https://pub.dev/packages/riverpod_generator/versions
- https://pub.dev/packages/go_router/versions
- https://pub.dev/packages/go_router/changelog
- https://pub.dev/packages/google_fonts
- https://pub.dev/packages/google_fonts/changelog

# Invariants

- `ContentGlowzApp` remains bootstrapped through a top-level `ProviderScope`.
- `sharedPrefsProvider` and `appDiagnosticsProvider` remain overridden before app render.
- `appRouterProvider` returns a stable `GoRouter` and disposes `_AppRouterRefreshListenable`.
- `resolveAppRedirect` remains pure and directly testable.
- Root `/` redirects to `/entry`.
- Signed-out and unauthorized users can access `/entry`, `/auth` and `/feedback` only.
- Authenticated ready users entering `/entry` redirect to `/feed`.
- `feedback-admin` access behavior does not become broader than current behavior.
- Demo mode onboarding rules remain intact.
- Backend unavailable/degraded mode keeps cached authenticated users on usable routes.
- `silentResume` does not emit visible intermediate access jumps.
- Offline queue replay preserves temp-ID reconciliation and stops on invalid auth states.
- Provider invalidation continues to refresh workspace/project data after auth, active project and offline replay changes.
- Theme and language preferences persist in `shared_preferences`.
- Tests must not rely on network fonts or external backend calls.
- No generated Riverpod files are created unless an existing annotation requires it; current scan found no `@riverpod` declarations or Riverpod `.g.dart` parts.

# Links & Consequences

- `lib/main.dart`: owns `ProviderScope`, diagnostics observer, shared prefs overrides, `ContentGlowzApp`, `_OfflineSyncBridge`, periodic replay and resume-triggered access refresh.
- `lib/router.dart`: owns guarded redirects, route table, `appRouterProvider`, `_AppRouterRefreshListenable`, `AsyncValue<AppAccessState>` reads and GoRouter signatures.
- `lib/providers/providers.dart`: largest Riverpod surface; uses `StateNotifierProvider`, `StateProvider`, `AsyncNotifierProvider`, `FutureProvider`, `Provider.family`, `.future`, invalidation and many `valueOrNull` reads.
- `lib/core/app_diagnostics.dart`: extends `ProviderObserver`; migration must keep provider failure observability without logging secrets.
- `lib/core/in_app_tour/in_app_tour_controller.dart`: uses `StateNotifierProvider`, `StateNotifier`, `GoRouterState.of(context).uri.path` and `context.go`.
- `lib/presentation/widgets/in_app_tour_overlay.dart`, `project_picker_action.dart`, `app_error_view.dart`, `app_shell.dart`: route and value access surfaces that can regress.
- `lib/presentation/screens/**`: many screens use `valueOrNull`, `context.go`, `context.push`, and `GoRouterState.of`.
- `lib/presentation/theme/app_theme.dart`: imports `google_fonts` and calls `GoogleFonts.interTextTheme` during theme construction.
- `test/core/app_access_resume_test.dart`, `test/navigation/resume_no_jump_test.dart`, `test/core/offline_sync_test.dart`, `test/widget_test.dart`, feed/projects/project picker tests: regression coverage must be updated with production APIs.
- Product consequence: route regressions affect auth handoff, onboarding, feed, projects, editor, settings, feedback and degraded mode.
- Ops consequence: CI/build time and transitive analyzer/codegen dependencies may change.
- Security consequence: dependency source, auth route gating, session logs and replay behavior must be revalidated even though no server auth model changes.

# Documentation Coherence

- `CHANGELOG.md`: add a dated migration entry with package majors and validation commands after implementation.
- `shipglows_data/technical/app/guidelines.md`: update only if the implementation establishes a new convention for `package:flutter_riverpod/legacy.dart`, Riverpod retry policy, GoRouter matching, or Riverpod codegen policy.
- `README.md`: update only if Flutter/Dart minimum setup, commands, or local web smoke flow changes.
- `CLAUDE.md`: expected no change unless mandatory commands or Turso decision wording changes.
- Business, pricing, onboarding copy, screenshots and support docs: no change expected because the user-facing feature contract is intentionally unchanged.
- Existing behavior specs remain contracts to revalidate, not docs to rewrite: `SPEC-offline-sync-v2.md`, `spec-no-ui-jump-on-resume.md`, `SPEC-project-flows-selection-onboarding-archive.md`.

# Edge Cases

- Riverpod 3 moves legacy providers out of `flutter_riverpod.dart`; missing imports can break multiple files at once.
- `AsyncValue.valueOrNull` is widespread; replacing with `.value` must preserve loading/error behavior and not treat error states as ready states.
- Riverpod automatic retry can make failing auth/bootstrap/offline providers appear loading or repeatedly retry, hiding a recoverable failure or duplicating side effects.
- Riverpod pauses listeners for out-of-view widgets; `_OfflineSyncBridge` and route refresh behavior must remain active enough for replay/resume semantics.
- Provider failures may be wrapped in `ProviderException` when rethrown; diagnostics and tests must not double-log or lose root cause.
- Provider update filtering by `==` can suppress updates if mutable objects or equality implementations are surprising.
- Ref/notifier calls after dispose can throw; async notifiers and replay methods must not use stale refs after awaits if analyzer/tests expose issues.
- Test overrides using `overrideWith`/`overrideWithValue` may need signature changes, especially family/async providers.
- GoRouter 16+ treats differently cased URLs as distinct; existing routes are lowercase and smoke should confirm `/Feed` does not accidentally pass as `/feed`.
- ShellRoute observer notification changes in GoRouter 17 may affect route observers or diagnostics if later added; current app has no explicit observer but the route stack must be smoke-tested.
- Google Fonts 8 removes some fonts but not `Inter` per consulted changelog; method existence still must be compiled.
- Web font loading can create test flakiness; widget tests must not wait on external font network.
- Solver may force analyzer/source_gen/build_runner changes; they are allowed only inside the codegen lot with explicit lockfile review.
- Worktree is dirty and the spec file is untracked; migration implementation must isolate diffs from existing unrelated modifications.

# Implementation Tasks

- [x] Tâche 1 : Capture baseline, dirty worktree and target matrix
  - Fichier : `pubspec.yaml`
  - Action : Run `git status --short`, `flutter --version`, `flutter pub outdated`, and record latest stable compatible targets for `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `go_router`, `google_fonts`.
  - User story link : Ensures the migration is current and reversible before changing app behavior.
  - Depends on : none
  - Validate with : `git status --short` and `flutter pub outdated`
  - Notes : Do not edit unrelated dirty files; reject prerelease targets and non-pub.dev sources. `flutter pub outdated --mode=null-safety` was attempted on 2026-04-27 and failed because the installed Flutter/Dart toolchain no longer supports the option.

- [x] Tâche 2 : Establish rollback checkpoints by lot
  - Fichier : repository metadata only
  - Action : Record previous package versions and planned file groups for Riverpod runtime, Riverpod API, codegen, GoRouter, Google Fonts and docs.
  - User story link : Lets maintainers reduce risk without global resets.
  - Depends on : Tâche 1
  - Validate with : `git diff --stat` before first edit and `shipglows_data/workflow/specs/app/migrate-flutter-core-majors-baseline.md`
  - Notes : Previous direct versions are `flutter_riverpod 2.6.1`, `riverpod_annotation 2.6.1`, `riverpod_generator 2.6.5`, `go_router 14.8.1`, `google_fonts 6.3.3`.

- [x] Tâche 3 : Bump Riverpod runtime and choose retry policy
  - Fichier : `pubspec.yaml`
  - Action : Bump `flutter_riverpod` to the latest stable compatible 3.x and add an explicit retry policy in `ProviderScope` only if auth/access/offline providers need default retry disabled or bounded.
  - User story link : Updates state management while preserving access and offline behavior.
  - Depends on : Tâche 2
  - Validate with : `flutter pub get`
  - Notes : Solver required immediate `riverpod_annotation`/`riverpod_generator` alignment; no retry override was added because targeted access/offline tests stayed stable after migration.

- [x] Tâche 4 : Resolve Riverpod legacy provider imports
  - Fichier : `lib/providers/providers.dart`
  - Action : Add `package:flutter_riverpod/legacy.dart` for `StateNotifierProvider` and `StateProvider` if no longer exported by the main package.
  - User story link : Preserves existing manual provider behavior without broad refactor.
  - Depends on : Tâche 3
  - Validate with : `flutter analyze`
  - Notes : Keep provider declarations unchanged unless compilation proves a required API change.

- [x] Tâche 5 : Resolve in-app tour legacy provider import
  - Fichier : `lib/core/in_app_tour/in_app_tour_controller.dart`
  - Action : Add legacy import or minimal API adaptation for `StateNotifierProvider`/`StateNotifier`.
  - User story link : Keeps guided navigation state and persisted tour progress stable.
  - Depends on : Tâche 4
  - Validate with : `flutter analyze`
  - Notes : Do not change `context.go` route behavior.

- [x] Tâche 6 : Migrate redirect `AsyncValue` access
  - Fichier : `lib/router.dart`
  - Action : Replace `valueOrNull` with the Riverpod 3-safe accessor/pattern while preserving loading/error redirect behavior.
  - User story link : Prevents auth and resume routing regressions.
  - Depends on : Tâche 4
  - Validate with : `flutter test test/navigation/resume_no_jump_test.dart`
  - Notes : Error states must not look like authenticated ready states.

- [x] Tâche 7 : Migrate providers `AsyncValue` access
  - Fichier : `lib/providers/providers.dart`
  - Action : Replace or wrap every `valueOrNull` read according to Riverpod 3 semantics and audit each loading/error path.
  - User story link : Preserves app state, degraded reads, project selection and offline replay behavior.
  - Depends on : Tâche 6
  - Validate with : `flutter analyze` and `flutter test test/core/app_access_resume_test.dart test/core/offline_sync_test.dart`
  - Notes : Avoid mechanical changes that turn errors into empty success states unless that was already the old behavior.

- [x] Tâche 8 : Migrate UI/test `AsyncValue` access
  - Fichier : `lib/presentation/`
  - Action : Update `valueOrNull` in screens/widgets and associated tests, preserving visible loading/error states.
  - User story link : Keeps UI rendering stable after state package migration.
  - Depends on : Tâche 7
  - Validate with : `flutter analyze` and targeted widget tests
  - Notes : Include entry, shell, settings, feed, onboarding, integrations, analytics, performance, content tools, drip, uptime, ritual, angles and test files from `rg valueOrNull`.

- [x] Tâche 9 : Adapt diagnostics observer
  - Fichier : `lib/core/app_diagnostics.dart`
  - Action : Update `AppDiagnosticsObserver.providerDidFail` to Riverpod 3 `ProviderObserverContext` and keep provider identity plus sanitized error context.
  - User story link : Maintains operational visibility into provider failures during migration.
  - Depends on : Tâche 3
  - Validate with : `flutter analyze` and `flutter test test/widget_test.dart`
  - Notes : If Riverpod exposes dependency failures as `ProviderException`, avoid duplicate noisy logs while preserving the root failure.

- [x] Tâche 10 : Update Riverpod test overrides and containers
  - Fichier : `test/`
  - Action : Update `ProviderContainer`, `ProviderScope`, `overrideWithValue`, `overrideWith`, async provider overrides and listeners to the new APIs.
  - User story link : Keeps regression suite executable and trustworthy.
  - Depends on : Tâche 4 through Tâche 9
  - Validate with : `flutter test test/core/app_access_resume_test.dart test/core/offline_sync_test.dart test/widget_test.dart`
  - Notes : Do not weaken assertions to make tests pass.

- [x] Tâche 11 : Run Riverpod validation gate
  - Fichier : no source file
  - Action : Run analyzer and state/routing/offline tests after Riverpod runtime/API changes.
  - User story link : Confirms state migration did not regress core behavior.
  - Depends on : Tâche 10
  - Validate with : `flutter analyze` and `flutter test test/core test/navigation/resume_no_jump_test.dart test/widget_test.dart`
  - Notes : Stop before codegen/go_router/google_fonts lots if this fails.

- [x] Tâche 12 : Bump Riverpod annotation and generator
  - Fichier : `pubspec.yaml`
  - Action : Bump `riverpod_annotation` to latest stable compatible 4.x and `riverpod_generator` to latest stable compatible 4.x, with dev dependency adjustments only if solver requires.
  - User story link : Keeps future provider codegen compatible without changing current manual providers.
  - Depends on : Tâche 11
  - Validate with : `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs`
  - Notes : Accept major 4.x for annotation/generator if solver confirms compatibility; do not force same major as `flutter_riverpod`. `riverpod_generator 4.0.3` is stable but depends on transitive dev package `riverpod_analyzer_utils 1.0.0-dev.9`; accepted on 2026-04-27 as a dev-only transitive exception imposed by the stable generator from `https://pub.dev`.

- [x] Tâche 13 : Confirm no unintended Riverpod codegen churn
  - Fichier : `lib/`
  - Action : Search for generated additions/deletions and Riverpod annotations after build_runner.
  - User story link : Avoids accidental architecture changes outside migration scope.
  - Depends on : Tâche 12
  - Validate with : `git status --short` and `rg "@riverpod|part '.*\\.g\\.dart'|part \\\".*\\.g\\.dart\\\"" lib test`
  - Notes : Current expected result is no Riverpod generated provider files.

- [x] Tâche 14 : Bump GoRouter
  - Fichier : `pubspec.yaml`
  - Action : Bump `go_router` to latest stable compatible 17.x.
  - User story link : Updates navigation core while preserving guarded routes.
  - Depends on : Tâche 11
  - Validate with : `flutter pub get`
  - Notes : Confirm Flutter/Dart SDK from `flutter --version`; pub.dev shows 17.2.2 needs Dart 3.9.

- [x] Tâche 15 : Adapt production GoRouter usage
  - Fichier : `lib/router.dart`
  - Action : Update constructor, redirect, `ShellRoute`, `pageBuilder`, `state.uri`, `state.pathParameters`, refresh behavior or matching only if the selected GoRouter version requires it.
  - User story link : Preserves auth gate and no-jump navigation.
  - Depends on : Tâche 14
  - Validate with : `flutter test test/navigation/resume_no_jump_test.dart`
  - Notes : Keep all paths lowercase and unchanged. No production route code adaptation was required for GoRouter 17.2.2.

- [x] Tâche 16 : Adapt UI GoRouter usage
  - Fichier : `lib/presentation/` and `lib/core/in_app_tour/`
  - Action : Update `context.go`, `context.push`, `GoRouterState.of(context).uri`, query/path parameter usage only if required.
  - User story link : Keeps onboarding intents, editor links, settings links and tour navigation working.
  - Depends on : Tâche 15
  - Validate with : `flutter analyze` and affected widget tests
  - Notes : Smoke `/onboarding?mode=create&intent=project-manage`, `/editor/:id`, `/settings/integrations`, `/angles`, `/templates`, `/drip`. No UI GoRouter call-site adaptation was required for GoRouter 17.2.2.

- [x] Tâche 17 : Adapt GoRouter tests
  - Fichier : `test/navigation/resume_no_jump_test.dart`
  - Action : Update direct GoRouter construction and assertions if signatures or matching changed.
  - User story link : Keeps navigation regression coverage alive.
  - Depends on : Tâche 15
  - Validate with : `flutter test test/navigation/resume_no_jump_test.dart`
  - Notes : Added a case-sensitive path sanity check for `/Feed` versus `/feed`.

- [x] Tâche 18 : Adapt feed/project router tests
  - Fichier : `test/presentation/screens/feed/feed_screen_test.dart`
  - Action : Update local router construction and route assertions while preserving destination expectations.
  - User story link : Verifies feed CTAs still route correctly.
  - Depends on : Tâche 16
  - Validate with : `flutter test test/presentation/screens/feed/feed_screen_test.dart`
  - Notes : Do not change expected route destinations. No expected route destination changed.

- [x] Tâche 19 : Adapt projects/project picker tests
  - Fichier : `test/presentation/screens/projects/projects_screen_test.dart`
  - Action : Update local router/provider overrides and assertions if GoRouter/Riverpod APIs require it.
  - User story link : Verifies project management navigation remains stable.
  - Depends on : Tâche 16
  - Validate with : `flutter test test/presentation/screens/projects/projects_screen_test.dart test/presentation/widgets/project_picker_action_test.dart`
  - Notes : Preserve tri-state active project behavior. No production or expected behavior change was required.

- [x] Tâche 20 : Run GoRouter validation gate
  - Fichier : no source file
  - Action : Run analyzer and navigation/widget subsets after GoRouter changes.
  - User story link : Confirms users do not get bounced, blocked or routed incorrectly.
  - Depends on : Tâche 19
  - Validate with : `flutter analyze` and `flutter test test/navigation test/presentation/screens/feed/feed_screen_test.dart test/presentation/screens/projects/projects_screen_test.dart test/presentation/widgets/project_picker_action_test.dart`
  - Notes : Stop if guarded routing regresses.

- [x] Tâche 21 : Bump Google Fonts
  - Fichier : `pubspec.yaml`
  - Action : Bump `google_fonts` to latest stable compatible 8.x.
  - User story link : Updates theme dependency with isolated functional risk.
  - Depends on : Tâche 20
  - Validate with : `flutter pub get`
  - Notes : Keep after state/navigation so font failures are easy to isolate.

- [x] Tâche 22 : Validate theme/font compatibility
  - Fichier : `lib/presentation/theme/app_theme.dart`
  - Action : Confirm `GoogleFonts.interTextTheme` still exists, compiles and does not force network-dependent tests.
  - User story link : Preserves app startup and text rendering.
  - Depends on : Tâche 21
  - Validate with : `flutter analyze` and `flutter test test/widget_test.dart`
  - Notes : If `Inter` API changes unexpectedly, use a documented replacement or asset-bundled fallback; do not redesign theme. `GoogleFonts.interTextTheme` compiled unchanged with `google_fonts 8.0.2`.

- [x] Tâche 23 : Full automated validation
  - Fichier : no source file
  - Action : Run full local quality gate.
  - User story link : Confirms migration is ready for users.
  - Depends on : Tâche 22
  - Validate with : `flutter analyze`, `flutter test`, `dart run build_runner build --delete-conflicting-outputs`, `flutter build web`
  - Notes : Review `pubspec.lock` for unexpected source/major drift.

- [x] Tâche 24 : Runtime web smoke
  - Fichier : no source file
  - Action : Launch the app with project-standard web command and verify entry/auth/demo/onboarding/feed/settings/projects/editor/feedback/degraded backend behavior.
  - User story link : Verifies observable app behavior beyond compilation.
  - Depends on : Tâche 23
  - Validate with : `./build.sh --serve` and `./scripts/validate-clerk-runtime.sh` when Clerk runtime is configured
  - Notes : Completed manually on 2026-04-27 after `CLERK_PUBLISHABLE_KEY` was supplied. The app built with Clerk config, served on `http://localhost:3050`, `/` and `/entry` returned 200, and the browser smoke confirmed both existing-user and new-user Clerk flows work: existing workspace reaches `/feed`, new/no-workspace flow reaches `/onboarding`, refresh/session restore works, and `/api/bootstrap` does not bounce back to `/entry`.

- [x] Tâche 25 : Update developer docs/changelog
  - Fichier : `CHANGELOG.md`
  - Action : Add migration note with final package majors, validation commands and no-Turso conclusion; update `shipglows_data/technical/app/guidelines.md` only for new Riverpod/GoRouter conventions.
  - User story link : Helps future maintainers understand migration consequences.
  - Depends on : Tâche 24
  - Validate with : manual docs diff review
  - Notes : Completed on 2026-04-27 with migration entry in `CHANGELOG.md` and concise Riverpod 3 legacy/codegen policy note in `shipglows_data/technical/app/guidelines.md`. No business/branding docs changed.

- [x] Tâche 26 : Final rollback and security review
  - Fichier : `pubspec.yaml`, `pubspec.lock`, touched Dart/test/docs files
  - Action : Review each lot's diff, package sources, no prereleases, no backend/Turso changes, no secret logging and no widened route access.
  - User story link : Ensures the migration reduces maintenance debt without creating operational/security risk.
  - Depends on : Tâche 25
  - Validate with : `git diff --stat`, `git diff -- pubspec.lock`, route test results and docs review
  - Notes : Completed on 2026-04-27: no backend/Turso files or SQL migrations were touched, package sources remain hosted on `https://pub.dev`, no concrete secret was found outside ignored local env/build artifacts, `build/web` was restored after local smoke because Vercel owns the production build, and the only prerelease is the documented dev transitive `riverpod_analyzer_utils 1.0.0-dev.9` required by stable `riverpod_generator 4.0.3`. Turso migration required: no.

# Acceptance Criteria

- [x] CA 1 : Given the repo is in `/home/claude/contentglowz/app`, when the migration starts, then `git status --short` is reviewed and unrelated dirty files are not reverted.
- [x] CA 2 : Given current official docs and `flutter pub outdated`, when selecting package versions, then only stable compatible pub.dev versions are used and prereleases are rejected, except the documented dev transitive `riverpod_analyzer_utils 1.0.0-dev.9` imposed by stable `riverpod_generator 4.0.3`.
- [x] CA 3 : Given local SDK constraint `^3.11.3`, when selecting GoRouter 17.x, then `flutter --version` and `flutter pub get` prove SDK compatibility.
- [x] CA 4 : Given Riverpod legacy providers exist, when Riverpod runtime is migrated, then `StateProvider` and `StateNotifierProvider` compile via the correct legacy import or documented minimal adaptation.
- [x] CA 5 : Given `valueOrNull` is removed, when all usages are migrated, then loading/error states retain their previous behavior and route guards do not treat errors as ready states.
- [x] CA 6 : Given Riverpod automatic retry is introduced, when auth/access/offline providers fail, then failures remain observable and do not produce duplicate side effects or infinite hidden loading.
- [x] CA 7 : Given provider diagnostics are used, when a provider fails after migration, then `AppDiagnosticsObserver` records a sanitized provider failure with useful context.
- [x] CA 8 : Given a signed-out user, when visiting protected routes, then redirects still land on `/entry` except allowed public feedback/auth routes.
- [x] CA 9 : Given a ready authenticated user, when visiting `/entry`, then the app redirects to `/feed`.
- [x] CA 10 : Given resume states `checkingBackend` or `checkingWorkspace`, when the current route is protected and usable, then the user is not bounced through `/entry`.
- [x] CA 11 : Given backend unavailable/degraded mode with cached bootstrap, when the app refreshes access, then it keeps usable routes instead of hard-failing.
- [x] CA 12 : Given GoRouter is migrated, when navigating to lowercase app routes, then existing destinations and query/path parameter behavior remain unchanged.
- [x] CA 13 : Given a differently cased route like `/Feed`, when GoRouter 16+/17 matching applies, then the app does not accidentally treat it as `/feed` unless explicitly intended.
- [x] CA 14 : Given Google Fonts is migrated, when the theme builds, then `GoogleFonts.interTextTheme` compiles and widget tests do not require external font network.
- [x] CA 15 : Given build_runner runs after annotation/generator migration, when no Riverpod annotations exist, then no Riverpod generated files are added.
- [x] CA 16 : Given `flutter analyze`, `flutter test`, `dart run build_runner build --delete-conflicting-outputs`, and `flutter build web` run, then all pass before the migration is considered complete.
- [x] CA 17 : Given implementation changes developer workflow or conventions, when docs are reviewed, then `CHANGELOG.md` and any relevant `shipglows_data/technical/app/guidelines.md` updates are present.
- [x] CA 18 : Given final diff review, when checking security and data scope, then no backend files, SQL migrations, widened access controls, non-pub.dev package sources, direct prerelease package choices, or secret logs are present.

# Test Strategy

Automated checks:

- `flutter pub get`
- `flutter pub outdated`
- `flutter analyze`
- `flutter test`
- `flutter test test/navigation/resume_no_jump_test.dart`
- `flutter test test/core/app_access_resume_test.dart`
- `flutter test test/core/offline_sync_test.dart`
- `flutter test test/widget_test.dart`
- `flutter test test/presentation/screens/feed/feed_screen_test.dart`
- `flutter test test/presentation/screens/projects/projects_screen_test.dart`
- `flutter test test/presentation/widgets/project_picker_action_test.dart`
- `dart run build_runner build --delete-conflicting-outputs`
- `flutter build web`

Manual/runtime smoke:

- Run `./build.sh --serve` or the project-standard web command.
- Visit `/entry` signed out and verify sign-in/demo/feedback affordances.
- Enter demo and confirm onboarding/feed behavior.
- Navigate to `/settings`, `/projects`, `/onboarding?mode=create&intent=project-manage`, `/feed`, `/drip`, `/angles`, `/templates`, `/editor/test-id` if test data allows.
- Refresh/resume while on `/feed` and `/settings`; verify no transient jump through `/entry`.
- Simulate backend unavailable and confirm cached/degraded mode does not hard-fail authenticated app access.
- Run `./scripts/validate-clerk-runtime.sh` if Clerk runtime is configured.
- Verify light/dark theme text renders without console font-loading errors that block startup.

# Risks

- High: Riverpod 3 can compile after superficial fixes while changing retry/loading/error semantics for auth, access and offline flows.
- High: Widespread `valueOrNull` replacement can hide errors or accidentally empty UI state.
- High: GoRouter major changes can alter protected route matching, redirects or browser URL behavior.
- Medium: ProviderObserver migration can lose diagnostics or double-log dependency failures.
- Medium: Riverpod pause/listener lifecycle changes can affect `_OfflineSyncBridge`, route refresh and replay triggers.
- Medium: Solver may require analyzer/build_runner/source_gen changes beyond direct packages.
- Medium: Dirty worktree and untracked spec increase rollback risk.
- Low/Medium: Google Fonts web asset/caching behavior can alter test determinism or bundle behavior.
- Low: Supply-chain risk from hosted package updates is mitigated by pub.dev-only stable packages, lockfile review and build/test validation.

# Execution Notes

Read first:

- `pubspec.yaml`
- `pubspec.lock`
- `lib/main.dart`
- `lib/router.dart`
- `lib/providers/providers.dart`
- `lib/core/app_diagnostics.dart`
- `test/navigation/resume_no_jump_test.dart`
- `test/core/app_access_resume_test.dart`

Implementation approach:

1. Capture baseline, target matrix and worktree state.
2. Migrate Riverpod runtime and make compile fixes with explicit retry decision.
3. Migrate `AsyncValue`, legacy imports, observer and test overrides.
4. Migrate `riverpod_annotation`/`riverpod_generator` to current stable compatible majors and confirm no generated churn.
5. Migrate GoRouter and revalidate route contracts.
6. Migrate Google Fonts and revalidate theme/build web.
7. Run full gate, smoke, docs, rollback/security review.

Package constraints:

- Use stable pub.dev releases only.
- Do not use prerelease versions, git/path dependencies, permanent overrides or unrelated package upgrades unless the solver requires them and the lockfile diff is reviewed.
- Do not introduce Riverpod experimental offline persistence or mutations.

Stop conditions:

- `flutter pub get` cannot solve without prerelease, non-pub source or broad unrelated major drift.
- Auth/access route tests fail and require product decisions beyond preserving current behavior.
- Riverpod automatic retry causes hidden loading or duplicate side effects that cannot be bounded locally.
- GoRouter requires route contract changes.
- Google Fonts requires design-system changes beyond compile/runtime compatibility.
- Any backend API, Turso schema, auth contract, storage payload or permission behavior change appears.

Security review notes:

- Authorized actors: maintainers/developers running dependency migration locally/CI.
- Non-authorized/misuse cases: route bypass through URL case/query manipulation, stale auth state treated as ready, replay retry after invalid auth, malicious/incorrect package source, secret leakage in diagnostics.
- Trust boundaries: pub.dev package registry, Clerk browser runtime, FastAPI API, local shared preferences, offline queue/cache.
- Mitigations: pub.dev-only stable sources, lockfile review, no backend changes, route guard tests, no secret logging, explicit Turso no-migration conclusion, full build/test/smoke.

# Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-04-27 | sf-verify | GPT-5 | Verified Flutter core major migration against spec, diff, official dependency docs, package resolution, analyze/test/codegen checks, and Clerk runtime smoke availability. | partial | Run Clerk/web runtime smoke, add migration changelog/docs note, then rerun sf-verify. |
| 2026-04-27 | sf-verify | GPT-5 | Re-verified after Clerk smoke success, docs/changelog update, build artifact cleanup, bug gate, dependency/source scan, secret scan, analyze, tests, and codegen gate. | verified | Run /sf-end to close the chantier. |
| 2026-04-27 | sf-end | GPT-5 | Closed the migration chantier after verified checks, docs, task tracker updates, and final security/rollback review. | closed | Run /sf-ship to commit and push the scoped migration changes. |
| 2026-04-27 | sf-ship | GPT-5 | Shipped scoped Flutter core major migration changes after green analyze, tests, codegen, Clerk smoke, docs, and tracker updates. | shipped | None. |

## Current Chantier Flow

- sf-spec: ready
- sf-ready: ready
- sf-start: completed
- sf-verify: verified
- sf-end: closed
- sf-ship: shipped
