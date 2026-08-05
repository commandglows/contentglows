---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "contentglows"
created: "2026-05-13"
created_at: "2026-05-13 03:21:04 UTC"
updated: "2026-05-13"
updated_at: "2026-05-13 03:21:04 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlows authentifiee, je veux voir et attacher les bons assets aux bons emplacements de publication par plateforme, afin que mes contenus sociaux, articles, thumbnails, videos courtes et pistes audio partent avec des formats efficaces sans sortir de l'editeur guide."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "contentglows"
  - "Project Asset Library"
  - "publish router"
  - "Zernio/LATE"
  - "Image Robot / Flux"
  - "Remotion video workflow"
  - "AI audio workflow"
  - "Bunny CDN"
  - "Clerk"
  - "Turso/libSQL"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "in_progress"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "unknown"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md"
    artifact_version: "unknown"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md"
    artifact_version: "unknown"
    required_status: "draft"
  - artifact: "contentglows/INSPIRATION.md"
    artifact_version: "unknown"
    required_status: "inspiration-only"
  - artifact: "contentglows/GUIDELINES.md"
    artifact_version: "unknown"
    required_status: "inspiration-only"
  - artifact: "TikTok Content Posting API media transfer guide"
    artifact_version: "official docs checked 2026-05-13: https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide"
    required_status: "official"
  - artifact: "X API media upload and post docs"
    artifact_version: "official docs checked 2026-05-13: https://docs.x.com/x-api/media/upload-media and https://docs.x.com/x-api/posts/manage-tweets/introduction"
    required_status: "official"
  - artifact: "LinkedIn Posts and Videos APIs"
    artifact_version: "official docs checked 2026-05-13: https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/posts-api?view=li-lms-2026-01 and https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/videos-api"
    required_status: "official"
  - artifact: "YouTube Data API videos and thumbnails"
    artifact_version: "official docs checked 2026-05-13: https://developers.google.com/youtube/v3/docs/videos and https://developers.google.com/youtube/v3/docs/thumbnails/set"
    required_status: "official"
  - artifact: "Instagram Platform Content Publishing"
    artifact_version: "fresh-docs gap 2026-05-13: official URL identified as https://developers.facebook.com/docs/instagram-platform/content-publishing/ but direct page render was unavailable in agent browser"
    required_status: "manual official refresh before strict Instagram-specific constraints"
supersedes: []
evidence:
  - "User request 2026-05-12/13: spec Social placement / formats de publication from contentglows inspiration, linking assets to platforms: thumbnail, vertical, post image, video courte, audio."
  - "User product direction: ContentGlows should guide users toward efficient social content, not a free creative playground."
  - "contentglows/INSPIRATION.md: Canva simplicity, CapCut templates, Remotion composable video, Descript text editing and AI media tools are inspirations only."
  - "contentglows/GUIDELINES.md: generated outputs should use standard formats: MP4, MP3/WAV, PNG/JPG/WebP, GIF/MP4; preview when possible; workflow between tools."
  - "Code evidence: app/lib/data/models/content_item.dart defines PublishingChannel for wordpress, ghost, twitter, linkedin, instagram, tiktok and youtube."
  - "Code evidence: app/lib/presentation/screens/editor/platform_preview_sheet.dart shows platform previews but has no asset slot or placement validation."
  - "Code evidence: lab/api/routers/publish.py accepts media_urls and sends them to Zernio as image media without project asset ownership or placement validation."
  - "Code evidence: lab/status/schemas.py and lab/api/routers/assets.py already define project assets, usages, placement, primary state, tombstone history and storage descriptors."
  - "Code evidence: lab/status/service.py supports usage actions including select_for_content, publish_media and set_primary, but video_version target validation is not available yet."
  - "Code evidence: app/lib/presentation/widgets/project_asset_picker.dart already accepts a placement string and can be reused for slot-specific picking."
  - "Fresh docs checked 2026-05-13: official docs confirm current social APIs treat media as platform-specific upload/use cases rather than arbitrary raw URLs."
next_step: "/sf-ready Social placement format registry"
---

# Title

Social Placement Format Registry

## Status

Draft. This spec defines the product and technical contract for mapping project assets to platform-specific publication placements. It builds on the now-existing project asset library and makes publish/review flows understand slots such as blog hero, post image, link thumbnail, video thumbnail, vertical short video, reel cover, caption file and audio track.

