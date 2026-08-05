# Changelog

All notable changes to the ContentGlows monorepo are documented here.

## [2026-06-12]

### Changed
- Removed proven-unused direct/codegen Flutter dependencies from `app` and reconciled safe Pub updates so the remaining direct dependency drift is limited to the out-of-scope `record` major.
- Hardened the `app` Vercel Flutter install/build path around the pinned `.flutter-version` SDK source and archive checksum verification instead of a floating `stable` branch clone.

## [2026-06-10]

### Changed
- Updated competitive intelligence and backlog trackers with future inspiration for MCP/ChatGPT Apps distribution, LLM mentions/GEO reporting, Firecrawl PDF/document ingestion, Krotos-style SFX enrichment, Android creator workflows, and inference/model-routing benchmarks.

## [2026-05-30]

### Fixed
- Fixed the Clerk email sign-up OTP flow by keeping SignUp verification steps inside the static auth page hash route and guarding against duplicate Clerk component mounts.
- Fixed Flutter app API availability detection when production builds receive `API_BASE_URL` as `api.contentglows.com` without an explicit `https://` scheme.

### Added
- Added regression coverage for the dual-mode AI runtime platform branch and dispatch-pipeline provider matrices.

### Changed
- Centralized additional app/site design-token semantics for text, borders, app hero tint, and generated Flutter theme constants.
- Added real dark-mode support for the Astro site through semantic CSS variables, explicit `data-theme="dark"` support, `prefers-color-scheme: dark`, and matching browser theme colors.
- Reduced design-token literal debt under the tracked scan thresholds: Flutter 68/128 and Site 38/401.
- Refreshed the dual-mode AI runtime chantier status and marked the older strict-BYOK spec as superseded.

## [2026-05-14]

### Added
- Added AI asset understanding auto-tagging and recommendation capabilities across backend and Flutter surfaces: async understanding jobs, normalized suggested/accepted/rejected tag flows, confidence-scored fit reasons, and rights/attribution warnings for third-party/social footage.
- Added global-library candidate recommendation plus explicit project attach flow so same-user reusable assets can be suggested across projects with `candidate_global_asset` and `requires_project_attachment` semantics.
- Added the unified ContentGlows video timeline foundation across Flutter, FastAPI, and the Remotion worker, including versioned timeline APIs, render-safe asset resolution, preview/final gates, and a local Remotion MP4 smoke fixture.
- Added Remotion worker GCS artifact storage support, backend GCS signed playback URL handling, and a Cloud Run deployment runbook for durable video preview/final renders.

### Changed
- Extended the project asset workflow with deterministic media inspection guardrails (ffprobe/ffmpeg sampling limits, quota/concurrency bounds, BYOK-first credential resolution, and recoverable status outcomes) without auto-publishing or legal-rights assumptions.

## [2026-05-13]

### Added
- Prepared the Flux AI Provider for Image Robot backend foundation with guided Flux profiles, project-scoped visual references, asynchronous generation history, Bunny CDN asset persistence, and Flutter API client models/methods.

### Security
- Hardened remote image ingestion and Flux output handling with authenticated project ownership, durable Bunny-only returned assets, private-network URL rejection, MIME checks, byte limits, and normalized provider errors.

## [2026-05-11]

### Added
- Added a project-scoped asset library backend surface for listing, usage history, events, eligibility checks, primary selection, tombstone/restore, preview refresh, and cleanup reporting.
- Added Flutter project asset models, API methods, Riverpod state, a reusable picker, and an editor entry point for linking eligible project assets to content placements.

### Fixed
- Enforced server-side target ownership, media-kind compatibility, safe storage descriptors, and stale active-project guards across asset selection and primary mutations.

### Changed
- Documented the asset library as a guided project workflow layer, not a public DAM or arbitrary media playground.

## [Unreleased]

### Removed
- Removed generated Flutter web build artifacts from Git tracking so Vercel owns `app/build/web` generation during deployment.

### Added
- Added privacy capture planning artifacts for Android, Web, Windows, macOS, iOS, and Linux, plus shared contract, post-production review, and QA matrix documents.
- Added root monorepo task tracking and a site-specific tracker aligned with the ready Astro 6 migration spec.
- Added a ShipGlowz master dashboard entry for ContentGlows.
- Added Android APK CI setup documentation and a Blacksmith-backed GitHub Actions workflow.
- Added baseline `shipglows_data/technical/` governance for `app` and `site`.
- Added baseline `shipglows_data/editorial/` governance for the public Astro site.

### Changed
- Added bilingual `fr/en` core routes for the marketing site with English at `/`, French under `/fr`, localized homepage/privacy/handoff copy, and locale-aware `lang`, canonical, `og:url`, `hreflang`, and `x-default` metadata on the shipped core pages.
- Added bilingual `fr/en` blog routing with English articles under `/blog`, French articles under `/fr/blog`, locale-filtered blog indexes and tag pages, and locale-aware blog metadata plus localized shared blog CTAs/links.
- Reprioritized ContentGlows trackers so feedback production checks are no longer treated as the next blocking win after the admin allowlist was configured.
- Reconnected ContentGlows site and app Vercel auto-deploys to the organization monorepo and verified deployment from `main`.
- Reconciled the Flutter app tracker so the previously fixed light-mode contrast regression is marked done.
- Migrated `site` tracking to Astro 6 completion and documented the site migration closure.
- Prioritized Vercel monorepo reconnect verification for the organization repository.
- Migrated global markdown governance artifacts to `shipglows_data/workflow/**`, updated durable-path pointers, and logged migration inventory/security/closure reports.
- Fixed ShipGlowz frontmatter compliance for active root, app, and site documentation artifacts.
- Consolidated `lab` agent guidance into `AGENT.md` and kept `AGENTS.md` as the compatibility symlink.

### Fixed
- Coalesced concurrent Flutter app access refreshes so Clerk restore sends one backend health/bootstrap pass for the same auth session.
