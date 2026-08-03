---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: lab
created: "2026-05-11"
created_at: "2026-05-11 14:04:51 UTC"
updated: "2026-05-11"
updated_at: "2026-05-12 17:25:15 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: feature
owner: Diane
confidence: high
user_story: "En tant qu'utilisateur ContentGlowz connecte a un projet web, je veux comprendre en langage naturel ce qui se passe dans Google Search pour mon site et transformer ces signaux en priorites editoriales, afin de savoir quel contenu creer, renforcer, corriger ou laisser tranquille."
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - lab/api/services/gsc_client.py
  - lab/api/routers/drip.py
  - lab/api/routers/settings_integrations.py
  - lab/api/routers/integrations.py
  - lab/api/routers/analytics.py
  - lab/api/routers/idea_pool.py
  - lab/api/routers/psychology.py
  - lab/api/services/user_key_store.py
  - lab/api/services/user_data_store.py
  - lab/api/services/analytics_store.py
  - lab/agents/sources/ingest.py
  - app/lib/presentation/screens/settings/integrations_screen.dart
  - app/lib/presentation/screens/analytics/analytics_screen.dart
  - app/lib/presentation/screens/idea_pool/idea_pool_screen.dart
  - app/lib/presentation/screens/seo/seo_screen.dart
depends_on:
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-progressive-content-release.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/lab/DRIP_IMPLEMENTATION.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Existing backend only exposes GSC submission/indexation under Drip; no general Search Console insights UI exists."
  - "lab/api/services/gsc_client.py supports service-account based Indexing API and URL Inspection API only through environment credentials."
  - "app/lib/presentation/screens/drip/drip_wizard_sheet.dart exposes a narrow Drip GSC toggle but no Search Console connection or insight dashboard."
  - "lab/api/routers/idea_pool.py and agents/sources/ingest.py already support ingestion of SEO, competitor, social, newsletter, and SERP feedback ideas."
  - "lab/api/routers/psychology.py dispatches selected ideas/angles into content generation and marks source ideas as used."
  - "Google Search Analytics API supports page/query/country/device performance metrics; URL Inspection API supports indexed URL status but not live URL testing; both require authorization and quotas."
  - "User clarified 2026-05-11 that OAuth and a real SEO stats screen are expected, and that the SEO stats screen can replace the current analytics surface."
  - "User clarified 2026-05-11 that the interface must show principal traffic metrics: top visited pages, site visits/pageviews, organic clicks, today, last 7 days, recent months, and last 6 months."
  - "User clarified 2026-05-11 that private analytics and Google Search Console must remain separate data sources even if the UI presents them in one SEO Stats area."
  - "User clarified 2026-05-11 that mixing metrics in one user experience is acceptable as long as no metric is invented and source provenance remains explicit enough to avoid misleading users."
next_step: "/sf-ship Google Search Console intelligence"
---

# Title

Google Search Console Intelligence

## Status

Ready. This spec creates a new product layer on top of the existing low-level GSC plumbing. The existing Drip GSC integration remains in place but is not enough for the user-facing goal. The MVP uses Google OAuth as the primary connection path and repurposes the current Analytics area into a Search Console-first SEO stats screen. Recommended UX: one default overview that answers in natural language, followed by two source sections, "Google Search" and "Site traffic". Search Console and first-party analytics remain separate data sources; the UI may correlate them in one experience, but backend models, labels, summaries, and recommendations must keep source provenance and must not invent or merge incompatible metrics.

## User Story

En tant qu'utilisateur ContentGlowz connecte a un projet web, je veux comprendre en langage naturel ce qui se passe dans Google Search pour mon site et transformer ces signaux en priorites editoriales, afin de savoir quel contenu creer, renforcer, corriger ou laisser tranquille.

Primary actor: authenticated ContentGlowz user with access to a project and at least one configured work domain.

Trigger: the user connects Google Search Console for a project through OAuth, opens the SEO Stats/Analytics area, or runs a manual/scheduled Search Console sync.

Observable result: the user sees a concise natural-language diagnosis of organic visibility in the primary stats screen and can ingest prioritized content opportunities into the Idea Pool.

## Minimal Behavior Contract

The system accepts a project-scoped Google Search Console OAuth connection, automatically binds the best matching Search Console property from the already-selected ContentGlowz project's domains, synchronizes recent Search Analytics and selected URL Inspection data for domains owned by that project, renders a plain-language overview of organic Google visibility, risk, and opportunities in the main SEO stats screen, and can convert selected Search Console opportunities into Idea Pool items that the existing content pipeline can generate or refresh. Manual property confirmation is only a fallback when the Google account returns no clear compatible property or an ambiguous/invalid state. The private first-party analytics tracker can appear in the same screen as a separate site-traffic section and can be used as contextual evidence in cross-source insights, but it is not Search Console data; every metric and insight must keep its source provenance and no combined traffic total can be invented. If authorization, ownership, Google quotas, project domains, or API calls fail, the user sees a recoverable explanation and no partial content-generation action is triggered automatically. The easy edge case is confusing "indexed" with "performing": an indexed page with weak impressions, CTR, or declining clicks must be treated as an editorial opportunity, not as a successful SEO outcome.

## Success Behavior

