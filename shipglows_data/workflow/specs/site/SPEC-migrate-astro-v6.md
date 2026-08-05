---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "site"
created: "2026-04-27"
updated: "2026-05-03"
status: ready
source_skill: sf-spec
scope: "migration"
owner: "Diane"
confidence: medium
user_story: "En tant que mainteneuse du site marketing ContentGlows, je veux migrer site d'Astro 5 vers Astro 6, afin de garder un build supporté, sécurisé et déployable sans régression SEO ni rupture des pages de contenu."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "Astro static build"
  - "Vercel deployment"
  - "Content collections Markdown"
  - "Sitemap and robots endpoints"
  - "ContentGlows app handoff routes"
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/site/guidelines.md"
    artifact_version: "0.1.0"
    required_status: "unknown"
  - artifact: "CLAUDE.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/technical/site/architecture.md"
    artifact_version: "0.1.0"
    required_status: "draft"
supersedes: []
evidence:
  - "CLAUDE.md"
  - "package.json"
  - "package-lock.json"
  - "astro.config.mjs"
  - "src/content/config.ts"
  - "src/pages/**/*.astro"
  - "src/layouts/Layout.astro"
  - "src/layouts/BlogPost.astro"
  - "src/config/site.ts"
  - "src/pages/robots.txt.ts"
  - "https://docs.astro.build/en/guides/upgrade-to/v6/"
next_step: "/sf-start Implement Astro v6 migration"
---

## Title
Migrate site from Astro 5 to Astro 6

## Status
Ready. Spec implementable without blocking gaps.

Baseline observed on 2026-04-27:

- Current working directory: `/home/claude/contentglows/site`
- Current package name: `contentglows-landing`
- Current Astro dependency: `astro@^5.17.1`
- Current sitemap integration: `@astrojs/sitemap@^3.7.2`
- Current package manager: `npm@11.12.1`
- Current Node constraint: `>=22 <23`
- Current local runtime used for validation: Node `v22.22.2`, npm `11.12.1`
- Current baseline command result: `npm run build` passes and generates 72 static pages plus `robots.txt` and sitemap files.
- Current repo state includes pre-existing uncommitted changes in docs and package files. The migration implementation must not revert or overwrite unrelated parallel agent changes.

## User Story
En tant que mainteneuse du site marketing ContentGlows, je veux migrer `site` d'Astro 5 vers Astro 6, afin de garder un build supporté, sécurisé et déployable sans régression SEO, contenu, sitemap, pages marketing, ni routes de redirection vers l'application.

Actor: mainteneuse du site marketing ContentGlows.

Trigger: décision de migration majeure Astro 5 -> 6 sur le repo `site`.

Observable result: le site compile avec Astro 6, génère les mêmes familles de routes publiques, conserve les métadonnées SEO essentielles, conserve les redirections statiques `/sign-in`, `/sign-up`, `/launch`, et publie un artefact statique compatible Vercel.

## Minimal Behavior Contract
Le système accepte le code source Astro/Markdown existant, installe Astro 6 et les intégrations officielles compatibles, convertit les content collections vers la Content Layer API requise par Astro 6, remplace les usages supprimés comme `post.slug` et `post.render()`, puis produit un build statique déterministe via `npm run build`. En cas d'erreur de migration, l'implémentation doit isoler la cause dans le fichier concerné, ne pas supprimer de contenu, et revenir au dernier état Astro 5 validé par Git si le build Astro 6 ne peut pas être stabilisé. L'edge case facile à rater est la génération des slugs et des ancres Markdown: Astro 6 remplace les anciennes propriétés legacy de content collections et modifie les IDs de titres Markdown, ce qui peut casser des URL internes ou la table des matières sans erreur de build.

## Success Behavior
Après migration:

- `npm install` installe les dépendances sans conflit de lockfile.
- `npm run build` passe sous Node `22.12.0` ou supérieur.
- `npm run preview` peut servir le répertoire `dist` pour sanity check manuel.
- `astro.config.mjs` reste ESM et continue à définir `site`, `base: '/'`, et `@astrojs/sitemap` avec exclusion des drafts.
- Les collections Markdown sont définies dans `src/content.config.ts` avec `defineCollection`, `glob()` depuis `astro/loaders`, et `z` depuis `astro/zod`.
- Les routes dynamiques utilisent `post.id` comme slug de route, pas `post.slug`.
- Les pages dynamiques rendent le contenu avec `render(post)` depuis `astro:content`, pas `post.render()`.
- Les pages index et related posts construisent leurs URLs avec l'identifiant compatible Astro 6.
- `/robots.txt` répond sans trailing slash et pointe vers `${siteUrl}/sitemap-index.xml`.
- Les routes `/sign-in`, `/sign-up`, et `/launch` conservent leur handoff vers `app.contentglows.winflowz.com` et la transmission de `redirect_url` quand applicable.
- Les métadonnées SEO de `Layout.astro` restent générées: canonical, Open Graph, Twitter Card, JSON-LD Organization/WebSite/Article.
- Les pages de contenu principales restent générées: `blog`, `ai-agents`, `platform`, `seo-strategy`, `startup-journey`, `technical-optimization`, `tutorials`.
- Le sitemap généré ne contient pas de drafts et ne référence pas de chemins cassés causés par le passage de `slug` à `id`.

