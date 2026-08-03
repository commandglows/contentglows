---
artifact: technical_docs_index
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: worker
created: "2026-06-29"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: technical-docs
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - worker/server/
  - worker/remotion/
  - worker/package.json
depends_on: []
supersedes: []
evidence:
  - "worker/README.md"
  - "worker/package.json"
  - "worker/server/index.ts"
  - "worker/remotion/index.ts"
next_review: "2026-09-29"
next_step: "/sf-docs technical audit worker"
---

# Technical Docs

This directory maps the durable technical context for the `worker` Remotion render service.

Start with `code-docs-map.md`. Load only the mapped module context for the files being changed.

## Current Coverage

- `architecture.md`: Remotion worker runtime, token-protected render API, storage modes, and deployment boundary.
- `runtime-and-render-api.md`: environment contract, route-level API expectations, storage/retention rules, and smoke-render validation.

## Maintenance Rule

Update this index and `code-docs-map.md` when a new worker subsystem gets a technical module context or when mapped files move.