- A user can open Settings > Integrations and see a Google Search Console OAuth connection block with status: missing, connected, valid, invalid, expired, or degraded.
- A user can click "Connect Google Search Console", complete Google's OAuth consent flow in the system browser, and return to ContentGlowz with the integration attached to their account.
- After OAuth, the backend auto-matches a Search Console property from the selected ContentGlowz project's configured domains; the user only sees a fallback choice if no compatible property can be attached automatically.
- A user can validate the connection; validation checks token refresh, Search Console API access, property access, and whether at least one configured project domain belongs under the attached property.
- A user can open the primary SEO Stats screen, replacing the current analytics-first screen, and see:
  - a default "Overview" area that summarizes what matters without requiring the user to choose a data source first;
  - a "Google Search" rail for Search Console periods: Today when available and explicitly partial, Last 7 days, Last 30 days/current month, Last 90 days, and Last 6 months;
  - Search Console metrics only in the Google Search rail: organic clicks, impressions, CTR, average position, top organic landing pages, top queries, indexed sampled pages, and issue counts;
  - an optional "Site traffic" rail from first-party analytics for the same periods, clearly labeled as private tracker data: visits/pageviews and most visited site pages;
  - a short natural-language summary that can correlate GSC and private analytics signals, with each claim tied to its source and no invented metric;
  - top growing pages/queries;
  - declining pages/queries;
  - low-CTR pages with high impressions;
  - page-two opportunities;
  - indexation or canonical problems from sampled URL Inspection results.
- A user can click "Add to Idea Pool" for selected opportunities; the backend creates deduplicated `IdeaRecord` rows with source `search_console_feedback`, `seo_signals`, `priority_score`, and raw evidence.
- A generated idea can later be dispatched through the existing Psychology/content pipeline. The resulting `ContentRecord.metadata` preserves `source_idea_ids`, `seo_keyword`, and Search Console evidence.
- The sync path writes timestamps and cache state so the UI can distinguish fresh data, stale data, empty GSC data, and failed sync.
- Proof of success includes backend tests for service validation, summary generation, opportunity scoring, idea ingestion, and Flutter tests for connection/degraded UI states.

## Error Behavior

- Missing project or project not owned by the user returns `404` or `403` through existing ownership helpers and does not reveal whether another user's project exists.
- Missing work domains returns a clear 409-style response: "Connect a domain to this project before connecting Search Console."
- Invalid OAuth callback, missing authorization code, invalid token response, or revoked refresh token returns a non-secret validation message and no token is persisted.
- Missing or inaccessible GSC property returns `409` with a message explaining that the connected Google account must have access to the Search Console property.
- Search Analytics quota/load errors return a degraded state and preserve the last successful snapshot if available.
- URL Inspection quota errors skip inspection for the remaining URLs, record partial coverage, and keep Search Analytics summary available.
- A sync that partially fails never creates Idea Pool items automatically; the user must explicitly ingest opportunities.
- Duplicate opportunities for the same project, URL/query, reason, and period are not recreated; existing raw/enriched ideas are surfaced instead.
- If LLM/natural-language polishing is unavailable, the backend returns deterministic copy based on metrics instead of failing the dashboard.
- No failure path logs OAuth tokens, encrypted secrets, raw authorization headers, or private Search Console payloads beyond sanitized counts and URL/query evidence needed for the product.

## Problem

The current implementation treats Google Search Console as a publishing accelerator inside Drip: submit URLs and inspect indexation after publication. That is not the product the user described. Users need an interface that explains organic-search reality in human language, then feeds that reality back into content decisions. The current `AnalyticsScreen` is also not answering that need: it summarizes ContentGlowz pipeline state, not search performance.

Today there is no general GSC OAuth connection UI, no Search Analytics ingestion, no narrative SEO status, no project-scoped Search Console snapshot, and no direct bridge from real GSC data to the Idea Pool. The existing Drip toggle only sends published URLs when a plan is configured, and `gsc_client.py` only reads server environment credentials.

## Solution

Build a project-scoped Search Console Intelligence module:

1. Add a Settings integration for Google Search Console using Google OAuth, encrypted refresh-token storage, and automatic project-domain property binding with fallback confirmation only when needed.
2. Add backend Search Console sync endpoints that query Search Analytics for performance and URL Inspection for sampled indexation diagnostics.
3. Generate deterministic natural-language insights and structured opportunity objects.
4. Replace the current analytics-first screen with a Search Console-first SEO Stats screen that explains what is happening and lets the user ingest opportunities.
5. Feed selected opportunities into the existing Idea Pool and content generation pipeline without automatically generating content.

## Scope In

- Project-scoped Google Search Console OAuth connection status, connect, callback, disconnect, automatic property binding, fallback property confirmation, and validation.
- OAuth authorization-code flow for Google web-server apps with CSRF `state`, offline access, refresh-token storage, and token refresh.
- Search Console property listing and project property URL storage per user/project.
- Search Analytics sync for 7d, 30d/current month, 90d, and 6-month windows, with comparison to previous equivalent period when data quality is sufficient.
- Search Console period views for Today when available and explicitly partial, Last 7 days, Last 30 days/current month, Last 90 days, and Last 6 months.
- Search Console metric cards:
  - organic clicks from Google Search Console;
  - impressions, CTR, and average position;
  - top organic landing pages and queries;
  - indexed sampled pages and URL Inspection issues.
- Optional first-party analytics context cards, visually and semantically separated from Search Console:
  - site visits/pageviews from existing cookie-free analytics;
  - most visited pages on the site;
  - equivalent periods when analytics data is available.
- URL Inspection sync for a bounded sample of pages selected by risk/opportunity.
- Cached Search Console snapshot table or store.
- Natural-language summary generated from deterministic rules, optionally polished by existing OpenRouter runtime only when available.
- Opportunity scoring and classification:
  - `low_ctr_high_impressions`
  - `page_two_opportunity`
  - `query_without_targeted_content`
  - `declining_clicks`
  - `growing_query_to_support`
  - `indexed_but_underperforming`
  - `indexation_problem`
  - `canonical_mismatch`
- Idea Pool source `search_console_feedback`, UI label/filter, and ingestion action.
- Content pipeline metadata enrichment so generated/refreshed content keeps Search Console evidence.
- Repurposing `/analytics` into the primary SEO Stats screen, with existing pipeline analytics retained as a secondary tab/section rather than the first viewport.
- Tests for auth, tenant boundaries, credential handling, sync, scoring, dedupe, and UI states.
- Docs updates for connection setup and interpretation of GSC metrics.

## Scope Out

