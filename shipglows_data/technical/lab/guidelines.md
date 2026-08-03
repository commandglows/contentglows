---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: lab
created: "2026-04-25"
updated: "2026-07-12"
status: reviewed
source_skill: sf-docs
scope: guidelines
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - .github/dependabot.yml
  - lab/requirements.txt
  - lab/requirements-dev.txt
  - lab/requirements.lock
  - lab/requirements-dev.lock
depends_on: []
supersedes: []
evidence:
  - CLAUDE.md
  - shipglows_data/business/business.md
  - shipglows_data/branding/branding.md
next_review: "2026-07-26"
next_step: /sf-docs audit shipglows_data/technical/lab/guidelines.md
---
# Development Guidelines

## Scope

Backend/API conventions for `lab`.

## Stack

- Python 3.11+
- FastAPI
- Pydantic / PydanticAI / CrewAI
- Scheduler + job orchestration
- SQLite/Turso persistence layer
- Doppler for secrets, Flox for reproducible env

## API Rules

1. Keep domain boundaries clear in `api/routers`.
2. Use Pydantic models for public request/response boundaries.
3. Protect sensitive endpoints with auth dependencies.
4. Keep startup initialization idempotent and explicit in logs.
5. Document or update endpoint effects in `CHANGELOG.md` when contract changes.

## Data and Migration Rules

- Avoid destructive DB changes in hot code paths.
- Add new tables/columns via migration-safe paths with clear fallback behavior.
- Ensure background services handle transient failures without taking down the app.
- Keep scheduler jobs deterministic and easy to retry.

## Observability Rules

- Return consistent status semantics (`ok`, `error`, `details`, `request_id` where applicable).
- Keep failures observable (logs + status endpoints + structured events).
- Ensure cost/status tracking surfaces exist for long-running AI jobs.

## Release Hygiene

- When adding new endpoints:
  - update `api/` router registration,
  - update env/deployment docs (`ENVIRONMENT_shipglows_data/technical/SETUP.md`, `README.md`),
  - include migration impact in `CHANGELOG.md`.
- If contract changes affect `app`, flag compatibility considerations immediately in notes.

## Backend Dependency Review Policy

- Dependabot checks Python manifests in `/lab` weekly. Its pull requests are review inputs, not automatic approval to change the production dependency graph.
- Keep direct dependency ranges in `requirements.txt` and development-only inputs in `requirements-dev.txt`; production and local validation continue to install the checked-in lockfiles.
- Regenerate `requirements.lock` and `requirements-dev.lock` together on Python 3.12 whenever an accepted update changes resolution. Do not merge a manifest-only update when the resolved lockfiles would remain stale.
- Review release notes and resolver changes for FastAPI, Pydantic/PydanticAI, CrewAI/LiteLLM, auth, storage, database, and cryptography dependencies before accepting an update.
- Require `tests/test_dependency_policy.py`, the relevant targeted tests, and `python3 -m pip_audit -r requirements.lock --no-deps --disable-pip` to pass before merge. Run the full backend suite for framework, resolver, or transitive graph changes.
- Keep optional or conflicting integrations isolated. In particular, do not reintroduce Mem0 or Composio into the default runtime, and do not treat CrewAI's transitive ChromaDB dependency as project-memory storage, without a dedicated review.
