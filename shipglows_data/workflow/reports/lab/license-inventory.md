# ContentGlowz Lab License Inventory

Date: 2026-05-03

Scope: production dependency graph from `requirements.lock` generated for Python 3.12.

Command used:

```bash
uv run --no-project --python 3.12 --with-requirements requirements.lock python -I <metadata script>
```

## Summary

- Production packages inventoried: 283 / 283 locked packages.
- Strong copyleft blockers found: 0.
- AGPL/SSPL packages found: 0.
- GPL-only blockers found: 0.
- Packages with empty PyPI license metadata reviewed from source: `crewai`, `libsql`, `mem0ai`, `mistralai`.
- Packages requiring normal notice/review if ContentGlowz is redistributed as a packaged/on-prem product: `certifi`, `docutils`, `orjson`, `pyphen`, `tqdm`.

For the current hosted SaaS/backend use case, the production dependency graph is acceptable from a dependency-license risk perspective. This is not legal advice; run a legal review before redistributing a packaged backend, shipping an on-prem edition, or publishing a bundled third-party notices file.

## Source-Verified Metadata Gaps

| Package | Locked version | PyPI metadata issue | Verified license | Source |
|---------|----------------|---------------------|------------------|--------|
| `crewai` | 1.6.1 | Empty license fields/classifiers | MIT | https://raw.githubusercontent.com/crewAIInc/crewAI/main/LICENSE |
| `libsql` | 0.1.11 | Empty license fields/classifiers | MIT | https://raw.githubusercontent.com/tursodatabase/libsql-python/main/LICENSE.md |
| `mem0ai` | 0.1.115 | Empty license fields/classifiers | Apache-2.0 | https://raw.githubusercontent.com/mem0ai/mem0/main/LICENSE |
| `mistralai` | 1.12.4 | Empty license fields/classifiers | Apache-2.0 | https://raw.githubusercontent.com/mistralai/client-python/main/LICENSE |

`libsql` was the specific unknown called out by the dependency audit. The package metadata is blank, but Turso's maintained Python binding and upstream libSQL repositories publish MIT license files.

## Mixed Or Weak-Copyleft Notices

| Package | Why flagged | Runtime path | Verdict |
|---------|-------------|--------------|---------|
| `pyphen` | GPL-2.0+ / LGPL-2.1+ / MPL-1.1 tri-license, including bundled dictionaries | Transitive via `textstat`, used by `agents/seo/tools/editing_tools.py`; code has an import fallback | Acceptable for hosted SaaS; review before redistribution/on-prem. |
| `docutils` | Metadata includes Public Domain, BSD, and GPL classifiers | Transitive via `rich-rst` -> `cyclopts` -> `fastmcp` | Not GPL-only; notice review if redistributing. |
| `certifi` | MPL-2.0 | TLS CA bundle dependency | Common weak-copyleft dependency; keep notice. |
| `orjson` | `MPL-2.0 AND (Apache-2.0 OR MIT)` | Transitive/runtime JSON dependency | Common mixed-license dependency; keep notice. |
| `tqdm` | `MPL-2.0 AND MIT` | Transitive utility dependency | Common mixed-license dependency; keep notice. |

No package in the production lock currently requires a migration spec solely for licensing. The only practical follow-up is to generate a full third-party notices file before any packaged distribution.
