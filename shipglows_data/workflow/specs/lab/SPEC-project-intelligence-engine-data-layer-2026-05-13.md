---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: lab
created: "2026-05-13"
created_at: "2026-05-13 07:41:19 UTC"
updated: "2026-05-14"
updated_at: "2026-05-14 22:24:12 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: Diane
confidence: high
user_story: "En tant que propriétaire d'un projet ContentGlowz, je veux importer ou connecter mes données projet et obtenir une mémoire projet nettoyée, dédupliquée et exploitable, afin de prendre des décisions de contenu, SEO et croissance avec des preuves et un niveau de confiance."
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - lab/api/routers/projects.py
  - lab/api/routers/personas.py
  - lab/api/routers/search_console.py
  - lab/api/routers/idea_pool.py
  - lab/api/services/ai_runtime_service.py
  - lab/api/services/repo_understanding_service.py
  - lab/api/services/search_console_store.py
  - lab/status/service.py
  - app/lib/data/services/api_service.dart
  - app/lib/providers/providers.dart
depends_on:
  - artifact: "shipglows_data/workflow/explorations/2026-05-12-project-intelligence-engine.md"
    artifact_version: "1.0.0"
    required_status: "unknown"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-google-search-console-intelligence.md"
    artifact_version: "0.1.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-backend-persona-autofill-repo-understanding-user-keys.md"
    artifact_version: "1.0.0"
    required_status: "ready"
supersedes: []
evidence:
  - "shipglows_data/workflow/explorations/2026-05-12-project-intelligence-engine.md concludes that ContentGlowz has feature-specific intelligence bricks but no canonical project brain."
  - "lab/api/services/ai_runtime_service.py centralizes BYOK/platform provider resolution for openrouter, exa, and firecrawl."
  - "lab/api/services/repo_understanding_service.py already collects repo/site evidence and synthesizes persona-ready understanding."
  - "lab/api/routers/search_console.py and api/services/search_console_store.py already store project-scoped SEO snapshots and opportunities."
  - "lab/api/routers/idea_pool.py and lab/agents/sources/ingest.py already ingest newsletter, SEO, competitor, social, and Search Console ideas."
  - "lab/status/service.py bulk_create_ideas currently has no user_id parameter although authenticated routers pass user_id, so bulk ingestion ownership must be fixed before reuse."
  - "OpenAI official docs describe vector stores/file search and model optimization/fine-tuning as separate workflows; current model optimization docs also reinforce that fine-tuning is not the default path for arbitrary uploads."
  - "Google Gemini official docs state Gemini Files API uploads are temporary and Gemini API fine-tuning has no current supported model after Gemini 1.5 Flash-001 deprecation, with Vertex AI as the tuning path."
  - "sf-verify 2026-05-14 found the V1 implementation present with backend tests and Flutter analyze passing, but partial because source removal did not exclude duplicate-derived recommendation evidence, active job enforcement was not atomic, connector caps were not globally proven, 10 MB file validation read full payloads first, and Flutter lacked job/document/dedupe/file-upload proof."
next_step: "/sf-start Project Intelligence Engine Data Layer fix verification gaps"
---

# Title

Project Intelligence Engine Data Layer

## Status

Ready. This spec formalizes the product idea into an implementation-ready V1 chantier. It intentionally separates the reliable V1 promise from the aspirational provider claim: ContentGlowz should first build a project-owned intelligence layer that cleans, formats, deduplicates, scores, and cites evidence. Direct fine-tuning or deployment to OpenAI, Gemini, or open-source runtimes is a later provider-adapter layer and must not be marketed as universally possible "in minutes" until each provider path has a tested contract.

Revision 0.1.1 is a post-verify hardening pass. The first implementation delivered the main backend and Flutter surface with green checks, but the next `sf-start` must close the verification gaps before ship: atomic active-job enforcement, removed duplicate evidence exclusion, bounded upload reads, global connector caps, and explicit Flutter proof for jobs/documents/deduplication/file import behavior.

## User Story

En tant que propriétaire d'un projet ContentGlowz, je veux importer ou connecter mes données projet et obtenir une mémoire projet nettoyée, dédupliquée et exploitable, afin de prendre des décisions de contenu, SEO et croissance avec des preuves et un niveau de confiance.

Primary actor: authenticated ContentGlowz user with access to an active project.

Trigger: the user uploads project files, starts a project intelligence sync from existing project sources, opens the Project Intelligence screen, or asks ContentGlowz to generate recommendations from the current project memory.

Observable result: the user sees a project-scoped intelligence dashboard with source inventory, cleaning/deduplication status, extracted facts, confidence/provenance, recommendations, and actions such as "add to Idea Pool".

## Minimal Behavior Contract

The system accepts project-scoped uploads and selected existing ContentGlowz sources, creates an ingestion job, extracts readable text, normalizes and chunks that text, detects exact and near duplicates, stores source documents, facts, provenance, confidence, and recommendations under the requesting `user_id + project_id`, and shows the user what was accepted, skipped, duplicated, failed, and recommended. If a file, connector, provider, project, or permission check fails, the job records a recoverable error without exposing another tenant's data or sending private content to providers unexpectedly. The easy edge case is treating duplicated or stale source material as new truth: duplicated evidence must reinforce provenance when useful, but it must not inflate recommendation confidence or create duplicate ideas.

For the verification-gap repair, "implemented" means the invariants are enforced by code paths that cannot be bypassed by common races or derived reads: active jobs are claimed atomically at the store/database boundary, source removal excludes duplicate rows and recommendations derived from duplicate/canonical document relationships, upload size checks do not require reading an unbounded file into memory, connector caps apply globally per sync run, and Flutter exposes enough job/document/dedupe state to prove the user can understand what happened.

## Success Behavior

