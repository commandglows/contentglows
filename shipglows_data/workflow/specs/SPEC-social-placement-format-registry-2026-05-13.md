---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: "contentglows"
created: "2026-05-13"
created_at: "2026-05-13 03:21:04 UTC"
updated: "2026-08-09"
updated_at: "2026-08-09 19:26:33 UTC"
status: ready
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
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.3.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/design-system-authority.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md"
    artifact_version: "1.1.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.1"
    required_status: "reviewed"
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
  - artifact: "shipglows_data/business/project-competitors-and-inspirations.md"
    artifact_version: "1.2.0"
    required_status: "reviewed"
  - artifact: "Zernio create-post and media validation API"
    artifact_version: "official docs checked 2026-08-08: https://docs.zernio.com/posts/create-post and https://docs.zernio.com/validate/validate-media"
    required_status: "official"
  - artifact: "Zernio Instagram platform guide"
    artifact_version: "official provider docs checked 2026-08-08: https://docs.zernio.com/platforms/instagram"
    required_status: "advisory until direct Meta refresh for strict numeric enforcement"
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
  - "shipglows_data/business/project-competitors-and-inspirations.md: Canva simplicity, CapCut templates, Remotion composable video, Descript text editing and AI media tools are inspirations only."
  - "Canonical app/lab guidelines: generated outputs use standard interoperable media formats, backend auth remains authoritative, and API changes preserve Flutter compatibility."
  - "Code evidence: app/lib/data/models/content_item.dart defines PublishingChannel for wordpress, ghost, twitter, linkedin, instagram, tiktok and youtube."
  - "Code evidence: app/lib/presentation/screens/editor/platform_preview_sheet.dart shows platform previews but has no asset slot or placement validation."
  - "Code evidence: lab/api/routers/publish.py accepts media_urls and sends them to Zernio as image media without project asset ownership or placement validation."
  - "Code evidence: lab/status/schemas.py and lab/api/routers/assets.py already define project assets, usages, placement, primary state, tombstone history and storage descriptors."
  - "Code evidence: lab/status/service.py supports usage actions including select_for_content, publish_media and set_primary, but video_version target validation is not available yet."
  - "Code evidence: app/lib/presentation/widgets/project_asset_picker.dart already accepts a placement string and can be reused for slot-specific picking."
  - "Fresh docs checked 2026-05-13: official docs confirm current social APIs treat media as platform-specific upload/use cases rather than arbitrary raw URLs."
  - "Fresh provider docs checked 2026-08-08: Zernio POST /v1/posts accepts mediaItems, supports x-request-id idempotency, and exposes media URL validation; current local publish code still sends the legacy media field and no idempotency header."
  - "Readiness review 2026-08-08: remaining tasks were aligned to current files, exact endpoint and legacy-input precedence were fixed, and proportional OWASP/Test Contracts were added."
next_step: "/102-sg-start Social Placement Format Registry"
---

# Title

Social Placement Format Registry

## Status

Ready. The backend registry slice is already implemented: stable format, platform and placement IDs, EN/FR labels, legacy aliases, validation and an authenticated read-only registry endpoint. Tasks 3-15 are the bounded remaining implementation contract for placement planning, compatibility checks, publish preflight, Flutter consumers, proof and documentation.

## User Story

En tant que creatrice ContentGlows authentifiee, je veux voir et attacher les bons assets aux bons emplacements de publication par plateforme, afin que mes contenus sociaux, articles, thumbnails, videos courtes et pistes audio partent avec des formats efficaces sans sortir de l'editeur guide.

## Minimal Behavior Contract

When a creator opens a content editor, video editor or publish review for an owned content item, ContentGlows computes a placement plan from the content type and selected platforms, shows the required and recommended asset slots, lets the creator generate or pick eligible project assets for each slot, persists the selection as project asset usages, and blocks publish only when a selected platform cannot be served safely without a required asset. If an asset is missing, foreign, local-only, tombstoned, degraded, incompatible, stale or based on a platform rule that needs manual refresh, the UI shows a recoverable warning or blocking error and the backend does not send that media to the publish provider. The easy edge case to miss is treating platform media as raw URLs: the publish path must resolve server-validated project assets and placements, while exact platform dimensions stay in a versioned registry that can be refreshed as external rules change.

## Success Behavior

- Given an authenticated creator owns a project and opens a content editor, when the content targets blog, X/Twitter, LinkedIn, Instagram, TikTok or YouTube, then the app requests a backend placement plan for that content and renders platform-specific slots.
- Given a blog article targets blog plus social promotion, when the plan is built, then it includes at least `PLC_BLOG_HERO`, `PLC_SOCIAL_POST_IMAGE` and `PLC_LINK_THUMBNAIL` recommendations where relevant.
- Given a social post targets X/Twitter or LinkedIn, when no asset is required, then the plan still recommends `PLC_SOCIAL_POST_IMAGE` or `PLC_LINK_THUMBNAIL` but does not block text-only publish.
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
- A direct raw `media`/`media_urls` request without `media_contract_version` uses only the documented legacy validation path. Declaring `asset_placements.v1` with either raw field returns `400`/`PFL_LEGACY_CONFLICT`; the backend never mixes contracts.
- A provider timeout or rejection after internal preflight persists a normalized platform error in publish metadata without changing asset usage state.
- A stale registry version in Flutter triggers a registry refresh before publish instead of publishing with hidden outdated client assumptions.
- What must never happen: raw public URLs accepted as trusted media authority, cross-project asset publish, local-only files sent to Zernio, tombstoned assets reused, provider secrets or signed tokens returned to Flutter, or a silent downgrade from a missing required video/image slot to text-only publish on media-first platforms.

