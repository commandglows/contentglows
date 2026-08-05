---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-05-11"
created_at: "2026-05-11 15:03:05 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 15:57:46 UTC"
status: ready
source_skill: sf-spec
source_model: "gpt-5.5"
scope: "feature"
owner: "Diane"
confidence: "medium"
user_story: "En tant que créatrice ContentGlows authentifiée, je veux pouvoir entraîner et activer un modèle visuel spécialisé pour un projet avec consentement, droits, contrôle qualité et limites explicites, afin d'obtenir une cohérence visuelle plus forte que les références guidées sans promettre une identité parfaite."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "api/images"
  - "Image Robot"
  - "Project visual memory"
  - "Bunny CDN"
  - "Clerk"
  - "Turso/libSQL"
  - "BFL FLUX.2 training"
  - "model registry"
  - "legal review"
depends_on:
  - artifact: "shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "User request 2026-05-11: create future chantier spec for fine-tuning / LoRA visual identity training."
  - "Product context: current ready specs promise guided visual consistency via project references, not perfect identity."
  - "Code evidence: lab/api/routers/images.py currently has Image Robot routes for profiles, generation, upload, history, and project-scoped data, but no training workflow or model registry."
  - "Code evidence: lab/api/services/ai_image_generation.py currently supports OpenAI image generation only as a local-file provider helper."
  - "Code evidence: lab/agents/images uses Bunny CDN upload/optimizer flows and Robolly-oriented deterministic Image Robot components."
  - "External docs checked by parent 2026-05-11: BFL FLUX.2 [klein] Training, BFL FLUX.2 Style Training, and official BFL FLUX.2 inference repo."
  - "User decision 2026-05-11: keep this spec as future research/non-blocking for the current Image Robot feature."
  - "User decision 2026-05-11: do not make product copy promise guaranteed identity."
  - "User decision 2026-05-11: lack of provider-side true untraining/deletion is not automatically blocking, but must be disclosed and handled."
  - "User decision 2026-05-11: training access is admin-only for now."
  - "User decision 2026-05-11: do not introduce a blanket ban on people/human likeness in user-created videos; training still needs consent/legal review."
  - "Readiness pass 2026-05-11: recast unresolved research topics as implementation gates, stop conditions, and admin-only disabled-by-default workflow requirements."
  - "Fresh docs rechecked 2026-05-11 during sf-ready: official BFL FLUX.2 [klein] Training, Style Training, and official GitHub inference repo remain the cited external sources."
next_step: "/sf-start AI Visual Identity Training And LoRA Research Workflow"
---

# Title

AI Visual Identity Training And LoRA Research Workflow

## Status

Ready for `/sf-start` as a future research and controlled-workflow chantier, explicitly non-blocking for the current Flux/Image Robot feature. It must not be implemented as a silent extension of V1 or exposed as public self-serve training. Product direction is fixed for this phase: admin-only access, no product promise of guaranteed identity, no blanket ban on people in user-created videos, and provider deletion gaps are acceptable only when disclosed, audited, and future use is disabled. The current ready specs remain the product baseline: guided visual consistency from project references, structured prompts, and durable project assets.

## User Story

En tant que créatrice ContentGlows authentifiée, je veux pouvoir entraîner et activer un modèle visuel spécialisé pour un projet avec consentement, droits, contrôle qualité et limites explicites, afin d'obtenir une cohérence visuelle plus forte que les références guidées sans promettre une identité parfaite.

## Minimal Behavior Contract

When an admin-qualified authenticated project owner/operator starts a visual identity training workflow, ContentGlows collects only project assets with documented rights, consent where required, retention settings, and training purpose; validates that the dataset meets quality, safety, likeness, copyright, and minimum-volume rules; creates a controlled training job with provider-specific metadata; registers the resulting model or LoRA artifact only after evaluation; and allows Image Robot generation to opt into that trained identity for that project. If consent, rights, dataset quality, provider availability, legal review, budget, or evaluation gates fail, the workflow must stop or remain inactive and generation must fall back to guided references. The easy edge case to miss is treating training as a stronger prompt feature: trained artifacts create new data-retention, likeness, copyright, deletion, cost, and safety obligations that must be product-visible and auditable even when normal user videos may contain people.

