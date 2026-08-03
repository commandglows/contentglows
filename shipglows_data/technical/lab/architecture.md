---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
status: reviewed
project: lab
created: "2026-04-26"
updated: "2026-07-13"
source_skill: sf-docs
scope: architecture
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
external_dependencies:
  - SendGrid
  - Gmail IMAP
  - Doppler
  - PM2
  - Render
  - Clerk JWKS endpoint
  - OpenRouter API
  - Exa
  - Firecrawl
  - DataForSEO/SERP APIs
linked_systems:
  - FastAPI
  - Turso/libsql
  - Amazon S3
  - Clerk
  - CrewAI
  - PydanticAI
  - OpenRouter
  - OpenAI-compatible providers
  - Render
evidence:
  - api/main.py
  - api/dependencies/auth.py
  - api/dependencies/agents.py
  - api/routers
  - api/services
  - scheduler/scheduler_service.py
  - status/service.py
  - status/db.py
  - requirements.txt
  - ecosystem.config.cjs
  - .env.example
depends_on:
  - shipglows_data/technical/lab/context.md
  - shipglows_data/technical/lab/context-function-tree.md
  - shipglows_data/business/business.md
  - shipglows_data/technical/lab/guidelines.md
supersedes: []
next_review: "2026-07-26"
next_step: /sf-docs audit shipglows_data/technical/lab/architecture.md
---

# shipglows_data/technical/lab/architecture.md

## High-level architecture

```text
Client surfaces
  ├─ Flutter / web consumers
  └─ Internal tooling
        │
        ▼
  FastAPI app (api/main.py)
        │
        ├─ REST + WebSocket endpoints (api/routers)
        │     ├─ auth + ownership guards
        │     ├─ analytics/research/content/project routes
        │     └─ scheduler + feedback/job routes
        ├─ Dependency providers (api/dependencies)
        │     ├─ Clerk user context
        │     └─ Lazy AI agent loaders
        └─ Service layer (api/services)
              ├─ Turso-backed stores
              │     ├─ user settings/project metadata
              │     ├─ credentials
              │     ├─ jobs/status
              │     └─ feedback
              ├─ video source intake
              │     ├─ revisioned folder/source state in Turso/libSQL
              │     ├─ private canonical media in Amazon S3
              │     └─ provider-neutral storage and preview ports
              ├─ agent/runtime services
              │     ├─ AI runtime selector
              │     └─ provider secret handling
              └─ external integrations (OpenRouter/EXA/Firecrawl/etc.)
                    │
                    ▼
               Agent modules (agents/*)
                    │
                    ▼
             Scheduler + status subsystem
                    │
                    ├─ scheduler/scheduler_service.py (60s loop)
                    ├─ status service (content lifecycle + transitions)
                    └─ durable storage in Turso/libSQL
```

## Layer breakdown

- **Presentation boundary (HTTP/WebSocket)**
  - `api/routers/*` expose route contracts and response models.
  - `api/main.py` centralizes middleware and app-wide behavior.

- **Application layer (composition + policy)**
  - `api/dependencies/*` implements auth ownership and provider injection.
  - `api/services/*` contains domain orchestration and external API integration logic.
  - `api/services/email_source_service.py` stores per-user IMAP email-source metadata in `UserSettings.robotSettings.emailSource` and the app password in encrypted `UserProviderCredential`.

- **Agent/domain service layer**
  - `agents/*` host the CrewAI/PydanticAI pipelines.
  - Heavy imports are deferred using `lru_cache` providers to protect startup latency.
  - Newsletter inbox ingestion reads a user-configured IMAP folder, extracts ideas, writes them to the Idea Pool with user/project ownership, and archives processed messages to the configured folder when possible.
  - Historical local README files under `lab/agents/*` are migration façades only; durable workflow documentation belongs in `shipglows_data/technical/lab/agent-pipelines.md` and this architecture file.

