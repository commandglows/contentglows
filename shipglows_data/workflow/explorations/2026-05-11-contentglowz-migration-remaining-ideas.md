---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-11"
updated: "2026-05-11"
status: draft
source_skill: sf-explore
scope: "contentglowz remaining migration ideas"
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - "contentglowz"
  - "app"
  - "lab"
  - "Image Robot"
  - "Remotion"
  - "ElevenLabs"
  - "Bunny CDN"
  - "Turso/libSQL"
evidence:
  - "contentglowz/INSPIRATION.md lists video AI, audio AI, image AI, design/editor references."
  - "contentglowz/SOURCE.md lists ElevenLabs, Whisper, GPT/Claude, DALL-E, Stability, Replicate, Remotion, FFmpeg, Sharp and Convex as inspiration sources."
  - "contentglowz contains remotion-template, v0-flux-2-playground, v0-ai-image-generation-benchmark, v0-ai-powered-animation-studio, v0-cool-design-ressemble-gocharbon-connexion-reseaux-sociaux, v0-eleven-labs-v3-podcast-generator, v0-eleven-labs-true-crime-podcast, and v0-eleven-labs-music-starter."
  - "Existing ready specs already cover Flux/Image Robot foundation, editor-linked AI visuals, upload references, quotas/PAYG, Remotion video editor, asset picker, and LoRA research."
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
supersedes: []
next_step: "/sf-spec AI audio and podcast generation workflow"
---

# Exploration Report: ContentGlowz Remaining Migration Ideas

## Starting Question

What remains worth migrating from `contentglowz` now that the first AI visual and Remotion-related specs exist, and what additional spec candidates should be considered before implementation?

## Context Read

- `contentglowz/INSPIRATION.md` - mapped the broader product inspiration across video, audio, image, design and editing.
- `contentglowz/SOURCE.md` - identified provider/tool families referenced by the inspiration repo.
- `contentglowz/*/package.json` - grouped prototypes by provider and capability.
- `contentglowz/*/app/api/**/route.ts` - identified concrete backend behaviors in the prototypes.
- Existing `shipglows_data/workflow/specs/**` - compared already-created specs against remaining prototype ideas.

## Internet Research

- None. This pass used local repository evidence only.

## Problem Framing

The prior specs covered the visual-generation spine. The remaining `contentglowz` value is mostly not code-portable because the prototypes are Next/Supabase/Vercel/React, while ContentGlowz uses Flutter, FastAPI, Clerk, Turso and Bunny. The useful migration unit is therefore product behavior and contracts, not source code.

## Option Space

### Option A: Finish Visual Spine First

- Summary: implement the five ready visual/video specs before defining more.
- Pros: keeps focus; builds the core asset/generation foundation.
- Cons: ignores audio/social workflow ideas that could shape data models now.

### Option B: Spec Remaining Media Workflows Before Implementation

- Summary: create specs for audio/podcast/music, social distribution settings, animation/keyframe UI, provider benchmarking, and transcription/media intelligence.
- Pros: gives a fuller migration map from `contentglowz`; avoids painting the app into an image-only architecture.
- Cons: more spec work before product proof; risks broadening scope.

## Comparison

Option B is better if the near-term goal is to audit what is still valuable in `contentglowz`. Option A is better if the near-term goal is shipping the current AI visuals. The middle path is to create only the specs that affect architecture soon: audio assets, provider cost telemetry, and social placement settings.

## Emerging Recommendation

Create 3 near-term specs and leave 2 as later research:

- Near term: AI audio/podcast generation workflow.
- Near term: Social placement and platform settings in the editor/publish queue.
- Near term: Provider benchmark and cost telemetry, folded into or linked to PAYG quotas.
- Later: AI animation/keyframe assistant.
- Later: Transcription/Descript-style media intelligence.

## Non-Decisions

- No implementation order chosen.
- No provider selected for audio beyond noting ElevenLabs as inspiration.
- No commitment to import any Next/Supabase/Vercel code.
- No decision to build a standalone studio surface; current product direction remains guided editor workflows.

## Rejected Paths

- Porting `contentglowz` code directly - rejected because the stack does not match and the prototypes leak implementation assumptions we do not want.
- Building a global studio hub - rejected for now because the current product direction favors guided flows inside existing content/editor surfaces.

## Risks And Unknowns

- Audio generation can create cost, rights, consent and storage issues similar to image generation.
- Music and voice generation may need separate legal/product limits from generic audio feedback.
- Animation/keyframe editing may become a large freeform editor if not constrained to templates/storyboards.
- Benchmark/provider telemetry overlaps with quotas/PAYG and should not become a separate billing system.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: Only local file paths and high-level behavior summaries are persisted.

## Decision Inputs For Spec

- User story seed: En tant que creatrice ContentGlowz, je veux transformer un contenu existant en audio, podcast, musique courte ou enrichissement media guide, afin de reutiliser mes contenus sur plus de formats sans quitter le workflow editor.
- Scope in seed: editor-linked audio generation, script generation, voice/dialogue rendering, durable Bunny audio assets, job status, cost tracking, publish queue attachment.
- Scope out seed: global audio playground, voice cloning by default, arbitrary music marketplace, direct provider secrets in app, Supabase/Vercel migration.
- Invariants/constraints seed: FastAPI/Clerk/Turso/Bunny stack, async jobs, user/project ownership, backend provider calls, quota/PAYG compatibility.
- Validation seed: backend route tests, ownership tests, provider failure/refund tests, Bunny audio asset persistence, Flutter editor integration tests.

## Handoff

- Recommended next command: `/sf-spec AI audio and podcast generation workflow`
- Why this next step: audio/podcast is the largest remaining valuable capability in `contentglowz` that is not already covered by the ready visual/video specs.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-05-11 16:17:00 UTC | Remaining migration ideas from `contentglowz` | Read local inspiration docs, prototype directories, package manifests, route files, and current spec inventory. | Identified covered specs and five additional spec candidates. | `/sf-spec AI audio and podcast generation workflow` |
