---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-11"
created_at: "2026-05-11 15:03:26 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 15:57:26 UTC"
status: ready
source_skill: sf-spec
source_model: "gpt-5.5"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que créatrice ContentGlowz authentifiée travaillant dans un projet, je veux retrouver, filtrer, sélectionner et gouverner les visuels générés, importés ou capturés de ce projet, afin de réutiliser les bons assets dans mes contenus sans ouvrir un navigateur média public ni un playground libre."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "content_assets"
  - "Image Robot"
  - "Flux image generation"
  - "Bunny CDN"
  - "Turso/libSQL"
  - "Clerk"
  - "content publishing"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md"
    artifact_version: "1.0.0"
    required_status: "active"
  - artifact: "Bunny Storage API"
    artifact_version: "official docs checked 2026-05-11: https://docs.bunny.net/api-reference/storage/manage-files/upload-file and https://docs.bunny.net/storage/http"
    required_status: "active"
  - artifact: "BFL FLUX.2 docs"
    artifact_version: "official docs checked 2026-05-11: https://docs.bfl.ai/flux_2"
    required_status: "active"
supersedes: []
evidence:
  - "User decision 2026-05-11: the editor-linked AI visuals UI spec excludes a global asset library V1."
  - "User decision 2026-05-11: this future chantier must formalize a project media library for generated, imported, and captured assets."
  - "User decision 2026-05-11: V1 is an editor-linked picker, not a standalone media library or global navigation surface."
  - "User decision 2026-05-11: local-only captures may appear in the picker/library with limited eligibility."
  - "User decision 2026-05-11: eligible generated/imported assets can be promoted directly as references."
  - "User decision 2026-05-11: removing an asset prevents future reuse without breaking existing content usage."
  - "Code evidence: lab/status/db.py already creates content_assets with content_id, project_id, user_id, storage_uri, status, metadata, and deleted_at."
  - "Code evidence: lab/status/service.py already lists, creates, updates, and tombstones non-deleted content assets by content_id."
  - "Code evidence: lab/api/routers/status.py exposes authenticated /api/status/content/{content_id}/assets routes after require_owned_content_record."
  - "Code evidence: app/lib/data/services/api_service.dart already posts device capture metadata to /api/status/content/{id}/assets."
  - "Code evidence: app/lib/router.dart has no asset-library route and currently sanitizes every /editor/* route as /editor/:id."
  - "Code evidence: app/lib/providers/providers.dart scopes pending content and project data through activeProjectIdProvider."
next_step: "/sf-start Project Visual Asset Picker Library"
---

# Title

Project Visual Asset Picker Library

## Status

Ready. This spec defines a project-scoped visual asset picker/library owned by the backend. Product direction is fixed for V1: no standalone media library screen, no global nav entry, no project-detail media browser, and no free playground; the user-facing surface is an editor-linked picker. Local-only captures may appear with limited eligibility, durable eligible assets can be promoted directly as references, and removal blocks future reuse without breaking existing content usage.

## User Story

En tant que créatrice ContentGlowz authentifiée travaillant dans un projet, je veux retrouver, filtrer, sélectionner et gouverner les visuels générés, importés ou capturés de ce projet, afin de réutiliser les bons assets dans mes contenus sans ouvrir un navigateur média public ni un playground libre.

## Minimal Behavior Contract

For an authenticated user inside an owned project and editor workflow, ContentGlowz provides a project visual asset picker that lists visual assets already owned by that project, supports search and filters by source, kind, status, placement, reference state, generation metadata, and usage, shows which contents use each asset when relevant, lets the user select an eligible asset for a content placement, directly promote an eligible durable asset as a project visual reference, or tombstone an asset from future use. The backend validates project ownership, content ownership, generation ownership, storage durability, and placement rules before returning or mutating anything. If an asset is deleted, foreign, local-only, missing durable storage, or already tombstoned, the UI shows a recoverable state and does not offer unsafe publish/reference actions; local-only captures may still be visible as non-publishable/non-reference items. The easy edge case to miss is confusing this with a generic media browser: V1 only manages project-owned ContentGlowz visual assets through editor-linked picking and never browses arbitrary public URLs or provider playground outputs.

