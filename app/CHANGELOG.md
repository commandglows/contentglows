# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog.

## [Unreleased]

### Added
- Added the `/editor/:id/video` timeline workspace with text/asset clip editing, clean-version preview gating, final-render gating, and signed artifact token redaction in the visible UI.
- Added Android pro recorder Batch 2 native session-control groundwork in the content capture path (typed recorder state events, foreground pause/resume/stop wiring, and configuration preflight contracts); camera overlay composition and Android-device validation remain pending.

### Changed
- Redesigned the empty mobile Flow dashboard into a compact swipe-action deck with one CTA per card and hidden zero-count workspace cards.

### Fixed
- Coalesced concurrent app access refreshes for the same Clerk session so resume and manual refresh flows share one backend health/bootstrap pass.
- Fixed the Clerk email sign-up OTP flow by switching the embedded SignUp component to hash routing on the static auth page and skipping duplicate mounts on the same node.
- Fixed production API availability detection when `API_BASE_URL` is injected as a bare host such as `api.contentglows.com`; the app now normalizes it to an HTTPS origin before health checks.
- Fixed Android system Back in the app shell so pushed in-app routes pop to their parent before showing the app-exit confirmation dialog.

## [2026-06-12]

### Changed
- Pinned the Flutter toolchain contract to the checked-in `.flutter-version` source and hardened the Vercel/local web build scripts so version checks and Dart defines remain reproducible.
- Updated safe direct app dependencies within the existing major lines for routing, fonts, audio feedback, and Sentry while keeping native recorder migration risk out of scope.

### Security
- Replaced the floating Vercel Flutter `stable` branch clone path with a pinned archive install flow plus checksum verification.

### Removed
- Removed unused direct Riverpod/JSON/image/responsive dependencies and the dead codegen toolchain from the app manifest and resolved lockfile.

## [2026-05-04]

### Added
- Added Android-first local device capture with MediaProjection screenshots, foreground-service screen recording, optional microphone audio, local capture history, preview, discard, and share/export.
- Added local capture-to-content linking so Android captures can create manual content drafts or attach to pending content without uploading media files.
- Added focused capture model/store/widget coverage and documented the local-only Android capture scope.
- Added GitHub Actions APK build documentation for the Blacksmith runner workflow and CLI artifact retrieval.

### Security
- Kept captured screen media local-only in V1 with no backend file upload, synced cloud media library, or offline binary replay; backend capture asset records store metadata only.

## [2026-05-02]

### Fixed
- Prevented feed previews from being treated as authoritative content bodies in editor and publish flows.
- Blocked cached full-body fallback after authorization failures so protected content edits require a valid body response.

## [2026-04-28]

### Added
- Added project-scoped Zernio/LATE publish persistence for profiles, account mappings, and one-use connect sessions.
- Added backend regressions for project-scoped account listing, forged account refusal before provider calls, connect state handling, local unlink, scheduled/published results, and partial publish recovery.

### Changed
- Scoped publish account listing, connect, disconnect, and approve-to-publish flows to the active ContentGlows project instead of a provider-wide account list.
- Documented server-only `ZERNIO_API_KEY`, unsupported WordPress/Ghost auto-publish behavior, and manual Zernio smoke verification steps.

### Security
- Prevented client-supplied or cross-project Zernio account ids from reaching the provider before local `userId + projectId` authorization succeeds.
- Revalidated Zernio connect callbacks against persisted server state and current project ownership before creating local mappings.

## [2026-04-27]

### Changed
- Migrated Flutter core majors to stable hosted versions on `https://pub.dev`: `flutter_riverpod 3.3.1`, `riverpod_annotation 4.0.2`, `riverpod_generator 4.0.3` (dev), `go_router 17.2.2`, `google_fonts 8.0.2`.

### Verified
- Migration validation gate passed: `flutter analyze`, `flutter test`, and `dart run build_runner build --delete-conflicting-outputs`.
- Accepted transitive dev exception required by `riverpod_generator 4.0.3`: `riverpod_analyzer_utils 1.0.0-dev.9` (hosted on `https://pub.dev`).
- Scope remained Flutter app dependency/runtime only; no backend FastAPI or Turso/libSQL changes were introduced by this migration.

## [2026-04-26]

### Added
- Added a dedicated ClerkJS `/sign-up` auth page so email account creation no longer falls through to the Flutter app.

### Fixed
- Fixed Clerk sign-up routing by pointing the sign-in widget at `/sign-up` and serving Clerk's sign-in/sign-up sub-routes from the auth pages instead of the SPA fallback.

