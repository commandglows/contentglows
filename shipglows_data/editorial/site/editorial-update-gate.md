---
artifact: editorial_content_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: site
created: "2026-05-06"
updated: "2026-05-06"
status: draft
source_skill: sf-docs
scope: content-gate
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
  - shipglows_data/editorial/site/public-surface-map.md
  - shipglows_data/editorial/site/page-intent-map.md
  - shipglows_data/editorial/site/claim-register.md
depends_on: []
supersedes: []
evidence:
  - "Baseline editorial update gate created for public site governance."
next_review: "2026-06-06"
next_step: "/sf-docs editorial audit site"
---

# Editorial Update Gate

Use this gate after changes to public copy, routes, README promises, FAQ/support content, pricing, privacy, claims, or runtime content.

## Editorial Update Plan

```markdown
## Editorial Update Plan

- Changed behavior or source: `[source]`
- Impacted surface: `[route/file/surface]`
- Source of truth: `[contract/spec/evidence]`
- Required action: `[none|review|update|create|remove|surface missing|pending final copy]`
- Reason: `[why]`
- Owner role: `[Editorial Reader|executor|integrator|human decision]`
- Parallel-safe: `[yes|no]`
- Validation: `[check]`
- Closure status: `[complete|no editorial impact|pending final copy|blocked]`
```

## Claim Impact Plan

Use `claim-register.md` when the change touches security, privacy, compliance, AI automation, speed, savings, availability, pricing, or business outcomes.

## Pending Final Copy

Use `pending final copy` when product behavior is known but public wording needs human approval.

## Surface Missing

Use `surface missing: blog` or another explicit surface when requested content has no declared route or owner.

## Maintenance Rule

Update this gate when editorial plan fields, claim impact rules, public surface ownership, or closure labels change.
