---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "ShipGlowz"
created: "2026-07-18"
created_at: "2026-07-18 00:00:00 UTC"
updated: "2026-07-18"
updated_at: "2026-07-18 00:00:00 UTC"
status: ready
source_skill: 900-shipglowz-core
source_model: "GPT-5 Codex"
scope: "cross-project-governance"
owner: "Diane"
confidence: "high"
user_story: "En tant qu'utilisateur d'un projet ShipGlowz, je veux comprendre immédiatement qu'une action asynchrone est en cours, connaître son étape et savoir quoi faire en cas d'attente ou d'échec, afin de ne jamais confondre un délai avec un bug."
risk_level: "medium"
security_impact: "no"
docs_impact: "yes"
linked_systems:
  - "skills/*"
  - "skills/references/"
  - "design workflows"
  - "customer workflows"
  - "auth/OAuth workflows"
  - "build and verification workflows"
depends_on:
  - artifact: "skills/references/skill-instruction-layering.md"
    artifact_version: "1.1.0"
    required_status: "active"
  - artifact: "skills/references/spec-driven-development-discipline.md"
    artifact_version: "1.5.1"
    required_status: "active"
supersedes: []
evidence:
  - "Operator feedback 2026-07-18: a Clerk session check and Google sign-in left the user unsure whether the app was working or frozen because no visible animation/state explained the delay."
  - "Operator direction 2026-07-18: every behavior that takes time must provide visible feedback, not only auth."
  - "Existing shared doctrine has no single reusable async-feedback contract covering immediate acknowledgement, step labels, timeout, retry, and diagnostics across design/customer/build skills."
next_step: "/101-sg-ready cross-project async feedback visibility"
---

# Cross-project async feedback visibility

## Status

Ready as a mini-spec. This work defines a reusable doctrine and proof contract; it does not itself edit any `SKILL.md`, application code, or the final shared reference. The recommended implementation placement is a new shared reference at `skills/references/async-feedback-visibility.md`, with compact links from affected skills only where activation requires them.

## User Story

En tant qu'utilisateur d'un projet ShipGlowz, je veux comprendre immédiatement qu'une action asynchrone est en cours, connaître son étape et savoir quoi faire en cas d'attente ou d'échec, afin de ne jamais confondre un délai avec un bug.

## Minimal Behavior Contract

Toute action susceptible de durer plus qu'un tour d'interface doit accuser réception immédiatement, exposer un état visible et animé, indiquer l'étape en langage utilisateur, puis terminer par un succès, une erreur récupérable ou un état bloqué diagnostiquable. Aucun écran, bouton ou rapport ne doit rester visuellement statique pendant une attente connue. La visibilité doit être adaptée à la surface (loader/bouton verrouillé dans une UI, étape et preuve dans une skill, progression/heartbeat dans un job) sans divulguer secrets, tokens, cookies ou payloads privés.

## Success Behavior

- Given a user starts OAuth, API, import, generation, upload, render, or workspace/session checking, when the operation begins, then the UI or workflow acknowledges it immediately with an animation/heartbeat and a human-readable step label.
- Given an operation has multiple known phases, when the active phase changes, then the current phase and next expected transition are exposed without claiming completion early.
- Given an operation exceeds its declared timeout or heartbeat window, when no terminal result exists, then the surface changes to a timed-out/retryable or blocked state with a sanitized diagnostic and an owner route.
- Given a retry is safe, when the user or agent retries, then the retry is explicit, idempotent where required, and visibly returns to an active state; duplicate submissions are prevented while in flight.
- Given a successful terminal result arrives, when the surface renders completion, then the animation stops, controls re-enable, and the result/proof is stated clearly.
- Given a skill reports an unfinished external proof, when it hands off, then it names `proof_type`, `owner_skill`, `scenario`, and `target_or_environment` rather than leaving a generic “waiting” note.

## Error Behavior