## Success Behavior

- Given an admin-qualified project owner/operator opens the future training workflow, when they create a dataset, then every included asset records source, ownership/rights basis, consent status where applicable, subject/likeness flags, copyright/style risk flags, retention policy, and whether it may be used for model training.
- Given the dataset includes people, faces, brand mascots, customer images, employee images, creator likenesses, or any biometric-adjacent likeness, when training is requested, then the workflow requires explicit consent metadata and a recorded legal/product approval decision before provider submission.
- Given a dataset passes automated and manual review, when training starts, then ContentGlows creates a durable training job with provider, model family, training type, dataset version, cost estimate, owner, project id, status, admin approver, and audit trail.
- Given the provider returns a trained LoRA/model artifact, when evaluation passes defined quality and safety thresholds, then the artifact is added to a project-scoped model registry as inactive or staged until a human explicitly activates it.
- Given a trained artifact is active for a project, when Image Robot generates an eligible visual, then the backend may pass the trained model/LoRA identifier through the provider-specific generation path and records `visual_identity_mode=trained_project_model`.
- Given a trained artifact is not active, revoked, expired, deleted, over budget, unsafe, or unavailable, when generation runs, then Image Robot uses the existing guided-reference path and records the fallback reason.
- Given the owner, administrator, or authorized depicted subject requests opt-out or deletion, when the request is accepted, then ContentGlows disables the artifact immediately, stops future use, deletes or requests deletion of provider-side training artifacts where supported, updates retention/audit records, and communicates any provider limitations. Provider inability to truly untrain is not automatically blocking, but it must be explicit before any training submission.
- Given model quality is evaluated, when results are shown internally, then the system reports measured consistency and failure rates, not identity guarantees.

## Error Behavior

- If the user is not authenticated or does not own/admin the project, reject dataset, training, registry, activation, and deletion actions.
- If any asset lacks training rights, consent, or project ownership metadata, exclude it from the dataset and block training when minimum dataset requirements are no longer met.
- If an asset is flagged as a third-party copyrighted style imitation, living artist style request, brand-confusable work, unsafe content, or unclear provenance, require manual review or exclude it.
- If likeness/biometric consent is missing, ambiguous, expired, withdrawn, or belongs to a minor/sensitive category, block training for that asset and require legal review before any override policy can exist.
- If the provider training API fails, times out, returns unsafe output, returns no artifact id, or changes contract, keep the training job failed/pending with sanitized provider details and do not activate anything.
- If evaluation fails consistency, safety, copyright, or prompt-leakage checks, store the artifact as rejected or quarantine it; never silently activate it.
- If deletion/opt-out cannot be fully completed provider-side, mark the artifact disabled immediately, record the provider-side deletion gap, and surface the residual retention limitation for review.
- If a project has an active trained identity but a generation endpoint does not support it, generation must fail clearly or use guided references with explicit fallback metadata; it must not pretend training was applied.
- What must never happen: training on unconsented likenesses, cross-project model reuse, provider secrets in app responses, model activation without evaluation, automatic public claims of perfect identity matching, or hidden retention of deleted training data.

## Problem

The current ready AI visual specs deliberately promise only `coherence visuelle guidee`: project references, structured prompts, approved visual memory, and guided placements. That is the correct V1 boundary, but it may not satisfy projects that need recurring characters, products, creators, mascots, or brand worlds with stronger consistency across many generated assets. Fine-tuning, LoRA, and provider-managed style training can improve consistency in some conditions, but they introduce high-risk product, legal, ethical, cost, and security responsibilities that do not exist in reference-guided generation.

## Solution

Define a future controlled workflow for project-specific visual identity training. The system treats training as a governed lifecycle: dataset intake, rights/consent review, provider training job, artifact registry, evaluation, staged activation, generation-time selection, monitoring, opt-out/deletion, and documentation. Public self-serve access remains out of scope. The product language must remain prudent: trained identity may improve consistency under supported conditions, but ContentGlows must not promise absolute identity preservation or perfect likeness.

## Scope In