- **Persistence layer**
  - User/project/security-critical state is persisted to Turso (`libsql`).
  - Status lifecycle uses local adapters with migration-safe schema bootstrapping.
  - Binary video-source originals are private, versioned S3 objects. Domain rows persist only a provider-neutral locator (`provider`, `namespace`, opaque object key, version, checksum), never a durable URL.
  - Upload-session provider state remains backend-only. Multipart URLs are signed per part only after the backend validates its expected number and size and binds its SHA-256 checksum.

## Video source intake boundary

- `Sources prêtes` records the exact ready revision and never dispatches generation.
- `Générer la vidéo` records the same readiness boundary, then emits one idempotent ids-only handoff. Generation, editing and rendering execute outside this intake surface.
- Images, MP4 video and supported audio enter a quarantine namespace, are decoded/inspected, stripped of private metadata, then written to the canonical `assets` namespace. Persistence failures trigger deletion compensation.
- Validated images also produce a bounded WebP thumbnail as a distinct derived asset/usage in S3. Video and audio use safe technical-metadata fallbacks until dedicated internal thumbnail/waveform generators are enabled; preview failure never rewrites or invalidates the original.
- Text is normalized and hashed through Project Intelligence primitives. Public links are revalidated on every redirect to prevent SSRF and only bounded, safe metadata is stored.
- Removing or replacing a source soft-deletes only its `video_source_folder` usage. The canonical asset remains governed by Unified Project Asset Library retention and other usages.
- `ObjectStorageProvider`, `MediaDeliveryProvider` and `MediaPreviewProvider` isolate provider-specific behavior. S3 is the only enabled canonical provider in V1.
- Bunny Optimizer or Stream may later implement preview delivery after latency/cost evidence demonstrates value. Bunny is disabled for this flow today: no source duplication and no Bunny credential is required.

### S3 operational requirements

- Private bucket with S3 Block Public Access enabled and Object Ownership set to bucket-owner-enforced.
- Versioning and default encryption enabled (`AES256` by default, optional KMS key).
- Runtime IAM role limited to the configured prefix and required multipart/read/delete/version operations; no credentials in Flutter.
- Lifecycle rules abort incomplete multipart uploads and expire quarantine objects after the agreed repair window, while canonical retention follows asset-library policy.
- CORS allows only trusted app origins and `PUT`, and exposes `ETag` plus `x-amz-checksum-sha256`; it must not make objects public.

- **Background processing**
  - In-process scheduler (`scheduler/scheduler_service.py`) executes periodic jobs and updates state transitions.
  - Jobs can invoke newsletter/SEO/social pipeline steps.
  - Some historical subsystems were documented as "agents" even when they behave as deterministic pipelines; architecture decisions should follow current code behavior, not legacy naming.

## External dependencies and boundaries

- **Clerk**
  - JWT auth validation for protected routes.
  - Webhook verification for user events (`api/routers/auth_web.py`).

- **AI/Research providers**
  - OpenRouter (primary LLM path) and provider-specific integrations managed by runtime mode + credential model.
  - Search/ crawler integrations (EXA, Firecrawl, dataforSEO, SERP, etc.) used by agent tools.

- **Email and productivity integrations**
  - SendGrid for outbound mail.
  - IMAP is the sole Gmail/newsletter intake path; no managed email-integration SDK is part of the runtime.
  - Per-user email source settings store non-secret IMAP metadata in `UserSettings.robotSettings.emailSource` and the app password in encrypted `UserProviderCredential`.
  - Saving an email source creates/updates a managed `ingest_newsletters` scheduler job. The job runs every 6 hours, reads the configured folder with the user's IMAP credentials, creates `newsletter_inbox` ideas for the configured project, and moves processed emails to the archive folder when IMAP supports it.

## Constraints and invariants

- Keep startup non-breaking:
  - scheduler startup and DB ensure calls must degrade gracefully on partial failure.
- Keep migrations additive:
  - add tables/columns with idempotent checks and startup safety.
- Keep auth consistent:
  - never bypass `require_current_user` for routes that expose user-owned data.
- Preserve request accountability:
  - ownership checks must remain for cross-project/resource access.
