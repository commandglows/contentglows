---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: site
created: "2026-05-06"
updated: "2026-05-06"
status: draft
source_skill: sf-docs
scope: surface-map
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
content_surfaces:
  - public_site
  - repo_docs
  - runtime_content
claim_register: shipglows_data/editorial/site/claim-register.md
page_intent: shipglows_data/editorial/site/page-intent-map.md
linked_systems:
  - README.md
  - src/pages/
  - src/components/
  - src/content/
depends_on:
  - artifact: "shipglows_data/editorial/site/content-map.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "Astro route files exist under src/pages."
next_review: "2026-06-06"
next_step: "/sf-docs editorial audit site"
---

# Public Surface Map

| Surface | Path | Role | Source of truth | Update trigger |
| --- | --- | --- | --- | --- |
| Marketing home | `src/pages/index.astro` | Public positioning and primary CTA | `shipglows_data/business/business.md`, `shipglows_data/product/site/product.md`, `shipglows_data/branding/branding.md`, `shipglows_data/gtm/site/gtm.md` | Offer, ICP, CTA, claim, or product behavior changes |
| Launch handoff | `src/pages/launch.astro` | App entry handoff | `shipglows_data/product/site/product.md`, app route contracts | Auth/app URL or onboarding changes |
| Sign-in/sign-up handoff | `src/pages/sign-in.astro`, `src/pages/sign-up.astro` | Auth handoff routes | app auth contract and site config | Auth provider, app URL, or CTA changes |
| Privacy | `src/pages/privacy.astro` | Public privacy/security explanation | verified product data handling and legal review | Data, auth, storage, analytics, or compliance changes |
| Runtime content | `src/content/**` | Astro-rendered Markdown content | `src/content.config.ts` and content policy | Content schema or collection changes |
| README | `README.md` | Public repo orientation | actual project setup and deployment model | setup, scripts, deployment, or architecture changes |

## Maintenance Rule

Update this map when a public route, README surface, runtime content collection, CTA, or source-of-truth contract changes.
