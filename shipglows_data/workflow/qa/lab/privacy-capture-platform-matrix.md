# Privacy Capture Platform QA Matrix

Created: 2026-05-08  
Scope: cross-platform QA matrix for dynamic privacy capture redaction. This is a QA artifact only; it does not define implementation scope.

## QA Principles

- Treat every platform as best-effort privacy redaction, not guaranteed anonymization.
- A privacy asset is acceptable only when the final user-facing file is flattened and already redacted.
- OCR text, clear frames, clear thumbnails, and clear local paths must not be persisted, logged, exported, or sent to backend metadata.
- Share, export, download, and content attachment must be blocked until the user acknowledges manual review.
- If detection, rendering, encoding, consent, protected-content handling, or cleanup cannot be trusted, stop the attempt and do not register a misleading privacy asset.

## Platform Matrix

| Platform | Status | Capture source | Detection/redaction path | Export target | QA priority | Primary evidence expected | Stop conditions |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Android | Draft spec | MediaProjection with user consent | ML Kit Text Recognition, ML Kit Face Detection, temporal boxes, blur/pixelate/scramble | Flattened PNG/MP4 in app-scoped storage | P0 | Real-device video/screenshot, metadata dump, share gate proof, temp cleanup proof | MediaProjection denied/stopped, ML Kit unavailable, OCR lag exposes readable text, clear asset appears in history/share, temp cleanup fails without quarantine |
| Web | Draft spec | `getDisplayMedia()` browser chooser | TextDetector where available, local WASM OCR fallback, Canvas/OffscreenCanvas, WebCodecs or MediaRecorder | Flattened browser export, actual MIME labeled honestly | P0 Chromium, P1 other browsers | Browser recording, capability report, exported file inspection, object URL/blob cleanup notes | Capture denied, OCR unavailable when text redaction required, encoder fails, clear stream/blob becomes shareable, browser only supports unsafe partial flow |
| Windows | Draft spec and exploration | Windows.Graphics.Capture picker | Windows.Media.Ocr, Direct3D/Win2D effects, temporal boxes, optional visual heuristics | Flattened PNG/MP4 | P0 | Windows screen recording, OCR/redaction overlay evidence, multi-DPI coordinate proof, temp directory inspection | Picker canceled, protected content blank/degraded, OCR/encoding/device loss failure, DPI drift leaves readable text, partial/clear file registered |
| iOS | Exploration only | ReplayKit sample buffers or broadcast flow | Vision text/face detection, Core Image/Metal redaction, AVAssetWriter | Flattened local MP4/PNG | P1 until spec exists | Device capture recording, ReplayKit consent/indicator proof, Vision boxes redacted, final asset review gate | ReplayKit unavailable/stopped, AVAssetWriter fails, protected playback behavior unclear, live pipeline falls back to clear persisted source |
| Linux | Exploration only | xdg-desktop-portal ScreenCast/PipeWire; X11 fallback on Xorg only | Tesseract/OpenCV/PaddleOCR candidates, GStreamer/GL redaction, temporal boxes | Flattened MP4/Matroska or documented container | P1 Wayland portal, P2 X11 fallback | Desktop environment matrix, PipeWire stream proof, encoded redacted file, temp/cache inspection | Portal unavailable, user denies source selection, PipeWire/GStreamer stalls, OCR lag exposes text, X11 fallback used on unsupported Wayland path |
| macOS | Placeholder | Not explored | Not explored | Not defined | P2 gap tracking only | Exploration/spec reference before executable QA | Do not claim support; do not expose startable privacy capture controls without exploration/spec |

## Scenario Matrix