- Using service-account setup as the primary user path. Service accounts may remain as an operator/admin fallback or advanced import later, but the product MVP is OAuth.
- Automatic content generation from GSC signals. MVP creates user-reviewable ideas only.
- Bulk URL Inspection of every page on every sync. MVP samples high-value URLs to respect quota.
- Ranking guarantees, instant indexing promises, or claims that Indexing API submission improves ranking.
- Replacing DataForSEO SERP tracking. GSC feedback complements existing SERP/DataForSEO flows.
- Search Console management operations beyond reading Search Analytics, inspecting selected URLs, and validating access.
- Multi-user shared GSC credentials at organization/workspace level. MVP stores OAuth tokens per authenticated user.
- Unique people/visitor counting unless a privacy-safe unique visitor/session metric is explicitly added to the first-party analytics model.
- Billing/credit metering for sync jobs.

## Constraints

- Follow existing FastAPI router patterns with `require_current_user` and project ownership checks.
- Follow existing Turso/libSQL storage patterns. Do not reintroduce durable local SQLite.
- Store OAuth access and refresh tokens encrypted. Never expose raw tokens to the client after callback.
- Treat Search Console data as project/user-private business data.
- Keep UI explanations factual: clicks, impressions, CTR, position, coverage, and confidence. Avoid "Google likes/dislikes" speculation.
- Use deterministic summaries as the baseline; LLM text is optional and must not block the feature.
- Search Analytics grouping/filtering by page and query can be expensive; use bounded date ranges and cache snapshots.
- URL Inspection is per URL and quota limited; sample, queue, or degrade rather than scan every URL.
- The current Drip `GSCClient` uses process environment credentials. This feature needs OAuth user/project credentials, so it should create a separate `search_console_service.py` or refactor `gsc_client.py` behind credential injection without breaking Drip.
- The Indexing API is not the source of Search Console performance insights. It remains separate from this dashboard.
- OAuth uses browser redirects only; do not open Google's consent endpoint inside an embedded WebView.

## Dependencies

- Local code:
  - `lab/api/services/gsc_client.py` for existing Google client patterns.
  - `lab/api/routers/drip.py` for existing GSC endpoints and publish-time behavior.
  - `lab/api/routers/integrations.py` for existing OAuth state/callback patterns from GitHub.
  - `lab/api/services/user_key_store.py` for encrypted credential storage.
  - `lab/api/services/user_data_store.py` for project-scoped integration metadata.
  - `lab/api/routers/analytics.py` and `app/lib/presentation/screens/analytics/analytics_screen.dart` for current analytics UX.
  - `lab/api/routers/idea_pool.py` and `app/lib/presentation/screens/idea_pool/idea_pool_screen.dart` for idea ingestion and review.
  - `lab/api/routers/psychology.py` for content generation from idea/angle metadata.
- Python packages:
  - `google-api-python-client>=2.100.0,<3.0`
  - `google-auth>=2.23.0,<3.0`
- Google official docs, fresh-docs checked:
  - Search Analytics `query`: https://developers.google.com/webmaster-tools/v1/searchanalytics/query
  - Search Console usage limits: https://developers.google.cn/webmaster-tools/limits?hl=en
  - URL Inspection `index.inspect`: https://developers.google.com/webmaster-tools/v1/urlInspection.index/inspect
  - URL Inspection launch/use cases and quota: https://developers.google.com/search/blog/2022/01/url-inspection-api
  - Indexing API usage/errors: https://developers.google.com/search/apis/indexing-api/v3/using-api and https://developers.google.com/search/apis/indexing-api/v3/core-errors
  - Google OAuth web-server flow: https://developers.google.com/identity/protocols/oauth2/web-server
  - Search Console authorization and scopes: https://developers.google.com/webmaster-tools/v1/how-tos/authorizing
  - Sensitive scope verification: https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification
- External doc verdict: `fresh-docs checked`. Current docs support Search Analytics and URL Inspection for this module. Current docs also show Indexing API is a separate notification API with ownership/quota errors; this spec must not present Indexing API as a broad SEO-performance insight mechanism.
- OAuth doc verdict: `fresh-docs checked`. Google's web-server OAuth docs require redirect to Google, code exchange at `https://oauth2.googleapis.com/token`, `access_type=offline` for refresh tokens, refresh handling, and secure `state`. Google Search Console API docs state private Search Console API access uses OAuth 2.0 and supports `webmasters.readonly` for read-only data. Sensitive-scope verification may be required before public launch.

## Invariants

- A user can only read, sync, or ingest GSC data for projects they own.
- A Search Console OAuth token/property configured for one user/project is not visible to another user/project.
- Stored OAuth access/refresh tokens are write-only from the client perspective and encrypted at rest.
- Sync writes are idempotent by `(user_id, project_id, property_url, period, synced_at bucket)` or a stricter snapshot key.
- Opportunity ingestion is idempotent by `(project_id, source, reason, url/query, compared_period)`.
- Natural-language summaries are generated from structured metrics and must never invent metrics that are absent.
- Search Console summaries and opportunity evidence use Search Console data only; first-party analytics can be shown as separate context but cannot be represented as Google Search performance.
- Idea Pool remains the review boundary before content generation.
- Drip publish-time GSC submission remains optional and does not become required for Search Console Intelligence.

## Links & Consequences

