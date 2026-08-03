---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "app"
created: "2026-05-08"
created_at: "2026-05-08 09:45:40 UTC"
updated: "2026-05-08"
updated_at: "2026-05-08 09:45:40 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "As a ContentGlowz creator using the web app in a browser to capture a screen or tab for public sharing, I want a privacy mode that dynamically obscures readable text and sensitive imagery before export, so I can reduce accidental leaks while keeping the workflow video understandable."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter capture UI"
  - "app web capture support"
  - "app local capture metadata store"
  - "app capture/content asset metadata"
  - "Browser Screen Capture API"
  - "Browser frame processing APIs"
  - "Canvas and OffscreenCanvas"
  - "WebCodecs"
  - "MediaRecorder"
  - "Shape Detection TextDetector"
  - "OCR WASM fallback"
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
  - artifact: "shipglows_data/workflow/explorations/2026-05-08-web-privacy-capture-redaction.md"
    artifact_version: "unknown"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md"
    artifact_version: "0.1.0"
    required_status: "draft"
supersedes: []
evidence:
  - "shipglows_data/workflow/explorations/2026-05-08-web-privacy-capture-redaction.md concludes browser V1 is feasible but limited by browser API variability and real-time performance."
  - "The exploration recommends getDisplayMedia capture, frame processing, TextDetector when available, OCR WASM fallback, blur/pixelate/scramble, local-only processing, and review before share/export."
  - "app/lib/data/services/device_capture_service.dart currently returns unsupported on web through kIsWeb, so web privacy capture needs a browser-specific client path rather than the existing Android MethodChannel path."
  - "app/lib/presentation/screens/capture/capture_screen.dart already owns capture actions, recording state, recent assets, share actions, and unsupported-platform UI."
  - "shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md establishes product invariants reused here: best-effort only, no guarantee, flattened redacted output, no OCR text persistence, and review acknowledgement before sharing."
next_step: "/sf-ready web privacy capture dynamic redaction"
---

# Title

Web Privacy Capture Dynamic Redaction

## Status

Draft spec for a web/browser-only privacy capture mode. This chantier adds best-effort dynamic redaction to browser screen or tab capture using browser APIs. V1 captures through `getDisplayMedia()`, processes frames client-side, obscures detected text and sensitive imagery with blur, pixelation, or scramble-style overlays, and exposes only a flattened redacted export after user review acknowledgement.

This spec explicitly excludes Windows desktop APIs, iOS ReplayKit, Linux desktop capture, native Electron/Tauri capture, and non-browser platform parity. Browser support must be feature-detected at runtime and presented honestly. The feature does not guarantee anonymization.

## User Story

As a ContentGlowz creator using the web app in a browser to capture a screen or tab for public sharing, I want a privacy mode that dynamically obscures readable text and sensitive imagery before export, so I can reduce accidental leaks while keeping the workflow video understandable.

## Minimal Behavior Contract

When a browser user enables privacy mode and starts a capture, ContentGlowz must show a best-effort disclosure, ask the browser for screen or tab capture through the standard chooser, process captured frames locally before normal preview/share/export, save or expose only a flattened redacted media asset marked as needing review, and block share/export until the user acknowledges reviewing the result; if the browser denies capture, required APIs are unavailable, OCR fails, frame processing falls behind, or export cannot be finalized, the app must stop cleanly, avoid registering a misleading privacy asset, discard or quarantine temporary clear data, and explain that privacy capture was not safely completed. The easy edge case is fast scrolling or transitions: detected boxes must persist and expand across nearby frames so readable text does not flash clear between OCR runs.

## Success Behavior

