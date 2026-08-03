---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: lab
created: "2026-04-26"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: technical
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
evidence:
  - README.md
  - shipglows_data/technical/lab/README.md
  - shipglows_data/technical/lab/architecture.md
depends_on: []
supersedes: []
linked_systems:
  - FastAPI
  - Turso/libsql
  - Clerk
  - OpenRouter
  - Exa
  - Firecrawl
  - SendGrid
  - Doppler
next_review: "2026-09-29"
next_step: /sf-docs audit CLAUDE.md
---

# CLAUDE.md

## Project Overview

`lab` is the production-oriented backend platform for the ContentGlowz ecosystem.

## Canonical References

- `shipglows_data/technical/lab/README.md`
- `shipglows_data/technical/lab/context.md`
- `shipglows_data/technical/lab/architecture.md`
- `shipglows_data/technical/lab/guidelines.md`

## Common Commands

```bash
pip install -r requirements.lock
pip install -r requirements-memory.txt  # optional semantic memory features only
doppler run -- uvicorn api.main:app --reload --port 8000
curl http://localhost:8000/health
```

## Backend Focus

- Preserve authenticated contracts consumed by `app`.
- Keep Turso/libSQL schema changes explicit and documented.
- Update canonical `shipglows_data` docs when backend behavior changes.

## Forbidden Paths

- `/home/claude/contentglowz/lab_deploy`
- PM2 or other live process control from this repo context
