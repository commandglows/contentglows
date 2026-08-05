---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "app"
created: "2026-05-08"
created_at: "2026-05-08 10:08:12 UTC"
updated: "2026-05-08"
updated_at: "2026-05-08 10:08:12 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "As a ContentGlows creator reviewing a privacy capture before publishing or sharing it, I want to inspect the redacted output, add extra redaction where needed, and acknowledge the remaining risk, so that only a reviewed flattened privacy asset can leave the app."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter capture UI"
  - "app CaptureAsset metadata"
  - "app CaptureLocalStore"
  - "app DeviceCaptureClient contract"
  - "app capture preview components"
  - "app share/export/content attachment actions"
  - "app ApiService capture metadata payloads"
  - "Android privacy capture dynamic redaction"
  - "Web privacy capture dynamic redaction"
  - "Windows privacy capture dynamic redaction"
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/flutter-app-shell-and-capture.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md"
    artifact_version: "0.1.0"
    required_status: "shipped_pending_manual_qa"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-web-privacy-capture-dynamic-redaction.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-windows-privacy-capture-dynamic-redaction.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/explorations/2026-05-06-screen-text-obfuscation.md"
    artifact_version: "1.0.0"
    required_status: "draft"
supersedes: []
evidence:
  - "User requested a P1/reflection spec for post-production review after privacy capture, covering redacted preview, zoom/frame sampling, manual correction overlays, no-clear compare policy, acknowledgement, export/share gating, flattened output, local-only metadata, failure states, and no-guarantee copy."
  - "Android, web, and Windows privacy capture specs already require privacy-marked assets with post-production review acknowledgement before share/export."
  - "shipglows_data/workflow/explorations/2026-05-06-screen-text-obfuscation.md warns that post-production alone is not a high-confidentiality boundary, but is accepted as a final safety net and review workflow."
  - "app/lib/data/models/capture_asset.dart currently has no privacy review state, correction revision, or acknowledgement metadata."
  - "app/lib/data/services/capture_local_store.dart persists recent capture metadata and content links in SharedPreferences."
  - "app/lib/presentation/screens/capture/capture_screen.dart currently calls share/create/attach actions directly from capture cards."
  - "app/lib/data/services/api_service.dart currently sends minimal capture asset metadata and does not include privacy review status."
next_step: "/sf-ready privacy capture post-production review"
---

# Title

Privacy Capture Post-Production Review

## Status

Draft spec for a cross-platform privacy-capture review flow. This chantier defines the shared UX, data, copy, gating, and failure contract that Android, web, Windows, and future platform privacy capture implementations must satisfy after they produce a privacy-marked redacted asset.

This spec is not a native implementation spec. It does not choose OCR, capture, encoding, WebCodecs, MediaProjection, Windows.Graphics.Capture, or platform renderer details. Platform-specific specs own how redacted media and flattened corrected output are produced. This spec owns what the user can inspect, correct, acknowledge, share, export, or attach after a privacy capture exists.

## User Story

As a ContentGlows creator reviewing a privacy capture before publishing or sharing it, I want to inspect the redacted output, add extra redaction where needed, and acknowledge the remaining risk, so that only a reviewed flattened privacy asset can leave the app.

## Minimal Behavior Contract

When ContentGlows has a privacy-marked capture asset, the app must route share, export, download, and content-attachment attempts through a post-production review flow that shows only the redacted output, supports zooming and video frame sampling, lets the user add manual redaction overlays, flattens any corrections into a new redacted output, and requires an explicit best-effort acknowledgement before the asset can leave the app; if preview, sampling, correction, flattening, cleanup, or metadata persistence fails, the app must keep the asset blocked from share/export, explain the recoverable state, and never expose a clear original or clear comparison view. The easy edge case is a tempting before/after compare: review may compare redacted draft versus corrected redacted output, but must never show a clear source frame, thumbnail, or replay as the baseline.

## Success Behavior