- Research and specify provider-managed FLUX.2 training, LoRA-style artifacts, or equivalent specialized visual identity model workflows.
- Create a project-scoped dataset model for training candidates, dataset versions, asset rights, consent, provenance, retention, and review state.
- Add consent and rights gates for assets containing faces, people, likenesses, brand marks, copyrighted material, customer assets, or third-party style influence.
- Add dataset quality checks: minimum/maximum images, duplicate detection, resolution, aspect coverage, subject coverage, unsafe content, noisy captions, and outlier rejection.
- Add a training job lifecycle: draft, review_required, approved, queued, training, provider_failed, evaluating, rejected, staged, active, disabled, deletion_requested, deleted.
- Add a project-scoped model/LoRA registry with artifact id, provider, base model, dataset version, training parameters, evaluation report, activation state, retention/deletion state, and cost metadata.
- Add Image Robot generation activation logic so eligible profiles can use a trained project artifact only when active and compatible.
- Add evaluation tooling for consistency, prompt adherence, safety, copyright/style risk, likeness risk, and negative regression against guided-reference generation.
- Add cost controls: estimates, owner confirmation, budget caps, retry limits, training frequency limits, and provider invoice metadata.
- Add audit logs for dataset changes, consent updates, training starts, evaluation decisions, activation, fallback, opt-out, deletion, and legal review.
- Add product copy/docs that set limits clearly: improved consistency, no absolute guarantee, no unrestricted style or likeness cloning.

## Scope Out

- Implementing training in the current Flux/Image Robot V1.
- Public self-serve training without admin gating and review.
- Anonymous generation or anonymous training.
- Local model hosting, GPU orchestration, or custom inference infrastructure unless a later architecture decision selects it.
- Training on arbitrary uploads without durable project ownership and rights metadata.
- Training for perfect face identity, biometric identification, authentication, or surveillance use cases.
- Copying a living artist's style, protected character, or third-party brand identity as a product promise.
- Cross-project sharing, marketplace sale, or public export of trained artifacts.
- Automatic retroactive training on existing Bunny/CDN images without new consent and rights capture.
- Billing implementation beyond training cost estimation, budget gating, and provider metadata capture.

## Constraints

- This spec is future-facing but ready for controlled implementation. The implementation must default every training capability to disabled until provider credentials, legal/product approval metadata, retention settings, budget caps, and admin permissions are configured.
- The current V1 promise remains guided visual consistency. Product surfaces must not claim guaranteed identity, perfect character lock, or absolute style reproduction.
- Training artifacts are project-scoped and must not be reused across projects by default.
- Training access is admin-only until a later product decision broadens it.
- Training requires authenticated project ownership/admin permission and explicit dataset approval.
- Rights and consent metadata must be stored before provider submission; provider-side terms must be rechecked against official docs and recorded before enabling a real provider call.
- Deletion and opt-out behavior must be designed before launch, including provider limitations where model untraining is impossible or delayed. A deletion limitation is not automatically blocking if future use is disabled and the limitation is disclosed before training.
- Provider secrets, signed training upload URLs, and provider artifact ids that function as secrets must never reach Flutter.
- Data retention must be configurable and documented for source images, captions, dataset archives, training manifests, evaluation samples, and trained artifacts.
- Any likeness-sensitive or biometric-adjacent workflow requires a recorded legal/product approval event before dataset approval or provider submission.
- Any generated output used for evaluation must be stored only as needed and must follow the same project ownership and deletion policies as other generated images.
- Security impact: yes, mitigated by server-side Clerk auth, project/admin authorization, signed URL containment, provider secret isolation, project-scoped storage, audit logs, immediate disablement on opt-out, rate/cost limits, sanitized provider errors, and tests for cross-project access and leakage.

## Dependencies

- Ready baseline backend spec: `shipglows_data/workflow/specs/SPEC-flux-ai-provider-image-robot-2026-05-11.md`.
- Ready editor UI spec: `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`.
- Existing backend entrypoints:
  - `lab/api/routers/images.py`
  - `lab/api/services/ai_image_generation.py`
  - `lab/agents/images/**`
- Expected future backend modules:
  - `lab/api/models/image_training.py`
  - `lab/api/routers/image_training.py`
  - `lab/api/services/image_training_store.py`
  - `lab/api/services/visual_identity_registry.py`
  - `lab/api/services/flux_training_provider.py`
  - `lab/api/services/visual_identity_evaluation.py`
