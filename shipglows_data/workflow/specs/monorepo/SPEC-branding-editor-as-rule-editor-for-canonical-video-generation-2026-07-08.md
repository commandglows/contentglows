---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-07-08"
created_at: "2026-07-08 14:33:23 UTC"
updated: "2026-07-08"
updated_at: "2026-07-08 23:05:00 UTC"
status: ready
source_skill: 100-sg-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlows authentifiee, je veux creer et modifier un profil de marque de projet depuis l'app, afin que les generations video utilisent automatiquement les bons defaults de branding sans creer un second moteur de rendu."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "Settings"
  - "Brand Profiles"
  - "Canonical branded video generation"
  - "Unified ContentGlows Video Timeline"
depends_on:
  - artifact: "shipglows_data/business/business.md"
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
  - "Repo evidence: backend CRUD already exists for project-scoped brand profiles in lab/api/routers/brand_profiles.py and lab/api/services/brand_profile_store.py."
  - "Repo evidence: the app has no dedicated brand profile editor surface yet; brand data is only used indirectly by branded generation."
  - "Repo evidence: canonical branded generation already exists in lab/api/routers/video_timelines.py and can consume brand profile ids."
  - "User direction 2026-07-04: branding must become a second engine of rules, not a second render model."
next_step: "/102-sg-start brand profiles preview-through-generation and token cleanup"
---

## Title

Brand profiles and branding rules editor

## Status

Ready. This spec defines the missing app surface for project-scoped brand profiles. It gives the user a place to create, edit, select, and default brand profiles from Settings, then preview their effect through the canonical branded-generation route. The product contract is deliberately narrow: brand profiles are rule data for future generations, not a second video editor and not a second render engine. Blueprint editing stays out of scope for this first step; the backend generation path can continue to consume its own default blueprint logic.

## User Story

En tant que creatrice ContentGlows authentifiee, je veux creer et modifier un profil de marque de projet depuis l'app, afin que les generations video utilisent automatiquement les bons defaults de branding sans creer un second moteur de rendu.

## Minimal Behavior Contract

Depuis le projet actif, l'utilisateur peut ouvrir une surface Branding dans l'app, voir ses brand profiles, en creer un nouveau, modifier ses regles visuelles et textuelles, en definir un comme profil actif, puis lancer un preview canonique pour verifier l'effet sur une generation video reelle. Si la marque est incomplete, le systeme doit rester explicite sur les defaults utilises; si l'utilisateur n'a pas les droits sur le projet, rien ne doit etre enregistre; si le preview echoue, les regles sauvegardees doivent rester intactes. Le cas facile a rater est le changement de profil pendant une generation en cours: cela ne doit jamais requalifier silencieusement un rendu deja parti ni muter un timeline draft existant.

## Success Behavior

- Given an authenticated user with an active project, when they open Settings, then they can reach a dedicated Brand Profiles surface for that project.
- Given a project has one or more brand profiles, when the user opens the surface, then they can inspect the current default profile, the active revision and the saved rule values.
- Given the user edits colors, fonts, logo usage, CTA defaults, caption defaults, motion intensity, transition family or intro/outro toggles, when they save, then the backend persists a new revision for that brand profile and the selection remains project-scoped.
- Given the project has multiple profiles, when the user marks one as default, then the app reflects the new active profile and subsequent branded generations use that profile as the preferred rule source.
- Given the user wants to validate the effect of branding changes, when they press preview, then the app calls the canonical branded-generation route and shows the result of that route instead of inventing a local preview model.
- Given the user later generates a video from content, when the generation path resolves branding, then it uses the saved brand profile state rather than whatever is temporarily open in an unsaved form.
- Proof of success is that a user can manage project branding in one place, see the current active profile, and preview its impact without opening the timeline editor first.

## Error Behavior

