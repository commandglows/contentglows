---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-04-25"
updated: "2026-04-27"
status: ready
source_skill: sf-docs
scope: feature
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
user_story: "En tant qu'utilisateur ContentGlowz, je veux une architecture cible unique Flutter -> FastAPI avec auth Clerk pour retrouver mon compte et mes donnees sans fragmentation de runtime."
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs audit shipglows_data/workflow/specs/app/architecture-cible-fastapi-clerk-flutter.md"
---
# Spec: Architecture cible propre — Astro + Flutter + FastAPI + Clerk

Date: 2026-03-23

## Titre

Sortie complete de Next.js runtime au profit d'une architecture produit propre:
- `Astro` pour le site marketing statique
- `Flutter` pour l'application
- `FastAPI` pour le backend unique
- `Clerk` pour l'auth unique
- base existante conservee comme source de verite

## Probleme

L'application historique JavaScript porte encore:
- l'auth via Clerk;
- plusieurs APIs utilisateur;
- une partie de la couche donnees necessaire pour retrouver un compte existant.

La nouvelle Flutter app, elle:
- n'a pas de vraie auth;
- s'appuie encore sur des booleens locaux;
- ne peut pas retrouver de maniere fiable un compte existant ni ses donnees.

Si on garde cet etat, on fragmente le produit:
- identite d'un cote;
- donnees d'un autre;
- logique metier du pipeline ailleurs.

## Solution

Conserver `Clerk` et la base existante, mais faire de `FastAPI` le backend runtime unique.

Le schema cible est:
- `Astro` ne sert que le marketing;
- `Flutter` appelle uniquement `FastAPI`;
- `FastAPI` valide les tokens Clerk, derive le `user_id`, lit/ecrit la base, expose tous les endpoints applicatifs;
- `Next.js` sort du runtime une fois la parite atteinte.

## Scope In

- Auth Clerk cote Flutter et cote FastAPI
- Bootstrap session/workspace dans Flutter
- Reexposition FastAPI des domaines `me`, `projects`, `settings`, `creator profile`, `personas`, `content`
- Controle d'ownership coherent
- Retrait de la logique locale d'auth/onboarding comme source de verite
- Plan de sortie de Next.js runtime

## Scope Out

- Refonte marketing Astro
- Billing
- Auth multi-provider alternative a Clerk
- Migration de toutes les routes secondaires de l'ancien dashboard en une seule passe
- Suppression immediate du code Next.js avant parite fonctionnelle

## Decision d'architecture

### Cible finale

- `Astro`
  - landing
  - pricing
  - docs marketing
  - liens vers l'app

- `Flutter`
  - UI produit
  - navigation
  - cache local
  - appels authentifies vers FastAPI

- `FastAPI`
  - validation Clerk
  - endpoints metier
  - acces DB
  - content engine
  - scheduling
  - publishing

- `Clerk`
  - login/signup/session
  - source d'identite unique

- `DB existante`
  - source de verite unique des donnees utilisateur

### Regles structurantes

- Ne jamais recreer une auth locale parallele.
- Ne jamais remplacer le `userId Clerk` par un nouvel identifiant applicatif.
- Ne jamais decider l'onboarding depuis `SharedPreferences`.
- Ne jamais faire de Flutter -> Next.js une dependance produit finale.
- Toute donnee utilisateur doit etre lue/ecrite via `FastAPI` dans l'etat cible.

## Constat actuel

### Auth

- L'ancienne app Next.js protege globalement les routes via Clerk middleware.
- Les handlers utilisent `auth()` et scoppent la plupart des requetes par `userId`.
- Le `userId Clerk` est deja la vraie identite produit.

Fichiers de reference:
- `/home/claude/contentglowz/chatbot/middleware.ts`
- `/home/claude/contentglowz/chatbot/app/api/projects/route.ts`
- `/home/claude/contentglowz/chatbot/app/api/settings/route.ts`
- `/home/claude/contentglowz/chatbot/app/api/psychology/route.ts`
- `/home/claude/contentglowz/chatbot/app/api/psychology/personas/route.ts`
- `/home/claude/contentglowz/chatbot/lib/db/schema.ts`
- `/home/claude/contentglowz/chatbot/lib/db/queries.ts`