- Given a privacy-marked capture appears in local captures, when its `reviewState` is `needsReview`, then the card shows a review-required state and share/export/content-attachment actions route to the review flow instead of leaving the app.
- Given the user opens review for a screenshot, when the preview loads, then the app displays the redacted screenshot only, supports fit-to-screen, zoom, and pan, and never offers a reveal-original action.
- Given the user opens review for a recording, when playback loads, then the app displays the redacted video only, supports playback/scrub controls, and presents sampled redacted frames to help inspect risky moments.
- Given a recording has processing stats or detected-risk timestamps from the platform pipeline, when frame samples are generated, then the sampler prioritizes start/end frames, regular interval frames, and platform-reported risky frames without claiming the sample set is exhaustive.
- Given a recording has no usable risk timestamps, when frame samples are generated, then the app still provides deterministic interval samples and labels sampling as an inspection aid, not a safety proof.
- Given the user zooms or samples frames, when the UI changes view state, then it does not create shareable thumbnails, clear frame exports, or backend metadata containing frame images.
- Given the user sees a missed sensitive area, when they draw a manual correction overlay, then the overlay can only add more redaction and cannot remove or weaken existing redaction.
- Given the user adds a manual correction on a screenshot, when they apply it, then the app creates or requests a flattened redacted screenshot output and keeps the asset blocked until flattening succeeds.
- Given the user adds a manual correction on a recording, when they choose its temporal scope, then the UI requires an explicit frame/time range and keeps the asset blocked until a flattened redacted video output succeeds.
- Given correction flattening succeeds, when the corrected output is registered, then the current shareable asset path points to the flattened corrected redacted media or a clearly tracked flattened revision, not to editable overlay instructions.
- Given the user wants to compare results, when compare mode is available, then it may compare current redacted draft with corrected redacted output only; it must not request, decode, render, or expose a clear source asset.
- Given no manual correction is needed, when the user completes review, then the app still requires explicit acknowledgement that redaction is best-effort, non exhaustive, and manually reviewed.
- Given acknowledgement succeeds, when the asset metadata is persisted, then `reviewState` becomes `reviewed`, `reviewedAt` is set locally, the reviewed revision is recorded, and share/export/content attachment gates can pass.
- Given a reviewed privacy asset is shared or attached to content, when payload metadata is prepared, then it includes only privacy status/settings/review summary fields that are safe for backend metadata and excludes clear paths, OCR text, frame images, and manual overlay geometry unless a later reviewed backend contract explicitly allows it.
- Given privacy mode is not enabled for an asset, when the user shares or attaches it, then existing normal capture behavior remains unchanged.

## Error Behavior

- If a privacy-marked asset has no valid redacted media path, show "redacted file unavailable" behavior, keep share/export/content attachment blocked, and do not fall back to a clear original.
- If preview decoding fails for the redacted asset, block acknowledgement and export until the user can retry, discard, or regenerate the redacted asset through the platform-specific flow.
- If video frame sampling fails but full redacted playback works, allow review to continue with a visible degraded notice and require the acknowledgement copy to mention that frame samples were unavailable.
- If neither playback nor sampling works for a recording, keep the asset in `reviewFailed` or `needsReview` and block share/export/content attachment.
- If manual overlay drawing state cannot be saved locally, do not let the user apply a correction that could be lost silently; keep the asset blocked and explain the local persistence failure.
- If flattening a manual correction fails, keep the last known redacted draft but mark the review as `correctionFailed` or `needsReview`; do not allow the asset to be acknowledged as reviewed until the corrected flattened output succeeds or the user explicitly discards the correction.
- If a correction is discarded, reset the review state to the last flattened redacted revision and require acknowledgement again before sharing.
- If a stale acknowledgement exists for an older redaction revision, when a new correction, reprocessing result, or asset replacement occurs, invalidate the acknowledgement and return the asset to `needsReview`.
- If cleanup of temporary redacted or correction files fails, show a local cleanup warning, avoid registering temporary files as shareable, and never expose clear temp files through local history.
- If a platform-specific review/flatten method reports that it would need a persistent clear intermediate, stop the review operation and route back to the platform spec/readiness decision before shipping.
- If backend linking happens while offline, preserve the local review state and local content link behavior, but do not enqueue OCR text, frame samples, overlay coordinates, clear paths, or binary media.
- If a user tries to bypass the review gate through share, export, download, create-content, attach-content, or any future publish shortcut, the same blocking policy must apply.

