---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "app"
created: "2026-05-08"
created_at: "2026-05-08 10:06:37 UTC"
updated: "2026-05-08"
updated_at: "2026-05-08 10:06:37 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: "Diane"
confidence: medium
user_story: "As a ContentGlows creator who captures screens on multiple platforms for public sharing, I want one shared privacy capture contract for metadata, temporary files, backend payloads, disclosure, and review gates, so Android, Web, Windows, and future iOS/Linux/macOS implementations reduce leaks consistently without forcing the same native pipeline."
risk_level: high
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter capture asset model"
  - "app Flutter device capture service boundary"
  - "app local capture metadata store"
  - "app Capture UI share/export/content-link flows"
  - "app API capture/content metadata payloads"
  - "Android privacy capture pipeline"
  - "Web/browser privacy capture pipeline"
  - "Windows desktop privacy capture pipeline"
  - "Future iOS ReplayKit privacy capture pipeline"
  - "Future Linux xdg-desktop-portal/PipeWire privacy capture pipeline"
  - "Future macOS ScreenCaptureKit privacy capture pipeline"
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
  - artifact: "shipglows_data/workflow/explorations/2026-05-08-ios-privacy-capture-redaction.md"
    artifact_version: "unknown"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/explorations/2026-05-08-linux-privacy-capture-redaction.md"
    artifact_version: "unknown"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/explorations/2026-05-08-macos-privacy-capture-redaction.md"
    artifact_version: "unknown"
    required_status: "draft"
supersedes: []
evidence:
  - "Android, Web, and Windows privacy capture specs all require best-effort disclosure, flattened redacted output, OCR text non-persistence, safe temporary-file handling, and review before share/export."
  - "app/lib/data/models/capture_asset.dart currently has only basic capture metadata and no privacy contract fields."
  - "app/lib/data/services/device_capture_service.dart currently exposes an Android-only capture service boundary and typed native events."
  - "app/lib/data/services/capture_local_store.dart stores recent capture metadata in SharedPreferences and can be extended without storing binary data."
  - "app/lib/data/services/api_service.dart currently sends capture metadata through _captureAssetMetadata(asset) and must remain backend-safe."
  - "iOS, Linux, and macOS explorations show future platform pipelines can produce the same flattened redacted asset contract while using different native capture/OCR/render/encode APIs."
next_step: "/sf-ready shared privacy capture contract"
---

# Title

Shared Privacy Capture Contract

## Status

Draft spec for the shared cross-platform privacy capture contract. This chantier defines the app-level contract that all platform-specific privacy capture implementations must satisfy before they can register, preview, share/export, or attach a privacy-marked capture asset. It does not implement Android, Web, Windows, iOS, Linux, or macOS redaction pipelines. It defines the common metadata schema, temporary-file and clear-original rules, OCR text non-persistence, backend-safe payload shape, review gate behavior, and disclosure copy slots that platform specs must map onto.

The contract is intentionally platform-neutral. Android may use MediaProjection/ML Kit/MediaCodec, Web may use getDisplayMedia/Canvas/WebCodecs/MediaRecorder, Windows may use Windows.Graphics.Capture/Windows.Media.Ocr/Direct3D, iOS may use ReplayKit/Vision/Core Image/AVAssetWriter, Linux may use xdg-desktop-portal/PipeWire/GStreamer, and macOS may use ScreenCaptureKit/Vision/Core Image/AVAssetWriter. Those pipelines can differ, but the asset they hand back to Flutter and the metadata sent to backend must follow the same privacy contract.

## User Story

As a ContentGlows creator who captures screens on multiple platforms for public sharing, I want one shared privacy capture contract for metadata, temporary files, backend payloads, disclosure, and review gates, so Android, Web, Windows, and future iOS/Linux/macOS implementations reduce leaks consistently without forcing the same native pipeline.

## Minimal Behavior Contract

When any ContentGlows platform starts or completes a privacy capture, the app must treat it through one shared contract: the platform may use its own capture and redaction technology, but the normal capture history, preview, share/export, and content attachment flows may receive only a flattened redacted asset with privacy metadata, no persisted OCR text, no exposed clear temporary file, a backend-safe metadata payload, and a review acknowledgement gate before public use. If the privacy pipeline fails, falls behind, cannot clean a clear intermediate, or cannot prove the final asset is flattened and redacted, ContentGlows must avoid registering a misleading privacy asset, delete or quarantine unsafe intermediates, and explain the recoverable state. The easy edge case is platform drift: each native implementation can be technically correct while using different field names or failure semantics, so this shared contract must be the source of truth at the Flutter model/service/API boundary.

## Success Behavior

