---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: site
created: "2026-05-06"
updated: "2026-06-30"
status: draft
source_skill: sf-docs
scope: page-intent
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
content_surfaces:
  - public_site
  - runtime_content
claim_register: shipglows_data/editorial/site/claim-register.md
page_intent: shipglows_data/editorial/site/page-intent-map.md
linked_systems:
  - src/pages/
  - src/config/site.ts
depends_on:
  - artifact: "shipglows_data/editorial/site/content-map.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "Baseline page intent map created for current Astro routes."
next_review: "2026-06-06"
next_step: "/sf-docs editorial audit site"
---

# Page Intent Map

| Route or file | Intent | Primary CTA | Source contracts | Shared-file risk |
| --- | --- | --- | --- | --- |
| `/` via `src/pages/index.astro` | Explain ContentGlowz and move qualified visitors toward the app | Open app or start/sign in | `shipglows_data/business/business.md`, `shipglows_data/product/site/product.md`, `shipglows_data/gtm/site/gtm.md` | High: homepage copy affects positioning and claims |
| `/fr` via `src/pages/fr/index.astro` | French localized entry surface with the same product promise and CTA structure | Open app or start/sign in | same as `/` + French copy rules | High: localized promise drift |
| `/launch` | Route users into the app experience | Continue to app | `shipglows_data/product/site/product.md`, app handoff config | Medium: app URL and auth state must stay current |
| `/fr/launch` | French localized launch handoff | Continue to app | same as `/launch` | Medium: localized handoff drift |
| `/sign-in` | Redirect or hand off existing users to app sign-in | Sign in | app auth contract | High: auth claims and route correctness |
| `/fr/sign-in` | French localized sign-in handoff | Sign in | app auth contract + language rules | High: auth correctness and copy trust |
| `/sign-up` | Redirect or hand off new users to app sign-up | Sign up | app auth contract, GTM offer | High: conversion and auth correctness |
| `/fr/sign-up` | French localized sign-up handoff | Sign up | app auth contract, GTM offer, language rules | High: conversion and auth correctness |
| `/privacy` | State privacy and data-handling posture | None or contextual app link | legal/product evidence | High: security and privacy claims need proof |
| `/fr/privacy` | French localized privacy and data-handling posture | None or contextual app link | legal/product evidence + translation fidelity | High: privacy claim drift |
| `/blog`, `/fr/blog`, article and tag routes | Publish discoverable editorial proof without breaking locale-aware metadata | Read article / continue exploring | content strategy, `src/content.config.ts`, localized metadata contract | High: SEO and locale parity |
| `src/content/**` | Render structured content through Astro collections | Surface-specific | `src/content.config.ts` | High: schema drift can break build |

## Maintenance Rule

Update this map when route intent, CTA, source contracts, auth/app handoff, or shared layout behavior changes.