## Problem

Privacy capture redaction is best-effort. OCR, visual detection, motion tracking, and platform capture pipelines can miss text or sensitive imagery. The Android, web, and Windows privacy specs all require a post-production review acknowledgement, but the current app has only normal local capture preview/share/attach behavior. Without a shared review contract, each platform implementation could accidentally diverge: one path might allow share before review, another might offer a clear original comparison, another might persist sensitive overlay or frame metadata, and another might mark a video safe after inspecting only a few samples.

The product needs a single cross-platform review flow that keeps the user-facing promise honest: inspect the redacted result, correct missed regions when possible, acknowledge the remaining risk, and only then allow flattened redacted output to leave the app.

## Solution

Add a shared privacy-capture review contract around `CaptureAsset` state, local review metadata, Capture UI actions, preview/review UI, correction overlay commands, platform flattening hooks, and share/export/content attachment gates. The review flow always operates on redacted media and local-only review metadata. It can add redaction but never reveal or compare against clear source pixels. Platform capture specs remain responsible for producing initial redacted assets and applying/flattening corrections into final media.

## Scope In

- Cross-platform review state model for privacy-marked capture assets.
- Capture card states for `needsReview`, `inReview`, `correctionPending`, `correctionFailed`, `reviewed`, and unsupported/degraded review states.
- Redacted-only preview for privacy screenshots and recordings.
- Screenshot zoom and pan controls for inspecting redacted output.
- Video playback, scrubbing, and frame sampling controls for inspecting redacted output.
- Deterministic video frame sampling contract: start/end, interval samples, and platform-provided risky timestamps when available.
- Manual correction overlays that add more redaction on screenshots or timestamped video ranges.
- Overlay constraints: add-only redaction, no unredact, no weaken, no clear reveal, no editable layers in export.
- Flattened correction output requirement before review can be acknowledged after manual correction.
- Compare policy that permits redacted-draft versus corrected-redacted comparison only.
- Explicit review acknowledgement copy with best-effort, non-exhaustive, manual-review-required language.
- Export/share/download/content-attachment gating for privacy assets until review acknowledgement passes.
- Local-only review metadata for samples inspected, local correction drafts, acknowledgement timestamp, review revision, failure reason, and cleanup status.
- Backend metadata minimization for content-linked assets: privacy flags, review state, reviewed revision, and aggregate stats only.
- Failure states for missing media, preview decode failure, sampling failure, correction save failure, flatten failure, stale acknowledgement, cleanup warning, and unsupported platform review.
- Shared Dart tests and widget tests for review state, local store persistence, gates, copy, and normal capture regressions.
- Documentation updates for privacy review limits, no-guarantee copy, and local-only metadata rules.

## Scope Out

- Native capture or redaction implementation for Android, web, Windows, iOS, macOS, or Linux.
- OCR model selection, computer vision implementation, encoding implementation, media muxing, MediaProjection, WebCodecs, Windows.Graphics.Capture, or GPU renderer choices.
- Perfect anonymization, formal privacy certification, numeric safety score, or guarantee copy.
- Showing clear originals, clear thumbnails, clear frame samples, or unredacted source comparison.
- Cloud review, cloud OCR, cloud redaction, backend binary upload, CDN storage, or retention-policy changes.
- Storing OCR text, transcripts, semantic screen contents, frame images, clear temp paths, or clear thumbnails.
- Full video editor timeline, trimming, captions, audio editing, publishing automation, or YouTube/social upload.
- Public marketing claims before implementation QA and wording review.

## Constraints

- Review must never load, display, thumbnail, sample, or compare a clear original.
- Review must operate only on privacy-marked redacted media produced by a platform privacy capture flow.
- The final shareable/exportable output must be flattened raster media; overlays must not remain as reversible export layers.
- Manual corrections may only increase redaction and must never weaken or remove an existing redaction region.
- Acknowledgement is tied to a specific redaction revision and must be invalidated by reprocessing or corrections.
- Review metadata must stay local-first and metadata-only; it must not contain OCR text, frame images, clear paths, or clear thumbnails.
- Backend payloads may receive minimal privacy/review summary metadata only when assets are linked to content.
- Copy must state best-effort, non exhaustive, and manual review required; it must not say "safe", "guaranteed", "fully anonymized", "privacy certified", or equivalent absolute claims.
- Sampling is an inspection aid; the UI must not imply that sampled frames prove the whole recording is safe.
- Normal non-privacy capture behavior must remain unchanged.
- Platform-specific implementations must provide typed events/errors into Dart before widgets consume them.
- If the shared review gate and a platform-specific capability disagree, the stricter gate wins.

