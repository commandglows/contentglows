---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-05-04"
created_at: "2026-05-04 19:29:42 UTC"
updated: "2026-05-04"
updated_at: "2026-05-04 21:27:40 UTC"
status: active
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "En tant que créateur ContentGlows sur Android, je veux capturer une photo ou une vidéo de tout l'écran de mon appareil avec consentement système explicite, afin de produire rapidement des assets visuels réutilisables dans mes contenus."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter Android"
  - "app Android native Kotlin"
  - "app Riverpod providers"
  - "Android MediaProjection"
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
  - artifact: "CLAUDE.md"
    artifact_version: "1.1.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "pubspec.yaml already has Flutter/Riverpod/Dio/shared_preferences and the audio-only record package, but no screen capture or MediaProjection dependency."
  - "android/app/src/main/AndroidManifest.xml currently declares only RECORD_AUDIO and no mediaProjection foreground service permissions."
  - "android/app/src/main/kotlin/com/contentglows/app/MainActivity.kt is a minimal FlutterActivity, so native platform-channel capture work is clean-slate."
  - "lib/data/services/feedback_service.dart and lab/api/routers/feedback.py already implement a signed upload/finalize pattern for binary audio feedback; this is a future reference pattern only, not V1 scope."
  - "SPEC-offline-sync-v2 explicitly blocks binary/audio uploads offline, which should apply to capture media uploads too."
  - "Android official MediaProjection docs confirm full display/app-window capture through MediaProjection, VirtualDisplay, MediaRecorder/ImageReader, user consent, and foreground-service requirements."
next_step: "/sf-verify android device screen capture on real Android device"
---

# Title

Android Device Screen Capture

## Status

Implemented Android-first feature spec, pending real-device Android QA. V1 is Android native, local-only screen capture with screenshot, screen recording, optional microphone audio toggle off by default, a 5-minute recording cap, local preview/history, discard, and share/export. Backend upload, synced asset library, and Turso migration are explicitly deferred to a follow-up spec and must not be implemented in this chantier.

## User Story

En tant que créateur ContentGlows sur Android, je veux capturer une photo ou une vidéo de tout l'écran de mon appareil avec consentement système explicite, afin de produire rapidement des assets visuels réutilisables dans mes contenus.

## Minimal Behavior Contract

When a signed-in Android user opens the new Capture surface and starts a screenshot or screen-recording session, the app asks Android for MediaProjection consent, starts a visible foreground capture session for recording, captures the full device display when the system grants it, and returns a local PNG or MP4 asset with preview, discard, and share/export actions; if consent is denied, another projection stops the session, the device policy blocks capture, storage fails, or recording reaches the 5-minute cap, the app must stop cleanly, preserve any completed local file when safe, and show a recoverable state without silent background capture. The easy edge case is Android 14+: each MediaProjection token is single-use, so every capture session must request fresh consent and cannot reuse a cached intent/projection.

## Success Behavior

- Given the user taps "Screenshot" on Android, when Android grants capture consent, then ContentGlows captures one frame of the device display through MediaProjection and stores a local PNG in app-scoped storage.
- Given the user taps "Record", when Android grants capture consent, then ContentGlows records the device display to a local MP4 until the user taps stop or Android stops the projection.
- Given the device is on Android 14 or newer, when full-display capture can be requested, then the native layer should request the default display capture mode so the user flow is biased toward whole-device capture rather than app-window capture.
- Given the user grants app-window capture instead of full-display capture because the OS/OEM prompts that way, then the app must not lie: it should label the capture result as system-selected capture and keep the file usable.
- Given a local capture completes, when preview loads, then the user can discard or share/export the file from app-scoped storage.
- Given the user starts recording with microphone disabled, when recording begins, then the MP4 contains screen video only and does not request microphone permission.
- Given the user turns on microphone audio, when `RECORD_AUDIO` is granted, then the MP4 includes microphone audio; when `RECORD_AUDIO` is denied, recording continues video-only with an observable notice.
- Given recording reaches 5 minutes, when the cap fires, then the app stops and finalizes the recording as if the user tapped stop.
- Given the app is offline or FastAPI is degraded, then local capture, preview, discard, and share/export still work because V1 has no backend upload dependency.

