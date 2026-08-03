---
artifact: research
project: "contentglowz"
created: "2026-05-07"
updated: "2026-05-07"
status: reviewed
source_skill: sf-research
scope: "Android technologies for privacy screen recording with text scrambling, blur, and photo pixelation"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
source_count: 13
evidence:
  - "Android MediaProjection documentation"
  - "Android MediaCodec and MediaMuxer API references"
  - "AndroidX Media3 Transformer and Effect documentation"
  - "Google ML Kit Text Recognition v2 documentation"
  - "Google ML Kit Object Detection, Image Labeling, and Face Detection documentation"
  - "Android AccessibilityService API and Google Play AccessibilityService policy"
  - "FFmpegKit retirement notice"
next_step: "/sf-spec Android privacy capture mode with dynamic redaction"
---

# Research: Android Privacy Screen Redaction Technologies

Generated 2026-05-07. Scope: Android only.

## Executive Summary

For ContentGlowz's Android-only privacy capture mode, the best technical direction is a native Kotlin pipeline built on `MediaProjection` + GPU rendering/OpenGL + `MediaCodec` + `MediaMuxer`, with ML Kit Text Recognition v2 providing text bounding boxes and ML Kit Face Detection/Object Detection/Image Labeling used selectively for photos and sensitive visual regions.

Do not base V1 on character rewriting in third-party apps. For arbitrary apps, "scramble" should be visual: detect text regions in pixels or accessibility nodes, cover the real text, then draw fake scrambled glyphs or apply strong blur/pixelation. Do not rely on FFmpegKit for a new Android implementation because the project is officially retired.

## Current Project Context

ContentGlowz currently has an Android MediaProjection capture implementation. The normal recording path uses native Android screen capture and stores local PNG/MP4 assets. A privacy mode should not merely add a Flutter overlay after the fact; it needs a native path that can transform frames before the final export is considered safe.

## Technology Findings

### Capture Input: Android MediaProjection

Android's MediaProjection APIs capture display or app-window contents as a media stream and project the captured image to a virtual display rendered on an app-provided `Surface`. Android documentation explicitly lists `MediaRecorder`, `SurfaceTexture`, and `ImageReader` as possible consumers.

Verdict: keep MediaProjection. For normal capture, `MediaRecorder` is fine. For privacy capture, use `SurfaceTexture`/GPU or `ImageReader` so ContentGlowz can inspect and alter frames before encoding.

Source: Android MediaProjection docs.

### Video Output: MediaCodec + MediaMuxer

`MediaCodec` supports video encoders with an input `Surface` via `createInputSurface()`. `MediaMuxer` writes encoded elementary streams into containers such as MP4.

Verdict: for live/privacy mode, prefer `MediaCodec` + `MediaMuxer` over `MediaRecorder`, because `MediaRecorder` is too direct: screen pixels go into the MP4 without a clean per-frame edit step.

Source: Android MediaCodec and MediaMuxer API references.

### GPU Rendering And Effects

Media3 Transformer is designed for media editing/transcoding, supports custom effects, uses MediaCodec for hardware-accelerated encode/decode, and uses OpenGL for graphical modifications. Media3 also exposes video effects such as `GaussianBlur` and a `GlEffect` interface.

Verdict: use Media3 Transformer for post-production redaction/export if starting from an existing file. For real-time privacy capture, expect a custom OpenGL/MediaCodec pipeline or a careful Media3 spike; Media3 is excellent for post-processing, but less directly aligned with a live MediaProjection source.

Source: AndroidX Media3 Transformer and Effect docs.

### Text Detection: ML Kit Text Recognition v2

ML Kit Text Recognition v2 supports text extraction from images and video. It accepts `InputImage` from `Bitmap`, `media.Image`, `ByteBuffer`, byte array, or file. It returns text structure with blocks, lines, elements, symbols, bounding boxes, corner points, rotation, and confidence. Google recommends throttling detector calls in real-time pipelines and rendering detector output plus overlay in one step.

Verdict: best V1 default for text detection. Use bundled Latin first for predictable startup, then add Chinese/Japanese/Korean/Devanagari modules if product scope requires them. Do not store recognized text; store only rectangles and anonymization metadata.

Source: Google ML Kit Text Recognition v2 docs.

### Scroll Handling

ML Kit guidance says real-time apps should throttle detector calls and drop frames while detection is busy. That means OCR should not run on every 30/60 fps frame. The privacy pipeline should combine:

- OCR every N frames or when the scene changes.
- Temporal persistence: keep redaction boxes active for several frames after detection.
- Box expansion margins.
- Motion/scroll tracking to move boxes between OCR runs.
- More aggressive blur during high-motion periods.

Verdict: dynamic redaction is feasible as best-effort, but not perfect. Scroll quality depends on temporal tracking, not just OCR accuracy.

Source: Google ML Kit Text Recognition performance guidance.

### Photo And Face Redaction

ML Kit Face Detection gives face bounding boxes and supports video/image inputs. ML Kit Object Detection can detect and track up to five objects per image in video streams and provides tracking IDs. ML Kit Image Labeling can label 400+ image categories, but it does not itself solve "find every photo rectangle in a UI".

Verdict: for "blur/pixelize photos", combine multiple signals:

- Accessibility node bounds for image-like UI elements when available.
- Heuristics for large rectangular image/card regions in the screen frame.
- Face detection inside those regions.
- Object/image labeling as an optional signal, not the core detector.

For visual quality, pixelate or blur only the photo area while keeping the app layout visible.

Sources: ML Kit Face Detection, Object Detection, and Image Labeling docs.

### Accessibility Overlay For Third-party Apps

