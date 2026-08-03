---
artifact: technical_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
status: reviewed
project: lab
created: "2026-04-26"
updated: "2026-04-27"
source_skill: sf-docs
scope: context
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - FastAPI
  - Turso/libsql
  - Clerk
  - OpenRouter
  - Exa
  - Firecrawl
  - Project Intelligence generation context
  - SendGrid
  - PM2
  - Doppler
evidence:
  - README.md
  - api/main.py
  - api/auth/clerk.py
  - api/services/user_data_store.py
  - api/services/user_key_store.py
  - api/services/web_auth_handoff_store.py
  - api/services/ai_runtime_service.py
  - scheduler/scheduler_service.py
  - api/services/crypto.py
  - status/db.py
  - requirements.txt
  - ecosystem.config.cjs
  - main.py
  - run_seo_tools.sh
depends_on:
  - shipglows_data/business/business.md
  - shipglows_data/branding/branding.md
  - shipglows_data/technical/lab/guidelines.md
supersedes: []
next_step: /sf-docs audit shipglows_data/technical/lab/context.md
---

# shipglows_data/technical/lab/context.md

## What `lab` is

`lab` is a FastAPI backend that serves ContentGlowz client surfaces and orchestrates AI-driven content workflows.
It combines:

- REST + WebSocket endpoints in `api/`
- AI pipelines and tool integrations in `agents/`
- Project Intelligence generation context in `api/services/project_generation_context.py`
- persistent scheduling/status orchestration in `scheduler/`, `status/`, and `api/services/`
- support utilities in `utils/`
- behavioral contracts and test coverage in `tests/`
- operational specs in `shipglows_data/workflow/specs/lab/`

## Runtime model

- Entry point:
  - `main.py` launches `uvicorn` with `api.main:app`
  - `api/main.py` defines app initialization and lifespan

- API lifecycle (`api/main.py`):
  - adds global CORS, rate limiting, and error handler middleware
  - registers domain routers with `/api/...` prefixes
  - starts scheduler task during startup (`scheduler/scheduler_service.py`)
  - ensures required tables/services via idempotent startup migrations

- Authentication:
  - Clerk JWT validation and bearer protection in `api/auth/clerk.py` and `api/dependencies/auth.py`
  - optional Clerk webhooks in `api/routers/auth_web.py` for user lifecycle events

- Persistence strategy:
  - user/project/workflow settings and credentials in Turso/libSQL
  - status/job/audit tables in status subsystem
  - explicit startup checks with `ensure_*` helpers before handling traffic

- AI runtime:
  - runtime services are provided lazily and guarded by mode/credential checks (`api/services/ai_runtime_service.py`)
  - BYOK and platform modes are enforced per request, route and provider.

- Generation context:
  - relational Project Intelligence rows are canonical for project knowledge
  - newsletter and psychology generation receive bounded, tenant-scoped context from `api/services/project_generation_context.py`
  - context logs and generation signals are created by `ProjectIntelligenceStore.ensure_tables()`
  - no separate runtime project-memory package is installed; `chromadb` may remain only as a CrewAI transitive residual

- Background execution:
  - `scheduler/scheduler_service.py` dispatches due jobs and updates job status transitions
  - scheduled jobs can generate newsletter/content/research/social content and refresh statuses via status services

## Environment and deployment context

- Required operational envs are documented in `.env.example` and deploy manifests.
- Render and PM2-based flows exist for process/runtime packaging.
- `DOPPLER`-style secret delivery is expected for production workflows in repo instructions.

## Operational boundaries

- This backend is consumed by at least:
  - Flutter app (`app`)
  - downstream web/chat surfaces in the wider ContentGlowz ecosystem
- Any contract change touching auth, payload shape, IDs, job semantics, or migration strategy must be coordinated with related consumers before rollout.
