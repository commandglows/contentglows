---
ast: spec
artifact_version: "1.0.0"
project: "contentglows"
metadata_schema_version: "1.0"
created: "2026-08-09"
created_at: "2026-08-09 00:00:00 UTC"
updated: "2026-08-09"
updated_at: "2026-08-09 00:00:00 UTC"
status: draft
source_skill: 100-sg-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: high
user_story: "En tant que créatrice ContentGlows, je veux un mode d’édition visuelle structuré (timeline + motion, audio, texte/captions et aide IA) pour retoucher rapidement des videos déjà générées, avec une trajectoire claire vers des capacités de niveau professionnel sans créer de second modèle de rendu."
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - "app"
  - "lab"
  - "worker"
  - "Unified ContentGlows Video Timeline"
  - "Brand Profiles"
  - "Remotion"
  - "project assets"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-unified-contentglows-video-timeline-2026-05-14.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-branding-editor-as-rule-editor-for-canonical-video-generation-2026-07-08.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ahead-of-time-branded-video-generation-runs-and-feed-readiness-2026-07-08.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-feed-native-ready-made-video-review-cards-and-publish-preflight-2026-07-08.md"
    artifact_version: "1.0.0"
    required_status: "ready"
supersedes: []
evidence:
  - "Filmora/PixVerse parity is currently tracked as backlog in lab/TASKS.md (Filmora Parity Roadmap, PixVerse Parity Roadmap)."
  - "Canonical timeline stack is implemented enough for versioned, preview-gated editing (`lab/api/routers/video_timelines.py`, `lab/api/models/video_timeline.py`, `app/lib/presentation/screens/editor/video_timeline_screen.dart`)."
  - "Branding rule editing is implemented in a dedicated surface and does not own timeline rendering (`SPEC-branding-editor-as-rule-editor-for-canonical-video-generation`)."
  - "Draft specs exist for text-based editing and scene-motion assistance but are standalone: `SPEC-text-based-media-editing-social-video-2026-05-12` and `SPEC-remotion-scene-motion-assistant-2026-05-12`."
next_step: /sf-spec professional-video-editor-capability-roadmap 2026-08-09
---

# Pro Editor Capability Roadmap (Filmora / PixVerse)

## Status

Draft. This spec defines the concrete roadmap to grow the current canonical timeline into a Filmora/PixVerse-inspired editing surface while preserving one model of truth and one rendering stack. It is not about inventing a second renderer. It is about progressively adding high-value editor capabilities around the existing `/editor/:id/video` timeline and branded-generation pipeline.

## User Story

En tant que créatrice ContentGlows, je veux retoucher rapidement une vidéo déjà générée via un éditeur visuel guidé (timeline, keyframes, audio, captions, motion), avec des options Filmora/PixVerse pertinentes, sans perdre la promesse principale: génération prête à publier par défaut puis édition optionnelle.

## Positioning and Invariants

- The canonical editable model remains `ContentGlows` timeline V1 from `SPEC-unified-contentglows-video-timeline-2026-05-14`.
- The branding editor remains a rules layer, not a second media assembly engine.
- There is one render path: backend timeline version -> Remotion props -> worker.
- Flutter never calls Remotion directly.
- Offline-only and destructive edits remain out of scope for this phase.
- Editing remains preview-gated and publish-gated as today.

## Minimal Contract

1. Keep `/editor/:id/video` as the only edit surface for generated timeline corrections.
2. Add advanced editing primitives as bounded, owned milestones:
   - timeline ergonomics (non-destructive and version-safe)
   - keyframe animation graph for supported media properties
   - transcript-native cut/edit workflows
   - caption pipeline (auto generation + manual override)
   - audio finishing and track-level controls
   - motion/tracking helpers where feasible
3. Preserve auto-first flow: `branded generate -> feed ready state -> optional edit -> publish`.
4. Every new capability must consume and mutate the existing timeline json shape (`clips`, `assets`, `metadata`, preview state), or a strictly backward-compatible extension.

## Current State (as of 2026-08-09)

Already in scope:
- canonical timeline model and preview/final gate (`SPEC-unified-contentglows-video-timeline`)
- AI-first branded draft generation, feed projection, and swipe publish (`SPEC-ai-first...`, `SPEC-ahead-of-time...`, `SPEC-feed-native-ready-made-video-review-cards`)
- branding rules editor and preview-through-generation path (`SPEC-branding-editor-as-rule-editor...`)

Missing/under-implemented:
- advanced animation graph and keyframe editing
- full text/transcript-native correction loop
- native caption generation/edits/timing UX
- audio finish stack (normalization, ducking, volume envelopes)
- motion-assisted editing tools

## Core Workstreams

### W1 — Timeline Correction UX

- Ripple trim, split, duplicate, scrub, zoom, undo/redo, keyboard shortcuts.
- Track semantics: locking, muting, clip insert/reorder constraints.
- Playhead/selection improvements: faster edits without regressions.

### W2 — Motion and Property Animation

- Keyframe model on top of clip fields: `transform`, `opacity`, `scale`, `rotation`, `crop`, `blur`, `volume`.
- Curve/easing editor with bounded controls.
- Per-timeline motion budget to cap complexity.