## Problem

ContentGlows now has the foundations for project assets and AI image generation, but publication still treats media too loosely. The backend publish route accepts `media_urls` and forwards them as images; the Flutter preview sheet shows platform text previews but not the assets that must accompany a post. This leaves a gap between generated/reused project assets and actual distribution: users can create useful visuals, thumbnails, videos or audio, but the system does not yet model which asset belongs to which platform placement, which assets are required, which are only recommended, and what blocks publishing.

ContentGlows inspiration points in the right direction: Canva and CapCut show that guided formats and templates are more useful than a blank creative tool, Remotion makes video outputs composable, and the guidelines push standard media formats. For ContentGlows, the product goal is not artistic freedom; it is efficient, guided, platform-aware content distribution from the current editor.

## Solution

Add a backend-owned social placement registry and publish preflight layer. The registry defines stable placement ids, supported platforms, content types, required/recommended rules, compatible asset media kinds, format hints, media intent and external doc provenance. Flutter consumes the registry to render slots in the editor/publish review and uses the existing project asset picker to attach assets by placement. The publish backend resolves those asset usages server-side and builds provider media payloads only from owned, active, durable assets.

### V1 API and media transition contract

- Keep the existing authenticated `GET /api/placement-registry` endpoint as the full catalog endpoint.
- Add `GET /api/content/{content_id}/placement-plan?platform=<value>&platform=<value>&locale=<locale>`. The backend resolves the owned content record and its project, maps its existing `content_type` to a canonical `FMT_*` id, resolves platform aliases to canonical `PLAT_*` ids, and returns `registry_version`, `content_id`, `format_id`, per-platform slots and issue codes. The response does not expose `user_id`, storage paths or provider credentials.
- Add `POST /api/publish/preflight` with `content_record_id`, the same platform/account targets used by publish, and optional `registry_version`. V1 resolves selected media only from primary `project_asset_usages` rows where `target_type=content`, `target_id=<content_record_id>` and `placement=<canonical PLC_* id>`; the client does not need to resend asset ids to publish.
- The preflight response returns `can_publish`, the current `registry_version`, per-platform `can_publish`, resolved slot summaries, sanitized provider `mediaItems` summaries and stable issue codes. Required failures set `can_publish=false`; advisory or recommended gaps remain warnings.
- Stable V1 issue codes are `PFL_MISSING_REQUIRED`, `PFL_ASSET_NOT_FOUND`, `PFL_ASSET_FORBIDDEN`, `PFL_ASSET_STATUS_BLOCKED`, `PFL_ASSET_INCOMPATIBLE`, `PFL_STORAGE_UNAVAILABLE`, `PFL_REGISTRY_STALE`, `PFL_UNSUPPORTED_PLATFORM`, `PFL_PROVIDER_CONTRACT_UNSUPPORTED` and `PFL_LEGACY_CONFLICT`. Labels/messages are localizable; codes are immutable and never translated.
- `media_contract_version="asset_placements.v1"` selects the new contract. In that mode `media` and `media_urls` are rejected with `400`/`PFL_LEGACY_CONFLICT`; the backend uses only validated primary usages.
- Requests that omit `media_contract_version` but contain `media` or `media_urls` remain on the explicit legacy compatibility path. The backend never mixes those values with project asset usages, validates that URLs are public HTTP(S) media inputs before provider submission, records `mediaContract="legacy_raw_urls"` plus a sanitized count in publish metadata, and never records them as validated project assets. New Flutter code must always send `asset_placements.v1` and must never send raw media URLs.
- Provider payload construction uses the current Zernio field `mediaItems`, not the local legacy `media` field. Each item is derived from a backend-resolved durable Bunny URL and contains only provider-supported fields. Reuse or extract the existing Bunny URL resolution behavior from `lab/api/routers/video_timelines.py`; do not create a second inconsistent URL policy.
- Each logical provider create-post call sends one persisted UUID as `x-request-id`. Retries for the same logical publish reuse it; a new publish attempt gets a new value. Handle Zernio's `existingPost` idempotent response as the original post result rather than as a second publication.
- If a required placement cannot be represented by the current Zernio contract, preflight returns `PFL_PROVIDER_CONTRACT_UNSUPPORTED` and no provider call occurs. Optional provider-unsupported placements remain warnings and are not silently inserted into `mediaItems`.

## Scope In

