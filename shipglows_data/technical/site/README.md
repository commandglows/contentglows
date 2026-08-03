---
artifact: technical_docs_index
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: site
created: "2026-05-06"
updated: "2026-06-30"
status: draft
source_skill: sf-docs
scope: technical-docs
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - src/
  - astro.config.mjs
  - package.json
depends_on: []
supersedes: []
evidence:
  - "site is an Astro public site with pages, layouts, content config, and Vercel deployment config."
next_review: "2026-06-06"
next_step: "/sf-docs technical audit site"
---

# Technical Docs

This directory maps code areas that need durable technical context before future ShipGlowz edits.

Start with `code-docs-map.md`. Load only the mapped module context for the files being changed.

## Current Coverage

- `astro-site-routing-and-content.md`: Astro routing, layouts, public pages, content schema, SEO metadata, sitemap, and build validation.

## Runtime Contract

- Build runtime: Node `>=22 <23`.
- Local validation path: `npm run dev`, `npm run build`, `npm run preview`.
- Production deploy path: Vercel with `npx --yes npm@11.12.1 install` and `npx --yes npm@11.12.1 run build` from `vercel.json`.

## Canonical Technical Anchors

- `context.md`: public-surface role, env contract, handoff boundaries, degraded-mode messaging.
- `context-function-tree.md`: route inventory, localized `fr/*` surfaces, content collection rendering, redirect behavior.
- `architecture.md`: Astro/Vercel build pipeline, SEO/metadata, security headers, analytics activation boundaries.
- `guidelines.md`: editing rules, public-nav invariants, claim hygiene, documentation sync rules.

## Maintenance Rule

Update this index and `code-docs-map.md` when a new site subsystem gets a technical module context or when mapped files move.