## Error Behavior

- If the user denies MediaProjection consent, show a calm declined state and return to idle without creating an empty asset.
- If Android stops the projection through the status bar chip, lock screen, another projection, or process pressure, release MediaRecorder/ImageReader/VirtualDisplay resources and finalize or delete the partial file according to recorder state.
- If the app targets Android 14+ and foreground-service permissions or service type are missing, implementation must fail tests/build review before runtime; do not ship a capture flow that can throw `MissingForegroundServiceTypeException`.
- If `createVirtualDisplay()` throws because a token is reused, treat it as an implementation bug; request fresh consent for the next session.
- If notification permission is denied on Android 13+, recording may still be technically possible but the UI must explain that Android requires visible capture indicators and the app cannot hide the session.
- If microphone audio is enabled and `RECORD_AUDIO` is denied, video-only recording should remain available.
- If internal app audio capture is attempted in a later version and Android or the source app disallows playback capture, continue with screen video and surface that internal audio was unavailable.
- If the 5-minute cap is reached, stop recording, finalize the local file when possible, and show that the maximum duration was reached.
- If capture contains sensitive third-party screen content, it must remain local unless the user explicitly shares or exports it outside ContentGlows.

## Problem

ContentGlows currently helps creators plan, draft, review, and publish content, but it does not let the creator capture what is happening on their own Android device. Existing media code is limited to audio feedback. That is not enough for tutorials, walkthroughs, bug/UX examples, app demos, swipeable proof, or short-form B-roll captured from the device. The user explicitly accepts the Android consent prompt as part of the feature, so the problem is not consent friction; the problem is designing a correct native Android capture boundary that records the whole device screen, handles Android privacy constraints honestly, and fits ContentGlows's local-first/offline model.

## Solution

Add an Android-first capture feature backed by native Kotlin MediaProjection code exposed to Flutter through platform channels. The native layer owns consent, foreground service, VirtualDisplay, MediaRecorder/ImageReader, lifecycle callbacks, microphone inclusion when enabled, 5-minute recording cap enforcement, and app-scoped file output. Flutter owns the Capture screen, state model, preview, local asset history, share/export, and discard actions.

Prefer a custom native implementation for V1 instead of relying blindly on a generic plugin, because this feature needs full-device bias, screenshot and video support, Android 14 token handling, foreground-service correctness, explicit privacy copy, local-only behavior, microphone toggle control, duration-cap enforcement, and robust lifecycle cleanup. `flutter_screen_recording` can be evaluated as a spike, but should be adopted only if it passes the Android 14, foreground service, notification, output path, microphone, duration, and lifecycle criteria in this spec.

## Scope In

- Android native full-device screen capture using `MediaProjection`.
- One-shot screenshot capture to PNG using a projection surface/ImageReader.
- Screen recording to MP4 using MediaProjection + VirtualDisplay + MediaRecorder.
- Fresh user consent for each screenshot and each recording session.
- Foreground service with visible notification while recording.
- Stop controls from the app UI and robust stop handling from Android callbacks.
- Local asset preview/history in Flutter.
- Share/export from local file.
- Optional microphone audio toggle for recordings, off by default.
- 5-minute recording cap for V1.
- Android runtime permission handling for microphone and notification only where needed.
- Tests and manual QA focused on Android behavior, lifecycle, local persistence, duration cap, and share/export.

## Scope Out

- Web implementation.
- iOS/ReplayKit implementation.
- Silent/background capture without Android's consent prompt and visible system indicators.
- Guaranteed capture of protected content from apps that set secure/display-capture restrictions.
- Guaranteed internal audio capture from every app.
- Automatic upload immediately after recording.
- Any backend capture upload endpoint, upload action, synced asset library, cloud asset history, or server-side capture storage.
- Turso migration or backend asset metadata table for capture media.
- Offline binary upload replay through `offline_queue_v1`.
- Public marketing claims that imply invisible recording or universal cross-platform screen capture.
- Rich video editing, trimming, captions, transcoding pipeline, or AI analysis of captured video.

## Constraints