- Existing storage/auth/data systems: Clerk, Bunny CDN, Turso/libSQL, Image Robot jobs/history once implemented by the Flux provider spec.
- Fresh external docs: `fresh-docs checked`. The parent run and this `sf-ready` pass checked these official sources on 2026-05-11; no local BFL SDK/package version is currently pinned in this spec:
  - BFL FLUX.2 [klein] Training: `https://docs.bfl.ai/flux_2/flux2_klein_training`
  - BFL FLUX.2 Style Training: `https://docs.bfl.ai/flux_2/flux2_klein_training_example`
  - Official BFL FLUX.2 inference repo: `https://github.com/black-forest-labs/flux2`

## Invariants

- Every training dataset belongs to exactly one project and one accountable user/org.
- Every dataset asset has durable provenance, rights basis, consent state, and retention state before training.
- A trained artifact cannot be active without a passing evaluation report and explicit activation event.
- Generation must record whether it used guided references, a trained project artifact, both if provider-supported, or a fallback path.
- Training artifacts must be disabled immediately when consent is withdrawn or project access/ownership policy requires it.
- Cross-project access to datasets, training jobs, artifacts, evaluation outputs, and generated samples is forbidden.
- Product and docs language must describe trained identity as a consistency aid with measurable limits, not a guarantee.
- Existing Robolly/OpenAI/Flux guided-reference paths must remain usable when training is unavailable.

## Links & Consequences

- `lab/api/routers/images.py`: future generation routes need compatibility checks for `visual_identity_mode`, active artifact id, fallback reason, and registry lookup.
- `lab/api/services/ai_image_generation.py`: current OpenAI helper is not a training provider abstraction; training needs separate provider services and normalized contracts.
- `lab/agents/images/tools/bunny_cdn_tools.py`: source images and evaluation outputs must use safe ingestion and avoid arbitrary/private URL fetches.
- `app` visual UI: future training controls should be behind a project settings or visual identity management surface, not inside the basic generation prompt flow.
- Turso/libSQL: training introduces new durable tables with sensitive metadata and audit requirements.
- Legal/support/docs: consent withdrawal, deletion, copyright/style complaints, and model limitation explanations become support workflows.
- Analytics/ops: training job latency, failure rate, evaluation pass rate, cost per project, activation rate, fallback rate, and deletion SLA become operational metrics.
- Pricing: provider training and evaluation costs may require plan gating before public availability.

## Documentation Coherence

- Add backend setup docs for provider training credentials, allowed training provider, environment variables, and cost/timeout settings.
- Add product docs explaining the difference between guided references and trained visual identity.
- Add consent/rights help copy before dataset submission.
- Add support docs for opt-out, consent withdrawal, deletion, copyright/style complaints, and model limitation reports.
- Add internal legal/security review notes before enabling real provider submission or human-likeness training.
- Add changelog only when implementation ships; this spec update alone does not change user-facing behavior.

## Edge Cases

- Dataset has enough images numerically but all are too similar, too low-resolution, or overfit to one pose/background.
- Dataset mixes multiple people, products, mascots, styles, or brands without labels and causes identity bleed.
- Dataset contains images where the uploader owns the file but not the depicted person's likeness rights.
- Dataset contains AI-generated images whose original training rights or downstream training rights are unclear.
- A user asks to mimic a living artist, competitor brand, copyrighted character, celebrity, or private person.
- Consent is withdrawn after a model is trained and before provider-side deletion completes.
- Provider supports disabling an artifact but not true untraining/deletion.
- Training succeeds but evaluation shows higher consistency and higher copyright/likeness risk.
- Active artifact improves one placement, such as thumbnails, but degrades another, such as blog heroes.
- Provider changes training limits, dataset format, base model compatibility, pricing, or retention terms.
- Project ownership changes, team members leave, or a customer requests data export/deletion.
- Multiple active artifacts exist for one project, such as product identity and creator likeness, and a generation profile must choose safely.

## Implementation Tasks