## [2026-04-25]

### Added
- Added widget coverage for project management and picker flows: active summary/no duplicate active card rendering, archived section rendering, and picker commands for explicit no-selection and create-project intent routing.

### Changed
- Project selection now persists as tri-state mode (`auto`, `selected`, `none`) so users can explicitly keep no active project without fallback auto-selection.
- Onboarding/project source input now accepts optional source URLs (HTTP/S), no longer forcing GitHub-only repository links.

### Fixed
- Project lifecycle handling now follows archive-first behavior in app flows, with unarchive support and clearer handling of archived projects in selection surfaces.

## [2026-04-23]

### Added
- Added dedicated resume no-jump regression coverage for guarded routes, including `/settings`, deep in-app routes, degraded backend mode, and unauthorized single-redirect behavior.
- Added notifier-level access refresh tests with mocked API scenarios to verify `silentResume` vs `interactive` stage behavior across healthy, degraded, and unauthorized outcomes.

### Changed
- Stabilized app resume checks so authenticated users keep the current route while lifecycle revalidation runs in background-first mode.
- Switched app router wiring to a stable provider-backed `GoRouter` instance with refresh listening on app access state.

### Fixed
- Fixed resume-time UI bounce regressions that could previously route users through `/entry` during transient access checks.
- Fixed unauthorized resume handling to avoid redirect loops by allowing a single transition to `/entry` and stopping there.

## [2026-04-22]

### Added
- Added an OpenRouter settings card with masked key status, save, validate, delete, and direct OpenRouter access from the Settings screen.
- Added client models, API methods, and a Riverpod provider for the new `/api/settings/integrations/openrouter` backend flow.

### Changed
- Settings now surfaces OpenRouter credential state alongside backend health and GitHub integration so AI persona draft prerequisites are visible in-app.

## [2026-04-21]

### Added
- Added a GitHub repository picker for project and source selection flows, with explicit “configure integration” path when no OAuth provider is connected.
- Added a repository/project source selector for Drip wizard steps so users can pick content folders and sources directly from their connected project instead of typing paths.
- Added detailed contextual explanations in Drip onboarding steps for clustering strategy and publication/rebuild controls to support advanced users before plan execution.
- Added new random publication window fields (`publish_time_start`, `publish_time_end`) to Drip plans to support randomized scheduling within a selected daytime range.
- Added explicit GitHub connection actions in onboarding, drip and SEO screens to launch OAuth, open browser authentication, and return with refreshed connection status.
- Added a dedicated connection card in Settings that surfaces the current signed-in email, auth state, and a direct sign-out action.
- Added a dedicated Ritual shortcut in the shared Create navigation so the mobile More sheet exposes the ritual entry point directly.

### Fixed
- Fixed the in-app tour overlay layout/positioning compile regression by passing an `Offset` where required in widget offset calculations.
- Fixed GitHub OAuth error handling so backend configuration/auth failures are surfaced with copyable diagnostics instead of a silent unavailable state.
- Fixed session revalidation/routing so authenticated users stay on their current screen during background auth and bootstrap checks instead of bouncing through `/entry`.
- Fixed the empty Feed dashboard on mobile so action cards and status cards use the full width without right-side dead space or 320px overflow.
- Fixed the ritual naming in navigation and screen titles so the French UI now consistently shows `Rituel`.

## [2026-04-20]

### Added
- Added a persisted app theme preference with `light`, `dark`, and `system` modes, plus Flutter tests covering theme normalization and app-level theme restoration.
- Added a shared editorial theme palette and semantic color tokens so surfaces, accents, and status tones can be reused consistently across the Flutter shell.
- Added queue-aware offline sync badges on supported list surfaces so projects, personas, affiliations, content cards, and drip plans can show `Pending sync` or `Sync failed`.
- Added the offline sync V2 reference spec in `shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md` and aligned project documentation with the current degraded-mode behavior.
- Added a multi-project management flow with a dedicated `Projects` screen, a global current-project switcher, and backend-aligned project selection persistence.
- Added Drip plan scheduling window fields (`publish_time_start`, `publish_time_end`) so plans can configure random publish slots instead of one fixed time.

