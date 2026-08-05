---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-05-13"
updated: "2026-05-13"
status: draft
source_skill: sf-explore
scope: "Mirage / Oasis realtime AI world-video signal for ContentGlows"
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - "app"
  - "lab"
  - "contentglows_remotion_worker"
  - "contentglows/TOOLS.md"
  - "Decart Mirage/Oasis/Lucy"
  - "Remotion video editor workflow"
  - "AI video b-roll generation workflow"
  - "AI provider benchmark cost quality telemetry"
  - "Bunny Storage/CDN"
  - "Clerk"
  - "Turso/libSQL"
evidence:
  - "contentglows/TOOLS.md lists DecartAI/Lucy-Edit-ComfyUI, Oasis 2.0, and Decart JavaScript/Python API docs."
  - "Decart Mirage publication frames MirageLSD as live stream diffusion for realtime video-to-video transformation."
  - "Decart Oasis publication frames Oasis as an interactive realtime open-world AI model conditioned by user inputs."
  - "Decart API docs expose Realtime WebRTC, Queue async video, and Process image APIs; current public model names emphasize Lucy 2.1 and Lucy Restyle."
  - "ContentGlows specs already define guided Remotion storyboard editing, scene motion, AI b-roll, text-based media editing, Flux/Image Robot, and provider telemetry."
  - "ContentGlows architecture and README docs confirm Flutter app, FastAPI backend, Clerk auth, Turso/libSQL persistence, Bunny-backed durable assets, async jobs, and partial offline behavior."
depends_on:
  - "contentglows/TOOLS.md"
  - "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
  - "shipglows_data/workflow/specs/monorepo/SPEC-remotion-scene-motion-assistant-2026-05-12.md"
  - "shipglows_data/workflow/specs/monorepo/SPEC-ai-video-broll-generation-workflow-2026-05-13.md"
  - "shipglows_data/workflow/specs/monorepo/SPEC-text-based-media-editing-social-video-2026-05-12.md"
  - "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
  - "shipglows_data/workflow/specs/SPEC-ai-provider-benchmark-cost-quality-telemetry-2026-05-12.md"
supersedes: []
next_step: "continue exploring only if a focused Decart provider/product decision is requested"
---

# Exploration Report: Mirage / Oasis For ContentGlows

## Starting Question

Clarify what the local `mirge / oasis` signal means for ContentGlows, whether Mirage/Oasis/Decart realtime video should become a product direction, how it contrasts with the current async guided-content architecture, and whether it deserves a new spec, research note, or future note inside existing specs.

## Context Read

- `contentglows/TOOLS.md` - local signal: Decart Lucy ComfyUI, Oasis 2.0, and Decart API docs.
- `shipglows_data/workflow/TASKS.md` - current priorities: design tokens, dual-mode AI runtime, project asset library, Flux/Image Robot, not realtime video.
- `shipglows_data/workflow/explorations/2026-05-11-contentglows-migration-remaining-ideas.md` - existing stance: contentglows is inspiration only, not code to port.
- `lab/README.md` - backend owns guided API workflows, jobs, Turso persistence, Bunny asset descriptors, and Image Robot Flux generation.
- `app/README.md` - Flutter app owns guided user workflows, partial offline cache/queue, server-owned publishing, and blocks binary/server-first jobs offline.
- `shipglows_data/technical/lab/architecture.md` and `shipglows_data/technical/app/architecture.md` - confirmed FastAPI/Flutter/Clerk/Turso boundaries.
- `lab/status/schemas.py` and `lab/api/services/project_asset_storage.py` - confirmed project asset kinds, sources, and durable vs provider-temporary storage descriptors.
- Existing specs compared:
  - Remotion video editor workflow.
  - Remotion scene motion assistant.
  - AI video b-roll generation workflow.
  - Text-based media editing for social video.
  - Flux AI Provider for Image Robot.
  - AI provider benchmark/cost/quality telemetry.

## Internet Research

