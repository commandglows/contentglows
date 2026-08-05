---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-05-11"
created_at: "2026-05-11 15:02:43 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 16:01:53 UTC"
status: ready
source_skill: sf-spec
source_model: "gpt-5.5"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que créatrice ContentGlows authentifiée, je veux uploader, valider et maintenir des références visuelles de projet durables, afin que Image Robot puisse générer des visuels cohérents à partir de références fiables sans exposer de fichiers non contrôlés."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "api/status/content assets"
  - "api/images references"
  - "Image Robot"
  - "Bunny Storage/CDN"
  - "Turso/libSQL"
  - "Clerk"
  - "Black Forest Labs FLUX.2"
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
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "User brief 2026-05-11: current V1 does not upload arbitrary files; it uses project references and durable Bunny images."
  - "User brief 2026-05-11: future chantier must cover user-facing binary upload for project references, validation, Bunny storage, Turso/content_assets/image references metadata, replacement/deletion, and Image Robot usage."
  - "Spec evidence: SPEC-flux-ai-provider-image-robot-2026-05-11 requires controlled project reference images and durable Bunny assets, and explicitly excludes arbitrary playground upload."
  - "Spec evidence: SPEC-editor-linked-ai-visuals-ui-2026-05-11 explicitly leaves local file upload for arbitrary reference images out of V1 and routes binary upload to a separate storage/upload spec."
  - "Code evidence: lab/status/db.py and api/migrations/004_status_lifecycle.sql already create content_assets with storage_uri, source, kind, status, metadata, and ownership fields."
  - "Code evidence: lab/api/routers/status.py exposes authenticated /api/status/content/{content_id}/assets endpoints with require_owned_content_record."
  - "Code evidence: lab/status/service.py supports list/create/update/tombstone content assets but does not yet validate Bunny-backed image_robot uploads or primary/reference semantics."
  - "Code evidence: lab/agents/images/tools/bunny_cdn_tools.py supports upload, delete, list, and CDN URL derivation but currently accepts local path or URL sources without the hardened binary upload boundary needed here."
  - "Code evidence: app/lib/data/services/api_service.dart currently attaches local capture metadata only; it does not upload binary visual references."
  - "User decision 2026-05-11: an uploaded image starts as a project asset, not as an approved reference or free playground output."
  - "User decision 2026-05-11: V1 has no human approval step; backend validation remains mandatory."
  - "User decision 2026-05-11: image-to-image/reference use should support brand style, character consistency, and composition guidance."
  - "User decision 2026-05-11: deletion/removal keeps a 30-day history before cleanup."
  - "User decision 2026-05-11: asset scope is project first, then optional content attachment and one or more placements."
  - "sf-ready 2026-05-11: V1 readiness fixed backend-proxied upload, conservative image limits, metadata stripping, backend eligibility, deletion/tombstone semantics, and abuse controls without changing the user-approved product scope."
next_step: "/sf-start AI Visual Reference Upload Advanced"
---

# Title

AI Visual Reference Upload Advanced

## Status

Ready. This spec defines the advanced upload and lifecycle contract for user-facing binary project visual assets and references. V1 product direction is fixed: uploaded images start as project assets, no human approval step is required, references may guide brand style, character consistency, and composition, deletion blocks future use immediately while preserving 30 days of history, and asset scope is project first with optional content attachment and one or more placements.

## User Story

En tant que créatrice ContentGlows authentifiée, je veux uploader, valider et maintenir des références visuelles de projet durables, afin que Image Robot puisse générer des visuels cohérents à partir de références fiables sans exposer de fichiers non contrôlés.

## Minimal Behavior Contract

When an authenticated creator selects image files inside a project workflow, ContentGlows validates project ownership, declared upload intent, MIME/type sniffing, byte size, decoded dimensions, duplicate hash, filename safety, metadata stripping, and per-user/project abuse limits before storing sanitized bytes in Bunny Storage, recording durable metadata in Turso, and returning project asset records. Those assets can be attached to one content item and one or more placements, then selected for Image Robot reference/image-to-image use after backend eligibility validation; there is no human approval gate in V1. Failed uploads return clear recoverable errors and leave no selectable/promotable partial asset behind. The easiest edge case to miss is replacement/deletion: a new file must not silently change past generation provenance, and a deleted or retired asset must remain traceable for 30 days while being unavailable for future reuse.

## Success Behavior

