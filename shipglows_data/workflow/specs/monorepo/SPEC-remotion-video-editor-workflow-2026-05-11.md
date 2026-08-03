---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-11"
created_at: "2026-05-11 15:03:03 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 15:58:47 UTC"
status: ready
source_skill: sf-spec
source_model: "gpt-5.5"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlowz authentifiee, je veux construire un vrai workflow video Remotion avec scenes, assets, preview editable et rendu final, afin de transformer un contenu existant en video exploitable sans sortir du workflow editor/reels."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - app
  - lab
  - worker
  - contentglowz/remotion-template
  - editor workflow
  - reels workflow
  - content assets
  - Image Robot
  - Turso jobs
  - Clerk auth
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/reels-from-content-preview-workflow.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "contentglowz/remotion-template/README.md"
    artifact_version: "1.0.0 local package; Remotion dependencies ^4.0.0"
    required_status: "inspiration-only"
  - artifact: "Remotion renderMedia docs"
    artifact_version: "2026-05-11"
    required_status: "official"
  - artifact: "Remotion SSR Node docs"
    artifact_version: "2026-05-11"
    required_status: "official"
  - artifact: "Remotion selectComposition docs"
    artifact_version: "2026-05-11"
    required_status: "official"
supersedes: []
evidence:
  - "Existing ready spec remotion-render-service-integration.md covers the worker/API render foundation and must not be duplicated."
  - "Existing ready spec reels-from-content-preview-workflow.md covers the MVP /reels preview/export flow and must remain the first user-facing render path."
  - "Existing editor-linked AI visuals spec only prepares image assets such as video_cover; it explicitly scopes out timeline and Remotion rendering."
  - "contentglowz/remotion-template/server/index.ts exposes a quiz-specific Express render API using /renders and an in-memory queue."
  - "contentglowz/remotion-template/server/render-queue.ts uses selectComposition() and renderMedia(), but currently targets QuizVideo, buffers output, and includes Telegram side effects."
  - "contentglowz/remotion-template/remotion/Root.tsx registers HelloWorld and QuizVideo, not a scene-based ContentGlowz video composition."
  - "app/lib/presentation/screens/reels/reels_screen.dart currently contains the Instagram import UI; the ready reels spec introduces create-from-content preview/export."
  - "app/lib/router.dart has /reels and /editor/:id; future editor video routes must be added deliberately and sanitized before broad /editor/* matching."
  - "lab/api/routers/reels.py currently handles Instagram download/cookies; render endpoints are specified as separate additions by the ready Remotion integration spec."
  - "lab/api/services/job_store.py persists job status/data in a generic jobs table suitable for workflow jobs, but scene/project state needs an explicit contract."
  - "User decision 2026-05-11: the real video editor V1 should be a guided storyboard, not a free timeline."
  - "User decision 2026-05-11: the main entry point is the content editor."
  - "User decision 2026-05-11: final render/publication requires validating a preview first."
  - "User decision 2026-05-11: V1 includes text, scenes, images, durations, and layouts only; audio, voiceover, music, and subtitles stay future scope."
  - "User decision 2026-05-11: support vertical plus non-vertical formats from the start, with vertical as the primary focus."
  - "Readiness decision 2026-05-11: use primary route /editor/:id/video, with /reels linking into the same content-scoped editor instead of owning a separate full editor."
  - "Readiness decision 2026-05-11: V1 stores one active video project per source content and format preset, with immutable versions and internal stale history rather than a visible version browser."
  - "Readiness decision 2026-05-11: V1 initial storyboard generation is deterministic from source content and trusted assets; AI planning is future scope."
  - "Readiness decision 2026-05-11: V1 format presets are vertical_9_16 as default and landscape_16_9 as the required non-vertical preset."
  - "Fresh-docs checked 2026-05-11: official Remotion renderMedia, SSR Node and selectComposition docs support JSON inputProps, reusable bundles and passing the same inputProps to selectComposition and renderMedia."
next_step: "/sf-start Remotion video editor workflow"
---

## Title

Remotion Video Editor Workflow

## Status

Ready after `sf-ready` rerun. This is the real ContentGlowz video editor workflow for V1: guided storyboard from the content editor, preview validation required before final render/publication, text/scenes/images/durations/layouts only, and vertical-first multi-format support with `vertical_9_16` plus `landscape_16_9`. It depends on the ready Remotion render service integration and the ready reels preview/export MVP. It must be implemented after those foundations are live and verified, because this spec adds scene/editor state and orchestration on top of their API and worker contracts.