- Given an old non-privacy `CaptureAsset` is loaded from local storage, when it is parsed by the new model, then it defaults to `privacyMode=false`, `redactionStatus=notRequested`, `reviewState=notRequired`, and remains shareable under the existing normal-capture behavior.
- Given any platform returns a successfully redacted privacy screenshot or recording, when Flutter registers the asset, then the asset includes `privacyMode=true`, `privacyContractVersion=1.0`, a platform label, redaction status, text/photo style, strength, review state, and aggregate processing stats.
- Given privacy capture succeeds, when the asset is added to recent captures, then the file path points to the flattened redacted output only; clear originals, editable redaction layers, OCR sidecars, and frame caches are not added to normal history.
- Given privacy capture succeeds with nonfatal degradation, when the asset is registered, then `redactionStatus=degradedBestEffort`, `reviewState=needsReview`, and a sanitized degradation reason is visible to the user without exposing OCR text, local clear paths, or frame data.
- Given a privacy asset has `reviewState=needsReview`, when the user attempts share, export, download, OS share, create-content-from-capture, or attach-to-content, then ContentGlows blocks the action until the user acknowledges manual review.
- Given the user acknowledges review, when share/export/content attachment continues, then ContentGlows updates local metadata to `reviewState=reviewed` and uses only the flattened redacted output plus backend-safe metadata.
- Given platform code uses OCR, text detection, accessibility nodes, visual detectors, or recognition APIs, when it derives redaction regions, then recognized text strings are used only transiently and are discarded before any persistence, logging, analytics, backend payload, or user-visible diagnostics.
- Given a platform implementation needs clear buffers or temporary clear files internally, when the session succeeds, fails, or is canceled, then those intermediates stay app-private, are never exposed through preview/history/share/backend, and are deleted before the flow is considered safe.
- Given deletion of a clear intermediate cannot be confirmed, when the platform reports completion, then Flutter treats the result as unsafe: no normal privacy asset is registered unless the clear file is quarantined outside normal history and the user sees a cleanup warning.
- Given a privacy asset is sent to backend as content metadata, when `_captureAssetMetadata(asset)` is built, then the payload includes only safe privacy metadata and aggregate stats; it excludes OCR text, frame images, clear thumbnails, local clear paths, temp paths, editable layers, and raw redaction boxes.
- Given a platform exports a non-MP4 format such as WebM, when the asset is registered, then `mimeType`, filename, `exportEngine`, and user copy match the actual output and no platform claims unsupported format guarantees.
- Given Android, Web, Windows, or future iOS/Linux/macOS implement privacy capture, when they cross the Flutter service boundary, then they map native options, status, errors, and events into the same Dart contract names.

## Error Behavior

- If `privacyMode=true` is requested but a platform cannot produce a flattened redacted asset, return a typed privacy failure and do not fall back to normal clear capture silently.
- If a platform reports `redactionStatus=processing`, treat it as transient event state only; never persist it as a completed asset in recent captures.
- If OCR/text detection cannot initialize and text redaction is required, block or fail privacy capture instead of recording clear output as a privacy asset.
- If photo/face redaction is requested and unavailable, continue only when the platform-specific spec allows an explicit user-visible degraded state; otherwise fail before asset registration.
- If frame processing falls behind, the platform may degrade to stronger persistence/expanded boxes/lower cadence, but it must stop and fail if it cannot keep the output coherent enough to register as best-effort privacy output.
- If capture is canceled by the OS chooser, browser chooser, projection chip, target close, permission denial, or app lifecycle event, create no completed asset unless a valid flattened redacted partial export is explicitly supported and user-initiated by that platform spec.
- If a temporary clear file cannot be deleted, mark the attempt or hidden temp record as `quarantined`, keep it outside recent captures and backend payloads, block share/export/content attachment, and surface a local cleanup warning.
- If backend write/linking is offline, preserve local review state and safe metadata; do not send local file paths or OCR-derived data when retrying later.
- If a privacy asset has `reviewState=blocked`, share/export/content attachment must remain blocked even if the user tries to acknowledge review.
- If platform-specific metadata contains unknown enum values, parse conservatively to `failed`, `blocked`, or `unknown` support state rather than treating the asset as reviewed or shareable.

## Problem

The platform privacy capture specs were drafted independently for Android, Web, and Windows, with future feasibility notes for iOS, Linux, and macOS. They share product invariants but can drift in field names, review states, temporary-file behavior, backend payloads, and disclosure wording. That drift is risky because the same Capture UI and backend metadata helper will eventually serve multiple capture pipelines. A privacy feature that is correct on one platform but sends OCR text, exposes a clear temp path, skips review, or mislabels a degraded output on another platform would break user trust and create a data exposure path.

The current app model is also too small for privacy capture. `CaptureAsset` records kind, local path, MIME type, dimensions, duration, microphone state, and capture scope. `DeviceCaptureService` only gates Android support and native events. `CaptureLocalStore` persists recent asset metadata in SharedPreferences. `_captureAssetMetadata(asset)` sends only basic capture metadata. The app needs one shared privacy contract before platform implementation work spreads across native, browser, and desktop code.

## Solution

Define a shared privacy capture contract at the Flutter model/service/API boundary. Add common Dart metadata types, JSON keys, native event fields, backend-safe metadata mapping, local review state semantics, review gate rules, and disclosure copy slots. Platform-specific implementations remain responsible for capture, OCR/detection, rendering, encoding, and cleanup, but they may register a completed privacy asset only by satisfying this contract.

The shared contract has two layers:

- Local/Dart contract: lowerCamelCase model fields and enum names used by Flutter UI, local storage, platform events, and tests.
- Backend metadata contract: snake_case JSON keys generated by `_captureAssetMetadata(asset)` and safe to send as content/capture metadata.