## Dependencies

Local dependencies and contracts:

- `app/lib/data/models/capture_asset.dart`: add privacy review state, redaction revision, acknowledgement, correction, sampling, and safe aggregate metadata fields.
- `app/lib/data/services/capture_local_store.dart`: persist and update local review metadata without storing binary data, OCR text, frame images, or clear paths.
- `app/lib/data/services/device_capture_service.dart`: expose typed cross-platform review/flatten capability and failure contracts while leaving native implementation to platform specs.
- `app/lib/presentation/screens/capture/capture_screen.dart`: route share/export/create/attach actions through the privacy review gate.
- `app/lib/presentation/screens/capture/capture_asset_preview.dart`, `capture_asset_preview_io.dart`, and `capture_asset_preview_stub.dart`: support redacted-only preview states and avoid clear fallback for privacy assets.
- New UI file, likely `app/lib/presentation/screens/capture/privacy_capture_review_sheet.dart`: shared review surface for redacted preview, zoom, sampling, manual corrections, compare policy, and acknowledgement.
- New policy/model files, likely `app/lib/data/models/privacy_capture_review.dart` and `app/lib/data/services/privacy_capture_review_policy.dart`: centralize gates and copy so future share/export paths cannot bypass review.
- `app/lib/data/services/api_service.dart`: include minimized privacy review metadata when linking captures to content and exclude local-only correction metadata.
- `app/test/data/capture_asset_test.dart`, `capture_local_store_test.dart`, and `test/presentation/screens/capture/capture_screen_test.dart`: extend coverage for privacy review metadata and gates.
- New review UI/policy tests under `app/test/presentation/screens/capture/` or `app/test/data/`.

Fresh external docs verdict: `fresh-docs not needed`. This spec defines a local UX/data contract and deliberately avoids platform API or SDK implementation choices. Platform-specific freshness checks remain in the Android, web, and Windows privacy capture specs.

## Invariants

- A privacy-marked asset with `reviewState != reviewed` cannot be shared, exported, downloaded, attached to content, or passed into a future publish shortcut.
- A privacy-marked asset cannot be marked `reviewed` unless a redacted preview was available and the user acknowledged the best-effort copy for the current redaction revision.
- A manual correction resets acknowledgement until the corrected flattened output is successfully registered.
- Review UI never exposes clear source media, clear thumbnails, OCR text, or clear comparison views.
- Compare mode is redacted-to-redacted only.
- Review metadata remains local-only unless it is a safe summary field explicitly allowed by the backend metadata contract.
- Final exported/shared media is flattened redacted output.
- Normal non-privacy captures do not inherit review gates.
- Platform-specific review failures must be visible and recoverable; silent failure cannot unlock sharing.

## Links & Consequences

- Product: privacy capture becomes a two-step workflow: capture/redact first, then post-production review before any external sharing.
- UX: capture cards need visible state and a primary Review action for privacy assets; share/export actions may be disabled or rerouted until review passes.
- Privacy/security: this flow reduces accidental external exposure but is not a confidentiality guarantee; no-clear compare and copy discipline are part of the security boundary.
- Data: `CaptureAsset` and local store metadata must become rich enough to represent review state without introducing sensitive persisted content.
- Backend: no schema migration is expected if minimal privacy summary fields remain inside existing metadata JSON, but payload tests must prove no OCR text, overlay geometry, clear paths, or frame images are sent.
- QA: automated tests can prove gates and metadata behavior, but manual review QA is still required for visual clarity, zoom usability, video sampling, and correction flattening.
- Documentation: README/GUIDELINES/technical docs must describe review as required, best-effort, local-first, and non-guaranteed.

## Documentation Coherence

