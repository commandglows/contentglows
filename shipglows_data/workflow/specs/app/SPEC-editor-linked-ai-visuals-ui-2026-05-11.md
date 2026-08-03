---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-11"
created_at: "2026-05-11 13:44:58 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 14:41:31 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que créatrice ContentGlowz authentifiée, je veux générer, revoir et attacher des visuels IA depuis l'éditeur du contenu courant, afin d'alimenter mes articles, posts, thumbnails et futurs assets vidéo sans ouvrir un playground libre."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "api/images"
  - "api/status/content assets"
  - "Image Robot"
  - "Bunny CDN"
  - "Clerk"
  - "Remotion render workflow"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-editor-multiformat.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/reels-from-content-preview-workflow.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "contentglowz/v0-flux-2-playground"
    artifact_version: "unknown"
    required_status: "inspiration-only"
supersedes: []
evidence:
  - "User decision 2026-05-11: Flux/Image Robot generation should integrate into existing guided workflows, not as a free playground."
  - "User decision 2026-05-11: primary uses are blog images, thumbnails, post visuals, and later video images."
  - "User decision 2026-05-11: V1 UI should be tied to the existing editor; if a dedicated surface exists, it is linked from the editor, not standalone navigation."
  - "Code evidence: app/lib/presentation/screens/editor/editor_screen.dart is the current content editor with AppBar actions, platform preview, save, publish, and audit trail."
  - "Code evidence: app/lib/router.dart has /editor/:id but no Remotion editor route currently integrated."
  - "Code evidence: app/lib/presentation/screens/reels/reels_screen.dart exists, but Remotion UI work is governed by the ready reels specs."
  - "Code evidence: lab/api/routers/status.py already exposes /api/status/content/{content_id}/assets for attached content asset metadata."
  - "Code evidence: app/lib/data/services/api_service.dart already attaches capture assets to content through /api/status/content/{id}/assets."
  - "Code evidence: app/lib/router.dart currently sanitizes /editor/* before a visuals-specific branch; implementation must add /editor/:id/visuals before the generic editor sanitizer."
  - "Code evidence: app/lib/data/models/content_item.dart currently has imageUrl/copyWith imageUrl but lacks a typed projectId field."
  - "Code evidence: lab/api/routers/publish.py currently accepts raw media_urls; publish hardening is required before live Image Robot media publishing."
  - "Prototype evidence: contentglowz/v0-flux-2-playground has useful concepts: reference images, profile-like ratios, history, gallery/single result, and use-as-input, but its Next/Supabase/Vercel stack is excluded."
next_step: "/sf-start Editor-Linked AI Visuals UI"
---

# Title

Editor-Linked AI Visuals UI

## Status

Ready. This spec creates the Flutter UI/workflow for AI visual generation attached to the existing content editor. It depends on the ready Flux/Image Robot backend spec for generation and on existing content asset endpoints for content attachment. It intentionally does not create a global visual playground or a full Remotion editor.

## User Story

En tant que créatrice ContentGlowz authentifiée, je veux générer, revoir et attacher des visuels IA depuis l'éditeur du contenu courant, afin d'alimenter mes articles, posts, thumbnails et futurs assets vidéo sans ouvrir un playground libre.

## Minimal Behavior Contract

Depuis l'éditeur d'un contenu appartenant au projet actif, ContentGlowz ouvre une surface visuelle liée à ce contenu, propose des placements guidés selon le format du contenu, affiche les références visuelles approuvées du projet, permet de lancer ou suivre une génération Image Robot asynchrone, puis permet de garder une image durable Bunny comme option candidate ou de l'utiliser comme visuel primaire pour un placement. Côté système, "attacher" signifie seulement lier l'image au contenu; côté interface, V1 doit exposer des actions compréhensibles comme "garder comme option" et "utiliser pour ce placement", pas un libellé technique "attacher". Si le projet, le contenu, les références, le job Image Robot, le CDN, l'attachement asset, la sélection primaire, ou la validation d'appartenance génération-contenu échoue, l'interface conserve l'état éditeur, montre une erreur récupérable, et ne prétend jamais qu'un visuel est prêt ou publié. Le cas facile à rater est de traiter cette surface comme un prompt playground: V1 doit partir du contenu courant, des profils, des références projet et des placements attendus, pas d'un champ libre modèle/ratio/provider.

## Success Behavior

