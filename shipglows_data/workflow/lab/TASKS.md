# ContentGlows Lab — Tasks

## Documentation Migration (2026-06-29)

### Done

- [x] Reclassify `lab/tasks.md` as a deprecated local façade and move canonical backlog ownership to `shipglows_data/workflow/lab/TASKS.md`.
- [x] Reclassify `lab/TEST_LOG.md` as a deprecated local façade and merge retained QA entries into `shipglows_data/workflow/qa/TEST_LOG.md`.
- [x] Create canonical technical docs for testing and historical agent/pipeline documentation under `shipglows_data/technical/lab/`.
- [x] Reduce local `lab/tests/README.md`, `lab/agents/seo/README.md`, and `lab/agents/scheduler/README.md` to migration pointers.
- [x] Consolidate important former `lab/README.md` backend contracts into `shipglows_data/technical/lab/backend-runtime-and-product-apis.md`.
- [x] Restore planning items that had only existed in deprecated `lab/tasks.md` into canonical workflow tracking or canonical research notes.

### Next

- [ ] Reduce `lab/README.md`, `lab/AGENT.md`, and `lab/CLAUDE.md` further if duplicate operational detail drifts again from `shipglows_data/technical/lab/*`.
- [ ] Decide whether the monorepo should keep one shared `shipglows_data/workflow/TASKS.md` in addition to surface-scoped trackers, or keep `shipglows_data/workflow/<surface>/TASKS.md` as the working pattern.

### Recovered From Deprecated `lab/tasks.md`

These items were present in the local `lab/tasks.md` before it was converted to a façade. They were not deleted; they are retained here with ownership still to confirm.

- [ ] Connect frontmatter audit actions (`audit`/`dry-run`/`autofix`) to an explicit confirmation modal before `autofix`.
- [ ] Add an optional commit message input in `Grow -> Strategy` for grouped autofix commits.
- [x] Define repository content containers per project using registered `Content Sources`.
- [x] Scope Strategy analytics by `projectId` to avoid cross-project cluster/funnel contamination.
- [x] Add frontmatter governance flow in `Grow -> Strategy`: audit, dry-run, autofix with grouped commits per `repo@branch`, and JSON/CSV report export.
- [ ] Add scheduled frontmatter audit job, nightly per project.
- [ ] Add policy presets for required canonical fields by project type: blog, docs, mixed.

### Filmora Parity Roadmap

Research source: `shipglows_data/workflow/research/filmora-gap-analysis-2026-06-29.md`.

- [ ] Strengthen the timeline editor UX: ripple trim, split, duplicate, snap, zoom, playhead scrubbing, undo/redo, keyboard shortcuts, and clearer track locking/muting semantics.
- [ ] Add a property animation system for timeline clips with keyframes on transform, opacity, scale, rotation, crop, blur, and volume, then expose easing curves and a graph editor.
- [ ] Introduce reusable adjustment layers and clip-level effect stacks.
- [ ] Ship transcript-native editing: speech-to-text, editable transcript segments, text-based cuts, silence detection, and timeline export from transcript edits.
- [ ] Build a caption pipeline with auto captions, timing edits, multilingual translation, style presets, burned-in vs sidecar outputs, and project-level caption reuse.
- [ ] Add audio finishing tools: normalization, denoise, ducking, fade handles, beat sync, audio meters, and music/voice balance presets.
- [ ] Add motion tools: motion tracking, planar/smart masking, subject linking, picture-in-picture controls, and freeze-frame workflows.
- [ ] Add pro color controls: LUTs, color wheels, curves/HSL, scopes, comparison view, and reusable look presets.
- [ ] Implement multicam workflows with sync by waveform/markers, angle switching in preview, and automatic camera-cut generation.
- [ ] Add short-form automation: smart scene cut, highlight extraction, auto reframe, and candidate short clips generated from long-form source content.
- [ ] Add a live retake recording mode inspired by Vento: pause, rewind a few seconds, and re-record over mistakes without restarting the whole take.
- [ ] Turn ContentGlows strategy context into editing assistance: AI copilot suggestions for hooks, scene ordering, B-roll slots, text overlays, CTA placement, and per-platform pacing.
- [ ] Create reusable templates and presets for video formats, titles, lower thirds, intros/outros, caption styles, and project-scoped brand kits.
- [ ] Upgrade preview/render confidence: background queues, stale-preview states, proxy previews, deterministic cache invalidation, and recovery after failed renders.
- [ ] Expand export/publish readiness with platform presets, ratio/duration/safe-zone validation, thumbnail/cover packaging, and final asset bundles per channel.
- [ ] Add asset provenance and library controls: trusted media intake, search/filter/tagging, usage history, licensing metadata, and safe replacement across versions.
- [ ] Instrument performance and quality at editor scale: preview FPS, render timings, memory pressure, queue latency, crash recovery, and project health diagnostics for heavy timelines.

### PixVerse Parity Roadmap

Research source: fresh official PixVerse product/docs pages checked 2026-06-30.

- [ ] Add AI video generation entry points for text-to-video and image-to-video, with template-driven creation flows and clear model selection.
- [ ] Introduce short-form generation controls for duration, aspect ratio, resolution, and native audio so creator outputs are predictable for social formats.
- [ ] Build reference-driven generation: character/reference assets, style references, and multi-frame or multi-shot continuity controls.
- [ ] Add a guided "video agent" workflow that turns a rough idea into prompts, scene structure, and a draft storyboard before generation.
- [ ] Support remix/modify workflows for existing clips, including add/replace/remove/transform operations on generated or imported video.
- [ ] Expose trend-oriented effect packs and reusable presets so the app can ship fast, viral-style variations without custom prompt work every time.
- [ ] Add asset management for generated clips, prompt history, reference images, and versioned outputs so iterations remain auditable.
- [ ] Support API/CLI-friendly generation paths for automation, batch creation, and agent-driven media workflows.
- [ ] Connect generation outputs to the editor timeline so AI clips can become governed project assets instead of isolated exports.

### Priority Slices

Direction produit retenue le 2026-07-04:

Spec source: `shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md`.