- Given a user opens Capture in a supported browser, when they enable privacy mode, then the UI shows privacy controls and a disclosure that redaction is best-effort, non exhaustive, and requires manual review before sharing.
- Given privacy mode is enabled, when the user starts capture, then the browser `getDisplayMedia()` chooser opens and ContentGlowz does not attempt to preselect or silently capture a screen.
- Given the browser returns a display media stream, when frame processing starts, then frames are analyzed locally and redaction is applied before preview/export paths treat the result as shareable media.
- Given text detection is available through `TextDetector`, when text regions are detected, then ContentGlowz uses only region geometry for redaction and discards recognized text content immediately.
- Given `TextDetector` is unavailable or unreliable in the browser, when OCR fallback is enabled, then ContentGlowz uses a local WASM OCR path with lower cadence and clear performance messaging.
- Given OCR is unavailable and text redaction is required, when privacy capture is requested, then ContentGlowz blocks privacy capture instead of silently recording clear output.
- Given the selected text style is `scramble`, when text boxes are detected, then real pixels are covered and fake glyphs or line fragments preserve layout without storing or reusing recognized text.
- Given the selected style is `blur` or `pixelate`, when text or photo regions are detected, then expanded boxes are rendered unreadable while preserving enough surrounding UI to understand the workflow.
- Given recording is active, when frames are processed, then the output stream or encoded chunks contain redacted frames only, and the normal asset list receives the asset only after export finalizes.
- Given WebCodecs is available and suitable, when the implementation chooses that path, then encoded output is produced from redacted frames and muxed/exported without exposing a clear track.
- Given WebCodecs is unavailable or too costly, when the fallback path is used, then a redacted Canvas/OffscreenCanvas stream is recorded with MediaRecorder and the resulting asset is still flattened and privacy-marked.
- Given a privacy-marked asset has `reviewState=needsReview`, when the user taps share/export, then ContentGlowz requires a review acknowledgement before sharing.
- Given the user acknowledges review, when share/export continues, then only the flattened redacted asset is passed to browser download/share mechanisms.
- Given privacy mode is disabled, when the user uses existing capture flows, then normal Android capture behavior and unsupported-web messaging are not regressed except where web support is explicitly added.

## Error Behavior

- If the browser does not support `navigator.mediaDevices.getDisplayMedia`, show an unsupported web privacy capture state and do not expose capture controls that imply support.
- If the user cancels or denies the browser capture chooser, create no asset and show a recoverable canceled state.
- If the browser stops the display track, stop processing, release frame/canvas resources, and either finalize a valid redacted partial asset only if the user explicitly stopped normally or discard the failed attempt.
- If `TextDetector` is absent and the OCR WASM fallback cannot load, block text privacy capture and explain that the browser cannot safely run privacy capture.
- If OCR or frame analysis falls behind, reduce analysis cadence, persist/expand recent boxes, and surface a performance notice; if the pipeline cannot keep output coherent, stop and do not register a privacy asset.
- If MediaRecorder is the only viable encoder and the browser can only produce a format such as WebM, label the exported file type honestly and do not claim MP4 support for that session.
- If WebCodecs is used but encoding or muxing fails, discard the incomplete export or mark it failed; do not add a broken or clear file to recent captures.
- If a temporary clear `VideoFrame`, canvas, Blob, or object URL is required internally, keep it in memory or sandboxed browser storage only as long as necessary and revoke/delete it on success, failure, or cancellation.
- If cleanup of a temporary Blob/object URL cannot be confirmed, avoid registering the attempt as shareable and surface a local cleanup warning.
- If backend linking or content creation uses the captured asset, include privacy metadata only; never include OCR text, frame images, thumbnails generated from clear frames, or clear local paths.

## Problem

Creators using the web app may need to record browser workflows, tabs, or screen content for public videos. Raw captures can include private messages, names, URLs, emails, tokens, account data, photos, avatars, and notifications. Browser APIs intentionally require explicit user selection and expose uneven media-processing capabilities across engines. The product needs a web-only privacy mode that reduces readable sensitive content without implying full anonymization and without depending on native desktop capture APIs.

## Solution

Add a browser-specific privacy capture client and UI path that uses `navigator.mediaDevices.getDisplayMedia()` for consented capture, processes video frames client-side through the best available browser APIs, applies dynamic redaction regions, and exports a flattened redacted media asset. Feature detection chooses between `TextDetector` and local WASM OCR for text detection, Canvas/OffscreenCanvas for rendering, and WebCodecs or MediaRecorder for final encoding/export.

## Scope In