- A versioned placement registry in `lab` covering V1 platform/channel surfaces: blog/CMS output, X/Twitter, LinkedIn, Instagram, TikTok and YouTube.
- Stable placement ids for V1:
  - `PLC_BLOG_HERO`
  - `PLC_INLINE_IMAGE`
  - `PLC_SOCIAL_POST_IMAGE`
  - `PLC_LINK_THUMBNAIL`
  - `PLC_VIDEO_THUMBNAIL`
  - `PLC_VERTICAL_SHORT_VIDEO`
  - `PLC_LANDSCAPE_VIDEO`
  - `PLC_REEL_COVER`
  - `PLC_CAPTION_TRACK`
  - `PLC_AUDIO_TRACK`
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
- New Flutter requests must send `media_contract_version="asset_placements.v1"`; legacy requests are detected only by an absent version plus present `media`/`media_urls`, are never mixed with primary usages, and remain explicitly observable for later retirement.
- Blog/CMS outputs are represented in placement planning, but current Zernio social publish excludes `wordpress` and `ghost`; CMS publishing remains a separate integration.
- Instagram exact constraints must be manually refreshed from official Meta docs before strict Instagram-specific dimensions/durations are enforced. Until then, V1 should use conservative recommended presets and provider rejection handling rather than pretending the agent-cached snippet is authoritative.
- Current Zernio provider docs may confirm that Instagram requires media and may inform advisory hints, but they do not authorize strict numeric Instagram enforcement in the registry without the direct Meta refresh above.
- Video-version placements cannot mutate `target_type=video_version` until the video asset store validation ships; V1 may attach publish placements to `target_type=content` and link to video render assets by asset id/metadata.
- Placement ids must be stable. Display labels can change, ids cannot silently change because project asset usages depend on them.
- For `publish_media` and placement-scoped `set_primary`, aliases are accepted at the API boundary but canonical `PLC_*` ids are persisted. Existing legacy aliases are resolved during preflight; unrelated placements such as `editor_body` are ignored, not rewritten.
- UI changes follow `tools/design-tokens/contentglows_theme.json` through `tools/design-tokens/generate_app_theme_tokens.mjs`; no one-off visual constants are introduced when a shared token applies.

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
  - `shipglows_data/business/project-competitors-and-inspirations.md`
  - `shipglows_data/product/app/product.md`
  - `shipglows_data/technical/lab/guidelines.md`
  - `shipglows_data/technical/app/guidelines.md`
  - `shipglows_data/technical/design-system-authority.md`
- Related specs:
  - `shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md`
- Fresh external docs:
  - `fresh-docs checked`: Zernio create-post API uses `mediaItems` and supports per-logical-request `x-request-id` idempotency: `https://docs.zernio.com/posts/create-post`.
  - `fresh-docs checked`: Zernio media validation rejects private/localhost URLs and reports media metadata/limits: `https://docs.zernio.com/validate/validate-media`.
  - `fresh-docs checked`: Zernio's current Instagram guide confirms that media is required; its numeric limits remain advisory in ContentGlows until direct Meta refresh: `https://docs.zernio.com/platforms/instagram`.
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
- Placement-scoped primary selection and demotion stay within the same `project_id` and `user_id`, and run atomically so concurrent requests cannot leave two active primaries for one content/placement.
- Candidate assets can appear in UI but do not publish until selected as primary or explicitly included by the backend plan.
- Registry warnings are visible before the publish call; provider errors are normalized after the provider call.
- Platform docs are unstable, so the registry must store provenance and last review metadata.
- Rule provenance is platform-specific. A rule may not inherit unrelated X or YouTube documentation merely because all rules are stored in one registry module.
- A publish request uses exactly one media contract: validated primary usages or the explicit legacy raw-URL path, never both.
- A logical provider call is idempotent across retries and records a request id without exposing it to unrelated users.

## Links & Consequences

- `lab/api/routers/publish.py`: must stop treating app-provided media URLs as the authoritative media contract for new publish flows, use current Zernio `mediaItems`, preserve the explicit isolated legacy path, and reuse a persisted `x-request-id` during reconciliation/retry.
- `lab/api/routers/assets.py`: existing placement and usage endpoints can remain, but this spec may add placement-aware filters or usage summaries.
- `lab/status/service.py`: eligibility currently supports broad `publish_media`; it needs canonical placement validation, owner-scoped primary lookup, atomic primary replacement and placement registry checks for asset media kind, target platform, required slot and current asset status.
- `lab/api/models/status.py`: may need typed placement/preflight response models or a new `api/models/social_placements.py`.
- `app/lib/presentation/widgets/project_asset_picker.dart`: should receive placement/platform constraints so users do not pick irrelevant assets for a slot.
- `app/lib/presentation/screens/editor/platform_preview_sheet.dart`: should display selected/missing assets alongside platform previews, not just text truncation.
- `app/lib/data/models/content_item.dart`: existing `PublishingChannel` is the app-facing channel enum; registry platform ids must map cleanly to it.
- Publish metadata: should record `assetPlacements`, registry version, media contract, platform preflight issues, logical provider request id and a sanitized provider media summary without storing raw signed tokens or raw legacy URLs.
- Analytics/ops: preflight warnings should be counted so we can learn which slots users miss most often.
- Security: this is a hardening step for publish media ownership and URL trust.

## Documentation Coherence

- Update `lab/README.md` and `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` with the catalog, plan/preflight endpoints, supported stable ids, Zernio `mediaItems`, idempotent retry contract and exact legacy `media`/`media_urls` behavior.
- Update `shipglows_data/technical/app/architecture.md` with the rule that Flutter displays registry hints but backend validation and server-selected primary usages are final; new UI publish requests send `asset_placements.v1` and no raw media URL fields.
- Update `CHANGELOG.md` because the authenticated publish API contract changes while preserving an explicit legacy path.
- Add support/product copy for users explaining missing required asset, recommended asset, incompatible asset and generate/choose actions.
- Update related specs when implemented:
  - Flux/Image Robot should list which generated image profiles satisfy `PLC_BLOG_HERO`, `PLC_SOCIAL_POST_IMAGE`, `PLC_LINK_THUMBNAIL`, `PLC_VIDEO_THUMBNAIL` and `PLC_REEL_COVER`.
  - Remotion video spec should emit render assets usable for `PLC_VERTICAL_SHORT_VIDEO`, `PLC_LANDSCAPE_VIDEO` and `PLC_VIDEO_THUMBNAIL`.
  - AI audio spec should emit assets usable for `PLC_AUDIO_TRACK` and future caption/audio placements.

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
- A timeout followed by a retry reuses the same logical `x-request-id`; an `existingPost` response is reconciled as the first call's result and does not create a second content lifecycle transition.
- Two primary-selection requests race for the same content/placement. The final committed primary is unique, and preflight never constructs media from two active primaries.
- An old client sends only `media_urls`. The request follows the legacy validation/metadata path. If it also declares `asset_placements.v1`, it fails with `PFL_LEGACY_CONFLICT` before any provider call.
- A primary usage contains a legacy placement alias. Preflight resolves it to the canonical `PLC_*` id for compatibility; new selections persist only the canonical id.
- Direct provider docs are inaccessible during implementation. Exact hard blocking for that platform rule must remain conservative or warning-only until manually refreshed.