- Update `app/README.md` with the privacy capture review workflow: redacted preview, manual corrections, acknowledgement, share/export gating, and no guarantee.
- Update `shipglows_data/technical/app/guidelines.md` with no-clear compare policy, local-only review metadata rules, and banned guarantee copy.
- Update `shipglows_data/technical/app/flutter-app-shell-and-capture.md` with the shared privacy review gate and platform-specific ownership split.
- Update `app/CHANGELOG.md` after implementation.
- Update related Android/web/Windows privacy specs only if implementation changes their assumed review state contract.
- Do not update public marketing copy until platform QA proves the flow is usable and product/legal copy is reviewed.

## Edge Cases

- Privacy asset created before this spec exists and missing review metadata.
- Privacy asset has `reviewState=reviewed` but no `reviewedRevision` or stale revision.
- User starts a correction, leaves review, and returns after app restart.
- User adds an overlay and then discards it.
- User adds an overlay on a long recording but forgets to set the time range.
- Video frame sampling misses the exact moment where sensitive text appears.
- Platform-reported risky timestamps are empty, wrong, or not sorted.
- Redacted video playback works but sample extraction fails.
- Sample extraction works but full video playback fails.
- Screenshot preview can zoom but the image file is missing after OS cleanup.
- Recording codec/container is unsupported by the preview widget on the current platform.
- User tries to share from a stale capture card while review state is updating.
- User links a `needsReview` asset to content while offline.
- Manual correction flatten succeeds but local metadata update fails.
- Local metadata update succeeds but temp cleanup fails.
- Corrected output is smaller, wrong MIME type, or points to a temp path.
- Compare mode accidentally labels one side "original" or requests a clear source.
- Assistive technology reads acknowledgement copy out of order.
- Non-privacy assets are accidentally blocked by the privacy gate.

## Implementation Tasks

- [ ] Task 1: Add shared privacy review metadata to capture assets.
  - File: `app/lib/data/models/capture_asset.dart`
  - Action: Add backwards-compatible enums/fields for privacy mode, redaction revision, review state, review acknowledgement timestamp, reviewed revision, correction state, sampled-frame summary, and safe aggregate review stats.
  - User story link: Lets the app know whether a privacy capture is blocked, under review, corrected, or reviewed.
  - Depends on: None.
  - Validate with: `flutter test test/data/capture_asset_test.dart`.
  - Notes: Do not add fields for OCR text, clear frame paths, clear thumbnails, or binary data.

- [ ] Task 2: Add local review-state persistence methods.
  - File: `app/lib/data/services/capture_local_store.dart`
  - Action: Add methods to update review state, reviewed revision, correction draft state, acknowledgement timestamp, and failure reason for an existing asset without rewriting unrelated assets or links.
  - User story link: Keeps review acknowledgement and correction state durable across app restarts.
  - Depends on: Task 1.
  - Validate with: `flutter test test/data/capture_local_store_test.dart`.
  - Notes: Review work metadata is local-only; never persist frame images or OCR text.

- [ ] Task 3: Centralize privacy review policy and copy.
  - File: `app/lib/data/services/privacy_capture_review_policy.dart`
  - Action: Create a shared policy that answers whether a capture can share/export/download/create-content/attach-content, why it is blocked, what action should open review, and what acknowledgement copy must be shown.
  - User story link: Prevents future actions from bypassing the review gate.
  - Depends on: Task 1.
  - Validate with: targeted Dart unit tests for each review state and action type.
  - Notes: Include banned guarantee-copy checks in tests or fixtures where practical.

- [ ] Task 4: Define the shared platform review/flatten contract.
  - File: `app/lib/data/services/device_capture_service.dart`
  - Action: Add typed capability/results/errors for privacy review support, redacted preview availability, frame sampling availability, correction flatten requests, and corrected asset results.
  - User story link: Lets shared Flutter UI request corrections without embedding native platform logic.
  - Depends on: Tasks 1-3.
  - Validate with: fake client tests or widget tests using a fake `DeviceCaptureClient`.
  - Notes: Do not implement Android/web/Windows native flattening in this chantier; platform specs own it.

