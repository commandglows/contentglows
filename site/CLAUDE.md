---
artifact: project_context
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: site
created: "2026-04-26"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: operations
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: low
docs_impact: yes
depends_on:
  - shipglows_data/business/business.md
  - shipglows_data/branding/branding.md
  - shipglows_data/technical/site/guidelines.md
evidence:
  - README.md
  - shipglows_data/technical/site/README.md
  - shipglows_data/editorial/site/README.md
supersedes: []
next_review: "2026-09-29"
next_step: /sf-docs audit CLAUDE.md
---

# CLAUDE.md

## Project Overview

`site` is the public Astro surface for ContentGlows.

## Canonical References

- `shipglows_data/technical/site/README.md`
- `shipglows_data/technical/site/architecture.md`
- `shipglows_data/editorial/site/README.md`
- `shipglows_data/workflow/site/TASKS.md`

## Common Commands

```bash
npm install
npm run dev
npm run build
npm run preview
```

## Operating Rules

- Keep public messaging grounded in what this repo actually renders.
- Keep French copy in informal address with proper accents.
- Update canonical `shipglows_data` docs when routing, content schema, handoff, or public claims change.