## Error Behavior
Si une étape échoue:

- Échec d'installation: ne pas modifier manuellement le lockfile à l'aveugle; relancer avec logs complets, identifier la dépendance bloquante, puis choisir entre `npx @astrojs/upgrade` ou mise à jour manuelle de `astro` et intégrations officielles.
- Échec Content Collections: vérifier d'abord `src/content.config.ts`, les loaders `glob()`, la suppression de `type: 'content'`, l'import `astro/zod`, puis les appels `getCollection()`.
- Échec de type sur `post.slug`: remplacer par `post.id` et vérifier que les URLs générées gardent la même forme publique.
- Échec de rendu sur `post.render()`: importer `render` depuis `astro:content` et utiliser `await render(post)`.
- Régression route dynamique: inspecter les sorties de build pour chaque collection, comparer les chemins générés au baseline Astro 5, et corriger les paramètres de `getStaticPaths()`.
- Régression SEO ou sitemap: bloquer le ship, car la migration ne doit pas sacrifier l'indexation.
- Régression visuelle liée à l'ordre `<script>`/`<style>` Astro 6: corriger l'ordre dans les composants ciblés plutôt que contourner globalement.
- Si le build ne peut pas être stabilisé dans la session: rollback par retour au commit/branche de départ ou restauration ciblée des fichiers modifiés par la migration uniquement, sans toucher aux changements parallèles d'autres agents.

## Problem
Astro 6 retire des comportements encore présents dans ce repo Astro 5. Le point bloquant local est l'usage de l'ancienne configuration de content collections dans `src/content/config.ts` avec `type: 'content'`, `z` importé depuis `astro:content`, `post.slug`, et `post.render()`. La documentation officielle Astro v6 indique que le support legacy des content collections est supprimé, que la config doit être déplacée vers `src/content.config.ts`, que chaque collection doit définir un loader, que `type: 'content'` doit être supprimé, que l'ID d'entrée remplace le slug legacy, et que `render(entry)` remplace `entry.render()`.

Sans migration explicite, l'upgrade Astro 6 peut casser le build, générer des routes différentes, ou rendre les pages de contenu impossibles à compiler. Même si le site est statique et sans adapter SSR, le risque est élevé parce que la majorité des routes publiques vient des collections Markdown.

## Solution
Migrer en deux couches: d'abord rendre le code compatible Astro 6 tout en restant conceptuellement proche du comportement Astro 5, puis mettre à jour `astro`, `@astrojs/sitemap`, `package-lock.json`, et les artefacts associés. L'approche doit conserver les URLs publiques existantes autant que possible en remplaçant systématiquement `post.slug` par `post.id` et en vérifiant les chemins générés.

La migration doit être incrémentale:

1. Créer une branche ou un commit de sauvegarde avant modification.
2. Convertir les content collections vers `src/content.config.ts`.
3. Adapter les routes et layouts aux APIs Astro 6.
4. Mettre à jour les dépendances Astro et lockfile.
5. Exécuter build, preview et checks SEO ciblés.
6. Déployer en preview Vercel et comparer les routes critiques.
7. Ship uniquement si les critères d'acceptation passent.

## Scope In
- Lire et respecter `CLAUDE.md`, `package.json`, `package-lock.json`, `astro.config.mjs`, `src/pages`, `src/layouts`, composants structurants, `src/config/site.ts`, `src/content/config.ts`, et scripts npm.
- Mettre à jour `package.json` pour Astro 6 et intégrations officielles compatibles.
- Régénérer `package-lock.json` avec npm 11.
- Migrer `src/content/config.ts` vers `src/content.config.ts` selon la Content Layer API Astro 6.
- Supprimer l'ancienne config legacy `src/content/config.ts` après migration réussie.
- Remplacer les imports Zod legacy par `astro/zod`.
- Ajouter `glob()` depuis `astro/loaders` pour chaque collection Markdown.
- Remplacer `post.slug` par `post.id` sur routes, index, related posts, breadcrumbs, et cartes.
- Remplacer `post.render()` par `render(post)` depuis `astro:content`.
- Vérifier que les paramètres `getStaticPaths()` sont des chaînes.
- Vérifier les usages `import.meta.env` dans `src/config/site.ts` et `src/layouts/Layout.astro` sous le nouveau comportement d'inlining Astro 6.
- Vérifier les endpoints avec extension, surtout `/robots.txt`, sans trailing slash.
- Vérifier les impacts Markdown heading IDs sur la table des matières de `BlogPost.astro`.
- Vérifier les images statiques et Open Graph sous Astro 6.
- Prévoir validation Vercel preview.
- Documenter rollback et commandes de validation.

## Scope Out
- Migration des autres repos `app` et `lab`.
- Changement de design, copywriting, branding, pricing ou funnel.
- Ajout d'un adapter SSR Vercel ou passage en server rendering.
- Refonte du système de contenu au-delà de la compatibilité Astro 6.
- Migration vers MDX, collections live, route caching, CSP Astro 6, fonts Astro 6 ou Rust compiler expérimental.
- Modification des contenus Markdown sauf correction minimale d'ancres internes cassées si la validation les identifie.
- Modification de la base Turso/libSQL ou des contrats backend. Conclusion attendue: aucune migration DB requise pour cette migration front statique.
- Revert des changements parallèles déjà présents dans le working tree.

