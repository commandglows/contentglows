---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-06-12"
created_at: "2026-06-12 04:10:19 UTC"
updated: "2026-06-12"
updated_at: "2026-06-12 04:10:19 UTC"
status: "draft"
source_skill: 100-sf-spec
source_model: "GPT-5 Codex"
scope: "migration"
owner: "Diane"
confidence: "high"
user_story: "En tant que mainteneur ContentGlowz, je veux faire évoluer la dépendance audio `record` de l’application Flutter sans changer le comportement fonctionnel, afin de réduire le risque de sécurité, les écarts de compatibilité et les futures dépendances non maintenables."
risk_level: "medium"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app/lib/data/services/device_capture_service.dart"
  - "app/lib/data/services/feedback_service.dart"
  - "app/lib/presentation/screens/feedback/feedback_screen.dart"
  - "app/pubspec.yaml"
  - "app/pubspec.lock"
depends_on:
  - artifact: "app/AGENT.md"
    artifact_version: "unknown"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-migrate-flutter-core-majors.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Flutter project baseline dans /home/claude/contentglowz: Flutter 3.41.7, Dart 3.11.5."
  - "record actuellement en `^6.2.0` (`pubspec.yaml`) avec lockfile en `6.2.0` (`pubspec.lock`)."
  - "Les flux audio existants sont implémentés via `device_capture_service.dart`, `feedback_service.dart`, et exposés depuis `feedback_screen.dart`."
  - "No dedicated test file for feedback audio flow was identified in the current working tree."
next_step: "/101-sf-ready Migrate Flutter `record` package in contentglowz app"
---

# Migrate Flutter audio capture dependency (`record`) in `app`

## Status

- draft
- owner: maintainers ContentGlowz app
- target SDK context: Flutter `3.41.7`, Dart `3.11.5`

## User Story

En tant que mainteneur ContentGlowz, je veux passer la dépendance `record` vers une version maintenue et cohérente avec la version Flutter actuelle, afin de sécuriser les dépendances et de garantir que l’enregistrement audio continue de fonctionner dans l’écran de feedback.

## Minimal Behavior Contract

Le chantier consiste à mettre à jour `record` dans le projet Flutter sans changer la fonctionnalité visible: démarrer, arrêter, rejouer et envoyer un feedback audio doit rester identique visuellement, avec les mêmes règles d’erreur existantes (permission refusée, enregistrement interrompu, échec de soumission) et une gestion stricte des fichiers temporaires. En cas d’incompatibilité de version majeure avec Flutter/Dart actuel, la migration doit se limiter au meilleur niveau stable résolu pour cet environnement, avec une décision explicite consignée avant codage.

## Success Behavior

- Quand une session d’enregistrement est lancée côté feedback, elle démarre correctement sur les plateformes cibles Android/iOS Web supportées par le projet, elle enregistre un payload exploitable et le soumet au service feedback.
- Quand une mise à jour de version est appliquée, `flutter pub get`, `flutter analyze` et les tests ciblés passent sans régression dans les flux de feedback.
- Quand la dépendance est stabilisée, la spec d’entrée (version de package + version résolue) est documentée et aucune API comportementale externe non approuvée n’est introduite.

## Error Behavior

- Si `record` ne peut pas migrer en sécurité sur Flutter/Dart actuel, le run est stoppé avant les modifications applicatives, et une proposition de lot suivant (migration SDK/stack) est produite.
- Si une signature API change et fait échouer compile/behavior, la couche service doit adapter uniquement les points nécessaires pour conserver les mêmes règles métiers; sinon l’erreur est bloquante tant que le flux feedback n’est pas préservé.
- Si permission microphone/stockage est refusée, le flux affiche le même état dégradé qu’aujourd’hui: pas de crash, action utilisateur récupérable, et aucun fichier temp persistant non supprimé.

## Problem

`record` est actuellement en `6.2.0` avec un environnement Flutter/Dart récent. Plusieurs dépendances critiques montent ailleurs dans le projet; une stratégie de migration cohérente évite qu’un futur lot Flutter impose une migration forcée non maîtrisée du flux audio.

Le risque principal est une incompatibilité de constraints SDK (notamment entre majors de `record` et Flutter/Dart), qui pourrait provoquer une migration partielle ou un drift non voulu si elle n’est pas scellée en contrat.

## Solution

Appliquer une migration de dépendance audio pilotée par résolution réelle, avec rollback clair:

- Lot 0: prise d’empreinte baseline et vérification de compatibilité officielle.
- Lot 1: migration `record` vers version la plus récente résoluble sans force de source non stable et sans sortie du scope.
- Lot 2: adaptation minimale des imports et appels uniquement dans les services/fichiers feedback.
- Lot 3: validation comportementale ciblée et preuve d’absence de régression fonctionnelle.

## Scope In

