---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: "contentglows"
created: "2026-05-11"
created_at: "2026-05-11 17:20:22 UTC"
updated: "2026-08-07"
updated_at: "2026-08-07 19:12:55 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que créatrice ContentGlows authentifiée travaillant dans un projet, je veux retrouver et réutiliser tous les assets de projet utiles aux contenus, images IA, vidéos, audio, musiques, thumbnails et fonds animés, afin de garder une production cohérente sans dupliquer les fichiers ni sortir du workflow guidé."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "worker"
  - "content_assets"
  - "Image Robot"
  - "AI visual references"
  - "Remotion video editor"
  - "AI audio/music generation"
  - "Bunny Storage/CDN"
  - "Turso/libSQL"
  - "Clerk"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-project-visual-asset-library-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md"
    artifact_version: "1.0.0"
    required_status: "active"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "Bunny Storage API"
    artifact_version: "official docs checked 2026-05-11: https://docs.bunny.net/api-reference/storage"
    required_status: "active"
supersedes: []
evidence:
  - "User selection 2026-05-11: after AI audio/video editor spec, next spec should be the asset library foundation."
  - "User decision 2026-05-11: assets are project assets first, then optionally linked to one content item and one or more placements."
  - "User decision 2026-05-11: no human approval step for asset promotion in V1."
  - "User decision 2026-05-11: removed assets keep 30 days of history and are blocked from future reuse."
  - "User decision 2026-05-11: the app should guide users through content formats instead of offering free playgrounds."
  - "Spec evidence: SPEC-project-visual-asset-library-2026-05-11 is ready but focuses on visual/image assets."
  - "Spec evidence: SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11 adds audio, music and animated background assets to video versions."
  - "Code evidence: lab/status/db.py creates content_assets with content_id, project_id, user_id, source, kind, mime_type, duration, storage_uri, status, metadata and deleted_at."
  - "Code evidence: lab/status/service.py currently lists and mutates content-scoped assets but has no unified project asset inventory across media kinds."
  - "Code evidence: lab/api/routers/status.py exposes /api/status/content/{content_id}/assets with owned-content checks."
  - "Code evidence: app/lib/data/services/api_service.dart attaches local capture metadata but has no typed cross-media asset-library client."
  - "Code evidence: app/lib/providers/providers.dart centralizes app state and active project scoping with Riverpod."
  - "Fresh docs checked 2026-05-11: Bunny Storage API official docs define server-side storage-zone API behavior and AccessKey authentication; this spec uses server-owned Bunny URLs only."
next_step: "/sf-start Unified Project Asset Library workflow integrations"
---

# Title

Unified Project Asset Library

## Status

Ready. This spec defines the cross-media project asset library that sits above the visual picker, upload/reference, Image Robot, video editor, and AI audio/music specs. It does not replace those specs; it normalizes their outputs into one backend-owned inventory so project assets can be found, governed, reused and audited across content workflows. Contract version 1.1 adds the bounded canonical asset-category slice: stable locale-neutral IDs, localized catalog labels, original filename preservation and safe export-name suggestions are implemented without changing the broader cross-media delivery status.

## User Story

En tant que créatrice ContentGlows authentifiée travaillant dans un projet, je veux retrouver et réutiliser tous les assets de projet utiles aux contenus, images IA, vidéos, audio, musiques, thumbnails et fonds animés, afin de garder une production cohérente sans dupliquer les fichiers ni sortir du workflow guidé.

## Minimal Behavior Contract

For an authenticated creator inside an owned project, ContentGlows exposes a unified project asset library that lists and filters server-known assets across media types, including generated images, uploaded references, local-only captures, thumbnails, video covers, narration tracks, music beds, Remotion background configs and future render artifacts. The library returns only owned, safe metadata plus backend-approved preview/playback URLs, lets editor-linked flows pick or reuse eligible assets for a content placement or video version, and lets users tombstone assets from future reuse while preserving 30-day history and existing provenance. If ownership, eligibility, storage, source metadata, stale version, or media-kind compatibility fails, the action is rejected with a recoverable typed error and no downstream publish/render state changes. The edge case easy to miss is treating this as a public DAM or upload playground: V1 is a project-scoped, workflow-guided inventory and picker layer, not a public media browser or a generic file manager.

Category metadata uses a small backend-owned, versioned ContentGlows registry rather than a broad sound-library taxonomy. `category_id` and optional `subcategory_id` are stable, locale-neutral identifiers; English and French labels are presentation data returned by the catalog endpoint. A category is one deliberate organizational assignment and is distinct from the many AI-generated semantic tags in asset understanding. The backend preserves `original_file_name`, never rewrites stored objects to enforce a naming convention, and returns a traversal-safe `suggested_export_file_name` for optional export use.

## Success Behavior

