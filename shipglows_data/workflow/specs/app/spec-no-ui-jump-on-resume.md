---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-04-25"
updated: "2026-05-10"
status: ready
source_skill: sf-docs
scope: feature
owner: unknown
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
user_story: "unknown (legacy spec migrated to ShipGlowz metadata)"
linked_systems:
  - "Flutter Riverpod app access state"
  - "GoRouter guarded navigation"
  - "ClerkJS web auth"
  - "FastAPI /api/bootstrap"
depends_on: []
supersedes: []
evidence:
  - "Production diagnostics on 2026-05-10 showed duplicate app_access.resolve, /health, and /api/bootstrap calls during Clerk session restore."
  - "User report: Google/Clerk login can emit two authentication codes because a page refresh or redundant auth/access cycle occurs between attempts."
  - "Hosted user retest on 2026-05-10: Clerk/Google auth completed without issue and did not request any authentication code."
next_step: "/sf-verify shipglows_data/workflow/specs/app/spec-no-ui-jump-on-resume.md"
---
# Stabiliser La Reprise Mobile/Web Sans Mouvement UI

Status: ready

## Problem
Lors d'un retour dans l'application (resume mobile ou retour d'onglet web), l'interface effectue un passage visible par `/entry` avant de revenir sur la route precedente. Ce jump casse la continuite de lecture et donne une impression d'instabilite, meme quand la session est valide et que le workspace est deja charge.

Le comportement attendu est strict: les checks session/backend/bootstrap doivent continuer en arriere-plan, mais la route visible ne doit pas changer si l'utilisateur est deja sur une route autorisee.

## Solution
Stabiliser la navigation autour de deux principes: routeur singleton et refresh d'acces non disruptif. Le routeur ne doit plus etre recree a chaque variation de `appAccessStateProvider`, et les transitions internes de stage (`checkingBackend`, `checkingWorkspace`) ne doivent pas provoquer de retour visuel vers `/entry`.

La resolution d'acces continue de tourner au resume pour garder la fiabilite (reauth, backend health, bootstrap), mais elle devient "silent-first": tant que la session reste valide et que la route courante est autorisee, aucune redirection n'est appliquee. Les redirections restent reservees aux cas terminaux explicites (signed out, unauthorized durable, route interdite). Le mode silent est explicite dans l'API de refresh d'acces (pas une convention implicite) afin de distinguer les checks lifecycle des checks utilisateur manuels.

## Scope In
- Supprimer les sauts visuels de route au resume mobile/web quand la session est valide.
- Garder les checks en arriere-plan au resume (session, health, bootstrap).
- Conserver les redirections de securite quand elles sont necessaires.
- Rendre le comportement verifiable par tests ciblant navigation + lifecycle.
- Conserver la telemetrie de diagnostic (`app_access.resolve`, `api.request`) pour observer les checks silent sans bruit UX.

## Scope Out
- Refonte UX de `EntryScreen` ou du contenu marketing.
- Changement de provider d'auth (Clerk) ou de backend contract `/api/bootstrap`.
- Rework global du systeme offline queue au-dela du trigger resume.
- Nouvelle logique metier onboarding/projets.

## Constraints
- Respecter les conventions locales-first de `app` (degraded mode et cache restent actifs).
- Conserver la compatibilite GoRouter existante (`/entry`, `/onboarding`, shell routes, editor route).
- Ne pas introduire de regressions sur les transitions legitimes: signedOut -> `/entry`, ready sur `/entry` -> `/feed`.
- Le comportement doit rester coherent sur Flutter mobile et Flutter web.
- `initialLocation` ne doit plus etre reapplique hors cold start.

## Invariants
- Un utilisateur authentifie sur une route in-app autorisee ne doit pas voir de navigation vers `/entry` juste pour un check de reprise.
- Les stages transitoires (`restoringSession`, `checkingBackend`, `checkingWorkspace`) ne doivent pas imposer de redirection si la route courante est deja valide.
- Les redirections vers `/entry` ne doivent se produire que pour des etats terminaux ou des routes interdites.
- Les checks backend/bootstrap doivent continuer a s'executer au resume.
- Le routeur applicatif doit rester une instance stable tant que le process app n'est pas relance.
- Une meme session auth ne doit pas declencher deux resolutions d'acces concurrentes avec deux appels `/health` puis deux appels `/api/bootstrap`.
- Les protections anti-doublon ne doivent pas masquer les transitions terminales de securite: `bootstrapUnauthorized` doit encore forcer une reauth unique.

## Auth Single-Flight Addendum
Le signal production du 2026-05-10 montre un cas plus strict que le simple no-jump: au retour du flow Clerk/Google, `appAccessStateProvider.build()` et un `refresh()` lance par le bridge offline peuvent partir en parallele. Cela cree des doublons de `GET /health` et `GET /api/bootstrap`, puis amplifie les transitions `bootstrapUnauthorized` et les sign-out locaux. Le correctif doit rendre la resolution d'acces single-flight par session/backend: une resolution deja en cours est rejointe par les refresh concurrents au lieu d'en ouvrir une seconde.

Ce single-flight ne change pas le contrat de securite. Si la resolution partagee conclut a un `401`, l'app garde le comportement actuel: une transition terminale vers `bootstrapUnauthorized`, puis l'utilisateur revient a `/entry` sans boucle.

## Edge Cases
- Reprise sur `/editor/:id` avec edition en cours: aucun jump vers `/entry`.
- Reprise pendant un trou reseau bref: rester sur la route courante, basculer eventuellement en mode degrade sans reroutage.
- Token expire pendant resume: une redirection unique vers `/entry` est acceptable seulement apres confirmation unauthorized.
- Reprise sur `/onboarding?intent=entry`: rester sur onboarding tant que `needsOnboarding` persiste.
- Web avec hash-route profonde (`#/analytics`, `#/projects`): conserver la route visible au retour d'onglet.
- Resume pendant un retry queue long: checks d'acces peuvent finir apres replay, mais sans reset de route.
- Cold start depuis un deep link valide: la stabilisation resume ne doit pas casser le comportement initial de guard.

## Implementation Tasks
- [ ] Task 1: Stabiliser le cycle de vie du routeur pour eviter toute recreation disruptive
  - File: `lib/providers/providers.dart`, `lib/router.dart`
  - Action: Introduire un provider dedie pour `GoRouter` (instance creee une fois), avec route definitions extraites dans `router.dart` pour eviter duplication/derive.
  - Notes: Le routeur doit vivre hors `ContentGlowsApp.build()` pour eliminer l'effet `initialLocation` au resume.

- [ ] Task 2: Connecter MaterialApp au routeur stable
  - File: `lib/main.dart`
  - Action: Remplacer l'appel direct `createAppRouter(ref)` par la lecture du provider de routeur stable.
  - Notes: Aucun changement UX attendu hors disparition du jump `/entry` -> route precedente.

- [ ] Task 3: Separer refresh d'acces "silent" et transitions terminales
  - File: `lib/providers/providers.dart`
  - Action: Ajouter un mode explicite de refresh (ex: `interactive` vs `silentResume`) dans `AppAccessNotifier.refresh(...)`, avec preservation des transitions terminales (`signedOut`, `bootstrapUnauthorized`).
  - Notes: La logique de resolution continue a faire `healthCheck` + `fetchBootstrap`; seule la politique de transition/notification change.

- [ ] Task 4: Adapter le bridge lifecycle pour declencher des checks arriere-plan sans effet de navigation
  - File: `lib/main.dart`
  - Action: Mettre a jour `_OfflineSyncBridge.didChangeAppLifecycleState` et `_triggerReplay` pour utiliser `refresh(silentResume)` lors du `resumed`.
  - Notes: Conserver retry queue + refresh access quand pertinent.

- [ ] Task 5: Durcir les regles de redirect pour ignorer les states transitoires sur routes valides
  - File: `lib/router.dart`
  - Action: Ajuster `redirect` pour que les states transitoires de checks (`checkingBackend`, `checkingWorkspace`) ne renvoient jamais vers `/entry` sur une route deja autorisee; garder redirections terminales strictes.
  - Notes: Le callback `redirect` doit lire l'etat courant (`ref.read(appAccessStateProvider)`) a chaque evaluation et ne pas capturer un snapshot stale pris lors de la creation initiale du routeur.

- [ ] Task 6: Ajouter des tests de non-regression navigation/resume
  - File: `test/navigation/resume_no_jump_test.dart`
  - Action: Creer des tests widget/router qui simulent une route in-app puis un refresh de stage transitoire (`silentResume`), et verifient l'absence de redirection vers `/entry`.
  - Notes: Couvrir au minimum `/feed`, `/editor/:id`, `/onboarding` et cas unauthorized.

- [ ] Task 7: Ajouter un test notifier sur la resolution d'acces au resume
  - File: `test/core/app_access_resume_test.dart`
  - Action: Tester `AppAccessNotifier.refresh(silentResume)` pour verifier que les checks se font sans transition disruptive quand session/backend restent valides, et avec transition vers `/entry` en cas unauthorized.
  - Notes: Mock `ApiService` pour scenarios healthy, degraded, unauthorized.

- [x] Task 8: Dedoublonner les resolutions d'acces concurrentes d'une meme session
  - File: `lib/providers/providers.dart`
  - Action: Ajouter un single-flight interne a `AppAccessNotifier` base sur la session auth courante et l'URL backend, afin que `build()` et `refresh()` concurrents partagent le meme `healthCheck` + `fetchBootstrap`.
  - Notes: Ne pas persister de token; la cle de deduplication reste en memoire et sert seulement a comparer la resolution en cours.

- [x] Task 9: Couvrir le cas double refresh auth/bootstrap
  - File: `test/core/app_access_resume_test.dart`
  - Action: Ajouter un test qui lance deux `refresh()` concurrents et verifie qu'un seul `healthCheck` et un seul `fetchBootstrap` sont executes.
  - Notes: Ce test cible le symptome observe dans les diagnostics production: requetes auth/bootstrap en double.

## Acceptance Criteria
- [ ] AC 1: Given un utilisateur authentifie sur `/feed`, when l'app passe background puis resume, then la route visible reste `/feed` sans passage visuel par `/entry`.
- [ ] AC 2: Given un utilisateur authentifie sur `/editor/123`, when un refresh access est declenche, then aucune redirection vers `/entry` n'a lieu tant que la session reste valide.
- [ ] AC 3: Given un utilisateur authentifie et backend temporairement indisponible, when l'app resume, then la route courante reste stable et l'etat degrade est gere sans jump UI.
- [ ] AC 4: Given un token invalide, when le backend repond unauthorized pendant resume, then l'app redirige vers `/entry` une seule fois et n'effectue pas de boucle de reroutage.
- [ ] AC 5: Given un utilisateur en `needsOnboarding` sur `/onboarding?intent=entry`, when resume est declenche, then la route reste onboarding (pas de passage par `/entry`).
- [ ] AC 6: Given Flutter web sur une route hash profonde, when l'onglet est quitte puis restaure, then l'URL et l'ecran visibles restent inchanges hors cas terminal d'auth.
- [ ] AC 7: Given un resume suivi d'un refresh interactif manuel (ex: action Retry), when le check est relance, then la navigation respecte les memes regles sans reset de route parasite.
- [x] AC 8: Given une session Clerk restauree et deux resolutions d'acces declenchees simultanement, when les checks backend/bootstrap sont en cours, then l'app n'envoie qu'un seul `/health` et un seul `/api/bootstrap`.

## Test Strategy
- Unit: tests notifier sur `AppAccessNotifier` pour transitions de stage en refresh `silentResume` vs `interactive`.
- Unit: test single-flight sur `AppAccessNotifier` pour les refresh concurrents d'une meme session.
- Integration: tests widget/router qui simulent lifecycle resume + updates providers et verifient la route active avec routeur stable.
- Manual: verification sur mobile reel (Android/iOS) et web (Chrome/Safari) avec scenarios: session valide, backend down, unauthorized.

## Risks
- Risque de masquer une vraie redirection necessaire si la regle "silent" est trop permissive.
- Risque de masquer une vraie revalidation si le single-flight fusionne des sessions differentes; mitigation: la cle inclut la session auth et l'URL backend.
- Risque de complexifier le route guard si singleton router + refresh notifier sont mal synchronises.
- Risque de regression sur les flux legitimes depuis `/entry` (signedOut/auth flow) sans couverture test suffisante.
- Risque de divergence entre logs diagnostics et comportement visible si les transitions silent ne sont pas clairement taggees.

## Open Questions
- None

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-10 16:43:17 UTC | sf-tasks | GPT-5 Codex | Recorded hosted user retest: Clerk/Google auth worked without requesting an authentication code. | hosted-validated | Ship the current dirty set, then run sf-end/sf-ship closure. |
| 2026-05-10 16:20:37 UTC | sf-tasks | GPT-5 Codex | Checked dirty state, tracker/changelog alignment, and local verification for the app-access single-flight patch. | tracked | Ship the current dirty set, then retest hosted Clerk restore on the deployed app. |
| 2026-05-10 10:11:50 UTC | sf-build | GPT-5 Codex | Added app-access single-flight protection and regression coverage for concurrent auth/bootstrap refreshes after Clerk restore; local analyze and full Flutter tests pass. | implemented | Hosted Clerk retest remains pending until the backend Clerk env mismatch is corrected and this scope is deployed. |

## Current Chantier Flow

- sf-spec: ready
- sf-ready: ready
- sf-start: implemented
- sf-verify: hosted-passed
- sf-end: pending
- sf-ship: pending
