---
artifact: repurpose_pack
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: contentglows
created: "2026-07-11"
updated: "2026-07-11"
status: draft
source_skill: 202-sg-repurpose
scope: project-memory-product-and-architecture
owner: Diane
confidence: high
risk_level: high
security_impact: yes
docs_impact: yes
source_type: conversation_transcript
source_ref: docs/conversations/conversation-contentglows-memoire-projet-sobre-et-vectorielle-20260711-120903.md
linked_systems:
  - lab/memory/
  - lab/api/services/project_intelligence_processor.py
  - lab/api/services/brand_profile_store.py
  - shipglows_data/workflow/specs/lab/SPEC-project-intelligence-engine-data-layer-2026-05-13.md
  - shipglows_data/technical/lab/backend-runtime-and-product-apis.md
  - shipglows_data/product/app/product.md
  - shipglows_data/editorial/site/content-map.md
depends_on:
  - artifact: docs/conversations/conversation-contentglows-memoire-projet-sobre-et-vectorielle-20260711-120903.md
    required_status: captured
supersedes: []
evidence:
  - "Captured operator conversation defining the customer, product, and architecture boundaries for project memory."
  - "Existing Project Intelligence, project-scoped brand profiles, and optional Mem0 code confirmed in the repository."
next_step: /100-sg-spec sober project memory and retrieval architecture
---

# ContentGlows Project Memory Source-Faithful Pack

## Best Next Actions

1. Reframe the existing Project Intelligence chantier around one invariant: ContentGlows-owned relational data is canonical; vector search is a rebuildable retrieval index.
2. Specify the first generation-context contract before choosing a vector provider: required structured facts, optional retrieved excerpts, token budget, provenance, and project isolation.
3. Inventory the current Mem0 callers and map each call to structured project context, retrieved evidence, or removable agent history.
4. Define how ordinary customer actions become memory signals without exposing technical memory administration in the product UI.
5. Keep public claims deferred until the context-selection path is implemented, tested, and observable end to end.

## Source-Faithful Pack

### Source Classification

- Source type: product and technical conversation transcript.
- Primary project: ContentGlows.
- Best angle: product architecture and future public explanation.
- Owner route: `100-sg-spec` for implementation framing, then `300-sg-docs` and public content owners after verification.
- Main risks: tenant isolation, silent learning, stale or contradictory facts, unsupported quality claims, and coupling to fast-moving agent-memory frameworks.

### Source Truth

- The product goal remains valid: generated content should become increasingly coherent with each customer project.
- The customer must not administer a technical memory system. ContentGlows should learn from normal product actions such as brand setup, explicit instructions, corrections, approvals, and repeated edits.
- A generic autonomous agent-memory layer is not required to satisfy that goal and currently introduces avoidable dependency and operational complexity.
- Canonical project knowledge should be explicit, inspectable, versioned, attributable to a source, and isolated by project.
- Critical facts and rules should be selected deterministically for generation.
- Vector search should retrieve relevant documents, approved examples, and historical excerpts. It should not decide what is true.
- The model may propose candidate learnings, but application rules must decide whether they become durable project knowledge.
- The vector index must be reconstructible from canonical project data and must support deletion or invalidation when a source changes.

### Core Product Model

The customer experience is automatic:

1. The customer configures a project and creates content normally.
2. ContentGlows observes explicit instructions, corrections, approvals, and repeated choices.
3. The backend records reliable facts directly and keeps uncertain preferences as candidates.
4. Before generation, ContentGlows assembles a bounded context from structured facts and relevant retrieved evidence.
5. The generated result and subsequent edits provide new signals for later generations.

The customer may see plain-language controls such as "always use this spelling", "do not use this expression", or "use this as a reference". They should not see embeddings, collections, vector stores, confidence plumbing, or agent-memory configuration.

### Technical Separation Of Responsibilities

| Layer | Responsibility | Must not own |
| --- | --- | --- |
| Relational product store | Canonical facts, brand rules, preferences, provenance, status, versions, project ownership | Semantic relevance ranking |
| Vector index | Retrieve relevant excerpts from documents, approved content, and examples | Truth, authorization, or permanent memory decisions |
| Context builder | Merge required facts and bounded retrieval results into a generation contract | Unbounded prompt accumulation |
| Generation model | Draft content from the supplied context | Silent writes to canonical project knowledge |
| ContentGlows policy | Accept, reject, expire, supersede, or delete learnings | Delegating governance to a third-party memory framework |

### Candidate Data Contracts