## Success Behavior

- Given a creator owns a project, when they open the editor-linked asset picker for that project/content context, then the backend returns only project-owned assets whose metadata is safe to expose, including local-only captures when they are clearly marked with limited eligibility.
- Given assets exist from local capture, Image Robot/Flux generation, future import, or content attachment, when the creator filters by source, kind, placement, status, reference state, provider, profile, or usage, then results update with stable pagination and total counts.
- Given a creator searches by title, label, file name, alt text, prompt summary, reference label, content title, or tags, when matching assets exist in the project, then the API returns ranked or consistently ordered project-only results.
- Given an asset is used by one or more content records, when the creator opens the asset detail, then the library shows usage entries with content id, title, status, placement, primary/candidate state, and last updated date.
- Given a durable eligible visual asset is selected for a content placement, when the user confirms selection, then the backend creates or updates the content asset placement link and optionally sets it primary through a server-side atomic action.
- Given a generated or uploaded durable asset should guide future generation, when the creator promotes it as a reference, then the backend directly creates or updates a project-scoped visual reference record and records the source asset id without a human approval queue.
- Given a creator tombstones an asset, when the backend accepts the request, then the asset is hidden from future picker reuse and cannot be newly selected or used as a reference, while existing content usage remains auditable and not silently broken.
- Given the editor-linked picker needs asset picking, when it calls the selection API with project id, content id, and placement, then it receives only eligible assets for that placement and project.
- Given Bunny stores the underlying binary, when metadata points to a durable storage URI, then returned URLs are backend-approved Bunny/CDN URLs or backend proxy URLs, never provider temporary URLs.

## Error Behavior

- If the user is not authenticated through Clerk, return `401` and expose no asset metadata.
- If the project is absent, archived without access, or not owned by the user, return `404` or `403` using existing ownership conventions and do not leak whether foreign assets exist.
- If `project_id` is missing, reject list/search/mutation requests with `400`; this feature is project-scoped.
- If content selection references a content record outside the project or user, reject with `403` and keep the asset unchanged.
- If an asset id belongs to another project, is tombstoned, lacks durable storage for a publishable placement, or is `local_only`, reject selection/promotion with a typed error.
- If a search/filter request asks for unsupported filters, return `400` with supported filter names instead of silently broadening results.
- If Bunny/CDN metadata is unavailable, return asset metadata with a degraded preview state only when ownership and storage URI are still valid; do not return temporary provider URLs.
- If tombstoning an asset conflicts with active primary content usage, either require an explicit force mode or preserve the existing primary link while blocking future reuse; never silently remove publish-critical media.
- If concurrent primary selection happens for the same content placement, the backend must leave exactly one primary asset or return a conflict that the UI can refresh.
- What must never happen: cross-project asset visibility, arbitrary URL ingestion through the library, unauthenticated browsing, deletion of Bunny binaries without explicit retention policy, provider secrets in responses/logs, or using Flutter-side filtering as the permission boundary.

## Problem

ContentGlowz has several partial asset concepts: local capture metadata in `content_assets`, future Flux/Image Robot generation history, project visual references, Bunny CDN storage, and content placement metadata. The editor-linked AI visuals UI intentionally excludes a global asset library V1, but the product still needs a durable project media library so users can find, understand, reuse, retire, and promote visuals across content workflows. Without a backend-owned library contract, each UI surface risks inventing its own asset rules and weakening ownership, deletion, reference, and publish safety.

## Solution