- Given an authenticated user owns a project, when they upload visual reference files, then the backend accepts only a bounded proxied multipart upload path, validates project access, and never exposes Bunny Storage credentials to the app.
- Given a user uploads an allowed image file, when validation succeeds, then the backend stores sanitized bytes in Bunny Storage under a project/user-scoped path, records a Turso asset/reference row, and optionally creates or links a `content_assets` row when the asset is attached to a content item.
- Given Bunny Optimizer is enabled, when the uploaded reference is stored, then the response includes durable CDN URL metadata plus optimizer/responsive metadata where the existing `CDNManager` pattern supports it.
- Given an uploaded project asset is created, when validation succeeds, then it is immediately available as a project asset and can be attached to an owned content item and one or more placements according to backend placement rules.
- Given a validated durable project asset is selected as a visual reference, when Image Robot generates with visual memory, then only same-project/same-user eligible assets can be passed to FLUX.2 for brand style, character consistency, or composition guidance, and the generation record stores immutable asset/reference IDs plus resolved Bunny URLs used at execution time.
- Given a creator replaces a reference file, when replacement succeeds, then the new Bunny object and metadata become the active version while previous version metadata remains available for provenance and historical generations.
- Given a creator deletes or removes a reference asset, when deletion succeeds, then the asset is no longer selectable for future Image Robot jobs and 30-day history/cleanup rules apply.
- Given upload validation or storage fails, when the app refreshes references, then no failed file appears as eligible or selectable, and any temporary upload state is marked failed or cleaned up.
- Given local capture assets already exist, when this advanced upload ships, then local-only capture behavior remains unchanged and is not silently uploaded unless the user explicitly chooses an upload/reference action.

## Error Behavior

- If the user is unauthenticated, return `401` through the existing Clerk/FastAPI auth path.
- If the project is missing or not owned by the current user, return `403` or `404` using existing ownership conventions and never reveal cross-project reference metadata.
- If the file MIME type, extension, byte size, dimensions, frame count, or content sniffing result is disallowed, reject before or immediately after upload finalization and do not create a selectable/promotable reference asset.
- If the upload is interrupted, duplicated, replayed, or finalized twice, return an idempotent result for the same upload attempt or a typed conflict; do not create duplicate active references.
- If Bunny Storage upload fails, return a storage-specific sanitized error and do not create a usable reference row.
- If Turso metadata persistence fails after Bunny upload, mark the upload as orphan-cleanup-needed or delete the Bunny object according to the implementation's compensation path; never report success without metadata.
- If Bunny delete or purge fails during reference deletion, mark deletion as partially completed and keep the reference unavailable for future use while exposing an operator-visible recovery state.
- If a non-durable, deleted, foreign, failed, or otherwise ineligible asset is selected for generation, reject with a normalized `reference_asset_not_eligible` error.
- If an eligible reference asset is replaced or deleted while an Image Robot job is queued, the worker must either use the immutable references captured at job creation or fail with a typed stale-reference error; it must not silently swap in a different image.
- What must never happen: Bunny API keys in Flutter, arbitrary remote URL ingestion from user input, raw file bytes logged, EXIF/GPS data retained unintentionally, cross-project reference reuse, eligibility bypassed by client metadata, or historical generation provenance erased by replacement/deletion.

## Problem

ContentGlows's current AI visual direction is intentionally constrained: Image Robot uses validated project references and Bunny-hosted durable assets, while the editor-linked UI avoids arbitrary binary upload. That protects consistency and security, but it leaves a future gap: creators need a controlled way to add their own project visual assets without turning the product into an unsafe playground upload surface. Existing `content_assets` metadata can represent attached assets, and Bunny tooling can upload/delete storage objects, but there is no user-facing binary upload boundary, no project asset/reference eligibility lifecycle, no replacement/deletion semantics, and no hardened bridge from uploaded files to Image Robot reference selection.

## Solution

Add a backend-owned, proxied upload lifecycle for project visual assets and references: create upload attempts, validate bytes and metadata, strip unsafe metadata, store sanitized files in Bunny Storage, persist asset/reference/content asset metadata in Turso, and expose validated eligible references to Image Robot through project-scoped APIs. Flutter adds typed upload/reference methods and UI entry points only inside editor/project visual workflows; it never receives storage secrets or converts arbitrary URLs into publishable/Image Robot references.

## Scope In