- [ ] Task 5: Add review-gated capture actions.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Add review-required card state, Review action, and gate share/export/create-content/attach-content through the shared policy before invoking existing service/API calls.
  - User story link: Ensures a privacy asset cannot leave the app before review acknowledgement.
  - Depends on: Tasks 1-4.
  - Validate with: `flutter test test/presentation/screens/capture/capture_screen_test.dart`.
  - Notes: Normal non-privacy captures must keep existing behavior.

- [ ] Task 6: Build the shared privacy review surface.
  - File: `app/lib/presentation/screens/capture/privacy_capture_review_sheet.dart`
  - Action: Create the review UI for redacted-only preview, screenshot zoom/pan, video playback/scrubbing, sampled-frame list, degraded notices, acknowledgement, and action buttons.
  - User story link: Gives the user a concrete place to inspect the redacted output before sharing.
  - Depends on: Tasks 1-5.
  - Validate with: widget tests for screenshot review, recording review, degraded sampling, and acknowledgement.
  - Notes: Use redacted media only; no original/reveal affordance.

- [ ] Task 7: Add manual correction overlay UI and state.
  - File: `app/lib/presentation/screens/capture/privacy_capture_review_sheet.dart`, `app/lib/data/models/privacy_capture_review.dart`
  - Action: Support add-only redaction rectangles/regions for screenshots and timestamped video ranges, local correction draft state, discard correction, and apply correction requests.
  - User story link: Lets the user fix missed sensitive regions before acknowledging review.
  - Depends on: Tasks 4 and 6.
  - Validate with: widget/unit tests for add-only behavior, time-range requirement, discard, and apply states.
  - Notes: The UI stores only local correction instructions until platform flattening returns a redacted output; exports never include editable layers.

- [ ] Task 8: Enforce no-clear preview and compare behavior.
  - File: `app/lib/presentation/screens/capture/capture_asset_preview.dart`, `app/lib/presentation/screens/capture/capture_asset_preview_io.dart`, `app/lib/presentation/screens/capture/capture_asset_preview_stub.dart`
  - Action: Make privacy previews explicitly redacted-only, prevent fallback to any clear/original path, and ensure compare labels are redacted draft versus corrected redacted output only.
  - User story link: Prevents accidental clear exposure during review.
  - Depends on: Tasks 1 and 6.
  - Validate with: widget tests using privacy assets with missing/failed previews.
  - Notes: If redacted preview is unavailable, show a blocked/error preview rather than a clear fallback.

- [ ] Task 9: Minimize backend metadata for reviewed privacy assets.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Extend `_captureAssetMetadata` to include safe privacy summary fields and review state while excluding local correction drafts, overlay geometry, frame samples, OCR text, temp paths, and local file paths as durable server truth.
  - User story link: Lets content records know an asset was privacy-reviewed without leaking sensitive review data.
  - Depends on: Tasks 1-3.
  - Validate with: targeted API payload test following existing `api_service` test patterns.
  - Notes: Offline queued payloads must follow the same minimization rule.

- [ ] Task 10: Add regression tests for gates and metadata.
  - File: `app/test/data/capture_asset_test.dart`, `app/test/data/capture_local_store_test.dart`, `app/test/presentation/screens/capture/capture_screen_test.dart`
  - Action: Cover old asset parsing, privacy review states, stale revision invalidation, local persistence, share/export/content gate blocking, review acknowledgement, and normal capture unchanged behavior.
  - User story link: Makes the review contract enforceable.
  - Depends on: Tasks 1-9.
  - Validate with: targeted Flutter tests.
  - Notes: Add fake capture clients rather than platform-native test dependencies.

- [ ] Task 11: Update docs for privacy review behavior.
  - File: `app/README.md`, `shipglows_data/technical/app/guidelines.md`, `shipglows_data/technical/app/flutter-app-shell-and-capture.md`, `app/CHANGELOG.md`
  - Action: Document review-required flow, no-clear compare policy, local-only metadata, no-guarantee copy, manual correction limits, and platform-specific ownership split.
  - User story link: Aligns implementers and users around what privacy review does and does not guarantee.
  - Depends on: Tasks 1-10.
  - Validate with: docs review.
  - Notes: Avoid marketing claims until QA and wording review are complete.