- No silent async wait, disabled control without explanation, indefinite spinner, or success message before the terminal result.
- If the operation cannot expose percentage progress, use phase progress or a heartbeat; never fabricate numeric progress.
- If the provider/browser/device callback is unavailable, preserve the current state, show a recoverable explanation, and route to the concrete diagnostic owner.
- If an operation is cancelled or the route is disposed, stop polling/animation and ignore stale responses.
- Feedback must remain sanitized: never show auth codes, access/refresh tokens, cookies, provider secrets, private payloads, or raw exception dumps.

## Pressure Scenarios (scenario-first proof)

1. `ASYNC-OAUTH-RETURN`: browser opens for Google/Clerk, callback is delayed or lost; the APK shows an active state, then timeout plus retry/diagnostic instead of appearing frozen.
2. `ASYNC-API-SLOW`: a backend request takes several seconds; the UI acknowledges immediately, labels the current step, prevents duplicate taps, and recovers on success/error.
3. `ASYNC-GENERATION-QUEUED`: image/video generation remains queued; the user sees queued/in-progress phases and bounded polling, not a false completion.
4. `ASYNC-IMPORT-UPLOAD`: upload/import has no percentage; the surface shows phase heartbeat and a safe retry after timeout.
5. `ASYNC-SKILL-HANDOFF`: a build/design/customer/auth skill cannot finish provider or device proof; the report contains the concrete owner route and target fields.
6. `ASYNC-STALE-RESPONSE`: the user navigates away or changes project while work is in flight; stale responses do not overwrite the new state and active feedback stops.

## Implementation Contract

1. Add `skills/references/async-feedback-visibility.md` as the canonical cross-skill doctrine, including state vocabulary (`idle`, `starting`, `in_progress`, `queued`, `success`, `error`, `timed_out`, `blocked`, `cancelled`), animation/heartbeat rules, timeout/retry rules, sanitization, and handoff fields.
2. Update only the narrowest affected skill contracts to load or point to that reference; prioritize `001-sg-build`, `003-sg-bug`, `006-sg-design`, `008-sg-customer`, `102-sg-start`, `103-sg-verify`, `107-sg-test`, `109-sg-auth-debug`, and `900-sg-core` where their activation paths need the doctrine.
3. Add a reusable checklist or test matrix under `shipglows_data/workflow/checklists/` only if the reference cannot remain followable without it; avoid duplicating the doctrine in every skill.
4. For app projects, map the doctrine to existing design-system loading indicators and state components; do not invent one-off visual tokens or disclose sensitive diagnostics.

## Proof Contract

- `scenario-first`: pressure scenarios above must be represented by focused mechanical checks or contract scans before claiming the doctrine is hardened.
- `evidence-first`: for one representative Flutter/auth surface, verify immediate animation, step label, timeout/retry, stale-response handling, and sanitized error behavior with widget/unit tests or an agent-run browser/device proof as appropriate.
- Run metadata lint, skill budget audit, runtime sync check, and focused `rg` checks proving the shared reference is linked without duplicated doctrine.
- Remaining native/provider/device proof is owned by `109-sg-auth-debug` or `107-sg-test` with explicit target/environment fields; do not fabricate it from static checks.

## Scope Out

- No implementation of Clerk, OAuth, API, generation, import, or upload behavior in this mini-spec.
- No mandatory animation library or design-system token change.
- No replacement of existing product-specific progress models where they already satisfy this contract.
- No public plugin packaging of `900-sg-core`.

## Readiness Decision

Ready: the failure scenario, reusable placement, scope boundary, state/error contract, and proof path are explicit. No unresolved operator decision blocks creation of the shared reference; implementation must still pass the normal `100 → 101 → 102 → 103 → 104 → 005` lifecycle.

## Current Chantier Flow

- `900-sg-core build`: mini-spec drafted from operator feedback.
- `101-sg-ready`: pending delegated readiness validation.
- `102-sg-start`: pending shared-reference implementation.