- User-facing binary upload of project visual assets from ContentGlows app surfaces tied to project/editor visual workflows.
- Authenticated backend-proxied bounded multipart upload contract; direct-to-Bunny client upload is out of scope for V1.
- V1 allowlist: `image/jpeg`, `image/png`, and `image/webp`; reject GIF, SVG, TIFF, HEIC/HEIF, PDF, archives, video, audio, and unknown content.
- V1 limits: max 10 MiB per file, max 8 files per request, max 4096 px per side, max 16 decoded megapixels, max 50 active reference assets per project, and max 20 upload attempts per user per project per hour until the quota/billing spec replaces these caps.
- Validation of MIME type, extension, byte size, decoded dimensions, file name, duplicate hash, project ownership, content sniffing, and path safety.
- EXIF/GPS and ancillary metadata stripping before durable Bunny storage; original unstripped bytes are not preserved in V1.
- Bunny Storage upload under deterministic project/user/reference paths using existing Bunny configuration patterns.
- Durable Bunny CDN URL and optional optimizer metadata for uploaded references.
- Turso/libSQL metadata for project visual assets/references, upload attempts, upload versions, eligibility status, and failure/cleanup state.
- Integration with existing `content_assets` for references that are also attached to content records, using `source=image_reference`.
- Backend validation and eligibility workflow for project assets before Image Robot can consume them; no human approval step in V1.
- Project-level asset ownership plus optional content attachment and one-or-more placement links.
- Replacement/versioning of references without losing historical generation provenance.
- Tombstone/delete workflow for references and optional Bunny object deletion/cache purge according to policy.
- Image Robot reference resolution that consumes only eligible same-project references and records immutable reference provenance in generation metadata.
- Flutter `ApiService` typed methods for proxied multipart upload, listing assets/references, replacing, deleting, attaching to content/placements, and selecting references for generation.
- Tests for auth, ownership, validation, Bunny failure, Turso failure, eligibility gating, replacement, deletion, and Image Robot usage.
- Documentation updates for environment, storage limits, reference lifecycle, and operator cleanup.

## Scope Out

- Anonymous upload or public playground upload.
- Human approval workflow for uploaded references in V1.
- Direct-to-Bunny client uploads, signed Bunny write credentials in Flutter, or temporary browser-visible Bunny storage write tokens.
- Supabase Storage, Vercel Blob, Next.js upload routes, or client-side Bunny credentials.
- Uploading arbitrary non-image documents, PSD/AI/source design files, video references, or audio.
- Fine-tuning, LoRA training, identity guarantees, face recognition, or biometric identity verification.
- Additional semantic moderation service, legal review, copyright review, trademark review, face recognition, or human policy review beyond technical validation and provider safety at generation time.
- Automatic upload of existing local capture assets without explicit user action.
- Full digital asset management outside project visual references and content assets.
- Billing/quota enforcement beyond the conservative V1 abuse caps in this spec and the future PAYG quota/billing spec.
- Cross-project shared brand libraries unless explicitly designed in a separate spec.
- A standalone global upload playground or media library navigation item.

## Constraints

- Backend remains `lab` FastAPI with Clerk auth and Turso/libSQL persistence.
- Flutter remains `app` with `ApiService` and Riverpod; widgets must not make ad-hoc upload HTTP clients outside the service layer.
- Bunny Storage/CDN is the durable binary storage system; no alternate storage provider is introduced.
- Bunny Storage API keys stay server-side only.
- V1 upload transport is backend-proxied multipart streaming with bounded request bodies and deterministic server-generated storage paths.
- Upload validation must stream or spool within bounded limits; implementation must not load unbounded request bodies into memory.
- `content_assets` currently allows generic metadata writes; Image Robot/reference upload must add server-side validation rather than relying on client-provided `source`, `storage_uri`, or metadata.
- Current `ContentAssetStatus` only has `local_only`, `pending_upload`, `uploaded`, and `deleted`; advanced asset/reference eligibility needs either separate reference fields or carefully scoped asset metadata so local capture behavior is not broken.
- Existing local capture `device_capture` flow must remain local-only unless the user explicitly chooses to upload.
- Existing Flux/Image Robot V1 continues to use validated project references; this chantier supplies the future upload lifecycle for creating and maintaining those references from uploaded project assets.
- Reference usage by FLUX.2 remains limited by provider constraints, including multi-reference count, supported input image formats, and input moderation.
- Metadata and logs must redact signed URLs, storage access paths if sensitive, EXIF details, raw provider payloads, and secrets.
- Automated eligibility in V1 is technical/backend eligibility, not a human or legal approval statement. Provider safety checks still apply when assets are sent to FLUX.2.

## Dependencies

- Existing backend status asset contract:
  - `lab/api/routers/status.py`
  - `lab/status/service.py`
  - `lab/status/db.py`
  - `lab/api/models/status.py`
  - `lab/api/migrations/004_status_lifecycle.sql`
- Existing Bunny storage tools:
  - `lab/agents/images/tools/bunny_cdn_tools.py`
  - `lab/agents/images/cdn_manager.py`
