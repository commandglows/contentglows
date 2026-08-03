---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "app"
created: "2026-05-08"
created_at: "2026-05-08 09:47:05 UTC"
updated: "2026-05-08"
updated_at: "2026-05-08 09:47:05 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "As a ContentGlowz creator on Windows desktop who records arbitrary windows or monitors for public videos, I want to enable a privacy mode that dynamically makes text unreadable and redacts sensitive visual regions while preserving workflow readability, so that I can reduce accidental data leaks before sharing without pretending the result is guaranteed safe."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter capture UI"
  - "app Flutter platform-channel service boundary"
  - "app local capture metadata store"
  - "app capture/content asset metadata"
  - "Windows desktop runner"
  - "Windows.Graphics.Capture"
  - "Direct3D/Win2D rendering pipeline"
  - "Windows.Media.Ocr"
  - "Windows.Media.Core MediaStreamSource"
  - "Windows.Media.Transcoding MediaTranscoder"
  - "Microsoft Media Foundation"
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
  - artifact: "shipglows_data/workflow/explorations/2026-05-08-windows-privacy-capture-redaction.md"
    artifact_version: "unknown"
    required_status: "draft"
supersedes: []
evidence:
  - "shipglows_data/workflow/explorations/2026-05-08-windows-privacy-capture-redaction.md found Windows.Graphics.Capture feasible for user-selected window/display capture, Win2D/Direct3D feasible for effects, Windows.Media.Ocr feasible for text boxes, and MediaStreamSource/MediaTranscoder feasible for flattened video export."
  - "app currently has Android native capture code but no app/windows runner directory, so Windows desktop capture is clean slate relative to platform-native code."
  - "app/lib/data/services/device_capture_service.dart currently reports non-Android platforms unsupported and uses typed MethodChannel/EventChannel parsing at the service/model boundary."
  - "shipglows_data/technical/app/guidelines.md requires typed native platform-channel APIs at the service/model boundary, app-scoped capture storage, metadata-only SharedPreferences persistence, and no durable backend truth based on device-local paths."
  - "The Android privacy spec establishes the product pattern for privacy-marked assets, best-effort disclosure, post-production review, and no persistence of recognized text."
next_step: "/sf-ready windows privacy capture dynamic redaction"
---

# Title

Windows Privacy Capture Dynamic Redaction

## Status

Draft spec for a Windows desktop-only privacy capture mode. The current Flutter app has no `app/windows` runner, so Windows native capture is a clean-slate platform addition that must integrate through the existing Dart capture service/model boundary. This chantier does not implement Web, iOS, Linux, or Android parity work. It defines a best-effort privacy capture path for arbitrary Windows windows or monitors, using `Windows.Graphics.Capture`, Direct3D/Win2D redaction effects, `Windows.Media.Ocr`, and a flattened local export through `MediaStreamSource`/`MediaTranscoder` or Media Foundation. The result must require user review before share/export and must never be described as guaranteed anonymization.

V1 goal: prove and ship a minimal Windows desktop path for one selected window or display, text OCR boxes, blur/pixelate/scramble rendering, flattened redacted screenshot/MP4 export, privacy metadata, temp-file controls, and review-gated share.

V2 goal: add stronger visual detection and resilience, including optional ONNX Runtime WinUI detection for faces/people/logos/screenshots-inside-screens, persistent user-defined protected regions, improved multi-monitor capture ergonomics, and adaptive confidence/fallback states.

## User Story

As a ContentGlowz creator on Windows desktop who records arbitrary windows or monitors for public videos, I want to enable a privacy mode that dynamically makes text unreadable and redacts sensitive visual regions while preserving workflow readability, so that I can reduce accidental data leaks before sharing without pretending the result is guaranteed safe.

## Minimal Behavior Contract

When a Windows desktop user enables privacy mode and starts a screenshot or recording, ContentGlowz must show an explicit best-effort disclosure, let the user select a window or monitor through Windows capture UI, process captured pixels through local redaction before registering the saved asset, store only a flattened privacy-marked PNG/MP4 for normal preview/share flows, and require review acknowledgement before share/export; if capture support, picker consent, OCR, rendering, encoding, temp cleanup, or protected-content access fails, the app must stop cleanly, avoid exposing a clear asset through normal UI, delete or quarantine clear intermediates, and explain that the privacy capture was not safely finalized. The easy edge case is a mixed-DPI multi-monitor setup: capture coordinates, OCR boxes, redaction boxes, and encoded output dimensions can drift unless all transforms are normalized and tested across monitor scale factors.

## Success Behavior

