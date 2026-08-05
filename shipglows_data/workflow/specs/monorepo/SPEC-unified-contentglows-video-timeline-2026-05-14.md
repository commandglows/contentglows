---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-05-14"
created_at: "2026-05-14 15:27:39 UTC"
updated: "2026-05-14"
updated_at: "2026-05-14 18:32:37 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlows authentifiee, je veux une seule timeline video ContentGlows pour assembler textes, images, videos, audio et musique depuis un contenu existant, afin de previsualiser puis rendre une video sociale sans gerer Remotion ni maintenir deux modeles de montage concurrents."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "worker"
  - "project asset library"
  - "Turso/libSQL"
  - "JobStore"
  - "Clerk auth"
  - "Remotion renderer"
  - "future reels workflow"
depends_on:
  - artifact: "shipglows_data/workflow/explorations/2026-05-14-video-renderer-boundary.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md"
    artifact_version: "1.0.0"
    required_status: "ready; implementation must be verified before timeline render batches"
  - artifact: "shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "app/CLAUDE.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
  - artifact: "lab/CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "Remotion renderMedia official docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
  - artifact: "Remotion SSR Node official docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
  - artifact: "Remotion selectComposition official docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
  - artifact: "Remotion timeline official docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
  - artifact: "Remotion license official docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
supersedes:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    reason: "Superseded as the canonical product direction because the user rejected two separate storyboard/timeline models. Storyboard may remain only as a simplified view over the same ContentGlows timeline."
evidence:
  - "User decision 2026-05-14: ContentGlows must not have two competing timelines."
  - "User decision 2026-05-14: Remotion is the V1 rendering engine, but ContentGlows owns the timeline, editor, schema, validation and adapter boundary."
  - "User decision 2026-05-14: prefer a mature rendering product over a Dart-only renderer if maturity protects the application."
  - "User answer 2026-05-14: V1 starts from existing content through /editor/:id/video."
  - "User answer 2026-05-14: model the full clip family from the start, even if V1 UI stays focused."
  - "User answer 2026-05-14: do not use Remotion Timeline or Editor Starter as the product UI; build the Flutter timeline ourselves."
  - "User answer 2026-05-14: V1 supports vertical_9_16 and landscape_16_9, 30fps, max 3 minutes."
  - "Spec decision 2026-05-14: V1 preview truth is a server-rendered Remotion MP4 for the current immutable timeline version; in-app interactive preview is future enhancement, not the source of truth."
  - "app/lib/router.dart has /editor/:id but no /editor/:id/video route; route sanitization must handle the specific video route before generic /editor/* matching."
  - "app/lib/presentation/screens/editor/editor_screen.dart can open the project asset picker but has no video timeline."
  - "app/lib/presentation/widgets/project_asset_picker.dart already supports allowedMediaKinds and target/action context for project asset selection."
  - "lab/status/service.py already names select_for_video_version and use_in_remotion_render actions, but video_version ownership validation currently raises until the video asset store ships."
  - "lab/status/service.py video_version eligibility currently omits still-image/capture use cases that a video timeline needs."
  - "lab/api/services/project_asset_storage.py distinguishes render-safe Bunny descriptors from temporary provider descriptors."
  - "lab/api/services/job_store.py can store preview/final render jobs, but must not become the source of truth for timeline state."
  - "Fresh-docs checked 2026-05-14: Remotion renderMedia official docs support programmatic rendering with JSON inputProps, output locations, progress callbacks and codec options."
  - "Fresh-docs checked 2026-05-14: Remotion SSR Node official docs define server-side rendering as a Node workflow."
  - "Fresh-docs checked 2026-05-14: Remotion selectComposition official docs confirm composition selection and inputProps usage."
  - "Fresh-docs checked 2026-05-14: Remotion timeline official docs describe a React timeline/editor product surface that is explicitly out of scope for ContentGlows V1 UI."
  - "Fresh-docs checked 2026-05-14: Remotion license official docs require explicit commercial/license review before production commitment."
  - "Adversarial readiness review 2026-05-14 found the first draft lacked safe execution batches, concrete API/data/render contracts, render abuse controls and an explicit worker prerequisite."
next_step: "/sf-spec Remotion Cloud Run GCS render deployment for ContentGlows video timeline"
---

## Title

Unified ContentGlows Video Timeline

## Status

Ready after adversarial `sf-ready` correction and focused re-review. This spec captures the new product decision: ContentGlows has one canonical video timeline, implemented as ContentGlows-owned Flutter/backend product code, rendered by Remotion through a replaceable adapter in V1. It supersedes the previous storyboard-only Remotion video editor framing. A storyboard can still exist later, but only as a guided view over the same timeline data, not as a separate source of truth.

## User Story

En tant que creatrice ContentGlows authentifiee, je veux une seule timeline video ContentGlows pour assembler textes, images, videos, audio et musique depuis un contenu existant, afin de previsualiser puis rendre une video sociale sans gerer Remotion ni maintenir deux modeles de montage concurrents.

## Minimal Behavior Contract

Depuis un contenu appartenant au projet actif, ContentGlows ouvre ou cree une timeline video unique, persistante et versionnee, qui accepte des clips textes, images, videos, audio, musique et fonds issus d'assets serveur valides, permet de les placer dans le temps avec des durees et des pistes, lance une preview MP4 serveur pour la version courante, puis autorise un rendu final uniquement depuis cette preview terminee et non stale. Si les droits, le contenu, les assets, la sauvegarde, la validation, le worker Remotion ou le rendu echouent, l'utilisateur voit un etat recuperable, aucune version incoherente ne devient courante et aucun artefact final n'est annonce pret. Le cas facile a rater est la derive entre modeles: Remotion recoit seulement des props derivees d'une timeline ContentGlows immuable; il ne devient jamais la timeline canonique, et une interface storyboard ne peut pas enregistrer un etat concurrent.

## Success Behavior

- Given un utilisateur Clerk authentifie et un `content_id` appartenant a son projet actif, when il ouvre `/editor/:id/video`, then l'app cree ou charge une timeline active pour `(user_id, project_id, content_id, format_preset)` et affiche le montage, ses pistes, ses clips, son statut de sauvegarde et son statut de preview.
- Given aucune timeline n'existe encore pour ce contenu et ce format, when la page video s'ouvre, then le backend cree une timeline initiale depuis le contenu et les assets eligibles sans lancer automatiquement de rendu couteux.
- Given l'utilisateur ajoute, deplace, retaille, remplace ou supprime un clip dans les limites V1, when il sauvegarde, then le backend valide l'operation, persiste une nouvelle version immuable et marque toute preview/final derivee d'une ancienne version comme stale.
- Given un asset est choisi pour un clip, when le backend valide la selection, then l'asset est owned, durable ou render-safe, compatible avec le type de clip et lie au `video_version` par une usage mutation auditable.
- Given la version courante est valide, when l'utilisateur demande une preview, then l'API cree ou reutilise un job preview pour cette version exacte, convertit la timeline en props Remotion, appelle l'adaptateur Remotion et expose un statut pollable.
- Given la preview serveur est terminee pour la version courante, when l'utilisateur la lit, then l'app charge un MP4 via l'URL d'artefact signee existante et montre clairement que la preview correspond a la version actuelle.
- Given l'utilisateur modifie la timeline apres preview, when il tente de rendre final, then l'action est bloquee jusqu'a une nouvelle preview terminee pour la nouvelle version.
- Given une preview terminee et non stale est validee, when l'utilisateur demande le rendu final, then le backend cree un job final distinct lie a la version et au `preview_job_id`, puis expose l'artefact final quand le worker termine.
- Given l'utilisateur choisit le format, when la timeline est creee ou rendue, then V1 accepte seulement `vertical_9_16` et `landscape_16_9`, avec 30fps et une duree totale inferieure ou egale a 180 secondes.
- Proof of success is a persisted timeline/version, asset usages linked to video versions, a Remotion preview MP4 for the exact version, a final job gated by that preview, and passing backend, Flutter and worker tests for auth, asset validation, stale preview prevention and render orchestration.