- Web/browser-only privacy capture mode in the existing Capture screen.
- Runtime browser support detection for `getDisplayMedia`, frame processing, Canvas/OffscreenCanvas, WebCodecs, MediaRecorder, `TextDetector`, and OCR WASM fallback.
- Explicit best-effort disclosure before browser privacy capture.
- Browser display media capture through `navigator.mediaDevices.getDisplayMedia()`.
- Frame processing path for redaction before preview/share/export.
- Text redaction styles: `scramble`, `blur`, and `pixelate`.
- Photo or image-region redaction styles: `off`, `blur`, and `pixelate`.
- Text detection through `TextDetector` when available.
- Local OCR WASM fallback when `TextDetector` is unavailable and browser/device performance allows it.
- Temporal tracking for moving text regions: box persistence, margin expansion, merge behavior, and conservative fallback during scroll or dropped analysis frames.
- Redacted rendering through Canvas or OffscreenCanvas; WebGL/WebGPU may remain optional optimization only.
- Encoded/exportable output from redacted frames using WebCodecs where viable or MediaRecorder fallback from a redacted canvas stream.
- Flattened redacted export only; no editable redaction layers and no clear media track.
- Review acknowledgement before browser share, download, export, or content attachment of a privacy-marked asset.
- Privacy metadata on local capture assets: privacy mode, redaction status, text style, photo style, strength, detection engine, export engine, review state, and aggregate stats.
- Tests for Dart service/model/UI contracts and browser capability selection where feasible.
- Manual browser QA on at least one Chromium-based browser, with documented gaps for Firefox/Safari if unsupported.

## Scope Out

- Windows desktop capture APIs, macOS native capture APIs, Linux desktop capture APIs, Electron, Tauri, or browser-extension capture APIs.
- iOS ReplayKit, Android MediaProjection, or native mobile parity work in this chantier.
- Perfect anonymization guarantee, formal privacy certification, or numeric safety claim.
- Preselecting a screen/window/tab before the browser chooser.
- Persisted browser capture permission; browser consent must remain per session.
- Cloud OCR, cloud redaction, backend media upload, server-side transcoding, CDN, or retention policy changes.
- Storing recognized text, OCR transcripts, clear frames, clear thumbnails, or clear temporary file paths.
- Manual frame-by-frame video editor, trimming timeline, captioning, publishing automation, or YouTube upload.
- Region Capture, Element Capture, Capture Handle, WebGPU, and WebGL optimizations as required V1 dependencies; they may be documented as V2/optimization paths only.
- Claiming MP4 export when the current browser path can only produce WebM or another container.

## Constraints

- `getDisplayMedia()` must be invoked from a user gesture and must rely on the browser chooser; ContentGlowz cannot silently capture or force a source before the chooser.
- Browser permission cannot be persisted between capture sessions.
- Browser support is uneven; all major APIs must be feature-detected and failures must be user-visible.
- The final shareable/exportable asset must be flattened redacted media, not a clear source plus overlay instructions.
- OCR text content must be discarded immediately after deriving boxes; only geometry and aggregate stats may survive.
- The UI must say best-effort, non exhaustive, and manual review required; it must not imply guaranteed anonymization.
- Privacy capture must be local-first in the browser. No captured frames, OCR output, or redaction data may be sent to backend services in V1.
- Normal Android capture behavior must remain unchanged. Web support must be introduced through a browser-specific client path, not by weakening the Android-only MethodChannel assumptions.
- If browser output format differs by engine, the asset MIME type, filename, and UI label must match the actual export.
- Performance safeguards are part of correctness: frame dropping or OCR lag must not produce a falsely trusted privacy asset.

## Dependencies

Local dependencies and contracts:

- `app/lib/data/services/device_capture_service.dart`: currently blocks web through `_isWebRuntime`; add or route to a web-specific capture client contract in implementation.
- `app/lib/presentation/screens/capture/capture_screen.dart`: add browser privacy controls, disclosure, recording/progress/error states, review gate, and browser-supported UI.
- `app/lib/data/models/capture_asset.dart`: extend metadata for privacy mode, review state, detection/export engine, redaction settings, and aggregate stats.
- `app/lib/data/services/capture_local_store.dart`: persist review state and privacy metadata without storing clear media or OCR text.
- `app/lib/data/services/api_service.dart`: include privacy metadata in capture/content payloads without backend media upload or OCR text.
- `app/lib/presentation/screens/capture/capture_asset_preview.dart` and platform variants: preview privacy-marked web assets without clear-source fallback.
- New web/browser capture implementation file(s), likely under `app/lib/data/services/` or `app/lib/data/services/web/`, using conditional imports so non-web builds are not affected.
- New browser worker or helper module(s), if implementation needs off-main-thread frame analysis or OCR.
- `app/web/`: only update if required for worker asset loading, CSP, WASM packaging, or browser runtime assets.

