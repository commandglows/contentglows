---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-05-06"
updated: "2026-05-06"
status: draft
source_skill: sf-explore
scope: "Privacy-preserving text obfuscation for arbitrary Android whole-screen capture"
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - "app Flutter capture UI"
  - "app Android MediaProjection native capture"
  - "app local capture storage"
  - "app capture/content asset linking"
evidence:
  - "shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md defines Android MediaProjection local-only PNG/MP4 capture."
  - "shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md keeps media local and stores only asset metadata server-side."
  - "app/lib/data/services/device_capture_service.dart exposes takeScreenshot/startRecording through platform channels."
  - "app/android/app/src/main/kotlin/com/contentglows/app/capture/* records actual screen pixels through MediaProjection surfaces."
  - "Android documentation requires user consent per MediaProjection session and treats a session as one createVirtualDisplay call."
  - "shipglows_data/workflow/research/shared/android-privacy-screen-redaction-technologies.md validates Android-native ML Kit/MediaCodec/MediaMuxer/Media3 technology choices for privacy redaction."
depends_on:
  - "shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md"
  - "shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md"
supersedes: []
next_step: "/sf-spec privacy mode for screen capture text obfuscation"
---

# Exploration Report: Screen Text Obfuscation

## Starting Question

For confidentiality, all text visible in whole-device screen recordings should become unreadable across arbitrary apps: messaging, browser, third-party apps, system screens, and ContentGlows. Should ContentGlows transform text before recording, during recording, or after recording, and should the app add a character-scrambling feature?

## Context Read

- `shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md` - Confirms V1 is Android MediaProjection, local-only, with screenshot and recording outputs saved as PNG/MP4.
- `shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md` - Confirms captures may be linked to content but raw files remain local in V1.
- `app/lib/data/services/device_capture_service.dart` - Shows Flutter only starts/stops native capture and receives completed asset metadata.
- `app/lib/presentation/screens/capture/capture_screen.dart` - Shows the current user workflow has capture controls, local history, share, discard, and content attachment.
- `app/android/app/src/main/kotlin/com/contentglows/app/capture/*` - Shows native code captures rendered pixels through MediaProjection, VirtualDisplay, ImageReader, and MediaRecorder.

## Internet Research

