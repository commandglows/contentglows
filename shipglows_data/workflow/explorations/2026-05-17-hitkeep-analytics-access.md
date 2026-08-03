---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-17"
updated: "2026-05-17"
status: draft
source_skill: sf-explore
scope: "HitKeep and Clamp inspiration for Analytics access model"
owner: "unknown"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - app/lib/presentation/screens/analytics/
  - app/lib/data/models/app_access_state.dart
  - lab/api/routers/analytics.py
  - lab/api/routers/search_console.py
  - lab/api/dependencies/ownership.py
evidence:
  - "HitKeep public pages describe RBAC, per-site permissions, API clients, read-only MCP access, shareable dashboards, email reports, cookie-free tracking, and open exports."
  - "Clamp public pages describe agent-native analytics via MCP, analyst-grade prompt workflows, funnels, cohorts, alerts, revenue, custom events, and project-scoped API keys."
  - "ContentGlowz analytics router currently protects reads with Clerk JWT and user/project domain resolution."
  - "Search Console summary already combines Google Search snapshots and private tracker traffic under owned project checks."
  - "App access state is workspace/bootstrap-oriented rather than analytics-capability-oriented."
depends_on: []
supersedes: []
next_step: "/sf-spec Analytics access governance"
---

# Exploration Report: HitKeep And Clamp Analytics Access

## Starting Question

Est-ce que HitKeep peut nous aider a ameliorer notre systeme d'acces a l'Analytics ?

## Context Read

- `lab/api/routers/analytics.py` - public collect endpoint and authenticated analytics query endpoints.
- `lab/api/routers/search_console.py` - current combined Search Console/private tracker summary.
- `lab/api/dependencies/ownership.py` - project ownership gate.
- `app/lib/data/models/app_access_state.dart` - app-level access states and workspace-data readiness.
- `app/lib/presentation/screens/analytics/analytics_screen.dart` - current Analytics screen composition.

## Internet Research