- Given an authenticated creator owns a project, when they open an asset picker or asset panel from an editor/video/generation workflow, then the backend returns only assets owned by that project and user scope.
- Given the project contains image, audio, music, video-cover, local-capture, generated-reference, background-config, and render-output records, when the creator filters by media kind, source, placement, content usage, generation provider, status, eligibility, created date, updated date, or tag, then results are deterministic and paginated.
- Given an asset has one or more usages, when the creator opens asset detail, then the response shows linked content records, video project versions, placements, primary/candidate state, stale state, publish/render relevance, and last used timestamps.
- Given an asset is eligible for a requested placement or video version, when a workflow selects it, then the backend creates or updates a server-side usage link and invalidates any stale preview/publish/render state that depends on the previous asset selection.
- Given an image asset is eligible as a visual reference, when promoted, then the existing visual-reference flow records `source_asset_id` and keeps project ownership/provenance.
- Given an audio or music asset is eligible for a video version, when selected, then the video version references the asset by server id and Remotion receives only backend-resolved URLs or descriptors.
- Given a local-only capture is present, when listed in the library, then it is clearly marked as local-only and cannot be used for server-side publish/render/reference actions until an upload/reference spec makes it durable.
- Given an asset is tombstoned, when future list/search/picker calls run, then default results hide it and new usage is blocked while existing usage/provenance remains readable for 30 days.
- Given an existing content still uses a tombstoned asset, when the user opens its usage detail, then the system shows historical usage and requires a replacement before future publish/render if the placement needs a durable active asset.
- Given storage metadata is durable, when previews are returned, then images use backend-approved Bunny/CDN/proxy URLs, audio uses signed or render-safe playback URLs, and procedural backgrounds use schema-validated configs rather than arbitrary code.
- Given the category registry is requested in English or French, when the catalog is returned, then the same stable category/subcategory IDs are paired with localized labels and one explicit registry version.
- Given a creator assigns or clears a category, when the mutation succeeds, then exact project/user-scoped category filters reflect it and AI understanding tags are unchanged.
- Given an asset has an unsafe, accented or path-like original filename, when its API representation is returned, then the original value remains preserved while `suggested_export_file_name` is portable, contains no path traversal, and keeps only a safe extension.

## Error Behavior

- Missing Clerk auth returns `401` and exposes no asset metadata.
- A foreign, missing, archived-without-access, or cross-project asset/project/content/video id returns `403` or `404` without leaking names, prompts, storage paths, provider request ids or signed URLs.
- Missing `project_id` or unsupported filters return `400` with supported filter names; the backend must not silently broaden the result set.
- Unknown category IDs, a subcategory without a category, or a subcategory outside its parent category return `400` and do not mutate the asset.
- Selecting an asset for an incompatible placement, media kind, aspect ratio, duration, source, storage state, or video version returns a typed eligibility error and makes no usage mutation.
- Selecting a `local_only`, failed, deleted, tombstoned, foreign, provider-temporary, or stale asset for publish/render/reference use is rejected server-side.
- If two requests race to set a primary asset for the same content placement or video placement, the backend leaves at most one primary link or returns a conflict requiring refresh.
- If Bunny metadata is missing or the object cannot be verified, the asset can appear only in a degraded detail state; it cannot be newly selected for publish/render until storage is repaired.
- If a tombstone or usage update fails after partial mutation, the backend records a recoverable repair state and never hides the inconsistency from the owning user/operator.
- If a signed preview/playback URL expires, the UI refreshes asset detail or media status instead of displaying tokens or persisting expired URLs.
- If active project/content/video context changes while a list or mutation is in flight, Flutter ignores stale responses and clears context-specific selection state.
- What must never happen: cross-project asset visibility, client-side permission filtering as the only boundary, arbitrary public URL ingestion, provider secrets in responses/logs, raw signed URL tokens in diagnostics, physical Bunny deletion without retention policy, or a final publish/render using a stale/tombstoned asset.

## Problem

ContentGlows already has multiple asset concepts that are correct in isolation but not unified: content-scoped `content_assets`, local-only captures, AI-generated image candidates, uploaded visual references, video covers, Remotion video versions, AI narration tracks, music beds, and procedural animated backgrounds. The existing ready `Project Visual Asset Picker Library` covers visual/image reuse, but the product direction now needs a broader asset foundation so the app can reason consistently about every project asset used by content and video workflows. Without a unified contract, each feature will invent its own eligibility, tombstone, storage, usage and picker rules.

## Solution

Create a backend-owned unified project asset domain that indexes all reusable project media and media-like configs with typed media kinds, sources, storage descriptors, usage links, eligibility rules, tombstone/history semantics and picker APIs. Flutter consumes that domain through typed models/providers and editor-linked picker panels; generation, upload, image, video and audio specs remain owners of asset creation, while this spec owns cross-media discovery, reuse, governance and usage audit.

## Scope In

- Unified project asset inventory across images, uploaded references, local captures, thumbnails, video covers, audio narration, music beds, Remotion background configs and render artifacts.
- Small versioned canonical category registry with stable category/subcategory IDs and localized English/French labels.
- Exact category/subcategory filtering, user assignment/clearing, original filename preservation and backend-generated safe export-name suggestions.
- Backend-owned project-level list, search, filter, detail, usage, selection, primary/candidate, tombstone, restore-within-history-window, and eligibility APIs.
- Media kind taxonomy for `image`, `audio`, `music`, `video`, `thumbnail`, `video_cover`, `background_config`, `render_output`, `capture`, and future-safe extension.
- Source taxonomy for `device_capture`, `image_robot`, `manual_upload`, `visual_reference`, `video_audio_ai`, `video_music_ai`, `remotion_background`, `remotion_render`, `reels_import`, and future backend-safe sources.
- Usage model linking one asset to zero or more contents, placements, video project versions, render jobs, generation references or project references.
- Eligibility rules by action: `select_for_content`, `set_primary`, `promote_reference`, `select_for_video_version`, `use_in_remotion_render`, `publish_media`, `preview_only`, and `historical_only`.
- Project-scoped picker APIs reusable by editor-linked AI visuals, video editor audio/music/backgrounds, Remotion render workflow and future upload/import flows.
- 30-day tombstone/history window for removed assets before cleanup eligibility.
- Degraded storage states for missing Bunny object, expired signed URL, provider-temporary URL, local-only file, and orphan metadata.
- Flutter typed models, `ApiService` methods, Riverpod controller, and reusable asset picker/detail components.
- Tests for auth, ownership, pagination, filters, media-kind compatibility, selection, primary conflict, tombstone/history, storage degradation, stale context and diagnostics redaction.
- Documentation updates describing the difference between asset library, visual picker, upload/reference, Image Robot generation and Remotion media selection.

## Scope Out

