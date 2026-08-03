---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "app"
created: "2026-05-08"
created_at: "2026-05-08 09:22:48 UTC"
updated: "2026-05-08"
updated_at: "2026-05-08 09:22:48 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "En tant que createur ContentGlowz sur Android qui enregistre tout son ecran pour publier des videos en ligne, je veux activer un mode confidentialite qui rend les textes illisibles et floute ou pixelise les photos tout en gardant l'interface comprehensible, afin de reduire les fuites d'informations sans produire une video inutilisable."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter capture UI"
  - "app Android native Kotlin MediaProjection"
  - "app Android foreground capture services"
  - "app local capture metadata store"
  - "app capture/content asset metadata"
  - "Android MediaProjection"
  - "Android MediaCodec/MediaMuxer"
  - "Google ML Kit Text Recognition and Face Detection"
  - "AndroidX Media3 Transformer"
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
  - artifact: "shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md"
    artifact_version: "1.0.0"
    required_status: "active"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md"
    artifact_version: "0.1.0"
    required_status: "shipped_pending_manual_qa"
  - artifact: "shipglows_data/workflow/explorations/2026-05-06-screen-text-obfuscation.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/research/shared/android-privacy-screen-redaction-technologies.md"
    artifact_version: "unknown"
    required_status: "reviewed"
supersedes: []
evidence:
  - "User clarified that the target is arbitrary Android whole-screen capture: messaging apps, browser, and third-party apps, not only ContentGlowz screens."
  - "User prioritized visually pleasant public videos over large static masks, accepting best-effort dynamic blur/scramble plus post-production review."
  - "app currently records video through ScreenRecordService using MediaProjection -> VirtualDisplay -> MediaRecorder surface, which does not expose a per-frame edit step."
  - "app currently captures screenshots through ImageReader, which can be extended for privacy screenshot redaction."
  - "shipglows_data/workflow/research/shared/android-privacy-screen-redaction-technologies.md recommends ML Kit Text Recognition v2, ML Kit Face Detection, MediaCodec/MediaMuxer, Media3 Transformer, and avoids FFmpegKit."
  - "Android official docs require user consent per MediaProjection session and foreground service declarations for Android 14+."
  - "Google Play AccessibilityService policy requires prominent disclosure, affirmative consent, and declaration/review if accessibility APIs are used."
next_step: "/sf-ready android privacy capture dynamic redaction"
---

# Title

Android Privacy Capture Dynamic Redaction

## Status

Draft spec for an Android-only privacy capture mode. This chantier adds best-effort dynamic redaction to the existing Android capture feature: text regions are blurred, pixelated, or visually replaced with scrambled fake glyphs; photos/faces are blurred or pixelated; the final local asset is marked as `privacy_best_effort` and must pass a post-production review acknowledgement before normal share/export. V1 does not promise perfect anonymization and does not use an AccessibilityService. Accessibility-assisted third-party app bounds are explicitly deferred to a V2 spike.

## User Story

En tant que createur ContentGlowz sur Android qui enregistre tout son ecran pour publier des videos en ligne, je veux activer un mode confidentialite qui rend les textes illisibles et floute ou pixelise les photos tout en gardant l'interface comprehensible, afin de reduire les fuites d'informations sans produire une video inutilisable.

## Minimal Behavior Contract

When an Android user enables privacy mode from Capture and starts a screenshot or recording, ContentGlowz must show an explicit best-effort disclosure, request Android MediaProjection consent, process captured screen pixels through a redaction pipeline, save only a privacy-marked local PNG/MP4 asset for normal preview/share flows, and require post-production review acknowledgement before sharing; if consent is denied, redaction dependencies fail, the device cannot keep up, or Android stops the projection, the app must stop cleanly, avoid exposing a clear asset through normal UI, delete or quarantine temporary clear files, and explain that the capture was not safely finalized. The easy edge case is fast scrolling: OCR will miss frames unless detected regions persist across time with expanded margins and motion-aware smoothing.

## Success Behavior