- `project_context`: project identity, active brand profile, audience, objectives, preferred and forbidden terminology, product facts, editorial rules, and version.
- `project_memory`: category, normalized content, source, confidence, lifecycle status, first-seen and last-used timestamps.
- `project_source`: uploaded or connected source metadata, ownership, content version, processing status, and provenance.
- `project_knowledge_chunk`: source ID, chunk version, project ID, category, embedding reference, and invalidation state.
- `generation_context_log`: generation ID, required facts used, retrieved source IDs, context version, and policy decisions.
- `content_revision_signal`: generated text reference, approved revision reference, extracted differences, and candidate learnings.

These are design candidates from the conversation, not approved database schemas.

### Retrieval Contract

- Filter by authenticated ownership and `project_id` before semantic ranking.
- Inject critical facts and explicit rules directly rather than relying on similarity search.
- Retrieve only bounded, source-attributed excerpts relevant to the requested channel and content type.
- Record which facts and excerpts were supplied to each generation.
- Invalidate or replace indexed chunks when their canonical source changes.
- Treat an unavailable vector index as a degraded retrieval condition, not as loss of canonical project knowledge.
- Hide the storage provider behind a small internal interface for index, search, and source deletion.

### Learning Policy

- Explicit customer fact or instruction: eligible for immediate durable storage.
- Explicit correction: high-confidence learning with provenance.
- Repeated edit pattern: candidate preference until the evidence threshold is met.
- One-off behavior: do not persist as a durable preference.
- Contradictory information: supersede or request product-level clarification; do not silently average facts.
- Model inference: candidate only; never an autonomous permanent write.

### Reusable Wording

- "The relational database knows what is true. The vector index finds what is relevant. The model writes. ContentGlows decides what can be learned, forgotten, or used."
- "Vector search is a retrieval engine for project memory, not the memory itself."
- "ContentGlows improves from ordinary customer work without turning the customer into a memory-system administrator."

### Documentation Notes

- User-visible behavior: the product reuses explicit brand rules, project facts, approved references, and validated preferences during later generations.
- Workflow impact: generation must pass through a bounded context builder with provenance and project isolation.
- Constraint: no public claim that ContentGlows "learns automatically" until learning thresholds, correction behavior, deletion, and generation use are verified.
- Security constraint: every canonical item and indexed chunk must remain tenant- and project-scoped.

### Internal Change Narrative

- Before: memory is partly framed as an agent capability supplied by Mem0/Chroma and consumed by feature-specific agent flows.
- After: project knowledge becomes a ContentGlows product domain; vector retrieval and models are replaceable implementation details.
- Tradeoff: more explicit schemas and policies in exchange for predictable behavior, inspectability, easier testing, and reduced framework coupling.
- Follow-up: decide whether the existing Project Intelligence Engine spec should be amended or superseded by a narrower memory-to-generation slice.

### Marketing Claims

- Safe now: ContentGlows has project-scoped brand profiles and Project Intelligence foundations documented in the repository.
- Safe as a product direction: ContentGlows is designing project context so future generations can reuse project-specific facts, rules, and approved references.
- Must soften: "ContentGlows learns your brand automatically."
- Avoid until verified: claims of improved content quality, perfect brand consistency, autonomous learning, guaranteed factual accuracy, privacy, security, or effortless long-term memory.

### Content Angles

- Product education: why useful AI memory is a governed product system rather than a chatbot history.
- Technical explanation: truth, relevance, writing, and governance are four separate responsibilities.
- FAQ: "Do I have to configure or manage ContentGlows's memory?"
- Platform page: how project context can shape generation while keeping project boundaries explicit.
- Founder narrative: moving from impressive agent frameworks to a smaller, more durable architecture.

### Diffusion Map

- Canonical public surface after implementation: a declared Platform page explaining project context and generation.
- Supporting surfaces: homepage capability summary, FAQ, relevant agent pages, and one technical/founder article.
- Repeated concept: ContentGlows uses project context automatically; the customer controls ordinary product inputs, not memory infrastructure.
- Per-surface job: Platform explains the mechanism, FAQ removes customer anxiety, agent pages show workflow impact, and the article explains the architectural principle.
- Intentionally skipped now: pricing, security/privacy promises, and quantified quality claims.

## Existing Content Opportunities

