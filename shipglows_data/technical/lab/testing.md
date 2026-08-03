---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: lab
created: "2026-06-29"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: technical
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: no
docs_impact: yes
linked_systems:
  - pytest
  - FastAPI
  - Turso/libsql
evidence:
  - lab/tests/README.md
  - pytest.ini
  - tests/
  - requirements-dev.lock
depends_on:
  - shipglows_data/technical/lab/README.md
  - shipglows_data/technical/lab/code-docs-map.md
supersedes: []
next_review: "2026-09-29"
next_step: /sf-docs technical audit lab
---

# Testing

## Purpose

Document the durable testing contract for `lab` after migrating stale local test documentation out of `lab/tests/README.md`.

## Owned Files

- `tests/`
- `pytest.ini`
- `requirements-dev.lock`
- local helper scripts that invoke pytest for backend validation

## Entrypoints

- `python -m pytest`
- `uv run --no-project --python 3.12 --with-requirements requirements-dev.lock python -m pytest`

## Invariants

- `lab` testing truth comes from the current test tree and commands, not from historical migration-status prose.
- Claims like pass counts, migration completion, or category coverage must not live in durable docs unless they are regenerated and kept current.
- Live API or provider-dependent checks must be labeled as conditional or optional.

## Validation

- Confirm `pytest.ini` still matches the current test layout.
- Confirm command examples run against the current dependency lockfiles.
- If new durable test categories are introduced, update this file and `shipglows_data/technical/lab/README.md`.

## Reader Checklist

- Read this file before changing test layout, test invocation guidance, or backend validation expectations.
- Prefer code and current test commands over historical summaries.

## Maintenance Rule

Keep this file limited to stable testing contracts. Put execution history in QA trackers, not here.