- Missing or invalid auth returns `401`; no profile is created, updated, or deleted.
- Foreign project ownership returns `403` or `404` without leaking profile content or linked asset details.
- Invalid field values return field-level validation errors and leave the saved profile revision unchanged.
- If no brand profile exists yet, the UI shows an empty state with a clear create action rather than a broken editor.
- If preview generation fails, the editor keeps the last saved profile state and surfaces the failure as a recoverable error instead of wiping user edits.
- If the user tries to delete the current default profile, the app must block the action and explain that another profile must be set as default first.
- What must never happen: a profile save mutates a video timeline directly, the app invents a second renderable branding model, or a preview claims success without using the canonical generation path.

## Problem

The repo already has the backend substrate for project-scoped brand profiles, and the branded generation path can already consume them. What is missing is the app surface that lets creators manage these rules directly. Without that surface, branding changes stay hidden in backend payloads or one-off generation parameters, which makes the product harder to explain, harder to reuse, and more likely to drift into manual montage thinking.

## Solution

Build a dedicated brand-profile editor in the app, anchored in Settings, that manages the project-scoped defaults used by future branded video generations. The editor owns list/create/edit/default/delete-when-allowed flows and preview-through-generation requests, but it never becomes a timeline editor or a second render model. The current default profile is protected from deletion until the user explicitly promotes another profile. This keeps the user on a single rule-management surface for future generations while preserving the canonical timeline as the only editable video instance.

## Scope In

- App models and API wrappers for brand profiles.
- Provider state for loading, editing, saving, selecting default, and deleting non-default brand profiles.
- A Settings entry point and a dedicated Brand Profiles editor screen.
- Editing of project-scoped branding defaults:
  - colors
  - fonts
  - logo asset reference
  - tone keywords
  - CTA defaults
  - caption defaults
  - motion intensity
  - transition family
  - intro/outro toggles
- Preview-through-generation against the canonical branded-generation route.
- Empty, loading, validation, saving, and error states that keep the saved profile intact.
- Brand profile revision and default switching semantics.

## Scope Out

- Editing brand video blueprints in the app.
- Timeline editing or media assembly.
- A second render engine or a local preview renderer.
- Cross-project brand kit sharing or marketplace workflows.
- Org-level brand governance, approvals, or comments.
- Feed redesign.

## Constraints

- Brand profiles are project-scoped and must never cross ownership boundaries.
- The canonical branded-generation route remains the only preview path for brand impact.
- The editor must not write directly into timeline draft JSON.
- Visual implementation must resolve through the shared design-system authority and the central token source, not local hardcoded colors, spacing, radii, typography, or motion values.
- The app must keep using the existing settings/navigation architecture rather than creating a parallel standalone brand studio entrypoint.
- Any change to a brand profile only affects subsequent generations after save and should not retroactively mutate already-started generation work.
- Fresh external docs are not needed here because the behavior is defined by local repo contracts and current app/backend code, not by a changing third-party API.

## Test Contract

- Surface: backend router/service tests plus app provider and widget tests.
- Proof profile: scenario-first.
- Proof order:
  - backend ownership/default behavior for brand profiles
  - app model parsing and service wrappers
  - app provider state transitions
  - widget/navigation tests for Settings and the Brand Profiles editor
  - design-system drift check for new UI
- Required scenario ids:
  - `BRAND-PROFILE-001` list and open existing profiles from Settings
  - `BRAND-PROFILE-002` create and update a profile revision
  - `BRAND-PROFILE-003` switch the default profile without crossing project ownership
  - `BRAND-PROFILE-004` preview branding impact through the canonical branded-generation route
  - `BRAND-PROFILE-005` foreign project or invalid payload is rejected and saved state remains intact

## Dependencies

- `lab/api/models/brand_profile.py`
- `lab/api/routers/brand_profiles.py`
- `lab/api/services/brand_profile_store.py`
- `lab/api/routers/video_timelines.py`
- `app/lib/data/services/api_service.dart`
- `app/lib/providers/providers.dart`
- `app/lib/presentation/screens/settings/settings_screen.dart`
- `app/lib/presentation/screens/`
- `shipglows_data/branding/branding.md`
- `shipglows_data/product/app/product.md`
- `shipglows_data/technical/design-system-authority.md`

