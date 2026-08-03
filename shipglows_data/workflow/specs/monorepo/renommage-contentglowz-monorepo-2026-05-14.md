---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-14"
created_at: "2026-05-14 22:42:30 UTC"
updated: "2026-05-24"
updated_at: "2026-05-24 00:00:00 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "migration"
owner: "Diane"
confidence: "high"
user_story: "En tant que propriétaire du produit, je veux que tout le monorepo, les surfaces publiques, les environnements et les pipelines utilisent ContentGlowz/contentglowz au lieu de l'ancien nom, afin que la marque, le domaine et le dépôt GitHub soient cohérents avant les prochains déploiements."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "GitHub repository and Actions"
  - "Vercel site and app deployments"
  - "Flutter web and Android app metadata"
  - "FastAPI CORS, OpenAPI metadata, auth handoff, analytics"
  - "Remotion worker and render storage"
  - "Clerk, Sentry, Doppler, Turso, Bunny, GCS, Google OAuth/Search Console environment configuration"
  - "ShipGlowz governance docs and specs"
depends_on:
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/README.md"
    artifact_version: "unknown"
    required_status: "active"
supersedes: []
evidence:
  - "User request 2026-05-14: project must be contentglowz / ContentGlowz everywhere; domain contentglowz.com has been purchased; GitHub repo target is https://github.com/diane-defores/contentglowz (note: /actions is the GitHub UI page, not the git remote URL)."
  - "2026-05-15: local git remote reports https://github.com/diane-defores/contentglowz.git for fetch and push."
  - "2026-05-15: active monorepo folders exist as site, app, lab, worker, and tools/design-tokens/contentglowz_theme.json."
  - "2026-05-15: .github/workflows/android-apk.yml uses app and artifact contentglowz-android-apk."
  - "2026-05-15: app defaults use https://contentglowz.com, https://app.contentglowz.com, and https://api.contentglowz.com."
  - "2026-05-15: backend CORS/OpenAPI paths include contentglowz.com domains and GitHub contact URL."
  - "2026-05-15: worker package/composition contract is now contentglowz-remotion-worker and ContentGlowzTimelineVideo."
  - "2026-05-15: residual active old-name occurrences remain in app copy and lab agent docs; many governance/spec/research occurrences are historical or require classification."
next_step: "/sf-test --retest BUG-2026-05-10-001"
---

## Title

Renommage ContentGlowz monorepo

## Status

Ready 2026-05-15 après gate `sf-ready` sur la reprise post-exécution partielle.

Le chantier ne repart plus de zéro. Les éléments suivants sont déjà appliqués localement et ne doivent pas être refaits aveuglément: remote Git `contentglowz`, dossiers `contentglowz_*`, fichier `tools/design-tokens/contentglowz_theme.json`, workflow Android `app` + artefact `contentglowz-android-apk`, defaults app/site/API ContentGlowz, CORS/OpenAPI backend, identité Android `com.contentglowz.app`, worker Remotion `ContentGlowzTimelineVideo`, et branding docs subprojets en `ContentGlowz`.

La prochaine exécution doit reprendre par audit/correction des restes actifs, classification des occurrences historiques ShipGlowz, validation multi-stack, et plan opérateur externe. La spec est prête pour `/sf-start`.

## User Story

En tant que propriétaire du produit, je veux que tout le monorepo, les surfaces publiques, les environnements et les pipelines utilisent ContentGlowz/contentglowz au lieu de l'ancien nom, afin que la marque, le domaine et le dépôt GitHub soient cohérents avant les prochains déploiements.

Acteur principal : Diane, propriétaire du produit et du dépôt.

Déclencheur : achat du domaine `contentglowz.com` et renommage cible du dépôt GitHub vers `diane-defores/contentglowz`.

Résultat observable : un clone frais, les builds locaux, GitHub Actions, les surfaces web/app/API et les docs actives ne présentent plus l'ancien nom comme identité courante.

## Minimal Behavior Contract

Quand un utilisateur, un opérateur ou un pipeline interagit avec le projet après migration, le système doit présenter `ContentGlowz` comme marque affichée, `contentglowz` comme identifiant technique courant, `https://contentglowz.com` comme site public, `https://app.contentglowz.com` comme app web, `https://api.contentglowz.com` comme API cible, et `https://github.com/diane-defores/contentglowz` comme dépôt source. Si une dépendance externe n'est pas encore configurée, le build ou le check doit échouer clairement ou rester pilotable par variable d'environnement, sans revenir silencieusement vers l'ancien nom. L'edge case facile à rater est le mélange entre renommage visible et contrats techniques : CORS, OAuth callbacks, Android package/applicationId, artefacts CI, buckets, chemins de dossiers et clés de stockage client peuvent continuer à référencer l'ancien nom même quand la homepage est renommée.

## Success Behavior