- Given an authenticated creator opens `/editor/:id` for owned content, when they tap the visuals action, then the app opens `/editor/:id/visuals` without adding a global navigation item.
- Given the visual editor opens, when the active project and content detail load, then the UI shows the content context, supported placements, existing content visual assets, project visual references, and recent project generations relevant to that content.
- Given the creator selects a guided placement such as blog hero, social visual, thumbnail, or video cover, when they start generation, then the app creates an Image Robot generation job/profile request scoped to the active project and content.
- Given the backend returns a queued/in-progress generation, when the app polls the generation status, then the UI shows an observable pending state until the job completes, fails, or is cancelled.
- Given generation completes with a durable Bunny URL, when the creator chooses "keep as option", then the app links it to the content as a non-primary candidate through the backend's Image Robot-safe content asset path with source `image_robot`, kind `image`, status `uploaded`, placement metadata, generation id, provider, profile id, alt text, and storage URI.
- Given the creator chooses "use for this placement", when the image is not yet linked to the content, then the app first links it as an `image_robot` asset and then sets it primary for that placement through the server-side atomic primary action.
- Given the app links an `image_robot` result to a content record, when the backend accepts the request, then the accepted asset must be tied to a generation/result owned by the same user, project, and content; the Flutter client must not turn arbitrary user-supplied URLs into publishable content assets.
- Given the creator chooses "use for this placement", when the asset is set primary, then the backend atomically makes it the only primary `image_robot` asset for that content and placement; non-primary candidates remain available for comparison but do not publish.
- Given a generated result should become future visual memory, when the creator chooses "save as reference", then the app calls the Image Robot visual-reference API and refreshes the project reference list.
- Given a content item has a selected primary visual asset, when it is published through an existing `channelToPlatform` social channel (`twitter`, `linkedin`, `instagram`, `tiktok`, `youtube`), then `PendingContentNotifier.approve` passes the selected visual URL through `mediaUrls` while preserving text-body reliability rules.
- Given a future Remotion render flow needs a cover image, when it reads content assets, then `video_cover` assets created here are discoverable through placement metadata without this spec changing Remotion rendering.

## Error Behavior

- If there is no active project, the visuals action is disabled or opens a recoverable no-project state; no generation request is sent.
- If content detail cannot load or belongs to another user/project, the screen shows the same ownership-safe unavailable behavior as the editor and does not expose cached cross-project visuals.
- If Image Robot profiles cannot load, generation controls are disabled and existing attached assets remain visible if available.
- If project references fail to load, generation may continue without references only when the request uses automatic project memory; explicitly selected missing/foreign references must block generation.
- If generation returns `queued` or `in_progress`, the app polls with bounded lifecycle and stops polling when the route is disposed, project changes, or the job reaches a terminal state.
- If the provider/backend returns a typed failure such as missing provider config, moderation rejection, rate limit, timeout, CDN upload failure, or history persistence failure, the UI shows a sanitized recoverable state and does not attach an asset.
- If an attached asset POST succeeds but content refresh fails, the app shows a local success with a refresh action and invalidates content detail/history providers.
- If linking an image as a candidate fails, the generated result stays visible as a result but is not shown among content options and cannot be set primary.
- If setting a primary fails after candidate linking succeeds, the image remains a candidate, the previous primary remains active, and publish media is unchanged.
- If publishing sees a selected primary visual with no durable `storage_uri`/URL or failed ownership validation, the app blocks publish with a recoverable error explaining that the visual must be fixed or unselected before publishing; it must not pass temporary provider URLs or silently publish text-only.
- If multiple assets are returned as primary for the same placement, the UI shows a recoverable conflict state, refreshes/retries primary reconciliation, and excludes that placement from publish media until a single durable primary is confirmed.
- If the user changes active project while generation or attachment is in flight, stale responses are ignored and the visual editor resets to the new project/content state.
- What must never happen: provider API keys in Flutter, raw base64 images stored in app state/logs, arbitrary local file upload in this V1, cross-project reference reuse, a global playground nav entry, or Remotion timeline editing hidden inside this UI.

## Problem

ContentGlowz already has a content editor and Image Robot backend foundations, but AI image generation would be easy to bolt on as a standalone Flux playground. That would conflict with the product direction: users should review and distribute guided content, not manually generate isolated images outside the flow. The app also already has `ContentItem.imageUrl`, content asset endpoints, content publish media parameters, and future Remotion specs, so the missing piece is an editor-linked visual workflow that connects generated images to a specific content item.

## Solution

Add a child visual editor route launched from `EditorScreen`, backed by typed Flutter models, `ApiService` methods, and Riverpod state. The screen presents guided placements and Image Robot results for the current content, attaches generated images through an Image Robot-safe content asset path, lets the creator set a single primary per placement, and makes selected primary images available to publishing and future Remotion asset selection.

## Scope In

- Add an editor AppBar visual action for content that has an active project.
- Add route `/editor/:id/visuals` with sanitized Sentry route name `/editor/:id/visuals`.
- Add a Flutter visual editor screen tied to one `contentId`, not a global `/visuals` nav entry.
- Show guided placement tabs/options:
  - `blog_hero` for articles/blog/newsletter hero usage.
  - `social_visual` for social post and cross-post visuals.
  - `thumbnail` for YouTube/video/reel cover usage.
  - `video_cover` as asset metadata for future Remotion/reels workflows, without timeline editing.
