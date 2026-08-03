---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-06-12"
created_at: "2026-06-12 12:01:52 UTC"
updated: "2026-06-12"
updated_at: "2026-06-12 13:17:00 UTC"
status: active
source_skill: 100-sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "En tant que createur ContentGlowz sur Android, je veux un recorder d'ecran professionnel avec overlay de controle, pause/reprise, camera avant, camera arriere, et double camera quand l'appareil le supporte, afin de produire des videos natives, stables et polyvalentes sans quitter mon flux de creation."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter capture UI"
  - "app Flutter theme tokens"
  - "app Android native capture bridge"
  - "app Android foreground services"
  - "app local capture metadata store"
  - "Android MediaProjection"
  - "Android CameraX concurrent camera"
  - "Android camera2 multi-camera capability checks"
  - "Android MediaCodec/MediaMuxer"
  - "Android AudioRecord and playback capture rules"
  - "Sentry Flutter/native diagnostics"
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/architecture.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/design-system-authority.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/technical/app/flutter-app-shell-and-capture.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md"
    artifact_version: "1.0.0"
    required_status: "active"
  - artifact: "shipglows_data/workflow/explorations/2026-06-12-android-native-vs-custom-screen-recorder.md"
    artifact_version: "1.0.0"
    required_status: "draft"
supersedes:
  - "shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md"
evidence:
  - "Current capture UI in app/lib/presentation/screens/capture/capture_screen.dart only exposes screenshot, record, stop, and microphone toggle."
  - "Current Android recorder in ScreenRecordService uses MediaProjection -> VirtualDisplay -> MediaRecorder with no live camera overlay, pause/resume, or composition stage."
  - "ScreenCaptureChannel already provides a stable custom Flutter/native boundary for capture lifecycle and permission events."
  - "Design-system authority requires all spacing, motion, radii, colors, overlay layers, and responsive values to come from shared Flutter theme/token sources."
  - "User requires both selectable front/rear camera and simultaneous dual-camera mode when the hardware supports it."
  - "Android official docs confirm MediaProjection consent/session constraints, Android 14 single-use behavior, Android 15 QPR1+ status chip and lock-screen stop behavior."
  - "Android official docs confirm CameraX concurrent camera support is device-dependent and must be capability-gated."
next_step: "/101-sf-ready Android pro creator recorder"
---

# Title

Android Pro Creator Recorder

## Status

Active chantier for replacing the current Android screen recorder V1 with a professional creator-oriented recorder. The existing screenshot/local-capture foundation remains valuable, but screen video recording evolves into a composed pipeline with floating overlay controls, pause/resume, camera overlay modes, richer audio controls, typed diagnostics, stronger crash handling, and explicit capability degradation by Android version/device. This spec supersedes the V1 screen-recording contract inside `SPEC-android-device-screen-capture.md` for recording flows while preserving its consent, local-only, and foreground-service invariants.

2026-06-12 implementation status:
- Batch 1 foundation is implemented: typed recorder metadata/contracts in Dart, capability discovery and degradation plumbing in the Android bridge, capture preflight UI in Flutter, and local-store/test updates.
- Batch 2 native session controls are implemented: typed recorder state events, foreground pause/resume/stop actions, pause-aware duration tracking, and Flutter/Dart wiring for pause/resume session control.
- The composed video pipeline, pause/resume engine, floating in-session controls, and real camera overlay composition remain open.

## User Story

En tant que createur ContentGlowz sur Android, je veux un recorder d'ecran professionnel avec overlay de controle, pause/reprise, camera avant, camera arriere, et double camera quand l'appareil le supporte, afin de produire des videos natives, stables et polyvalentes sans quitter mon flux de creation.

## Minimal Behavior Contract

When an Android creator starts a recording session from Capture, ContentGlowz must request fresh MediaProjection consent, start a visible foreground recording session, open a movable overlay control surface with pause/resume/stop and camera controls, capture the screen through a composed native pipeline, and save a local MP4 whose metadata records the selected composition/audio/camera mode and any degraded capability decisions. If the device lacks a requested capability, the camera becomes unavailable, a projection/camera/audio path fails, the OS stops projection, the app overheats, or encoder pressure makes the session unsafe, the recorder must degrade or stop predictably, preserve only a valid finalized local file when safe, surface a typed recoverable or terminal error, and leave no phantom active session. The easy edge case is dual camera: some devices can switch front/rear but cannot open both simultaneously, so the recorder must advertise and enforce per-device capability truth instead of pretending all Android phones support the same mode.