### Flutter

- Il n'y a pas encore de vraie auth.
- L'etat connecte/deconnecte repose sur `SharedPreferences`.
- Le routeur n'est pas pilote par une session reelle.
- L'onboarding est stocke localement au lieu d'etre derive du backend.

Fichiers de reference:
- `/home/claude/contentglowz-app/lib/main.dart`
- `/home/claude/contentglowz-app/lib/router.dart`
- `/home/claude/contentglowz-app/lib/data/services/api_service.dart`
- `/home/claude/contentglowz-app/lib/providers/providers.dart`
- `/home/claude/contentglowz-app/lib/presentation/screens/entry/entry_screen.dart`
- `/home/claude/contentglowz-app/lib/presentation/screens/onboarding/onboarding_screen.dart`

### Donnees a recuperer pour retrouver un compte existant

Priorite 0:
- `Project`
- `UserSettings`
- `CreatorProfile`
- `CustomerPersona`
- `ContentRecord`

Priorite 1:
- `ContentAngle`
- `ContentSource`
- `NarrativeChapter`
- `CreatorEntry`
- `NarrativeUpdate`

Priorite 2:
- `ActivityLog`
- `ScheduleJob`
- `NewsletterGenerator`

Donnees a ne jamais exposer brut au client:
- `UserSettings.apiKeys`
- `GmailToken`

### Point critique de securite

La couche `content` est moins propre que `projects/settings/personas`:
- `ContentRecord` n'a pas de `userId` direct dans le schema actuel;
- certaines routes/queries n'imposent pas assez l'ownership.

Decision:
- dans la migration FastAPI, toute lecture/ecriture `content` doit etre protegee par ownership;
- ownership recommande: `projectId -> Project.userId`;
- si cela s'avere trop fragile, ajouter `userId` a `ContentRecord` dans une vague 2 de durcissement schema.

## Architecture cible detaillee

### 1. Auth Flutter -> Clerk -> FastAPI

Flux:
1. Flutter ouvre l'UI Clerk.
2. Clerk renvoie une session valide.
3. Flutter recupere un JWT/session token Clerk.
4. Flutter envoie `Authorization: Bearer <token>` a FastAPI.
5. FastAPI valide le token via les `JWKS` Clerk.
6. FastAPI extrait `sub`.
7. `sub` devient le `user_id` applicatif.
8. Toute route metier derive ses droits et ses donnees depuis ce `user_id`.

### 2. Bootstrap applicatif

Apres login, Flutter ne doit pas aller directement au feed.

Flutter doit:
1. restaurer la session Clerk;
2. appeler `GET /api/me`;
3. appeler un endpoint bootstrap ou un petit ensemble d'endpoints;
4. decider entre:
   - `signed_out`
   - `signed_in_without_workspace`
   - `signed_in_with_workspace`

Decision de navigation:
- pas connecte -> `AuthScreen`
- connecte + bootstrap loading -> `LaunchScreen`
- connecte + aucun workspace -> `OnboardingScreen`
- connecte + workspace existe -> `Feed`

### 3. FastAPI comme backend unique

FastAPI devient l'unique facade backend pour Flutter.

Domaines minimaux a exposer:
- `me`
- `projects`
- `settings`
- `creator profile`
- `personas`
- `content`

Domaines ensuite:
- `content angles`
- `content sources`
- `narrative history`
- `schedule jobs`

### 4. Astro hors runtime applicatif

Astro ne porte:
- ni auth applicative;
- ni API metier;
- ni logique de session produit.

Astro peut contenir:
- CTA vers login/app;
- pages publiques;
- contenu marketing.

## Contrat API cible

### Compte / bootstrap