## Implementation Tasks

- [x] Task 1: Add the canonical backend registry read contract
  - File: `lab/api/services/social_placement_registry.py`, `lab/api/routers/placement_registry.py`
  - Action: Define immutable registry entry/rule types, stable `FMT_*`, `PLAT_*` and `PLC_*` ids, EN/FR labels, legacy aliases, validation and the authenticated read-only catalog endpoint.
  - User story link: Makes the shared format/platform/placement vocabulary explicit and inspectable.
  - Depends on: Existing project asset models.
  - Validate with: from `lab/`, `python3 -m pytest tests/test_placement_registry.py`.
  - Notes: Implemented in the existing backend registry tranche. Labels and aliases may evolve; canonical ids may not.

- [x] Task 2: Implement the registry service
  - File: `lab/api/services/social_placement_registry.py`
  - Action: Create the V1 registry for blog/CMS output, X/Twitter, LinkedIn, Instagram, TikTok and YouTube with the stable placement ids listed in this spec.
  - User story link: Converts content type/platform choices into required and recommended asset slots.
  - Depends on: Task 1.
  - Validate with: Unit tests for each content type/platform combination and registry version.
  - Notes: Use conservative recommendations for Instagram until official docs are manually refreshed; do not embed unverified exact limits as blocking rules.

- [x] Task 3: Add typed plan/preflight contracts and exact routes
  - File: `lab/api/models/social_placements.py`, `lab/api/services/social_placement_registry.py`, `lab/api/routers/social_placements.py`, `lab/api/main.py`, `lab/api/routers/__init__.py`
  - Action: Define Pydantic `PlacementPlan`, `PlacementSlot`, `PlacementIssue`, `PublishPreflightRequest` and `PublishPreflightResponse`; expose the exact V1 endpoints in `V1 API and media transition contract`; map existing content/platform aliases to canonical ids; and replace the registry's shared `_DOC_SOURCES` tuple with rule-specific provenance so Instagram rules do not cite unrelated X/YouTube docs.
  - User story link: Lets the UI show slots before publishing.
  - Depends on: Task 2.
  - Validate with: Router/model tests for `401`, owned content, cross-project/nonexistent content, repeated platform query values, aliases, unsupported platforms, locale, issue shape and registry version.
  - Notes: Register one router without changing the existing catalog route. Return `404` for an inaccessible content id to avoid ownership enumeration; return `422` for unsupported public platform input.

- [x] Task 4: Add server-side primary-usage lookup and compatibility checks
  - File: `lab/status/service.py`, `lab/api/services/social_placement_preflight.py`, `lab/api/routers/assets.py`, `lab/api/models/status.py`
  - Action: Add an owner-scoped query for active primary usages by content/placement; canonicalize publish placement aliases before persistence; make placement-scoped primary demotion include `project_id` and `user_id` in one transaction; and validate media family, lifecycle status, ownership, durable storage, MIME plus optional aspect/duration metadata against each rule. Map `image|thumbnail|video_cover|capture` to the image family, `video|render_output` to video, and `audio|music` to audio; unsupported kinds remain incompatible.
  - User story link: Prevents wrong or unsafe assets from reaching publish.
  - Depends on: Tasks 1-3.
  - Validate with: Existing project asset service/router tests plus primary uniqueness, alias persistence, cross-user/project isolation, concurrent/stale primary, status, media family, MIME, metadata-missing warning and durable Bunny URL cases.
  - Notes: Keep generic project asset actions backward compatible when no placement context is provided. `publish_media` and placement-scoped `set_primary` require a recognized placement; legacy non-publish values such as `editor_body` remain readable and are ignored by preflight.

- [x] Task 5: Extend publish request and payload construction
  - File: `lab/api/routers/publish.py`
  - Action: Add `media_contract_version`, run the same preflight service before the external call, resolve primary usages server-side, build Zernio `mediaItems` from durable Bunny URLs, persist/reuse one UUID `x-request-id` per logical attempt, handle `existingPost`, and record sanitized placement/preflight/provider metadata. Implement the exact legacy precedence contract above; do not send the current local `media` field to Zernio.
  - User story link: Makes actual publishing use the selected slots.
  - Depends on: Tasks 1-4.
  - Validate with: `lab/tests/integration/test_publish_router.py` covering success, missing required media, incompatible/foreign/tombstoned asset, required provider-contract gap, `mediaItems` shape, asset/legacy conflict, legacy-only success metadata, public-URL rejection, timeout retry id reuse, `existingPost`, and zero provider calls for every blocking preflight.
  - Notes: Keep content ownership, provider account authorization and duplicate publish checks before external calls. Never return raw storage tokens, request ids or provider secrets. Optional provider-unsupported placements remain warnings; required ones block.