## Success Behavior

- Given an Android user opens Capture, when recorder support is available, then the screen shows a recorder configuration surface that can choose audio mode, camera mode, and overlay behavior before recording starts.
- Given the user taps Record, when Android grants MediaProjection consent, then ContentGlowz starts a foreground recording service and shows a persistent in-app/system overlay with at least pause, resume, stop, camera toggle, and collapse controls.
- Given recording is active, when the user taps pause from the overlay or main app, then screen video capture pauses without crashing the session, the UI reflects paused state, and resume continues inside the same recording output if the platform path supports true pause; otherwise the app must implement a safe segmented pause model transparently and merge segments before final asset registration.
- Given recording is active, when the user chooses front camera mode, then the exported MP4 includes a live front-camera picture-in-picture overlay using the configured shape/size/position.
- Given recording is active, when the user chooses rear camera mode, then the exported MP4 includes a live rear-camera picture-in-picture overlay using the configured shape/size/position.
- Given the device supports concurrent front+rear camera recording, when the user chooses dual-camera mode, then the exported MP4 includes both live camera feeds in the composed output.
- Given the device does not support concurrent dual-camera mode, when the user selects it, then the UI shows that dual mode is unavailable on this device and offers front-only or rear-only instead.
- Given the user changes overlay size, shape, or placement before or during recording within supported controls, when the recording continues, then the final MP4 reflects the updated composition without needing a restart.
- Given the user selects microphone-only audio, when recording starts, then the app records screen video plus microphone without attempting playback capture.
- Given the user selects internal-audio-only or mixed audio, when Android or the source app disallows playback capture, then the recorder degrades honestly to the nearest valid mode and surfaces the degraded decision.
- Given a session completes normally, when the user stops recording, then the recorder finalizes a valid local MP4, registers one local capture asset, and stores typed metadata about duration, audio mode, camera mode, overlay configuration snapshot, and degraded capability flags.
- Given normal screenshot capture is used, when no pro-recorder session is active, then the existing screenshot behavior remains available and unaffected.

## Error Behavior

- If MediaProjection consent is denied, abort cleanly and do not start the recorder overlay or camera pipeline.
- If the foreground service cannot start with the required service types, fail before recording starts and surface a typed startup error.
- If camera permission is required and denied for a requested camera mode, continue with screen-only recording or abort before start depending on the chosen mode, and explain the fallback.
- If the selected camera becomes unavailable during recording, remove or replace that camera feed with a visible degraded state, continue if the remaining session is valid, and record the degradation in metadata and diagnostics.
- If dual-camera mode is requested but not supported or becomes unstable, downgrade to a declared single-camera fallback or block start; do not silently fake dual mode.
- If pause/resume cannot be implemented as a true continuous muxed stream on a specific path, segment safely and merge before asset registration; if merge fails, quarantine partial segments and surface a terminal error.
- If the app loses MediaProjection because of Android's status chip stop, lock-screen auto-stop, another projection, or process pressure, finalize safely if possible, otherwise discard the incomplete asset and emit a typed stop reason.
- If the encoder, muxer, or compositor falls behind enough to threaten stability or file correctness, stop rather than saving a corrupt or misleading MP4.
- If Sentry is configured, capture startup and terminal recorder faults with redacted structured context; never send private screen content, raw local file paths, or audio/video payloads.
- If cleanup of temp segments or temp composition artifacts fails, keep them app-private, unlisted from recent captures, and report a cleanup warning in diagnostics instead of exposing them to share/export.

## Problem

The current Android recorder is a basic screen-capture implementation: it starts MediaProjection, records the screen through `MediaRecorder`, and optionally includes microphone audio. That is useful for local capture, but it is not a creator-grade recorder. It does not provide a floating control overlay, true pause/resume semantics, camera overlay composition, rear/front switching, dual-camera capability detection, richer audio policy, or a robust degradation/error model. The user wants something that feels like the Android recorder "but better": creator controls, live composition, and professional reliability. Android's built-in recorder product is not an SDK surface that can be extended, so the app must own the composition pipeline while still using official Android APIs for capture and hardware access.

## Solution

Replace the current screen-recording path with a layered native Android recorder architecture:

- `MediaProjection` remains the official screen-capture foundation.
- Camera feeds move to CameraX with explicit capability detection for single-camera and concurrent dual-camera modes.
- The recorder composes screen frames, camera feed(s), and overlay state into a controlled output pipeline rather than writing raw screen pixels directly through `MediaRecorder`.
- Overlay controls are owned by ContentGlowz, tokenized through the app design system, and synchronized between Flutter state and native recorder state.
- Typed diagnostics, Sentry-safe observability, and cleanup policies become first-class contract requirements rather than afterthoughts.