## User Story

En tant que creatrice ContentGlows authentifiee, je veux voir et attacher les bons assets aux bons emplacements de publication par plateforme, afin que mes contenus sociaux, articles, thumbnails, videos courtes et pistes audio partent avec des formats efficaces sans sortir de l'editeur guide.

## Minimal Behavior Contract

When a creator opens a content editor, video editor or publish review for an owned content item, ContentGlows computes a placement plan from the content type and selected platforms, shows the required and recommended asset slots, lets the creator generate or pick eligible project assets for each slot, persists the selection as project asset usages, and blocks publish only when a selected platform cannot be served safely without a required asset. If an asset is missing, foreign, local-only, tombstoned, degraded, incompatible, stale or based on a platform rule that needs manual refresh, the UI shows a recoverable warning or blocking error and the backend does not send that media to the publish provider. The easy edge case to miss is treating platform media as raw URLs: the publish path must resolve server-validated project assets and placements, while exact platform dimensions stay in a versioned registry that can be refreshed as external rules change.

## Success Behavior

- Given an authenticated creator owns a project and opens a content editor, when the content targets blog, X/Twitter, LinkedIn, Instagram, TikTok or YouTube, then the app requests a backend placement plan for that content and renders platform-specific slots.
- Given a blog article targets blog plus social promotion, when the plan is built, then it includes at least `blog_hero`, `social_post_image` and `link_thumbnail` or `og_card` recommendations where relevant.
- Given a social post targets X/Twitter or LinkedIn, when no asset is required, then the plan still recommends a `social_post_image` or link thumbnail but does not block text-only publish.
- Given a post targets Instagram feed or a vertical short targets TikTok/Instagram Reels/YouTube Shorts, when no compatible visual/video asset is attached, then publish preflight returns a blocking missing-placement issue for that platform.
- Given a YouTube video target exists, when the plan is built, then thumbnail and video placements are represented separately so the editor can validate a thumbnail without confusing it with the main video render.
- Given an asset picker opens from a slot, when the user selects an asset, then the backend creates or updates a project asset usage with `target_type=content`, `target_id=<content_record_id>`, `placement=<placement_id>`, `usage_action=publish_media` or `set_primary`, and records whether it is primary.
- Given multiple candidate assets exist for the same slot, when one is set primary, then only that asset is used for preflight and publish payload construction unless the user changes it.
- Given a selected asset is active, owned, durable, compatible and primary for a platform slot, when publish preflight runs, then the backend resolves a safe storage descriptor or backend-owned URL and includes it in the provider payload with the correct media intent.
- Given placement validation succeeds and the creator schedules or publishes, then publish metadata records which asset ids and placement ids were used for each platform.
- Given a platform rule is advisory in V1, when the asset is likely usable but not exact, then preflight returns a warning and does not silently block unless the placement is required by the selected channel.
- Given a platform official doc changes later, when registry data is refreshed, then Flutter receives the updated registry from backend without hard-coded mobile changes for ordinary rule updates.

## Error Behavior

- Missing Clerk auth returns `401` and exposes no content, asset or platform plan.
- A content id, project id, account id or asset id outside the current user's project returns `403` or `404` without leaking titles, storage paths, prompts, signed URLs or account names.
- A platform not supported by ContentGlows publish returns `422` with supported platform ids; blog/CMS channels remain separate from the Zernio social publish integration.
- A placement id not present in the registry returns `400` with a registry version and supported placement ids.
- A required placement with no selected primary asset returns a blocking preflight issue for platforms that require media, and a warning for platforms where media is optional.
- A selected asset with status `local_only`, `degraded` or `tombstoned` returns a blocking issue for publish media and is never sent to the provider.
- A selected asset whose media kind, MIME, aspect ratio, duration or storage descriptor is incompatible with the slot returns a typed compatibility issue and keeps the previous valid selection unchanged.
- A direct raw `media_urls` publish request from legacy clients must not bypass the new project asset validation in new UI flows. If legacy compatibility remains during rollout, the backend must mark it as legacy and never mix it with validated `asset_placements` without a clear precedence rule.
- A provider timeout or rejection after internal preflight persists a normalized platform error in publish metadata without changing asset usage state.
- A stale registry version in Flutter triggers a registry refresh before publish instead of publishing with hidden outdated client assumptions.
- What must never happen: raw public URLs accepted as trusted media authority, cross-project asset publish, local-only files sent to Zernio, tombstoned assets reused, provider secrets or signed tokens returned to Flutter, or a silent downgrade from a missing required video/image slot to text-only publish on media-first platforms.

