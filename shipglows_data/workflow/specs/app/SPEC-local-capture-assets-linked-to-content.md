---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-05-05"
created_at: "2026-05-05 00:00:00 UTC"
updated: "2026-05-05"
updated_at: "2026-05-05 00:00:00 UTC"
status: active
source_skill: sf-build
source_model: "GPT-5"
scope: feature
owner: "Diane"
confidence: medium
user_story: "En tant que créateur ContentGlows sur Android, je veux rattacher une capture locale à un contenu existant ou à créer, afin de transformer immédiatement un screenshot ou une vidéo d'écran en asset de travail sans upload cloud automatique."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter capture UI"
  - "app local capture storage"
  - "app ApiService/offline content flow"
  - "lab FastAPI status router"
  - "lab Turso/libSQL status schema"
depends_on:
  - artifact: "shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md"
    artifact_version: "1.0.0"
    required_status: active
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Capture V1 stores local metadata in SharedPreferences under capture_recent_assets_v1 and does not link assets to projects or content records."
  - "lab already owns ContentRecord, content_bodies, content_edits, and authenticated project ownership checks."
  - "No backend content_assets table or API exists yet."
next_step: "/sf-test local capture assets linked to content on Android"
---

# Local Capture Assets Linked To Content

## Status

Shipped pending manual Android QA. This chantier extends the Android capture V1 with content attachment and a backend metadata contract. It does not upload local media files to cloud storage in V1.

## User Story

En tant que créateur ContentGlows sur Android, je veux rattacher une capture locale à un contenu existant ou à créer, afin de transformer immédiatement un screenshot ou une vidéo d'écran en asset de travail sans upload cloud automatique.

## Minimal Behavior Contract

When an Android user completes a screenshot or recording, the app keeps the media file local, offers to create a content draft from that capture or attach it to an existing content record in the active project, stores a local asset/content link for device preview, and registers a backend `content_assets` metadata record only when a backend content id exists. The backend contract must never treat a device-local path as durable server truth; V1 stores metadata and a client asset id only, with `storage_uri` nullable for future upload.

## Scope In

- Flutter UI action on local capture cards: create content from capture.
- Flutter UI action on local capture cards: attach capture to an existing pending content item.
- Local link persistence between `CaptureAsset.id` and `ContentItem.id`.
- Backend `content_assets` table and idempotent schema ensure path.
- Authenticated FastAPI endpoints under `/api/status/content/{content_id}/assets`.
- Backend asset metadata fields for source, kind, mime type, dimensions, duration, byte size, client asset id, status, and future nullable `storage_uri`.
- App API methods to create a manual content draft from a capture and attach capture metadata to a content record.
- Documentation and changelog updates for local-only behavior and backend contract.

## Scope Out

- Uploading PNG/MP4 bytes to the backend.
- Cloud storage buckets, signed uploads, CDN delivery, retention policy, billing, or transcoding.
- Web screen capture parity.
- Gallery export or media library sync.
- AI analysis of captured media.
- Publishing an attached local asset to social channels.

## Invariants

- Completed media files stay in app-scoped Android storage unless the user explicitly shares/exports them.
- Backend records must not store raw Android local filesystem paths.
- Backend asset records are scoped by authenticated user, project, and content record ownership.
- A deleted local capture should remove the local link and mark/delete metadata safely where possible, but it must not delete the content record.
- Creating content from a capture must require an active project.
- The feature must remain usable without cloud file upload.

## Backend Contract

Table: `content_assets`

- `id TEXT PRIMARY KEY`
- `content_id TEXT NOT NULL`
- `project_id TEXT NOT NULL`
- `user_id TEXT NOT NULL`
- `client_asset_id TEXT`
- `source TEXT NOT NULL DEFAULT 'device_capture'`
- `kind TEXT NOT NULL`
- `mime_type TEXT NOT NULL`
- `file_name TEXT`
- `byte_size INTEGER`
- `width INTEGER`
- `height INTEGER`
- `duration_ms INTEGER`
- `storage_uri TEXT`
- `status TEXT NOT NULL DEFAULT 'local_only'`
- `metadata TEXT NOT NULL DEFAULT '{}'`
- `created_at TEXT NOT NULL`
- `updated_at TEXT NOT NULL`
- `deleted_at TEXT`