- Use Android MediaProjection consent through `MediaProjectionManager.createScreenCaptureIntent()` or `createScreenCaptureIntent(MediaProjectionConfig)` where available.
- Every capture session must request fresh consent. Do not cache or reuse `Intent`, `MediaProjection`, or `VirtualDisplay` for a new session.
- Target Android 14+ foreground-service rules: declare `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, and a service with `android:foregroundServiceType="mediaProjection"`.
- Use app-scoped storage for raw local files by default; use Android `MediaStore` only for explicit export/save-to-gallery if later scoped.
- Keep native capture state observable to Flutter through typed status events, not ad-hoc strings in widgets.
- Keep API/state logic outside widgets: service/model/provider layers first, then screen UI.
- Never persist captured screen media in `SharedPreferences`; store only metadata and file paths for local history.
- Do not add backend upload, asset-library, or Turso migration work in V1. A follow-up spec must define auth, storage, retention, ownership, size limits, costs, and migrations before upload is implemented.
- On Linux ARM64 local dev, do not run Android release builds; use local analyze/tests and route release APK/AAB builds to x64 CI/Blacksmith.

## Dependencies

Local app dependencies and contracts:

- `app/pubspec.yaml`: currently has no MediaProjection/screen capture package and may need `permission_handler` only if runtime permission handling is not implemented natively.
- `android/app/src/main/AndroidManifest.xml`: add foreground service permissions/service declaration and possibly `POST_NOTIFICATIONS`.
- `android/app/src/main/kotlin/com/contentglows/app/MainActivity.kt`: add or delegate MethodChannel/EventChannel registration.
- New native Kotlin classes under `android/app/src/main/kotlin/com/contentglows/app/capture/`.
- New Flutter data/model/provider/UI files under `lib/data/models`, `lib/data/services`, `lib/providers`, and `lib/presentation/screens/capture`.
- `lib/router.dart` and `lib/presentation/screens/app_shell.dart`: add route/navigation entry if the feature is part of the app shell.
- `lab/api/routers/feedback.py` and `api/services/feedback_storage.py`: future reference pattern for signed upload only; do not call, modify, or overload feedback routes in V1.
- `lab/api/models/feedback.py`: future reference for upload validation style only; no capture backend models are part of V1.

Fresh external docs verdict: `fresh-docs checked` on 2026-05-04.

- Android MediaProjection official docs: `https://developer.android.com/guide/topics/large-screens/media-projection-large-screens`
- Android 14 behavior changes: `https://developer.android.com/about/versions/14/behavior-changes-14`
- Android foreground service types: `https://developer.android.com/develop/background-work/services/fgs/service-types`
- Android video/audio capture: `https://developer.android.com/media/platform/av-capture`
- Android AudioPlaybackCaptureConfiguration reference: `https://developer.android.com/reference/android/media/AudioPlaybackCaptureConfiguration`
- Candidate Flutter package reference, not accepted by default: `https://pub.dev/packages/flutter_screen_recording`

## Invariants

- Capture starts only after explicit Android consent.
- Recording is visibly active through Android foreground-service/system indicators.
- The user can stop recording from ContentGlows; Android can also stop it externally.
- Each projection token is single-use.
- Completed local media remains under user control until discard or share/export.
- V1 never uploads captured media to a backend or stores capture metadata in a server asset library.
- Captured media is never silently attached to feedback, diagnostics, content records, or analytics.
- Degraded/offline mode does not block local capture, preview, discard, or share/export.
- Protected or black-screen content from other apps is an expected platform outcome, not a ContentGlows bug.

## Links & Consequences

- Product: adds a new creator tool, likely under the existing "Create" or "Tools" navigation group.
- Privacy/security: full-screen capture can include secrets, private messages, payment screens, tokens, or personal data. The UI must treat this as sensitive media.
- Backend/storage: V1 has no backend upload, asset library, or Turso migration. Future upload work must be scoped in a separate spec that covers storage costs, retention, auth, ownership, size limits, and migration strategy; the existing feedback upload flow is only a pattern reference.
- Offline: local capture fits the current local-first posture; no binary upload replay is introduced.
- Android release: native service and permissions require Android-specific QA on real devices, especially API 29, 33, 34, and 35+ behavior.
- Web/iOS: the spec intentionally does not promise parity; future specs can add web desktop and iOS ReplayKit separately.

## Documentation Coherence