- [HitKeep on BetaList](https://betalist.com/startups/hitkeep) - Accessed 2026-05-17 - Product summary and launch positioning.
- [HitKeep homepage](https://hitkeep.com/) - Accessed 2026-05-17 - Feature set: governed access, API clients, read-only MCP, exports, privacy and deployment model.
- [HitKeep introduction](https://hitkeep.com/guides/introduction/) - Accessed 2026-05-17 - Access-control details: instance roles, per-site roles, bearer-token API clients, shareable dashboards.
- [HitKeep vs GoatCounter](https://hitkeep.com/vs/goatcounter/) - Accessed 2026-05-17 - Current feature comparison and shipped access/reporting surfaces.
- [Clamp on BetaList](https://betalist.com/startups/clamp) - Accessed 2026-05-17 - Launch positioning: privacy-first analytics for agents and small teams.
- [Clamp homepage](https://clamp.sh/) - Accessed 2026-05-17 - Product surface: MCP-first analytics, funnels, cohorts, alerts, revenue, errors, journey/path analysis.
- [Clamp Analytics MCP Server on Glama](https://glama.ai/mcp/servers/clamp-sh/mcp) - Accessed 2026-05-17 - MCP tool model, project-scoped API keys, analytics prompts, read/diagnostic tool list.

## Problem Framing

ContentGlowz already has basic analytics access: authenticated users query analytics for their project domains, and Search Console data is scoped by project ownership. The gap is not "can we read analytics"; the gap is governed, shareable, programmatic access for humans, reports, and assistants without giving everyone full app/session access.

## Option Space

### Option A: Adopt HitKeep as analytics backend

- Summary: Use HitKeep for web analytics storage, dashboards, reports, roles, exports, and optional assistant access.
- Pros: Faster route to mature dashboard/reporting/RBAC features; self-host or managed; open exports; cookie-free orientation.
- Cons: Migration and product fit risk; duplicate data model with ContentGlowz projects/domains; integration work for app identity, project ownership, and Search Console semantics.

### Option B: Copy the access model, keep our tracker

- Summary: Keep current private tracker and Search Console store, but add HitKeep-inspired access primitives.
- Pros: Fits existing ContentGlowz data model; lower migration risk; preserves current Search Console/editorial opportunity integration.
- Cons: We must build RBAC/API-client/share/report features ourselves; needs careful security design and audit logging.

### Option C: Do nothing beyond current owner-only access

- Summary: Keep analytics visible only through authenticated app/project ownership.
- Pros: Lowest implementation cost and simplest security posture.
- Cons: No read-only stakeholder access, no scoped assistant/reporting tokens, no shareable dashboards, no real analytics permission model.

### Option D: Copy Clamp's agent-native analytics loop

- Summary: Keep our own tracker, but expose a read-only analytics tool surface for agents with predefined analysis workflows.
- Pros: Strong fit for ContentGlowz because agents already create content, landing pages, reels, newsletters, and project intelligence; closes the loop from shipped content to measured outcome.
- Cons: Higher prompt/tool safety burden; requires strict scoped credentials, query limits, and careful separation between read-only diagnosis and write actions.

## Comparison

HitKeep is most useful as a reference architecture for access governance:

- Roles: instance/team and per-site roles map to workspace/project/domain roles.
- API clients: scoped bearer tokens map to reporting jobs, internal tools, and agents.
- Read-only assistant/MCP access: aggregate analytics can be exposed without dashboard cookies or write access.
- Share links and scheduled reports: stakeholders can consume analytics without becoming full app users.
- Exports: open data takeout improves trust and reduces lock-in.

Clamp is more useful as a reference architecture for agent workflows:

- MCP-first query model: analytics is available where the agent works, not only in dashboards.
- Prompt workflows: weekly report, traffic diagnosis, conversion audit, channel breakdown, and page performance can become first-class ContentGlowz analysis actions.
- Event schema: product/content events need typed names and properties so agents can ask reliable questions.
- Alerts: analytics should trigger follow-up work when traffic, conversion, or publishing outcomes move.

## Emerging Recommendation

Do not replace the current system immediately. Use HitKeep as the design benchmark for a ContentGlowz-native analytics access layer, and Clamp as the benchmark for agent-native analysis workflows:

1. Add an explicit analytics capability model: `analytics:view`, `analytics:export`, `analytics:share`, `analytics:connect`, `analytics:sync`, `analytics:admin`.
2. Introduce project/domain-scoped read-only API clients for reports and agents.
3. Add shareable read-only dashboard/report links with expiration, revocation, and audit logs.
4. Keep Search Console OAuth ownership stricter than private traffic viewing.
5. Add Clamp-style predefined analysis tools: weekly report, traffic diagnosis, page/content performance, channel quality, and conversion audit.
6. Consider HitKeep or Clamp as a parallel pilot for one site only if we need richer event/funnel reporting quickly.

Confidence: medium. HitKeep and Clamp's public claims are clear, but a production decision would require testing the live products/APIs and reviewing their security model.

## Non-Decisions

- No decision to migrate analytics storage to HitKeep.
- No decision to expose MCP in ContentGlowz yet.
- No decision on paid/managed HitKeep Cloud.
- No decision on paid/managed Clamp.

## Rejected Paths

- Immediate replacement of ContentGlowz analytics - rejected because our Search Console/editorial intelligence integration is already app-specific.
- Giving assistants normal user sessions - rejected because HitKeep's pattern points to scoped read-only API clients instead.
- Letting agents create alerts/funnels or open PRs without human review - rejected for V1 because analytics tooling should start read-only and diagnostic.

## Risks And Unknowns

- HitKeep maturity: product was featured recently, so reliability and long-term maintenance need validation.
- Clamp maturity: product was featured recently, so reliability, auth design, MCP safety, and retention/export posture need validation.
- Compliance: cookie-free does not automatically settle ePrivacy/PECR/GDPR questions, especially where sessionStorage or similar client storage is used.
- Data model mismatch: ContentGlowz project/domain/user ownership may not map cleanly to HitKeep site/team permissions.
- Security: scoped tokens and share links need revocation, expiry, audit logs, and rate limits from day one.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: Report summarizes code and public web sources only.

## Decision Inputs For Spec

- User story seed: As a project owner, I can grant read-only analytics access to stakeholders, jobs, and approved assistants without granting full workspace access, and I can ask an approved assistant to diagnose content performance from scoped aggregate data.
- Scope in seed: analytics permissions, API clients, read-only shares, audit logs, UI states, backend enforcement, predefined agent analysis workflows.
- Scope out seed: full migration to HitKeep; public write APIs beyond existing collect; session replay.
- Invariants/constraints seed: backend-enforced project ownership; Search Console OAuth remains owner/admin-only; tokens are scoped, revocable, expiring, and read-only by default.
- Validation seed: authorization tests across owner/viewer/token/share states; expired/revoked token tests; UI checks for degraded access states.

## Handoff

- Recommended next command: `/sf-spec Analytics access governance`
- Why this next step: The access model affects security and product behavior, so it should be specified before implementation.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-05-17 15:28:55 UTC | Evaluate HitKeep for Analytics access | Read HitKeep sources and ContentGlowz analytics/access code | Recommend native access-governance layer inspired by HitKeep, not immediate migration | `/sf-spec Analytics access governance` |
| 2026-05-17 15:28:55 UTC | Evaluate Clamp for Analytics access | Read Clamp public pages and MCP server reference | Add Clamp as inspiration for agent-native analytics workflows on top of governed read-only access | `/sf-spec Analytics access governance` |