- Given a Windows desktop user opens Capture, when Windows capture support is available, then the app exposes Windows privacy capture controls without enabling the Android-only path.
- Given privacy mode is enabled, when the user starts capture, then the app shows a best-effort disclosure that says manual review is required and no guarantee is provided.
- Given the user accepts the disclosure, when they start a screenshot or recording, then Windows system UI lets them select a single window or display through `GraphicsCapturePicker`.
- Given the user selects a capturable window or display, when capture begins, then ContentGlowz receives frames from `Direct3D11CaptureFramePool` and processes them locally before any user-facing asset is registered.
- Given text appears in captured content, when OCR runs, then detected word/line geometry is converted to output-space redaction boxes and recognized text content is discarded immediately.
- Given text redaction style is `blur`, `pixelate`, or `scramble`, when text boxes are active, then the corresponding Win2D/Direct3D effect covers the real pixels with expanded margins so the final output is unreadable in review.
- Given visual redaction is enabled in V1, when the app can identify conservative image-like regions through heuristics, then those regions can be blurred or pixelated without masking the full screen by default.
- Given a privacy screenshot succeeds, when the asset appears in local captures, then it is a flattened PNG with privacy metadata and `reviewState=needsReview`.
- Given a privacy recording succeeds, when the asset appears in local captures, then it is a flattened MP4 whose frames already include redaction and whose metadata includes processing stats and `reviewState=needsReview`.
- Given a privacy-marked asset has `reviewState=needsReview`, when the user tries to share/export or link it into normal content flows, then ContentGlowz requires review acknowledgement first.
- Given the user acknowledges review, when share/export continues, then only the flattened redacted PNG/MP4 path is passed to the OS share/export mechanism.
- Given privacy mode is off, when a platform supports normal capture, then existing non-privacy capture behavior and metadata remain unchanged.

## Error Behavior

- If Windows capture APIs are unavailable, do not show startable Windows privacy capture controls and report unsupported Windows capture.
- If the user cancels or dismisses `GraphicsCapturePicker`, do not create an asset and return Capture to idle with an explanatory message.
- If a selected target blocks capture or produces protected-content black/blank frames, preserve the platform behavior, mark the attempt failed or degraded, and do not claim the content was redacted.
- If OCR engine creation fails, the requested language is unsupported, or `OcrEngine.MaxImageDimension` forces downscaling, block or degrade according to the user-visible privacy settings; do not silently save clear output as privacy output.
- If OCR falls behind during recording, keep recent boxes alive for a short temporal window, expand margins, reduce OCR cadence or analysis resolution, and surface a degraded notice; if coherence cannot be maintained, stop and fail rather than save a misleading privacy asset.
- If Direct3D device loss, frame-pool resize, target resize, DPI change, or monitor move occurs, rebuild the frame pool/effect resources and keep coordinate transforms correct; if rebuild fails, stop and clean up.
- If the encoder cannot prepare or finalize the MP4 through `MediaTranscoder`/Media Foundation, delete or quarantine the partial output and do not add it to recent captures.
- If any temporary clear frame file is technically unavoidable, it must live in an app-private temp directory, be excluded from recent captures and share/export, be overwritten or deleted on success/failure when feasible, and be quarantined with a visible cleanup warning if deletion fails.
- If clear frame data exists only in GPU/CPU memory, release surfaces/bitmaps promptly, do not log raw frame paths or OCR text, and do not persist recognized text, screenshots, or thumbnails outside the flattened redacted asset.
- If a privacy-marked asset is linked to backend content metadata, send privacy status/settings and aggregate stats only; never send recognized text, OCR boxes that reveal text content, local clear paths, or temp file paths.
- If the user tries this feature on Web, iOS, Linux, or Android, do not expose the Windows implementation path; Android remains governed by its own spec.

## Problem

Creators on Windows desktop may need to record browsers, messaging clients, dashboards, design tools, terminals, and other apps for public videos. Raw screen capture can expose names, URLs, messages, access tokens, customer data, financial data, notifications, profile photos, and protected business context. A static full-screen mask is safer but makes the video hard to follow. The product needs a Windows-specific dynamic redaction mode that reduces readable sensitive content while preserving the workflow narrative, and it must set honest expectations because OCR and visual detection can miss content.

## Solution

Add a Windows desktop privacy capture path behind the existing Flutter capture service boundary. Flutter owns controls, disclosure, metadata, review state, and share gating; Windows native code owns picker consent, frame capture, OCR, redaction rendering, encoding, temp cleanup, and native events. V1 uses `Windows.Graphics.Capture` for user-selected window/display frames, `Windows.Media.Ocr` for text boxes, Direct3D/Win2D effects for blur/pixelate/scramble, and `MediaStreamSource`/`MediaTranscoder` or Media Foundation for a flattened redacted PNG/MP4 output. V2 can add ONNX Runtime WinUI visual detectors and user-pinned protected regions.

## Scope In