- Update `README.md` with Android capture feature scope, required Android permissions, local build limitations, 5-minute cap, local-only behavior, and platform limitations.
- Do not update `.env.example` for V1 because no capture backend env vars are introduced.
- Update `shipglows_data/product/app/product.md` if the product promise expands from review/publish preparation into device media capture.
- Update `shipglows_data/technical/app/guidelines.md` only if a reusable platform-channel convention is introduced.
- Update `CHANGELOG.md` after implementation.
- Update `site` marketing copy only after the feature ships and after platform limits are worded honestly.

## Edge Cases

- User grants app-window capture instead of full display on Android 14+.
- User rotates the device during recording.
- User locks the device during recording.
- User taps Android's status bar capture chip and stops projection.
- Another app starts a projection and terminates ContentGlows's session.
- Device policy disables screen capture.
- Source app marks content secure, yielding black frames or omitted protected content.
- Recording starts while ContentGlows goes to background to capture another app.
- Notification permission is denied.
- Microphone permission is denied while video capture is allowed.
- App process is killed while the foreground service is recording.
- Output file exists but MediaRecorder finalization fails.
- Recording reaches the 5-minute cap.
- User enables microphone but denies `RECORD_AUDIO`.
- Local metadata points to a file that was removed by OS cleanup or user action.

## Implementation Tasks

- [x] Task 1: Decide custom native implementation vs plugin adoption after a short Android spike.
  - File: `app/pubspec.yaml`, `app/android/app/src/main/kotlin/com/contentglows/app/MainActivity.kt`
  - Action: Evaluate whether `flutter_screen_recording` satisfies screenshot, Android 14 consent, foreground service, local output path, lifecycle callbacks, notification, and storage requirements. Default to custom Kotlin if any requirement is not met cleanly.
  - User story link: Ensures the Android capture foundation can actually capture device screen media for creator assets.
  - Depends on: None.
  - Validate with: Real-device smoke on Android 14+ or plugin example audit; document verdict in this spec or implementation notes.
  - Notes: Do not adopt low-confidence/unmaintained packages just to reduce native code.

- [x] Task 2: Add Android manifest permissions and capture service declaration.
  - File: `app/android/app/src/main/AndroidManifest.xml`
  - Action: Add `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, optional `POST_NOTIFICATIONS`, keep `RECORD_AUDIO`, and declare a non-exported foreground service with `android:foregroundServiceType="mediaProjection"`.
  - User story link: Makes Android screen recording legal and stable under modern foreground-service rules.
  - Depends on: Task 1.
  - Validate with: Android manifest inspection and targeted debug build on Android 14+ CI/device.
  - Notes: Avoid legacy external storage permissions unless an explicit gallery export task scopes them.

- [x] Task 3: Implement native MediaProjection consent bridge.
  - File: `app/android/app/src/main/kotlin/com/contentglows/app/capture/ScreenCaptureChannel.kt`
  - Action: Register MethodChannel/EventChannel APIs for `isSupported`, `requestScreenshotConsent`, `startRecordingConsent`, `stopRecording`, and status events; use Activity Result APIs or equivalent safe request flow.
  - User story link: Lets Flutter trigger Android's explicit consent prompt and receive reliable state.
  - Depends on: Task 2.
  - Validate with: Native unit/manual smoke showing denied consent and granted consent paths.
  - Notes: Do not reuse Activity result `Intent` across sessions.

- [x] Task 4: Implement native screenshot capture.
  - File: `app/android/app/src/main/kotlin/com/contentglows/app/capture/ScreenShotCapture.kt`
  - Action: Use MediaProjection + VirtualDisplay + ImageReader to capture one frame, save PNG to app-scoped storage, release all resources, and return file metadata.
  - User story link: Provides the "prendre en photo tout l'ecran" capability.
  - Depends on: Task 3.
  - Validate with: Real-device screenshot smoke across portrait/landscape and protected-content case.
  - Notes: Timeout if no frame arrives; never leave projection alive after one-shot capture.

- [x] Task 5: Implement native recording foreground service.
  - File: `app/android/app/src/main/kotlin/com/contentglows/app/capture/ScreenRecordService.kt`
  - Action: Start a foreground service, configure MediaRecorder MP4 output, create VirtualDisplay from MediaProjection, stream status/duration, enforce a 5-minute maximum, stop/finalize file safely, and release resources in `MediaProjection.Callback.onStop()`.
  - User story link: Provides the "enregistrer une video de tout l'ecran" capability.
  - Depends on: Task 3.
  - Validate with: Real-device start/stop, 5-minute cap, external stop, lock screen stop, rotation, and file playback smoke.
  - Notes: Register callbacks before `createVirtualDisplay()`.

- [x] Task 6: Add optional microphone audio toggle, off by default.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`, `app/android/app/src/main/kotlin/com/contentglows/app/capture/ScreenRecordService.kt`
  - Action: Add a disabled-by-default microphone toggle; request runtime mic permission only when enabled; continue video-only if denied.
  - User story link: Lets creators record voiceover while capturing the device screen.
  - Depends on: Task 5.
  - Validate with: Permission denied, permission granted, and playback smoke.
  - Notes: Internal device audio is out of scope for V1.

