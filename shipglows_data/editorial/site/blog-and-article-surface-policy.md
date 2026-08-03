---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: site
created: "2026-05-06"
updated: "2026-05-06"
status: draft
source_skill: sf-docs
scope: blog-article-policy
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
content_surfaces:
  - future_blog
  - runtime_content
claim_register: shipglows_data/editorial/site/claim-register.md
page_intent: shipglows_data/editorial/site/page-intent-map.md
linked_systems:
  - src/pages/
  - src/content/
  - src/content.config.ts
depends_on:
  - artifact: "shipglows_data/editorial/site/content-map.md"
    artifact_version: "1.0.0"
    required_status: reviewed
supersedes: []
evidence:
  - "Baseline policy created because article/blog work needs an explicit route before publication."
next_review: "2026-06-06"
next_step: "/sf-docs editorial audit site"
---

# Blog And Article Surface Policy

Blog or article requests must resolve to a declared route and content collection before publication.

## Policy

- If no blog/article route exists, report `surface missing: blog`.
- Do not publish article claims that exceed `claim-register.md`.
- Preserve `src/content.config.ts` when adding or editing runtime Markdown content.
- Draft strategy and governance can live in `shipglows_data/editorial/`; app-rendered content belongs only in runtime paths accepted by Astro.

## Maintenance Rule

Update this policy when the site adds blog routes, article collections, newsletter archives, or other long-form public content surfaces.
