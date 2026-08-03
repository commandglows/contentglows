---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "contentglowz"
created: "2026-05-12"
created_at: "2026-05-12 19:37:34 UTC"
updated: "2026-05-12"
updated_at: "2026-05-12 19:42:54 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlowz authentifiee dans l'editeur video d'un contenu, je veux appliquer des animations de scene guidees optimisees pour les reseaux sociaux, afin de produire des videos plus lisibles, rythmées et efficaces sans utiliser un studio d'animation artistique libre."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "worker"
  - "contentglowz/v0-ai-powered-animation-studio"
  - "contentglowz/remotion-template"
  - "Remotion video editor workflow"
  - "Unified Project Asset Library"
  - "AI audio/music/backgrounds"
  - "OpenRouter BYOK"
  - "Turso/libSQL"
  - "Clerk"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "contentglowz/INSPIRATION.md"
    artifact_version: "unknown"
    required_status: "inspiration-only"
  - artifact: "contentglowz/BUSINESS.md"
    artifact_version: "unknown"
    required_status: "inspiration-only"
  - artifact: "contentglowz/v0-ai-powered-animation-studio"
    artifact_version: "local prototype"
    required_status: "inspiration-only"
  - artifact: "contentglowz/remotion-template"
    artifact_version: "local prototype; Remotion dependencies ^4.0.0"
    required_status: "inspiration-only"
  - artifact: "Remotion interpolate docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "Remotion renderMedia docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "Remotion Composition docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
supersedes: []
evidence:
  - "User direction 2026-05-12: create a ShipGlowz spec for AI Animation / Motion Assistant for Remotion Scenes from contentglowz inspirations, not an implementation."
  - "User direction 2026-05-12: V1 must be integrated into existing guided workflows and future /editor/:id/video, not a global playground or free animation studio."
  - "User decision 2026-05-12: prefer effective social content over artistic animation work; motion should optimize readability, hook, retention and platform formats."
  - "Prior ready spec evidence: SPEC-remotion-video-editor-workflow-2026-05-11 defines /editor/:id/video, guided storyboard, immutable video versions, trusted assets, preview gate and Remotion render delegation."
  - "Prior ready spec evidence: SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11 adds procedural Remotion animated backgrounds, audio/music versioning and editor-linked guided controls."
  - "Prior ready spec evidence: SPEC-unified-project-asset-library-2026-05-11 defines project-scoped assets and workflow-guided reuse across images, audio, music, background configs and render outputs."
  - "Prototype evidence: contentglowz/v0-ai-powered-animation-studio/contexts/animation-context.tsx models layers with x, y, width, height, rotation, opacity, scaleX, scaleY and keyframes with easing."
  - "Prototype evidence: contentglowz/v0-ai-powered-animation-studio/components/animation-templates.tsx contains useful preset categories: entrance, emphasis, exit, motion and special."
  - "Prototype evidence: contentglowz/v0-ai-powered-animation-studio/components/ai-chat-panel.tsx uses prompt-like quick actions and tool-call-shaped mutations, but it is a standalone Next/Gemini demo and should not be ported as-is."
  - "Prototype evidence: contentglowz/v0-ai-powered-animation-studio/components/timeline-panel.tsx has a free keyframe timeline; V1 should only reuse simplified preview/keyframe concepts, not expose a full timeline."
  - "Prototype evidence: contentglowz/remotion-template/remotion/Root.tsx registers Remotion compositions and contentglowz/remotion-template/server/render-queue.ts uses selectComposition/renderMedia for server rendering."
  - "Code evidence: app/lib/router.dart currently exposes /editor/:id and sanitizes all /editor/* as /editor/:id; /editor/:id/video is not implemented yet."
  - "Code evidence: app/lib/presentation/screens/editor/editor_screen.dart already has editor-linked project asset access; future video/motion controls should remain editor-linked."
  - "Code evidence: lab/status/db.py and status/service.py already include project asset and usage tables/flows, including media kinds for video, video_cover, remotion_background and remotion_render."
  - "Fresh docs checked 2026-05-12: official Remotion interpolate docs support frame-based interpolation, easing and clamping for controlled animations."
  - "Fresh docs checked 2026-05-12: official Remotion renderMedia docs confirm programmatic video/audio rendering via @remotion/renderer."
  - "Fresh docs checked 2026-05-12: official Remotion Composition docs confirm composition-level id, duration, fps, dimensions, schema and defaultProps patterns."
next_step: "/sf-ready Remotion scene motion assistant"
---

## Title

Remotion Scene Motion Assistant

## Status

