---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "site"
created: "2026-06-12"
created_at: "2026-06-12 13:10:00 UTC"
updated: "2026-06-12"
updated_at: "2026-06-12 12:39:00 UTC"
status: ready
source_skill: 100-sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que lecteur francophone ou anglophone du blog ContentGlowz, je veux accéder à un index, des tags, des articles et des métadonnées cohérents avec la langue réelle du contenu, afin de ne pas naviguer dans un blog mixte avec de faux signaux SEO."
risk_level: "high"
supersedes: []
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "Astro content collections"
  - "Blog list and tag routes"
  - "Blog post layout metadata"
  - "Shared CTA and shell links"
depends_on:
  - artifact: "site/CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/editorial/site/content-map.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/editorial/site/page-intent-map.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/editorial/site/editorial-update-gate.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/editorial/site/claim-register.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/technical/design-system-authority.md"
    artifact_version: "1.0.0"
    required_status: "draft"
evidence:
  - "site/src/pages/blog/index.astro lists published blog posts without locale split while the blog corpus already mixes EN and FR content."
  - "site/src/pages/blog/tag/[tag].astro and src/pages/blog/[...slug].astro inherit the same mixed-locale assumption."
  - "site/src/layouts/BlogPost.astro formats UI chrome in English and receives no explicit locale from content entries."
  - "User decision 2026-06-12: site bilingue fr/en, root=en, continuer avec le reste après les pages coeur."
next_step: "/101-sf-ready shipglows_data/workflow/specs/site/SPEC-bilingual-fr-en-blog-routing-and-locale-metadata-2026-06-12.md"
---

## Title
Implement bilingual `fr/en` routing and locale-aware metadata for the ContentGlowz blog surfaces

## Status
Ready. The next bounded tranche is the blog only: English remains at `/blog`, French moves under `/fr/blog`, and existing mixed-language publishing gets explicit locale handling.

## User Story
En tant que lecteur francophone ou anglophone du blog ContentGlowz, je veux accéder à un index, des tags, des articles et des métadonnées cohérents avec la langue réelle du contenu, afin de ne pas naviguer dans un blog mixte avec de faux signaux SEO.

## Minimal Behavior Contract
Le site publie les articles anglais du blog sous `/blog/...` et les articles français sous `/fr/blog/...`. Les index et pages tag n'affichent que les articles de leur locale. Chaque article rend le bon `lang`, le bon canonical, et n'émet un alternate `hreflang` que lorsqu'une vraie paire EN/FR existe. Les CTA et liens blog partagés ne doivent pas renvoyer un visiteur francophone vers l'index anglais par défaut.

## Scope In
- `site/src/content.config.ts`
- `site/src/content/blog/*.md`
- `site/src/layouts/BlogPost.astro`
- `site/src/pages/blog/index.astro`
- `site/src/pages/blog/tag/[tag].astro`
- `site/src/pages/blog/[...slug].astro`
- nouvelles routes `site/src/pages/fr/blog/**/*.astro`
- helper(s) blog/locale sous `site/src/data`
- composants partagés strictement nécessaires à cette tranche (`CtaBanner`, `ClosingCta`, `siteShell` si impact blog)

## Scope Out
- autres collections (`ai-agents`, `platform`, `seo-strategy`, `startup-journey`, `technical-optimization`, `tutorials`)
- traduction de nouveaux articles EN<->FR absents
- regroupement cross-collection des routes `/fr/...` hors blog
- 404 et design playground

## Test Contract
- `npm run build`
- vérifier `dist/blog/**` et `dist/fr/blog/**`
- inspecter HTML généré pour un article EN, un article FR, un index EN, un index FR
- vérifier qu'un index/tag EN n'inclut pas de post FR publié, et inversement

## Implementation Tasks
- [ ] ajouter un champ `locale` au contrat de contenu et annoter les articles blog publiés
- [ ] extraire des helpers de filtrage/formatting blog par locale
- [ ] créer `/fr/blog`, `/fr/blog/tag/[tag]`, `/fr/blog/[...slug]`
- [ ] rendre `BlogPost.astro` locale-aware pour breadcrumbs, dates, labels, CTA, canonical et `lang`
- [ ] corriger les liens blog partagés sur les surfaces FR concernées
- [ ] valider le build et la sortie statique

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-06-12 12:39:00 UTC | 001-sf-build | GPT-5 Codex | Implemented, verified, closed, and shipped bilingual blog routing with locale-aware content filtering, metadata, and shared blog links/CTAs. | shipped | /405-sf-prod site |

## Current Chantier Flow

100-sf-spec done -> 101-sf-ready ready -> 102-sf-start done -> 103-sf-verify done -> 104-sf-end integrated-via-001 -> 005-sf-ship shipped