- Auth/security: new endpoints must use `require_current_user`, signed OAuth `state`, token encryption, and project ownership helpers. Credential validation must not broaden access to arbitrary GSC properties.
- Data: add project-scoped Search Console config and snapshot storage. This affects Turso migrations/startup ensures.
- UI: Settings Integrations gains GSC OAuth connection. `/analytics` becomes a Search Console-first SEO Stats screen; current pipeline analytics can move to a secondary tab/section.
- Data-source boundary: Google Search Console and the private analytics tracker are distinct products and distinct datasets. Reusing the `/analytics` route or screen shell is a UX/navigation decision only, not a data-model merge.
- Metrics semantics: Search Console clicks are not total site visitors. Existing first-party analytics stores pageviews but not unique people; the UI must label those as visits/pageviews unless a privacy-safe unique visitor/session metric is added. GSC cards must use labels like `Organic clicks from Google`, `Impressions`, `CTR`, `Average position`, `Top organic landing pages`, and `Top queries`; private analytics cards must use labels like `Site visits/pageviews` and `Most visited pages on site`.
- Content workflow: Idea Pool gains a new source and source filter. Pipeline-generated content preserves GSC source metadata.
- Existing Drip behavior: the Drip GSC toggle can eventually read the same property/credentials, but this spec does not require merging them in the first implementation.
- SEO/product copy: UI must explain that GSC data is delayed/incomplete for recent days and that URL Inspection reflects Google's indexed version, not a live crawl test.
- Performance: sync should be explicit/manual first, with caching, before adding frequent background jobs.
- Operations: Render/env docs must list Google OAuth client ID/secret/callback settings and any operator-level fallback only if used.

## Documentation Coherence

- Update `lab/.env.example` with OAuth client settings: `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI`, and optional operator fallback only if implemented.
- Update `lab/README.md` with Search Console setup: create Google OAuth client, configure consent screen, enable Search Console API, set redirect URI, and understand verification requirements.
- Update `app` in-app strings/l10n for:
  - Google Search Console OAuth connection
  - SEO Stats screen replacing the analytics-first experience
  - traffic periods: Today, Last 7 days, Last 30 days, Last 90 days, Last 6 months
  - source-aware labels and tooltips that distinguish site visits/pageviews from Google organic clicks without making the user manage data-source complexity by default
  - natural-language summary states
  - degraded quota/credential states
  - Idea Pool source `search_console_feedback`
- Update product docs or site content later to avoid promising instant indexing or ranking improvements.
- Update changelog when implemented.

## Edge Cases

- Search Console property is `sc-domain:example.com` while project domain is `https://www.example.com`.
- URL-prefix property requires a trailing slash.
- OAuth callback is received after the user changed active project in the app.
- OAuth `state` is expired, replayed, missing, or belongs to another user.
- Google returns no refresh token because the user already granted access or `access_type=offline`/`prompt=consent` was not handled correctly.
- User revokes Google access after a successful connection.
- OAuth consent is blocked by Workspace admin policy or app verification status.
- App is public but OAuth scope verification is incomplete.
- Project has multiple domains but only one is covered by the configured GSC property.
- Search Analytics returns no rows for a new site.
- Today has partial data in both Search Console and first-party analytics; UI must label today's data as partial when applicable.
- User asks "how many people came"; if unique visitor tracking is not implemented, UI must not call pageviews "people".
- User compares "most visited pages" with "top pages from Google"; UI must explain these can differ because private analytics measures all tracked site traffic while Search Console measures Google Search clicks/impressions only.
- Recent data is incomplete; comparison should avoid overreacting to the newest incomplete day.
- Query/page dimensions return many rows; backend must page or cap results.
- Page and query grouped queries are expensive; sync should reduce range/filters when Google returns quota/load errors.
- URL Inspection reports `PASS` but Search Analytics performance is weak.
- URL Inspection reports Google-selected canonical different from user canonical.
- Page URL from GSC does not map cleanly to a local content record.
- Content has no `target_url`, `seo_keyword`, or matching content path.
- Existing `serp_feedback` and new `search_console_feedback` ideas could duplicate each other; dedupe should compare URL/query/reason, not only source.
- User disconnects OAuth while a sync job is running.
- OAuth access token is expired and refresh token is revoked or invalid.
- Google client libraries are declared but not installed in a local runtime.

## Implementation Tasks

- [ ] Tache 1 : Add Search Console models
  - Fichier : `lab/api/models/search_console.py`
  - Action : Create Pydantic models for connection status, config upsert/delete, validation response, sync request/result, summary, traffic overview periods, metric rows with `source`/`source_label`, URL inspection rows, opportunity records, and idea-ingest request.
  - User story link : Enables typed contracts for connection, diagnosis, and editorial opportunities.
  - Depends on : None
  - Validate with : `python3 -m pytest tests/test_search_console_models.py`
  - Notes : Use snake_case JSON in backend; Flutter can map as needed.

- [ ] Tache 2 : Add project-scoped Search Console storage
  - Fichier : `lab/api/services/search_console_store.py`
  - Action : Create store methods for `GoogleOAuthState`, `SearchConsoleConnection`, `SearchConsoleProjectProperty`, `SearchConsoleSnapshot`, and optional `SearchConsoleInspectionResult` using Turso/libSQL async client.
  - User story link : Persists connection status and cached insight state.
  - Depends on : Tache 1
  - Validate with : `python3 -m pytest tests/test_search_console_store.py`
  - Notes : Store encrypted OAuth tokens via `UserProviderCredential` provider `google_search_console_oauth`; store only property URL, project ID, status, scopes, selected account metadata, and timestamps in project config.

- [ ] Tache 3 : Ensure Search Console tables at startup
  - Fichier : `lab/api/main.py`
  - Action : Call `search_console_store.ensure_tables()` when Turso is configured, following existing `user_key_store`, `analytics_store`, and `feedback_store` patterns.
  - User story link : Makes the feature durable in production.
  - Depends on : Tache 2
  - Validate with : startup smoke test and store tests.
  - Notes : Do not edit legacy local SQLite paths.

- [ ] Tache 4 : Implement credential-aware Search Console service
  - Fichier : `lab/api/services/search_console_service.py`
  - Action : Build Google API clients from the authenticated user's encrypted OAuth refresh/access tokens, refresh expired access tokens, list accessible properties, query Search Analytics, inspect selected URLs, validate property access, normalize `sc-domain:` and URL-prefix properties, and return structured errors.
  - User story link : Pulls the real search data behind the natural-language dashboard.
  - Depends on : Tache 1, Tache 2
  - Validate with : `python3 -m pytest tests/test_search_console_service.py`
  - Notes : Do not rely on process env service-account credentials for this feature. Keep `gsc_client.py` intact unless a small shared helper extraction reduces duplication.

