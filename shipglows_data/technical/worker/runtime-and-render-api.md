---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: worker
created: "2026-06-29"
updated: "2026-06-29"
status: reviewed
source_skill: sf-docs
scope: runtime-and-render-api
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - worker/server/index.ts
  - worker/server/render-storage.ts
  - worker/remotion/index.ts
  - worker/remotion/timeline-smoke-props.json
  - worker/DEPLOYMENT.md
  - lab
depends_on:
  - artifact: "shipglows_data/technical/worker/architecture.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "worker/README.md"
  - "worker/DEPLOYMENT.md"
  - "worker/server/index.ts"
  - "worker/server/render-storage.ts"
next_review: "2026-09-29"
next_step: "/sf-docs technical audit worker"
---

# Runtime And Render API

## Purpose

Preserve the operational runtime contract, protected render API, and artifact storage rules for the internal `worker` service.

## Owned Files

- `worker/server/index.ts`
- `worker/server/render-storage.ts`
- `worker/remotion/index.ts`
- `worker/remotion/timeline-smoke-props.json`
- `worker/DEPLOYMENT.md`

## Runtime Environment

- `PORT`: optional, default `3210`
- `REMOTION_WORKER_TOKEN`: required bearer token for protected routes
- `CONTENTGLOWS_RENDER_DIR`: local render root, defaults to `./renders`
- `CONTENTGLOWS_RENDER_STORAGE`: `local` or `gcs`, defaults to `local`
- `GCS_RENDER_BUCKET`: required when `CONTENTGLOWS_RENDER_STORAGE=gcs`
- `GCS_RENDER_PREFIX`: optional object prefix, default `renders`
- `RENDER_ARTIFACT_RETENTION_DAYS`: optional, default `30`
- `REMOTION_SERVE_URL`: optional prebuilt Remotion bundle URL

Production deployment expectations for Cloud Run and GCS remain in `worker/DEPLOYMENT.md`. `lab` is the public auth boundary and owns signed playback URLs.

## Entrypoints

- `npm run dev`
- `npm run start`
- `npm run lint`
- `npm run test:storage`
- `npm run test:timeline`
- `npm run remotion:studio`

## API Contract

Protected endpoints require:

`Authorization: Bearer <REMOTION_WORKER_TOKEN>`

### `GET /health`

- Unauthenticated for probes
- Returns service health, storage provider, resolved render root, retention days, and active serve URL

### `POST /renders`

Creates a render job.

Required request fields:

- `jobId`: safe server-visible identifier, later used in artifact names
- `renderMode`: `preview` or `final`
- `durationSeconds`: bounded by the worker timeline limit
- `inputProps`: server-resolved Remotion props payload

Optional request fields:

- `templateId`
- `compositionId`

Timeline expectations:

- `ContentGlowsTimelineVideo` supports `vertical_9_16` (`1080x1920`) and `landscape_16_9` (`1920x1080`) at `30fps`
- composition metadata is derived from `inputProps.format`
- timeline renders should receive resolved `assets[asset_id].render_url` values from `lab`
- missing media asset URLs render a neutral visual placeholder instead of crashing local composition development

### `GET /renders/:workerJobId`

Returns job status, progress, timestamps, and artifact metadata when completed.

### `DELETE /renders/:workerJobId`

Cancels a queued or in-progress job.

## Artifact Storage Contract

Local mode:

- outputs are worker-generated and path-safe
- preview path: `previews/{jobId}.mp4`
- final path: `finals/{jobId}.mp4`
- path traversal attempts are rejected
- cleanup runs on startup and daily

GCS mode:

- requires `CONTENTGLOWS_RENDER_STORAGE=gcs`
- requires `GCS_RENDER_BUCKET`
- preview object: `{GCS_RENDER_PREFIX}/previews/{jobId}.mp4`
- final object: `{GCS_RENDER_PREFIX}/finals/{jobId}.mp4`
- startup fails closed if GCS mode is selected without a bucket
- worker returns storage metadata only, never a browser playback URL

Retention metadata:

- `retentionExpiresAt`: defaults to 30 days after completion
- `deletionWarningAt`: 72 hours before retention expiry

## Validation

- `npm run lint`
- `npm run test:storage`
- `npm run test:timeline`
- `npx remotion render remotion/index.ts ContentGlowsTimelineVideo /tmp/contentglows-timeline-smoke.mp4 --props=remotion/timeline-smoke-props.json --overwrite`

The smoke render uses text/background-only props so it validates the Remotion runtime and H.264 output path without depending on network media assets.

## Reader Checklist

- Read this file before changing worker env vars, protected routes, render request payloads, or artifact retention behavior.
- Cross-check any production-storage or signed-URL change with `lab`, because the worker is not the public artifact delivery surface.

## Maintenance Rule

Keep runtime, API, and storage truth here. If the local `worker/README.md` needs more detail than an entrypoint, move that detail into this file or `architecture.md` instead of rebuilding a second local source of truth.
