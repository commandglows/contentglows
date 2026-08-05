---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "contentglows"
created: "2026-07-08"
created_at: "2026-07-08 00:00:00 UTC"
updated: "2026-07-08"
updated_at: "2026-07-08 00:00:00 UTC"
status: draft
source_skill: 100-sg-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlows authentifiee, je veux regenerer une video branded tout en preservant certains choix comme des assets, scenes ou copies, afin d'obtenir une nouvelle proposition sans perdre mes decisions importantes."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "app"
  - "Unified ContentGlows Video Timeline"
  - "Brand Video Blueprints"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-branding-editor-as-rule-editor-for-canonical-video-generation-2026-07-08.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Repo evidence: blueprint model already has allowed_regeneration_locks_json."
  - "Repo evidence: branded assembly is currently stateless and reconstructs drafts from scratch."
  - "User direction 2026-07-04: regeneration should preserve explicit locks and constraints."
next_step: "/101-sg-ready branded video regeneration with locks and preserved selections"
---

## Title

Branded video regeneration with locks and preserved selections

## Status

Draft. This spec defines regeneration of branded videos from a previous canonical version while preserving selected user choices through explicit lock rules. It adds the missing contract between blueprint-level lock policy, request-level lock instances and merge behavior into a newly generated timeline version.

## User Story

En tant que creatrice ContentGlows authentifiee, je veux regenerer une video branded tout en preservant certains choix comme des assets, scenes ou copies, afin d'obtenir une nouvelle proposition sans perdre mes decisions importantes.

## Minimal Behavior Contract

L'utilisateur peut demander une regeneration a partir d'une version canonique existante en envoyant des locks explicites et des changements demandes. Le backend valide ces locks contre la politique autorisee du blueprint, genere une nouvelle proposition branded, puis merge ou preserve les parties verrouillees dans une nouvelle version canonique. Si un lock est invalide, incompatible ou non satisfaisable, le systeme retourne un conflit typé plutot que d'ignorer silencieusement la demande.

## Success Behavior

- Given a current canonical timeline version exists, when the user requests regeneration with allowed locks, then the backend creates a new regenerated canonical version rather than mutating the previous one.
- Given clip-level or asset-level locks are requested, when regeneration runs, then preserved selections survive the new assembly where the policy allows them.
- Given the blueprint disallows some lock types, when the request includes them, then the backend rejects those locks explicitly.
- Given regeneration succeeds, when the new version is created, then previous preview/final states are treated as stale until fresh preview/final work completes for the regenerated version.

## Error Behavior

- Missing or foreign timeline/version/blueprint context returns ownership-safe errors.
- Unsupported or disallowed lock types return `409` or validation errors with specific conflict codes.
- If preserved selections cannot fit the regenerated structure, the backend returns a partial-constraint conflict rather than silently discarding the preserved choice.
- Regeneration never auto-publishes and never overwrites a published version in place.

## Problem

The repo can generate branded drafts, but only from scratch. There is no durable way to say “regenerate this while keeping my chosen asset, scene or copy.” Without this, users must choose between full regeneration and manual editing, which breaks the intended AI-first but user-steerable workflow.

## Solution

Add a regeneration contract built on three layers: blueprint-level allowed lock policy, request-level lock instances, and merge rules from prior version to regenerated version. Persist the result as a new canonical version and invalidate previous preview/final approval as needed.

## Scope In

- Regeneration request and response models.
- Backend validation of requested locks against blueprint policy.
- Persistence of lock metadata where needed.
- Merge logic between prior version and regenerated proposal.
- App wiring to request regeneration with preserved selections.

## Scope Out

- Full branding editor UI.
- Background ahead-of-time orchestration.
- Generic content regeneration outside the video-timeline domain.

## Constraints

- Regeneration always creates a new canonical version; it never mutates old immutable versions.
- Blueprint policy defines which lock types are allowed.
- Clip-level metadata may carry lock instance data, but it must remain canonical timeline data, not a second hidden sidecar document.
- Regeneration never bypasses preview/final freshness rules.