- Building a standalone public DAM, marketplace, or public media browser.
- Arbitrary public URL import.
- Free-form provider playground controls.
- Binary upload implementation itself; upload remains owned by `SPEC-ai-visual-reference-upload-advanced-2026-05-11.md` or future upload specs.
- Audio/music generation itself; generation remains owned by `SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`.
- Image generation itself; generation remains owned by `SPEC-flux-ai-provider-image-robot-2026-05-11.md` and editor-linked AI visuals specs.
- Full Remotion timeline editing or render worker implementation.
- Physical Bunny object deletion as default V1 behavior.
- Cross-project shared brand libraries, team roles, approvals, licensing registry, folders, comments, bulk transformations, or legal rights guarantees.
- Rewriting existing content publish providers.
- Offline binary replay or offline media upload.

## Constraints

- `lab` is the source of truth for asset metadata, ownership checks, usage links, tombstones and eligibility.
- Every library operation is project-scoped and Clerk-authenticated.
- Existing project ownership remains the V1 permission model unless a separate roles spec is ready before implementation.
- `content_assets` compatibility must be preserved; existing capture metadata and content-scoped routes cannot break.
- Existing `file_name` behavior remains compatible; `original_file_name` is preserved separately and category assignment never renames a stored object.
- Canonical category IDs are backend-owned and versioned. Localized labels and AI semantic tags must not be persisted into `category_id` or `subcategory_id`.
- Asset creation remains delegated to owner features; this library should not create generated image/audio/video outputs by itself.
- Client requests pass asset ids, project ids, content ids, video ids, placement ids and guided actions, not arbitrary URLs or trusted metadata claims.
- Storage URLs returned to Flutter must be backend-approved, redacted in diagnostics, and refreshed rather than persisted as authority.
- `local_only` assets remain preview/history metadata unless explicitly uploaded through a durable backend path.
- Default list/search must hide tombstoned assets; detail/history can expose them only to owning users.
- Search/filter must be paginated and indexed; no unbounded project media dump.
- Remotion props must consume only selected backend-validated asset descriptors, not raw library rows.
- Existing publish hardening requirements remain: publish must validate selected media server-side against owned assets/generation records.

## Dependencies

- Ready visual asset picker foundation: `shipglows_data/workflow/specs/SPEC-project-visual-asset-library-2026-05-11.md`.
- Ready visual upload/reference foundation: `shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md`.
- Ready editor AI visuals UI: `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`.
- Ready Flux/Image Robot provider foundation: `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`.
- Ready video editor audio/music/backgrounds: `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`.
- Ready Remotion video editor workflow: `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`.
- Existing local capture contract: `shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md`.
- Existing backend files:
  - `lab/status/db.py`
  - `lab/status/schemas.py`
  - `lab/status/service.py`
  - `lab/api/models/status.py`
  - `lab/api/routers/status.py`
  - `lab/api/dependencies/auth.py`
  - `lab/api/dependencies/ownership.py`
- Existing Flutter files:
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/data/models/capture_asset.dart`
  - `app/lib/data/models/capture_content_link.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
- External docs:
  - `fresh-docs checked`: Bunny Storage API official docs at `https://docs.bunny.net/api-reference/storage`.
  - `fresh-docs checked`: Bunny Storage HTTP API official docs at `https://docs.bunny.net/storage/http`.
  - No additional external docs are required to draft the library domain because most behavior is local metadata, auth, Turso and existing specs; implementation must re-check provider docs when coding storage upload/delete, provider generation or Remotion runtime behavior.

## Invariants

- Every asset belongs to exactly one project in V1.
- Every response is ownership-filtered before search/filter/pagination logic.
- Every action checks both asset ownership and target content/video/project ownership.
- A library asset can exist without current content usage, but publish/render assets must be linked through server-validated usage actions.
- A usage link must name an action context, target type, target id, placement, state and version when applicable.
- Candidate assets never publish or render until selected through a server-side action.
- Primary selection is unique per target and placement.
- Tombstoned assets cannot be newly selected, promoted, published or rendered.
- Historical usages and generation provenance remain readable during the 30-day history window.
- Physical binary deletion is separate from tombstone and requires a cleanup/retention policy.
- Provider output URLs are never treated as durable library state until the backend stores or validates a durable Bunny/proxy storage descriptor.
- Procedural background configs are assets only when schema-validated and allowlisted; they are not executable code.
- Flutter cache and UI state are never a permission boundary.
- Category assignment is single-valued organizational metadata; AI understanding tags remain separately many-valued, confidence-bearing suggestions.
- Export filename suggestions are convenience metadata only. They never become a storage locator, overwrite the original filename, or grant file access.

## Links & Consequences

- `lab/status/db.py`: needs project asset library tables or companion indexes beyond content-scoped `content_assets`.
- `lab/status/schemas.py`: needs typed project asset, usage, source, media kind, eligibility and tombstone models.
- `lab/status/service.py`: needs project-level asset queries and mutations that preserve existing content asset behavior.
- `lab/api/models/status.py`: needs request/response models for list/search/detail/usage/selection/tombstone/restore actions.
- `lab/api/routers/status.py`: current content-scoped routes should remain; unified library routes may live in a dedicated router if status router becomes too broad.
- `app/lib/data/services/api_service.dart`: needs typed API calls and diagnostics redaction for signed/storage URLs.
- `app/lib/providers/providers.dart`: needs scoped Riverpod controller for project asset query state, active filters, selection and stale-response rejection.
- Editor AI visuals, video editor audio/music/backgrounds and Remotion render specs should call this shared library contract for picking/reuse instead of inventing parallel pickers.
- Documentation must avoid promising a standalone public media library, full DAM, legal rights guarantee, or cross-project brand library.

## Documentation Coherence