## Problem

ContentGlows now has the foundations for project assets and AI image generation, but publication still treats media too loosely. The backend publish route accepts `media_urls` and forwards them as images; the Flutter preview sheet shows platform text previews but not the assets that must accompany a post. This leaves a gap between generated/reused project assets and actual distribution: users can create useful visuals, thumbnails, videos or audio, but the system does not yet model which asset belongs to which platform placement, which assets are required, which are only recommended, and what blocks publishing.

ContentGlows inspiration points in the right direction: Canva and CapCut show that guided formats and templates are more useful than a blank creative tool, Remotion makes video outputs composable, and the guidelines push standard media formats. For ContentGlows, the product goal is not artistic freedom; it is efficient, guided, platform-aware content distribution from the current editor.

## Solution

Add a backend-owned social placement registry and publish preflight layer. The registry defines stable placement ids, supported platforms, content types, required/recommended rules, compatible asset media kinds, format hints, media intent and external doc provenance. Flutter consumes the registry to render slots in the editor/publish review and uses the existing project asset picker to attach assets by placement. The publish backend resolves those asset usages server-side and builds provider media payloads only from owned, active, durable assets.

## Scope In

- A versioned placement registry in `lab` covering V1 platform/channel surfaces: blog/CMS output, X/Twitter, LinkedIn, Instagram, TikTok and YouTube.
- Stable placement ids for V1:
  - `blog_hero`
  - `inline_image`
  - `social_post_image`
  - `link_thumbnail`
  - `video_thumbnail`
  - `vertical_short_video`
  - `landscape_video`
  - `reel_cover`
  - `caption_track`
  - `audio_track`
- Registry fields for platform id, content types, target placement, asset media kinds, MIME families, recommended aspect ratios, minimum dimensions where safe, duration bands, required/recommended/blocking policy, provider media intent, doc sources, `last_reviewed_at` and `rule_strictness`.
- Backend placement plan endpoint for a content item and selected platforms.
- Backend publish preflight endpoint or publish-route preflight function that validates selected placements before provider calls.
- Extension of `PublishRequest` with validated asset placement inputs or a server-side lookup of selected primary usages by content/platform/placement.
- Server-side conversion from selected project asset usages to provider media payloads, with raw `storage_uri` hidden from Flutter and provider URLs resolved only in backend.
- Use of existing project asset usage fields: `target_type`, `target_id`, `placement`, `usage_action`, `is_primary`, `metadata`.
- UI updates in the content editor and publish review to show required/recommended slots and their asset status.
- Reuse of `ProjectAssetPicker` with slot-specific filters and `placement` ids.
- Platform preview updates to display selected asset placeholders/previews and missing/incompatible slot states.
- Suggested generation actions per slot, such as opening the Flux/Image Robot guided profile for `blog_hero`, `social_post_image`, `link_thumbnail`, `video_thumbnail` or `reel_cover`.
- Future-compatible hooks for Remotion render outputs and AI audio assets without requiring the full video/audio workflows to ship first.
- Tests for registry output, ownership, compatibility, preflight, publish payload construction, legacy media URL behavior, Flutter model parsing and widget slot states.
- Documentation updates for placement ids, publish media contract and how content creators should reason about assets versus platform slots.

## Scope Out

- Building a standalone media library or generic asset manager beyond the existing project asset library.
- Creating a free-form creative playground.
- Implementing binary upload, direct file transfer, provider upload sessions, direct social OAuth or Zernio account connection flows.
- Replacing Zernio/LATE as the publish provider.
- Rewriting Remotion video rendering, AI audio generation or Flux image generation.
- Automatic AI cropping, reframing or transcoding in V1.
- Guaranteeing exact platform optimization forever; the registry is versioned and must be refreshed as platform docs change.
- A global brand asset library across projects.
- Public marketplace, template marketplace, licensing registry, approval workflow or multi-role review.
- Publishing audio-only content to podcast platforms in this spec.
- Enforcing every obscure platform supported by Zernio; V1 covers the channels already present in ContentGlows's core UX.

## Constraints

