---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: "app"
created: "2026-05-10"
created_at: "2026-05-10 22:48:42 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 06:15:00 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "En tant que créateur ContentGlowz, je veux transformer une idée ou un angle en script vidéo structuré pour Short, Reel, TikTok, YouTube Shorts ou vidéo paysage longue, afin de préparer un contenu filmable et révisable sans encore produire la vidéo finale."
risk_level: medium
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter /reels workbench"
  - "app Flutter Angles"
  - "app Flutter Editor"
  - "app Flutter Feed cards"
  - "app ContentItem model"
  - "lab dispatch-pipeline"
  - "lab PipelineDispatchRequest"
  - "lab ShortContentCrew"
  - "lab status/content body versioning"
  - "lab AI runtime preflight"
depends_on:
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-editor-multiformat.md"
    artifact_version: "0.1.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md"
    artifact_version: "1.0.0"
    required_status: "ready"
supersedes: []
evidence:
  - "User clarified on 2026-05-10 that the near-term goal is script creation, not real video generation."
  - "User confirmed on 2026-05-11 that `/reels` becomes the primary video script workbench and import/repurpose remains secondary."
  - "User confirmed on 2026-05-11 that V1 adds a true backend `video_script` target format instead of mapping it to `article`."
  - "User confirmed on 2026-05-11 that generation creates a content record directly as `in_progress`, then moves to review only after the body is persisted."
  - "User added on 2026-05-11 that the workbench needs a button to switch to landscape / long format."
  - "lab/api/routers/psychology.py currently supports async `dispatch-pipeline` for article, newsletter, short, and social_post."
  - "app/lib/data/services/api_service.dart currently maps angle `video_script` to backend `article`, which this spec must correct."
  - "lab/agents/short/short_crew.py already generates hook, script, duration_seconds, on_screen_text, hashtags, cta, visual_notes, and thumbnail_concept."
  - "app/lib/presentation/screens/reels/reels_screen.dart is currently a repurposing/download surface, not a script workbench."
  - "app/lib/data/services/api_service.dart and app/lib/providers/providers.dart already enforce full-body loading before editor/publish paths."
next_step: "/sf-ready Video Script Creation Workbench"
---

# Title

Video Script Creation Workbench

## Status

Draft spec updated after readiness review. Product decisions are locked: `/reels` becomes the primary script creation workbench, Instagram reel import/repurpose remains secondary, `video_script` becomes a real backend dispatch target, and generation follows the existing async pipeline model with a content record created as `in_progress` then moved to review only after the authoritative body is saved.

## User Story

En tant que créateur ContentGlowz, je veux transformer une idée ou un angle en script vidéo structuré pour Short, Reel, TikTok, YouTube Shorts ou vidéo paysage longue, afin de préparer un contenu filmable et révisable sans encore produire la vidéo finale.

## Minimal Behavior Contract

When a creator opens Reels or starts from an existing angle, ContentGlowz must present script creation as the primary action, let the creator choose a vertical short format or press a visible landscape / long-format button, validate the topic, platform, duration, and creative constraints, then start one authenticated generation job that creates a script content record as `in_progress` and moves it to review only after a readable full body is persisted. On success, the creator sees progress and can open the review/editor lifecycle for a structured script package with hook, timed script, on-screen text, visual notes, CTA, hashtags when relevant, cover concept, orientation, duration, and platform metadata. On validation, runtime, ownership, generation, body persistence, or editor loading failure, the creator gets a recoverable error and no incomplete script is presented as ready to film. The easy edge case is mixing vertical labels (`short`, `reel`, TikTok, YouTube Shorts) with the new landscape long mode: labels may differ in the UI, but saved content must be either a coherent `short` package or a coherent `video_script` package, never a rendered video or an article fallback.

## Success Behavior