### Changed
- Switched the Flutter app shell to load both light and dark themes and resolve `ThemeMode` from user settings instead of forcing a single dark theme.
- Added an Appearance section in Settings so users can switch theme mode manually while still supporting automatic system-follow behavior.
- Migrated the Flutter screen layer to rely on `Theme.of(context)` and `AppTheme.paletteOf(context)` for most surfaces, borders, text, overlays, and status accents instead of local color constants.
- Expanded degraded/offline mode from a limited shell into a broader client-side sync model with persisted cache, dependency-aware replay queue, and temp-ID reconciliation for supported creates.
- Extended offline support to broad app flows including content creation from angles and drip plan create/update/lifecycle actions, while keeping uploads, deletes, and publish actions explicitly blocked offline.
- Project selection now treats `settings.defaultProjectId` as the persisted “last opened project” and surfaces detected repository config such as content directories and configured sources in the Flutter project UI.
- Drip plan wizard now validates and sends hourly publish windows (`publish_time_start`/`publish_time_end`) in cadence payloads.

### Fixed
- Fixed the light-theme rollout by removing the remaining hard-coded screen colors that were keeping multiple flows visually dark-only or low-contrast in light mode.
- Fixed Drip reads to avoid masking non-offline failures as empty cached views; malformed backend payloads now raise actionable errors while cache fallback stays offline-safe.
- Updated offline sync chips so `Retrying`, `Sync paused`, and `Waiting for dependency` now map to distinct user-visible badges instead of always showing `Pending sync` unless failed.
- Removed unsupported project archive/unarchive affordances from the Flutter UI so project actions now match the real FastAPI backend contract.
- Fixed session revalidation during app resume so background auth/backend checks no longer force authenticated screens back to `/entry`.

## [2026-04-19]

### Added
- Added a centralized app access state and degraded-mode shell so the Flutter app now distinguishes Clerk auth, FastAPI health, and workspace bootstrap instead of collapsing backend outages into fake sign-in failures.
- Added a Feedback Admin v1 client flow with text feedback, audio feedback recording/upload, local draft persistence, and lightweight local history for recently sent entries.
- Added an in-app feedback admin screen with filters, audio playback, review actions, and supporting docs for the expected FastAPI feedback contract.
- Added a centralized in-app diagnostics/log buffer plus reusable copy-to-clipboard error widgets so runtime, Riverpod, auth, bootstrap, and API failures can be exported directly from the UI.
- Added app-level language preference handling with `system` / `english` / `french` options persisted via SharedPreferences and wired into the Flutter shell.

### Changed
- Stopped sending `edited_by` and `changed_by` from the Flutter client for content body saves and status transitions so the backend becomes the sole source of truth for audit attribution.
- Reworked entry, routing, uptime, and settings flows around explicit backend availability checks, richer diagnostics, and degraded-mode messaging when FastAPI is unavailable.
- Wired the Flutter web build/runtime config to compile `FEEDBACK_ADMIN_EMAILS`, surface the feedback admin entry point for allowlisted emails, and expose a public feedback entry point from the landing screen.
- Unified auth, entry, uptime, degraded-mode, and multiple screen-level error states around shared diagnostics panels and snackbars instead of one-off debug blocks.
- Localized the editor, drip planning screens, platform previews, uptime, work domains, runs, research, and settings flows so the French UI is selectable throughout the current shell.
- Completed the Flutter side of the Content Drip UI with the plan list, creation wizard, detail dashboard, lifecycle actions, and translated status/config copy.

### Fixed
- Fixed the Clerk web OAuth redirect flow so Google sign-in returns through `/sso-callback` before landing on `/#/entry`, allowing Clerk session finalization to complete.
- Fixed onboarding/workspace creation guards so unauthenticated users can no longer create a workspace and backend outages no longer masquerade as broken Clerk sessions.
- Fixed anonymous feedback access by moving the feedback route outside the authenticated shell so signed-out users can still submit product feedback.
- Fixed the inability to copy signup/bootstrap/runtime failures from the app by surfacing copy actions anywhere an error card or error snackbar is shown.

## [2026-04-13]

### Added
- Added a website-driven web auth handoff so `site` can authenticate with Clerk and open Flutter web through `/api/auth/web/exchange` on `/entry`.

### Changed
- Reworked the Flutter auth screen around the official Clerk UI so password-manager autofill and configured social providers can be rendered by the SDK instead of a custom form.
- Switched Flutter web to redirect users toward the main website for sign-in instead of relying on the unsupported `clerk_flutter` web UI.

### Fixed
- Replaced the infinite auth spinner with explicit Clerk SDK initialization states, including a timeout and surfaced diagnostics when Clerk fails to load.