- Windows desktop only.
- Windows runner/platform-channel setup if the Flutter project still lacks `app/windows`.
- Windows support detection in the Flutter capture service, separate from Android support.
- Privacy mode controls for Windows capture: text redaction style, visual/photo redaction style, redaction strength, OCR cadence/performance profile, and review state.
- Best-effort disclosure before privacy capture starts and review acknowledgement before share/export.
- `GraphicsCaptureSession.IsSupported()` checks and `GraphicsCapturePicker`-based target selection.
- Capture of one user-selected window or one user-selected display per V1 session.
- `Direct3D11CaptureFramePool` frame acquisition with resize/device-loss handling.
- OCR through `Windows.Media.Ocr.OcrEngine`, including language availability checks, image size constraints, downscale mapping, and immediate discard of recognized text.
- Text redaction styles: `blur`, `pixelate`, and `scramble` using Direct3D/Win2D built-in or custom effects.
- V1 visual region redaction for conservative image-like regions where feasible, without promising face/object detection.
- Flattened redacted PNG export for screenshots.
- Flattened redacted MP4 export for recordings through `MediaStreamSource`/`MediaTranscoder` or a Media Foundation pipeline if that is more reliable in the Flutter Windows runner.
- Temporary clear file and buffer rules, including app-private temp location, no UI exposure, no share/export exposure, deletion/quarantine, and diagnostic limits.
- Multi-monitor and DPI handling in coordinate transforms, capture target metadata, and manual QA.
- Protected-content behavior, black-frame behavior, target closure, target resize, and capture cancellation handling.
- Local capture metadata fields aligned with the Android privacy spec where useful: privacy mode, redaction status, text style, visual style, strength, review state, platform label, processing stats, and degradation notices.
- Dart tests for metadata, support gating, service contract, review gating, and normal capture unchanged behavior.
- Windows native smoke validation on real Windows hardware or VM with graphics support.

## Scope Out

- Web capture, browser APIs, or web privacy mode.
- iOS ReplayKit, Linux Desktop Portal/X11/Wayland capture, or Android implementation changes.
- Perfect anonymization, full privacy guarantee, or numeric safety claim.
- Silent/background capture without user-selected Windows system UI.
- Capturing multiple windows/displays in one V1 session.
- V1 ONNX Runtime object/face/logo detection as a shipping dependency.
- V1 Accessibility or UI Automation semantic scraping.
- Cloud redaction, cloud upload, backend video storage, CDN, server-side transcoding, or retention-policy changes.
- Storing OCR text, OCR transcripts, clear frame images, editable redaction layers, or unredacted auxiliary tracks.
- Full video editor timeline, manual frame editor, captions, trimming, or publishing automation.
- Public marketing claims before QA and legal/product wording review.

## Constraints

- Windows capture must be explicitly user-consented through the system picker or a documented equivalent user-mediated Windows API path.
- The final shareable file must be a flattened raster PNG/MP4 with redaction already applied; it must not include clear source tracks or editable overlay layers that can reveal the original pixels.
- Recognized OCR text must be used only transiently to derive bounds and must never be persisted, logged, sent to the backend, or included in analytics.
- The normal Flutter platform-channel API must stay typed at the service/model boundary before values reach widgets.
- App-scoped storage remains the default for captured files and temp files. Gallery/library export requires a separate explicit export step.
- Backend metadata may store privacy settings/status and aggregate stats only; local file paths must not become durable server truth.
- V1 must keep Windows behavior isolated from Android privacy implementation and must not regress Android capture tests.
- Direct3D/Win2D resources must handle device loss, frame-pool resize, HDR/SDR pixel format decisions, and target closure without leaking surfaces.
- Multi-monitor and DPI transforms must treat capture frame coordinates, OCR coordinates, preview coordinates, and encoded output coordinates as separate spaces until normalized.
- Protected content, black frames, and unavailable targets are platform constraints, not a guarantee that redaction succeeded.
- The UI copy must say best-effort, non-exhaustive, and manual review required; it must not imply ContentGlowz assumes full liability for every leak.
- If implementation cannot avoid writing a clear intermediate file for any stage, that design must be reviewed before shipping and must meet the temp clear file rules in this spec.

## Dependencies

Local dependencies and contracts:

- `app/lib/data/models/capture_asset.dart`: extend metadata with privacy fields in a backwards-compatible way.
- `app/lib/data/services/device_capture_service.dart`: add Windows platform support detection and typed privacy options/events without weakening Android behavior.
- `app/lib/data/services/capture_local_store.dart`: persist review state and privacy metadata only.
- `app/lib/presentation/screens/capture/capture_screen.dart`: add Windows privacy controls, disclosure, status/degraded states, and share/export review gate.
- `app/lib/data/services/api_service.dart`: include privacy metadata when capture assets are linked to backend content, without sending local paths or OCR text.
- `app/windows/`: currently absent; V1 must create or restore the Windows runner before adding native Windows capture code.
- `app/windows/runner/`: prospective Flutter Windows runner files for plugin registration and native method/event channel binding.
- `app/windows/runner/privacy_capture/`: prospective native module for Windows capture, OCR, redaction, encoding, temp cleanup, and event emission.
- `app/pubspec.yaml`: may need Windows desktop plugin or FFI dependencies only if the chosen architecture requires them; prefer native runner integration before adding broad package surface.
- `app/README.md`, `shipglows_data/technical/app/guidelines.md`, `app/CHANGELOG.md`, and `shipglows_data/technical/app/flutter-app-shell-and-capture.md`: update after implementation.

Fresh external docs verdict: `fresh-docs checked` on 2026-05-08 through official Microsoft documentation and the Windows exploration source list.