Draft. This spec frames a guided AI animation and motion assistant for ContentGlowz's future `/editor/:id/video` workflow. It intentionally does not implement a standalone animation studio and does not replace the ready Remotion video editor, audio/backgrounds, asset library, or render service specs.

## User Story

En tant que creatrice ContentGlowz authentifiee dans l'editeur video d'un contenu, je veux appliquer des animations de scene guidees optimisees pour les reseaux sociaux, afin de produire des videos plus lisibles, rythmées et efficaces sans utiliser un studio d'animation artistique libre.

## Minimal Behavior Contract

Depuis `/editor/:id/video`, ContentGlowz permet a une creatrice authentifiee d'appliquer a une scene, un texte, un asset visuel ou un fond anime des presets de mouvement allowlistes concus pour les contenus sociaux: accroche lisible, rythme clair, retention courte, focus sur le message et compatibilite verticale/landscape. Un assistant prompté peut proposer uniquement des changements de motion structurés et validés, sans chercher une direction artistique libre. Le systeme enregistre ces changements dans la version video courante, les convertit en props Remotion deterministes, invalide les previews/finals stale et exige une nouvelle preview avant rendu final. Si le prompt, la scene, l'asset, les keyframes, les droits, le worker ou la validation echouent, aucune mutation partielle incoherente n'est appliquee et l'utilisateur voit une erreur recuperable. Le cas facile a rater est de laisser l'IA ou le client ecrire une timeline libre ou des animations décoratives: V1 accepte des intentions et presets bornés qui servent l'efficacite sociale, pas du JSX, des URLs, du code, ni un studio global.

## Success Behavior

- Given une creatrice authentifiee ouvre un projet video owned dans `/editor/:id/video`, when elle selectionne une scene, un texte, une image, un groupe ou un background editable, then l'app affiche des presets de motion compatibles avec ce type de cible, le format courant et l'objectif social du contenu.
- Given un preset compatible est applique, when l'utilisateur sauvegarde, then le backend persiste une nouvelle version video avec un `motion_layer` ou `scene_motion` versionne, lie a la cible, au preset, aux parametres et aux keyframes normalisees.
- Given l'utilisateur decrit une intention comme "rendre l'accroche plus dynamique sans nuire a la lecture", when l'assistant est lance, then le backend utilise le runtime LLM autorise pour proposer une operation structurée issue d'une allowlist de presets et parametres orientés lisibilite, hook et retention, pas du code libre.
- Given une proposition IA est valide, when l'utilisateur applique la suggestion, then l'UI montre le delta lisible, applique les parametres bornés a la scene courante, preserve le texte et les assets, et marque la preview existante comme stale.
- Given une scene contient des mouvements de texte, d'image et de background, when une preview est demandee, then le backend transforme la version video en props Remotion schema-validees, et le worker rend les animations via interpolation/spring/easing deterministes.
- Given l'utilisateur modifie la duree d'une scene, when des keyframes existent deja, then le systeme conserve les motions compatibles ou demande un recalage explicite si les keyframes sortent des bornes.
- Given une preview Remotion de la version courante avec motion est terminee et validee par l'utilisateur, when le final render est lance, then le rendu final reference exactement la meme version video et les memes parametres de motion.
- Proof of success is a persisted video project version containing allowlisted motion configs, normalized keyframes, stale preview handling, Remotion preview/final output matching selected motion, and tests covering ownership, invalid prompts, incompatible targets, stale versions and render-safe props.

## Error Behavior

- Missing or invalid Clerk auth returns `401`; no motion suggestion, save, preview or final render is created.
- Foreign content, project, video project, scene, asset, background or version ids return ownership-safe `403` or `404` without leaking names, prompts, asset URLs, render ids or scene metadata.
- Unsupported target types, missing target ids, locked or deleted scenes/assets, incompatible media kinds, and stale video versions return typed validation errors and do not mutate the current video version.
- Prompted assistant output that contains unsupported preset ids, arbitrary code, raw CSS/JS, raw URLs, excessive keyframes, negative durations, off-canvas unsafe bounds, unsupported easing, or text/content changes outside motion scope is rejected before persistence.
- If OpenRouter BYOK or the approved LLM runtime is unavailable for prompt interpretation, manual presets and existing motion editing remain usable, but AI suggestion is disabled with a recoverable runtime error.
- If two saves race, optimistic concurrency blocks the stale write and preserves the newer version.
- If scene duration changes make existing keyframes invalid, final render stays blocked until the motion is normalized, dropped by explicit user action, or recalculated through a valid preset.
- If the Remotion worker cannot render the motion props, the job is marked failed with sanitized details and the video project remains editable.
- If a preview completes after a newer motion version exists, that preview is stale and cannot unlock final render.
- What must never happen: client-provided JSX or JavaScript enters Remotion, an LLM invents unvalidated timeline state, arbitrary media URLs are persisted, a stale preview unlocks final render, provider secrets or signed URLs appear in Flutter diagnostics, or global studio state crosses project boundaries.