- Update `lab/README.md` or API docs with unified asset endpoints, media kinds, sources, eligibility states, tombstone/history semantics and security model.
- Update `app/README.md` after UI implementation with picker entry points and offline limitations.
- Update Image Robot docs to say generated/selected assets enter the unified project library.
- Update Remotion/video editor docs to say selected audio/music/background/video cover assets are referenced through the project asset library.
- Update local capture docs to explain local-only captures may appear as limited historical/picker metadata but are not server-publishable until uploaded.
- Add changelog entries when the backend API and UI ship.
- User-facing copy in Flutter must use the app localization system and natural accented French where French strings are added.

## Edge Cases

- Project has zero assets.
- Project has thousands of assets across many media kinds.
- Asset exists in `content_assets` but has no project-level library row yet.
- Project-level library row exists but the underlying Bunny object is missing.
- A local-only capture exists on one device and the library is opened from another device.
- A generated image has provider metadata but no durable storage URI.
- Audio duration no longer matches a video version after scene timing changes.
- A music asset is tombstoned while it is still historical provenance for a final render.
- A Remotion background config is valid for vertical but invalid for landscape.
- Two sessions set different primary assets for the same placement.
- Asset is attached to multiple content records with different placement states.
- Asset is selected, then active project changes while polling or saving.
- Signed preview URL expires during playback.
- Tombstone happens while an editor picker is open.
- A stale picker tab attempts to use an asset after it was deleted or replaced.
- Provider returns duplicate assets pointing to the same Bunny object.
- A client forges metadata to mark a local-only, foreign, failed or tombstoned asset as eligible.

## Implementation Tasks

- [ ] Task 1: Define unified asset domain schemas
  - Fichier : `lab/status/schemas.py`
  - Action : Add typed models/enums for project asset media kind, source, storage descriptor, preview descriptor, usage target, placement, eligibility, tombstone state, history window and degraded state.
  - User story link : Establishes one contract for finding and reusing all project assets.
  - Depends on : Existing `ContentAssetRecord` compatibility.
  - Validate with : Python schema tests for enum validation, optional media fields, unknown source rejection and compatibility conversion from content assets.
  - Notes : Do not replace `ContentAssetRecord`; build a project asset model that can reference or wrap existing records.

- [ ] Task 2: Add unified asset persistence and indexes
  - Fichier : `lab/status/db.py`
  - Action : Add idempotent Turso/libSQL tables or companion columns for `project_assets`, `project_asset_usages`, `project_asset_events`, storage descriptors, tombstones, primary uniqueness and cleanup eligibility.
  - User story link : Makes cross-media library queries fast, durable and auditable.
  - Depends on : Task 1.
  - Validate with : migration tests on empty DB and DB containing existing `content_assets` rows.
  - Notes : Keep migration-safe startup behavior; no destructive schema changes.

- [ ] Task 3: Backfill/normalize existing content assets
  - Fichier : `lab/status/service.py`
  - Action : Add service logic to normalize existing `content_assets` rows into project asset records or virtual rows for library listing without breaking current content-scoped routes.
  - User story link : Makes current captures and attached assets visible in the new library.
  - Depends on : Tasks 1-2.
  - Validate with : service tests for local-only capture, uploaded image, deleted asset, missing project id and duplicate client asset id.
  - Notes : Existing rows remain source-compatible; no broad rewrite required in V1.

- [ ] Task 4: Implement project asset query service
  - Fichier : `lab/status/service.py`
  - Action : Add `list_project_assets`, `search_project_assets`, `get_project_asset_detail`, `get_project_asset_usage`, `get_project_asset_events` and deterministic pagination/filter handling.
  - User story link : Lets creators retrieve the right assets across workflows.
  - Depends on : Tasks 1-3.
  - Validate with : service tests for ownership scope, filters, pagination, sort stability, degraded storage and tombstone visibility.
  - Notes : Ownership filtering must happen before search/filter logic.

- [ ] Task 5: Implement asset eligibility and usage mutation service
  - Fichier : `lab/status/service.py`
  - Action : Add server-side actions for select, set primary, clear candidate, promote reference through existing visual reference flow, select for video version, tombstone, restore within 30 days and mark cleanup eligible.
  - User story link : Lets workflows safely reuse assets without duplicating rules.
  - Depends on : Task 4.
  - Validate with : tests for incompatible media kind, foreign target, local-only rejection, primary conflict, stale video version, tombstone and restore.
  - Notes : If video project storage is not implemented yet, define the method boundary and stop at integration stubs until the video spec supplies actual persistence.

- [ ] Task 6: Add API models for unified asset operations
  - Fichier : `lab/api/models/status.py`
  - Action : Add request/response models for asset list filters, detail, usage, eligibility result, select request, primary request, tombstone request, restore request and preview URL refresh.
  - User story link : Gives Flutter a typed API contract for the asset library.
  - Depends on : Tasks 1 and 5.
  - Validate with : Pydantic model tests for invalid filters, bad target type, bad placement, bad pagination and unsafe URL fields.
  - Notes : Responses must not expose raw provider payloads, Bunny AccessKey, signed token internals or local file paths.

- [ ] Task 7: Expose authenticated project asset routes
  - Fichier : `lab/api/routers/assets.py`
  - Action : Add `/api/projects/{project_id}/assets` routes for list/search/detail/usage/eligibility/select/primary/tombstone/restore/preview-refresh, with Clerk auth and project ownership checks.
  - User story link : Provides the shared backend boundary consumed by editor and video workflows.
  - Depends on : Tasks 4-6.
  - Validate with : router tests for 401, 403/404, invalid filters, foreign asset, successful selection, conflict and tombstone.
  - Notes : Register the router in `lab/api/routers/__init__.py` and `lab/api/main.py`.