Android AccessibilityService can retrieve window content as `AccessibilityNodeInfo` trees when configured, and accessibility overlays can be attached to windows or displays. Google Play permits AccessibilityService use but requires disclosure, consent, and declaration/review for non-accessibility-tool apps.

Verdict: AccessibilityService is the strongest optional V2 accelerator for Google Messages/browser-style screens because it may provide text/image bounds before OCR. It is not a Google Messages plugin and it cannot rewrite the app UI. It should be optional and separately consented.

Sources: Android AccessibilityService API, Google Play AccessibilityService policy.

### Google Messages Plugin Feasibility

No official source found for a third-party Google Messages client UI plugin that can scramble the displayed UI. Google RCS Business Messaging APIs are for business agents sending messages through RCS services, not for modifying the consumer Google Messages interface.

Verdict: do not plan around a Google Messages plugin. Plan around AccessibilityService + pixel overlay/redaction.

Source: Google RCS Business Messaging API docs.

### OCR Alternatives

Tesseract Android wrapper `tess-two` is archived and explicitly no longer maintained. PaddleOCR has Android/on-device deployment documentation and a stronger modern OCR stack, but requires a heavier native deployment with multiple models and C++/Paddle Lite integration.

Verdict: use ML Kit first. Consider PaddleOCR only after a dedicated spike if ML Kit misses too much text in screen UI. Avoid tess-two for V1.

Sources: tess-two GitHub archive notice, PaddleOCR on-device deployment docs.

### FFmpeg / FFmpegKit

FFmpegKit is officially retired; older binaries were scheduled for removal in 2025. It can still inspire command-line-style post-processing, but it is a poor foundation for a new production Android app dependency.

Verdict: avoid FFmpegKit as the primary implementation. Use Android native MediaCodec/MediaMuxer and Media3 Transformer instead.

Source: FFmpegKit retirement notice.

## Recommended Architecture

```text
MediaProjection
   -> VirtualDisplay
   -> SurfaceTexture or ImageReader
   -> frame analyzer queue
      -> ML Kit text boxes
      -> optional AccessibilityService boxes
      -> optional face/photo detectors
      -> temporal tracker
   -> GPU compositor
      -> draw original frame
      -> apply blur/pixelation/scramble overlays on sensitive boxes
   -> MediaCodec video encoder input Surface
   -> MediaMuxer MP4
   -> redacted local asset
```

## Product Recommendation

### V1: Privacy Capture Beta

- Android only.
- Normal mode remains unchanged.
- Privacy mode uses a separate native pipeline, not the existing direct `MediaRecorder` pipeline.
- Text mode choices:
  - `Scramble`: cover text and draw fake glyphs/lines.
  - `Blur`: strong localized blur.
  - `Pixelate`: blocky mosaic.
- Photo mode choices:
  - `Blur photos`
  - `Pixelate photos`
  - `Blur faces`
- Run ML Kit OCR at a throttled cadence.
- Use temporal smoothing and margin expansion for scroll.
- Require post-production review before export/share.
- Mark output metadata as `privacy_best_effort`.

### V2: Accessibility-assisted Redaction

- Optional AccessibilityService for better bounds in Google Messages, browsers, and other apps that expose nodes.
- Separate prominent disclosure and affirmative consent.
- Play Console declaration and review preparation.
- Never upload or store recognized text; use local rectangles only.

### V3: Stronger OCR / Custom Models

- Evaluate PaddleOCR mobile if ML Kit misses too many screen-text cases.
- Evaluate custom TensorFlow Lite text-region detector trained on mobile UI screenshots.
- Keep this behind a spike because model size, latency, and native complexity are significant.

## Implementation Notes

- The implementation belongs in native Android Kotlin/Kotlin + OpenGL/MediaCodec, coordinated from Flutter through platform channels.
- Do not process every frame with OCR. Process selected frames and track boxes between them.
- During fast scroll, expand boxes and keep them alive longer to avoid flashes of clear text.
- Use stronger redaction than visual blur alone for high-risk text. A nice-looking blur can still be inferable if it is too light.
- Export only the flattened redacted MP4 for upload. The final MP4 should not contain an edit history or hidden clear-text layer.
- Keep any clear temporary frames/files in app-private storage, mark them temporary, and delete them as soon as the redacted output is produced.

## Sources

- Android MediaProjection documentation: https://developer.android.google.cn/media/grow/media-projection
- Android MediaCodec API reference: https://developer.android.com/reference/android/media/MediaCodec
- Android MediaMuxer API reference: https://developer.android.com/reference/android/media/MediaMuxer
- AndroidX Media3 Transformer: https://developer.android.google.cn/media/media3/transformer
- AndroidX Media3 Effect API: https://developer.android.com/reference/androidx/media3/common/Effect
- AndroidX Media3 GaussianBlur: https://developer.android.com/reference/androidx/media3/effect/GaussianBlur
- ML Kit Text Recognition v2 Android: https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- ML Kit Object Detection Android: https://developers.google.cn/ml-kit/vision/object-detection/android
- ML Kit Face Detection Android: https://developers.google.com/ml-kit/vision/face-detection/android
- ML Kit Image Labeling Android: https://developers.google.cn/ml-kit/vision/image-labeling/android
- Android AccessibilityService API: https://developer.android.com/reference/android/accessibilityservice/AccessibilityService.html
- Google Play AccessibilityService policy: https://support.google.com/googleplay/android-developer/answer/10964491
- FFmpegKit retirement notice: https://arthenica.github.io/ffmpeg-kit/
- PaddleOCR on-device deployment: https://www.paddleocr.ai/v3.0.3/en/version3.x/deployment/on_device_deployment.html
- tess-two archive notice: https://github.com/rmtheis/tess-two
