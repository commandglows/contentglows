# Tasks — ContentGlows (Flutter)

> **Priority:** 🔴 P0 blocker · 🟠 P1 high · 🟡 P2 normal · 🟢 P3 low · ⚪ deferred
> **Status:** 📋 todo · 🔄 in progress · ✅ done · ⛔ blocked · 💤 deferred

**Stack**: Flutter 3.41, Riverpod, GoRouter, Dio, flutter_card_swiper, Google Fonts | **Phase**: Phase 11 — Offline sync V2 shipped

**Backend**: Python FastAPI (23 agents CrewAI/PydanticAI) at ContentGlows_lab/

**Top priority**: Reprendre les priorités app haut impact après validation hostée du fix Clerk OTP.

## Documentation Migration (2026-06-29)

### Done

- [x] Reclassify `app/TASKS.md` as a deprecated local façade and keep canonical tracker ownership in `shipglows_data/workflow/app/TASKS.md`.
- [x] Reclassify `app/AUDIT_LOG.md` as a deprecated local façade and keep canonical audit ownership in `shipglows_data/workflow/app/AUDIT_LOG.md`.
- [x] Reduce `app/README.md`, `app/AGENT.md`, and `app/CLAUDE.md` to the same lightweight façade pattern as `lab` and `site`.

---

### Filmora / PixVerse Visual Editing (canonical)

Concurrent sources: Filmora, PixVerse. Canonical execution spec: `shipglows_data/workflow/specs/monorepo/SPEC-professional-video-editor-capability-roadmap-2026-08-09.md`. Layer should be implemented as an extension of `/editor/:id/video`, not a separate studio.

| Pri | Task | Status |
|-----|------|--------|
| 🔴 | Ajouter l’ergonomie pro du player timeline (split, ripple trim, duplication, snap, undo/redo, verrouillage/mute, scrubbing) sans changement de route | 📋 todo |
| 🔴 | Ajouter le modèle `keyframes` et le mini éditeur d’animation (transform/opacity/scale/rotation/volume + easing basic) côté app + persistance immutable | 📋 todo |
| 🟠 | Ajouter pipeline transcript/captions côté app avec preview-gated edits et alignement des timings sur versioning | 📋 todo |
| 🟠 | Ajouter audio-mix controls (fades, niveaux, ducking, normalization helpers) dans l’éditeur de révision vidéo | 📋 todo |
| 🟡 | Ajouter couche d’assistance IA read-only pour hook/séquençage/B-roll/CTA et option d’application explicite | 📋 todo |

## Phase 1 — Scaffold & Core Screens ✅

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Projet Flutter (web + Android), pubspec, structure clean architecture | ✅ done |
| ✅ | Modèles ContentItem, ContentType, ContentStatus, PublishingChannel + JSON serialization | ✅ done |
| ✅ | API service Dio avec fallback mock data | ✅ done |
| ✅ | Riverpod providers (settings, API, content feed, history, personas) | ✅ done |
| ✅ | Theme Material 3 dark + Google Fonts | ✅ done |
| ✅ | Feed screen — swipeable cards (droite=publish, gauche=skip, haut=edit) | ✅ done |
| ✅ | Content card riche (type badge, projet, channels, preview, swipe hints) | ✅ done |
| ✅ | Editor screen — markdown preview + inline edit + publish/skip | ✅ done |
| ✅ | History screen — timeline published/rejected | ✅ done |
| ✅ | Settings screen — API URL, 7 channels, notifications | ✅ done |
| ✅ | Settings — gestion OpenRouter (lecture, enregistrement, validation, suppression de clé) | ✅ done |
| ✅ | GoRouter (13 routes) + bottom nav shell (Feed/Schedule/History/Settings) | ✅ done |

