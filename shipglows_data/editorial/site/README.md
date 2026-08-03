---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: site
created: "2026-05-06"
updated: "2026-05-06"
status: draft
source_skill: sf-docs
scope: editorial-governance
owner: Diane
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
content_surfaces:
  - public_site
  - repo_docs
  - runtime_content
  - future_blog
claim_register: shipglows_data/editorial/site/claim-register.md
page_intent: shipglows_data/editorial/site/page-intent-map.md
linked_systems:
  - shipglows_data/editorial/site/content-map.md
  - shipglows_data/business/business.md
  - shipglows_data/product/site/product.md
  - shipglows_data/branding/branding.md
  - shipglows_data/gtm/site/gtm.md
  - src/pages/
  - src/content.config.ts
  - src/content/
depends_on:
  - artifact: "shipglows_data/editorial/site/content-map.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "site has public Astro routes and runtime content."
next_review: "2026-06-06"
next_step: "/sf-docs editorial audit site"
---

# Editorial Governance

This directory governs public ContentGlowz site surfaces, claims, page intent, runtime content schema boundaries, and editorial update gates.

Load order:

1. `public-surface-map.md`
2. `page-intent-map.md`
3. `claim-register.md`
4. `editorial-update-gate.md`
5. `astro-content-schema-policy.md`
6. `blog-and-article-surface-policy.md`

## Maintenance Rule

Update this index when public surfaces, claim evidence, page intent, runtime content schema, or editorial gates change.