## [2026-04-12]

### Changed
- Rebranded the Flutter app from `ContentGlowsz` to `ContentGlows` across the app shell, entry/auth/settings copy, web metadata, Android package identifiers, and project documentation.
- Switched the default deployed API base URL from local development to `https://api.contentglows.com` in runtime config, PM2/Vercel build scripts, and README examples.

### Fixed
- Corrected the generated Android entrypoint/package path to match the renamed `com.contentglows.app` namespace.
- Regenerated Flutter web output so the built assets, manifest, bootstrap metadata, and service worker version align with the current app identity.

## [0.7.0] - 2026-04-11 — Mobile UX Overhaul

### Changed
- **Bottom navigation redesigned**: replaced unusable 18-item horizontal scroll with a 5-tab bar (Feed, Schedule, History, Drip, More) + categorized bottom sheet for all other screens.
- **Entry screen responsive**: hero text scales from 28px→36px→48px based on viewport width; feature/step cards go full-width on mobile instead of fixed 320/350px.
- **Pain vs Flow section**: fixed `Expanded` inside `Column` crash on compact layout; now uses conditional Row/Column correctly.
- **Feed action buttons**: replaced `GestureDetector` with `Material` + `InkWell` for visible ripple touch feedback on mobile.
- **Content card footer**: swipe hints hide on screens narrower than 380px to prevent overflow; spacing tightened.
- **Settings frequency sliders**: stacks label/slider vertically on screens narrower than 360px instead of cramped horizontal layout.

### Fixed
- **Idea Pool action buttons**: increased touch targets from ~24px to 44px minimum height (WCAG 2.5.8 compliance).

## [0.6.0] - 2026-03-27 — DataForSEO Integration

### Added
- **DataForSEO API v3 client** (`dataforseo_client.py`): reusable HTTP client with Basic Auth for SERP, keywords, trends, competitors, search intent, domain rank.
- **DFS provider** (`dataforseo_provider.py`): DFSSERPAnalyzer, DFSTrendMonitor, DFSKeywordGapFinder, DFSRankingPatternExtractor — real data instead of mocks.
- **Level 1 — SEO keyword ingestion**: `ingest_seo_keywords()` rewritten with DFS `keyword_ideas` + `keyword_overview`. Each idea gets real volume, difficulty, CPC, intent, opportunity_score.
- **Level 2 — Idea enrichment**: new `enrich_ideas()` batch-enriches raw ideas via DFS `keyword_overview`, computes `priority_score`, transitions to status `enriched`.
- **Level 3 — Competitor intelligence**: new `ingest_competitor_watch()` uses DFS `domain_intersection` + `ranked_keywords` to find content gaps and competitor keywords.
- **Level 4 — SERP position tracking**: new `track_serp_positions()` checks Google rankings for published content, stores 90-day position history in content metadata.
- **SERP feedback loop**: `_evaluate_serp_feedback()` creates refresh ideas (source=`serp_feedback`) when content is never ranked, declining, or stuck on page 2.
- **Angle Strategist bridge**: optional step in `_run_article_job` (opt-in via `use_angle_strategist` config) that feeds enriched SEO data through the Angle Strategist before the SEO Crew.
- **3 new API endpoints**: `POST /api/ideas/enrich`, `POST /api/ideas/ingest/competitors`, `POST /api/ideas/track-serp`.
- **3 new scheduler job types**: `enrich_ideas`, `ingest_competitors`, `track_serp`.
- `DFS_CONFIG` in `research_config.py` with location, language, depth settings.
- `DATAFORSEO_LOGIN` and `DATAFORSEO_PASSWORD` in `.env.example`.

### Changed
- `research_tools.py` rewritten: SerpApi removed, DFS provider classes used directly. Same `@tool` wrappers for CrewAI agents.
- `_run_article_job` now passes `competitor_domains`, `sector`, `business_goals`, `brand_voice`, `target_audience`, `tone` to SEO Crew (were ignored before).
- Content record metadata now includes `target_keyword`, `seo_signals`, `source_idea_id` for SERP tracker traceability.
- `ingest_seo_keywords` default `max_keywords` raised from 30 to 50.

### Removed
- SerpApi dependency (`serpapi` package) and `SERP_API_KEY` from `.env.example`.
- Mock/hardcoded data in `TrendMonitor` (trend_score: 75.0) and `KeywordGapFinder` (search_volume: 1000).
- `SEO_PROVIDER` env var toggle (no longer needed, DFS is the only provider).