- Existing Flutter API/provider patterns:
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
- Ready/active specs:
  - `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`
  - `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`
  - `shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md`
- External docs, `fresh-docs checked` by parent on 2026-05-11:
  - Black Forest Labs FLUX.2 overview: `https://docs.bfl.ai/flux_2/flux2_overview`
  - BFL FLUX.2 Pro API: `https://docs.bfl.ml/api-reference/models/generate-or-edit-an-image-with-flux2-%5Bpro%5D`
  - Bunny Storage API: `https://docs.bunny.net/api-reference/storage`
  - Bunny upload endpoint: `https://docs.bunny.net/api-reference/storage/manage-files/upload-file`
- Fresh external docs, `fresh-docs checked` by sf-ready on 2026-05-11:
  - BFL FLUX.2 overview confirms multi-reference guidance, style/composition support, and API reference limits up to 8 images for FLUX.2 Pro/Max/Flex API.
  - BFL FLUX.2 Pro API confirms `input_image` through `input_image_8`, width/height, `safety_tolerance`, output formats `jpeg`, `png`, `webp`, and async polling response fields.
  - Bunny Storage API confirms Storage API authentication uses server-side `AccessKey` for the storage zone password.
  - Bunny Upload File API confirms raw PUT upload to storage path, optional SHA256 checksum header, and `201` success response.

## Invariants

- Every uploaded reference belongs to exactly one authenticated user and one project unless a future cross-project library spec changes that explicitly.
- A project asset is usable by Image Robot only after backend validation proves it is durable, owned by the same project/user, not deleted, and eligible for reference/image-to-image use.
- A Bunny object is not considered durable product state until Turso metadata exists.
- A Turso reference row is not considered usable until Bunny upload validation/finalization succeeds.
- `content_assets` records are not trusted as Image Robot references unless linked to a validated image reference or generation record.
- Historical Image Robot generations keep immutable provenance for the reference IDs and resolved asset versions used.
- Replacement creates a new active version; it does not rewrite past generation provenance.
- Deletion/tombstone prevents future use but must preserve enough metadata for audit and history.
- During the 30-day history window, deleted assets are hidden from normal selection lists, remain visible only as historical provenance where a past generation/content link needs explanation, and cannot satisfy future generation, primary placement, or publish eligibility.
- If a deleted asset is still linked to content placement metadata, the link remains historical but is not publishable or selectable as a future primary visual; the UI/backend must require replacement before future publish for that placement.
- Client-provided file names, MIME types, dimensions, and metadata are hints only; backend validation is authoritative.
- Existing local-only capture metadata cannot become uploaded or publishable without explicit backend upload/finalization.

## Links & Consequences

- `lab/api/routers/status.py`: existing asset endpoints need hardening or a dedicated reference-safe attach path so uploaded reference assets cannot be forged through generic metadata.
- `lab/status/service.py`: current asset CRUD supports metadata, update, and tombstone but lacks primary/reference/version/eligibility semantics.
- `lab/status/db.py` and `api/migrations/004_status_lifecycle.sql`: schema must add upload/reference tables or columns idempotently for Turso.
- `lab/api/models/status.py`: content asset request/response models may need fields or stricter models for uploaded image references and eligibility state.
- `lab/agents/images/tools/bunny_cdn_tools.py`: current helper accepts URL or local path; this chantier needs a safer bytes/file-object upload path and SSRF-resistant constraints.
- `lab/agents/images/cdn_manager.py`: optimizer upload patterns should be reused where they make sense, but upload validation must happen before CDN manager storage.
- `app/lib/data/services/api_service.dart`: add typed binary upload/reference methods and error mapping; do not leak raw upload internals to widgets.
- `app/lib/providers/providers.dart`: add focused state for upload progress, reference list, and selection without mixing it into unrelated content providers if feature complexity grows.
- Image Robot/Flux: reference resolution must select only eligible project references and enforce provider reference limits.
- Operations: orphan Bunny object cleanup, failed upload recovery, cache purge, and audit logs become required operational concerns.
- Documentation/support: user-facing wording must explain that references guide consistency after backend validation; it must not promise exact identity replication.

## Documentation Coherence

- Update `lab` setup docs with Bunny upload variables, storage zone/hostname expectations, upload size limits, and cleanup operations.
- Update backend API docs or README with proxied upload attempt/finalization, reference lifecycle, eligibility statuses, replacement, deletion, and Image Robot reference usage.
- Update `app/README.md` with online-only upload behavior and the difference between local capture metadata and durable uploaded references.
- Update changelogs for both app and backend after implementation.
- Add support/operator notes for failed upload cleanup, Bunny delete/purge failures, and reference eligibility troubleshooting.
- Add localization strings for upload progress, validation errors, eligibility states, replacement confirmation, and deletion/tombstone outcomes.