Fresh external docs verdict: `fresh-docs checked via exploration` on 2026-05-08. No new broad research was required for this spec; official/source URLs were carried forward from `shipglows_data/workflow/explorations/2026-05-08-web-privacy-capture-redaction.md`.

- MDN Screen Capture API: `https://developer.mozilla.org/en-US/docs/Web/API/Screen_Capture_API`
- MDN `MediaDevices.getDisplayMedia`: `https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getDisplayMedia`
- MDN WebCodecs API: `https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API`
- MDN `MediaStreamTrackProcessor`: `https://developer.mozilla.org/en-US/docs/Web/API/MediaStreamTrackProcessor`
- MDN `MediaStreamTrackGenerator`: `https://developer.mozilla.org/en-US/docs/Web/API/MediaStreamTrackGenerator`
- MDN Canvas 2D `filter`: `https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/filter`
- MDN Canvas 2D `imageSmoothingEnabled`: `https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/imageSmoothingEnabled`
- MDN Canvas pixel manipulation: `https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Pixel_manipulation_with_canvas`
- MDN WebGPU API: `https://developer.mozilla.org/en-US/docs/Web/API/WebGPU_API`
- W3C Screen Capture Working Draft 2025: `https://www.w3.org/TR/screen-capture/`
- W3C Region Capture Working Draft 2023: `https://www.w3.org/TR/mediacapture-region/`
- W3C Capture Handle identity draft: `https://w3c.github.io/mediacapture-handle/identity/`
- Chrome Capture Handle docs: `https://developer.chrome.com/docs/web-platform/capture-handle/`
- Chrome Shape Detection capabilities: `https://developer.chrome.com/docs/capabilities/shape-detection`
- Tesseract project: `https://tesseract.projectnaptha.com/`
- Tesseract.js repository: `https://github.com/naptha/tesseract.js`

## Invariants

- Web privacy capture is browser-only and must not imply support for Windows, iOS, Linux, Electron, Tauri, or native desktop capture.
- Privacy mode is best-effort and must be labeled as such.
- A privacy-marked asset must never be represented as fully anonymized or guaranteed safe.
- A privacy-marked asset must require review acknowledgement before share/export/content attachment.
- Normal Android capture mode remains unchanged unless explicitly touched by shared model/UI metadata.
- Clear frames, clear blobs, and OCR text must never appear in local capture history.
- Recognized text content must never be persisted, logged, sent to backend, or included in asset metadata.
- Backend metadata may contain redaction settings, review state, engine names, and aggregate stats only.
- Browser capture and redaction remain local-first in V1.
- Protected-content black frames, browser capture restrictions, and chooser limitations are platform behavior, not ContentGlowz bugs.

## Links & Consequences

- Product: Capture becomes available on web only where browser APIs can uphold the privacy flow; unsupported browsers need clear messaging rather than hidden partial behavior.
- Privacy/security: captured browser content is sensitive; data minimization, no OCR persistence, and cleanup of temporary browser objects are mandatory.
- Performance: OCR WASM, frame processing, and encoding can overload low-end devices; adaptive cadence, frame skipping, and failure states are core requirements.
- UX: Browser chooser behavior cannot be customized beyond API constraints, so the UI must prepare users before capture and verify after capture.
- Backend: no schema migration is expected if privacy metadata stays in existing metadata payloads; backend must not receive OCR text or media bytes in this chantier.
- Build/runtime: WASM OCR may require web asset packaging and worker loading decisions; this must be validated in Flutter web builds.
- QA: automated tests cannot prove privacy quality; manual browser review is required for scrolling text, dense pages, image-heavy pages, and export/share gates.

## Documentation Coherence