## Acceptance Criteria

- [ ] CA 1: Given a privacy capture asset has `reviewState=needsReview`, when the Capture card renders, then it shows a review-required state and a primary Review action.
- [ ] CA 2: Given a privacy capture asset has `reviewState=needsReview`, when the user taps Share, Export, Create content, or Attach to content, then the app opens or prompts review instead of invoking the share/API action.
- [ ] CA 3: Given a privacy screenshot opens in review, when the preview renders, then only the redacted screenshot is visible and zoom/pan controls are available.
- [ ] CA 4: Given a privacy recording opens in review, when the preview renders, then only the redacted video is playable and redacted frame samples are available or a degraded sampling notice is shown.
- [ ] CA 5: Given a recording has platform-provided risky timestamps, when samples are generated, then those timestamps are included alongside start/end and interval samples.
- [ ] CA 6: Given frame sampling is available, when the user inspects samples, then the UI labels sampling as an aid and does not claim the whole recording is guaranteed safe.
- [ ] CA 7: Given a user enters compare mode, when the views render, then both sides are redacted outputs and no clear original/source label or path is used.
- [ ] CA 8: Given the redacted preview cannot load, when the user attempts acknowledgement, then acknowledgement is blocked and the asset remains unshareable.
- [ ] CA 9: Given the user draws a manual correction on a screenshot, when they apply it, then the asset stays blocked until a flattened corrected redacted screenshot is registered.
- [ ] CA 10: Given the user draws a manual correction on a video, when no timestamp/frame range is selected, then apply is blocked until the correction scope is explicit.
- [ ] CA 11: Given a manual correction flatten fails, when the flow returns to review, then the asset is not marked reviewed and share/export/content attachment remains blocked.
- [ ] CA 12: Given a manual correction flatten succeeds, when the corrected revision is registered, then acknowledgement is required for that corrected revision before share/export is allowed.
- [ ] CA 13: Given a reviewed privacy asset is modified or reprocessed, when its redaction revision changes, then the previous acknowledgement is invalidated and the asset returns to `needsReview`.
- [ ] CA 14: Given the user completes review without manual correction, when they acknowledge best-effort/non-exhaustive/manual-review copy, then the current redacted revision becomes shareable.
- [ ] CA 15: Given a privacy asset is reviewed, when the user shares or exports it, then only the flattened redacted asset path is passed to the platform share/export mechanism.
- [ ] CA 16: Given a reviewed privacy asset is attached to content, when the backend payload is built, then safe privacy summary metadata is included and OCR text, frame images, overlay geometry, temp paths, and clear paths are absent.
- [ ] CA 17: Given a non-privacy capture asset exists, when the user shares or attaches it, then existing non-privacy capture behavior is unchanged.
- [ ] CA 18: Given a stale or malformed privacy asset has missing review metadata, when it is loaded from local storage, then it defaults to a blocked `needsReview` or `reviewFailed` state rather than a reviewed state.

## Test Strategy

- Dart unit tests:
  - `capture_asset_test.dart` for backwards-compatible parsing, privacy review states, revision/acknowledgement behavior, and safe JSON serialization.
  - `capture_local_store_test.dart` for update methods, stale revision handling, correction draft persistence, and local-only metadata.
  - `privacy_capture_review_policy` tests for share/export/create/attach gates across every review state.
- Flutter widget tests:
  - Capture card review-required state and Review action.
  - Share/export/create/attach actions are blocked for `needsReview`, `correctionPending`, `correctionFailed`, and stale acknowledgements.
  - Review sheet loads redacted screenshot preview with zoom controls.
  - Review sheet loads redacted recording state with sample/degraded notices.
  - Manual correction add/apply/discard states.
  - Acknowledgement copy and reviewed-state transition.
  - Normal non-privacy capture flow remains unchanged.
- API payload tests:
  - `_captureAssetMetadata` includes safe privacy review summary.
  - Payloads exclude OCR text, frame images, overlay geometry, temp paths, and local clear paths.
  - Offline queued attach/create payloads follow the same minimization rule.
