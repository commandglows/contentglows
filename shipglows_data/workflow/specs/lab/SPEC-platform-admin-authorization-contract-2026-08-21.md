---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-08-21"
created_at: "2026-08-21 16:40:01 UTC"
updated: "2026-08-21"
updated_at: "2026-08-21 16:40:01 UTC"
status: ready
source_skill: sg-docs
source_model: "GPT-5 Codex"
scope: "security"
owner: "Diane"
confidence: "high"
risk_level: "critical"
security_impact: "yes"
docs_impact: "yes"
user_story: "En tant qu'opératrice ContentGlows, je veux que chaque action globale ou financière soit autorisée par une capacité serveur explicite et auditée, afin qu'un compte authentifié, une adresse e-mail ou un rôle local à une fonctionnalité ne puisse jamais obtenir des privilèges plateforme."
linked_systems:
  - "lab"
  - "Clerk"
  - "Turso/libSQL"
  - "AI usage and quota ledger"
depends_on:
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Repository audit on 2026-08-21 found authenticated user identity and a feedback-only email allowlist, but no platform-wide admin authorization contract."
  - "Clerk official session-token documentation checked on 2026-08-21 documents signed custom claims but also documents refresh lag; token metadata is therefore not selected as the mutation authority."
  - "The AI quota spec requires a dedicated admin-auth contract before Task 10 when no reliable admin role system exists."
next_review: "2026-09-21"
next_step: "Implement Tasks 1-4 before resuming Task 10 of the AI quota chantier."
---

# Platform Admin Authorization Contract

## Status

Ready. This security prerequisite owns platform-level authorization. It does not itself grant any user a permission and does not authorize AI quota administration until its implementation and focused proof exist.

## Outcome

ContentGlows has one server-authoritative, capability-based admin boundary for global, financial, security-sensitive, and cross-tenant operations. Authentication establishes identity; a separate durable grant establishes authority. Every protected mutation fails closed and emits an immutable audit record.

## Existing-State Finding

- Clerk JWT validation establishes a signed user identity through the `sub` claim.
- `CurrentUser` currently carries user id, optional email, and bearer token, but no platform permissions.
- Feedback administration uses `FEEDBACK_ADMIN_EMAILS`; this is feature-local compatibility behavior, not a platform role.
- No reusable server-side platform-admin dependency or durable grant registry exists.

The feedback allowlist must not be reused, renamed, or widened for quota, billing, entitlement, user, security, or cross-project administration.

## Authority Model

### Identity

- A valid Clerk session token supplies the immutable actor `user_id` from its signed `sub` claim.
- Email is display/audit context only. Email, domain, client state, request body, query parameters, headers other than the validated bearer token, and Flutter visibility never grant authority.
- Organization membership or `org_role` does not imply platform authority.

### Durable platform grants

The backend owns a durable `platform_admin_grants` record keyed by grant id and actor user id. Each record contains:

- `grant_id`
- `user_id`
- `capabilities`
- `status` (`active` or `revoked`)
- `reason`
- `granted_by`
- `granted_at`
- `revoked_by` nullable
- `revoked_at` nullable
- `version`

The initial capability vocabulary is intentionally narrow:

- `ai_usage:read_all`
- `ai_usage:adjust`
- `ai_usage:refund`
- `ai_usage:override`

Capabilities are explicit; there is no wildcard, implicit super-admin, email-domain shortcut, or fallback allowlist.

### Clerk claims

A small signed custom claim may later be used as a non-authoritative UI capability hint. It must never authorize a platform mutation. The backend must read the current durable grant for every privileged request because Clerk documents that custom session claims can lag underlying metadata changes until token refresh.

## Enforcement Contract

- A reusable dependency resolves the authenticated `user_id`, loads the current durable grant, and checks one exact required capability.
- Missing database configuration, missing grant, revoked grant, unknown capability, malformed record, or lookup failure denies access.
- Authentication failure returns `401`; authenticated but unauthorized access returns a generic `403`; authorization infrastructure failure returns a redacted `503` and never falls back to permissive behavior.
- The target user/project scope is resolved independently of actor authority. Possessing a capability never bypasses record validation or tenant identifiers.
- List/read-all and mutation capabilities remain separate.
- Self-adjustment and self-refund are denied by default. Any future break-glass exception requires a separate product/security decision and a distinct audited capability.
- Admin authorization is evaluated at request time, not cached across requests.

## Audit Contract

Every attempted privileged mutation records or safely stages an audit event containing:

- actor user id and grant id/version;
- exact capability checked;
- action and target identifiers;
- idempotency key;
- bounded reason supplied by the operator;
- before/after domain references or hashes where sensitive payload retention is inappropriate;
- UTC timestamp;
- outcome (`allowed`, `denied`, `conflict`, or `failed`).

Audit records never store bearer tokens, raw authorization headers, secrets, or unrestricted user payloads. A successful domain mutation and its success audit must share an atomic contract; an audit failure must not silently permit the mutation.

## Provisioning And Revocation

- Platform grants are provisioned only through an authenticated, audited server/operations path defined after the first authority implementation exists.
- There is no public self-service grant endpoint and no client-writable metadata path.
- Initial bootstrap is an explicit deployment operation scoped to exact Clerk user ids, with a recorded actor/reason and a post-bootstrap removal or disablement step.
- Revocation takes effect on the next privileged request because the durable registry, not the session claim, is authoritative.

## Scope In

- Durable capability grants and revocation.
- Reusable fail-closed FastAPI authorization dependency.
- Atomic audit contract for privileged mutations.
- Exact integration boundary for AI usage administration.
- Focused adversarial authorization tests.

## Scope Out

- Admin UI.
- Customer organization roles.
- General project collaboration roles.
- Checkout, invoices, taxes, public prices, or payment-provider permissions.
- Migrating feedback administration; it remains feature-local until a separate compatibility task is approved.
- Implementing AI usage adjustments, refunds, or overrides; those remain Task 10 of the quota chantier after this contract is implemented.

## Acceptance Criteria

- [ ] AC1: A signed Clerk identity without a durable active grant cannot access any platform-admin endpoint.
- [ ] AC2: Email, email domain, feedback allowlist membership, organization role, and client-sent claims cannot grant platform capabilities.
- [ ] AC3: Each route declares one or more exact capabilities and rejects missing/revoked/unknown grants fail-closed.
- [ ] AC4: Cross-user and cross-project target scope is validated independently from the admin capability.
- [ ] AC5: Self-adjustment and self-refund are rejected.
- [ ] AC6: Every privileged mutation has an idempotent, redacted, actor-attributed audit event coupled to its outcome.
- [ ] AC7: Revocation is observed on the next privileged request without relying on token refresh.
- [ ] AC8: Configuration/store failures never fall back to an email allowlist or client-visible claim.

## Execution Plan

- [ ] Task 1: Add storage-agnostic grant, capability, and audit contracts.
- [ ] Task 2: Add an injected-client durable adapter with additive schema and compare-and-set grant versioning.
- [ ] Task 3: Add the reusable FastAPI permission dependency and redacted error mapping.
- [ ] Task 4: Author focused tests for unauthenticated, ungranted, wrong-capability, revoked, stale-claim, feedback-allowlisted, self-targeting, cross-tenant, store-failure, idempotency, and audit-atomicity cases.
- [ ] Task 5: Define and document the bounded bootstrap/revocation operations before any production grant is created.
- [ ] Task 6: Resume AI quota Task 10 using only the proven dependency and exact AI usage capabilities.

## Security Stops

- Stop if implementation requires trusting email or any client-writable field.
- Stop if the backing store cannot couple privileged domain mutations and success audit evidence atomically.
- Stop before provisioning a real grant without an explicit deployment operation and named operator authority.
- Stop if a route requires an undefined capability; add it to this contract before implementation.

## Verification Plan

- Contract tests for any grant-store adapter.
- Dependency tests covering each deny path and redacted response.
- Route tests proving authentication and capability checks precede target data access.
- Concurrency/idempotency tests for duplicate privileged mutations.
- Audit reconciliation tests proving no successful mutation lacks success evidence.
- Authorized hosted smoke with a granted account, a normal account, a revoked account, and a foreign target.

## Freshness Evidence

Clerk's official documentation checked on 2026-08-21 states that custom session claims are signed into session tokens but may remain stale until token refresh. This contract therefore uses Clerk for authenticated identity and a durable ContentGlows registry for current platform authority. Recheck the official session-token and authorization documentation before implementing a different claim or organization-role strategy.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-08-21 16:40:01 UTC | sg-docs | GPT-5 Codex | Audited the existing authorization boundary and formalized a fail-closed platform capability contract after no reusable global admin authority was found. | Ready contract created; no permissions, grants, endpoints, or production state changed. | Implement Tasks 1-4 before resuming AI quota Task 10. |

## Current Chantier Flow

spec ready ✅ -> authorization implementation ⏳ -> focused security verification ⏳ -> AI quota Task 10 blocked pending proof