- [ ] Make AI-first branded video assembly the default workflow: users provide images/videos/content inputs, ContentGlows generates a finished video draft automatically, and manual editing stays optional.
- [ ] Add a canonical brand-to-video system: one brand profile should drive templates, scene sequencing, motion rules, transitions, typography, overlays, CTA blocks, caption style, and export defaults.
- [ ] Add a dedicated branding editor surface so users can tune brand kits, template rules, animation language, and reusable video systems separately from one-off timeline edits.
- [x] Review product/docs promise alignment because current docs still frame ContentGlows as human-in-the-loop and not fully automated; update canonical product language if this AI-first direction is adopted.
- [x] Persist ahead-of-time branded-video generation runs and expose feed readiness states (`ready_to_publish`, `preparing`, `blocked`) with scheduler handoff and idempotent reuse; targeted backend and Flutter verification passed 2026-07-11.

#### P0 — editor core and trust

- [ ] Define the "brand video blueprint" schema that maps brand kit inputs to layouts, typography, color usage, transitions, motion presets, lower thirds, intro/outro blocks, and safe CTA patterns.
- [ ] Build automatic timeline/story assembly from source content plus selected media assets, so the first output is a complete branded draft rather than an empty editor.
- [ ] Ship timeline ergonomics: ripple trim, split, duplicate, snap, zoom, playhead scrubbing, undo/redo, keyboard shortcuts, and track locking/muting semantics.
- [ ] Add preview/render confidence: stale-preview states, background queues, proxy previews, deterministic cache invalidation, and recovery after failed renders.
- [ ] Introduce reusable adjustment layers and clip-level effect stacks.
- [ ] Add property animation with keyframes plus easing/graph editing for transform, opacity, scale, rotation, crop, blur, and volume.
- [ ] Create reusable templates and presets for video formats, titles, lower thirds, intros/outros, caption styles, and project-scoped brand kits.
- [x] Add a lightweight branding editor MVP for fonts, colors, logo treatments, caption style, intro/outro modules, transition family, and motion intensity. Brand-profile editor and canonical preview are verified; hosted/device proof remains.

#### P1 — transcript, audio, and creator automation

- [ ] Ship transcript-native editing: speech-to-text, editable transcript segments, text-based cuts, silence detection, and timeline export from transcript edits.
- [ ] Build a caption pipeline with auto captions, timing edits, multilingual translation, style presets, burned-in vs sidecar outputs, and project-level caption reuse.
- [ ] Add audio finishing tools: normalization, denoise, ducking, fade handles, beat sync, audio meters, and music/voice balance presets.
- [ ] Add recording-session structure tools: rewind checkpoints, quick alternate takes from the last checkpoint, chapter markers, and post-record author annotations for async viewing.
- [ ] Add short-form automation: smart scene cut, highlight extraction, auto reframe, and candidate short clips generated from long-form source content.
- [ ] Turn ContentGlows strategy context into editing assistance: AI copilot suggestions for hooks, scene ordering, B-roll slots, text overlays, CTA placement, and per-platform pacing.
- [ ] Let users edit generated videos indirectly through brand rules: changing a brand preset should update future drafts and offer controlled regeneration of existing videos.
- [ ] Add per-brand video archetypes such as testimonial, product demo, UGC ad, talking-head highlight, faceless reel, and recap, each with default pacing and scene grammar.

#### P2 — generation, tracking, and scale

- [ ] Add AI video generation entry points for text-to-video and image-to-video, with template-driven creation flows and clear model selection.
- [ ] Build reference-driven generation: character/reference assets, style references, and multi-frame or multi-shot continuity controls.
- [ ] Add a guided "video agent" workflow that turns a rough idea into prompts, scene structure, and a draft storyboard before generation.
- [ ] Support remix/modify workflows for existing clips, including add/replace/remove/transform operations on generated or imported video.
- [ ] Implement multicam workflows with sync by waveform/markers, angle switching in preview, and automatic camera-cut generation.
- [ ] Add motion tools: motion tracking, planar/smart masking, subject linking, picture-in-picture controls, and freeze-frame workflows.
- [ ] Add pro color controls: LUTs, color wheels, curves/HSL, scopes, comparison view, and reusable look presets.
- [ ] Add asset provenance and library controls: trusted media intake, search/filter/tagging, usage history, licensing metadata, and safe replacement across versions.
- [ ] Instrument performance and quality at editor scale: preview FPS, render timings, memory pressure, queue latency, crash recovery, and project health diagnostics for heavy timelines.
- [ ] Add regenerate-with-constraints workflows so users can ask AI for a new cut while preserving selected brand rules, locked scenes, chosen assets, or caption timing.

## Completed

| Task | Status |
|------|--------|
| Social Listener — multi-platform ingestion (Reddit, X, HN, YouTube) | Done |
| Content Quality Scoring — textstat integration + fix broken Flesch | Done |
| OG Preview service — OpenGraph extraction for link previews | Done |
| Social Listener spec — `shipglows_data/workflow/specs/lab/social-listener.md` | Done |
| Production API publish — expose backend on `api.winflowz.com` via Caddy + PM2 | Done |
| Turso production connectivity — replace deprecated `libsql-client`, restore DB health to operational | Done |
| Branding alignment — rename ContentGlowsz defaults, paths, domains, and archive labels to ContentGlows | Done |
| Feature documentation on ContentGlows site (3 pages + index update) | Done |
| P0.2 — Rename fake agents to pipelines (SchedulerPipeline, ImagePipeline) | Done |
| P0.3 — Remove hollow SEO tools, wire KeywordIntegrator to DataForSEO | Done |
| P0.4 — Wire Firecrawl + Exa as shared CrewAI tools | Done |
| P0.1 — Externalize all agent prompts to YAML (17 files, 14 agents, prompt_loader helper) | Done |
| P1.1 — Fuse 6 separate SEO Crews into single multi-agent Crew (Process.sequential + task.context) | Done |
| P1.2 — Enable allow_delegation=True on coordinator agents (Editor, Strategist, Marketing, AudienceAnalyst) | Done |
| P1.3 — Add Pydantic output schemas to all 6 SEO pipeline tasks (output_pydantic=) | Done |
| Website auth handoff endpoints (`/api/auth/web/handoff`, `/api/auth/web/exchange`) + signed Clerk webhook receiver | Done |
| Project selection contract aligned on `UserSettings.defaultProjectId` for `/api/me`, `/api/bootstrap`, and project responses | Done |
| `POST /api/projects` + `PATCH /api/projects/{id}` (`github_url`) aligned with Flutter multi-project management | Done |
| Add GitHub integration endpoints for project discovery and repository folder browsing to support pickers in onboarding and Drip source selection | Done |

