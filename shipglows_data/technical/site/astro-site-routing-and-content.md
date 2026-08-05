---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: site
created: "2026-05-06"
updated: "2026-05-06"
status: draft
source_skill: sf-docs
scope: astro-site-routing-and-content
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - astro.config.mjs
  - src/pages/
  - src/layouts/
  - src/components/
  - src/content.config.ts
  - src/content/
  - package.json
depends_on:
  - artifact: "shipglows_data/technical/site/architecture.md"
    artifact_version: "1.0.0"
    required_status: reviewed
  - artifact: "shipglows_data/editorial/site/content-map.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "Astro public site source is present under site/src."
  - "Existing specs cover i18n structure and Astro major migration."
next_review: "2026-06-06"
next_step: "/sf-docs technical audit site"
---

# Technical Module Context: Astro Site Routing And Content

## Purpose

This module covers the ContentGlows Astro site routing, layouts, shared components, runtime content schema, SEO metadata, sitemap behavior, and build validation. Agents should load it before changing public routes, page copy structure, content collection schemas, canonical URLs, language routing, or Vercel-facing build behavior.

## Owned Files

| Path | Role | Edit notes |
| --- | --- | --- |
| `astro.config.mjs` | Astro site configuration | Preserve site URL, integrations, sitemap, and future i18n assumptions. |
| `src/pages/**` | Public routes | Keep route intent, CTA, auth handoff, and SEO behavior aligned with editorial governance. |
| `src/layouts/**` | Shared page/content layout | Preserve metadata, language attributes, canonical URLs, and content rendering. |
| `src/components/**` | Shared public UI | Keep navigation, footer, and CTA behavior consistent across routes. |
| `src/content.config.ts` | Runtime content schema | Do not add ShipGlowz metadata unless the schema explicitly accepts it. |
| `src/content/**` | Runtime Markdown content | Preserve Astro content frontmatter shape. |
| `package.json` | Scripts and dependency contract | Keep build and preview commands current. |

## Entrypoints

- `npm run build`: production static build and route generation.
- `npm run preview`: local preview of the built site when needed.
- `src/pages/**`: Astro route entrypoints.
- `src/content.config.ts`: runtime content schema entrypoint.

## Control Flow

```text
npm run build
  -> astro.config.mjs
  -> src/pages route generation
  -> src/layouts metadata/content wrapping
  -> src/components shared UI
  -> src/content.config.ts validates runtime content
```

## Invariants

- Public routes must keep honest CTAs and app handoff URLs.
- SEO metadata must stay coherent with canonical routes, language state, sitemap, and robots behavior.
- Runtime content frontmatter must match `src/content.config.ts`.
- Public claims must not exceed `shipglows_data/business/business.md`, `shipglows_data/product/site/product.md`, `shipglows_data/branding/branding.md`, `shipglows_data/gtm/site/gtm.md`, verified behavior, or claim-register evidence.

## Failure Modes

- Astro schema drift can break builds or silently drop content.
- Copy or CTA edits can create public claims not supported by product truth.
- i18n or canonical changes can cause duplicate indexing or wrong-language metadata.
- Dependency upgrades can pass locally but alter generated route output.

## Security Notes

- Do not expose private app URLs, secrets, internal logs, or operational deployment details in public pages.
- Auth handoff routes must not imply authentication is handled by the static site itself.
- Privacy, compliance, AI automation, and data-handling claims need evidence before publication.

## Validation

```bash
npm run build
```

Use browser or preview checks when route layout, CTAs, visual hierarchy, or content rendering changes.

## Reader Checklist

- `src/pages/**` changed -> check page intent, CTA, public claims, and route validation.
- `src/layouts/**` changed -> check metadata, canonical, language, and content rendering.
- `src/content.config.ts` or `src/content/**` changed -> check runtime schema policy before adding frontmatter.
- `astro.config.mjs` changed -> check sitemap, site URL, integrations, and deployment assumptions.

## Maintenance Rule

Update this doc when routing, layouts, content schema, public metadata, build commands, or Astro/Vercel assumptions change.
