---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "contentglows"
created: "2026-08-05"
created_at: "2026-08-05 17:34:00 UTC"
updated: "2026-08-05"
updated_at: "2026-08-05 18:18:00 UTC"
status: implemented
source_skill: "100-sg-spec"
source_model: "GPT-5 Codex"
scope: "brand-studio-persona-content-context"
owner: "Diane"
user_story: "En tant que créatrice, je veux choisir une persona pour chaque contenu et configurer une marque guidée afin que mes contenus et aperçus vidéo restent cohérents sans dupliquer mes audiences."
risk_level: medium
security_impact: none
docs_impact: yes
linked_systems:
  - "app Flutter"
  - "lab FastAPI brand profile and psychology APIs"
  - "branded video generation"
depends_on:
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.3.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/design-system-authority.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Brand profiles currently expose raw asset IDs and JSON defaults in the Flutter dialog."
  - "The branded-video API requires a profile and a blueprint, while the app exposes only profile settings."
  - "Personas already exist and guide angle generation, but their identity is not persisted on content created from an angle."
next_step: "verification"
---

# Title

Studio de marque et contexte persona par contenu

## Status

Ready — user selected the per-content persona model on 2026-08-05.

## User Story

En tant que créatrice, je veux choisir une persona pour chaque contenu et configurer une marque guidée afin que mes contenus et aperçus vidéo restent cohérents sans dupliquer mes audiences.

## Minimal Behavior Contract

Le flux de création depuis les angles conserve l'identifiant de la persona choisie sur le contenu créé. Le Studio de marque permet de créer et modifier un profil avec des contrôles compréhensibles, montre si une génération vidéo peut réellement démarrer et, lors du choix d'un contenu à prévisualiser, expose la persona qui a guidé ce contenu. En cas de profil, blueprint, contenu ou persona indisponible, l'utilisateur voit le prérequis exact et aucune génération trompeusement présentée comme un simple aperçu n'est lancée.

## Success Behavior

- Un contenu créé depuis un angle contient `persona_id` dans ses métadonnées.
- Le Studio ne promet l'aperçu vidéo que lorsqu'un profil et un blueprint utilisable existent.
- Le choix du contenu pour l'aperçu affiche la persona liée lorsque celle-ci est connue.
- Les profils restent réutilisables entre plusieurs personas et les données Persona ne sont pas copiées dans BrandProfile.

## Error Behavior

- Une persona absente ou supprimée n'empêche pas de consulter un contenu existant; elle est affichée comme indisponible.
- L'absence de blueprint bloque l'action de génération avec une explication récupérable, sans appel de rendu.
- Les échecs réseau préservent les profils et affichent l'état exact via les mécanismes de diagnostic existants.

## Problem

Les règles de marque sont aujourd'hui une fiche de paramètres vidéo à champs techniques. Les personas existent, mais leur sélection ne suit pas le contenu créé depuis les angles. Le bouton d'impact de marque déclenche en réalité un rendu et peut échouer si un blueprint invisible dans l'interface manque.

## Solution

Faire du profil une expérience de Studio progressive, persister la référence persona sur les contenus nés d'un angle et la rendre visible dans le chemin de prévisualisation. Ne pas introduire une persona par défaut dans BrandProfile ni un portail client/DAM.

## Scope In

- Persistance de `persona_id` dans les métadonnées de contenu créé depuis Angles.
- Lecture de cette référence dans le Studio de marque.
- Édition guidée des valeurs déjà supportées par BrandProfile, sans JSON ni identifiant d'asset à saisir.
- Préflight clair des dépendances de génération vidéo.
- Tests ciblés des payloads et états principaux.

## Scope Out

- Nouvelle table Persona, liaison persona par défaut au BrandProfile, portail client, white-label, partage d'assets ou extension navigateur.
- Réécriture des autres créateurs de contenu qui ne partent pas des Angles.
- Changement du moteur IA de génération de texte ou du format de rendu.

## Constraints