- Given an Android user opens Capture, when they enable privacy mode, then the UI shows privacy controls for text style, photo style, redaction strength, and a disclosure that the result is best-effort and requires manual review.
- Given privacy mode is enabled, when the user starts a screenshot and grants MediaProjection consent, then ContentGlowz captures the screen, detects likely text/photo/face regions, applies the selected redaction style, stores a local PNG whose metadata says `privacyMode=true` and `reviewState=needsReview`, and never adds the clear screenshot to recent captures.
- Given privacy mode is enabled, when the user starts a recording and grants MediaProjection consent, then ContentGlowz captures video frames, tracks text regions through scroll/motion, applies blur/pixelation/scramble overlays before producing the final MP4, stores a local MP4 whose metadata says `privacyMode=true` and `reviewState=needsReview`, and never exposes a clear MP4 through preview/share.
- Given the user chooses text style `scramble`, when text regions are detected, then real text pixels are covered and replaced visually with fake glyphs or line fragments that preserve layout without storing recognized text.
- Given the user chooses text style `blur` or `pixelate`, when text regions are detected, then the selected effect is applied with enough expansion around each region to cover ascenders, descenders, antialiasing, and scroll jitter.
- Given photo redaction is enabled, when image-like regions or faces are detected, then ContentGlowz applies the selected photo redaction effect without masking the entire screen by default.
- Given the user scrolls a messaging app or browser during recording, when OCR detects text on nearby frames, then redaction boxes remain active for a short temporal window and move/expand conservatively so text does not flash clear between OCR runs.
- Given a privacy-marked asset exists, when the user taps share/export before review acknowledgement, then ContentGlowz shows a review confirmation explaining that anonymization is best-effort and the user is responsible for checking the final video before upload.
- Given the user acknowledges review, when they share/export a privacy-marked asset, then only the redacted flattened PNG/MP4 is shared through Android intents.
- Given privacy mode is off, when the user records normally, then the existing capture path and behavior remain unchanged.

## Error Behavior

- If the user declines the privacy disclosure, do not start MediaProjection and leave Capture idle with an explanatory state.
- If the user denies MediaProjection consent, do not create an asset and show the existing declined capture state.
- If ML Kit text recognition is unavailable or fails to initialize, block privacy mode recording by default and explain that privacy capture cannot start safely; do not silently fall back to unredacted capture.
- If face/photo redaction fails but text redaction is available, allow the user to continue only if photo redaction was disabled or after an explicit warning that photo redaction is unavailable for this session.
- If the frame processing pipeline falls behind during recording, apply more conservative region persistence/expansion and surface a recoverable notice; if output cannot be kept coherent, stop and mark the attempt failed rather than saving a misleading "privacy" asset.
- If Android stops projection through the status bar chip, lock screen, another projection, or process pressure, release MediaProjection, ImageReader/SurfaceTexture, MediaCodec, MediaMuxer, and temporary files; emit a native event that lets Flutter return to a recoverable state.
- If a temporary clear file or frame buffer is required internally, it must remain app-private, be marked temporary, never appear in recent captures, never be shareable, and be deleted on success or failure when possible.
- If deletion of a temporary clear file fails, quarantine it outside normal capture history, show a local cleanup warning, and avoid any share/export path that could select it.
- If a privacy-marked asset is linked to content, backend metadata may record privacy status and redaction settings, but must not store recognized text, OCR output, frame thumbnails, or local clear paths.
- If the user tries to use privacy mode on non-Android platforms, show unsupported behavior and do not expose partial settings.

## Problem

Creators want to record real Android workflows across messaging apps, browsers, system screens, and third-party apps for public internet videos. Raw screen recordings can include private messages, names, URLs, photos, avatars, payment details, tokens, and notifications. Large static masks protect privacy but make the video unattractive and hard to understand. Character scrambling cannot directly rewrite third-party app UIs because MediaProjection captures rendered pixels, not semantic text. The product needs a best-effort privacy mode that preserves the visual flow while reducing readable sensitive content and forcing a post-production review gate.

## Solution

Add an Android-only privacy capture mode that uses a separate native capture pipeline for privacy sessions. The normal `MediaRecorder` path stays available for standard capture, while privacy sessions route frames through ML Kit detection, temporal tracking, GPU/effect rendering, and MediaCodec/MediaMuxer output so the saved user-facing asset is a flattened redacted PNG/MP4. Flutter owns the mode controls, disclosure/acknowledgement UI, local metadata, review state, and share gating.

