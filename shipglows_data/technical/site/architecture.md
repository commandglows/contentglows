---
artifact: architecture_context
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: site
updated: "2026-06-30"
created: "2026-04-26"
status: reviewed
source_skill: sf-docs
scope: architecture
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: low
docs_impact: yes
depends_on:
  - AGENT.md@1.0.0
  - shipglows_data/technical/site/context.md@1.0.0
  - shipglows_data/technical/site/context-function-tree.md@1.0.0
evidence:
  - astro.config.mjs
  - src/layouts
  - src/pages
  - src/components
  - src/content
  - src/content.config.ts
  - src/config/site.ts
  - vercel.json
linked_systems:
  - Astro
  - Node.js
  - Vercel
  - Markdown
external_dependencies:
  - npm/Node ecosystem (astro, @astrojs/sitemap)
  - Vercel platform services (headers, build, deploy)
  - App handoff endpoints (APP_WEB_URL/API_BASE_URL)
invariants:
  - src/content schemas should remain backward compatible with existing frontmatter keys.
  - sign-in/sign-up/launch routes must keep the same handoff behavior unless CLAUDE.md is updated.
  - canonical URLs and build metadata must stay consistent across astro.config.mjs and vercel.json.
supersedes: []
next_review: "2026-07-26"
next_step: /sf-docs update shipglows_data/technical/site/architecture.md
---

# shipglows_data/technical/site/architecture.md — site (Astro + Node + Vercel)

## 1) Architecture globale

```text
[Editeur Markdown + collections]
        |
        v
  astro build (Node)
        |
        v
  Pages Astro SSG (src/pages, composants)
        |
        +--> ContentLayer (src/content + src/content.config.ts)
        +--> SEO metadata (Layout.astro)
        +--> Handoff links (src/config/site.ts)
        |
        v
  Outputs dist/ pages statiques
        |
        v
  Vercel (headers + domaine + assets)
```

Le site est une application frontale de documentation/acquisition.
Il ne contient pas de logique métier backend ni de règles business sensibles ; il sert de point d’entrée et de relais vers l’app web.

## 2) Couche de rendu
- **Compilation**: Astro + Node (scripts `astro dev`, `astro build`, `astro preview`).
- **Rendu par route**:
  - pages statiques (`index`, `privacy`, redirections auth),
  - variantes localisées `fr/*` pour home, privacy, handoff et blog,
  - routes dynamiques pré-générées via `getStaticPaths`.
- **Intégration SEO**:
  - sitemap intégré via `@astrojs/sitemap`,
  - route `robots.txt` générée en runtime Astro.

## 3) Couche contenu
- Sources éditoriales dans `src/content/*` :
  - `blog`, `ai-agents`, `platform`, `seo-strategy`, `startup-journey`, `technical-optimization`, `tutorials`.
- Schéma commun dans `src/content.config.ts` via Content Layer API :
  - validation frontmatter,
  - transformation dates (`date` normalisée),
  - champs dérivés (`cover`, `byline`).
- Rendus article via `BlogPost.astro` pour:
  - hero,
  - méta article,
  - table des matières,
  - articles liés.

## 4) Couche handoff app
- `src/config/site.ts` centralise les endpoints de site et de redirection:
  - `siteUrl`, `appWebUrl`, `appSignInUrl`, `appEntryUrl`,
  - `apiBaseUrl`, `buildCommitSha`, `buildEnvironment`, `buildTimestamp`.
- `/sign-in`, `/sign-up`, `/launch` sont des pages de transition vers l’app.
- `/sign-in` et `/sign-up` conservent `redirect_url` quand le paramètre existe.
- `Navbar/Hero/ClosingCta/CtaBanner` exposent les CTAs de conversion de manière homogène.

## 5) Couche déploiement
- Build Node -> artefacts dans `dist/`.
- Déploiement attendu sur Vercel avec install/build épinglés sur `npm@11.12.1` et headers globaux:
  - `X-Content-Type-Options: nosniff`,
  - `X-Frame-Options: DENY`,
  - `Referrer-Policy`,
  - `Permissions-Policy`.
- Les changements de domaines/headers exigent une mise à jour simultanée de:
  - `astro.config.mjs`,
  - `vercel.json`,
  - `README.md`,
  - `AGENT.md` + `CONTEXT*`.

## 6) Contraintes de cohérence
- Les pages d’accueil et de documentation doivent rester alignées avec les capacités réelles de l’écosystème (app + backend).
- Les liens d’authentification doivent rester des redirections courtes et prévisibles.
- Les pages handoff doivent rester `noindex`.
- La promesse publique de résilience doit rester bornée au mode dégradé réellement décrit: accès app après auth, lectures cache, file locale des actions supportées, replay automatique.
- Les données de contenu affichées en page d’accueil, FAQ, pricing et CTA doivent être maintenues cohérentes avec `shipglows_data/branding/branding.md` et `shipglows_data/business/business.md`.

## 7) Risques techniques
- `draft: true` sur un article non filtré peut changer le SEO si une collection est mal configurée.
- Des changements de schéma content peuvent casser la génération si l’enveloppe frontmatter n’est pas rétro-compatible.
- Une modification des variables d’environnement de handoff sans migration docs crée des liens cassés vers l’app.