- Given an authenticated user with an owned active project, when they upload supported text-like files, then ContentGlowz creates a `project_intelligence.ingest` job and persists source records, cleaned documents, chunks, dedupe decisions, and a job summary.
- Given existing project sources such as project profile, repo understanding, Search Console snapshots, Idea Pool items, creator profile, personas, work domains, and project assets metadata, when the user runs "sync project intelligence", then those sources are imported into the same memory model with explicit source type and provenance.
- Given duplicated content from two uploads or one upload plus one connector, when ingestion runs, then exact duplicates are skipped by hash and near duplicates are linked to the canonical document with a visible duplicate count and reason.
- Given enough clean evidence, when recommendations are generated, then the response includes recommendation type, priority, confidence, evidence references, affected entities, and a safe next action.
- Given a recommendation that can become an idea, when the user selects "add to Idea Pool", then ContentGlowz creates or reuses a deduplicated idea scoped to the same user/project and stores the originating evidence IDs.
- Given BYOK or platform mode is required for LLM summarization, when runtime credentials are available, then provider calls go through `ai_runtime_service` and never read raw provider env vars directly inside the new route/service.
- Given AI runtime is unavailable, when ingestion itself can run deterministically, then cleaning, chunking, dedupe, source inventory, and deterministic recommendations still complete; LLM-only synthesis is marked degraded.
- Proof of success includes backend tests for ownership, file validation, ingestion idempotency, dedupe, fact/recommendation provenance, AI runtime preflight, and Idea Pool handoff, plus Flutter tests for dashboard states.

## Error Behavior

- Missing, archived, deleted, or foreign project returns `404` or `403` through existing project ownership helpers and never reveals cross-tenant resource existence.
- Unsupported file type, empty file, oversized file, malformed JSON/CSV, unsafe URL, or unsupported connector returns a per-item failure inside the job summary; other valid items in the same job can still complete.
- Upload limits are enforced before reading full payloads: V1 accepts at most 10 files per job, 10 MB per file, and only `text/plain`, `text/markdown`, `text/csv`, `application/json`, `text/html`, and common markdown extensions.
- If Turso is unavailable, the job fails before partial document writes or records a failed status if a job row already exists; no source is reported as ingested unless committed.
- If AI provider resolution fails, deterministic ingestion completes and recommendation generation returns `degraded` with a provider error envelope pointing to AI runtime settings.
- If a duplicate is detected, the duplicate row is linked to the canonical document and excluded from recommendation scoring unless the recommendation explicitly counts independent corroborating sources.
- If "add to Idea Pool" is retried, the existing idea is returned or skipped with a duplicate reason; no duplicate `raw` idea should appear for the same project, recommendation key, target URL/query/topic, and source evidence.
- If the user removes an uploaded source, the source and derived rows become unavailable to reads, recommendations, provider readiness, and Idea Pool actions; duplicate rows where either `documentId` or `canonicalDocumentId` belongs to the removed source are hidden or soft-deleted, and recommendations whose `evidenceJson` references removed documents/chunks/facts/duplicates are removed or regenerated without that evidence.
- If two ingestion or sync requests arrive concurrently for the same `userId + projectId`, the store/database layer atomically creates exactly one active job. The loser must receive the existing active job or a structured conflict. A service-level pre-check without an atomic claim is not sufficient.
- If uploaded HTML/Markdown contains scripts, event handlers, iframes, data URLs, or other executable markup, the processor extracts text only and the Flutter UI renders escaped text, never trusted HTML.
- No error path logs uploaded document bodies, OAuth tokens, provider secrets, raw authorization headers, encrypted payloads, or private Search Console payloads beyond sanitized counts, IDs, and source labels.

## Problem

ContentGlowz already has intelligence in several places, but each feature owns its own local interpretation:

- project onboarding knows project profile, source URL, local repo path, tech stack, and content directories;
- persona draft can inspect repo/site evidence and produce persona candidates;
- Search Console Intelligence stores SEO snapshots and opportunities;
- Idea Pool ingests newsletter, SEO, competitor, social, weekly ritual, and Search Console ideas;
- the AI runtime resolver controls BYOK/platform provider usage.

The missing product layer is a durable "project brain" that every decision flow can query. Without that layer, uploaded files, crawled content, SEO signals, personas, assets, ideas, and repo evidence remain fragmented. Decisions may duplicate work, miss provenance, over-trust stale data, or silently depend on a provider-specific upload/fine-tuning path that does not preserve ContentGlowz's tenant boundaries and evidence model.

## Solution

Build `Project Intelligence Engine` V1 as a backend-owned, project-scoped data layer plus a compact Flutter decision surface. V1 ingests uploads and existing ContentGlowz sources, normalizes them into sources/documents/chunks/facts/recommendations with dedupe and provenance, and exposes reviewable recommendations that can feed the Idea Pool. Provider-specific file search, fine-tuning, Gemini, OpenAI, and open-source deployments are represented as export/readiness metadata in V1, not executed automatically.

## Scope In

- Backend models for project intelligence sources, documents, chunks, facts, duplicates, recommendations, and ingestion jobs.
- Turso/libSQL tables created through idempotent `ensure_tables` startup logic.
- Authenticated project-owned routes under `/api/projects/{project_id}/intelligence`.
- Upload ingestion for text, markdown, CSV, JSON, and HTML files within strict size/count limits.
- Upload guardrails that reject more than 10 files per job and any file larger than 10 MB without reading an unbounded payload into process memory; when a request lacks reliable size metadata, the router reads at most `10 MB + 1 byte` per file and fails that item if the sentinel byte exists.
- Connector ingestion from existing local data:
  - Project record and project settings.
  - Work domains.
  - Creator profile and personas.
  - Repo/site understanding snapshots when generated or regenerated.
  - Search Console snapshots and opportunities.
  - Idea Pool items.
  - Project asset metadata and usage, without binary upload.
- Deterministic cleaning and formatting:
  - whitespace normalization;
  - HTML text extraction with BeautifulSoup;
  - JSON flattening for readable key/value text;
  - CSV header/row sampling;
  - markdown/plain text preservation.
- Chunking with stable source offsets and content hashes.
- Exact duplicate detection by SHA-256 of normalized text.
- Near duplicate detection using deterministic token-set similarity or SimHash-like fingerprints implemented locally, without adding a vector database in V1.
- Fact extraction into typed categories:
  - audience;
  - offer;
  - positioning;
  - channel;
  - SEO;
  - competitor;
  - constraint;
  - content_asset;
  - risk;
  - open_question.