## Scope In

- Common `CaptureAsset` privacy metadata for Android, Web, Windows, and future iOS/Linux/macOS.
- Shared enum/value contract for `privacyMode`, `privacyContractVersion`, `privacyPlatform`, `redactionStatus`, `textRedactionStyle`, `photoRedactionStyle`, `redactionStrength`, `reviewState`, `processingStats`, and sanitized degradation reasons.
- Backwards-compatible parsing for existing normal capture assets.
- Native/platform event contract for privacy progress, notice, completed, failed, canceled, degraded, and quarantine states.
- Temporary clear file and clear-original handling rules.
- OCR/text recognition non-persistence rules.
- Backend-safe metadata payload shape for content creation and asset attachment.
- Share/export/download/content-attachment review gate contract.
- Disclosure and review gate copy contract slots for localization.
- Compatibility guidance for Android, Web, Windows, and future iOS/Linux/macOS platform implementations.
- Tests that prove old assets remain compatible, privacy assets serialize safely, review gates block risky actions, and backend payloads exclude forbidden data.
- Documentation updates to README/GUIDELINES/CHANGELOG after implementation.

## Scope Out

- Implementing any platform capture/redaction pipeline.
- Choosing platform-specific OCR, vision, rendering, encoder, or GPU libraries beyond mapping their outputs into this contract.
- Guaranteeing perfect anonymization or defining a formal privacy certification.
- Backend binary upload, cloud redaction, server-side transcoding, CDN, storage retention, or media hosting.
- Persisting OCR text, transcripts, raw screenshots, thumbnails generated from clear frames, editable redaction layers, or per-frame redaction boxes as durable metadata.
- Building a full video editor, manual timeline review UI, publishing automation, or YouTube/social upload.
- Rewriting third-party app UI text at the source.
- Changing public marketing copy before platform QA and legal/product wording review.

## Constraints

- Privacy capture is best-effort only. UI, docs, payloads, and metadata must never describe the result as guaranteed safe, fully anonymized, certified, or leak-proof.
- Normal capture behavior must remain backwards compatible when `privacyMode=false`.
- A completed privacy asset must be a flattened raster image/video output. It must not depend on clear source media plus overlay instructions.
- `redactionStatus=processing` is transient and must not be persisted as a normal completed asset.
- `redactionStatus=failed` or `redactionStatus=quarantined` must not be shareable, exportable, downloadable, or attachable to backend content.
- OCR text, accessibility node text, recognized strings, transcripts, and raw detection observations must never be persisted, logged, sent to analytics, sent to backend, or included in local metadata.
- Processing stats must be aggregate and sanitized. They may count frames/regions and name engines, but must not include recognized text, raw coordinates, frame images, thumbnails, local clear paths, temp paths, or user content.
- Temporary clear files, when technically unavoidable, must stay app-private, outside recent captures, outside gallery/export, outside backend payloads, and must be deleted or quarantined on every success/failure/cancel path.
- Content attachment is treated as an export-like action because it sends metadata and places the asset into a public-workflow context; the review gate applies before create-content-from-capture and attach-to-content.
- Backend metadata may store privacy status/settings/review state/aggregate stats, but backend must not treat `reviewed` as a security guarantee.
- Copy must preserve the concepts "best effort", "not exhaustive", and "manual review required" in each supported locale, even if exact wording changes.
- Fresh external docs are not needed for this shared model contract. Platform-specific specs and explorations already record the official docs consulted for Android/Web/Windows/iOS/Linux/macOS capture APIs.

## Dependencies

Local files and contracts:

- `app/lib/data/models/capture_asset.dart`: current `CaptureAsset` and `CaptureNativeEvent` model boundary to extend.
- `app/lib/data/services/device_capture_service.dart`: current `DeviceCaptureClient`/`DeviceCaptureService` boundary for support, platform methods, and event parsing.
- `app/lib/data/services/capture_local_store.dart`: current SharedPreferences metadata store and future review-state update surface.
- `app/lib/data/services/api_service.dart`: current `_captureAssetMetadata(asset)` helper used by content draft and asset attachment payloads.
- `app/lib/presentation/screens/capture/capture_screen.dart`: current Capture UI, local history, share, discard, create-content, and attach-content actions.
- `app/test/data/capture_asset_test.dart`: model serialization tests.
- `app/test/data/capture_local_store_test.dart`: local metadata persistence tests.
- `app/test/presentation/screens/capture/capture_screen_test.dart`: Capture UI and event-flow tests.
- `app/README.md`, `shipglows_data/technical/app/guidelines.md`, and `app/CHANGELOG.md`: docs to align after implementation.

Source specs and explorations:

- `shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md`
- `shipglows_data/workflow/specs/app/SPEC-web-privacy-capture-dynamic-redaction.md`
- `shipglows_data/workflow/specs/app/SPEC-windows-privacy-capture-dynamic-redaction.md`
- `shipglows_data/workflow/explorations/2026-05-06-screen-text-obfuscation.md`
- `shipglows_data/workflow/explorations/2026-05-08-ios-privacy-capture-redaction.md`
- `shipglows_data/workflow/explorations/2026-05-08-linux-privacy-capture-redaction.md`
- `shipglows_data/workflow/explorations/2026-05-08-macos-privacy-capture-redaction.md`