| Lane | Surface | Placement idea | Audience learning moment | Source proof | Content move | Priority | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Internal docs | `shipglows_data/workflow/specs/lab/SPEC-project-intelligence-engine-data-layer-2026-05-13.md` | Clarify relational authority, vector-index rebuildability, learning policy, and generation-context logging | Contributors understand that embeddings retrieve evidence but do not define truth | Conversation architecture and existing spec already describe ContentGlows-owned memory | Amend or supersede through a bounded spec decision | must write | `100-sg-spec` |
| Internal docs | `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` | Expand Project Intelligence with the generation-context and degraded-retrieval contracts | Implementers understand how memory reaches generation safely | Existing doc already calls Project Intelligence project-scoped memory | Add contract after implementation | should write | `300-sg-docs` |
| Internal docs | `shipglows_data/product/app/product.md` | Describe customer-facing learning controls without technical memory language | Product owners distinguish automatic context reuse from customer administration | Conversation explicitly rejects a technical memory UI | Update after scope approval | should write | `300-sg-docs` |
| Internal docs | `lab/memory/` documentation | Mark Mem0 as legacy/optional and map consumers to the future project-context service | Maintainers know which code is transitional | Dependency audit and transcript show Mem0 is optional and feature-specific | Migration note, not immediate deletion | should write | `300-sg-docs` |
| Public content | `site/src/content/platform/` | Add a project-context page only after the feature is verified | Customers understand that ContentGlows reuses project knowledge without requiring technical setup | Product concept is clear, but delivery is not yet proven end to end | Defer new page until verification | must write later | `200-sg-redact` |
| Public content | Site FAQ or homepage | Answer "Do I have to manage the AI memory?" in plain language | Customers understand they manage their project, not infrastructure | Conversation supplies the objection and answer | Add FAQ after product contract is shipped | should write later | `201-sg-enrich` |
| Public content | `site/src/content/ai-agents/` | Replace generic agent-memory framing with project-context wording where applicable | Readers understand that agent output is grounded by governed project data | Conversation separates agent behavior from memory governance | Audit after implementation | optional | `206-sg-audit-copy` |

## Owner Skill Handoffs

### Product And Architecture Spec

- Target: existing Project Intelligence Engine spec or a new bounded successor spec.
- Source truth: relational project knowledge is canonical; vectors retrieve; models draft; ContentGlows governs learning.
- Source proof: captured transcript plus existing project intelligence, brand-profile, and generation infrastructure.
- Content move: define schemas, context assembly, learning thresholds, tenant isolation, invalidation, observability, and migration from Mem0 callers.
- Claim constraint: do not assume a vector provider or promise automatic quality improvement.
- Priority: must write.
- Next command: `/100-sg-spec sober project memory and retrieval architecture`.

### Internal Documentation

- Target: Project Intelligence product and technical contracts.
- Source truth: update documentation only after the implementation contract is approved or delivered.
- Content move: document customer-visible behavior, generation-context selection, provenance, degraded retrieval, and legacy Mem0 status.
- Priority: should write.
- Next command: `/300-sg-docs project memory contracts after spec approval`.

### Public Content

- Target: declared Platform page plus FAQ support after verification.
- Source truth: the architectural concept is approved as direction, not yet a shipped public capability.
- Content move: explain the customer benefit without exposing vector-store administration or claiming autonomous learning.
- Claim constraints: no guaranteed quality, factuality, security, privacy, or automatic learning claims without proof.
- Priority: deferred until implementation verification.
- Next command after verification: `/200-sg-redact ContentGlows project context platform page`.

## Evidence Ledger

| Statement | Evidence | Classification | Publication posture |
| --- | --- | --- | --- |
| Mem0 is optional in the main backend runtime | Dependency audit discussion and current `lab/requirements-memory.txt` split | confirmed by workstream | Internal only unless separately verified for public use |
| Chroma remains transitive through CrewAI in the current lock | Dependency audit discussion and lockfile inspection | confirmed by workstream | Not a customer-facing claim |
| ContentGlows has project-scoped brand profiles | Brand profile API/store, app editor, and branding spec | confirmed by code and spec | Publish only within verified feature bounds |
| ContentGlows has Project Intelligence foundations | Product and technical docs plus service code | confirmed by repo | Avoid implying the complete memory-to-generation loop is shipped |
| Customers should not administer vector memory | Explicit operator decision in the transcript | confirmed product requirement | Safe as UX direction |
| Relational truth plus vector retrieval is the target architecture | Explicit conversation decision | confirmed direction, not implementation | Label as architecture direction until shipped |
| The approach will improve content quality | Desired outcome only | unproven | Do not publish as fact |
| ContentGlows learns automatically from every correction | Proposed behavior with undefined thresholds | unproven | Do not publish until specified and verified |

## Handoff Checklist

- Must route: architecture and product contract to `100-sg-spec`.
- Should route after approval: internal contracts to `300-sg-docs`.
- Optional after implementation: agent-page wording audit through `206-sg-audit-copy`.
- Deferred: Platform page and FAQ until end-to-end product verification exists.
- Chantier trace: not written; this repurpose run was not attached to exactly one active chantier.
