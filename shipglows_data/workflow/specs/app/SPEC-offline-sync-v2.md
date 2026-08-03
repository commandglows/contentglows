---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-04-25"
updated: "2026-04-27"
status: reviewed
source_skill: sf-docs
scope: feature
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: none
docs_impact: yes
user_story: "En tant qu'utilisateur connecte, je veux continuer a travailler hors-ligne avec cache, file d'attente et reprise de synchronisation sans perte de progression."
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs audit shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md"
---
# SPEC — Offline Sync V2

## Purpose

Document the current degraded/offline behavior of the Flutter app when FastAPI is unavailable, including persisted cache, queued writes, temp-ID reconciliation, dependency-aware replay, and UI sync feedback.

This spec reflects the implemented client behavior as of `2026-04-20`. It is intentionally narrower than a theoretical "full offline app": only flows with a safe local representation and replay strategy are included.

## Goals

- Keep the authenticated app usable when FastAPI is down.
- Serve the latest persisted backend data when cached data exists.
- Queue supported backend mutations locally and replay them automatically.
- Support selected offline creates with temporary IDs and later reconciliation.
- Surface sync state clearly enough that users understand what is pending, stale, paused, or failed.

## Non-goals

- Full offline parity for every backend endpoint.
- Binary upload replay.
- Automatic replay of destructive or externally visible operations.
- Backend contract changes purely for V2.

## Persisted Stores

- `offline_cache_v1`
  Read-through cache for backend responses, scoped per signed-in user.
- `offline_queue_v1`
  Persisted list of queued backend mutations, scoped per signed-in user.
- `offline_id_mappings_v1`
  Persisted `tempId -> realId` mappings used to rewrite queued actions and cached data after replayed creates succeed.

## Queue Model

Each queued entry is represented by `QueuedOfflineAction`.

Stable fields:
- `id`
- `userScope`
- `resourceType`
- `actionType`
- `label`
- `method`
- `path`
- `dedupeKey`
- `payload`
- `queryParameters`
- `createdAt`
- `updatedAt`
- `attemptCount`
- `lastError`

Stable metadata conventions in `meta`:
- `entityType`
- `entityId`
- `tempId`
- `dependsOnTempIds`

## Queue Statuses

- `pending`
  Ready to replay when backend connectivity is available.
- `retrying`
  Previously attempted, still retryable.
- `blockedDependency`
  Waiting for another queued create to reconcile a referenced `tempId`.
- `pausedAuth`
  Replay paused because FastAPI responded with `401/403`.
- `failed`
  Permanent client-visible failure, usually validation or business `4xx`.
- `cancelled`
  Manually removed from active replay.

## Replay Rules

Replay is triggered:
- on app startup
- when app-access state refreshes after startup or connectivity transitions
- manually from the Uptime screen

Replay policy:
- FIFO by creation time
- before sending an action, resolve known `tempId -> realId` mappings in `path`, `payload`, `queryParameters`, `dedupeKey`, and `meta`
- if `dependsOnTempIds` still contains unresolved temp IDs, mark the action `blockedDependency` and skip it for now
- if a replayed create returns a real backend ID, persist the mapping and rewrite queued actions plus cached data immediately

Error handling:
- network, timeout, `5xx` -> keep retryable
- `401/403` -> `pausedAuth`
- validation or business `4xx` -> `failed`

## Cache Rules

- Reads go through a read-through cache for supported resources.
- Successful backend responses refresh persisted cache.
- Backend failures fall back to cached data when failures are offline/unreachable.
- Malformed payloads or invalid-response contract errors remain visible to avoid masking backend regressions.
- Cache data is marked stale in the app state and surfaced in UI.
- Cache is user-scoped. Data must not leak between authenticated users.
- Demo data is not injected into authenticated offline flows.

## Supported Offline Flows

### Reads

Supported read fallback exists for the main authenticated shell and the core V1/V2 resources, including:
- bootstrap-derived app access
- projects
- settings
- creator profile
- personas
- pending content and content body/history views used by the review flow
- affiliations
- drip plans and drip stats

### Writes

Supported offline queue/replay flows currently include:
- projects: create, update
- settings: update, including `defaultProjectId`
- creator profile: save
- personas: create, update
- affiliations: create, update
- content: create from angle fallback, update, save body, transition, schedule
- ideas: update
- text feedback flows already routed through the queue layer
- drip plans: create, update, schedule, activate, pause, resume, cancel

Offline creates with optimistic local objects plus temp-ID reconciliation:
- project
- persona
- affiliation
- content record created from angle fallback
- drip plan

## Explicitly Blocked Offline

The client refuses these flows while FastAPI is unavailable:
- publish actions to external platforms
- binary/audio uploads
- destructive deletes
- drip import
- drip clustering
- drip execute tick
- other server-first flows without a safe local representation

## UI Surface

Global UI:
- the authenticated shell remains accessible
- the degraded-mode banner summarizes backend availability, stale data, replay activity, paused auth, failed actions, and dependency-blocked actions
- the Uptime screen acts as the queue control center

Entity-level UI:
- supported list surfaces show `Pending sync` when related queued work exists
- supported list surfaces can show `Retrying sync` when retry loops are active
- supported list surfaces can show `Sync paused` when a `401/403` auth issue requires session refresh
- supported list surfaces can show `Waiting for dependency` when chained actions are blocked on unresolved `tempId`.
- supported list surfaces show `Sync failed` when the latest related queued work failed
- the badge mapping is driven by entity sync providers keyed by `entityType + entityId`

Current list surfaces with sync badges:
- projects
- personas
- affiliations
- content cards
- drip plans

## Reconciliation Details

When a queued create succeeds and the backend returns a real ID:
- the mapping is stored in `offline_id_mappings_v1`
- queued actions are rewritten to use the real ID
- cached collections and detail records are rewritten to replace the temp ID
- later reads and mutations resolve through the mapping automatically

This is what allows chained offline work such as:
- create project -> set `defaultProjectId`
- create drip plan -> update/schedule/activate it later
- create content from angle -> edit, transition, or schedule the content later

## Known Limits

- Uploads remain online-only.
- Deletes remain online-only.
- External publish operations remain online-only.
- Some complex backend-first jobs are still blocked instead of approximated locally.
- Sync badges are intentionally limited to the primary list surfaces, not every detail/form screen.

## Reference Files

- `lib/data/models/offline_sync.dart`
- `lib/data/services/offline_storage_service.dart`
- `lib/data/services/api_service.dart`
- `lib/providers/providers.dart`
- `lib/presentation/screens/app_shell.dart`
- `lib/presentation/screens/uptime/uptime_screen.dart`
- `lib/presentation/widgets/offline_sync_status_chip.dart`
