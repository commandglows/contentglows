---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: contentglows
created: "2026-05-24"
updated: "2026-05-24"
status: draft
source_skill: sf-docs
scope: platform-usage-crewai
owner: Diane
confidence: high
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - shipglows_data/technical/lab/code-docs-map.md
  - shipglows_data/technical/lab/ai-runtime-and-url-safety.md
  - lab/requirements.txt
  - lab/api/services/user_llm_service.py
  - lab/agents/
depends_on:
  - artifact: "shipglows_data/technical/external-platforms/crewai.md"
    artifact_version: "0.1.0"
    required_status: "draft"
supersedes: []
evidence:
  - "lab/requirements.txt pins crewai>=1.6.1,<1.7 and notes newer CrewAI 1.14.x requires openai>=2.30."
  - "lab imports CrewAI Agent, Task, Crew, Process, LLM, and @tool wrappers across SEO, psychology, newsletter, social, short, scheduler, and shared tools."
  - "ContentGlows App references CrewAI as backend-owned; CrewAI usage belongs to the lab/backend surface."
next_review: "2026-06-24"
next_step: "/sf-docs technical audit lab"
---

# CrewAI Usage

## Purpose

Document how the ContentGlows monorepo uses CrewAI. This is the governance-root usage contract for the backend agent runtime, scoped primarily to `lab/`.

Use the global CrewAI note for current source links and release behavior:

- `/home/claude/shipglowz/shipglows_data/technical/external-platforms/crewai.md`

## Usage Summary

- Provider role: backend multi-agent orchestration for SEO, psychology, newsletter, short content, social posts, scheduler tooling, and shared research tools.
- Applies to paths: `lab/agents/**`, `lab/api/routers/**`, `lab/api/services/user_llm_service.py`, `lab/requirements*.txt`.
- Environments used: local Python backend runtime, test runtime, deployed FastAPI backend when agent routes are enabled.
- Validation surface: dependency policy, import/compile checks, focused agent tests, URL-safety tests for LLM-callable tools, API route tests, and live-provider smoke only when credentials are intentionally available.
- Owner: Diane.
- Last verified: 2026-05-24 by local documentation audit and official CrewAI source review, without runtime agent execution.

## Local Configuration

| Item | Value or rule | Secret? | Notes |
| --- | --- | --- | --- |
| Runtime dependency | `crewai>=1.6.1,<1.7` | no | Intentional older pin; do not upgrade casually to 1.14.x without migration work. |
| Python support | project Python runtime from backend env | no | CrewAI 1.14.5 currently requires Python `>=3.10,<3.14`; verify before upgrades. |
| LLM bridge | `user_llm_service.get_crewai_llm(...)` | no | Builds request-scoped CrewAI `LLM` with user OpenRouter key. |
| Model gateway | OpenRouter via LiteLLM/CrewAI | credentials | Keys are resolved per request; never record values. |
| Tool wrappers | `@tool` functions under `agents/**/tools/**` and `agents/shared/tools/**` | mixed | Treat web fetch, email, publishing, storage, and MCP-style tools as high risk. |
| Structured outputs | `output_pydantic` in SEO crew tasks | no | Version-sensitive CrewAI behavior; keep regression coverage. |
| Memory | Project Intelligence context is injected before CrewAI runs; `chromadb` may remain transitively via CrewAI | potential user data | Do not enable CrewAI persistent memory. Keep project context canonical in Project Intelligence relational rows. |
| Observability | Sentry/logging plus optional CrewAI tracing if configured | potential sensitive data | Redact prompts, tool inputs, user content, and provider errors. |

## Runtime And Integration Notes

- `api/services/user_llm_service.py` is the request-scoped LLM boundary for CrewAI. App-visible flows should obtain a user OpenRouter key through `ai_runtime_service.preflight_providers(...)`, then construct CrewAI `LLM` with explicit `base_url`, `api_key`, `temperature`, and optional `max_tokens`.
- `agents/seo/seo_crew.py` runs a unified six-agent SEO crew with `Process.sequential` and task-level Pydantic output schemas.
- Several individual agents still create one-agent crews with `Crew(...).kickoff()`. Do not refactor these patterns without checking current CrewAI docs and local tests.
- Shared Exa and Firecrawl tools are LLM-callable. URL safety must run before provider client creation, as documented in `shipglows_data/technical/lab/ai-runtime-and-url-safety.md`.
- ContentGlows App should not own a CrewAI usage note. The Flutter app calls backend APIs; CrewAI orchestration is backend-owned by `lab`.