- Given a creator opens `/reels`, when the page renders, then the primary surface is a script creation workbench and the existing Instagram reel import/download flow is visually secondary under "Repurpose existing reel".
- Given the creator keeps the default vertical mode, when they select TikTok, Instagram Reels, YouTube Shorts, Short, or Reel, then the request uses backend `target_format=short`, saved `content_type=short`, and metadata includes `script_mode=vertical_short`, `orientation=portrait`, `platform`, and `duration_seconds`.
- Given the creator presses the landscape / long-format button, when the form switches modes, then the UI labels the mode as script for landscape long video, the request uses backend `target_format=video_script`, saved `content_type=video_script`, and metadata includes `script_mode=landscape_long`, `orientation=landscape`, `platform=general_video`, and `duration_seconds`.
- Given an existing angle is selected in Angles, when the creator chooses "Create video script", then the app stores a Reels draft in Riverpod state and opens `/reels` with the angle title, hook, angle, pain point, confidence, creator voice, and active project context without dispatching an article pipeline.
- Given the creator starts blank, when they enter a topic and required constraints, then the workbench creates an angle-like request payload from the topic and selected settings without requiring an existing angle.
- Given the form is valid and the creator submits, when backend AI runtime preflight succeeds, then the backend creates one content record owned by the current user/project with status `in_progress`, starts one background job, and returns `task_id`, `content_record_id`, `format`, and `status=running`.
- Given generation succeeds, when the job completes, then the backend normalizes the script package, saves a human-readable full body through content body versioning, updates metadata with structured script fields, transitions the content record to `pending_review`, and returns job result metadata sufficient for the app to refresh the review queue.
- Given the completed script appears in the review queue, when the creator opens the editor, then the editor loads the latest full body through `contentDetailProvider` and shows video metadata without falling back to `content_preview`.
- Given a landscape long script has no hashtags or short cover text, when it is displayed, then those fields are absent or labeled optional and the body remains readable, not padded with invented values.
- Given a script is approved with no video publishing channel configured, when approval completes, then only the content review state changes and the UI does not claim that an MP4, Reel, TikTok, YouTube video, or social upload was produced.

## Error Behavior

- If the creator submits an empty topic and no source angle is loaded, block generation client-side and show a field-level validation message; no backend request is sent.
- If mode, target format, platform, orientation, or duration is outside the server allowlist, reject the request before content record creation and keep the form editable with the allowed range visible.
- If a user double-submits while a request is running, the UI keeps the submit action disabled for that local request and the backend duplicate-title check prevents a second equivalent content record for the same user/project/title before an AI call.
- If BYOK/OpenRouter or platform runtime entitlement is missing, return the existing AI runtime error envelope, route the creator to Settings, and do not create a partial content record.
- If the active project id is missing or not owned by the caller, backend ownership checks reject the request and no cross-project script body or metadata is returned.
- If `dispatch-pipeline` receives unsupported `target_format=video_script` on an older backend, the app shows "Content generation route unavailable on this backend" and keeps the request editable.
- If `ShortContentCrew` returns malformed JSON or missing fields, the backend normalizes to a safe script package, persists the raw text as a readable script body, marks optional metadata absent, and does not invent generated values.
- If body persistence fails after the content record is created, the backend transitions the content record to `failed` or leaves it non-reviewable, the job result reports failure, and the review queue must not show the item as ready to approve.
- If metadata update fails after the body is saved, the body remains authoritative; the UI may show reduced metadata, but editor/publish flows still use the saved full body.
- If polling fails or the app is refreshed while the job is running, the creator can recover through the review queue/history once the backend transitions the record; polling must not trigger another AI generation.
- If the existing Instagram reel import flow fails because `instagrapi`, Bunny, cookies, or remote media are unavailable, the script creation form remains usable because the two flows do not share execution or validation state.
- If external video publishing accounts are unavailable, approving a script does not trigger external video posting and does not imply a rendered media asset exists.

## Problem

ContentGlowz already has useful building blocks for script-first video preparation: `ShortContentCrew`, the async `dispatch-pipeline`, content types for `video_script`, `short`, and `reel`, body versioning, review queue cards, and the universal editor. The pieces are not assembled into a clear "build me a script I can film" flow. The current `/reels` page is an Instagram reel download/audio extraction tool, while the Flutter service currently maps `video_script` angles to the article pipeline. This creates product and data-contract confusion: creators need a script workbench, but the app either shows an import tool or risks generating article content for a video-script request.

## Solution

Turn `/reels` into a script-first workbench with import/repurpose as a secondary panel. The workbench supports two modes: vertical short-form scripts through backend `target_format=short`, and a visible landscape / long-format mode through a new backend `target_format=video_script`. Both modes use the existing authenticated async dispatch model: create an `in_progress` content record, generate one normalized script package, save a readable full body, update metadata, then transition to review.

