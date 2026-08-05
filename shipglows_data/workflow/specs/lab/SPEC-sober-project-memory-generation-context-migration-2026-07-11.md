---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: contentglows
created: "2026-07-11"
created_at: "2026-07-11 12:30:00 UTC"
updated: "2026-07-11"
updated_at: "2026-07-11 12:33:07 UTC"
status: ready
source_skill: 100-sg-spec
source_model: "gpt-5.5"
scope: migration
owner: Diane
confidence: high
user_story: "En tant que proprietaire authentifie d'un projet ContentGlows, je veux que les generations newsletter et psychologie utilisent un contexte projet fiable, borne, attribue et supprimable depuis Project Intelligence au lieu de Mem0/Chroma, afin que mes contenus restent coherents avec mon projet sans fuite tenant, dependance memoire fragile, ni apprentissage silencieux."
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - lab/memory/
  - lab/agents/newsletter/newsletter_crew.py
  - lab/agents/newsletter/tools/memory_tools.py
  - lab/api/routers/psychology.py
  - lab/api/models/project_intelligence.py
  - lab/api/services/project_intelligence_store.py
  - lab/api/services/project_intelligence_service.py
  - lab/api/services/project_intelligence_processor.py
  - lab/api/main.py
  - lab/requirements.txt
  - lab/requirements-memory.txt
  - lab/requirements.lock
  - lab/tests/test_newsletter_memory_scoping.py
  - lab/tests/test_psychology_auth_jobs.py
  - lab/tests/test_project_intelligence_store.py
  - lab/tests/test_project_intelligence_service.py
  - lab/tests/test_project_intelligence_router.py
  - lab/tests/test_dependency_policy.py
depends_on:
  - artifact: "shipglows_data/workflow/repurpose-packs/2026-07-11-contentglows-project-memory-repurpose-pack.md"
    artifact_version: "1.0.0"
    required_status: "draft"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-project-intelligence-engine-data-layer-2026-05-13.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/technical/platforms/crewai.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "skills/contentglows-turso-migrations/SKILL.md"
    artifact_version: "unknown"
    required_status: "active"
supersedes:
  - artifact: "lab/memory Mem0-backed project memory runtime"
    artifact_version: "unknown"
    required_status: "legacy"
evidence:
  - "The repurpose pack states relational ContentGlows project data is canonical, vector search is only a rebuildable retrieval index, and customers must not administer technical memory."
  - "lab/memory/memory_config.py configures Mem0 local mode with a Chroma vector_store provider under lab/data/mem0."
  - "lab/memory/memory_service.py wraps mem0 Memory/MemoryClient and exposes load_project_context, store_generation_scoped, and delete_all through a user_id:project_id scoped user string."
  - "lab/agents/newsletter/newsletter_crew.py loads brand voice, past newsletter, and content inventory memory before CrewAI tasks and stores generation records after completion."
  - "lab/agents/newsletter/tools/memory_tools.py exposes CrewAI tools that recall project context, past newsletters, and brand voice from Mem0 with global fallback when no scope is bound."
  - "lab/api/routers/psychology.py loads Mem0 project context during dispatch-pipeline generation and stores generation records after article/newsletter/short/social generation, swallowing failures as optional memory."
  - "lab/api/services/project_intelligence_store.py already creates Turso/libSQL ProjectIntelligenceSource, Document, Chunk, Fact, Recommendation, Duplicate, and Job tables with userId + projectId query scope."
  - "lab/api/services/project_intelligence_service.py already ingests uploads/connectors, rebuilds deterministic recommendations, and removes sources from default reads."
  - "lab/requirements-memory.txt still declares mem0ai>=0.1.0,<1.0, while lab/requirements.txt states chromadb remains transitive through crewai."
  - "lab/requirements.lock pins chromadb==1.1.1 via crewai==1.6.1; CrewAI replacement/removal is documented as a separate dependency chantier."
next_step: "/102-sg-start Sober Project Memory Generation Context Migration"
---

# Title

Sober Project Memory Generation Context Migration

## Status

Ready. This is an implementation-ready successor spec for the project-memory-to-generation slice. It builds on the ready Project Intelligence Engine data layer and replaces the Mem0/Chroma-backed memory runtime used by newsletter and psychology generation. It does not replace the existing Project Intelligence ingestion/dashboard contract, and it does not attempt to replace CrewAI.

This chantier is high risk because it touches private project data, tenant isolation, prompt construction, dependency hygiene, source deletion, and active generation routes. The implementation must not weaken generation behavior by silently dropping context. When context cannot be built, the route must return an explicit recoverable error or a documented degraded status that the caller can observe.

## User Story

En tant que proprietaire authentifie d'un projet ContentGlows, je veux que les generations newsletter et psychologie utilisent un contexte projet fiable, borne, attribue et supprimable depuis Project Intelligence au lieu de Mem0/Chroma, afin que mes contenus restent coherents avec mon projet sans fuite tenant, dependance memoire fragile, ni apprentissage silencieux.

Primary actor: authenticated ContentGlows user who owns the active project.

Trigger: the user launches newsletter generation or psychology dispatch-pipeline generation for an article, newsletter, short, or social post.

Observable result: generation receives a deterministic, bounded, project-scoped context package from the Project Intelligence domain; the run records which facts, chunks, sources, and policy decisions were used; removed or invalidated evidence never appears in future contexts; Mem0 code and package references are gone from the application memory path.

## Minimal Behavior Contract