- Une persona appartient au contenu, pas au profil de marque.
- Les identifiants utilisateur/projet existants restent les frontières d'autorisation.
- Les valeurs visuelles utilisent uniquement les tokens Flutter existants.
- Le système ne crée pas d'asset, persona ou blueprint implicite.

## Test Contract

Surface mixte Flutter/FastAPI. Preuve automatisée : tests Dart ciblés pour les payloads et tests Python de route/modèle lorsque le contrat API change. Preuve manuelle : le flux protégé de réglages doit être vérifié avec une session existante; pas de rendu réel requis. Exception-with-proof : un rendu worker n'est pas appelé pendant les tests de préflight.

## Dependencies

- `BrandProfile`, `CustomerPersona`, ContentRecord metadata et routes vidéo existantes.
- Fresh external docs: not needed; les changements utilisent uniquement les contrats locaux existants.

## Invariants

- Un BrandProfile reste project-scoped et n'embarque pas de données Persona.
- Un contenu d'un autre projet ou utilisateur n'est jamais utilisable dans une prévisualisation.
- Une action présentée comme génération prévisualisée reste explicitement libellée comme telle.
- Les données existantes sans `persona_id` demeurent compatibles.

## Links & Consequences

- Angles devient la première surface qui conserve le contexte de cible sur le contenu.
- La timeline continue à être assemblée depuis le contenu complet; la persona est un contexte traçable, pas une seconde source de script.
- Les futures entrées de contenu pourront adopter la même clé `persona_id` sans migration de profil.

## Documentation Coherence

Mettre à jour le contexte produit app et le changelog pour préciser que le profil de marque reste dédié à la vidéo et que le contexte persona est contenu-scoped.

## Edge Cases

- Contenu historique sans persona.
- Persona supprimée après création du contenu.
- Profil existant sans logo, couleurs ou blueprint.
- Projet actif changé pendant le chargement d'un profil ou de personas.

## Implementation Tasks

- [x] Tâche 1 : Conserver le contexte persona sur les contenus créés depuis Angles.
  - Fichier : `app/lib/data/services/api_service.dart`, `lab/api/routers/psychology.py`
  - Action : accepter l'identifiant persona optionnel et l'écrire dans la metadata de premier niveau du contenu créé depuis un angle.
  - Validate with : tests Dart et Python ciblés de payload.

- [x] Tâche 2 : Passer la persona sélectionnée à la création de contenu.
  - Fichier : `app/lib/presentation/screens/angles/angles_screen.dart`
  - Action : transmettre l'ID de la persona sélectionnée à l'appel existant, sans modifier la propriété du profil de marque.
  - Validate with : analyse Flutter ciblée.

- [x] Tâche 3 : Remplacer l'éditeur technique de BrandProfile par un Studio guidé.
  - Fichier : `app/lib/presentation/screens/branding/brand_profiles_screen.dart`
  - Action : remplacer les champs ID/JSON par un choix de logo depuis les assets du projet, des champs de texte simples, un choix de mouvement et un préflight explicite avant génération.
  - Validate with : test widget ciblé et analyse Flutter.

- [x] Tâche 4 : Exposer les prérequis de génération vidéo dans l'API app et la UI.
  - Fichier : `app/lib/data/services/api_service.dart`
  - Action : charger les blueprints existants du profil avant de déclencher le rendu et éviter l'appel lorsque le préflight local échoue.
  - Validate with : test de requête API et état UI.

- [x] Tâche 5 : Documenter et prouver.
  - Fichier : `shipglows_data/product/app/product.md`, `CHANGELOG.md`
  - Action : refléter le modèle persona-par-contenu et la limite vidéo du Studio.
  - Validate with : relecture ciblée et tests demandés ci-dessus.

## Acceptance Criteria