- [MirageLSD: The First Live-Stream Diffusion AI Video Model](https://decart.ai/publications/mirage) - Accessed 2026-05-13 - primary Decart source for Mirage as infinite realtime video-to-video/live-stream diffusion, latency claims, limitations, and future control work.
- [Oasis: A Universe in a Transformer](https://decart.ai/publications/oasis-interactive-ai-video-game-model) - Accessed 2026-05-13 - primary Decart source for Oasis as interactive realtime open-world AI/world model.
- [Oasis 2.0](https://oasis2.decart.ai/) - Accessed 2026-05-13 - current public demo/mod positioning: realtime AI experience that transforms a world while playing.
- [Decart API Platform JavaScript SDK](https://docs.platform.decart.ai/sdks/javascript) - Accessed 2026-05-13 - confirmed API split: Realtime WebRTC, Queue async video, Process image, short-lived client tokens.
- [Decart API Platform Python SDK](https://docs.platform.decart.ai/sdks/python) - Accessed 2026-05-13 - confirmed backend-friendly async Python SDK path for Queue/Process APIs.
- [Decart Realtime Overview](https://docs.platform.decart.ai/models/realtime/overview) - Accessed 2026-05-13 - confirmed current public realtime models are framed as Lucy Restyle / Lucy 2.1 for restyling, character reference and object/scene editing.
- [Decart Streaming Best Practices](https://docs.platform.decart.ai/models/realtime/streaming-best-practices) - Accessed 2026-05-13 - confirmed WebRTC constraints, connection lifecycle, mobile battery/bandwidth concerns, and client-token implications.
- [Decart Realtime Integration Paths](https://docs.platform.decart.ai/integrations/overview) - Accessed 2026-05-13 - confirmed SDK direct, WebSocket signaling proxy, and HTTP signaling proxy patterns; WebRTC media still goes direct to Decart.
- [Decart HTTP Signaling](https://docs.platform.decart.ai/integrations/signaling-proxy-http) - Accessed 2026-05-13 - confirmed HTTP signaling private-preview posture and direct WebRTC media path.
- [Decart WS Signaling Proxy](https://docs.platform.decart.ai/integrations/signaling-proxy-ws) - Accessed 2026-05-13 - confirmed white-label signaling proxy can see prompts/events but not media frames.
- [Decart Pricing](https://docs.platform.decart.ai/getting-started/pricing) - Accessed 2026-05-13 - confirmed pay-as-you-go per-second realtime/video pricing examples for Lucy models.
- [Decart Acceptable Use Policy](https://docs.platform.decart.ai/resources/aup) - Accessed 2026-05-13 - used for safety, consent, disclosure, deepfake, biometric and high-risk usage constraints.
- [Decart Mirage Minecraft Mod Cookbook](https://cookbook.decart.ai/mirage-minecraft-mod) - Accessed 2026-05-13 - technical reference for game-screen capture/replacement and why realtime world transformation is a deep rendering pipeline, not a simple content workflow.

## Problem Framing

Mirage/Oasis is not just "another video model". It points to a different product class:

```text
Async ContentGlows today
  source content -> guided generation job -> durable Bunny asset -> editor/review -> publish queue

Mirage/Oasis class
  live media/input -> WebRTC or frame loop -> realtime transformed stream -> optional capture/share
```

Oasis is closer to realtime interactive world simulation. Mirage/Lucy is closer to realtime video-to-video restyle/editing. Both are impressive R&D and may become useful provider capabilities, but the default ContentGlows product is the opposite shape: guided, project-scoped, asynchronous, reviewable, durable, and publish-gated.

The useful translation is therefore not "build Oasis inside ContentGlows". It is: decide whether Decart becomes a future provider in existing video workflows, or whether realtime preview becomes a later experimental surface after the durable Remotion/video/asset spine exists.

## Option Space

### Option A: Veille Only

- Summary: keep Decart/Mirage/Oasis as frontier research and provider radar; do not spec now.
- Pros: preserves current focus; avoids WebRTC/mobile/security cost; keeps the product out of free playground territory.
- Cons: no immediate learning from Decart APIs; may miss an early provider opportunity for video restyling.

### Option B: Internal Realtime Prototype

- Summary: later create an ops-only or local prototype using Decart Realtime API with a test token and a single canned prompt, purely to measure latency, mobile behavior, cost and safety.
- Pros: real evidence on Flutter/web/mobile feasibility; useful for cost/quality telemetry design.
- Cons: not shippable; WebRTC, tokens, lifecycle, consent and media-stream handling are a separate system from current jobs/assets.

### Option C: Async Decart Video Restyle Provider

- Summary: treat Decart Queue API/Lucy as a candidate provider for the existing AI video b-roll/restyle spec, not as realtime UI. Generated outputs would be downloaded server-side, stored to Bunny, and registered as project assets.
- Pros: best fit with ContentGlows architecture; reuses async jobs, Bunny durability, project asset library, quota and telemetry; can be compared with Runway/Luma/Veo later.
- Cons: loses the "realtime magic"; still raises safety/consent and provider-cost risks; requires docs refresh and provider adapter work.

### Option D: Live Preview / Avatar-Persona Surface

- Summary: add a future live restyle/avatar/persona preview in the editor or capture flow using WebRTC and short-lived tokens.
- Pros: differentiated experience for creators, live streaming, thumbnails, avatar/persona demos, or camera-based creative previews.
- Cons: high-risk product fit; likely creates a free playground; requires explicit consent/deepfake policy, mobile lifecycle work, WebRTC expertise, and recording/storage decisions.

## Comparison

| Criterion | A: Veille | B: Prototype | C: Async Provider | D: Live Surface |
| --- | --- | --- | --- | --- |
| Fit with ContentGlows guided workflows | High | Medium | High | Low/Medium |
| Fit with durable Bunny assets | N/A | Low unless recorded | High | Low unless capture/export added |
| Fit with Remotion | Indirect | Indirect | High as scene asset input | Low; Remotion is render-time, not live stream |
| Flutter/mobile complexity | None | High | Medium | Very high |
| Security/consent risk | Low | Medium | Medium/High | Very high |
| Cost predictability | High | Low | Medium via job bounds | Low; billed by active seconds |
| Time-to-product value | None now | Low | Medium later | Unclear |
| Risk of free playground drift | Low | Medium | Medium | Very high |

## Existing Spec Comparison

### Remotion Video Editor Workflow

Disposition: no new dependency. The Remotion editor already defines the durable storyboard, scene versions, trusted assets, preview gate and final render path. Mirage/Oasis should not replace this. If Decart enters the product, it should feed this editor as a generated video asset or preview candidate, not become the editor runtime.

### Remotion Scene Motion Assistant

Disposition: keep separate. The motion assistant already covers bounded motion presets and prompt-to-structured-motion operations. Realtime restyle is not motion props; it is a generated/transformed media stream. It can inspire preview expectations, but it should not be folded into scene motion.

### AI Video B-roll Generation Workflow

Disposition: closest fit. Decart Queue API / Lucy video restyling could become a future provider candidate in this spec, alongside Runway/Luma/Veo, if the product wants video-to-video restyle or guided clip transformation. This should be a future note/provider extension, not a separate spec today.

### Text-Based Media Editing For Social Video

Disposition: no direct spec impact. Mirage/Oasis does not solve transcription, caption tracks or text edit plans. If realtime sessions are recorded later, the recorded output could become an input to transcription, but that is downstream.

### Flux AI Provider For Image Robot

Disposition: no change. Flux/Image Robot handles guided still imagery and visual references. Decart realtime character/reference video features are higher-risk because they approach likeness transformation and deepfake policy. They should not be conflated with visual memory images.

### AI Provider Benchmark Cost Quality Telemetry

Disposition: important future gate. Any Decart evaluation should enter this telemetry system first: per-second cost, active generation time, latency, error rates, moderation failures, durable-output success, and admin quality review. The public Decart pricing/docs are not enough for product default decisions.

## Emerging Recommendation

Keep Mirage/Oasis in research for now. Do not create a standalone ContentGlows spec for realtime world/video generation yet.

The most pragmatic future path is:

1. Add a research note to the AI video b-roll provider radar when that spec is next touched: "Decart/Lucy candidate for async video restyle/video-to-video provider; not V1."
2. If evidence is needed, run a later internal prototype only after the Remotion video editor, project asset library, b-roll generation, quotas and provider telemetry are implemented enough to measure cost and durable-output fit.
3. Treat any realtime WebRTC surface as a separate future product decision with explicit consent, mobile, cost and safety gates.

Key finding: Mirage/Oasis is a strong signal for future provider capability, not a near-term ContentGlows product surface. Its value for ContentGlows is most likely async video restyling or provider benchmarking, not interactive worlds.

## Non-Decisions

- No provider selection for Decart, Runway, Luma, Veo or other video providers.
- No commitment to WebRTC in Flutter.
- No decision to store or record live transformed streams.
- No decision to support avatar/persona realtime features.
- No change to existing specs.
- No porting of `contentglows` code.

## Rejected Paths

- Build an Oasis-like interactive world in ContentGlows - rejected because it is game/R&D territory, not current content pipeline value.
- Add a public realtime playground - rejected because it conflicts with guided workflows, quotas, safety review and durable assets.
- Let Flutter call Decart directly with a permanent API key - rejected by Decart docs and ContentGlows backend-boundary rules.
- Use provider temporary streams/URLs as durable assets - rejected by ContentGlows Bunny/project asset invariants.
- Treat realtime avatar/character transformation as a casual visual feature - rejected until consent, disclosure, likeness and abuse policies are explicit.

## Risks And Unknowns

- Cost: Decart realtime/video pricing is per active/generated second; live exploration can burn spend without producing reusable assets.
- Latency: Decart claims low latency, but ContentGlows would still need end-user network, Flutter WebRTC, mobile device capture, app lifecycle and reconnect behavior.
- Mobile Flutter: WebRTC support, codec constraints, battery, bandwidth and background lifecycle are all non-trivial; Decart docs specifically call out mobile resource concerns.
- Security: short-lived tokens reduce key exposure but active sessions can continue after token expiry; backend needs session governance, disconnect policy and abuse controls.
- Privacy and consent: live camera/screen streams can include faces, private rooms, other apps, minors, client data or third-party content.
- Deepfake/likeness: character/reference transformation requires consent, clear disclosure and conservative product copy.
- Storage: realtime output is not automatically a durable Bunny asset; recording/export would need explicit user intent, size limits, retention and publish review.
- Remotion compatibility: Remotion expects deterministic render props/assets; it does not naturally consume a live WebRTC stream as the authoritative preview/final render.
- Product value: creators may prefer durable b-roll/captions/assets over live effects unless a concrete workflow proves higher conversion or speed.
- Provider maturity: current API docs emphasize Lucy 2.1/Lucy Restyle rather than the older Mirage naming, so implementation assumptions must be refreshed at the time of any spec.
- Legal/disclosure: Decart AUP requires attention to prohibited uses, consent, generated/manipulated media disclosure, metadata/watermark preservation where applicable, and content moderation.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none.
- Redactions applied: none.
- Notes: Report contains only local file paths, high-level repo facts, and public Decart URLs. No secrets, tokens, customer data or logs were persisted.

## Decision Inputs For Spec

If this becomes a spec later, the likely spec should not be "Mirage/Oasis realtime playground". A safer seed is:

- User story seed: En tant que creatrice ContentGlows, je veux appliquer une transformation video guidee a un clip owned et obtenir un asset durable, afin d'enrichir une scene sociale sans manipuler un flux live ou ouvrir un playground.
- Scope in seed: backend provider adapter, async Decart Queue API evaluation, cost/quality telemetry, Bunny durable storage, project asset registration, scene/placement candidate linking.
- Scope out seed: public realtime playground, WebRTC live streaming, avatar/likeness transformation, arbitrary game/world generation, direct Flutter provider calls, provider temporary URLs as durable output.
- Invariants/constraints seed: FastAPI owns provider calls; Clerk + project ownership required; outputs reusable only after Bunny storage; Remotion receives validated asset ids; quota and telemetry gates are required.
- Validation seed: provider availability tests, quota preflight, moderation failure, Bunny upload failure, asset registration, telemetry event, stale scene/version behavior, diagnostics redaction.

## Handoff

- Recommended next command: `continue exploring` or `/sf-spec Decart async video restyle provider` only if product explicitly wants a Decart provider evaluation.
- Why this next step: the current evidence does not justify a realtime spec. A later Decart provider spec would make sense only after the AI video b-roll workflow and provider telemetry have enough foundation to compare real cost, latency and output quality.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-05-13 04:16:10 UTC | Mirage / Oasis realtime AI world-video signal for ContentGlows | Read local signal, ContentGlows architecture/docs/specs, and public Decart Mirage/Oasis/API/pricing/safety docs. | Recommended research-only for now; Decart may become a future async video restyle provider candidate, not a near-term realtime product surface. | Continue exploring only if a focused Decart provider/product decision is requested. |