- Recommendation generation with evidence links, confidence, priority, rationale, and next action.
- Action bridge from recommendations to Idea Pool with dedupe and evidence metadata.
- Source removal for uploaded sources: the user can remove an uploaded source from the project intelligence memory, derived documents/chunks/facts/recommendations are deleted or soft-deleted consistently, and removed evidence is excluded from future scoring.
- Duplicate removal propagation: duplicate records and recommendation evidence that reference a removed source's duplicate document or canonical document must be excluded from default reads and from new recommendation generation.
- Display-safe evidence snippets: uploaded or connected HTML/Markdown is shown only as escaped text snippets or derived facts; raw HTML/Markdown from untrusted sources is never rendered as trusted UI markup.
- Provider readiness report that says whether the current memory is better suited for RAG/file search, fine-tuning dataset export, or no provider deployment yet.
- Flutter API client models/providers and one Project Intelligence screen reachable from the existing project-scoped app shell.
- Flutter screen evidence controls for the verification surface: visible job state/history, source inventory, document summaries, dedupe/duplicate counts or reasons, facts, recommendations, provider readiness, and a clear distinction between backend multipart file upload and any text-paste import fallback.
- Backend and Flutter tests for core happy paths and security/error states.
- Documentation updates for README/API setup and product interpretation.

## Scope Out

- Automatic fine-tuning or deployment to OpenAI, Gemini, Vertex AI, Ollama, Hugging Face, or any open-source runtime.
- Sending uploaded private project data to external AI providers during ingestion unless the user explicitly triggers recommendation synthesis and the current AI runtime mode is configured.
- Binary media understanding, OCR, audio/video transcription, PDF extraction, and image embedding.
- Full vector database adoption, cross-project global memory, organization-shared intelligence, or public sharing of intelligence records.
- Replacing Search Console, Idea Pool, persona draft, or project asset routes. V1 consumes and links them.
- Automatic content generation from recommendations. V1 creates reviewable recommendations and optional Idea Pool items only.
- Billing/credit metering for ingestion jobs.
- Offline replay of file uploads in Flutter.
- Provider-specific claim that all models can be trained and deployed "in minutes".

## Constraints

- Follow FastAPI router patterns with `require_current_user` and project ownership checks through existing project helpers.
- Follow Turso/libSQL additive schema rules: new tables only, idempotent startup ensure, indexes on `userId`, `projectId`, source status, hashes, and updated timestamps.
- Use existing `job_store` pattern or a dedicated intelligence job table with the same client-observable status semantics; do not invent a local-only job store.
- Active intelligence job creation must be atomic for `userId + projectId + active status`. Prefer a transaction, conditional insert, or durable lock row in Turso/libSQL. A separate `get_active_job` followed by `create_job` is a known race and fails readiness.
- Use `ai_runtime_service.preflight_providers` for any LLM-backed synthesis and keep deterministic ingestion usable without LLM credentials.
- Do not mutate process environment for provider credentials.
- Do not log raw uploaded content, OAuth payloads, API keys, provider secrets, or private connector payloads.
- Do not render uploaded or connector-provided HTML/Markdown as trusted markup in Flutter; use escaped text widgets/snippets and bounded previews.
- Treat uploaded and connected project data as user-private business data.
- Keep V1 file support intentionally narrow and predictable.
- Allow at most one active ingestion/sync job per `userId + projectId` in V1; concurrent requests return the existing active job or a structured conflict response, and tests must exercise concurrent calls rather than only sequential pre-checks.
- Connector imports must use explicit service constants for source limits, enforce a global per-run cap as well as per-source/per-period caps, and tests must prove large Idea Pool/Search Console sources cannot exceed the cap.
- Dedupe must be deterministic and testable.
- Recommendation confidence must be explainable from evidence quality, recency, source diversity, and duplicate handling.
- Flutter UI must remain project-scoped and degrade gracefully when backend data is unavailable.
- Avoid provider lock-in: ContentGlowz's own normalized memory remains the source of truth.

## Dependencies

- Local backend:
  - `lab/api/routers/projects.py` for project ownership and project-scoped routing patterns.
  - `lab/api/services/user_data_store.py` for user-owned profile/persona/work-domain data patterns.
  - `lab/agents/seo/config/project_store.py` for Project table patterns.
  - `lab/api/services/ai_runtime_service.py` for BYOK/platform runtime preflight.
  - `lab/api/services/repo_understanding_service.py` for existing repo/site evidence collection.
  - `lab/api/routers/search_console.py` and `api/services/search_console_store.py` for SEO snapshots/opportunity evidence.
  - `lab/status/service.py` for Idea Pool CRUD and the bulk ingestion ownership bug that must be fixed.
  - `lab/api/main.py` and `api/routers/__init__.py` for router/startup registration.
- Local frontend:
  - `app/lib/data/services/api_service.dart` for API calls, caching, and error mapping.
  - `app/lib/providers/providers.dart` for Riverpod project-scoped providers.
  - `app/lib/router.dart` and `presentation/screens/app_shell.dart` for navigation.
  - `app/lib/l10n/app_localizations.dart` for labels.
- Python packages already available or acceptable under current constraints:
  - `fastapi[standard]` includes multipart upload support in current requirements.
  - `beautifulsoup4` is already in `requirements.txt` for HTML text extraction.
  - `json`, `csv`, `hashlib`, `re`, `uuid`, and `datetime` from the standard library for deterministic parsing/dedupe.
- Fresh external docs checked:
  - OpenAI File Search guide: https://platform.openai.com/docs/guides/tools-file-search/
  - OpenAI Retrieval/vector stores guide: https://platform.openai.com/docs/guides/retrieval
  - OpenAI fine-tuning/model optimization guide: https://platform.openai.com/docs/guides/fine-tuning
  - Gemini Files API guide: https://ai.google.dev/gemini-api/docs/files
  - Gemini embeddings guide: https://ai.google.dev/gemini-api/docs/embeddings
  - Gemini fine-tuning notice: https://ai.google.dev/gemini-api/docs/model-tuning