## Constraints
- Repo autorisé: `/home/claude/contentglows/site` uniquement.
- Fichier de spec autorisé: `/home/claude/contentglows/shipglows_data/workflow/specs/site/SPEC-migrate-astro-v6.md`.
- Ne jamais annuler ou écraser les changements d'autres agents.
- Le working tree actuel contient déjà des modifications non liées dans plusieurs fichiers docs et package files; l'implémentation doit inspecter les diffs avant d'éditer un fichier modifié.
- Node doit rester `>=22 <23`; Astro 6 requiert Node `22.12.0` ou supérieur selon la doc officielle.
- npm doit rester `>=11 <12` si aucune contrainte de déploiement ne l'interdit.
- Le site doit rester statique.
- `astro.config.mjs` doit rester ESM; Astro 6 ne supporte plus les configs CommonJS `.cjs` / `.cts`.
- Le sitemap doit continuer à exclure les URLs contenant `/drafts/`.
- Les liens de handoff app doivent continuer à utiliser `src/config/site.ts`.
- Les variables privées lues via `import.meta.env` sont inlinées en Astro 6; éviter d'introduire de secret côté client ou dans le HTML généré.
- En français, le contenu doit utiliser `tu` et les accents selon `CLAUDE.md`, même si cette migration ne devrait pas modifier le contenu marketing.

## Dependencies
Internal dependencies:

- `CLAUDE.md@0.1.0`: contraintes opérationnelles, structure, handoff backend, règles de langue.
- `shipglows_data/business/business.md@1.0.0`: promesse produit et cohérence business.
- `shipglows_data/branding/branding.md@1.0.0`: ton, positionnement, microcopy.
- `shipglows_data/technical/site/guidelines.md@0.1.0`: dette metadata car statut draft.
- `shipglows_data/technical/site/architecture.md@0.1.0`: architecture site statique et routes à préserver.
- `package.json`: scripts `dev`, `start`, `build`, `preview`; engines Node/npm.
- `package-lock.json`: lockfile npm v3 à régénérer.
- `astro.config.mjs`: `site`, `base`, sitemap integration.
- `src/content/config.ts`: source legacy à migrer.
- `src/layouts/BlogPost.astro`: rendu des pages de collections, related posts, breadcrumbs, table des matières.
- `src/layouts/Layout.astro`: SEO global, schema.org, analytics production-only.
- `src/config/site.ts`: URLs app, checkout, API, build metadata.
- `src/pages/robots.txt.ts`: endpoint avec extension concerné par la règle trailing slash Astro 6.

External dependencies and fresh-docs verdict:

- Official Astro v6 upgrade guide: `https://docs.astro.build/en/guides/upgrade-to/v6/` checked on 2026-04-27. Verdict: `fresh-docs checked`.
- Key Astro v6 changes relevant locally: Node 22.12+, Vite 7, Zod 4, official integration upgrades, removal of legacy content collections, removal of `Astro.glob()`, removal of `post.render()` legacy entry API, removal of `post.slug` legacy entry API, `import.meta.env` inlining, endpoint trailing slash behavior, Markdown heading ID generation changes.
- Vite 7 migration guide: only needed if custom Vite config/plugins are introduced. Current repo has no `vite` config in `astro.config.mjs`; verdict: `fresh-docs not needed unless implementation adds Vite config`.
- Zod 4 migration guide: needed if current schemas fail after Astro 6 because `baseSchema` uses transform/default/coerce. Verdict: `fresh-docs gap acceptable for spec; implementation should consult if build/type errors point to Zod`.

## Invariants
- Public site URL remains `https://contentglows.winflowz.com` by default unless `APP_SITE_URL` overrides it.
- App URL remains `https://app.contentglows.winflowz.com` by default unless `APP_WEB_URL` overrides it.
- `/sign-in`, `/sign-up`, and `/launch` stay noindex redirect pages.
- `/robots.txt` remains a generated endpoint with `Content-Type: text/plain; charset=utf-8`.
- Sitemap URL in robots remains `${siteUrl}/sitemap-index.xml`.
- `dist` remains build output.
- Content drafts must not be exposed by collection pages.
- Blog tag pages are generated only from non-draft blog posts.
- Article SEO uses title, description, cover, byline, tags, date from transformed collection data.
- Related posts never include the current post.
- Build should not require backend availability.
- No Turso/libSQL migration is required because this scope touches only the static marketing site.

## Links & Consequences
Upstream links:

- Markdown content entries feed dynamic route generation.
- Environment variables feed site canonical URLs, app handoff URLs, checkout URLs, API URL, and build metadata.
- Vercel or deployment environment must run Node 22.12+.

Downstream consequences:

- SEO: route path changes can invalidate indexed URLs. The migration must verify every collection path before ship.
- Sitemap: slug/id mismatch can publish wrong URLs. The generated sitemap must be inspected.
- Analytics: `import.meta.env.PROD` controls production-only script injection; Astro 6 env inlining must keep this behavior.
- Auth/app handoff: redirect pages are static but client-side scripts use `define:vars`; validation must confirm `redirect_url` forwarding still works.
- Accessibility: no intended UI changes. If script/style ordering affects nav menu behavior, keyboard/mobile navigation must be retested.
- Performance: Astro 6/Vite 7 may change asset hashes and CSS/script ordering. Compare page load smoke tests, not exact filenames.
- Security: Astro 6 removes `%25` route filenames for security and inlines env vars; do not introduce secrets into `import.meta.env` usage.
- Ops: Vercel project settings may need Node 22 if dashboard still pins Node 20.

## Documentation Coherence
Documentation to update if implementation changes commands, engines, routes, or deployment behavior:

- `CLAUDE.md`: update Common Commands or architecture notes only if scripts, Node/npm requirements, or content collection locations change in a way future agents need.
- `README.md`: update setup instructions if it lists Astro 5, older Node, or old content collection paths.
- `shipglows_data/technical/site/architecture.md`: update content collection architecture from `src/content/config.ts` to `src/content.config.ts` if present.
- `shipglows_data/editorial/site/content-map.md`: update only if route paths or content folders change.
- `CHANGELOG.md`: add migration note after implementation, not during spec writing unless session workflow requires it.
- This spec itself: update `Status`, `Execution Notes`, and `Acceptance Criteria` evidence after implementation.

Documentation coherence debt already present:

- `shipglows_data/technical/site/guidelines.md` and `shipglows_data/technical/site/architecture.md` are draft metadata, while `shipglows_data/business/business.md`, `shipglows_data/branding/branding.md`, `shipglows_data/product/site/product.md`, `shipglows_data/gtm/site/gtm.md`, and `shipglows_data/editorial/site/content-map.md` are reviewed. `/sf-ready` should decide whether draft docs block readiness.

## Edge Cases
- Collection entries named `index.md` currently generate paths like `/ai-agents/index/index.html` under Astro 5 baseline. Do not assume Astro 6 should collapse these paths unless product explicitly wants route cleanup.
- `post.id` may preserve nested path IDs differently than `post.slug`; verify generated route output per collection.
- `src/content/docs/**` exists as a collection but currently has no dynamic docs route. Do not expose it accidentally.
- `baseSchema` uses `.transform()` and `.default(false)`; Zod 4 changed some default/transform behavior. Validate transformed fields `date`, `cover`, `byline`, `featured`, and `draft`.
- Markdown headings ending with punctuation or inline code may get different IDs in Astro 6. `BlogPost.astro` currently computes ToC slugs manually with regex and may diverge from Astro-rendered heading IDs.
- Related posts and breadcrumb schema currently use `post.slug`; after migration they must use the same route ID as `getStaticPaths()`.
- Blog tag pages generate tag slugs from tag labels; ensure params remain strings and no accented tag creates invalid path behavior.
- `/robots.txt/` should not be expected to work in Astro 6 because endpoints with file extensions only support no trailing slash.
- `src/config/site.ts` reads `APP_SITE_URL`, `APP_WEB_URL`, `POLAR_*`, `API_BASE_URL`, `VERCEL_*`, and `BUILD_TIMESTAMP` from `import.meta.env`; Astro 6 inlines values and does not coerce strings.
- `Layout.astro` references `/apple-touch-icon.png`, but `public` currently only has favicon and OG assets. This is not introduced by migration; do not block Astro 6 unless validation decides to fix existing missing asset debt separately.
- `public/og-default.svg` and `public/favicon.svg` should not be rasterized because they are used as static assets, not Astro `<Image />` transformations.
- No usage of `Astro.glob()`, `<ViewTransitions />`, `<ClientRouter />`, `astro:actions`, custom adapters, or custom Vite config was found. Re-scan before implementation because parallel agents may add code.

## Implementation Tasks
- [ ] Tâche 1 : Stabiliser le point de départ et protéger les changements parallèles
  - Fichier : `git working tree`
  - Action : Lire `git status --short` et `git diff -- package.json package-lock.json src/content/config.ts src/layouts/BlogPost.astro src/pages src/config/site.ts astro.config.mjs` avant toute édition; noter les fichiers déjà modifiés par d'autres agents.
  - User story link : garantit une migration sûre sans écraser le travail existant.
  - Depends on : aucune.
  - Validate with : `git status --short` et inspection des diffs ciblés.
  - Notes : si `package.json` ou `package-lock.json` ont changé depuis cette spec, intégrer ces changements plutôt que les remplacer.

- [ ] Tâche 2 : Créer une sauvegarde de rollback
  - Fichier : `git branch` ou commit local selon workflow équipe
  - Action : Créer une branche de migration ou identifier le commit SHA de départ; consigner le SHA dans les notes d'exécution.
  - User story link : permet de revenir à Astro 5 si Astro 6 ne peut pas être stabilisé.
  - Depends on : Tâche 1.
  - Validate with : `git rev-parse --short HEAD` et `git branch --show-current`.
  - Notes : ne pas committer les changements parallèles sans accord; si le working tree est sale, privilégier une branche et un journal précis des fichiers touchés.

