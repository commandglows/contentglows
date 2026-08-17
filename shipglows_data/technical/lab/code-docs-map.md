---
artifact: code_docs_map
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: lab
created: "2026-05-04"
updated: "2026-05-10"
status: draft
source_skill: sf-build
scope: code-docs-map
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - api/services/
  - agents/shared/tools/
  - agents/
  - shipglows_data/technical/platforms/crewai.md
  - tests/
depends_on:
  - artifact: "shipglows_data/technical/ai-runtime-and-url-safety.md"
    artifact_version: "1.0.0"
    required_status: draft
supersedes: []
evidence:
  - "Created during PydanticAI runtime adapter verification."
  - "CrewAI usage note added for backend agent orchestration, tools, structured outputs, and dependency migration risk."
next_review: "2026-06-04"
next_step: "/sf-docs technical audit lab"
---

# Code Docs Map

Use this map before editing backend runtime, provider, or LLM-callable external-fetch code.

| Code path | Primary doc | Coverage | Reader trigger |
| --- | --- | --- | --- |
| `api/services/pydantic_ai_runtime.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | PydanticAI adapter and request-scoped OpenRouter rules | Any direct PydanticAI, OpenRouter, output schema, or credential-resolution change |
| `api/services/user_llm_service.py` | `shipglows_data/technical/platforms/crewai.md` | Request-scoped CrewAI `LLM` construction through user OpenRouter credentials | Any CrewAI LLM, OpenRouter route, model, credential-resolution, or fallback behavior change |
| `agents/**/*.py` with `crewai`, `Agent`, `Task`, `Crew`, `Process`, or `kickoff` | `shipglows_data/technical/platforms/crewai.md` | CrewAI agent orchestration, tools, structured outputs, memory/tracing assumptions, and migration risk | Any CrewAI agent, crew, task, tool, process, structured output, memory, tracing, or dependency behavior change |
| `api/services/repo_understanding_service.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | Repo/site collection and structured persona understanding synthesis | Any persona draft, repository collection, public-site crawl, or synthesis change |
| `api/services/url_safety.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | Public HTTP URL validation and SSRF guardrails | Any URL parsing, DNS resolution, allowed scheme, or private-network policy change |
| `api/services/email_source_service.py` | `shipglows_data/technical/lab/architecture.md` | Per-user IMAP metadata, encrypted app-password lookup, validation state, and managed 6-hour ingestion job setup | Any email-source credential, folder, schedule, or validation contract change |
| `api/routers/settings_integrations.py` | `shipglows_data/technical/lab/architecture.md` | User-managed integration endpoints including OpenRouter and email source | Any integration route, credential response, or settings contract change |
| `api/routers/projects*.py` / `api/services/project*` | `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` | Project selection, project CRUD, repository analysis, and project-scoped intelligence behavior | Any project selection, project CRUD, intelligence ingestion, or repository analysis contract change |
| `api/routers/video_timelines.py` / `api/models/video_timeline.py` / `api/migrations/005_video_timelines.sql` | `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` | Video timeline draft/version/preview/final gates, render-safe assets, Remotion worker boundary, and artifact URL rules | Any timeline, render job, artifact, asset eligibility, or migration behavior change |
| `api/routers/assets*.py` / project asset services | `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` | Project asset library routes, usage links, tombstone/restore, storage descriptors, and selection safety | Any project asset route, asset eligibility, storage descriptor, or tombstone behavior change |
| `api/routers/images*.py` / image generation services | `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` | FLUX image generation, references, Bunny persistence, and project asset registration | Any image generation provider, reference, persistence, or asset-registration change |
| `api/routers/search_console*.py` / Search Console services | `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` | Google Search Console OAuth setup, encrypted tokens, callback, and response redaction | Any GSC OAuth, token storage, callback, or Search Console response behavior change |
| `api/routers/affiliations.py` / `api/routers/links.py` / `api/models/affiliations.py` / `api/migrations/008_link_management.sql` | `shipglows_data/technical/lab/backend-runtime-and-product-apis.md` | Affiliate link CRUD, slug-based public redirects `/r/{slug}`, click telemetry, A/B variant rotation, and targeting | Any affiliation, slug, redirect, click, variant, or link-management contract change |
| `scheduler/scheduler_service.py` / `api/routers/idea_pool.py` / `agents/sources/ingest.py` | `shipglows_data/technical/lab/architecture.md` | Recurring Idea Pool ingestion jobs and newsletter inbox source ingestion | Any source ingestion, scheduler cadence, ownership, or archive behavior change |
| `agents/newsletter/tools/imap_tools.py` | `shipglows_data/technical/lab/architecture.md` | IMAP reader, folder validation, newsletter detection, processed-email archiving | Any IMAP credential, folder, detection, or archive behavior change |
| `agents/shared/tools/exa_tools.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | Exa search/content tools and URL-fetch guardrails | Any LLM-callable Exa tool change |
| `agents/shared/tools/firecrawl_tools.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | Firecrawl scrape/crawl/map tools and URL-fetch guardrails | Any LLM-callable Firecrawl tool change |
| `tests/test_pydantic_ai_runtime.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | Runtime adapter regression coverage | Any PydanticAI adapter contract change |
| `tests/test_url_safety.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | URL safety regression coverage | Any URL safety policy change |
| `tests/test_external_url_tools_safety.py` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | Exa/Firecrawl guard regression coverage | Any external tool wrapper change |
| `tests/conftest.py` / `pytest.ini` | `shipglows_data/technical/ai-runtime-and-url-safety.md` | Local test harness, mocked provider credentials, and live API skip policy | Any test collection, marker, fixture, or live API prerequisite change |

## Documentation Update Plan Format

```text
Documentation Update Plan:
- Status: complete | no impact | pending final integration | blocked
- Impacted docs:
  - shipglows_data/technical/<doc>.md: <required update or no change>
- Reason:
  - <why the docs are or are not current>
```

## Maintenance Rule

Update this map when covered files move, new runtime/provider surfaces are introduced, or validation responsibilities change.