This is not a greenfield feature. It is a bounded architectural upgrade of the current capture stack into a professional recorder surface.

## Scope In

- Android recording flow only; screenshot remains in scope only where shared models/contracts are touched.
- Floating control overlay during active recording.
- Overlay actions: pause, resume, stop, collapse/expand, camera mode switch, and quick mute/mic status where valid.
- Preflight recorder configuration in Flutter before start.
- Camera modes:
  - screen only
  - screen + front camera
  - screen + rear camera
  - screen + dual camera when supported
- Overlay composition controls:
  - size presets
  - shape presets
  - position presets plus drag support if technically stable
  - optional mirrored front camera preview behavior
- Audio modes:
  - screen only
  - screen + microphone
  - screen + playback audio when allowed
  - screen + microphone + playback audio when allowed
- Device capability detection and truthful UI gating for unsupported camera/audio modes.
- Strong native error taxonomy and recoverable-vs-terminal event model.
- Temp artifact cleanup and crash-recovery strategy for interrupted sessions.
- Sentry-safe diagnostics and local copy-diagnostics surface for recorder failures.
- Local asset metadata extension for recorder mode, capability fallback, and diagnostics summary.
- Focused Flutter tests, Kotlin unit/compile checks where feasible, and real-device Android QA.

## Scope Out

- iOS, web, Windows, or macOS parity.
- Editing timeline, trimming, captions, scene templates, or post-production editor UX.
- Live streaming.
- Cloud rendering, upload automation, or direct social publishing from the recorder.
- AccessibilityService-based screen semantics.
- Guaranteed universal dual-camera support on all Android devices.
- External Bluetooth microphone routing beyond what the Android audio stack already exposes.
- Full desktop-style multi-window broadcast studio features.
- Marketing claims that imply invisible capture, universal internal audio capture, or universal dual-camera support.

## Constraints

- MediaProjection consent is mandatory per session and cannot be cached or silently reused.
- Android foreground-service and visible indicator behavior must remain compliant on current target Android versions.
- Android 15 QPR1+ stop chip and lock-screen stop behavior are hard platform constraints, not bugs to hide.
- Overlay, sizing, radii, spacing, motion, shadows, z-order, and visual states must resolve through the declared Flutter design-system authority, not screen-local literals.
- Camera concurrency is device-dependent; the app must detect support and refuse unsupported modes honestly.
- New recording architecture must preserve local-only storage defaults and must not introduce backend upload side effects in this chantier.
- Recorder diagnostics must never expose screen contents, audio payloads, tokens, cookies, or user-private text.
- If the native path requires segmented pause/resume implementation, partial segments remain private until merge succeeds; no partial capture should appear in normal history.
- Stability and correctness outrank "feature completeness": unsupported or unsafe modes must degrade or stay unavailable.

## Test Contract

- Surface/stack profile: mixed Flutter + Android native Kotlin + device media/hardware + Sentry runtime observability.
- Automated proof available:
  - `flutter analyze`
  - targeted `flutter test` for capture models, local store, and capture UI
  - Android/Kotlin compile proof through debug build or CI
  - optional Kotlin/JVM helper tests for capability and state-transition logic
- Manual proof required:
  - real Android device validation for MediaProjection, camera availability, overlay behavior, pause/resume, audio-mode degradation, rotation, background/lock, and stop-chip behavior
- Ordered proof path:
  - automated -> Android compile/build -> diagnostics/contract review -> real device manual QA
- Manual checklist artifact required:
  - `shipglows_data/workflow/test-checklists/android-pro-creator-recorder.md`
- Exceptions:
  - no browser/auth path: `exception-with-proof` because this chantier is native Android capture, not web/browser
  - no provider-side backend proof: `exception-with-proof` because capture remains local-only in this chantier except metadata shape continuity

## Dependencies

Local code and docs to update:

- `app/lib/presentation/screens/capture/capture_screen.dart`
- new recorder-specific Flutter presentation components under `app/lib/presentation/screens/capture/`
- `app/lib/data/services/device_capture_service.dart`
- `app/lib/data/models/capture_asset.dart`
- `app/lib/data/services/capture_local_store.dart`
- `app/lib/presentation/theme/app_theme_tokens.dart` and/or `app_theme.dart` if new shared recorder tokens are required
- `app/android/app/src/main/AndroidManifest.xml`
- `app/android/app/build.gradle.kts`
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenCaptureChannel.kt`
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenRecordService.kt`
- new native recorder classes under `app/android/app/src/main/kotlin/com/contentglowz/app/capture/pro/`
- `app/lib/main.dart` and diagnostics surfaces if recorder-specific copy-diagnostics needs extension
- `app/README.md`
- `shipglows_data/technical/app/guidelines.md`

Fresh external docs verdict: `fresh-docs checked` on 2026-06-12.

- MediaProjection docs: `https://developer.android.com/media/grow/media-projection`
  - Confirms per-session consent, virtual display pipeline, Android 15 QPR1 status chip, and lock-screen stop behavior.
- Android 14 behavior changes: `https://developer.android.com/about/versions/14/behavior-changes-14`
  - Confirms one-time MediaProjection token/session expectations.
- App screen sharing docs: `https://developer.android.com/about/versions/14/features/app-screen-sharing`
  - Confirms app-window/full-display capture UX differences that must be reflected honestly.
- CameraX configuration docs: `https://developer.android.com/media/camera/camerax/configuration`
  - Confirms concurrent camera support and composition-mode behavior.
- Camera2 multi-camera docs: `https://developer.android.com/media/camera/camera2/multi-camera`
  - Confirms device-dependent rules for opening multiple cameras.
- Multiple camera streams docs: `https://developer.android.com/media/camera/camera2/multiple-camera-streams-simultaneously`
  - Confirms stream-combination limits and throughput constraints.
- Capture video and audio docs: `https://developer.android.com/media/platform/av-capture`
  - Confirms playback-capture constraints and media/audio capture interactions.
- CameraX release/docs references:
  - Use stable CameraX versions that support the required concurrent-camera behavior at implementation time; record exact chosen versions in the implementation PR/spec history.

## Invariants

- Every recording session requires explicit Android consent and visible foreground/system indicators.
- The recorder must never claim a capability the device/session cannot actually provide.
- A finalized capture asset is registered only after the MP4 is valid and shareable.
- Temp segments and temp composition artifacts must stay app-private and hidden from capture history.
- Pause/resume state transitions must be explicit, typed, and recoverable across app/UI synchronization.
- Overlay visual design must remain token-driven and consistent with app-wide design authority.
- Diagnostics must include build identity and Paris/UTC build timestamps through the app's runtime diagnostics surface when present.
- Sentry/diagnostics may capture error metadata, but never raw captured media or private screen/audio content.
- Normal screenshot behavior remains available and should not be broken by recorder work.

## Links & Consequences

- Product: Capture shifts from a utility feature to a core creation surface with stronger expectations around UX polish and reliability.
- Design system: recorder overlay becomes a reusable app surface and must not accumulate one-off visual literals.
- Performance: live composition, camera feeds, and screen capture can significantly increase CPU/GPU/thermal pressure.
- Security/privacy: creator recordings can include secrets and private content; logs and diagnostics must be aggressively redacted.
- Android QA: device fragmentation matters more now because camera concurrency and playback capture differ by hardware/vendor.
- Observability: recorder state and failure reasons need better structured diagnostics than current generic messages.
- Maintenance: the old direct `MediaRecorder` service may survive only as a compatibility/simple mode helper or be fully replaced; implementation must decide with minimal duplication.

## Documentation Coherence

- Update `app/README.md` with recorder capabilities, device-dependent dual-camera truth, audio limitations, and visible-indicator/platform limits.
- Update `shipglows_data/technical/app/flutter-app-shell-and-capture.md` after implementation to reflect the new recorder architecture and validation commands.
- Update `shipglows_data/technical/app/guidelines.md` with recorder-specific capability gating, diagnostics redaction, and cleanup invariants.
- Update `app/CHANGELOG.md` after implementation.
- Do not update public marketing/site copy until real-device QA validates the experience and wording is honest about capability variance.

## Edge Cases

- Dual-camera requested on a device that supports only front or rear single-camera composition.
- Dual-camera supported in theory but becomes unavailable because another app or system component has one camera open.
- Front/rear switch during an active session while the overlay is collapsed.
- Pause requested while camera pipeline is recovering from a brief availability loss.
- App rotates during recording while the overlay is anchored near a screen edge.
- Lock screen or screen-off mid-recording on Android 15+.
- Overlay hidden behind OEM/system surfaces or affected by special window policies.
- Playback capture requested from an app that opts out of audio playback capture.
- Microphone route changes during recording because of headset/Bluetooth changes.
- Encoder pressure or thermal throttling after several minutes of dual-camera recording.
- App process death while temp segments exist.
- User returns to Capture after a crashed/interrupted session and the app must reconcile stale recorder state.

