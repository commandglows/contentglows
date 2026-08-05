## [Unreleased]

### Added
- The Brand Profiles flow now lets creators set up an active video style before requesting a branded preview, so the required video blueprint is visible and recoverable in the app.
- Content generated from an Angle now retains the selected persona identifier as content metadata for downstream context and preview selection.

### Changed
- Brand profile editing uses plain-language CTA and caption-style fields instead of raw JSON input, while retaining any existing advanced values.

## [2026-07-12]

### Added
- Weekly Dependabot monitoring for backend Python dependencies, with a documented review and lockfile validation policy.

## [2026-07-11]

### Added
- Brand profiles can now be managed from Settings with project-scoped state, persistent default selection, protected default-profile deletion, and canonical branded-generation preview handoff.

### Changed
- Project generation context now uses scoped Project Intelligence data with deterministic relational retrieval, bounded context budgets, provenance, and generation signals for newsletter and psychology flows.
- Branded video generation now persists ahead-of-time runs, reuses equivalent active runs idempotently, and exposes scheduler-backed feed readiness states before swipe/publish.

### Removed
- Removed the Mem0 project-memory runtime and its dedicated dependency/setup artifacts. ChromaDB remains only as a CrewAI transitive dependency and is not used by project memory.

### Fixed
- Corrected scheduler video-generation test imports so the test collects and passes with the repository's pytest configuration.

## [2026-07-10]

### Added
- Feed-native video cards in the app feed now surface preview media, readiness state, destination summary, publish preflight blockers, and a direct `/editor/:id/video` edit path for prepared video content.

### Changed
- Feed publish actions now stay truthful for video items: swipe/publish remains disabled until backend readiness is `ready_to_publish`, while rendering and blocked states explain why publish is unavailable.
- Operator and canonical app docs now describe the feed as a publish-ready video decision surface instead of a generic approve-or-publish review queue.
## [2026-07-18]

### Added
- Added an Android-native Clerk authentication bridge for Flutter, including native callback handling, in-memory bearer handoff, and Google sign-in entry flow.

### Changed
- Kept the existing ClerkJS web authentication flow unchanged; Android provider/device validation remains pending.