Endpoints:

- `GET /api/status/content/{content_id}/assets`
- `POST /api/status/content/{content_id}/assets`
- `PATCH /api/status/content/{content_id}/assets/{asset_id}`
- `DELETE /api/status/content/{content_id}/assets/{asset_id}`

Statuses:

- `local_only`: asset exists only on the client device.
- `pending_upload`: future reserved status.
- `uploaded`: future reserved status when `storage_uri` is populated.
- `deleted`: metadata tombstone.

## Implementation Tasks

- [x] Task 1: Add backend asset schema and service methods.
  - Files: `lab/api/migrations/004_status_lifecycle.sql`, `lab/status/db.py`, `lab/status/schemas.py`, `lab/status/service.py`
  - Validate with: backend unit/import tests or targeted pytest where feasible.

- [x] Task 2: Add FastAPI request/response models and status router endpoints.
  - Files: `lab/api/models/status.py`, `lab/api/routers/status.py`
  - Validate with: route-level tests or API model import checks.

- [x] Task 3: Add Flutter local link model/store methods.
  - Files: `app/lib/data/models/capture_content_link.dart`, `app/lib/data/services/capture_local_store.dart`
  - Validate with: Dart unit tests.

- [x] Task 4: Add Flutter API methods for create draft from capture and attach metadata.
  - Files: `app/lib/data/services/api_service.dart`
  - Validate with: existing API parsing tests or compile/analyze.

- [x] Task 5: Add capture UI attachment flow.
  - Files: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Validate with: widget tests and manual Android follow-up.

- [x] Task 6: Update docs and changelog.
  - Files: `app/README.md`, `app/CHANGELOG.md`, `shipglows_data/technical/app/guidelines.md`, `lab/CHANGELOG.md`
  - Validate with: docs review.

## Acceptance Criteria

- Given a local capture exists and an active project is selected, when the user chooses create content, then the app creates a manual content draft and links the capture locally.
- Given backend is reachable, when a capture is linked to a content record, then `/api/status/content/{content_id}/assets` contains a `local_only` metadata record without a local Android path.
- Given backend is unreachable, local capture history must remain usable and the user must see that backend linking is unavailable or queued.
- Given an existing pending content item belongs to the active project, when the user attaches a capture to it, then the local store records the link and the backend stores metadata when reachable.
- Given a capture is discarded, local link metadata for that capture is removed.
- Given a non-Android/web user opens Capture, unsupported capture behavior remains unchanged.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-05 | sf-build | GPT-5 | Created full-stack local capture asset/content contract spec. | implemented | /sf-start local capture assets linked to content |
| 2026-05-05 | sf-build | GPT-5 | Implemented Flutter local links, capture-to-content UI, backend content_assets contract, docs, and targeted validation. | partial | /sf-test local capture assets linked to content on Android |
| 2026-05-05 | sf-ship | GPT-5 | Quick shipped full dirty scope at user request. | shipped | /sf-test local capture assets linked to content on Android |

## Current Chantier Flow

sf-spec ✅ -> sf-ready ✅ -> sf-start ✅ -> sf-verify ⚠️ -> sf-end ✅ -> sf-ship ✅

## Verification Notes

- Passed: `dart format` on changed Flutter files.
- Passed: `flutter test test/data/capture_asset_test.dart test/data/capture_local_store_test.dart test/presentation/screens/capture/capture_screen_test.dart`.
- Passed: `flutter analyze`.
- Passed: `python3 -m py_compile api/models/status.py api/routers/status.py status/schemas.py status/service.py status/db.py`.
- Passed: `/tmp/contentglows-pytest-venv/bin/python -m pytest tests/test_status_content_body.py -q`.
- Blocked: Turso production schema check could not run because the local Turso CLI is not authenticated in this shell.
- Pending: manual Android QA for creating content from a real capture and attaching capture metadata to an existing content record.
- Shipped in quick mode with full dirty scope at user request.