- Update `app/README.md` with browser privacy capture scope, best-effort limits, browser support caveats, local-only processing, and review-before-share behavior.
- Update `shipglows_data/technical/app/guidelines.md` with web privacy data-minimization rules: no OCR text persistence, no clear frame/blob registration, no cloud redaction, and review-gated export.
- Update `app/CHANGELOG.md` after implementation.
- Update `shipglows_data/product/app/product.md` only if the feature ships publicly and changes supported-platform positioning.
- Do not update `site` marketing copy until manual browser QA proves the feature is usable and wording is legally safe.
- Do not update `.env.example` unless OCR fallback or worker packaging introduces a configurable runtime flag.

## Edge Cases

- User selects the wrong tab/window/screen in the browser chooser.
- User captures ContentGlowz itself and creates mirror/recursive capture effects.
- Fast vertical scrolling in a chat, email inbox, CRM table, or browser page.
- Horizontal carousels, modals, route transitions, and animated overlays moving text between OCR samples.
- Small text in address bars, sidebars, developer tools, code blocks, tables, or status areas.
- White text over images, translucent overlays, gradients, dark mode, high-contrast mode, and stylized fonts.
- Non-Latin scripts, emojis, mixed scripts, all-caps UI, and text rendered as images.
- Text embedded inside photos, videos, screenshots, canvas content, or remote desktop streams.
- Browser throttles background tab, worker, or capture processing.
- User stops sharing from browser chrome instead of ContentGlowz controls.
- MediaRecorder produces WebM while the UI expected MP4.
- WebCodecs is present but missing a required encoder, hardware path, or muxing support.
- OCR WASM download/load is slow, blocked, or too memory-heavy.
- User goes offline after capture and tries to attach a privacy asset to content.
- Object URLs, frames, or temporary blobs survive longer than intended after cancellation.

## Implementation Tasks

- [ ] Task 1: Add web privacy capture metadata to the capture asset model.
  - File: `app/lib/data/models/capture_asset.dart`
  - Action: Add backwards-compatible fields/enums for `privacyMode`, `redactionStatus`, `textRedactionStyle`, `photoRedactionStyle`, `redactionStrength`, `reviewState`, `detectionEngine`, `exportEngine`, and aggregate stats.
  - User story link: Lets the app distinguish normal captures from browser privacy captures and gate export/share.
  - Depends on: None.
  - Validate with: `flutter test test/data/capture_asset_test.dart`.
  - Notes: Do not add fields for OCR text, clear frame paths, or clear blob references.

- [ ] Task 2: Extend local capture storage for privacy review state.
  - File: `app/lib/data/services/capture_local_store.dart`
  - Action: Add or extend methods to update asset privacy metadata and `reviewState` without rewriting media bytes or breaking recent asset ordering/content links.
  - User story link: Lets review acknowledgement persist across a session without weakening privacy metadata.
  - Depends on: Task 1.
  - Validate with: `flutter test test/data/capture_local_store_test.dart`.
  - Notes: Keep storage metadata-only.

- [ ] Task 3: Define a browser-capable capture client contract.
  - File: `app/lib/data/services/device_capture_service.dart`
  - Action: Route web runtime to a browser capture client or add an interface extension for privacy options while preserving Android MethodChannel behavior.
  - User story link: Makes web privacy capture possible without misusing Android-only platform channel assumptions.
  - Depends on: Task 1.
  - Validate with: Dart tests using fake capture clients and existing unsupported-platform cases.
  - Notes: Normal Android `takeScreenshot`, `startRecording`, `stopRecording`, and `shareAsset` behavior must remain compatible.

- [ ] Task 4: Implement browser support detection and capability reporting.
  - File: `app/lib/data/services/web/browser_capture_capabilities.dart`
  - Action: Detect `getDisplayMedia`, frame processing primitives, Canvas/OffscreenCanvas, MediaRecorder, WebCodecs, TextDetector, worker support, and OCR fallback availability; expose clear reason codes.
  - User story link: Prevents users from starting privacy capture in browsers that cannot safely complete it.
  - Depends on: Task 3.
  - Validate with: browser capability unit tests where feasible and manual checks in target browsers.
  - Notes: Capability detection must be runtime-based, not user-agent-only.

- [ ] Task 5: Add browser privacy controls and disclosure to Capture.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Show web privacy mode controls, text/photo style selectors, strength setting, best-effort disclosure, and unsupported capability messages in the existing capture flow.
  - User story link: Gives creators explicit control while making limits visible before capture.
  - Depends on: Tasks 3 and 4.
  - Validate with: `flutter test test/presentation/screens/capture/capture_screen_test.dart`.
  - Notes: Wording must say best-effort, non exhaustive, and manual review required.