- [ ] Tâche 3 : Migrer les collections vers Astro 6 Content Layer API
  - Fichier : `src/content.config.ts`
  - Action : Créer `src/content.config.ts`; importer `defineCollection` depuis `astro:content`, `z` depuis `astro/zod`, et `glob` depuis `astro/loaders`; définir une collection par dossier avec `loader: glob({ pattern: '**/[^_]*.{md,mdx}', base: './src/content/<collection>' })`; conserver `baseSchema` et son transform en l'adaptant à Zod 4 si nécessaire.
  - User story link : débloque le build Astro 6 pour toutes les pages de contenu.
  - Depends on : Tâche 2.
  - Validate with : `npm run build` après adaptation des routes, ou `npx astro sync` si disponible.
  - Notes : inclure les collections `blog`, `docs`, `ai-agents`, `platform`, `seo-strategy`, `startup-journey`, `technical-optimization`, `tutorials`.

- [ ] Tâche 4 : Retirer la configuration legacy
  - Fichier : `src/content/config.ts`
  - Action : Supprimer le fichier legacy après création validée de `src/content.config.ts`.
  - User story link : respecte la suppression Astro 6 du support legacy.
  - Depends on : Tâche 3.
  - Validate with : absence d'import ou référence à `src/content/config.ts`; `rg -n "src/content/config|type: 'content'|defineCollection\(\{ type" src astro.config.mjs`.
  - Notes : ne supprimer aucun fichier Markdown sous `src/content/**`.

- [ ] Tâche 5 : Adapter les routes dynamiques de collections
  - Fichier : `src/pages/blog/[...slug].astro`, `src/pages/ai-agents/[...slug].astro`, `src/pages/platform/[...slug].astro`, `src/pages/seo-strategy/[...slug].astro`, `src/pages/startup-journey/[...slug].astro`, `src/pages/technical-optimization/[...slug].astro`, `src/pages/tutorials/[...slug].astro`
  - Action : Importer `render` depuis `astro:content`; remplacer `params: { slug: post.slug }` par `params: { slug: post.id }`; remplacer `const { Content } = await post.render()` par `const { Content } = await render(post)`.
  - User story link : préserve les routes publiques de contenu sous l'API Astro 6.
  - Depends on : Tâche 3.
  - Validate with : `rg -n "post\.slug|post\.render\(" src/pages` retourne aucun usage à migrer; `npm run build` liste toutes les routes attendues.
  - Notes : `getStaticPaths()` doit retourner uniquement des strings ou undefined dans `params`.

- [ ] Tâche 6 : Adapter les index, tags, breadcrumbs et related posts
  - Fichier : `src/pages/blog/index.astro`, `src/pages/blog/tag/[tag].astro`, `src/layouts/BlogPost.astro`
  - Action : Remplacer les usages de `post.slug`, `featured.slug`, `rp.slug` par `post.id`, `featured.id`, `rp.id`; vérifier `sectionPath` et schema.org breadcrumb; conserver la logique de tri et filtrage.
  - User story link : évite les liens internes cassés après migration.
  - Depends on : Tâche 5.
  - Validate with : `rg -n "\.slug" src/pages src/layouts` ne montre plus de dépendance aux collection entries legacy; inspection de `dist/blog/index.html` et d'une page article.
  - Notes : les slugs de tags restent calculés depuis les labels de tags, pas depuis `post.id`.

- [ ] Tâche 7 : Corriger la table des matières Markdown si les IDs divergent
  - Fichier : `src/layouts/BlogPost.astro`
  - Action : Comparer les IDs rendus par Astro 6 aux slugs générés par le regex ToC; si divergence avec les titres finissant par ponctuation/code, soit aligner le slugger manuel sur Astro 6, soit utiliser les `headings` retournés par `render(post)` et les passer au layout.
  - User story link : préserve la navigation intra-article.
  - Depends on : Tâche 5.
  - Validate with : ouvrir une page contenant au moins trois h2/h3 et tester les liens ToC; grep dans `dist` pour `href="#` et IDs correspondants.
  - Notes : ne pas ajouter de plugin rehype de compat Astro 5 sauf si des ancres publiques critiques sont prouvées cassées.

- [ ] Tâche 8 : Mettre à jour Astro et intégrations officielles
  - Fichier : `package.json`, `package-lock.json`
  - Action : Utiliser `npx @astrojs/upgrade` ou mise à jour manuelle équivalente pour passer `astro` à `^6.x` et `@astrojs/sitemap` à la version compatible Astro 6; régénérer le lockfile avec npm 11.
  - User story link : bascule effectivement le site sur Astro 6 supporté.
  - Depends on : Tâches 3 à 7 préparées ou prêtes à corriger immédiatement.
  - Validate with : `npm install`, `npm ls astro @astrojs/sitemap vite zod`, puis `npm run build`.
  - Notes : conserver `engines.node: ">=22 <23"` sauf raison documentée; vérifier que le lockfile ne rétrograde pas les changements parallèles.

- [ ] Tâche 9 : Vérifier `astro.config.mjs` contre les changements Astro 6
  - Fichier : `astro.config.mjs`
  - Action : Confirmer qu'aucun flag expérimental supprimé, config CommonJS, custom Vite `build.rollupOptions.output`, i18n, adapter SSR ou legacy collections n'est présent; garder `sitemap({ filter })`.
  - User story link : réduit les risques de breaking changes non applicables au repo.
  - Depends on : Tâche 8.
  - Validate with : `npm run build` et `rg -n "legacy|experimental|vite:|rollupOptions|adapter|i18n" astro.config.mjs`.
  - Notes : ne pas ajouter d'adapter Vercel pour un site statique.