- Windows screen capture, `Windows.Graphics.Capture`, picker, frame pool, consent, support checks, protected target caveats, HDR/pixel-format notes: `https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture`
- Windows screen capture to video, `MediaStreamSource`, `MediaTranscoder`, Direct3D frame copy, encoded video file process: `https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture-video`
- `Windows.Media.Ocr.OcrEngine`, `RecognizeAsync`, word/line position output, available languages, max image dimension: `https://learn.microsoft.com/en-us/uwp/api/windows.media.ocr.ocrengine`
- Win2D features and effects overview: `https://learn.microsoft.com/en-us/windows/apps/develop/win2d/features`
- Win2D custom effects and interop complexity for custom pixel/scramble effects: `https://learn.microsoft.com/en-us/windows/apps/develop/win2d/custom-effects`
- ONNX Runtime WinUI optional V2 detector path: `https://learn.microsoft.com/en-us/windows/ai/models/get-started-onnx-winui`
- `Windows.Media.Core.MediaStreamSource`: `https://learn.microsoft.com/en-us/uwp/api/windows.media.core.mediastreamsource`
- `Windows.Media.Transcoding.MediaTranscoder`: `https://learn.microsoft.com/en-us/uwp/api/windows.media.transcoding.mediatranscoder`
- Microsoft Media Foundation SDK fallback for a native desktop encoding pipeline: `https://learn.microsoft.com/en-us/windows/win32/medfound/microsoft-media-foundation-sdk`

## Invariants

- Windows privacy capture is best-effort and must be labeled as such.
- A privacy-marked asset must never be represented as guaranteed safe or fully anonymized.
- A privacy-marked asset must require review acknowledgement before share/export.
- Clear temporary media must never appear in local capture history, preview, share/export, or backend metadata.
- Recognized OCR text must never be persisted, logged, sent to the backend, or included in asset metadata.
- Normal capture behavior must remain unchanged when privacy mode is off.
- Android privacy capture remains governed by the Android spec; this chantier must not edit Android native capture unless a shared Dart contract requires backwards-compatible fields.
- Backend metadata may contain redaction settings and aggregate stats only.
- Capture and redaction remain local-first; no cloud processing is introduced in this chantier.
- Protected-content black frames or omitted frames remain Windows platform behavior, not a ContentGlowz privacy guarantee.

## Links & Consequences

- Product: Windows desktop capture changes Capture from Android-only local capture to cross-platform local capture with platform-specific implementations and expectations.
- Security: this feature touches highly sensitive screen content; data minimization, temp cleanup, and review-gated sharing are mandatory.
- Platform architecture: the app currently lacks `app/windows`; adding a Windows runner creates a new native surface that must follow Flutter desktop channel conventions.
- Performance: OCR, frame copies, effects, and encoding can overload low-end devices, 4K displays, high frame rates, and multi-monitor setups.
- UX: Windows capture target selection is mediated by OS UI; users may choose the wrong monitor/window, so target labels and review states matter.
- Backend: no schema migration should be needed if privacy data remains in existing metadata JSON, but payload tests must prove no local paths or OCR text are sent.
- Docs: README/GUIDELINES/technical docs must distinguish Windows V1 from Android V1 and avoid public guarantee language.
- QA: real Windows validation is required because Dart/widget tests cannot prove capture, OCR, GPU effects, or encoder behavior.

## Documentation Coherence

- Update `app/README.md` with Windows desktop privacy capture scope, best-effort limits, local-only processing, review requirement, and no cloud redaction.
- Update `shipglows_data/technical/app/guidelines.md` with Windows native capture temp-file rules, OCR text discard rules, multi-monitor/DPI validation expectations, and review-gated share behavior.
- Update `shipglows_data/technical/app/flutter-app-shell-and-capture.md` to add Windows runner/native capture ownership, validation commands, and Windows QA requirements.
- Update `app/CHANGELOG.md` after implementation.
- Update `shipglows_data/product/app/product.md` only if Windows privacy capture ships publicly and changes platform positioning.
- Do not update `site` marketing copy until Windows QA proves the feature usable and wording is legally safe.

## Edge Cases

- User cancels the Windows capture picker.
- User chooses the wrong monitor in a multi-monitor setup.
- User chooses a monitor with a different DPI scale than the main app window.
- Selected window moves between monitors with different DPI scales during capture.
- Selected window is resized, minimized, closed, occluded, or moved off-screen.
- Selected content blocks capture, produces black frames, or omits protected video.
- HDR or advanced color capture produces washed-out output if pixel formats are mishandled.
- OCR input exceeds `OcrEngine.MaxImageDimension` and must be downscaled with correct coordinate mapping.
- OCR misses small text, low-contrast text, stylized text, terminal text, code, browser URL bars, notification toasts, or translucent overlays.
- Text appears for only a few frames during fast scrolling.
- Text is embedded in images, screenshots inside apps, videos, or canvas-rendered content.
- UI contains non-Latin scripts or mixed languages not supported by the active OCR engine.
- OCR results include recognized text in memory; implementation must discard text after box derivation.
- Win2D custom effect fails to realize on a device, deadlocks, or mishandles DPI compensation.
- Direct3D device is lost during capture or encode.
- MediaStreamSource requests frames faster or slower than capture/redaction can provide them.
- Encoder dimensions are odd or incompatible with H.264 profile settings.
- Partial MP4 cannot be finalized after cancellation, crash, or encoder failure.
- App process dies while app-private clear temp files exist.
- User tries to share a privacy asset before review acknowledgement.
- User links a privacy asset to content while backend is offline.
- Capture runs on a Windows VM or remote desktop environment with limited GPU/capture support.