## Error Behavior

- Missing, expired or invalid Clerk auth returns `401`; no timeline, version, usage link, preview job or final job is created.
- Foreign, missing, deleted or cross-project `content_id`, `timeline_id`, `version_id`, `asset_id`, `job_id` or `project_id` returns `403` or `404` without leaking titles, prompts, storage paths, signed URLs or render status.
- Unsupported format preset, fps, duration over 180 seconds, negative duration, overlapping clips on exclusive tracks, invalid track type, malformed clip JSON, unsupported transition, missing required text/media, or unknown schema version returns a typed validation error and leaves the previous current version intact.
- Selecting a local-only, provider-temporary, tombstoned, deleted, failed, foreign, non-render-safe or incompatible asset for render use is rejected server-side and does not mutate the timeline.
- If two saves race, stale writes return conflict based on the last known timeline version and must not overwrite the newer version.
- If the Remotion worker, render adapter, bundle, FFmpeg path, storage descriptor, signed URL service or local render directory fails, the preview/final job becomes observable as failed with sanitized details; timeline editing remains available.
- If the signed preview URL expires while the player is open, the app refreshes job status to obtain a fresh signed URL instead of treating the preview as failed.
- If active project or content context changes while Flutter is saving, selecting assets, polling or rendering, stale responses are ignored and the UI reloads the current context.
- If an old storyboard-only spec or future route tries to save scene data separately, implementation must route it through the same timeline/version APIs or reject it.
- What must never happen: arbitrary client URLs or local file paths enter Remotion props, provider secrets reach Flutter logs, the worker is called directly by Flutter, `JobStore` becomes the canonical timeline store, a stale preview is exported as final, or two product surfaces persist competing edits for the same video.

## Problem

ContentGlows currently has no real video timeline. Existing "Timeline" language in the app is an activity/publishing chronology, not a media editing model. The existing Remotion video editor spec framed the V1 product as a guided storyboard, but the product decision has changed: there must not be a separate storyboard timeline and a later "real" timeline. The product needs a single canonical ContentGlows timeline from day one, while still using Remotion as the mature renderer for V1.

## Solution

Introduce a ContentGlows-owned video timeline domain with versioned tracks, clips, asset usages, validation, preview/final render state and a Flutter editor at `/editor/:id/video`. Remotion remains the V1 render engine behind a backend adapter that converts immutable timeline versions into Remotion input props; the adapter can be replaced later without changing the product timeline model.

## Scope In

- Add one canonical timeline model for videos, not a separate storyboard model.
- Create or load one active timeline per `(user_id, project_id, content_id, format_preset)` in V1.
- Support a full V1 data model for clip families: `text`, `image`, `video`, `audio`, `music`, `background`, and `render_output` references where appropriate.
- Keep the initial UI focused and guided while using the same underlying timeline data: tracks, clips, durations, start times, ordering, asset refs, style/layout metadata, and render metadata.
- Add backend Pydantic/domain models for timeline draft mutations, immutable versions, clip validation and renderer props generation.
- Add Turso/libSQL tables and idempotent startup/migration ensures for timelines, immutable timeline versions and render/job links.
- Add APIs to create/load a content-linked timeline, save a version, validate a version, request preview, validate preview, request final render, poll jobs and list linked assets.
- Integrate with the project asset library using `target_type=video_version`, `usage_action=select_for_video_version` and `usage_action=use_in_remotion_render`.
- Implement server-side ownership and eligibility validation for `video_version` usages, including still images/captures needed for image clips.
- Add a Flutter route `/editor/:id/video` as the V1 entry point from the existing content editor.
- Add a Flutter timeline screen with tracks, clip blocks, basic trim/move/reorder, asset picker integration, inspector controls, save state, preview state and final render action.
- Use server-rendered Remotion MP4 preview as the V1 truth for previewing and final-render eligibility.
- Convert immutable ContentGlows timeline versions into Remotion `inputProps` through a backend-owned renderer adapter contract.
- Implement `RemotionRendererAdapter` for V1, delegating to the existing Remotion worker/render service foundation.
- Support `vertical_9_16` and `landscape_16_9`, 30fps, maximum total duration 180 seconds.
- Use existing render job infrastructure where appropriate for preview/final status; keep timeline state in dedicated timeline tables.
- Add tests for backend validation, auth/ownership, asset eligibility, stale write handling, stale preview prevention, app state transitions and worker props compatibility.

## Scope Out

- Building a custom low-level renderer, codec stack, muxer, media decoder, FFmpeg distribution, or browser capture engine from scratch in V1.
- Using Remotion Timeline, Remotion Editor Starter, or any React timeline/editor product UI as the ContentGlows editor surface.
- Creating a second storyboard source of truth. Storyboard mode, if added, is only a constrained view over the same timeline.
- Real-time in-app interactive preview as the final source of truth. Flutter may show thumbnails, scrub handles or rough local hints later, but V1 render eligibility comes from server MP4 preview.
- Client-side final rendering as the only or primary path.
- Full professional editor parity with Premiere, Final Cut, CapCut, DaVinci Resolve, After Effects or browser NLEs.
- Arbitrary public URL media import.
- Generic binary upload flows unless already implemented by the project asset library or a separate upload spec.
- Social publishing, scheduling or platform-specific upload of the final MP4.
- AI automatic timeline planning, voiceover generation, music generation, subtitles, text-based video editing and B-roll generation unless covered by their own future specs.
- Visible multi-version browser in V1; immutable versions exist for correctness and diagnostics, while UI focuses on current draft/current render state.
- Offline queueing for timeline save/render operations. V1 video editing is online-only.

## Constraints

- ContentGlows timeline data is canonical. Remotion props, storyboard views and preview artifacts are derived outputs.
- Flutter never calls the Remotion worker directly; `lab` remains the authenticated public API boundary.
- Client requests pass ids and guided mutations, not trusted storage descriptors, file paths or arbitrary URLs.
- Every timeline, version, usage and render job is scoped to `user_id`, `project_id` and `content_id`.
- Durable timeline data requires a Turso/libSQL migration and idempotent ensure logic in the same implementation change.
- Render jobs can use existing `JobStore`, but `JobStore` must not store the editable timeline as its primary source of truth.
- `video_version` ownership validation in `lab/status/service.py` must be implemented before any asset can be selected for timeline render.
- Asset eligibility for video versions must allow the actual V1 clip needs: at minimum `image`, `thumbnail`, `video_cover`, `capture`, `video`, `audio`, `music`, `background_config` and controlled `render_output` references where safe.
- Provider-temporary or local-only assets may appear for preview/history only if clearly marked, but cannot enter server-side Remotion renders until made durable/render-safe.
- The Remotion worker/render-service foundation from `remotion-render-service-integration.md` is an implementation prerequisite for any preview/final render batch. If `worker/` or equivalent worker endpoints are absent at start time, `sf-start` must execute that prerequisite chantier first or stop before coding preview/final behavior.
- Timeline saves use optimistic concurrency. A stale client cannot overwrite newer edits.
- A final render requires a completed preview job for the exact immutable version and format preset.
- Preview and final jobs are separate and cannot overwrite each other.
- `vertical_9_16` and `landscape_16_9` are the only V1 presets; both use 30fps and max 180 seconds.
- Render creation is explicitly user-triggered in V1 to avoid render spam.
- Timeline render requests inherit the render-service anti-abuse contract: max one active render per user, max three active renders globally in local mode, `429` with `Retry-After: 60` when capacity is exhausted, sanitized worker errors, server-generated artifact paths only and compacted renderer props size <= 64KB unless the render-service spec is explicitly revised.
- Timeline complexity limits for V1: max 12 tracks, max 100 clips, max 50 asset descriptors in renderer props, max 2,000 characters per text clip, and max 180 seconds total duration.
- Short-lived signed artifact playback URLs may appear only in completed render job API responses under `artifact.playback_url`. They are browser playback handles, not durable state. Flutter must not persist them as authority, and diagnostics/logs must redact their query strings and token values. Worker tokens, provider tokens, storage URIs and storage secrets must never reach Flutter or API responses.
- Remotion license/commercial terms must be reviewed before production rollout if the organization crosses the applicable commercial threshold or usage changes.

