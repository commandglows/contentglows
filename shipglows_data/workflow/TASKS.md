# Tasks — ContentGlows

## Priority Snapshot — 2026-07-12

### P0 — Do First

- [ ] Run the real-provider manual smoke for the dual-mode AI runtime, then complete final verify/end/ship (`Impact: High | Effort: Medium | Unblocks: production confidence for BYOK and platform AI modes`).

### P1 — High ROI

- Brand Studio: compléter la preuve authentifiée et la couverture widget avant la prochaine livraison.

### P2 — Upstream Watch

- [ ] Re-audit the Mem0/ChromaDB upstream situation when upstream support changes, then decide whether a dedicated worker or full CrewAI removal is justified (`Impact: Medium | Effort: Medium | Risk: dependency exposure remains in the optional path`).

### Notes

- Priority last updated: 2026-07-12.
- Criteria: balanced impact, security/blockers first, then high-ROI bounded work.
- The 103/104 project-memory chantier is verified and closed for bookkeeping; this ranking covers only the remaining dependency follow-up and automation.
- General production health does not close the dual-mode AI runtime chantier; provider-level smoke evidence is still required.

🟢 [app] task: Feed-native ready-made video review cards and publish preflight | status: done | area: feed-video-publish-preflight
🟢 [worker] task: `@google-cloud/storage` est mis a jour en `7.21.0` et la stack Remotion en `4.0.482`; `uuid` est force en `11.1.1` via l'override pnpm et `pnpm audit --prod` est propre | status: done | area: deps-security-storage
🟢 [worker] task: `packageManager` pnpm est fige sur les packages Node, `engines` Node/pnpm sont declares et Dependabot surveille maintenant `site`, `worker` et `github-actions` | status: done | area: deps-config-automation
🟢 [lab] task: `requirements.lock` / `requirements-dev.lock` sont regeneres avec `aiohttp 3.14.1`, `pydantic-ai 1.107.0`, `pyjwt 2.13.0`, `urllib3 2.7.0`, `starlette 1.3.1`, `idna 3.18` et `cryptography 48.0.1`; `pip-audit` ne remonte plus que `mem0ai` / `chromadb` | status: done | area: deps-security-lock-refresh
🟢 [lab] task: `mem0ai` retire du runtime par defaut; pile memoire deplacee dans `lab/requirements-memory.txt`, backend valide sans memoire, et `chromadb` documente comme residu transitif `crewai` | status: done | area: deps-runtime-exposure-review
🟠 [lab] task: Executer le smoke manuel avec de vrais credentials OpenRouter, Exa et Firecrawl en modes BYOK et platform, puis lancer verify/end/ship | status: in_progress | area: dual-mode-ai-runtime | spec: shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md
🟡 [lab] task: Re-auditer `lab/requirements-memory.txt` et le transitive `chromadb` de `crewai` quand un correctif upstream existe, puis decider reintroduction ou worker dedie | status: todo | area: deps-memory-upstream-watch
🟢 [lab] task: Ajouter une automation Dependabot pour `pip` et documenter la politique de revue des mises a jour backend | status: done | area: deps-automation
🟢 [lab] task: Composio retire du runtime et du backend newsletter; IMAP devient le seul chemin email | status: done | area: deps-composio-removal
🟠 [app] task: Vérifier dans un workspace de test authentifié le flux persona → contenu → Studio de marque, y compris persona supprimée, choix de logo et prérequis blueprint sans lancer de rendu | status: todo | area: brand-studio-persona-content-context | spec: shipglows_data/workflow/specs/app/SPEC-brand-studio-persona-content-context-2026-08-05.md | dependencies: authenticated-test-workspace\, deployed-app-target
🟡 [app] task: Ajouter des tests widget pour le préflight de prévisualisation vidéo et l'état persona indisponible du Studio de marque | status: todo | area: brand-studio-persona-content-context | spec: shipglows_data/workflow/specs/app/SPEC-brand-studio-persona-content-context-2026-08-05.md
🟡 [app] task: Ajouter le test de non-régression qui garantit `generateBrandedVideoFromContent` utilisé depuis feed + content detail dans le même payload | status: todo | area: branding-canonical-path | spec: shipglows_data/workflow/specs/app/SPEC-brand-studio-persona-content-context-2026-08-05.md
🟡 [app] task: Ajouter le test de flux canoniques end-to-end: génération auto -> `/editor/:id/video` -> gate de publish sans route secondaire | status: todo | area: branding-canonical-path | spec: shipglows_data/workflow/specs/app/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md
🟢 [lab] task: Valider en smoke test backend que les réponses de branded-generation exposent `brand_template_id` et `brand_template_revision` sur preview/final success | status: done | area: branded-video-pipeline | spec: shipglows_data/workflow/specs/lab/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md