## In Progress

| Pri | Task | Status |
|-----|------|--------|
| P1 | Backend persona autofill + repo understanding + user keys | Done |
| P0 | Fix Turso Hrana NULL binding failure during persona draft jobs | Done |
| P0 | Persona AI draft fallback when project clone is missing | ✅ done |
| P2 | Feedback Admin v1 — finaliser les vérifications prod restantes | Admin email configuré; restent Bunny/audio et validation admin connectée |
| P0 | Dual-mode AI runtime (BYOK + platform) all providers — implement ready spec | 🔄 in progress — automated backend/Flutter checks pass; manual provider smoke + final verify/ship pending |
| P2 | Consolidate `AGENTS.md` operational guidance into `AGENT.md` and keep compatibility symlink | ✅ done |
| P0 | Project flows selection onboarding archive — optional source_url, projectSelectionMode tri-state, archive/unarchive API + bootstrap no-selection | ✅ done |
| P0 | Persona draft GitHub repository access diagnostics and README collection hardening | ✅ done |

### Feedback Admin v1 (2026-04-19)

Contexte:
- Le code backend FastAPI est implémenté localement dans `lab`
- L'app Flutter appelle maintenant ce backend
- Il reste surtout la partie déploiement/config serveur

Fait:
- [x] Ajouter l'auth optionnelle Clerk pour accepter les feedbacks anonymes
- [x] Ajouter les modèles feedback (`text`, `audio`, `status`)
- [x] Ajouter le store `FeedbackEntry` sur la base existante Turso/libsql
- [x] Ajouter les routes `/api/feedback/*`
- [x] Protéger l'admin par allowlist email côté serveur
- [x] Ajouter le flux audio avec upload signé et lecture signée via Bunny Storage
- [x] Ajouter des tests d'intégration ciblés sur le flux feedback

À faire côté serveur:
- [x] Push/merge les changements `lab` sur la branche de déploiement du backend
- [x] Déployer la nouvelle version du backend sur le serveur
- [x] Redémarrer le process FastAPI après déploiement
- [x] Vérifier que la table `FeedbackEntry` est bien créée
- [x] Vérifier que `TURSO_DATABASE_URL` et `TURSO_AUTH_TOKEN` sont bien présents en prod
- [x] Ajouter `FEEDBACK_SIGNING_SECRET` en prod
- [x] Ajouter `FEEDBACK_ADMIN_EMAILS` en prod
- [ ] Ajouter `BUNNY_STORAGE_API_KEY` en prod
- [ ] Ajouter `BUNNY_STORAGE_ZONE` en prod
- [ ] Vérifier ou ajouter `BUNNY_STORAGE_REGION` en prod si nécessaire

Validation après déploiement:
- [x] Tester un feedback texte anonyme depuis l'app
- [ ] Tester un feedback texte connecté depuis l'app
- [ ] Tester un feedback audio depuis l'app
- [ ] Vérifier qu'un email hors allowlist reçoit bien un `403` sur `/api/feedback/admin`
- [ ] Vérifier qu'un admin allowlisté voit la liste et peut marquer une entrée comme lue

Note infra:
- On ne rajoute pas une nouvelle base de données
- Le flux feedback réutilise la base Turso/libsql déjà en place dans le backend
- "Configurer Turso" ici veut seulement dire: vérifier que les variables Turso existantes sont bien présentes sur le serveur où tourne FastAPI
- Le texte est déjà live sur `https://api.contentglows.com/api/feedback/text`
- L'upload audio crée maintenant bien une `uploadUrl`, mais l'upload réel reste bloqué tant que `BUNNY_STORAGE_ZONE` et `BUNNY_STORAGE_API_KEY` ne sont pas configurés en prod
- L'admin côté serveur a maintenant l'allowlist `FEEDBACK_ADMIN_EMAILS`; la validation admin connectée reste à tester
- Le process PM2 live et le checkout de déploiement sont operator-only: les agents ne doivent pas les lire, les modifier, les tester, ni les redémarrer
- Pour un incident prod, l'agent doit fournir le diagnostic et les actions opérateur à exécuter, sans toucher au checkout de déploiement ni à PM2

### Audit: Code (2026-04-28)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Require an owned `content_record_id` for `POST /api/publish` so authenticated callers cannot publish arbitrary text outside the ContentGlows review/status lifecycle | ✅ done |
| ✅ | Decision: keep one shared Zernio API key for all connected publish accounts for now; publishing is provider-wide, not per-user tenant-isolated | ✅ done |
| ✅ | Implement `ProjectPublishAccount` (or equivalent) so each Zernio `account_id` is explicitly authorized for `userId + projectId` before `/api/publish` calls Zernio | ✅ done |
| ✅ | Add product/operator guardrails for the shared Zernio model: do not present it as tenant-isolated until project-level account scoping is implemented | ✅ done |
| ✅ | Add route regressions for project-scoped accounts, forged account refusal before provider call, local disconnect, connect state, scheduled, published and partial publish results | ✅ done |
| 🟡 | Run manual Zernio smoke with real `ZERNIO_API_KEY`, two projects, one connected social account, publish success, forged account `403`, and provider error recovery before prod rollout | 📋 todo |
| 🟡 | Modernize deprecated Pydantic v1 validators and FastAPI `regex=` query parameters surfaced by the publish-router test run | 📋 todo |

### Audit: Code (2026-04-07)