- [x] Task 6: Add Flutter models/API methods for registry and preflight
  - File: `app/lib/data/models/social_placement.dart`
  - Action: Create typed Dart models matching plan/preflight responses, including canonical ids, localized labels, slot state, stable issue codes, per-platform results, `canPublish` and `registryVersion`.
  - User story link: Gives the app typed slot data instead of hard-coded platform assumptions.
  - Depends on: Tasks 1-3 contracts.
  - Validate with: Dart model parsing tests.
  - Notes: Include unknown-field tolerance for registry evolution.

- [x] Task 7: Add Flutter API client methods
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add methods for the exact plan and preflight endpoints; change new publish calls to send `media_contract_version: asset_placements.v1`; remove `media_urls` from the new UI path while retaining deserialization/backward compatibility needed by queued legacy actions.
  - User story link: Connects editor/publish UI to backend slots.
  - Depends on: Task 6.
  - Validate with: Existing API service test pattern or mocked provider tests.
  - Notes: Resolve local id mappings like existing project asset methods. Offline publish remains blocked as today; do not queue a new placement publish with stale registry state or unresolved ids.

- [x] Task 8: Add placement state/provider
  - File: `app/lib/providers/providers.dart`
  - Action: Add a notifier or extend existing content/editor state to load placement plans, cache registry version, track preflight issues and ignore stale project/content responses.
  - User story link: Shows current slot status in the editor and publish review.
  - Depends on: Task 7.
  - Validate with: Provider tests for project switch, stale response, missing slot, selected asset refresh and preflight warnings.
  - Notes: Follow the revision pattern already used by `ProjectAssetLibraryNotifier`. A newer backend registry version invalidates the cached plan and disables the final publish action until refresh/preflight completes.

- [x] Task 9: Update project asset picker for slot-specific selection
  - File: `app/lib/presentation/widgets/project_asset_picker.dart`
  - Action: Accept the slot's canonical placement/platform constraints, show backend-derived eligibility or incompatibility, and persist the chosen asset as primary with `usage_action=publish_media`, `target_type=content` and the canonical placement id.
  - User story link: Lets creators attach the right asset without leaving guided flow.
  - Depends on: Tasks 6-8.
  - Validate with: Widget tests for eligible, missing, incompatible, tombstoned and primary states.
  - Notes: Do not turn the picker into a free media library; keep the slot context visible.

- [x] Task 10: Update editor and platform preview surfaces
  - File: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: Add a placement panel or publish-readiness section that appears from the content editor and uses `ProjectAssetPicker` per slot.
  - User story link: Makes asset placement part of the current editor, not a separate playground.
  - Depends on: Tasks 8-9.
  - Validate with: Editor widget tests for opening placement panel and selecting a slot asset.
  - Notes: Keep mobile layout compact; use a linked bottom sheet/screen rather than crowding the main editor. Use the canonical token JSON/generator and existing theme tokens for spacing, sizes, colors and motion.

- [x] Task 11: Update platform preview sheet
  - File: `app/lib/presentation/screens/editor/platform_preview_sheet.dart`
  - Action: Show selected/missing asset slots for each platform preview and surface blocking/warning issue states.
  - User story link: Lets creators see what will be published per platform.
  - Depends on: Tasks 8-10.
  - Validate with: Widget tests for Twitter text-only allowed, Instagram missing media blocking, YouTube thumbnail separation and LinkedIn optional image warning.
  - Notes: Avoid hard-coding official limits as final truth in the UI; localize messages from stable backend issue codes and preserve the backend's required/warning severity.

- [x] Task 12: Register generation actions from placement slots
  - File: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: For supported empty image slots, reuse `listImageProfiles` and `queueImageGenerationFromProfile` in the existing API client from a content/project/placement-scoped sheet. When no compatible profile exists, keep Choose available and show a localized explanation instead of inventing a free-form generator.
  - User story link: Makes missing slots actionable.
  - Depends on: Existing `/api/images/profiles` and `/api/images/generate-from-profile` contracts plus Tasks 8-10.
  - Validate with: Widget/provider tests that empty `PLC_SOCIAL_POST_IMAGE` or `PLC_VIDEO_THUMBNAIL` slots expose generate/choose actions.
  - Notes: Do not add a standalone playground; action must stay scoped to content/project/placement.

- [x] Task 13: Add tests for backend registry and publish validation
  - File: `lab/tests/test_placement_registry.py`, `lab/tests/test_social_placement_preflight.py`, `lab/tests/integration/test_publish_router.py`
  - Action: Cover registry shape, rule-specific doc provenance, required/recommended policies, content mappings, issue generation, ownership boundaries, media contract transition, provider payload and idempotent retry behavior.
  - User story link: Ensures the registry stays dependable as docs/platforms evolve.
  - Depends on: Tasks 1-5.
  - Validate with: from `lab/`, `python3 -m pytest tests/test_placement_registry.py tests/test_social_placement_preflight.py tests/integration/test_publish_router.py`.
  - Notes: Include tests proving provider HTTP client is not called on blocking preflight failure.

- [ ] Task 14: Add Flutter tests
  - File: `app/test/data/social_placement_test.dart`, `app/test/providers/social_placement_provider_test.dart`, `app/test/presentation/screens/editor/editor_screen_test.dart`, `app/test/presentation/screens/editor/platform_preview_sheet_test.dart`
  - Action: Test model parsing, request contract, stale-response protection, provider state and editor/preview widget states for placement slots.
  - User story link: Protects the guided UI behavior.
  - Depends on: Tasks 6-11.
  - Validate with: use the focused Flutter command in `Execution Notes`.
  - Notes: Add focused tests rather than broad golden coverage.

