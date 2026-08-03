---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: site
created: "2026-05-06"
updated: "2026-06-30"
status: draft
source_skill: sf-docs
scope: claim-register
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
content_surfaces:
  - public_site
  - repo_docs
claim_register: shipglows_data/editorial/site/claim-register.md
page_intent: shipglows_data/editorial/site/page-intent-map.md
linked_systems:
  - shipglows_data/business/business.md
  - shipglows_data/product/site/product.md
  - shipglows_data/branding/branding.md
  - shipglows_data/gtm/site/gtm.md
  - src/pages/
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: reviewed
  - artifact: "shipglows_data/product/site/product.md"
    artifact_version: "1.0.0"
    required_status: reviewed
  - artifact: "shipglows_data/gtm/site/gtm.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "Baseline claim register created for public site governance."
next_review: "2026-06-06"
next_step: "/sf-docs editorial audit site"
---

# Claim Register

| Claim area | Allowed posture | Evidence source | Status | Notes |
| --- | --- | --- | --- | --- |
| AI automation | Describe implemented workflows and reviewed specs only | `shipglows_data/product/site/product.md`, ready specs, verified code | needs proof per claim | Do not promise autonomous publishing without product evidence. |
| Time savings or growth outcomes | Use cautious benefit language | `shipglows_data/gtm/site/gtm.md`, user evidence, analytics when available | needs proof | Avoid quantified gains unless validated. |
| Security and privacy | State only verified handling | `privacy` page source, backend/app contracts, legal review | needs proof | Do not imply certifications or compliance not documented. |
| Availability or reliability | Avoid uptime promises | deployment proof and runtime monitoring | needs proof | Use operational status only when measured. |
| Degraded mode and resilience | Allow bounded recovery messaging only | app + lab canonical docs, verified product behavior | needs proof | Allowed claim: authenticated app access, cached reads where supported, local queue for supported actions, automatic replay. |
| Pricing or offers | Match current GTM/pricing source | `shipglows_data/gtm/site/gtm.md`, pricing spec if present | needs proof | No public pricing claim without a current offer contract. |
| Localized French copy | Preserve claim meaning, not just translated wording | source EN copy + canonical business/product docs | needs proof | No stronger promise in `fr/*` than in default locale. |

## Claim Impact Plan

- Changed source:
- Impacted claim:
- Evidence:
- Required action: `none | review | update | remove | blocked`
- Closure status:

## Maintenance Rule

Update this register before strengthening public claims about AI, automation, security, privacy, availability, pricing, outcomes, or compliance.