## Scope In

- Android-only privacy mode toggle in the existing Capture screen.
- Explicit best-effort disclosure before the first privacy capture and per-session review acknowledgement before share/export.
- Text redaction styles: `scramble`, `blur`, and `pixelate`.
- Photo redaction styles: `off`, `blur`, and `pixelate`.
- Face redaction toggle or inclusion in photo redaction when ML Kit Face Detection is available.
- Redaction strength control with at least `balanced` and `strong`; default to `balanced` for visual quality and allow `strong` for higher-risk sessions.
- Native privacy screenshot path that redacts the bitmap before saving PNG.
- Native privacy recording path that processes frames before producing the final MP4, using MediaProjection plus a non-`MediaRecorder` processing/encoding pipeline.
- ML Kit Text Recognition v2 for text-region detection.
- ML Kit Face Detection for face boxes where feasible.
- Temporal tracker for scroll/motion: box persistence, expansion margins, and conservative fallback during high motion.
- Privacy metadata on `CaptureAsset` and backend asset metadata payloads: privacy mode, redaction status, text style, photo style, strength, review state, and processing stats.
- Local-only storage behavior consistent with the existing capture feature.
- Tests for Dart model/service/UI contracts and native contract sanity where feasible.
- Manual Android QA for browser, Google Messages or another messaging app, scrolling, screenshot, recording, review, and share gating.

## Scope Out

- Perfect anonymization guarantee or numeric reliability claim such as "70% safe".
- Direct Google Messages plugin or any third-party app UI rewrite.
- V1 AccessibilityService implementation.
- iOS ReplayKit, web/desktop capture, or non-Android parity.
- Cloud upload, cloud redaction, backend storage of video bytes, CDN, retention policy, or server-side transcoding.
- Storing recognized text, OCR transcripts, frame images, thumbnails, or clear local paths in backend metadata.
- Full video editor timeline, manual frame-by-frame editor, captions, trimming, publishing automation, or YouTube upload.
- Custom OCR model training in V1.
- FFmpegKit dependency.

## Constraints

- MediaProjection consent remains mandatory for each screenshot/recording session; Android 14+ single-use token rules still apply.
- Privacy recording must not use the current direct `MediaRecorder` output path as the final privacy asset because it bypasses per-frame redaction.
- The final shareable file must be flattened raster video/image output; it must not include editable redaction layers, OCR text, source frames, or unblurred auxiliary tracks.
- ML Kit recognized text content must be discarded immediately after deriving bounds; only region geometry and aggregate stats may be stored.
- The UI must state "best-effort", "non exhaustive", and "manual review required"; it must not state that ContentGlowz is fully responsible for every leak or that the output is guaranteed safe.
- Legal copy must be product-safe but implementation should leave final liability wording reviewable; do not hard-code aggressive legal claims that need counsel.
- Privacy mode must preserve normal capture mode behavior.
- Use app-scoped storage for outputs and temporary files.
- Use native Kotlin/Android for frame processing and encoding; Flutter controls settings and receives typed events.
- On Linux ARM64 local dev, do not require release APK/AAB builds; route real-device/release validation to appropriate Android CI/device environment.

## Dependencies

Local dependencies and contracts:

- `app/lib/presentation/screens/capture/capture_screen.dart`: add privacy controls, disclosure, review gating, and asset review state UI.
- `app/lib/data/services/device_capture_service.dart`: extend platform-channel contract to pass privacy options and parse privacy events/assets.
- `app/lib/data/models/capture_asset.dart`: extend local asset metadata for privacy/redaction status.
- `app/lib/data/services/capture_local_store.dart`: persist new metadata only; no binary data.
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenCaptureChannel.kt`: route normal vs privacy operations and expose typed native errors/events.
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenRecordService.kt`: keep normal recording unchanged; do not overload it with privacy behavior if a separate service keeps lifecycle clearer.
- New native privacy classes under `app/android/app/src/main/kotlin/com/contentglowz/app/capture/privacy/`.
- `app/android/app/build.gradle.kts`: add Android native dependencies for ML Kit and Media3 if used.
- `app/android/app/src/main/AndroidManifest.xml`: update only if new service metadata is required; do not add AccessibilityService in V1.
- `app/lib/data/services/api_service.dart`: include privacy metadata in capture asset/content metadata payloads without backend schema changes.