- Load Image Robot profiles, project visual references, recent generations, and content-attached visual assets.
- Queue or request Image Robot generation through the app API client using project id, content id, placement, profile id, optional creative direction, and selected approved reference ids.
- Poll generation status while the route is active.
- Preview completed generated images using cached network images and stable aspect-ratio containers.
- Let the creator keep a generated image as a non-primary content option through the existing content asset endpoint.
- Let the creator use a generated image or existing option for the current placement through a server-side atomic primary update; if the image is not yet linked to the content, link it first.
- Promote a generated durable image to project visual reference through Image Robot visual-reference API.
- Pass selected visual URLs to publish only for channels already mapped by `channelToPlatform`: `twitter`, `linkedin`, `instagram`, `tiktok`, and `youtube`.
- Add localization strings, tests, README/changelog notes, and diagnostics that redact signed URLs/provider details.

## Scope Out

- A standalone `/visuals`, `/images`, or playground navigation item.
- Anonymous generation, demo-only public generation, Supabase, Vercel Blob, Vercel OAuth, or Next.js routes.
- Arbitrary model/provider/ratio controls in the UI.
- Local file upload for arbitrary reference images in V1; binary upload needs a separate storage/upload spec.
- Full asset library management outside the current content/project.
- Full Remotion editor, timeline, scene ordering, browser Remotion Player, or MP4 rendering changes.
- Remotion scene image selection beyond `video_cover`.
- Automatic insertion into article markdown body.
- Fine-tuning, LoRA, custom model training, or identity guarantees beyond guided visual consistency.
- Offline generation or offline binary/media replay.
- New publish provider integration; this spec only passes existing media URLs to the current publish path.

## Constraints

- `app` remains Flutter + Riverpod + GoRouter + Dio; no React/Next prototype code is imported.
- `lab` remains the only public generation and storage boundary.
- V1 must not add a global AppShell nav item.
- Generation and reference writes are online-only.
- The screen must use typed models and `ApiService`; widgets must not make ad-hoc Dio/fetch calls.
- `ContentItem.body` and full-body publish reliability invariants remain unchanged.
- Generated images are considered usable by the app only after the backend returns a durable Bunny URL or content asset storage URI.
- Flutter must never see provider secrets, provider polling URLs that act as secrets, raw provider payloads, or local backend file paths.
- Signed URLs, if any are used by future endpoints, must be redacted from diagnostics and not persisted in local cache.
- `image_robot` attachments are publishable only when they originate from a backend Image Robot result/reference record owned by the same content/project/user. If the backend only exposes a raw `storage_uri` attach path with no generation ownership validation, implementation must stop and route that backend hardening before enabling publish media.
- Publish media resolution must include only selected primary image assets with `source=image_robot`, `status=uploaded`, durable HTTP(S)/Bunny URL or backend-public URL, matching placement metadata, and no conflict state.
- Candidate content assets are review/options inventory only; candidates never publish, never satisfy Remotion cover selection, and never replace the primary visual until the primary action succeeds.
- Blog/newsletter visual assets are linked for editor/review/future CMS usage; they are not pushed through the current `mediaUrls` path unless their channel is mapped by `channelToPlatform`.
- Publish requests that include media must be validated server-side against owned content assets or generation records; Flutter-side URL filtering is defense-in-depth only.
- UI copy must stay guided by placement and content outcome, not provider marketing language.
- Existing capture asset behavior must remain unchanged.

## Dependencies

- Ready backend generation contract: `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`.
- Existing editor contracts:
  - `shipglows_data/workflow/specs/app/SPEC-content-editor-multiformat.md`
  - `shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md`
- Existing/future video contracts:
  - `shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md`
  - `shipglows_data/workflow/specs/monorepo/reels-from-content-preview-workflow.md`