- [ ] Task 6: Gate web share/export/content attachment by review state.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Require review acknowledgement before browser share/download/export or content attachment for `reviewState=needsReview`; persist `reviewState=reviewed`.
  - User story link: Ensures the user reviews the flattened result before public use.
  - Depends on: Tasks 1, 2, and 5.
  - Validate with: widget tests for share/export blocked until acknowledgement.
  - Notes: This is a safety gate, not a guarantee of complete anonymization.

- [ ] Task 7: Create the browser privacy capture service.
  - File: `app/lib/data/services/web/browser_privacy_capture_service.dart`
  - Action: Start `getDisplayMedia()` from user gestures, manage track lifecycle, emit recording/progress/failed/completed events, and return privacy-marked assets only after redacted export finalizes.
  - User story link: Provides the web-specific capture lifecycle.
  - Depends on: Tasks 3-5.
  - Validate with: browser smoke tests and fake-service Dart tests for event sequencing.
  - Notes: Do not attempt to preselect a source or persist capture permission.

- [ ] Task 8: Build the frame processing pipeline.
  - File: `app/lib/data/services/web/browser_frame_processor.dart`
  - Action: Convert captured frames into processable frames using the best available API path, schedule analysis cadence, handle frame dropping, and send redacted frames to the renderer/exporter.
  - User story link: Ensures redaction happens before output becomes shareable.
  - Depends on: Tasks 4 and 7.
  - Validate with: browser manual QA and focused tests for pipeline state transitions.
  - Notes: Prefer worker/off-main-thread processing where feasible; stop if processing cannot keep output coherent.

- [ ] Task 9: Implement text detection with conditional TextDetector and OCR WASM fallback.
  - File: `app/lib/data/services/web/browser_text_detector.dart`
  - Action: Use `TextDetector` when available; otherwise use a local WASM OCR fallback with throttled cadence; output geometry/stats only and discard recognized text.
  - User story link: Finds likely sensitive text regions without persisting their contents.
  - Depends on: Tasks 4 and 8.
  - Validate with: static fixture/browser smoke where feasible and no-OCR-text persistence checks.
  - Notes: If neither detector path is viable, block text privacy capture.

- [ ] Task 10: Implement temporal redaction tracking.
  - File: `app/lib/data/services/web/browser_redaction_tracker.dart`
  - Action: Persist boxes across nearby frames, expand margins, merge overlapping boxes, expire stale boxes, and apply conservative behavior during scroll or dropped analysis.
  - User story link: Prevents readable text flashes during dynamic browser capture.
  - Depends on: Task 9.
  - Validate with: unit tests for merge, expiry, expansion, and dropped-frame behavior.
  - Notes: This is required for fast scrolling and transitions.

- [ ] Task 11: Implement Canvas/OffscreenCanvas redaction rendering.
  - File: `app/lib/data/services/web/browser_redaction_renderer.dart`
  - Action: Apply blur, pixelate, and scramble overlays to detected boxes on redacted frames using Canvas/OffscreenCanvas; preserve surrounding UI layout.
  - User story link: Produces visually understandable but unreadable privacy output.
  - Depends on: Tasks 8-10.
  - Validate with: browser visual smoke on dense text pages and screenshots.
  - Notes: Pixelation should use reduced-resolution redraw with smoothing disabled; scramble should cover real pixels with fake glyphs/lines.

- [ ] Task 12: Implement flattened redacted export paths.
  - File: `app/lib/data/services/web/browser_redacted_exporter.dart`
  - Action: Export redacted frames using WebCodecs when viable or a redacted Canvas stream with MediaRecorder fallback; register only finalized redacted assets with accurate MIME/extension metadata.
  - User story link: Ensures share/export receives a flattened redacted media file, not clear source plus overlays.
  - Depends on: Tasks 8 and 11.
  - Validate with: manual browser recording export, MIME/extension checks, and failure-path tests where feasible.
  - Notes: Do not claim MP4 if the actual browser output is WebM.

