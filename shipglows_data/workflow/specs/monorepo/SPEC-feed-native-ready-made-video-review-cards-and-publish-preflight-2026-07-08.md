---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-07-08"
created_at: "2026-07-08 00:00:00 UTC"
updated: "2026-07-10"
updated_at: "2026-07-10 00:00:00 UTC"
status: ready
source_skill: 100-sg-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlowz authentifiee, je veux voir dans le feed une vraie carte video prete a publier avec ses etats et son preflight, afin de swiper en confiance sans ouvrir l'editeur sauf si je le choisis."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "publish accounts"
  - "Unified ContentGlowz Video Timeline"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ahead-of-time-branded-video-generation-runs-and-feed-readiness-2026-07-08.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-ai-first-branded-video-generation-and-swipe-publish-2026-07-04.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/product/app/product.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Repo evidence: current feed card is still a generic content review card with no video readiness projection."
  - "Repo evidence: app/lib/data/models/content_item.dart already exposes video generation readiness, blockers and timeline/version identifiers for feed consumption."
  - "Repo evidence: app/lib/providers/providers.dart already gates feed swipe-publish behavior on branded video readiness and opens the canonical video editor when the candidate is not ready."
  - "User direction 2026-07-08: the platform should propose already-prepared content in final form by default."
next_step: "/005-sg-ship feed-native ready-made video review cards and publish preflight"
---

## Title

Feed-native ready-made video review cards and publish preflight

## Status

Ready after repo-alignment review. The current feed is still visually and textually a generic review queue, but the implemented substrate is now sufficient for a bounded feed-native execution slice: branded-video readiness, blockers, timeline identifiers and swipe-publish gating already exist in the app/backend contract. This spec can therefore move to implementation as a UI and projection-consumption chantier rather than waiting on another orchestration foundation rewrite.

## User Story

En tant que creatrice ContentGlowz authentifiee, je veux voir dans le feed une vraie carte video prete a publier avec ses etats et son preflight, afin de swiper en confiance sans ouvrir l'editeur sauf si je le choisis.

## Minimal Behavior Contract

Quand un contenu video-ready existe pour le projet actif, le feed doit afficher une carte video enrichie avec miniature ou playback court, etat produit (`ready`, `rendering`, `needs review`, `blocked`), resume de preflight publication et action primaire adapteee. Si la video n'est pas publiable, la carte l'explique directement dans le feed et propose la bonne branche de recuperation sans faire du detour vers l'editeur le comportement par defaut.

## Success Behavior

- Given a video candidate is `ready_to_publish`, when it appears in the feed, then the card shows preview or final media, destination hints and swipe affordance that truly maps to publish.
- Given a video candidate is still rendering or blocked, when it appears in the feed, then the card shows a compact non-ready state and no misleading publish-ready affordance.
- Given publish accounts or channels are missing or ambiguous, when the user sees the card, then the preflight summary explains the blocker before swipe.
- Given the user explicitly wants to modify the video, when they choose edit, then the flow opens the canonical video editor route rather than a generic text editor.

## Error Behavior

- If the feed cannot load enriched readiness data, it falls back to a safe generic state rather than claiming publishability.
- If the final artifact URL is stale or unavailable, the card shows a blocked or refreshing state and does not offer a misleading swipe-to-publish affordance.
- If publish preflight data is incomplete, the card must surface that uncertainty as a blocker or warning.

## Problem

The feed already exists as the main operator surface, but it still thinks in generic content-review terms. That is incompatible with the product direction of ready-made branded videos. Even after technical unification, users still do not get a clear feed-native answer to one simple question: is this video ready to publish right now?

## Solution

Create a dedicated video candidate card and data contract for the feed. The card should consume the ahead-of-time readiness projection, show a compact publish preflight summary, gate swipe affordances truthfully, and keep editing as an optional branch instead of the default recovery path.

## Scope In

- Feed-side video candidate read model.
- Specialized card visuals and action states for video-first content.
- Visible publish preflight summary on the feed card.
- Proper route branching to canonical video editor when the user requests edits.

## Scope Out

- Background orchestration itself.
- Branding editor.
- Regeneration with locks.
- Generic feed redesign for non-video content types.

## Constraints

- The feed must not imply blind autopublish or hidden processing.
- A card can only be labeled `ready` when the backend says it is ready with current artifact and publish prerequisites.
- The editor remains optional and secondary; it must not become the normal path for items that are only waiting for background work.

## Test Contract

- Surface: app widget/provider tests plus targeted backend projection tests.
- Proof profile: evidence-first.
- Required scenario ids:
  - `FEED-VIDEO-001` ready card shows publishable state
  - `FEED-VIDEO-002` rendering card does not expose publish swipe
  - `FEED-VIDEO-003` blocked-by-accounts state explains preflight blocker
  - `FEED-VIDEO-004` edit route opens `/editor/:id/video`

## Dependencies

- `app/lib/presentation/screens/feed/feed_screen.dart`
- `app/lib/presentation/screens/feed/content_card.dart`
- `app/lib/providers/providers.dart`
- `app/lib/data/models/content_item.dart`
- any new feed candidate API model introduced by the ahead-of-time orchestration spec