## [0.5.0] - 2026-03-26 — Unified Content Pipeline

### Added
- **Idea Pool** (backend): new SQLite table + CRUD API `/api/ideas` for aggregating content ideas from all sources (newsletters, SEO keywords, weekly ritual, competitor watch).
- **Source ingestion** (backend): `ingest_newsletter_inbox()` reads emails via IMAP, `ingest_seo_keywords()` generates keywords via Advertools, `ingest_weekly_ritual()` converts ritual entries — all feed the Idea Pool.
- **Enriched Angle Generation** (backend): Angle Strategist now accepts `seo_signals` and `trending_signals`, returns `priority_score` and `seo_keyword` per angle.
- **Pipeline Dispatch** (backend): `POST /api/psychology/dispatch-pipeline` replaces the static `render-extract` placeholder with real async content generation.
- **Short Content Agent** (backend): new CrewAI agent for TikTok/Reels/YouTube Shorts — generates hook, timed script, hashtags, CTA, visual notes.
- **Social Post Agent** (backend): new CrewAI agent for Twitter/LinkedIn/Instagram — generates platform-adapted posts with thread support.
- **Scheduler jobs** (backend): implemented `_run_seo_job`, `_run_article_job` (were stubs), added `_run_short_job`, `_run_social_job`, `_run_ingest_newsletters`, `_run_ingest_seo`.
- **Content Frequency Config** (backend + Flutter): user sets blog/month, newsletters/week, shorts/day, social/day — scheduler auto-creates jobs to match.
- **ContentType.short** in Flutter enum with parser, serializer, icon, and theme color.
- **Format-specific metadata** in Flutter: content cards and editor show SEO keyword, platform, duration, hashtags, narrative thread depending on content type.
- **Settings: Content Frequency section** with sliders for each format.
- Spec document: `shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md`.
- Flutter repo initialized and pushed to GitHub (`dianedef/ContentGlows-app`).

### Changed
- Angles screen now calls `POST /api/psychology/dispatch-pipeline` for real content generation (with fallback to old `createContentFromAngle`).
- `ApiService`: added `dispatchPipeline()` and `getPipelineStatus()` methods.
- Backend enums extended: `ContentType.SHORT`, `ContentType.SOCIAL_POST`, `SourceRobot.SHORT`, `SourceRobot.SOCIAL`.
- `render-extract` endpoint marked as deprecated.

### Removed
- Legacy Next.js chatbot (41 MB) — frontend fully replaced by Flutter.
- 5 empty/unused v0 prototypes and brainstorm directories.
- BMAD framework files.
- Root `package-lock.json`, `ecosystem.config.cjs` symlink, `SPEC-chatbot.md`, `SPEC-features.md`.

## [0.4.0] - 2026-03-25 — Auth & Workspace Migration

### Added
- FastAPI Clerk auth foundation with authenticated `/api/me` and `/api/bootstrap` endpoints.
- FastAPI user data endpoints for `/api/settings`, `/api/creator-profile`, and `/api/personas`.
- Shared ownership helpers in FastAPI for project-scoped content access.
- Flutter session and bootstrap models to route through a single auth/bootstrap layer.
- Headless Clerk auth service, config layer, and dedicated auth screen in Flutter.
- SharedPreferences-backed Clerk persistence for restoring the real Flutter session.
- FastAPI-backed Flutter creator profile model/provider.
- Publish account parsing from `/api/publish/accounts` with real Zernio/LATE account IDs.
- Technical specs for LATE integration and target architecture.

### Changed
- Settings publishing channels now show real connected account state.
- Approve to publish flow resolves connected accounts and returns user-facing result messages.
- FastAPI projects router uses authenticated user context instead of `default-user`.
- Flutter router, entry screen, onboarding, and Dio client depend on centralized session state.
- Demo onboarding flow locked to one pre-populated public repository.
- Onboarding creates a real workspace via FastAPI.
- FastAPI publish routes require auth, verify ownership, persist Zernio metadata, and scope Zernio/LATE accounts to `userId + projectId`.
- Zernio connect/disconnect/account listing now uses local project-scoped mappings instead of provider-wide account exposure.

### Fixed
- Scheduling API method aligned with FastAPI (POST → PATCH).
- Feed and editor publish snackbars reflect actual outcome.
- Project route ownership enforced in FastAPI.
- Authenticated routes no longer silently fall back to mock data.
- 401 responses invalidate session explicitly.