- [ ] Tache 4b : Add separate site-traffic context aggregation
  - Fichiers :
    - `lab/api/services/search_console_service.py`
    - `lab/api/services/analytics_store.py`
  - Action : Return Search Console metrics and first-party analytics context in separate response objects for Today, Last 7 days, Last 30 days/current month, Last 90 days, and Last 6 months; every metric row must include source provenance; never aggregate them into one traffic total; return top visited pages and top organic landing pages separately.
  - User story link : Gives users the principal metrics they expect before deeper SEO interpretation.
  - Depends on : Tache 4
  - Validate with : `python3 -m pytest tests/test_search_console_traffic_overview.py`
  - Notes : Do not label pageviews as unique people. Do not mix first-party analytics rows into Search Console evidence. If unique visitor/session tracking is added, use privacy-safe anonymous/session identifiers and update this spec before implementation.

- [ ] Tache 5 : Add Search Console OAuth and API router
  - Fichier : `lab/api/routers/search_console.py`
  - Action : Expose authenticated endpoints:
    - `GET /api/search-console/status?projectId=...`
    - `POST /api/search-console/oauth/start`
    - `GET /api/search-console/oauth/callback`
    - `POST /api/search-console/property`
    - `DELETE /api/search-console/connection?projectId=...`
    - `POST /api/search-console/validate`
    - `POST /api/search-console/sync`
    - `GET /api/search-console/summary?projectId=...&period=30d`
    - `GET /api/search-console/opportunities?projectId=...&period=30d`
    - `POST /api/search-console/opportunities/ingest`
  - User story link : Gives the app a full connection, sync, insight, and ingestion surface.
  - Depends on : Tache 4
  - Validate with : `python3 -m pytest tests/test_search_console_router.py`
  - Notes : Use project ownership checks before any credential lookup or Google API call. OAuth callback state must bind user, optional project, redirect intent, expiry, and one-time use.

- [ ] Tache 6 : Register Search Console router
  - Fichier : `lab/api/main.py`
  - Action : Import and include the new router.
  - User story link : Makes the feature reachable by the Flutter app.
  - Depends on : Tache 5
  - Validate with : route list or API smoke test.
  - Notes : Keep route prefix `/api/search-console`.

- [ ] Tache 7 : Implement insight and opportunity scoring
  - Fichier : `lab/agents/sources/search_console_feedback.py`
  - Action : Convert Search Analytics and URL Inspection rows into natural-language summary bullets and structured opportunities with reason, evidence, confidence, priority score, suggested action, target URL/query, and optional content record link.
  - User story link : Translates raw GSC data into "what should I do next?"
  - Depends on : Tache 4
  - Validate with : `python3 -m pytest tests/test_search_console_feedback.py`
  - Notes : Baseline copy must be deterministic and locale-ready. LLM polish can be a later optional enhancement.

- [ ] Tache 8 : Link opportunities to local content records
  - Fichier : `lab/agents/sources/search_console_feedback.py`
  - Action : Match GSC page URLs to `ContentRecord.target_url`, `content_path`, or normalized path. Include match confidence and never block if no match exists.
  - User story link : Allows ContentGlowz to decide whether to refresh existing content or create new content.
  - Depends on : Tache 7
  - Validate with : feedback tests covering target_url, content_path, and no-match cases.
  - Notes : Use owned project scope in all status service reads.

- [ ] Tache 9 : Ingest selected opportunities into Idea Pool
  - Fichier : `lab/api/routers/search_console.py`
  - Action : Implement `/opportunities/ingest` so selected opportunities create deduped `IdeaRecord` rows with source `search_console_feedback`, `raw_data`, `seo_signals`, `tags`, `priority_score`, `project_id`, and `user_id`.
  - User story link : Bridges Search Console insight to the existing content engine.
  - Depends on : Tache 7, Tache 8
  - Validate with : router tests and Idea Pool list assertions.
  - Notes : User action is required; no automatic generation.

- [ ] Tache 10 : Add Idea Pool source support
  - Fichier : `lab/api/models/idea_pool.py`
  - Action : Add `SEARCH_CONSOLE_FEEDBACK = "search_console_feedback"` to `IdeaSource`.
  - User story link : Makes GSC-derived ideas first-class.
  - Depends on : Tache 9
  - Validate with : existing Idea Pool tests plus source label checks.
  - Notes : Current requests accept string sources, but enum and docs should still be aligned.

- [ ] Tache 11 : Preserve Search Console evidence in pipeline metadata
  - Fichier : `lab/api/routers/psychology.py`
  - Action : Ensure `dispatch_pipeline` keeps `search_console_evidence`, `seo_signals`, `source_idea_ids`, and target URL/query from GSC ideas when creating `ContentRecord.metadata`.
  - User story link : Keeps downstream content decisions explainable.
  - Depends on : Tache 9
  - Validate with : `python3 -m pytest tests/test_psychology_search_console_metadata.py`
  - Notes : Do not change pipeline behavior for non-GSC ideas.

- [ ] Tache 12 : Add Flutter data models and API client methods
  - Fichiers :
    - `app/lib/data/models/search_console.dart`
    - `app/lib/data/services/api_service.dart`
  - Action : Add models and API calls for status, OAuth start/callback completion handoff, automatic property binding state, fallback property confirmation, disconnect, validate, sync, summary, opportunities, and ingest.
  - User story link : Lets the app render and act on Search Console state.
  - Depends on : Tache 5
  - Validate with : Flutter unit tests for JSON parsing and API method paths.
  - Notes : Keep offline/degraded read patterns consistent with existing API service behavior.