- `lab` remains the authority for registry rules, asset ownership, placement validation and publish payload construction.
- `app` must not hard-code platform constraints as final truth; it can cache registry responses but must refresh before publish if the backend version changes.
- All placement actions require Clerk auth and project/content ownership.
- The existing project asset library remains the storage/governance layer; this spec adds platform placement semantics, not a new asset table unless needed for registry snapshots.
- Bunny CDN remains the durable media path. Provider-temporary URLs are not durable placement assets.
- Raw `media_urls` cannot be the new publish contract.
- Blog/CMS outputs are represented in placement planning, but current Zernio social publish excludes `wordpress` and `ghost`; CMS publishing remains a separate integration.
- Instagram exact constraints must be manually refreshed from official Meta docs before strict Instagram-specific dimensions/durations are enforced. Until then, V1 should use conservative recommended presets and provider rejection handling rather than pretending the agent-cached snippet is authoritative.
- Video-version placements cannot mutate `target_type=video_version` until the video asset store validation ships; V1 may attach publish placements to `target_type=content` and link to video render assets by asset id/metadata.
- Placement ids must be stable. Display labels can change, ids cannot silently change because project asset usages depend on them.

## Dependencies

- Existing project asset backend:
  - `lab/status/schemas.py`
  - `lab/status/service.py`
  - `lab/api/routers/assets.py`
  - `lab/api/models/status.py`
- Existing Flutter asset client/state:
  - `app/lib/data/models/project_asset.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
- Existing publish backend:
  - `lab/api/routers/publish.py`
  - `lab/tests/integration/test_publish_router.py`
- Existing editor and preview UI:
  - `app/lib/data/models/content_item.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/presentation/screens/editor/platform_preview_sheet.dart`
  - `app/test/presentation/screens/editor/editor_screen_test.dart`
- Existing project docs:
  - `lab/README.md`
  - `contentglows/INSPIRATION.md`
  - `contentglows/GUIDELINES.md`
- Related specs:
  - `shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md`
- Fresh external docs:
  - `fresh-docs checked`: TikTok Content Posting API media transfer guide: `https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide`.
  - `fresh-docs checked`: X API media upload and post docs: `https://docs.x.com/x-api/media/upload-media`, `https://docs.x.com/x-api/posts/manage-tweets/introduction`.
  - `fresh-docs checked`: LinkedIn Posts and Videos APIs: `https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/posts-api?view=li-lms-2026-01`, `https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/videos-api`.
  - `fresh-docs checked`: YouTube Data API videos and thumbnails docs: `https://developers.google.com/youtube/v3/docs/videos`, `https://developers.google.com/youtube/v3/docs/thumbnails/set`.
  - `fresh-docs gap`: Meta Instagram Platform Content Publishing official page URL was identified, but direct page rendering was unavailable in the agent browser: `https://developers.facebook.com/docs/instagram-platform/content-publishing/`. Implementation must manually refresh Meta docs before strict Instagram-specific constraints.

## Invariants

- A placement plan is scoped to one content item and one project.
- A placement id is stable and backend-owned.
- A platform slot can be required, recommended, optional or unsupported; the UI must show the difference.
- Required media-first placements block publish only for platforms/content types that require them.
- Recommended placements create warnings or suggestions, not hard blocks.
- Publish payload media must come from server-validated project assets, not client-trusted URLs.
- Every selected publish asset must be active, durable, owned by the same project and compatible with the placement.
- Tombstoned, degraded and local-only assets are never eligible for publish media.
- A primary usage is unique per target and placement.
- Candidate assets can appear in UI but do not publish until selected as primary or explicitly included by the backend plan.
- Registry warnings are visible before the publish call; provider errors are normalized after the provider call.
- Platform docs are unstable, so the registry must store provenance and last review metadata.

## Links & Consequences