- [ ] Task 13: Include privacy metadata in capture/content payloads.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Include privacy status/settings/review state/engine metadata when creating or attaching content from captures; exclude OCR text, clear frames, and local clear paths.
  - User story link: Preserves privacy context when a capture becomes content.
  - Depends on: Task 1.
  - Validate with: targeted API payload tests if existing patterns support it.
  - Notes: No backend schema change expected.

- [ ] Task 14: Update tests, docs, and browser QA notes.
  - File: `app/test/data/capture_asset_test.dart`, `app/test/data/capture_local_store_test.dart`, `app/test/presentation/screens/capture/capture_screen_test.dart`, `app/README.md`, `shipglows_data/technical/app/guidelines.md`, `app/CHANGELOG.md`
  - Action: Cover privacy metadata parsing, review-state persistence, disclosure UI, share/export gating, normal Android unaffected behavior, and document web-only best-effort browser limits.
  - User story link: Keeps the shipped feature honest, testable, and aligned with product guarantees.
  - Depends on: Tasks 1-13.
  - Validate with: targeted Flutter tests, `flutter analyze`, browser manual QA checklist.
  - Notes: Manual QA remains mandatory because tests cannot prove real-world redaction quality.

## Acceptance Criteria

- [ ] CA 1: Given a user opens Capture in a browser with `getDisplayMedia` support, when privacy mode is enabled, then privacy controls and a best-effort disclosure appear before capture starts.
- [ ] CA 2: Given a browser lacks `getDisplayMedia`, when the user opens Capture, then browser privacy capture is shown as unsupported and no misleading start action is enabled.
- [ ] CA 3: Given privacy mode is enabled, when the user starts capture, then ContentGlowz invokes the browser chooser through `getDisplayMedia()` from the user action.
- [ ] CA 4: Given the user cancels the browser chooser, when control returns to ContentGlowz, then no asset is created and the UI shows a recoverable canceled state.
- [ ] CA 5: Given `TextDetector` is available, when text is detected in captured frames, then only geometry is used for redaction and recognized text is not persisted.
- [ ] CA 6: Given `TextDetector` is unavailable and OCR WASM fallback loads successfully, when privacy capture runs, then text redaction uses the fallback with throttled analysis and performance-safe status messaging.
- [ ] CA 7: Given no viable text detection path exists, when privacy capture is requested, then capture is blocked instead of recording clear output.
- [ ] CA 8: Given text style is `scramble`, when text boxes are detected, then real text pixels are covered and fake glyph/line fragments are rendered in the output.
- [ ] CA 9: Given text style is `blur` or `pixelate`, when text boxes are detected, then the region plus margin is unreadable in the exported preview.
- [ ] CA 10: Given a page scrolls quickly during recording, when OCR cadence skips frames, then recent boxes persist/expand and obvious clear-text flashes are not visible in manual review.
- [ ] CA 11: Given WebCodecs export succeeds, when recording completes, then the registered asset is flattened, redacted, privacy-marked, and uses accurate MIME/extension metadata.
- [ ] CA 12: Given WebCodecs is unavailable and MediaRecorder fallback succeeds, when recording completes, then the registered asset is still flattened, redacted, privacy-marked, and honestly labeled with the actual browser output format.
- [ ] CA 13: Given export or encoding fails, when the flow returns to idle, then no misleading privacy asset is listed and temporary clear resources are revoked/deleted where possible.
- [ ] CA 14: Given a privacy asset has `reviewState=needsReview`, when the user attempts share/export/content attachment, then ContentGlowz blocks the action until review acknowledgement.
- [ ] CA 15: Given the user acknowledges review, when share/export/content attachment continues, then only the flattened redacted asset and privacy metadata are used, with no OCR text or clear frame data.
- [ ] CA 16: Given privacy mode is disabled, when existing Android capture flows are used, then existing Android support and behavior remain unchanged.

## Test Strategy

- Dart unit tests:
  - `capture_asset_test.dart` for backwards-compatible parsing, privacy fields, engine metadata, and review state.
  - `capture_local_store_test.dart` for review-state persistence and metadata-only updates.
  - targeted service tests using fake browser capture clients for event order and failure codes.
- Flutter widget tests:
  - Capture screen shows browser privacy controls only when web capabilities support them.
  - Disclosure blocks capture until accepted.
  - Share/export/content attachment gate blocks `needsReview` privacy assets until acknowledgement.
  - Normal Android-oriented capture controls remain compatible.