## Problem

ContentGlowz has already framed the base Remotion video editor, AI audio/music/backgrounds and unified asset library. The remaining inspiration from `contentglowz/v0-ai-powered-animation-studio` is valuable but dangerous if copied directly: it is a standalone animation studio with layers, canvas, free timeline and AI chat. ContentGlowz needs the useful parts, namely presets, keyframes, prompt-assisted edits and animated scene composition, but only when they make social videos clearer, more rhythmic and more publishable inside the guided `/editor/:id/video` workflow.

## Solution

Add a scene motion layer to the video editor model and UI. V1 exposes curated social-performance motion presets and a prompt assistant that maps user intent to validated motion operations for existing scene targets, then renders them through the Remotion worker from server-owned versioned props. The product surface remains a guided scene editor for effective social content with preview-first export, not a separate animation playground or motion-design canvas.

## Scope In

- Add motion controls inside `/editor/:id/video` for the current video project and current scene.
- Support target scopes: whole scene, text layer, image/asset layer, shape/accent layer if the base video editor creates one, and procedural background config.
- Add allowlisted preset categories inspired by the prototype: `entrance`, `emphasis`, `exit`, `motion_path`, `background_motion`, and `timing_adjustment`.
- Add V1 presets such as readable hook reveal, slide/zoom in for titles, controlled emphasis pulse, subtle image pan/ken-burns, caption/highlight beat, CTA reveal, section transition, parallax depth and subtle background loop.
- Persist motion as structured data on immutable video project versions: target id, target type, preset id, parameters, normalized keyframes, easing, duration, offset, repeat policy, intensity and generated/edited provenance.
- Add a prompt assistant that proposes motion operations from scene context and a user instruction, with previewable diff before applying.
- Add social-effectiveness metadata to presets: intended use (`hook`, `caption`, `proof`, `transition`, `cta`, `background`), platform fit, readability risk, motion intensity and default duration.
- Use the existing BYOK/LLM policy for app-visible AI interpretation when a prompt must be understood; manual presets do not require LLM access.
- Add backend validation for target ownership, target compatibility, duration bounds, keyframe count, coordinate bounds, opacity/scale/rotation limits, easing allowlist and format-preset compatibility.
- Add a simplified motion timeline or keyframe inspector only where needed to explain and adjust V1 motion; it must not become a free multi-track timeline.
- Add Remotion worker support for motion props using deterministic frame-based interpolation/easing and safe clamping.
- Add support for animated scene backgrounds by reusing the procedural background direction from the audio/music/backgrounds spec and extending it with motion parameters.
- Invalidate preview/final readiness whenever motion changes for the current video version.
- Add tests for API, model validation, prompt tool output validation, UI state, stale versions and worker rendering.

## Scope Out

- A standalone AI Animation Studio, global studio route, public playground, landing page, or free canvas.
- Porting the Next.js prototype UI, Gemini route, React canvas reducer or free timeline as production code.
- Arbitrary layer creation unrelated to the saved video storyboard.
- Frame-accurate professional timeline, Bezier path editor, graph editor, dope sheet, nested compositions UI or After Effects parity.
- Lottie/Rive import, SVG path morphing, 3D/Three.js motion, custom user scripts, user-uploaded animation code, expressions or plugins.
- AI video generation for backgrounds; V1 uses Remotion procedural motion and trusted still assets.
- Creating or editing the base video project, audio, music, voiceover or asset library contracts already owned by other specs.
- Automatic social trend effect library, CapCut template marketplace, collaborative review, comments or public sharing.
- Artistic animation generation, abstract motion experiments, decorative effects unrelated to social-message clarity, or "make it beautiful" freeform prompt execution.
- Letting Flutter call the Remotion worker directly.
- Arbitrary media upload or URL import.
- Visible full version-history browser.

## Constraints