- Manual QA:
  - Review a privacy screenshot, zoom into small text, add correction, flatten, acknowledge, share.
  - Review a privacy recording, inspect sampled frames, scrub around a fast scroll, add timestamped correction, flatten, acknowledge, share.
  - Verify compare mode never shows a clear original.
  - Verify failed preview/sampling/flattening keeps share/export blocked.
  - Verify copy says best-effort, non exhaustive, and manual review required without guarantee language.
- Validation commands:
  - `flutter test test/data/capture_asset_test.dart test/data/capture_local_store_test.dart test/presentation/screens/capture/capture_screen_test.dart`
  - `flutter analyze`
  - Platform-specific manual QA from Android, web, or Windows privacy specs after their native flattening hooks exist.

## Risks

- User-trust risk: users may treat review acknowledgement as a guarantee unless copy and UI state are strict.
- No-clear exposure risk: implementers may add a convenient before/after comparison that leaks the clear source.
- Sampling risk: sampled frames can miss sensitive content; the UI must avoid implying exhaustive review.
- Metadata risk: overlay geometry, OCR output, or frame thumbnails could leak sensitive structure if sent to backend or logs.
- Gate drift risk: future share/export/content flows could bypass the first implementation unless policy is centralized.
- Platform contract risk: Android, web, and Windows may expose different correction/flatten capabilities; the shared UI must degrade without unlocking unsafe export.
- Performance risk: video preview, sampling, and correction overlay rendering may be slow on large recordings.
- Accessibility risk: zoom, sampling, and acknowledgement controls must remain understandable with keyboard and screen readers.
- QA risk: automated tests can prove gates but cannot prove real-world visual privacy.

## Execution Notes

Read first:

- `shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md`
- `shipglows_data/workflow/specs/app/SPEC-web-privacy-capture-dynamic-redaction.md`
- `shipglows_data/workflow/specs/app/SPEC-windows-privacy-capture-dynamic-redaction.md`
- `app/lib/data/models/capture_asset.dart`
- `app/lib/data/services/capture_local_store.dart`
- `app/lib/presentation/screens/capture/capture_screen.dart`
- `app/lib/data/services/device_capture_service.dart`
- `app/lib/data/services/api_service.dart`

Implementation approach:

1. Add metadata and local-store review state first.
2. Add the centralized gate/policy before touching UI actions.
3. Add the shared review UI with fakeable preview/correction clients.
4. Add manual correction and platform flattening contracts without native implementation.
5. Wire share/export/create/attach gates to the policy.
6. Add minimized backend metadata and tests.
7. Update docs after behavior and copy are stable.
8. Let Android, web, and Windows implementation specs provide the actual platform flattening hooks.

Constraints for implementers:

- Do not implement platform-native capture/redaction in this chantier.
- Do not expose clear originals, clear previews, clear thumbnails, or clear compare mode.
- Do not store OCR text anywhere.
- Do not send manual overlay geometry, sampled frame images, or correction drafts to the backend.
- Do not unlock share/export/content attachment after failed preview, failed flattening, or stale acknowledgement.
- Do not claim guaranteed anonymization or safety.
- Stop and rescope if the review flow requires persistent clear media to apply corrections.

Fresh external docs: `fresh-docs not needed` for this shared UX/data contract. Re-check official docs only when a platform-specific implementation changes native APIs, browser APIs, encoding, storage, or permissions.

## Open Questions

- None blocking for this draft. Product decisions fixed by the brief and related privacy specs:
  - Review is required before privacy capture share/export/content attachment.
  - Review uses redacted media only.
  - Compare is redacted-to-redacted only.
  - Manual corrections can add redaction only.
  - Corrected output must be flattened before it can be reviewed or shared.
  - Review metadata is local-only except safe backend summary fields.
  - Copy must be best-effort, non exhaustive, and no-guarantee.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-08 10:08:12 UTC | sf-spec | GPT-5 Codex | Created cross-platform post-production review flow spec for privacy captures from platform privacy specs, exploration, and local capture code anchors. | draft saved | /sf-ready privacy capture post-production review |

## Current Chantier Flow

sf-spec done -> sf-ready not launched -> sf-start not launched -> sf-verify not launched -> sf-end not launched -> sf-ship not launched