- `app/pubspec.yaml`
- `app/pubspec.lock`
- `app/lib/data/services/device_capture_service.dart`
- `app/lib/data/services/feedback_service.dart`
- `app/lib/presentation/screens/feedback/feedback_screen.dart`
- `app/test` (ajout/modification de tests ciblés si existants ou nécessaires)
- Validation Flutter locale: analyze/test/possible build smoke

## Scope Out

- Backend FastAPI / worker / remotion stack
- Refonte UX du feedback (UI redesign)
- Changement de permissions générales du projet au-delà de l’enregistrement audio
- Migration Flutter majeure (SDK, tooling) et autres librairies non liées à `record` dans ce lot

## Constraints

- `record` doit rester une source stable `pub.dev` (pas de git/path dependency).
- Pas de mise à jour d’API non liée au lot si non forcée par compilation.
- Maintenir la compatibilité fonctionnelle du flux feedback dans les chemins offline/online déjà documentés.
- Ne pas modifier d’autres surfaces (backend/site/lab) tant que cette spec n’est pas passée.
- Si une version 7 est visée, elle doit être validée par compatibilité SDK/Dart réelle; sinon le plan bascule explicitement vers `6.x` la plus récente compatible.
- Conserver les règles de sécurité/privacité sur enregistrements temporaires et journaux de debug.

## Test Contract

1) Automatisé: `flutter pub get` passe sans override non stable ni source non-`pub.dev`.
2) Compile-time: `flutter analyze` sans nouvelles erreurs d’API.
3) Comportement: test ciblé du service de feedback si tests existent (ou ajout) + scénario manuel minimal sur enregistrement.
4) Cross-check de version: capturer la version effective de `record` et les éventuels transitive drifts.

## Dependencies

### Internal
- `app/AGENT.md`
- `shipglows_data/technical/app/architecture.md` (si disponible), `shipglows_data/business/*` uniquement pour contexte

### External (freshness)
- `pub.dev/package:record` changelog/compat notes
- Flutter/Dart compatibility docs (version cible)

Decision de fraîcheur: `fresh-docs needed` avant mise en oeuvre pour confirmer la faisabilité de `record 7.x` sur Flutter `3.41.7` + Dart `3.11.5`.

## Invariants

- Le feedback audio visible doit conserver: démarrage, arrêt, gestion d’erreur permission, et envoi/liaison des données au service actuel.
- Aucune donnée audio ne doit être uploadée/soumise sans passage par la logique métier feedback existante.
- Aucun changement d’API d’authentification, routing, offline queue, ou stockage durable n’est attendu dans ce lot.

## Links & Consequences

- Migration dépendante de la matrice Flutter/Dart du projet; un échec de résolution peut bloquer ce lot et déclencher un chantier de montée d’environnement.
- Risque de dérive de lockfile: si la migration de `record` force des majors transitive non souhaités, les changements doivent être explicitement listés et validés lot par lot.
- Toute incohérence dans la gestion locale de fichiers audio peut impacter privacy/cleanup et donc le prochain chantier de device capture.

## Documentation Coherence

- Mettre à jour `shipglows_data/workflow/specs/app/SPEC-migrate-flutter-core-majors.md` (ou issue liée) si la résolution `record` influence une feuille de route globale de migration.
- Ajouter/mettre à jour changelog applicatif si migration majeure retenue.
- Créer ou enrichir le test-checklist d’audio si la validation manuelle devient obligatoire.

## Edge Cases

- Permission microphone refusée après démarrage d’une tentative.
- Changement de plateforme (web/mobile) entre start et stop d’enregistrement.
- Interruption de permissions par changement de cycle de vie app.
- Conflit de version transitive sur `record_android`/`record_ios` ou package lié à l’audio path.

## Implementation Tasks

- [ ] Tâche 1: Capturer la baseline migration
  - Fichier : `app/pubspec.yaml`, `app/pubspec.lock`
  - Action : noter versions Flutter/Dart, versions `record` actuelle/résolue/latest, et états transitive.
  - User story link : Garantir une décision de migration fondée sur la compatibilité réelle.
  - Depends on : aucune
  - Validate with : `flutter --version`, `flutter pub outdated`, `git diff --stat`
  - Notes : vérifier l’état initial du dépôt (worktree dirty) sans rollback forcé.

- [ ] Tâche 2: Résoudre la cible `record` compatible
  - Fichier : `app/pubspec.yaml`
  - Action : poser la cible de version (idéalement dernier stable compatible; ou `6.x` résoluble si `7.x` invalide dans ce contexte), puis `flutter pub get`.
  - User story link : Stabiliser la dépendance sans casser le produit.
  - Depends on : Tâche 1
  - Validate with : `flutter pub get`
  - Notes : ne pas forcer des pré-releases, ni git/path deps.