- Product hypothesis: the primary entry point is the existing/future content-scoped video editor at `/editor/:id/video`; this spec should not add a new app-shell navigation item.
- Product decision: V1 optimizes practical social content effectiveness: readability, hook, pacing, message focus and platform format fit. It does not optimize for artistic motion design, visual experimentation or portfolio-quality animation.
- Product hypothesis: V1 motion editing is scene-targeted and preset-led. A tiny timeline/keyframe inspector is acceptable only for transparency and bounded adjustments.
- Product hypothesis: AI assistance changes motion only; it must not rewrite scene text, select assets, generate images/audio, or alter publishing metadata unless a later spec expands the scope.
- This spec depends on the base Remotion video project model from `SPEC-remotion-video-editor-workflow-2026-05-11.md`; implement after that model exists.
- This spec depends on the audio/backgrounds spec only for procedural background concepts; it must not reimplement audio/music generation.
- This spec depends on the project asset library for selecting eligible images/background assets; motion props may reference asset ids only through backend-resolved descriptors.
- ContentGlowz app remains Flutter; backend remains FastAPI; durable state uses Turso/libSQL; auth uses Clerk.
- Flutter sends desired actions, preset ids and bounded parameter edits, not trusted final Remotion props.
- Backend remains the permission, validation, versioning and props-adapter boundary.
- Remotion receives only schema-validated motion descriptors and resolved asset descriptors.
- Motion generation and rendering are online-only and must not enter offline write queues.
- Provider/API keys, signed URLs, raw LLM prompts containing private content, and raw worker errors must be redacted from diagnostics.
- Respect existing route sanitizer expectations; `/editor/:id/video` needs a specific sanitized route before generic `/editor/*`.

## Dependencies

- Ready base editor spec: `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`.
- Ready audio/background extension spec: `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`.
- Ready asset library spec: `shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md`.
- Local inspiration only:
  - `contentglowz/v0-ai-powered-animation-studio/contexts/animation-context.tsx`
  - `contentglowz/v0-ai-powered-animation-studio/components/animation-templates.tsx`
  - `contentglowz/v0-ai-powered-animation-studio/components/ai-chat-panel.tsx`
  - `contentglowz/v0-ai-powered-animation-studio/components/timeline-panel.tsx`
  - `contentglowz/v0-ai-powered-animation-studio/components/animation-canvas.tsx`
  - `contentglowz/remotion-template/remotion/Root.tsx`
  - `contentglowz/remotion-template/server/render-queue.ts`
- Existing app files to integrate after base video editor exists:
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/data/models/project_asset.dart`
  - `app/lib/presentation/widgets/project_asset_picker.dart`
- Existing backend files to reuse:
  - `lab/status/schemas.py`
  - `lab/status/service.py`
  - `lab/api/dependencies/auth.py`
  - `lab/api/dependencies/ownership.py`
- Expected base video files from the prior specs:
  - `lab/api/models/videos.py` or the actual video model module created by the base editor implementation
  - `lab/api/services/video_project_store.py`
  - `lab/api/services/remotion_scene_props.py`
  - `lab/api/routers/videos.py`
  - `app/lib/data/models/video_project.dart`
  - `app/lib/presentation/screens/editor/video_editor_screen.dart`
  - `worker/src/schema/video-props.ts`
  - `worker/src/compositions/ContentGlowzSceneVideo.tsx`
- Fresh external docs checked:
  - `fresh-docs checked`: Remotion `interpolate()` docs at `https://www.remotion.dev/docs/interpolate`.
  - `fresh-docs checked`: Remotion `renderMedia()` docs at `https://www.remotion.dev/docs/renderer/render-media`.
  - `fresh-docs checked`: Remotion `<Composition>` docs at `https://www.remotion.dev/docs/composition`.

## Invariants

- Every motion config belongs to exactly one user, project, content, video project and immutable video version.
- A motion target must resolve to a scene element or background config already present in that video version.
- Motion configs are structured data, not executable code.
- Preset ids, easing values, repeat policies and target types are allowlisted.
- Keyframes are sorted, bounded by scene duration and capped by a server-defined maximum.
- Coordinates, scale, opacity, rotation and blur-like values are bounded to prevent unreadable, off-canvas or render-expensive output.
- Preset defaults must favor readable text, stable focal points and subtle motion over visual novelty.
- Motion changes always invalidate preview/final readiness for the current version.
- Final render requires a completed user-validated preview for the exact version containing the selected motion configs.
- Assistant output is advisory until user-applied and server-validated.
- Manual preset controls must remain usable without LLM availability.
- The product remains content-scoped and project-scoped; no global animation library state is shared across users or projects.

## Links & Consequences

- `SPEC-remotion-video-editor-workflow-2026-05-11.md` must be implemented first because this spec extends scene/version state rather than creating it.
- `SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md` should own audio/music and base procedural backgrounds; this spec owns motion parameters and assistant operations for scenes/backgrounds.
- `SPEC-unified-project-asset-library-2026-05-11.md` remains the asset discovery/reuse boundary; this spec only references eligible assets through video scene targets.
- `app/lib/router.dart` needs a `/editor/:id/video` route and sanitizer before generic editor sanitization when the base editor ships.
- `app/lib/presentation/screens/editor/video_editor_screen.dart` should host the motion controls; avoid a parallel `AnimationStudioScreen`.
- `lab/api/routers/videos.py` should expose motion endpoints beside other video project actions after the base video router exists.
- `lab/api/services/remotion_scene_props.py` or equivalent needs to include motion props in version-to-worker adaptation.
- `worker` currently does not exist in this checkout; implementation must create or use the worker package from prior specs, not silently put render logic in Flutter.
- Analytics/observability should distinguish preset apply, AI suggestion requested, suggestion applied, motion validation failure, motion preview render and motion render failure.