- External docs verdict: `fresh-docs checked`. Current provider docs support a V1 direction where ContentGlowz keeps its own memory and later exports to provider-specific retrieval/fine-tuning paths only after a dedicated adapter decision. OpenAI vector stores/file search are provider-managed retrieval tools, not the ContentGlowz source of truth. OpenAI model optimization requires evals and task-specific datasets, and the current docs state the fine-tuning platform is winding down for new users, so it is not the right default for arbitrary uploads. Gemini Files API uploads are temporary media/file inputs, Gemini embeddings can support RAG-like retrieval, and Gemini API fine-tuning is not currently available for a supported Gemini API model after Gemini 1.5 Flash-001 deprecation; Vertex AI or Gemini Enterprise Agent Platform is the separate tuning path.

## Invariants

- Every intelligence row is scoped by both `userId` and `projectId`.
- A user can only read, ingest, sync, or act on intelligence for projects they own.
- Raw uploads and cleaned documents are never returned to another user or project.
- Connector imports retain original source type, source ID, captured timestamp, and evidence metadata.
- Recommendations must cite evidence IDs and must not rely on uncited LLM claims.
- Deduped documents must keep provenance without double-counting confidence.
- Provider calls must use the current AI runtime resolver and fail with structured runtime errors.
- Source memory remains ContentGlowz-owned even if a future provider export is created.
- No recommendation can create content directly; it can only create/reuse Idea Pool entries or guide the user.
- Removed sources and their derived evidence must not appear in source inventory, facts, recommendations, provider readiness, or Idea Pool actions.
- Removed-source exclusion includes second-order duplicate evidence: if a removed document participated in `ProjectIntelligenceDuplicate` as either duplicate or canonical document, that duplicate link cannot appear in status, recommendations, provider readiness, or evidence details.
- Active-job uniqueness is a data-layer invariant, not only a service-layer intention.

## Links & Consequences

- Data: new Turso tables are required and must be ensured on startup before routes are usable.
- Auth: all routes require Clerk-authenticated `CurrentUser` and project ownership.
- Security: uploads and connector data are private business inputs; logs and errors must be sanitized.
- API: new route namespace under project routes affects Flutter API client and OpenAPI.
- AI runtime: recommendation synthesis may require `openrouter`; deterministic ingestion must not.
- Existing Search Console: snapshots and opportunities become source evidence, not a competing SEO engine.
- Existing Idea Pool: recommendation actions reuse Idea Pool but must fix user ownership for `bulk_create_ideas`.
- Existing personas/repo understanding: V1 can import persona/creator/repo facts; future persona draft can consume intelligence facts.
- Performance: ingestion must be bounded by file count, file size, chunk count, and connector source limits.
- Cost: no embedding/provider cost is incurred during deterministic ingestion; LLM synthesis is explicit.
- Analytics/SEO: no public SEO metadata changes.
- Accessibility: Flutter dashboard controls need standard buttons, progress states, empty states, and error copy.
- Safety: uploaded HTML/Markdown must be displayed as escaped text only; no untrusted document body can become executable UI.
- Deployment: backend startup must tolerate missing Turso by surfacing explicit service errors, following current patterns.

## Documentation Coherence

- Update `lab/README.md` with Project Intelligence routes, supported file types, limits, startup tables, and provider-synthesis behavior.
- Update `app/README.md` with the new project-scoped decision surface and offline limits for uploads.
- Add or update a short internal docs section explaining "RAG/index first, fine-tuning later" so the product does not over-promise provider training.
- Update API examples or OpenAPI descriptions for upload, sync, recommendations, and Idea Pool action routes.
- Add localization strings in `app/lib/l10n/app_localizations.dart`.
- Changelog/task tracking is handled by later lifecycle steps, not this spec.

## Edge Cases

- Same content uploaded twice with different filenames.
- Same source imported from Search Console and Idea Pool because an opportunity was previously ingested.
- Empty markdown file, JSON with no scalar text, CSV with headers only, or HTML with scripts/styles only.
- Large file near limit and multi-file job where one item fails.
- Job retry after partial failure.
- Active project switched in Flutter while an intelligence job is running.
- Archived/deleted project accessed through stale route state.
- AI runtime unavailable after deterministic ingestion succeeds.
- LLM returns uncited recommendations or invalid JSON.
- User tries to ingest connector data before Search Console or work domains are configured.
- Duplicate recommendation action retried after network timeout.
- Stale facts from older source snapshots conflict with newer source facts.
- Uploaded private content accidentally contains credentials.
- User removes an uploaded source after it generated facts/recommendations.
- Uploaded HTML/Markdown contains script tags, event handlers, iframe markup, or malicious links.

## Implementation Tasks

- [ ] Task 1: Add backend intelligence Pydantic contracts
  - File: `lab/api/models/project_intelligence.py`
  - Action: Create request/response models for source inventory, upload result, ingest job, document, chunk summary, fact, duplicate, recommendation, provider readiness, and Idea Pool action responses using project API naming conventions.
  - User story link: Defines the observable contract for importing data and making decisions.
  - Depends on: None.
  - Validate with: `pytest lab/tests/test_project_intelligence_models.py`.
  - Notes: Include aliases for camelCase client payloads where existing models do so.

- [ ] Task 2: Add Turso-backed intelligence store
  - File: `lab/api/services/project_intelligence_store.py`
  - Action: Implement `ensure_tables`, create/list/update/delete-or-soft-delete methods for `ProjectIntelligenceSource`, `ProjectIntelligenceDocument`, `ProjectIntelligenceChunk`, `ProjectIntelligenceFact`, `ProjectIntelligenceRecommendation`, and `ProjectIntelligenceDuplicate`.
  - User story link: Provides durable project memory with provenance.
  - Depends on: Task 1.
  - Validate with: `pytest lab/tests/test_project_intelligence_store.py`.
  - Notes: Use additive tables with `userId`, `projectId`, `createdAt`, `updatedAt`; add indexes for scope, status, `contentHash`, `canonicalDocumentId`, and recommendation status. Removed source evidence must be excluded by default queries.

- [ ] Task 3: Register startup ensure for intelligence tables
  - File: `lab/api/main.py`
  - Action: Call `project_intelligence_store.ensure_tables()` in lifespan when Turso is configured, matching Search Console and image generation startup style.
  - User story link: Ensures the feature is available without manual migration steps.
  - Depends on: Task 2.
  - Validate with: `pytest lab/tests/test_bootstrap_routes.py` and a startup import sanity check.
  - Notes: Startup failure should be non-critical but explicit in logs, matching current patterns.

