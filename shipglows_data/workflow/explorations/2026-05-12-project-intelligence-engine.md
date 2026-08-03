---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: contentglowz
created: "2026-05-12"
updated: "2026-05-12"
status: draft
source_skill: sf-explore
scope: "project intelligence engine and provider runtime"
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - lab/api/services/ai_runtime_service.py
  - lab/api/services/repo_understanding_service.py
  - lab/api/routers/personas.py
  - lab/api/routers/search_console.py
  - lab/api/routers/idea_pool.py
  - lab/agents/sources/ingest.py
evidence:
  - "shipglows_data/workflow/TASKS.md marks dual-mode AI runtime, Search Console intelligence, project asset library, and Flux provider work as in progress."
  - "lab/api/services/ai_runtime_service.py resolves BYOK/platform modes for openrouter, exa, and firecrawl."
  - "lab/api/services/repo_understanding_service.py synthesizes project/persona understanding from local repo, GitHub, or public site evidence."
  - "lab/api/routers/search_console.py creates project-scoped Search Console summaries and opportunities."
  - "lab/api/routers/idea_pool.py and agents/sources/ingest.py ingest SEO, competitor, newsletter, social, and SERP signals into ideas."
depends_on:
  - shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md
  - shipglows_data/workflow/specs/lab/SPEC-google-search-console-intelligence.md
  - shipglows_data/workflow/specs/lab/SPEC-backend-persona-autofill-repo-understanding-user-keys.md
supersedes: []
next_step: "/sf-spec project intelligence engine data layer"
---

# Exploration Report: Project Intelligence Engine

## Starting Question

Clarify what intelligence engine ContentGlowz currently has for each project profile, and what is missing to support an ideal flow: upload data, clean/format/deduplicate it, then route training or deployment to OpenAI, Gemini, or open-source providers for informed decisions.

## Context Read

- `shipglows_data/workflow/TASKS.md` - showed current implementation priorities and in-progress AI/runtime work.
- `shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md` - defined BYOK/platform runtime policy and provider resolution.
- `shipglows_data/workflow/specs/lab/SPEC-backend-persona-autofill-repo-understanding-user-keys.md` - defined repo/site understanding for persona draft generation.
- `lab/api/services/ai_runtime_service.py` - confirmed the centralized provider resolver exists.
- `lab/api/services/repo_understanding_service.py` - confirmed repo/site content collection and LLM synthesis exists.
- `lab/api/routers/search_console.py` - confirmed project-scoped SEO intelligence/opportunity ingestion exists.
- `lab/api/routers/idea_pool.py` and `lab/agents/sources/ingest.py` - confirmed multiple sources already feed the Idea Pool.

## Internet Research

- None. This exploration used local project evidence only.

## Problem Framing

ContentGlowz already has several intelligence pieces, but not yet one explicit "project brain". The current system can resolve AI credentials, understand a repository or site enough to draft a persona, ingest market/SEO/social/newsletter signals, and turn some signals into ideas. The missing layer is a canonical project intelligence data layer that normalizes all uploaded and connected data into durable, deduplicated, scored, explainable project facts before any model/provider action.

## Option Space

### Option A: Keep Current Feature-Specific Intelligence

- Summary: Continue adding intelligence directly inside personas, Search Console, Idea Pool, newsletter, and content generation flows.
- Pros: Fastest short-term path; fewer new tables and abstractions.
- Cons: Knowledge remains fragmented; dedupe and provenance vary by feature; hard to make cross-source decisions.

### Option B: Add A Project Intelligence Layer

- Summary: Introduce a project-scoped ingestion and normalization layer that stores raw sources, cleaned documents, extracted facts, embeddings, duplicates, confidence, provenance, and decision recommendations.
- Pros: Best fit for informed decisions; reusable by personas, SEO, content planning, assets, and provider routing.
- Cons: Needs careful schema, privacy boundaries, job orchestration, and product UI.

### Option C: Outsource To Provider Fine-Tuning

- Summary: Upload data directly to provider fine-tuning or file-search systems and let provider-specific tooling own cleanup/training.
- Pros: Faster demos for one provider.
- Cons: Lock-in, weak cross-provider consistency, harder data governance, and not ideal when many decisions need retrieval/scoring rather than actual fine-tuning.

## Comparison

Option B is the strongest product foundation. Most project decisions need clean evidence, retrieval, scoring, and explanations more than they need fine-tuned models. Fine-tuning should be a later export/deployment path for specific repeatable tasks, not the first storage model.

## Emerging Recommendation

Create a "Project Intelligence Engine" V1:

1. Ingest: upload files, URLs, repos, Search Console, analytics, newsletters, social, competitors.
2. Normalize: clean text, chunk, classify source, extract entities/topics/personas/offers/constraints.
3. Deduplicate: hash exact duplicates and detect near-duplicates by title/content/source/time.
4. Store: keep raw source, cleaned document, extracted facts, embeddings, confidence, and provenance by `user_id + project_id`.
5. Decide: generate recommendations with evidence links and confidence scores.
6. Route: use the existing AI runtime resolver to execute with BYOK/platform providers.
7. Export/deploy: later support RAG indexes, OpenAI/Gemini file search, fine-tuning datasets, or open-source adapters when the use case justifies training.

## Non-Decisions

- No provider has been selected as the sole training/deployment target.
- No assumption that every project needs fine-tuning.
- No UI design chosen for reviewing cleaned/deduplicated data.

## Rejected Paths

- "Train everything immediately" - rejected because most current product decisions need retrieval and evidence-backed scoring first.
- "Provider-specific uploads as the source of truth" - rejected because ContentGlowz needs consistent project memory, provenance, and privacy controls across providers.

## Risks And Unknowns

- Privacy and tenant isolation are high-risk because project files, OAuth data, emails, and Search Console data are business-sensitive.
- Costs can grow quickly if uploads are embedded, summarized, and reprocessed without cache/versioning.
- The current `status.service.bulk_create_ideas` signature appears inconsistent with some router calls that pass `user_id`; this should be verified before relying on bulk source ingestion.
- Open-source deployment in minutes is feasible for small adapters or managed inference, but not a general promise for every model/training workload.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: The report summarizes code and specs only; no secrets, tokens, or customer data were included.

## Decision Inputs For Spec

- User story seed: As a project owner, I want to upload or connect project data and have ContentGlowz clean, deduplicate, understand, and score it so I can make evidence-backed content and growth decisions.
- Scope in seed: project-scoped ingestion jobs, raw/clean document storage, dedupe, fact extraction, embeddings/indexing, confidence/provenance, recommendations, provider runtime routing.
- Scope out seed: automatic provider fine-tuning for all uploads, unsupported claims of training every model in minutes, public sharing of private project intelligence.
- Invariants/constraints seed: every item scoped by `user_id + project_id`; raw secrets never exposed; provider calls use `ai_runtime_service`; recommendations must cite source evidence.
- Validation seed: tests for ownership, dedupe, provenance, provider preflight, ingestion idempotency, and recommendation confidence.

## Handoff

- Recommended next command: `/sf-spec project intelligence engine data layer`
- Why this next step: the concept is now clear enough to become an implementation-ready spec with schemas, endpoints, jobs, and UI contracts.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-05-12 19:21:13 UTC | Project intelligence engine | Read runtime, persona, Search Console, Idea Pool, and specs | Identified existing pieces and missing canonical project intelligence layer | `/sf-spec project intelligence engine data layer` |