- `GET /api/me`
  - retourne:
    - `user_id`
    - `email`
    - `display_name` si disponible
    - `workspace_exists`
    - `default_project_id`

- `GET /api/bootstrap`
  - retourne:
    - `user`
    - `projects_count`
    - `default_project_id`
    - `has_creator_profile`
    - `personas_count`
    - `workspace_status: empty | ready`

### Projects

- `GET /api/projects`
- `POST /api/projects`
- `GET /api/projects/{id}`
- `PATCH /api/projects/{id}`
- `DELETE /api/projects/{id}`

### Settings

- `GET /api/settings`
- `PATCH /api/settings`

Regle:
- ne jamais renvoyer de secrets bruts;
- renvoyer uniquement des indicateurs safe si necessaire.

### Creator profile

- `GET /api/creator-profile?projectId=...`
- `PUT /api/creator-profile`

### Personas

- `GET /api/personas?projectId=...`
- `POST /api/personas`
- `PUT /api/personas/{id}`
- `DELETE /api/personas/{id}`

### Content

- `GET /api/content?projectId=...&status=...`
- `GET /api/content/{id}`
- `PATCH /api/content/{id}`
- `GET /api/content/{id}/history`

### Plus tard

- `GET /api/content-angles?projectId=...`
- `GET /api/content-sources?projectId=...`
- `GET /api/schedule-jobs?projectId=...`

## Structure FastAPI recommandee

### Fichiers a creer

- `/home/claude/contentglowz/api/auth/clerk.py`
  - validation JWT Clerk
  - chargement/caching JWKS
  - extraction `sub`

- `/home/claude/contentglowz/api/dependencies/auth.py`
  - dependency `get_current_user()`
  - dependency `require_current_user()`

- `/home/claude/contentglowz/api/models/me.py`
- `/home/claude/contentglowz/api/models/settings.py`
- `/home/claude/contentglowz/api/models/persona.py`
- `/home/claude/contentglowz/api/models/creator_profile.py`
- `/home/claude/contentglowz/api/models/bootstrap.py`

- `/home/claude/contentglowz/api/repositories/`
  - `projects_repository.py`
  - `settings_repository.py`
  - `creator_profile_repository.py`
  - `personas_repository.py`
  - `content_repository.py`

- `/home/claude/contentglowz/api/routers/me.py`
- `/home/claude/contentglowz/api/routers/settings.py`
- `/home/claude/contentglowz/api/routers/personas.py`
- `/home/claude/contentglowz/api/routers/creator_profile.py`
- `/home/claude/contentglowz/api/routers/bootstrap.py`

### Fichiers a modifier

- `/home/claude/contentglowz/api/main.py`
  - ajouter la nouvelle auth dependency/middleware
  - inclure les nouveaux routers
  - mettre a jour la doc/CORS si necessaire

- `/home/claude/contentglowz/api/routers/projects.py`
  - remplacer `default-user` par le vrai user Clerk

- `/home/claude/contentglowz/api/routers/content.py`
- `/home/claude/contentglowz/api/routers/status.py`
- `/home/claude/contentglowz/api/routers/publish.py`
  - imposer ownership et user context la ou pertinent

## Structure Flutter recommandee

### Fichiers a creer

- `lib/auth/auth_state.dart`
- `lib/auth/auth_controller.dart`
- `lib/data/models/auth_user.dart`
- `lib/data/models/bootstrap_state.dart`
- `lib/presentation/screens/auth/auth_screen.dart`
- `lib/presentation/screens/launch/launch_screen.dart`

### Fichiers a modifier

- `pubspec.yaml`
  - ajouter la dependance Clerk Flutter/web et le stockage securise si necessaire

- `lib/main.dart`
  - retirer `isLoggedInProvider` comme source de verite
  - conserver `SharedPreferences` seulement pour le cache/prefs non critiques
  - ajouter:
    - `authSessionProvider`
    - `authTokenProvider`
    - `appBootstrapProvider`