- [x] Task 7: Add Flutter capture models and platform service.
  - File: `app/lib/data/models/capture_asset.dart`, `app/lib/data/services/device_capture_service.dart`
  - Action: Define `CaptureAsset`, `CaptureStatus`, `CaptureKind`, `CaptureFailure`, and a typed platform-channel service with unsupported fallbacks for non-Android.
  - User story link: Gives the rest of the app typed capture state instead of widget-local channel calls.
  - Depends on: Tasks 3-5.
  - Validate with: Dart unit tests for model parsing/status transitions where possible.
  - Notes: Include local path, mime type, duration, width/height, file size, createdAt, microphone-enabled flag, and system-selected capture label metadata. Do not include upload metadata in V1.

- [x] Task 8: Add capture state recovery and local history.
  - File: `app/lib/data/services/capture_local_store.dart`, `app/lib/presentation/screens/capture/capture_screen.dart`, `app/android/app/src/main/kotlin/com/contentglows/app/capture/ScreenRecordService.kt`
  - Action: Add native recording-state replay for screen recreation, plus local metadata persistence for recent captures.
  - User story link: Keeps capture status visible and recoverable across UI transitions.
  - Depends on: Task 7.
  - Validate with: Local history tests and real-device recording recreation smoke.
  - Notes: Store metadata only, not binary bytes, in local preferences. A broader Riverpod capture controller remains optional if capture state is reused outside `/capture`.

- [x] Task 9: Add Android-first Capture screen and navigation.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`, `app/lib/router.dart`, `app/lib/presentation/screens/app_shell.dart`
  - Action: Add `/capture`, controls for screenshot/record/stop, microphone toggle off by default, clear recording status, 5-minute cap display, local preview cards, discard/share/export actions, and unsupported states for web/iOS.
  - User story link: Gives creators one obvious place to capture device media.
  - Depends on: Task 8.
  - Validate with: Widget tests for Android-supported state, unsupported state, recording state, preview actions, and overflow-safe mobile layout.
  - Notes: Avoid in-app text that promises hidden/universal capture. Do not show upload actions in V1.

- [x] Task 10: Add share/export integration for local files.
  - File: `app/lib/data/services/device_capture_service.dart`, `app/android/app/src/main/kotlin/com/contentglows/app/capture/CaptureFileProvider.kt`, `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Wire local PNG/MP4 share/export from app-scoped storage through a native Android read-only content provider and share intent.
  - User story link: Lets creators reuse captured local assets in their content workflows without backend storage.
  - Depends on: Task 9.
  - Validate with: Widget/service tests for missing file, share success, and share failure states, plus real-device share sheet smoke.
  - Notes: Gallery save is not required unless existing app patterns already support it cleanly.

- [x] Task 11: Add V1 QA and documentation updates.
  - File: `app/README.md`, `app/CHANGELOG.md`, `shipglows_data/product/app/product.md`
  - Action: Document Android capture scope, platform limits, local-only behavior, microphone toggle, 5-minute cap, and changelog entry.
  - User story link: Keeps operator/product claims aligned with real platform behavior.
  - Depends on: Tasks 1-10.
  - Validate with: Documentation review and no unsupported cross-platform claims.
  - Notes: Do not add V1 `.env.example` capture variables; marketing site update should wait until implementation is verified.