- [ ] Tache 13 : Add GSC connection UI in Integrations
  - Fichier : `app/lib/presentation/screens/settings/integrations_screen.dart`
  - Action : Add a Google Search Console settings group with "Connect Google" OAuth action, connected account/status display, automatically matched property display, fallback compatible-property choices when needed, disconnect/validate actions, and setup/verification guidance.
  - User story link : Gives users an interface to connect GSC.
  - Depends on : Tache 12
  - Validate with : Flutter widget tests for missing, connected, valid, invalid, expired, and deleting states.
  - Notes : Launch OAuth in the platform browser/default browser, not an embedded WebView.

- [ ] Tache 14 : Replace analytics-first screen with SEO Stats
  - Fichier : `app/lib/presentation/screens/analytics/analytics_screen.dart`
  - Action : Make Search Console SEO Stats the first viewport: connection state, sync action, global period selector/cards for Today, Last 7 days, Last 30 days/current month, Last 90 days, Last 6 months, a default natural-language overview, a "Google Search" section with organic clicks, impressions, CTR, average position, top organic landing pages/queries, opportunities, and degraded-state messages, plus a "Site traffic" section with first-party visits/pageviews and most visited site pages when available. Use source labels or tooltips on cards; do not add a mandatory source filter as the primary UX.
  - User story link : Gives users the language-level explanation they asked for.
  - Depends on : Tache 12
  - Validate with : Flutter widget tests and manual mobile/desktop check.
  - Notes : If this makes `AnalyticsScreen` too large, extract widgets to `app/lib/presentation/screens/analytics/search_console_panel.dart`.

- [ ] Tache 15 : Add opportunity ingestion actions in Flutter
  - Fichier : `app/lib/presentation/screens/analytics/search_console_panel.dart`
  - Action : Add selectable opportunities and "Add to Idea Pool" action with success/error snackbar and Idea Pool invalidation.
  - User story link : Turns insight into content queue decisions.
  - Depends on : Tache 14
  - Validate with : widget test for selected opportunities and API call.
  - Notes : Never auto-ingest on sync.

- [ ] Tache 16 : Update Idea Pool UI labels and filters
  - Fichiers :
    - `app/lib/data/models/idea.dart`
    - `app/lib/presentation/screens/idea_pool/idea_pool_screen.dart`
    - `app/lib/l10n/app_localizations.dart`
  - Action : Add source label/filter/color for `search_console_feedback` and display GSC evidence chips when present.
  - User story link : Makes GSC-derived ideas legible during review.
  - Depends on : Tache 9
  - Validate with : widget test for GSC idea card.
  - Notes : Keep card density suitable for repeated review workflows.

- [ ] Tache 17 : Add backend tests
  - Fichiers :
    - `lab/tests/test_search_console_service.py`
    - `lab/tests/test_search_console_router.py`
    - `lab/tests/test_search_console_feedback.py`
  - Action : Cover OAuth start/callback state validation, token refresh/revocation, property validation, ownership, quota degradation, snapshot caching, opportunity scoring, dedupe, idea ingestion, and token redaction.
  - User story link : Proves the critical contracts are safe and testable.
  - Depends on : Tache 1 through Tache 11
  - Validate with : `python3 -m pytest tests/test_search_console_service.py tests/test_search_console_router.py tests/test_search_console_feedback.py`
  - Notes : Mock Google clients; do not hit live Google APIs in CI.

- [ ] Tache 18 : Add Flutter tests
  - Fichiers :
    - `app/test/presentation/settings/search_console_integration_test.dart`
    - `app/test/presentation/analytics/search_console_panel_test.dart`
  - Action : Cover OAuth connection states, property selection, validation messages, summary/degraded states, SEO Stats replacing analytics-first layout, and opportunity ingestion action.
  - User story link : Proves the user-facing interface works.
  - Depends on : Tache 12 through Tache 16
  - Validate with : `flutter test test/presentation/settings/search_console_integration_test.dart test/presentation/analytics/search_console_panel_test.dart`
  - Notes : Reuse existing provider override/test patterns.

- [ ] Tache 19 : Update docs and environment examples
  - Fichiers :
    - `lab/README.md`
    - `lab/.env.example`
    - `lab/CHANGELOG.md`
    - `app/lib/l10n/app_localizations.dart`
  - Action : Document OAuth setup, consent screen requirements, callback URL, limitations, GSC data interpretation, quota/degraded states, and no ranking guarantee.
  - User story link : Reduces setup confusion and product overpromising.
  - Depends on : Tache 13, Tache 14
  - Validate with : docs review and grep for stale `GOOGLE_INDEXING_API_KEY` guidance if not used.
  - Notes : Keep Drip Indexing API docs separate from Search Console Intelligence docs.

## Acceptance Criteria