## Edge Cases

- User uploads multiple files and one fails validation.
- Same file uploaded twice to the same project.
- Same file uploaded to two different projects by the same user.
- Upload attempt created but the proxied multipart request is aborted before durable metadata is finalized.
- Upload succeeds to Bunny but finalization fails in Turso.
- Turso row exists in pending state but Bunny object is missing.
- EXIF orientation changes displayed dimensions.
- EXIF/GPS metadata is present and must be stripped before durable storage.
- Animated GIF or very large PNG passes extension check but fails actual content validation.
- User renames a file with a misleading extension.
- Upload is retried after app background/foreground.
- User switches active project during upload.
- User loses project access between upload start and finalization.
- Reference asset is made eligible while replacement is in progress.
- Reference is deleted while queued Image Robot jobs still reference it.
- Bunny cache purge fails after replacement or deletion.
- Reference count exceeds the FLUX.2 provider limit; backend must choose explicit ordering or require user selection.
- Content asset is attached to content but reference eligibility is later revoked.
- Existing `device_capture` asset has the same client asset id as an upload candidate.
- User reaches per-hour upload attempt cap or active project reference cap.
- Deleted reference is still linked to a content placement that a publish flow tries to use.

## Implementation Tasks

- [ ] Task 1: Define upload/reference schema and lifecycle states
  - File: `lab/api/migrations/004_status_lifecycle.sql`
  - Action: Add idempotent Turso schema for upload attempts, project visual assets/references, and reference versions, or add equivalent tables with clear links to `content_assets`. Include project/user ownership, Bunny storage path, CDN URL, MIME, byte size, dimensions, hash, eligibility status, active version, deleted_at, history_expires_at, and cleanup/error fields.
  - User story link: Creates durable, auditable project references for Image Robot.
  - Depends on: none.
  - Validate with: migration applied twice against a test libSQL/SQLite connection without destructive changes.
  - Notes: Do not overload `content_assets.metadata` as the only source of truth for eligibility/versioning.

- [ ] Task 2: Add backend models for upload attempts and references
  - File: `lab/api/models/status.py`
  - Action: Add Pydantic request/response models for proxied upload attempt, uploaded project asset/reference, eligibility state, replacement, deletion, content placement links, and normalized upload errors.
  - User story link: Gives Flutter a typed contract for upload, eligibility, and placement states.
  - Depends on: Task 1.
  - Validate with: model import/validation tests for allowed statuses, MIME, size fields, reference IDs, and error codes.
  - Notes: Keep existing local capture models backward compatible.

- [ ] Task 3: Extend status service with reference persistence
  - File: `lab/status/service.py`
  - Action: Add service methods for create upload attempt, finalize proxied upload metadata, list project assets/references, mark/select eligible references, create replacement version, tombstone/delete, link to content/placements, and lookup eligible references for Image Robot by project/user.
  - User story link: Enforces lifecycle transitions server-side instead of trusting Flutter metadata.
  - Depends on: Tasks 1 and 2.
  - Validate with: unit tests for ownership inputs, idempotency, replacement history, tombstone behavior, and historical version lookup.
  - Notes: Preserve `create_content_asset` behavior for `device_capture`.

- [ ] Task 4: Harden Bunny binary upload utilities
  - File: `lab/agents/images/tools/bunny_cdn_tools.py`
  - Action: Add a safe upload function for backend-validated bytes or bounded file streams, with V1 MIME allowlist, 10 MiB max byte enforcement, SHA256 checksum support where practical, deterministic storage paths, content type, timeout, and no arbitrary remote URL fetching for user uploads.
  - User story link: Stores user-provided references durably without turning upload into SSRF or unbounded resource usage.
  - Depends on: Task 2.
  - Validate with: tests for allowed image upload, oversize rejection, bad MIME rejection, path traversal rejection, and Bunny error mapping.
  - Notes: Existing URL/local path helper can remain for legacy agent flows but must not be the user-upload boundary.

- [ ] Task 5: Add CDN/optimizer metadata handling for references
  - File: `lab/agents/images/cdn_manager.py`
  - Action: Reuse or add a method that returns stable CDN URL, storage path, optimizer/responsive metadata, byte size, content type, and propagation status for uploaded references.
  - User story link: Provides durable reference URLs to Image Robot and app previews.
  - Depends on: Task 4.
  - Validate with: mocked Bunny upload/optimizer tests and propagation failure behavior.
  - Notes: Propagation failure should not automatically make a reference asset eligible.

