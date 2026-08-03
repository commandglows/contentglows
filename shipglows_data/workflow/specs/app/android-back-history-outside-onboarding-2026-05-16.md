---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-05-16"
created_at: "2026-05-16 14:15:47 UTC"
updated: "2026-05-17"
updated_at: "2026-05-17 13:40:14 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant qu'utilisateur Android de ContentGlowz, je veux que le bouton système Back remonte l'historique de navigation interne avant de proposer de fermer l'app, afin d'éviter des sorties prématurées quand j'explore des actions hors onboarding."
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "app/lib/router.dart"
  - "app/lib/presentation/screens/app_shell.dart"
  - "app/lib/presentation/screens/onboarding/onboarding_screen.dart"
  - "app/lib/presentation/widgets/app_exit_confirmation.dart"
  - "app/test/navigation/"
  - "app/test/presentation/screens/"
depends_on:
  - artifact: "app/CLAUDE.md"
    artifact_version: "unknown"
    required_status: "active"
  - artifact: "shipglows_data/workflow/bugs/app/BUG-2026-05-05-002.md"
    artifact_version: "1.0.0"
    required_status: "closed"
supersedes: []
evidence:
  - "2026-05-16 user retest note after BUG-2026-05-05-002: outside onboarding, Android Back proposes app exit directly although an action history may exist."
  - "Code inspection 2026-05-16: AppShell wraps shell routes in PopScope and calls confirmAndExitApp when ModalRoute.of(context)?.isFirst is true."
  - "Code inspection 2026-05-16: many action/detail routes use context.push(), while tab/rail navigation uses context.go()."
  - "Code inspection 2026-05-16: onboarding already has a separate page-level Back contract and must not regress."
next_step: "/sf-test Android back history outside onboarding on Android device"
---

# Title

Android back history outside onboarding

## Status

Spec prête pour implémentation, créée le 2026-05-16 pour clarifier le comportement Android Back hors onboarding.

Cette spec ne réouvre pas `BUG-2026-05-05-002`. Ce bug est clôturable sur son contrat initial: Back dans le wizard onboarding revient à l'étape précédente puis demande confirmation avant fermeture. Le besoin ici est plus large: définir quand Back doit remonter une pile de navigation interne dans le shell ContentGlowz, et quand il doit proposer de fermer l'app.

## User Story

En tant qu'utilisateur Android de ContentGlowz, je veux que le bouton système Back remonte l'historique de navigation interne avant de proposer de fermer l'app, afin d'éviter des sorties prématurées quand j'explore des actions hors onboarding.

Acteur principal: utilisateur Android signed-in ou demo.

Déclencheur: l'utilisateur appuie sur le bouton système Back depuis un écran ou sous-flow de l'app hors onboarding.

Résultat observable: si une destination interne précédente existe, l'app y revient; sinon elle affiche la confirmation de fermeture existante.

## Minimal Behavior Contract

Quand l'utilisateur appuie sur Back hors onboarding, ContentGlowz doit d'abord respecter la pile de navigation interne réellement disponible. Si l'écran courant a été ouvert par un `push` depuis un écran parent, Back revient au parent. Si l'utilisateur est sur une route racine du shell, ou si la navigation précédente a été remplacée volontairement par `go`, Back affiche la confirmation de fermeture. Si une sheet, un dialogue ou un sous-flow modal est ouvert, Back ferme ce niveau transitoire avant de quitter l'app. L'edge case facile à rater est de confondre historique de tabs et historique d'actions: changer de tab via la navigation principale ne doit pas nécessairement créer une pile infinie de retours, mais ouvrir une action/detail depuis une tab doit pouvoir revenir à son écran source.

## Success Behavior

- Depuis une route racine du shell (`/feed`, `/calendar`, `/settings`, etc.), Back affiche `Close ContentGlowz?` / `Fermer ContentGlowz ?` au lieu de fermer directement.
- Depuis une route ouverte par action interne (`/editor/:id`, `/personas/:id`, `/settings/integrations`, `/angles`, `/ritual`, etc.), Back revient à l'écran source quand un parent existe dans la pile.
- Depuis une navigation principale par bottom nav ou side rail, les changements de tab restent des remplacements de destination (`go`) et ne créent pas d'historique artificiel de tab à tab, sauf décision contraire explicite dans une spec future.
- Les dialogs, sheets et sous-flows modaux se ferment avant toute confirmation de sortie.
- Le comportement onboarding existant reste inchangé: page 2 -> page 1, puis confirmation de fermeture.

