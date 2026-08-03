---
artifact: gtm_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: sf-docs
scope: gtm
owner: "Diane"
confidence: "medium"
risk_level: "medium"
docs_impact: "yes"
security_impact: "unknown"
evidence:
  - "README.md"
  - "CLAUDE.md"
  - "shipglows_data/business/business.md"
  - "shipglows_data/branding/branding.md"
  - "lib/router.dart"
  - "lib/presentation/screens/settings/integrations_screen.dart"
  - "web_auth/sign-in.html"
  - "web_auth/sign-up.html"
  - "web_auth/sso-callback.html"
  - "shipglows_data/workflow/specs/app/late-integration-finalization.md"
  - "shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md"
depends_on:
  - "shipglows_data/business/business.md@1.0.0"
  - "shipglows_data/branding/branding.md@1.0.0"
  - "shipglows_data/technical/app/guidelines.md@1.0.0"
supersedes: []
target_segment:
  - creators
  - solopreneurs
  - small marketing teams
offer: operation-focused Flutter workflow shell for planning, review, scheduling, and continuity
channels:
  - web auth onboarding path via web_auth routes (entry, sign-in, sign-up, sso-callback)
  - README and scripts used for install, runbook and validation
  - ecosystem referral through site and internal links
proof_points:
  - Clerk-session gate and routed onboarding with `AppAccessState` checks
  - local cache + queue + replay behavior documented and implemented for supported offline writes
  - multi-project selection and diagnostics surfaces (projects, uptime, performance, activity)
next_review: "2026-07-26"
next_step: "/sf-docs audit shipglows_data/gtm/app/gtm.md"
---

# Go-to-Market Context — app

## Public promise
ContentGlowz App is a practical operator interface for creators and lean teams who want to move from idea to publish-ready content with less tooling friction and stronger continuity. It does **not** claim complete automation; it claims controlled, traceable execution backed by human review and resilient workflows.

## Primary segment
- **Primary:** creators, solopreneurs, founders, and small content teams.
- **Buying pattern:** teams that already use multiple tools and need one authenticated workspace to reduce switching overhead.
- **Behavioral signal:** prefer reliability and continuity over raw feature count, especially during backend instability.

## Offer shape
- A production Flutter shell tied to FastAPI for planning, review, and scheduling operations.
- Human-in-the-loop content control (`editor`, `feed`, `review/status`, `drip`, `calendar`) instead of opaque fully-automatic publishing.
- Resilient operations through local cache and offline queueing for supported mutations.

## Channels currently documented in repo
- **Direct usage / onboarding channel:** web auth handoff paths under `APP_WEB_URL` + `web_auth/*` (`/sign-in`, `/sign-up`, `/sso-callback`).
- **Supportive conversion surface:** in-repo documentation (`README.md`) and setup scripts that are reused for installation + validation.
- **Cross-surface referral channel:** ecosystem references to `site` for acquisition and positioning (external to this repo).

## Proof points (supported in code/docs)
- End-to-end auth path and gated routing are documented and implemented for app entry.
- Multi-project workspace flow exists in app navigation and state providers.
- Offline/ degraded mode is explicitly implemented and documented as a product quality mechanism.
- Feedback admin and admin gate are present (email allowlist path, separate admin screen).

## GTM objections and prepared responses
- **"Can I publish everywhere today?"**
  - Partial answer: publish-related screens and settings exist, but the complete account-mapping and external publish feedback loop is still marked incomplete in current specs.
- **"Is this production-ready?"**
  - The app is operational for authenticated planning/review workflows, with explicit degraded-mode behavior under API failure; this supports continuity claims while reserving full publish parity for later phases.
- **"Is AI fully autonomous?"**
  - No. The documented positioning is explicit: assistant + human review.
- **"Can this break existing channels?"**
  - Route and auth behavior are centralized; integration changes should be validated through specs and docs before changes are promoted.

## Market readiness caveat
Given the current state, messaging should prioritize reliability, workflow continuity, and human review depth first, and avoid hard promises about complete publication automation or billing outcomes.
