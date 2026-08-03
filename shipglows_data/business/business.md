---
artifact: business_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: contentglowz
created: "2026-04-25"
updated: "2026-06-28"
status: reviewed
source_skill: sf-docs
scope: business
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: none
docs_impact: yes
target_audience: creators, independent operators, founders, and SMB content teams
value_proposition: turn content ideas and source assets into ready-made publishable outputs with predictable, transparent execution
business_model: one ContentGlowz product expressed across multiple surfaces with shared business truth
market: content teams, founders, and solo operators
depends_on: []
supersedes:
  - shipglows_data/business/app/business.md
  - shipglows_data/business/site/business.md
  - shipglows_data/business/lab/business.md
evidence:
  - README.md
  - shipglows_data/branding/branding.md
  - shipglows_data/product/app/product.md
  - shipglows_data/product/site/product.md
  - shipglows_data/product/lab/product.md
next_review: "2026-07-28"
next_step: /sf-docs audit shipglows_data/business/business.md
---
# Business Context

## Purpose

ContentGlowz is one product system with multiple delivery surfaces.
The business truth is shared across the project even when the runtimes differ.

The project exists to help creators and lean teams move from idea or source assets to ready-made publishable content with less tooling friction, more continuity, and clearer operational control.

## Problem

The target users often face:

- fragmented workflows across tools,
- slow turnaround between idea, draft, review, and publish,
- fragile systems when backend services are temporarily unavailable,
- unclear boundaries between marketing promise, operator workflow, and automation layer.

ContentGlowz reduces this friction by keeping the promise explicit:
AI assembles publishable drafts by default, users can approve fast or modify when needed, and the system must remain understandable when dependencies fail.

## Shared Product Positioning

The shared business model is:

- `site`: acquisition, education, trust, and conversion,
- `app`: authenticated execution layer for day-to-day operator workflows,
- `lab`: backend contracts and orchestration authority,
- `worker`: supporting execution service for render workflows.

These are not separate businesses.
They are surfaces of one ContentGlowz offer and must stay aligned on audience, promise, and constraints.

## Core User Value

- Reduce the overhead between idea and execution.
- Deliver ready-made outputs that are publishable immediately in the default path.
- Preserve continuity when services degrade or reconnect.
- Keep workflows explicit, reviewable, and operationally trustworthy.
- Centralize planning, drafting, scheduling, generation, and swipe-to-publish orchestration without forcing manual editing as the normal path.

## Commercial Scope

- Pricing and monetization are not canonically defined in code repositories.
- Repositories should document product truth, user value, and constraints without inventing separate commercial narratives per surface.
- Surface-specific GTM can vary, but the underlying business promise stays shared.

## Governance Notes

- `branding/branding.md` is shared because the brand is shared.
- `business/business.md` is shared because the business truth is shared.
- `product/*` and `gtm/*` may diverge by surface because the user journey and conversion role differ.
- `technical/*` must diverge by surface when runtimes, deployment paths, or implementation contracts differ.
