---
artifact: research
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-05-13"
updated: "2026-05-13"
status: reviewed
source_skill: sf-research
scope: "Decart Lucy/Oasis visual asset editing research for ContentGlows"
confidence: "medium"
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
source_count: 31
evidence:
  - "https://docs.platform.decart.ai/llms.txt"
  - "https://docs.platform.decart.ai/getting-started/overview"
  - "https://docs.platform.decart.ai/getting-started/models"
  - "https://docs.platform.decart.ai/models/image/image-editing"
  - "https://docs.platform.decart.ai/models/video/video-editing"
  - "https://docs.platform.decart.ai/models/realtime/overview"
  - "https://docs.platform.decart.ai/getting-started/pricing"
  - "https://docs.platform.decart.ai/resources/terms-of-service"
  - "https://docs.platform.decart.ai/resources/api-terms"
  - "https://docs.platform.decart.ai/resources/aup"
  - "https://docs.platform.decart.ai/resources/privacy-policy"
  - "https://docs.platform.decart.ai/resources/dpa"
  - "https://github.com/DecartAI/Lucy-Edit-ComfyUI"
  - "https://huggingface.co/decart-ai/Lucy-Edit-Dev-ComfyUI/blob/main/README.md"
  - "https://oasis2.decart.ai/"
  - "contentglows/TOOLS.md"
  - "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
  - "shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md"
  - "shipglows_data/workflow/specs/SPEC-project-visual-asset-library-2026-05-11.md"
  - "shipglows_data/workflow/specs/SPEC-ai-provider-benchmark-cost-quality-telemetry-2026-05-12.md"
  - "shipglows_data/workflow/specs/monorepo/SPEC-ai-video-broll-generation-workflow-2026-05-13.md"
  - "shipglows_data/workflow/specs/monorepo/SPEC-remotion-scene-motion-assistant-2026-05-12.md"
next_step: "Add Decart Lucy Image 2 and Lucy 2.1 as benchmark candidates before any product spec; keep Oasis/Mirage as veille only."
---

# Research: Decart Lucy/Oasis Visual Asset Editing For ContentGlows

> Generated 2026-05-13 — Sources: 31

## Executive Summary

Decart is relevant for ContentGlows, but not as a direct new product spec today. The best fit is narrow provider evaluation: Lucy Image 2 for editing/restyling existing project images, and Lucy 2.1 for batch video-to-video editing of existing clips. Oasis 2.0 and Mirage/Lucy Restyle Live are realtime/live-world experiences, not a near-term ContentGlows asset pipeline.

Recommendation: do not create a new Decart spec yet. Add Decart to the internal provider benchmark/cost telemetry track, run controlled fixtures against owned Bunny-backed assets, and only draft a future spec if benchmarks prove a workflow gap not already covered by Flux/Image Robot, asset library, AI video b-roll, or Remotion motion specs.

## Background

Local signal is limited to four inspiration links in `contentglows/TOOLS.md`: DecartAI/Lucy-Edit-ComfyUI, Oasis 2.0, and Decart API docs for JavaScript/Python. Project direction remains Flutter app, FastAPI backend, Clerk, Turso/libSQL, Bunny CDN, and guided async workflows; `contentglows` is inspiration only, not a Next/Supabase/Vercel migration source.

The existing ContentGlows specs already cover the main surfaces this research could touch:

- `SPEC-flux-ai-provider-image-robot-2026-05-11.md`: Image Robot/Flux async image generation, project visual references, Bunny durability, Turso history.
- `SPEC-ai-visual-reference-upload-advanced-2026-05-11.md`: safe project image upload, metadata stripping, reference eligibility, deletion/versioning.
- `SPEC-project-visual-asset-library-2026-05-11.md`: editor-linked project asset picker/library, durable assets, promotion to references.
- `SPEC-ai-provider-benchmark-cost-quality-telemetry-2026-05-12.md`: internal provider benchmark, cost/latency/quality telemetry, no public playground.
- `SPEC-ai-video-broll-generation-workflow-2026-05-13.md`: guided AI video b-roll as short candidate assets, first adapter framed as Runway, future providers via registry.
- `SPEC-remotion-scene-motion-assistant-2026-05-12.md`: deterministic Remotion scene motion, bounded presets, no free animation studio.

## Current Decart State

The current Decart API Platform docs expose three integration modes:

- **Process API** for synchronous image editing. Official docs show `lucy-image-2` as the current image editing model and the endpoint `/v1/generate/lucy-image-2`.
- **Queue API** for async video processing. Official docs describe video jobs as submit, poll, and download result; Decart also documents migration away from synchronous video endpoints.
- **Realtime API** for WebRTC video transformation. Official docs use realtime client tokens for browser/mobile and warn not to expose permanent API keys in frontend code.

Current model docs list `lucy-2.1` for realtime and batch video editing, `lucy-restyle-2` for restyling, and `lucy-image-2` for image editing. The changelog says Lucy 2.1 launched in April 2026, `reference_image` support was added to `lucy-image-2`, and in May 2026 several older models were retired; the changelog also says Mirage was renamed to Lucy Restyle Live in March 2026.

Pricing docs are usage-based: image models are billed per generation, video models per generated second, and realtime models per active generation second. On 2026-05-13, Decart lists Lucy Image 2 at $0.01 for 480p and $0.02 for 720p, Lucy 2.1 batch video editing at $0.04/sec for 720p, and Lucy 2.1 realtime at $0.02/sec for 720p.

## Clear Distinctions

| Area | What it is | ContentGlows interpretation |
| --- | --- | --- |
| Lucy Image 2 | Image-to-image editing from input image + prompt, optional reference image, 480p/720p | Candidate provider for editing/restyling an owned project image, not replacing Flux generation |
| Lucy 2.1 batch | Existing video + prompt/reference image, async `/v1/jobs/*`, 720p, MP4 input, max 200 MB, documented as unlimited duration | Candidate video-to-video edit/post-process provider for existing Bunny clips |
| Lucy 2.1 realtime | WebRTC live video editing/character transform with short-lived client tokens | Mismatch for ContentGlows V1 async workflows; possible future live preview only |
| Lucy Restyle 2 / Restyle Live | Style transformation/restyling of live or recorded video | More relevant to filters/restyling than durable content editing |
| Oasis / Oasis 2.0 | Realtime game/world transformation; Oasis 2.0 site frames a Minecraft-style mod/demo | Veille/inspiration only for ContentGlows |
| Lucy-Edit-ComfyUI | ComfyUI nodes plus local Dev weights and API workflow examples | Non-production exploration; local weights are non-commercial per Hugging Face card |
| Decart API/SDK | Official JS/Python/Swift/Android SDKs; Python async client; JS browser/server usage | Backend adapter possible for Process/Queue; realtime requires token service and privacy review |

## Fit For ContentGlows Workflows

### Asset Editing / Restyle

**Fit: medium.** Lucy Image 2 directly edits existing images, which maps to a future "edit this owned asset" action in the project asset library. It could support corrections such as background change, clothing/accessory edits, style transfer, or object replacement after a Flux/Image Robot result or uploaded image exists.

This should not replace the current Flux/Image Robot spec because Flux covers guided generation with references, while Lucy Image 2 is better framed as asset edit/restyle. It must consume an owned durable Bunny image or backend-approved reference and return a new derived asset/version, not mutate the original asset in place.

### Image-To-Image / References

**Fit: medium-high for evaluation.** Decart docs and platform pages describe `reference_image` for Lucy Image 2, useful for adding or matching a specific item/style. ContentGlows already has the reference upload and asset library specs needed to govern this safely. The missing piece is quality/cost evidence versus Flux.2 editing/reference behavior.

### Video-To-Video Editing

**Fit: medium, future.** Lucy 2.1 batch video editing aligns with existing-video transformations: style transfer, object modifications, character replacement, visual transformation. ContentGlows could use this later to restyle or modify a user-owned clip, generated b-roll candidate, or Remotion-exported clip.

It is not a first b-roll generator: the documented core is editing an existing video, not creating a fresh short b-roll clip from a scene prompt. The current AI video b-roll spec already has a cleaner V1 path for prompt/image-to-video providers and durable project asset registration.

### B-Roll Generation

**Fit: low to medium until confirmed.** Decart's public model page mentions Lucy 5B/14B image-to-video, but the current API Platform model overview and pricing docs are centered on image editing, video editing, video restyling, and realtime. Treat Decart image-to-video as an external lead requiring official sales/API confirmation before it affects the b-roll spec.

### Motion / Live Preview