- [ ] Task 1: Add provider/legal/product readiness gate
  - Files: `lab/api/models/image_training.py`, `lab/api/services/flux_training_provider.py`, `lab/README.md`.
  - Action: Represent provider training terms, dataset requirements, retention/deletion capabilities, likeness policy flags, copyright/style policy flags, price model, supported inference activation contract, and a `training_enabled=false` default config. The gate must block real provider submission unless an admin records current official-doc review, legal/product approval, budget cap, retention policy, and disclosure text.
  - User story link: Prevents shipping training before its obligations are explicitly recorded.
  - Depends on: none.
  - Validate with: model/config tests that provider submission remains disabled when any gate field is missing, stale, expired, or inconsistent.

- [ ] Task 2: Define training data and registry models
  - File: `lab/api/models/image_training.py`
  - Action: Add typed models for dataset assets, dataset versions, consent records, rights records, training jobs, evaluation reports, registry artifacts, activation state, deletion state, and normalized provider errors.
  - User story link: Makes training auditable and project-scoped.
  - Depends on: Task 1.
  - Validate with: model validation tests for consent, retention, rights, artifact states, and invalid transitions.

- [ ] Task 3: Add durable training store
  - File: `lab/api/services/image_training_store.py`
  - Action: Create Turso/libSQL-backed storage for datasets, dataset assets, consent/rights metadata, training jobs, evaluation reports, registry artifacts, audit events, and deletion requests.
  - User story link: Ensures training decisions and opt-out state survive process restarts.
  - Depends on: Task 2.
  - Validate with: store tests for project isolation, state transitions, deletion disablement, and audit append behavior.

- [ ] Task 4: Add dataset intake and review API
  - File: `lab/api/routers/image_training.py`
  - Action: Add authenticated admin-only endpoints to create dataset drafts, add/remove existing Bunny-backed project assets, capture consent/rights metadata, request review, approve/reject dataset versions, and list audit history.
  - User story link: Lets project owners prepare training data without arbitrary ungoverned upload.
  - Depends on: Tasks 2 and 3.
  - Validate with: API tests for ownership, missing consent, cross-project assets, review-required states, and deletion/withdrawal.

- [ ] Task 5: Implement training provider adapter
  - File: `lab/api/services/flux_training_provider.py`
  - Action: Implement a provider abstraction for BFL FLUX.2 training or selected equivalent, including dataset manifest preparation, signed upload handling if required, training submission, polling, provider error normalization, cost metadata, artifact id capture, and timeout behavior.
  - User story link: Connects governed datasets to provider-managed training without leaking provider details.
  - Depends on: Tasks 1, 2, and 3.
  - Validate with: mocked provider tests for success, validation failure, rate limit, cost limit, timeout, provider retention metadata, and missing credentials.

- [ ] Task 6: Build evaluation pipeline
  - File: `lab/api/services/visual_identity_evaluation.py`
  - Action: Generate or score a fixed evaluation set comparing guided-reference baseline versus trained artifact for consistency, prompt adherence, safety, likeness/copyright risk, artifact quality, and placement fit. Thresholds must be configuration values recorded in the evaluation report; if thresholds are absent, activation is blocked.
  - User story link: Activates only artifacts that measurably improve the project within acceptable risk.
  - Depends on: Task 5.
  - Validate with: deterministic fixture tests, threshold tests, failed-evaluation quarantine, and report serialization tests.

- [ ] Task 7: Add project visual identity registry
  - File: `lab/api/services/visual_identity_registry.py`
  - Action: Register trained artifacts, enforce lifecycle transitions, expose active/staged/disabled status, handle activation/deactivation, and record deletion/opt-out state. Support multiple registry artifacts per project but allow at most one active artifact per generation profile unless a later spec defines composition rules.
  - User story link: Lets Image Robot choose a trained identity only when safe and active.
  - Depends on: Tasks 3 and 6.
  - Validate with: registry state machine tests and cross-project isolation tests.

- [ ] Task 8: Integrate trained identity into generation
  - File: `lab/api/routers/images.py`
  - Action: Extend generation request/response metadata to support `visual_identity_mode`, active artifact lookup, provider compatibility checks, fallback reason, and audit logging while preserving guided-reference behavior.
  - User story link: Makes trained identity available during generation without changing the product promise to a guarantee.
  - Depends on: Task 7 and the ready Flux provider implementation.
  - Validate with: API tests for active artifact use, disabled fallback, incompatible provider fallback, and metadata persistence.

