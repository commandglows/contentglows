# ContentGlows Lab

Backend platform for ContentGlows.

This root README is now an entrypoint, not the canonical technical source of truth.

## Canonical Docs

- Technical index: `shipglows_data/technical/lab/README.md`
- Architecture: `shipglows_data/technical/lab/architecture.md`
- Context: `shipglows_data/technical/lab/context.md`
- Workflow backlog: `shipglows_data/workflow/lab/TASKS.md`
- QA log: `shipglows_data/workflow/qa/TEST_LOG.md`

## Quick Start

1. `pip install -r requirements.lock`
2. `doppler setup`
3. `doppler run -- uvicorn api.main:app --reload --port 8000`
4. `curl http://localhost:8000/health`

## Project Intelligence Generation Context

Newsletter and psychology generation use the relational Project Intelligence
generation context. Startup calls `ProjectIntelligenceStore.ensure_tables()`,
which idempotently creates the source/document/chunk/fact/recommendation tables
plus generation context logs and generation signals.

There is no optional project-memory install path. `chromadb` may still appear in
`requirements.lock` as a CrewAI transitive residual; it is not used by
ContentGlows project memory.

Useful local checks:

- `pytest lab/tests/test_project_generation_context_builder.py lab/tests/test_project_generation_context_store.py`
- `pytest lab/tests/test_newsletter_generation_context.py lab/tests/test_psychology_generation_context.py`
- `rg -n "mem0ai|from memory|import memory|get_memory_service|chromadb" lab --glob "*.py"`

## Rule

If a local `lab/*` doc and a `shipglows_data/*` doc disagree, treat `shipglows_data/*` as canonical and reduce the local file instead of expanding it.