## Test Contract

- Surface: backend service/router tests plus targeted app request-model tests.
- Proof profile: scenario-first.
- Required scenario ids:
  - `REGEN-LOCK-001` preserve allowed asset or scene selection
  - `REGEN-LOCK-002` reject disallowed lock type
  - `REGEN-LOCK-003` conflict when locks cannot be satisfied together
  - `REGEN-LOCK-004` stale previous preview after regenerated version creation

## Dependencies

- `lab/api/services/branded_video_assembly.py`
- `lab/api/models/video_timeline.py`
- `lab/api/models/brand_video_blueprint.py`
- `lab/api/services/video_timeline_store.py`
- `lab/api/routers/video_timelines.py`

## Invariants

- Regeneration preserves canonical timeline truth and version immutability.
- Allowed lock policy belongs to the blueprint, not to arbitrary client-side behavior.
- Lock instance data must be explicit and traceable.

## Links & Consequences

- This spec depends on branding-editor policy because the blueprint defines allowed lock types.
- It also affects feed readiness because regenerated versions invalidate prior preview/final readiness.

## Documentation Coherence

- User-facing docs must explain the difference between “regenerate” and “edit manually.”
- Avoid claims that all user selections are always preservable; constraints must stay explicit.

## Edge Cases

- A user asks to preserve a clip that no longer fits duration or structure constraints.
- Two tabs ask for different lock sets on the same base version.
- A published version is used as regeneration base.
- The blueprint policy changes after the user opens the regeneration UI but before submit.

## Implementation Tasks

- [ ] Tache 1: Add regeneration request and response contracts.
  - Fichiers: `lab/api/models/video_timeline.py`, app model wrappers if needed.
  - Action: support base version, lock instances, requested changes and typed conflicts.

- [ ] Tache 2: Add backend validation against blueprint policy.
  - Fichiers: `lab/api/routers/video_timelines.py` plus service layer.
  - Action: enforce `allowed_regeneration_locks_json` and ownership-safe references.

- [ ] Tache 3: Add regeneration merge service.
  - Fichiers: new or extended service around `branded_video_assembly.py`.
  - Action: generate a fresh proposal, then preserve allowed locked selections into the new canonical version.

- [ ] Tache 4: Persist lock metadata and invalidate stale preview/final state.
  - Fichiers: timeline model/store and router flow.
  - Action: keep lock state traceable and preserve renderer freshness rules.

## Acceptance Criteria

- Regeneration can preserve selected choices without mutating previous immutable versions.
- Requested lock types are validated against blueprint policy.
- Unsatisfied or conflicting locks return typed errors rather than silent degradation.
- Any regenerated version makes prior preview/final approval stale until refreshed.

## Test Strategy

- Add service tests for merge behavior and conflict detection.
- Add router tests for validation and stale-state handling.
- Add light app tests only for request composition and error mapping if the UI is not yet built.

## Risks

- The largest risk is implementing preservation rules that silently diverge from what the user asked to keep.
- There is also structural risk if lock data is stored outside canonical timeline/version truth in a way later agents cannot reason about.

## Execution Notes

- Prefer storing lock instance metadata at clip level when possible; track-level `locked` is too coarse for the required product behavior.
- The first implementation should favor a small set of lock types with strong proofs over a broad but weakly-defined preservation matrix.

## Open Questions

None. The user direction to preserve explicit locks during regeneration is already part of the product contract.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-08 00:00:00 UTC | 100-sg-spec | GPT-5 Codex | Created a dedicated spec for branded video regeneration with locks and preserved selections. | draft | /101-sg-ready branded video regeneration with locks and preserved selections |

## Current Chantier Flow

- 100-sg-spec: completed
- 101-sg-ready: pending
- 102-sg-start: pending
- 103-sg-verify: pending
- 104-sg-end: pending
- 005-sg-ship: pending
