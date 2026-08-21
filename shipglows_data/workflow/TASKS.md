# Tasks — ContentGlows

## Priority Snapshot — 2026-08-20

### P0 — Do First

- [ ] Restore the production deployment of `app.contentglows.com`: the repository and app source use `ContentGlows`, but the 2026-08-19 Vercel app build failed and production still serves the legacy `ContentGlowz` build (`Impact: Critical | Effort: Unknown until authenticated Vercel logs are available | Type: external deployment blocker`).
- [ ] Run the real-provider manual smoke for the dual-mode AI runtime, then complete final verify/end/ship (`Impact: High | Effort: Medium | Type: external provider proof | Unblocks: production confidence for BYOK and platform AI modes`).

### P1 — High ROI

- [x] Add the missing Brand Studio widget coverage for linked/unavailable personas and preview preflight states (`Impact: High | Effort: Low | Type: code-authored; execution deferred by no-local-build policy`).
- [x] Add canonical video-path regression coverage for API payload integrity, feed/content-detail convergence, timeline loading, and publish gating without last-minute regeneration (`Impact: High | Effort: Low | Type: code-authored; execution deferred by no-local-build policy`).
- [x] Complete Task 1 of the AI usage/quota foundation: typed domain models and validation tests, without checkout, prices, migrations, persistence, routes, or provider calls (`Impact: High | Effort: Low | Type: code-authored; execution deferred by no-local-build policy`).
- [x] Complete Task 2 of the AI usage/quota foundation: persistence-agnostic store contract, injected-client libSQL adapter, tenant-scoped durable tables, and reusable adapter-contract tests (`Impact: High | Effort: Medium | Type: implemented — unverified`).
- [x] Complete Task 3 of the AI usage/quota foundation: storage-agnostic preflight and reconciliation service, transactional compare-and-set reservations, concurrency protection, idempotent settlement, and stale expiry (`Impact: High | Effort: Medium | Type: implemented — unverified`).
- [x] Complete Task 4 of the AI usage/quota foundation: injected action-policy registry with internal usage-unit estimates, managed/BYOK invariants, provider routing, failure behavior, and override eligibility without public pricing (`Impact: High | Effort: Low | Type: implemented — unverified`).
- [x] Complete Task 5 of the AI usage/quota foundation: owner-scoped Flux reservation before queue/provider work, structured quota blocks, reservation linkage, lazy runtime composition, and pre-queue release (`Impact: High | Effort: Medium | Type: implemented — unverified`).
- [x] Complete Task 6 of the AI usage/quota foundation: normalize BFL provider-credit cost, megapixels, request identity and timing without currency conversion or public pricing (`Impact: High | Effort: Low | Type: implemented — unverified`).
- [x] Author the exhaustive app/site design-token migration, preserve documented media/platform/data exceptions, and reconcile the canonical design documentation; execution and visual proof remain deferred while design-drift enforcement stays owned centrally by ShipGlows (`Impact: High | Effort: Medium | Type: implemented — unverified`).
- [ ] Complete authenticated Brand Studio proof once a working deployed app target is available (`Impact: High | Effort: Medium | Type: external proof | Blocked by: app production deployment`).
- [ ] Prepare a dedicated commercial/checkout contract before implementing Polar billing; the ready AI quota spec explicitly excludes checkout, invoices, taxes, and public prices (`Impact: High | Effort: Medium | Type: product/spec dependency, not code-ready`).

### P2 — Upstream Watch

- [ ] Re-audit the Mem0/ChromaDB upstream situation when upstream support changes, then decide whether a dedicated worker or full CrewAI removal is justified (`Impact: Medium | Effort: Medium | Risk: dependency exposure remains in the optional path`).

### Notes

- Priority last updated: 2026-08-20 from repository, spec-flow, production, and tracker evidence.
- Criteria: balanced impact, security/blockers first, then high-ROI bounded work.
- The 103/104 project-memory chantier is verified and closed for bookkeeping; this ranking covers only the remaining dependency follow-up and automation.
- General production health does not close the dual-mode AI runtime chantier; provider-level smoke evidence is still required.
- `SPEC-content-editor-multiformat` is implemented and verified; it is no longer an implementation priority, although lifecycle closure/ship bookkeeping remains pending.
- Structured audit actors are already rendered in the editor audit panel and included in copied audit trails; the previous P1 wording was stale.
- Code-ready work, external proof, deployment blockers, and product/spec dependencies are kept separate so “next P0/P1” does not route into an unavailable account or an undefined commercial contract.