### W3 — Transcript, Captions and Text Editing

- `speech-to-text` ingestion path from owned renderable source.
- Text segment graph for cut/split/mute operations.
- Caption generation + track-level style presets.
- Manual caption text correction with provenance.

### W4 — Audio and Mix Controls

- Track and clip-level volume envelopes.
- Fade/ducking/normalization helpers.
- Beat-aware preview markers and mix-safe caps.

### W5 — Assisted Creative Layer

- AI suggestions for hook placement, scene order tweaks, transitions, pacing.
- Template and preset catalog for intro/outro, lower-thirds, CTA timing.

### W6 — Pro Assist Additions (Next)

- Motion tracking and freeze-frame utilities where model permits.
- Scene extraction suggestions from longform material.
- Per-brand reusable look/animation presets and export presets.

## Functional Scope by Phase

#### P0 — Editorial Core

- timeline ergonomics
- preview invalidation and undo-safe edit history
- keyframe support for transform/opacity/volume
- transcript import stub + caption basic pipeline
- robust gating tests for versioning/publish safety

#### P1 — Social Optimization

- polished caption pipeline with multilingual-ready structure
- audio finish controls at clip/track level
- motion/transition preset catalog
- template reuse per brand and per format

#### P2 — Assist and Scale

- motion-tracking + advanced scene/asset assistance
- short-form automation entry points (scene candidates, highlight candidates)
- pro-grade performance monitoring for timeline interactions

## Non-Goals

- building a standalone third-party media studio outside the canonical editor
- changing canonical timeline to multiple competing models
- free-form cloud-native render editing inside Flutter
- replacing Remotion adapter contract

## Security and Trust Constraints

- All mutation requests remain owner-scoped and project-scoped.
- Provider calls remain backend managed.
- No direct local file paths or raw client URLs in render props.
- Signed URLs never persist as long-lived state.
- Stale timelines invalidate preview and final readiness identically to current rules.

## API and Data Model Implications

- Expand timeline validation to support optional animation/caption/audio fields while preserving current core schema.
- Add timeline revision-safe storage for `keyframes`, `captionTracks`, `audioMix`, `editOperations` metadata.
- Extend provider status models where needed with explicit capability flags and gating codes.
- Keep existing `/api/video-timelines` entrypoints; add optional fields and new capability-aware error codes.

## Success Behavior

- Given an auto-generated branded draft in `ready` state, when the creator opens `/editor/:id/video`, then correction tools are immediately available with safe defaults and no workflow change.
- Given a non-destructive keyframe edit, when preview is regenerated, then previous versions and signed artifacts stay immutable and stale markers are accurate.
- Given text-based edits are made, when preview completes, then caption/text state and timing changes are reflected consistently for publish readiness.
- Given audio finishing changes are made, when final validation passes, then publish gating behavior stays unchanged but content quality controls improve for social formats.

## Failure and Risk Behavior

- If advanced features are partially implemented, the editor must disable unavailable actions explicitly instead of showing inert controls.
- If transcript provider is unavailable, editing remains in manual mode with explicit fallback state.
- If motion complexity exceeds payload budget, edits are clamped or rejected with typed remediation.
- If any new capability fails validation, the previous stable version remains current.

## Documentation and Tracking

- This spec should replace roadmap duplication between Filmora/PixVerse sections in `shipglows_data/workflow/lab/TASKS.md` by acting as the canonical decomposition.
- Existing `P0/P1/P2` roadmap tasks in `lab/TASKS.md` become execution backlog derived from this spec.
- Any implementation slice must include a spec update with versioned evidence.

## Implementation Tasks (initial)

- [ ] Tache 1: Define timeline capability schema extension (`keyframes`, `captionTracks`, `audioMix`) with migration-safe backward compatibility in `lab/api/models/video_timeline.py` and `api/services/video_timeline_store.py`.
- [ ] Tache 2: Implement timeline editing ergonomics and undo-safe state transitions in `app/lib/presentation/screens/editor/video_timeline_screen.dart` and `app/lib/providers/video_timeline_provider.dart` without changing canonical render contract.
- [ ] Tache 3: Add transcript+captions backend + app flow (or explicit capability flag if feature-gated by roadmap) in `lab/api/routers/video_timelines.py` and caption UI layer.
- [ ] Tache 4: Add animation keyframe property support in `lab/api/services/remotion_timeline_props.py` and `worker/remotion` composition contracts.
- [ ] Tache 5: Add audio finishing controls in app UI and pass through persisted metadata for Remotion props conversion.
- [ ] Tache 6: Add AI-assisted editing suggestions as read-only recommendations first; optional auto-application remains gated and explicit.
- [ ] Tache 7: Add regression coverage per phase (`app/widgets`, `app/provider`, `lab router/service`, `worker prop`, anti-regression for preview/final gates).

## Acceptance Criteria

- The advanced capability roadmap is implemented in phases and mapped to a single canonical timeline model.
- No alternate timeline renderer/model is introduced.
- Existing feed-first and swipe-to-publish flow remains unchanged.
- New editing capabilities improve correction speed, not mandatory path complexity.
- Preview/final publish gates remain strict and user-visible.