## Error Behavior

- Si aucune route précédente n'existe ou si l'état de navigation est ambigu, l'app doit afficher la confirmation de fermeture plutôt que fermer silencieusement.
- Si une route protégée est inaccessible après un retour, les guards existants redirigent vers `/entry` sans boucle.
- Si un écran contient des données non sauvegardées, cette spec ne crée pas un workflow de sauvegarde; le comportement doit être explicitement conservateur et ne pas supprimer l'état sans confirmation déjà existante.
- Le correctif ne doit pas affaiblir les guards auth, demo, degraded mode ou les redirections de `resolveAppRedirect`.

## Problem

Après validation de `BUG-2026-05-05-002`, l'utilisateur a observé que le bouton Android Back hors onboarding propose parfois directement de sortir de l'app alors qu'une action précédente semble exister. Cela peut rendre l'exploration Android frustrante et donner l'impression que l'app perd l'historique de navigation.

## Solution

Définir puis implémenter une règle claire pour le shell Flutter: Back remonte les routes empilées par `push`; Back sur une route racine du shell affiche la confirmation de fermeture; la navigation principale par tabs/rail reste une navigation de remplacement. Ajouter des tests qui simulent les chemins représentatifs plutôt qu'un comportement global non maîtrisé.

## Scope In

- Audit des routes `GoRoute`, `ShellRoute`, `context.push()` et `context.go()` dans `app/lib`.
- Correction du comportement Back dans `AppShell` si le `PopScope` intercepte trop tôt les routes empilées.
- Tests Flutter pour au moins:
  - route racine shell -> confirmation de sortie;
  - route action/detail poussée depuis une route shell -> retour au parent;
  - onboarding Back inchangé.
- Documentation courte dans changelog ou note app si le comportement Back Android est documenté ailleurs.

## Scope Out

- Undo/redo métier des actions utilisateur.
- Historique complet de tabs ou retour tab-par-tab si la navigation principale utilise `go`.
- Sauvegarde automatique, brouillons, ou confirmation de perte de données non sauvegardées.
- Refonte de GoRouter, auth guards, deep links, URL strategy web, ou architecture globale de navigation.
- Correction des flows hosted auth/OAuth ou preview Vercel.

## Constraints

- Préserver les corrections déjà fermées:
  - `BUG-2026-05-05-001`: safe-area onboarding Android.
  - `BUG-2026-05-05-002`: Back dans onboarding.
- Ne pas remplacer aveuglément tous les `context.go()` par `context.push()`.
- Préserver `context.go()` pour les destinations de navigation principale afin d'éviter une pile de tabs imprévisible.
- Ne pas introduire de dépendance Flutter/GoRouter nouvelle sans justification.
- Respecter `app/CLAUDE.md`: sur ARM64 Linux, pas de build Android release local; validation locale limitée à `flutter analyze`, `flutter test`, et éventuellement build web.

## Dependencies

- Stack: Flutter, Riverpod, GoRouter, `PopScope`, `ShellRoute`, Android system Back.
- Project development mode: `app` est `hybrid`; ce chantier est local Android/UI et ne nécessite pas de preview Vercel pour la validation initiale.
- Fresh external docs: `fresh-docs not needed` pour cette spec light, car le comportement cible est défini par le contrat produit et les patterns locaux existants. Si l'implémentation dépend d'un détail GoRouter/Flutter non évident, l'agent d'exécution doit consulter la documentation officielle actuelle avant de patcher.

## Invariants

- Les routes protégées restent protégées par `resolveAppRedirect`.
- Les routes racine du shell continuent à afficher une confirmation avant fermeture.
- L'onboarding conserve son propre comportement de page interne.
- Les modals/dialogs/sheets gardent la priorité Back native attendue.
- Aucun changement de navigation ne doit exposer des écrans non autorisés ou contourner l'état demo/signed-out.

## Links & Consequences