Fresh external docs verdict: `fresh-docs not needed` for the shared contract itself. This spec depends on local specs/explorations that already cite current official platform docs where capture APIs govern implementation.

## Invariants

- Privacy capture output is local-first unless a separate backend media upload spec explicitly changes that.
- Normal asset history may contain only normal captures and finalized safe privacy assets, never clear privacy intermediates.
- Backend capture metadata may contain privacy settings and sanitized aggregate stats, never OCR text, frame data, local clear paths, temp paths, or raw region maps.
- Review acknowledgement is a product safety gate, not a claim that ContentGlows verified the asset as safe.
- `reviewState=reviewed` means the user acknowledged reviewing the flattened output; it does not mean the app guarantees no sensitive content remains.
- Platform implementations may use different APIs and output containers, but they must map into the same Dart and backend metadata contract.
- Unsupported platforms must fail closed: no startable privacy controls that imply support and no clear fallback marked as privacy output.
- Existing non-privacy assets and normal capture flows remain compatible.

### Common Metadata Contract

Local/Dart model fields:

| Field | Type | Required | Allowed values | Meaning |
|-------|------|----------|----------------|---------|
| `privacyMode` | `bool` | yes | `false`, `true` | Whether the capture was requested through privacy mode. Defaults to `false` for old assets. |
| `privacyContractVersion` | `String` | yes for privacy assets | `1.0` for this spec | Version of the shared contract used by the asset. Normal old assets may omit it. |
| `privacyPlatform` | enum | yes for privacy assets | `android`, `web`, `windows`, `ios`, `linux`, `macos`, `unknown` | Platform implementation that produced the asset. |
| `redactionStatus` | enum | yes | `notRequested`, `processing`, `privacyBestEffort`, `degradedBestEffort`, `failed`, `quarantined` | Redaction lifecycle/status. `processing` is transient; `failed` and `quarantined` are not normal shareable assets. |
| `textRedactionStyle` | enum | yes for privacy assets | `none`, `blur`, `pixelate`, `scramble` | Text treatment requested/applied. `scramble` means cover real pixels and draw fake glyphs/lines. |
| `photoRedactionStyle` | enum | yes for privacy assets | `off`, `blur`, `pixelate` | Photo/image/face treatment requested/applied where supported. |
| `redactionStrength` | enum | yes for privacy assets | `balanced`, `strong` | Conservative strength knob shared across platforms. Platform-specific values must map to one of these in V1. |
| `reviewState` | enum | yes | `notRequired`, `needsReview`, `reviewed`, `blocked` | Review gate state. Privacy success/degraded assets start at `needsReview`; failed/quarantined assets use `blocked`. |
| `processingStats` | object | optional | sanitized aggregate keys only | Counts and engine labels useful for review/debug without user content. |
| `degradationReasons` | list of strings | optional | stable reason codes | Sanitized reason codes such as `ocr_unavailable`, `frame_lag`, `photo_detection_disabled`, `export_format_fallback`, `cleanup_quarantined`. |

Backend metadata keys generated from this model:

| Backend key | Source field | Safe to send | Notes |
|-------------|--------------|--------------|-------|
| `privacy_mode` | `privacyMode` | yes | Boolean only. |
| `privacy_contract_version` | `privacyContractVersion` | yes | Include for privacy assets. |
| `privacy_platform` | `privacyPlatform` | yes | Stable enum label. |
| `redaction_status` | `redactionStatus` | yes | Backend must not treat status as a guarantee. |
| `text_redaction_style` | `textRedactionStyle` | yes | Style only, no recognized text. |
| `photo_redaction_style` | `photoRedactionStyle` | yes | Style only. |
| `redaction_strength` | `redactionStrength` | yes | Shared strength label. |
| `review_state` | `reviewState` | yes | User acknowledgement state, not safety proof. |
| `processing_stats` | `processingStats` | yes if sanitized | Aggregate counts and engine labels only. |
| `degradation_reasons` | `degradationReasons` | yes if sanitized | Stable reason codes only. |

Allowed `processingStats` keys:

- `framesAnalyzed`
- `framesRedacted`
- `textRegionsRedacted`
- `photoRegionsRedacted`
- `faceRegionsRedacted`
- `droppedFrameCount`
- `processingDurationMs`
- `analysisEngine`
- `renderEngine`
- `exportEngine`
- `outputFormat`
- `maxObservedLagMs`
- `degraded`

Forbidden metadata anywhere durable:

- recognized text strings, OCR transcripts, accessibility node text, or model prompts;
- raw screenshots, frame images, clear thumbnails, frame hashes derived from clear content, or OCR sidecar files;
- raw per-frame redaction boxes or coordinates;
- clear original path, temp path, object URL, file descriptor, system picker handle, or local directory structure;
- editable redaction layers, masks that can reveal clear pixels, or unredacted auxiliary tracks;
- user secrets, tokens, messages, names, URLs, account identifiers, or copied app text.