## Phase 2 — Psychology Engine & Onboarding ✅

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Modèles Project, ContentTypeConfig, Persona, RitualEntry, AngleSuggestion | ✅ done |
| ✅ | Onboarding 3 pages (projet GitHub, types contenu + fréquence, résumé) | ✅ done |
| ✅ | Weekly Ritual screen (5 entry types → narrative synthesis → validation) | ✅ done |
| ✅ | Persona list screen + confidence scores | ✅ done |
| ✅ | Persona editor (name, demographics, pain points min 2, goals min 2) | ✅ done |
| ✅ | Angles screen (3 AI angles, sélection, generate content) | ✅ done |
| ✅ | Calendar screen (week strip + daily timeline) | ✅ done |
| ✅ | API service branché sur vrais endpoints (/api/status/content, /api/psychology/*) | ✅ done |
| ✅ | Content Engine section dans Settings (raccourcis ritual, personas, angles, onboarding) | ✅ done |

## Phase 3 — Backend Integration & Polish ✅

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Tous les endpoints vérifiés, ContentItem.fromJson réécrit, flux complet testé | ✅ done |
| ✅ | Editor, skeleton loaders, first-launch redirect, dev serving | ✅ done |

## Phase 3b — Fixes & Wiring ✅

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Angles, Schedule, Content update, Personas refresh, Ritual narrative, Persona language model | ✅ done |
| ✅ | GitHub Actions, Zernio API, Publish accounts, Channel states, Schedule API | ✅ done |
| ✅ | Retirer les artefacts Flutter web `build/web` du suivi Git et laisser Vercel reconstruire le build au déploiement | ✅ done |
| ✅ | OAuth channel connections (Connect + Disconnect via Zernio) | ✅ done |

## Phase 4 — Auth & Workspace Migration ✅

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Spec architecture, Clerk auth FastAPI + Flutter, Bootstrap, Projects, User data, Content ownership | ✅ done |
| ✅ | Flutter auth headless Clerk, session restore, onboarding réel, 401 handling | ✅ done |
| ✅ | Écran auth Clerk officiel + fallback diagnostics quand le SDK reste bloqué au chargement | ✅ done |
| ✅ | Auth web déportée sur ContentGlows Site + handoff sécurisé vers Flutter web (`/entry` + exchange backend) | ✅ done |
| ✅ | Vérifier runtime Clerk réel en environnement Flutter | ✅ done |
| ✅ | Remplacer l'auth web Flutter beta / handoff par ClerkJS officiel sur le domaine app (`/sign-in`, `/sso-callback`, Google direct) | ✅ done |
| ✅ | Corriger le callback OAuth Clerk web pour finaliser la session sur `/sso-callback` avant le retour vers `/#/entry` | ✅ done |
| ✅ | Corriger le flux Clerk email sign-up sur `/sign-up` au lieu du fallback Flutter `/sign-up#/entry` | ✅ done |
| ✅ | Corriger le double envoi d'email OTP Clerk pendant la création de compte email, probablement déclenché par une actualisation/re-mount impromptu de la page sign-up | ✅ done |
| ✅ | Shipper le fix Clerk OTP et vérifier sur l'app hostée qu'une inscription email n'envoie qu'un seul code | ✅ done |
| ✅ | Bloquer la création workspace/onboarding tant qu'aucune session Clerk authentifiée n'est présente | ✅ done |
| ✅ | Introduire un `AppAccessState` central pour séparer session Clerk, health FastAPI et bootstrap workspace | ✅ done |
| ✅ | Ajouter un mode dégradé avec shell limité, diagnostics enrichis et warning global quand FastAPI tombe | ✅ done |
| ✅ | Afficher clairement l'état de session dans Settings (email connecté + bouton logout) pour éviter l'ambiguïté sur l'auth active | ✅ done |
| 🔴 | Stabiliser la reprise mobile/web sans mouvement d'UI: aucun jump vers `/entry` ni reroutage visible lors du retour d'app (checks uniquement en arrière-plan) | ✅ done |
| ✅ | Corriger la régression de contraste UI (fond clair + texte blanc illisible) observée après le dernier commit | ✅ done |

---

## Phase 5 — Unified Content Pipeline (2026-03-26) ✅

> Unifier les 3 pipelines déconnectés (Psychology, SEO, Newsletter) en un flux unique:
> Sources → Idea Pool → Angles enrichis → Pipelines par format → Review Queue

### Backend (contentglows/)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Étendre enums ContentType (short, social_post) et SourceRobot (short, social) | ✅ done |
| ✅ | Idea Pool — modèle, table SQLite, CRUD StatusService, API `/api/ideas` | ✅ done |
| ✅ | Enrichir Angle Strategist — accepte seo_signals + trending_signals, retourne priority_score + seo_keyword | ✅ done |
| ✅ | Pipeline dispatch — `POST /api/psychology/dispatch-pipeline` remplace le placeholder render-extract | ✅ done |
| ✅ | Short Content Agent — CrewAI agent pour TikTok/Reels/Shorts (hook, script, hashtags) | ✅ done |
| ✅ | Social Post Agent — CrewAI agent pour Twitter/LinkedIn/Instagram (platform-adapted posts) | ✅ done |
| ✅ | Scheduler complet — _run_seo_job, _run_article_job implémentés + _run_short_job, _run_social_job ajoutés | ✅ done |
| ✅ | Config fréquence — ContentFrequencyConfig dans RobotSettings + _reconcile_frequency_jobs dans scheduler | ✅ done |
| ✅ | Sources → Idea Pool — ingest_newsletter_inbox, ingest_seo_keywords, ingest_weekly_ritual | ✅ done |
| ✅ | Scheduler ingestion jobs — ingest_newsletters, ingest_seo job types + API triggers manuels | ✅ done |
| ✅ | Nettoyage legacy JS — suppression chatbot/ Next.js (41 MB), prototypes v0, BMAD framework | ✅ done |

### Flutter (contentglows-app/)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | ContentType.short dans enum Dart + parser/serializer | ✅ done |
| ✅ | Metadata helpers — seoKeyword, shortPlatform, shortDuration, socialPlatforms, etc. | ✅ done |
| ✅ | Content card — chips métadonnées par format (SEO, plateforme, durée, hashtags) | ✅ done |
| ✅ | Editor — barre de métadonnées contextuelle par content type | ✅ done |
| ✅ | Theme — couleur Short (coral red) | ✅ done |
| ✅ | Angles screen → dispatch-pipeline endpoint (vraie génération) avec fallback | ✅ done |
| ✅ | ApiService — dispatchPipeline() + getPipelineStatus() | ✅ done |
| ✅ | Settings — section Content Frequency (sliders blog/newsletter/short/social) | ✅ done |

## Phase 6 — DataForSEO Integration (2026-03-27) ✅

> Intégrer DataForSEO API v3 comme source de données SEO réelles dans tout le pipeline.
> Remplace SerpApi (SERP-only) + Advertools (combos mock) par une API unifiée.

### Backend (contentglows/)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Client DataForSEO API v3 — `dataforseo_client.py` (SERP, keywords, trends, competitors, intent) | ✅ done |
| ✅ | Provider DFS — `dataforseo_provider.py` (DFSSERPAnalyzer, DFSTrendMonitor, DFSKeywordGapFinder, DFSRankingPatternExtractor) | ✅ done |
| ✅ | Supprimer SerpApi — `research_tools.py` réécrit, DFS direct, mêmes @tool wrappers CrewAI | ✅ done |
| ✅ | Niveau 1 — `ingest_seo_keywords` réécrit avec DFS keyword_ideas + keyword_overview (vrais volume/difficulty/CPC) | ✅ done |
| ✅ | Niveau 2 — `enrich_ideas` batch-enrichit les idées raw via DFS keyword_overview → priority_score | ✅ done |
| ✅ | Niveau 3 — `ingest_competitor_watch` via DFS domain_intersection + ranked_keywords → idées competitor_watch | ✅ done |
| ✅ | Niveau 4 — `track_serp_positions` vérifie le ranking Google post-publication → serp_history dans metadata | ✅ done |
| ✅ | Scheduler jobs — enrich_ideas, ingest_competitors, track_serp wired dans scheduler_service.py | ✅ done |
| ✅ | API endpoints — POST /api/ideas/enrich, /ingest/competitors, /track-serp | ✅ done |
| ✅ | Gap 1 fix — `_run_article_job` passe seo_signals + competitor_domains au SEO Crew | ✅ done |
| ✅ | Gap 2 fix — Bridge optionnel Idea Pool → Angle Strategist dans _run_article_job (opt-in) | ✅ done |
| ✅ | Gap 3 fix — Feedback loop SERP → idées refresh (`_evaluate_serp_feedback`, 3 triggers) | ✅ done |
| ✅ | Config — DFS_CONFIG dans research_config.py, .env.example mis à jour | ✅ done |

## Phase 7 — Legacy Domain Migration (2026-03-28) ✅

> Re-implement all 13 domains deleted with legacy Node.js chatbot.
> Scrollable nav replaces fixed 4-tab NavigationBar. Pattern: SQL migration + Pydantic + store + router + Flutter screen.

### Backend Lab — New domains

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Affiliations — migration SQL + modèle Pydantic + store CRUD 5 méthodes + router 5 endpoints | ✅ done |
| ✅ | Activity Log — migration SQL + store list/create + router 2 endpoints | ✅ done |
| ✅ | Work Domains — migration SQL + store list/create/update + router 3 endpoints | ✅ done |
| ✅ | Idempotent table creation au démarrage FastAPI (ensure_*_table dans lifespan) | ✅ done |

### Flutter — New screens (13 écrans)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Navigation scrollable horizontale (remplace NavigationBar fixe 4 tabs → 17 tabs) | ✅ done |
| ✅ | Affiliations — liste + stats + filtres status/category + formulaire BottomSheet CRUD | ✅ done |
| ✅ | Activity — timeline des actions robots/utilisateur avec badges status | ✅ done |
| ✅ | Runs — liste historique des runs robots | ✅ done |
| ✅ | Templates — galerie des templates par défaut | ✅ done |
| ✅ | Newsletter — check config + formulaire génération async | ✅ done |
| ✅ | Research — formulaire analyse concurrentielle + résultats | ✅ done |
| ✅ | Reels — download Instagram reel + extract audio + upload CDN | ✅ done |
| ✅ | SEO Mesh — analyse topical mesh + issues + recommandations | ✅ done |
| ✅ | Content Tools — 3 tabs : validations pendantes, funnel clusters SEO, audit contenu | ✅ done |
| ✅ | Work Domains — cards status par domaine (SEO, Newsletter, etc.) | ✅ done |
| ✅ | Analytics — pipeline funnel + content par type + channels + timeline publication | ✅ done |
| ✅ | Performance — stats dashboard (total, pending, published, rejected, par type) | ✅ done |
| ✅ | Uptime — health check API + ping history avec latence | ✅ done |

---

## P1 — Prochaines priorités

| Pri | Task | Impact | Effort | Notes |
|-----|------|--------|--------|-------|
| ✅ | Regrouper les 17 tabs en sections (Content, Create, Analyze, System) | High | Low | ✅ done — dividers visuels entre sections |
| ✅ | Validation runtime Clerk (site sign-in réel, handoff web, restore session, `/api/bootstrap`) | High | Medium | ✅ done — auth web directe via ClerkJS sur le domaine app, bootstrap validé |
| ✅ | OAuth flow pour connecter les channels (via LATE/Zernio) | High | Medium | ✅ done — Connect + Disconnect complets |
| ✅ | Landing page produit (ContentGlows_site rebrand complet) | High | Medium | ✅ done — Hero, Features, How It Works, Pricing Free/19/49, Use Cases, FAQ |
| ✅ | Feedback Admin v1 côté Flutter — soumission texte/audio, historique local léger, accès anonyme et écran admin in-app | High | Medium | ✅ done — client FastAPI prêt, build-time allowlist + docs ajoutés |
| ✅ | Localisation app EN/FR — préférence de langue (système/anglais/français) + couverture FR sur les écrans shell, debug et drip | High | Medium | ✅ done — AppLanguage, persistance SharedPreferences et passe UI sur settings/editor/drip/uptime/work domains/runs/research |
| ✅ | Système de thème complet — light/dark/system persisté + réglage utilisateur + thème éditorial partagé | High | Medium | ✅ done — préférence normalisée, `ThemeMode` branché sur l'app Flutter, palette/tokens centralisés |
| ✅ | Purger les couleurs hard-codées des écrans Flutter pour rendre le light mode réellement cohérent | High | High | ✅ done — écrans migrés vers `Theme.of(context)` / `AppTheme.paletteOf(context)` sur tout `lib/presentation/screens` |
| ✅ | Implémenter `SPEC-content-editor-multiformat` (toolbar riche universelle Markdown-backed: gras/italique/titres/listes/citation/lien/suppression de paragraphe + tests) | High | Medium | ✅ implemented and verified — lifecycle closure/ship bookkeeping remains |
| 🟡 | Finaliser les vérifications feedback restantes: stockage audio S3-compatible, URLs signées de lecture admin et validation admin connectée | Medium | Low | 📋 todo — admin email configuré; non bloquant pour le prochain gros chantier |
| 🔴 | Project flows selection onboarding archive — source URL optionnelle, no-selection explicite persistante, archive/unarchive alignés app+API | High | High | ✅ done |
| 🟠 | Polar.sh Billing (free, 19€, 49€) | High | Medium | ⛔ not code-ready — requires a dedicated commercial/checkout spec; the ready AI quota spec excludes checkout, invoices, taxes, and exact prices |
| ✅ | Tests end-to-end pipeline | High | Low | ✅ done — test_e2e_pipeline.py + test_new_domains.py dans lab |
| 🟡 | DataForSEO — credentials OK dans Doppler, ajouter credits au compte DFS | High | Low | Auth OK (20000), mais 402 Payment Required — ajouter credits sur dataforseo.com/billing |
| ✅ | Exposer l'audit structuré des actions (`actor_type/id/label`) dans l'UI debug/admin | High | Medium | ✅ done — editor audit panel renders actor label/type/id and copied audit trails preserve the structured actor |

## Phase 11 — Offline Sync V2 (2026-04-20) ✅

> Garder l'app authentifiée utilisable quand FastAPI tombe, avec cache persistant, queue de replay locale, temp IDs réconciliés et surfaces UI explicites pour l'état de sync.

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Accès complet au shell authentifié en mode dégradé, sans renvoi forcé vers l'entrée | ✅ done |
| ✅ | Stabiliser la navigation au retour d’onglet : rester sur la route courante pendant la revalidation en arrière-plan | ✅ done |
| ✅ | Cache persistant des lectures principales + état `stale` exposé dans le shell/Uptime | ✅ done |
| ✅ | Queue persistée des mutations backend sûres avec retry automatique | ✅ done |
| ✅ | Réconciliation `tempId -> realId` pour projets, personas et affiliations | ✅ done |
| ✅ | Extension V2 aux créations offline depuis Angles et aux plans Drip | ✅ done |
| ✅ | Blocage explicite des opérations non sûres offline (uploads, deletes, publish, jobs serveur-first) | ✅ done |
| ✅ | Gestion des dépendances de queue via état `blockedDependency` | ✅ done |
| ✅ | Badges `Pending sync` / `Sync failed` sur les listes principales supportées | ✅ done |
| ✅ | Docs mises à jour (`README`, `CHANGELOG`, `TASKS`, `SPEC-offline-sync-v2`) | ✅ done |

## Link Management — Shortener & Affiliate Enhancement

> Transformer le CRM d'affiliate links passif en infrastructure de link management active.
> Inspiration: QuitURL (shortener + targeting + A/B + overlays).
> **Architecture choisie: Option B — self-hosted + inspiration Dub.co** (webhooks, conversion tracking, UTM builder, deep links, cloaking, previews). Pas d'intégration vendor lock-in.

### Quick Wins ✅

| Pri | Task | Impact | Effort | Status | Notes |
|-----|------|--------|--------|--------|-------|
| 🟠 | Enforcer `expiresAt` dans le CRM affiliations : badge "Expiré", blocage à l'édition, filtres | High | Low | ✅ done | Badge automatique, `isExpired` getter, tap bloqué si expiré |
| 🟠 | Ajouter alias custom + slug generator : champ `slug` sur `AffiliateLink`, endpoint `GET /r/{slug}` (redirect + log click) | High | Medium | ✅ done | Migration 008, store, router public `/r/{slug}` 302 + log click |
| 🟠 | Click tracking minimal : table `LinkClick` (linkId, timestamp, country, device, referrer), premier endpoint analytics | High | Medium | ✅ done | Migration 008, store, router `/api/links/clicks` + `/api/links/clicks/summary` |

### Moyen terme

| Pri | Task | Impact | Effort | Status | Notes |
|-----|------|--------|--------|--------|-------|
| 🟡 | A/B rotator : modèle `LinkVariant` (url, weight), endpoint `/r/{slug}` sert une variante selon weight, log de variante | Medium | Medium | ✅ done | Migration 008, store, router `/api/links/variants`, sélection par weight dans `/r/{slug}` |
| 🟡 | Geo/device targeting : middleware redirect qui lit country/IP et choisit la destination ciblée | Medium | High | 📋 todo | `LinkVariant` supporte `country`, `device`, `language` ; la sélection ciblée est prête dans `/r/{slug}` |
| 🟡 | CTA overlays : page de redirect intermédiaire avec bannière branding + CTA, puis forward destination | Medium | Medium | 📋 todo | Non démarré |

### Long terme

| Pri | Task | Impact | Effort | Status | Notes |
|-----|------|--------|--------|--------|-------|
| 🟢 | Password protection sur les liens | Low | Low | 📋 todo | Gate par mot de passe avant redirect |
| 🟢 | Branded domains : gestion DNS + wildcard SSL pour servir les redirects sur domaine custom | Medium | High | 📋 todo | Infrastructure lourde, dépend de la croissance |

## Link Management — Dub.co-inspired Features

> Features inspirées de Dub.co pour enrichir le shortener self-hosté.
> Priorisation : webhooks d'abord (débloque crews temps réel), puis conversion funnel, puis UX/attribution avancée.

### Quick Wins

| Pri | Task | Impact | Effort | Status | Notes |
|-----|------|--------|--------|--------|-------|
| 🟠 | Webhooks : endpoint `POST /api/links/webhooks` + stockage `LinkWebhook`, events `link.created`, `link.clicked`, `conversion.created` | High | Medium | ✅ done | Migration 009, store, router `/api/webhooks/links` + public `/r/webhooks/public/{id}` |
| 🟠 | Conversion tracking : table `LinkConversion` (linkId, type=lead/sale, revenue, currency, partnerId), endpoint `/api/links/conversions` | High | Medium | ✅ done | Migration 009, store, router `/api/links/conversions` + summary |
| 🟡 | UTM builder + templates : modèle `UtmTemplate` (name, params), UI dans affiliations screen, auto-apply au créer un lien | Medium | Low | ✅ done | Migration 009, store, router `/api/utm`, modèles Flutter + API service |

### Moyen terme

| Pri | Task | Impact | Effort | Status | Notes |
|-----|------|--------|--------|--------|-------|
| 🟡 | Deep links deferred : stockage `deeplink`/`fallback_url` sur `AffiliateLink`, routing dans `/r/{slug}` iOS/Android | Medium | High | 📋 todo | Si on vise mobile natif |
| 🟡 | Link cloaking : option `cloak=true` sur `AffiliateLink`, redirect via page intermédiaire sans référer | Medium | Low | 📋 todo | Améliore CTR, masque destination |
| 🟡 | Custom link previews : stockage `previewTitle`/`previewImage` sur `AffiliateLink`, meta tags dans redirect HTML | Medium | Low | 📋 todo | OG tags pour social sharing |
| 🟡 | Folders + tags : modèle `LinkFolder`, tag many-to-many sur `AffiliateLink`, filtres UI | Medium | Medium | 📋 todo | Organisation à grande échelle |

### Long terme

| Pri | Task | Impact | Effort | Status | Notes |
|-----|------|--------|--------|--------|-------|
| 🟢 | Analytics sharing : token de partage, endpoint public `/api/links/{id}/shared-analytics` | Low | Low | 📋 todo | Dashboards partageables avec partenaires |
| 🟢 | Bulk operations : endpoints `/api/links/bulk-create`, `/bulk-update`, `/bulk-delete` | Medium | Medium | 📋 todo | Pour programmes partenaires massifs |
| 🟢 | Séparation modèle : `PartnerProgram` + `Partner` + `PayoutRule` distincts de `AffiliateLink` | High | High | 📋 todo | Refonte schema si on scale les programmes |

## Link Management — Consumer Connections

> Brancher les affiliate links dans les flux de création de contenu qui les consomment.

### Quick Wins ✅

| Pri | Task | Impact | Effort | Status | Notes |
|-----|------|--------|--------|--------|-------|
| 🟠 | Editeur : picker d'affiliate links dans "Insert link" au lieu du dialogue URL brut | High | Medium | ✅ done | Bottom sheet avec liste des liens actifs/non expirés, insertion du slug court si dispo |
| 🟠 | Pipeline : passer les affiliations à dispatchPipeline → _run_pipeline_task | High | Medium | ✅ done | `PipelineDispatchRequest.affiliations` ajouté, fetch côté Flutter + fallback backend |
| 🟡 | Contexte génération : inclure les affiliations actives dans build_generation_context() | Medium | Medium | ✅ done | Section `## Active Affiliate Links` ajoutée au prompt_text, tronquée si budget dépassé |
| 🟡 | Prompts agents : ajouter instructions de matching/insertion d'affiliate links dans SEO, short, social, newsletter | Medium | Low | ✅ done | Backstories YAML mises à jour pour copywriter, short_form_writer, platform_adapter, content_writer |
| 🟡 | Matching keywords : logique simple AffiliateLink.keywords ↔ angle.topic/content keywords | Medium | Low | 📋 todo | Champ keywords exposé dans le payload affiliations ; matching IA côté prompt reste à affiner |

### 🟡 P2 — Polish & Engagement

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Bulk approve (approve all pending in one tap) | ✅ done |
| ✅ | Responsive layout web (side rail on desktop, bottom nav on mobile) | ✅ done |
| ✅ | Preview post par plateforme (Twitter, LinkedIn, Instagram, Ghost, YouTube, TikTok) | ✅ done |
| ✅ | Stats post-publication (destinations breakdown + approval rate) | ✅ done |
| ✅ | Landing page rebrand (hero, features, pricing, use cases, FAQ) | ✅ done |
| ✅ | Firebase Cloud Messaging scaffold (service layer ready, needs Firebase config) | ✅ done |
| ✅ | Diagnostics centralisés + copie d'erreurs/logs exportables dans l'app (runtime, API, auth, Riverpod, snackbars) | ✅ done |
| ✅ | Mobile UX audit — bottom nav redesign, responsive typography, touch targets, layout fixes | ✅ done |
| 🟡 | Corriger l'overlap Android de l'onboarding demo avec la barre systeme native | ✅ done - retest appareil suivi dans BUG-2026-05-05-001 |
| 🟡 | Corriger le bouton retour Android: revenir dans la demo et confirmer avant fermeture app | ✅ done - retest appareil suivi dans BUG-2026-05-05-002 |
| ✅ | Rebrand produit `ContentGlowsz` → `ContentGlows` (nom app, package Android, manifests web, scripts et docs) | ✅ done |
| ✅ | Localisation app EN/FR — préférence de langue (système/anglais/français) + couverture FR sur les écrans shell, debug et drip | ✅ done |
| ✅ | Ajouter un accès direct au rituel dans le menu mobile "More" pour augmenter la fréquence de remplissage | ✅ done |
| 🟠 | Ajouter une visite guidée simplifiée (4 cartes max) pour mode “publier vite” : parcours orienté résultats, choix rapide au premier lancement | 📋 todo |
| 🟠 | Ajouter une vraie section compte dans Settings (lien gestion Clerk / mot de passe / providers connectés) au lieu d'un simple état de session | 📋 todo |
| 🟠 | Passe i18n complémentaire sur les écrans secondaires encore partiellement en anglais | 🔄 in progress |

### Audit: Design (2026-04-21 — Feed mobile page — Overall: C→B)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Remplacer les cartes vides du feed par une composition responsive mobile-first (CTA empilés, cartes pleine largeur, stats sans débordement) | ✅ done |
| 🟠 | Valider sur vrai appareil le header mobile du feed avec `ProjectPickerAction` lorsque le nom du projet est très long et qu’un bulk action est présent | 📋 todo |
| 🟡 | Revoir plus tard la version mobile du feed “avec cartes à swiper” pour confirmer que la zone d’actions basse ne gêne pas les petits écrans 320–360px | 📋 todo |

### Audit: Design Tokens (2026-05-10)

| Pri | Task | Status |
|-----|------|--------|
| 🔴 | Remplacer les 722 valeurs visuelles Flutter hardcodées par des helpers issus de `AppTheme`/`tools/design-tokens/contentglows_theme.json` | 🔄 in progress |
| 🔴 | Introduire des tokens Flutter responsives mobile pour tailles de texte, padding, gap et rayons, puis migrer les écrans principaux | 🔄 in progress |
| 🟠 | Tokeniser les couleurs directes restantes (`Colors.red`, `Colors.white`, alphas de bordures) hors fichiers de thème générés | 📋 todo |
| 🟠 | Ajouter une vérification automatisée qui bloque les nouveaux `fontSize`, `EdgeInsets` et `BorderRadius.circular` hors exceptions autorisées | 📋 todo |

### Audit: Copywriting (2026-05-10 — App entry homepage — Overall: C+)

| Pri | Task | Status |
|-----|------|--------|
| 🟠 | Repositionner `/entry` comme page de reprise/récupération pour utilisateurs existants et réserver la promesse produit complète aux pages onboarding/feed où la valeur est visible | ✅ done |
| 🟠 | Aligner les claims amont du site (`swipe to publish`, `6x more content`, `0 platforms to manage`, automatisation) avec les limites réelles app: human review, publish externe partiel, mode dégradé borné | ✅ done |
| 🟡 | Ajouter un CTA alternatif plus léger et rassurant depuis l’entry/sign-in pour les nouveaux visiteurs: démo guidée, aperçu onboarding, ou explication claire de ce qui se passe après Google | ✅ done |
| 🟡 | Déplacer les preuves opérationnelles trop techniques (`Auth`, `API`, `Workspace`) vers une preuve orientée résultat utilisateur: reprise de travail, état de sync compréhensible, diagnostic copiable en cas de blocage | ✅ done |

### 🟠 P1 — Content Drip (Publication Progressive)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Étape 1 — Fondations : SourceRobot.DRIP + table drip_plans + DripService CRUD + router /api/drip/ | ✅ done |
| ✅ | Étape 2 — Import + clustering DIRECTORY : scanner .md, créer ContentRecords, grouper par dossiers | ✅ done |
| ✅ | Étape 3 — Scheduling + Execution : cadence fixe/ramp-up, frontmatter updater, rebuild trigger, cron tick, plan lifecycle (activate/pause/resume/cancel) | ✅ done |
| ✅ | Étape 4 — Clustering avancé : cluster_by_tags + cluster_auto via Topical Mesh Architect (fallback gracieux si crewai absent) | ✅ done |
| ✅ | Étape 5 — GSC : GSCClient (Indexing API submit + URL Inspection API check), endpoints /gsc/submit-urls et /gsc/indexation-status, auto-submit dans execute-tick | ✅ done |
| 🟠 | Étape 6 — Flutter UI : écran liste plans + wizard création + dashboard progression + actions lifecycle | ✅ done |
| ✅ | Publier les plans Drip avec heure aléatoire dans une plage horaire (plage début/fin par plan) | ✅ done |
| ✅ | Clarifier l’étape 3 du wizard Drip (clustering + stratégie “pillars first”) | ✅ done |
| ✅ | Clarifier l’étape 4 du wizard Drip (méthode de contrôle, heure de publication, draft flag, mode sécurisé GSC, rebuild manuel/automatique et détail “publication à plage aléatoire”) | ✅ done |
| ✅ | Ajouter un sélecteur de dossier source Drip depuis le projet actif (réutilisation `content_directories`) pour éviter la saisie manuelle | ✅ done |
| 🟡 | Étape 7 — Passe i18n complémentaire sur les écrans secondaires et harmonisation des clés de traduction | 📋 todo |
🟢 [app] task: Restore French translation coverage for app UI keys | status: done | area: translate

### 🟢 P3 — Backlog

| Pri | Task | Status |
|-----|------|--------|
| 🟢 | Gmail OAuth integration | 💤 deferred (complex OAuth flow) |
| 🟢 | iOS support | 💤 deferred |
| 🟡 | Offline V3 — uploads, suppressions et flux backend-first complexes avec stratégie de réconciliation explicite | 📋 todo |
| 🟢 | Image generation (Robolly) | 💤 deferred |
| 🟢 | Video script → teleprompter mode | 💤 deferred |
| 🟢 | A/B testing de hooks/titles | 💤 deferred |
| 🟢 | Newsletter preview HTML | 💤 deferred |
| 🟢 | App Store / Play Store submission | 💤 deferred |

---

> **Priority last updated**: 2026-08-20
> **Criteria**: Impact/effort matrix — "what makes the product actually work"
> **Recommended next**: Restaurer d'abord le déploiement Vercel de l'app; côté code, compléter les tests Brand Studio/canonical video path et poursuivre la centralisation des design tokens. Polar billing reste bloqué jusqu'à un contrat commercial/checkout dédié.

### Audit: Code (2026-04-28)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Replace web-auth diagnostic `innerHTML` rendering with text-node construction on `/sign-in`, `/sign-up`, and `/sso-callback` | ✅ done |
| ✅ | Make `ApiService.publishContent` require `contentRecordId` to match the backend publish authorization contract | ✅ done |
| ✅ | Move publishing account selection to the active project: Settings binds Zernio accounts to `userId + projectId`, not a global platform list | ✅ done |
| 🟡 | Run manual Zernio smoke with real `ZERNIO_API_KEY`, two projects, one connected social account, publish success, forged account `403`, and provider error recovery before prod rollout | 📋 todo |
| 🟠 | Add a browser regression test that loads `/sso-callback?redirect_url=<img...>` and asserts diagnostics render as text, not HTML | 📋 todo |
| 🟡 | Add a Flutter unit test around `publishContent` payload construction with required `contentRecordId` | 📋 todo |

### Audit: Code (2026-04-27)

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Remove `FEEDBACK_ADMIN_EMAILS` from Flutter web build defines to avoid exposing admin allowlist identities in client bundles | ✅ done |
| ✅ | Switch feedback-admin entry visibility to authenticated-session discovery while keeping backend `403` as the real authorization gate | ✅ done |
| ✅ | Add backend capability probe-driven feedback-admin visibility (`/api/feedback/admin/capability`) to avoid optimistic UI exposure for non-admin users | ✅ done |
| 🟡 | Add CI checks for `flutter analyze` plus targeted auth/offline regression tests | 📋 todo |

### Audit: Deps (2026-04-27)

| Pri | Task | Status |
|-----|------|--------|
| 🟠 | Plan and execute major upgrades for core packages (`flutter_riverpod`, `go_router`, `google_fonts`, `riverpod_annotation`, `riverpod_generator`) with regression matrix | ✅ done |
| 🟠 | Replace or mitigate discontinued transitive build packages (`build_resolvers`, `build_runner_core`) by upgrading the generator stack | ✅ done |
| 🟡 | Remove or justify likely unused dependencies (`cached_network_image`, `responsive_framework`, `cupertino_icons`, annotations if codegen stays unused) | 📋 todo |
| ✅ | Add dependency update automation baseline (`.github/dependabot.yml` for pub + GitHub Actions) | ✅ done |
| ✅ | Pin Flutter toolchain version (`.fvmrc` -> 3.41.7) for reproducible dependency resolution | ✅ done |