- `lab/api/routers/publish.py`: must stop treating app-provided media URLs as the authoritative media contract for new publish flows. It needs preflight validation and provider payload construction from project assets.
- `lab/api/routers/assets.py`: existing placement and usage endpoints can remain, but this spec may add placement-aware filters or usage summaries.
- `lab/status/service.py`: eligibility currently supports broad `publish_media`; it needs placement registry checks for asset media kind, target platform, required slot and current asset status.
- `lab/api/models/status.py`: may need typed placement/preflight response models or a new `api/models/social_placements.py`.
- `app/lib/presentation/widgets/project_asset_picker.dart`: should receive placement/platform constraints so users do not pick irrelevant assets for a slot.
- `app/lib/presentation/screens/editor/platform_preview_sheet.dart`: should display selected/missing assets alongside platform previews, not just text truncation.
- `app/lib/data/models/content_item.dart`: existing `PublishingChannel` is the app-facing channel enum; registry platform ids must map cleanly to it.
- Publish metadata: should record `assetPlacements`, registry version, platform preflight issues and provider media payload summary without storing raw signed tokens.
- Analytics/ops: preflight warnings should be counted so we can learn which slots users miss most often.
- Security: this is a hardening step for publish media ownership and URL trust.

## Documentation Coherence

- Update `lab/README.md` with the placement registry, preflight endpoint, supported placement ids and legacy `media_urls` behavior.
- Add an internal note to any publish API documentation that `asset_placements` or server-selected project asset usages are the preferred media path.
- Update Flutter developer notes or README with the rule: UI may display registry hints but backend validation is final.
- Add support/product copy for users explaining missing required asset, recommended asset, incompatible asset and generate/choose actions.
- Update related specs when implemented:
  - Flux/Image Robot should list which generated image profiles satisfy `blog_hero`, `social_post_image`, `link_thumbnail`, `video_thumbnail` and `reel_cover`.
  - Remotion video spec should emit render assets usable for `vertical_short_video`, `landscape_video` and `video_thumbnail`.
  - AI audio spec should emit assets usable for `audio_track` and future caption/audio placements.

## Edge Cases

- A content item targets both LinkedIn and Instagram, and one image is acceptable for LinkedIn but not for Instagram. Preflight must return platform-specific issues rather than a single global pass/fail.
- A text-only X/Twitter post has no image. Publish should be allowed, with an optional recommendation if a social image would improve the post.
- A TikTok/Instagram/YouTube Shorts target has only an image. Publish should block the video placement unless the current provider path supports static-image video generation, which is outside this spec.
- A YouTube video has a video render but no thumbnail. Preflight should allow draft/render workflows but block final publish only if YouTube publish requires thumbnail in the selected product flow.
- A blog post has a hero image but no social card. The blog save/publish path can proceed while social promotion shows a missing recommended placement.
- The same asset is selected for multiple placements. This is allowed if the registry says it is compatible with each placement; usage rows must record every placement separately.
- The user tombstones an asset after it was selected. Future publish preflight blocks it and asks for replacement; historical usage remains visible.
- Flutter has a cached registry and backend has a newer registry. Publish preflight returns current registry version and issue codes; UI refreshes.
- Provider accepts a media payload that passed internal preflight but fails platform-side. Publish metadata stores normalized platform error and does not mutate asset usages.
- Direct provider docs are inaccessible during implementation. Exact hard blocking for that platform rule must remain conservative or warning-only until manually refreshed.

## Implementation Tasks

- [ ] Task 1: Add backend placement registry models
  - File: `lab/api/models/social_placements.py`
  - Action: Define Pydantic models for `PlacementSpec`, `PlacementRule`, `PlacementPlan`, `PlacementSlot`, `PlacementIssue`, `AssetPlacementInput`, `PublishPreflightRequest` and `PublishPreflightResponse`.
  - User story link: Makes platform slots explicit and inspectable.
  - Depends on: Existing project asset models.
  - Validate with: `python -m pytest lab/tests/test_social_placement_registry.py` after tests are added.
  - Notes: Keep ids ASCII and stable; include `registry_version`, `last_reviewed_at`, `doc_sources` and `rule_strictness`.

- [ ] Task 2: Implement the registry service
  - File: `lab/api/services/social_placement_registry.py`
  - Action: Create the V1 registry for blog/CMS output, X/Twitter, LinkedIn, Instagram, TikTok and YouTube with the stable placement ids listed in this spec.
  - User story link: Converts content type/platform choices into required and recommended asset slots.
  - Depends on: Task 1.
  - Validate with: Unit tests for each content type/platform combination and registry version.
  - Notes: Use conservative recommendations for Instagram until official docs are manually refreshed; do not embed unverified exact limits as blocking rules.

