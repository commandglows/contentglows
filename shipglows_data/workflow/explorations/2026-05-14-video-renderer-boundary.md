---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-14"
updated: "2026-05-14"
status: draft
source_skill: sf-explore
scope: "video timeline renderer boundary"
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - app
  - lab
  - contentglowz_remotion_worker
  - project asset library
  - future video timeline editor
evidence:
  - "Current product discussion clarified that ContentGlowz should not have two competing timelines."
  - "Current product discussion clarified that ContentGlowz should own the timeline model and editor experience."
  - "User decision 2026-05-14: prefer a mature rendering product over a less proven Dart-only renderer if maturity protects the application."
  - "Remotion official renderer docs expose server-side renderMedia(), selectComposition(), JSON inputProps, codec options, progress callbacks, browser reuse, and FFmpeg-related rendering concerns."
  - "Fluvie presents a Flutter/Dart Remotion-like approach but still renders frames and encodes through FFmpeg."
  - "Laminar is a young Dart/Flutter Remotion-inspired package with very low public adoption at time of research."
  - "FFmpegKit was officially retired and archived, making direct Flutter FFmpeg dependency strategy risky without owning builds/forks."
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    required_status: "ready"
supersedes: []
next_step: "/sf-spec Unified ContentGlowz Video Timeline"
---

# Exploration Report: Video Renderer Boundary

## Starting Question

Where should ContentGlowz draw the boundary between proprietary product code and rendering infrastructure for a real video timeline? Is Remotion a low-level indispensable layer, should a Dart/Flutter renderer be preferred, or should ContentGlowz build the renderer itself?

## Context Read

- `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md` - existing ready spec frames the current plan as a guided Remotion storyboard, not a single source-of-truth timeline.
- `app/lib/presentation/screens/editor/editor_screen.dart` - current editor can open project assets but has no video timeline.
- `app/lib/presentation/widgets/project_asset_picker.dart` - existing asset picker links assets to content targets, which is relevant for future timeline clip insertion.

## Internet Research