## Links & Consequences

- Product: privacy capture becomes a cross-platform feature family instead of isolated platform features; shared wording and states matter.
- Security/privacy: the contract becomes a trust boundary between native/browser pipelines, Flutter UI, local persistence, and backend metadata.
- Data: `CaptureAsset` and local JSON parsing must remain backwards compatible while adding privacy fields.
- Backend: no schema migration is expected if privacy metadata remains nested inside existing metadata JSON, but payload tests must prove unsafe keys are absent.
- UI: share/export/content attachment must route through a review gate for privacy assets; this affects existing buttons in Capture.
- Offline: local review state must persist and replay safely when backend attachment retries later.
- Compatibility: future platform teams can implement native pipelines without redefining review states or backend payload semantics.
- Docs: README/GUIDELINES/CHANGELOG must explain the shared best-effort contract and data minimization rules.
- QA: automated tests can prove contract safety and gate behavior; platform manual QA remains required for redaction quality.

### Temporary File And Clear Original Rules

- Privacy mode must not save a clear original as a normal `CaptureAsset`.
- If a platform can redact before writing output, that is preferred.
- If clear buffers are unavoidable in memory, release them promptly after deriving redaction output.
- If clear temporary files are unavoidable, they must be app-private, excluded from recent captures, excluded from OS gallery/library, excluded from share/export/content attachment, and excluded from backend payloads.
- Clear temporary files must use a platform-owned privacy temp area with startup cleanup for stale files.
- Success requires deletion of clear temporary files before the privacy asset is considered safe to register.
- Failure/cancel requires deletion when possible; if deletion cannot be confirmed, quarantine outside normal history and block all user-facing use of that file.
- Quarantine diagnostics must avoid printing or sending full clear paths; user-facing copy may say cleanup is required without exposing sensitive path details.
- Post-production workflows that create a clear original cannot mark the clear original as `privacyMode=true`; only the flattened redacted result can become a privacy asset, and the clear original must follow the temp/quarantine rules.

### Disclosure Copy Contract

Localization keys and required semantics:

| Copy key | Required meaning | Interpolation slots |
|----------|------------------|---------------------|
| `privacyCapture.disclosure.title` | Privacy capture is being enabled. | `{platformLabel}` |
| `privacyCapture.disclosure.bestEffort` | Redaction is best-effort and non-exhaustive. | none |
| `privacyCapture.disclosure.localProcessing` | Capture/redaction runs locally for this feature version. | `{platformLabel}` |
| `privacyCapture.disclosure.noGuarantee` | ContentGlows does not guarantee every sensitive item is hidden. | none |
| `privacyCapture.disclosure.reviewRequired` | The user must manually review before sharing/exporting/attaching. | none |
| `privacyCapture.disclosure.tempFiles` | Unsafe clear intermediates are not exposed and failed cleanup blocks use. | none |
| `privacyCapture.disclosure.accept` | User accepts starting privacy capture with those limits. | none |
| `privacyCapture.disclosure.cancel` | User cancels and no privacy capture starts. | none |
| `privacyCapture.reviewGate.title` | Review is required before public use. | none |
| `privacyCapture.reviewGate.body` | The asset is best-effort redacted; user is responsible for checking the final output. | `{redactionStatus}`, `{degradationReasons}` |
| `privacyCapture.reviewGate.confirmReviewed` | User confirms they reviewed the flattened output. | none |
| `privacyCapture.reviewGate.cancel` | User returns without sharing/exporting/attaching. | none |
| `privacyCapture.degradedNotice` | Capture completed with a nonfatal limitation that requires extra review. | `{degradationReasons}` |
| `privacyCapture.quarantineWarning` | Capture could not be safely finalized because cleanup/quarantine is required. | none |
| `privacyCapture.unsupported` | The current platform/browser/device cannot safely run privacy capture. | `{platformLabel}`, `{reason}` |

Copy constraints:

- Required meanings must survive localization; exact English words are not mandatory.
- Do not use guarantee language such as "safe", "fully anonymized", "certified", "all sensitive data removed", or "leak-proof" unless negated as part of a warning.
- Keep disclosure concise in UI. Longer legal/product wording can live in docs, but the capture flow must still show the required concepts before capture starts.
- Review gate copy must appear for share/export/download/create-content/attach-content when `reviewState=needsReview`.

## Documentation Coherence

- Update `shipglows_data/technical/app/guidelines.md` with this shared privacy metadata, backend-safe payload, OCR non-persistence, temp-file/quarantine, and review gate contract.
- Update `app/README.md` with a product-facing explanation of cross-platform privacy capture status, best-effort limitation, local-first processing, and manual review requirement.
- Update `app/CHANGELOG.md` after implementation lands.
- Update platform specs or implementation notes to reference this spec as the shared contract before platform-specific implementation starts.
- Do not update public marketing copy until at least one platform implementation passes manual QA and product/legal wording review.
- Do not update `.env.example` unless implementation introduces a configurable privacy feature flag, OCR worker path, or backend contract setting.

## Edge Cases