- Depuis un clone frais du dépôt cible, `git remote -v` pointe vers `https://github.com/diane-defores/contentglowz.git` ou l'équivalent SSH du même repo.
- Les dossiers actifs du monorepo sont renommés de façon cohérente : `site`, `app`, `lab`, `worker`, et `tools/design-tokens/contentglowz_theme.json`, sauf si une contrainte outil impose une transition documentée.
- Les builds et checks utilisent les nouveaux chemins dans les scripts, workflows, README et outils internes.
- Les surfaces publiques affichent `ContentGlowz` dans les titres, métadonnées, JSON-LD, manifestes, OG, favicon/asset metadata, blog/content authors, privacy page, app title et textes localisés.
- Les valeurs par défaut de configuration utilisent `https://contentglowz.com`, `https://app.contentglowz.com` et `https://api.contentglowz.com`; les anciennes URLs `contentglowz.winflowz.com`, `app.contentglowz.winflowz.com` et `contentglowz.com` ne restent que dans une note de migration ou dans une liste de redirections temporaires explicitement nommée.
- FastAPI accepte les nouvelles origines CORS, publie des métadonnées OpenAPI ContentGlowz, conserve des messages d'erreur sûrs, et ne loggue aucun secret pendant la migration.
- GitHub Actions produit un artefact `contentglowz-android-apk` et lit les nouveaux chemins.
- Les tests et audits d'occurrences distinguent les références historiques explicitement permises des identifiants actifs à migrer.

## Error Behavior

- Si `contentglowz.com`, `app.contentglowz.com` ou `api.contentglowz.com` ne sont pas provisionnés au moment de l'implémentation, l'agent doit arrêter avant release et documenter le blocage au lieu de livrer des defaults incohérents.
- Si le changement Android `applicationId` menace une app déjà publiée, l'agent doit demander une décision explicite avant de modifier l'identifiant package; le nom affiché peut être renommé séparément.
- Si des secrets ou variables externes manquent dans GitHub, Vercel, Doppler, Clerk, Sentry, Turso, Bunny ou GCP, l'agent doit mettre à jour les exemples et docs, puis signaler les actions opérateur nécessaires sans inventer ni exposer de secrets.
- Si `rg -i "contentglowz|content flow"` trouve encore des occurrences actives après migration, le chantier ne passe pas ready/verify tant que chaque occurrence n'est pas soit migrée, soit classée comme historique autorisée.
- Le chantier ne doit jamais casser volontairement l'auth, élargir CORS à des domaines non maîtrisés, supprimer des données utilisateur, exposer des tokens, ni remplacer des clés de stockage sans plan de compatibilité.
- Une erreur OAuth/Clerk/Google auth partielle (callback invalide, redirect mismatch, origin mismatch) doit créer un état d'erreur observable (log + blocage manuel) et ne doit pas déclencher de fallback automatique vers des valeurs anciennes.
- Toute modification de domaines ou d'identifiants de sécurité doit être suivie d'une vérification d'influence cross-file (site/app/lab/worker) avant tout push.

## Problem

Le renommage ContentGlowz est partiellement exécuté. Les fondations visibles sont en place, mais il reste des références actives à l'ancien nom dans quelques fichiers d'app/backend/docs, et beaucoup d'occurrences dans ShipGlowz doivent être classées entre historique acceptable et source de vérité active à migrer.

Sans reprise cadrée, un prochain agent risque soit de refaire des opérations déjà faites, soit de laisser passer des restes qui cassent l'auth/CORS/OAuth, les docs opérateur, les builds multi-stack, ou la traçabilité des futures specs.

## Solution

Reprendre la migration en phase de consolidation: vérifier les fondations déjà appliquées, corriger les occurrences actives restantes, classifier les occurrences historiques/gouvernance, exécuter les checks pertinents par sous-projet, puis produire une checklist opérateur pour les consoles externes. Les références historiques peuvent rester uniquement si leur contexte les rend clairement non actives.

## Scope In

- Vérification sans réécriture des fondations déjà appliquées: remote, dossiers, workflow Android, app config, backend CORS/OpenAPI, worker composition, branding docs.
- Correction des occurrences actives résiduelles détectées dans `app/lib/**`, `site/src/content/**`, `lab/AGENT.md`, `lab/AGENTS.md`, `lab/CLAUDE.md`, et docs opérateur racine si l'audit en retrouve.
- Classification des occurrences ShipGlowz/gouvernance: specs/research/bugs historiques acceptables vs docs actives à migrer.
- Validation des contrats de sécurité: CORS allowlist, OAuth/Clerk callback documentation, absence de wildcard non maîtrisé, absence de secrets dans templates/logs.
- Validation des contrats app/backend/worker: Android applicationId, package Kotlin, manifest/provider authorities, composition ID `ContentGlowzTimelineVideo`, tests associés.
- Exécution ou documentation des checks site/app/backend/worker disponibles.
- Plan opérateur hors repo: GitHub, Vercel, DNS, Clerk, Google OAuth/Search Console, Sentry, Doppler, Turso, Bunny, GCS.

## Scope Out

- Purchasing or configuring DNS, Vercel domains, Clerk domains, OAuth clients, Sentry projects, Turso databases, Bunny zones, GCS buckets, Doppler projects, or GitHub repository settings directly from code.
- Rotating production secrets or changing live database names without operator confirmation.
- Rewriting product positioning beyond the mechanical brand rename from ContentGlowz to ContentGlowz.
- Removing old redirects or backwards-compatible origins before production traffic is proven moved.
- Changing feature behavior unrelated to naming, branding, domains, CORS/auth handoff, build paths, or deployment names.

## Constraints