| Sev | Issue | Location | Status |
|-----|-------|----------|--------|
| 🔴 | Command injection — f-string + shell=True in git/npm commands | `publishing_tools.py`, `tech_audit_tools.py` | **FIXED** |
| 🔴 | 12 API routers have NO authentication | 12 routers | **FIXED** |
| 🔴 | Global exception handler leaks `str(exc)` to clients | `api/main.py` | **FIXED** |
| 🔴 | shell=True with interpolated paths in tech audit tools | `tech_audit_tools.py` | **FIXED** |
| 🟠 | 7 bare `except:` clauses mask all errors | `repo_analyzer.py`, `seo_research_tools.py` | **FIXED** |
| 🟠 | Drip router hardcodes `user_id="system"` — no tenant isolation | `api/routers/drip.py` | **FIXED** |
| 🟠 | CORS regex allows any `*.vercel.app` subdomain | `api/main.py` | **FIXED** |
| 🟠 | In-memory state lost on restart (deployment, templates) | `api/routers/deployment.py`, `api/routers/templates.py` | Open |
| 🟠 | Loose dependency pins (`>=` with no upper bound) | `requirements.txt` | **FIXED** |
| 🟠 | God file: 3512 lines, 140 functions | `agents/seo/tools/internal_linking/` | **FIXED** |
| 🟡 | No CI/CD pipeline to run existing tests | Project-wide | Deferred — tests need API keys, no value until pure unit tests exist |
| 🟡 | Multiple 500+ line files (8 files over 500 lines) | `ingest.py`, `dataforseo_client.py`, `status/service.py`, etc. | Open |
| 🟡 | No structured logging for production | Project-wide | **FIXED** |
| 🟡 | No rate limiting on any endpoint | `api/main.py` | **FIXED** |
| 🟡 | No DB health check in health endpoint | `api/routers/health.py` | **FIXED** |
| 🟡 | In-memory state (deployment, templates routers) | `api/services/job_store.py` | **FIXED** |
| 🟡 | test_runner.py user input sanitization | `test_runner.py` | **FIXED** |

## Backlog

| Pri | Task | Notes |
|-----|------|-------|
| P2 | Social Listener v2 — TikTok, Instagram, Bluesky | Needs ScrapeCreators API key |
| P2 | models.dev AI model registry benchmark | Évaluer l'API JSON publique comme source structurée pour providers, IDs, prix, fenêtres de contexte, limites de sortie, capacités et dates; prévoir cache, fallback, schéma interne, sécurité et usage BYOK/platform — source: https://models.dev/ et https://models.dev/api.json (veille 2026-06-10) |
| P2 | Auriko-style inference gateway benchmark | Étudier les patterns gateway LLM compatible OpenAI pour routing multi-provider, failover automatique, BYOK, budget controls, analytics, optimisation coût/latence/throughput et modèle sans markup provider — source: https://betalist.com/startups/auriko (veille 2026-06-10) |
| P2 | Android 17 creator workflow benchmark | Étudier Screen Reactions, qualité Instagram, Edits IA on-device, séparation audio, Adobe Premiere tablette et APV comme inspirations pour reels/shorts, génération médias et publication mobile — source: Google Blog 2026-05-12 |
| P2 | DataForSEO LLM Mentions API — veille marketing externalisée | Étudier l'API comme inspiration pour mesurer mentions de marque, concurrents, domaines et mots-clés dans les réponses LLM/AI search; cadrer un futur module GEO/AI visibility et reporting de veille marketing externalisée — source: https://dataforseo.com/apis/ai-optimization-api/llm-mentions-api (veille 2026-06-10) |
| P2 | Firecrawl Fire PDF + `/parse` endpoint — sources de contenu | Étudier l'usage futur pour ingérer PDFs, documents locaux/non publics et sources longues dans l'Idea Pool avec extraction Markdown/JSON, limites fichier, coût, sécurité et rétention — sources: https://www.firecrawl.dev/blog/fire-pdf-launch et https://docs.firecrawl.dev/api-reference/endpoint/parse (veille 2026-06-10) |
| P2 | Alpic MCP / ChatGPT Apps benchmark | Étudier Alpic comme inspiration pour exposer ContentGlows à des agents via MCP servers et ChatGPT Apps: création d'idées, ingestion de sources, briefs, calendrier, lancement de pipelines, monitoring, sécurité et distribution — sources: https://alpic.ai/ et https://alpic.ai/blog/deploy-chatgpt-apps-on-alpic (veille 2026-06-10) |
| P2 | AppSumo VOC mining for creator tools | Étudier comment exploiter pages AppSumo, reviews, questions et réponses fondateur comme source structurée de voix du client pour concurrents/inspirations creator tools; commencer par Subscribr pour extraire objections, demandes réelles, limites produit et wording utilisateur — sources: https://subscribr.ai/ et https://appsumo.com/products/subscribr/ (veille 2026-07-07) |
| P2 | Readability endpoint — `POST /api/content/{id}/readability` | Score existing content from calendar |
| P3 | OG Preview caching — avoid refetching same URLs | Simple dict or store-based cache |
| P3 | OpenPostern-style vendor risk scoring inspiration | Inspiration légère: scoring 0-100, alertes, sources sécurité et prochaines actions pour futurs patterns de monitoring; non central pour ContentGlows — source: https://betalist.com/startups/openpostern et https://openpostern.com/ (veille 2026-06-10) |
| P3 | Benchmark concurrent Firecrawl Web Agent | Future task: comparer skills, subagents parallèles, structured output, streaming et sécurité URL vs agents recherche/SEO ContentGlows — source: https://github.com/firecrawl/web-agent (veille 2026-06-10) |
| P3 | Krotos-style video SFX enrichment | Future task: étudier l'ajout d'effets sonores et de "video-to-sound" aux vidéos ContentGlows, avec génération/personnalisation SFX puis export dans le workflow Remotion/publication — inspiration: https://krotos.studio/ (veille 2026-06-10) |
| P3 | Columns.ai integration — générer des illustrations éditoriales pour les contenus | Intégration future via l'accès produit disponible; prévoir specs API, droits d'usage, stockage asset library et insertion dans le workflow contenu |
| P3 | Unsplash API integration — stock photos for content | Nice-to-have complement to AI images |

---

## Architecture : Refonte Intelligence des Agents IA

### Contexte du diagnostic (2026-04-02)

Audit complet du code des agents dans `agents/`. Sur ~21 agents définis, environ la moitié n'utilisent jamais le LLM (Scheduler, Images). Ceux qui l'utilisent (SEO, Newsletter, Psychology, Social, Short) le font de manière rigide : pipeline linéaire, tools vides, zéro collaboration inter-agents. Le potentiel d'intelligence est là (CrewAI, Mem0, DataForSEO sont installés) mais sous-exploité.

- **Score d'intelligence actuel estimé :** 3/10
- **Score cible :** 8/10

---

### P0 — Court terme (quick wins, pas de refactoring majeur)

