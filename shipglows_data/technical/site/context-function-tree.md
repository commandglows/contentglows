---
artifact: artifact_context
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: site
created: "2026-04-26"
updated: "2026-06-30"
status: reviewed
source_skill: sf-docs
scope: function_tree
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: low
docs_impact: yes
depends_on:
  - shipglows_data/technical/site/context.md@1.0.0
  - AGENT.md@1.0.0
evidence:
  - src/pages
  - src/layouts
  - src/components
  - src/content.config.ts
  - src/config/site.ts
supersedes: []
next_review: "2026-07-26"
next_step: /sf-docs update shipglows_data/technical/site/context-function-tree.md
---

# shipglows_data/technical/site/context-function-tree.md — site

## Racine Astro
- `src/pages/index.astro`
  - Assemble le parcours home (Navbar → Hero → Problem → Robots → Features → Testimonials → Pricing → FAQ → ClosingCta → Footer).
  - Utilise `Layout.astro` avec meta/SEO par défaut.

## Handoff/auth
- `src/pages/sign-in.astro`
  - `appSignInUrl` via `src/config/site.ts`
  - page shell sans indexation
  - script client `window.location.replace()` avec support optionnel de `redirect_url`.
- `src/pages/sign-up.astro`
  - même comportement redirection que `/sign-in` pour cohérence CTA.
  - propage aussi `redirect_url` vers la cible app.
- `src/pages/launch.astro`
  - route d’entrée explicite vers l’app (`APP_WEB_URL/#/entry`) avec fallback UI.
- `src/pages/fr/sign-in.astro`, `src/pages/fr/sign-up.astro`, `src/pages/fr/launch.astro`
  - variantes localisées du handoff avec mêmes invariants (`noindex`, redirection client, contrat app inchangé).

## Pages de contenu éditorial
- `src/pages/blog/index.astro`
  - `getCollection('blog', ...not draft)`
  - tri décroissant par date
  - extraction d’un article `featured`
  - rendu liste + carte featured.
- `src/pages/blog/[...slug].astro`
  - `getStaticPaths()` sur collection `blog`
  - résout chaque `post` puis `render(post)` dans `BlogPost.astro`.
- `src/pages/blog/tag/[tag].astro`
  - agrège tous les tags existants depuis `blog` (`getCollection`)
  - génère un chemin par tag avec slug
  - filtre les posts taggés puis affiche la liste.
- `src/pages/fr/blog/index.astro`, `src/pages/fr/blog/[...slug].astro`, `src/pages/fr/blog/tag/[tag].astro`
  - variantes localisées du blog avec metadata et routage par locale.
- `src/pages/platform/[...slug].astro`
  - route dynamique de collection `platform`, même pattern que `blog`.
- `src/pages/ai-agents/[...slug].astro`
  - route dynamique de collection `ai-agents`.
- `src/pages/startup-journey/[...slug].astro`
  - route dynamique de collection `startup-journey`.
- `src/pages/seo-strategy/[...slug].astro`
  - route dynamique de collection `seo-strategy`.
- `src/pages/technical-optimization/[...slug].astro`
  - route dynamique de collection `technical-optimization`.
- `src/pages/tutorials/[...slug].astro`
  - route dynamique de collection `tutorials`.
- `src/pages/privacy.astro`
  - page statique privacy + déclaration cookie-free analytics.
- `src/pages/fr/index.astro`, `src/pages/fr/privacy.astro`
  - surfaces coeur localisées pour acquisition et trust.
- `src/pages/robots.txt.ts`
  - handler `GET: APIRoute`
  - répond `text/plain` avec `Sitemap: ${siteUrl}/sitemap-index.xml`.

## Layouts
- `src/layouts/Layout.astro`
  - Props SEO (`title`, `description`, `ogImage`, etc.).
  - Computation canonical URL et image absolue.
- `src/layouts/Layout.astro` (continuation)
  - `articleSchema` conditionnel quand `ogType === article`.
  - injection JSON-LD `Organization` + `WebSite`.
  - script analytics non bloquant en production uniquement.
- `src/layouts/BlogPost.astro`
  - compose `Layout` avec metadata article.
  - calcule `wordCount` + `readingTime`.
  - extrait ToC (`h2`, `h3`) depuis markdown body.
  - section "related" via proximité de tags + `getCollection` de même collection.
  - calcule `sectionPath` depuis `post.collection`.

## Infrastructure configuration
- `src/config/site.ts`
  - normalise:
    - `APP_SITE_URL` -> `siteUrl`
    - `APP_WEB_URL` -> `appWebUrl`, `appSignInUrl`, `appEntryUrl`
    - `API_BASE_URL` + metadata Vercel.
- `src/content.config.ts`
  - schéma commun `baseSchema` (title, description, dates, image, tags, draft, etc.)
  - `transform` pour `date`, `cover`, `byline`.
- `astro.config.mjs`
  - `site` depuis `APP_SITE_URL`
  - integration `@astrojs/sitemap` avec filtre d’exclusion `/drafts/`.
- `vercel.json`
  - headers sécurité globales (nosniff, X-Frame-Options, Referrer-Policy, Permissions-Policy).

## Composants UI réutilisables (`src/components`)
- `Navbar.astro`
  - navigation principale + ancrages de sections + CTA Google.
  - script d’ouverture du menu mobile (`aria-expanded`).
- `Hero.astro`, `Problem.astro`, `Robots.astro`, `Features.astro`, `Pricing.astro`, `Testimonials.astro`, `FAQ.astro`
  - blocs de conversion/argumentaire.
- `ClosingCta.astro`, `CtaBanner.astro`
  - rappels CTA "Start free / Open App".
- `Footer.astro`
  - liens de trust et routes légales.