- Existing assets without privacy fields must parse as normal non-privacy captures.
- A privacy asset completes with a platform-specific unknown enum value.
- A platform emits `completed` while temp cleanup is still pending.
- A privacy recording is canceled after a partial redacted output exists.
- A privacy recording produces a valid redacted WebM while UI expected MP4.
- A platform emits a degraded state because OCR falls behind during fast scroll.
- Photo/face detection is disabled or unavailable while text redaction succeeds.
- The user tries to share a `needsReview` asset, then cancels the review gate.
- The user reviews an asset offline, then later attaches it to backend content.
- Backend attachment retries after app restart and must use the latest local review state.
- A quarantined temp file exists on startup after a crash.
- A native implementation logs a platform error containing a local temp path.
- A browser object URL or native temp path accidentally enters `processingStats`.
- A future iOS/Linux/macOS implementation uses different capture APIs but must still map into the same fields.

## Implementation Tasks

- [ ] Task 1: Add shared privacy metadata enums and value contract.
  - File: `app/lib/data/models/capture_asset.dart`
  - Action: Add `PrivacyPlatform`, `RedactionStatus`, `TextRedactionStyle`, `PhotoRedactionStyle`, `RedactionStrength`, `ReviewState`, and a sanitized `PrivacyProcessingStats` representation, or split them into a focused model file imported by `capture_asset.dart` if that keeps the model readable.
  - User story link: Establishes the common contract every platform must return.
  - Depends on: None.
  - Validate with: `flutter test test/data/capture_asset_test.dart`.
  - Notes: Use lowerCamelCase Dart fields and parse snake_case aliases where native/backend maps already use them.

- [ ] Task 2: Extend `CaptureAsset` parsing and serialization backwards compatibly.
  - File: `app/lib/data/models/capture_asset.dart`
  - Action: Add privacy fields with defaults for old assets; serialize local metadata with no OCR text, no raw boxes, no temp paths, and no binary data.
  - User story link: Lets existing captures keep working while privacy assets carry required state.
  - Depends on: Task 1.
  - Validate with: `flutter test test/data/capture_asset_test.dart`.
  - Notes: Unknown privacy enum values must fail closed to blocked/failed-style behavior, not reviewed/shareable behavior.

- [ ] Task 3: Define shared privacy capture options and event fields at the service boundary.
  - File: `app/lib/data/services/device_capture_service.dart`
  - Action: Add typed privacy options/status/failure parsing for platform clients, including platform capability data and privacy event reason codes, while keeping normal capture methods compatible.
  - User story link: Gives Android/Web/Windows/future platforms a stable Flutter boundary for privacy requests and results.
  - Depends on: Tasks 1 and 2.
  - Validate with: service tests or fake `MethodChannel`/client tests for normal and privacy events.
  - Notes: Do not silently route unsupported platforms into normal clear capture.

- [ ] Task 4: Add local review-state update and quarantine-aware metadata behavior.
  - File: `app/lib/data/services/capture_local_store.dart`
  - Action: Add a metadata-only update path for `reviewState`, `redactionStatus`, sanitized `processingStats`, and degradation reasons without rewriting binary files or changing recent capture ordering.
  - User story link: Lets users review once and safely continue share/export/content attachment later.
  - Depends on: Task 2.
  - Validate with: `flutter test test/data/capture_local_store_test.dart`.
  - Notes: Quarantined/blocked assets must not appear as normal shareable captures.

- [ ] Task 5: Sanitize backend capture metadata payloads.
  - File: `app/lib/data/services/api_service.dart`
  - Action: Extend `_captureAssetMetadata(asset)` with the backend metadata keys from this spec; exclude OCR text, raw boxes, clear frame data, local clear paths, temp paths, object URLs, and editable layer metadata.
  - User story link: Preserves privacy context in content metadata without leaking sensitive capture data.
  - Depends on: Task 2.
  - Validate with: targeted API payload test covering privacy and normal assets.
  - Notes: Do not add backend schema changes unless a later readiness gate proves metadata JSON is insufficient.

- [ ] Task 6: Apply the review gate to all public-use actions.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Block share/export/download/create-content/attach-content for `reviewState=needsReview` until acknowledgement; keep `blocked` assets blocked; persist `reviewState=reviewed` through the local store.
  - User story link: Makes manual review mandatory before a privacy-marked capture enters a public workflow.
  - Depends on: Tasks 2 and 4.
  - Validate with: `flutter test test/presentation/screens/capture/capture_screen_test.dart`.
  - Notes: Content attachment is included because it sends metadata and moves the asset into a publishing workflow.

- [ ] Task 7: Add disclosure and review gate copy slots.
  - File: `app/lib/presentation/screens/capture/capture_screen.dart`
  - Action: Implement UI references to the disclosure/review copy keys and required semantics from this spec, using existing localization helpers.
  - User story link: Ensures users understand best-effort limits before capture and review obligations before public use.
  - Depends on: Task 6.
  - Validate with: widget tests for disclosure acceptance, cancellation, degraded notice, and review gate copy.
  - Notes: Keep wording concise; do not hard-code guarantee language.