- [ ] Task 3: Add placement plan/preflight routes
  - File: `lab/api/routers/social_placements.py`
  - Action: Expose `GET /api/content/{content_id}/placement-plan` or equivalent project/content-scoped endpoint, plus `POST /api/publish/preflight` if not folded into publish.
  - User story link: Lets the UI show slots before publishing.
  - Depends on: Task 2.
  - Validate with: Router tests for auth, ownership, unsupported platforms, missing content and plan shape.
  - Notes: Route naming can follow existing API conventions, but plan and preflight must be content-owned and project-scoped.

- [ ] Task 4: Add server-side asset compatibility checks
  - File: `lab/status/service.py`
  - Action: Extend project asset eligibility for `publish_media` to accept placement/platform context and validate media kind, status, ownership, storage descriptor, optional MIME/aspect/duration metadata and required slot policy.
  - User story link: Prevents wrong or unsafe assets from reaching publish.
  - Depends on: Tasks 1-3.
  - Validate with: Existing project asset service tests plus new compatibility cases.
  - Notes: Keep generic project asset actions backward compatible where no placement context is provided, but publish preflight must use placement-aware checks.

- [ ] Task 5: Extend publish request and payload construction
  - File: `lab/api/routers/publish.py`
  - Action: Add `asset_placements` or server-side primary-usage resolution, run preflight before provider call, resolve provider media payloads from validated project assets, and record placement metadata in content publish metadata.
  - User story link: Makes actual publishing use the selected slots.
  - Depends on: Tasks 1-4.
  - Validate with: `lab/tests/integration/test_publish_router.py` covering success, missing required media, incompatible asset, foreign asset, tombstoned asset, raw media URL legacy behavior and provider payload shape.
  - Notes: Keep provider account authorization and duplicate publish checks before external calls. Do not expose raw storage tokens in responses.

- [ ] Task 6: Add Flutter models/API methods for registry and preflight
  - File: `app/lib/data/models/social_placement.dart`
  - Action: Create typed Dart models matching backend placement/preflight responses.
  - User story link: Gives the app typed slot data instead of hard-coded platform assumptions.
  - Depends on: Tasks 1-3 contracts.
  - Validate with: Dart model parsing tests.
  - Notes: Include unknown-field tolerance for registry evolution.

- [ ] Task 7: Add Flutter API client methods
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add methods to fetch placement plans and run publish preflight; add publish request support for asset placements if publish is called from Flutter in this flow.
  - User story link: Connects editor/publish UI to backend slots.
  - Depends on: Task 6.
  - Validate with: Existing API service test pattern or mocked provider tests.
  - Notes: Resolve local id mappings like the existing project asset methods do.

- [ ] Task 8: Add placement state/provider
  - File: `app/lib/providers/providers.dart`
  - Action: Add a notifier or extend existing content/editor state to load placement plans, cache registry version, track preflight issues and ignore stale project/content responses.
  - User story link: Shows current slot status in the editor and publish review.
  - Depends on: Task 7.
  - Validate with: Provider tests for project switch, stale response, missing slot, selected asset refresh and preflight warnings.
  - Notes: Follow the revision pattern already used by `ProjectAssetLibraryNotifier`.

- [ ] Task 9: Update project asset picker for slot-specific selection
  - File: `app/lib/presentation/widgets/project_asset_picker.dart`
  - Action: Accept placement/platform constraints, show why assets are eligible/ineligible, and call `setPrimary` or `selectForTarget` with the placement id.
  - User story link: Lets creators attach the right asset without leaving guided flow.
  - Depends on: Tasks 6-8.
  - Validate with: Widget tests for eligible, missing, incompatible, tombstoned and primary states.
  - Notes: Do not turn the picker into a free media library; keep the slot context visible.

- [ ] Task 10: Update editor and platform preview surfaces
  - File: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add a placement panel or publish-readiness section that appears from the content editor and uses `ProjectAssetPicker` per slot.
  - User story link: Makes asset placement part of the current editor, not a separate playground.
  - Depends on: Tasks 8-9.
  - Validate with: Editor widget tests for opening placement panel and selecting a slot asset.
  - Notes: Keep mobile layout compact; if dense editing becomes unreadable, route to a linked editor sheet/screen rather than crowding the main editor.