Fresh external docs verdict: `fresh-docs checked` on 2026-05-08.

- Android MediaProjection docs: `https://developer.android.google.cn/media/grow/media-projection`
  - Confirms foreground service requirements, per-session consent, single-use token behavior, app-window/full-display behavior, and callback expectations.
- Android MediaCodec API: `https://developer.android.com/reference/android/media/MediaCodec`
  - Confirms encoder input `Surface` via `createInputSurface()` and hardware-accelerated rendering requirement.
- Android MediaMuxer API: `https://developer.android.com/reference/android/media/MediaMuxer`
  - Confirms MP4 muxing of encoded streams.
- Google ML Kit Text Recognition v2: `https://developers.google.com/ml-kit/vision/text-recognition/v2/android`
  - Confirms `TextRecognizer`, multiple script libraries, `InputImage` sources, and text detection pipeline.
- Google ML Kit Face Detection: `https://developers.google.com/ml-kit/vision/face-detection/android`
  - Confirms face detection for images/video, bounding coordinates, FAST mode, and real-time performance guidance.
- AndroidX Media3 Transformer: `https://developer.android.google.cn/media/media3/transformer`
  - Confirms post-processing/transcoding, custom effects, MediaCodec-backed encode/decode, and OpenGL graphical modifications.
- Google Play AccessibilityService policy: `https://support.google.com/googleplay/android-developer/answer/10964491`
  - Confirms prominent disclosure, affirmative consent, and Play declaration requirements if V2 uses accessibility APIs.

## Invariants

- Normal capture mode remains available and unchanged unless privacy mode is explicitly enabled.
- Privacy mode is best-effort and must be labeled as such.
- A privacy-marked asset must never be represented as fully anonymized or guaranteed safe.
- A privacy-marked asset must require review acknowledgement before share/export.
- Clear temporary media must never appear in local capture history.
- Recognized text content must never be persisted, logged, sent to backend, or included in asset metadata.
- Backend metadata may contain redaction settings and aggregate stats only.
- Capture and redaction must remain local-first; no cloud processing in this chantier.
- Protected-content black frames or omitted content remain platform behavior, not a ContentGlowz bug.

## Links & Consequences

- Product: Capture evolves from "local screen capture" to "creator-safe public-video preparation"; onboarding/copy must clarify best-effort limits.
- Privacy/security: this feature touches extremely sensitive screen contents; data minimization and temporary-file cleanup are mandatory.
- Performance: privacy recording adds OCR, detection, rendering, and encoding load; it may need lower analysis resolution, throttled OCR, and fallback stop behavior on low-end devices.
- UX: redaction must preserve visual comprehension, so dynamic selective redaction is preferred over whole-screen masks.
- Backend: no schema migration required if privacy metadata is kept inside existing `metadata` JSON; backend must not receive OCR text or local paths.
- App store policy: AccessibilityService is out of V1; any V2 spike must include Play policy review before implementation.
- QA: real-device Android validation is required; widget/unit tests cannot prove frame-level redaction quality.

## Documentation Coherence

- Update `app/README.md` with privacy capture scope, Android-only status, best-effort limitation, post-production review requirement, and no cloud upload behavior.
- Update `shipglows_data/technical/app/guidelines.md` with privacy capture data-minimization rules: no OCR text persistence, no clear temp file exposure, review-gated share.
- Update `app/CHANGELOG.md` after implementation.
- Update `shipglows_data/product/app/product.md` only if the feature ships publicly and changes product positioning.
- Do not update `.env.example` in V1 unless implementation introduces a configurable build/runtime flag.
- Do not update `site` marketing copy until QA proves the feature is usable and wording is legally safe.

## Edge Cases