## Documentation Coherence

- Update `app/README.md` after implementation with the editor-linked motion assistant, online-only AI suggestion caveat and preview-first workflow.
- Update `lab/README.md` or API docs with motion endpoints, validation limits, versioning, BYOK behavior and redaction rules.
- Update `worker/README.md` with motion prop schema, supported presets, sample props, local render smoke commands and known render limits.
- Update product/support docs to say this is guided scene motion, not a standalone animation studio.
- Add changelog entries for manual motion presets, AI motion suggestions, stale preview handling and Remotion render support.
- Do not document the contentglowz prototype as production behavior.

## Edge Cases

- Video project does not exist yet for the content.
- Base video editor exists but worker package is not yet implemented locally.
- Scene has zero duration or a duration shorter than the selected preset.
- Text is too long and animated reveal makes it overflow.
- Motion target was deleted after the assistant suggestion was generated.
- Asset was tombstoned or made ineligible after a motion was configured.
- Background motion lowers contrast or creates excessive motion behind text.
- Vertical preset works but landscape crops the motion path.
- User changes scene duration after applying keyframes.
- User applies an exit animation that ends before required scene content is readable.
- Two browser tabs apply different motion edits to the same version.
- AI assistant proposes a valid preset but with invalid intensity/duration bounds.
- AI assistant returns a target id from stale UI context.
- User asks for impossible or out-of-scope changes such as "animate this as 3D particles".
- Render worker supports a preset in vertical but not in landscape.
- Preview job completes after a newer motion version is saved.
- Signed preview URL expires during review.
- User changes active project while suggestion, save or polling is in flight.
- Reduced-motion/accessibility settings need a future product decision; V1 should keep motion intensity conservative by default.

## Implementation Tasks