- Do not implement this spec in the `sf-spec` run.
- Preserve working tree safety; do not revert user changes.
- Use structured parsers or framework conventions for manifests/configs where practical; avoid blind global replacement for files with security-sensitive URLs, package identifiers, JSON, YAML, or generated lockfiles.
- Treat secrets and production project settings as external operator-owned state.
- Keep French copy accented where French strings are edited.
- Use `ContentGlowz` for user-visible brand, `contentglowz` for lowercase identifiers, `contentglowz.com` for the apex domain, `app.contentglowz.com` for app web, and `api.contentglowz.com` for API unless a later operator decision overrides before implementation.
- Do not expand CORS with wildcard domains beyond owned deployment hosts.
- Package identity changes for Android must be gated if the app is already published.
- Sécurisation opérationnelle:
  - Les changements liés aux domaines/CORS/OAuth/callbacks/domaine app/API sont opérateur-only (owner/admin).
  - Aucun secret n'est modifié ou injecté par diff de spec; l'opérateur met à jour ces valeurs dans les consoles (GitHub, Vercel, Clerk, Google, Doppler, Sentry, Turso, Bunny, GCS).
  - Toute décision de migration partielle qui laisse un état incohérent (domaine inactif, callback invalide, alias CORS invalide) doit stopper le flux avant release.

## Dependencies

