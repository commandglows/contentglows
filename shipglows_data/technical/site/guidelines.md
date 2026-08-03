---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: site
created: "2026-04-26"
updated: "2026-06-30"
status: reviewed
source_skill: sf-docs
scope: guidelines
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: none
docs_impact: yes
linked_systems:
  - app
  - lab
evidence:
  - CLAUDE.md
  - shipglows_data/business/business.md
  - shipglows_data/branding/branding.md
depends_on:
  - shipglows_data/business/business.md@1.0.0
  - shipglows_data/branding/branding.md@1.0.0
supersedes: []
next_review: "2026-07-26"
next_step: /sf-docs audit shipglows_data/technical/site/guidelines.md
---
# Development Guidelines

## Scope

This document defines conventions for working on the Astro website in `site`.

## Tech Stack

- Astro
- TypeScript
- Markdown content collections

## Source Layout

- `src/layouts/`: base page/layout composition.
- `src/components/`: reusable UI sections.
- `src/pages/`: routes.
- `src/content/`: editorial assets (blog, tutorials, strategy, startup journey, etc.).
- `astro.config.mjs`: site URL and sitemap settings.
- `src/config/site.ts`: shared runtime config values.

## Environment Variables

- `APP_SITE_URL`: used for site URL fallback/SEO setup.
- `APP_WEB_URL`: public app handoff target.
- `API_BASE_URL`: backend API base URL exposed in `src/config/site.ts`.
- `POLAR_CREATOR_CHECKOUT_URL`, `POLAR_PRO_CHECKOUT_URL`: optional absolute overrides for checkout links.
- `VERCEL_GIT_COMMIT_SHA`, `VERCEL_ENV`, `BUILD_TIMESTAMP`: build telemetry metadata used for observability.

## Content Governance

- Keep public documentation aligned with current product capabilities.
- Do not claim unsupported automation behaviors.
- Ensure auth handoff and CTA language remains stable across landing and pricing pages.
- When editing content that references integrations or handoff, verify against app/backend contract updates.
- In French public copy, keep informal address (`tu`) and proper accents.

## Operational Conventions

- Keep fallback URL/config behavior explicit and non-failing.
- Preserve clarity around degraded/unavailable backend behavior.
- Add or update trust signaling where external dependency state is user-facing.
- Do not reintroduce site-owned authentication logic; the site hands off to the app.
- Keep handoff routes (`/sign-in`, `/sign-up`, `/launch` and `fr/*` variants) `noindex`.
- Preserve the public navigation contract around `/`, `/fr`, `/blog`, `/fr/blog`, `/privacy`, `/#features`, `/#pricing`, and `/#faq`.
- Keep production analytics gated behind `import.meta.env.PROD`.

## Release and Documentation Hygiene

- Update `README.md` and doc pages when navigation or auth handoff flow changes.
- Keep environment expectations in `.env.example` synchronized with `src/config/site.ts` and deployment config.
- For any significant behavior change, update `shipglows_data/branding/branding.md`, `shipglows_data/business/business.md`, and `CLAUDE.md` references.