When a project-owned generation route starts, ContentGlows builds a project-scoped generation context from canonical Project Intelligence relational data using `user_id + project_id` in every query, orders required facts and retrieved excerpts deterministically within a fixed context budget, injects that context into the newsletter or psychology generation prompt, and records redacted provenance for the run. If context data is sparse, the route still runs with an explicit empty-context provenance record; if the context builder, database, ownership, or invalidation checks fail, the route returns or records an observable error instead of silently falling back to Mem0, global memory, or no context. The easy edge case is deletion: any source-derived fact, chunk, duplicate, recommendation, or generation-context log link that traces to a removed source must be excluded from later contexts even when it appears indirectly through canonical duplicate evidence.

## Success Behavior

- Given an authenticated user and an owned active project, when newsletter generation starts with `user_id` and `project_id`, then `NewsletterCrew.generate_newsletter` receives a Project Intelligence generation context containing brand/audience/style facts, content inventory evidence, and past generation summaries when available.
- Given psychology dispatch-pipeline starts for article, newsletter, short, or social post, when `_run_pipeline_task` prepares CrewAI or pipeline inputs, then it requests the same generation-context builder before model execution and passes the resulting prompt block to the target generator without reading Mem0.
- Given Project Intelligence has facts and chunks for the project, when context is built, then required facts are selected first, retrieval excerpts are selected through a small internal interface, and ordering is deterministic by policy priority, confidence, recency, category, source id, document id, chunk order, and id.
- Given no Project Intelligence facts or chunks exist for the project, when generation starts, then the context builder returns an explicit empty context object with `degraded=false`, `items=[]`, and a provenance/log row explaining `empty_project_context`; generation may continue because there is no missing dependency, only no evidence.
- Given a Turso/libSQL read, query, or ownership failure occurs, when context is required for an active generation route, then the route fails or marks the background job failed with a sanitized error and no model call is made with a fabricated or untracked context.
- Given a source is deleted or invalidated through Project Intelligence, when a future generation context is built, then facts, chunks, duplicate links, recommendations, and retrieved excerpts derived from that source or its duplicate/canonical relationships are absent.
- Given generation completes, when the result is persisted, then the run writes a relational generation signal/log through Project Intelligence or status metadata with no raw private body logs and no autonomous model-written durable facts.
- Given dependency hygiene is checked, when tests and audit commands run, then `mem0ai` is absent from default and optional runtime requirements, Mem0 imports are absent from application code, and any remaining `chromadb` is reported honestly as a CrewAI transitive residual not used for project memory.

## Error Behavior

- Foreign, missing, archived, or deleted projects must fail through existing project ownership checks before context queries or generation.
- Every context-store query must include both `user_id` and `project_id`; a query scoped only by project, user, source, document, chunk, recommendation, or generation id is a readiness blocker.
- If the context builder cannot reach Turso/libSQL, active generation must not silently continue as if memory were optional. Background jobs must move to `failed` with a sanitized message such as `generation_context_unavailable`; synchronous routes must return a structured 409 or 503 according to existing router patterns.
- If the context budget is exceeded, the builder must trim optional retrieved excerpts before required facts and must record truncation counts in provenance. It must not exceed the configured budget by appending unbounded prompt text.
- If source-derived evidence is removed during or immediately before context construction, the builder must re-check removal state at read time and exclude stale rows. A log may record excluded counts, not raw bodies.
- If the future retrieval adapter is unavailable, this implementation must use the deterministic relational adapter. No external vector provider, local Chroma collection, Mem0 client, or provider-managed file search may be required for this chantier.
- If an LLM suggests a new durable fact from a generated body, the implementation must store it only as a candidate signal for later policy review or omit it. The model must never write canonical project facts silently.
- Error logs, Sentry breadcrumbs, job errors, and context provenance must never include OpenRouter keys, provider tokens, cookies, auth headers, raw uploaded/source bodies, generated full bodies, private email text, or unredacted project secrets.

## Problem

ContentGlows has two memory systems with conflicting responsibilities.

Project Intelligence is already a ContentGlows-owned Turso/libSQL domain with source, document, chunk, fact, recommendation, duplicate, job, source-removal, connector, and provider-readiness concepts. It is tenant-scoped by `userId + projectId` and is the right canonical home for durable project knowledge.

The active generation consumers still use `lab/memory`, which wraps Mem0 and local Chroma-backed storage. Newsletter generation loads brand voice, past newsletter, and content inventory from Mem0 and stores generation records back to Mem0. Psychology dispatch-pipeline loads Mem0 context and stores generation records after creating article, newsletter, short, or social content. Both consumers treat memory as optional and swallow failures, which was acceptable for a transitional feature flag but is no longer acceptable for a canonical project memory path.

This creates four risks:

- Canonical truth is split between Project Intelligence relational data and Mem0 vector memory.
- Active routes can silently lose context when Mem0 is absent, broken, or unscoped.
- Deletion/invalidation cannot be proven across Mem0/Chroma because the current source-of-truth and retrieval index are the same third-party memory layer.
- Dependency cleanup is ambiguous: `mem0ai` can be removed, but `chromadb` currently remains installed transitively through CrewAI and must not be misreported as project-memory usage.

## Solution

Create a Project Intelligence generation-context layer and migrate newsletter and psychology consumers to it. The relational Project Intelligence store remains canonical. Retrieval is hidden behind a small replaceable interface with a deterministic relational implementation in this chantier and a future vector adapter boundary that can be rebuilt from canonical rows. Each generation receives a bounded context package and each context package writes redacted provenance. Mem0 code, package references, optional requirements, seed scripts, and docs are removed or rewritten as legacy-deleted.

The implementation must preserve active functionality: brand voice/style, audience/project facts, content inventory, past generation deduplication signals, and relevant source snippets continue to be available to generation, but they come from Project Intelligence rows and deterministic store queries instead of Mem0.

## Scope In