#### P0.1 — Externaliser les prompts dans des fichiers YAML ✅

- [x] **Créer le dossier `agents/{robot}/prompts/` pour chaque robot**

**Problème :** Tous les prompts (role, goal, backstory, `Task.description`) sont des f-strings hardcodées dans le code Python. Impossible de modifier un prompt sans toucher au code. Pas de versioning, pas d'A/B testing, pas de feedback loop.

**Solution détaillée :**

1. Créer un dossier `agents/{robot}/prompts/` pour chaque robot ayant des agents CrewAI
2. Créer un fichier YAML par agent à l'intérieur, nommé d'après l'agent : `research_analyst.yaml`, `strategy_expert.yaml`, etc.
3. Structure YAML attendue :
   ```yaml
   role: "SEO Research Analyst"
   goal: "Conduct comprehensive competitive intelligence..."
   backstory: "You are an expert SEO analyst with 10+ years..."
   tasks:
     research:
       description: "Analyze the competitive landscape for {topic}..."
       expected_output: "A structured research report with..."
   ```
4. Les variables dynamiques (`{topic}`, `{brand}`, `{url}`) restent en placeholder dans le YAML — elles seront injectées au runtime via `.format()` ou `str.format_map()`
5. Créer un helper `load_prompt(robot, agent_name)` dans `agents/shared/prompt_loader.py` qui :
   - Charge le fichier YAML correspondant
   - Retourne un dict avec `role`, `goal`, `backstory`, `tasks`
   - Gère les erreurs (fichier manquant, clé manquante) avec des messages explicites

**Fichiers à modifier :**
- [x] `agents/seo/` — 8 agents extraits vers YAML (research_analyst, copywriter, editor, content_strategist, marketing_strategist, technical_seo, topical_mesh_architect, internal_linking_specialist)
- [x] `agents/newsletter/newsletter_agent.py` — 3 agents extraits vers YAML
- [x] `agents/psychology/` — 3 agents extraits vers YAML (audience_analyst, angle_strategist, creator_psychologist)
- [x] `agents/social/social_crew.py` — 2 agents extraits vers YAML
- [x] `agents/short/short_crew.py` — 1 agent extrait vers YAML
- [x] Créer `agents/shared/prompt_loader.py` — helper de chargement YAML

**Bénéfice :** Itération rapide sur les prompts sans risquer de casser le code Python. Versioning Git des prompts séparément du code. Possibilité future d'A/B testing de prompts.

---

#### P0.2 — Assumer les faux agents comme pipelines Python ✅

- [x] **Nettoyer la confusion sémantique agents/pipelines**

**Problème :** Les agents Scheduler (`agents/scheduler/scheduler_crew.py`) et Images (`agents/images/image_robot_crew.py`) instancient des objets `Agent()` CrewAI avec `role`/`goal`/`backstory` mais ne font JAMAIS `crew.kickoff()`. Ce sont des scripts Python classiques déguisés en "agents IA". Les méthodes sont appelées directement :
```python
schedule_result = self.calendar_manager.schedule_content(content_data)
publish_result = self.publishing_agent.publish_content(content_path, ...)
```

**Solution détaillée :**

1. Retirer les objets `Agent()` CrewAI inutilisés de ces fichiers — supprimer les imports CrewAI (`from crewai import Agent, Task, Crew`) et les instanciations `Agent(role=..., goal=..., backstory=...)`
2. Renommer les classes pour refléter leur vraie nature :
   - `SchedulerCrew` → `SchedulerPipeline`
   - `ImageRobotCrew` → `ImagePipeline`
3. Mettre à jour tous les imports dans les routers FastAPI qui référencent ces classes (chercher `from agents.scheduler.scheduler_crew import` et `from agents.images.image_robot_crew import`)
4. Documenter clairement dans un commentaire en tête de fichier que ces modules sont des **pipelines déterministes**, pas des agents IA
5. **NE PAS changer la logique métier** — uniquement nettoyer la confusion sémantique