- [ ] Task 8: Add storage descriptor verification helpers
  - Fichier : `lab/api/services/project_asset_storage.py`
  - Action : Add helpers to classify durable Bunny URLs, signed playback/preview URLs, provider-temporary URLs, local-only files, missing objects and render-safe descriptors.
  - User story link : Prevents unsafe assets from being reused in publish/render.
  - Depends on : Tasks 1 and 5.
  - Validate with : mocked Bunny/storage tests for valid URL, expired signed URL, provider URL, missing object and redaction.
  - Notes : This service should not upload binaries; upload remains in upload/reference specs.

- [ ] Task 9: Connect image generation and visual references to unified library
  - Fichier : `lab/api/routers/images.py`
  - Action : Ensure generated image results and promoted visual references upsert or link unified project asset records with generation id, provider, profile, prompt summary/hash, storage descriptor and reference eligibility.
  - User story link : Makes image assets reusable outside the original generation session.
  - Depends on : Tasks 4-8 and Image Robot implementation.
  - Validate with : integration tests using mocked generation completion and reference promotion.
  - Notes : Do not return provider temporary URLs as library storage.

- [ ] Task 10: Connect video/audio/media generation to unified library
  - Fichier : `lab/api/routers/videos.py`
  - Action : Ensure generated narration, music beds, video covers, Remotion backgrounds and render artifacts create or reference unified project asset records and usage links.
  - User story link : Makes video editor media discoverable and reusable through the same project library.
  - Depends on : Tasks 4-8 and video/audio spec implementation.
  - Validate with : tests for audio/music/background asset registration, stale version and selected media usage.
  - Notes : If `videos.py` does not exist yet, apply this to the router/service introduced by the video specs.

- [ ] Task 11: Add Flutter unified asset models
  - Fichier : `app/lib/data/models/project_asset.dart`
  - Action : Add typed Dart models for project asset, media kind, source, storage/preview descriptor, usage entry, eligibility, tombstone, filters and paginated responses.
  - User story link : Lets Flutter consume the library safely across editor surfaces.
  - Depends on : Task 6.
  - Validate with : Dart model tests for JSON parsing, unknown enum fallback, signed URL redaction and degraded states.
  - Notes : Keep models independent from `CaptureAsset`; bridge local captures through response mapping.

- [ ] Task 12: Add Flutter API service methods
  - Fichier : `app/lib/data/services/api_service.dart`
  - Action : Add typed methods for listing/searching assets, loading detail/usage, selecting for target, setting primary, tombstoning/restoring and refreshing preview URLs.
  - User story link : Gives app workflows one client boundary for asset reuse.
  - Depends on : Tasks 7 and 11.
  - Validate with : ApiService tests for request serialization, error mapping, pagination and diagnostics redaction.
  - Notes : Do not add ad hoc Dio calls from widgets.

- [ ] Task 13: Add Riverpod asset library controller
  - Fichier : `app/lib/providers/providers.dart`
  - Action : Add scoped state for active project asset filters, query results, detail, usage, mutations, stale response rejection and cache invalidation after selection/tombstone.
  - User story link : Keeps asset UI coherent when projects and workflows change.
  - Depends on : Task 12.
  - Validate with : provider tests for active project changes, filter changes, mutation refresh, stale responses and offline/degraded reads.
  - Notes : Split into a dedicated provider file during implementation if local patterns make that cleaner.

- [ ] Task 14: Add reusable picker/detail UI components
  - Fichier : `app/lib/presentation/widgets/project_asset_picker.dart`
  - Action : Build reusable list/filter/detail/usage/action components for editor-linked and video-linked pickers, with compact responsive layouts and media-specific previews.
  - User story link : Lets users find and reuse assets without a free playground.
  - Depends on : Task 13.
  - Validate with : widget tests for empty state, filters, degraded asset, local-only asset, eligible selection, tombstone and mobile layout.
  - Notes : V1 may expose these components from existing editor/video surfaces, not as a global nav item unless a later product decision changes navigation.