- Add or extend Project Intelligence models for generation-context requests, items, budgets, provenance refs, context logs, and generation signals.
- Add additive/idempotent Turso/libSQL schema in the same change for generation context logs and generation signals.
- Add a small retrieval interface under Project Intelligence, with deterministic relational implementation now and a vector adapter boundary only as an interface.
- Add a generation-context builder that composes required facts, retrieved excerpts, past generation summaries, budget accounting, deterministic ordering, and redacted provenance.
- Replace newsletter direct `get_memory_service`, `load_project_context`, `load_context`, and `store_generation_scoped/store_generation` usage with the new builder and relational generation signal writer.
- Replace newsletter CrewAI memory tools with Project Intelligence context tools or remove tool exposure if the crew receives sufficient prompt context; no tool may call Mem0.
- Replace psychology dispatch-pipeline Mem0 load/store blocks with the new builder and relational generation signal writer for article, newsletter, short, and social routes.
- Preserve behavior for active generation routes: no silent context loss, no global memory fallback, and no model call with untracked context when required context reads fail.
- Extend source deletion/invalidation so removed source-derived evidence cannot appear in future generation contexts, including second-order duplicate/canonical relationships.
- Remove `lab/memory/**` source code and seed scripts from runtime, or leave only a non-imported deletion note if implementation needs a short migration marker.
- Remove `mem0ai` from optional/runtime package files and dependency docs; delete `lab/requirements-memory.txt` unless a non-runtime archived note is explicitly kept outside install paths.
- Update tests and dependency policy to prove Mem0 imports/package declarations are absent and chromadb status is reported as a CrewAI transitive residual only.
- Update internal docs that currently describe Mem0/Chroma project memory so they describe Project Intelligence generation context and dependency status.

## Scope Out

- Replacing CrewAI, removing CrewAI, or removing `chromadb` when it is installed only as a transitive dependency of CrewAI.
- Adding an external vector provider, local Chroma replacement, provider-managed file-search dependency, or embeddings dependency in this implementation.
- Migrating historical Mem0/Chroma data into Project Intelligence. Existing canonical Project Intelligence rows, connector sync, status/content records, brand profiles, and user/project data are the sources for context.
- Public marketing claims that ContentGlows "learns automatically", improves quality, guarantees factual accuracy, or provides autonomous long-term memory.
- Customer-facing memory administration UI for embeddings, vector stores, collections, or retrieval providers.
- Changing the user OpenRouter/BYOK model for CrewAI routes.
- Rewriting non-newsletter/non-psychology agents that merely import CrewAI but do not currently use Mem0 project memory.
- Full Project Intelligence dashboard redesign.

## Constraints