- [ ] Task 4: Implement document cleaning, formatting, chunking, and dedupe utilities
  - File: `lab/api/services/project_intelligence_processor.py`
  - Action: Add deterministic parsers for text/markdown, JSON, CSV, and HTML; normalize whitespace; compute raw and normalized hashes; chunk text with stable offsets; compute near-duplicate signatures and similarity.
  - User story link: Delivers the "cleaning, formatting, deduplication" promise.
  - Depends on: Task 1.
  - Validate with: `pytest lab/tests/test_project_intelligence_processor.py`.
  - Notes: Do not add a vector DB or external parser in V1. Strip scripts/styles from HTML with BeautifulSoup.

- [ ] Task 5: Implement project intelligence orchestration service
  - File: `lab/api/services/project_intelligence_service.py`
  - Action: Compose store + processor + existing sources; implement upload ingestion, connector sync, fact extraction, deterministic recommendations, optional LLM recommendation polishing through `ai_runtime_service`, and provider readiness report.
  - User story link: Turns raw and connected data into decision-ready memory.
  - Depends on: Tasks 2, 4.
  - Validate with: `pytest lab/tests/test_project_intelligence_service.py`.
  - Notes: Deterministic recommendations should cover at least missing persona evidence, weak source diversity, duplicated ideas, SEO opportunity backlog, stale source data, and high-confidence Idea Pool candidates.

- [ ] Task 6: Add authenticated project intelligence router
  - File: `lab/api/routers/project_intelligence.py`
  - Action: Add routes under `/api/projects/{project_id}/intelligence` for status, upload, connector sync, jobs, sources, source removal, documents, facts, recommendations, provider readiness, and add-to-Idea-Pool action.
  - User story link: Exposes the project intelligence workflow to clients.
  - Depends on: Task 5.
  - Validate with: `pytest lab/tests/test_project_intelligence_router.py`.
  - Notes: Reuse `require_owned_project`; return `404` for foreign project data. Use `UploadFile` for multipart uploads.

- [ ] Task 7: Register the new router
  - File: `lab/api/routers/__init__.py`
  - Action: Export `project_intelligence_router`.
  - User story link: Makes the route available through the FastAPI app.
  - Depends on: Task 6.
  - Validate with: router exposure test in `test_project_intelligence_router.py`.
  - Notes: Follow existing router export ordering.

- [ ] Task 8: Include the router in FastAPI
  - File: `lab/api/main.py`
  - Action: Import and include `project_intelligence_router`.
  - User story link: Makes the route callable from Flutter.
  - Depends on: Task 7.
  - Validate with: `pytest lab/tests/test_bootstrap_routes.py lab/tests/test_project_intelligence_router.py`.
  - Notes: Keep health/no-prefix routes unchanged.

- [ ] Task 9: Fix Idea Pool bulk ingestion ownership before using it
  - File: `lab/status/service.py`
  - Action: Add `user_id: Optional[str] = None` to `bulk_create_ideas`, write `user_id` into `idea_pool`, and preserve backward-compatible callers that omit user_id.
  - User story link: Ensures intelligence recommendations cannot create ownerless or cross-tenant ideas.
  - Depends on: None.
  - Validate with: `pytest lab/tests/test_project_intelligence_router.py lab/tests/test_search_console_router.py`.
  - Notes: The current authenticated router passes `user_id` to a method that does not accept it; this is a blocking bug for safe recommendation actions.

- [ ] Task 10: Add backend tests for security, dedupe, and degradation
  - File: `lab/tests/test_project_intelligence_router.py`
  - Action: Cover project ownership, unsupported files, oversized files, upload success, connector sync success, duplicate detection, recommendation evidence, provider-unavailable degradation, source removal, escaped HTML/Markdown evidence handling, concurrent job conflict, connector caps, and Idea Pool retry dedupe.
  - User story link: Verifies the happy path and failure behavior.
  - Depends on: Tasks 1-9.
  - Validate with: `pytest lab/tests/test_project_intelligence_router.py`.
  - Notes: Use AsyncMock and in-memory/test libsql patterns already used by neighboring tests.

- [ ] Task 11: Add Flutter data models
  - File: `app/lib/data/models/project_intelligence.dart`
  - Action: Create Dart models for status, source, document summary, fact, recommendation, provider readiness, job, upload result, and action result.
  - User story link: Lets the app render the intelligence state accurately.
  - Depends on: Task 1.
  - Validate with: `flutter test` for model parsing if existing test harness supports it.
  - Notes: Keep null-safe parsing and defensive defaults like existing models.

- [ ] Task 12: Add Flutter API client methods
  - File: `app/lib/data/services/api_service.dart`
  - Action: Add methods for fetch status, upload files, sync connectors, fetch jobs, list sources/facts/recommendations, provider readiness, and add recommendation to Idea Pool.
  - User story link: Connects the UI to backend behavior.
  - Depends on: Tasks 6, 11.
  - Validate with: existing Dart analyzer and targeted API service tests if present.
  - Notes: Do not queue file uploads offline. Cache read-only status/recommendation responses when safe.

- [ ] Task 13: Add Riverpod providers/controller
  - File: `app/lib/providers/providers.dart`
  - Action: Add project-scoped intelligence providers and a notifier for upload/sync/recommendation actions that invalidates affected providers.
  - User story link: Keeps Project Intelligence tied to the active project.
  - Depends on: Task 12.
  - Validate with: `flutter analyze`.
  - Notes: Guard on `activeProjectIdProvider` and `appAccessStateProvider` like Search Console providers.

- [ ] Task 14: Add Project Intelligence screen
  - File: `app/lib/presentation/screens/project_intelligence/project_intelligence_screen.dart`
  - Action: Build a project-scoped screen with upload/sync controls, source inventory, source removal, job state, facts, recommendations, confidence/evidence details, provider readiness, and add-to-Idea-Pool actions.
  - User story link: Gives the user the decision surface.
  - Depends on: Task 13.
  - Validate with: `flutter analyze` and a manual web run screenshot when implemented.
  - Notes: Use compact operational UI, not a landing page. Every recommendation should show evidence and confidence, not just generated prose.