## User Story

En tant que creatrice ContentGlowz authentifiee, je veux construire un vrai workflow video Remotion avec scenes, assets, preview editable et rendu final, afin de transformer un contenu existant en video exploitable sans sortir du workflow editor/reels.

## Minimal Behavior Contract

Depuis un contenu appartenant au projet actif, ContentGlowz cree ou ouvre un projet video storyboard compose de scenes ordonnees, de textes, de timings, de visuels et de layouts, puis permet de previsualiser, modifier, sauvegarder, relancer une preview et demander un rendu final via le worker Remotion existant. La preview de la version courante est obligatoire avant final render/publication. Si le contenu, les assets, le worker, la sauvegarde, les droits, la preview ou le rendu final echouent, l'utilisateur voit un etat recuperable et le systeme conserve la derniere version coherente du projet video sans annoncer de MP4 pret. Le cas facile a rater est la separation entre montage et rendu: l'editeur manipule un modele de scenes versionne et valide, tandis que Remotion reste le moteur de composition/rendu, sans importer un editeur professionnel arbitraire ni reutiliser silencieusement un ancien artefact d'une autre version.

## Success Behavior

- Given un utilisateur Clerk authentifie avec un projet actif et un contenu owned, when il choisit de creer une video depuis l'editeur de contenu, then ContentGlowz cree un `video_project` lie a `content_id`, `project_id`, `user_id`, `source_content_version`, et une premiere version de scenes storyboard.
- Given un `video_project` existant, when l'utilisateur ouvre l'editeur video, then l'app affiche les scenes, leurs textes, durees, assets, statut de validation, preview courante, statut de rendu et derniere date de sauvegarde.
- Given l'utilisateur modifie une scene, remplace un asset ou reordonne une sequence autorisee, when il sauvegarde, then le backend persiste une nouvelle version coherente du projet et invalide toute preview/final render derivee d'une version plus ancienne.
- Given une version valide du projet video, when l'utilisateur demande une preview, then le backend transforme le modele de scenes en props Remotion validees, lance ou reutilise un job preview pour cette version exacte, et expose un statut pollable.
- Given la preview est terminee, when l'utilisateur la lit dans l'app, then la video charge via une URL d'artefact signee ou un endpoint compatible avec les contraintes deja definies par `reels-from-content-preview-workflow.md`.
- Given la preview correspond a la version courante et a ete validee, when l'utilisateur demande le rendu final, then le backend cree un job final distinct lie a la version video et au preview job valide, puis expose l'artefact final une fois complete.
- Given format options are available, when a storyboard is created or rendered, then `vertical_9_16` is the default/primary format and `landscape_16_9` is supported from the start as the non-vertical preset.
- Given un asset `video_cover` ou une image generee par l'UI visuels IA existe pour le contenu, when l'utilisateur choisit un asset de scene, then l'editeur peut le proposer comme candidat sans faire confiance a une URL arbitraire fournie par Flutter.
- Proof of success is a persisted video project with versioned scenes, a scene-based Remotion composition previewable locally, final render jobs tied to exact project versions, and tests covering ownership, stale versions, invalid props, asset validation and preview/final state transitions.

## Error Behavior

- Missing, expired or invalid Clerk auth returns `401` through the existing auth boundary; no video project, preview job or final job is created.
- A content, reel, asset, preview job or video project outside the current user's projects returns `403` or `404` without leaking title, paths, asset URLs or render state.
- If the render service integration spec is not implemented or not healthy, the editor can save scene drafts but preview/final actions are disabled with a recoverable backend unavailable state.
- If scene JSON is malformed, has unsupported scene type, invalid duration, missing required text, unsupported asset reference, or props exceed worker limits, the backend rejects the version and keeps the previous valid version active.
- If the user edits after a preview completes, that preview becomes stale and final export from it is blocked until a preview exists for the current version.
- If asset validation fails because an Image Robot result is foreign, deleted, non-durable, non-primary where primary is required, or not compatible with video usage, the scene keeps the previous asset and shows an actionable error.
- If two saves race, the backend uses optimistic version checks; stale writes return conflict and must not overwrite newer scenes.
- If worker preview/final rendering fails, the job is marked failed with sanitized error details and the video project remains editable.
- If signed artifact URL expires, the app refreshes job status for the current version rather than treating the project as failed.
- If the user changes active project while loading, saving, polling, or rendering, stale responses are ignored and the editor resets to the new project context.
- What must never happen: arbitrary file paths or raw media URLs from the client enter Remotion props, provider secrets reach Flutter, a stale preview is exported as final, an old version's final MP4 is shown as current, or the future editor bypasses the existing Remotion worker/API contracts.