## Implementation Tasks

- [ ] Task 1: Define the professional recorder contract in shared Dart models.
  - File: `app/lib/data/models/capture_asset.dart`
  - Action: Extend asset metadata with recorder mode, audio mode, camera mode, overlay preset snapshot, capability fallback flags, pause/resume segmentation state if needed, and diagnostics summary fields.
  - User story link: Lets the app represent advanced recorder sessions honestly.
  - Depends on: None.
  - Validate with: `flutter test test/data/capture_asset_test.dart`.
  - Notes: Do not store private local temp paths or raw diagnostics payloads.

- [ ] Task 2: Add typed recorder configuration and event contracts in Dart.
  - File: `app/lib/data/services/device_capture_service.dart`
  - Action: Introduce typed config/event objects for audio mode, camera mode, overlay config, capability reports, pause/resume, and recorder degradation events instead of expanding ad-hoc maps.
  - User story link: Keeps the Flutter/native boundary professional and evolvable.
  - Depends on: Task 1.
  - Validate with: targeted Dart unit tests for config serialization/parsing.
  - Notes: Preserve backwards compatibility for screenshot calls where possible.

- [ ] Task 3: Define recorder capability discovery in native and Flutter layers.
  - File: `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenCaptureChannel.kt`
  - Action: Add methods to report capture/camera/audio capability availability, including dual-camera support truth and playback-capture eligibility signals when discoverable.
  - User story link: Prevents unsupported pro modes from appearing as if they work everywhere.
  - Depends on: Task 2.
  - Validate with: Kotlin compile and Dart parsing tests.
  - Notes: Camera concurrency must be reported as device/session capability, not guessed from brand/model.

- [ ] Task 4: Create recorder token and overlay design primitives.
  - File: `app/lib/presentation/theme/app_theme_tokens.dart`, `app/lib/presentation/theme/app_theme.dart`
  - Action: Add named shared tokens/constants for recorder overlay spacing, radii, elevations, chip sizes, animation timings, and safe placement rules if the existing token set is insufficient.
  - User story link: Makes the overlay visually coherent and maintainable.
  - Depends on: None.
  - Validate with: design-system drift scan and Flutter compile.
  - Notes: No hardcoded overlay literals in screen widgets unless platform-bound and documented.

- [ ] Task 5: Build the Flutter recorder configuration surface.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Replace the simple record controls with a recorder setup panel that selects audio mode, camera mode, and overlay preset based on discovered capabilities, while preserving screenshot access.
  - User story link: Lets creators configure the session before starting.
  - Depends on: Tasks 1-4.
  - Validate with: `flutter test test/presentation/screens/capture/capture_screen_test.dart`.
  - Notes: Unsupported choices should be disabled with short rationale, not hidden mysteriously.

- [ ] Task 6: Add a recorder overlay UI contract in Flutter.
  - File: new files under `app/lib/presentation/screens/capture/`
  - Action: Create overlay/state widgets or controllers that represent active, paused, degraded, and finishing recorder states, synchronized with the native event stream.
  - User story link: Gives users in-session controls comparable to and stronger than the Android recorder.
  - Depends on: Task 5.
  - Validate with: widget tests for overlay state transitions.
  - Notes: If the live overlay itself must be native for reliability, Flutter still owns the canonical visual/state contract and configuration metadata.

- [ ] Task 7: Add native dependencies for CameraX and advanced recording.
  - File: `app/android/app/build.gradle.kts`
  - Action: Add current stable CameraX artifacts needed for preview/video/concurrent-camera support and any recorder/composition helpers, plus safe version alignment notes.
  - User story link: Provides the native camera foundation for front/rear/dual modes.
  - Depends on: fresh-docs checked.
  - Validate with: Android build/Gradle sync.
  - Notes: Record exact versions chosen during implementation because concurrent-camera support evolves over time.

- [ ] Task 8: Create native recorder config/capability classes.
  - File: new files under `app/android/app/src/main/kotlin/com/contentglowz/app/capture/pro/`
  - Action: Define typed Kotlin models for recorder config, capability report, degraded state, overlay commands, and terminal failure taxonomy.
  - User story link: Keeps state transitions explicit and testable.
  - Depends on: Tasks 2, 3, and 7.
  - Validate with: Kotlin compile.
  - Notes: Model pause, resume, stop, collapse, camera switch, and fallback reasons explicitly.