- [ ] CA 1 : Given a user owns a project with a configured domain, when they open Integrations, then they can see a Google Search Console OAuth connection block.
- [ ] CA 2 : Given a user clicks Connect Google Search Console, when Google redirects back with a valid authorization code and state, then the backend exchanges the code, stores encrypted tokens, and returns a connected status without exposing tokens.
- [ ] CA 3 : Given an expired, missing, replayed, or wrong-user OAuth state, when callback is received, then the backend rejects the callback and stores no tokens.
- [ ] CA 4 : Given the connected Google account lacks Search Console property access for the selected ContentGlowz project domain, when OAuth/validation runs, then the status explains that no compatible property could be attached and instructs the user to use an account with access.
- [ ] CA 5 : Given a valid connection, when the user runs sync for 30d, then the backend queries Search Analytics, caches a snapshot, and returns clicks, impressions, CTR, position, and top rows.
- [ ] CA 5b : Given first-party analytics data exists for the project, when SEO Stats loads, then the interface shows site visits/pageviews for Today, Last 7 days, Last 30 days/current month, Last 90 days, and Last 6 months.
- [ ] CA 5c : Given Search Console data exists for the project, when SEO Stats loads, then the interface shows Google organic clicks for the same periods and does not call them total visitors.
- [ ] CA 5d : Given pageview and Search Console data both exist, when SEO Stats shows top pages, then it separates "Most visited pages on site" from "Top organic landing pages from Google".
- [ ] CA 5e : Given both data sources exist, when the backend returns SEO Stats, then Search Console metrics and first-party analytics context are separate objects and no API field presents a combined "total traffic" value from both sources.
- [ ] CA 5f : Given both data sources exist, when the user opens SEO Stats, then they see a default overview plus distinct "Google Search" and "Site traffic" sections, without needing to choose a source filter first.
- [ ] CA 5g : Given a summary sentence combines context from both sources, when it is rendered or tested, then each underlying evidence item has source provenance and no sentence claims a metric that was not present in source data.
- [ ] CA 6 : Given a valid connection and selected high-value URLs, when URL Inspection runs, then the backend stores bounded inspection results and marks partial/degraded status if quota is hit.
- [ ] CA 7 : Given fresh Search Console data, when the user opens `/analytics`, then SEO Stats is the first viewport and shows a natural-language summary that names the main movement, risk, and next recommended action.
- [ ] CA 8 : Given an indexed page with falling clicks, when opportunities are generated, then the system creates a `declining_clicks` opportunity with evidence and priority.
- [ ] CA 9 : Given a query/page with high impressions and low CTR, when opportunities are generated, then the system recommends title/meta or angle work rather than new content by default.
- [ ] CA 10 : Given a query with impressions and no matching content record, when opportunities are generated, then the system can classify it as a creation opportunity.
- [ ] CA 11 : Given selected opportunities, when the user clicks "Add to Idea Pool", then deduped `search_console_feedback` ideas appear in the Idea Pool for the same project.
- [ ] CA 12 : Given an existing matching GSC idea for the same URL/query/reason/period, when ingest is requested again, then no duplicate idea is created.
- [ ] CA 13 : Given a GSC idea is dispatched to the content pipeline, when a content record is created, then `source_idea_ids`, `seo_signals`, and GSC evidence remain in metadata.
- [ ] CA 14 : Given Google quota or load errors, when sync fails partially, then the UI shows degraded state and still displays the last successful snapshot if present.
- [ ] CA 15 : Given a user does not own a project, when they call any Search Console endpoint for it, then the API returns not found/forbidden without leaking config or data.
- [ ] CA 16 : Given no GSC data exists for a new site, when the user opens the dashboard, then the UI explains the empty state without presenting it as an error.
- [ ] CA 16b : Given today's data is partial, when the user views Today, then the UI labels it as partial or in progress instead of comparing it as a complete day.
- [ ] CA 17 : Given OAuth access is revoked or disconnected, when the user opens the dashboard, then sync actions are disabled and existing snapshots are labeled stale.
- [ ] CA 18 : Given app tests run, when backend and Flutter suites complete, then Search Console service/router/feedback and UI panel tests pass.

## Test Strategy

- Backend unit tests:
  - OAuth URL generation, state storage, callback exchange, token refresh, revoked-token handling, and mocked Google API resources.
  - Property normalization for URL-prefix and domain properties.
  - Search Analytics response mapping.
  - Traffic overview aggregation for today, 7d, 30d/month, 90d, and 6m.
  - Separation of first-party pageviews versus GSC organic clicks.
  - URL Inspection response mapping.
  - Opportunity scoring rules.
  - Natural-language summary deterministic fallback.
  - Token redaction and validation errors.
- Backend router tests:
  - Auth required.
  - Project ownership.
  - OAuth start/callback/disconnect/status/validate/sync/summary/opportunity/ingest endpoints.
  - Duplicate idea prevention.
  - Degraded quota behavior.
- Flutter unit/widget tests:
  - JSON model parsing.
  - Integrations GSC OAuth card states.
  - SEO Stats screen states: missing config, loading, summary, empty, degraded, stale.
  - SEO Stats metric cards and top page lists for all required periods.
  - Opportunity selection and ingest action.
- Manual QA:
- Configure a test Google OAuth client and Search Console property matching the selected ContentGlowz project domain.
- Connect an account through OAuth and confirm the backend auto-attaches the matching property without requiring routine user selection.
  - Run sync for 7d and 30d.
  - Confirm no raw OAuth token appears in network responses/logs.
  - Ingest one opportunity and confirm it appears in Idea Pool.
  - Dispatch the idea to article generation and confirm metadata keeps evidence.

## Risks

- Security risk: OAuth refresh tokens are sensitive. Mitigation: encrypt with existing credential store, never echo raw tokens, add redaction tests.
- OAuth launch risk: public use of Search Console scopes may require Google verification. Mitigation: document verification requirements, start with least-privilege `webmasters.readonly`, and keep service-account/operator fallback separate if needed.
- Tenant-boundary risk: GSC data could leak across projects/users. Mitigation: ownership checks before every config/snapshot read and write.
- Data-source confusion risk: implementers or users may treat private analytics as Search Console data. Mitigation: separate API objects, separate UI rails, explicit labels, and tests that assert no combined traffic total.
- Product-trust risk: the system could overstate causality. Mitigation: factual copy and confidence labels; no ranking guarantees.
- Google quota risk: Search Analytics and URL Inspection can degrade under expensive queries. Mitigation: cache snapshots, cap ranges, inspect only sampled URLs.
- Metric-trust risk: users may interpret clicks/pageviews as unique people. Mitigation: precise labels and no "people" wording unless unique visitor tracking exists.
- Implementation risk: current `gsc_client.py` is environment-credential based. Mitigation: implement OAuth credential client in a separate service or inject credentials cleanly.
- UX risk: OAuth connection can fail because of Google consent, Workspace policy, or unverified app state. Mitigation: explicit status messages and setup docs.
- Data-quality risk: GSC data is delayed/incomplete for recent dates. Mitigation: compare stable windows and label incomplete/recent data.
- Scope risk: this can sprawl into a full SEO suite. Mitigation: MVP ends at insights plus Idea Pool ingestion, not automatic publishing.

## Execution Notes

Read these first before implementation:

- `lab/api/services/gsc_client.py`
- `lab/api/routers/settings_integrations.py`
- `lab/api/routers/integrations.py`
- `lab/api/services/user_key_store.py`
- `lab/api/routers/idea_pool.py`
- `lab/api/routers/psychology.py`
- `app/lib/presentation/screens/settings/integrations_screen.dart`
- `app/lib/presentation/screens/analytics/analytics_screen.dart`
- `app/lib/presentation/screens/idea_pool/idea_pool_screen.dart`

Implementation approach:

1. Build backend contracts and storage first.
2. Add service and router with mocked Google tests.
3. Add opportunity scoring and Idea Pool ingestion.
4. Add Flutter API/models.
5. Add Settings OAuth connection UI.
6. Replace Analytics first viewport with SEO Stats/Search Console panel.
7. Align Idea Pool labels and metadata.
8. Run backend and Flutter tests.

Packages:

- Use existing `google-api-python-client` and `google-auth`.
- Prefer existing `httpx` plus `google-auth` primitives for OAuth token exchange/refresh unless a small official Google helper package is clearly justified.
- Do not add a new analytics vendor.

Stop conditions / reroute:

- If Google OAuth verification or consent-screen requirements block public rollout, keep the feature behind an internal/tester gate and create a release-readiness follow-up before shipping publicly.
- If Turso schema changes require a migration policy beyond idempotent ensure-table methods, route through `contentglowz-turso-migrations`.
- If Drip GSC behavior must be merged with this feature immediately, update this spec before coding.
- If live Google validation is required in CI, stop; tests must mock Google APIs.

## Open Questions

None.

Deferred non-MVP decisions:

- Organization-level shared GSC credentials.
- Automatic scheduled sync cadence and notification policy.
- Automatic content generation from high-confidence opportunities.
- Merging Drip GSC configuration with Search Console Intelligence configuration.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 14:04:51 UTC | sf-spec | GPT-5 Codex | Created Search Console Intelligence spec from user request and repo investigation. | Draft spec saved. | /sf-ready Google Search Console intelligence |
| 2026-05-11 14:10:04 UTC | sf-spec | GPT-5 Codex | Updated spec to make Google OAuth primary and SEO Stats the replacement for the analytics-first screen. | Draft spec updated. | /sf-ready Google Search Console intelligence |
| 2026-05-11 14:19:39 UTC | sf-spec | GPT-5 Codex | Added explicit SEO Stats traffic metrics, required periods, top pages, and metric-label semantics. | Draft spec updated. | /sf-ready Google Search Console intelligence |
| 2026-05-11 14:33:30 UTC | sf-ready | GPT-5 Codex | Ran readiness gate, tightened metric semantics, verified task ordering, security posture, and fresh official Google docs coverage. | ready | /sf-start Google Search Console intelligence |
| 2026-05-11 14:35:43 UTC | sf-spec | GPT-5 Codex | Clarified that Google Search Console and private analytics are separate data sources even when shown in one SEO Stats surface. | Ready spec clarified. | /sf-start Google Search Console intelligence |
| 2026-05-11 14:42:54 UTC | sf-spec | GPT-5 Codex | Captured UX decision: default overview plus two source sections, with provenance instead of a mandatory source filter. | Ready spec clarified. | /sf-start Google Search Console intelligence |
| 2026-05-11 15:08:30 UTC | sf-start | gpt-5.3-codex | Implémentation MVP backend Search Console: OAuth state one-time, stockage chiffré tokens, router `/api/search-console`, sync/summaries/opportunities source-aware, ingestion Idea Pool dédupliquée, ensure tables, tests ciblés, docs/env. | partial | /sf-start Google Search Console intelligence continue |
| 2026-05-11 15:09:21 UTC | sf-start | GPT-5 Codex | Parent review: removed premature changelog entry, added camelCase request validation support, and fixed OAuth state fallback consumption. | partial | /sf-start Google Search Console intelligence continue |
| 2026-05-11 16:12:19 UTC | sf-start | GPT-5 Codex | Continued implementation: added Flutter Search Console models/API/providers, Integrations OAuth/property UI, SEO Stats first viewport with Google Search and private analytics sections, opportunity selection/Idea Pool ingest UI, Idea Pool source labels/evidence chips/l10n, spec-aligned OAuth/disconnect aliases, and focused backend/Flutter tests. | partial | /sf-start Google Search Console intelligence continue |
| 2026-05-11 16:24:34 UTC | sf-start | GPT-5 Codex | Hardened local implementation: property list endpoint/UI from accessible Google properties, property selection now requires connected OAuth access, URL Inspection runs as bounded sync sample with degraded fallback, SEO Stats displays inspection metrics/issues, refresh-token revocation and quota-degradation tests added. | implemented | /sf-ship Google Search Console intelligence |
| 2026-05-11 16:44:27 UTC | sf-verify | GPT-5 Codex | Verified the spec against the local backend and Flutter implementation; fixed disconnect stale-snapshot preservation and disabled sync when the connection/property is not usable; local checks pass. Hosted OAuth/callback proof remains pending because `app` is `hybrid`. | partial | /sf-ship Google Search Console intelligence |
| 2026-05-12 17:25:15 UTC | sf-ship | GPT-5 Codex | Quick ship for Google Search Console Intelligence: committed backend OAuth/search-console module, Flutter SEO Stats UI, auto project-domain property binding, source-aware metrics, Idea Pool bridge, docs/env updates, and targeted tests. | shipped | /sf-prod app |

## Current Chantier Flow

- sf-spec: done
- sf-ready: done
- sf-start: implemented locally; hosted OAuth proof pending
- sf-verify: partial; local checks pass; hosted OAuth/callback proof pending
- sf-end: not launched
- sf-ship: quick shipped; hosted OAuth proof pending

Next lifecycle step: `/sf-prod app`, then `/sf-auth-debug Google Search Console OAuth callback` for hosted OAuth/callback proof before final verification.