- [ ] Task 15: Wire navigation and localization
  - File: `app/lib/router.dart`
  - Action: Add a route for Project Intelligence in the authenticated shell.
  - User story link: Makes the feature discoverable for active project work.
  - Depends on: Task 14.
  - Validate with: `flutter analyze`.
  - Notes: Keep the existing project picker action available.

- [ ] Task 16: Add labels/translations
  - File: `app/lib/l10n/app_localizations.dart`
  - Action: Add English/French labels for Project Intelligence, upload states, sync, dedupe, evidence, confidence, provider readiness, and Idea Pool action results.
  - User story link: Makes the UI understandable in the current app language setup.
  - Depends on: Task 14.
  - Validate with: `flutter analyze`.
  - Notes: Avoid promising automatic fine-tuning in UI copy.

- [ ] Task 17: Update backend and app documentation
  - File: `lab/README.md`
  - Action: Document routes, supported sources, upload limits, table ensure behavior, and provider readiness semantics.
  - User story link: Keeps implementation and operator expectations aligned.
  - Depends on: Tasks 1-16.
  - Validate with: docs review.
  - Notes: Add a short statement that provider fine-tuning/deployment is follow-up scope.

- [ ] Task 18: Update app documentation
  - File: `app/README.md`
  - Action: Document the Project Intelligence screen, project scoping, offline upload limitation, and decision/recommendation workflow.
  - User story link: Keeps product behavior documented for the Flutter client.
  - Depends on: Tasks 11-16.
  - Validate with: docs review.
  - Notes: Mention that recommendations can be converted to Idea Pool items for review.

- [ ] Task 19: Close post-verify data-layer and UI proof gaps
  - Files:
    - `lab/api/services/project_intelligence_store.py`
    - `lab/api/services/project_intelligence_service.py`
    - `lab/api/routers/project_intelligence.py`
    - `lab/api/services/project_intelligence_processor.py`
    - `lab/tests/test_project_intelligence_store.py`
    - `lab/tests/test_project_intelligence_service.py`
    - `lab/tests/test_project_intelligence_router.py`
    - `app/lib/data/models/project_intelligence.dart`
    - `app/lib/data/services/api_service.dart`
    - `app/lib/providers/providers.dart`
    - `app/lib/presentation/screens/project_intelligence/project_intelligence_screen.dart`
    - `app/lib/l10n/app_localizations.dart`
    - `lab/README.md`
    - `app/README.md`
  - Action: Repair the four blocking verification gaps and the Flutter proof gap: make active-job creation atomic; hide or soft-delete duplicates and recommendations tied to removed source evidence; enforce bounded upload reads; enforce connector caps globally per sync run; and expose/test job/document/dedupe evidence in the Flutter surface.
  - User story link: Converts the implemented V1 from "present" to decision-safe: a user can trust the memory, understand ingestion outcomes, and avoid stale or duplicated evidence.
  - Depends on: Tasks 1-18.
  - Validate with:
    - `python3 -m pytest tests/test_project_intelligence_models.py tests/test_project_intelligence_processor.py tests/test_project_intelligence_store.py tests/test_project_intelligence_service.py tests/test_project_intelligence_router.py tests/test_search_console_router.py tests/test_ai_runtime_service.py tests/test_persona_draft_route.py`
    - `flutter analyze`
    - targeted Flutter widget/model tests if the existing harness supports them.
  - Notes:
    - Atomic job enforcement must be implemented below the orchestration race window. A service-level `get_active_job` then `create_job` sequence is explicitly insufficient.
    - Source removal must handle duplicate links in both directions: removed duplicate document and removed canonical document.
    - Recommendation cleanup must inspect persisted evidence IDs, not only direct `sourceId` columns.
    - Search Console and Idea Pool connector caps must be proven against oversized fixtures; a per-period Search Console limit that multiplies across periods is not enough.
    - For Flutter, either implement real file selection/upload when an existing dependency supports it, or label text-paste import as a text-source fallback and keep backend multipart file upload documented and tested. In both cases, job/document/dedupe state must be visible to the user.

## Acceptance Criteria

