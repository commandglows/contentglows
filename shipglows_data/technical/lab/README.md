---
artifact: technical_docs_index
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: lab
created: "2026-05-04"
updated: "2026-05-04"
status: draft
source_skill: sf-build
scope: technical-docs
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - api/
  - agents/
  - requirements.lock
  - shipglows_data/technical/platforms/crewai.md
depends_on: []
supersedes: []
evidence:
  - "sf-build resumed SPEC-migrate-pydantic-ai-major.md and found no technical docs map."
  - "CrewAI governance-root usage note added because CrewAI is core backend orchestration infrastructure."
next_review: "2026-06-04"
next_step: "/sf-docs technical audit lab"
---

# Technical Docs

This directory maps code areas that need durable technical context before future ShipGlowz edits.

Start with `code-docs-map.md`. Load only the mapped module context for the files being changed.

## Current Coverage

- `ai-runtime-and-url-safety.md`: PydanticAI adapter, BYOK OpenRouter key resolution, repo understanding synthesis, and URL safety for Exa/Firecrawl.
- `agent-pipelines.md`: durable boundary for historical `agents/*` local READMEs and current pipeline documentation ownership.
- `backend-runtime-and-product-apis.md`: backend runtime notes, public/product API contracts, project intelligence, asset library, video timeline, render artifacts, GSC OAuth, image generation, and project selection.
- `testing.md`: stable backend testing contract and migration target for stale local test-framework prose.
- `../platforms/crewai.md`: CrewAI version policy, request-scoped LLM routing, agent/tool boundaries, structured outputs, and migration risks for `lab`.

## Maintenance Rule

Update this index and `code-docs-map.md` when a new backend subsystem gets a technical module context or when mapped files move.