- [Remotion renderMedia() official docs](https://www.remotion.dev/docs/renderer/render-media) - Accessed 2026-05-14 - confirmed Remotion's server-side render API accepts composition, codec, output path, inputProps, progress callbacks, audio/video settings and browser/FFmpeg-related options.
- [Remotion SSR Node official docs](https://www.remotion.dev/docs/ssr-node) - Accessed 2026-05-14 - confirmed Remotion's intended server-side rendering architecture.
- [Fluvie](https://fluvie.dev/) - Accessed 2026-05-14 - identified a Flutter/Dart Remotion-like renderer that captures Flutter frames and encodes with FFmpeg.
- [Laminar on pub.dev](https://pub.dev/packages/laminar) - Accessed 2026-05-14 - identified a young Remotion-inspired Dart/Flutter package with low public adoption at research time.
- [FFmpegKit GitHub repository](https://github.com/arthenica/ffmpeg-kit) - Accessed 2026-05-14 - confirmed official retirement/archive and binary removal schedule, making it risky as a primary Flutter-side foundation.

## Problem Framing

The real product value is not "React vs Dart" or "Remotion vs no Remotion". The product value is a stable ContentGlowz video model that users can edit, validate, version, preview and render. The renderer should be treated as an execution engine behind a boundary, not as the source of truth.

## Option Space

### Option A: ContentGlowz Owns Timeline, Remotion Renders V1

- Summary: Build the timeline model, Flutter UI, backend validation, asset rules and renderer adapter ourselves. Use Remotion as the first production renderer behind that adapter.
- Pros: fastest route to reliable MP4 output, mature server-side render API, keeps ContentGlowz product logic proprietary and portable.
- Cons: introduces Node/React rendering infrastructure and a Remotion dependency.

### Option B: ContentGlowz Owns Timeline, Dart/Flutter Renderer Renders V1

- Summary: Use or build a Dart/Flutter Remotion-like renderer such as Fluvie/Laminar, keeping the composition language closer to the Flutter app.
- Pros: language coherence with the app, potential reuse of Flutter widgets and design system.
- Cons: current ecosystem appears younger, still depends on FFmpeg-style encoding, server/headless rendering and long-form stability need proof.

### Option C: ContentGlowz Builds Full Renderer From Scratch

- Summary: Build timeline, frame rendering, media decode, audio mixing, effects, codecs, muxing and export pipeline ourselves.
- Pros: maximum control.
- Cons: too low-level for current product stage; codec/container/audio/media compatibility risks can dominate roadmap value.

## Comparison

The recommended boundary is not "do not build the adapter". The recommended boundary is the opposite: build the adapter and own it. Do not build the low-level renderer, codecs or media stack until a proven product need forces it.

## Emerging Recommendation

ContentGlowz should own:

- timeline JSON/schema;
- Flutter timeline editor;
- backend validation and versioning;
- asset eligibility and rights checks;
- preview/final render state machine;
- renderer adapter contract;
- Remotion adapter implementation for V1.

ContentGlowz should not own in V1:

- video codec implementation;
- MP4 container/muxer implementation;
- low-level media decoding;
- headless frame capture engine from scratch;
- cross-platform FFmpeg binary distribution.

Given the user preference for a mature product, Remotion is the preferred V1 renderer unless the Dart/Flutter POC shows unexpectedly strong maturity, maintainability and deployment reliability.

## Non-Decisions

- Whether Fluvie can replace Remotion later.
- Whether a native/FFmpeg/MLT renderer should exist later.
- Whether the timeline UI exposes a full professional editor or a constrained V1.

## Rejected Paths

- Two timelines - rejected because storyboard and timeline would drift and confuse product state.
- Remotion-owned product model - rejected because ContentGlowz should not make Remotion props the canonical data model.
- Pure from-scratch renderer in V1 - rejected because it shifts effort into codecs and media plumbing instead of user-visible timeline capability.

## Risks And Unknowns

- Remotion licensing and commercial constraints need explicit review before production commitment.
- Fluvie needs a real spike before being dismissed or adopted.
- Flutter headless/server rendering may have operational constraints that only a POC will reveal.
- Audio mixing, captions and video clips will increase renderer complexity beyond image/text-only timelines.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: No secrets, tokens, customer data or private logs were included.

## Decision Inputs For Spec

- User story seed: As a ContentGlowz creator, I want one video timeline that can assemble images, videos, text and audio, preview it, and render final social formats without managing rendering internals.
- Scope in seed: unified timeline model, Flutter editor, server-side validation, renderer adapter interface, RemotionRendererAdapter V1, renderer alternatives spike.
- Scope out seed: custom codec stack, arbitrary professional editor parity, client-side final rendering as the only path, two independent timeline/storyboard models.
- Invariants/constraints seed: ContentGlowz timeline is source of truth; renderer props are derived; only server-validated asset IDs enter renders; stale preview cannot become final; renderer can be replaced behind an adapter.
- Validation seed: render fixture matrix comparing Remotion and Dart/Flutter POC on text+image, multi-track, video clip and audio cases.

## Handoff

- Recommended next command: `/sf-spec Unified ContentGlowz Video Timeline`
- Why this next step: the decision space is clear enough to turn into a product/technical spec with explicit renderer boundaries and POC gates.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-05-14 14:45:50 UTC | Renderer boundary and build-vs-buy question | Compared Remotion, Dart/Flutter renderer candidates and from-scratch renderer scope | Recommended owning the timeline and adapter while using Remotion as V1 renderer behind a replaceable boundary | `/sf-spec Unified ContentGlowz Video Timeline` |
| 2026-05-14 14:45:50 UTC | Maturity preference | Captured user preference for mature renderer choice | Remotion remains preferred V1 renderer; Dart/Flutter renderer stays POC/future candidate | `/sf-spec Unified ContentGlowz Video Timeline` |