## Implementation Tasks

- [ ] Task 1: Establish Windows desktop runner and native module boundary if absent.
  - File: `app/windows/`
  - Action: Create or restore the Flutter Windows desktop runner and reserve a focused native privacy capture module under the runner instead of mixing capture logic into generated boilerplate.
  - User story link: Provides the Windows desktop platform surface required for user-selected native capture.
  - Depends on: None.
  - Validate with: Windows `flutter build windows` or equivalent Windows desktop compile in a supported environment.
  - Notes: The current repository does not have `app/windows`; do not attempt to implement Windows behavior through Android native files.

- [ ] Task 2: Add cross-platform privacy metadata to capture assets.
  - File: `app/lib/data/models/capture_asset.dart`
  - Action: Add backwards-compatible fields/enums for `privacyMode`, `redactionStatus`, `textRedactionStyle`, `visualRedactionStyle`, `redactionStrength`, `reviewState`, `privacyPlatform`, `processingStats`, and `degradationReason`.
  - User story link: Lets the app distinguish normal assets from best-effort Windows privacy assets and gate share/export.
  - Depends on: None.
  - Validate with: `flutter test test/data/capture_asset_test.dart`.
  - Notes: Do not store OCR text, OCR transcripts, frame thumbnails, local clear paths, or temp paths.

- [ ] Task 3: Extend local capture store for review state updates.
  - File: `app/lib/data/services/capture_local_store.dart`
  - Action: Add a metadata-only update path for privacy review state and degradation stats without rewriting binary media or changing recent capture ordering.
  - User story link: Lets a user review once, then share later while preserving privacy status.
  - Depends on: Task 2.
  - Validate with: `flutter test test/data/capture_local_store_test.dart`.
  - Notes: Continue using SharedPreferences for metadata only.

- [ ] Task 4: Extend Flutter capture service support for Windows.
  - File: `app/lib/data/services/device_capture_service.dart`
  - Action: Add `TargetPlatform.windows` support detection, Windows-specific privacy options, typed native event parsing, and privacy failure codes while preserving Android method compatibility.
  - User story link: Lets Flutter request Windows privacy capture through a typed service boundary.
  - Depends on: Task 2.
  - Validate with: Dart unit tests using fake `MethodChannel`/`EventChannel` where feasible.
  - Notes: Keep Windows and Android platform behavior explicit; do not make generic capture methods silently change semantics.

- [ ] Task 5: Add Windows privacy controls, disclosure, and degraded states.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Add Windows privacy controls for text style, visual style, strength, performance profile, best-effort disclosure, and degraded/failure notices.
  - User story link: Gives creators control while making limits and review obligations visible before capture starts.
  - Depends on: Task 4.
  - Validate with: `flutter test test/presentation/screens/capture/capture_screen_test.dart`.
  - Notes: UI copy must be concise and must not promise complete anonymization.

- [ ] Task 6: Gate share/export and content linking for privacy-marked assets.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Require review acknowledgement before share/export or content linking when `reviewState=needsReview`; persist `reviewState=reviewed` locally after acknowledgement.
  - User story link: Makes manual review part of the privacy workflow before public sharing.
  - Depends on: Tasks 2, 3, and 5.
  - Validate with: widget tests for share/link blocked until acknowledgement.
  - Notes: This is a product safety gate, not a legal guarantee.

- [ ] Task 7: Add Windows native channel registration.
  - File: `app/windows/runner/flutter_window.cpp`
  - Action: Register method and event channels matching `contentglowz/device_capture` and `contentglowz/device_capture_events`, route only Windows-supported calls to the native privacy capture controller, and return typed unsupported errors otherwise.
  - User story link: Connects Flutter controls to Windows native capture without bypassing model/service typing.
  - Depends on: Tasks 1 and 4.
  - Validate with: Windows desktop compile and a channel smoke test.
  - Notes: Exact file may differ after runner creation; keep generated boilerplate changes minimal and isolated.

- [ ] Task 8: Define Windows native options, events, and error types.
  - File: `app/windows/runner/privacy_capture/privacy_capture_types.h`
  - Action: Define native representations for privacy options, redaction styles, strength, capture target metadata, processing stats, review metadata, degradation notices, and stable error codes.
  - User story link: Keeps channel parsing out of OCR/render/encode internals.
  - Depends on: Task 7.
  - Validate with: Windows C++ compile.
  - Notes: Keep option names aligned with Dart enums and Android privacy metadata where applicable.