- [ ] Task 9: Add opt-out and deletion workflow
  - File: `lab/api/routers/image_training.py`
  - Action: Add endpoints and service actions for consent withdrawal, artifact disablement, provider deletion request, dataset retention deletion, audit logging, and user-visible deletion status.
  - User story link: Gives owners and depicted subjects a path to stop future use.
  - Depends on: Tasks 3, 5, and 7.
  - Validate with: tests for immediate disablement, provider deletion failure, partial deletion status, and future generation block.

- [ ] Task 10: Specify and implement app management UI later
  - File: `shipglows_data/workflow/specs/app/SPEC-ai-visual-identity-training-management-ui-2026-05-11.md`
  - Action: Create a separate UI spec for project visual identity training management after backend gates exist; until that spec is ready, expose no public self-serve UI and keep admin-only operations backend/API driven.
  - User story link: Keeps training management separate from basic editor-linked generation and avoids accidental public exposure.
  - Depends on: Tasks 1 through 9.
  - Validate with: created UI spec or explicit handoff note stating that no app route, menu item, or editor prompt exposes training.

- [ ] Task 11: Document operations, support, and product limits
  - Files: `lab/README.md`, `app/README.md`, `lab/.env.example`, support/legal docs selected during implementation.
  - Action: Document setup, provider credentials, cost controls, data retention, deletion/opt-out, consent language, rights requirements, disclosure of provider deletion limitations, and careful product claims.
  - User story link: Prevents users and operators from misunderstanding trained visual identity as guaranteed or unconstrained.
  - Depends on: Tasks 1 through 9.
  - Validate with: docs review and support scenario walkthrough.

## Acceptance Criteria

- A fresh engineer can explain the difference between guided visual consistency and trained project identity from this spec alone.
- No implementation path allows training without authenticated project ownership, consent/rights metadata, dataset review, and provider/legal sign-off.
- Dataset, training job, registry artifact, evaluation report, activation, fallback, and deletion states are all durable and project-scoped.
- Generation records show whether a trained artifact was used and why fallback occurred when it was not.
- A trained artifact cannot become active without passing evaluation and explicit activation.
- Consent withdrawal disables future use immediately even if provider-side deletion is asynchronous or partial.
- Product copy and docs avoid absolute guarantees and describe measured, bounded consistency.
- Tests cover ownership, consent, rights, provider failure, evaluation failure, activation, fallback, opt-out, deletion, and cross-project isolation.
- Real provider training remains disabled until an admin records current official-doc review, legal/product approval, retention policy, budget cap, and disclosure text.
- If provider-side true untraining is unavailable, the system still disables future use immediately, records the residual limitation, and exposes the status for audit/support.

## Test Strategy

- Unit tests for training data models, state machines, retention flags, consent expiry/withdrawal, and invalid lifecycle transitions.
- Store tests against SQLite/libSQL for dataset versioning, audit logs, registry state, and deletion state.
- API tests for Clerk-authenticated ownership, project isolation, dataset review, training submission, activation, and opt-out.
- Mocked provider tests for FLUX.2/BFL training submission, polling, failure mapping, artifact id capture, pricing metadata, and retention/deletion limitations.
- Evaluation tests with fixture datasets and generated samples to verify thresholds, rejected artifacts, and report persistence.
- Regression tests proving existing guided-reference generation still works when no trained artifact exists.
- Security tests for cross-project artifact use, arbitrary URL ingestion, signed URL leakage, provider secret leakage, and deletion access.
- Manual QA checklist for high-risk scenarios: face/likeness consent, living artist style request, third-party brand similarity, deletion request, and budget cap exceeded.
- Readiness regression test proving `training_enabled=false` blocks provider calls and activation even when lower-level services are present.

## Risks