| Scenario | Priority | Android | Web | Windows | iOS | Linux | macOS | Evidence expected | Stop conditions |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Consent and disclosure | P0 | MediaProjection consent follows best-effort disclosure | Browser chooser opens from user gesture after disclosure | Windows picker opens after disclosure | ReplayKit system consent/indicator visible | Portal source picker visible | Placeholder unsupported | Screen recording or screenshots of disclosure plus OS chooser; no capture starts before consent | Capture starts silently, permission persists unexpectedly, disclosure omits best-effort/review language |
| Fast scroll text | P0 | Messaging/browser scroll keeps boxes alive between OCR frames | Dense webpage scroll does not flash readable text between OCR cycles | Browser/app scroll works across DPI scale | ReplayKit scroll test with Vision cadence | Wayland PipeWire scroll with OCR cadence | Not covered | Redacted recording slowed/frame-stepped; processing stats showing OCR cadence and box persistence | Any readable private text flashes in final asset, tracker drops boxes during normal scroll |
| Dense OCR text | P0 | Small text, URLs, names, messages obscured | Tab/screen with URLs, email, dashboard text obscured | Browser/terminal/dashboard text obscured | Notes/messages/browser text obscured | Browser/terminal text obscured | Not covered | Before/after local QA notes; final asset only; no OCR text in logs/metadata | OCR text stored, logs include recognized words, clear text remains readable in final export |
| Photo/image regions | P1 | Photo style blur/pixelate works without full-screen mask by default | Image-heavy page redacts selected visual regions or clearly labels limitation | Image-like regions redacted where V1 supports heuristics | Vision/Core Image visual redaction validated if implemented | OpenCV/PaddleOCR visual path validated if implemented | Not covered | Final asset with photo regions obscured; settings metadata shows visual style | UI implies photo safety when detector is absent; unredacted faces/photos pass under enabled photo mode without warning |
| Faces | P0 Android, P1 others | ML Kit Face Detection boxes cover faces | Browser face support only if implemented/fallback documented | V2/optional detector unless implemented; otherwise gap | Vision face rectangles if in scope | OpenCV face detector if in scope | Not covered | Face test clip with final frames reviewed; detector availability recorded | Face redaction toggle is exposed but unavailable, or face boxes are missed without degraded warning |
| Protected content | P1 | Black/omitted protected frames treated as platform behavior | Browser restrictions/black frames labeled honestly | Protected target blank/degraded labeled honestly | Protected AVPlayer/ReplayKit gaps documented | Portal/compositor restrictions documented | Not covered | Attempt log/status showing degraded/failed state; no false "redacted" success | Blank/omitted content is marketed as successful redaction, or failed capture registers normal asset |
| Temporary clear files | P0 | App-private only; deleted or quarantined; never recent/shareable | Clear VideoFrame/canvas/blob/object URL released/revoked | App-private temp only; deleted or quarantined | Avoid clear persisted source; if fallback exists, explicitly blocked/reviewed | No clear cache by default; temp artifacts inspected | Not covered | Filesystem/storage inspection; metadata proves no clear local path; cleanup warning on failure | Clear file appears in recent captures/export picker/backend metadata, deletion failure is silent |
| Export/share gate | P0 | `reviewState=needsReview` blocks Android intents | Download/share/content attach blocked until review | OS share/export path blocked until review | iOS share sheet blocked until review | Desktop export/content attach blocked until review | Not covered | UI recording showing block, acknowledgement, then only redacted file shared | Any privacy asset can be shared before review, or share uses clear source path |
| Review playback | P0 | Preview plays flattened redacted PNG/MP4 only | Browser preview uses redacted blob/file only | Preview uses redacted PNG/MP4 only | Preview uses redacted AVAsset output only | Preview uses encoded redacted output only | Not covered | Final preview inspection; no overlay-only redaction layers | Preview depends on clear media plus reversible overlay, or clear thumbnail is generated |
| Backend/content metadata | P0 | Privacy settings and aggregate stats only | Same | Same | Same when implemented | Same when implemented | Not covered | Captured payload/log inspection with no OCR text, no clear paths, no frame thumbnails | OCR text, local clear path, temp path, or clear thumbnail leaves device |
| Performance degradation | P1 | Lower cadence/expand boxes; stop if incoherent | Lower cadence/fallback engine; stop if unsafe | Lower cadence/rebuild resources; stop if unsafe | Back-pressure handled; stop if unsafe | GStreamer/OCR latency handled; stop if unsafe | Not covered | Device/browser stats, dropped-frame notes, degraded notices in UI | App saves "privacy" asset after pipeline fell behind enough to expose readable content |
| Normal capture regression | P1 | Privacy off keeps existing capture behavior | Existing unsupported/normal web behavior changes only by intended web support | Privacy off isolated from Android path | Platform unsupported until implementation | Platform unsupported until implementation | Unsupported | Baseline normal capture smoke results | Privacy work breaks normal capture or changes metadata for non-privacy assets unexpectedly |

## Platform-Specific QA Notes

### Android