- [ ] Task 1: Confirm base video editor implementation boundary
  - Fichier : `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - Action : Read the ready base editor spec and identify the actual implemented file names for video models, store, router, props adapter, Flutter screen and Remotion worker before coding.
  - User story link : Prevents building a standalone animation studio instead of extending the content-scoped video editor.
  - Depends on : Base video editor implementation available.
  - Validate with : Implementation notes list actual target files and confirm `/editor/:id/video` is the host surface.
  - Notes : Stop and reroute if the base video project model does not exist yet.

- [ ] Task 2: Add video motion domain models
  - Fichier : `lab/api/models/videos.py`
  - Action : Add typed Pydantic models/enums for `VideoMotionTarget`, `VideoMotionPreset`, `VideoMotionKeyframe`, `VideoMotionConfig`, `VideoMotionSuggestion`, `VideoMotionApplyRequest`, easing, repeat policy, bounds and provenance.
  - User story link : Defines the structured contract that replaces free timeline/code edits.
  - Depends on : Task 1.
  - Validate with : Model tests for valid presets, invalid target type, unsorted keyframes, unsupported easing, too many keyframes and invalid bounds.
  - Notes : If the base editor uses a different model module, update that module instead of creating a parallel videos model.

- [ ] Task 3: Persist motion configs on immutable video versions
  - Fichier : `lab/api/services/video_project_store.py`
  - Action : Extend video version persistence to store motion configs and create new versions on motion save with optimistic concurrency.
  - User story link : Makes motion edits reloadable, version-safe and preview-gated.
  - Depends on : Task 2.
  - Validate with : Store tests for apply preset, replace config, delete config, stale write conflict, version immutability and current-version retrieval.
  - Notes : Do not store motion inside transient render job metadata.

- [ ] Task 4: Add motion preset registry and validation service
  - Fichier : `lab/api/services/video_motion_presets.py`
  - Action : Implement allowlisted presets, target compatibility, parameter schemas, default values, min/max bounds, format compatibility and keyframe normalization.
  - User story link : Gives users useful animations without exposing arbitrary timeline editing.
  - Depends on : Task 2.
  - Validate with : Unit tests for each V1 preset category, incompatible targets, duration normalization, landscape/vertical compatibility and conservative defaults.
  - Notes : Use prototype presets as inspiration, but translate them into ContentGlowz scene targets.

- [ ] Task 5: Add AI motion suggestion service
  - Fichier : `lab/api/services/video_motion_assistant.py`
  - Action : Map user prompts plus scene context to structured allowlisted motion operations through the approved app-visible LLM runtime, returning a previewable diff and no direct mutation.
  - User story link : Lets creators describe motion in natural language while keeping output bounded.
  - Depends on : Tasks 2 and 4, plus existing BYOK/LLM runtime.
  - Validate with : Tests for missing BYOK, unsupported prompt, stale target, valid prompt-to-preset mapping, output schema enforcement and no operator-key fallback.
  - Notes : Manual presets must not depend on this service.

- [ ] Task 6: Add motion API endpoints
  - Fichier : `lab/api/routers/videos.py`
  - Action : Add authenticated endpoints to list presets for a scene/target, request an AI suggestion, apply a preset/suggestion, update bounded parameters, delete motion config and mark preview stale.
  - User story link : Exposes guided motion controls to Flutter through the backend boundary.
  - Depends on : Tasks 3-5.
  - Validate with : Router tests for 401, 403/404, foreign video/project/scene/asset denial, stale version conflict, prompt errors, apply success and delete success.
  - Notes : Keep routes under the video project API family, not a new global animation API.

- [ ] Task 7: Extend scene-to-Remotion props adapter
  - Fichier : `lab/api/services/remotion_scene_props.py`
  - Action : Include normalized motion configs in render props, resolve targets, clamp values, reject invalid configs and preserve stale preview/final gating.
  - User story link : Ensures Remotion renders the saved motion version exactly.
  - Depends on : Tasks 3-6.
  - Validate with : Adapter tests for target resolution, deleted target, invalid keyframes, props size, asset descriptor safety and exact version id.
  - Notes : Flutter must not submit final worker props.

- [ ] Task 8: Add Remotion motion schema
  - Fichier : `worker/src/schema/video-props.ts`
  - Action : Add TypeScript schema/types for motion targets, presets, keyframes, easing, repeat policy and background motion parameters.
  - User story link : Lets the worker reject unsafe or malformed motion props before rendering.
  - Depends on : Worker package from base Remotion specs and Task 7 contract.
  - Validate with : TypeScript schema tests or build checks for valid/invalid motion props.
  - Notes : If the worker path differs when implemented, use the actual schema file.

- [ ] Task 9: Render motion in the Remotion scene composition
  - Fichier : `worker/src/compositions/ContentGlowzSceneVideo.tsx`
  - Action : Implement deterministic motion rendering for V1 presets using Remotion frame APIs, interpolation/easing, clamping, scene-relative timing and background motion loops.
  - User story link : Produces the visible animated result in preview and final export.
  - Depends on : Task 8.
  - Validate with : Worker smoke renders for vertical and landscape sample props covering text entrance, image pan, pulse, background loop and invalid fallback.
  - Notes : Do not execute dynamic code from props.

- [ ] Task 10: Add Flutter motion models and API methods
  - Fichier : `app/lib/data/models/video_motion.dart`
  - Action : Add Dart models for motion presets, targets, configs, suggestions, keyframes, validation errors and stale preview states; add matching ApiService calls.
  - User story link : Gives the app a typed contract for motion controls.
  - Depends on : Task 6.
  - Validate with : Dart model/API tests for JSON parsing, unknown enum fallback, error mapping and signed URL/prompt redaction.
  - Notes : Keep models separate from project asset models but reference asset ids where needed.

- [ ] Task 11: Add Flutter motion state controller
  - Fichier : `app/lib/providers/providers.dart`
  - Action : Add provider/notifier state for selected scene target, compatible presets, active suggestion, applying edits, stale response rejection and preview invalidation.
  - User story link : Keeps motion edits coherent during async suggestions and saves.
  - Depends on : Task 10.
  - Validate with : Provider tests for load presets, suggest, apply, delete, active project switch, route disposal and stale version conflict.
  - Notes : Move to a dedicated provider file if local patterns prefer it by implementation time.

- [ ] Task 12: Add guided motion UI inside the video editor
  - Fichier : `app/lib/presentation/screens/editor/video_editor_screen.dart`
  - Action : Add a compact motion panel for selected scene/target with preset categories, parameter controls, AI prompt suggestion, diff preview, apply/delete actions, preview stale warnings and mobile-friendly layout.
  - User story link : Lets creators animate scenes without leaving the guided editor.
  - Depends on : Tasks 10-11 and base video editor UI.
  - Validate with : Widget tests for no target, compatible presets, prompt loading/error/success, apply, delete, stale preview warning and narrow layout.
  - Notes : Do not create `AnimationStudioScreen` or expose a free canvas.

- [ ] Task 13: Add simplified keyframe inspector if needed
  - Fichier : `app/lib/presentation/screens/editor/video_motion_keyframes.dart`
  - Action : Add a bounded inspector for generated keyframes with time, property and easing display plus limited edits allowed by the preset schema.
  - User story link : Provides transparency and minor adjustments without a full timeline.
  - Depends on : Task 12.
  - Validate with : Widget tests for keyframe bounds, invalid time rejection, long text labels and no layout overflow.
  - Notes : Skip this task if preset parameter controls are sufficient for V1; do not replace it with a free timeline.

- [ ] Task 14: Wire route and editor entrypoint safeguards
  - Fichier : `app/lib/router.dart`
  - Action : Ensure `/editor/:id/video` remains the only app route for this feature and sanitize it distinctly before generic `/editor/*`.
  - User story link : Keeps the motion assistant attached to content-scoped video editing.
  - Depends on : Base video route and Task 12.
  - Validate with : Router tests for `/editor/:id/video`, Sentry route naming and absence of global animation route.
  - Notes : If this was already handled by the base video editor implementation, add regression tests only.

- [ ] Task 15: Add docs and sample fixtures
  - Fichier : `worker/README.md`
  - Action : Document supported motion presets, prop schema, sample fixture JSON, local preview/final render commands, validation limits and troubleshooting.
  - User story link : Makes implementation and support repeatable.
  - Depends on : Tasks 8-9.
  - Validate with : Docs review plus worker sample render command verified by implementation.
  - Notes : Also update app/lab READMEs and changelog as listed in Documentation Coherence.

## Acceptance Criteria

- [ ] CA 1: Given an owned video project at `/editor/:id/video`, when a scene target is selected, then compatible social-purpose motion presets are shown and no global animation studio route is needed.
- [ ] CA 2: Given a text target, when the user applies `slide_in` with valid parameters, then the backend persists a new video version with a normalized motion config and marks preview/final stale.
- [ ] CA 3: Given an image target, when the user applies a pan or ken-burns preset, then the preview renders that motion from server-validated props without raw client URLs.
- [ ] CA 4: Given a procedural background target, when a background loop preset is applied, then Remotion renders bounded background motion in vertical and landscape formats.
- [ ] CA 5: Given a prompt requiring AI interpretation, when BYOK/runtime is missing, then AI suggestion fails with a structured recoverable error while manual presets remain usable.
- [ ] CA 6: Given a valid prompt like "rendre l'accroche plus dynamique sans perdre la lecture", when AI suggestion succeeds, then the returned operation uses allowlisted social-purpose preset ids and parameters and is not persisted until user apply.
- [ ] CA 7: Given AI output contains unsupported code, raw URL, unknown target, unknown easing or excessive keyframes, when validation runs, then the backend rejects it and does not mutate the video version.
- [ ] CA 8: Given a foreign scene, video project, content, project or asset id, when motion actions are requested, then the API returns ownership-safe denial and no suggestion/render job is created.
- [ ] CA 9: Given two tabs edit motion concurrently, when the stale tab saves, then the backend returns conflict and preserves the newer version.
- [ ] CA 10: Given scene duration changes after keyframes exist, when final render is requested, then backend blocks until motion is normalized or explicitly removed.
- [ ] CA 11: Given preview for version N completes and motion version N+1 is saved, when final render is requested, then final render is blocked until version N+1 has a validated preview.
- [ ] CA 12: Given worker rendering fails for motion props, when status is polled, then the job is failed with sanitized details and the project remains editable.
- [ ] CA 13: Given active project changes while suggestion/save/polling is in flight, when responses arrive, then Flutter ignores stale responses and clears context-specific motion state.
- [ ] CA 14: Given diagnostics capture a motion error, when logs are reviewed, then no provider secrets, signed URL tokens, raw worker stack with internal paths, or raw private prompt payload are exposed.
- [ ] CA 15: Given implementation ships, when docs and navigation are reviewed, then the feature is described as guided scene motion inside the video editor, not as a free AI animation studio.
- [ ] CA 16: Given a motion preset would reduce text readability, push the focal subject off-screen, over-animate the background or distract from the hook/CTA, when validation runs, then the backend rejects or normalizes it before preview/final render.

## Test Strategy

- Backend model tests for motion target, preset, keyframe, easing, bounds, provenance and suggestion payload validation.
- Backend service tests for preset compatibility, parameter normalization, duration/keyframe clamping, version persistence and optimistic concurrency.
- Backend assistant tests with mocked LLM runtime for missing BYOK, valid prompt mapping, unsupported prompt, malformed output and no operator-key fallback.
- Backend router tests for Clerk auth, ownership, foreign resource denial, stale version conflict, apply/delete success and typed errors.
- Props adapter tests for exact version id, target resolution, deleted target, asset safety, props size and stale preview prevention.
- Remotion worker schema/build tests for valid/invalid motion props.
- Remotion smoke renders for `vertical_9_16` and `landscape_16_9` using fixture props with text, image and background motion.
- Flutter model tests for parsing, unknown enums and typed error mapping.
- Flutter provider tests for presets, suggestion, apply, delete, route disposal, stale responses and active project changes.
- Flutter widget tests for compact motion panel, prompt flow, keyframe inspector if present, narrow layout, long labels and stale preview warning.
- Manual QA: open `/editor/:id/video`, select a scene, apply preset, request AI suggestion, apply suggestion, preview, edit duration to force invalidation, normalize, preview current version, validate preview and final render.

## Risks

- High product risk: copying the prototype too literally would create a standalone studio and violate the guided workflow direction.
- High product risk: optimizing for artistic animation instead of social effectiveness would make the feature slower, harder to use and less aligned with ContentGlowz's publishing value.
- High security risk: accepting arbitrary animation code, raw URLs or LLM-generated props could leak data or compromise render safety.
- High dependency risk: this chantier depends on the base video editor and worker being implemented first.
- Medium UX risk: even bounded keyframes can make mobile editing dense; V1 should default to presets and simple parameters.
- Medium render risk: motion configs may increase render time or fail in one format; worker fixtures and capacity limits are required.
- Medium accessibility risk: excessive motion can hurt readability or comfort; defaults should be subtle and future reduced-motion policy may need a separate product decision.
- Medium data risk: stale preview/final gating becomes more complex when small motion edits create new video versions.

## Execution Notes

- Read first:
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md`
  - `contentglowz/v0-ai-powered-animation-studio/contexts/animation-context.tsx`
  - `contentglowz/v0-ai-powered-animation-studio/components/animation-templates.tsx`
  - `contentglowz/v0-ai-powered-animation-studio/components/ai-chat-panel.tsx`
  - `contentglowz/remotion-template/remotion/Root.tsx`
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `lab/status/service.py`
- Implementation order: backend models and preset registry, persistence/versioning, AI suggestion service, video router endpoints, props adapter, worker schema/rendering, Flutter models/providers/UI, route safeguards, docs.
- Fresh external docs verdict: `fresh-docs checked` for Remotion interpolation, composition and programmatic rendering. Re-check official Remotion docs during implementation if the actual worker version differs materially from the local prototype's Remotion `^4.0.0`.
- Use Remotion frame-based primitives and schema-validated props. Do not introduce a custom render engine or dynamic code execution.
- Use existing ContentGlowz BYOK/app-visible LLM constraints for prompt interpretation. If BYOK foundations are unavailable, ship manual presets first and block AI suggestions.
- Stop and reroute if implementation requires free timeline editing, arbitrary layer creation, Lottie/Rive import, AI video backgrounds, 3D motion, custom scripts, public animation templates, cross-project animation libraries or artistic/freeform motion generation.
- Stop and ask the user if reduced-motion policy, visible version history for animation revisions, a trend/effects marketplace, or square/custom format support becomes necessary.
- Suggested validation commands after implementation:
  - `python3 -m pytest lab/tests/test_video_motion*.py lab/tests/test_video_router*.py`
  - `flutter test app/test/data/video_motion_test.dart app/test/providers/video_motion_provider_test.dart app/test/presentation/video_motion_panel_test.dart`
  - worker build and sample render command documented in `worker/README.md`

## Open Questions

None blocking for the draft. Product decisions confirmed: V1 remains preset-led inside `/editor/:id/video`; motion optimizes effective social content rather than artistic animation; AI suggestions modify motion only; a simplified keyframe inspector is acceptable only if bounded. Product assumptions to confirm during `/sf-ready`: reduced-motion accessibility defaults can be conservative in V1 without a full preference system.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-12 19:37:34 UTC | sf-spec | GPT-5 Codex | Created draft spec for guided AI motion assistant from contentglowz animation/remotion inspirations, existing Remotion editor/audio/background/asset specs, local code scan and official Remotion docs freshness check. | Draft saved. | /sf-ready Remotion scene motion assistant |
| 2026-05-12 19:42:54 UTC | sf-spec | GPT-5 Codex | Integrated product decision that motion should optimize social content effectiveness, not artistic animation. | Draft updated. | /sf-ready Remotion scene motion assistant |

## Current Chantier Flow

- sf-spec: done
- sf-ready: not launched
- sf-start: not launched
- sf-verify: not launched
- sf-end: not launched
- sf-ship: not launched

Prochaine commande: `/sf-ready Remotion scene motion assistant`
