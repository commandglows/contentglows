---
artifact: code_docs_map
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: worker
created: "2026-06-29"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: code-docs-map
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - worker/server/
  - worker/remotion/
  - worker/package.json
depends_on:
  - artifact: "shipglows_data/technical/worker/architecture.md"
    artifact_version: "1.0.0"
    required_status: reviewed
  - artifact: "shipglows_data/technical/worker/runtime-and-render-api.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "Baseline worker map created during monorepo documentation normalization."
next_review: "2026-09-29"
next_step: "/sf-docs technical audit worker"
---

# Code Docs Map

Use this map before editing Remotion worker runtime, render storage, token-protected API routes, or composition contracts.

| Code path | Primary doc | Coverage | Reader trigger |
| --- | --- | --- | --- |
| `worker/server/**` | `shipglows_data/technical/worker/runtime-and-render-api.md` | Express runtime, auth token checks, route contract, storage, retention, and artifact metadata rules | Any worker API, auth, retention, queue, or storage behavior change |
| `worker/remotion/**` | `shipglows_data/technical/worker/runtime-and-render-api.md` | Composition IDs, timeline props, metadata expectations, and local smoke-render contract | Any composition, timeline props, format, or render-schema change |
| `worker/package.json` / `worker/pnpm-lock.yaml` | `shipglows_data/technical/worker/architecture.md` | Runtime scripts and dependency contract | Any Remotion, Express, TypeScript, or build dependency change |
| `worker/Dockerfile` / `worker/ecosystem.config.cjs` / `worker/DEPLOYMENT.md` | `shipglows_data/technical/worker/architecture.md` | Deployment shape, service boundary, and runtime environment expectations | Any deployment, process manager, or container contract change |

## Documentation Update Plan Format

```text
Documentation Update Plan:
- Status: complete | no impact | pending final integration | blocked
- Impacted docs:
  - shipglows_data/technical/worker/<doc>.md: <required update or no change>
- Reason:
  - <why the docs are or are not current>
```

## Maintenance Rule

Update this map when covered files move, new worker subsystems are introduced, or validation responsibilities change.