🟢 [app] task: Feed-native ready-made video review cards and publish preflight | status: done | area: feed-video-publish-preflight
🟢 [worker] task: `@google-cloud/storage` est mis a jour en `7.21.0` et la stack Remotion en `4.0.482`; `uuid` est force en `11.1.1` via l'override pnpm et `pnpm audit --prod` est propre | status: done | area: deps-security-storage
🟢 [worker] task: `packageManager` pnpm est fige sur les packages Node, `engines` Node/pnpm sont declares et Dependabot surveille maintenant `site`, `worker` et `github-actions` | status: done | area: deps-config-automation
🟢 [lab] task: `requirements.lock` / `requirements-dev.lock` sont regeneres avec `aiohttp 3.14.1`, `pydantic-ai 1.107.0`, `pyjwt 2.13.0`, `urllib3 2.7.0`, `starlette 1.3.1`, `idna 3.18` et `cryptography 48.0.1`; `pip-audit` ne remonte plus que `mem0ai` / `chromadb` | status: done | area: deps-security-lock-refresh
🟢 [lab] task: `mem0ai` retire du runtime par defaut; pile memoire deplacee dans `lab/requirements-memory.txt`, backend valide sans memoire, et `chromadb` documente comme residu transitif `crewai` | status: done | area: deps-runtime-exposure-review
🟠 [lab] task: Executer le smoke manuel avec de vrais credentials OpenRouter, Exa et Firecrawl en modes BYOK et platform, puis lancer verify/end/ship | status: in_progress | area: dual-mode-ai-runtime | spec: shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md
🟡 [lab] task: Re-auditer `lab/requirements-memory.txt` et le transitive `chromadb` de `crewai` quand un correctif upstream existe, puis decider reintroduction ou worker dedie | status: todo | area: deps-memory-upstream-watch
🟢 [lab] task: Ajouter une automation Dependabot pour `pip` et documenter la politique de revue des mises a jour backend | status: done | area: deps-automation
🟢 [lab] task: Composio retire du runtime et du backend newsletter; IMAP devient le seul chemin email | status: done | area: deps-composio-removal
🟢 [lab] task: Définir les modèles typés usage/quota IA et leurs contrats de validation pour managed/BYOK, réservations, ledger, statuts, erreurs et coûts provider | status: done-code-authored-validation-deferred | area: ai-generation-quotas-billing | spec: shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md
🟢 [lab] task: Définir un store usage/quota agnostique, son adaptateur libSQL injecté et une suite contractuelle réutilisable couvrant isolation, idempotence, coûts provider et ajustements admin | status: done-code-authored-validation-deferred | area: ai-generation-quotas-billing | spec: shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md
🟢 [lab] task: Ajouter le préflight et la réconciliation quota agnostiques avec réservation transactionnelle compare-and-set, concurrence sans double dépense, transitions idempotentes et expiration des réservations | status: done-code-authored-validation-deferred | area: ai-generation-quotas-billing | spec: shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md
🟢 [lab] task: Définir des politiques d'action injectées et agnostiques couvrant unités internes estimées, provider/modèle, hard block, échec provider et éligibilité override sans prix public | status: done-code-authored-validation-deferred | area: ai-generation-quotas-billing | spec: shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md
🟢 [lab] task: Bloquer Flux avant toute dépense provider via une réservation owner-scoped, lier reservation/job/génération et libérer les unités en cas d'échec avant queue | status: done-code-authored-validation-deferred | area: ai-generation-quotas-billing | spec: shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md
🟢 [lab] task: Normaliser les preuves de coût BFL en crédits provider avec mégapixels, request id, timings UTC et état inconnu sans conversion monétaire | status: done-code-authored-validation-deferred | area: ai-generation-quotas-billing | spec: shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md
🟠 [app] task: Vérifier dans un workspace de test authentifié le flux persona → contenu → Studio de marque, y compris persona supprimée, choix de logo et prérequis blueprint sans lancer de rendu | status: todo | area: brand-studio-persona-content-context | spec: shipglows_data/workflow/specs/app/SPEC-brand-studio-persona-content-context-2026-08-05.md | dependencies: authenticated-test-workspace\, deployed-app-target
🟢 [app] task: Ajouter des tests widget pour la persona liée/indisponible et le préflight de prévisualisation vidéo du Studio de marque | status: done-code-authored-validation-deferred | area: brand-studio-persona-content-context | spec: shipglows_data/workflow/specs/app/SPEC-brand-studio-persona-content-context-2026-08-05.md
🟢 [app] task: Garantir par tests le payload canonique, la convergence feed/détail vers `/editor/:id/video`, le chargement timeline et le gate de publish sans régénération tardive | status: done-code-authored-validation-deferred | area: branding-canonical-path | spec: shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md
🟢 [lab] task: Valider en smoke test backend que les réponses de branded-generation exposent `brand_template_id` et `brand_template_revision` sur preview/final success | status: done | area: branded-video-pipeline | spec: shipglows_data/workflow/specs/lab/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md
🔴 [ContentGlows] task: Restore the app production deployment so app.contentglows.com serves ContentGlows instead of the legacy ContentGlowz build | status: blocked | area: app-production-branding | spec: shipglows_data/workflow/specs/monorepo/renommage-contentglows-monorepo-2026-05-14.md | dependencies: authenticated-vercel-logs