- [ ] Task 9: Implement native recorder session state machine.
  - File: `.../capture/pro/ProRecorderSession.kt`
  - Action: Build a strict state machine for idle, starting, active, paused, degraded, stopping, failed, and finalized states, including camera/pipeline interruptions and cleanup behavior.
  - User story link: Stability depends on deliberate lifecycle control, not loose callbacks.
  - Depends on: Task 8.
  - Validate with: Kotlin helper tests where feasible and compile.
  - Notes: This is the backbone of the error/crash policy.

- [ ] Task 10: Implement native camera capability and concurrent-camera selection.
  - File: `.../capture/pro/ProRecorderCameraCoordinator.kt`
  - Action: Use CameraX and underlying capability checks to decide front/rear/dual availability, select the right camera graph, and expose fallback reasons.
  - User story link: Enables both switchable and simultaneous camera modes with truthful gating.
  - Depends on: Tasks 7-9.
  - Validate with: Kotlin compile and real-device QA on at least one dual-capable and one non-dual-capable device if available.
  - Notes: Do not report dual support unless the actual selected path can sustain it.

- [ ] Task 11: Implement audio mode coordinator with honest degradation.
  - File: `.../capture/pro/ProRecorderAudioCoordinator.kt`
  - Action: Map requested microphone/playback/mixed modes to valid Android audio paths, detect unavailable playback capture conditions, and emit the final effective audio mode.
  - User story link: Users want more control than the current all-or-nothing microphone toggle.
  - Depends on: Tasks 8-9.
  - Validate with: compile plus manual QA.
  - Notes: Internal audio remains conditional on Android rules and source-app policy.

- [ ] Task 12: Implement composed screen recording pipeline.
  - File: `.../capture/pro/ProScreenRecordService.kt`
  - Action: Replace or supersede the current raw `MediaRecorder` path with a composed pipeline that ingests MediaProjection frames, blends camera feeds and overlay state, encodes a valid MP4, and supports pause/resume safely.
  - User story link: Delivers the actual “Android recorder but better” output.
  - Depends on: Tasks 7-11.
  - Validate with: Android build and real-device recording proof.
  - Notes: If true pause is not technically stable, implement segmented pause with private merge before asset registration.

- [ ] Task 13: Implement floating control overlay service behavior.
  - File: `.../capture/pro/ProRecorderOverlayController.kt` and manifest/service wiring
  - Action: Provide the live control surface for pause/resume/stop/camera controls, including collapse/expand behavior and synchronization with the recorder session state.
  - User story link: Gives creators the in-session control surface they explicitly requested.
  - Depends on: Tasks 4, 8, 9, and 12.
  - Validate with: real-device QA.
  - Notes: Respect Android overlay/service constraints and avoid invasive permissions if the chosen overlay approach can stay inside supported recorder surfaces.

- [ ] Task 14: Extend local store for advanced recorder metadata and recovery.
  - File: `app/lib/data/services/capture_local_store.dart`
  - Action: Persist finalized recorder metadata and any crash-recovery markers needed to reconcile interrupted sessions on next launch, without exposing temp artifacts as normal assets.
  - User story link: Prevents ghost sessions and confusing post-crash history.
  - Depends on: Task 1.
  - Validate with: `flutter test test/data/capture_local_store_test.dart`.
  - Notes: Recovery markers are operational metadata only.

- [ ] Task 15: Extend diagnostics and Sentry-safe observability.
  - File: `app/lib/main.dart` and/or recorder diagnostics surface files
  - Action: Ensure recorder errors can be copied through a safe diagnostics surface with build identity, release info, Paris/UTC build timestamps, effective recorder mode, and redacted stop reason or failure taxonomy.
  - User story link: Professional stability requires actionable diagnostics, not vague failure toasts.
  - Depends on: Tasks 2, 8, and 9.
  - Validate with: app diagnostics review and Flutter compile.
  - Notes: Never include captured content or private media paths.

- [ ] Task 16: Add Flutter tests for recorder contracts.
  - File: `app/test/data/capture_asset_test.dart`, `app/test/data/capture_local_store_test.dart`, `app/test/presentation/screens/capture/capture_screen_test.dart`
  - Action: Cover capability gating, recorder configuration defaults, event-driven state transitions, degraded-mode messaging, and finalized metadata behavior.
  - User story link: Protects the new recorder UX from regressions.
  - Depends on: Tasks 1-6 and 14.
  - Validate with: targeted Flutter tests.
  - Notes: Keep existing screenshot/normal-capture assertions green where still applicable.