- Run on a real Android device; emulators cannot prove MediaProjection lifecycle, performance, or share behavior.
- Cover screenshot and recording separately.
- Test at least one messaging app, one browser page, one image-heavy feed, and one fast scroll.
- Inspect local capture history to prove no clear asset was registered.
- Validate Android stop cases: consent denied, projection stopped from system UI, app background/lock interruption, and ML Kit unavailable/failing.

### Web

- Start with current Chromium desktop as P0 because support for frame processing, WebCodecs, and shape detection varies.
- Record browser capability decisions in evidence: `getDisplayMedia`, frame processor path, OCR engine, render path, encoder/export path, and MIME.
- Test cancellation from the browser chooser and track stop from browser UI.
- For non-Chromium browsers, classify as supported, degraded, or unsupported based on runtime feature detection; do not infer parity.

### Windows

- Validate on real Windows hardware or a VM with graphics acceleration.
- Include one 100% scaling monitor and one mixed-DPI or multi-monitor case before calling Windows P0 complete.
- Test target resize, target close, target move across monitors, and protected/blank content.
- Inspect temp directories and recent capture metadata after encoder failure and normal success.

### iOS

- Treat as exploratory until a formal spec exists.
- Prefer live or close-to-live ReplayKit redaction evidence; post-production from a clear source is not acceptable without explicit quarantine and product review.
- Validate recording indicator/consent UX, ReplayKit stop behavior, Vision text boxes, Vision face boxes if enabled, and AVAssetWriter finalization.

### Linux

- Split QA by session type and desktop environment: Wayland portal/PipeWire first, Xorg fallback separately.
- Capture portal version/backend, PipeWire stream details, GStreamer pipeline/export container, and OCR engine used.
- Stop unsupported Wayland sessions cleanly instead of falling back to X11-only assumptions.
- Treat X11 fallback as P2 compatibility unless product explicitly chooses it for V1.

### macOS

- No local exploration/spec source is available in this task.
- QA is limited to verifying unsupported UI behavior and tracking the gap.
- Do not add executable macOS privacy capture scenarios until a macOS exploration/spec defines capture API, redaction path, temp-file policy, and export contract.

## Required Evidence Pack

For each platform marked supported or degraded, attach or record:

- Platform version, device/browser/desktop environment, resolution, refresh rate, and scaling/DPI where relevant.
- Capture source type: full screen, window, tab, monitor, or app.
- Redaction settings: text style, photo/visual style, face setting, strength, OCR cadence/performance profile.
- Final exported file path or artifact ID for the flattened redacted asset only.
- Metadata snapshot proving `privacyMode=true`, redaction status, review state, platform, engines, aggregate stats, and no OCR text or clear paths.
- Logs or payload inspection proving no recognized text, clear thumbnails, clear frame paths, temp paths, or clear asset IDs are persisted or sent.
- Cleanup evidence for temp files, blobs, object URLs, GPU/CPU buffers where inspectable.
- Screen recording of review gate blocking share/export until acknowledgement.

## Global Stop Conditions

Stop the test run and file a P0 issue if any of these occur:

- A clear screenshot, video, frame, thumbnail, blob, or temp file appears in normal capture history, preview, share, export, or backend metadata.
- Recognized OCR text is persisted, logged, sent to backend, or visible in analytics/debug output.
- A privacy-marked asset can be shared, downloaded, exported, or attached before review acknowledgement.
- The final output relies on a clear source plus reversible overlay instead of flattened redacted pixels.
- The pipeline falls behind and saves a privacy asset with readable text flashes under normal scroll.
- A failed consent, capture, OCR, render, encode, or cleanup state still registers a successful privacy asset.
- UI copy or metadata implies guaranteed anonymization, exhaustive protection, or full responsibility for every leak.

## Gaps Not Covered

- macOS has exploration input but no spec yet; QA remains provisional until a macOS spec defines product contracts and implementation details.
- Android, Web, and Windows specs are draft; scenario details may need revision once implementation chooses exact engines and metadata field names.
- iOS and Linux are explorations only; priorities are provisional until specs define product contracts.
- Automated tests can verify service contracts, metadata, and share gates, but cannot prove frame-level privacy quality.
- Face/photo detection is uneven across platforms; Android has the clearest V1 path, while Windows/Linux/Web/iOS need implementation-specific detector decisions.
- Protected content behavior differs by OS/browser/compositor and should be documented as platform behavior, not redaction success.
- Performance thresholds are not defined here; QA must record degradation and stop behavior until product sets device/browser support floors.
