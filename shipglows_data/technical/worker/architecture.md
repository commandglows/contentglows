---
artifact: architecture_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: worker
created: "2026-06-29"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: architecture
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
depends_on:
  - shipglows_data/technical/worker/README.md
  - shipglows_data/technical/worker/code-docs-map.md
evidence:
  - worker/README.md
  - worker/package.json
  - worker/server/index.ts
  - worker/server/render-storage.ts
  - worker/remotion/index.ts
  - worker/remotion/ContentGlowzTimelineVideo.tsx
linked_systems:
  - Remotion
  - Express
  - TypeScript
  - Google Cloud Storage
  - lab
external_dependencies:
  - Remotion runtime
  - Google Cloud Run
  - Google Cloud Storage
invariants:
  - Protected worker endpoints require a bearer token.
  - Artifact URLs are not the worker's public contract in GCS mode.
  - Timeline/render props must stay aligned with lab-owned version contracts.
supersedes: []
next_review: "2026-09-29"
next_step: "/sf-docs technical audit worker"
---

# shipglows_data/technical/worker/architecture.md

## Purpose

Document the durable architecture contract for the internal Remotion render worker used by `lab`.

## Owned Files

- `worker/server/**`
- `worker/remotion/**`
- `worker/package.json`
- `worker/Dockerfile`
- `worker/ecosystem.config.cjs`
- `worker/DEPLOYMENT.md`

## Entrypoints

- `npm run dev`
- `npm run start`
- `npm run lint`
- `npm run test:storage`
- `npm run test:timeline`
- `npm run remotion:studio`

## High-level architecture

```text
lab video timeline/version contract
        |
        v
token-protected worker API (Express)
        |
        +--> Remotion composition + metadata resolution
        +--> local or GCS artifact storage
        +--> retention metadata + cleanup lifecycle
```

The worker is an internal rendering service, not a public product surface. `lab` owns timeline validation, user ownership checks, and signed playback URLs. The worker owns render execution and artifact persistence metadata only.

## Invariants

- Protected endpoints require `Authorization: Bearer <REMOTION_WORKER_TOKEN>`.
- `GET /health` may stay unauthenticated for probes.
- Storage mode is explicit: `local` or `gcs`.
- In GCS mode, the worker returns storage metadata, not public playback URLs.
- Composition and timeline contracts must stay aligned with the server-resolved props produced by `lab`.
- Retention and cleanup behavior must stay bounded and deterministic.

## Validation

- `npm run lint`
- `npm run test:storage`
- `npm run test:timeline`
- optional local smoke render using the documented timeline smoke props

## Reader Checklist

- Read this file before changing worker auth, render routes, storage mode, artifact retention, or Remotion composition contracts.
- Cross-check any timeline contract change with `lab` technical docs before treating the worker as source of truth.

## Maintenance Rule

Keep durable worker architecture here. The local `worker/README.md` should remain a lightweight entrypoint, not the primary technical authority.