**Fit: low for current ContentGlows.** Realtime WebRTC is powerful for live camera effects and interactive filters, but ContentGlows's workflows are guided, async, durable, and review/publish oriented. Realtime would add token minting, camera permission, session duration caps, consent, and privacy complexity while overlapping the Remotion motion assistant's deterministic preview role.

### Simple Veille

**Fit: high for Oasis/Mirage.** Oasis 2.0 and Mirage/Lucy Restyle Live are useful market signals around realtime world/video transformation, but they do not justify a product spec in ContentGlows today.

## Risks

### License / Commercial Use

The Decart API Terms say users own input and Decart assigns output rights subject to the terms, while Decart may use input/output to develop, improve, train, provide, and maintain the platform. That can be compatible with commercial use only after legal/product acceptance of the API Terms, DPA, and privacy posture.

The ComfyUI/local model path is different: the GitHub repo has no `LICENSE` file in the repository metadata, and the Hugging Face model card declares `lucy-edit-dev-model-non-commercial-license-v1.0`. Treat local Lucy Edit Dev as non-commercial experimentation unless Decart grants a separate commercial license.

### AUP / Safety

The AUP prohibits illegal, IP-infringing, harmful, sexual abuse/minor, hate, violence, and sensitive/private-information misuse cases. It also requires redistributors of Decart models/API-powered products to include equivalent AUP/license terms and prevent prohibited use where reasonably possible. ContentGlows would need provider-level moderation mapping, user-facing policy constraints, and admin-visible safety failures before exposing identity/video editing.

### Consent, Deepfake, Identity

Lucy 2.1 and Lucy Image explicitly support character/reference transformations, object/person replacement, virtual try-on, and appearance edits. This is high-risk for identity, likeness, public figures, minors, non-consensual edits, and brand/IP impersonation. Any ContentGlows integration must require owned/authorized inputs, reject or gate real-person likeness workflows, store provenance, and avoid claims of exact identity safety.

### Privacy / Data Retention

Decart's Privacy Policy describes personal data use for service operations, security, law enforcement/legal compliance, and anonymized/deidentified internal/external use including research. The DPA says Decart acts as processor for Developer Data but also describes retention as needed to provide and improve services, deletion/return on termination request unless law requires retention, and a 60-day deletion reservation after account deletion. The public Terms also allow Content use for model improvement/training.

For ContentGlows, this means no sensitive customer media, faces, private captures, or enterprise content should be sent until legal review resolves whether Decart API usage, DPA, account settings, and commercial contract meet the product's privacy promises.

### Cost

Decart image editing is cheap enough to benchmark, but video/realtime costs scale by seconds. Lucy 2.1 batch at $0.04/sec means a 30-second edit would cost about $1.20 before storage, retry, failed outputs, and PAYG margin. Realtime at $0.02/sec can quietly burn spend if sessions remain open. Any integration needs quota preflight, max durations, per-project caps, idempotency keys, and telemetry.

### API Maturity / Drift

Docs changed materially in 2026: client tokens v2, Lucy 2.1, model renames, model retirements, `-latest` aliases, and queue migration. Use explicit model ids for reproducibility, version the pricing catalog, and add docs-freshness checks before implementation. Avoid app-facing `latest` aliases except in internal experiments.

### Provider Lock-In

Realtime depends on Decart WebRTC/session semantics and client token rules. Queue/Process integrations are easier to isolate behind backend adapters, but model behavior and pricing are still Decart-specific. The existing provider benchmark spec's adapter/cost catalog design is the right boundary.

### Async vs Realtime

ContentGlows's current architecture favors async jobs, durable Bunny storage, Turso metadata, and review/publish state. Decart Process and Queue APIs fit that model. Realtime WebRTC does not produce a durable asset by default and should not be used for publishable media without an explicit capture, consent, storage, and moderation design.

## Comparison With Existing Specs

### Flux / Image Robot

Flux/Image Robot already owns guided image generation, project visual references, async jobs, Bunny storage, and Turso generation history. Lucy Image 2 should be evaluated as a separate action type: `asset_edit` or `asset_restyle`, not as a replacement provider for first-pass image generation.

### Visual Reference Upload

The visual reference upload spec already defines the safe boundary Decart would need: backend-proxied upload, file validation, EXIF/GPS stripping, Bunny storage, project ownership, eligibility gates, reference versioning, and immutable generation provenance. Decart must consume those records only through backend resolution.

### Project Asset Library