- Fast vertical scroll in a messaging app where text appears for only a few frames.
- Horizontal carousel, tab transition, or animation moving text across the screen.
- Small text in browser address bars, email lists, tables, code snippets, or status bars.
- White text on colored images, translucent overlays, or video backgrounds.
- Emojis, non-Latin scripts, mixed scripts, stylized fonts, or all-caps UI.
- Text embedded inside photos or screenshots inside the captured app.
- Face/photo region partly visible during scroll.
- Device rotates during privacy recording.
- Android 14+ user selects app-window capture instead of full display.
- ML Kit model unavailable, slow to load, or returns no results.
- MediaCodec encoder fails after recording has started.
- MediaMuxer cannot finalize MP4 after partial output.
- User stops projection from Android status bar chip.
- App process dies while temporary clear files exist.
- User attempts to share an asset before review acknowledgement.
- User links a privacy-marked asset to content while backend is offline.

## Implementation Tasks

- [ ] Task 1: Add privacy capture settings and asset metadata models.
  - File: `app/lib/data/models/capture_asset.dart`
  - Action: Add enums/fields for `privacyMode`, `redactionStatus`, `textRedactionStyle`, `photoRedactionStyle`, `redactionStrength`, `reviewState`, and optional aggregate stats such as detected text region count; keep backwards-compatible JSON parsing defaults for old assets.
  - User story link: Lets the app distinguish normal captures from best-effort privacy captures and gate share/export.
  - Depends on: None.
  - Validate with: `flutter test test/data/capture_asset_test.dart`.
  - Notes: Do not store recognized text, frame thumbnails, or clear temp paths.

- [ ] Task 2: Extend the Flutter capture service contract for privacy options.
  - File: `app/lib/data/services/device_capture_service.dart`
  - Action: Add typed privacy options to screenshot/recording calls or add explicit `takePrivacyScreenshot` and `startPrivacyRecording` methods; parse new native event fields and privacy failure codes.
  - User story link: Lets Flutter request privacy capture without overloading normal capture semantics invisibly.
  - Depends on: Task 1.
  - Validate with: Dart unit tests using fake `MethodChannel` where feasible.
  - Notes: Keep normal method behavior compatible for existing tests and callers.

- [ ] Task 3: Add privacy mode controls and disclosure UI.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Add a privacy mode toggle, text redaction style control (`scramble`, `blur`, `pixelate`), photo redaction style control (`off`, `blur`, `pixelate`), strength control (`balanced`, `strong`), and a first-run/session disclosure requiring affirmative acknowledgement before starting privacy capture.
  - User story link: Gives creators control over visual style while making best-effort limits explicit.
  - Depends on: Task 2.
  - Validate with: `flutter test test/presentation/screens/capture/capture_screen_test.dart`.
  - Notes: Prefer concise in-context UI and dialogs over long legal blocks; wording must say manual review is required.

- [ ] Task 4: Gate share/export for privacy-marked assets.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: When a privacy asset has `reviewState=needsReview`, require a review acknowledgement before calling `shareAsset`; after acknowledgement, persist `reviewState=reviewed` locally.
  - User story link: Ensures post-production review is part of the user flow before internet upload.
  - Depends on: Tasks 1 and 3.
  - Validate with: widget test for share blocked until acknowledgement.
  - Notes: This is a product safety gate, not a legal guarantee.

- [ ] Task 5: Persist privacy review state locally.
  - File: `app/lib/data/services/capture_local_store.dart`
  - Action: Add a method to update an asset's review state/metadata without rewriting binary files, preserving recent capture ordering and content links.
  - User story link: Lets users review once and share later without losing the privacy status.
  - Depends on: Task 1.
  - Validate with: `flutter test test/data/capture_local_store_test.dart`.
  - Notes: Continue storing metadata only in SharedPreferences.

- [ ] Task 6: Add Android dependencies for privacy redaction.
  - File: `app/android/app/build.gradle.kts`
  - Action: Add ML Kit Text Recognition v2 Latin bundled dependency, ML Kit Face Detection dependency, and Media3 Transformer/effect dependencies if used for post-processing; avoid FFmpegKit.
  - User story link: Provides the native detection/effect foundation.
  - Depends on: None.
  - Validate with: Gradle sync or targeted Android debug build on x64/CI/device.
  - Notes: If local `flutter.minSdkVersion` is below dependency requirements, gate privacy mode on Android API support or explicitly bump minSdk in a separate readiness decision.