- [ ] Task 17: Create manual recorder QA checklist.
  - File: `shipglows_data/workflow/test-checklists/android-pro-creator-recorder.md`
  - Action: Define device/manual proof for screen-only, front, rear, dual, pause/resume, overlay controls, audio fallback, rotation, background/lock, stop chip, and crash-recovery behavior.
  - User story link: Real-device proof is necessary to trust a recorder this complex.
  - Depends on: spec only.
  - Validate with: checklist review.
  - Notes: Include explicit expected degraded outcomes, not just happy paths.

- [ ] Task 18: Update docs and legacy V1 contract references.
  - File: `app/README.md`, `shipglows_data/technical/app/flutter-app-shell-and-capture.md`, `shipglows_data/technical/app/guidelines.md`, `app/CHANGELOG.md`
  - Action: Document the new recorder architecture, capability gating, Android limits, diagnostics, and the fact that V1 recording assumptions have been superseded.
  - User story link: Aligns implementation, operators, and future agents around the new recorder contract.
  - Depends on: Tasks 1-17.
  - Validate with: docs review.
  - Notes: Public claims stay conservative until QA proof exists.

## Acceptance Criteria

- [ ] CA 1: Given a supported Android device, when the user opens Capture, then recorder setup exposes only the camera/audio modes the device/session can realistically support.
- [ ] CA 2: Given recording starts successfully, when the session becomes active, then a live control overlay exposes pause/resume and stop without forcing the user back to the main app screen.
- [ ] CA 3: Given pause is tapped during recording, when the recorder pauses, then the session enters a visible paused state and can resume without app crash or ghost active session.
- [ ] CA 4: Given front-camera mode is selected, when recording completes, then the final MP4 includes front-camera picture-in-picture composition.
- [ ] CA 5: Given rear-camera mode is selected, when recording completes, then the final MP4 includes rear-camera picture-in-picture composition.
- [ ] CA 6: Given dual-camera mode is selected on a dual-capable device, when recording completes, then the final MP4 includes both camera feeds in the composed output.
- [ ] CA 7: Given dual-camera mode is selected on a device without stable support, when the user tries to start, then the recorder blocks or falls back explicitly and records the effective mode truthfully.
- [ ] CA 8: Given playback audio is requested but not permitted by Android or the source app, when recording starts, then the recorder degrades to a valid effective audio mode and surfaces that downgrade.
- [ ] CA 9: Given MediaProjection is stopped externally by Android, when the recorder receives the stop, then it finalizes or cancels safely, tears down overlay/camera resources, and leaves no phantom active state.
- [ ] CA 10: Given the app crashes or is killed during a segmented or active session, when the user relaunches the app, then stale recorder state is reconciled and temp artifacts do not appear as normal captures.
- [ ] CA 11: Given a recorder failure occurs, when diagnostics are copied, then the payload starts with build identity plus Paris/UTC build timestamps and contains only redacted structured recorder context.
- [ ] CA 12: Given screenshot capture is used, when no recording session is active, then screenshot behavior from the existing capture feature still works.

## Test Strategy

- Flutter automated:
  - `flutter analyze`
  - `flutter test test/data/capture_asset_test.dart test/data/capture_local_store_test.dart test/presentation/screens/capture/capture_screen_test.dart`
- Android/native automated:
  - debug build / CI compile proof for Kotlin, manifest, and dependencies
  - helper/unit tests for recorder state machine and capability mapping where practical
- Design-system validation:
  - `python3 "${SHIPGLOWZ_ROOT:-$HOME/shipglowz}/tools/design_system_drift_check.py" --changed --format markdown`
- Manual Android device QA:
  - screen-only record
  - front-camera mode
  - rear-camera mode
  - dual-camera mode on supported hardware
  - explicit unsupported dual-camera gating on unsupported hardware
  - pause/resume repeated multiple times
  - stop from overlay and stop from main app
  - lock-screen and status-chip interruption
  - audio-mode degradation cases
  - rotation/orientation changes
  - crash/interruption recovery
- Proof expectation:
  - at least one supported Android device is mandatory
  - second device with weaker or unsupported dual-camera support is strongly preferred before claiming readiness

## Risks