- [ ] Task 6: Add authenticated upload/reference API routes
  - File: `lab/api/routers/status.py`
  - Action: Add project-scoped endpoints for proxied multipart upload, list assets/references, mark/select eligible references, replace active file, delete/tombstone reference assets, and optionally attach assets to content placements.
  - User story link: Exposes the controlled user-facing reference workflow.
  - Depends on: Tasks 2, 3, 4, and 5.
  - Validate with: route tests for auth, project ownership, invalid file metadata, duplicate finalize, forbidden eligibility mutation, replace, delete, and list filtering.
  - Notes: If routes are placed under an image router during implementation, keep status/content asset interactions explicit and documented.

- [ ] Task 7: Harden content asset linkage for uploaded references
  - File: `lab/status/service.py`
  - Action: Add server-side validation so `content_assets` with reference/image_robot sources must link to an owned validated reference asset or generation record; add placement/reference metadata only through backend-controlled fields.
  - User story link: Prevents arbitrary user-provided `storage_uri` from becoming a trusted Image Robot or publishable asset.
  - Depends on: Tasks 3 and 6.
  - Validate with: tests that forged `storage_uri`, foreign reference IDs, ineligible references, and deleted references cannot be attached as trusted assets.
  - Notes: Generic local capture metadata remains allowed as `source=device_capture`, `status=local_only`.

- [ ] Task 8: Integrate eligible references with Image Robot resolution
  - File: `lab/api/routers/status.py`
  - Action: Expose or delegate a backend function that Image Robot/Flux can call to resolve eligible references by project/user, selected reference IDs, active version, Bunny URL, dimensions, reference role (`brand_style`, `character_consistency`, `composition`, or `general_reference`), and provider eligibility.
  - User story link: Ensures uploaded references actually guide future image generation.
  - Depends on: Tasks 3 and 6.
  - Validate with: integration tests where eligible references are accepted, ineligible/deleted/foreign references are rejected, and generation provenance stores immutable version IDs.
  - Notes: If Image Robot implementation owns this in an images router/service, keep this status service as the source of reference metadata.

- [ ] Task 9: Add Flutter API methods for upload/reference lifecycle
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add typed methods for proxied multipart upload, list project assets/references, replace, delete, attach to content/placements, promote/select references, and reference selection. Add normalized error mapping for validation, auth, storage, quota/rate, and stale state.
  - User story link: Lets creators manage references from the app without direct storage credentials.
  - Depends on: Task 6.
  - Validate with: Dart tests for request serialization, response parsing, upload progress hooks where applicable, and sanitized diagnostics.
  - Notes: Do not log binary payloads, signed URLs, or storage secrets.

- [ ] Task 10: Add Riverpod state for reference upload and selection
  - File: `app/lib/providers/providers.dart`
  - Action: Add focused providers/notifiers for project asset/reference list, upload progress, eligibility states, selected references for generation, and stale project-change cancellation.
  - User story link: Gives UI workflows reliable state for uploads and Image Robot selection.
  - Depends on: Task 9.
  - Validate with: provider tests for project switch, upload failure, retry, delete, replacement, and stale response ignoring.
  - Notes: Move to a dedicated provider file only if implementation size justifies it and matches repo patterns.

- [ ] Task 11: Add operator cleanup and audit hooks
  - File: `lab/status/db.py`
  - Action: Add helper accessors or scheduled-query support for orphan upload attempts, Bunny objects needing cleanup, failed delete/purge states, and reference audit events.
  - User story link: Keeps storage and audit state recoverable after partial failures.
  - Depends on: Tasks 1 and 3.
  - Validate with: tests or admin script dry-run for stale intent cleanup and failed storage cleanup listing.
  - Notes: Actual scheduling may be a separate implementation detail if no scheduler pattern exists.

- [ ] Task 12: Document advanced visual reference upload
  - File: `lab/README.md`
  - Action: Document Bunny config, upload limits, lifecycle states, eligibility rules, 30-day history/cleanup behavior, and Image Robot reference eligibility.
  - User story link: Makes the high-risk storage behavior operable after shipping.
  - Depends on: Tasks 1-11.
  - Validate with: docs review against final API/status names.
  - Notes: Also update app changelog/README if those files are part of the implementation scope.

## Acceptance Criteria