Create a backend-owned project asset picker API and metadata model that normalizes generated, imported, captured, and attached visual assets into one project-scoped inventory usable from editor workflows. Build UI consumers as bounded pick/list/detail flows that call typed APIs for search, filtering, usage, selection, tombstone, and direct reference promotion; do not expose a standalone media library, arbitrary public media browsing, or model playground controls in V1.

## Scope In

- Project-scoped asset inventory for authenticated users, exposed first through editor-linked picker flows.
- Backend-owned listing, search, filtering, detail, usage, selection, tombstone, and reference-promotion APIs.
- Asset sources: `image_robot`, `device_capture`, `manual_import` when upload/import is implemented, and future backend-captured sources.
- Asset kinds: image V1, with metadata room for video cover/future video asset references; binary video library is not required in this chantier.
- Filters for source, kind, status, MIME family, placement, primary/candidate state, reference state, provider, profile id, generation id, content usage, created date, updated date, dimensions/aspect ratio, and tags/labels.
- Usage view showing content records, placements, primary/candidate state, publish relevance, and tombstone impact.
- Selection API for choosing an eligible asset for a content placement.
- Atomic primary selection per `content_id + placement`.
- Tombstone semantics that prevent future reuse while preserving existing content usage.
- Direct promotion of durable eligible assets into project visual references for Image Robot/Flux consistency.
- Migration/extension of Turso/libSQL metadata where `content_assets` is insufficient for project-level inventory.
- Bunny CDN/storage URI validation and URL shaping in backend responses.
- Flutter typed models, ApiService methods, providers, and an editor-linked picker UI surface.
- Tests covering ownership, search/filter, usage, selection, primary conflict, tombstone, reference promotion, and degraded storage metadata.

## Scope Out

- A free-form Flux playground or arbitrary prompt/model/ratio console.
- Anonymous or public asset browsing.
- Cross-project media library.
- Arbitrary public URL browser/importer.
- Standalone media library screen, global navigation entry, or project-detail media browser in V1.
- Binary upload implementation unless an upload/import spec has already provided a safe ingestion path.
- Physical deletion of Bunny objects as the default V1 behavior.
- Full DAM features such as folders, roles beyond existing project ownership, comments, approvals workflow, licensing registry, or bulk transformations.
- Remotion timeline editing or video rendering.
- Supabase, Vercel Blob, Vercel OAuth, or contentglowz stack migration.
- Automatic insertion into article markdown bodies.

## Constraints

- `lab` is the source of truth for asset metadata, ownership checks, tombstones, and selection mutations.
- The library is always scoped by `project_id`; every endpoint must require or derive one owned project.
- Existing Clerk/FastAPI authentication and ownership helpers must remain the security boundary.
- Existing `content_assets` behavior for local capture must remain backward compatible.
- Flutter may cache asset lists for UX, but the backend remains authoritative for permissions, selection eligibility, primary state, and tombstones.
- Assets are publishable/selectable only when backend metadata proves durable storage or a server-owned reference to durable storage.
- `local_only` device captures may appear in the picker only as local/device-origin metadata; they are not publishable, reference-promotable, or selectable for server-side publish until uploaded.
- Tombstoning is metadata-first: it prevents future reuse while preserving existing content usage and history. Physical Bunny deletion follows the upload/reference retention policy rather than this picker alone.
- Search and filtering must be bounded and paginated; no unbounded project media dump.
- Returned diagnostics must redact signed URLs, provider request IDs when sensitive, provider payloads, and storage credentials.
- The feature must not weaken publish media validation described by the editor-linked AI visuals spec.

## Dependencies

- Existing backend status asset contract:
  - `lab/status/db.py`
  - `lab/status/service.py`
  - `lab/status/schemas.py`
  - `lab/api/models/status.py`
  - `lab/api/routers/status.py`