## Problem

ContentGlowz has two ready specs for a pragmatic Remotion MVP: one for the render worker/API foundation and one for a `/reels` create-from-content preview/export flow. The current AI visuals UI spec only prepares image assets such as `video_cover`; it intentionally does not provide timeline, scenes or Remotion editing. The missing future layer is the real video workflow: a persistent scene model, per-scene assets, editable preview loop, final render orchestration, and integration points from the existing editor and reels surfaces.

## Solution

Introduce a ContentGlowz video project model and content-editor-linked storyboard workflow that stores scene-level state in the backend, maps validated scene versions to Remotion props, and uses the already-specified Remotion worker for preview and final renders. Remotion remains the render/composition engine; the product surface is a guided storyboard, not an arbitrary professional timeline editor.

## Scope In

- Add a durable video project/workflow concept linked to `content_id`, `project_id`, `user_id`, `format_preset`, optional source reel job, and versioned scene data.
- Use one active video project per source content and format preset in V1; creating again from the same editor opens the active project instead of silently duplicating drafts.
- Generate an initial guided storyboard draft deterministically from existing content and available trusted assets.
- Represent scenes with typed fields: scene id, order, type, duration, text layers, visual asset references, layout/template id, transition metadata, and render-safe metadata.
- Support scene-level asset selection from trusted content assets, Image Robot durable outputs, and `video_cover` records only after backend ownership and durability validation.
- Add save/load/version APIs for video projects.
- Add preview render orchestration for the current video project version by delegating to the ready Remotion render service integration.
- Add final render orchestration only from a completed preview for the current version.
- Add app UI at `/editor/:id/video`, launched primarily from the existing content editor with project/content context preserved.
- Add Remotion scene composition(s) in the worker using a generic scene props schema instead of quiz-specific `QuizVideo` props.
- Add stale-version handling so edits invalidate older preview/final readiness.
- Add status surfaces for draft saved, preview queued/in progress/completed/failed/stale, final queued/in progress/completed/failed.
- Support `vertical_9_16` as the primary format plus `landscape_16_9` from the start.
- Add tests across backend model validation, API permissions, app state transitions, worker prop validation and stale preview prevention.
- Preserve the existing Instagram import and MVP reels flow.

## Scope Out

- Free timeline editing in V1; the chosen product mode is guided storyboard.
- Full arbitrary professional video editor parity with Premiere, CapCut, Final Cut, DaVinci Resolve or After Effects.
- Frame-accurate multi-track timeline unless explicitly chosen later.
- Browser-embedded Remotion Player requirement unless validated separately; MP4 preview through the existing signed artifact path remains acceptable.
- Replacing Remotion with a custom rendering engine.
- Rewriting the ready Remotion worker/API integration.
- Rewriting the ready `/reels` create-from-content MVP.
- Automatic voiceover, music generation, subtitles, captions or waveform editing unless covered by a future audio/caption spec.
- Social publishing of final videos.
- CDN/object-storage migration beyond what existing render specs require.
- Generic asset library management outside the current project/content/video workflow.
- Arbitrary user media upload or binary upload flows; scene images must come from already trusted ContentGlowz assets in V1.
- Visible version-history browsing; V1 keeps immutable versions for consistency, stale prevention and support diagnostics, while the UI focuses on the current editable draft and current/stale render status.
- AI storyboard planning; V1's initial storyboard builder is deterministic from saved content and trusted assets.
- Importing the `contentglowz/remotion-template` quiz/Telegram behavior as production product behavior.

## Constraints

