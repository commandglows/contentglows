---
artifact: technical_context
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: site
created: "2026-04-26"
updated: "2026-06-30"
status: reviewed
source_skill: sf-docs
scope: technique
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: low
docs_impact: yes
depends_on:
  - AGENT.md@1.0.0
  - shipglows_data/business/business.md@0.1.0
  - shipglows_data/branding/branding.md@0.1.0
  - shipglows_data/technical/site/guidelines.md@1.0.0
  - README.md@0.1.0
evidence:
  - src/pages
  - src/layouts
  - src/components
  - src/content
  - src/content.config.ts
  - src/config/site.ts
  - astro.config.mjs
  - vercel.json
supersedes: []
next_review: "2026-07-26"
next_step: /sf-docs update shipglows_data/technical/site/context.md
---

# shipglows_data/technical/site/context.md — site

## Contexte produit
`site` est la surface web publique de ContentGlowz : landing page, pages éditoriales (`blog`, `seo-strategy`, `technical-optimization`, etc.), privacy page et pages de point d’entrée vers l’app officielle.

Le site assure:
- la découverte produit,
- la variante localisée du coeur de tunnel public (`/fr`, `/fr/sign-in`, `/fr/sign-up`, `/fr/launch`, `/fr/privacy`),
- la communication des limites (notamment dégradation backend),
- la redirection fluide vers le tunnel d’auth et d’ouverture de l’app (`app.contentglowz.com`).

## Empilement technique
- **Framework**: Astro.
- **Runtime de build**: Node.js (`astro build`, `astro dev`, `astro preview`).
- **Langage**: TypeScript + Astro components.
- **Rendu**: pages SSG via `getStaticPaths` et `getCollection`.
- **Moteur de contenu**: markdown collections `astro:content`.

## Architecture logique (résumée)
1. Les routes d’entrée (`src/pages`) composent les pages avec des layouts et composants.
2. Les collections Markdown (`src/content.config.ts`) fournissent des métadonnées normalisées et un schéma commun.
3. `Layout.astro` applique la couche SEO générale (meta, canonical, JSON-LD, Open Graph/Twitter).
4. `BlogPost.astro` applique la présentation d’article avancée (ToC, temps de lecture, relations entre posts).
5. `src/config/site.ts` centralise les URLs et paramètres de build pour la cohérence des liens de handoff.
6. `astro.config.mjs` pilote le domaine/site et l’intégration Sitemap.

## Domaines de responsabilité
- **Pages marketing / conversion**: `index`, `privacy`, sections hero/FAQ/pricing/témoignages.
- **Pages marketing localisées**: `fr/index`, `fr/privacy` et variantes handoff `fr/sign-in`, `fr/sign-up`, `fr/launch`.
- **Documentation éditoriale**: `blog`, `platform`, `ai-agents`, `seo-strategy`, `startup-journey`, `technical-optimization`, `tutorials`.
- **Blog localisé**: `fr/blog`, `fr/blog/[...slug]`, `fr/blog/tag/[tag]`.
- **Handoff app/auth**: `sign-in`, `sign-up`, `launch`.
- **SEO opérationnel**: `robots.txt.ts` + sitemap via integration Astro.
- **Configuration runtime**: URLs du site, cible d’application, métadonnées de build.

## Variables et dépendances
- `APP_SITE_URL`: source de vérité pour URL canonical/site.
- `APP_WEB_URL`: racine de l’application de destination (`/sign-in`, `/#/entry`).
- `API_BASE_URL`: endpoint public de référence exposé dans `src/config/site.ts`.
- `POLAR_CREATOR_CHECKOUT_URL`, `POLAR_PRO_CHECKOUT_URL`: overrides checkout optionnels, sinon fallback sur `appSignInUrl?plan=...`.
- `VERCEL_GIT_COMMIT_SHA`, `VERCEL_ENV`, `BUILD_TIMESTAMP`: metadata d’observabilité.
- `import.meta.env.PROD`: garde d’activation du script analytics dans `Layout.astro`.

## Contraintes
- Les routes d’authentification du site sont **devenues des pages de redirection**, pas de gestion d’identité.
- `/sign-in` et `/sign-up` propagent `redirect_url` quand le paramètre est présent.
- Les pages handoff (`sign-in`, `sign-up`, `launch` et variantes `fr`) restent `noindex`.
- Les promesses produits doivent rester compatibles avec ce qui est réellement exposé par l’écosystème app/backend.
- Le messaging de résilience doit rester cohérent: backend indisponible = app encore accessible après authentification, lectures cache possibles, actions supportées mises en file locale puis rejouées.
- Tout ajout de collection, de route dynamique, ou de CTA de conversion doit être répercuté sur les docs d’architecture et de contexte.

## Contexte de déploiement
- Déploiement prévu sur Vercel avec support du site statique Astro et headers de sécurité.
- Les builds Vercel sont épinglés sur `npm@11.12.1` via `vercel.json`.
- `astro.config.mjs` et `vercel.json` sont les points centraux à faire évoluer si les domaines/champs SEO changent.