- `AppShell._wrapWithExitConfirmation` est probablement le point central à inspecter: il utilise `ModalRoute.of(context)?.isFirst` puis `confirmAndExitApp`.
- `router.dart` sépare les routes shell (`NoTransitionPage`) des routes hors shell (`MaterialPage`), ce qui influence la pile réelle.
- Les écrans `settings`, `angles`, `personas`, `feed`, `capture`, `projects` utilisent déjà un mélange de `context.push()` et `context.go()`.
- Une correction trop large peut casser les tests de resume/no-jump ou créer un historique de tabs non souhaité.
- Une correction trop faible laissera la sortie prématurée sur Android.

## Documentation Coherence

- Mettre à jour `app/CHANGELOG.md` si présent ou le journal de livraison utilisé par le projet si le comportement Back est user-visible.
- Ne pas modifier les docs marketing/site: le changement est un détail d'expérience mobile app.
- Si une aide utilisateur décrit la navigation Android, l'aligner sur la règle finale.

## Edge Cases

- Back depuis `/settings/integrations` ouvert depuis Settings doit revenir à Settings si la pile existe.
- Back depuis `/personas/new` ouvert depuis Personas doit revenir à Personas si la pile existe.
- Back depuis `/editor/:id/video` doit revenir à l'éditeur ou au parent selon la pile réelle, sans perdre le contenu.
- Back depuis une tab racine après navigation principale doit demander confirmation, pas remonter arbitrairement toutes les tabs visitées.
- Back pendant degraded mode ne doit pas casser les écrans limités.
- Back après un redirect auth ne doit pas provoquer de boucle `/entry` <-> route protégée.

## Implementation Tasks

- [ ] Tâche 1 : Cartographier les routes root, action/detail et modales
  - Fichier : `app/lib/router.dart`, `app/lib/presentation/screens/app_shell.dart`
  - Action : Classer les routes racine shell, les routes poussées hors shell, et les actions qui utilisent `context.push()` ou `context.go()`.
  - User story link : identifie où Back doit revenir en arrière et où il doit proposer la sortie.
  - Depends on : none.
  - Validate with : notes de classification dans le rapport `/sf-start`.
  - Notes : Ne pas modifier le code dans cette tâche si la classification révèle une ambiguïté produit.

- [ ] Tâche 2 : Corriger l'interception Back du shell si elle masque une pile existante
  - Fichier : `app/lib/presentation/screens/app_shell.dart`
  - Action : Ajuster `_wrapWithExitConfirmation` pour laisser la navigation dépiler quand un parent réel existe, et n'appeler `confirmAndExitApp` que sur une destination racine sans retour interne.
  - User story link : empêche la proposition de sortie prématurée hors onboarding.
  - Depends on : Tâche 1.
  - Validate with : tests Flutter ajoutés en Tâche 3.
  - Notes : Préserver la confirmation de sortie sur les routes root du shell.

- [ ] Tâche 3 : Ajouter des tests de navigation Android Back hors onboarding
  - Fichier : `app/test/navigation/android_back_history_test.dart` ou fichier de test voisin existant.
  - Action : Couvrir route root -> confirmation, route poussée -> retour parent, et non-régression onboarding.
  - User story link : prouve que Back remonte l'historique réel avant de proposer la sortie.
  - Depends on : Tâche 2.
  - Validate with : `flox activate -- flutter test test/navigation/android_back_history_test.dart test/presentation/screens/onboarding/onboarding_back_test.dart`.
  - Notes : Utiliser des routes/widgets minimaux si le routeur complet rend les fixtures trop lourdes.

- [ ] Tâche 4 : Vérifier cohérence globale app
  - Fichier : `app/lib/router.dart`, tests navigation existants.
  - Action : Relancer les tests de navigation existants et analyser les regressions potentielles.
  - User story link : garantit que le fix ne casse pas auth redirects, resume/no-jump ou onboarding.
  - Depends on : Tâche 3.
  - Validate with : `flox activate -- flutter test test/navigation/resume_no_jump_test.dart test/presentation/screens/onboarding/onboarding_back_test.dart` et `flox activate -- flutter analyze`.
  - Notes : Ne pas lancer de build Android release local sur ARM64.

## Acceptance Criteria