- [x] Task 15: Update docs
  - File: `lab/README.md`, `shipglows_data/technical/lab/backend-runtime-and-product-apis.md`, `shipglows_data/technical/app/architecture.md`, `CHANGELOG.md`
  - Action: Document the placement registry, supported ids, plan/preflight endpoints, `mediaItems` provider mapping, idempotency, server-authoritative asset selection, Flutter refresh behavior and the explicit legacy `media`/`media_urls` transition.
  - User story link: Keeps future agents and operators from reintroducing raw URL publishing.
  - Depends on: Tasks 1-5.
  - Validate with: Documentation review and links to external docs in this spec.
  - Notes: Mention that exact platform rules require periodic refresh.
  - Progress: backend documentation, Flutter architecture and changelog now document registry, plan/preflight, `mediaItems`, idempotency, server authority, stale-registry recovery and isolated legacy behavior.

## Acceptance Criteria

- [x] CA 1: Given an owned content item with selected platforms, when the app requests a placement plan, then the backend returns a registry version and slots for each selected platform.
- [x] CA 2: Given an unsupported platform is requested, when placement plan is requested, then the backend returns `422` and does not produce a fake slot.
- [x] CA 3: Given an X/Twitter text post has no image, when preflight runs, then publish is allowed and an optional image recommendation can be returned.
- [x] CA 4: Given an Instagram/TikTok vertical short has no video asset, when preflight runs, then it returns a blocking missing `PLC_VERTICAL_SHORT_VIDEO` issue and does not call the provider.
- [x] CA 5: Given a selected project image is active and compatible with `PLC_SOCIAL_POST_IMAGE`, when it is set primary for the content placement, then preflight includes it in the platform media plan.
- [x] CA 6: Given a selected asset belongs to another project or user, when preflight runs, then it returns a sanitized `404`/blocking issue without provider call or leaked metadata.
- [x] CA 7: Given a selected asset is tombstoned, local-only or degraded, when preflight runs, then it blocks publish media for that slot.
- [ ] CA 8: Given a YouTube target has a video asset but no thumbnail, when the plan is shown, then `PLC_LANDSCAPE_VIDEO` and `PLC_VIDEO_THUMBNAIL` are represented separately.
- [x] CA 9: Given two assets are candidates for one placement, when the user sets one primary, then only the primary is used in preflight.
- [x] CA 10: Given publish succeeds, when content metadata is updated, then used `asset_id`, `placement_id`, `platform`, `registry_version`, `mediaContract`, logical provider request id and provider result are recorded without signed URL tokens, provider secrets or raw legacy URLs.
- [x] CA 11: Given provider returns a platform media error after preflight, when publish response is persisted, then normalized error metadata is visible and asset selections remain unchanged.
- [ ] CA 12: Given Flutter has a stale registry version, when publish preflight returns a newer registry version, then the UI refreshes the plan before final publish action.
- [x] CA 13: Given legacy `media` or `media_urls` are sent without `media_contract_version`, when publish runs, then the backend validates the public HTTP(S) inputs, uses only the isolated legacy path, records `mediaContract=legacy_raw_urls`, and never treats the URLs as project assets; declaring `asset_placements.v1` with either raw field returns `400`/`PFL_LEGACY_CONFLICT` before provider access.
- [ ] CA 14: Given the editor opens the placement picker for `PLC_BLOG_HERO`, when the user selects a compatible active image, then the UI shows the slot as attached and the usage is persisted with that placement.
- [ ] CA 15: Given a missing image slot supports generation, when the user chooses generate, then the action opens the guided Image Robot/Flux path scoped to project, content and placement.
- [x] CA 16: Given English and French registry responses, when entries are compared, then immutable IDs and registry version remain identical while labels are localized; legacy aliases resolve to the same IDs and unknown IDs are rejected.
- [x] CA 17: Given a validated primary Bunny asset, when publish reaches Zernio, then the outbound payload uses `mediaItems` with a token-free durable URL and does not use the obsolete local `media` key.
- [x] CA 18: Given a provider timeout and a retry of the same logical publish, when the request is retried, then the same `x-request-id` is reused and an `existingPost` response is reconciled without a duplicate lifecycle transition.
- [x] CA 19: Given two concurrent primary selections for one content/placement, when both finish, then exactly one active primary remains within the same project/user boundary.
- [x] CA 20: Given any registry rule, when its provenance is inspected, then it names only relevant platform documentation; Instagram exact dimensions/durations remain advisory until direct Meta refresh.
- [ ] CA 21: Given the new Flutter publish flow, when its request is inspected, then it sends `media_contract_version=asset_placements.v1`, sends neither `media` nor `media_urls`, and blocks final publish while registry refresh or blocking preflight issues remain.

## Test Contract

- `surface`: authenticated FastAPI registry/plan/preflight/publish endpoints, project asset usage service, Flutter editor placement sheet, picker integration and platform preview.
- `proof_profile`: focused backend unit/router/integration tests, focused Dart model/provider/widget tests, static analysis, documentation/metadata lint and bounded manual UI QA.
- `proof_order`:
  1. Backend registry/model/service unit tests.
  2. Backend router and publish integration tests with the provider client mocked.
  3. Flutter model/provider tests.
  4. Flutter editor/picker/preview widget tests and `flutter analyze`.
  5. Metadata/documentation review, then manual responsive QA for the editor sheet and publish blocking/recovery states.