- Relational Project Intelligence data is canonical. Retrieval indexes are derived, rebuildable, and never the authority for truth, permissions, deletion, or retention.
- All context and log queries must include `user_id + project_id` at every store boundary.
- Context budget must be explicit, testable, and enforced before prompt injection. Default budget for this chantier: 6,000 estimated tokens, with sub-budgets of 2,000 for required facts/rules, 2,500 for retrieved excerpts, 1,000 for past generation summaries, and 500 reserved for labels/provenance headings.
- Deterministic ordering is required. The same database state and request parameters must produce the same ordered context item ids.
- Provenance is required for every included item: item type, source id when source-derived, document id, chunk id, fact id, generation signal id, category, score/rank, selected reason, and source version/removal state when available.
- No raw secret/private body logs. Context logs may store ids, categories, hashes, lengths, token estimates, selected reasons, exclusion reasons, and bounded snippets only when snippets already come from Project Intelligence evidence snippets. They must not store full source text or full generated output.
- No silent model writes. Generated output can create a generation signal and optional candidate learnings, but cannot directly create canonical facts, brand rules, audience truth, or source documents without explicit product policy.
- Source deletion/invalidation must exclude source-derived evidence from future contexts, including facts/chunks/documents, duplicate links where removed documents are either duplicate or canonical, recommendations/evidence JSON, and generation signals whose provenance references removed evidence.
- Additive/idempotent Turso schema must ship in the same implementation change, following ContentGlows Turso/libSQL guardrails: `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, and startup ensure before route use.
- Existing active route functionality must not be weakened. Removing Mem0 is acceptable only after replacement context behavior and tests are present.
- `chromadb` may remain installed transitively through CrewAI. The acceptance proof must say whether it remains in the lock and confirm it is not imported or used by project memory.
- Fresh external docs verdict: `fresh-docs not needed` for the implementation architecture because this chantier deliberately avoids new external vector/provider APIs and relies on local FastAPI/Turso/libSQL patterns already present in the repository. CrewAI replacement would require a separate documentation freshness gate.
- Observability: preserve existing Sentry initialization and safe diagnostics posture. New logs must be sanitized and should include route, user/project scope ids only when safe, generation id/content record id, context log id, selected count, excluded count, and error code.

## Test Contract

Test-first proof is mandatory. Before implementation beyond interfaces/models, add failing tests for the context builder/store and the newsletter/psychology consumers.

Required automated proof:

- `pytest lab/tests/test_project_generation_context_store.py` for schema ensure, tenant isolation, deterministic list/query ordering, source deletion/invalidation exclusion, and provenance log redaction.
- `pytest lab/tests/test_project_generation_context_builder.py` for context budget enforcement, required-facts-first selection, deterministic relational retrieval, empty-context behavior, unavailable-store error behavior, and no raw body in logs.
- `pytest lab/tests/test_newsletter_generation_context.py` or migrated `lab/tests/test_newsletter_memory_scoping.py` for newsletter using Project Intelligence scope and never falling back to global memory.
- `pytest lab/tests/test_psychology_generation_context.py` or extended `lab/tests/test_psychology_auth_jobs.py` for dispatch-pipeline loading context before model execution, failing observably on context-store errors, and writing generation signals without Mem0.
- `pytest lab/tests/test_dependency_policy.py` extended to prove no direct `mem0`, `mem0ai`, or `memory.memory_service` imports remain in application runtime code and no installable requirements file declares `mem0ai`.
- Existing regression suite subset: `pytest lab/tests/test_project_intelligence_store.py lab/tests/test_project_intelligence_service.py lab/tests/test_project_intelligence_router.py lab/tests/test_newsletter_router.py lab/tests/test_psychology_auth_jobs.py lab/tests/test_dependency_policy.py`.

Manual/runtime proof after automated tests:

- Start the API with Turso env configured or in-memory test client where supported and verify Project Intelligence table ensure includes the new generation-context tables.
- Run a local newsletter generation test with fake LLM/CrewAI stubs where provider calls are mocked and assert context provenance id is present in result metadata or logs.
- Run a psychology dispatch-pipeline test with fake provider/CrewAI stubs and assert no Mem0 import is attempted.
- Run dependency audit commands and record honest status: `mem0ai` absent; `chromadb` may remain via CrewAI only; no project-memory code imports Chroma.

Exception-with-proof:

- No live provider smoke is required for this spec because the change is context assembly and storage. Provider execution can be mocked as long as route preflight behavior remains covered.

## Dependencies

Local code dependencies:

- `lab/api/services/project_intelligence_store.py` for canonical Turso/libSQL tables, tenant-scoped source/document/chunk/fact/recommendation/duplicate access, and source removal.
- `lab/api/services/project_intelligence_service.py` for Project Intelligence orchestration, source removal, connector sync, and future generation-context service entrypoint.
- `lab/api/services/project_intelligence_processor.py` for deterministic parsing/chunking/recommendation patterns and constants style.
- `lab/api/models/project_intelligence.py` for Pydantic alias conventions.
- `lab/api/main.py` for startup ensure.
- `lab/agents/newsletter/newsletter_crew.py` and `lab/api/routers/psychology.py` for active generation consumers.
- `status` content records for generation result metadata and existing dedup/status lifecycle.
- `api.services.user_llm_service` and `api.services.ai_runtime_service` for request-scoped LLM/provider behavior; this spec must not bypass them.

Package/dependency dependencies:

- Keep `libsql` and existing Turso client usage; no new database engine.
- Keep `crewai` for existing agent orchestration in this chantier.
- Remove `mem0ai` from installable project requirements and docs.
- Do not add `chromadb`, vector DBs, embedding providers, or file-search SDKs for this implementation.
- Report lockfile reality honestly: current evidence shows `chromadb==1.1.1` is transitive through `crewai==1.6.1`; full CrewAI replacement/removal is a separate dependency chantier.

Documentation freshness:

- `fresh-docs not needed` for the new retrieval implementation because it is deterministic and relational.
- CrewAI docs freshness is not required unless implementation changes CrewAI API usage beyond passing prompt/context strings.
- Turso/libSQL behavior is governed by local project patterns and the `contentglows-turso-migrations` guardrail.

## Invariants

- No generation context row, item, or signal can be read or written without `user_id + project_id`.
- No generation context can include rows where the source, document, chunk, fact, recommendation, duplicate, or generation signal is removed, invalidated, superseded, or traces to removed source-derived evidence.
- Required project facts/rules outrank retrieved excerpts. Retrieval can influence relevance; it cannot decide truth.
- Future vector retrieval must be reconstructible from canonical Project Intelligence rows and must be replaceable behind the adapter without changing newsletter or psychology consumers.
- The context builder must be deterministic for identical inputs and database state.
- The context builder must return a structured context object, not only a prompt string, so tests can inspect items, budget, provenance, exclusions, and log ids.
- Empty context is a valid explicit state. Unavailable context store is an error state.
- Context provenance logs are redacted by design and cannot store raw uploaded bodies, raw email bodies, full generated bodies, tokens, cookies, auth headers, provider keys, or private request payloads.
- The model cannot write canonical project knowledge directly. Durable canonical writes require application policy outside the generation route.
- Removing Mem0 must not remove project-specific memory behavior from newsletter and psychology generation.

## Links & Consequences

- Data: new Turso/libSQL tables or columns are required for generation context logs and generation signals.
- Auth/tenant: every affected route already has authenticated user context; implementation must keep ownership checks before context building.
- Privacy: source snippets and generated output are private business data; provenance must use ids/counts/hashes and bounded snippets only.
- Prompting: newsletter and psychology prompt templates will change because context comes from a structured builder rather than Mem0 formatted history.
- Dependency hygiene: Mem0 package/code removal lowers supply-chain and operational risk, but CrewAI still carries a Chroma transitive dependency until a separate CrewAI dependency chantier removes it.
- Operations: if context DB is unavailable, generation should fail early and visibly instead of producing less-informed content without operator knowledge.
- Sentry/logging: new errors should be captured through existing observability, but logs must be redacted and not include raw context bodies.
- Future retrieval: the adapter boundary allows later vector work without changing canonical truth or consumers.
- Documentation: internal docs must stop describing project memory as Mem0/Chroma and describe Project Intelligence generation context instead.

## Documentation Coherence

- Update `lab/README.md` to remove Mem0 optional memory setup and describe Project Intelligence generation context, table ensure, and dependency status.
- Update or remove any docs under `shipglows_data/technical/**`, `shipglows_data/workflow/research/**`, and conversation-derived docs that still instruct maintainers to seed or enable Mem0 for project memory.
- Update `shipglows_data/technical/platforms/crewai.md` only if implementation changes CrewAI usage notes; otherwise leave CrewAI replacement as a separate chantier and do not claim chromadb removed.
- Update dependency comments in `lab/requirements.txt`, `lab/requirements-memory.txt`, and lockfile generation notes so install paths no longer advertise Mem0 project memory.
- Do not publish customer-facing claims until `/103-sg-verify` proves end-to-end generation context behavior.
- Changelog/task tracker updates belong to later lifecycle closure, not this spec creation run.

## Edge Cases

- Newsletter generation called without `project_id`: must not fall back to global Mem0 memory. It must either build a user-only empty context explicitly if the route contract permits no project, or fail with a structured missing-project error for project-scoped generation.
- Psychology dispatch-pipeline called with a stale project id after the project was archived or deleted.
- Project has facts but no chunks; required facts should still be injected.
- Project has chunks but no high-confidence facts; retrieved excerpts can be included but must be labeled as evidence, not truth.
- Multiple facts have identical priority/confidence; ordering must remain stable by category, updated timestamp, source id, document id, chunk id, and fact id.
- Context budget is smaller than required facts; builder must include highest-priority required facts, record truncation, and reject configurations that leave no room for required safety headings.
- A source is removed after facts were selected but before context log write; builder must re-check or write atomically enough to avoid logging stale included evidence as usable.
- Duplicate evidence where removed source is the canonical document and active source is the duplicate, or vice versa.
- Recommendations whose JSON evidence references removed source/document/chunk/fact ids.
- Generation signal references a removed source-derived context item; future contexts must exclude or mark that signal invalid for retrieval.
- Dependency audit finds `chromadb` still present; this is acceptable only if direct project-memory imports/usages are absent and the report names CrewAI as the transitive source.
- Tests import deleted `lab/memory` helpers; tests must be migrated rather than keeping compatibility shims that reintroduce Mem0.

## Implementation Tasks

- [ ] Task 1: Add failing generation-context model tests first
  - File: `lab/tests/test_project_generation_context_builder.py`
  - Action: Create tests for required-facts-first selection, deterministic item ordering, budget truncation, empty-context state, unavailable-store error, and redacted provenance fields.
  - User story link: Proves the replacement context behavior before removing Mem0.
  - Depends on: None.
  - Validate with: `pytest lab/tests/test_project_generation_context_builder.py`.
  - Notes: Use in-memory libSQL store or fake store fixtures; no external vector/provider dependency.

- [ ] Task 2: Add failing generation-context store tests first
  - File: `lab/tests/test_project_generation_context_store.py`
  - Action: Create tests for `ensure_tables`, tenant isolation by `user_id + project_id`, context log writes, generation signal writes, source invalidation exclusions, duplicate/canonical removal exclusions, and no raw body persistence.
  - User story link: Proves relational Project Intelligence is canonical and deletion-safe.
  - Depends on: None.
  - Validate with: `pytest lab/tests/test_project_generation_context_store.py`.
  - Notes: Include cross-user and cross-project rows with same ids where possible to prove every query scopes both fields.

- [ ] Task 3: Extend Project Intelligence Pydantic contracts
  - File: `lab/api/models/project_intelligence.py`
  - Action: Add `ProjectGenerationContextRequest`, `ProjectGenerationContextItem`, `ProjectGenerationContextProvenanceRef`, `ProjectGenerationContextBudget`, `ProjectGenerationContextResult`, `ProjectGenerationContextLog`, and `ProjectGenerationSignal` models using existing camelCase alias conventions.
  - User story link: Defines the inspectable context package and provenance contract.
  - Depends on: Tasks 1 and 2.
  - Validate with: `pytest lab/tests/test_project_intelligence_models.py lab/tests/test_project_generation_context_builder.py`.
  - Notes: Include item types such as `fact`, `source_excerpt`, `past_generation`, `recommendation`, and `empty_notice`.

- [ ] Task 4: Add additive Turso/libSQL generation-context schema
  - File: `lab/api/services/project_intelligence_store.py`
  - Action: Extend `ensure_tables` with `ProjectGenerationContextLog` and `ProjectGenerationSignal` tables plus indexes for `userId, projectId, generationType, contentRecordId, sourceId, removedAt, createdAt`.
  - User story link: Makes context provenance and past generation signals durable and queryable.
  - Depends on: Task 2.
  - Validate with: `pytest lab/tests/test_project_generation_context_store.py lab/tests/test_project_intelligence_store.py`.
  - Notes: Use `CREATE TABLE IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS`; do not mutate existing tables unless adding nullable columns is unavoidable and idempotent.

- [ ] Task 5: Add tenant-scoped context store methods
  - File: `lab/api/services/project_intelligence_store.py`
  - Action: Add methods to list context-eligible facts/chunks/recommendations/signals, write context logs, write generation signals, mark signals invalidated by source removal, and query removal-safe provenance.
  - User story link: Gives the builder a safe data boundary.
  - Depends on: Task 4.
  - Validate with: `pytest lab/tests/test_project_generation_context_store.py`.
  - Notes: All SQL must include `userId = ? AND projectId = ?`; joins to source/document/chunk tables must exclude removed rows.

- [ ] Task 6: Harden source removal for context provenance
  - File: `lab/api/services/project_intelligence_store.py`
  - Action: Extend `mark_source_removed` to invalidate generation signals and exclude context logs/items whose provenance references the removed source, documents, chunks, facts, duplicate document ids, or canonical document ids.
  - User story link: Ensures deletion/invalidation affects future generation contexts.
  - Depends on: Task 5.
  - Validate with: `pytest lab/tests/test_project_generation_context_store.py lab/tests/test_project_intelligence_store.py`.
  - Notes: Logs may remain as historical audit records, but future context reads must ignore invalidated evidence.

- [ ] Task 7: Implement retrieval adapter boundary
  - File: `lab/api/services/project_generation_context.py`
  - Action: Create a small interface with methods equivalent to `retrieve(query, user_id, project_id, filters, limit, budget)` and `explain()` plus a `RelationalProjectContextRetriever` implementation backed by Project Intelligence store queries.
  - User story link: Keeps retrieval replaceable without making vectors canonical.
  - Depends on: Tasks 3 and 5.
  - Validate with: `pytest lab/tests/test_project_generation_context_builder.py`.
  - Notes: The interface must not mention Chroma, Mem0, embeddings, file search, or any provider SDK. Future vector adapter can implement the same interface.

- [ ] Task 8: Implement generation-context builder
  - File: `lab/api/services/project_generation_context.py`
  - Action: Build structured context from required facts/rules, retrieved excerpts, past generation signals, budget accounting, deterministic ordering, provenance refs, exclusion reasons, and prompt rendering.
  - User story link: Supplies newsletter and psychology with reliable project context.
  - Depends on: Task 7.
  - Validate with: `pytest lab/tests/test_project_generation_context_builder.py`.
  - Notes: Return both structured data and a prompt block. Estimated tokens can use a deterministic local approximation such as `ceil(chars / 4)` with tests around budget behavior.

- [ ] Task 9: Add service entrypoints for consumers
  - File: `lab/api/services/project_intelligence_service.py`
  - Action: Add `build_generation_context(...)` and `record_generation_signal(...)` methods that delegate to the new builder/store and preserve sanitized error envelopes.
  - User story link: Gives active routes one stable Project Intelligence API.
  - Depends on: Task 8.
  - Validate with: `pytest lab/tests/test_project_intelligence_service.py lab/tests/test_project_generation_context_builder.py`.
  - Notes: Parameters should include generation type, route id, content type, topic/title/query, content record id when known, max budget, and caller metadata.

- [ ] Task 10: Register startup ensure for new tables
  - File: `lab/api/main.py`
  - Action: Ensure existing Project Intelligence startup path creates the new tables before routes use the context builder.
  - User story link: Avoids runtime missing-table failures.
  - Depends on: Task 4.
  - Validate with: `pytest lab/tests/test_bootstrap_routes.py lab/tests/test_project_generation_context_store.py`.
  - Notes: Follow current startup style, but errors that would break active generation must surface in route tests.

- [ ] Task 11: Migrate newsletter crew context reads/writes
  - File: `lab/agents/newsletter/newsletter_crew.py`
  - Action: Replace Mem0 imports and `MEMORY_AVAILABLE` flow with Project Intelligence generation-context calls for brand voice, past newsletters, and content inventory; write generation signals after successful generation.
  - User story link: Preserves newsletter coherence without Mem0.
  - Depends on: Task 9.
  - Validate with: `pytest lab/tests/test_newsletter_generation_context.py lab/tests/test_newsletter_router.py`.
  - Notes: Do not swallow context-store failures as non-critical. Empty context is acceptable only when builder returns explicit empty state.

- [ ] Task 12: Replace or remove newsletter memory tools
  - File: `lab/agents/newsletter/tools/memory_tools.py`
  - Action: Either replace tools with Project Intelligence context tools using bound `user_id + project_id`, or remove them from agent tool lists if all needed context is injected by `newsletter_crew.py`.
  - User story link: Prevents CrewAI tool calls from reintroducing Mem0/global memory.
  - Depends on: Task 11.
  - Validate with: `pytest lab/tests/test_newsletter_generation_context.py`.
  - Notes: No global fallback is allowed. If tools remain, calling them without project scope must return a structured missing-scope message.

- [ ] Task 13: Migrate psychology dispatch-pipeline context reads
  - File: `lab/api/routers/psychology.py`
  - Action: Replace the Mem0 `get_memory_service().load_project_context(...)` block with Project Intelligence `build_generation_context(...)` before article/newsletter/short/social generation.
  - User story link: Keeps psychology-generated content grounded in project context.
  - Depends on: Task 9.
  - Validate with: `pytest lab/tests/test_psychology_generation_context.py lab/tests/test_psychology_auth_jobs.py`.
  - Notes: If context builder fails, do not call the model. Mark the job/content record failed with sanitized error.

- [ ] Task 14: Migrate psychology generation writes
  - File: `lab/api/routers/psychology.py`
  - Action: Replace the post-generation Mem0 `store_generation_scoped(...)` block with `record_generation_signal(...)` that stores metadata, hashes, topics, content type, content record id, source idea ids, and context log id without raw full body.
  - User story link: Preserves past-generation dedupe signals relationally.
  - Depends on: Task 13.
  - Validate with: `pytest lab/tests/test_psychology_generation_context.py`.
  - Notes: Store bounded summaries/hashes, not full generated body. The canonical generated body remains in status/content storage.

- [ ] Task 15: Remove Mem0 runtime code
  - File: `lab/memory/__init__.py`
  - Action: Delete `lab/memory/**` runtime modules and seed scripts, or replace the package with a non-importable migration note outside Python import paths if deletion is not possible in the implementation tool.
  - User story link: Removes the old memory provider from runtime.
  - Depends on: Tasks 11 through 14.
  - Validate with: `rg -n "from memory|import memory|get_memory_service|mem0|Mem0|MemoryService" lab --glob "*.py"` returns no runtime usage except migration notes/tests explicitly asserting absence.
  - Notes: Do not keep compatibility wrappers that call Project Intelligence under the old `memory` module name; that would preserve the wrong architecture.

- [ ] Task 16: Remove Mem0 package/docs install path
  - File: `lab/requirements-memory.txt`
  - Action: Delete the file or replace it with a non-install instruction that is not referenced by runtime/dev installs; remove `mem0ai` declarations from all installable requirement files.
  - User story link: Completes dependency migration away from Mem0.
  - Depends on: Task 15.
  - Validate with: `rg -n "mem0ai|mem0|Mem0" lab/requirements*.txt lab/README.md shipglows_data docs --glob "*.md"`.
  - Notes: If docs retain historical mentions, they must say legacy removed and not instruct installation.

- [ ] Task 17: Add dependency policy assertions
  - File: `lab/tests/test_dependency_policy.py`
  - Action: Add AST/import and requirements tests proving Mem0 imports and `mem0ai` requirement declarations are absent, while allowing `chromadb` only as a CrewAI transitive lockfile residual.
  - User story link: Prevents regression to Mem0/Chroma-backed project memory.
  - Depends on: Tasks 15 and 16.
  - Validate with: `pytest lab/tests/test_dependency_policy.py`.
  - Notes: The test should fail if project memory imports `chromadb` directly. It may report lockfile chromadb with CrewAI provenance.

- [ ] Task 18: Update internal docs coherently
  - File: `lab/README.md`
  - Action: Replace Mem0 optional memory setup with Project Intelligence generation-context setup, table ensure, dependency audit commands, and chromadb transitive status.
  - User story link: Maintainers get the correct operating model.
  - Depends on: Tasks 11 through 17.
  - Validate with: `rg -n "Mem0|mem0ai|Chroma|chromadb|Project Intelligence generation context" lab/README.md shipglows_data/technical shipglows_data/workflow/research`.
  - Notes: Public claims remain out of scope until verified.

- [ ] Task 19: Run focused migration proof
  - File: `lab/tests/test_project_generation_context_builder.py`
  - Action: Run the full focused test set and repair failures without reintroducing Mem0.
  - User story link: Proves the migration preserves active generation behavior.
  - Depends on: Tasks 1 through 18.
  - Validate with: `pytest lab/tests/test_project_generation_context_builder.py lab/tests/test_project_generation_context_store.py lab/tests/test_project_intelligence_store.py lab/tests/test_project_intelligence_service.py lab/tests/test_project_intelligence_router.py lab/tests/test_newsletter_generation_context.py lab/tests/test_psychology_generation_context.py lab/tests/test_dependency_policy.py`.
  - Notes: If provider-dependent tests are unavailable, mock provider/CrewAI calls and record the exception-with-proof.

- [ ] Task 20: Run dependency audit proof and report residual chromadb honestly
  - File: `lab/requirements.lock`
  - Action: Verify `mem0ai` is absent from installable requirements/lock and document whether `chromadb` remains solely via CrewAI.
  - User story link: Completes the package migration without false claims.
  - Depends on: Task 17.
  - Validate with: `rg -n "mem0ai|chromadb|crewai==" lab/requirements*.txt lab/requirements.lock` and `python3 -m pip_audit -r lab/requirements.lock --no-deps --disable-pip` when pip-audit is available.
  - Notes: If `chromadb` remains, acceptance is still possible only with a report stating it is transitive through CrewAI and unused by project memory. Full CrewAI/chromadb removal routes to a separate dependency chantier.

## Acceptance Criteria

- [ ] AC 1: Given Project Intelligence contains facts/chunks/signals for `user-1/project-1` and unrelated rows for `user-2/project-1` plus `user-1/project-2`, when generation context is built for `user-1/project-1`, then only `user-1/project-1` items can appear in the context and provenance log.
- [ ] AC 2: Given the same database state and request parameters, when context is built twice, then selected item ids, ordering, token estimates, and prompt text are identical except for the new context log id/timestamps.
- [ ] AC 3: Given required facts and optional retrieved excerpts exceed the budget, when context is built, then required facts are retained first, optional excerpts are trimmed deterministically, and truncation is recorded in provenance.
- [ ] AC 4: Given no eligible Project Intelligence rows exist, when newsletter generation starts, then it receives an explicit empty Project Intelligence context and generation continues without Mem0/global fallback.
- [ ] AC 5: Given Turso/libSQL context reads fail, when newsletter or psychology generation starts, then no model call is made and the route/job reports a sanitized observable context error.
- [ ] AC 6: Given a source is removed, when context is built afterward, then no fact, chunk, duplicate, recommendation, retrieved excerpt, or generation signal derived from that source appears.
- [ ] AC 7: Given removed evidence appears indirectly as duplicate/canonical document evidence, when context is built, then that duplicate relationship is excluded from retrieval and provenance.
- [ ] AC 8: Given newsletter generation completes, when Project Intelligence is queried, then a generation signal exists with content type, title/topic metadata, hashes or bounded summary, context log id, and no full generated body.
- [ ] AC 9: Given psychology dispatch-pipeline completes for article/newsletter/short/social, when Project Intelligence is queried, then a generation signal exists and references the generation context log without raw body persistence.
- [ ] AC 10: Given code search runs after implementation, when scanning runtime Python files, then there are no `mem0`, `mem0ai`, `get_memory_service`, or `memory.memory_service` imports/usages.
- [ ] AC 11: Given dependency scan runs after implementation, when checking installable requirements, then `mem0ai` is absent.
- [ ] AC 12: Given lockfile scan still finds `chromadb`, when dependency policy tests run, then the result is accepted only if `chromadb` is transitive through CrewAI and no project-memory code imports or configures it.
- [ ] AC 13: Given future vector retrieval is desired, when reviewing this implementation, then only the small retrieval adapter needs replacement; canonical data, deletion policy, and consumers remain unchanged.
- [ ] AC 14: Given Sentry/logs/job errors capture a context failure, when reviewing output, then no secrets, auth headers, raw source bodies, raw email bodies, or full generated bodies are present.
- [ ] AC 15: Given a fresh agent reads this spec, when implementing tasks in order, then no product, tenant, deletion, dependency, or provider decision is missing.

## Test Strategy

1. Write failing tests first for builder/store/contracts before deleting Mem0 code.
2. Implement Project Intelligence schema/store additions and make store tests pass with in-memory libSQL.
3. Implement deterministic relational retrieval and context builder; make budget/order/provenance tests pass.
4. Migrate newsletter and psychology consumers with mocked providers/CrewAI; prove context is built before model execution and generation signals are recorded after success.
5. Remove Mem0 code and package declarations; run dependency policy and code-search tests.
6. Run the focused regression subset listed in the Test Contract.
7. Run metadata/docs coherence checks for updated docs in the implementation phase.
8. Run dependency audit proof and document `mem0ai` absence plus honest `chromadb` transitive status.

## Risks

- Silent degradation risk: existing code swallows memory failures. Mitigation: tests must prove active generation fails observably on context-store failures and continues only on explicit empty context.
- Tenant isolation risk: Project Intelligence has many row types. Mitigation: every store method/test must include cross-user and cross-project fixtures.
- Deletion risk: evidence can be linked through duplicate/canonical rows and JSON provenance. Mitigation: explicit invalidation tests cover first-order and second-order source-derived evidence.
- Prompt bloat risk: replacing vector search with relational retrieval can over-inject. Mitigation: strict budgets, deterministic ranking, and truncation provenance.
- Dependency-reporting risk: chromadb may still appear after Mem0 removal. Mitigation: acceptance distinguishes direct project-memory usage from CrewAI transitive residual and routes full CrewAI removal separately.
- Data retention risk: generation logs could become a second private-content store. Mitigation: log ids, hashes, lengths, bounded summaries, and provenance only; never raw bodies.
- Migration sequencing risk: deleting Mem0 before consumers are migrated would weaken generation. Mitigation: test-first and tasks require replacement paths before removal.

## Execution Notes

- Read first during implementation: `lab/api/services/project_intelligence_store.py`, `lab/api/services/project_intelligence_service.py`, `lab/agents/newsletter/newsletter_crew.py`, `lab/api/routers/psychology.py`, and `lab/tests/test_project_intelligence_store.py`.
- Use the existing Project Intelligence data layer and conventions rather than creating a parallel memory domain.
- Add schema in the same PR as code that reads/writes it, using additive/idempotent Turso/libSQL statements.
- Keep retrieval implementation deterministic and relational. Do not add a vector provider, Chroma replacement, embedding model, or provider file-search SDK in this chantier.
- Do not keep `lab/memory` as a compatibility facade. Consumers should call Project Intelligence services by name so future agents understand the architecture.
- Do not ask the operator to provide dependency status; run code search and dependency audit locally in the implementation phase.
- Stop and reroute if implementation discovers another active Mem0 consumer outside newsletter/psychology that would lose functionality, or if removing `lab/memory` would break a shipped route not covered by this spec.
- Stop and create a separate dependency chantier if the goal changes to removing CrewAI or fully eliminating transitive `chromadb`.

## Open Questions

None blocking. The user explicitly chose relational Project Intelligence as canonical, no external vector provider in this implementation, future vector adapter boundary only, deletion/invalidation support, no silent degradation, and CrewAI replacement/removal as a separate dependency chantier.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-11 12:30:00 UTC | 100-sg-spec | gpt-5.5 | Created successor spec for migrating project memory from Mem0/Chroma-backed runtime to Project Intelligence generation context. | draft | /101-sg-ready sober project memory generation context migration |
| 2026-07-11 12:33:07 UTC | 101-sg-ready | gpt-5.5 high | Strict readiness review against user-story fit, tenant isolation, deletion/invalidation, context failure behavior, retention/logging, Turso schema safety, dependency honesty, task order, acceptance criteria, and proof contract. | ready | /102-sg-start Sober Project Memory Generation Context Migration |
| 2026-07-11 13:02:35 UTC | 102-sg-start | gpt-5.5 high | Implemented Project Intelligence generation context schema, builder, newsletter and psychology consumer migration, Mem0 runtime removal, docs/dependency policy updates, and focused local proof. | implemented | /103-sg-verify Sober Project Memory Generation Context Migration |
| 2026-07-11 15:00:00 UTC | 103-sg-verify | direct execution | Re-ran focused migration/regression proof, scheduler test, full-suite collection, compile/hygiene checks, runtime Mem0 scan, dependency/lock audit, and imports. The scheduler test passes from repository root; migration scope is proven. Full suite reaches execution but retains unrelated blueprint/timeline failures outside this chantier. | verified | /104-sg-end Sober Project Memory Generation Context Migration |
| 2026-07-11 15:12:00 UTC | 104-sg-end | gpt-5.5 | Closed chantier bookkeeping after verified migration, documented residual unrelated full-suite failures, and prepared changelog framing without claiming a clean global suite or ship status. | closed | /005-sg-ship Sober Project Memory Generation Context Migration |
| 2026-07-11 18:55:00 UTC | 005-sg-ship | gpt-5.5 | Shipped the verified memory migration already present on main together with the worker dependency/toolchain hardening; push completed as commit `2834b3d`. | shipped | /405-sg-prod if hosted proof is required |

## Current Chantier Flow

100-sg-spec: done
101-sg-ready: ready
102-sg-start: implemented
103-sg-verify: verified
104-sg-end: closed
005-sg-ship: shipped

Next command: `/405-sg-prod` if hosted proof is required