- [ ] Task 8: Align platform-specific contracts to the shared field names.
  - File: `shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md`, `shipglows_data/workflow/specs/app/SPEC-web-privacy-capture-dynamic-redaction.md`, `shipglows_data/workflow/specs/app/SPEC-windows-privacy-capture-dynamic-redaction.md`
  - Action: Update platform implementation notes so native/browser platform events and assets map into this shared contract, especially redaction status, review state, processing stats, temp cleanup, and backend-safe payload semantics.
  - User story link: Prevents platform drift before implementation starts.
  - Depends on: This shared spec being accepted.
  - Validate with: spec review through `/sf-ready shared privacy capture contract`.
  - Notes: Keep platform-specific API choices in platform specs; only centralize shared behavior here.

- [ ] Task 9: Add contract tests for forbidden durable data.
  - File: `app/test/data/capture_asset_test.dart`, `app/test/data/capture_local_store_test.dart`, `app/test/presentation/screens/capture/capture_screen_test.dart`
  - Action: Add tests proving old assets default safely, privacy assets serialize required fields, `needsReview` blocks public-use actions, `blocked/quarantined` cannot be shared, and unsafe keys are absent from local/API metadata.
  - User story link: Protects the shared privacy promise from regressions.
  - Depends on: Tasks 1-7.
  - Validate with: targeted Flutter tests.
  - Notes: Include negative fixtures containing `ocrText`, `recognizedText`, `clearPath`, `tempPath`, `objectUrl`, and raw `boxes` keys and assert they are dropped or rejected.

- [ ] Task 10: Update documentation after implementation.
  - File: `shipglows_data/technical/app/guidelines.md`, `app/README.md`, `app/CHANGELOG.md`
  - Action: Document the shared contract, data minimization rules, temp-file/quarantine behavior, review gate, and supported platform status.
  - User story link: Aligns implementers and operators with the feature's real guarantees.
  - Depends on: Tasks 1-9.
  - Validate with: docs review.
  - Notes: Do not make public marketing claims until platform QA proves the user-visible experience.

## Acceptance Criteria

- [ ] CA 1: Given an existing non-privacy asset without privacy fields, when it is parsed, then it defaults to `privacyMode=false`, `redactionStatus=notRequested`, `reviewState=notRequired`, and existing normal capture behavior still works.
- [ ] CA 2: Given a completed privacy asset from any supported platform, when Flutter registers it, then it includes the required shared fields: `privacyMode`, `privacyContractVersion`, `privacyPlatform`, `redactionStatus`, `textRedactionStyle`, `photoRedactionStyle`, `redactionStrength`, `reviewState`, and sanitized `processingStats`.
- [ ] CA 3: Given a platform emits a transient privacy progress event, when local storage is saved, then `redactionStatus=processing` is not persisted as a completed asset.
- [ ] CA 4: Given a privacy capture fails, when the flow returns to idle, then no clear or misleading privacy asset appears in recent captures.
- [ ] CA 5: Given a clear temp file cannot be deleted, when cleanup completes unsuccessfully, then the attempt is blocked/quarantined and cannot be shared, exported, downloaded, created as content, attached to content, or sent to backend metadata as a normal asset.
- [ ] CA 6: Given OCR or text recognition runs, when asset metadata, local storage, logs, analytics, and backend payloads are inspected, then recognized text strings and transcripts are absent.
- [ ] CA 7: Given privacy `processingStats` are persisted or sent to backend, when the payload is inspected, then stats are aggregate only and contain no raw text, raw boxes, frame data, thumbnails, object URLs, clear paths, or temp paths.
- [ ] CA 8: Given a privacy asset has `reviewState=needsReview`, when the user attempts share/export/download/create-content/attach-content, then the action is blocked by the review gate.
- [ ] CA 9: Given the user confirms the review gate, when local metadata is saved, then `reviewState=reviewed` persists and the original asset ordering/content links remain stable.
- [ ] CA 10: Given a privacy asset has `reviewState=blocked` or `redactionStatus=quarantined`, when the user attempts any public-use action, then the action remains blocked even after attempted acknowledgement.
- [ ] CA 11: Given `_captureAssetMetadata(asset)` builds backend metadata for a privacy asset, when the payload is inspected, then it includes safe snake_case privacy fields and excludes unsafe OCR/temp/path/layer fields.
- [ ] CA 12: Given a web privacy asset exports WebM or another non-MP4 format, when it is registered, then MIME type, file extension, user copy, and backend metadata reflect the actual output format.
- [ ] CA 13: Given Android, Web, and Windows platform specs are read after this contract, when their implementation notes are aligned, then they reference this spec for shared metadata, review state, backend payload, temp-file, and OCR non-persistence behavior.
- [ ] CA 14: Given a future iOS, Linux, or macOS implementation is planned, when the team maps its platform events to this contract, then no new shared enum is needed for basic success, degraded, failed, review, or quarantine behavior.
- [ ] CA 15: Given disclosure/review localization keys are implemented, when privacy capture starts or a privacy asset is used publicly, then the user sees copy covering best-effort, non-exhaustive protection, no guarantee, local processing for this version, and manual review required.
- [ ] CA 16: Given privacy mode is off, when normal capture tests run, then normal screenshot/record/share/discard/create/link behavior remains compatible except for safe shared model defaults.