- [ ] Task 7: Create native privacy option and event data classes.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/privacy/PrivacyCaptureOptions.kt`
  - Action: Define Kotlin representations for privacy options, redaction styles, strength, review/status metadata, processing stats, and typed error codes from platform-channel arguments.
  - User story link: Keeps platform-channel parsing out of the low-level rendering pipeline.
  - Depends on: Task 2.
  - Validate with: Kotlin compile.
  - Notes: Keep option names aligned with Dart enums.

- [ ] Task 8: Route privacy requests through a separate native path.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenCaptureChannel.kt`
  - Action: Parse privacy options, request MediaProjection exactly like normal capture, and start privacy screenshot/recording classes instead of `ScreenShotService`/`ScreenRecordService` when privacy mode is enabled.
  - User story link: Lets privacy mode use a redaction pipeline without disturbing normal recording.
  - Depends on: Tasks 7 and existing capture consent flow.
  - Validate with: Kotlin compile and manual consent smoke.
  - Notes: Keep Android 14 single-use token behavior intact.

- [ ] Task 9: Implement privacy screenshot redaction.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/privacy/PrivacyScreenshotCapture.kt`
  - Action: Capture one frame through ImageReader, run text/face/photo detection on the bitmap, apply selected effects, save only the redacted PNG, and return privacy metadata.
  - User story link: Provides best-effort privacy for still captures.
  - Depends on: Tasks 6-8.
  - Validate with: real-device screenshot smoke and Kotlin compile.
  - Notes: This is the lowest-risk native redaction path and should be implemented before video.

- [ ] Task 10: Implement frame analysis service.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/privacy/PrivacyFrameAnalyzer.kt`
  - Action: Run ML Kit Text Recognition at a throttled cadence, run face detection when enabled, derive redaction boxes, discard recognized text content immediately, and emit only boxes/stats.
  - User story link: Finds sensitive regions while preserving user privacy and avoiding OCR text persistence.
  - Depends on: Task 6.
  - Validate with: Kotlin compile and a small analyzer smoke using static bitmap fixtures if feasible.
  - Notes: Use lower analysis resolution where needed; map boxes back to output coordinates.

- [ ] Task 11: Implement temporal redaction tracking for scroll.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/privacy/PrivacyRedactionTracker.kt`
  - Action: Persist detected boxes across a configurable frame/time window, expand margins, merge overlapping boxes, and apply conservative behavior during high motion or dropped OCR frames.
  - User story link: Prevents clear-text flashes during scroll while keeping the video visually pleasant.
  - Depends on: Task 10.
  - Validate with: JVM/Kotlin unit tests for box merge, expiry, margin expansion, and motion persistence if test harness exists; otherwise static helper tests.
  - Notes: This task is critical for the user's stated scroll concern.

- [ ] Task 12: Implement visual redaction renderer.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/privacy/PrivacyRedactionRenderer.kt`
  - Action: Render redaction effects over detected boxes: blur, pixelate, and fake scrambled glyph/line overlays; preserve surrounding UI layout and avoid large full-screen masks by default.
  - User story link: Produces internet-friendly videos where viewers understand the flow but cannot read sensitive text.
  - Depends on: Tasks 10 and 11.
  - Validate with: real-device visual smoke and static screenshot before/after comparison.
  - Notes: If full GPU blur is too heavy, V1 may approximate blur/pixelation with downscale/upscale regions or opaque/fake glyph overlays, but the output must be visibly unreadable.