## Invariants

- One project can have multiple brand profiles, but only one should be treated as the default at a time.
- The current default brand profile cannot be deleted; the user must set another profile as default first.
- Brand profiles are rule data, not renderable timelines.
- The canonical generation route remains the source of truth for previewing branding impact.
- Saved profile revisions must remain available for later generations until the user explicitly changes them.
- The editor must never introduce a second branching model for video creation.

## Links & Consequences

- The new entry point belongs in Settings because brand profiles are project configuration, not one-off video editing.
- This spec changes the user promise from hidden brand parameters to explicit, reusable project branding rules.
- It prepares the ground for later blueprint editing, but it does not require blueprint editing to ship the first profile surface.
- It should keep the main video flow DRY by reusing the existing canonical branded-generation path instead of adding another creation API.

## Documentation Coherence

- Update the product and help copy if needed so branding is described as a project rule surface, not as a timeline editor.
- Keep the language aligned with the brand guide: automation with optional review, explicit limits, and no fake certainty.
- Any new user-facing labels in Settings should match the canonical wording used by the app and branding docs.

## Edge Cases

- A user creates the first brand profile for a project that had no defaults.
- A user edits a profile while a branded generation job is already in flight.
- The user attempts to delete the default profile and must first promote another one.
- A profile contains only partial branding inputs, such as colors without a logo or fonts.
- The user switches projects while the Brand Profiles screen is open.
- The canonical preview route succeeds but the returned artifact is stale because a newer save happened after the request started.

## Implementation Tasks

- [ ] Tache 1: Add app-side brand profile models and API wrappers.
  - Fichiers: `app/lib/data/models/brand_profile.dart`, `app/lib/data/services/api_service.dart`
  - Action: model list/create/update/delete/default-switch flows and parse the existing backend contract.
  - User story link: lets the app talk to the existing project-scoped brand profile backend.
  - Depends on: backend brand profile CRUD already present.
  - Validate with: model and service tests for create/read/update/delete and default payload parsing.
  - Notes: keep the wrapper focused on the existing backend contract; do not invent a new branding schema.

- [ ] Tache 2: Add brand profile state and Settings entrypoint.
  - Fichiers: `app/lib/providers/providers.dart`, `app/lib/presentation/screens/settings/settings_screen.dart`, `app/lib/router.dart`
  - Action: expose the profile list/default state and add a visible Settings row into the branding surface.
  - User story link: makes project branding discoverable from the main settings surface.
  - Depends on: Tache 1.
  - Validate with: provider and route tests proving the new screen is reachable and project-scoped.
  - Notes: reuse the existing settings layout and navigation patterns instead of creating a parallel top-level surface.

- [ ] Tache 3: Build the Brand Profiles editor screen.
  - Fichiers: `app/lib/presentation/screens/branding/brand_profiles_screen.dart`, related widgets under `app/lib/presentation/screens/branding/`
  - Action: provide create/edit/default/delete controls for the profile fields, block deletion for the current default profile, and keep unsaved edits separate from saved state.
  - User story link: lets the user manage project branding rules directly.
  - Depends on: Tache 2.
  - Validate with: widget tests for empty, loading, edit, save, error, and default-switch states.
  - Notes: use the shared design-system tokens for all spacing, typography, color, motion, and radii.

- [ ] Tache 4: Wire preview-through-generation and regression proof.
  - Fichiers: `app/lib/providers/providers.dart`, `app/lib/data/services/api_service.dart`, `app/test/`
  - Action: add a preview action that calls the canonical branded-generation route and maps the response into the editor state.
  - User story link: proves the branding surface shapes future generations without becoming a second renderer.
  - Depends on: Tache 3.
  - Validate with: provider tests and a route-level sanity check that the preview path goes through branded generation, not a local render model.
  - Notes: keep blueprint handling on the backend generation side for this first spec.