- [x] CA 1 : Given une persona sélectionnée dans Angles, when la créatrice crée un contenu, then la metadata du contenu contient son `persona_id`.
- [ ] CA 2 : Given un contenu issu d'une persona, when la créatrice le sélectionne pour une prévisualisation de marque, then l'interface identifie cette persona sans la recopier dans le profil.
- [ ] CA 3 : Given une persona supprimée ou un contenu historique, when le Studio ouvre le contenu, then le flux reste utilisable et affiche un état neutre.
- [ ] CA 4 : Given aucun blueprint actif, when la créatrice veut générer une prévisualisation, then l'interface explique le prérequis avant tout appel de rendu.
- [ ] CA 5 : Given un profil existant, when la créatrice l'édite, then les réglages de couleur, ton, CTA, légende et mouvement restent persistés sans champ JSON ni asset ID manuel.

## Test Strategy

- Dart : test de payload `createContentFromAngle`, analyse du fichier Branding et tests providers existants.
- Python : tests des routes BrandProfile/blueprint non-régressifs si les contrats changent.
- Manual : session authentifiée, création d'angle avec persona, contenu, ouverture du Studio, vérification du préflight sans lancer de rendu.

## Risks

- L'association à la persona ne doit pas être interprétée comme une validation ou une preuve que le contenu a été généré avec cette persona par les anciens flux.
- Un préflight local ne remplace pas la vérification serveur de propriété et de disponibilité.

## Execution Notes

Lire d'abord `angles_screen.dart`, `api_service.dart`, `brand_profiles_screen.dart`, `brand_profile.dart` et `video_timelines.py`. Modifier les payloads avant l'interface. Réutiliser les providers et tokens existants. Ne pas ajouter de dépendance ni de migration Turso. Valider avec des tests focalisés et le drift check avant de déclarer le changement prêt.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-08-05 17:34:00 | 100-sg-spec | GPT-5 Codex | Created the implementation contract from the confirmed product decision. | Ready. | Implement scoped UI and metadata wiring. |
| 2026-08-05 17:50:00 | 001-sg-build | GPT-5 Codex | Implemented persona metadata wiring, video-style preflight, guided brand settings, tests and docs. | Local checks passed. | Verify the connected UI. |
| 2026-08-05 17:54:00 | 001-sg-build | GPT-5 Codex | Checked both deployed app hosts in a browser without generating content. | `app.contentglows.com` is rejected by Clerk for an invalid origin; `app.contentglowz.com` reaches the signed-out entry screen, but no authenticated workspace is available. | Recheck Brand Studio and Angles with a real test session. |
| 2026-08-05 18:14:00 | 103-sg-verify excellence | GPT-5 Codex | Checked API payload/metadata contracts, focused Flutter and FastAPI tests, static analysis, diff integrity, and the fresh excellence pass. Repaired persona lookup recovery and replaced manual logo-ID entry with project-library selection. | Partial: 2 Flutter tests and 5 Python tests pass, analysis and diff integrity pass. Rendered authenticated proof remains unavailable; drift scan reports pre-existing candidates in touched legacy screens. | proof_type: auth/browser/manual QA; owner_skill: 109-sg-auth-debug then 108-sg-browser; scenario: select persona in Angles, create content, open Brand Studio, verify persona label, deleted-persona neutral state, logo selection, and blueprint preflight without rendering; target_or_environment: authenticated `app.contentglowz.com` test workspace. |
| 2026-08-05 18:18:00 | 004-sg-deploy prepare | GPT-5 Codex | Prepared the bounded release scope without staging, committing, pushing, or deploying. | Partial: local checks are green, but authenticated rendered proof is still required. The release manifest excludes the pre-existing untracked backlog and exploration files; the current development mode is unknown-vercel because `app/vercel.json` exists without a documented project mode. | Obtain authenticated test-workspace proof before authorizing a bounded commit/push/deploy. |

## Current Chantier Flow

- 100-sg-spec: ready
- 101-sg-ready: ready by direct evidence review
- 102-sg-start: implemented
- 103-sg-verify: partial — automated contract checks pass; authenticated rendered proof is required before verification can close (owner: 109-sg-auth-debug → 108-sg-browser; target: authenticated app.contentglowz.com test workspace)
- 004-sg-deploy: partial — release scope prepared, no commit/push/deploy authorized
- 104-sg-end: pending authenticated rendered proof
- 005-sg-ship: not authorized; exclude pre-existing `BACKLOG.md` and white-label exploration from this release
