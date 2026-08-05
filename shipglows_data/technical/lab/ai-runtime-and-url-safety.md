---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: lab
created: "2026-05-04"
updated: "2026-05-04"
status: draft
source_skill: sf-build
scope: ai-runtime-url-safety
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - FastAPI backend
  - PydanticAI
  - OpenRouter
  - Exa
  - Firecrawl
  - persona draft jobs
depends_on:
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-migrate-pydantic-ai-major.md"
    artifact_version: "1.0.0"
    required_status: implemented
supersedes: []
evidence:
  - "api/services/pydantic_ai_runtime.py"
  - "api/services/repo_understanding_service.py"
  - "api/services/url_safety.py"
  - "agents/shared/tools/exa_tools.py"
  - "agents/shared/tools/firecrawl_tools.py"
  - "tests/test_pydantic_ai_runtime.py"
  - "tests/test_url_safety.py"
  - "tests/test_external_url_tools_safety.py"
  - "tests/conftest.py"
  - "pytest.ini"
next_review: "2026-06-04"
next_step: "/sf-docs technical audit lab"
---

# Technical Module Context: AI Runtime And URL Safety

## Purpose

This subsystem introduces PydanticAI through a single adapter while preserving ContentGlows's request-scoped AI credential model. It also centralizes URL validation for LLM-callable tools that can trigger external fetches through Exa or Firecrawl.

The main risk is accidentally broadening credential scope or SSRF surface while modernizing dependencies.

## Owned Files

| Path | Role | Edit notes |
| --- | --- | --- |
| `api/services/pydantic_ai_runtime.py` | PydanticAI adapter | Keep direct `pydantic_ai` imports here only. Use explicit request-scoped OpenRouter keys. |
| `api/services/repo_understanding_service.py` | Persona repo/site collection and synthesis | Keep synthesis routed through the adapter. Validate public non-GitHub URLs before Firecrawl calls. |
| `api/services/url_safety.py` | SSRF/public URL guard | Reject malformed, unsupported, localhost, link-local, private, metadata, and mixed public/private resolutions. |
| `agents/shared/tools/exa_tools.py` | LLM-callable Exa wrappers | Validate URLs before client creation for URL-fetching operations. |
| `agents/shared/tools/firecrawl_tools.py` | LLM-callable Firecrawl wrappers | Validate URLs before client creation for scrape/crawl/map operations. |
| `requirements.txt` / `requirements.lock` | Dependency policy and production resolution | Keep `pydantic-ai` on the supported v1 line unless a new migration spec owns v2. |
| `requirements-dev.txt` / `requirements-dev.lock` | Development/test resolution | Keep pytest plugins required by the checked-in test suite, including `pytest-httpx`. |
| `tests/conftest.py` / `pytest.ini` | Local pytest harness | Keep mocked provider credentials, registered markers, and live API skip policy explicit. |
| `docs/optional-integrations.md` | Isolated integration policy | Keep STORM/Reels exclusions documented if dependency conflicts remain. |

## Entrypoints

- `api/routers/personas.py`: validates AI runtime providers and starts persona draft jobs.
- `RepoUnderstandingService.understand(...)`: collects local repo, GitHub repo, or public site evidence.
- `RepoUnderstandingService._synthesize_understanding(...)`: calls `pydantic_ai_runtime.run_openrouter_structured(...)`.
- `ResearchAnalystAgent`: consumes shared Exa/Firecrawl tools.
- Exa/Firecrawl tool functions: can be selected by LLM agents and must fail closed on unsafe URLs.

## Control Flow

```text
persona draft request
  -> ai_runtime_service.preflight_providers(...)
  -> RepoUnderstandingService.collect source evidence
  -> pydantic_ai_runtime.resolve_openrouter_key(user_id, route="personas.draft")
  -> build OpenRouterProvider(api_key=<request-scoped key>)
  -> Agent(output_type=RepoUnderstandingResult).run(...)
  -> RepoUnderstandingResult with evidence attached
```

```text
LLM tool asks Exa/Firecrawl to fetch URL
  -> validate_public_http_url(...)
  -> reject unsafe URL before provider client creation
  -> create provider client from runtime provider context
  -> external provider call
```

## Invariants

- App-visible PydanticAI calls must not rely on ambient `OPENROUTER_API_KEY`.
- Direct `pydantic_ai` imports stay behind `api/services/pydantic_ai_runtime.py`.
- PydanticAI v1 result access uses `.output`, not legacy `.data`.
- Exa/Firecrawl URL-fetching wrappers validate URLs before creating provider clients.
- Public-site crawl paths must use normalized safe URLs after validation.
- Reels/STORM dependencies remain outside the default runtime while their resolver conflicts persist.

## Failure Modes

- Missing OpenRouter user credential: return the existing 409 AI runtime error envelope before model execution.
- Missing operator/platform provider secret: return the existing 503 operator-provider unavailable shape.
- Missing `pydantic-ai` import: raise `PydanticAIRuntimeError` from the adapter, not from routers.
- Unsafe URL: return an "Unsafe URL rejected" tool result and do not create Exa/Firecrawl clients.
- Optional Firecrawl unavailable for route preflight: exclude Firecrawl tools where that route already treats it as optional.

## Security Notes

- Never log decrypted provider credentials, API keys, auth headers, raw secrets, or full prompts that may contain secrets.
- Treat URL validation as a pre-provider SSRF guard, not as a complete network sandbox.
- DNS rebinding remains a future hardening risk; if direct HTTP fetching is added, revalidate resolved addresses immediately before the call.

## Validation

```bash
uv run --no-project --python 3.12 --with-requirements requirements-dev.lock python -m pytest \
  tests/test_dependency_policy.py \
  tests/test_url_safety.py \
  tests/test_external_url_tools_safety.py \
  tests/test_pydantic_ai_runtime.py \
  tests/test_persona_draft_route.py \
  tests/test_research_router.py \
  tests/agents/test_research_analyst.py

uv run --no-project --python 3.12 --with-requirements requirements-dev.lock python -m compileall -q api agents tests

python3 -m pip_audit -r requirements.lock --no-deps --disable-pip

uv run --no-project --python 3.12 --with-requirements requirements-dev.lock python -m pytest
```

The full local suite is expected to skip live API tests unless
`CONTENTGLOWS_LIVE_TEST_BASE_URL` or `http://localhost:8000` is reachable during
pytest collection. Those tests remain executable through their standalone
`--base-url` runners or by starting the API before pytest.

## Reader Checklist

- `pydantic_ai_runtime.py` changed -> verify adapter-only imports, explicit key use, `.output` result access, and targeted adapter tests.
- `repo_understanding_service.py` changed -> verify provider preflight semantics, GitHub/public-site source handling, safe URL usage, and persona draft tests.
- `url_safety.py` changed -> verify public/private DNS/IP cases and mixed-address rejection.
- `exa_tools.py` or `firecrawl_tools.py` changed -> verify unsafe URL tests prove no provider client creation.
- `requirements*.txt` or `requirements*.lock` changed -> verify dependency policy, `pip-audit`, and optional integration docs.
- `tests/conftest.py` or `pytest.ini` changed -> verify markers are registered, live API tests skip only when the API is unavailable, and full local pytest still runs.

## Maintenance Rule

Update this doc when AI runtime credential semantics, PydanticAI version range/API, repo-understanding source collection, Exa/Firecrawl URL policy, pytest harness behavior, or validation commands change.
