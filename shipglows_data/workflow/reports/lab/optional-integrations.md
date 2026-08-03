# Optional Integrations

ContentGlowz Lab keeps the default FastAPI/AI runtime install focused on the core dependency graph in `requirements.lock`.

## Composio

- Removed from the default runtime on 2026-07-13.
- The former newsletter adapter used the legacy `ComposioToolSet` / `Action` API.
- The current `composio-crewai` provider line is not compatible with ContentGlowz's CrewAI 1.6 runtime.
- Newsletter email intake uses direct IMAP. Reintroducing a managed email integration requires a dedicated compatibility, authentication, tenant-scoping, and product-value review.

## Reels / Instagram

`instagrapi` is intentionally excluded from the default runtime. Current releases pin `pydantic` and/or `requests` versions that conflict with the core AI stack and the requests security floor.

Strategy:

- Do not add `instagrapi` to `requirements.txt` or `requirements.lock`.
- If Reels remains product-critical, run it as an isolated worker/service with its own virtual environment and dependency lock.
- Keep the API boundary narrow: upload cookies, request download/transcode, return media metadata/CDN URLs.
- The core FastAPI runtime must keep returning `503` for Reels operations that need the Instagram client when the isolated integration is unavailable.

## STORM Research

`knowledge-storm` is intentionally excluded from the default runtime. Current compatible releases pull older `dspy`/OpenAI/LiteLLM constraints that conflict with the LiteLLM security floor.

Strategy:

- Do not add `knowledge-storm` to `requirements.txt` or `requirements.lock`.
- Prefer replacing STORM-style article research with the existing CrewAI/PydanticAI typed research flow over reintroducing the dependency.
- If a true STORM flow is required, run it as a separate offline research worker with a dedicated lockfile and no shared process with the core API.

## Semantic Memory

`mem0ai` and its local `chromadb` path are intentionally excluded from the default runtime. Current upstream releases still carry unresolved advisories, while the backend already handles memory as an optional capability. `chromadb` may still appear transitively through `crewai`, but there is no direct application import path for it outside the optional memory stack.

Strategy:

- Do not add `mem0ai` back to `requirements.txt` or `requirements.lock` until upstream fixes land and are re-audited.
- Install `lab/requirements-memory.txt` only in isolated or explicitly optional environments that need semantic memory.
- Keep API and agent flows resilient when memory is absent; missing memory should degrade to reduced context, not startup failure.
- If memory becomes product-critical, move it into a separate worker/service with its own lockfile and failure boundary instead of sharing the core API runtime.
- Track the residual `chromadb` vulnerability as a `crewai` transitive; do not add direct `chromadb` imports or config coupling on the core API path.

## Operational Rule

Optional integration workers may depend on packages that are incompatible with the core API only when they are isolated by process, lockfile, deployment unit, secrets, and failure envelope.
