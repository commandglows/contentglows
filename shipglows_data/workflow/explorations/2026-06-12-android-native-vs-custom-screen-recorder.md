---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-06-12"
updated: "2026-06-12"
status: draft
source_skill: "700-sf-explore"
scope: "Android screen recorder decision: reuse native system recorder UX vs build custom recorder on Android APIs"
owner: "Diane"
confidence: high
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - "app Flutter Android"
  - "app Android native Kotlin capture stack"
  - "Android MediaProjection"
  - "Android foreground services"
evidence:
  - "Existing Android capture implementation in app already uses MediaProjection via custom Kotlin services."
  - "Prior research for privacy capture concluded MediaProjection should stay, but direct MediaRecorder is too limited for transformed output."
  - "Android official docs confirm strict user-consent, single-use token, and visible projection constraints."
depends_on:
  - "shipglows_data/workflow/research/shared/android-privacy-screen-redaction-technologies.md"
  - "shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md"
supersedes: []
next_step: "/100-sf-spec Android custom recorder and live composition"
---

# Exploration Report: Android Native Recorder vs Custom Recorder

## Starting Question

Can ContentGlows rely on Android's native screen recording experience for stability and add differentiated features on top, or does the product need its own recorder pipeline?

## Context Read

- `shipglows_data/workflow/research/shared/android-privacy-screen-redaction-technologies.md` - prior Android capture research and pipeline recommendation.
- `shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md` - current product contract for Android capture.
- `app/android/app/src/main/kotlin/com/contentglows/app/capture/ScreenRecordService.kt` - current native recording implementation.
- `app/android/app/src/main/kotlin/com/contentglows/app/capture/ScreenCaptureChannel.kt` - Flutter/native boundary and permission flow.
- `app/lib/data/services/device_capture_service.dart` - Flutter service contract already assumes a custom native layer.
- `shipglows_data/workflow/qa/lab/privacy-capture-platform-matrix.md` - risk framing for privacy capture quality and stop conditions.

## Internet Research

