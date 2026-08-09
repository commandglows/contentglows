---
artifact: product_context
metadata_schema_version: "1.0"
artifact_version: "1.4.0"
project: "app"
created: "2026-04-26"
updated: "2026-08-09"
status: "reviewed"
source_skill: sf-docs
scope: product
owner: "Diane"
confidence: "medium"
risk_level: "medium"
docs_impact: "yes"
security_impact: "none"
evidence:
  - "README.md"
  - "CLAUDE.md"
  - "shipglows_data/business/business.md"
  - "shipglows_data/branding/branding.md"
  - "shipglows_data/technical/app/guidelines.md"
  - "lib/router.dart"
  - "lib/data/services/"
  - "lib/presentation/screens/"
  - "lib/presentation/screens/branding/brand_profiles_screen.dart"
  - "shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md"
  - "shipglows_data/workflow/specs/app/SPEC-project-flows-selection-onboarding-archive.md"
  - "shipglows_data/workflow/specs/app/late-integration-finalization.md"
  - ".env.example"
depends_on:
  - "shipglows_data/business/business.md@1.0.0"
  - "shipglows_data/branding/branding.md@1.0.0"
  - "shipglows_data/technical/app/guidelines.md@1.0.0"
supersedes: []
target_user: creators and operators who produce recurring content
user_problem: content teams lose continuity when backend services are unstable or workflows are split across disconnected tools
desired_outcomes:
  - Improve throughput from idea or source assets to ready-made publishable outputs.
  - Keep authenticated workflows usable in degraded/partial-offline states.
  - Preserve workspace and queue state continuity across app restarts and reconnection cycles.
non_goals:
  - Native mobile auth stack parity or native-only feature set.
next_review: "2026-08-19"
next_step: "/sf-docs audit shipglows_data/product/app/product.md"
---

# Product Context — app

## Position
`app` is the authenticated Flutter execution layer of the ContentGlows ecosystem. It is the operator-facing app that turns source inputs (ideas, project context, personas, rituals, media assets) into ready-made publishable output with optional edits while tolerating API instability.

## What this product does now
- provides authenticated onboarding and workspace bootstrap via Clerk + FastAPI session flow;
- supports multi-project workspace management with an explicit active-project selection model;
- runs content workflows (feed, ideas, angles, editor, personas, scheduling, drip plans, affiliation/content domains);
- preserves the selected Angle persona as content-scoped metadata, so one brand can serve several audiences without duplicating persona records;
- exposes `Project Intelligence V1` for project-scoped source ingestion, recommendations, and Idea Pool conversion;
- exposes `Video Timeline V1` for backend-orchestrated preview/final render preparation from existing content items;
- exposes a pre-generation source library where creators can add image, video, audio, text and public-link sources, resolve individual failures, and deliberately choose between saving `Sources prêtes` or starting `Générer la vidéo`;
- prepares video-compatible feed items ahead of swipe time through durable branded-video generation runs with feed-facing readiness states (`ready_to_publish`, `preparing`, `needs_review`, `blocked`, `failed`) and compact publish-preflight summaries on the card;
- captures local Android screenshots and screen recordings for creator reference assets;
- supports production-adjacent resilience through degraded mode (cached reads + queued writes + replay + sync state)
- exposes diagnostics and observability (`/uptime`, `/performance`, `/analytics`, `/activity`) so operators understand backend and queue health;
- supports feedback capture (text/audio) and admin review for support triage.

## Core user journey
1. user signs in through Clerk web auth pages and lands on `/entry`;
2. bootstrap checks evaluate auth, API availability, and workspace state;
3. user either completes onboarding, resumes from cached state, or navigates to a project/workflow screen;
4. workflow actions are executed against FastAPI and reflected in the app shell;
5. if API is unavailable, supported actions are queued and replayed when connectivity returns.

## Product boundaries (what is currently documented and delivered)
- **In scope:** AI-first content assembly, optional edit, feed-native publish preflight, truthful publish flows, project configuration, content status, offline continuity, and workflow surfaces.
- **Project Intelligence V1 scope:** active-project intelligence status, source management, evidence ingestion, recommendations, and Idea Pool conversion, with backend constraints on upload types and sizes.
- **Video Timeline V1 scope:** timeline editing plus preview/final render orchestration through backend contracts, without direct Flutter-to-worker calls.
- **Video Source Intake V1 scope:** collecting and validating project-scoped sources, saving an exact ready revision, and optionally handing that revision to generation. Video generation execution, editing, rendering and publication remain separate stages.
- **Ahead-of-time branded video scope:** the feed can request safe refreshes of branded-video candidates, consume compact readiness states, surface preflight blockers directly on the card, and keep the video editor as an explicit optional branch instead of the default path.
- **Brand profile scope:** Settings (`/settings/branding`) owns reusable, project-scoped visual and editorial rules for future branded-video generations. A saved profile can be selected as default; a branding-impact preview first selects completed content, then uses the canonical branded-generation route and opens the resulting video in `/editor/:id/video`. The branding surface never renders locally or mutates an existing timeline draft. A persona remains associated with its content rather than the profile.
- **Branding template scope:** brand profiles resolve into versioned blueprint objects (brand + format + archetype rules) that drive draft assembly. A blueprint defines reusable motion presets, scene grammar, caption style, transitions, CTA behavior, and export constraints; the branding screen now exposes a format-derivation preview (Reels, Shorts, LinkedIn, YouTube) to validate archetype behavior by channel. Changing the template does not rewrite in-flight drafts, it changes the rule input for next generation/regeneration runs.
- **Android-only V1 scope:** local device screenshot and screen-recording capture with Android consent, app-scoped storage, preview, discard, and share/export.
- **Partially in scope / not finished:** end-to-end external publish execution by channel.
  - Route and UX for publish actions exists in some paths, but full channel-account linking and feedback loop are not fully closed yet.
- **Explicitly out of scope in this repo:** marketing site, public SEO/landing content, pricing mechanics, and full AI orchestration decisions (owned by surrounding repos and services).

## Competitors and inspirations

- Filmora and PixVerse are explicit inspiration buckets for editing ergonomics and AI-assisted rough-cut workflows.
- The canonical constraint remains unchanged: no second rendering engine; branding must stay a rule layer and the timeline remains the single editable content object.

## Proven functional domains
- Entry and access control (`/entry`, `/auth`, `/onboarding`, route guards).
- Structured workflows: `Projects`, `Feed`, `Editor`, `Persona`, `Ideas`, `Angles`, `Drip`, `Research`, `Ritual`.
- Operational domains: `Affiliations`, `SEO`, `Runs`, `Newsletter`, `Templates`, `Content Tools`, `Calendar`, `History`, `Activity`.
- Settings and integrations surfaces (`/settings`, `/settings/integrations`).

## Non-goals (explicitly maintained)
- Not positioned as a blind autopilot that publishes opaque outputs without user visibility or control.
- Not responsible for marketing pages or external campaign channel management.
- Not a native-auth-first mobile rewrite yet (web auth path is the active production path in this repo).
- Not a cloud screen-recording asset library yet; capture uploads, retention, and sync need a separate backend spec.

## Business-facing constraints to keep synchronized
- The app depends on consistent workspace/project semantics from backend contracts.
- Any change to onboarding, feed publish semantics, video readiness states, or offline coverage changes this product promise and must trigger docs updates for user-facing claims.