- [ ] Task 15: Integrate picker into existing workflows
  - Fichier : `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action : Add entry points or replace per-feature pickers so editor visuals and future video editor panels use the shared asset picker for eligible asset selection.
  - User story link : Makes the library useful inside the guided content workflow.
  - Depends on : Task 14 and relevant editor/video specs.
  - Validate with : widget/integration tests for selecting content visual, video cover, audio/music asset and ignoring stale project responses.
  - Notes : If video editor UI exists in a different file by implementation time, integrate there too.

- [ ] Task 16: Add cleanup/history support
  - Fichier : `lab/api/services/project_asset_cleanup.py`
  - Action : Add a backend service or scheduled cleanup boundary that marks assets eligible after 30-day tombstone history and reports orphan storage/metadata states without physical deletion by default.
  - User story link : Honors the user-approved 30-day history behavior.
  - Depends on : Tasks 2 and 5.
  - Validate with : tests for tombstone age, historical usage, cleanup eligibility and orphan report.
  - Notes : Physical Bunny deletion requires explicit retention policy approval or a future spec.

- [ ] Task 17: Update docs and changelog
  - Fichier : `lab/README.md`
  - Action : Document project asset APIs, media kinds, sources, eligibility, storage descriptors, tombstone/history, cleanup and security; update app README/changelog where UI ships.
  - User story link : Keeps operators and future implementation agents aligned.
  - Depends on : Backend and Flutter tasks.
  - Validate with : docs review plus `rg` for stale claims such as standalone media library, public DAM, guaranteed rights or arbitrary URL import.
  - Notes : Also update feature docs for Image Robot, video editor and local capture if their asset flows use the library.

- [x] Task 18: Add canonical asset category metadata slice
  - Fichiers : `lab/status/asset_categories.py`, `lab/status/db.py`, `lab/status/schemas.py`, `lab/status/service.py`, `lab/api/models/status.py`, `lab/api/routers/assets.py`, `app/lib/data/models/project_asset.dart`, `app/lib/data/services/api_service.dart`, `app/lib/providers/providers.dart`, `app/lib/presentation/widgets/project_asset_picker.dart`
  - Action : Add a small versioned backend registry, stable category/subcategory persistence, exact filters, localized catalog retrieval, assignment/clearing, original filename preservation and safe export suggestions; expose the supported fields and controls through the existing Flutter picker.
  - User story link : Lets creators organize reusable media consistently across language and workflow boundaries without conflating curated organization with AI tags.
  - Depends on : Existing unified asset backend/client/picker slice.
  - Validate with : Focused backend registry/service/router/migration tests, Flutter model/provider/picker tests, focused analyze and design-token drift scan.
  - Notes : No binary rename, folder automation, public DAM behavior or 550-entry sound taxonomy is introduced.

## Acceptance Criteria

- [ ] CA 1: Given a user owns project A and not project B, when they list/search project A assets, then only project A assets are returned and project B ids return ownership-safe 403/404.
- [ ] CA 2: Given a project has images, captures, audio, music, video covers, backgrounds and render artifacts, when filters are applied, then results match only supported filters with stable pagination.
- [ ] CA 3: Given unsupported filters are passed, when the API validates them, then it returns 400 and does not broaden the result set.
- [ ] CA 4: Given an asset has multiple usages, when asset detail is opened, then usage entries show target type, target id, placement, state, version/stale status and last used timestamp.
- [ ] CA 5: Given a durable eligible image, when selected for a content placement, then the backend creates/updates usage and leaves one primary if primary mode is requested.
- [ ] CA 6: Given a durable eligible audio/music asset, when selected for a video version, then the video version references the asset id and invalidates stale preview/final render state.
- [ ] CA 7: Given a local-only capture, when selected for publish/render/reference, then the backend rejects it with a typed eligibility error.
- [ ] CA 8: Given an asset is tombstoned, when default list/search runs, then it is hidden and future use is blocked while historical detail remains available to the owner.
- [ ] CA 9: Given a tombstoned asset is within 30 days and has historical usage, when detail is requested, then provenance is visible and no new publish/render action is allowed.
- [ ] CA 10: Given Bunny storage metadata is degraded, when listing assets, then the UI shows degraded preview and backend rejects publish/render selection until storage is repaired.
- [ ] CA 11: Given two sessions race to set primary for the same target/placement, when requests finish, then final state has at most one primary or returns a refreshable conflict.
- [ ] CA 12: Given signed preview/playback URL expires, when the user plays/previews again, then the app refreshes through backend and does not expose tokens.
- [ ] CA 13: Given active project changes while requests are in flight, when stale responses return, then Flutter ignores them and clears context-specific selection.
- [ ] CA 14: Given diagnostics capture an asset error, when logs are reviewed, then no Bunny AccessKey, signed token, provider secret, raw provider payload, raw audio bytes or local device path is present.
- [ ] CA 15: Given the feature ships, when navigating the app, then no public DAM, arbitrary URL import, or free provider playground is introduced by this chantier.
- [x] CA 16: Given English and French category catalogs, when their entries are compared, then category/subcategory IDs and registry version are stable while labels are localized.
- [x] CA 17: Given a valid or invalid category assignment, when the backend processes it, then exact filters and audit events update only for valid assignments and AI understanding tags remain separate.
- [x] CA 18: Given an existing or path-like filename, when asset metadata is returned, then the original filename is preserved and the suggested export filename is portable and traversal-safe.

## Test Strategy

- Backend schema tests for unified asset models, media/source enums, storage descriptors, usage targets and eligibility validation.
- Backend migration tests on empty DB and existing DB with `content_assets`.
- Backend service tests for list/search/filter, pagination, ownership, usage, selection, primary conflict, tombstone, restore and cleanup eligibility.
- Backend router tests for 401, 403/404, invalid filters, incompatible media kinds, stale targets and redacted responses.
- Storage descriptor tests using mocked Bunny/object metadata and signed URL expiry.
- Integration-style tests connecting generated image records and video/audio generated assets to unified project asset rows.
- Flutter model tests for parsing, unknown enum fallback, degraded preview and redaction.
- Flutter ApiService/provider tests for active project scoping, mutation invalidation, stale responses and typed error mapping.
- Flutter widget tests for reusable picker/list/detail states on mobile and desktop widths.
- Manual QA: use one project with generated image, uploaded reference, local capture, narration track, music bed and video cover; filter, select, tombstone, refresh, and confirm publish/render eligibility behavior.

## Risks

- High security risk: a cross-media library endpoint can leak project assets if ownership filtering happens after search/filter or in Flutter.
- High data risk: tombstone, primary or usage mutation can break publish/render if historical usage and compatibility checks are weak.
- High product risk: "global library" can drift into a public DAM or free playground if V1 navigation and actions are not bounded by project/workflow context.
- Medium performance risk: AI generation can create many assets quickly; indexes and pagination are mandatory.
- Medium storage risk: Bunny metadata and DB metadata can diverge; degraded states and cleanup reports are required.
- Medium implementation risk: multiple upstream specs may not exist in code yet; integration tasks must stop at stable boundaries if owner features are not implemented.
- Medium UX risk: one unified picker can become too dense; V1 should use media-kind filters and workflow-specific eligible-action defaults.

## Execution Notes

- Read first:
  - `shipglows_data/workflow/specs/SPEC-project-visual-asset-library-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `lab/status/db.py`
  - `lab/status/schemas.py`
  - `lab/status/service.py`
  - `lab/api/routers/status.py`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