## Dependencies

- `app`: Flutter, Dart 3.11+, Riverpod, GoRouter, Dio and existing editor/project asset patterns.
- `lab`: FastAPI, Clerk auth, Turso/libSQL, existing project ownership helpers, project asset library APIs and `JobStore`.
- `worker`: Node/TypeScript/React/Remotion render service foundation from `remotion-render-service-integration.md`.
- Existing app files to read first:
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
  - `app/lib/data/models/project_asset.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
- Existing backend files to read first:
  - `lab/api/routers/assets.py`
  - `lab/api/models/status.py`
  - `lab/api/services/project_asset_storage.py`
  - `lab/api/services/job_store.py`
  - `lab/status/schemas.py`
  - `lab/status/service.py`
  - `lab/api/main.py`
  - `lab/api/routers/__init__.py`
- Expected new backend API family:
  - `POST /api/video-timelines/from-content`
  - `GET /api/video-timelines/{timeline_id}`
  - `PATCH /api/video-timelines/{timeline_id}/draft`
  - `POST /api/video-timelines/{timeline_id}/versions`
  - `POST /api/video-timelines/{timeline_id}/versions/{version_id}/preview`
  - `POST /api/video-timelines/{timeline_id}/versions/{version_id}/preview/{preview_job_id}/approve`
  - `POST /api/video-timelines/{timeline_id}/versions/{version_id}/render-final`
  - `GET /api/video-timelines/{timeline_id}/jobs/{job_id}`
- Expected app route:
  - `/editor/:id/video`, sanitized as `/editor/:id/video` before generic `/editor/*` matching.
- Fresh external docs checked:
  - `fresh-docs checked`: Remotion `renderMedia()` official docs at `https://www.remotion.dev/docs/renderer/render-media`.
  - `fresh-docs checked`: Remotion SSR Node official docs at `https://www.remotion.dev/docs/ssr-node`.
  - `fresh-docs checked`: Remotion `selectComposition()` official docs at `https://www.remotion.dev/docs/renderer/select-composition`.
  - `fresh-docs checked`: Remotion timeline official docs at `https://www.remotion.dev/docs/timeline`; treated as out-of-scope UI inspiration only.
  - `fresh-docs checked`: Remotion license official docs at `https://www.remotion.dev/docs/license`; production rollout needs explicit license review.

## API Contract

All new endpoints are Clerk-authenticated through existing `lab` auth dependencies and return only resources owned by the current user/project. New video timeline endpoints use typed JSON responses. Error responses for this API family should use this envelope in `HTTPException.detail` unless an existing shared exception handler forces a different shape:

```json
{
  "code": "timeline_conflict",
  "message": "Timeline version is stale.",
  "field": "base_version_id",
  "retry_after_seconds": null
}
```

Error `code` values must be stable strings: `not_found`, `forbidden`, `invalid_timeline`, `timeline_conflict`, `asset_not_eligible`, `preview_stale`, `render_capacity_exhausted`, `worker_unavailable`, `render_failed`, `license_blocked`, and `internal_error`. Do not include signed artifact URLs, storage URIs, worker tokens, provider ids, prompts, or raw worker stack traces in errors.

- `POST /api/video-timelines/from-content`
  - Request:
    ```json
    {
      "content_id": "content-123",
      "format_preset": "vertical_9_16",
      "client_request_id": "optional-idempotency-key"
    }
    ```
  - Behavior: creates or returns the active timeline for `(user_id, project_id, content_id, format_preset)`. `format_preset` defaults to `vertical_9_16`. If the same active timeline exists, return it and do not duplicate. No render is launched.
  - Response `200` or `201`: `VideoTimelineResponse`.

- `GET /api/video-timelines/{timeline_id}`
  - Response `200`: `VideoTimelineResponse` including current draft, latest immutable version metadata, preview/final job summaries and stale status.

- `PATCH /api/video-timelines/{timeline_id}/draft`
  - Request:
    ```json
    {
      "base_version_id": "version-previous-or-null",
      "draft_revision": 4,
      "timeline": {"schema_version": "1.0", "format_preset": "vertical_9_16", "fps": 30, "tracks": [], "clips": []}
    }
    ```
  - Behavior: validates and stores a mutable draft for editing. `draft_revision` is optimistic concurrency. This endpoint cannot create preview/final jobs.
  - Response `200`: `VideoTimelineDraftResponse` with `draft_revision`, `validation`, `latest_version_id`, and `preview_status`.

- `POST /api/video-timelines/{timeline_id}/versions`
  - Request:
    ```json
    {
      "base_version_id": "version-previous-or-null",
      "draft_revision": 4,
      "timeline": {"schema_version": "1.0", "format_preset": "vertical_9_16", "fps": 30, "tracks": [], "clips": []},
      "client_request_id": "optional-idempotency-key"
    }
    ```
  - Behavior: validates the submitted timeline, creates an immutable version, sets it as current, and marks previous preview/final readiness stale. If `client_request_id` already created the same version for this user/timeline, return the existing version.
  - Response `201` or duplicate `200`: `VideoTimelineVersionResponse`.

- `POST /api/video-timelines/{timeline_id}/versions/{version_id}/preview`
  - Request:
    ```json
    {"client_request_id": "optional-idempotency-key"}
    ```
  - Behavior: verifies `version_id` is current, validates renderer props, enforces render capacity, and creates or returns one preview job for this exact version. It returns `429` with `Retry-After: 60` and `code=render_capacity_exhausted` when capacity is full.
  - Response `202` for queued/in-progress or `200` for existing/completed: `VideoTimelineRenderJobResponse`.

- `POST /api/video-timelines/{timeline_id}/versions/{version_id}/preview/{preview_job_id}/approve`
  - Request:
    ```json
    {"approved": true}
    ```
  - Behavior: approves a completed preview only when it belongs to the same user/timeline/version, is `render_mode=preview`, has a non-empty artifact, and is not stale. Approval stores `approved_preview_job_id` and `preview_approved_at` on the version metadata.
  - Response `200`: `VideoTimelineVersionResponse`.

- `POST /api/video-timelines/{timeline_id}/versions/{version_id}/render-final`
  - Request:
    ```json
    {
      "preview_job_id": "preview-job-123",
      "client_request_id": "optional-idempotency-key"
    }
    ```
  - Behavior: requires an approved completed preview for the exact version, creates a separate final job, and returns the existing active/completed final job for the same `(user_id, timeline_id, version_id, preview_job_id, client_request_id)` if repeated. If no idempotency key is provided, the backend still de-duplicates active/completed final jobs for the same approved preview.
  - Response `202` for queued/in-progress or `200` for existing/completed: `VideoTimelineRenderJobResponse`.

- `GET /api/video-timelines/{timeline_id}/jobs/{job_id}`
  - Response `200`: `VideoTimelineRenderJobResponse` with worker status refreshed when the job is non-terminal.

Core response shapes:

```json
{
  "timeline_id": "timeline-123",
  "content_id": "content-123",
  "project_id": "project-123",
  "user_id": "user-123",
  "format_preset": "vertical_9_16",
  "current_version_id": "version-123",
  "draft_revision": 4,
  "draft": {"schema_version": "1.0", "format_preset": "vertical_9_16", "fps": 30, "tracks": [], "clips": []},
  "latest_version": null,
  "preview_status": "missing",
  "final_status": "missing",
  "created_at": "2026-05-14T15:46:55Z",
  "updated_at": "2026-05-14T15:46:55Z"
}
```

```json
{
  "job_id": "job-123",
  "timeline_id": "timeline-123",
  "version_id": "version-123",
  "render_mode": "preview",
  "status": "queued",
  "progress": 0,
  "message": "Queued",
  "artifact": null,
  "stale": false,
  "created_at": "2026-05-14T15:46:55Z",
  "updated_at": "2026-05-14T15:46:55Z"
}
```

`status` values for render jobs are exactly `queued`, `in_progress`, `completed`, `failed`, and `cancelled`. `preview_status` and `final_status` are exactly `missing`, `queued`, `in_progress`, `completed`, `failed`, `cancelled`, and `stale`.

For completed render jobs, `artifact` is:

```json
{
  "playback_url": "https://api.example.com/api/video-timelines/timeline-123/jobs/job-123/artifact?token=short-lived-signed-token",
  "artifact_expires_at": "2026-05-15T15:46:55Z",
  "retention_expires_at": "2026-06-13T15:46:55Z",
  "deletion_warning_at": "2026-06-10T15:46:55Z",
  "byte_size": 1234567,
  "mime_type": "video/mp4",
  "file_name": "preview-job-123.mp4",
  "render_mode": "preview"
}
```

Artifact URL rules:

- `playback_url` is returned only for owned completed jobs with non-empty MP4 artifacts.
- `playback_url` expires exactly according to `artifact_expires_at`; Flutter refreshes by polling the job again.
- The signing token is scoped to `job_id`, `timeline_id`, `version_id`, `render_mode`, artifact hash and expiry.
- Artifact downloads may use a signed unauthenticated playback URL because browser video elements cannot reliably attach Clerk bearer headers. Fresh job polling and fresh URL issuance remain Clerk-authenticated.
- Logs, diagnostics, Sentry context and stored Flutter provider state must redact or omit `playback_url` query strings.

## Timeline Data Contract

The canonical timeline document is owned by ContentGlows and is stored as validated JSON. The backend accepts canonical frame-based values; Flutter may display seconds, but API writes must send frame integers to avoid rounding drift.

```json
{
  "schema_version": "1.0",
  "format_preset": "vertical_9_16",
  "fps": 30,
  "duration_frames": 450,
  "tracks": [
    {"id": "track-main", "type": "visual", "order": 0, "exclusive": true, "muted": false, "locked": false},
    {"id": "track-text", "type": "overlay", "order": 1, "exclusive": false, "muted": false, "locked": false},
    {"id": "track-music", "type": "audio", "order": 2, "exclusive": false, "muted": false, "locked": false}
  ],
  "clips": [
    {
      "id": "clip-1",
      "track_id": "track-main",
      "clip_type": "image",
      "start_frame": 0,
      "duration_frames": 150,
      "asset_id": "asset-image-1",
      "trim_start_frame": 0,
      "role": "primary_visual",
      "style": {"fit": "cover", "background": "#111111"},
      "metadata": {}
    }
  ]
}
```

Allowed V1 `format_preset` values:

| Format | Width | Height | FPS | Max duration |
| --- | ---: | ---: | ---: | ---: |
| `vertical_9_16` | 1080 | 1920 | 30 | 180s |
| `landscape_16_9` | 1920 | 1080 | 30 | 180s |

Allowed track `type` values:

- `visual`: image/video/background clips. `exclusive=true` means clips on that track cannot overlap.
- `overlay`: text/image overlays. Overlap is allowed and compositing follows `track.order` then `clip.start_frame`.
- `audio`: audio/music clips. Overlap is allowed and mixed by the renderer; backend trims playback to `duration_frames`.

Allowed `clip_type` values:

- `text`: requires `text`, optional `style`. `text` max 2,000 characters. No asset id.
- `image`: requires a render-safe `asset_id` with media kind `image`, `thumbnail`, `video_cover`, or durable `capture`.
- `video`: requires a render-safe `asset_id` with media kind `video`, optional `trim_start_frame`, optional `volume`.
- `audio`: requires a render-safe `asset_id` with media kind `audio`, optional `trim_start_frame`, optional `volume`.
- `music`: requires a render-safe `asset_id` with media kind `music`, optional `trim_start_frame`, optional `volume`.
- `background`: may use an allowlisted color/gradient config or a render-safe `background_config` asset. Arbitrary code is forbidden.
- `render_output`: reserved in the schema for future controlled reuse. V1 user-created `render_output` clips are rejected unless a backend-only migration or follow-up spec explicitly marks a render output as safe for reuse.

Compositing and overlap rules:

- Visual output is composed by increasing `track.order`; later tracks visually appear above earlier tracks.
- Clips on the same `exclusive=true` track must not overlap.
- Clips on `overlay` and `audio` tracks may overlap.
- `duration_frames` is `max(start_frame + duration_frames)` across non-muted visual/overlay tracks and must be `> 0` and `<= 5400`.
- A V1 video timeline must contain at least one visible non-muted `visual` or `overlay` clip with non-zero duration. Text-only timelines are valid because `text` clips on an `overlay` track render visible pixels. Audio-only/music-only timelines are rejected with `invalid_timeline` until the user adds a `text`, `image`, `video`, or `background` clip.
- Audio/music is clipped to the visible timeline duration. Audio outside the visible duration is ignored for render props.
- `start_frame`, `duration_frames`, and `trim_start_frame` must be non-negative integers. `duration_frames` must be greater than zero.
- If Flutter starts from seconds, it must convert to frames before sending writes. Backend helper conversion uses `round(seconds * 30)` and then validates integer frame boundaries.

Validation rejects unknown fields that would affect render behavior, unknown clip types, unknown track types, missing referenced tracks, duplicate ids, direct URLs, local paths, non-owned asset ids, tombstoned assets, provider-temporary descriptors and props that exceed compacted 64KB render input.

## Renderer Contract

`lab` converts immutable `VideoTimelineVersionResponse.timeline` into `ContentGlowsTimelineProps`. Remotion receives only this derived object, never the mutable draft and never client-supplied URLs.

```json
{
  "composition_id": "ContentGlowsTimelineVideo",
  "timeline_id": "timeline-123",
  "version_id": "version-123",
  "format": {"preset": "vertical_9_16", "width": 1080, "height": 1920, "fps": 30, "duration_in_frames": 450},
  "tracks": [{"id": "track-main", "type": "visual", "order": 0}],
  "clips": [{"id": "clip-1", "track_id": "track-main", "type": "image", "start_frame": 0, "duration_in_frames": 150, "asset_ref": "asset-image-1"}],
  "assets": {
    "asset-image-1": {
      "asset_id": "asset-image-1",
      "media_kind": "image",
      "mime_type": "image/png",
      "render_url": "server-resolved-signed-or-internal-url",
      "width": 1080,
      "height": 1920,
      "duration_frames": null
    }
  }
}
```

Renderer adapter invariants:

- `selectComposition()` and `renderMedia()` receive the same `inputProps`.
- Backend resolves `render_url` or internal asset descriptors after auth, ownership and render-safety checks.
- Renderer props must be deterministic for the same immutable version and asset descriptor state.
- Preview and final render use the same timeline props except for render mode, codec/quality settings and output path.
- Worker errors are normalized into `queued`, `in_progress`, `completed`, `failed`, or `cancelled`.
- Final render cannot be requested from renderer props unless the version stores `approved_preview_job_id`.
- If the worker package/directory is missing, preview/final tasks are blocked and the prerequisite render-service chantier must run first.

## Invariants

- A V1 timeline belongs to exactly one `user_id`, `project_id`, `content_id` and `format_preset`.
- At most one active timeline exists per `(user_id, project_id, content_id, format_preset)`.
- A timeline version is immutable once created.
- Render jobs reference immutable versions, not mutable drafts.
- Current draft edits invalidate preview/final readiness from older versions.
- Timeline clip ids are stable within a version and unique inside that version.
- Track order and clip order are deterministic after backend validation.
- Total rendered duration is `max(end_time)` across visible video tracks and must be `> 0` and `<= 180s`.
- Audio/music clips cannot extend the render beyond the approved timeline duration unless explicitly trimmed by the backend.
- Exclusive visual tracks cannot contain impossible overlaps unless the schema explicitly defines compositing order.
- Asset refs in clips are server-side asset ids plus roles, never client-supplied URLs.
- Remotion receives only backend-sanitized props and resolved render-safe descriptors.
- Preview and final renders are separate jobs and separate artifacts.
- Final render requires a completed, approved, non-stale preview for the exact version.
- A stale preview can remain visible as history only when clearly marked stale and never used for final gating.
- All user-visible errors are recoverable or explanatory; silent data loss is forbidden.

## Links & Consequences

- `app/lib/router.dart` gains a specific `/editor/:id/video` route and Sentry route sanitizer before broad `/editor/*` matching.
- `app/lib/presentation/screens/editor/editor_screen.dart` gains a video entry action from an existing content item.
- `app/lib/presentation/screens/editor/video_timeline_screen.dart` or equivalent is created as the primary workspace.
- `app/lib/presentation/widgets/project_asset_picker.dart` is reused for timeline clip asset selection rather than duplicating picker logic.
- `app/lib/data/models/project_asset.dart` may need role/eligibility fields surfaced if backend adds video-version metadata not currently modeled.
- `app/lib/data/services/api_service.dart` gains typed video timeline methods.
- `app/lib/providers/` gains a timeline provider/notifier; implementation should follow existing Riverpod patterns and avoid hiding a large feature in unrelated providers if local conventions allow a separate file.
- `lab/api/models/video_timeline.py` or equivalent is created for request/response schemas.
- `lab/api/services/video_timeline_store.py` or equivalent owns Turso persistence and optimistic concurrency.
- `lab/api/services/video_renderer_adapter.py` and a Remotion implementation own conversion from ContentGlows timeline to renderer calls.
- `lab/api/routers/video_timelines.py` exposes the authenticated API and is registered in the FastAPI app/router registry.
- `lab/status/service.py` must stop rejecting `target_type=video_version` once the video version store exists and must enforce ownership/eligibility.
- `lab/status/schemas.py` and `api/models/status.py` may need enum/eligibility updates for still-image clips and controlled render outputs.
- `lab/api/migrations/005_video_timelines.sql` or next available migration adds the required timeline tables and indexes.
- `worker` gains a composition that consumes normalized timeline props, not storyboard-only or quiz-specific props.
- Existing specs for audio/music, B-roll, motion assistant and text-based editing should attach to the same timeline model later instead of creating separate state.
- Product analytics/observability should distinguish timeline created, version saved, asset selected, preview requested, preview completed, preview stale, final requested and final completed.

## Documentation Coherence

- Update `app/README.md` or app docs with the `/editor/:id/video` workflow, online-only render limitation and preview/final gate.
- Update `lab/README.md` or `ENVIRONMENT_shipglows_data/technical/SETUP.md` with timeline API routes, Turso migration requirements, worker dependency and environment variables inherited from the render service.
- Update `worker/README.md` with timeline props schema, sample input props and local render commands.
- Add a changelog entry for the new video timeline domain, route and API family.
- Mark `SPEC-remotion-video-editor-workflow-2026-05-11.md` as superseded or linked to this spec during docs cleanup after readiness.
- Update operator/support notes to explain that video editing is online-only in V1, final render requires a non-stale preview and render artifacts may expire according to the render-service retention policy.
- Do not copy Remotion docs into project docs; link official docs and keep local docs focused on ContentGlows contracts.

## Edge Cases

- Content is deleted, archived, moved or changed after a timeline is created.
- The same content is opened in two tabs and both tabs save timeline edits.
- User switches active project while the timeline route is open.
- First timeline generation has no render-safe images; text-only timeline must still be valid if within scope.
- A timeline has only audio/music clips and no visible layer; backend rejects it with `invalid_timeline` and asks for a text, image, video, or background clip.
- Clip duration rounds differently between Flutter display and Remotion frames; backend frame conversion must be deterministic at 30fps.
- A clip starts or ends between frame boundaries.
- Audio clip is shorter or longer than the visible timeline duration.
- Asset is tombstoned after selection but before preview.
- Asset was render-safe when selected but storage descriptor becomes unavailable before render.
- Provider-temporary URL is accidentally sent as an asset descriptor; backend must reject before Remotion props generation.
- Preview job completes but artifact file is missing, zero bytes, expired or has invalid metadata.
- Preview for version A completes after user already saved version B; UI marks it stale and cannot approve it for version B.
- Final render is requested twice quickly for the same approved preview; backend returns existing active/completed final job instead of duplicating where appropriate.
- Worker returns an unknown status or malformed payload.
- Remotion composition selection fails because `inputProps` shape is invalid.
- Timeline duration exceeds 180 seconds after an asset trim or transition update.
- Old storyboard code path tries to create separate scene state.
- Diagnostic logging includes signed artifact URL query strings; logs must redact them.
- License review is not complete before production deployment; release must be blocked or explicitly approved by the operator.

## Execution Batches

Parallel implementation is blocked until Batch 1 locks the backend API/data contract with tests. After Batch 1 passes, Batch 2 Flutter work and Batch 3 worker composition work may run in parallel because their write sets are disjoint, but integration remains sequential.

- Batch 0: Renderer foundation prerequisite
  - Scope: verify or implement `shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md` until `worker/` or an equivalent local worker contract exists with preview/final render job support.
  - Owned files: the files owned by the render-service integration spec, not this timeline spec.
  - Blocks: any implementation of preview/final endpoints that calls a real worker.
  - Acceptance: local worker API or fake-compatible adapter contract is available; render-service tests pass; worker artifact/signing/retention/capacity rules are documented.
  - Shippability: not user-shippable alone; internal foundation.
  - Stop condition: if Remotion licensing, local worker deployment or render artifact storage cannot be made safe, stop before timeline render implementation and route to user decision.

- Batch 1: Backend timeline contract and persistence
  - Scope: timeline models, migration/ensure, store, asset `video_version` validation, renderer adapter interface, props conversion fixtures, API router and backend tests.
  - Owned files: `lab/api/models/video_timeline.py`, `lab/api/services/video_timeline_store.py`, `lab/api/services/video_renderer_adapter.py`, `lab/api/services/remotion_timeline_props.py`, `lab/api/routers/video_timelines.py`, `lab/api/main.py`, `lab/api/routers/__init__.py`, `lab/api/migrations/005_video_timelines.sql` or next, `lab/status/service.py`, `lab/status/schemas.py`, `lab/api/models/status.py`, and focused backend tests.
  - Acceptance: backend tests prove create/load, draft save, immutable version save, conflict handling, validation rejection, asset eligibility, preview/final gating through a fake renderer adapter and render capacity errors.
  - Shippability: internal only unless Flutter route remains hidden/unlinked.
  - Stop condition: if Turso migration/ensure pattern cannot be matched safely or asset validation cannot prove ownership, stop and reroute to readiness correction.

- Batch 2: Flutter editor route and state
  - Scope: Dart timeline models, API methods, Riverpod provider, `/editor/:id/video` route, editor entry action, V1 timeline screen and widget/provider tests.
  - Owned files: `app/lib/data/models/video_timeline.dart`, `app/lib/data/services/api_service.dart`, `app/lib/providers/video_timeline_provider.dart`, `app/lib/providers/providers.dart` only for export/wiring if needed, `app/lib/router.dart`, `app/lib/presentation/screens/editor/video_timeline_screen.dart`, `app/lib/presentation/screens/editor/editor_screen.dart`, `app/lib/presentation/widgets/project_asset_picker.dart` if video-specific invocation support is needed, and focused Flutter tests.
  - Acceptance: route resolves, Sentry sanitizer preserves `/editor/:id/video`, screen loads backend state, asset picker uses `targetType=video_version`, stale preview disables final render, and API diagnostics redact signed artifact URLs.
  - Shippability: user-visible behind existing auth/project context once Batch 1 is live; final render actions remain disabled if Batch 3/worker is unavailable.
  - Stop condition: if backend Batch 1 response shapes change, stop and update Dart models/API before UI expansion.

- Batch 3: Remotion worker timeline composition
  - Scope: Remotion composition for `ContentGlowsTimelineProps`, fixture props, vertical/landscape rendering, audio clipping, text/image/video layer rendering and worker tests/sample render.
  - Owned files: `worker/remotion/ContentGlowsTimelineVideo.tsx`, worker root registration, worker schema/fixtures/tests and worker README examples.
  - Acceptance: sample render or worker tests handle text-only, image+text, video clip, audio/music, vertical and landscape fixtures without importing Remotion Timeline/Editor Starter UI.
  - Shippability: required before preview/final render can be considered complete.
  - Stop condition: if worker directory remains absent after Batch 0, do not invent a partial worker inside Flutter or backend; return to Batch 0.

- Batch 4: Documentation, verification and release gate
  - Scope: app/backend/worker docs, changelog, operator notes, spec trace, verification and bounded ship preparation.
  - Owned files: `app/README.md`, `lab/README.md`, `lab/ENVIRONMENT_shipglows_data/technical/SETUP.md` if present, `worker/README.md`, `CHANGELOG.md` files where local convention requires them and this spec history.
  - Acceptance: docs explain online-only video editing, timeline route, render worker dependency, Turso migration, preview/final gate, retention/capacity rules and Remotion license release gate.
  - Shippability: required before merge/ship.
  - Stop condition: if manual/browser/render proof is incomplete, do not ship user-visible route without explicit risk acceptance.

## Implementation Tasks

- [ ] Tache 1: Prime implementation context and freeze old storyboard direction.
  - Fichier: `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - Action: During implementation kickoff, treat it as superseded by this spec for product direction; do not implement a competing storyboard source of truth.
  - User story link: Prevents two timeline models.
  - Depends on: None.
  - Validate with: Implementation notes reference this spec as canonical before code changes begin.
  - Notes: This task may be documentation-only unless `/sf-ready` requires an explicit status edit.

- [ ] Tache 2: Define backend timeline schemas.
  - Fichier: `lab/api/models/video_timeline.py`
  - Action: Add Pydantic models for format presets, tracks, clips, clip roles, timeline draft, immutable version, preview/final job responses, validation errors and renderer props DTOs.
  - User story link: Establishes the ContentGlows-owned canonical timeline model.
  - Depends on: Tache 1.
  - Validate with: `pytest lab/tests/test_video_timeline_models.py`.
  - Notes: Include schema versioning and 30fps frame conversion helpers or explicit DTO fields.

- [ ] Tache 3: Add Turso/libSQL persistence.
  - Fichier: `lab/api/migrations/005_video_timelines.sql`
  - Action: Create tables and indexes for `video_timelines`, `video_timeline_versions`, and timeline-to-render-job links if not represented on the version row.
  - User story link: Persists one active timeline and immutable versions.
  - Depends on: Tache 2.
  - Validate with: migration/unit tests and a local schema check.
  - Notes: If migration numbering has advanced, use the next available number. Include idempotent startup ensure logic in the same change.

- [ ] Tache 4: Implement timeline store and concurrency.
  - Fichier: `lab/api/services/video_timeline_store.py`
  - Action: Add create/load by content, save draft/version, optimistic concurrency checks, version lookup, stale preview marking and ownership-scoped queries.
  - User story link: Makes timeline saves reliable and prevents stale overwrites.
  - Depends on: Tache 3.
  - Validate with: `pytest lab/tests/test_video_timeline_store.py`.
  - Notes: Store timeline JSON as validated JSON plus indexed owner/project/content/format/version metadata.

- [ ] Tache 5: Implement video version asset validation.
  - Fichier: `lab/status/service.py`
  - Action: Replace the current `video_version target validation is not available` path with ownership checks against the new video timeline/version store and expand eligibility for V1 clip media kinds.
  - User story link: Lets clips use existing project assets safely.
  - Depends on: Tache 4.
  - Validate with: `pytest lab/tests/test_project_assets_service.py`.
  - Notes: Allow still-image clip use cases while keeping local-only/provider-temporary assets out of server renders.

- [ ] Tache 6: Add renderer adapter contract.
  - Fichier: `lab/api/services/video_renderer_adapter.py`
  - Action: Define an internal interface for preview/final render requests, status normalization and artifact metadata independent from Remotion.
  - User story link: Keeps Remotion replaceable behind a stable product boundary.
  - Depends on: Tache 2.
  - Validate with: adapter unit tests using a fake renderer.
  - Notes: The interface should accept immutable timeline version ids or validated props, never mutable drafts.

- [ ] Tache 7: Add Remotion timeline props conversion.
  - Fichier: `lab/api/services/remotion_timeline_props.py`
  - Action: Convert validated ContentGlows timeline versions and render-safe asset descriptors into Remotion `inputProps`.
  - User story link: Produces renderable previews/finals from the canonical timeline.
  - Depends on: Tache 5 and Tache 6.
  - Validate with: fixture tests comparing timeline JSON to expected props.
  - Notes: Enforce 30fps, 180s, format dimensions and no arbitrary URLs.

- [ ] Tache 8: Add video timeline API router.
  - Fichier: `lab/api/routers/video_timelines.py`
  - Action: Implement create/load, save/version, validate, preview, approve preview, final render and job polling endpoints with Clerk auth and project/content ownership.
  - User story link: Exposes the video timeline workflow to Flutter.
  - Depends on: Tache 4, Tache 6 and Tache 7.
  - Validate with: `pytest lab/tests/test_video_timelines_router.py`.
  - Notes: Register the router in `lab/api/main.py` and/or `lab/api/routers/__init__.py` following existing patterns.

- [ ] Tache 9: Extend Remotion worker for timeline props.
  - Fichier: `worker/remotion/ContentGlowsTimelineVideo.tsx`
  - Action: Add a composition that renders normalized timeline tracks/clips for both V1 format presets.
  - User story link: Turns timeline props into MP4 output.
  - Depends on: Tache 7.
  - Validate with: worker tests or sample render using fixture props.
  - Notes: Do not import Remotion Timeline/Editor Starter UI. This is render composition code only.

- [ ] Tache 10: Add Flutter timeline data models.
  - Fichier: `app/lib/data/models/video_timeline.dart`
  - Action: Add Dart models for timeline, version, tracks, clips, validation errors, preview/final job state and format presets.
  - User story link: Lets Flutter represent the canonical timeline contract.
  - Depends on: Tache 2 and Tache 8.
  - Validate with: `flutter test test/data/video_timeline_test.dart`.
  - Notes: Match API JSON exactly and include stale/preview status fields.

- [ ] Tache 11: Add Flutter API methods.
  - Fichier: `app/lib/data/services/api_service.dart`
  - Action: Add typed methods for all video timeline endpoints and redacted diagnostics for signed artifact URLs.
  - User story link: Connects the editor UI to backend timeline operations.
  - Depends on: Tache 10.
  - Validate with: existing ApiService tests or new focused mock tests.
  - Notes: Render/timeline writes are online-only and must not enter the offline queue.

- [ ] Tache 12: Add Flutter timeline provider/notifier.
  - Fichier: `app/lib/providers/video_timeline_provider.dart`
  - Action: Manage load/save/dirty/conflict/preview/final polling state with active project/content guards.
  - User story link: Keeps UI state coherent during editing and polling.
  - Depends on: Tache 11.
  - Validate with: `flutter test test/providers/video_timeline_provider_test.dart`.
  - Notes: If repo conventions require central exports in `providers.dart`, add only the export/wiring there.

- [ ] Tache 13: Add `/editor/:id/video` route and editor entry.
  - Fichier: `app/lib/router.dart`
  - Action: Register the video editor route and sanitize it as `/editor/:id/video` before generic editor routes.
  - User story link: Provides the agreed V1 entry point.
  - Depends on: Tache 12.
  - Validate with: router tests and Sentry sanitizer assertions if available.
  - Notes: Preserve existing `/editor/:id` behavior.

- [ ] Tache 14: Add primary video timeline screen.
  - Fichier: `app/lib/presentation/screens/editor/video_timeline_screen.dart`
  - Action: Build the V1 timeline workspace with tracks, clip blocks, inspector, asset selection, save state, preview player and final render action.
  - User story link: Gives users the single timeline editing surface.
  - Depends on: Tache 12 and Tache 13.
  - Validate with: `flutter test test/presentation/screens/editor/video_timeline_screen_test.dart`.
  - Notes: Keep UI focused and utilitarian. Use existing design patterns and avoid nested card-heavy layout.

- [ ] Tache 15: Integrate asset picker for timeline clips.
  - Fichier: `app/lib/presentation/widgets/project_asset_picker.dart`
  - Action: Ensure the picker can be invoked for timeline clip roles with `targetType=video_version`, allowed media kinds and placement metadata.
  - User story link: Lets users place existing assets on the timeline.
  - Depends on: Tache 5, Tache 12 and Tache 14.
  - Validate with: picker/widget tests covering video_version target context.
  - Notes: Reuse the existing picker; do not create a second asset library.

- [ ] Tache 16: Add editor screen entry action.
  - Fichier: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add a video action that opens `/editor/:id/video` for the current content and preserves project context.
  - User story link: Starts the V1 workflow from existing content.
  - Depends on: Tache 13 and Tache 14.
  - Validate with: `flutter test test/presentation/screens/editor/editor_screen_test.dart`.
  - Notes: Do not remove the existing asset picker action.

- [ ] Tache 17: Add backend integration tests.
  - Fichier: `lab/tests/test_video_timelines_router.py`
  - Action: Cover create/load, save, conflict, preview, stale preview block, final render gate, ownership failures and worker failures.
  - User story link: Proves the core workflow is secure and correct.
  - Depends on: Tache 8.
  - Validate with: `pytest lab/tests/test_video_timelines_router.py`.
  - Notes: Use fake renderer adapter and fake auth/ownership patterns consistent with existing tests.

- [ ] Tache 18: Add docs and changelog updates.
  - Fichier: `lab/README.md`
  - Action: Document timeline API, migration, worker dependency and local validation commands; add matching app/worker docs where those README files exist.
  - User story link: Makes the workflow operable after implementation.
  - Depends on: Tache 8, Tache 9 and Tache 14.
  - Validate with: docs review and `/sf-ready` or `/sf-verify` follow-up checks.
  - Notes: Keep Remotion docs linked rather than copied.

## Acceptance Criteria

- [ ] CA 1: Given an authenticated user owns a content item, when they open `/editor/:id/video`, then ContentGlows creates or loads the active timeline for that content and format.
- [ ] CA 2: Given a user does not own the content, when they open or mutate a video timeline for it, then the API returns `403` or `404` and leaks no timeline or asset metadata.
- [ ] CA 3: Given a timeline draft with valid text/image/video/audio clips under 180 seconds, when the user saves, then the backend creates an immutable version and returns it as current.
- [ ] CA 4: Given a stale client saves over a newer version, when the request includes an old version token, then the backend returns conflict and preserves the newer version.
- [ ] CA 5: Given a render-safe owned image asset, when the user selects it for an image clip, then the backend records a `video_version` usage and the clip references the asset id.
- [ ] CA 6: Given a provider-temporary or local-only asset, when the user tries to use it for server rendering, then selection or render validation fails with a typed recoverable error.
- [ ] CA 7: Given a valid current version, when the user requests preview, then a preview job is created for that exact version and Remotion receives derived props only.
- [ ] CA 8: Given the preview job completes, when Flutter polls the job, then the preview player receives a signed MP4 artifact URL and marks it current.
- [ ] CA 9: Given the user edits after preview completion, when the UI reloads status, then the old preview is marked stale and final render is disabled.
- [ ] CA 10: Given a current completed preview is approved, when the user requests final render, then a separate final job is created and linked to the preview/version.
- [ ] CA 11: Given the same final render is requested twice quickly, when an active/completed final job already exists for the same approved preview, then the backend returns the existing job or a deterministic conflict according to the API contract.
- [ ] CA 12: Given a timeline duration exceeds 180 seconds or uses an unsupported preset, when the user saves or previews, then validation rejects it before the worker is called.
- [ ] CA 13: Given the Remotion worker is unavailable, when preview/final is requested, then the job becomes failed or the request returns a recoverable error without changing timeline validity.
- [ ] CA 14: Given a signed artifact URL expires, when Flutter refreshes job status, then it receives a fresh URL if the user still owns the resource.
- [ ] CA 15: Given an old storyboard route or future simplified mode edits video structure, when it saves, then it uses the same timeline/version API and does not create a second model.
- [ ] CA 16: Given a timeline has only audio or music clips, when the user saves or previews, then validation rejects it with `invalid_timeline` until a visible text, image, video, or background clip is present.
- [ ] CA 17: Given a completed owned render job, when Flutter polls the job, then the API returns a short-lived `artifact.playback_url` and diagnostics/provider state do not persist or log its token.

## Test Strategy

- Backend unit tests for Pydantic schema validation, 30fps frame conversion, max duration, clip overlap rules and Remotion props conversion.
- Backend store tests for create/load active timeline, immutable versions, optimistic concurrency, stale preview marking and migration/ensure behavior.
- Backend router tests for Clerk auth, project/content ownership, asset ownership, asset eligibility, preview/final gating and sanitized errors.
- Project asset service tests for `video_version` target ownership and media-kind eligibility changes.
- Worker tests or sample renders for text-only, image+text, video clip, audio/music and landscape/vertical fixtures.
- Flutter model tests for JSON parse/serialize and stale/preview/final state mapping.
- Flutter provider tests for load/save conflict handling, active project changes, polling, stale preview and expired artifact refresh.
- Flutter widget tests for `/editor/:id/video`, timeline blocks, asset picker invocation, preview player status and disabled final-render states.
- Manual QA after implementation: create timeline from existing content, add image clip, request preview, edit after preview, confirm final blocked, re-preview, approve, final render, switch project mid-poll, verify no cross-project data appears.

## Risks

- Scope creep: a real timeline can expand into a professional editor. V1 must stay focused on content-linked social video assembly.
- Render latency: server MP4 preview is reliable but slower than interactive preview. Mitigation: explicit preview action, clear status and future local thumbnail/scrub enhancements.
- Data migration risk: missing Turso tables can break the route even when app UI exists. Mitigation: migration plus startup ensure in the same implementation.
- Asset eligibility risk: existing video_version action is named but intentionally not implemented yet. Mitigation: implement and test it before UI selection.
- Renderer coupling risk: Remotion props can accidentally become the product model. Mitigation: keep adapter/props conversion separate from timeline schemas.
- Security risk: arbitrary media URLs or signed tokens could leak through logs. Mitigation: ids-only API, server descriptors and diagnostics redaction tests.
- Stale preview risk: final render from an old preview would break user trust. Mitigation: immutable versions and exact preview/version gating.
- Performance risk: large timelines or many assets can slow Flutter and backend validation. Mitigation: 180s limit, pagination and explicit preview renders.
- License risk: Remotion commercial terms may affect rollout. Mitigation: explicit license review before production release.
- Product coherence risk: old storyboard specs and future AI features may create competing state. Mitigation: this spec is canonical; future modes must attach to the same timeline.

## Execution Notes

- Start by reading `app/CLAUDE.md`, `lab/CLAUDE.md`, this spec, the renderer boundary exploration report, `remotion-render-service-integration.md` and `SPEC-unified-project-asset-library-2026-05-11.md`.
- Execute Batch 0 before any real preview/final render work if the render-service integration is not already implemented locally. The timeline backend can use a fake renderer adapter for tests, but user-visible preview/final success requires the render-service foundation.
- Implement backend foundations before Flutter UI: schemas, migration, store, asset validation, adapter and router. The UI depends on stable API contracts.
- Do not run parallel implementation until Batch 1 passes. After Batch 1, Flutter Batch 2 and worker Batch 3 may run in parallel only if their write ownership stays disjoint.
- Use the existing ContentGlows patterns: FastAPI auth/ownership checks, Turso/libSQL migrations/ensures, Riverpod providers, GoRouter routes and Dio diagnostics redaction.
- Do not introduce Remotion Timeline/Editor Starter or a React editor UI. Use Remotion only for render composition and server-side render execution.
- Keep render preview online-only and user-triggered. Do not route timeline saves or renders through offline replay in V1.
- Enforce render capacity and props-size limits before dispatching a worker job. Do not rely on Flutter button disablement as the anti-abuse boundary.
- Treat signed artifact URLs as ephemeral response data. Do not store them in durable timeline/version rows, do not include query tokens in logs, and add tests for diagnostics redaction where Flutter touches `artifact.playback_url`.
- Validation commands expected after implementation:
  - `pytest lab/tests/test_video_timeline_models.py lab/tests/test_video_timeline_store.py lab/tests/test_video_timelines_router.py lab/tests/test_project_assets_service.py`
  - `flutter test test/data/video_timeline_test.dart test/providers/video_timeline_provider_test.dart test/presentation/screens/editor/video_timeline_screen_test.dart test/presentation/screens/editor/editor_screen_test.dart`
  - Worker package tests or a sample render command from `worker` once the worker exists locally.
- Turso migration required: yes. This feature adds durable timeline/version storage that cannot safely live only in `JobStore`.
- Stop and reroute to `/sf-explore` or user decision if implementation discovers that Remotion licensing, deployment constraints or worker maturity make V1 production use unacceptable.

## Open Questions

None blocking for V1. The preview decision is fixed here as: server-rendered Remotion MP4 is the source of truth for preview/final gating; interactive in-app preview can be added later as a convenience layer if it reads from the same ContentGlows timeline and never becomes a second renderer authority.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-14 15:27:39 UTC | sf-spec | GPT-5 Codex | Created unified video timeline spec from renderer-boundary exploration and user decisions | Draft saved | /sf-ready Unified ContentGlows Video Timeline |
| 2026-05-14 15:41:42 UTC | sf-ready | GPT-5 Codex | Initial readiness pass before adversarial review | not ready | /sf-spec Unified ContentGlows Video Timeline |
| 2026-05-14 15:46:55 UTC | sf-build | GPT-5 Codex with GPT-5.5 xhigh review | Stopped premature implementation and added execution batches, API contract, data/render contract and anti-abuse constraints | rerouted | /sf-ready Unified ContentGlows Video Timeline |
| 2026-05-14 15:52:48 UTC | sf-build | GPT-5 Codex with GPT-5.5 xhigh review | Resolved artifact playback and audio-only timeline readiness blockers | rerouted | /sf-ready Unified ContentGlows Video Timeline |
| 2026-05-14 15:54:00 UTC | sf-ready | GPT-5.5 xhigh review | Focused re-review confirmed no remaining blockers for execution batches, worker prerequisite, API/data/render contract, signed playback URLs, audio-only rejection and anti-abuse controls | ready | /sf-start Unified ContentGlows Video Timeline |
| 2026-05-14 16:10:00 UTC | sf-start | GPT-5.3 Codex implementation | Executed Batch 0 render-service prerequisite: worker package, reel render-job API, signed local artifacts, retention/capacity rules and focused tests | implemented foundation | Batch 1 backend timeline |
| 2026-05-14 16:30:00 UTC | sf-start | GPT-5 Codex with GPT-5.5 xhigh review | Executed Batch 1 backend timeline contract: migration/store/models/router, video_version asset validation, props conversion, renderer adapter boundary and focused tests | backend batch implemented and tests passing | Batch 2 Flutter and Batch 3 worker |
| 2026-05-14 16:44:00 UTC | sf-start | GPT-5.3 Codex implementation | Executed Batch 2 Flutter route/models/provider/screen and Batch 3 Remotion timeline composition with backend adapter wiring and worker duration limit lifted to 180s | integrated implementation; Node runtime smoke still pending because worker dependencies are absent | /sf-verify Unified ContentGlows Video Timeline |
| 2026-05-14 17:35:30 UTC | sf-verify | GPT-5 Codex | Verified the unified timeline implementation against the spec contract, dependency spec, focused backend and Flutter checks, worker smoke availability, and Remotion official docs freshness gate | partial: backend skeleton and local app checks pass, but asset-to-Remotion resolution/usages, real Flutter editing controls, worker runtime proof, real MP4 smoke, and app/backend docs remain incomplete | /sf-start Unified ContentGlows Video Timeline |
| 2026-05-14 18:15:51 UTC | sf-build | GPT-5 Codex with delegated workers | Closed partial verify gaps for render readiness: backend asset resolution and usage auditing, Flutter editable timeline controls, worker dependency lock/runtime checks, MP4 smoke fixture, docs and changelog updates | implemented; local checks passing, ready for verification | /sf-verify Unified ContentGlows Video Timeline |
| 2026-05-14 18:27:00 UTC | sf-verify | GPT-5.5 xhigh subagent | Re-verified backend asset resolution, Flutter timeline editability, worker Remotion runtime proof, docs, and ship readiness | partial: local core verified, but final provider dirty-draft guard, Flutter provider/diagnostics tests, worker git hygiene, deployed Cloud Run/GCS proof, and clean ship scope remained incomplete | /sf-build corrective pass |
| 2026-05-14 18:32:37 UTC | sf-build | GPT-5 Codex | Added final-render dirty-draft guard, provider tests for dirty final and playback URL refresh, diagnostics redaction test for signed playback URLs, worker .gitignore, and reran local backend/app/worker checks plus MP4 smoke | partial: local implementation verifies, but production durable renderer deployment/E2E proof and unrelated dirty worktree still block sf-end/sf-ship | /sf-spec Remotion Cloud Run GCS render deployment for ContentGlows video timeline |

## Current Chantier Flow

- sf-spec: done
- sf-ready: done
- sf-start: launched; Batches 0, 1, 2 and 3 implemented locally; sf-build follow-up closed local gaps for asset resolution, UI edit controls, worker runtime proof, MP4 smoke, dirty-draft final guard, signed URL diagnostics redaction and docs
- sf-verify: partial; local backend, Flutter and worker proof pass, but no deployed durable renderer proof exists yet
- sf-end: blocked by missing Cloud Run/GCS or equivalent production render-service proof
- sf-ship: blocked by missing deployed E2E proof and unrelated dirty worktree entries outside this chantier
- Prochaine commande: `/sf-spec Remotion Cloud Run GCS render deployment for ContentGlows video timeline`