- [Media projection - Android Developers](https://developer.android.com/media/grow/media-projection) - Accessed 2026-06-12 - official contract for MediaProjection, virtual displays, consent, Android 15 QPR1 status chip, and lock-screen auto stop.
- [Capture video and audio playback - Android Developers](https://developer.android.com/media/platform/av-capture) - Accessed 2026-06-12 - official contract for screen and audio capture flows.
- [Behavior changes: Apps targeting Android 14 or higher](https://developer.android.com/about/versions/14/behavior-changes-14) - Accessed 2026-06-12 - confirms single-use MediaProjection consent/session constraints.
- [App screen sharing - Android Developers](https://developer.android.com/about/versions/14/features/app-screen-sharing) - Accessed 2026-06-12 - shows newer Android can prefer app-window capture, which affects UX and assumptions about full-display control.
- [Android 15 features](https://developer.android.com/about/versions/15/features) - Accessed 2026-06-12 - confirms the prominent status chip and auto-stop behavior on lock for Android 15 QPR1+.
- [Secure sensitive activities - Android Developers](https://developer.android.com/security/fraud-prevention/activities) - Accessed 2026-06-12 - confirms `FLAG_SECURE` limits remain a hard platform boundary.

## Problem Framing

There are two different things that can be called "Android native recorder":

1. The platform APIs Android exposes to apps, mainly `MediaProjection`, `VirtualDisplay`, `MediaRecorder`, `MediaCodec`, `MediaMuxer`, camera/audio APIs, overlays, and foreground services.
2. The first-party system recorder UX that some Android builds ship to end users, with its own camera bubble, pause/resume behavior, audio options, and constraints.

The product asks whether it can inherit the stability of item 2 while customizing UI and behavior. The answer is effectively no. Android exposes APIs to build a recorder; it does not expose the system recorder as a reusable, skinnable component with supported extension points for bubble size, shape, live editing, or custom audio policy.

## Option Space

### Option A: Lean on the system recorder UX where possible

- Summary:
  Use Android's built-in recorder experience conceptually, but try to avoid building a deeper custom stack.
- Pros:
  Fastest path if product requirements stay very close to what the device already offers.
  Benefits from OEM/system polish for the exact flows the OS supports.
  Less media-pipeline code to own.
- Cons:
  No supported extension model for the recorder UI itself.
  Camera bubble size/shape/position controls are not yours to change.
  Audio routing options are not yours to redefine beyond what the OS/API allows.
  No strong path for "edit while recording" if that means live compositing, masking, reframing, overlays, or privacy transforms.
  Behavior varies by Android version and OEM because the built-in recorder is partly product/UI, not just API.
  Product differentiation is boxed in by the exact system UX choices.

### Option B: Keep Android APIs, own the recorder pipeline

- Summary:
  Keep `MediaProjection` and other official Android APIs, but build your own composition/recording layer and app UX.
- Pros:
  Preserves the stable, supported capture entry point Android wants apps to use.
  Gives product control over live composition: camera bubble size, shape, placement, overlays, guides, review gates, privacy redaction, branded UI.
  Lets you choose output architecture by mode:
  `MediaRecorder` for simple V1 recording, `MediaCodec` + compositor for advanced/lived-edited recording.
  Fits the current codebase direction because ContentGlows already owns a custom Flutter/native bridge.
  Keeps future room for post-processing with Media3 Transformer.
- Cons:
  More engineering complexity, especially for live camera + screen + audio + editing interactions.
  More device QA, performance tuning, lifecycle handling, and media edge cases.
  Harder to guarantee parity across Android versions.
  You still cannot bypass Android constraints such as consent prompts, visible indicators, stop chip, lock-screen stop, and `FLAG_SECURE`.

### Option C: Hybrid product split

- Summary:
  Maintain a simple stable recorder path for ordinary capture and introduce a separate advanced recorder mode for differentiated workflows.
- Pros:
  Lowest strategic risk.
  Ordinary users get a dependable baseline fast.
  Advanced mode can justify a more complex compositor only where product value is real.
  Matches the existing distinction already present in prior privacy-capture research: direct recorder path for normal capture, custom pipeline for transformed capture.
- Cons:
  Two product modes to explain.
  More surface area in QA and product copy.
  Requires strong boundaries so "simple capture" and "advanced capture" do not blur into one unreliable mode.

## Comparison

```text
Decision axis                System recorder UX   Android APIs + custom stack
---------------------------  -------------------  ----------------------------
Reuse official API surface   Partial              Yes
Reuse built-in recorder UI   Yes                  No
Control camera bubble        No                   Yes
Custom audio policy          Very limited         Partial to strong
Live editing/compositing     No                   Yes
Stable consent/security      Yes                  Yes
Avoid Android indicators     No                   No
Handle privacy transforms    No                   Yes
Engineering cost             Low                  High
Strategic differentiation    Low                  High
```

Key distinction: "use Android" and "use the Android system recorder product" are not the same choice.

The product can and should use Android's official capture APIs. It should not plan around extending the first-party recorder UX.

## Emerging Recommendation

Recommendation: do not anchor the roadmap on extending the built-in Android recorder UX. Treat that path as blocked for the features the product wants.

Instead:

- Keep `MediaProjection` as the stable platform capture foundation.
- Keep the current custom native bridge as the product boundary.
- Split roadmap into two layers:
  - Simple recorder path: current `MediaProjection` + `MediaRecorder` service for straightforward local capture.
  - Advanced recorder path: custom composition pipeline for live camera bubble control, richer audio modes, and in-capture transforms.

This is not "start from zero." It is "keep the Android capture APIs, stop depending on the built-in recorder product UX."

## Non-Decisions

- Exact live-editing scope is not decided yet: resize only, drag/resize/shape, annotations, privacy overlays, trimming during capture, or scene-based composition.
- Exact audio matrix is not decided yet: mic only, playback only where allowed, mixed mic + playback, or selectable sources by device/Android version.
- Whether advanced capture is Android-only for V1 is not decided here, though that is the most realistic initial boundary.

## Rejected Paths

- "Skin or extend the native Android recorder UI directly" - rejected because Android does not offer a supported extension surface for those product controls.
- "Use the system recorder for stability and add live editing after the fact in the same session" - rejected for the requested experience because the edits need to affect capture-time composition, not just post-export editing.

## Risks And Unknowns

- Performance risk:
  Live composition with screen capture, front camera, and audio mixing can become thermal/latency-sensitive on mid-tier devices.
- UX risk:
  Android 14 QPR2+ can push app-window capture flows, which may conflict with a product expectation of full-display recording unless the UX is worded carefully.
- Platform boundary risk:
  Android 15 QPR1+ adds a larger status chip and auto-stop on lock. This improves trust and privacy, but reduces any illusion of silent or persistent capture.
- Audio complexity risk:
  "Mic without media" is easy if "media" means playback audio track. "Mic only while still recording the screen video" is fine. But capturing internal app audio remains governed by Android playback-capture rules and app opt-out behavior.
- Secure-content risk:
  `FLAG_SECURE` screens still cannot be relied on for capture.
- Product scope risk:
  "Edit while recording" ranges from simple bubble resize to a full scene compositor. The architecture is very different depending on which one is actually required.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied:
  - none
- Notes: no secrets or user data were persisted.

## Decision Inputs For Spec

- User story seed:
  As a creator on Android, I want a custom recorder mode that captures the device screen with my camera and chosen audio inputs while letting me control the live composition.
- Scope in seed:
  Screen capture via `MediaProjection`, front-camera overlay, movable/resizable camera bubble, explicit audio mode selection, local output, visible foreground session.
- Scope out seed:
  Extending the built-in Android recorder UI, bypassing consent/indicators, guaranteed protected-content capture.
- Invariants/constraints seed:
  Fresh user consent per session, visible system indicators, stop on system stop/lock where required, local-only until user exports/shares, honest capability detection by Android version/device.
- Validation seed:
  Real-device QA across Android 13/14/15, thermal/perf runs, front camera overlay correctness, audio mode proof, lock/rotation/stop-chip behavior, secure-content handling.

## Handoff

- Recommended next command: `/100-sf-spec Android custom recorder and live composition`
- Why this next step:
  The decision boundary is now clear enough. The remaining uncertainty is product scope and implementation shape, not whether Android allows a supported extension of its built-in recorder UX.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-06-12 00:00:00 UTC | Decide whether to rely on Android's native recorder UX or custom recorder | Reviewed local specs/code and refreshed Android official docs | Conclusion: keep Android capture APIs, do not depend on extending the built-in recorder UX | `/100-sf-spec Android custom recorder and live composition` |