- Browser implementation checks:
  - Capability detection tests for absent APIs using fakes where possible.
  - Tracker unit tests for box merge, expiry, margin expansion, and dropped-frame behavior.
  - Export tests or manual assertions for MIME/extension consistency.
- Manual browser QA:
  - Chromium-based browser capture of one tab and one full screen/window where available.
  - Fast scrolling in a text-heavy browser page.
  - Dense tables, email-like list, chat-like page, address-bar-adjacent content, and image-heavy page.
  - `TextDetector` path where available.
  - OCR WASM fallback path where `TextDetector` is unavailable or disabled.
  - MediaRecorder fallback path.
  - Browser stop-sharing control.
  - Review-before-share/export gate.
  - Confirm no OCR text appears in logs, metadata, backend payloads, or local asset JSON.
- Validation commands:
  - `flutter test test/data/capture_asset_test.dart test/data/capture_local_store_test.dart test/presentation/screens/capture/capture_screen_test.dart`
  - `flutter analyze`
  - `flutter build web`
  - Manual browser QA checklist from this spec.

## Risks

- Browser compatibility risk: core APIs vary significantly across Chromium, Firefox, and Safari.
- Performance risk: OCR WASM plus frame rendering and encoding may be too slow on low-end devices.
- Privacy miss risk: OCR may miss small, stylized, moving, image-embedded, low-contrast, or non-Latin text.
- Weak-redaction risk: visually pleasant blur or pixelation may remain inferable if too light.
- Export-container risk: MediaRecorder output format differs by browser and may not be MP4.
- Cleanup risk: temporary `VideoFrame`, Blob, canvas, or object URL state can outlive cancellation if lifecycle handling is incomplete.
- Trust risk: users may overestimate the protection unless UI copy repeatedly states best-effort and review required.
- QA risk: automated tests cannot prove that arbitrary real-world screen content is safe to publish.

## Execution Notes

Read first:

- `shipglows_data/workflow/explorations/2026-05-08-web-privacy-capture-redaction.md`
- `shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md`
- `app/lib/data/services/device_capture_service.dart`
- `app/lib/presentation/screens/capture/capture_screen.dart`
- `app/lib/data/models/capture_asset.dart`

Implementation approach:

1. Add model/storage metadata and review state first.
2. Introduce a browser-specific capture client path behind runtime capability checks.
3. Add Capture UI controls, disclosure, and share/export/content attachment gating.
4. Build capability detection and no-op/fakeable browser service contracts before real frame work.
5. Implement frame processor, detector, tracker, renderer, and exporter in small pieces.
6. Validate with targeted Flutter tests, web build, then manual browser QA.

Constraints for implementers:

- Do not implement Windows, iOS, Linux, Electron, Tauri, or native desktop capture in this chantier.
- Do not send captured frames or OCR content to the backend.
- Do not store OCR text in logs, metadata, local storage, analytics, or payloads.
- Do not claim guaranteed anonymization.
- Do not register clear or partially processed assets as privacy assets.
- Do not claim MP4 if the browser only exported WebM.
- Stop and rescope if no available browser export path can produce flattened redacted media without exposing clear output.

Fresh external docs: `fresh-docs checked via exploration` on 2026-05-08 using official MDN, W3C, Chrome, and Tesseract sources listed in `Dependencies`.

## Open Questions

- None blocking for V1. Product decisions fixed for this draft:
  - Browser/web only.
  - No Windows/iOS/Linux/native desktop parity.
  - Best-effort language, no percentage guarantee.
  - `getDisplayMedia()` chooser is mandatory and user-driven.
  - `TextDetector` is conditional; OCR WASM fallback is local and performance-gated.
  - Share/export/content attachment requires review acknowledgement.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-08 09:45:40 UTC | sf-spec | GPT-5 Codex | Created web/browser privacy capture dynamic redaction spec from exploration, Android privacy spec style, and local capture code anchors. | draft saved | /sf-ready web privacy capture dynamic redaction |

## Current Chantier Flow

sf-spec done -> sf-ready not launched -> sf-start not launched -> sf-verify not launched -> sf-end not launched -> sf-ship not launched