- Implementation order: backend schemas, migrations, normalization, query service, mutation/eligibility service, routes, Flutter models/API, providers, picker UI, workflow integration, cleanup/docs.
- Treat this as a shared domain layer. Do not reimplement provider generation, upload, Remotion rendering or audio generation here.
- Stop and reroute if product scope changes to cross-project brand libraries, team roles, public DAM navigation, arbitrary URL import, physical deletion policy or legal rights registry.
- Stop and reroute if server-side validation cannot prove same project/user ownership for both asset and target.
- Fresh docs verdict: `fresh-docs checked` for Bunny Storage API behavior. Most of this spec is local metadata and workflow policy; re-check official provider docs during implementation only when coding provider/storage side effects outside the local contract.
- Suggested validation commands after implementation:
  - `python3 -m pytest lab/tests/test_project_assets*.py lab/tests/test_status*asset*.py`
  - `flutter test test/data/project_asset_test.dart test/providers/project_asset_provider_test.dart test/presentation/project_asset_picker_test.dart`
  - `flutter analyze` when Flutter UI changes.

## Open Questions

None. Product assumptions locked for this draft: "global" means unified within an owned project and its guided editor/video/generation workflows, not a public cross-project media browser; assets are project-first with optional content/video placements; no human approval step; tombstone blocks future reuse and preserves 30-day history; creation remains owned by existing generation/upload/video specs.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 17:20:22 UTC | sf-spec | GPT-5 Codex | Created draft spec for a unified cross-media project asset library from user selection, existing ready visual/upload/video specs, local asset code scan, and Bunny freshness evidence. | Draft saved. | /sf-ready Unified Project Asset Library |
| 2026-05-11 17:39:14 UTC | sf-ready | GPT-5 Codex | Ran readiness gate on the unified project asset library, verified structure, metadata, user-story traceability, task ordering, fresh Bunny docs, language doctrine, adversarial cases and security controls; made the Image Robot/Flux dependency explicit. | Ready after spec update. | /sf-start Unified Project Asset Library |
| 2026-05-11 18:25:00 UTC | sf-start | gpt-5.3-codex | Implemented backend-first vertical slice: unified project asset schemas, DB tables/indexes, status service list/detail/usage/select/tombstone/restore, dedicated authenticated `/api/projects/{project_id}/assets` router, and targeted router tests. | Partial: backend slice shipped, cross-feature integrations and Flutter/UI layers pending. | /sf-verify Unified Project Asset Library |
| 2026-05-11 18:26:00 UTC | sf-verify | GPT-5.5 high | Verified the backend-first vertical slice against the full Unified Project Asset Library contract, inspected modified backend code, TASKS, bug sources and targeted router tests. | Partial: targeted tests pass, but selection lacks target ownership validation and the backend surface remains incomplete against the spec. | /sf-start Unified Project Asset Library backend gaps |
| 2026-05-11 18:21:24 UTC | sf-start | GPT-5 Codex | Closed backend gaps from verification: server-side target ownership validation before asset selection, unsupported action/target rejection, video-version boundary refusal until the video store exists, client-safe storage descriptors and redaction tests. | Partial: critical backend selection gap closed; broader integrations, events, cleanup, docs and Flutter/UI remain pending. | /sf-verify Unified Project Asset Library backend gaps |
| 2026-05-11 18:31:22 UTC | sf-verify | GPT-5.5 high | Verified the backend gaps slice only: target ownership validation before selection mutation, unsupported action/target rejection, video-version boundary refusal, API storage descriptor redaction, targeted tests, py_compile, and metadata lint. | Partial: backend gaps verified; full Unified Project Asset Library remains incomplete and not ready to ship as a full feature. | /sf-start Unified Project Asset Library remaining feature gaps |
| 2026-05-11 18:38:34 UTC | sf-start | GPT-5 Codex | Implemented the next backend feature-gap slice: asset events/history table and endpoints, eligibility endpoint, explicit primary/clear-primary endpoints, preview-refresh descriptor endpoint, non-destructive cleanup report, and backend README API/security documentation. | Partial: backend asset-library surface is broader and tested; cross-feature integrations and Flutter/UI remain pending. | /sf-verify Unified Project Asset Library remaining feature gaps |
| 2026-05-11 18:43:37 UTC | sf-verify | GPT-5 Codex | Verified the remaining backend feature-gap slice against the spec, inspected focused backend diff and tests, checked bugs, ran targeted pytest, py_compile, and ShipGlowz metadata lint. | Partial: checks pass and backend surface is mostly verified, but `/primary` can use `set_primary` without media-kind compatibility enforcement; full Flutter/integration feature remains pending. | /sf-start Unified Project Asset Library primary eligibility gap |
| 2026-05-11 19:00:00 UTC | sf-start | GPT-5 Codex | Fixed primary-eligibility bypass by enforcing `set_primary` media-kind compatibility by target type (`content` vs `video_version`), and added a regression test proving `/primary`-equivalent `set_primary` rejects audio on content without mutating usages. | Partial: critical `/primary` compatibility gap closed; full feature/integrations remain pending and must be re-verified. | /sf-verify Unified Project Asset Library primary eligibility gap |
| 2026-05-11 18:47:58 UTC | sf-verify | GPT-5 Codex | Verified the targeted primary-eligibility fix: inspected `set_primary` target-type compatibility, confirmed audio-to-content rejection has no usage mutation, checked events/cleanup/preview route continuity, and ran targeted pytest, py_compile and metadata lint. | Partial: backend primary eligibility bypass is verified closed; full feature remains partial because Flutter and Image/Video/Audio integrations are outside this backend slice. | /sf-end Unified Project Asset Library backend slice or /sf-start remaining Flutter/Image/Video integrations |
| 2026-05-11 18:53:02 UTC | sf-start | GPT-5 Codex | Implemented Flutter client foundation for unified project assets: typed Dart models (`ProjectAsset`, usage/event/eligibility/cleanup structures) and typed `ApiService` methods for list/detail/usage/events/eligibility/select/primary/clear-primary/preview-refresh/tombstone/restore/cleanup-report, plus targeted model tests. | Partial: Flutter API/model foundation is now consumable; Riverpod/UI integration and Image/Video/Audio workflow hooks still pending. | /sf-verify Unified Project Asset Library Flutter client foundation |
| 2026-05-11 18:56:23 UTC | sf-verify | GPT-5 Codex | Verified the Flutter client foundation slice: compared Dart models with backend project asset response/usage/event/eligibility/cleanup contracts, inspected `ApiService` endpoint patterns, added a focused redacted descriptor model test, and ran targeted Flutter checks plus spec metadata lint. | Partial: Flutter model/API foundation is verified; full feature remains incomplete until Riverpod state, picker/detail UI and Image/Video/Audio workflow integrations ship. | /sf-start Unified Project Asset Library Flutter providers and picker integration |
| 2026-05-11 19:06:26 UTC | sf-start | GPT-5 Codex | Implemented Flutter Riverpod asset-library state and reusable picker widget slice: project-scoped list filters, detail/usage/events loading, selection + tombstone/restore/primary/clear-primary mutations, stale-response guard on project context changes, and targeted provider/widget tests. | Partial: provider + reusable picker are in place and validated; workflow-level Image/Video/Audio integrations remain pending. | /sf-verify Unified Project Asset Library Flutter providers and picker integration |
| 2026-05-11 19:09:29 UTC | sf-verify | GPT-5 Codex | Verified the Flutter provider/picker slice against the targeted contract, inspected provider and widget code, checked bug files and project development mode, ran targeted Dart/Flutter checks and metadata lint. | Partial: list/detail stale-response guards, project scoping, filters, callbacks and compact picker surface are present, but mutation flows do not re-check freshness before refresh/reselect after an active-project change. | /sf-start Unified Project Asset Library Flutter mutation stale guard |
| 2026-05-11 19:12:56 UTC | sf-start | GPT-5 Codex | Added stale-context guards across Flutter project-asset mutations (`selectForTarget`, `setPrimary`, `clearPrimary`, `tombstoneAsset`, `restoreAsset`) to skip post-mutation state writes, refresh, and reselection when active project changes mid-flight; added provider regression tests covering each mutation stale-switch scenario. | Implemented: mutation stale guards now prevent refresh/reselect bleed into the new project context; targeted provider/widget/analyze checks pass. | /sf-verify Unified Project Asset Library Flutter mutation stale guard |
| 2026-05-11 19:16:02 UTC | sf-verify | GPT-5 Codex | Verified Flutter mutation stale guards, found and fixed the remaining post-refresh reselection window, added refresh-delay project-switch regressions for select/primary/tombstone/restore, and ran targeted format/test/analyze plus metadata lint. | Verified: mutations no longer refresh/reselect into a changed active-project context; full feature remains partial until workflow integrations consume the library. | /sf-start Unified Project Asset Library workflow integrations |
| 2026-05-11 19:21:16 UTC | sf-start | GPT-5 Codex | Integrated unified project asset library into the existing editor workflow with a project-scoped app-bar entry point opening an inline bottom-sheet `ProjectAssetPicker` (`targetType=content`, `targetId=<content_id>`, `usageAction=select_for_content`, `placement=editor_body`), plus widget tests for open/disabled states and targeted Flutter checks. | Partial: editor workflow integration shipped and validated; Image/Video/Audio guided workflow integrations remain to complete full cross-media scope. | /sf-verify Unified Project Asset Library workflow integrations |
| 2026-05-11 19:25:26 UTC | sf-verify | GPT-5 Codex | Verified the editor workflow integration against the unified project asset library contract: inspected app-bar/project-context wiring, picker bottom-sheet target parameters, editor widget tests, provider/picker tests, targeted analyze, format check and metadata lint. | Verified: targeted editor integration passes; broader Image/Video/Audio workflow integrations remain future gaps, not blockers for this editor slice. | /sf-end Unified Project Asset Library editor integration slice or /sf-start Image/Video/Audio asset workflow integrations |
| 2026-05-11 19:45:39 UTC | sf-end | GPT-5 Codex | Closed the verified editor integration slice, updated tracker/changelog bookkeeping, and kept the broader Image/Video/Audio integrations as future non-blocking work. | Closed: backend/client/editor asset-library slice is ready to ship; full cross-media spec remains partial by design. | /sf-ship Unified Project Asset Library editor integration slice |
| 2026-05-11 19:45:39 UTC | sf-ship | GPT-5 Codex | Prepared quick ship for the verified unified project asset library editor integration slice with targeted checks and explicit staging scope. | Shipped after targeted validation and push. | /sf-start Image/Video/Audio asset workflow integrations when ready |
| 2026-08-07 19:15:30 UTC | 001-sg-build | GPT-5 Codex | Implemented the canonical asset category slice: versioned EN/FR registry, idempotent Turso fields/index, exact filtering, category assignment audit events, safe export-name suggestions, and Flutter picker integration. | Implemented and verified locally: 34 backend tests and 18 Flutter tests pass; focused Flutter analysis is clean; design-token scan confirms the new visual values resolve through canonical tokens. | Continue remaining Image/Video/Audio guided integrations when prioritized. |

## Current Chantier Flow

- sf-spec: done
- sf-ready: ready
- sf-start: partial (backend/client/editor and canonical taxonomy slices implemented; Image/Video/Audio guided integrations remain future work)
- sf-verify: verified (targeted editor workflow integration and canonical taxonomy slice)
- sf-end: closed (editor integration slice)
- sf-ship: shipped (targeted slice)

Prochaine commande: `/sf-start Image/Video/Audio asset workflow integrations` when those future owner workflows are ready.