## Acceptance Criteria

- A signed-in user can open Brand Profiles from Settings.
- The user can create, edit, and delete project-scoped brand profiles.
- The user can choose one profile as the default and see that choice persist.
- Previewing branding impact goes through the canonical branded-generation route.
- No timeline draft is mutated directly by the brand editor.
- The UI remains aligned with the central design-system tokens.

## Test Strategy

- Add backend or service regression tests only where the current backend contract needs a guardrail.
- Add app model and provider tests for parse/save/default-switch behavior.
- Add widget tests for the editor states and the Settings entrypoint.
- Add a design-system drift check on the new UI files before merge.
- Prefer deterministic state assertions over snapshot-heavy tests for the editor form.

## Risks

- The main risk is accidental coupling between profile editing and timeline instance editing.
- Another risk is introducing a parallel branding surface that behaves like a second editor instead of a rule editor.
- A third risk is leaving the UI too generic and making brand profiles feel like hidden settings instead of a durable product object.

## Execution Notes

- Read order for implementation:
  - `lab/api/models/brand_profile.py`
  - `lab/api/routers/brand_profiles.py`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/screens/settings/settings_screen.dart`
  - `app/lib/presentation/screens/`
- Keep the app surface grounded in Settings because brand profiles are project configuration.
- Keep blueprint editing for a later spec if the first pass stays focused on the brand profile contract.
- The feature should reuse the canonical branded-generation path already present in the repo and should not introduce a second generation entrypoint.

## Open Questions

None. The user direction is explicit: first expose brand profiles as reusable rules, then keep optional edits and generation consistent with that system.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-07-08 14:33:23 UTC | 100-sg-spec | GPT-5 Codex | Recast the branding editor into a brand-profile-first app spec grounded in the existing backend CRUD and canonical branded-generation route. | draft | /101-sg-ready brand profiles and branding rules editor |
| 2026-07-08 16:30:06 UTC | 101-sg-ready | GPT-5 Codex | Verified the brand-profile-first spec against the current repo substrate and approved the bounded Settings-based editor slice for implementation. | ready | /102-sg-start brand profiles and branding rules editor |
| 2026-07-08 16:55:12 UTC | 102-sg-start | GPT-5 Codex | Implemented the app-side brand profile model/API wrappers, Settings entrypoint, dedicated branding screen, routing, and targeted regression tests for the first bounded slice. | implemented | /103-sg-verify brand profiles and branding rules editor |
| 2026-07-08 17:05:05 UTC | 103-sg-verify | GPT-5 Codex | Verified the implemented brand profile slice with model/service/provider tests and Flutter analyze, but the preview-through-generation contract remains unwired and the changed UI files still show unresolved design-system drift findings. | partial | /102-sg-start brand profiles preview-through-generation and token cleanup |
| 2026-07-08 20:51:49 UTC | 102-sg-start | GPT-5 Codex | Implemented the branding preview entrypoint from Settings, routed preview impact through canonical branded generation, and added regression coverage for the editor handoff and content-complete filtering. | implemented | /103-sg-verify brand profiles preview-through-generation and token cleanup |
| 2026-07-11 19:05:00 UTC | 103-sg-verify | GPT-5 Codex | Verified brand profile models/API, project-scoped provider state, Settings entrypoint, editor, default protection, canonical preview handoff, targeted Flutter/backend tests, Flutter analyze, and design-token drift. | verified | /104-sg-end branding editor and canonical branded generation |
| 2026-07-11 19:12:00 UTC | 104-sg-end | gpt-5.5 | Closed the verified brand-profile editor and canonical preview slice with hosted/device proof explicitly remaining. | closed | /005-sg-ship branding editor and canonical branded generation |

## Current Chantier Flow

- 100-sg-spec: completed
- 101-sg-ready: ready
- 102-sg-start: implemented
- 103-sg-verify: verified
- 104-sg-end: closed
- 005-sg-ship: pending