- [ ] Deferred follow-up: Specify backend upload and synced capture asset library after V1.
  - File: `shipglows_data/workflow/specs/app/SPEC-android-capture-backend-upload.md`
  - Action: Create a separate spec for signed upload, explicit upload UI, server asset metadata, retention, auth/ownership, size limits, Turso migration, and reuse of feedback upload patterns without overloading feedback routes.
  - User story link: Preserves a future path for reusable cloud assets without expanding local-only V1.
  - Depends on: V1 verification and a product decision to add server storage.
  - Validate with: Future `/sf-ready` on the follow-up spec before any backend or ApiService implementation.
  - Notes: This is not a V1 implementation task and must not be started in this chantier.

## Acceptance Criteria

- [ ] CA1: Given an Android user selects Screenshot and grants system consent, when capture completes, then a PNG of the system-granted display/app region is saved locally and previewed in ContentGlows.
- [ ] CA2: Given an Android user selects Record and grants system consent, when they stop recording, then an MP4 is saved locally, can be previewed/shared, and has duration/file-size metadata.
- [ ] CA3: Given the user denies consent, when the system dialog closes, then no file is created and the Capture screen returns to idle with a declined message.
- [ ] CA4: Given Android stops projection externally, when `onStop()` fires, then all native resources are released and Flutter state leaves recording mode.
- [ ] CA5: Given Android 14+, when a second recording starts, then the app requests new consent rather than reusing the previous token.
- [ ] CA6: Given microphone is off by default, when recording starts, then the app does not request microphone permission and the MP4 is video-only.
- [ ] CA7: Given microphone is enabled, when permission is granted, then the MP4 includes microphone audio; when permission is denied, then recording continues video-only and the UI shows a recoverable notice.
- [ ] CA8: Given recording reaches 5 minutes, when the cap fires, then recording stops, resources are released, and a completed local MP4 is previewed when finalization succeeds.
- [ ] CA9: Given the platform is web/iOS/desktop, when `/capture` opens in this Android-first spec, then the screen shows unsupported or "coming later" state and does not crash.
- [ ] CA10: Given offline/degraded FastAPI state, when a user captures a screenshot or video, then local preview, discard, and share/export still work with no backend request.
- [ ] CA11: Given the user opens the Capture screen in V1, when a capture is previewed, then no upload action, server asset id, or cloud library state is shown.

## Test Strategy

- Flutter unit/provider tests:
  - `capture_asset` model serialization/parsing.
  - capture state transitions: idle, awaiting consent, recording, finalizing, ready, failed.
  - local metadata history persistence.
  - microphone toggle default off, permission denied fallback, and 5-minute cap state.
  - local-only behavior while offline/degraded.
- Flutter widget tests:
  - Capture screen unsupported platform state.
  - Capture screen Android-supported controls with mocked service.
  - recording status and stop action.
  - preview actions: discard/share/export.
  - no upload action or cloud asset state in V1.
- Android native/manual tests on real devices:
  - API 29 or 30 baseline MediaProjection.
  - API 33 notification permission behavior.
  - API 34/35 foreground service + single-use token behavior.
  - rotation during recording.
  - lock screen and status bar chip stop.
  - protected-content app results.
  - 5-minute cap stop/finalize behavior.
  - microphone permission granted and denied behavior.
- Validation commands:
  - `cd app && flutter analyze`
  - `cd app && flutter test`
  - Android debug build/smoke on x64 CI or real device environment

## Risks

- High privacy risk: full-screen recordings can include secrets and personal data. Mitigation: explicit consent, visible recording, local-only default, no backend upload, no automatic sharing.
- High platform risk: Android 14+ MediaProjection token semantics and foreground-service rules can break naive implementations. Mitigation: fresh consent per session, callback cleanup, real-device QA.
- Medium product risk: Android may offer app-window sharing or OEM-specific behavior even when the product wants full-device capture. Mitigation: request default display where supported and label system-selected results honestly.
- Medium dependency risk: generic Flutter packages may lag Android platform changes. Mitigation: evaluate but default to custom native code.
- Medium local storage risk: video files are large. Mitigation: 5-minute cap, local file-size metadata, discard action, and app-scoped storage.
- Medium offline risk: users may expect cloud sync. Mitigation: visible local-only state, share/export action, and explicit follow-up spec for backend upload.