- [ ] Task 11: Update platform preview sheet
  - File: `app/lib/presentation/screens/editor/platform_preview_sheet.dart`
  - Action: Show selected/missing asset slots for each platform preview and surface blocking/warning issue states.
  - User story link: Lets creators see what will be published per platform.
  - Depends on: Tasks 8-10.
  - Validate with: Widget tests for Twitter text-only allowed, Instagram missing media blocking, YouTube thumbnail separation and LinkedIn optional image warning.
  - Notes: Avoid hard-coding official limits as final truth in the UI; display backend issue messages.

- [ ] Task 12: Register generation actions from placement slots
  - File: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add guided actions from empty image slots to existing Image Robot/Flux profiles where available.
  - User story link: Makes missing slots actionable.
  - Depends on: Flux/Image Robot route availability and Tasks 8-10.
  - Validate with: Widget/provider tests that empty `social_post_image` or `video_thumbnail` slots expose generate/choose actions.
  - Notes: Do not add a standalone playground; action must stay scoped to content/project/placement.

- [ ] Task 13: Add tests for backend registry and publish validation
  - File: `lab/tests/test_social_placement_registry.py`
  - Action: Cover registry shape, doc provenance, required/recommended policies, content type mappings and platform-specific issue generation.
  - User story link: Ensures the registry stays dependable as docs/platforms evolve.
  - Depends on: Tasks 1-5.
  - Validate with: `python -m pytest lab/tests/test_social_placement_registry.py lab/tests/integration/test_publish_router.py`.
  - Notes: Include tests proving provider HTTP client is not called on blocking preflight failure.

- [ ] Task 14: Add Flutter tests
  - File: `app/test/data/social_placement_test.dart`
  - Action: Test model parsing, provider state and editor/preview widget states for placement slots.
  - User story link: Protects the guided UI behavior.
  - Depends on: Tasks 6-11.
  - Validate with: `flutter test app/test/data/social_placement_test.dart app/test/presentation/screens/editor/editor_screen_test.dart`.
  - Notes: Add focused tests rather than broad golden coverage.

- [ ] Task 15: Update docs
  - File: `lab/README.md`
  - Action: Document the placement registry, supported placements, preflight behavior, publish media contract and legacy `media_urls` handling.
  - User story link: Keeps future agents and operators from reintroducing raw URL publishing.
  - Depends on: Tasks 1-5.
  - Validate with: Documentation review and links to external docs in this spec.
  - Notes: Mention that exact platform rules require periodic refresh.

## Acceptance Criteria

- [ ] CA 1: Given an owned content item with selected platforms, when the app requests a placement plan, then the backend returns a registry version and slots for each selected platform.
- [ ] CA 2: Given an unsupported platform is requested, when placement plan is requested, then the backend returns `422` and does not produce a fake slot.
- [ ] CA 3: Given an X/Twitter text post has no image, when preflight runs, then publish is allowed and an optional image recommendation can be returned.
- [ ] CA 4: Given an Instagram/TikTok vertical short has no video asset, when preflight runs, then it returns a blocking missing `vertical_short_video` issue and does not call the provider.
- [ ] CA 5: Given a selected project image is active and compatible with `social_post_image`, when it is set primary for the content placement, then preflight includes it in the platform media plan.
- [ ] CA 6: Given a selected asset belongs to another project, when preflight runs, then it returns `403` or a blocking issue without provider call or leaked metadata.
- [ ] CA 7: Given a selected asset is tombstoned, local-only or degraded, when preflight runs, then it blocks publish media for that slot.
- [ ] CA 8: Given a YouTube target has a video asset but no thumbnail, when the plan is shown, then `landscape_video` and `video_thumbnail` are represented separately.
- [ ] CA 9: Given two assets are candidates for one placement, when the user sets one primary, then only the primary is used in preflight.
- [ ] CA 10: Given publish succeeds, when content metadata is updated, then used `asset_id`, `placement_id`, `platform`, `registry_version` and provider result are recorded without signed URL tokens.
- [ ] CA 11: Given provider returns a platform media error after preflight, when publish response is persisted, then normalized error metadata is visible and asset selections remain unchanged.
- [ ] CA 12: Given Flutter has a stale registry version, when publish preflight returns a newer registry version, then the UI refreshes the plan before final publish action.
- [ ] CA 13: Given legacy `media_urls` are sent by an old client, when no `asset_placements` are present, then the backend follows the documented compatibility path and never treats those URLs as validated project assets.
- [ ] CA 14: Given the editor opens the placement picker for `blog_hero`, when the user selects a compatible active image, then the UI shows the slot as attached and the usage is persisted with that placement.
- [ ] CA 15: Given a missing image slot supports generation, when the user chooses generate, then the action opens the guided Image Robot/Flux path scoped to project, content and placement.