## Invariants

- Publish affordances in the feed must match backend readiness truth.
- The feed card is a consumer of enriched state, not a second orchestration engine.
- Video cards never route to the generic text editor when the user asks to edit the video.

## Links & Consequences

- This spec depends on a durable readiness projection from the orchestration spec.
- It will likely require copy updates in feed strings and support docs because the meaning of swipe changes from generic approval to actual publish intent for videos.

## Documentation Coherence

- Update product/feed copy only when the backend projection is truthful.
- Keep wording aligned with `branding.md`: automation with optional review, not magic certainty.

## Edge Cases

- The card loads while the final render completes mid-session.
- Accounts are available for some channels but not all selected destinations.
- A ready card becomes stale because the timeline changed elsewhere.
- The project has a video candidate but no signed playback URL at refresh time.

## Implementation Tasks

- [x] Tache 1: Define the feed video candidate model.
  - Fichiers: app data model plus backend projection shape.
  - Action: include readiness, blockers, destination summary helpers and timeline/version identifiers for feed consumption.

- [x] Tache 2: Add specialized video card rendering.
  - Fichiers: `app/lib/presentation/screens/feed/content_card.dart`.
  - Action: show media preview, readiness badge, blocker summary and publish-state-aware affordances.

- [x] Tache 3: Surface publish preflight results.
  - Fichiers: provider plus UI binding.
  - Action: expose readiness/blocker-driven preflight summary already available in feed metadata in a compact card section.

- [x] Tache 4: Align feed actions with video readiness.
  - Fichiers: `feed_screen.dart`, providers.
  - Action: keep swipe publish only for truly ready states and route non-ready states to explicit recovery actions.

## Acceptance Criteria

- Video items in the feed show a specialized card that distinguishes `ready`, `rendering`, `needs review` and `blocked`.
- Swipe-to-publish is only visible or active when the backend says the item is publishable.
- Preflight blockers are visible before swipe rather than being discovered only after an attempted publish.
- Choosing edit from a video card opens the canonical video editor route.

## Test Strategy

- Add widget tests for card states and CTA gating.
- Add provider tests for state mapping from backend readiness into feed semantics.
- Keep targeted backend projection tests if feed data is served by a dedicated route.

## Risks

- The main risk is a dishonest UX that still looks publishable when the backend state is not ready.
- Another risk is overloading the generic feed card instead of creating a clear video-specific projection.

## Execution Notes

- Preserve existing feed patterns where they still fit, but do not force the generic content-review card to absorb all video states if that makes the UI ambiguous.

## Open Questions

None. The product direction is already explicit: the feed is a consumption and decision surface for already-prepared content.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-08 00:00:00 UTC | 100-sg-spec | GPT-5 Codex | Created a dedicated product spec for feed-native ready-made video cards and publish preflight. | draft | /101-sg-ready feed-native ready-made video review cards and publish preflight |
| 2026-07-09 00:00:00 UTC | 101-sg-ready | GPT-5 Codex | Verified the spec against the live repo: generic feed UI still needs the dedicated video-card layer, but the readiness projection, swipe gating and canonical video edit route are implemented enough to approve a bounded implementation slice. | ready | /102-sg-start feed-native ready-made video review cards and publish preflight |
| 2026-07-10 00:00:00 UTC | 102-sg-start | GPT-5 Codex | Implemented a specialized feed-native video card, truthful publish gating, visible preflight summary, explicit `/editor/:id/video` edit affordance, and FEED-VIDEO-001..004 widget coverage. | completed | /103-sg-verify feed-native ready-made video review cards and publish preflight |
| 2026-07-10 00:00:00 UTC | 103-sg-verify | GPT-5 Codex | Re-verified the feed-native video card after the dedicated media preview landed: targeted analyze/tests passed, the preview contract is now proven in widget coverage, and the feed remains truthful about publish readiness. | OK | /104-sg-end feed-native ready-made video review cards and publish preflight |
| 2026-07-10 00:00:00 UTC | 104-sg-end | GPT-5 Codex | Deferred closure after implementation and verify because feed/operator copy still describes a generic approve-or-publish queue, while the new video card now exposes readiness states and preflight semantics that need docs/copy alignment before ship framing. | deferred | /300-sg-docs sync feed-native video card copy and operator docs |
| 2026-07-10 00:00:00 UTC | 300-sg-docs | GPT-5 Codex | Aligned the feed operator copy and canonical app docs with the implemented video-card readiness/preflight model so the chantier can return to closure. | completed | /104-sg-end feed-native ready-made video review cards and publish preflight |
| 2026-07-10 00:00:00 UTC | 104-sg-end | GPT-5 Codex | Closed the chantier bookkeeping after implementation, verification, tracker/changelog updates, and docs alignment for the feed-native video publish-preflight flow. | closed | /005-sg-ship feed-native ready-made video review cards and publish preflight |

## Current Chantier Flow

- 100-sg-spec: completed
- 101-sg-ready: ready
- 102-sg-start: completed
- 103-sg-verify: completed
- 104-sg-end: closed
- 005-sg-ship: pending
