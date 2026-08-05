---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.3.0"
project: app
created: "2026-04-26"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: technical
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: none
docs_impact: yes
evidence:
  - "shipglows_data/technical/app/README.md"
  - "shipglows_data/technical/app/architecture.md"
depends_on:
  - shipglows_data/technical/app/guidelines.md
supersedes: []
linked_systems:
  - Flutter
  - Clerk
  - FastAPI
next_review: "2026-09-29"
next_step: /sf-docs audit CLAUDE.md
---

# CLAUDE.md

## Project Overview

`app` is the Flutter product application for ContentGlows.

## Canonical References

- `shipglows_data/technical/app/README.md`
- `shipglows_data/technical/app/architecture.md`
- `shipglows_data/technical/app/context.md`
- `shipglows_data/workflow/app/TASKS.md`
- `shipglows_data/workflow/app/AUDIT_LOG.md`

## Common Commands

```bash
./build.sh --serve
./pm2-web.sh
./scripts/validate-clerk-runtime.sh
```

## Operating Rules

- Keep local docs short and defer durable truth to `shipglows_data`.
- Update canonical docs when routing, auth, offline replay, publish, capture, or API contract behavior changes.
- Before manual QA, run the strongest local Flutter checks that match the changed surface.