## Test Strategy

- Backend unit tests:
  - Registry service returns stable ids, registry version, doc provenance and correct required/recommended policies.
  - Compatibility logic rejects wrong media kind, tombstoned/local/degraded assets and unsupported placements.
  - Registry does not mark Instagram exact dimensions as strict until official docs are manually refreshed.
- Backend integration tests:
  - Publish route runs preflight before provider calls.
  - Provider HTTP client is not called on ownership failure, missing required placement or incompatible asset.
  - Provider payload is built from resolved project asset descriptors, not client `media_urls`.
  - Publish metadata records asset placements and sanitized provider results.
- Flutter tests:
  - Dart models parse registry/preflight payloads with unknown future fields.
  - Provider ignores stale responses after project/content switch.
  - Editor placement panel shows required, recommended, attached, missing and incompatible states.
  - Platform preview sheet distinguishes text-only allowed from media-required blocks.
- Manual QA:
  - Create content with X/Twitter and LinkedIn channels; verify text-only publish preflight is allowed with recommendations.
  - Create Instagram/TikTok vertical content without video; verify publish is blocked with an actionable slot message.
  - Generate/select a Flux image for social post image; verify it appears as attached and publish preflight uses it.
  - Tombstone an attached asset; verify the slot becomes blocked and asks for replacement.

## Risks

- Platform rules drift quickly. Mitigation: backend-owned versioned registry, doc sources and periodic refresh; UI does not own final constraints.
- Existing raw `media_urls` behavior can undermine asset validation if left as an uncontrolled production path. Mitigation: define a documented legacy compatibility path and route new UI through asset placements only.
- Exact Instagram constraints could be wrong if inferred from cached snippets. Mitigation: block strict Instagram rule enforcement until manual official refresh.
- Publish provider abstraction may not expose every platform-specific media field we want. Mitigation: start with internal preflight and provider-compatible media payloads; store provider errors for later refinement.
- Media metadata may be incomplete for older assets. Mitigation: warnings for optional rules, blocking only where durability/media kind/status is required; add repair/generation actions.
- UI could become too dense on mobile. Mitigation: use a compact slot summary in editor and expand into picker/sheet for edits.
- Video/audio placements depend on future workflows. Mitigation: include stable placement ids now, but attach to content-level publish flow until video_version validation ships.

## Execution Notes

- Read first:
  - `lab/api/routers/publish.py`
  - `lab/api/routers/assets.py`
  - `lab/status/service.py`
  - `app/lib/presentation/screens/editor/platform_preview_sheet.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
- Implementation order:
  - Backend registry and preflight models.
  - Registry service tests.
  - Publish preflight and provider payload construction.
  - Flutter models/API/provider.
  - Editor/preview UI slots.
  - Docs.
- Prefer static code-defined registry for V1, not a database table. Add persistence later only if operators need live registry edits.
- Do not add a new asset store. Use existing `project_assets` and `project_asset_usages`.
- Do not introduce new social provider SDKs in this spec. Keep Zernio/LATE integration boundary.
- Do not implement automatic crop/transcode in V1; return clear issues and generation/replacement actions.
- Stop condition: if Zernio's current API cannot accept the media payloads required by selected platforms, split a provider contract spec before shipping publish-side changes.
- Stop condition: if strict Instagram publishing constraints are needed for launch, manually refresh Meta official docs before `/sf-ready`.

## Open Questions

None blocking for this spec draft. The implementation can start with existing ContentGlows channels and conservative registry rules. Before strict Instagram enforcement, a human or agent with working Meta docs access must refresh the official Instagram Content Publishing documentation and update the registry source metadata.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-13 03:21:04 UTC | sf-spec | GPT-5 Codex | Created social placement format registry spec from contentglows inspiration, existing asset library and official social platform docs. | Draft spec saved. | /sf-ready Social placement format registry |

## Current Chantier Flow

- sf-spec: done for this draft.
- sf-ready: not launched.
- sf-start: not launched.
- sf-verify: not launched.
- sf-end: not launched.
- sf-ship: not launched.
- Next command: `/sf-ready Social placement format registry`.