- `checklist_path`: not applicable; the required scenarios are the acceptance criteria and manual QA list in this spec, and no external-device-only platform behavior is introduced.
- `required_scenario_ids`: `CA 1` through `CA 21`, including already-proved `CA 16` as a regression.
- `required_results`: all focused automated tests pass; backend provider mocks prove zero calls on every blocking issue; outbound payload and logs contain no storage/provider token; Flutter analyze is clean for touched code; manual QA proves required versus recommended states and usable compact layout.
- `exception_with_proof`: if browser/device manual QA is unavailable, widget tests at compact and wide constraints plus a recorded visual-proof gap may support implementation verification, but UI closure remains partial until the missing visual proof is completed.
- `exception_without_proof`: not allowed for ownership isolation, raw/validated media separation, provider-call blocking, token redaction, primary uniqueness, stale-registry blocking or idempotent retry.
- Runtime diagnostics must record UTC timestamp, content id, project id, canonical platform/placement, registry version, issue code, media contract and provider result status. They must not record auth tokens, API keys, signed query strings, raw legacy URLs, content bodies or provider payload secrets.

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

## Product Coherence Gate

- Business/product alignment: the shared business promise is publishable output with predictable execution; the app product serves creators who lose continuity across disconnected content tools. Guided placement planning directly supports both without adding a separate creative product.
- Journey/capability alignment: the critical moment is the final publish decision. Success is a visible per-platform readiness state; failure remains in the editor with a precise choose/generate/replace recovery action and no external call.
- Architecture alignment: FastAPI remains the auth, ownership, registry and publish authority; Flutter remains a typed consumer; the existing project asset library remains the only asset governance layer; Zernio remains the external adapter.
- Atlas: not applicable because this repository has no `shipglows_data/workflow/atlas/approved-surfaces.json`; no protection-level claim is made.
- Cross-contract result: no conflict, material orphan or unresolved gap found. The reviewed Flux spec is sufficient only for reusing already-existing profile/generation APIs; this chantier does not expand or certify the wider Flux provider spec.

## OWASP Security Gate

- Risk level: high because this changes authenticated object access, persisted asset selection and an external publication side effect.
- Top 10:2025 categories considered: `A01 Broken Access Control`, `A05 Injection`, `A06 Insecure Design`, `A08 Software or Data Integrity Failures`, `A09 Security Logging and Alerting Failures`, and `A10 Mishandling of Exceptional Conditions`.
- Trust/data boundaries: Clerk-authenticated Flutter input -> FastAPI authorization and Pydantic boundary -> owner-scoped Turso project/content/usage rows -> durable Bunny delivery URL -> server-held Zernio credential and external create-post API.
- Selected ASVS v5.0.0 requirements: `v5.0.0-2.2.2` trusted-layer input validation; `v5.0.0-2.3.3` transactional business operation; `v5.0.0-8.2.2` object-level authorization; `v5.0.0-8.3.1` server-side authorization enforcement; `v5.0.0-14.2.6` minimum sensitive-data response; `v5.0.0-16.3.2` failed-authorization logging; `v5.0.0-16.5.1` non-disclosing errors; `v5.0.0-16.5.3` fail-secure exceptional behavior.
- Required proof: `401` unauthenticated tests; owner/cross-owner project-content-asset tests; canonical allowlist validation; transaction/primary concurrency test; no-provider-call assertions for every block; redaction assertions; timeout/idempotency/reconciliation tests; sanitized security-event logging assertions.
- Residual gap and owner route: strict numeric Instagram rules remain advisory until direct Meta documentation is refreshed. This does not block V1 because media-required behavior is independently confirmed and the spec forbids strict numeric enforcement before that refresh.

## Risks

- Platform rules drift quickly. Mitigation: backend-owned versioned registry, doc sources and periodic refresh; UI does not own final constraints.
- Existing raw `media`/`media_urls` behavior can undermine asset validation if mixed into the new path. Mitigation: explicit mutually exclusive media contracts, public-URL validation and legacy telemetry; new Flutter always declares `asset_placements.v1`.
- The current provider adapter uses the local `media` field while current Zernio docs specify `mediaItems`. Mitigation: Task 5 replaces the outbound provider field and asserts the exact mocked payload before any completion claim.
- Timeout retries can duplicate external posts. Mitigation: persist and reuse one provider `x-request-id` per logical attempt and reconcile `existingPost` responses.
- Concurrent primary selection can leave ambiguous media intent. Mitigation: owner-scoped transactional replacement, the existing partial unique-index invariant for non-null canonical placements, and a race-focused test.
- Exact Instagram constraints could be wrong if inferred from cached snippets. Mitigation: block strict Instagram rule enforcement until manual official refresh.
- Publish provider abstraction may not expose every platform-specific media field we want. Mitigation: start with internal preflight and provider-compatible media payloads; store provider errors for later refinement.
- Media metadata may be incomplete for older assets. Mitigation: warnings for optional rules, blocking only where durability/media kind/status is required; add repair/generation actions.
- UI could become too dense on mobile. Mitigation: use a compact slot summary in editor and expand into picker/sheet for edits.
- Video/audio placements depend on future workflows. Mitigation: include stable placement ids now, but attach to content-level publish flow until video_version validation ships.

## Execution Notes