## Execution Notes

- Recommended V1 defaults:
  - Android native first.
  - Local screenshot PNG and recording MP4.
  - Recording duration cap: 5 minutes.
  - Microphone audio: optional toggle, off by default.
  - Internal audio: out of scope until explicitly requested.
  - Backend upload, synced asset library, and Turso migration: out of scope and deferred to `SPEC-android-capture-backend-upload.md` or equivalent future spec.
- Read first: `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/contentglows/app/MainActivity.kt`, `lib/router.dart`, `lib/presentation/screens/app_shell.dart`, existing provider/service patterns, and feedback upload files only as future-pattern reference.
- Stop conditions: do not implement backend upload, ApiService capture upload methods, capture backend routes, capture migrations, automatic upload, internal app audio capture, or web/iOS capture in this chantier.
- Use `MediaProjectionConfig.createConfigForDefaultDisplay()` on API 34+ if implementation confirms it reliably biases toward whole-display capture; gracefully fallback to system user choice on older APIs or unsupported OEM behavior.
- Do not run Android release builds locally on Linux ARM64; use permitted local checks and x64 CI/device smoke.

## Implementation Evidence

- Custom native Kotlin implementation selected; no new screen-recording plugin dependency was added.
- Screenshot and recording paths both start Android foreground services with `mediaProjection` service types before creating a `VirtualDisplay`.
- Recording state is replayed to Flutter when `/capture` resubscribes, so a visible Stop action can return after navigation/recreation while the native service is still active.
- Microphone-denied and notification-denied states are modeled as recoverable notices instead of terminal capture failures.
- V1 docs were updated in `README.md`, `shipglows_data/product/app/product.md`, `shipglows_data/technical/app/guidelines.md`, and `CHANGELOG.md`.
- Static validation passed locally: `flutter analyze`, focused capture tests, full `flutter test`, and Android `:app:compileDebugKotlin -x :app:processDebugResources`.
- `flutter build apk --debug` was attempted locally and failed before app code packaging because Gradle could not start the Linux AAPT2 daemon on this ARM64 environment.
- Pending proof: real-device Android smoke and full debug APK packaging on a compatible Android build environment.

## Open Questions

None. Master decision resolved V1 as Android native local-only screen capture with optional microphone audio off by default, a 5-minute recording cap, and no backend upload, asset library, or Turso migration.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-04 19:29:42 UTC | sf-spec via sf-build | GPT-5 Codex | Created Android-first device screen capture spec from existing Flutter/FastAPI contracts and current Android docs | Draft saved | /sf-ready android device screen capture |
| 2026-05-04 20:58:02 UTC | sf-build / sf-spec-prep | GPT-5 Codex | Resolved V1 decisions as Android native local-only capture, removed backend/Turso V1 tasks, and prepared readiness trace | Ready | /sf-start android device screen capture |
| 2026-05-04 21:14:38 UTC | sf-start | GPT-5 Codex | Implemented Android native local-only capture bridge, foreground recording service, local Flutter metadata/history/UI, route/nav wiring, and focused capture tests | Implemented with device-smoke gap | /sf-verify android device screen capture |
| 2026-05-04 21:27:40 UTC | sf-build / sf-verify | GPT-5 Codex | Addressed review findings for screenshot foreground service, recording-state replay, startup failure events, and recoverable permission notices; updated docs | Static verification passed; device QA pending | real-device Android smoke |

## Current Chantier Flow

- sf-spec: draft created via sf-build.
- sf-ready: ready after V1 decision cleanup.
- sf-start: implemented V1 local-only Android capture; Android debug APK packaging blocked locally by AAPT2 binary startup on ARM64, Kotlin compile succeeded with resource step skipped.
- sf-verify: static verification launched and passed for Flutter analyze/tests plus Android Kotlin compile; real-device MediaProjection smoke still pending.
- sf-end: documentation and changelog updated; full closure blocked by missing device QA.
- sf-ship: not launched because full Android packaging/device proof is still missing and the worktree contains unrelated dirty files from other chantiers.

Next lifecycle command: `/sf-test android device screen capture on Android device`.