- This spec depends on `remotion-render-service-integration.md`; do not duplicate or bypass its worker token, artifact signing, local retention, preview/final job separation, capacity and path-safety rules.
- This spec depends on `reels-from-content-preview-workflow.md`; the simple `/reels` preview/export MVP must remain available and should become one entry point into this richer editor, not be deleted.
- This spec depends on `SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`; AI visuals provide candidate assets such as `video_cover`, but they do not define video scenes.
- `lab` remains the authenticated public API boundary. Flutter does not call the Remotion worker directly.
- Remotion remains responsible for rendering from validated props; ContentGlowz remains responsible for auth, ownership, scene persistence, asset validation and job orchestration.
- All scene and asset references must be server-side identifiers, not arbitrary client-supplied URLs or local paths.
- Every preview/final job must be tied to a specific immutable video project version.
- Project version writes must use optimistic concurrency or equivalent stale-write protection.
- The first implementation is a bounded, guided storyboard editor.
- Keep UI utilitarian and workflow-linked; no marketing page or global playground.
- Render creation is online-only and must not enter the offline write queue.
- Signed artifact URLs and worker/internal tokens must be redacted from diagnostics and never persisted in durable Flutter state.
- Durable video project scenes and immutable versions must use explicit Turso-backed video project storage. `JobStore` stores preview/final render job metadata only and must not be the source of truth for scene drafts.
- V1 supports exactly two format presets: `vertical_9_16` and `landscape_16_9`; adding square or other variants requires a follow-up spec or explicit scope extension.

## Dependencies

- Ready foundation spec: `shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md`.
- Ready app MVP spec: `shipglows_data/workflow/specs/monorepo/reels-from-content-preview-workflow.md`.
- Ready visual asset spec: `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`.
- Existing app entrypoints:
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/presentation/screens/reels/reels_screen.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
- Existing backend entrypoints:
  - `lab/api/routers/reels.py`
  - `lab/api/services/job_store.py`
  - `lab/api/dependencies/auth.py`
  - `lab/api/dependencies/ownership.py`
  - status/content asset APIs used by the AI visuals spec.
- Existing Remotion prototype files as inspiration only:
  - `contentglowz/remotion-template/server/index.ts`
  - `contentglowz/remotion-template/server/render-queue.ts`
  - `contentglowz/remotion-template/remotion/Root.tsx`
- Expected new backend API family:
  - `POST /api/videos/projects/from-content`
  - `GET /api/videos/projects/{video_project_id}`
  - `PATCH /api/videos/projects/{video_project_id}`
  - `POST /api/videos/projects/{video_project_id}/preview`
  - `POST /api/videos/projects/{video_project_id}/render-final`
  - `GET /api/videos/projects/{video_project_id}/jobs/{job_id}`
- Expected app route:
  - `/editor/:id/video` as the primary editor-linked video workspace, sanitized as `/editor/:id/video` before the generic `/editor/*` sanitizer.
  - `/reels` may link to `/editor/:id/video` for eligible content, but it does not own a separate full storyboard editor in V1.
- Expected worker capability:
  - A scene-based composition, for example `ContentGlowzSceneVideo`, accepting validated scene props and rendering MP4 for `vertical_9_16` and `landscape_16_9`.
- Fresh external docs checked:
  - `fresh-docs checked`: Remotion `renderMedia()` official docs at `https://www.remotion.dev/docs/renderer/render-media`.
  - `fresh-docs checked`: Remotion SSR Node official docs at `https://www.remotion.dev/docs/ssr-node`.
  - `fresh-docs checked`: Remotion `selectComposition()` official docs at `https://www.remotion.dev/docs/renderer/select-composition`.

## Invariants

- A video project always belongs to exactly one user, project and source content unless a future spec introduces multi-source videos.
- V1 has at most one active video project for each `(user_id, project_id, content_id, format_preset)` tuple.
- A video project version is immutable once a preview or final render references it.
- The current editable draft can change; render jobs reference immutable snapshots.
- Scene order is deterministic and server-validated.
- Scene duration totals must stay within the duration and capacity limits exposed by the ready render service at implementation time; exceeding those limits requires a separate capacity/product spec.
- Asset references in scenes are backend-owned records; Remotion receives sanitized render URLs or resolved asset descriptors only after backend validation.
- Preview and final render jobs are distinct and cannot overwrite each other.
- Final render requires a completed and user-validated preview for the exact current version.
- A stale preview/final can remain visible as historical state only if clearly marked stale and not presented as current.
- Worker errors are normalized by the lab API before reaching Flutter.
- Existing `/reels` Instagram import and MVP create-from-content behavior remain testable after this workflow is added.

## Links & Consequences

