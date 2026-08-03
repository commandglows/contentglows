# Audit Log

| Date       | Scope        | Code | Design | Copy | SEO | GTM | Translate | Deps | Perf | Overall | Issues     |
|------------|--------------|------|--------|------|-----|-----|-----------|------|------|---------|------------|
| 2026-04-06 | SEO          | —    | —      | —    | C→B | —   | —         | —    | —    | C→B     | 4/6/5 (10 fixed) |
| 2026-04-06 | Copywriting  | —    | —      | D+   | —   | —   | —         | —    | —    | D+      | 4/4/3      |
| 2026-04-07 | Code         | C    | —      | —    | —   | —   | —         | —    | —    | C       | 4/6/8      |
| 2026-04-27 | full project | B | — | — | — | — | — | — | — | — | 0/1/3 |
| 2026-04-27 | dependencies | — | — | — | — | — | — | D | — | D | 1/2/2 (unpinned ranges + 58 ignored Safety findings) |
| 2026-04-27 | dependencies (fix pass) | — | — | — | — | — | — | B- | — | B- | 0/1/2 (ignored findings 58 -> 1; `pydantic-ai` major migration pending) |
| 2026-05-02 | dependencies (resolver conflict) | — | — | — | — | — | — | B- | — | B- | 0/1/3 (default resolver fixed; `pydantic-ai` CVE + lockfile/optional integrations pending) |
| 2026-05-03 | dependencies (risk closure) | — | — | — | — | — | — | A- | — | A- | 0/0/1 (`pip-audit` clean; lockfiles + PydanticAI adapter + URL safety added; license inventory pending) |
| 2026-05-03 | dependencies (license inventory) | — | — | — | — | — | — | A | — | A | 0/0/0 (283 production packages inventoried; 0 AGPL/SSPL/GPL-only blockers; `libsql` source license verified as MIT) |
| 2026-04-28 | monorepo code audit | B- | — | — | — | — | — | — | — | B- | 1/2/3 (publish now requires owned ContentRecord; account ownership decision remains) |