- Local stack detected: Astro 6.1 + npm 11 in the site, Flutter/Dart in app, FastAPI/Python in lab, Remotion/Express/TypeScript worker, GitHub Actions, Vercel, Clerk, Turso/libSQL, Bunny, GCS, Sentry, Doppler.
- Internal contract docs: subproject branding docs are reviewed at version `1.0.0` and name `ContentGlowz`; this spec must preserve their tone/trust posture.
- External dependencies (Freshness gate): `fresh-docs checked` (documentation officielle consultée pour chaque dépendance active).
  - GitHub repository rename & remote: `docs.github.com` (`Renaming a repository`, `Managing remote repositories`) : redirections GitHub, `git remote set-url` pour aligner les clones, et rappel sur l'impact des workflows Actions renommés.
  - GitHub Actions workflow: `docs.github.com` (`Workflow syntax for GitHub Actions`) : chemins relatifs / working directory, structure de workflow, références d'actions.
  - Vercel root domain config: `vercel.com/docs/builds/configure-a-build` (`Root Directory` + portée monorepo) et `vercel.com/docs/domains/set-up-custom-domain` (ajout de domaine, DNS `A`/`CNAME`, vérification + SSL).
  - Clerk redirects: `clerk.com/docs/guides/development/customize-redirect-urls` + `clerk.com/docs/reference/backend/types/backend-redirect-url` pour whitelists `redirect` et sémantique fallback.
  - Google OAuth: `developers.google.com/identity/protocols/oauth2/web-server` + `developers.google.com/identity/protocols/oauth2/policies` sur hostnames/redirect_uri exact match.
  - Android: `developer.android.com/build/configure-app-module` sur `namespace` vs `applicationId` et impact de changement d'identifiant publié.
  - Bunny: `docs.bunny.net/api-reference/authentication` et `docs.bunny.net/api-reference/core/storage-zone/list-storage-zones` pour identité API/zone et clés.
  - Doppler: `docs.doppler.com/docs/service-tokens` (séparation read-only/prod, création de token).
  - Sentry: `docs.sentry.io/api/auth/` et `docs.sentry.dev/cli/configuration` (variables/token DSN/auth).
  - Turso: `docs.turso.tech/cli/introduction` et `docs.turso.tech/tutorials/get-started-turso-cli/step-01-installation` (CLI, nom DB, URL de base de l'instance).
- Operator-owned prerequisites: DNS/domain mapping pour `contentglowz.com`, `app.contentglowz.com`, `api.contentglowz.com`; renommage GitHub (ancien `contentglowz` → `contentglowz`) ; root directories Vercel et variables/secrets dans Vercel, Doppler, Clerk, Sentry, Turso, Bunny, GCP/GCS.

## Invariants

- Authentication and ownership rules remain unchanged.
- Existing data models, API routes and business workflows remain behaviorally equivalent unless a name/domain field is the explicit change.
- Old domains may be accepted temporarily only as migration aliases with a clear comment and removal plan.
- No server secret moves into Flutter/web build defines.
- Render jobs and asset storage retain ownership checks and signed URL boundaries.
- Historical specs can mention the old name as evidence only when clearly historical; active instructions must use ContentGlowz.
- Generated files should be regenerated by the repo's scripts after source/path changes instead of manually patched where generation already exists.

## Links & Consequences

- GitHub Actions depends on renamed directories; path mismatch will fail APK builds.
- Vercel root directory settings must be changed outside the repo after directory renames; otherwise deploys will fail even if code is correct.
- Clerk, Google OAuth, Search Console, CORS and redirect URLs must be updated together; partial migration can break sign-in and integrations.
- Android package/applicationId changes can affect installed app continuity and app-store identity.
- LocalStorage keys, method channels and file provider authorities can strand old local state or break Android native bridges if renamed without compatibility.
- Turso database names like `contentglowz-prod2`, Bunny zones like `contentglowz-images`, GCS paths like `contentglowz/renders`, and Sentry releases may require explicit migration or compatibility aliases.
- Public SEO metadata and canonical URLs must switch atomically with domain deployment to avoid duplicate indexing.
- ShipGlowz trackers and old specs contain many old-name occurrences; verification must distinguish active current-truth docs from archived historical evidence.
- Les erreurs d'authentification doivent être observables: callback invalide, domaine non autorisé, token manquant doivent produire un log/état d'échec net, pas de fallback silencieux vers l'ancien environnement.

## Documentation Coherence

Update or audit:

- Root `README.md`, `shipglows_data/technical/SETUP.md`, `CHANGELOG.md`.
- `shipglows_data/workflow/README.md`, subproject business/technical/editorial docs, active TASKS/AUDIT logs if they describe current state.
- `site/README.md`, `shipglows_data` docs, public content, privacy page, page intent/claim register.
- `app/README.md`, `CHANGELOG.md`, web auth docs, setup/build scripts, localization references.
- `lab/README.md`, `.env.example`, deployment docs, API docs/OpenAPI metadata.
- `worker/README.md`, `DEPLOYMENT.md`, package metadata.
- Any generated reports/specs that are intended as active implementation inputs for future agents.

No documentation surface is exempt when it states current repo, brand, domain, deploy, environment, or setup truth.

## Edge Cases

- `ContentGlowzTimelineVideo` is now a shared backend/worker API/schema composition ID; changing it again breaks compatibility unless backend, worker, fixtures and tests change together.
- Android package paths are now under `com/contentglowz/app`; any future applicationId change can affect installed app continuity and must be operator-approved if the app is published.
- App-local keys such as `contentglowz:eruda` may need migration to avoid losing useful debug preferences.
- CORS regex currently allows ContentGlowz deployment domains and subdomains; broad edits can over-allow domains.
- Generated comments in theme token files point to `tools/design-tokens/contentglowz_theme.json`; regenerate after renaming the theme source.
- Lockfiles (`package-lock.json`, `pubspec.lock`) should reflect package renames after package manager commands, not hand-edited unless the package manager has no better path.
- Archived research/spec evidence may legitimately say the old name; active docs and runtime strings must not.
- Git remote is currently aligned locally, but other clones may still require `git remote set-url`.

## Implementation Tasks

- [ ] Tâche 1 : Vérifier l'état de reprise et protéger les changements existants
  - Fichier : `shipglows_data/workflow/specs/monorepo/renommage-contentglowz-monorepo-2026-05-14.md`
  - Action : Lire cette spec, confirmer que le chantier est en reprise post-exécution partielle, et noter dans le rapport `sf-start` les fondations déjà appliquées.
  - User story link : évite de refaire ou d'écraser un renommage partiellement appliqué.
  - Depends on : none.
  - Validate with : `git remote -v`, `find . -maxdepth 2 -type d -name 'contentglowz_*'`, `test -f tools/design-tokens/contentglowz_theme.json`.
  - Notes : Stopper si le worktree contient des changements utilisateur incompatibles avec la reprise.

- [ ] Tâche 2 : Corriger les occurrences actives résiduelles dans l'app, le site et les docs agent backend
  - Fichier : `app/lib/l10n/app_localizations.dart`, `app/lib/presentation/screens/analytics/analytics_screen.dart`, `site/src/content/ai-agents/newsletter-robot.md`, `site/src/content/ai-agents/scheduler-robot.md`, `lab/AGENT.md`, `lab/AGENTS.md`, `lab/CLAUDE.md`
  - Action : Remplacer uniquement les occurrences qui désignent l'ancien produit ou les anciens chemins actifs; conserver les expressions génériques en anglais comme `content flows` si elles ne désignent pas la marque.
  - User story link : supprime les restes visibles ou opérateur de l'ancien nom.
  - Depends on : Tâche 1.
  - Validate with : `rg -n -i "contentglowz|content flow" app site lab --glob '!**/.flox/**' --glob '!**/.venv_check/**'`.
  - Notes : Ne pas remplacer mécaniquement les phrases naturelles `content flows` qui ne sont pas une référence à ContentGlowz.

- [ ] Tâche 3 : Vérifier et finaliser les docs root/setup/changelog
  - Fichier : `README.md`, `shipglows_data/technical/SETUP.md`, `CHANGELOG.md`
  - Action : Confirmer que clone URL, chemins, domaines, noms d'artefacts, commandes de setup et entrée de migration utilisent ContentGlowz; corriger les restes actifs éventuels.
  - User story link : un opérateur suit le bon dépôt et les bons chemins.
  - Depends on : Tâche 1.
  - Validate with : `rg -n -i "contentglowz|content flow|diane-defores/contentglowz" README.md shipglows_data/technical/SETUP.md CHANGELOG.md`.
  - Notes : Les mentions historiques dans `CHANGELOG.md` sont autorisées si explicitement historiques.

- [ ] Tâche 4 : Vérifier les scripts et tokens de design après renommage
  - Fichier : `tools/design-tokens/check_design_tokens.mjs`, `tools/design-tokens/generate_app_theme_tokens.mjs`, scripts root éventuels
  - Action : Confirmer que les chemins `contentglowz_*` et `tools/design-tokens/contentglowz_theme.json` sont utilisés, puis régénérer les tokens si une source générée est désynchronisée.
  - User story link : préserve les validations design/build sous le nouveau nom.
  - Depends on : Tâche 1.
  - Validate with : `node tools/design-tokens/check_design_tokens.mjs` si les dépendances locales sont présentes.
  - Notes : Ne pas hand-edit des sorties générées si un script officiel existe.

- [ ] Tâche 5 : Vérifier GitHub Actions Android
  - Fichier : `.github/workflows/android-apk.yml`
  - Action : Vérifier que le workflow pointe vers `app`, les nouveaux domaines et l'artefact `contentglowz-android-apk`; corriger uniquement les restes si l'audit en trouve.
  - User story link : les builds CI publient des artefacts sous le nouveau nom.
  - Depends on : Tâche 1.
  - Validate with : YAML parse/check local si disponible et `rg -n -i "contentglowz" .github/workflows/android-apk.yml`.
  - Notes : Variables GitHub `APP_SITE_URL`, `APP_WEB_URL`, `API_BASE_URL` restent overrideables.

- [ ] Tâche 6 : Valider le site Astro sous ContentGlowz
  - Fichier : `site/package.json`, `astro.config.mjs`, `.env.example`, `vercel.json`, `src/config/site.ts`, `src/layouts/*`, `src/components/*`, `src/pages/*`, `src/content/**`
  - Action : Corriger les restes actifs, vérifier canonical URL, app URL, API URL, metadata, JSON-LD, copy publique, privacy, authors et liens GitHub/API.
  - User story link : le site public présente ContentGlowz et les bons domaines.
  - Depends on : Tâches 2, 3.
  - Validate with : `npm run build` depuis `site` et audit `rg -n -i "contentglowz|content flow" site`.
  - Notes : Les phrases naturelles `content flows` peuvent rester si elles ne désignent pas la marque.

- [ ] Tâche 7 : Valider l'app Flutter et Android native
  - Fichier : `app/pubspec.yaml`, `.env.example`, `web/index.html`, `web/manifest.json`, `lib/core/app_config.dart`, `lib/main.dart`, `lib/l10n/app_localizations.dart`, `lib/**`, `test/**`
  - Action : Corriger les restes actifs, vérifier package name, titre, manifest, defaults URL, l10n, messages, tests, namespace/applicationId `com.contentglowz.app`, Kotlin package paths et provider authorities.
  - User story link : l'expérience app affiche et configure ContentGlowz.
  - Depends on : Tâches 2, 3.
  - Validate with : `flox activate --command 'flutter analyze'` et `flox activate --command 'flutter test'` depuis `app`.
  - Notes : Si l'application Android est déjà publiée, ne pas changer à nouveau `applicationId` sans validation opérateur.

- [ ] Tâche 8 : Valider le backend FastAPI et les contrats sécurité
  - Fichier : `lab/api/main.py`, `lab/api/services/**`, `lab/api/routers/**`, `lab/.env.example`, `lab/README.md`, `lab/render.yaml`, `lab/ecosystem.config.cjs`
  - Action : Vérifier OpenAPI title/contact, CORS origins/regex, user-agent, messages, docs, env examples et noms de service; corriger les restes actifs sans élargir les domaines autorisés.
  - User story link : l'API accepte et décrit les nouveaux domaines sans élargir la sécurité.
  - Depends on : Tâches 2, 3.
  - Validate with : tests ciblés backend et `rg -n -i "contentglowz|content flow" lab/api lab/tests lab/.env.example lab/README.md`.
  - Notes : Conserver les anciennes origines seulement comme alias temporaires commentés avec plan de retrait.

- [ ] Tâche 9 : Finaliser les contrats auth, OAuth et intégrations externes documentées
  - Fichier : `lab/.env.example`, `site/.env.example`, `app/.env.example`, docs setup/deployment
  - Action : Documenter les nouvelles URLs de callback/redirect pour Clerk, Google OAuth/Search Console, Vercel, GitHub, Sentry, Doppler, Bunny, GCS, Turso.
  - User story link : évite les ruptures d'auth et d'intégrations après déploiement.
  - Depends on : Tâches 6-8.
  - Validate with : revue manuelle des env templates et checklist opérateur.
  - Notes : Ne jamais écrire de secret réel.

- [ ] Tâche 10 : Valider le worker Remotion et son contrat backend
  - Fichier : `worker/package.json`, `README.md`, `DEPLOYMENT.md`, `server/**`, `remotion/**`, tests
  - Action : Vérifier package/service/docs/storage path defaults et cohérence backend/worker sur `ContentGlowzTimelineVideo`.
  - User story link : les rendus et artefacts internes suivent le nouveau nom.
  - Depends on : Tâches 8, 9.
  - Validate with : `npm run lint`, `npm run test:storage`, `npm run test:timeline` depuis `worker`.
  - Notes : Ne pas changer à nouveau le composition ID sans mettre à jour backend, fixtures et tests ensemble.

- [ ] Tâche 11 : Classifier et migrer les docs de gouvernance actives
  - Fichier : `shipglows_data/business/**`, `shipglows_data/editorial/**`, `shipglows_data/technical/**`, `shipglows_data/workflow/**`
  - Action : Migrer les documents qui décrivent l'état courant; laisser les specs/research/bugs historiques si leur ancien nom est une preuve ou un contexte passé.
  - User story link : les agents futurs lisent ContentGlowz comme source de vérité.
  - Depends on : Tâches 2-10.
  - Validate with : `rg -n -i "contentglowz|content flow" shipglows_data`.
  - Notes : Ne pas réécrire toute l'histoire ShipGlowz; la classification doit apparaître dans le rapport de vérification.

- [ ] Tâche 12 : Mettre à jour les tests, fixtures et snapshots de noms restants
  - Fichier : `app/test/**`, `lab/tests/**`, `worker/**/*.test.ts`, fixtures JSON
  - Action : Adapter uniquement les assertions/fixtures qui portent encore l'ancien nom actif; vérifier les tests déjà migrés vers ContentGlowz.
  - User story link : la validation automatique protège le nouveau contrat de nommage.
  - Depends on : Tâches 6-10.
  - Validate with : suites de tests app/backend/worker.
  - Notes : Ne pas désactiver de test uniquement parce qu'il capture l'ancien nom.

- [ ] Tâche 13 : Vérifier assets et metadata visuelles
  - Fichier : `site/public/*`, `app/web/icons/*`, manifests, OG metadata
  - Action : Vérifier que SVG/OG/favicon/manifest ne contiennent pas l'ancien texte; remplacer ou régénérer si nécessaire.
  - User story link : les previews sociales et installations web affichent ContentGlowz.
  - Depends on : Tâches 6-7.
  - Validate with : inspection SVG/metadata et build site/app.
  - Notes : Les bitmaps peuvent nécessiter une tâche design séparée si le texte est incrusté.

- [ ] Tâche 14 : Auditer les occurrences globales et classifier les restes
  - Fichier : repo complet
  - Action : Exécuter `rg -n -i "contentglowz|content flow|contentglowz"` avec exclusions de dossiers générés, puis migrer ou classer chaque occurrence restante.
  - User story link : garantit le "partout" demandé.
  - Depends on : Tâches 2-13.
  - Validate with : rapport d'audit final listant zéro occurrence active non justifiée.
  - Notes : Le fichier de cette spec peut mentionner l'ancien nom comme preuve de migration.

- [ ] Tâche 15 : Exécuter les validations multi-stack
  - Fichier : `site`, `app`, `lab`, `worker`
  - Action : Lancer les builds/checks pertinents par sous-projet.
  - User story link : prouve que le renommage ne casse pas les runtimes.
  - Depends on : Tâches 6-14.
  - Validate with : site build, Flutter analyze/test, backend tests ciblés, worker lint/tests.
  - Notes : Documenter les checks impossibles faute de dépendances/secrets.

- [ ] Tâche 16 : Préparer le plan opérateur de déploiement
  - Fichier : `shipglows_data/technical/SETUP.md`, docs deployment subprojects, rapport final du chantier
  - Action : Lister les actions hors repo : GitHub repo settings, GitHub variables/secrets, Vercel root directories/domains/env vars, Clerk allowed origins/redirects, Google OAuth callbacks, Sentry project/release, Doppler project/env, Turso/Bunny/GCS aliases.
  - User story link : relie le code renommé à la production réelle.
  - Depends on : Tâches 9, 15.
  - Validate with : checklist opérateur prête avant `/sf-ship`.
  - Notes : Ne pas supposer que les consoles externes ont été changées.

## Acceptance Criteria

- [ ] CA 1 : Given un clone frais du dépôt, when l'opérateur lit `README.md` et `shipglows_data/technical/SETUP.md`, then il voit `ContentGlowz`, `contentglowz`, `diane-defores/contentglowz`, et les nouveaux chemins de sous-projets.
- [ ] CA 2 : Given le remote local, when `git remote -v` est exécuté, then fetch et push pointent vers le dépôt `contentglowz`.
- [ ] CA 3 : Given le workflow Android, when GitHub Actions s'exécute, then il utilise `app` et produit un artefact `contentglowz-android-apk`.
- [ ] CA 4 : Given le site Astro, when `npm run build` réussit, then les canonical URLs, JSON-LD, titres, metadata et copy publique utilisent ContentGlowz et `contentglowz.com`.
- [ ] CA 5 : Given l'app Flutter, when l'utilisateur ouvre l'app web ou Android, then le titre, le manifest, les messages visibles et les URLs par défaut utilisent ContentGlowz/contentglowz.
- [ ] CA 6 : Given l'API FastAPI, when une requête vient de `https://contentglowz.com` ou `https://app.contentglowz.com`, then CORS l'autorise sans accepter des domaines non maîtrisés.
- [ ] CA 7 : Given l'auth web et les intégrations OAuth, when les callbacks sont documentés, then les nouvelles URLs ContentGlowz sont listées et aucun secret réel n'est committé.
- [ ] CA 8 : Given le worker Remotion, when les tests timeline et storage passent, then backend et worker partagent le même nom de composition ou un alias compatible documenté.
- [ ] CA 9 : Given un audit `rg -i "contentglowz|content flow"`, when une occurrence reste, then elle est soit supprimée, soit classée comme historique autorisée dans le rapport de vérification.
- [ ] CA 10 : Given les anciens domaines, when ils restent dans CORS ou docs, then ils sont marqués comme aliases temporaires de migration avec plan de retrait.
- [ ] CA 11 : Given une app Android déjà publiée, when l'applicationId doit changer, then l'implémentation s'arrête et demande validation opérateur avant modification.
- [ ] CA 12 : Given les docs ShipGlowz actives, when un agent frais lit les contextes business/techniques, then il comprend que la source de vérité est ContentGlowz et non l'ancien nom.
- [ ] CA 13 : Given les intégrations externes critiques, when `/sf-start` est lancé, then la vérification de la documentation officielle GitHub/Vercel/Clerk/Google/Android est explicitement attestée (`fresh-docs checked`) ou l'agent doit refuser de procéder.

## Test Strategy

- Audit d'occurrences avant/après avec `rg --count-matches` et `rg -n -i`.
- Site : `npm run build` depuis `site`.
- App : `flox activate --command 'flutter analyze'` et `flox activate --command 'flutter test'` depuis `app`; build APK debug si Android metadata change.
- Backend : tests ciblés FastAPI, auth/CORS, observability et routes touchées; au minimum les tests existants liés à app config, observability, auth handoff, projects/bootstrap si disponibles.
- Worker : `npm run lint`, `npm run test:storage`, `npm run test:timeline`.
- Manual QA : vérifier homepage, sign-in/sign-up redirect, app title, API `/docs`, health endpoint, rendered artifact naming, GitHub Actions workflow syntax, docs setup.
- Operator QA : vérifier que les consoles externes ont les nouveaux domaines, callbacks, env vars et root directories avant production.

## Risks

- P1 : Auth/CORS/OAuth cassés si domaines et callbacks ne sont pas synchronisés.
- P1 : Android package/applicationId changé sans stratégie de publication.
- P1 : CI/CD cassé si Vercel ou GitHub Actions gardent les anciens root directories.
- P1 : Échec de conformité externe si des changements GitHub/Vercel/Clerk/Google/Android sont appliqués en dehors des contraintes vérifiées de cette spec.
- P2 : Anciennes URLs SEO indexées si canonical/sitemap/redirections sont incohérents.
- P2 : Artefacts ou buckets cloud renommés sans compatibilité avec les jobs existants.
- P2 : Audit d'occurrences trop agressif qui réécrit de l'historique et détruit la traçabilité.
- P3 : Lockfiles/generated files modifiés manuellement et désynchronisés.

## Execution Notes

- Lire d'abord cette spec, puis `README.md`, `shipglows_data/technical/SETUP.md`, `.github/workflows/android-apk.yml`, `site/src/config/site.ts`, `app/lib/core/app_config.dart`, `app/android/app/build.gradle.kts`, `lab/api/main.py`, `worker/remotion/Root.tsx`, et `worker/package.json`.
- Procéder par couches de consolidation : preuve des fondations déjà faites, correction des restes actifs, validation sécurité, validation app/backend/worker, classification gouvernance, puis audit global.
- Ne pas refaire les renommages de dossiers ou de remote déjà appliqués; vérifier et préserver ces changements.
- Éviter un remplacement global aveugle dans les fichiers de sécurité, JSON/YAML, lockfiles et specs historiques.
- Stopper avant release si DNS, Vercel domains, Clerk redirects, OAuth callbacks ou applicationId Android ne sont pas confirmés.
- Commandes de validation cibles : `git remote -v`, `rg -n -i ...`, `npm run build`, `flutter analyze`, `flutter test`, tests backend ciblés, `npm run lint` et tests worker.
- Fresh External Docs : `fresh-docs checked` (docs listées dans `Dependencies` validées le 2026-05-14).
- Contrôles sécurité (minimum) : callback/auth flow, CORS allowlist, applicationId transition plan, et preuve d'absence de secret dans logs/build.
- Operator QA : vérifier que les consoles externes ont les nouveaux domaines, callbacks, env vars et root directories avant production.
- Stop condition : si une occurrence restante touche auth, OAuth, CORS, applicationId, storage/bucket path ou identité de repo sans preuve claire de compatibilité, rerouter vers décision opérateur au lieu de deviner.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-14 22:42:30 UTC | sf-spec | GPT-5 Codex | Création de la spec de migration ContentGlowz après scan du monorepo, des docs, du remote Git et des occurrences de marque. | Draft saved | `/sf-ready Renommage ContentGlowz monorepo` |
| 2026-05-14 22:52:42 UTC | sf-ready | GPT-5 Codex | Vérification DoR du spec de renommage ContentGlowz et conformité à la doctrine de préparation avant implémentation. | Not ready | `/sf-spec Renommage ContentGlowz monorepo` |
| 2026-05-14 22:55:24 UTC | sf-spec | GPT-5 Codex | Ajout explicite des dépendances externes, gates de fraîcheur doc, et garde-fous sécurité avant exécution. | Draft updated | `/sf-ready Renommage ContentGlowz monorepo` |
| 2026-05-14 23:09:58 UTC | sf-ready | GPT-5 Codex | Relecture DoR du spec et évaluation finale avant /sf-start ; dépendances externes et sécurité encore non validées en docs fraîches. | Not ready | `/sf-spec Renommage ContentGlowz monorepo` |
| 2026-05-14 23:26:12 UTC | sf-ready | GPT-5 Codex | Vérification DoR finale après consultation documentaire officielle pour toutes dépendances listées; mise à jour du `fresh-docs` en `checked`. | Ready | `/sf-start Renommage ContentGlowz monorepo` |
| 2026-05-14 23:52:54 UTC | sf-start | GPT-5 Codex | Lancement du chantier de renommage en lot initial: validation remote, finalisation des dossiers, et migration ciblée des références actives critiques (env/site, package names, OpenAPI, docs worker). | partial | `/sf-verify Renommage ContentGlowz monorepo` |
| 2026-05-15 06:17:00 UTC | sf-start | GPT-5 Codex | Tentative d'exécution depuis ce spec: blocage de contrat détecté (`status: in_progress`), donc reroutage vers gate de readiness avant nouvelle implémentation. | rerouted | `/sf-ready Renommage ContentGlowz monorepo` |
| 2026-05-15 19:22:36 UTC | sf-ready | GPT-5 Codex | Revue DoR après exécution partielle: le contrat décrit encore l'état initial et ne sépare pas assez le reste à faire des tâches déjà exécutées. | Not ready | `/sf-spec Renommage ContentGlowz monorepo` |
| 2026-05-15 19:39:20 UTC | sf-spec | GPT-5 Codex | Recadrage de la spec en phase de consolidation après exécution partielle: preuves actualisées, tâches déjà faites sorties du chemin critique, tâches restantes ordonnées et garde-fous sécurité conservés. | Draft updated | `/sf-ready Renommage ContentGlowz monorepo` |
| 2026-05-15 19:53:23 UTC | sf-ready | GPT-5 Codex | Gate DoR stricte sur la spec recadrée: structure complète, tâches restantes actionnables, sécurité/domaines/auth bornés, et état partiel explicitement pris en compte. | Ready | `/sf-start Renommage ContentGlowz monorepo` |
| 2026-05-15 20:25:00 UTC | sf-start | GPT-5 Codex | Exécution de consolidation: correction des chemins actifs restants `contentglowz` dans les docs opérateur backend, maintien des expressions génériques `content flows`, et relance d'audit ciblé des occurrences actives. | implemented | `/sf-verify Renommage ContentGlowz monorepo` |
| 2026-05-15 20:33:49 UTC | sf-verify | GPT-5 Codex | Vérification de l'exécution de consolidation: corrections lab confirmées, mais critères d'acceptance multi-stack et bug gate global non encore clôturés. | partial | `/sf-start Renommage ContentGlowz monorepo` |
| 2026-05-15 20:38:28 UTC | sf-start | GPT-5 Codex | Reprise du chantier en mode consolidation: revalidation des fondations (remote/dossiers/theme), audit ciblé des occurrences actives, et relance du check design tokens pour confirmer les écarts hors scope renommage. | partial | `/sf-verify Renommage ContentGlowz monorepo` |
| 2026-05-16 06:52:41 UTC | sf-verify | GPT-5 Codex | Vérification reprise: fondations ContentGlowz confirmées, mais readiness non atteinte à cause du bug gate partiel, de `lab/AGENTS.md` non symlink malgré bug clos, du check design tokens en échec, et des preuves preview/multi-stack manquantes. | partial | `/sf-start Renommage ContentGlowz monorepo` |
| 2026-05-16 07:35:49 UTC | sf-build | GPT-5 Codex | Loop agents séquentiel: correction de `lab/AGENTS.md` en symlink, réduction du budget `duration` Flutter via `AppMotion.base`, et relance des validations ciblées. | partial | `/sf-test retests bug gate ContentGlowz` |
| 2026-05-16 12:18:30 UTC | sf-test | GPT-5 Codex | Retest manuel BUG-2026-05-05-001 préparé puis bloqué par l'absence de l'entrée `Open Interactive Demo` dans le build Android release fourni. | blocked | `/sf-fix BUG-2026-05-05-001 Android demo entry unavailable` |
| 2026-05-16 12:27:23 UTC | sf-fix | GPT-5 Codex | Correction directe du blocage de retest Android: restauration du CTA `Open Interactive Demo` sur l'écran d'entrée signed-out et validation Flutter ciblée. | fix-attempted | `/sf-test --retest BUG-2026-05-05-001 on Android device` |
| 2026-05-16 12:53:04 UTC | sf-test | GPT-5 Codex | Retest manuel BUG-2026-05-05-001 validé par l'utilisateur après correction du CTA demo; passage du bug en `fixed-pending-verify`. | pass | `/sf-verify BUG-2026-05-05-001 Android safe area demo onboarding` |
| 2026-05-16 12:54:28 UTC | sf-verify | GPT-5 Codex | Vérification ciblée BUG-2026-05-05-001: tests Flutter focalisés repassés et retest Android utilisateur accepté comme preuve de fermeture. | verified | `/sf-test --retest BUG-2026-05-05-002 on Android device` |
| 2026-05-16 13:54:53 UTC | sf-test | GPT-5 Codex | Retest manuel BUG-2026-05-05-002 validé par l'utilisateur; remarque séparée soulevée sur le comportement Back hors onboarding à clarifier. | pass | `/sf-verify BUG-2026-05-05-002 Android back navigation demo` |
| 2026-05-16 13:57:23 UTC | sf-verify | GPT-5 Codex | Vérification ciblée BUG-2026-05-05-002: test Flutter focalisé repassé et retest Android utilisateur accepté comme preuve de fermeture; question Back hors onboarding laissée hors contrat. | verified | `/sf-test --retest BUG-2026-05-10-001` |

## Current Chantier Flow

- sf-spec: done
- sf-ready: ready
- sf-start: partial
- sf-verify: partial; BUG-2026-05-05-001 verified; BUG-2026-05-05-002 verified
- sf-build: partial
- sf-test: pass
- sf-fix: fix-attempted
- sf-end: not launched
- sf-ship: not launched

Prochaine commande recommandée : `/sf-test --retest BUG-2026-05-10-001`.