- `lib/router.dart`
  - remplacer la garde locale par une machine d'etat:
    - `signedOut`
    - `signedInLoading`
    - `signedInNoWorkspace`
    - `signedInReady`

- `lib/data/services/api_service.dart`
  - injecter le bearer token Clerk
  - gerer les 401
  - separer clairement appels publics et authentifies

- `lib/providers/providers.dart`
  - bloquer les providers metier tant que session/bootstrap ne sont pas prets
  - ajouter:
    - `workspaceBootstrapProvider`
    - `currentProjectProvider`
    - `sessionReadyProvider`
    - `workspaceReadyProvider`

- `lib/presentation/screens/entry/entry_screen.dart`
  - supprimer la logique provisoire
  - remplacer par `AuthScreen` ou `LaunchScreen`

- `lib/presentation/screens/onboarding/onboarding_screen.dart`
  - retirer `prefs.setBool('onboarding_complete', true)` comme source de verite
  - faire de l'onboarding une creation/configuration de workspace backend

- `lib/presentation/screens/settings/settings_screen.dart`
  - afficher le compte reeel:
    - email / user
    - sign out
    - workspace courant

## Taches d'implementation

- [ ] Tache 1: Ajouter l'auth Clerk cote FastAPI
  - Fichier: `/home/claude/contentglowz/api/auth/clerk.py`
  - Action: Implementer validation JWT via JWKS Clerk, extraction `sub`, cache JWKS.

- [ ] Tache 2: Creer la dependency user courante
  - Fichier: `/home/claude/contentglowz/api/dependencies/auth.py`
  - Action: Exposer `get_current_user()` pour toutes les routes protegees.

- [ ] Tache 3: Corriger la route projects FastAPI
  - Fichier: `/home/claude/contentglowz/api/routers/projects.py`
  - Action: Supprimer `default-user`, utiliser le user Clerk reel.

- [ ] Tache 4: Ajouter les routes `me` et `bootstrap`
  - Fichier: `/home/claude/contentglowz/api/routers/me.py`
  - Fichier: `/home/claude/contentglowz/api/routers/bootstrap.py`
  - Action: Exposer les informations minimales pour la decision Flutter login/onboarding/dashboard.

- [ ] Tache 5: Reexposer `settings` via FastAPI
  - Fichier: `/home/claude/contentglowz/api/routers/settings.py`
  - Action: Lire/ecrire les settings utilisateur sans jamais renvoyer les secrets.

- [ ] Tache 6: Reexposer `creator profile`
  - Fichier: `/home/claude/contentglowz/api/routers/creator_profile.py`
  - Action: Reprendre le contrat utile a Flutter autour de la psychologie.

- [ ] Tache 7: Reexposer `personas`
  - Fichier: `/home/claude/contentglowz/api/routers/personas.py`
  - Action: CRUD complet scoppé par `user_id` et `project_id`.

- [ ] Tache 8: Durcir et reexposer `content`
  - Fichier: `/home/claude/contentglowz/api/repositories/content_repository.py`
  - Fichier: `/home/claude/contentglowz/api/routers/content.py`
  - Action: Imposer un vrai controle d'ownership et exposer liste/detail/update/history.

- [ ] Tache 9: Integrer Clerk dans Flutter
  - Fichier: `pubspec.yaml`
  - Fichier: `lib/auth/auth_controller.dart`
  - Action: Brancher session Clerk reelle et exposition de l'etat auth.

- [ ] Tache 10: Remplacer le gate local Flutter
  - Fichier: `lib/router.dart`
  - Fichier: `lib/presentation/screens/auth/auth_screen.dart`
  - Fichier: `lib/presentation/screens/launch/launch_screen.dart`
  - Action: Piloter le routage via session + bootstrap backend.

- [ ] Tache 11: Rendre l'onboarding backend-driven
  - Fichier: `lib/presentation/screens/onboarding/onboarding_screen.dart`
  - Action: Deriver la completion depuis les projets/settings backend plutot que `SharedPreferences`.