- Existing Flutter integration points:
  - `app/lib/router.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
- Upstream generation/reference contract: `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`.
- Upstream editor-linked visual workflow: `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`.
- Existing local capture asset contract: `shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md`.
- Bunny CDN/storage for durable binaries and public/proxied URLs.
- Turso/libSQL for durable metadata and indexes.
- Fresh external docs verdict: `fresh-docs checked`. Bunny Storage API official docs were checked on 2026-05-11 for server-side Storage API behavior and AccessKey-based HTTP upload/storage-zone semantics. BFL FLUX.2 official docs were checked on 2026-05-11 for generated/reference image metadata assumptions, including API multi-reference support. Implementation must re-check official docs only if it codes Bunny API calls, upload/delete/retention behavior, or FLUX.2 provider request construction beyond metadata linking.

## Invariants

- Every library asset has an owning `project_id` and `user_id` or equivalent ownership mapping.
- Every library response is filtered by authenticated ownership before search/filter logic is applied.
- A content placement link must belong to the same project as the selected asset.
- An asset can be a library item without being linked to content, but a publishable content visual must be linked to content through a server-validated action.
- Tombstoned assets do not appear in default list/search results and cannot be newly selected or promoted.
- Existing content usage must remain auditable after tombstone.
- A project visual reference is derived from an owned durable asset or an explicitly approved backend ingestion path.
- Bunny URLs and provider metadata are presentation metadata, not the permission model.
- Search and filter results must be deterministic under pagination.
- The library never imports, proxies, or lists arbitrary public media as a browsing feature.

## Links & Consequences

- `lab/status/db.py`: `content_assets` likely needs project-level indexes and metadata fields or companion tables for library inventory, usage, reference promotion, labels, alt text, placement state, primary uniqueness, and tombstones.
- `lab/status/service.py`: needs project-scoped asset list/search/detail methods in addition to current content-scoped CRUD.
- `lab/api/routers/status.py`: current `/api/status/content/{content_id}/assets` routes are content-scoped; library endpoints should either live under a new router such as `/api/assets` or a project route while preserving existing status routes.
- `app/lib/data/services/api_service.dart`: needs typed library methods instead of ad hoc Dio calls.
- `app/lib/providers/providers.dart`: needs a bounded provider/controller for library query state and mutations, scoped by active project and optional content selection context.
- `app/lib/router.dart`: no standalone library route is required for V1; only update routing or Sentry sanitization if the editor implementation introduces a nested editor route while preserving `/editor/*` sanitization.
- Publishing must keep validating media URLs against owned content assets or generation records; this library cannot make raw URLs trustworthy.
- Docs must distinguish "project asset picker" from "standalone media library", "editor AI visuals", and "free playground".

## Documentation Coherence

- Update backend API docs or README with project asset library endpoints, filters, statuses, tombstone behavior, and security model.
- Update app README/changelog after implementation with the editor-linked picker behavior and supported actions.
- Update Image Robot docs to explain how generated assets enter the library and how references are promoted.
- Update local capture docs if local-only captures appear in the library with limited eligibility.
- Add support copy explaining that deleting/tombstoning removes future reuse but does not necessarily delete already published external media or Bunny binaries.

## Edge Cases

- Project has no assets yet.
- Project has thousands of generated images and requires stable pagination.
- Asset is durable in Bunny but its content usage was deleted.
- Asset is linked to multiple contents with different placements.
- Asset is primary for one placement and candidate for another.
- Asset has provider metadata but no generation record because it predates the Flux history schema.
- Local-only capture exists on one device but the library is opened on another device.
- A generated image is tombstoned while an editor selection dialog is open.
- A reference-promoted asset is later tombstoned.
- Bunny object exists but metadata row is missing, stale, or references an old URL format.
- Duplicate assets point to the same Bunny object.
- Search term matches content title and asset label with different ranking expectations.
- Active project changes while list/search/detail requests are in flight.
- User tries to select an image for a placement whose aspect ratio or kind is incompatible.
- Concurrent users or sessions set different primary assets for the same placement.
- A user forges client metadata to mark a local-only or foreign asset as durable, eligible, primary, or reference-promotable.
- A stale picker tab attempts selection or promotion after the asset was tombstoned, replaced, or detached in another session.

## Implementation Tasks

- [ ] Task 1: Define the project asset library data contract
  - File: `lab/status/schemas.py`
  - Action: Add or extend typed records/enums for library source, kind, visibility, tombstone state, reference state, placement usage, primary state, selection eligibility, and normalized metadata.
  - User story link: Makes project assets searchable and governable through one backend contract.
  - Depends on: none.
  - Validate with: Python import/type tests for new schema objects and enum validation.
  - Notes: Preserve existing `ContentAssetRecord` compatibility for local capture. V1 search metadata includes prompt summary/hash, alt text, labels, content title, generated profile id, tags, dimensions, placement, and source when present; missing optional fields must not block listing.

- [ ] Task 2: Add Turso/libSQL metadata and indexes for project-level inventory
  - File: `lab/status/db.py`
  - Action: Add idempotent migration/ensure logic for project-level asset library fields or companion tables, including indexes for project, user, source, kind, status, deleted_at, reference state, generation id, content usage, placement, and updated_at.
  - User story link: Enables fast project-scoped list/search/filter without scanning content records.
  - Depends on: Task 1.
  - Validate with: migration test against an empty DB and an upgraded DB containing existing `content_assets`.
  - Notes: If unique primary per placement is stored in metadata today, formalize it with a DB-level or service-level invariant.

- [ ] Task 3: Implement project-scoped asset service methods
  - File: `lab/status/service.py`
  - Action: Add methods for `list_project_assets`, `search_project_assets`, `get_project_asset_detail`, `get_asset_usage`, `select_asset_for_content`, `set_primary_asset_for_placement`, `tombstone_project_asset`, and `promote_asset_reference`.
  - User story link: Makes backend the owner of library behavior and not just a content asset append store.
  - Depends on: Tasks 1 and 2.
  - Validate with: unit tests for ownership scope, filters, pagination, usage, tombstone, reference promotion, and primary conflict.
  - Notes: Service methods must reject cross-project content/asset combinations before mutation. Direct reference promotion creates or updates a project-scoped visual reference record that records `source_asset_id`; it must not rely only on marking the asset row as reference-eligible.

- [ ] Task 4: Add backend API models for library requests and responses
  - File: `lab/api/models/status.py`
  - Action: Add request/response models for list filters, search, asset detail, usage entries, selection request, primary update, tombstone request, and reference promotion response.
  - User story link: Gives Flutter and future clients a typed API instead of overloading raw metadata maps.
  - Depends on: Task 1.
  - Validate with: model validation tests for unsupported filters, bad pagination, invalid placement, and tombstone modes.
  - Notes: Avoid exposing provider secrets, signed URL internals, or raw prompt payloads.

- [ ] Task 5: Expose authenticated project asset library endpoints
  - File: `lab/api/routers/status.py`
  - Action: Add or delegate project asset routes for list/search/detail/usage/select/primary/tombstone/promote-reference while preserving `/api/status/content/{content_id}/assets`.
  - User story link: Lets users browse and act on project assets from the approved editor-linked picker.
  - Depends on: Tasks 2, 3, and 4.
  - Validate with: API tests for 401, 403/404 foreign project, project list filters, detail, usage, selection, primary atomicity, tombstone, and reference promotion.
  - Notes: If route ownership grows too large, create a dedicated router in implementation, but this spec anchors the existing status router as the current asset API owner.

- [ ] Task 6: Connect Image Robot/Flux generation records to library inventory
  - File: `lab/api/routers/status.py`
  - Action: Ensure generated assets from Image Robot/Flux can be surfaced as project library assets with generation id, provider, model, profile id, reference ids, prompt summary/hash, dimensions, Bunny storage URI, and content usage when attached.
  - User story link: Makes generated assets reusable beyond the original editor session.
  - Depends on: Task 5 and the Flux provider backend implementation.
  - Validate with: integration test using a mocked completed generation and a Bunny-backed URL.
  - Notes: Do not return provider temporary URLs or make generation history the only inventory source.

- [ ] Task 7: Harden tombstone and retention behavior
  - File: `lab/status/service.py`
  - Action: Implement tombstone modes that distinguish hide-from-library, block-future-reuse, preserve-existing-usage, and force-remove-candidate links where explicitly allowed.
  - User story link: Lets users clean the library without breaking content invisibly.
  - Depends on: Task 3.
  - Validate with: tests for tombstoning unused asset, primary-used asset, candidate-used asset, promoted reference, and repeated tombstone.
  - Notes: Physical Bunny deletion remains out of scope unless a retention policy spec authorizes it.

- [ ] Task 8: Add Flutter models and API methods
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add typed methods for project asset list/search/detail/usage/select/primary/tombstone/promote-reference and parse typed response models.
  - User story link: Provides client access to backend-owned asset library behavior.
  - Depends on: Task 5.
  - Validate with: Dart tests for serialization, pagination params, error mapping, and response parsing.
  - Notes: Keep signed URLs and provider details out of diagnostics.

- [ ] Task 9: Add Riverpod library state controller
  - File: `app/lib/providers/providers.dart`
  - Action: Add a scoped provider/controller for active project asset queries, filters, selected asset detail, mutations, and invalidation of content detail/history after selection.
  - User story link: Keeps the library responsive while preserving active project boundaries.
  - Depends on: Task 8.
  - Validate with: provider tests for active project changes, filter changes, mutation refresh, and stale response ignore.
  - Notes: Move to a dedicated provider file during implementation only if the repo pattern supports that split.

- [ ] Task 10: Add editor-linked picker UI surface
  - File: `app/lib/presentation/screens/editor/widgets/project_asset_picker.dart`
  - Action: Add the picker/list/detail/selection/tombstone/reference-promotion UI as an editor-linked surface that consumes Task 9 state and opens only from an owned content editor context.
  - User story link: Gives creators access to project assets without creating a standalone media library or free playground.
  - Depends on: Task 9.
  - Validate with: widget tests for empty state, local-only limited eligibility, filter/search, detail usage, select, promote reference, tombstone, and stale mutation refresh.
  - Notes: Do not add a global navigation entry or project-detail media browser. Update `app/lib/router.dart` only if the editor integration creates a new editor subroute that needs sanitization.

- [ ] Task 11: Add documentation and changelog updates
  - File: `lab/README.md`
  - Action: Document API behavior, security model, filters, tombstone semantics, reference promotion, Bunny/storage assumptions, and local-only limitations; update app changelog/readme where implementation lands.
  - User story link: Keeps operators and future implementers aligned on what the picker/library is and is not.
  - Depends on: Tasks 5, 8, and 10.
  - Validate with: docs review against endpoint tests and UX behavior.
  - Notes: Also update `app/CHANGELOG.md` and `app/README.md` if the UI surface ships in the same chantier. User-facing copy introduced by the picker must be localized through the app localization system and use natural accented French where French strings are added.

## Acceptance Criteria

- [ ] CA 1: Given an authenticated user owns project A and not project B, when they list project A assets, then only project A assets are returned and project B asset ids return 403/404.
- [ ] CA 2: Given a project has generated, captured, and imported visual metadata, when the user filters by source and placement, then the response contains only matching project assets with stable pagination.
- [ ] CA 3: Given an asset is attached to two contents, when the user opens asset detail, then both usage entries show content title/id, placement, primary/candidate state, and content status.
- [ ] CA 4: Given a durable eligible asset and owned content in the same project, when the user selects it for a placement, then the backend links it to the content and returns the updated usage state.
- [ ] CA 5: Given two primary selection requests race for the same content placement, when both complete or one fails, then the final backend state contains at most one primary asset for that placement.
- [ ] CA 6: Given a local-only device capture asset, when the user tries to select it for publishable placement or promote it as reference, then the backend rejects it with a typed eligibility error.
- [ ] CA 7: Given an asset is tombstoned, when normal list/search runs, then the asset is hidden; when detail is requested by id, then the response shows tombstone state only if the user still owns the project.
- [ ] CA 8: Given a tombstoned asset was previously used by content, when content usage is viewed, then historical usage remains auditable and no new selection is allowed.
- [ ] CA 9: Given an eligible durable image asset, when promoted as a visual reference, then project reference metadata includes the source asset id and remains project-scoped.
- [ ] CA 10: Given unsupported filters are passed, when the API validates the request, then it returns 400 with supported filter keys and does not broaden results.
- [ ] CA 11: Given Bunny metadata is stale, when the asset list loads, then the UI can show a degraded preview state without exposing provider temporary URLs.
- [ ] CA 12: Given active project changes in Flutter while a query is in flight, when the old response returns, then provider state ignores it and does not show stale assets.
- [ ] CA 13: Given the editor-linked picker is implemented, when the user navigates the app, then there is no standalone media library screen, global nav entry, project-detail media browser, public URL browser, or free Flux playground introduced by this chantier.
- [ ] CA 14: Given an asset is promoted as a visual reference and later tombstoned, when future generation/reference selection runs, then new Image Robot usage is blocked while historical generation/content provenance remains visible to the owning project.

## Test Strategy

- Backend unit tests for service filtering, search, pagination, usage joins, tombstone behavior, reference promotion, and primary uniqueness.
- Backend API tests for auth, project ownership, content ownership, invalid filters, selection, tombstone, and conflict cases.
- Migration tests for empty Turso/libSQL schema and upgraded schema containing existing `content_assets` rows.
- Mocked Bunny/storage tests for durable URL shaping, missing metadata, invalid storage URI, and signed URL redaction.
- Flutter ApiService tests for request serialization, response parsing, and typed error mapping.
- Riverpod/provider tests for active project scoping, query refresh, mutation invalidation, stale response handling, and offline/degraded read states.
- Manual QA for the editor-linked picker: no assets, many assets, filter/search, detail/usage, select for content, promote reference, tombstone, stale tab refresh, and no global library route/nav entry.

## Risks

- High security risk: a library endpoint that filters after query or trusts Flutter could leak cross-project media.
- High data risk: tombstoning or primary changes can break publishing if existing content usage is not preserved and audited.
- Medium performance risk: project libraries may grow quickly from AI generation history; pagination and indexes are mandatory.
- Medium product risk: implementation can accidentally recreate a global playground if the UI starts from prompts instead of inventory and content/project context.
- Medium storage risk: Bunny object deletion and metadata tombstone can diverge without a retention policy.
- Medium migration risk: existing `content_assets` is content-scoped; project-level inventory may need companion tables to avoid overloading metadata JSON.

## Execution Notes

- Read first: `lab/status/db.py`, `lab/status/service.py`, `lab/api/routers/status.py`, `app/lib/data/services/api_service.dart`, and `app/lib/providers/providers.dart`.
- Treat `content_assets` as the compatibility base, not necessarily the final complete asset-library schema.
- Implement backend foundations before Flutter UI: schema, service, models, routes, tests, then typed client and providers.
- Stop and reroute if server-side validation cannot prove same user/project/content/generation/storage ownership for selection.
- Stop and reroute if a requirement implies binary upload, Bunny physical deletion, global navigation IA, or free playground controls; those need separate product decisions/specs.
- Fresh docs status: `fresh-docs checked` for Bunny Storage API and BFL FLUX.2 generated/reference image metadata; re-check official docs during implementation if API calls, retention behavior, or upload/delete semantics are coded.
- Validation commands should include targeted Python tests for status/service/routes and Dart analysis/tests for new app models/providers.
- Suggested checks: `python3 -m pytest` for the targeted backend tests added under the status/API area; `flutter test` for new ApiService/provider/widget tests; `flutter analyze` if the Flutter surface changes.
- Do not implement multi-user role distinctions in this chantier. Existing project ownership is the V1 permission model unless a separate roles spec becomes ready before implementation.

## Product Decisions Captured

- V1 user surface is an editor-linked picker, not a standalone media library.
- Local-only device captures can appear, but only with limited/non-publishable eligibility until uploaded.
- Durable eligible assets can be promoted directly as project references.
- Removing/tombstoning an asset prevents future reuse and does not break existing content usage.
- Broader content/asset lifecycle after use remains a future product decision.
- V1 search should index all available safe metadata named in Scope In; exact relevance ranking can be deterministic/simple as long as pagination is stable and unsupported filters are rejected.
- V1 uses existing project ownership. Multi-user project roles are out of scope until a separate roles spec exists.

## Security Review

Security impact: yes, mitigated by backend-only authz, project/content/generation/storage ownership validation, bounded pagination, typed filter allowlists, durable-storage eligibility checks, signed/provider URL redaction, and server-side mutations for selection, primary state, tombstone, and reference promotion.

- Authentication: all endpoints require the existing Clerk/FastAPI authenticated user; unauthenticated requests return `401` and expose no metadata.
- Authorization: project, content, asset, generation, and reference IDs must be checked server-side before reads or mutations; Flutter state is not a trust boundary.
- Input validation: project ids, content ids, asset ids, placement, pagination, filters, tombstone modes, and promotion requests are validated through Pydantic/API models and service allowlists.
- Workflow integrity: selection, primary updates, tombstone, and reference promotion must reject replay/stale/cross-project states and leave auditable history.
- Data exposure: responses expose only safe asset metadata and backend-approved Bunny/CDN/proxy URLs; provider payloads, secrets, signed URL internals, raw prompts where sensitive, and storage credentials are never returned or logged.
- Availability and abuse: search/list APIs are bounded and paginated; no unbounded media dump or arbitrary public URL ingestion is added.
- Multi-tenant boundary: every response is ownership-filtered before search/filter logic, and foreign asset ids return existing `403`/`404` conventions without existence leaks.

## Language Doctrine

Stable spec headings, metadata keys, acceptance criteria, stop conditions, and technical contracts remain in English. The user story and any French user-facing copy added by implementation must use natural accented French. Flutter visible strings must go through the existing localization system; implementation must not hardcode English-only picker labels if the affected surface already supports French.

## Open Questions

None. Former open points are resolved for V1 as follows: search uses all available safe metadata with deterministic ordering; direct promotion creates or updates a project-scoped visual reference record with `source_asset_id`; broader post-use lifecycle actions remain future scope; existing project ownership is sufficient for V1.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 | sf-spec | gpt-5.5 | Created draft spec for project-scoped visual asset library/mediatheque. | draft saved | /sf-ready Project Visual Asset Library |
| 2026-05-11 15:38:45 UTC | sf-spec | GPT-5 Codex | Integrated product decisions for editor-linked picker, local-only visibility, direct reference promotion, and tombstone future-reuse behavior. | Draft updated; standalone media library removed from V1 scope. | /sf-ready Project Visual Asset Picker Library |
| 2026-05-11 15:57:26 UTC | sf-ready | GPT-5 Codex | Readiness gate tightened V1 scope, security, language doctrine, freshness evidence, tasks, acceptance criteria, and open questions. | ready | /sf-start Project Visual Asset Picker Library |

## Current Chantier Flow

sf-spec ✅ -> sf-ready ✅ -> sf-start ⏳ -> sf-verify ⏳ -> sf-end ⏳ -> sf-ship ⏳
