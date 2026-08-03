---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: lab
created: "2026-06-29"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: architecture
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: no
docs_impact: yes
linked_systems:
  - agents/
  - scheduler/
  - FastAPI
  - CrewAI
  - PydanticAI
evidence:
  - lab/agents/seo/README.md
  - lab/agents/scheduler/README.md
  - shipglows_data/technical/lab/architecture.md
  - agents/
depends_on:
  - shipglows_data/technical/lab/architecture.md
  - shipglows_data/technical/lab/context.md
supersedes: []
next_review: "2026-09-29"
next_step: /sf-docs technical audit lab
---

# Agent Pipelines

## Purpose

Capture the durable documentation boundary for historical `agents/*` local READMEs that were previously acting as pseudo-canonical architecture docs.

## Owned Files

- `agents/seo/`
- `agents/scheduler/`
- related pipeline entrypoints under `agents/`

## Entrypoints

- backend route and service calls that dispatch SEO or scheduler workflows
- module imports under `agents/seo/*` and `agents/scheduler/*`

## Invariants

- Canonical architecture truth belongs in `shipglows_data/technical/lab/architecture.md` and related technical docs, not in long local feature READMEs under `lab/agents/*`.
- Historical claims about agent counts, specific models, phases, or completion status are unstable and must be treated as migration input unless proven by current code.
- Scheduler and image subsystems may be deterministic pipelines even when older docs describe them as "agents". Prefer current code semantics over historical naming.

## Validation

- When workflow architecture changes, update `shipglows_data/technical/lab/architecture.md` first.
- Reduce local `agents/*/README.md` files to lightweight pointers unless they are required by a runtime or packaging contract.
- Avoid copy-pasting capability matrices into multiple files.

## Reader Checklist

- Read this file when a task touches agent orchestration docs or historical agent READMEs.
- Cross-check with `shipglows_data/technical/lab/architecture.md` before trusting older prose.

## Maintenance Rule

Keep durable workflow documentation in `shipglows_data/technical/lab/`. Local README files under `agents/` should remain compatibility façades only.