- [ ] Task 9: Implement Windows support and picker controller.
  - File: `app/windows/runner/privacy_capture/windows_privacy_capture_controller.cpp`
  - Action: Check `GraphicsCaptureSession.IsSupported()`, invoke `GraphicsCapturePicker`, handle user cancellation, create `GraphicsCaptureItem`, and expose selected target metadata.
  - User story link: Ensures the user explicitly chooses the window or display to redact.
  - Depends on: Tasks 7 and 8.
  - Validate with: Windows manual picker smoke.
  - Notes: Do not add silent capture or UI Automation in V1.

- [ ] Task 10: Implement Direct3D frame pool and lifecycle management.
  - File: `app/windows/runner/privacy_capture/windows_capture_frame_source.cpp`
  - Action: Create the Direct3D device, `Direct3D11CaptureFramePool`, `GraphicsCaptureSession`, frame acquisition loop, target closed handling, resize handling, device-loss recovery, and timestamp propagation.
  - User story link: Provides the local frame stream that will be redacted before export.
  - Depends on: Task 9.
  - Validate with: Windows manual screenshot/recording frame smoke and compile.
  - Notes: Normalize capture frame size and content size separately to avoid undefined regions.

- [ ] Task 11: Implement OCR analyzer with coordinate normalization.
  - File: `app/windows/runner/privacy_capture/windows_ocr_analyzer.cpp`
  - Action: Use `Windows.Media.Ocr.OcrEngine`, check languages and max dimensions, run OCR at a throttled cadence, derive line/word boxes, discard recognized text immediately, and map boxes into output coordinates.
  - User story link: Finds likely sensitive text without storing its content.
  - Depends on: Task 10.
  - Validate with: static bitmap smoke if feasible plus Windows compile.
  - Notes: Downscale analysis images only with explicit scale mapping back to output space.

- [ ] Task 12: Implement temporal redaction tracker.
  - File: `app/windows/runner/privacy_capture/redaction_tracker.cpp`
  - Action: Persist boxes across a short frame/time window, merge overlaps, expand margins, handle fast scroll, and mark degraded confidence when OCR cadence drops.
  - User story link: Reduces clear-text flashes while keeping video understandable.
  - Depends on: Task 11.
  - Validate with: C++ unit tests or small helper tests for merge, expiry, margin, and DPI transform math.
  - Notes: This is critical for screen recordings and scrolling browser/messaging flows.

- [ ] Task 13: Implement Win2D/Direct3D redaction renderer.
  - File: `app/windows/runner/privacy_capture/windows_redaction_renderer.cpp`
  - Action: Apply blur, pixelate, and scramble effects to active regions using Win2D/Direct3D built-in effects or a custom effect where needed; preserve UI layout and avoid full-screen masks by default.
  - User story link: Produces visually usable videos while covering readable sensitive regions.
  - Depends on: Tasks 10, 11, and 12.
  - Validate with: Windows visual screenshot before/after smoke and compile.
  - Notes: If custom Win2D effects are too complex for V1, use simpler shader/downscale/upscale or fake glyph overlays that still make text unreadable.

- [ ] Task 14: Implement privacy screenshot export.
  - File: `app/windows/runner/privacy_capture/windows_privacy_screenshot.cpp`
  - Action: Capture a frame, analyze/redact it, write only the flattened redacted PNG to app-scoped storage, return privacy metadata, and release clear surfaces.
  - User story link: Provides the lowest-risk Windows privacy capture path.
  - Depends on: Tasks 10-13.
  - Validate with: Windows manual screenshot smoke.
  - Notes: Register the asset only after redaction and write succeed.

- [ ] Task 15: Implement privacy recording encode pipeline.
  - File: `app/windows/runner/privacy_capture/windows_privacy_recorder.cpp`
  - Action: Feed redacted Direct3D frames to `MediaStreamSource`/`MediaTranscoder` or Media Foundation, encode an MP4, track progress/stats, and finalize or fail atomically.
  - User story link: Delivers dynamic best-effort privacy for Windows desktop recordings.
  - Depends on: Tasks 10-13.
  - Validate with: Windows manual recording smoke at 1080p and one higher-resolution case.
  - Notes: Use Media Foundation instead of MediaTranscoder only if it reduces runner integration risk or improves reliability; document the decision in implementation notes.

- [ ] Task 16: Enforce temp clear file and crash cleanup rules.
  - File: `app/windows/runner/privacy_capture/privacy_temp_store.cpp`
  - Action: Centralize temp paths, app-private storage, delete-on-success/failure, startup cleanup of stale privacy temp files, quarantine behavior, and diagnostics that do not reveal clear paths in user-facing UI.
  - User story link: Prevents failed privacy processing from leaking clear intermediates.
  - Depends on: Tasks 14 and 15.
  - Validate with: Windows manual failure/cancel smoke and cleanup inspection.
  - Notes: Prefer no clear temp files. This task exists to control unavoidable intermediates and partial outputs.