- [ ] Tâche 10 : Vérifier les variables d'environnement et URLs de handoff
  - Fichier : `src/config/site.ts`, `src/pages/sign-in.astro`, `src/pages/sign-up.astro`, `src/pages/launch.astro`, `src/layouts/Layout.astro`
  - Action : Confirmer que les usages `import.meta.env` ne dépendent pas de coercion Astro 5; si une valeur booléenne/string devient ambiguë, convertir explicitement; vérifier que les scripts `define:vars` gardent les URLs attendues.
  - User story link : préserve les routes de conversion et d'auth app.
  - Depends on : Tâche 8.
  - Validate with : build, inspection HTML générée pour `/sign-in/index.html`, `/sign-up/index.html`, `/launch/index.html`, et test browser preview si possible.
  - Notes : ne jamais exposer de secret via `import.meta.env`.

- [ ] Tâche 11 : Vérifier endpoints, sitemap et SEO output
  - Fichier : `src/pages/robots.txt.ts`, `astro.config.mjs`, `src/layouts/Layout.astro`, `dist/sitemap-index.xml`, `dist/sitemap-0.xml`, `dist/robots.txt`
  - Action : Vérifier `/robots.txt` sans trailing slash, sitemap index, sitemap URLs, canonical, OG image absolue, JSON-LD Article et BreadcrumbList.
  - User story link : protège l'indexation et le trafic organique.
  - Depends on : Tâche 8.
  - Validate with : `npm run build`; `grep -R "sitemap-index.xml\|canonical\|application/ld+json" dist | head`; preview manuel de `/robots.txt`.
  - Notes : Astro 6 ne garantit pas `/robots.txt/`; ne pas créer de lien interne vers cette variante.

- [ ] Tâche 12 : Exécuter validation complète locale
  - Fichier : `dist/**`
  - Action : Lancer build et preview; comparer routes critiques avec le baseline observé; vérifier homepage, blog index, une page article par collection, tag page, privacy, auth redirect pages, robots et sitemap.
  - User story link : donne une preuve de non-régression observable.
  - Depends on : Tâches 3 à 11.
  - Validate with : `npm run build`, `npm run preview -- --host 127.0.0.1`, puis smoke tests HTTP si possible.
  - Notes : comparer les chemins, pas les hash assets.

- [ ] Tâche 13 : Mettre à jour la documentation minimale
  - Fichier : `README.md`, `CLAUDE.md`, `shipglows_data/technical/site/architecture.md`, `CHANGELOG.md`
  - Action : Mettre à jour seulement les mentions devenues fausses: version Astro, chemin `src/content.config.ts`, Node/npm requis, commandes de validation; ajouter une entrée changelog si le workflow le demande.
  - User story link : aide les futurs mainteneurs à exploiter Astro 6 sans contexte oral.
  - Depends on : Tâche 12.
  - Validate with : revue de diff; `rg -n "Astro 5|src/content/config.ts|Node 20|node 20|legacy collections" README.md CLAUDE.md shipglows_data/technical/site/architecture.md CHANGELOG.md`.
  - Notes : ne pas réécrire les docs business non concernées.

- [ ] Tâche 14 : Valider le déploiement preview
  - Fichier : `Vercel project settings`, `vercel.json`
  - Action : Confirmer que l'environnement de build Vercel utilise Node 22.12+; lancer un déploiement preview; tester les mêmes routes critiques que localement.
  - User story link : assure que la migration est vraiment déployable.
  - Depends on : Tâche 12.
  - Validate with : build Vercel vert, URL preview accessible, `/robots.txt`, `/sitemap-index.xml`, `/blog`, une page article, `/sign-in?redirect_url=...`.
  - Notes : `vercel.json` ne configure que les headers; pas de changement attendu sauf contrainte Node manquante ailleurs.

- [ ] Tâche 15 : Préparer le rollback documenté
  - Fichier : `Execution Notes` de cette spec ou notes de PR
  - Action : Documenter le SHA de départ, les fichiers modifiés, la commande de retour arrière, et les symptômes qui déclenchent rollback.
  - User story link : garantit une sortie de secours si le site prod régresse.
  - Depends on : Tâche 14.
  - Validate with : procédure lisible par un agent frais.
  - Notes : rollback cible les fichiers touchés par la migration seulement si le working tree contient des changements parallèles.