**Fichiers à modifier :**
- [ ] `agents/scheduler/scheduler_crew.py` — retirer Agent/Crew, renommer classe
- [ ] `agents/scheduler/agents/` (4 fichiers d'agents) — retirer les instanciations Agent() inutilisées
- [ ] `agents/images/image_robot_crew.py` — retirer Agent/Crew, renommer classe
- [ ] `agents/images/agents/` (4 fichiers d'agents) — retirer les instanciations Agent() inutilisées
- [ ] Les routers FastAPI qui importent ces classes — mettre à jour les imports

**Bénéfice :** Clarté architecturale. On sait immédiatement ce qui est "intelligent" (utilise le LLM) et ce qui est déterministe (pipeline Python classique).

---

#### P0.3 — Supprimer ou enrichir les tools coquilles vides ✅

- [x] **Auditer et corriger chaque tool factice du robot SEO**

**Problème :** Les tools des agents SEO renvoient des données statiques ou des templates hardcodés au lieu d'utiliser le LLM ou des APIs réelles :

| Tool | Fichier | Problème |
|------|---------|----------|
| `ContentWriter.write_content()` | `agents/seo/tools/writing_tools.py` | Renvoie un dict de "guidelines" sans générer de contenu |
| `ToneAdapter.adapt_tone()` | `agents/seo/tools/writing_tools.py` | Renvoie des templates pré-définis (professional, casual) |
| `KeywordIntegrator.integrate_keywords()` | `agents/seo/tools/writing_tools.py` | Fait du regex basique (`re.findall`) |
| `MetadataGenerator.generate_metadata()` | `agents/seo/tools/writing_tools.py` | Concatène des strings avec des templates |
| `TopicClusterBuilder.build_topic_cluster()` | `agents/seo/tools/strategy_tools.py` | Contient des branches `if "marketing" in pillar_topic.lower()` hardcodées |

**Solution — 2 options par tool :**
- **Option A : Supprimer le tool** → laisser le LLM raisonner seul (il est meilleur que du regex pour l'analyse de mots-clés ou la génération de contenu)
- **Option B : Connecter à une vraie API** → les tools DataForSEO existent et sont bien intégrés dans `agents/seo/tools/`, les étendre aux tools de writing/strategy

**Recommandation par tool :**
- [ ] `ContentWriter` → **Option A (supprimer)** — le LLM avec le bon prompt génère du contenu bien meilleur qu'un dict de guidelines
- [ ] `ToneAdapter` → **Option A (supprimer)** — le LLM adapte le ton naturellement via le prompt
- [ ] `MetadataGenerator` → **Option A (supprimer)** — le LLM génère des meta descriptions et titles de meilleure qualité
- [ ] `KeywordIntegrator` → **Option B (connecter à DataForSEO)** — le connecter aux données de volume de recherche et difficulté de mots-clés réelles via les tools DataForSEO déjà existants
- [ ] `TopicClusterBuilder` → **Option A (supprimer)** — le LLM avec le bon prompt fait des topic clusters bien meilleurs que des branches `if/else` hardcodées

**Fichiers à modifier :**
- [ ] `agents/seo/tools/writing_tools.py` — supprimer ContentWriter, ToneAdapter, MetadataGenerator ; enrichir KeywordIntegrator
- [ ] `agents/seo/tools/strategy_tools.py` — supprimer TopicClusterBuilder
- [ ] `agents/seo/seo_crew.py` — retirer les tools supprimés de la liste des tools assignés aux agents

---

#### P0.4 — Brancher Firecrawl et Exa comme tools CrewAI ✅

**Problème :** Les packages `firecrawl-py` et `exa-py` sont dans `requirements.txt`, les clés API sont configurées dans `.env.example` et `sync_env_to_doppler.sh`, des specs existent (SPEC-content-crawling.md, SPEC-competitor-analysis.md), mais AUCUN agent n'utilise Firecrawl et seulement 1 agent utilise Exa (Newsletter content curator dans `agents/newsletter/tools/content_tools.py`). Tout est prêt, il manque le câblage.

**Solution :**

1. Créer `agents/shared/tools/firecrawl_tools.py` — Wrappers `@tool` CrewAI autour du SDK Firecrawl :
   - [ ] `scrape_url(url: str)` — scraper une page et retourner le contenu structuré
   - [ ] `crawl_site(url: str, max_pages: int)` — crawler un site entier
   - [ ] `map_site(url: str)` — cartographier la structure d'un site
   - [ ] `search_web(query: str)` — recherche web via Firecrawl
   - [ ] `extract_structured(url: str, schema: dict)` — extraction de données structurées selon un schéma

2. Créer `agents/shared/tools/exa_tools.py` — Wrappers `@tool` CrewAI généralisés (le pattern existe déjà dans `content_tools.py`, le généraliser) :
   - [ ] `exa_search(query: str)` — recherche sémantique web
   - [ ] `exa_find_similar(url: str)` — trouver des pages similaires à une URL
   - [ ] `exa_get_contents(urls: list)` — récupérer le contenu de plusieurs URLs

3. Brancher sur les agents existants — Ajouter ces tools dans les listes `tools=[]` :
   - [ ] SEO Research Analyst (`agents/seo/agents/research_agent.py`) : `exa_search` + `firecrawl_crawl` pour l'analyse concurrentielle
   - [ ] SEO Copywriter (`agents/seo/agents/copywriter_agent.py`) : `firecrawl_scrape` pour analyser le contenu concurrent avant d'écrire
   - [ ] Newsletter Research Agent (`agents/newsletter/`) : généraliser les tools Exa existants dans `content_tools.py` vers les shared tools
   - [ ] Social Platform Adapter (`agents/social/`) : `exa_search` pour analyser les posts concurrents

**Prérequis :** Aucun — les packages et clés API sont déjà en place.
**Effort estimé :** ~2h
**Bénéfice :** Les agents accèdent enfin au web de manière structurée, sans passer par des tokens LLM coûteux pour le scraping.

---

### P1 — Moyen terme (restructuration de l'orchestration)

#### P1.1 — Passer à un vrai Crew multi-agents (pipeline SEO)

- [ ] **Refactorer le pipeline SEO en un seul Crew multi-agents**

**Problème :** Le pipeline SEO dans `seo_crew.py` crée 6 Crews séparées d'1 agent chacune, lancées séquentiellement :
```python
research_crew = Crew(agents=[self.research_agent.agent], tasks=[research_task])
research_output = research_crew.kickoff()
strategy_crew = Crew(agents=[self.strategy_agent.agent], tasks=[strategy_task])
# etc.
```
C'est l'**anti-pattern de CrewAI**. L'intérêt de CrewAI c'est justement l'orchestration multi-agents avec délégation, mémoire partagée et collaboration.

**Solution détaillée :**

1. Remplacer les 6 Crews séparées par **UN SEUL Crew** avec les 6 agents
2. Utiliser `Process.sequential` pour commencer (le plus simple, le plus prévisible), puis évaluer `Process.hierarchical` (avec un agent Manager qui décide de l'ordre) une fois que le sequential fonctionne bien
3. Code cible :
   ```python
   from crewai import Crew, Process

   seo_crew = Crew(
       agents=[research, strategy, copywriter, technical, marketing, editor],
       tasks=[research_task, strategy_task, writing_task, technical_task, marketing_task, editing_task],
       process=Process.hierarchical,
       manager_llm=llm,
       verbose=True
   )
   result = seo_crew.kickoff(inputs={"topic": topic, "url": url})
   ```
4. Tester avec des inputs connus pour vérifier que la qualité de l'output est au moins égale à l'approche actuelle

**Fichiers à modifier :**
- [ ] `agents/seo/seo_crew.py` — refactoring majeur : fusionner les 6 Crews en 1

---

#### P1.2 — Activer la délégation inter-agents

- [ ] **Permettre la collaboration entre agents via `allow_delegation=True`**

**Problème :** `allow_delegation=False` est mis sur **TOUS les 21 agents** sans exception. Aucun agent ne peut demander à un autre de l'aider ou de corriger son travail. Cela empêche toute collaboration intelligente.

**Solution détaillée :**

Mettre `allow_delegation=True` sur les agents qui bénéficient de collaboration :

| Agent | Robot | Pourquoi activer la délégation |
|-------|-------|-------------------------------|
| Editor SEO | SEO | Devrait pouvoir renvoyer au copywriter pour corrections |
| Strategy Expert | SEO | Devrait pouvoir demander des données au research analyst |
| Audience Analyst | Psychology | Devrait pouvoir consulter le research analyst SEO |
| Marketing Strategist | SEO | Devrait pouvoir valider avec le technical SEO |

Garder `allow_delegation=False` sur les agents terminaux (ceux qui produisent l'output final, comme le copywriter ou le technical SEO analyst).

**Fichiers à modifier :**
- [ ] `agents/seo/agents/*.py` — tous les fichiers d'agents SEO
- [ ] `agents/psychology/agents/*.py` — les fichiers d'agents Psychology
- [ ] `agents/newsletter/agents/*.py` — les fichiers d'agents Newsletter
- [ ] `agents/social/agents/*.py` — le fichier d'agent Social
- [ ] `agents/short/agents/*.py` — le fichier d'agent Short

---

#### P1.3 — Remplacer `str(output)` par des schémas Pydantic entre stages

- [ ] **Structurer les échanges inter-agents avec des modèles Pydantic**

**Problème :** Le passage de données entre stages est brutal : `str(research_output)` sérialisé en texte brut, tronqué (`outline[:2000]`), collé dans le prompt suivant. Perte d'information massive à chaque transition.

**Solution détaillée :**

1. Définir des schémas Pydantic pour chaque output d'agent :
   ```python
   from pydantic import BaseModel

   class ResearchOutput(BaseModel):
       competitors: list[CompetitorAnalysis]
       keywords: list[KeywordData]
       content_gaps: list[str]
       market_position: str

   class StrategyOutput(BaseModel):
       pillar_pages: list[PillarPage]
       topic_clusters: list[TopicCluster]
       content_calendar: list[CalendarEntry]
       priority_keywords: list[str]
   ```
2. Utiliser `output_pydantic=ResearchOutput` sur les Tasks CrewAI — ce pattern existe **déjà** dans le code pour les schémas d'images (`agents/images/`), donc le mécanisme est validé
3. L'agent suivant reçoit des données structurées au lieu de texte brut — plus de `str()` ni de troncature `[:2000]`
4. Chaque schéma doit documenter ses champs avec des `Field(description=...)` pour guider le LLM

**Fichiers à créer :**
- [ ] `agents/seo/schemas/research_output.py` — schéma de sortie de l'agent Research Analyst
- [ ] `agents/seo/schemas/strategy_output.py` — schéma de sortie de l'agent Strategy Expert
- [ ] `agents/seo/schemas/writing_output.py` — schéma de sortie de l'agent Copywriter
- [ ] `agents/seo/schemas/technical_output.py` — schéma de sortie de l'agent Technical SEO
- [ ] `agents/seo/schemas/marketing_output.py` — schéma de sortie de l'agent Marketing Strategist
- [ ] `agents/seo/schemas/editing_output.py` — schéma de sortie de l'agent Editor

**Fichier à modifier :**
- [ ] `agents/seo/seo_crew.py` — ajouter `output_pydantic=...` sur chaque Task

---

### P2 — Long terme (intelligence avancée)

#### P2.1 — Boucle d'évaluation et auto-correction

- [ ] **Ajouter un agent Évaluateur avec feedback loop dans chaque Crew**

**Problème :** Les agents génèrent du contenu mais ne l'évaluent jamais. Pas de feedback loop. Le premier jet est le jet final.

**Solution détaillée :**

1. Ajouter un agent **Évaluateur** dans chaque Crew qui note la qualité (score 1-10 sur des critères définis)
2. Si le score est < 7, renvoyer automatiquement à l'agent producteur avec le feedback détaillé
3. Limiter à **2 itérations max** pour éviter les boucles infinies et les coûts LLM excessifs
4. Critères d'évaluation par robot :

| Robot | Critères d'évaluation |
|-------|----------------------|
| SEO | Pertinence mots-clés, structure H1-H6, meta description, lisibilité Flesch |
| Newsletter | Qualité du hook, valeur ajoutée, CTA clair, longueur appropriée |
| Psychology | Profondeur d'analyse, actionabilité des insights, rigueur des sources |

**Fichiers à créer :**
- [ ] `agents/seo/agents/evaluator_agent.py`
- [ ] `agents/newsletter/agents/evaluator_agent.py`
- [ ] `agents/psychology/agents/evaluator_agent.py`

---

#### P2.2 — Convertir Scheduler et Images en vrais agents IA

- [ ] **Rendre le Scheduler et le pipeline Images intelligents**

**Problème :** Ces pipelines sont purement déterministes. Le Scheduler publie toujours de la même façon. L'Image pipeline génère toujours avec les mêmes paramètres, sans adaptation au contexte.

**Solution détaillée :**

- **Scheduler :** Un agent IA qui raisonne sur le **meilleur moment** de publication en analysant :
  - L'audience cible (fuseau horaire, habitudes de consommation)
  - L'historique de performance (quels jours/heures ont le meilleur engagement)
  - Les tendances actuelles (sujets trending à capitaliser rapidement)
  - Au lieu de suivre un calendrier fixe
- **Images :** Un agent IA qui choisit le style visuel, le cadrage, les couleurs en fonction :
  - Du contenu de l'article (ton, sujet, audience)
  - De la brand identity du projet
  - Des tendances visuelles du secteur
  - Au lieu d'appliquer des paramètres fixes

**Fichiers à modifier :**
- [ ] `agents/scheduler/scheduler_crew.py` — ajouter un vrai agent IA avec `crew.kickoff()`
- [ ] `agents/images/image_robot_crew.py` — ajouter un vrai agent IA pour le choix créatif

---

#### P2.3 — Orchestrateur avec branchement conditionnel

- [ ] **Évaluer LangGraph ou un state machine pour orchestration flexible**

**Problème :** Le pipeline est toujours linéaire (1→2→3→4→5→6). Certains stages pourraient tourner en parallèle (Technical SEO + Marketing SEO), et certains pourraient être skippés selon le contexte (pas besoin d'analyse technique si le contenu est une newsletter).

**Solution détaillée :**

1. Évaluer **LangGraph** ou un **state machine Python** (comme `transitions`) pour un orchestrateur plus flexible
2. Capacités visées :
   - **Parallélisme** — Technical SEO et Marketing SEO tournent en même temps
   - **Branchement conditionnel** — si le contenu est court, skipper l'analyse technique
   - **Boucles de feedback** — l'évaluateur peut renvoyer à n'importe quel agent
   - **Skip de stages** — selon le type de contenu, certains agents ne sont pas pertinents
3. Garder **CrewAI pour l'exécution des agents individuels**, mais gérer l'orchestration au niveau supérieur avec LangGraph

**Fichiers à créer :**
- [ ] `agents/shared/orchestrator.py` — orchestrateur avec state machine ou LangGraph
- [ ] `agents/shared/graph_definitions/` — définitions de graphes par robot

---

### Ce qui fonctionne bien (à préserver)

> Ces briques sont bien conçues et doivent être préservées telles quelles lors de la refonte :

- **Mémoire sémantique Mem0** (`memory/memory_service.py`) — recherche sémantique, scoping par projet, anti-duplication. Brique IA-native bien conçue.
- **RunHistory SQLite** (`agents/shared/run_history.py`) — les robots consultent leur historique. Bon pattern à étendre.
- **Status tracking** avec machine à états (`in_progress` → `generated` → `pending_review` → `approved` → `published`) — bon pour le workflow humain.
- **Agents Psychology** — les mieux conçus, utilisent vraiment le raisonnement IA qualitatif. **Modèle à suivre** pour les autres robots.
- **Schémas Pydantic images** — le pattern `output_pydantic` existe déjà dans `agents/images/`, il faut l'étendre aux autres robots (cf. P1.3).
- **Intégration DataForSEO** — les tools de données sont bien connectés aux APIs réelles, contrairement aux tools de writing/strategy qui sont factices.

---

## Veille stratégique

### OpenAI Skills in API — Compatibilité multi-LLM

**Lien :** https://developers.openai.com/cookbook/examples/skills_in_api
**Pertinence :** ContentGlows ne doit pas être verrouillé sur un seul LLM. Le pattern "skills" d'OpenAI montre comment encapsuler des agents comme des bundles réutilisables avec un manifeste. Ce pattern est LLM-agnostique dans son concept : un skill = instructions + fichiers + outils, monté sur n'importe quel runtime.

**Actions à explorer :**
- [ ] Étudier comment rendre les agents CrewAI compatibles avec plusieurs LLMs (Claude, GPT, Codex, Gemini)
- [ ] Évaluer si le format manifeste SKILL.md pourrait standardiser la définition des agents indépendamment du LLM
- [ ] Tester CrewAI avec `llm` parameter pointant vers OpenAI GPT-5/Codex en plus de Claude
- [ ] Documenter les différences de comportement entre LLMs pour chaque agent (certains prompts marchent mieux sur Claude, d'autres sur GPT)
- [ ] Considérer un router intelligent qui choisit le meilleur LLM selon la tâche (ex: Claude pour le raisonnement éthique/psychology, Codex pour le code/technical SEO)

**Priorité :** Backlog — à considérer lors de la refonte P1

---

### ~~Minexa AI — Scraping IA structuré pour agents~~ → IGNORÉ

**Raison :** Redondant avec Firecrawl et Exa déjà connectés en MCP servers. Pas besoin d'un troisième outil de scraping.
- Firecrawl couvre : scraping, crawl, extract, search
- Exa couvre : recherche web sémantique, code context
- À la place, intégrer Firecrawl et Exa comme tools CrewAI dans les agents existants

---

### Codex Prompting Guide — Patterns de prompt engineering avancés

**Lien :** https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide
**Pertinence :** Guide complet de prompting pour agents IA autonomes. Patterns transposables à tous les LLMs :

**Patterns à transposer :**
- [ ] **Parallélisme multi-tools** — lancer plusieurs agents simultanément au lieu de séquentiellement (applicable au pipeline SEO P1.1)
- [ ] **Compaction de contexte** — pour les agents qui analysent de gros corpus (SEO, content analysis), maintenir le contexte sur de longues sessions sans exploser les tokens
- [ ] **Personnalité calibrée** — le pattern "friendly" (langage "nous", affirmation des progrès) est directement alignable avec les agents Psychology et le coach IA Quit Coke
- [ ] **Meta-prompting** — demander au LLM d'identifier ses propres points faibles et de proposer des corrections de prompts. Applicable aux agents les moins performants.
- [ ] **Plan management** — le pattern update_plan avec statuts (pending/in_progress/completed) est transposable à l'orchestration des pipelines CrewAI

**Priorité :** Backlog — à intégrer progressivement lors de l'externalisation des prompts (P0.1)

### Audit: Code (2026-04-27)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Bound anonymous feedback audio uploads with signed max-bytes limits and content-length/body enforcement | ✅ done |
| ✅ | Harden GitHub OAuth state consumption against replay race conditions (`UPDATE ... RETURNING` + locked fallback) | ✅ done |
| ✅ | Cap in-memory rate-limiter active client tracking to reduce unbounded memory growth risk | ✅ done |
| ✅ | Enforce `USER_SECRETS_MASTER_KEY` on GitHub integration store operations and run startup rotation for legacy plaintext tokens | ✅ done |
| 🟠 | Roll out `USER_SECRETS_MASTER_KEY` in all deployed environments so GitHub integration endpoints remain available in production | 📋 todo |
| 🟡 | Add anti-automation controls for anonymous feedback upload URL issuance (captcha/challenge or stricter endpoint-specific quotas) | 📋 todo |

### Audit: Deps (2026-05-02)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Pin backend dependencies with lockfiles (`requirements.lock`, `requirements-dev.lock`) and route production installs through the production lock | ✅ done |
| ✅ | Complete the existing `pydantic-ai` major-line migration; full local pytest and `pip-audit` are clean after moving to `pydantic-ai>=1.56.0,<2.0` | ✅ done |
| ✅ | Document isolated-runtime strategy for excluded STORM/Reels integrations (`knowledge-storm`, `instagrapi`) if those flows remain product-critical | ✅ done |
| ✅ | Resolve the default `crewai`/`litellm` resolver conflict without lowering the LiteLLM security floor | ✅ done |
| ✅ | Move test-only packages (`pytest`, `pytest-asyncio`, `pytest-cov`) out of runtime requirements (`requirements-dev.txt`) | ✅ done |
| ✅ | Add dependency automation baseline (`.github/dependabot.yml` for pip + GitHub Actions) | ✅ done |
| ✅ | Establish project-scoped license inventory and review unknown license metadata for `libsql` | ✅ done |