- Legal/ethical: likeness and biometric-adjacent training may require consent standards, jurisdiction-specific handling, and legal review before any rollout.
- Copyright/style: training or prompting may create claims around artist style imitation, brand confusion, or protected characters.
- Product trust: users may interpret training as an identity guarantee unless copy and UI remain careful.
- Privacy/security: datasets and trained artifacts may contain sensitive personal or customer data.
- Deletion limits: provider-side artifacts may not support true untraining or immediate deletion.
- Cost: training, evaluation, retries, and storage may be expensive and unpredictable.
- Quality: LoRA/specialized training can overfit, underfit, or degrade prompt adherence compared with guided references.
- Provider lock-in: training artifacts may not be portable between provider models or future FLUX versions.
- Operations: long-running jobs, partial failures, and review queues increase support burden.

## Execution Notes

- Read first: `lab/api/routers/images.py`, `lab/api/services/ai_image_generation.py`, `lab/agents/images/**`, `shipglows_data/technical/lab/guidelines.md`, `shipglows_data/technical/app/guidelines.md`, the ready Flux provider spec, and the ready editor-linked visuals UI spec.
- Start with data contracts and disabled-by-default gates before provider calls. The first implementation milestone should prove that unauthorized users, non-admin users, missing consent, missing rights, missing retention, missing budget, missing provider-doc review, and `training_enabled=false` all block submission.
- Prefer provider-managed FLUX.2/BFL training adapter boundaries over self-hosted GPU infrastructure. Do not add local GPU orchestration, custom model hosting, marketplace export, or broad UI exposure in this chantier.
- Reuse existing FastAPI router/service/model patterns, Clerk auth dependencies, Bunny-backed project asset references, and Turso/libSQL storage patterns. Avoid ad-hoc string state machines; encode lifecycle states as typed values and validate transitions.
- Dataset ingestion should reuse durable Bunny-backed assets where possible, but training permission must be newly captured; existing project visual references are not automatically training-approved.
- Evaluation must include qualitative review and measurable criteria stored in the evaluation report. Metrics support internal decisions but must not become a public claim of guaranteed identity.
- Validation commands after implementation: targeted `pytest` for image training models/store/router/provider/evaluation tests; existing Image Robot/guided-reference regression tests; documentation lint or review for `README.md` and `.env.example` changes.
- Stop conditions: no real provider submission, activation, or user-facing UI if official provider docs are stale, provider credentials are missing, legal/product approval metadata is absent, retention/disclosure text is absent, budget caps are missing, evaluation thresholds are absent, or cross-project authorization tests fail.

## Product Decisions Captured

- This spec remains future research and does not block the current Image Robot feature.
- Access is admin-only for now.
- Product copy must say the feature can improve consistency, not guarantee identity.
- There is no blanket product ban on people in user-created videos; training on human likeness still needs consent/legal policy.
- Provider inability to guarantee true untraining/deletion is not automatically blocking, but future use must be disabled and the limitation disclosed/audited.

## Open Questions

None. The unresolved policy-specific values are implementation gate inputs, not hidden product questions: real provider submission and activation remain disabled until an admin records current provider-doc review, legal/product approval, retention/disclosure policy, budget cap, evaluation thresholds, and support owner for the project/dataset.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 15:03:05 | sf-spec | gpt-5.5 | Created draft future research spec for AI visual identity training / LoRA. | Draft spec created with consent, rights, registry, evaluation, cost, safety, retention, and open questions. | /sf-ready shipglows_data/workflow/specs/SPEC-ai-visual-identity-training-lora-2026-05-11.md |
| 2026-05-11 15:38:45 UTC | sf-spec | GPT-5 Codex | Integrated product decisions for future research status, admin-only access, no identity guarantee, no blanket people ban, and provider deletion-gap handling. | Draft updated; legal/consent/retention/cost/quality questions remain. | /sf-ready shipglows_data/workflow/specs/SPEC-ai-visual-identity-training-lora-2026-05-11.md |
| 2026-05-11 15:57:46 UTC | sf-ready | GPT-5 Codex | Ran readiness gate and converted unresolved research topics into explicit disabled-by-default gates, stop conditions, validation checks, and admin-only workflow constraints. | Ready. | /sf-start AI Visual Identity Training And LoRA Research Workflow |

## Current Chantier Flow

sf-spec ✅ -> sf-ready ✅ -> sf-start ⏳ -> sf-verify ⏳ -> sf-end ⏳ -> sf-ship ⏳