- [Android Media projection](https://developer.android.com/guide/topics/large-screens/media-projection) - Accessed 2026-05-06 - Used to confirm per-session consent, Android 14 token behavior, foreground service requirements, and whole-display/app-window capture behavior.
- [Android MediaProjection API reference](https://developer.android.com/reference/android/media/projection/MediaProjection.html) - Accessed 2026-05-06 - Used to confirm callback/resource lifecycle expectations.
- [Android capture video and audio playback](https://developer.android.com/media/platform/av-capture) - Accessed 2026-05-06 - Used to confirm platform-level capture restrictions and that device/admin/source apps can prevent capture.
- [Android AccessibilityService API reference](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService.html) - Accessed 2026-05-06 - Used to evaluate whether ContentGlows could observe third-party app text nodes and draw accessibility overlays.
- [Google Play AccessibilityService policy](https://support.google.com/googleplay/android-developer/answer/10964491) - Accessed 2026-05-06 - Used to evaluate consent, disclosure, declaration, and policy constraints if ContentGlows uses accessibility APIs.
- [Google RCS for Business documentation](https://developers.google.com/business-communications/rcs-business-messaging) - Accessed 2026-05-06 - Used to check whether Google messaging APIs are about business agent messaging, not modifying the Google Messages client UI.
- [Android privacy redaction technology research](../research/contentglows_other/android-privacy-screen-redaction-technologies.md) - Created 2026-05-07 - Used to select ML Kit Text Recognition, MediaProjection, MediaCodec/MediaMuxer, Media3 Transformer, and optional AccessibilityService as the likely implementation stack.

## Problem Framing

The sensitive object is not only the final exported video. It is every frame produced by MediaProjection, every local PNG/MP4 stored by the app, every preview rendered in ContentGlows, every share/export action, and any future AI/upload pipeline. If clear text ever reaches the recorded MP4, post-processing can reduce exposure in the shared copy but does not erase the fact that a sensitive local original existed.

The user clarified that the target is arbitrary whole-screen capture, not only recording ContentGlows. That means ContentGlows does not control the UI text source and cannot reliably "scramble characters" before display. MediaProjection receives rendered pixels, so the realistic problem is text-region detection and pixel masking/redaction across video frames.

The real requirement is therefore: prevent readable sensitive text from entering durable capture files whenever confidentiality mode is enabled, while being honest that arbitrary third-party screens cannot be perfectly sanitized without missed-detection risk.

## Option Space

### Option A: Pre-production Obfuscation Before Recording

Summary: The user prepares the screen before recording: demo data, fake accounts, browser extension, OS/app privacy mode, or ContentGlows-controlled presentation mode.

Pros:
- Best privacy posture when ContentGlows controls the displayed UI or demo content.
- No clear text enters the capture file.
- Lower compute cost than video processing.
- Easier to reason about for screenshots and recordings.

Cons:
- Cannot reliably transform text in third-party apps unless those apps support demo/privacy mode or an overlay approach is accepted.
- Character scrambling can break layout and make the demo harder to follow.
- Requires user discipline or a dedicated "privacy mode" workflow.

### Option B: During-capture Obfuscation In The Capture Pipeline

Summary: ContentGlows captures pixels and applies live blur/redaction before writing PNG/MP4.

Pros:
- Better than after-the-fact export if the raw clear stream is not persisted.
- Can produce only redacted files in ContentGlows storage.
- Could work for third-party screens if computer vision/text detection is accurate enough.

Cons:
- Hard on Android MediaProjection because the recorder currently writes the screen surface directly to MP4.
- Requires real-time OCR or text-region detection plus GPU/encoder processing.
- Risky for privacy: missed text boxes, fast scrolling, animation, notifications, small text, or transformed UI can leak.
- Adds battery, latency, and native complexity.

Notes for arbitrary screen capture:
- This is the only product direction that can plausibly support "whatever is on screen" while avoiding durable clear originals.
- The implementation cannot be character scrambling. It must be per-frame text detection plus blur/solid redaction of pixel regions.
- A practical V1 would likely use detection zones and conservative full-region masks before attempting automatic OCR-based redaction.

### Option C: Post-production Obfuscation After Recording

Summary: Record normally, then process the generated MP4/PNG to blur text before sharing or attaching.

Pros:
- Simplest to add as a workflow gate.
- Can be slower and more accurate than live processing.
- Lets the user review redaction before export.

Cons:
- The original local capture contains readable sensitive text.
- Requires strict handling of originals: encrypted local storage, automatic deletion, no preview of original, no accidental share.
- Still depends on OCR/detection quality if automatic.
- Not enough for high-confidentiality sessions where clear capture files must never exist.

### Option D: Manual Region Redaction

Summary: User draws persistent redaction zones before/during capture or masks areas after capture.

Pros:
- More reliable than OCR for known sensitive areas such as headers, account names, sidebars, tokens, emails, and notifications.
- Can be combined with pre-production or post-production.
- Easier to explain and test.

Cons:
- User can forget an area.
- Does not adapt automatically to scrolling or moving content.
- Requires UX for zones, preview, and validation.

### Option E: Third-party App "Plugin" Or Accessibility Overlay

Summary: Try to support apps like Google Messages by using a platform-level integration. There does not appear to be an official Google Messages plugin API that lets a third-party app rewrite or scramble the Messages UI. The closest Android-native option is an `AccessibilityService` that observes accessible text nodes/bounds and draws an overlay over them.

Pros:
- Could work across multiple apps that expose useful accessibility node text and bounds.
- Can produce a "scrambled text" visual by covering real text and drawing fake random glyphs in the same boxes.
- More targeted than full-frame OCR when apps expose accessible text nodes.
- Overlay can be user-visible before recording, so the user sees what will be masked.

Cons:
- It is not a Google Messages plugin and does not modify Google Messages itself.
- Requires the user to explicitly enable an accessibility service in Android settings.
- Requires prominent in-app disclosure, affirmative consent, and Google Play declaration/review if distributed through Play.
- Some apps may hide, omit, stale-cache, or virtualize accessibility node data.
- It can expose extremely sensitive data to ContentGlows, so local-only handling and clear consent are mandatory.
- It still needs OCR fallback or manual masks when accessibility nodes are unavailable.

## Comparison

Pre-production is the only approach that cleanly prevents sensitive text from entering the recording. During-capture transformation is attractive but technically risky for ContentGlows's current Android implementation because capture is native MediaProjection into recording surfaces. Post-production is useful as a safety net and export feature, but it is not the primary privacy boundary if original files persist.

Character scrambling is only appropriate as source-level rewriting for text that ContentGlows itself renders or text in a controlled demo environment. For arbitrary captured screens, "scrambling" must be implemented as a visual substitution: cover the real text pixels and optionally draw fake random glyphs on top. For third-party apps, ContentGlows cannot simply "replace characters"; it must mask pixels after detecting likely text regions, use accessibility-derived bounds, or rely on user-defined mask zones.

## Product Priority Update

The clarified product priority is not maximum secrecy at the cost of hiding large UI regions. The priority is public-facing videos that stay visually pleasant and understandable while making text materially harder to read. That favors dynamic text detection and selective blur/scramble over large static masks. Post-production review is accepted as part of the workflow.

Important technical clarification: a correctly rendered MP4/PNG does not contain an editing history or a hidden "pre-blur" layer. Once pixels are destructively blurred/redacted and the final video is exported as ordinary raster frames, the original text is not stored in the visible frame data. The residual risk comes from different sources: missed frames, weak blur/pixelation, compression artifacts, thumbnails/previews, metadata/sidecar files, OCR/transcript generation from unblurred frames, and contextual inference from the remaining UI.

## Emerging Recommendation

Build a "Privacy Capture Mode" with a layered approach. For arbitrary whole-device capture, the primary product behavior should be capture-time or immediate pre-save redaction, not source-text scrambling.

1. Primary for arbitrary public videos: dynamic text redaction pipeline.
   - Capture frames from MediaProjection.
   - Detect text-like regions frame-by-frame.
   - Apply selective blur, mosaic, or fake scrambled glyph overlays only around detected text.
   - Write only redacted frames to the saved PNG/MP4 when confidentiality mode is active.
   - Do not persist the clear recording as the normal asset.

2. Strong V1 candidate: visually pleasant privacy overlay.
   - Let the user enable "Scramble overlay" before recording.
   - Use full-region masks only as optional fallback for known high-risk areas.
   - Optionally use AccessibilityService to find text node bounds in apps like Google Messages and paint over those bounds.
   - Render fake scrambled glyphs over the mask if the user wants the UI to remain visually understandable.

3. Secondary: pre-capture hygiene.
   - Use demo/synthetic data where possible.
   - Disable notifications.
   - Prefer browser profiles/demo accounts.
   - Warn clearly that arbitrary text detection cannot be guaranteed.

4. Tertiary: capture-time masking for predictable areas.
   - Add configurable overlay/mask zones before the session.
   - Prefer blur/solid blocks over character scrambling for arbitrary screen pixels.
   - Ensure the mask is present in the pixels being recorded or applied before file write.

5. Final safety net: post-production redaction before share/export.
   - Auto-detect text regions where possible, then require user review.
   - Delete or quarantine the original clear file if confidentiality mode is enabled.
   - Store metadata that records whether the asset is redacted, original, or pending review.

For high-confidentiality recordings, do not rely on post-production alone.

## Non-Decisions

- No specific OCR library selected.
- No decision yet on whether to use FFmpeg/MediaCodec/OpenGL for video redaction.
- No decision yet on whether privacy mode applies only to ContentGlows screens or arbitrary device screens.
- No legal/compliance standard selected for retention, audit, or deletion requirements.

## Rejected Paths

- "Only scramble characters after recording" - Rejected as the primary privacy control because readable text already exists in the original capture.
- "Automatically guarantee all text is unreadable in any third-party app" - Rejected as an absolute promise because OCR/text detection can miss content and Android/source apps may restrict capture behavior. The product can offer best-effort redacted capture with conservative masks and review, but not a mathematical guarantee for arbitrary pixels.
- "Google Messages plugin that rewrites Messages text" - Rejected unless Google exposes a specific UI extension API. Current Google messaging developer docs are for business messaging agents/APIs, not modifying the consumer Messages client UI.
- "Silent background sanitization" - Rejected because Android MediaProjection requires explicit user consent and visible capture behavior.

## Risks And Unknowns

- OCR miss risk: small text, fast motion, scrolling, low contrast, non-Latin text, and stylized UI can bypass automatic detection.
- Original-file risk: post-processing creates a sensitive local original unless the pipeline writes only the redacted output.
- Weak-redaction risk: light blur or pixelation may still allow humans or models to infer text when the font, app UI, language, or message context is predictable.
- UX risk: too much obfuscation can make recordings useless for tutorials.
- Platform risk: Android capture behavior changes across API versions and OEMs.
- Scope risk: ContentGlows-owned UI obfuscation is tractable; arbitrary third-party app obfuscation is substantially harder.
- Policy risk: AccessibilityService can be a useful technical route but requires prominent disclosure, affirmative consent, Play Console declaration/review, and strict data-minimization. Misuse can block distribution.
- User trust risk: Showing a legal disclaimer is not enough. The UI must clearly show what is currently masked, what is not detected, and when post-production review is still required.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: This report summarizes architecture and privacy choices only. It does not include captured content, secrets, logs, or user data.

## Decision Inputs For Spec

- User story seed: As a creator recording an Android screen, I want a privacy capture mode that prevents readable sensitive text from appearing in saved captures, so I can safely create demos and assets.
- Scope in seed: privacy mode toggle, arbitrary-screen capture-time masking/redaction pipeline, pre-capture checklist, mask zones, optional accessibility overlay spike, redacted asset status, post-capture redaction review, original-file deletion/quarantine policy, user acknowledgements.
- Scope out seed: guaranteed redaction of every third-party app, cloud upload, legal compliance certification, automatic publication, direct Google Messages UI plugin unless an official API exists.
- Invariants/constraints seed: never claim guaranteed sanitization for arbitrary pixels; confidentiality mode must not expose clear originals through preview/share; all MediaProjection sessions still require Android consent; protected content may be blacked out by platform behavior; accessibility access must be separately disclosed and consented.
- Validation seed: screenshot privacy smoke, recording privacy smoke, Google Messages manual smoke if installed, browser manual smoke, original-file handling test, export-only-redacted test, manual third-party app redaction miss tests, Android real-device QA, Play policy review for accessibility usage.

## Handoff

- Recommended next command: `/sf-spec privacy mode for screen capture text obfuscation`
- Why this next step: The feature touches native capture, local storage, UX warnings, asset metadata, and privacy guarantees; it needs a spec before implementation.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-05-06 00:00:00 UTC | Before/during/after text obfuscation for screen recording | Read capture specs/code and Android docs, compared implementation options | Recommend layered privacy capture mode with pre-production as primary control | `/sf-spec privacy mode for screen capture text obfuscation` |