- [ ] CA 1: Given an authenticated user owns project A, when they upload a supported markdown file to project A intelligence, then the API returns a job/result with one accepted source, one cleaned document, chunks, and source provenance scoped to `userId + projectId`.
- [ ] CA 2: Given the same user uploads the same content twice under different filenames, when ingestion completes, then the second document is marked duplicate and recommendations do not double-count it.
- [ ] CA 3: Given user B requests project A intelligence data, when the API handles the request, then it returns `404` or `403` and no source/document/fact/recommendation data.
- [ ] CA 4: Given a mixed upload has one valid file and one unsupported file, when ingestion runs, then the valid file is ingested and the unsupported file is reported as failed with a recoverable reason.
- [ ] CA 5: Given Search Console snapshots and Idea Pool items exist for a project, when connector sync runs, then the engine imports them as separate source types with evidence IDs and does not create duplicate ideas automatically.
- [ ] CA 6: Given AI runtime credentials are missing, when the user requests recommendation generation, then deterministic recommendations are returned with `degraded` provider status or a structured runtime error, and no raw content is sent to a provider.
- [ ] CA 7: Given AI runtime credentials are configured and recommendation synthesis is enabled, when synthesis runs, then provider resolution goes through `ai_runtime_service` and recommendations still include evidence IDs.
- [ ] CA 8: Given a recommendation is converted to the Idea Pool, when the action succeeds, then the idea has `user_id`, `project_id`, source `project_intelligence`, and raw evidence metadata.
- [ ] CA 9: Given the same recommendation action is retried, when the backend detects an existing idea with the same stable key, then it returns reused/skipped status without inserting a duplicate raw idea.
- [ ] CA 10: Given the user opens the Flutter Project Intelligence screen with no active project, then the UI shows a project-required state and no API call attempts to fetch unscoped intelligence.
- [ ] CA 11: Given the backend is unreachable but cached read-only intelligence exists, when the screen opens, then the app may show stale cached summaries but upload/sync actions remain disabled or error clearly.
- [ ] CA 12: Given provider readiness is requested, when the memory has unreviewed or low-quality evidence, then the readiness report recommends improving the memory instead of fine-tuning/deploying.
- [ ] CA 13: Given current Gemini API fine-tuning limitations, when provider readiness references Gemini, then it does not claim Gemini API fine-tuning is available; it points to retrieval/embeddings or future Vertex AI adapter scope.
- [ ] CA 14: Given a user removes an uploaded source, when the source had generated documents, facts, and recommendations, then subsequent reads and recommendations exclude that source and its derived evidence.
- [ ] CA 15: Given uploaded HTML/Markdown contains executable markup, when the dashboard displays evidence snippets, then the UI shows escaped text or derived facts only and no raw uploaded markup is rendered.
- [ ] CA 16: Given two ingestion or connector sync requests are submitted concurrently for the same `userId + projectId`, when the second request arrives, then it returns the existing active job or a structured conflict without creating duplicate jobs or partial duplicate writes.
- [ ] CA 17: Given a removed source produced a duplicate document whose canonical document is still active, when recommendations/status/provider readiness are listed or regenerated, then no duplicate record or evidence reference from the removed source appears.
- [ ] CA 18: Given a removed source was the canonical document for another duplicate, when recommendations/status/provider readiness are listed or regenerated, then the duplicate relationship is hidden, soft-deleted, or re-canonicalized without referencing the removed document.
- [ ] CA 19: Given two upload or sync requests race at the same time for the same `userId + projectId`, when both reach the store layer, then the database ends with one active job and the second response is existing-job/conflict, not a second active row.
- [ ] CA 20: Given an uploaded file exceeds 10 MB by one byte and no reliable content-length exists, when the router reads it, then the file is rejected after reading at most `10 MB + 1 byte`, no document/chunk is persisted, and the failure is included in the job summary.
- [ ] CA 21: Given Search Console has more than the allowed connector cap across multiple periods, when sync runs, then imported Search Console evidence is capped globally for the job and the summary reports skipped/capped counts.
- [ ] CA 22: Given the Flutter Project Intelligence screen has completed an upload/sync with duplicates, when the user opens the screen, then they can see job status, document/source summaries, duplicate count/reason, facts/recommendations, and provider readiness without rendering trusted HTML/Markdown.

## Test Strategy

- Backend unit tests:
  - processor parsing/cleaning/chunking/dedupe;
  - store table ensure and scoped CRUD;
  - service connector import and recommendation generation;
  - provider-unavailable degradation.
- Backend router tests:
  - auth/ownership;
  - multipart upload validation;
  - bounded oversized-file read with a sentinel byte;
  - connector sync;
  - list/get routes;
  - source removal and removed-evidence exclusion, including duplicate rows where the removed source is either duplicate or canonical document;
  - escaped evidence snippets for uploaded HTML/Markdown;
  - concurrent ingestion conflict using real concurrent calls against the store path, plus connector cap behavior with oversized Search Console and Idea Pool fixtures;
  - Idea Pool action idempotency;
  - sanitized errors.
- Regression tests:
  - Search Console opportunity ingestion still works after `bulk_create_ideas` ownership fix.
  - Existing Idea Pool create/list/update routes remain owner-scoped.
  - Persona draft and AI runtime tests still pass.
- Flutter tests/checks:
  - model JSON parsing;
  - provider no-project/degraded states;
  - screen renders jobs/documents/dedupe evidence and escaped snippets;
  - analyzer for new screen/router/localization.
- Manual QA after implementation:
  - create/select a project;
  - upload a markdown file;
  - upload duplicate content;
  - sync existing sources;
  - confirm job/document/dedupe state is visible in the screen;
  - generate recommendations with and without AI runtime configured;
  - add a recommendation to Idea Pool;
  - remove an uploaded source and confirm derived recommendations disappear;
  - switch projects and confirm isolation.

## Risks

- Data privacy risk is high because uploaded files and connector records can contain sensitive strategy, customer, SEO, and credential-like content. Mitigation: strict auth, project scoping, file limits, sanitized logs, and no implicit provider upload.
- Untrusted content rendering risk is high because uploads may contain malicious HTML/Markdown. Mitigation: text extraction only, escaped snippets in Flutter, no trusted rendering of uploaded markup, and tests with executable markup.
- Data removal risk is medium because users may upload the wrong private source. Mitigation: V1 source removal excludes/deletes derived evidence and tests that removed evidence no longer influences decisions.
- Derived evidence retention risk is high after dedupe because a removed source can still influence recommendations through duplicate links or canonical-document references. Mitigation: duplicate rows and recommendation evidence are soft-deleted/filtered in both directions and covered by removal regression tests.
- Data quality risk is high because stale or duplicated evidence can distort decisions. Mitigation: source timestamps, dedupe links, confidence rules, and evidence display.
- Concurrency risk is high because two simultaneous ingestions can create conflicting active jobs and partial duplicate writes. Mitigation: atomic store/database claim for active jobs plus concurrent tests.
- Provider promise risk is high because OpenAI, Gemini, and open-source runtimes have different retrieval/fine-tuning capabilities. Mitigation: V1 provider readiness only, with fresh-docs checked and no automatic training/deploy.
- Cost risk is medium if recommendation synthesis sends large context to LLMs. Mitigation: deterministic preprocessing, bounded chunks, explicit synthesis action, provider preflight.
- Performance risk is medium for large uploads and connector imports. Mitigation: hard limits, chunk caps, background jobs, indexes.
- Migration risk is medium because new tables and startup ensure logic touch production Turso. Mitigation: additive schema, idempotent ensures, and focused migration tests.
- Product risk is medium if the UI becomes another dashboard silo. Mitigation: direct actions to Idea Pool and evidence-backed recommendations.

## Execution Notes

- Read first:
  - `lab/api/routers/projects.py`
  - `lab/api/services/ai_runtime_service.py`
  - `lab/api/routers/search_console.py`
  - `lab/status/service.py`
  - `app/lib/presentation/screens/analytics/search_console_panel.dart`