- [ ] CA 1: Given an authenticated user owns a project, when they upload a valid image reference, then a Bunny-backed reference record is created for that project and returned with durable metadata.
- [ ] CA 2: Given an unauthenticated request, when upload/reference endpoints are called, then the backend returns `401` and no Bunny object or Turso record is created.
- [ ] CA 3: Given a user targets a foreign project, when they create/finalize/list/promote/delete references, then the backend rejects the request without revealing foreign metadata.
- [ ] CA 4: Given a file exceeds allowed limits or fails MIME/content validation, when upload is attempted, then the backend returns a typed validation error and the reference asset is not selectable or promotable.
- [ ] CA 4a: Given a user uploads GIF, SVG, HEIC/HEIF, TIFF, PDF, video, audio, archive, a renamed file with misleading extension, a file larger than 10 MiB, more than 8 files in one request, more than 4096 px per side, or more than 16 decoded megapixels, when upload is attempted, then the backend rejects it before durable eligibility and returns a typed validation error.
- [ ] CA 5: Given Bunny upload succeeds but Turso persistence fails, when the request completes, then the response reports failure/recovery state and the object is deleted or queued for cleanup.
- [ ] CA 6: Given a reference asset is not durable, not eligible, deleted, or foreign, when Image Robot tries to use it, then generation is rejected with `reference_asset_not_eligible` or excludes it only when the user did not explicitly select it.
- [ ] CA 7: Given a reference asset is eligible, when Image Robot generates with selected references, then only same-project eligible active versions are sent to FLUX.2 and generation metadata records immutable reference provenance.
- [ ] CA 8: Given a reference is replaced, when future generations run, then they use the new active version while past generation history still points to the prior version used at execution time.
- [ ] CA 9: Given a reference is deleted/tombstoned, when references are listed for generation or publish/primary placement eligibility is checked, then it is not selectable or publishable for future use, while audit/history metadata remains available for 30 days.
- [ ] CA 10: Given a user forges a `content_assets` request with `source=image_reference` and arbitrary `storage_uri`, when the backend validates it, then the request is rejected unless it links to an owned validated reference.
- [ ] CA 11: Given the app backgrounds or project changes during upload, when the old upload response returns, then the UI ignores stale state and does not attach the reference to the wrong project.
- [ ] CA 12: Given local capture metadata exists, when this feature is enabled, then existing `device_capture` local-only assets remain local-only until explicit upload action.
- [ ] CA 13: Given an uploaded image contains EXIF/GPS or ancillary metadata, when validation succeeds, then the stored Bunny object is the sanitized derivative without preserved EXIF/GPS metadata.
- [ ] CA 14: Given a user exceeds V1 upload attempt or active reference caps, when upload is requested, then the backend returns a typed rate/limit error and does not create a new active reference.
- [ ] CA 15: Given selected references include roles for brand style, character consistency, or composition, when Image Robot resolves references, then those roles are stored in generation provenance and never inferred solely from client metadata.

## Test Strategy

- Backend model tests for upload/reference Pydantic validation and normalized error codes.
- Migration tests applying `004_status_lifecycle.sql` plus idempotent migrations twice against test libSQL/SQLite.
- Service tests for upload attempt lifecycle, finalization idempotency, eligibility transitions, replacement versioning, tombstone/delete, and historical provenance.
- Route tests for Clerk-authenticated ownership checks, invalid project/content/reference IDs, validation failure, and forbidden cross-project access.
- Bunny utility tests with mocked `requests.put`, `delete`, `head`, and failure states; include timeout, 401, 404 delete success, and purge failure.
- Security tests for path traversal file names, misleading extensions, bad MIME, oversized files, unbounded payload prevention, and forged `storage_uri`.
- Security tests for EXIF/GPS stripping, duplicate replay, upload cap enforcement, deleted asset publish blocking, and cross-project placement linking.
- Image Robot integration tests for eligible, ineligible, deleted, replaced, and foreign references.
- Flutter API tests for upload/reference serialization, response parsing, retry/error mapping, diagnostics redaction, and project-switch stale response handling.
- Manual QA after implementation: upload a valid image, reject invalid image, promote/select reference use, use it in Image Robot, replace it, delete it, confirm old generation provenance still displays.

## Risks

- High security risk: user-controlled binary upload can introduce malware, EXIF privacy leaks, storage abuse, SSRF if remote URL ingestion is allowed, and forged publish/reference assets. V1 mitigates this with authenticated-only backend-proxied upload, server-side ownership checks, file/type/dimension limits, metadata stripping, deterministic Bunny paths, no remote URL ingestion, no client Bunny credentials, and server-side eligibility gates.
- High data risk: partial Bunny/Turso failures can create orphan files or eligible metadata pointing to missing files.
- Medium product risk: V1 intentionally has no human approval gate, so automated/backend eligibility rules must be clear enough to prevent unsafe or broken assets feeding Image Robot.
- Medium performance/cost risk: large images and repeated uploads can increase bandwidth, storage, optimizer, and provider costs.
- Medium UX risk: replacement/deletion semantics can confuse users if "delete" does not physically delete immediately or if prior generations retain provenance.
- Medium compliance risk: references may contain people, brands, copyrighted material, or private data; V1 does not claim legal, copyright, trademark, likeness, or exact identity safety, and documentation/copy must keep that limit explicit while provider safety handles generation-time rejection.
- Medium implementation risk: reusing generic `content_assets` without stricter server-side validation would create a trust boundary bug.