- `app` needs a new video editor surface under the content editor at `/editor/:id/video` rather than a standalone global route by default.
- `app/lib/router.dart` needs route ordering and Sentry sanitizer updates for `/editor/:id/video` before generic `/editor/*` matching.
- `app/lib/presentation/screens/reels/reels_screen.dart` must not lose the import and MVP preview/export tabs introduced by the ready reels spec. It may link an eligible item into `/editor/:id/video`, but it is not the primary entry for the full storyboard editor.
- `app/lib/presentation/screens/editor/editor_screen.dart` may gain a video action next to visual actions once source content is eligible.
- `lab` needs video project models/routes/services separate from Instagram reels routes for readability.
- `JobStore` remains useful for render job state, but scene project state should be modeled deliberately instead of hidden entirely inside transient job metadata.
- `worker` or the derived worker package needs a scene composition and schema in addition to the MVP content-summary composition.
- AI-generated visuals become inputs to video scenes only through validated content assets, not direct provider URLs.
- Analytics/observability should distinguish draft saves, preview renders, stale previews, final renders and render failures.
- Performance risk increases because editor interactions may trigger many previews; rate limits and explicit preview actions should prevent render spam.

## Documentation Coherence

- Update `app/README.md` with the video editor workflow, route, online-only constraints and dependency on the Remotion worker.
- Update `lab/README.md` or environment docs with video project routes, storage assumptions and render versioning rules.
- Update `worker/README.md` with scene composition props, sample scene JSON and local render commands.
- Add changelog entries for video project editing, preview, final render and stale-version behavior.
- Add support/operator notes explaining that old local preview/final artifacts may expire according to the retention policy defined by the ready render integration spec.
- Do not duplicate Remotion official documentation in product docs; link to the worker README and keep implementation notes concise.

## Edge Cases

- Source content is deleted, archived or moved to another project after a video project is created.
- Active project changes while the video editor is open.
- Content body or generated summary changes after scene draft creation.
- Two browser tabs edit the same video project concurrently.
- A preview completes after the user has already saved a newer version.
- A final render is requested from a stale preview.
- A scene has no visual asset and must use a fallback layout.
- A referenced asset is deleted, loses primary status, expires or fails CDN access.
- Image Robot asset exists but is not eligible for video usage.
- Scene text is too long for its layout and needs validation before render.
- Scene total duration is zero, too short, too long or inconsistent with Remotion composition duration.
- Worker accepts props but Remotion composition throws at render time.
- JobStore has a render job but the video project version was deleted or migrated.
- Signed artifact URL expires while the preview player is open.
- User navigates from `/reels` to editor video and back during polling.
- Backend restarts during preview/final render.
- Local render retention deletes an artifact that a stale project still references.
- The product later chooses free timeline editing, requiring a different scene model granularity.

## Implementation Tasks