- [ ] CA 1 : Given l'utilisateur est sur une route racine du shell, when il appuie sur Back, then ContentGlowz affiche la confirmation de fermeture.
- [ ] CA 2 : Given l'utilisateur a ouvert une route action/detail avec `push`, when il appuie sur Back, then ContentGlowz revient à l'écran parent au lieu de proposer la sortie.
- [ ] CA 3 : Given l'utilisateur navigue entre tabs principales, when il appuie sur Back sur une tab racine, then l'app ne reconstruit pas un historique artificiel de tabs sauf si une route a été poussée.
- [ ] CA 4 : Given l'utilisateur est dans le wizard onboarding, when il appuie sur Back à partir de la page 2, then le comportement existant page 2 -> page 1 -> confirmation reste inchangé.
- [ ] CA 5 : Given une route protégée devient inaccessible après Back, when le guard s'applique, then la redirection reste stable et sans boucle.
- [ ] CA 6 : Given les tests ciblés passent, when `/sf-verify` relit cette spec, then le changement peut être considéré vérifié localement sans preview Vercel.

## Test Strategy

- Tests widget/navigation avec `handlePopRoute()` pour simuler Android Back.
- Tests de non-régression onboarding existants.
- Tests de redirection existants (`resume_no_jump_test.dart`) pour éviter les boucles ou jumps.
- `flutter analyze` pour la cohérence Dart/Flutter.
- Manual QA Android après implémentation:
  - Back depuis route root -> confirmation.
  - Back depuis action/detail -> retour parent.
  - Back depuis onboarding -> comportement déjà validé.

## Risks

- P2 : Une correction trop agressive peut créer un historique de tabs frustrant ou infini.
- P2 : Une correction trop faible peut laisser la sortie prématurée sur routes action/detail.
- P2 : Les tests minimalistes peuvent ne pas reproduire la pile réelle GoRouter si le routeur complet n'est pas utilisé.
- P3 : Des écrans avec données non sauvegardées peuvent nécessiter une spec dédiée de confirmation de perte de changements.

## Execution Notes

- Lire d'abord `app/lib/router.dart`, `app/lib/presentation/screens/app_shell.dart`, `app/lib/presentation/screens/onboarding/onboarding_screen.dart`, `app/lib/presentation/widgets/app_exit_confirmation.dart`, `app/test/navigation/resume_no_jump_test.dart`, et `app/test/presentation/screens/onboarding/onboarding_back_test.dart`.
- Commencer par classer les navigations `push` vs `go`.
- Ne pas modifier `resolveAppRedirect` sauf preuve que le bug vient d'un guard.
- Fresh external docs: `fresh-docs not needed` tant que l'implémentation s'appuie sur les patterns locaux. Si un détail de `PopScope` ou GoRouter devient bloquant, consulter les docs officielles avant de patcher.
- Validation mode: local Flutter + manual Android retest; pas de build release Android local sur ARM64.

## Open Questions

None. La décision produit retenue pour cette spec light est: Back remonte les routes réellement poussées; Back sur une route racine du shell demande confirmation; la navigation principale par tabs ne crée pas d'historique artificiel.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-16 14:15:47 UTC | sf-spec | GPT-5 Codex | Création de la spec light pour clarifier le comportement Android Back hors onboarding après la fermeture des bugs Android onboarding. | draft | `/sf-ready Android back history outside onboarding` |
| 2026-05-17 10:49:32 UTC | sf-ready | GPT-5 Codex | Vérification de la spec Android back history outside onboarding (alignment user story/contrat/tests/sécurité/contrats de trace). | ready | `/sf-start Android back history outside onboarding` |
| 2026-05-17 13:39:05 UTC | sf-start | GPT-5 Codex | Implémentation du back shell Android: confirmation de sortie seulement sans historique `canPop`, plus tests navigation ciblés et non-régression onboarding. | implemented | `/sf-verify Android back history outside onboarding` |
| 2026-05-17 13:40:14 UTC | sf-verify | GPT-5 Codex | Vérification locale du fix Android Back: revue du diff ciblé, tests navigation/onboarding, tests resume/no-jump et analyse Flutter. | partial | `/sf-test Android back history outside onboarding on Android device` |

## Current Chantier Flow

- sf-spec: draft
- sf-ready: ready
- sf-start: implemented
- sf-verify: partial
- sf-end: not launched
- sf-ship: not launched

Prochaine commande recommandée : `/sf-test Android back history outside onboarding on Android device`.