## Execution Notes

- Read first:
  - `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`
  - `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`
  - `lab/api/routers/status.py`
  - `lab/status/service.py`
  - `lab/agents/images/tools/bunny_cdn_tools.py`
  - `app/lib/data/services/api_service.dart`
- Start backend-first: schema/models/service/routes, then Bunny hardening, then Image Robot resolution, then Flutter API/providers.
- Keep upload secrets server-side. Flutter may receive upload status and progress data, but not Bunny `AccessKey` or storage-zone write credentials.
- Use backend-proxied bounded multipart upload for V1. Do not implement direct-to-Bunny upload in this chantier.
- Enforce V1 file policy exactly: JPEG/PNG/WebP only, 10 MiB per file, 8 files per request, 4096 px per side, 16 decoded megapixels, 50 active project references, and 20 upload attempts per user/project/hour.
- Strip EXIF/GPS and ancillary metadata before Bunny storage; store sanitized derivatives only and record `metadata_stripped=true`.
- Do not add a semantic moderation provider in this chantier unless one already exists behind a clearly documented internal policy. When references are sent to FLUX.2, keep provider `safety_tolerance` at the existing safe default from the Flux/Image Robot spec and persist provider safety rejection as a typed failure.
- Store immutable reference version IDs in generation provenance; do not rely only on active reference IDs.
- Treat `content_assets` as attachment metadata, not as the whole reference/version lifecycle unless schema changes make eligibility and provenance explicit.
- External docs verdict: `fresh-docs checked` by parent and sf-ready for BFL FLUX.2 and Bunny Storage on 2026-05-11. Re-check official docs during implementation if provider reference limits, FLUX.2 input-image behavior, Bunny Storage authentication, or Bunny upload semantics change.
- Suggested validation commands depend on final test layout, but should include targeted Python import/tests for `api.models.status`, `status.service`, Bunny tools, route tests, plus Dart tests for `api_service.dart` and providers.
- Stop conditions: if implementation cannot enforce backend-proxied bounded upload, server-side Bunny credentials, EXIF/GPS stripping, active reference caps, upload attempt caps, project ownership, content placement ownership, or deleted-asset publish blocking, stop and return to `/sf-spec` instead of weakening the contract.

## Product Decisions Captured

- Uploaded images start as project assets.
- V1 has no human approval step; backend validation and eligibility checks are still mandatory.
- Image-to-image/reference behavior should support brand style, character consistency, and composition guidance.
- Deletion/removal blocks future use immediately and keeps a 30-day history before cleanup.
- Asset scope is project first, then optional content attachment and one or more placements.
- V1 upload transport is backend-proxied bounded multipart; direct-to-Bunny client upload is deferred.
- V1 stores sanitized derivatives only; EXIF/GPS and ancillary metadata are stripped and original unstripped bytes are not preserved.
- V1 deleted/tombstoned assets remain historical for provenance but are not selectable, publishable, or eligible as primary placement assets for future use.
- V1 uses conservative fixed upload/storage/rate caps until a dedicated quota/billing spec replaces them.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 | sf-spec | gpt-5.5 | Created draft spec for advanced binary upload and lifecycle of project visual references. | draft saved; blocked by product/security open questions | /sf-ready shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md |
| 2026-05-11 15:38:45 UTC | sf-spec | GPT-5 Codex | Integrated user product decisions for upload defaults, no approval, reference guidance, 30-day history, and project/content/placement scope. | Draft updated; remaining blockers narrowed to upload/security/ops policy. | /sf-ready shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md |
| 2026-05-11 16:01:53 UTC | sf-ready | GPT-5 Codex | Ran readiness gate, resolved technical/security execution gaps within existing product decisions, checked current BFL/Bunny official docs, and updated readiness trace. | ready | /sf-start AI Visual Reference Upload Advanced |

## Current Chantier Flow

sf-spec ✅ -> sf-ready ✅ -> sf-start ⏳ -> sf-verify ⏳ -> sf-end ⏳ -> sf-ship ⏳