- [ ] Tâche 3: Ajuster les usages applicatifs du flux audio
  - Fichier : `app/lib/data/services/device_capture_service.dart`
  - Fichier : `app/lib/data/services/feedback_service.dart`
  - Fichier : `app/lib/presentation/screens/feedback/feedback_screen.dart`
  - Action : corriger uniquement les appels d’API impactés par la migration, sans réécrire la UX feedback.
  - User story link : Préserver le comportement feedback après migration.
  - Depends on : Tâche 2
  - Validate with : `flutter analyze`
  - Notes : priorité aux changements minimum; conserver les messages d’erreur locaux.

- [ ] Tâche 4: Mettre en place les preuves de non-régression
  - Fichier : `app/test/data/services` ou fichier dédié feedback existant
  - Action : ajouter un test ciblé si absent, ou adapter les tests existants pour couvrir start/stop/upload erreur permission.
  - User story link : Prouver que le contrat utilisateur reste stable.
  - Depends on : Tâche 3
  - Validate with : `flutter test` (scope ciblé)
  - Notes : garder tests légers, pas de dépendances externes réelles.

- [ ] Tâche 5: Packager la décision de lot
  - Fichier : `shipglows_data/workflow/specs/app/SPEC-record-package-migration-flutter-3-41.md`
  - Action : consigner version finale choisie, choix de compatibilité, et tout drift lockfile.
  - User story link : Traçabilité d’exécution pour `sf-ready`.
  - Depends on : Tâche 4
  - Validate with : revue par lot avant `/101-sf-ready`
  - Notes : si `record` ne peut pas monter, consigner explicitement blocage et prochaine migration possible.

## Acceptance Criteria

- [ ] CA1: Given l’app lance l’écran feedback, when l’utilisateur enregistre et soumet un message vocal, then le comportement observable (soumission, confirmation/erreur, réessayage) reste cohérent avec l’état pré-migration.
- [ ] CA2: Given `flutter pub get` sur la branche de migration, when le lot est appliqué, then l’arbre des dépendances ne contient pas de pré-releases non justifiées et le package `record` est stable pub.dev.
- [ ] CA3: Given la migration résolue est appliquée, when `flutter analyze` and scoped tests passent, then aucun nouveau warning d’API lié à feedback/audio n’est présent.
- [ ] CA4: Given un environnement avec permission refusée, when l’utilisateur tente l’enregistrement, then l’erreur reste gérable sans crash, sans fichier temp orphelin.
- [ ] CA5: Given migration échouée vers `7.x`, when la résolution est incompatible, then la spec met à jour clairement la cible retenue (`6.x` compatible) et déclenche un lot séparé de montée d’environnement avant d’imposer 7.x.

## Test Strategy

- `flutter pub get` avant/après mutation.
- `flutter analyze`.
- `flutter test` ciblé pour feedback + services.
- Test manuel court (Android + iOS simulé si dispo): démarrage, autorisation refusée, arrêt prématuré.
- Validation de lockfile: comparer diff pré/post migration pour détecter drift inattendu.
- En cas de migration majeure vers 7.x, ajouter un mini test de régression audio si nécessaire.

## Risks

- Medium: migration de version majeure non résolue avec Flutter/Dart actuel.
- Medium: modifications transitive non-intentionnelles du lockfile.
- Medium: régression silencieuse du comportement permission/cleanup.
- Low: impact de build time si `build`/analyse ralentis par la résolution.

## Execution Notes

- 1) D’abord baseline (`flutter --version`, `flutter pub outdated`, `git diff --stat`) avant tout edit.
- 2) Geler la scope list et refuser toute refonte feedback UI.
- 3) Appliquer migration `record` en lot unique, puis ajuster appels.
- 4) Ne pas toucher backend, shell commands or navigation.
- 5) Ne pas marquer 2.x/3.x pour `record`; c’est un lot Flutter dépendance unique.

Stop conditions:
- Résolution de `record 7.x` impossible sans upgrade SDK/Dart explicite.
- Incompatibilité API non maîtrisée qui touche un autre module audio hors feedback.
- Changement de comportement utilisateur non documenté dans Success/Error contract.

## Open Questions

- La migration `record` doit-elle viser strictement `6.x` (compatibilité sûre actuelle) ou accepter un lot préparatoire `7.x` avec roadmap d’upgrade Flutter/Dart ?
- Les runbooks manuels de retest audio existent-ils déjà dans un test-checklist réutilisable, ou faut-il le créer maintenant ?

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-06-12 04:10:19 UTC | 100-sf-spec | GPT-5 Codex | Création du spec de migration `record` pour `app` après revue de la surface feedback/record et contraintes Flutter/Dart. | draft saved | `/101-sf-ready Migrate Flutter 'record' package in contentglowz app` |

## Current Chantier Flow

- sf-spec: done
- sf-ready: not launched
- sf-start: not launched
- sf-verify: not launched
- sf-end: not launched
- sf-ship: not launched