- [ ] Tache 1: Prime implementation context and lock readiness contracts.
  - Fichier: `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - Action: Read this spec, the two ready Remotion specs, the editor-linked visuals spec, and the app/lab guidelines before coding; confirm implementation follows `/editor/:id/video`, Turso video project storage, deterministic initial storyboard generation, trusted assets only, `vertical_9_16` plus `landscape_16_9`, and inherited render capacity limits.
  - User story link: Prevents building the wrong editor surface or bypassing the preview-first creator workflow.
  - Depends on: Ready and verified `remotion-render-service-integration.md` plus `reels-from-content-preview-workflow.md`.
  - Validate with: implementation notes list the files read first and no Open Questions are reopened.
  - Notes: Stop and return to `/sf-spec` only if implementation requires product changes outside guided storyboard V1.

- [ ] Tache 2: Define backend video project models.
  - Fichier: `lab/api/models/video_projects.py`
  - Action: Add Pydantic models for `VideoProject`, `VideoProjectVersion`, `VideoScene`, `VideoSceneAssetRef`, preview/final status summaries, and save requests.
  - User story link: Gives the editor a durable scene model instead of rendering directly from ad-hoc client props.
  - Depends on: Tache 1.
  - Validate with: Python tests for valid scene JSON, invalid scene type, duration limits, missing required fields and unknown forward-compatible metadata.
  - Notes: Do not model this as arbitrary Remotion JSX from the client.

- [ ] Tache 3: Add video project persistence service.
  - Fichier: `lab/api/services/video_project_store.py`
  - Action: Persist video projects and immutable versions in explicit Turso-backed video project tables; include optimistic concurrency checks and a uniqueness rule for active `(user_id, project_id, content_id, format_preset)`.
  - User story link: Lets creators save and return to editable video drafts.
  - Depends on: Tache 2.
  - Validate with: Service tests for create, load, save new version, stale write conflict, project ownership filter and version immutability.
  - Notes: Route table creation/migration through the ContentGlowz Turso migration guardrails before coding.

- [ ] Tache 4: Add backend video project routes.
  - Fichier: `lab/api/routers/video_projects.py`
  - Action: Add authenticated create-from-content, get, save, preview and final render endpoints with ownership checks.
  - User story link: Connects editor/reels UI to durable video workflow operations.
  - Depends on: Taches 2-3.
  - Validate with: FastAPI tests for auth, owned content, foreign project denial, create initial draft, save version, conflict, preview request and final request.
  - Notes: Keep this separate from Instagram-specific `reels.py` unless implementation discovers a stronger local convention.

- [ ] Tache 5: Implement scene draft generation from content.
  - Fichier: `lab/api/services/video_scene_builder.py`
  - Action: Deterministically convert source content plus available trusted assets into an initial ordered scene draft.
  - User story link: Gives the creator a useful starting video rather than a blank technical form.
  - Depends on: Tache 3.
  - Validate with: Unit tests for empty body, long body, markdown/code content, missing assets and deterministic output.
  - Notes: Do not call an AI planner in V1; AI storyboard planning is future scope.

- [ ] Tache 6: Add scene-to-Remotion props adapter.
  - Fichier: `lab/api/services/remotion_scene_props.py`
  - Action: Validate a video project version, resolve owned asset references to render-safe descriptors, and produce worker input props for the scene composition.
  - User story link: Keeps Remotion rendering grounded in the saved scene model.
  - Depends on: Taches 3-5 and the ready render service integration.
  - Validate with: Unit tests for asset path safety, foreign asset rejection, missing asset fallback, props size limits and stale version prevention.
  - Notes: The client never sends final Remotion props directly.

- [ ] Tache 7: Extend the Remotion worker with a scene composition.
  - Fichier: `worker/remotion/Root.tsx`
  - Action: Register a scene-based composition using typed props and schema validation for `vertical_9_16` and `landscape_16_9`.
  - User story link: Lets the worker render the saved ContentGlowz scene timeline.
  - Depends on: Ready `worker` package from the render integration spec.
  - Validate with: Worker tests or local sample render using a checked-in sample scene props JSON.
  - Notes: Preserve the existing MVP composition required by the ready reels spec.

- [ ] Tache 8: Add app video editor models and API methods.
  - Fichier: `app/lib/data/models/video_project.dart`
  - Action: Define Dart models for video projects, scenes, assets, versions, status and artifact summaries, plus JSON parsing.
  - User story link: Lets Flutter render and update the project state safely.
  - Depends on: Taches 2-4 API contract.
  - Validate with: Dart model tests for parse, unknown enum fallback, missing optional fields and stale version flags.
  - Notes: Add `ApiService` methods in the existing service file during implementation if that is still the local pattern.

- [ ] Tache 9: Add video editor state provider.
  - Fichier: `app/lib/providers/providers.dart`
  - Action: Add or route to a focused provider/notifier for loading, editing, saving, polling preview/final jobs and handling stale responses.
  - User story link: Keeps multi-step editor state consistent across saves and renders.
  - Depends on: Tache 8.
  - Validate with: Provider tests for load, save, conflict, preview, stale preview, final render, cancel/error and active project change.
  - Notes: Move to a dedicated provider file only if implementation confirms that pattern is acceptable in the repo.

- [ ] Tache 10: Build the editor-linked video workspace UI.
  - Fichier: `app/lib/presentation/screens/editor/video_editor_screen.dart`
  - Action: Add the video editor screen with scene list/storyboard, selected scene controls for text, scene order/add/delete within bounds, image asset, duration, layout, format preset, preview status, final render status and recoverable errors.
  - User story link: Gives the creator the actual workflow to review and adjust scenes before rendering.
  - Depends on: Taches 8-9.
  - Validate with: Widget tests for empty/loading/error, scene edit, asset replace, save conflict, preview complete, stale preview and final complete states.
  - Notes: Keep controls bounded to guided storyboard V1; do not add free timeline, audio, captions, music or transitions.

- [ ] Tache 11: Wire entrypoints from editor and reels.
  - Fichier: `app/lib/router.dart`
  - Action: Add `/editor/:id/video`, sanitize it before generic `/editor/*` matching, then add launch actions from the editor and optional links from reels.
  - User story link: Integrates the workflow with existing content and reels surfaces.
  - Depends on: Tache 10.
  - Validate with: Router tests and manual navigation from `/editor/:id` and `/reels`.
  - Notes: Preserve current route behavior and add specific editor-video sanitizer before generic `/editor/*` matching.

- [ ] Tache 12: Add documentation and operator samples.
  - Fichier: `worker/README.md`
  - Action: Document scene props, sample render command, editor workflow assumptions and troubleshooting for stale previews/render failures.
  - User story link: Makes future implementation and support repeatable.
  - Depends on: Taches 4, 7 and 10.
  - Validate with: README commands reviewed against package scripts and API routes.
  - Notes: Also update app/lab docs and changelog as listed in Documentation Coherence.

## Acceptance Criteria

- [ ] CA 1: Given owned source content, when the user creates a video project, then a project-scoped draft with ordered scenes is persisted and reloadable.
- [ ] CA 1a: Given an active video project already exists for the same user, project, content and format preset, when the user launches video again from `/editor/:id`, then the app opens that project instead of creating an untracked duplicate.
- [ ] CA 2: Given a foreign content id, when creating or opening a video project, then the API returns ownership-safe denial without leaking metadata.
- [ ] CA 3: Given a saved draft, when the user edits a scene and saves with the current version, then a new version is persisted and older render artifacts are marked stale.
- [ ] CA 4: Given two concurrent saves, when the older client saves after a newer version exists, then the older save returns conflict and does not overwrite the new version.
- [ ] CA 5: Given a scene references an asset, when preview is requested, then the backend verifies the asset belongs to the same user/project/content or rejects the request.
- [ ] CA 6: Given a valid current version, when preview is requested, then the backend creates or returns a preview job tied to that exact version.
- [ ] CA 7: Given preview for version N completes and the user saves version N+1, when final render is requested, then final render is blocked until version N+1 has a completed preview.
- [ ] CA 8: Given the worker fails to render scene props, when the user polls status, then the job is failed with a sanitized message and the project remains editable.
- [ ] CA 9: Given a signed artifact URL expires, when the current version still has a completed preview/final job, then the app refreshes status to obtain a fresh URL.
- [ ] CA 10: Given the existing reels MVP flow, when the video editor workflow is added, then Instagram import and simple create-from-content preview/export still pass their tests.
- [ ] CA 11: Given the app route changes, when Sentry records route names, then video editor ids are sanitized and no raw content/video ids appear as transaction names.
- [ ] CA 12: Given implementation completes, when docs are reviewed, then app, lab and worker documentation mention editor workflow setup, env dependencies, stale preview behavior and retention limits.
- [ ] CA 13: Given format presets are shown, when a video project is created or rendered, then `vertical_9_16` is default and `landscape_16_9` can be selected and rendered without adding square or arbitrary custom dimensions.
- [ ] CA 14: Given the user has not validated a completed preview for the current version, when final render/publication is requested through UI or API, then the request is blocked server-side and the UI explains that a current preview must be validated first.

## Test Strategy

- Backend model tests for video project request/response parsing, scene validation, asset references and status enums.
- Backend service tests for create/load/save/version conflict, immutable version snapshots and project/user filtering.
- Backend service tests for one active video project per `(user_id, project_id, content_id, format_preset)` and deterministic draft generation from the same source content.
- Backend API tests for Clerk auth, ownership, foreign project denial, malformed scene payloads, preview request, final request and stale preview prevention.
- Backend adapter tests for scene-to-Remotion props generation, props size limits, duration limits, asset resolution and path safety.
- Worker tests or local render smoke test for the scene composition with sample props for `vertical_9_16`, `landscape_16_9`, and at least one missing-asset fallback case.
- Flutter model tests for JSON parsing and unknown enum fallbacks.
- Flutter provider tests for load/edit/save/preview/final state transitions, polling lifecycle, stale responses and active project changes.
- Flutter widget tests for the video editor surface on narrow and desktop widths, long text, scene selection, asset errors and stale preview warnings.
- Flutter router tests for `/editor/:id/video` route creation and sanitized Sentry route names.
- Manual QA: create from editor, create from reels, edit scene, save, preview, edit again, confirm stale preview, preview current version, final render, reload route and confirm persisted state.
- Regression QA: existing `/reels` Instagram import, ready reels preview/export MVP, editor visual asset selection and publish media behavior.

## Risks

- Product risk: building a free timeline too early could create a large professional editor project instead of a guided ContentGlowz workflow.
- Architecture risk: storing scene state inside generic job metadata would make drafts, concurrency and history brittle.
- Security risk: accepting client-provided media URLs or paths could create cross-project data leaks or arbitrary file render access.
- Render risk: scene props may grow too large or include media that Remotion cannot fetch reliably in local/dev environments.
- UX risk: stale preview/final states can confuse users unless the current-version relationship is explicit.
- Performance risk: repeated preview renders can saturate the local worker; explicit preview actions and existing render capacity limits must apply.
- Migration risk: if Turso schema changes are needed, they must follow ContentGlowz migration guardrails and cannot be hidden inside this spec's implementation.
- Dependency risk: this chantier is blocked if the two ready Remotion specs are not actually implemented and verified first.

## Execution Notes

- Read first: `remotion-render-service-integration.md`, `reels-from-content-preview-workflow.md`, and `SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`; they define the lower layers and boundaries.
- Then read: `shipglows_data/technical/app/guidelines.md`, `shipglows_data/technical/lab/guidelines.md`, `app/lib/router.dart`, `app/lib/presentation/screens/editor/editor_screen.dart`, `lab/api/services/job_store.py`, `lab/api/dependencies/auth.py`, and `lab/api/dependencies/ownership.py`.
- Implement with the readiness-fixed contracts: `/editor/:id/video`, explicit Turso video project tables, deterministic initial storyboard generation, trusted assets only, one active video project per source content and format preset, `vertical_9_16` plus `landscape_16_9`, and inherited render capacity limits.
- Start backend-first with explicit scene/version contracts, then worker scene props, then Flutter UI. Avoid starting with UI controls that imply timeline freedom.
- Reuse the existing Remotion worker and render job contracts. Do not create a second public render API from Flutter to Node.
- Keep Remotion compositions deterministic from props. Do not let client-side JSX, arbitrary JavaScript or raw URLs become render inputs.
- Use official Remotion docs already checked for `renderMedia()`, SSR Node and `selectComposition()` assumptions; recheck official docs during implementation if package versions differ from Remotion `^4.0.0` in the prototype/worker.
- Stop and reroute if implementation requires professional timeline features, audio/subtitle generation, object storage migration, or new binary upload flows; each is a separate spec.
- Stop and ask the user if implementation needs a product decision beyond the captured V1 storyboard controls, for example square format, visible version history, AI storyboard planning, public publishing, uploaded media, or timeline-like tracks.
- Suggested validation commands: FastAPI tests for `lab`, Flutter tests/analyze for `app`, and a worker scene render smoke test for both presets.

## Product Decisions Captured

- V1 editor mode is a guided storyboard, not a free timeline.
- The main entry point is the content editor.
- Final render/publication requires a validated preview for the current version.
- V1 scene controls are text, scenes, images, durations, and layouts only.
- Audio, voiceover, music, subtitles, and captions are future scope.
- Vertical is the primary format, with non-vertical format support from the start.
- Implementation route is `/editor/:id/video`; `/reels` may link into it but does not own the full storyboard editor.
- V1 supports `vertical_9_16` and `landscape_16_9`; square and custom dimensions are future scope.
- V1 stores one active video project per source content and format preset, with immutable internal versions and no visible version-history browser.
- V1 initial storyboard generation is deterministic from saved content and trusted assets; AI storyboard planning is future scope.
- V1 scene assets are trusted ContentGlowz content assets, durable Image Robot outputs, or `video_cover` records; arbitrary upload flows are future scope.
- Render capacity inherits the ready Remotion render service integration limits unless a later capacity spec changes them.

## Open Questions

None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 15:03:03 UTC | sf-spec | gpt-5.5 | Created draft spec for future Remotion video editor workflow from local code/spec evidence. | Draft saved; readiness blocked by open product/storage questions. | /sf-ready Remotion video editor workflow |
| 2026-05-11 15:38:45 UTC | sf-spec | GPT-5 Codex | Integrated product decisions for storyboard mode, editor entry, preview gate, V1 controls, and vertical-first multi-format support. | Draft updated; remaining blockers narrowed to route/storage/planner/assets/presets/capacity. | /sf-ready Remotion video editor workflow |
| 2026-05-11 15:58:47 UTC | sf-ready | GPT-5 Codex | Ran readiness gate, resolved remaining implementation-level gaps from existing product decisions and local constraints, checked fresh Remotion docs, and updated trace metadata. | ready | /sf-start Remotion video editor workflow |

## Current Chantier Flow

sf-spec ✅ -> sf-ready ✅ -> sf-start ⏳ -> sf-verify ⏳ -> sf-end ⏳ -> sf-ship ⏳