## Scope In

- `/reels` becomes the primary Flutter workbench for video script creation.
- The existing Instagram reel download/import flow remains available on `/reels` as a secondary "Repurpose existing reel" section.
- A visible mode control/button switches between vertical short mode and landscape / long-format mode.
- Vertical mode supports TikTok, Instagram Reels, YouTube Shorts, Short, and Reel labels while dispatching as backend `target_format=short`.
- Landscape / long-format mode dispatches as backend `target_format=video_script`, saves `content_type=video_script`, and uses `orientation=landscape`.
- Source modes: selected angle from Angles, blank topic, and template/default values where the existing app already exposes them.
- A Riverpod draft handoff state lets Angles seed `/reels` with selected angle context and the correct initial mode.
- Form controls: topic or source angle, mode, platform, duration, tone, audience, CTA intent, filming style, and visual constraints.
- Backend request fields for `target_format`, `script_mode`, `platform`, `orientation`, `duration_seconds`, `topic`, angle data, creator voice, project id, CTA intent, filming style, and visual constraints.
- Server-side allowlists and bounds for target format, mode, platform, orientation, duration, topic length, and creative constraint lengths.
- Backend `video_script` support in `PipelineDispatchRequest`, `_FORMAT_MAP`, `_PIPELINE_ACTOR_MAP`, `_DISPATCH_ROUTE_BY_FORMAT`, provider requirements, and pipeline execution.
- Script package normalization for complete JSON and raw-text fallback.
- Human-readable body formatting for body versioning and editor use.
- Metadata mapping into `ContentItem.metadata` and compact feed/editor display.
- Review queue integration through existing content body versioning and status lifecycle.
- Tests for form validation, request mapping, backend format validation, body formatting, metadata parsing, editor load, malformed generation fallback, and old-backend unsupported format handling.
- EN/FR localization strings for the workbench, validation messages, landscape / long-format button, and honest no-video copy.

## Scope Out

- No video rendering, Remotion-style composition, FFmpeg montage, template-based video generation, MP4 export, or binary media output.
- No timeline editor, trimming, scene drag-and-drop, caption burn-in, audio mixing, voice cloning, voiceover generation, automatic subtitles, or teleprompter.
- No real upload to TikTok, Instagram, YouTube, LATE, or any social video channel as a video asset.
- No transcription of existing Instagram reels into scripts.
- No rights management for third-party reel reuse.
- No new CDN storage, binary upload, video asset table, or capture asset upload contract.
- No replacement of the generic editor with a specialized rich document model.
- No new rich text package; scripts remain plain text or Markdown-compatible bodies.
- No article fallback for `video_script`; if `video_script` is unavailable, the app shows a route/backend compatibility error.
- No account-level AI quota system beyond existing runtime preflight, duplicate-title protection, input bounds, and no-retry behavior.

## Constraints

- Preserve the full-body invariant: generated script bodies must be loaded from the authoritative body endpoint before editing or publishing.
- Keep the canonical saved body plain text or Markdown-compatible text; structured fields live in metadata as display and filtering aids.
- Do not persist raw malformed LLM JSON as the default user-facing body when a normalized readable script body can be constructed.
- Use existing Riverpod providers and `ApiService`; widgets must not perform direct HTTP calls.
- Use existing `require_current_user`, AI runtime preflight, content ownership, project ownership, job ownership, and body endpoint boundaries.
- Reject unsupported target formats, modes, platforms, orientations, and duration ranges server-side before content record creation.
- Do not log full prompts, generated scripts, user keys, cookies, private project context, or body text in diagnostics, job errors, or exception paths.
- Keep external publish online-only and do not add media side effects.
- Keep labels honest: "script", "shot notes", "cover concept", "landscape script", not "generated video" or "published video".
- Fresh external docs verdict: `fresh-docs not needed` for this spec because the implementation uses existing local Flutter, Riverpod, GoRouter, Dio, FastAPI, CrewAI, AI runtime, and status-service integration points without adding a new SDK, platform API, rendering engine, storage provider, social publishing API, or migration framework.

## Dependencies