- [ ] Task 17: Add privacy metadata to backend capture/content payloads.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Include privacy status/settings/review state and aggregate stats when linking captures to content; exclude OCR text, clear file paths, temp paths, and local paths as durable server truth.
  - User story link: Preserves privacy context when a redacted capture becomes content.
  - Depends on: Task 2.
  - Validate with: existing API parsing tests or a targeted unit test.
  - Notes: No backend schema migration expected if metadata JSON is sufficient.

- [ ] Task 18: Add tests and documentation updates.
  - File: `app/test/data/capture_asset_test.dart`, `app/test/data/capture_local_store_test.dart`, `app/test/presentation/screens/capture/capture_screen_test.dart`, `app/README.md`, `shipglows_data/technical/app/guidelines.md`, `shipglows_data/technical/app/flutter-app-shell-and-capture.md`, `app/CHANGELOG.md`
  - Action: Cover parsing, support gating, disclosure, review gating, normal capture unchanged behavior, and document Windows-only V1 limits, temp rules, best-effort language, and manual QA.
  - User story link: Prevents regression and aligns operator expectations with actual privacy guarantees.
  - Depends on: Tasks 1-17.
  - Validate with: targeted Flutter tests, `flutter analyze`, docs review, and Windows manual QA report.
  - Notes: Native frame quality still requires Windows visual review beyond automated tests.

## Acceptance Criteria

- [ ] CA 1: Given the app runs on Windows desktop with capture support, when the user opens Capture, then Windows privacy capture controls are visible and Android-only unsupported copy is not shown.
- [ ] CA 2: Given the app runs on Web, iOS, Linux, or unsupported desktop, when the user opens Capture, then the Windows privacy capture path is not startable.
- [ ] CA 3: Given privacy mode is enabled, when the user starts screenshot or recording, then a best-effort disclosure appears before the Windows picker opens.
- [ ] CA 4: Given the user declines the disclosure, when capture is requested, then no Windows picker opens and no asset is created.
- [ ] CA 5: Given the user accepts the disclosure, when capture starts, then `GraphicsCapturePicker` lets the user select a window or display.
- [ ] CA 6: Given the user cancels the picker, when Capture returns to idle, then no asset is created and a recoverable message is visible.
- [ ] CA 7: Given a capturable target is selected, when a privacy screenshot succeeds, then the saved asset is a flattened redacted PNG with `privacyMode=true` and `reviewState=needsReview`.
- [ ] CA 8: Given a capturable target is selected, when a privacy recording succeeds, then the saved asset is a flattened redacted MP4 with `privacyMode=true`, processing stats, and `reviewState=needsReview`.
- [ ] CA 9: Given OCR detects text, when text style is `blur`, then the detected region plus margin is unreadable in the output preview.
- [ ] CA 10: Given OCR detects text, when text style is `pixelate`, then the detected region plus margin is mosaicked enough to be unreadable in the output preview.
- [ ] CA 11: Given OCR detects text, when text style is `scramble`, then real text pixels are covered by fake glyphs/lines and recognized text is not stored.
- [ ] CA 12: Given fast scrolling occurs during recording, when OCR runs at a throttled cadence, then redaction boxes persist across adjacent frames and no obvious clear-text flashes appear in manual review.
- [ ] CA 13: Given the selected target is resized or moved between monitors with different DPI scales, when capture continues, then redaction boxes stay aligned or the session fails with a clear degraded message.
- [ ] CA 14: Given protected content produces black or blank frames, when the asset is finalized or failed, then ContentGlowz does not claim the protected content was successfully redacted.
- [ ] CA 15: Given encoding fails or cancellation occurs mid-session, when Capture returns to idle, then no clear or partial output appears in recent captures and temp output is deleted or quarantined.
- [ ] CA 16: Given a privacy asset has `reviewState=needsReview`, when the user tries to share/export or link it to content, then ContentGlowz requires review acknowledgement first.
- [ ] CA 17: Given the user acknowledges review, when share/export continues, then only the flattened redacted PNG/MP4 path is passed to the OS.
- [ ] CA 18: Given a privacy asset is linked to backend content metadata, when the payload is sent, then privacy status/settings are included and OCR text, clear paths, temp paths, and local paths as durable truth are absent.

## Test Strategy

- Dart unit tests:
  - `capture_asset_test.dart` for backwards-compatible privacy metadata parsing and serialization.
  - `capture_local_store_test.dart` for review state updates and metadata-only persistence.
  - `device_capture_service` tests for Windows support detection, privacy options, platform errors, and Android behavior unchanged.
  - `api_service` tests for privacy metadata payloads when existing test patterns allow it.
- Flutter widget tests:
  - Capture screen shows Windows privacy controls only on supported Windows state.
  - Disclosure blocks capture until accepted.
  - Degraded/failure notices stay visible and actionable.
  - Share/export/content-link gate blocks `needsReview` privacy assets until acknowledgement.
  - Normal capture controls remain usable when privacy mode is off.