- Implementation order:
  1. Backend models and store.
  2. Processor and deterministic dedupe.
  3. Service orchestration and connector import.
  4. Router and startup registration.
  5. Idea Pool ownership fix.
  6. Source removal and untrusted content display safeguards.
  7. Backend tests.
  8. Flutter models/API/providers/screen.
  9. Docs and manual QA.
- Post-verify repair order for the next `sf-start`:
  1. Add atomic active-job claim in `ProjectIntelligenceStore` and update upload/sync orchestration to use it.
  2. Extend source removal to duplicate links and persisted recommendation evidence, then add regression tests for removed duplicate and removed canonical scenarios.
  3. Replace unbounded upload reads with a bounded `10 MB + 1 byte` read guard and test the sentinel path.
  4. Apply connector caps globally per sync job and test Search Console multi-period overflow plus Idea Pool overflow.
  5. Add or clarify Flutter import behavior and expose job/document/dedupe evidence in the screen, with analyzer and any available widget/model tests.
  6. Update README notes to match the repaired behavior.
- Provider approach:
  - V1 uses ContentGlowz-owned memory as source of truth.
  - V1 may generate a provider readiness report.
  - V1 must not launch provider fine-tuning jobs or upload files to OpenAI/Gemini automatically.
  - Later OpenAI adapter can map reviewed documents to vector stores/file search or JSONL fine-tuning datasets after eval requirements exist.
  - Later Gemini adapter can use embeddings/files for retrieval-like flows and must route tuning through a separate Vertex AI decision if needed.
- Packages to avoid in V1:
  - no new vector DB dependency;
  - no PDF/OCR/audio/video parser;
  - no trusted HTML/Markdown rendering package for uploaded evidence;
  - no provider-specific SDK beyond existing runtime paths.
- Commands to validate when implemented:
  - `pytest lab/tests/test_project_intelligence_models.py lab/tests/test_project_intelligence_processor.py lab/tests/test_project_intelligence_store.py lab/tests/test_project_intelligence_service.py lab/tests/test_project_intelligence_router.py`
  - `pytest lab/tests/test_ai_runtime_service.py lab/tests/test_search_console_router.py lab/tests/test_persona_draft_route.py`
  - `flutter analyze` from `app`
- Stop conditions / reroute:
  - If production Turso schema cannot be safely changed with additive ensures, reroute to `/sf-ready` or a Turso migration-specific review.
  - If a provider SDK/export is requested during implementation, create a follow-up provider-adapter spec instead of expanding V1.
  - If uploaded binary/PDF/OCR support becomes required, create a separate ingestion-media spec.

## Open Questions

None blocking for V1. The following decisions are intentionally locked by this spec:

- V1 is project-owned memory and recommendations, not automatic provider fine-tuning.
- V1 accepts only text-like files and existing ContentGlowz connector data.
- V1 keeps deterministic ingestion usable without AI runtime credentials.
- V1 provider readiness reports capability and next steps but does not deploy.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-13 07:41:19 UTC | sf-spec | GPT-5 Codex | Created Project Intelligence Engine Data Layer spec from exploration and code investigation | Draft spec saved | /sf-ready Project Intelligence Engine Data Layer |
| 2026-05-13 16:56:25 UTC | sf-verify | GPT-5 Codex | Verified draft spec contract, metadata, dependencies, fresh provider docs, and chantier readiness before implementation | partial | /sf-ready Project Intelligence Engine Data Layer |
| 2026-05-13 17:26:28 UTC | sf-ready | GPT-5 Codex | Added readiness safeguards for source removal, untrusted content rendering, concurrent jobs, and connector caps; promoted spec to ready | ready | /sf-start Project Intelligence Engine Data Layer |
| 2026-05-14 21:33:14 UTC | sf-start | GPT-5.5 | Started implementation and fixed Idea Pool bulk ownership path (`bulk_create_ideas` now accepts and stores optional `user_id`) before expanding the data layer | partial | /sf-verify Project Intelligence Engine Data Layer |
| 2026-05-14 21:39:05 UTC | sf-verify | GPT-5 Codex | Verified current implementation against the Project Intelligence Engine contract; only Idea Pool bulk ownership is implemented, core intelligence data layer/UI/routes are missing | not verified | /sf-start Project Intelligence Engine Data Layer |
| 2026-05-14 22:08:13 UTC | sf-start | GPT-5.3 Codex | Implemented backend Project Intelligence data layer/routes/tests and Flutter Project Intelligence slice (models/API/providers/screen/route/l10n/docs), then revalidated required backend regressions and Flutter analyze | implemented | /sf-verify Project Intelligence Engine Data Layer |
| 2026-05-14 22:15:00 UTC | sf-verify | GPT-5 Codex | Verified backend routes/data layer and Flutter decision surface against the ready spec; checks pass, but atomic active-job enforcement, removed duplicate evidence exclusion, connector cap coverage, and Flutter job/file-upload proof remain incomplete | partial | /sf-start Project Intelligence Engine Data Layer fix verification gaps |
| 2026-05-14 22:24:12 UTC | sf-spec | GPT-5 Codex | Revised ready spec to make the sf-verify partial findings executable: atomic active-job claim, duplicate-derived removal, bounded upload reads, global connector caps, and Flutter job/document/dedupe proof | ready | /sf-start Project Intelligence Engine Data Layer fix verification gaps |

## Current Chantier Flow

- sf-spec: done, draft saved in `shipglows_data/workflow/specs/lab/SPEC-project-intelligence-engine-data-layer-2026-05-13.md`.
- sf-ready: ready; gate added source removal, untrusted content rendering, concurrent job, and connector cap safeguards.
- sf-start: implemented; backend + Flutter V1 scope delivered with targeted tests and analyze checks passing.
- sf-verify: partial; implementation is present and checks pass, but verification found contract gaps in active-job concurrency, removed duplicate evidence exclusion, connector caps, and Flutter proof/UI completeness.
- sf-spec: ready; revision 0.1.1 turns those partial findings into explicit implementation tasks, acceptance criteria, and validation commands for the next start pass.
- sf-end: not launched.
- sf-ship: not launched.

Next command: `/sf-start Project Intelligence Engine Data Layer fix verification gaps`.