- Read first:
  - `lab/api/services/social_placement_registry.py`
  - `lab/api/routers/placement_registry.py`
  - `lab/api/routers/publish.py`
  - `lab/api/routers/assets.py`
  - `lab/api/services/project_asset_storage.py`
  - `lab/api/routers/video_timelines.py` (`_resolve_project_asset_render_url` behavior)
  - `lab/status/service.py`
  - `lab/tests/integration/test_publish_router.py`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/screens/editor/platform_preview_sheet.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
- Implementation order:
  - Backend registry and preflight models.
  - Registry service tests.
  - Publish preflight and provider payload construction.
  - Flutter models/API/provider.
  - Editor/preview UI slots.
  - Docs.
- Validation commands:
  - From `lab/`: `python3 -m pytest tests/test_placement_registry.py tests/test_social_placement_preflight.py tests/test_project_assets_service.py tests/test_project_assets_router.py tests/integration/test_publish_router.py`.
  - From `app/`: `flutter test test/data/social_placement_test.dart test/providers/social_placement_provider_test.dart test/presentation/screens/editor/editor_screen_test.dart test/presentation/screens/editor/platform_preview_sheet_test.dart test/presentation/widgets/project_asset_picker_test.dart`.
  - From `app/`: `flutter analyze`.
  - From repo root: `node tools/design-tokens/generate_app_theme_tokens.mjs --check` and `python3 /home/claude/shipglows/tools/shipglows_metadata_lint.py shipglows_data/workflow/specs/SPEC-social-placement-format-registry-2026-05-13.md`.
- Prefer static code-defined registry for V1, not a database table. Add persistence later only if operators need live registry edits.
- Do not add a new asset store. Use existing `project_assets` and `project_asset_usages`.
- Do not introduce new social provider SDKs in this spec. Keep Zernio/LATE integration boundary.
- Do not implement automatic crop/transcode in V1; return clear issues and generation/replacement actions.
- Stop condition: if Zernio's current API cannot represent a required V1 placement, return `PFL_PROVIDER_CONTRACT_UNSUPPORTED` with no provider call and split a provider-contract follow-up before shipping that required path; do not invent a payload field.
- Stop condition: if strict numeric Instagram constraints become launch requirements, pause those rules and refresh direct Meta official docs. Otherwise keep current media-required behavior plus numeric hints conservative/advisory.
- Stop condition: if primary usage lookup cannot be made tenant-safe and atomic with the current schema, route a bounded additive Turso/libSQL migration before publish integration; do not weaken ownership or uniqueness.
- Stop condition: if raw and validated media would be mixed, fail closed with `PFL_LEGACY_CONFLICT` rather than choosing silently.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-13 03:21:04 UTC | sf-spec | GPT-5 Codex | Created social placement format registry spec from contentglows inspiration, existing asset library and official social platform docs. | Draft spec saved. | /sf-ready Social placement format registry |
| 2026-08-08 00:05:00 UTC | 001-sg-build | GPT-5 Codex | Implemented the backend registry tranche with immutable short IDs, EN/FR labels, legacy alias resolution, validation and authenticated read-only endpoint. | Partial: focused registry tests and Python compilation pass; placement plan, preflight, publish integration and Flutter consumers remain pending. | Continue placement plan and preflight tranche. |
| 2026-08-08 18:38:59 UTC | 101-sg-ready | gpt-5.6-sol | Reviewed remaining tasks against current backend/Flutter code, current Zernio provider docs, the conservative Instagram rule, legacy media transition and OWASP/Test Contracts. | Ready: exact routes, ownership boundaries, provider payload/idempotency, proof and stop conditions are implementation-safe. | /102-sg-start Social Placement Format Registry |
| 2026-08-08 19:01:11 UTC | 102-sg-start | gpt-5.6-sol | Implemented Tasks 3-5 and backend portions of Tasks 13/15: typed plan/preflight routes, owner-scoped atomic primary selection, compatibility/storage validation, server-resolved Zernio mediaItems, exclusive legacy contract, idempotent retry and sanitized metadata. | Implemented backend tranche: 97 focused tests pass plus Python compilation and route registration checks; Flutter Tasks 6-12/14 and app docs remain pending. | Continue the Flutter placement consumer tranche, then combined verification. |
| 2026-08-09 00:00:00 UTC | 102-sg-start | GPT-5 Codex | Completed Flutter Tasks 6-12: typed placement contracts, API/client state, stale-response handling, slot-aware picker, editor panel, preview readiness summary and scoped image-generation action. | Implemented; Flutter test/analyze proof is intentionally deferred by operator VM policy. | Run focused Flutter proof and combined verification on an approved machine. |
| 2026-08-09 19:26:33 UTC | 300-sg-docs | GPT-5 Codex | Aligned Flutter architecture and changelog with the social placement registry, server-authoritative preflight and legacy media transition. | Documentation updated; runtime proof remains deferred by operator VM policy. | Run focused Flutter proof and combined verification on an approved machine. |

## Current Chantier Flow

- 100-sg-spec: complete; existing spec retained and tightened for current code/provider truth.
- 101-sg-ready: ready on 2026-08-08.
- 102-sg-start: implemented; backend Tasks 3-5 and 13 plus Flutter Tasks 6-12 are implemented, and Task 15 documentation is complete.
- backend registry: implemented and verified.
- placement plan/preflight: implemented and focused tests pass.
- publish integration: implemented and focused tests pass.
- Flutter consumers: implemented; focused test/analyze evidence deferred by operator VM policy.
- 103-sg-verify: pending combined proof on an approved machine.
- 104-sg-end: pending.
- 005-sg-ship: not authorized in this run.
- Next step: run focused Flutter proof for Task 14, then combined verification.