- Existing app files:
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/data/models/content_item.dart`
  - `app/lib/l10n/app_localizations.dart`
  - `app/lib/presentation/theme/app_theme.dart`
- Existing backend status asset contract:
  - `lab/api/models/status.py`
  - `lab/api/routers/status.py`
  - `lab/status/service.py`
- Existing publish media contract:
  - `app/lib/data/services/api_service.dart` `publishContent(mediaUrls: ...)`
  - `lab/api/routers/publish.py` `PublishRequest.media_urls`
  - `app/lib/providers/providers.dart` `channelToPlatform` currently maps `twitter`, `linkedin`, `instagram`, `tiktok`, and `youtube`; other channels are not V1 media publish targets.
- Existing Flutter dependency for network image previews: `cached_network_image`.
- App-facing Image Robot routes expected by this UI:
  - `GET /api/images/profiles?provider=flux&project_id={project_id}` lists Flux-capable guided profiles.
  - `POST /api/images/generate-from-profile` creates a queued generation when `image_provider=flux` and returns `generation_id`, `job_id`, `status`, `project_id`, `content_id`, `profile_id`, and normalized status/error fields.
  - `GET /api/images/generations/{generation_id}` returns status, durable URLs, profile/provider metadata, reference IDs, and normalized errors for an owned generation.
  - `GET /api/images/history?project_id={project_id}&content_id={content_id}` returns recent owned generations relevant to the current content/project.
  - `GET /api/images/references?project_id={project_id}` lists approved project visual references.
  - `POST /api/images/references` promotes an owned durable generation/result to a project reference.
  - `POST /api/status/content/{content_id}/assets` may be used for `image_robot` only if the backend validates the referenced generation/result; otherwise use the backend's dedicated attach-by-generation endpoint if introduced during the Flux implementation.
  - `PATCH /api/status/content/{content_id}/assets/{asset_id}/primary` or equivalent server-side action atomically sets the single primary asset for one placement.
- Backend precondition for end-to-end enablement: the Flux/Image Robot implementation must expose durable generation status/history/reference endpoints, and either validate `source=image_robot` content asset attachment against owned generation records or expose a dedicated attach-by-generation/result endpoint. UI implementation may build typed clients and mocks before that backend is shipped, but final enablement must stop if server-side validation is absent.
- Fresh external docs verdict: `fresh-docs not needed` for this UI spec because it uses local app/backend contracts and existing dependencies. Remotion API behavior is governed by the ready Remotion specs that already captured official docs.

## Invariants

- The visual editor always has a `contentId`.
- `ContentItem` exposes a typed `projectId`; the current `contentId` and active project id must agree before generation, attachment, primary selection, publish media resolution, or reference actions.
- Project visual references are project-scoped and approved by the backend.
- A generated result is not a content visual option until it is linked through a server-validated Image Robot content asset action.
- A content visual asset stores durable URL metadata, placement, generation id, provider, profile id, and selected/primary state.
- A non-primary candidate can be attached to content for comparison, but only the primary asset for a placement affects publish media or future Remotion cover lookup.
- Only one asset per content placement is treated as primary at a time. If backend responses contain duplicate primaries, the UI must surface a conflict and avoid publishing media for that placement until reconciliation succeeds.
- Publishing uses full body resolution first, then media URL resolution; failure to resolve media must not cause a preview body fallback.
- Future Remotion workflows consume visual assets by metadata; this UI does not render videos.
- Existing Robolly/OpenAI/template image flows keep their behavior.

## Links & Consequences

- `EditorScreen` gains a visual action and may need content detail invalidation when assets are attached.
- `router.dart` gains a route and Sentry route sanitizer branch.
- `ApiService` expands from capture-only content asset attachment to generic content asset listing/attachment/update for image robot assets.
- The Image Robot attach path must not rely on Flutter as the security boundary; ownership and generation/result validation stay server-side.
- `lab` publish handling must validate media URLs against owned content assets before forwarding to the existing publish provider path; raw `media_urls` are not trustworthy for Image Robot publishing.
- `lab` content asset handling must add an atomic primary-selection path for content+placement, or expose an equivalent server action used by this UI.
- `providers.dart` needs a focused visual editor state controller. Keep it bounded; if it grows too large, move feature logic to a dedicated provider file only if the repo already accepts that pattern during implementation.
- `PendingContentNotifier.approve` must pass selected image URLs to `publishContent(mediaUrls: ...)` for platforms that accept media.
- `ContentItem` currently has `imageUrl` and `copyWith(imageUrl: ...)`, but lacks typed `projectId`; the model must expose `projectId` for UI project/content coherence checks.
- Existing `/reels` specs remain the place for Remotion MP4 workflow. This visual UI only makes image assets available to those workflows.
- Docs and changelog must clarify that image consistency V1 uses guided references and generated assets, not model training.

## Documentation Coherence

- Update `app/README.md` with a short note that editor-linked visuals require Image Robot/Flux backend availability and are online-only.
- Update `app/CHANGELOG.md` after implementation with the editor-linked visual workflow and publish media behavior.
- Update `lab` docs through the backend Flux spec for provider env vars and generation behavior, not by duplicating provider setup here.
- Add/update localization entries in `app/lib/l10n/app_localizations.dart`.
- No marketing-site copy change is required until the feature ships and is verified.

## Edge Cases

- No active project.
- Content opened from a stale deep link after project access changed.
- Active project changes while the visual editor route is open.
- Content has no publish-capable channels but still needs a blog hero or future thumbnail.
- Project has zero approved visual references.
- Project has more references than Flux can use.
- A selected reference is deleted or rejected while a generation request is open.
- Image Robot returns queued job but app is backgrounded or route disposed.
- Generation completes after the user leaves the editor.
- Generated image URL is durable but content asset attachment fails.
- Content asset exists but its Bunny URL is missing, expired, or malformed.
- Two assets claim primary for the same placement after concurrent updates.
- User promotes a generated image to reference twice.
- Very long title/placement labels overflow mobile.
- Cached image preview fails to decode.
- Publish path has text success but media provider rejects media URL.
- A future Remotion workflow expects `video_cover` but no selected asset exists.

## Implementation Tasks

- [ ] Task 1: Add typed visual models.
  - File: `app/lib/data/models/image_visual.dart`
  - Action: Define `ImageProfile`, `ProjectVisualReference`, `ImageGenerationJob`, `GeneratedVisualResult`, `ContentVisualAsset`, `VisualPlacement`, and status enum parsing from backend JSON.
  - User story link: Gives the app stable types for guided visuals, references, jobs, and attached assets.
  - Depends on: `SPEC-flux-ai-provider-image-robot-2026-05-11.md` response schema and existing status asset schema.
  - Validate with: `flutter test test/data/image_visual_test.dart`.
  - Notes: Include unknown-status fallbacks and keep provider metadata in a sanitized map.

- [ ] Task 2: Harden backend Image Robot content asset attachment.
  - File: `lab/api/routers/status.py`
  - Action: Add or route `image_robot` attachment through a server-side validation path that accepts generation/result identity, verifies authenticated user ownership, same project/content eligibility, `kind=image`, supported MIME type, durable Bunny/backend URL, and rejects raw arbitrary URLs.
  - User story link: Prevents editor-generated visuals from becoming a cross-project or arbitrary-URL publishing bypass.
  - Depends on: Backend Flux/Image Robot generation store from `SPEC-flux-ai-provider-image-robot-2026-05-11.md`.
  - Validate with: FastAPI tests for owned generation attach, foreign generation reject, raw URL reject, unsupported MIME reject, and missing durable URL reject.
  - Notes: Preserve existing `device_capture` attachment behavior.

- [ ] Task 3: Add atomic primary selection for content visuals.
  - File: `lab/status/service.py`
  - Action: Add a server-side action used by the route layer to set one `image_robot` asset as primary for a `content_id + placement`, clearing other primaries for that placement in the same transaction/update operation.
  - User story link: Gives publishing and future Remotion a single selected visual per placement.
  - Depends on: Task 2.
  - Validate with: Service/API tests for primary set, concurrent duplicate cleanup, wrong content reject, wrong placement reject, and tombstoned asset reject.
  - Notes: Do not leave primary uniqueness as client-side JSON convention only.

- [ ] Task 4: Validate publish media server-side.
  - File: `lab/api/routers/publish.py`
  - Action: Before forwarding media through the existing publish provider path, validate every `media_url` against owned selected content assets or generation records for the `content_record_id`, enforce durable URL allowlist, enforce a V1 maximum of one image URL, and return sanitized warnings/errors.
  - User story link: Ensures attached visuals can safely affect real publication without trusting Flutter-provided URLs.
  - Depends on: Tasks 2-3 and existing publish account ownership checks.
  - Validate with: Publish route tests for valid owned asset, foreign URL reject, temporary/local URL reject, duplicate-primary conflict, more-than-one-image reject, and provider warning propagation.
  - Notes: Never log signed URLs, provider URLs, or raw external error payloads.

- [ ] Task 5: Add generic content asset API methods.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add `fetchContentAssets`, `attachImageRobotAssetToContent`, `setPrimaryContentVisualAsset`, `updateContentAsset`, and `deleteContentAsset`; keep existing `attachCaptureAssetToContent` behavior unchanged.
  - User story link: Persists generated image options and primary visual selection on the current content.
  - Depends on: Tasks 1-3.
  - Validate with: API service tests for payload shape, response parsing, and error mapping.
  - Notes: For image robot assets use `source=image_robot`, `kind=image`, `status=uploaded`, `storage_uri=<durable Bunny URL>`, and metadata fields `placement`, `is_primary`, `generation_id`, `provider`, `profile_id`, `alt_text`, `primary_url`, and `responsive_urls`. The method must accept only backend-returned generation/result objects, not arbitrary URL strings from UI controls, and must stop if the server cannot validate same-user/same-project/same-content ownership.

- [ ] Task 6: Add Image Robot UI API methods.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add typed methods for the app-facing Image Robot routes listed in Dependencies: Flux-capable profiles, generation creation through `/api/images/generate-from-profile`, generation status, generation history, project references, optional cancellation only if the backend exposes it, and promoting a generated result to project reference.
  - User story link: Connects the editor UI to guided Image Robot generation.
  - Depends on: Task 1 and ready backend Flux/Image Robot endpoints.
  - Validate with: API service tests using fake JSON for success, queued, completed, failed, missing provider config, and rate limit.
  - Notes: Keep wrappers typed so widgets do not depend on raw maps. Do not invent alternate client routes during implementation; update this spec first if the backend Flux implementation ships a different app-facing contract.

- [ ] Task 7: Update content model helpers for project and selected visuals.
  - File: `app/lib/data/models/content_item.dart`
  - Action: Add typed `projectId` parsing/copyWith support, add safe metadata helpers for selected visual ids/placements if backend responses include them, and keep `content_preview` separate from body.
  - User story link: Lets editor/feed state reflect selected visual changes without breaking content reliability.
  - Depends on: Task 1.
  - Validate with: `flutter test test/data/content_item_test.dart`.
  - Notes: `imageUrl` already exists in the model and copyWith; do not make `image_url` authoritative if the content asset endpoint returns a newer selected asset.

- [ ] Task 8: Add visual editor state controller.
  - File: `app/lib/providers/providers.dart`
  - Action: Add a family notifier/provider keyed by `contentId` that loads content detail, active project id, content assets, image profiles, references, generation history, current placement, in-flight job, selected asset, and retry/error state.
  - User story link: Keeps generation, polling, attachment, and project-change resets coherent.
  - Depends on: Tasks 1, 5, 6, and 7.
  - Validate with: Provider tests for load, project mismatch, generate, poll completed, poll failed, attach asset, mark primary, promote reference, cancel/dispose, and stale response ignore.
  - Notes: Use `autoDispose.family` keyed by `contentId`, register `ref.onDispose` cancellation/stop logic, poll with a bounded cadence/backoff, stop after terminal status/route dispose/project change/client timeout, and test with fake clock where possible. Track a request nonce/project id/content id for in-flight generation, attach, promote, and primary-update actions so stale responses cannot mutate current state.

- [ ] Task 9: Add visual editor route.
  - File: `app/lib/router.dart`
  - Action: Add `/editor/:id/visuals` route and sanitize it as `/editor/:id/visuals` for Sentry route naming.
  - User story link: Creates an editor-linked surface without global nav.
  - Depends on: None.
  - Validate with: Router/unit test that deep link requires normal app access, uses the visual screen with the expected content id, and `_sanitizeSentryRouteName('/editor/abc/visuals')` returns `/editor/:id/visuals`.
  - Notes: Add the visuals sanitizer branch before the generic `/editor/` branch; do not add an AppShell nav item.

- [ ] Task 10: Add the visual editor screen.
  - File: `app/lib/presentation/screens/editor/visual_editor_screen.dart`
  - Action: Build the content-linked visual workflow UI: placement selector, existing content visual options, project references, generation status card, result gallery, "keep as option" action, "use for this placement" action, promote-to-reference action, primary-conflict state, and retry states.
  - User story link: Lets the creator generate/review/attach visuals from the current editor context.
  - Depends on: Tasks 1, 5, 6, 8, and 9.
  - Validate with: Widget tests for empty project refs, existing assets, queued generation, completed generation, failed generation, attachment success, and narrow mobile layout.
  - Notes: Use stable aspect-ratio containers and `cached_network_image`; do not expose raw provider/model controls.

- [ ] Task 11: Add editor entry point.
  - File: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add an AppBar icon action that opens `/editor/{contentId}/visuals`; refresh content detail/assets when returning if the visual editor changed attachments.
  - User story link: Keeps visuals tied to editing/review instead of a standalone tool.
  - Depends on: Task 9.
  - Validate with: Editor widget test that the action is visible and routes to the visual editor for owned content.
  - Notes: Use an image/icon tooltip string through localization.

- [ ] Task 12: Add reusable visual widgets if needed.
  - File: `app/lib/presentation/screens/editor/visual_editor_widgets.dart`
  - Action: Extract focused widgets for placement chips, reference thumbnails, generated result cards, content asset cards, and job status rows if `visual_editor_screen.dart` becomes too large.
  - User story link: Keeps the UI maintainable and testable.
  - Depends on: Task 10.
  - Validate with: Widget tests for overflow-safe labels and primary selection indicators.
  - Notes: Keep cards for repeated items only; do not create nested cards.

- [ ] Task 13: Pass selected visual media to publishing.
  - File: `app/lib/providers/providers.dart`
  - Action: Before publish, resolve selected primary visual assets for the content and pass their durable URLs through `publishContent(mediaUrls: ...)` only for channels mapped by `channelToPlatform`.
  - User story link: Makes attached visuals affect posts/thumbnails instead of staying decorative in the editor.
  - Depends on: Tasks 4, 5, and 8.
  - Validate with: Pending content notifier tests asserting `mediaUrls` includes the selected durable image URL and excludes local/temporary/malformed URLs.
  - Notes: Preserve full-body resolution order and online-only publish behavior. Filter to selected primary `image_robot` assets with durable URLs and no duplicate-primary conflict; never publish local, provider-temporary, user-entered, or malformed URLs. Backend publish validation must reject any media URL not backed by an owned content asset/generation.

- [ ] Task 14: Add localization strings.
  - File: `app/lib/l10n/app_localizations.dart`
  - Action: Add French/English strings for visual action tooltip, placements, generation states, attach/promote/cancel/retry actions, and recoverable errors.
  - User story link: Keeps the new UI consistent with the localized app.
  - Depends on: Tasks 10-11.
  - Validate with: Widget tests under English and French locales where labels are asserted.
  - Notes: Avoid provider-marketing copy; prefer placement/outcome wording.

- [ ] Task 15: Add documentation note.
  - File: `app/README.md`
  - Action: Document that editor-linked visuals are online-only and require the Image Robot/Flux backend.
  - User story link: Helps operators understand runtime prerequisites.
  - Depends on: Feature implementation.
  - Validate with: Manual doc review.
  - Notes: Backend env var details belong to the Flux backend spec/docs.

- [ ] Task 16: Add changelog entry.
  - File: `app/CHANGELOG.md`
  - Action: Add an Unreleased entry for editor-linked AI visual generation and selected visual publish media behavior.
  - User story link: Records the user-facing behavior change.
  - Depends on: Feature implementation.
  - Validate with: Manual changelog review.
  - Notes: Keep wording outcome-based.

## Acceptance Criteria

- [ ] CA 1: Given owned content is open in `/editor/:id`, when the creator taps the visual action, then `/editor/:id/visuals` opens and no global Visuals nav item exists.
- [ ] CA 1.1: Given Sentry route names are sanitized, when `/editor/abc/visuals` is observed, then it is reported as `/editor/:id/visuals` rather than the generic `/editor/:id`.
- [ ] CA 2: Given no active project exists, when the visual action/screen is used, then no Image Robot request is sent and the UI shows a recoverable no-project state.
- [ ] CA 3: Given the visual screen opens with an active project, when data loads, then profiles, references, attached assets, and recent generations are fetched through `ApiService` methods, not widget-level HTTP calls.
- [ ] CA 4: Given a guided placement is selected, when generation starts, then the request includes `project_id`, `content_id`, `placement`, `profile_id`, and only approved reference ids selected by the UI.
- [ ] CA 5: Given generation is queued or in progress, when the route is mounted, then polling updates status until terminal state and stops on dispose or project change.
- [ ] CA 6: Given generation completes with a durable Bunny URL, when the creator chooses "keep as option", then `/api/status/content/{id}/assets` receives an `image_robot` candidate asset with placement and generation metadata and it is not primary.
- [ ] CA 6.1: Given an attachment request is created, when it is sent, then it is derived from a backend-returned generation/result owned by the same content/project/user, and implementation stops if the backend accepts raw unvalidated publishable `image_robot` URLs.
- [ ] CA 7: Given the creator chooses "use for this placement", when the backend accepts the primary update, then the asset appears as the only primary for that placement; if it was not already a candidate, it is linked first.
- [ ] CA 8: Given attachment fails, when the result remains visible, then it is not marked selected and publish media does not include it.
- [ ] CA 9: Given the creator promotes a generated image to reference, when the backend accepts it, then the project reference list refreshes and duplicate promotion is handled recoverably.
- [ ] CA 10: Given a selected primary visual asset exists, when publishing to `twitter`, `linkedin`, `instagram`, `tiktok`, or `youtube`, then `publishContent` receives that durable URL in `mediaUrls`.
- [ ] CA 11: Given a selected primary asset has only a temporary/provider/local URL, when publishing runs, then publish is blocked with a recoverable error and no temporary URL is sent.
- [ ] CA 12: Given the active project changes during generation, when the old response returns, then it is ignored and cannot attach to the new project/content.
- [ ] CA 13: Given the user opens a content id they do not own, when visuals load, then no content assets, references, or generation history leak.
- [ ] CA 14: Given a future Remotion flow reads content assets, when an asset has `placement=video_cover`, then it can identify the durable image without this UI invoking Remotion render APIs.
- [ ] CA 15: Given a 320px-wide viewport, when the visual editor renders labels and result cards, then no text/control overflow occurs.
- [ ] CA 16: Given duplicate primary assets exist for a placement after concurrent updates, when publish media is resolved, then that placement is excluded and the UI shows a recoverable conflict/retry state.
- [ ] CA 17: Given the backend lacks server-side validation for Image Robot asset attachment, atomic primary selection, or publish media ownership, when live wiring is attempted, then implementation stops and routes backend hardening instead of exposing media publishing.
- [ ] CA 18: Given a media URL is sent to publish, when the backend validates it, then it must be backed by an owned selected content asset or generation for the same `content_record_id`.

## Test Strategy

- Dart model tests for image visual JSON parsing, unknown enum handling, durable URL filtering, placement metadata, and content asset conversion.
- `ApiService` tests with fake Dio/server responses for image profile/reference/generation endpoints and `/content/{id}/assets` attach/update/delete.
- Riverpod provider tests for load, generation lifecycle, polling stop, stale response ignore, attachment, primary selection, reference promotion, and publish media resolution.
- Security-focused provider/API tests for rejecting arbitrary URL attachment in Flutter code paths, ignoring stale project/content responses, excluding duplicate-primary media, and redacting signed/provider URLs from diagnostics.
- Backend-contract tests or integration checks must prove `image_robot` attachment and publish media URLs are server-validated against owned content assets/generations before enabling end-to-end publish media.
- Widget tests for `EditorScreen` visual action, `VisualEditorScreen` loading/empty/success/failure states, narrow mobile rendering, and localized labels.
- Existing editor tests must still pass.
- Existing capture tests must still pass, proving capture asset attachment was not regressed.
- Manual QA:
  - Open editor for article, generate a blog hero, keep it as an option, use it for the placement, and publish to a supported social platform with media URL.
  - Open editor for video/reel content, attach `video_cover`, confirm no Remotion render is started by this screen.
  - Switch active project mid-flow and confirm stale generation cannot attach.
- Suggested validation commands:
  - `cd app && flutter analyze`
  - `cd app && flutter test`

## Risks

- Backend contract drift: the Flux spec may implement endpoint names differently. Mitigation: keep raw endpoints in `ApiService` only and align the UI through typed methods.
- Product drift: a visually rich image UI can become a playground. Mitigation: no global nav, no raw provider controls, content id required, placement required.
- Data leakage: references and generated history are project-scoped. Mitigation: backend ownership remains authoritative and UI ignores stale project responses.
- Publish mismatch: media URLs may not be accepted by every platform/provider. Mitigation: V1 only sends media for locally mapped `channelToPlatform` social channels, validates durable owned media server-side, and keeps provider warnings visible.
- Binary upload temptation: direct reference upload is useful but risky. Mitigation: scope it out of V1 and use generated-result promotion plus backend-managed references.
- UI complexity in `providers.dart` and `visual_editor_screen.dart`. Mitigation: extract typed models/widgets and keep provider responsibilities explicit.
- Remotion confusion: users may expect a video editor. Mitigation: this screen creates image assets only; Remotion preview/export remains in the ready Reels specs.

## Execution Notes

- Read first:
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `lab/api/routers/status.py`
  - `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`
- Backend readiness precheck before wiring live publish media:
  - Confirm image generation results include stable `generation_id`, durable URL fields, project id, content id or attach eligibility, and ownership-safe status/history reads.
  - Confirm content asset attachment for `source=image_robot` validates the generation/result belongs to the same authenticated user/project/content, or use a dedicated backend attach-by-generation endpoint if the backend adds one.
  - Confirm a server-side atomic primary-selection action exists for `content_id + placement`.
  - Confirm publish media validation accepts only owned durable content assets/generation URLs and forwards media only for locally mapped `channelToPlatform` social channels.
  - If any validation is absent, stop implementation at typed models/mocked UI and route a backend-hardening spec/update before exposing publishable image assets.
- Implement foundations before UI: models, API methods, provider/controller, route, then screen/widgets.
- Reuse existing `ProjectPickerAction`, `AppErrorView`, diagnostic snackbars, `context.tr`, `AppTheme`, and cached network image dependency.
- Avoid new Flutter dependencies unless implementation proves existing `cached_network_image` and Material controls are insufficient.
- Do not add local file upload, drag/drop upload, or base64 reference state in this spec.
- Stop and reroute if the backend Flux implementation does not expose durable generation status/history/reference endpoints, or if `/api/status/content/{id}/assets` cannot represent remote image assets with metadata.
- Fresh external docs: `fresh-docs not needed`; this spec is governed by local contracts and existing dependencies. If a new package is proposed during implementation, run the freshness gate before adding it.

## Open Questions

None blocking. Product decisions recorded: V1 is editor-linked, not a standalone playground; publish is blocked when a selected visual is invalid or not durable; generated images can be kept as non-primary candidates, and only the "use for this placement" action makes one primary.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 13:44:58 UTC | sf-spec | GPT-5 Codex | Created editor-linked AI visuals UI spec from user decision, local Flutter editor audit, Flux backend spec, and Remotion workflow specs. | Draft saved. | /sf-ready shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md |
| 2026-05-11 13:59:38 UTC | sf-ready | GPT-5 Codex | Tightened security/readiness contract before final gate: same-project generation attachment validation, duplicate-primary handling, publish media filtering, stale response guards, and French accents in user-story text. | Reviewed; final readiness pass in progress. | /sf-ready shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md |
| 2026-05-11 14:07:56 UTC | sf-ready | GPT-5 Codex | Integrated agent readiness blockers: exact app-facing Image Robot route contract, Sentry sanitizer order, typed projectId model task, server-side media validation, atomic primary selection, Riverpod polling lifecycle, and Remotion cover-only scope. | Not ready; two product decisions remain. | /sf-spec Editor-Linked AI Visuals UI |
| 2026-05-11 14:11:26 UTC | sf-spec | GPT-5 Codex | Recorded user decision that publish must block when a selected visual is invalid or not durable. | Spec updated; one product decision remains. | /sf-spec Editor-Linked AI Visuals UI |
| 2026-05-11 14:36:49 UTC | sf-spec | GPT-5 Codex | Recorded candidate/primary UX decision: "attach" is a backend link, UI exposes "keep as option" and "use for this placement"; only primary assets publish. | Spec updated; ready gate can rerun. | /sf-ready shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md |
| 2026-05-11 14:40:52 UTC | sf-ready | GPT-5 Codex | Reordered implementation tasks so backend security foundations precede Flutter live wiring and publish media. | Reviewed; final readiness pass in progress. | /sf-ready shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md |
| 2026-05-11 14:41:31 UTC | sf-ready | GPT-5 Codex | Ran final readiness gate after product decisions and task reordering. | Ready. | /sf-start Editor-Linked AI Visuals UI |

## Current Chantier Flow

- sf-spec: done; draft spec created for editor-linked AI visuals UI.
- sf-ready: ready; product decisions recorded and backend-first execution order is explicit.
- sf-start: not launched.
- sf-verify: not launched.
- sf-end: not launched.
- sf-ship: not launched.

Next command: `/sf-start Editor-Linked AI Visuals UI`