- App files:
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/app_shell.dart`
  - `app/lib/presentation/screens/reels/reels_screen.dart`
  - `app/lib/presentation/screens/angles/angles_screen.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/presentation/screens/feed/content_card.dart`
  - `app/lib/data/models/content_item.dart`
  - `app/lib/data/models/ritual.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/l10n/app_localizations.dart`
- Backend files:
  - `lab/api/routers/psychology.py`
  - `lab/api/models/psychology.py`
  - `lab/agents/short/short_crew.py`
  - `lab/agents/short/prompts/short_form_writer.yaml`
  - `lab/api/services/template_defaults.py`
  - `lab/status/service.py`
- Existing specs:
  - `shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md`
  - `shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md`
  - `shipglows_data/workflow/specs/app/SPEC-content-editor-multiformat.md`
  - `shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md`
  - `shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md`
- Test areas:
  - `app/test/data/content_item_test.dart`
  - `app/test/presentation/screens/editor/editor_screen_test.dart`
  - new app tests under `app/test/presentation/screens/reels/`
  - new or existing app service tests for `ApiService.dispatchPipeline`
  - `lab/tests/test_dispatch_pipeline_runtime.py`
  - `lab/tests/test_ai_runtime_service.py`
  - new backend tests for `target_format=short` and `target_format=video_script`

## Invariants

- A script package is content, not media.
- Review-ready means the script body was persisted and can be loaded through the body endpoint.
- `content_preview` remains display-only and cannot become the editable or publishable script body.
- `short` and `video_script` are distinct backend target formats; `video_script` must not route to the article pipeline.
- UI labels for TikTok, Reels, YouTube Shorts, Short, and Reel may map to backend `short`, but landscape / long-format maps to backend `video_script`.
- No UI action in this chantier creates, uploads, stores, or publishes an MP4.
- User-owned project and auth context remain mandatory for generated content records.
- Generated metadata is helpful but non-authoritative compared with the saved body.
- Malformed LLM output must degrade to recoverable readable script text, not broken UI, raw JSON as the default body, or silent data loss.
- Polling a job never triggers another AI generation.

## Links & Consequences

- Product: ContentGlowz gains a concrete "prepare a video script" workflow before true video generation exists.
- Navigation: `/reels` remains the route, but its primary label/copy becomes script creation; import/repurpose is secondary and clearly separate.
- App shell: the Reels menu item can remain, but screen header and onboarding/help copy must clarify "scripts for vertical and landscape video".
- Angles: `video_script`, `short`, and `reel` angles must open or seed the `/reels` workbench and must not dispatch `video_script` as `article`.
- Data: no database migration is expected because content records, body versions, status transitions, and metadata JSON already exist.
- Backend: `dispatch-pipeline` gains a real `video_script` route and package metadata handling.
- AI runtime: both `short` and `video_script` require OpenRouter via existing runtime preflight; no hidden env fallback.
- Editor: video scripts continue using the universal editor, but script-specific metadata chips must not corrupt JSON-like outputs or hide the authoritative body.
- Feed cards: script metadata must be compact and must not overflow mobile approve/reject/edit actions.
- Reels downloader: existing Bunny/Instagram import flow remains separate; failures in that flow must not disable script creation.
- Analytics: if content creation tracking exists, preserve or emit `content_type=short` or `content_type=video_script` and metadata `script_mode`.
- Accessibility: mode button, form controls, validation messages, progress state, and secondary import panel need labels and keyboard-friendly progression.
- Security: prompt input, angle context, creator voice, and generated body are user/private content; do not log them, expose them across users, or rely on UI-only validation.

## Documentation Coherence

- Update `app/README.md` if app feature docs list creator tools or content formats.
- Update `app/CHANGELOG.md` after implementation ships.
- Update `shipglows_data/product/app/product.md` because product positioning expands from content review/prep to explicit video script preparation.
- Update `shipglows_data/technical/app/context-function-tree.md` because the file exists and this feature changes route/provider behavior.
- Update `site` marketing copy only after the workbench is implemented and verified; do not claim real video generation.
- Update localization strings for all new workbench labels, validation messages, progress states, landscape / long-format button, and no-video copy.

## Edge Cases

- Existing angle has `content_type=video_script`; the app must seed landscape / long-format mode and backend `target_format=video_script`, not article.
- Existing angle has `content_type=reel`; the app must seed vertical mode and backend `target_format=short`.
- User presses the landscape / long-format button after entering vertical settings; the UI must preserve compatible topic/tone/CTA fields and reset incompatible platform/duration values to long-format bounds.
- User chooses YouTube Shorts with duration above 60 seconds; the app blocks submission and backend rejects any bypassed request.
- User chooses landscape long format with a duration below 60 seconds or above 600 seconds; the app blocks submission and backend rejects any bypassed request.
- Short crew returns valid script text but invalid JSON wrapper.
- Generated `hashtags` are a list in one path and a platform-keyed map in another path.
- `on_screen_text` is too long for compact cards.
- General landscape video script has no hashtags or cover concept.
- Creator edits body manually and metadata becomes stale.
- Save body succeeds but metadata update fails.
- Backend creates a content record but body save fails.
- User opens editor directly after generation while the pending list is stale.
- BYOK mode has no usable model key.
- Platform runtime mode is not entitled for the user.
- User is offline after submitting; existing online generation cannot be queued as a completed generation, and the app must show recoverable backend/offline state instead of fabricating a script.
- Project switch happens while a generation request is in flight; the completed content remains scoped to the project id submitted to the backend.
- Reels downloader dependency is unavailable because `instagrapi` is isolated; script workbench must remain usable.

## Implementation Tasks

- [ ] Task 1: Update Reels navigation and screen contract.
  - File: `app/lib/presentation/screens/reels/reels_screen.dart`
  - Action: Make script creation the primary `/reels` surface, move the current Instagram URL download UI into a secondary "Repurpose existing reel" section, and add a visible mode button for vertical short versus landscape / long format.
  - User story link: Gives creators one obvious place to create scripts and an explicit button for long landscape scripts without promising rendered video.
  - Depends on: None.
  - Validate with: widget test proving script creation renders before import/repurpose and the mode button changes labels/allowed duration.
  - Notes: Keep the existing `downloadReel` call only inside the secondary import panel.

- [ ] Task 2: Define app-side script request and metadata helpers.
  - File: `app/lib/data/models/content_item.dart`
  - Action: Add or refine typed helpers for `script_mode`, `orientation`, `platform`, `duration_seconds`, `hook`, `on_screen_text`, `visual_notes`, `cta`, `hashtags`, and `thumbnail_concept`; parse absent optional fields safely for both `short` and `video_script`.
  - User story link: Keeps generated script packages recognizable in review and editor surfaces.
  - Depends on: Task 1.
  - Validate with: unit tests for vertical short metadata, landscape long metadata, missing optional fields, malformed hashtag shapes, and stale metadata after body edits.
  - Notes: The saved body remains authoritative; metadata is for display, filtering, and diagnostics.

- [ ] Task 3: Extend app service dispatch payload for script modes.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add a script generation method or extend `dispatchPipeline` so selected angle and blank-topic requests can send `target_format=short` or `target_format=video_script` plus `script_mode`, `platform`, `orientation`, `duration_seconds`, topic, tone, audience, CTA intent, filming style, visual constraints, creator voice, and project id.
  - User story link: Connects both vertical and landscape script modes to real backend generation.
  - Depends on: Task 2.
  - Validate with: app service tests for vertical short, landscape `video_script`, missing OpenRouter key, duplicate conflict, unsupported format, and backend route unavailable responses.
  - Notes: Remove the current `video_script -> article` mapping for script creation paths.

- [ ] Task 4: Add backend request fields and validation.
  - File: `lab/api/models/psychology.py`
  - Action: Extend `PipelineDispatchRequest` with typed optional fields for script mode, platform, orientation, duration, topic, CTA intent, filming style, and visual constraints; document accepted target formats as `article`, `newsletter`, `short`, `video_script`, and `social_post`.
  - User story link: Makes the API contract explicit enough for app and backend to agree on vertical versus landscape scripts.
  - Depends on: Task 3.
  - Validate with: Pydantic/model tests or router tests covering accepted and rejected modes/platforms/durations.
  - Notes: Keep backward compatibility for existing article/newsletter/social calls.

- [ ] Task 5: Implement backend `video_script` dispatch.
  - File: `lab/api/routers/psychology.py`
  - Action: Add `video_script` to `_FORMAT_MAP`, `_PIPELINE_ACTOR_MAP`, `_DISPATCH_ROUTE_BY_FORMAT`, provider requirements, validation, content record metadata, and `_run_pipeline_task`; route `video_script` to script-package generation, save body before `pending_review`, and leave failed records non-reviewable.
  - User story link: Prevents landscape long scripts from falling into the article pipeline.
  - Depends on: Task 4.
  - Validate with: backend tests for `target_format=video_script`, `target_format=short`, unsupported format rejection, failed body save, and no duplicate content records from nested crews.
  - Notes: Validate project/user scope and reject invalid request fields before creating the content record.

- [ ] Task 6: Normalize script packages and readable body formatting.
  - File: `lab/agents/short/short_crew.py`
  - Action: Normalize both vertical and landscape script outputs into a predictable dict, add exact `general_video` landscape-long constraints, format a Markdown-compatible body, and preserve raw text safely when JSON parsing fails.
  - User story link: Ensures creators receive a filmable script body even when model output shape varies.
  - Depends on: Task 5.
  - Validate with: unit tests or focused agent tests for parsed JSON, raw-text fallback, missing optional fields, vertical duration constraints, and landscape duration constraints.
  - Notes: Avoid logging full prompts or generated scripts in exception paths.

- [ ] Task 7: Add Reels draft handoff state.
  - File: `app/lib/providers/providers.dart`
  - Action: Add a Riverpod state holder for pending Reels draft input containing source angle fields, initial script mode, active project id, and creator voice snapshot reference; expose clear and consume semantics so stale angle context cannot leak into a later blank-topic request.
  - User story link: Lets a creator start from a validated angle and arrive in the script workbench with the correct context.
  - Depends on: Tasks 1 and 3.
  - Validate with: provider test proving set, consume, clear, and project-switch clearing behavior.
  - Notes: Keep the draft local to app state; do not persist it as content until backend dispatch starts.

- [ ] Task 8: Integrate Angles with the Reels workbench.
  - File: `app/lib/presentation/screens/angles/angles_screen.dart`
  - Action: Replace direct `video_script` article dispatch behavior with a "Create video script" path that writes the selected angle into the Reels draft provider and navigates to `/reels`; use vertical mode for `short`/`reel` and landscape long mode for `video_script`.
  - User story link: Lets users turn validated ideas into scripts quickly without generating articles by mistake.
  - Depends on: Task 7.
  - Validate with: widget/provider test proving angle title, hook, content type, pain point, confidence, and project context reach the workbench request.
  - Notes: Preserve existing article, newsletter, and social dispatch behavior.

- [ ] Task 9: Show script progress and completed review entry.
  - File: `app/lib/presentation/screens/reels/reels_screen.dart`
  - Action: Show submit loading, running job state, backend error state, completed state, and a clear action to refresh/open the review item after `pending_review`; polling must use `getPipelineStatus` and must not re-submit generation.
  - User story link: Makes async creation observable and recoverable.
  - Depends on: Tasks 3 and 5.
  - Validate with: widget tests for running, completed, failed, route-unavailable, missing-key, and duplicate-conflict states.
  - Notes: The completed preview is a persisted script summary, not a pre-save accept step.

- [ ] Task 10: Improve script cards and editor metadata display.
  - File: `app/lib/presentation/screens/feed/content_card.dart`
  - Action: Show compact script metadata on review cards: script mode, platform, duration, hook or first line, and a safe hashtag summary without overflowing compact/mobile layouts.
  - User story link: Makes generated script packages recognizable in the review queue.
  - Depends on: Task 2.
  - Validate with: content card widget tests for `short`, `reel`, and `video_script` on mobile-width constraints.
  - Notes: Do not display long `on_screen_text` arrays directly on cards.

- [ ] Task 11: Preserve editor and publish behavior for scripts.
  - File: `app/lib/presentation/screens/editor/editor_screen.dart`
  - Action: Ensure the universal editor opens script bodies from `contentDetailProvider`, displays script metadata chips, saves full body versions, and does not expose unsupported video rendering or video publishing actions.
  - User story link: Keeps creator review/control before any future filming or publishing step.
  - Depends on: Tasks 2 and 10.
  - Validate with: editor widget tests for vertical short and landscape long script items with persisted body and metadata.
  - Notes: Teleprompter, scene timeline, and video asset controls stay out of scope.

- [ ] Task 12: Add localization and docs updates.
  - File: `app/lib/l10n/app_localizations.dart`
  - Action: Add EN/FR labels for script workbench, mode button, landscape / long format, validation messages, running/completed/error states, no-video copy, and secondary import/repurpose labels.
  - User story link: Makes the script flow understandable and honest in the product language.
  - Depends on: UI copy from Tasks 1, 9, 10, and 11.
  - Validate with: widget tests finding labels/tooltips and manual EN/FR spot check.
  - Notes: Update README, changelog, and product docs in the same implementation slice when user-facing behavior ships.

## Acceptance Criteria

- [ ] CA 1: Given a creator opens `/reels`, when the page renders, then script creation is the primary surface and no UI text claims that a video file will be generated.
- [ ] CA 2: Given the creator opens `/reels`, when they look for import/download, then the Instagram reel flow is visible only as a secondary "Repurpose existing reel" section.
- [ ] CA 3: Given vertical mode is selected, when the creator chooses TikTok, Instagram Reels, YouTube Shorts, Short, or Reel and submits valid inputs, then the app sends `target_format=short` with portrait metadata.
- [ ] CA 4: Given the creator presses the landscape / long-format button, when they submit valid inputs, then the app sends `target_format=video_script` with `script_mode=landscape_long` and `orientation=landscape`.
- [ ] CA 5: Given a selected angle has `content_type=video_script`, when the creator chooses "Create video script", then the workbench opens in landscape / long-format mode and does not dispatch an article job.
- [ ] CA 6: Given a selected angle has `content_type=short` or `reel`, when the creator chooses "Create video script", then the workbench opens in vertical mode and uses backend `target_format=short`.
- [ ] CA 7: Given a blank topic is submitted with no source angle, when the topic field is empty, then generation is blocked with a field-level validation message and no backend request is sent.
- [ ] CA 8: Given a duration exceeds the selected platform or landscape-long bounds, when the creator submits, then the app shows the allowed range and backend validation rejects any bypassed request before content record creation.
- [ ] CA 9: Given the backend accepts a valid script request, when dispatch starts, then exactly one user/project-owned content record exists with status `in_progress` and one owned background job is created.
- [ ] CA 10: Given generation succeeds, when the job completes, then the content record has a saved full body, script metadata, status `pending_review`, and the review queue can refresh to show it.
- [ ] CA 11: Given the short crew returns raw non-JSON text, when dispatch completes, then the system preserves it as a readable script body and marks missing optional metadata as absent.
- [ ] CA 12: Given body persistence fails, when generation otherwise produced text, then the content record is not shown as review-ready and the job reports a recoverable failure.
- [ ] CA 13: Given another user's content id, project id, or job id is supplied, when detail, body, or job endpoints are called, then backend ownership checks block access and cached script content is not shown.
- [ ] CA 14: Given a script card appears in the feed, when displayed on mobile, then mode/platform/duration/hook metadata does not overflow or hide approve/reject/edit actions.
- [ ] CA 15: Given a user approves a script with no video publishing channel, when approval completes, then the result is content-state approval only and no external video upload is attempted.
- [ ] CA 16: Given BYOK/OpenRouter runtime is missing, when the creator submits, then the app shows the existing settings-oriented runtime error and no partial content record is created.
- [ ] CA 17: Given the backend does not yet support `video_script`, when the creator submits landscape / long format, then the app shows the route-unavailable/backend compatibility message and keeps the form state.

## Test Strategy

- Unit test `ContentItem` metadata parsing for vertical `short`, `reel` label compatibility, and landscape `video_script`.
- Unit test script body formatter with complete package, missing optional fields, malformed hashtags, raw fallback, and landscape long script text.
- App service tests for `target_format=short`, `target_format=video_script`, validation failure, backend route unavailable, missing OpenRouter key, duplicate conflict, and malformed response.
- Backend router/model tests for `dispatch-pipeline` with `target_format=short`, `target_format=video_script`, invalid target format, invalid platform, invalid duration, duplicate title conflict, and missing runtime credential.
- Backend tests proving `create_content_record=False` remains used in dispatch-owned `ShortContentCrew` calls and prevents duplicate records.
- Widget tests for `/reels` primary script layout, secondary import panel, landscape mode button, form validation, form state preservation after error, running/completed/failed job states, and no-video wording.
- Widget tests for feed cards and editor metadata chips with compact script metadata.
- Manual QA on mobile and desktop widths for `/reels`, review queue cards, editor, and EN/FR copy.
- Regression check that article, newsletter, and social dispatch from Angles still uses their existing target formats.

## Risks

- Product confusion: users may still interpret "Reels" as video rendering. Mitigation: make script creation primary, import secondary, and add explicit no-video copy.
- Contract drift: app and backend can disagree on `video_script`. Mitigation: add backend model fields, remove Flutter `video_script -> article` mapping, and test both target formats.
- AI cost abuse: repeated generation can create unnecessary provider calls. Mitigation: client submit lock, server-side allowlists/bounds, runtime preflight before creation, duplicate-title conflict before AI call, no polling-triggered generation, and no automatic retry loop.
- Data drift: metadata may not match edited body after manual edits. Mitigation: body remains authoritative and metadata is treated as display aid.
- LLM shape instability: generated output may not be valid JSON. Mitigation: normalization and raw-text fallback.
- Backend duplication: nested crew status writes can create duplicate records. Mitigation: keep dispatch-owned persistence and test one content record per request.
- Security/privacy: prompts may include private project context. Mitigation: do not log full prompts, scripts, user keys, cookies, project context, or body text.
- Scope creep into video creation. Mitigation: explicit Scope Out and no media storage/rendering tasks.

## Execution Notes

- Read first: `app/lib/presentation/screens/reels/reels_screen.dart`, `app/lib/data/services/api_service.dart`, `lab/api/routers/psychology.py`, `lab/api/models/psychology.py`, and `lab/agents/short/short_crew.py`.
- Implement foundations before UI polish: backend request contract, backend format routing/validation, package normalization/body formatting, app service payload, then `/reels` workbench state.
- Use existing Flutter/Riverpod/Dio/FastAPI/status-service patterns; avoid new packages.
- Do not touch binary upload, CDN storage, Instagram cookies, FFmpeg, native capture code, LATE publishing, or video asset tables for script creation.
- Validation bounds for V1: vertical platforms use existing `ShortContentCrew.PLATFORM_CONSTRAINTS`; landscape long format uses `platform=general_video`, `orientation=landscape`, and duration range 60-600 seconds.
- Backend must validate unsupported target formats, platform values, orientation values, and duration before creating a content record.
- Backend must run AI runtime preflight before content record creation so missing BYOK/platform entitlement does not leave partial records.
- Stop and reroute to a new spec if the work requires MP4 rendering, transcription of third-party reels, social video upload, teleprompter mode, account-level AI quotas, or a dedicated document editor model.
- Validation commands: targeted `flutter test` under `app` and focused `pytest` tests under `lab`.
- Turso migration expected: no, because the intended implementation uses existing content records, body versions, status transitions, and metadata JSON. Re-evaluate only if metadata cannot fit the existing status model.
- Fresh external docs verdict: `fresh-docs not needed`; local code and existing specs define the relevant Flutter/FastAPI/CrewAI integration behavior for this change.

## Open Questions

- None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-10 22:48:42 UTC | sf-spec | GPT-5 Codex | Created the script-first video workbench spec from repo investigation and user clarification. | Draft spec saved. | /sf-ready video script creation workbench |
| 2026-05-11 05:26:00 UTC | sf-ready | GPT-5 Codex | Evaluated readiness before `/sf-start`. | Not ready: route/format contract, generation preview versus persistence flow, security abuse bounds, and dependency metadata need spec decisions. | /sf-spec Video Script Creation Workbench |
| 2026-05-11 06:15:00 UTC | sf-spec | GPT-5 Codex | Updated the spec with locked decisions for `/reels`, true `video_script`, direct async persistence, landscape long mode, and security bounds. | Draft spec updated for readiness re-check. | /sf-ready Video Script Creation Workbench |

## Current Chantier Flow

- sf-spec: updated on 2026-05-11 with route, backend format, persistence, landscape mode, security, dependency, and language-doctrine decisions.
- sf-ready: previous run was not ready; next gate should re-check this updated draft.
- sf-start: blocked until `/sf-ready` passes.
- sf-verify: not launched.
- sf-end: not launched.
- sf-ship: not launched.

Next command: `/sf-ready Video Script Creation Workbench`.