- Architecture risk: moving from direct `MediaRecorder` to composed recording is materially more complex.
- Device fragmentation risk: dual-camera and playback-audio behavior vary sharply by OEM and Android version.
- Performance risk: simultaneous screen capture, camera composition, and audio mixing can trigger thermal throttling or dropped frames.
- Stability risk: pause/resume with composition may require segmented recording if true pause is unreliable.
- UX risk: overlay controls can become brittle if implemented with hardcoded geometry instead of shared layout rules.
- Observability risk: recorder bugs are hard to diagnose without a strong typed error and diagnostics contract.
- Scope risk: the user's desired "truly professional" recorder can expand indefinitely unless the feature set stays bounded to capture-time composition and control.

## Execution Notes

Read first:

- `app/lib/presentation/screens/capture/capture_screen.dart`
- `app/lib/data/services/device_capture_service.dart`
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenCaptureChannel.kt`
- `app/android/app/src/main/kotlin/com/contentglowz/app/capture/ScreenRecordService.kt`
- `shipglows_data/technical/app/flutter-app-shell-and-capture.md`
- `shipglows_data/technical/design-system-authority.md`
- `shipglows_data/workflow/explorations/2026-06-12-android-native-vs-custom-screen-recorder.md`

Recommended implementation order:

1. Shared Dart recorder models + capability contract.
2. Tokenized Flutter setup/overlay contract.
3. Native capability discovery and recorder state machine.
4. Camera/audio coordinators.
5. Composed recording pipeline and overlay controls.
6. Diagnostics/recovery.
7. Docs + manual QA checklist.

Implementation guardrails:

- Prefer bounded professional implementation over feature sprawl.
- Keep screenshot path stable unless explicitly touched by shared model changes.
- Stop and rescope if the chosen overlay implementation would require unsupported or high-risk permissions outside the current recorder posture.
- If dual-camera support proves too unstable across representative devices, keep the architecture dual-ready but ship single-camera front/rear first with dual behind capability proof and explicit partial status.

## Open Questions

- None blocking for the draft. The operator has already fixed the key product choice:
  - front camera, rear camera, and simultaneous dual camera are all desired
  - unsupported dual camera must degrade honestly instead of being removed from the product vision

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-06-12 12:01:52 UTC | 100-sf-spec | GPT-5 Codex | Created the Android pro creator recorder spec from current capture code, Android official docs, and local exploration. | draft saved | /101-sf-ready Android pro creator recorder |
| 2026-06-12 12:48:00 UTC | 001-sf-build | GPT-5 Codex + Spark subagents | Implemented Batch 1 recorder foundation in Flutter/Dart and Android bridge: typed recorder contracts, capability discovery, degradation events, capture preflight UI, and regression tests. | partial | Continue with native recorder state machine, real camera pipeline, and readiness/verification for the remaining recording surface |
| 2026-06-12 13:17:00 UTC | 001-sf-build | GPT-5 Codex + Spark subagents | Added Batch 2 native recorder session controls: typed recorder state transitions, foreground pause/resume/stop actions, pause/resume channel methods, capability truth update, Flutter pause/resume wiring, and regression tests. | partial | Continue with formal 101 readiness, native composed camera/audio pipeline, real floating overlay surface, and device-level Android verification |
| 2026-06-12 13:34:55 UTC | 103-sf-verify | GPT-5 Codex | Reviewed Batch 1+2 execution state, Flutter checks, and proof requirements. Verified partial implementation only: no native Android build/device proof on this run and no required recorder QA checklist artifact found at `shipglows_data/workflow/test-checklists/android-pro-creator-recorder.md`; unresolved drift candidates remain open across project scope (`--warn-only --max-findings 40`). | partial | Route to 405-sf-prod (target discovery), then 107-sf-test for Android device proof; create/check recorder QA checklist before 104-sf-end. |
| 2026-06-12 13:35:57 UTC | 104-sf-end | GPT-5 Codex | Closed the spec trace as deferred because Android-native composed-pipeline/overlay proof and recorder QA checklist artifacts are still missing. | deferred | Execute `/005-sf-ship` after device checklist proof and Android validation before any final closure. |

## Current Chantier Flow

- 100-sf-spec: draft created for Android Pro Creator Recorder.
- 101-sf-ready: not launched formally; 001-sf-build performed a bounded readiness pass and selected the native recorder state-machine/control batch as the next safe slice.
- 102-sf-start: partial implementation completed for Batch 1 foundation plus Batch 2 native recorder state and session controls.
- 103-sf-verify: partial.
- 104-sf-end: deferred (implementation partially traced; finalization waits on Android device proof + required QA checklist).
- 005-sf-ship: not launched.