## Invariants

- CrewAI flows must use explicit request-scoped provider credentials for app-visible user actions.
- Agent tools that fetch external URLs must fail closed on unsafe URLs before creating provider clients.
- CrewAI dependency upgrades require `sf-deps` or `sf-migrate` because CrewAI 1.14.x has different dependency constraints than the current local pin.
- Do not introduce ambient `OPENROUTER_API_KEY` fallback for user-visible CrewAI routes unless a spec explicitly changes the credential model.
- Do not persist CrewAI memory, knowledge, traces, raw prompts, or tool inputs containing user data without a documented retention and deletion policy.
- Keep CrewAI and PydanticAI imports explicit; both ecosystems expose agent concepts and can be confused during migrations.

## Failure Modes

- CrewAI import fails -> check `requirements.txt`, lockfile/install environment, Python version, and optional extras before editing agents.
- New CrewAI release appears attractive -> compare against local OpenAI/LiteLLM/Pydantic constraints and run dependency/security checks before changing the pin.
- Agent output is invalid JSON or raw text -> preserve readable fallback behavior and add regression tests before relying on structured output.
- Tool calls unsafe URL or private network target -> return a safe tool failure; do not create Exa/Firecrawl clients.
- Missing user OpenRouter key -> keep the existing 409 AI runtime error envelope before CrewAI execution.
- Provider/runtime unavailable -> fail with route-specific structured errors, not raw stack traces or leaked provider details.

## Security Notes

- Do not store OpenRouter keys, provider tokens, raw prompts, raw user content, cookies, OAuth credentials, tool inputs, or private provider logs in docs.
- Treat CrewAI tools as privileged capabilities. Publishing, email, web fetch, storage, and external API tools need explicit validation and user/provider scoping.
- Treat memory and traces as potentially sensitive because they may contain prompts, user content, derived strategy, or tool arguments.
- Treat dependency upgrades as supply-chain sensitive. CrewAI pulls AI/provider/tooling dependencies and may affect OpenAI, LiteLLM, Pydantic, telemetry, or Python version support.

## Validation

For documentation-only changes:

```bash
python3 /home/claude/shipglowz/tools/shipglowz_metadata_lint.py shipglows_data/technical/platforms/crewai.md
rg -n "CrewAI|Validation|Maintenance Rule|request-scoped|output_pydantic" shipglows_data/technical/platforms/crewai.md
```

For code or dependency changes touching CrewAI:

```bash
uv run --no-project --python 3.12 --with-requirements requirements-dev.lock python -m compileall -q api agents tests
uv run --no-project --python 3.12 --with-requirements requirements-dev.lock python -m pytest \
  tests/test_dependency_policy.py \
  tests/test_external_url_tools_safety.py \
  tests/test_pydantic_ai_runtime.py \
  tests/agents/test_research_analyst.py
python3 -m pip_audit -r requirements.lock --no-deps --disable-pip
```

Run live-provider or full agent smoke tests only when the needed user/provider credentials are intentionally available and safe to use.

## Reader Checklist

- `lab/requirements*.txt` or lockfiles changed -> check CrewAI, OpenAI, LiteLLM, Pydantic, Python version, and security advisory impact.
- `api/services/user_llm_service.py` changed -> verify request-scoped CrewAI `LLM` construction and no ambient key fallback.
- `agents/**` changed and imports CrewAI -> check current global CrewAI note and this usage note.
- `agents/shared/tools/exa_tools.py` or `agents/shared/tools/firecrawl_tools.py` changed -> verify URL safety and provider client creation order.
- `output_pydantic`, JSON parsing, fallback parsing, or schema files changed -> run structured-output tests.
- Memory, knowledge, tracing, callbacks, or observability changed -> document retention, redaction, and tenancy assumptions before shipping.

## Maintenance Rule

Update this note when CrewAI version constraints, agent entrypoints, LLM/provider routing, tool exposure, memory/knowledge/tracing behavior, structured output handling, validation commands, or security assumptions change.