The asset library spec is the right UX home for future Decart image edits: select an owned asset, request an edit/restyle, save the result as a derived candidate, compare, promote, tombstone, or attach to a placement. This avoids a Decart playground and preserves ContentGlows's guided product direction.

### AI Video B-Roll

The b-roll spec should not switch to Decart today. Its current Runway-first V1 is aligned with prompt/image-to-video generation and short bounded b-roll. Lucy 2.1 should enter that ecosystem later as a video-to-video post-process candidate, not as the initial b-roll provider.

### Remotion Motion Assistant

Realtime Decart is not a substitute for Remotion scene motion. Remotion motion is deterministic, versioned, preview-gated, and render-safe. Decart realtime is live transformation and should stay out of the motion assistant unless a future "live preview/camera filter" product decision is made.

### Provider Benchmark / Cost Telemetry

This is the strongest landing zone. Add Decart candidates to benchmark fixtures:

- `decart/lucy-image-2` for image edit fixtures: background replacement, object replacement, visual restyle, accessory insertion, brand-style matching.
- `decart/lucy-2.1` batch for video-to-video fixtures: short owned clip restyle, object replacement, background replacement, style transfer, identity-preservation stress test.
- `decart/lucy-restyle-2` only if a pure restyling use case becomes important.
- Exclude realtime and Oasis from V1 benchmark unless the benchmark later includes live-session providers.

## Recommendations

1. **No new Decart product spec now.** Existing specs already cover the product surfaces, and Decart's fit is provider/action-level rather than a new standalone feature.
2. **Add Decart to provider benchmark as research-backed candidates.** Start with internal fixtures and mocked/staging calls; record cost, latency, failure modes, moderation, durability, and human quality ratings.
3. **Do not port Lucy-Edit-ComfyUI into production.** Use it for learning/prompting patterns only. Local Dev weights are non-commercial, and the repo has no product-ready license posture for ContentGlows.
4. **Keep Oasis/Mirage as veille.** They are realtime/gaming/live-world signals, not ContentGlows asset-editing requirements.
5. **Require legal/privacy review before any customer-media test.** API Terms, DPA, privacy retention, model-improvement language, likeness consent, and AUP obligations are blockers for production exposure.
6. **If benchmarks pass, draft a future narrow spec:** "AI Asset Edit/Restyle Provider Adapter" scoped to owned Bunny-backed assets and derived asset versions, not a playground.

## Decision

Recommended classification: **ajout au provider benchmark + recherche complémentaire**, not a new spec.

Research complement needed:

- Confirm Decart commercial/API contract terms for customer media, training opt-out, retention, and DPA execution.
- Confirm whether Decart's image-to-video Lucy 5B/14B offering has stable API docs, pricing, output rights, safety policy, and production access.
- Run benchmark fixtures against Flux/Image Robot and Decart Lucy Image 2 before deciding whether image asset editing deserves a future spec.
- Run batch video-to-video fixtures only on non-sensitive owned test assets.

## Chantier Potential

Chantier potentiel: **incertain**.

Proposed title: `Decart Lucy Provider Benchmark And Asset Edit Evaluation`

Reason: findings show non-trivial future work, but the work is best owned first by the existing provider benchmark/cost telemetry spec rather than a new product spec. A new spec should wait until evidence shows Decart outperforms existing providers for a concrete user workflow.

Severity: medium-high due to privacy, likeness, cost, and provider maturity risks.

Scope if later created: backend provider adapter for Decart Lucy Image 2 and/or Lucy 2.1 batch, benchmark fixtures, derived asset records, no creator-facing model picker, no realtime, no local ComfyUI commercial path.

Evidence: Decart docs for Process/Queue/Realtime APIs; pricing docs; API Terms/DPA/Privacy/AUP; ComfyUI/Hugging Face non-commercial model card; existing ContentGlows provider benchmark, asset library, visual reference, b-roll, and Remotion motion specs.

Recommended command if benchmarks prove value: `/sf-spec Decart Lucy asset edit/restyle provider adapter for owned ContentGlows assets`

Next step: update or run the existing provider benchmark workflow with Decart as a candidate; do not create a product spec from this research alone.

## Sources