## Test Strategy

- Dart model tests:
  - Backwards-compatible parsing of old `CaptureAsset` JSON/platform maps.
  - Serialization of privacy assets with all required shared fields.
  - Fail-closed parsing of unknown privacy enum values.
  - Sanitization/rejection of forbidden keys such as OCR text, clear paths, temp paths, object URLs, thumbnails, and raw boxes.
- Local store tests:
  - Metadata-only `reviewState` updates.
  - Recent capture ordering preserved after review acknowledgement.
  - Blocked/quarantined assets excluded from normal shareable history behavior.
  - Offline/restart persistence of review state.
- API payload tests:
  - `_captureAssetMetadata(asset)` includes safe snake_case privacy keys.
  - Payloads exclude OCR text, raw boxes, local clear paths, temp paths, object URLs, editable layers, and clear thumbnails.
  - Normal non-privacy payloads remain compatible.
- Widget/service tests:
  - Disclosure required before privacy capture start where platform support exists.
  - Review gate blocks share/export/download/create-content/attach-content for `needsReview`.
  - `blocked` and `quarantined` remain blocked.
  - Unsupported platform does not route to clear capture as a privacy fallback.
- Contract review:
  - Android/Web/Windows specs reference this shared contract before implementation.
  - Future iOS/Linux/macOS planning can map platform-specific outputs to existing fields.
- Validation commands:
  - `flutter test test/data/capture_asset_test.dart test/data/capture_local_store_test.dart test/presentation/screens/capture/capture_screen_test.dart`
  - `flutter analyze`
  - Platform-specific build/manual QA remains in the platform specs, not this shared contract.

## Risks

- Security risk: a platform implementation may satisfy field names while failing temp cleanup or OCR non-persistence internally.
- Trust risk: `reviewed` may be misread as "safe"; copy and backend semantics must keep it as user acknowledgement only.
- Drift risk: Android/Web/Windows/future native modules may invent local enum values or reason codes unless the shared contract is enforced in tests.
- Backwards compatibility risk: adding required fields to `CaptureAsset` can break old JSON unless defaults are explicit.
- Backend risk: metadata JSON is flexible, so unsafe keys can sneak in unless `_captureAssetMetadata` is the only payload path and tests cover negative fixtures.
- UX risk: adding gates to share/export/content attachment can feel repetitive unless review state persists correctly.
- Operations risk: quarantined files are intentionally not normal assets, but users still need a clear local cleanup path.
- Scope risk: this shared contract does not prove any platform redaction quality; platform specs must still require manual QA.

## Execution Notes

Read first:

- `shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md`
- `shipglows_data/workflow/specs/app/SPEC-web-privacy-capture-dynamic-redaction.md`
- `shipglows_data/workflow/specs/app/SPEC-windows-privacy-capture-dynamic-redaction.md`
- `app/lib/data/models/capture_asset.dart`
- `app/lib/data/services/device_capture_service.dart`
- `app/lib/data/services/capture_local_store.dart`
- `app/lib/data/services/api_service.dart`
- `app/lib/presentation/screens/capture/capture_screen.dart`

Implementation approach:

1. Add shared metadata enums/value parsing with backwards-compatible defaults.
2. Extend local `CaptureAsset` serialization and native/platform event parsing.
3. Add local review-state update support.
4. Sanitize backend metadata payloads.
5. Add review gate and disclosure copy in Capture UI.
6. Add negative tests for forbidden durable data.
7. Align Android/Web/Windows specs to depend on this contract before starting platform implementation.

Constraints for implementers:

- Do not implement platform redaction pipelines as part of this shared contract.
- Do not persist OCR text anywhere.
- Do not expose clear temporary files through normal capture history, share/export/content attachment, or backend metadata.
- Do not make backend schema changes unless `/sf-ready` explicitly expands scope.
- Do not make `reviewed` mean "verified safe"; it means the user acknowledged manual review.
- Do not let unsupported or failed privacy capture fall back to clear normal capture without explicit user action outside privacy mode.
- Stop and rescope if a platform requires a persistent clear original to complete privacy capture.

Fresh external docs: `fresh-docs not needed` for this shared contract; platform-specific source docs are already recorded in the source specs and explorations.

## Open Questions

- None blocking for this draft. Contract decisions fixed here:
  - `create-content-from-capture` and `attach-to-content` are treated as public-use actions and use the same review gate as share/export.
  - Backend receives only sanitized metadata and must not receive OCR text, clear paths, temp paths, raw boxes, or clear thumbnails.
  - `reviewed` is an acknowledgement state, not a safety certification.
  - Future iOS/Linux/macOS must map into the same shared fields before adding platform-specific fields.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-08 10:06:37 UTC | sf-spec | GPT-5 Codex | Created shared cross-platform privacy capture contract from Android/Web/Windows specs, privacy obfuscation exploration, future platform explorations, and current capture model/service/API code. | draft saved | /sf-ready shared privacy capture contract |

## Current Chantier Flow

sf-spec done -> sf-ready not launched -> sf-start not launched -> sf-verify not launched -> sf-end not launched -> sf-ship not launched