- Windows native checks:
  - Windows desktop compile after runner/native module creation.
  - Native helper tests for coordinate transforms, DPI scaling, box merge/expiry, margin expansion, and temp-store path filtering where feasible.
  - Static image OCR/redaction smoke if the native test harness supports it.
- Manual Windows QA:
  - Screenshot privacy capture for one window.
  - Screenshot privacy capture for one full display.
  - Recording privacy capture for one window.
  - Recording privacy capture for one full display.
  - Browser fast scroll with visible URL/text.
  - Messaging or document app fast scroll.
  - Multi-monitor test with different DPI scale factors.
  - Target resize and move between monitors.
  - Protected content or DRM/secure window behavior.
  - Encoder cancellation and app restart cleanup.
  - Review acknowledgement and OS share/export path.
  - Confirm no clear temp asset appears in recent captures or backend payloads.
- Validation commands:
  - `flutter test test/data/capture_asset_test.dart test/data/capture_local_store_test.dart test/presentation/screens/capture/capture_screen_test.dart`
  - `flutter analyze`
  - Windows desktop build/test command from the selected Windows CI or local Windows environment.

## Risks

- High platform risk: the project currently lacks a Windows runner, so desktop setup and native integration must be established before feature work.
- High security risk: failed cleanup or misleading UI could expose sensitive screen data.
- Redaction miss risk: OCR can miss small, moving, stylized, low-contrast, mixed-language, or image-embedded text.
- Weak-redaction risk: visually pleasant blur may remain inferable if strength is too low.
- Performance risk: 4K displays, high FPS, multi-monitor capture, OCR, effects, and encoding can overload CPU/GPU.
- Coordinate risk: mixed DPI and monitor movement can misalign OCR boxes and redaction regions.
- Protected-content risk: Windows can block or blank content; the app must not interpret black frames as successful privacy processing.
- Encoding risk: `MediaStreamSource`/`MediaTranscoder` integration may not fit the Flutter Windows runner cleanly, requiring Media Foundation.
- Temp-file risk: clear intermediates or partial MP4s are sensitive and must be deleted or quarantined.
- Trust risk: product copy must be honest and avoid guarantee language.
- QA risk: automated tests cannot prove real-world privacy quality; manual review on Windows hardware is mandatory.

## Execution Notes

Read first:

- `app/lib/data/services/device_capture_service.dart`
- `app/lib/data/models/capture_asset.dart`
- `app/lib/presentation/screens/capture/capture_screen.dart`
- `app/lib/data/services/capture_local_store.dart`
- `shipglows_data/technical/app/guidelines.md`
- `shipglows_data/workflow/explorations/2026-05-08-windows-privacy-capture-redaction.md`

Implementation approach:

1. Create/restore the Windows runner and confirm a no-feature Windows build before adding capture code.
2. Add Dart privacy metadata, Windows support detection, and review-gated UI while keeping Android tests green.
3. Add native Windows channel registration and typed option/event/error objects.
4. Implement screenshot privacy capture before video because it proves picker, frame acquisition, OCR, effects, temp cleanup, and asset registration with lower lifecycle risk.
5. Implement OCR analyzer, tracker, and renderer as separable native modules with coordinate tests.
6. Implement MP4 recording last, choosing `MediaStreamSource`/`MediaTranscoder` first unless Media Foundation is demonstrably safer for the runner.
7. Run Dart checks, Windows compile, then manual Windows QA across DPI, multi-monitor, protected content, and cleanup cases.

Constraints for implementers:

- Do not implement Web, iOS, Linux, or Android behavior in this chantier.
- Do not add cloud redaction or backend binary storage.
- Do not store OCR text anywhere.
- Do not expose clear temporary files to Flutter local history, preview, share/export, content linking, backend metadata, logs, or diagnostics.
- Do not claim guaranteed anonymization.
- Do not use UI Automation or Accessibility-style semantic scraping in V1.
- Do not add ONNX Runtime as a V1 dependency unless `/sf-ready` explicitly expands V1.
- Stop and rescope if the encoder path requires a persistent clear video file as an intermediate.

Fresh external docs: `fresh-docs checked` on 2026-05-08 through official Microsoft docs listed in `Dependencies`.

## Open Questions

- None blocking for V1. Product decisions fixed for this draft:
  - Windows desktop only.
  - Dynamic selective redaction over large static masks.
  - Best-effort language, no guarantee or percentage claim.
  - Post-production review gate required before share/export.
  - V1 uses OCR and effects; ONNX visual detection is V2 unless readiness explicitly expands scope.
  - Multi-window/multi-display simultaneous capture is out of V1.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-08 09:47:05 UTC | sf-spec | GPT-5 Codex | Created Windows desktop privacy capture dynamic redaction spec from Windows exploration, Android privacy spec style, guidelines, and official Microsoft docs. | draft saved | /sf-ready windows privacy capture dynamic redaction |

## Current Chantier Flow

sf-spec done -> sf-ready not launched -> sf-start not launched -> sf-verify not launched -> sf-end not launched -> sf-ship not launched