## Acceptance Criteria
- [ ] `package.json` déclare Astro 6 et une version compatible de `@astrojs/sitemap`.
- [ ] `package-lock.json` est régénéré avec npm 11 et ne contient pas de conflit ou de rollback accidentel de changements parallèles.
- [ ] `src/content.config.ts` existe et définit toutes les collections via Content Layer API Astro 6.
- [ ] `src/content/config.ts` n'existe plus ou n'est plus utilisé.
- [ ] `rg -n "post\.slug|featured\.slug|rp\.slug|\.render\(\)|from ['\"]astro:content['\"].*z|type: 'content'" src` ne retourne aucun usage legacy à corriger, hors faux positifs documentés.
- [ ] `npm run build` passe sous Node 22.12+.
- [ ] Le build génère les familles de routes attendues pour homepage, 404, privacy, launch, sign-in, sign-up, robots, blog, tags, et toutes les collections dynamiques.
- [ ] Les URLs d'articles restent cohérentes avec le baseline Astro 5 ou les écarts sont explicitement listés et acceptés.
- [ ] Le sitemap généré ne contient pas de drafts et référence des URLs valides.
- [ ] `/robots.txt` généré référence `${siteUrl}/sitemap-index.xml`.
- [ ] Une page article rend son contenu Markdown, son JSON-LD Article, son breadcrumb, ses tags, sa ToC si applicable, et ses related posts.
- [ ] Les redirections client `/sign-in`, `/sign-up`, `/launch` fonctionnent en preview et conservent `redirect_url` pour sign-in/sign-up.
- [ ] Aucune donnée secrète n'est exposée dans les fichiers statiques par changement d'usage `import.meta.env`.
- [ ] Vercel preview build passe avec Node 22.12+.
- [ ] Rollback documenté et possible sans supprimer les changements non liés d'autres agents.

## Test Strategy
Local automated checks:

- `node -v` doit être `v22.12.0` ou supérieur.
- `npm -v` doit respecter `>=11 <12`.
- `npm install` doit réussir.
- `npm ls astro @astrojs/sitemap vite zod` doit confirmer la pile Astro 6.
- `npm run build` doit réussir.
- `rg -n "Astro\.glob|post\.slug|featured\.slug|rp\.slug|post\.render\(|getEntryBySlug|getDataEntryById|from ['\"]astro:schema|from ['\"]astro:content['\"].*z|type: 'content'|ViewTransitions|handleForms|prefetch\(.+with" src astro.config.mjs` doit être propre ou documenter chaque faux positif.

Generated output checks:

- Vérifier `dist/index.html` pour title, canonical, OG, analytics prod condition selon mode.
- Vérifier `dist/blog/index.html` pour liens d'articles.
- Vérifier une page générée dans chaque collection dynamique.
- Vérifier `dist/blog/tag/<tag>/index.html` pour liens d'articles.
- Vérifier `dist/robots.txt` et `dist/sitemap-index.xml`.
- Vérifier que les routes avec `index.md` restent intentionnelles, par exemple `/platform/index/` si c'est le comportement conservé.

Manual preview checks:

- `npm run preview -- --host 127.0.0.1`.
- Ouvrir `/`, `/blog`, une page `/blog/...`, `/blog/tag/seo/`, `/platform/connect-your-website/`, `/ai-agents/article-generator/`, `/seo-strategy/seo-framework-2026/`, `/technical-optimization/cut-dependencies-50-percent/`, `/tutorials/secure-api-key-management/`, `/sign-in?redirect_url=%2Fdashboard`, `/sign-up`, `/launch`, `/robots.txt`, `/sitemap-index.xml`.
- Tester le menu mobile dans `Navbar.astro` car Astro 6 change l'ordre de rendu des scripts/styles.
- Tester les liens ToC sur un article avec au moins trois headings.

Deployment checks:

- Vercel preview build vert.
- Confirmer Node 22.12+ côté Vercel.
- Tester les mêmes routes critiques sur URL preview.
- Comparer un crawl rapide local vs preview si possible.

Rollback validation:

- Avant ship, confirmer que le rollback restaure `npm run build` Astro 5 baseline ou le dernier état stable.
- Après rollback éventuel, vérifier `npm run build` et routes critiques minimales.

## Risks
- High: content collections legacy supprimées dans Astro 6; le repo utilise précisément `src/content/config.ts`, `type: 'content'`, `post.slug`, et `post.render()`.
- High: route path drift si `post.id` ne correspond pas exactement à l'ancien `post.slug`.
- Medium: Zod 4 peut changer le comportement du schéma transformé, en particulier defaults et transforms.
- Medium: Markdown heading ID generation peut casser la ToC ou des ancres publiques.
- Medium: `import.meta.env` inlining peut figer des valeurs au build et exposer une mauvaise hypothèse sur variables privées/publiques.
- Medium: Vercel peut être configuré sur Node 20 même si `package.json` demande Node 22.
- Medium: working tree sale avec modifications parallèles dans `package.json` et `package-lock.json`; risque d'écraser un travail non lié.
- Low: absence d'adapter SSR limite les impacts Adapter API, SSRManifest, Actions, sessions.
- Low: absence de custom Vite config limite les impacts Vite Environment API.
- Low: absence d'Astro Image components limite les impacts image service, SVG rasterization et `getImage()` client.

## Execution Notes
Investigation performed for this spec on 2026-04-27:

- Read `CLAUDE.md`, `package.json`, `package-lock.json`, `astro.config.mjs`, `tsconfig.json`, `vercel.json`.
- Enumerated `src/pages`, `src/layouts`, `src/components`, `src/config/site.ts`, and content collections.
- Read `src/content/config.ts`, `src/layouts/Layout.astro`, `src/layouts/BlogPost.astro`, `src/pages/robots.txt.ts`, sign-in/sign-up/launch routes, and representative dynamic routes.
- Ran `npm run build` successfully on current Astro 5 baseline with Node `v22.22.2` and npm `11.12.1`; build generated 72 pages.
- Consulted official Astro v6 upgrade guide at `https://docs.astro.build/en/guides/upgrade-to/v6/`; verdict `fresh-docs checked`.
- No `Astro.glob()`, `ViewTransitions`, `ClientRouter`, Astro Actions, session config, custom adapter, custom Vite config, or Astro image API usage was found in current source scan.
- Found relevant legacy usages: `src/content/config.ts`, `z` from `astro:content`, `type: 'content'`, `post.slug`, `post.render()`.
- Current `git status --short` shows pre-existing modified files outside this spec, including docs and package files. Treat them as parallel work unless implementation proves otherwise.

Recommended incremental migration command sequence:

```bash
cd /home/claude/contentglows/site
git status --short
git diff -- package.json package-lock.json src/content/config.ts src/layouts/BlogPost.astro src/pages src/config/site.ts astro.config.mjs
node -v
npm -v
npm run build
# edit Content Layer API and route usages
npx @astrojs/upgrade
npm install
npm ls astro @astrojs/sitemap vite zod
npm run build
npm run preview -- --host 127.0.0.1
```

Rollback plan:

- Preferred: rollback by Git to the migration branch starting SHA, preserving unrelated parallel changes via selective restore or a separate worktree/stash plan.
- If only migration files changed, revert these files only: `package.json`, `package-lock.json`, `astro.config.mjs` if touched, `src/content.config.ts`, `src/content/config.ts`, dynamic routes under `src/pages`, `src/layouts/BlogPost.astro`, docs touched for the migration.
- Do not run destructive commands like `git reset --hard` in a dirty collaborative worktree.
- Rollback trigger: local build fails after reasonable targeted fixes, Vercel preview cannot run Node 22.12+, generated URLs differ materially without approval, sitemap/canonical routes break, or app handoff routes regress.
- Rollback validation: `npm install`, `npm run build`, inspect `/robots.txt`, `/blog`, one article route, and `/sign-in` on preview.

## Open Questions
No user questions were asked by instruction. The implementation should proceed with these explicit assumptions unless contradicted by newer repo state:

- Assumption: preserving existing public URL shapes is more important than cleaning up routes like `/platform/index/`.
- Assumption: no backend or Turso migration is required because the change is static-site-only.
- Assumption: Vercel is the deployment target because `vercel.json` exists and headers are configured there.
- Assumption: Node `>=22 <23` and npm `>=11 <12` are intended constraints, not accidental local changes.
- Assumption: `docs` collection remains defined for type/content access but remains unexposed unless existing routes expose it later.
- Assumption: if Markdown ToC anchors diverge, aligning `BlogPost.astro` to Astro 6 heading IDs is preferred over preserving Astro 5 IDs globally.
- Assumption: official Astro v6 docs are the source of truth; community migration notes are not needed unless a concrete build issue appears.

## Current Chantier Flow

- sf-spec: implemented
- sf-ready: implemented
- sf-start: implemented
- sf-verify: partial
- sf-end: closed
- sf-ship: shipped

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-04-29 | sf-start | gpt-5 | Implemented Astro 6 migration, updated docs, regenerated lockfile, and validated build/preview outputs | implemented | /sf-verify Migrate site from Astro 5 to Astro 6 |
| 2026-04-29 | sf-verify | gpt-5 | Verified Astro 6 migration against spec, docs, dependencies, generated output, bug gate, and quick risk checks | partial | Align root tracker and verify with npm 11 / Vercel preview before final ship |
| 2026-04-29 | sf-end | gpt-5 | Closed Astro 6 migration session, aligned trackers, and updated changelog | closed | /sf-ship Migrate site from Astro 5 to Astro 6 |
| 2026-04-29 | sf-ship | gpt-5 | Prepared commit and push for the Astro 6 migration closure | shipped | Verify Vercel preview after push |
| 2026-05-03 | sf-verify | gpt-5 | Re-verified Astro 6 migration post-ship with current docs, dependency checks, Vercel deploy evidence, protected preview fetches, local preview, and handoff browser checks | partial | Fix npm/Vercel engine alignment, repo hygiene, dev-mode docs, and stale architecture note, then rerun sf-verify |
| 2026-05-03 | sf-start | gpt-5 | Implemented post-verify cleanup: pinned Vercel npm commands, removed tracked venv from Git scope, documented development mode, and fixed stale architecture note | implemented | /sf-verify Migrate site from Astro 5 to Astro 6 |
| 2026-05-03 | sf-verify | gpt-5 | Re-ran post-cleanup verification: npm 11.12.1 install/build/audit, dependency tree, doc freshness scan, local preview routes, and app handoff checks | partial | /sf-ship post-cleanup changes, then /sf-prod verify Vercel build logs use npm 11.12.1 |
| 2026-05-03 | sf-ship | gpt-5 | Shipped post-cleanup fixes for npm/Vercel alignment, repo hygiene, dev-mode docs, stale docs, changelog, and trackers | shipped | /sf-prod site |