- [Decart docs index](https://docs.platform.decart.ai/llms.txt) — current doc map for official Decart API pages.
- [Decart API overview](https://docs.platform.decart.ai/getting-started/overview) — overview of realtime video, batch video, and image editing capabilities.
- [Decart models](https://docs.platform.decart.ai/getting-started/models) — current model ids and latest aliases for Lucy 2.1, Lucy Restyle 2, and Lucy Image 2.
- [Decart image editing](https://docs.platform.decart.ai/models/image/image-editing) — Lucy Image 2 endpoint, parameters, references, and prompt guidance.
- [Decart video editing](https://docs.platform.decart.ai/models/video/video-editing) — Lucy 2.1 async video editing workflow, requirements, and reference image support.
- [Decart realtime overview](https://docs.platform.decart.ai/models/realtime/overview) — realtime model distinction between Lucy 2.1 editing and Lucy Restyle Live.
- [Decart Realtime API](https://docs.platform.decart.ai/sdks/python-realtime) — WebRTC realtime connection, model state, prompt/image updates, and backend token guidance.
- [Decart Python SDK](https://docs.platform.decart.ai/sdks/python) — async SDK, Queue/Process/Realtime split, client tokens, model ids.
- [Decart Python Process API](https://docs.platform.decart.ai/sdks/python-process) — synchronous image editing with input image and optional reference image.
- [Decart Python Queue API](https://docs.platform.decart.ai/sdks/python-queue) — async video submit/status/result behavior.
- [Decart JavaScript SDK](https://docs.platform.decart.ai/sdks/javascript) — JS install and queue usage.
- [Decart JavaScript Queue API](https://docs.platform.decart.ai/sdks/javascript-queue) — async queue semantics and supported video models.
- [Decart client tokens](https://docs.platform.decart.ai/getting-started/client-tokens) — short-lived realtime client token security model.
- [Decart pricing](https://docs.platform.decart.ai/getting-started/pricing) — current usage-based prices for Lucy Image 2, Lucy 2.1 batch, and realtime.
- [Decart changelog](https://docs.platform.decart.ai/changelog) — April/May 2026 model launches, retirements, alias changes, DPA/API Terms, and Mirage rename.
- [Decart Acceptable Use Policy](https://docs.platform.decart.ai/resources/aup) — prohibited uses, redistribution obligations, moderation contact.
- [Decart Terms of Service](https://docs.platform.decart.ai/resources/terms-of-service) — content ownership, user responsibility, personal data responsibility, training/improvement language.
- [Decart API Terms](https://docs.platform.decart.ai/resources/api-terms) — credits, suspension, output storage disclaimers, API support caveats.
- [Decart Privacy Policy](https://docs.platform.decart.ai/resources/privacy-policy) — personal data use, anonymization/deidentification, retention.
- [Decart DPA](https://docs.platform.decart.ai/resources/dpa) — processor role, sub-processing, security incident timing, deletion/retention details.
- [Decart public models page](https://decart.ai/models) — Lucy video editing, image-to-video model listings, LSD/Oasis/Oasis 2.0 positioning.
- [Oasis 2.0](https://oasis2.decart.ai/) — realtime gaming/Minecraft-style experience positioning.
- [Lucy-Edit-ComfyUI GitHub](https://github.com/DecartAI/Lucy-Edit-ComfyUI) — ComfyUI nodes, API/local workflows, prompt guidance, roadmap.
- [Lucy Edit Dev Hugging Face model card](https://huggingface.co/decart-ai/Lucy-Edit-Dev-ComfyUI/blob/main/README.md) — non-commercial model license metadata and workflow link.
- `contentglows/TOOLS.md` — local Decart/Oasis/API inspiration links.
- `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md` — existing Flux/Image Robot contract.
- `shipglows_data/workflow/specs/SPEC-ai-visual-reference-upload-advanced-2026-05-11.md` — existing visual reference upload and eligibility contract.
- `shipglows_data/workflow/specs/SPEC-project-visual-asset-library-2026-05-11.md` — existing project visual asset picker/library contract.
- `shipglows_data/workflow/specs/SPEC-ai-provider-benchmark-cost-quality-telemetry-2026-05-12.md` — existing internal provider benchmark/cost telemetry contract.
- `shipglows_data/workflow/specs/monorepo/SPEC-ai-video-broll-generation-workflow-2026-05-13.md` — existing AI b-roll workflow and provider registry framing.
- `shipglows_data/workflow/specs/monorepo/SPEC-remotion-scene-motion-assistant-2026-05-12.md` — existing guided Remotion motion assistant framing.