- [ ] Task 13: Implement privacy recording encode pipeline.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/privacy/PrivacyScreenRecordService.kt`
  - Action: Build a foreground service that captures MediaProjection frames through a processable surface path, applies analyzer/tracker/renderer output, writes final video through MediaCodec input Surface and MediaMuxer MP4, enforces the existing duration cap, and emits progress/stats events.
  - User story link: Delivers dynamic best-effort privacy for whole-screen recordings.
  - Depends on: Tasks 8, 10, 11, and 12.
  - Validate with: Android real-device recording smoke; Kotlin compile; projection stop smoke.
  - Notes: This is the highest-risk implementation task. If a temporary clear buffer/file is technically unavoidable, keep it app-private, non-shareable, and deleted/quarantined before asset registration.

- [ ] Task 14: Add privacy metadata to capture/content backend payloads.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Extend capture metadata helper payloads to include privacy/redaction status and settings when linking or creating content from captures; never include OCR text or local clear paths.
  - User story link: Preserves privacy status when captures become content assets.
  - Depends on: Task 1.
  - Validate with: existing API parsing tests or targeted unit test.
  - Notes: No backend schema migration expected because metadata JSON already exists.

- [ ] Task 15: Add tests for privacy capture contracts.
  - File: `app/test/data/capture_asset_test.dart`, `app/test/data/capture_local_store_test.dart`, `app/test/presentation/screens/capture/capture_screen_test.dart`
  - Action: Cover backwards-compatible parsing, privacy settings serialization, review state updates, disclosure UI, share gating, and normal capture unaffected behavior.
  - User story link: Prevents regressions in user-visible privacy flow and metadata state.
  - Depends on: Tasks 1-5.
  - Validate with: targeted Flutter tests.
  - Notes: Native frame quality still requires manual/device validation.

- [ ] Task 16: Update docs and changelog.
  - File: `app/README.md`, `shipglows_data/technical/app/guidelines.md`, `app/CHANGELOG.md`
  - Action: Document Android-only privacy mode, best-effort limits, post-production review, local-only processing, dependencies, and no guarantee/no cloud upload behavior.
  - User story link: Aligns user/operator expectations with the feature's real guarantees.
  - Depends on: Tasks 1-15.
  - Validate with: docs review.
  - Notes: Avoid public marketing claims until manual QA validates quality.

## Acceptance Criteria

- [ ] CA 1: Given an Android user opens Capture, when privacy mode is toggled on, then privacy controls and a best-effort disclosure are visible before capture starts.
- [ ] CA 2: Given privacy mode is enabled and the user declines the disclosure, when they tap record or screenshot, then MediaProjection is not requested and no asset is created.
- [ ] CA 3: Given privacy mode is enabled and disclosure is accepted, when the user takes a screenshot, then the saved PNG is redacted, privacy-marked, and added to recent captures only after redaction succeeds.
- [ ] CA 4: Given privacy mode is enabled and disclosure is accepted, when the user records the screen, then the saved MP4 is redacted, privacy-marked, and added to recent captures only after redaction/encoding finalizes.
- [ ] CA 5: Given text style is `scramble`, when text is detected, then real text pixels are covered and fake glyphs/lines are rendered without storing recognized text.
- [ ] CA 6: Given text style is `blur`, when text is detected, then the detected region plus margin is blurred strongly enough to be unreadable in the output preview.
- [ ] CA 7: Given text style is `pixelate`, when text is detected, then the detected region plus margin is mosaicked strongly enough to be unreadable in the output preview.
- [ ] CA 8: Given a messaging app or browser scrolls during privacy recording, when text regions move quickly, then redaction persists across adjacent frames and no obvious clear-text flashes appear in manual review.
- [ ] CA 9: Given photo redaction is enabled, when faces or image-like regions are detected, then the selected photo effect is applied while preserving the surrounding app layout.
- [ ] CA 10: Given ML Kit text recognition cannot initialize, when privacy capture is requested, then the app blocks privacy capture and does not silently record clear output.
- [ ] CA 11: Given a privacy asset has `reviewState=needsReview`, when the user taps Share, then ContentGlowz requires review acknowledgement before invoking Android share.
- [ ] CA 12: Given the user confirms review, when Share is retried, then Android share receives only the redacted flattened PNG/MP4 path.
- [ ] CA 13: Given a privacy capture fails mid-session, when the app returns to idle, then no clear output is listed in recent captures and any temp file is deleted or quarantined.
- [ ] CA 14: Given privacy mode is off, when the user records normally, then existing normal capture tests and behavior still pass.
- [ ] CA 15: Given a privacy capture is linked to content, when metadata is sent to the backend, then privacy settings/status are included but OCR text, frame images, and local clear paths are absent.

## Test Strategy

- Dart unit tests:
  - `capture_asset_test.dart` for backwards-compatible metadata parsing and privacy fields.
  - `capture_local_store_test.dart` for review state persistence and local metadata only.
  - targeted `api_service` test for privacy metadata payloads if existing API test patterns support it.
- Flutter widget tests:
  - Capture screen privacy controls visible only on supported Android capture state.
  - Disclosure blocks capture until accepted.
  - Share/export gate blocks `needsReview` privacy assets until acknowledgement.
  - Normal capture controls remain usable when privacy mode is off.
- Kotlin/native checks:
  - Kotlin compile for new capture privacy classes.
  - Unit tests for redaction box merge/expiry/margin math where feasible.
  - Static screenshot analyzer smoke if fixture setup is practical.
- Manual Android QA:
  - Screenshot privacy capture on Android device.
  - Recording privacy capture on Android device.
  - Fast scroll in browser.
  - Fast scroll in Google Messages or another installed messaging app.
  - Photo/face redaction smoke with gallery/browser/social feed content.
  - Stop projection via Android status chip.
  - Lock screen during privacy recording.
  - Share gate and review acknowledgement.
  - Confirm no clear temp asset appears in ContentGlowz recent captures.
- Validation commands:
  - `flutter test test/data/capture_asset_test.dart test/data/capture_local_store_test.dart test/presentation/screens/capture/capture_screen_test.dart`
  - `flutter analyze`
  - Android debug build or CI build on a supported x64/Android environment.

## Risks

- High implementation complexity: live privacy recording needs a separate frame-processing/encoding pipeline instead of the existing direct MediaRecorder path.
- Redaction miss risk: OCR may miss small, stylized, moving, low-contrast, or non-Latin text.
- Weak-redaction risk: visually pleasant blur can still be inferable if too light.
- Performance risk: OCR, tracking, effects, and encoding may overload low-end devices.
- Temp-file risk: any clear intermediate file is sensitive and must be deleted/quarantined.
- Policy risk: future AccessibilityService work requires Play policy review and cannot be casually added.
- Trust risk: legal/disclosure wording must be honest without overpromising.
- QA risk: automated tests cannot prove real-world privacy quality; manual video review is mandatory.

## Execution Notes

Read first:

- `app/lib/data/services/device_capture_service.dart`
- `app/lib/presentation/screens/capture/capture_screen.dart`
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenCaptureChannel.kt`
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenRecordService.kt`
- `shipglows_data/workflow/research/shared/android-privacy-screen-redaction-technologies.md`

Implementation approach:

1. Add Dart metadata/settings and UI/share gating first; keep normal capture tests green.
2. Add Android dependencies and Kotlin option/event types.
3. Implement privacy screenshot before privacy recording.
4. Build analyzer/tracker/renderer pieces with small tests or static smokes.
5. Implement privacy recording service last, because it carries the highest native lifecycle risk.
6. Run Flutter checks, Kotlin/Android compile, then real-device QA.

Constraints for implementers:

- Do not add FFmpegKit.
- Do not add AccessibilityService in V1.
- Do not store OCR text anywhere.
- Do not expose clear temporary files to Flutter/local history/share.
- Do not change backend schema unless implementation proves metadata JSON is insufficient.
- Stop and rescope if MediaCodec/GPU pipeline cannot produce usable output without clear asset exposure.

Fresh external docs: `fresh-docs checked` on 2026-05-08 through official Android, Google ML Kit, Media3, and Google Play policy docs.

## Open Questions

- None blocking for V1. Product decisions fixed for this draft:
  - Android only.
  - Dynamic selective redaction over large static masks.
  - Best-effort language, no percentage guarantee.
  - Post-production review gate required before share/export.
  - AccessibilityService postponed to V2/spike.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-08 09:22:48 UTC | sf-spec | GPT-5 Codex | Created Android privacy capture dynamic redaction spec from exploration and research. | draft saved | /sf-ready android privacy capture dynamic redaction |

## Current Chantier Flow

sf-spec ✅ -> sf-ready not launched -> sf-start not launched -> sf-verify not launched -> sf-end not launched -> sf-ship not launched