- [ ] Tache 12: Authentifier tous les appels Flutter
  - Fichier: `lib/data/services/api_service.dart`
  - Action: Injecter le token Clerk, gerer `401`, distinguer appels publics et prives.

- [ ] Tache 13: Geler les providers metier tant que le bootstrap n'est pas pret
  - Fichier: `lib/providers/providers.dart`
  - Action: Eviter les chargements anonymes et les etats incoherents au demarrage.

- [ ] Tache 14: Nettoyer l'UX session/settings
  - Fichier: `lib/presentation/screens/settings/settings_screen.dart`
  - Action: Afficher utilisateur reel, workspace, sign out.

- [ ] Tache 15: Retirer Next.js du runtime une fois la parite atteinte
  - Fichier: docs d'exploitation / infra
  - Action: Basculer Flutter exclusivement sur FastAPI, puis decommission Next.js app runtime.

## Criteres d'acceptation

- [ ] CA1: Given un utilisateur existant avec un compte Clerk, when il se connecte dans Flutter, then l'app retrouve le meme `userId` et charge ses projets existants.
- [ ] CA2: Given un utilisateur connecte avec au moins un projet existant, when l'app demarre, then il arrive au dashboard sans repasser par l'onboarding.
- [ ] CA3: Given un utilisateur connecte sans workspace, when l'app demarre, then il est redirige vers l'onboarding.
- [ ] CA4: Given un token Clerk invalide ou expire, when Flutter appelle FastAPI, then FastAPI repond `401` et Flutter revient a l'etat auth.
- [ ] CA5: Given un utilisateur A, when il tente d'acceder a un content record de l'utilisateur B, then FastAPI refuse l'acces.
- [ ] CA6: Given `UserSettings` contient des secrets, when Flutter appelle `/api/settings`, then aucune cle sensible n'est retournee en clair.
- [ ] CA7: Given la Flutter app est installee sur un deuxieme device, when le meme compte se reconnecte, then l'etat onboarding/workspace est coherent sans dependre d'un flag local.
- [ ] CA8: Given la migration est terminee, when Flutter fonctionne en production, then aucune route Next.js n'est necessaire au runtime pour l'app produit.

## Strategie de migration

### Phase 1 — Foundations

- auth Clerk cote FastAPI
- `GET /api/me`
- `GET /api/bootstrap`
- correction `projects.py`

### Phase 2 — Workspace restore

- `projects`
- `settings`
- `creator profile`
- `personas`

Objectif:
- retrouver un compte existant;
- sortir de l'onboarding correctement.

### Phase 3 — Flutter auth cutover

- Clerk dans Flutter
- nouveau routeur auth/bootstrap
- suppression du faux etat local

### Phase 4 — Content parity

- `content` liste/detail/update/history
- durcissement ownership

### Phase 5 — Decommission Next.js runtime

- Flutter n'appelle plus que FastAPI
- Astro sert uniquement le marketing
- Next.js peut etre retire ou archive

## Risques

- Validation JWT Clerk cote Python mal configuree
- Contrats DB encore couples aux queries Drizzle TypeScript
- Ownership insuffisant sur `content`
- Differences de shape entre les reponses Next.js et les modeles Flutter actuels
- Dependances GitHub/oauth annexes qui devront etre reexposees plus tard

## Questions tranchees

- Faut-il garder Next.js en runtime ? Non.
- Faut-il garder Clerk ? Oui.
- Faut-il garder la DB existante ? Oui.
- Faut-il migrer progressivement ? Oui, mais vers FastAPI uniquement.
- Faut-il encore decider l'onboarding localement ? Non.

## Prochaine etape recommandee

Commencer par le backend:
1. auth Clerk dans FastAPI;
2. `GET /api/me`;
3. `GET /api/bootstrap`;
4. migration `projects/settings/creator-profile/personas`.

Sans cette base, toute integration Flutter restera du faux wiring.
