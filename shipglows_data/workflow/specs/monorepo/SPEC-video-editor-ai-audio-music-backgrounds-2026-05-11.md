---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-11"
created_at: "2026-05-11 16:55:05 UTC"
updated: "2026-05-11"
updated_at: "2026-05-11 17:09:43 UTC"
status: ready
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "medium"
user_story: "En tant que creatrice ContentGlowz authentifiee, je veux ajouter narration multi-speaker, musique et fonds animes guides dans l'editeur video Remotion du contenu courant, afin de produire des videos plus riches sans quitter le workflow editor."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "worker"
  - "contentglowz/v0-eleven-labs-v3-podcast-generator"
  - "contentglowz/v0-eleven-labs-music-starter"
  - "Remotion video editor workflow"
  - "OpenRouter BYOK"
  - "ElevenLabs"
  - "Bunny Storage/CDN"
  - "Turso/libSQL"
  - "Clerk"
  - "AI Generation Quotas/Billing"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "OpenRouter Audio docs"
    artifact_version: "2026-05-11"
    required_status: "official"
  - artifact: "OpenRouter Text-to-Speech docs"
    artifact_version: "2026-05-11"
    required_status: "official"
  - artifact: "ElevenLabs Text to Dialogue docs"
    artifact_version: "2026-05-11"
    required_status: "official"
  - artifact: "ElevenLabs Text to Speech docs"
    artifact_version: "2026-05-11"
    required_status: "official"
  - artifact: "ElevenLabs Music docs and Music Terms"
    artifact_version: "2026-05-11"
    required_status: "official"
supersedes: []
evidence:
  - "User clarification 2026-05-11: do not create a separate podcast feature; improve the existing video editor with podcast/audio ideas."
  - "User decision 2026-05-11: V1 scope includes multi-speaker narration and music."
  - "User decision 2026-05-11: limit the number of services and research whether OpenRouter or equivalent can cover audio."
  - "User decision 2026-05-11: V1 uses predefined/admin-configured voices; no voice cloning or user voice upload by default."
  - "User decision 2026-05-11: UI remains linked to the editor and may expand if mobile video editing becomes too dense."
  - "User decision 2026-05-11: guided formats are desirable."
  - "User decision 2026-05-11: add an animated-background generator for scene backgrounds."
  - "Code evidence: app/lib/router.dart exposes /editor/:id and existing Remotion spec expects /editor/:id/video."
  - "Code evidence: app/lib/presentation/screens/editor/editor_screen.dart is the current content editor surface."
  - "Code evidence: lab/api/routers/status.py and status/service.py already support content asset metadata with kind, mime_type, duration_ms, storage_uri and metadata."
  - "Code evidence: lab/api/services/job_store.py stores async job state, but current jobs table is not the scene/audio source of truth."
  - "Code evidence: lab/api/services/feedback_storage.py already uploads and plays audio via Bunny Storage with signed tokens, but is feedback-specific and not content-asset-safe."
  - "Prototype evidence: contentglowz/v0-eleven-labs-v3-podcast-generator shows script generation and ElevenLabs text-to-dialogue ideas, but the implementation is Next/Supabase and logs unsafe diagnostics."
  - "Prototype evidence: contentglowz/v0-eleven-labs-music-starter shows ElevenLabs music plan/compose ideas, but the implementation is Next route code and not production stack compatible."
  - "Fresh docs checked 2026-05-11: OpenRouter supports audio input/output and a dedicated TTS endpoint, but current docs do not show music composition or text-to-dialogue endpoints equivalent to ElevenLabs Music and Text to Dialogue."
  - "Fresh docs checked 2026-05-11: ElevenLabs Text to Dialogue accepts speaker text/voice-id pairs and recommends keeping total input text at or below 2000 characters for reliable generation."
  - "Fresh docs checked 2026-05-11: ElevenLabs Music supports composition plans and text-to-music composition, with Music Terms prohibiting artist names, song titles, label names and substantial lyric references."
next_step: "/sf-start Video editor AI audio, music, and animated backgrounds"
---

## Title

Video Editor AI Audio, Music, And Animated Backgrounds

## Status

Ready. This spec extends the ready Remotion video editor workflow with guided AI audio, multi-speaker narration, music and animated scene backgrounds. It is not a standalone podcast studio and does not change the app stack. It reuses the current ContentGlowz platform: Flutter app, FastAPI backend, Clerk auth, Turso/libSQL persistence, Bunny storage/CDN, OpenRouter BYOK for script/planning where applicable, and a single managed audio provider for features OpenRouter does not cover completely.

## User Story

En tant que creatrice ContentGlowz authentifiee, je veux ajouter narration multi-speaker, musique et fonds animes guides dans l'editeur video Remotion du contenu courant, afin de produire des videos plus riches sans quitter le workflow editor.

## Minimal Behavior Contract

Depuis `/editor/:id/video`, ContentGlowz permet a une creatrice authentifiee de generer ou modifier des pistes audio guidees pour la version video courante: narration solo ou multi-speaker, musique de fond courte, et fonds animes de scene. Le systeme part du contenu, du storyboard, des scenes et des formats choisis; il planifie les scripts via le runtime LLM utilisateur quand du texte structure est necessaire, rend l'audio avec un provider audio gere cote backend, stocke les fichiers durables dans Bunny, attache les assets au projet video et a la version concernee, puis passe uniquement des references serveur validees au worker Remotion. En cas d'echec de provider, quota, stockage, validation, version stale ou rendu Remotion, la derniere version coherente reste intacte et l'utilisateur voit une erreur recuperable. Le cas facile a rater est de transformer ce chantier en studio audio libre: V1 doit rester guide par les formats video, les scenes et les presets, pas par un playground de voix/musique.

## Success Behavior

- Given une creatrice ouvre un projet video owned depuis `/editor/:id/video`, when elle active l'onglet audio, then l'app affiche les formats audio guides disponibles pour cette video: `solo_narration`, `two_speakers`, `interview_style`, `voiceover_with_music`, et `music_bed_only`.
- Given un format audio guide est choisi, when la creatrice lance la generation, then le backend cree un job asynchrone owner-scoped lie a `video_project_id`, `video_version_id`, `content_id`, `project_id`, `user_id`, `format_preset`, `audio_format`, scenes ciblees, provider, voix choisies et reservation de quota.
- Given le format demande un script, when la generation commence, then le backend utilise OpenRouter BYOK selon la spec stricte BYOK pour produire une structure de script ou de dialogue, sans utiliser de cle LLM operateur pour du texte app-visible.
- Given la narration multi-speaker est generee, when le provider audio reussit, then le fichier audio final est uploade dans Bunny avec metadata durable: `source=video_audio_ai`, `kind=audio`, `mime_type`, `duration_ms`, `provider`, `model`, `voice_ids`, `script_version_hash`, `job_id`, `video_project_id`, `video_version_id`, et `placement`.
- Given une musique de fond est generee, when elle est acceptee par le provider et stockee, then elle devient un asset candidat avec metadata de droits, prompt nettoye, duree, force instrumental si applicable, provider song id si disponible, et statut `candidate`, pas automatiquement publiee.
- Given un fond anime est genere, when l'utilisateur choisit un preset guide, then le systeme cree une configuration Remotion procedurale versionnee pour la scene ou le projet, sans appeler un provider video externe en V1.
- Given la creatrice valide un asset audio ou background pour une version video, when elle sauvegarde, then la version video courante reference ces assets par identifiants serveur et invalide toute preview/final render stale.
- Given une preview Remotion est demandee, when la version video contient narration, musique ou background, then le backend resolv les URLs Bunny signees ou render-safe, les passe dans des props Remotion validees, et le worker rend la preview avec mix audio, volume et timing attendus.
- Given la preview courante avec audio/background est validee par l'utilisateur, when final render est lance, then le final render reference exactement la meme version video et les memes assets valides.
- Proof of success is a video project version containing scene data, audio tracks, music track and animated background config, Bunny-backed audio assets, normalized job status, quota ledger events, and a Remotion preview/final render that includes the chosen audio/background without arbitrary client URLs.

## Error Behavior

- Missing or invalid Clerk auth returns `401`; no planning, provider call, storage write, asset attach or render job is created.
- A video project, content record, asset or job outside the current user's owned projects returns `403` or `404` without leaking names, prompts, voice ids, provider request ids or artifact URLs.
- Missing OpenRouter BYOK state for script/planning returns the existing structured BYOK error before script generation; it does not block using an already-approved script if no new LLM call is required.
- Insufficient managed audio/PAYG quota hard-blocks before any managed audio provider call.
- If the audio provider key/config is missing, invalid, rate-limited, unavailable or rejects input, the job becomes `failed` with a sanitized error code and no fake asset is attached.
- If ElevenLabs text-to-dialogue input would exceed the reliable per-request limit, the backend must chunk, reduce, or reject with a recoverable `audio_script_too_long` error before provider submission; it must not rely on provider truncation.
- If generated music prompt contains prohibited inputs such as artist names, song titles, label names or substantial lyric references, the backend rejects or sanitizes before provider call and records `music_policy_blocked`.
- If Bunny upload fails after provider success, the audio/music asset is not marked usable; user-facing usage is released/refunded according to the quota spec.
- If an audio asset duration does not match scene timing beyond allowed tolerance, the UI shows an adjustment state and preview remains disabled until the mismatch is resolved or accepted through a defined trim/fade policy.
- If the user edits scenes after audio generation, linked audio becomes stale until explicitly reattached, regenerated or accepted for the new version.
- If animated background config is malformed, unsupported, too expensive to render, or incompatible with format preset, the backend rejects that version and keeps the previous valid background.
- What must never happen: voice cloning without an explicit future spec, user-uploaded voice samples in V1, provider secrets in Flutter, raw provider responses in logs, arbitrary audio URLs in Remotion props, direct client control of provider/model pricing fields, music prompts referencing protected artists/songs, or final render from stale audio/background assets.

## Problem

The ready Remotion video editor spec intentionally left audio, voiceover, music and subtitles out of scope. The `contentglowz` podcast and music prototypes show useful ideas, but they are separate Next/Supabase demos and would create the wrong product surface if copied directly. The product direction is now clearer: the audio ideas should enrich the existing editor-linked video workflow, not become a new podcast generator or global studio.

## Solution

Extend the Remotion video editor with a guided media layer for AI audio and animated backgrounds. Use OpenRouter BYOK only where it fits the existing app-visible LLM policy, mainly for structured scripts and format planning. Use a single direct managed audio provider for V1 rendering of multi-speaker dialogue and music, because current OpenRouter docs cover TTS and audio modalities but not the complete text-to-dialogue plus music composition contract. Generate animated backgrounds as Remotion procedural scene configs in V1 to avoid adding a separate AI video provider.

## Scope In

- Add video-editor audio controls under `/editor/:id/video`, not a standalone podcast/audio studio.
- Add guided audio formats: `solo_narration`, `two_speakers`, `interview_style`, `voiceover_with_music`, `music_bed_only`.
- Add admin-configured voice presets and project-safe voice selection. V1 does not support user voice cloning or voice uploads.
- Generate or reuse structured scripts/dialogue from source content, storyboard scenes, project voice/style and selected format.
- Use OpenRouter BYOK for script, dialogue plan and prompt normalization when an app-visible LLM call is needed.
- Use direct managed ElevenLabs provider integration for V1 audio rendering where current docs support text-to-speech, text-to-dialogue and music composition.
- Support multi-speaker narration with scene/segment mapping, voice assignment, per-segment text, duration target, and provider character-cost metadata.
- Support music bed generation with short guided prompts, duration target, instrumental preference, policy checks, and candidate approval.
- Store generated audio/music as Bunny-backed content/video assets with `source=video_audio_ai` and server-owned metadata.
- Add audio job history and status polling scoped to user/project/content/video version.
- Add versioned references from video project versions to audio tracks, music tracks and animated background configs.
- Add scene-level background generator using Remotion procedural templates, not external video generation in V1.
- Add Remotion worker support for audio mixing, scene audio alignment, volume, fades, loop/trim policy and animated background rendering from validated props.
- Add quota/PAYG reservation/release/consume integration for managed audio/music calls.
- Add tests for ownership, BYOK planning, provider error mapping, quota hard-block, policy rejection, Bunny upload failure, stale version handling, Remotion prop validation and UI state.

## Scope Out

- A standalone global podcast studio, audio studio, or free-form playground.
- Porting Next.js, Supabase, Vercel or React code from `contentglowz`.
- Replacing Flutter, FastAPI, Clerk, Turso, Bunny or Remotion.
- User voice cloning, voice upload, professional voice clone management or voice consent workflows.
- Dubbing uploaded videos, speech-to-speech voice conversion, voice isolation or speech-to-text editing.
- Full waveform editor, frame-accurate audio timeline, DAW-like mixing or multi-track professional audio suite.
- Publishing podcasts to Spotify/Apple Podcasts/RSS.
- Direct social publishing of audio-only assets.
- AI video generation for animated backgrounds. V1 backgrounds are Remotion procedural configs or use trusted still assets with motion.
- Full music marketplace, lyric editor, inpainting, finetuning, custom sonic identity or copyright/legal guarantee.
- Exact public pricing, checkout, invoices, taxes and credit packs; quota enforcement hooks depend on the existing quotas/billing spec.
- Captions/subtitles unless a later caption/transcription spec adds them.

## Constraints

- The public app stays Flutter and consumes FastAPI only.
- The backend owns provider calls, Bunny upload, asset metadata, job state, quota enforcement and ownership checks.
- App-visible script/planning LLM calls must use the user's OpenRouter BYOK runtime and follow `SPEC-strict-byok-llm-app-visible-ai.md`.
- Managed audio rendering is backend-paid/PAYG and must obey `SPEC-ai-generation-quotas-billing-2026-05-11.md`.
- Provider strategy V1: direct ElevenLabs for multi-speaker dialogue and music; OpenRouter is not treated as the complete audio provider for this feature.
- No provider key, provider polling URL, raw audio bytes, Bunny AccessKey, signed URL token, or raw prompt rejection detail may be logged to Flutter diagnostics.
- All audio and background assets must be tied to `user_id`, `project_id`, `content_id`, `video_project_id`, and immutable `video_version_id`.
- Audio assets are usable by Remotion only after Bunny upload succeeds and the backend marks them durable.
- Client requests must pass server identifiers and guided choices, not raw media URLs or arbitrary provider/model ids.
- Music prompt policy checks are required before provider submission.
- Animated backgrounds must be generated from allowlisted Remotion templates and bounded parameter schemas.
- Video preview/final render remains online-only and must not enter the offline write queue.
- Final render requires user-validated preview for the exact version containing the selected audio/music/background assets.

## Dependencies

- Ready Remotion editor foundation: `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`.
- Ready render service foundation: `shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md`.
- Ready visual assets UI: `shipglows_data/workflow/specs/app/SPEC-editor-linked-ai-visuals-ui-2026-05-11.md`.
- Ready quotas/billing foundation: `shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md`.
- Ready BYOK foundation: `shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md`.
- Existing app files:
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/data/services/api_service.dart`
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/screens/feedback/feedback_admin_screen.dart` for existing `audioplayers` usage reference.
- Existing backend files:
  - `lab/api/services/user_llm_service.py`
  - `lab/api/services/pydantic_ai_runtime.py`
  - `lab/api/services/job_store.py`
  - `lab/api/services/feedback_storage.py`
  - `lab/api/routers/status.py`
  - `lab/status/service.py`
  - `lab/api/dependencies/auth.py`
  - `lab/api/dependencies/ownership.py`
  - `lab/api/main.py`
  - `lab/api/routers/__init__.py`
- Inspiration-only prototype files:
  - `contentglowz/v0-eleven-labs-v3-podcast-generator/app/api/generate-script/route.ts`
  - `contentglowz/v0-eleven-labs-v3-podcast-generator/app/api/generate-podcast/route.ts`
  - `contentglowz/v0-eleven-labs-music-starter/app/api/music/plan/route.ts`
  - `contentglowz/v0-eleven-labs-music-starter/app/api/music/compose/route.ts`
- Fresh external docs checked:
  - `fresh-docs checked`: OpenRouter Audio docs at `https://openrouter.ai/docs/guides/overview/multimodal/audio`.
  - `fresh-docs checked`: OpenRouter Multimodal overview at `https://openrouter.ai/docs/guides/overview/multimodal/overview`.
  - `fresh-docs checked`: OpenRouter TTS endpoint at `https://openrouter.ai/docs/api/api-reference/tts/create-audio-speech`.
  - `fresh-docs checked`: OpenRouter API overview usage/cost fields at `https://openrouter.ai/docs/api/reference/overview`.
  - `fresh-docs checked`: ElevenLabs Text to Dialogue at `https://elevenlabs.io/docs/api-reference/text-to-dialogue/convert`.
  - `fresh-docs checked`: ElevenLabs Text to Speech at `https://elevenlabs.io/docs/api-reference/text-to-speech/convert`.
  - `fresh-docs checked`: ElevenLabs Music Compose at `https://elevenlabs.io/docs/api-reference/music/compose`.
  - `fresh-docs checked`: ElevenLabs Music Terms at `https://elevenlabs.io/music-terms`.

## Invariants

- This feature always starts from a content-scoped video project.
- A generated audio/music asset always belongs to one user, project, content, video project and source video version.
- A video version cannot silently use audio generated for another version after scenes, text or timing changed.
- Candidate audio/music assets do not affect preview/final render until selected for the current version.
- Only one selected narration track and one selected music bed are active per video version in V1 unless a future timeline spec changes that.
- Scene-level sound effects are not part of V1.
- Animated backgrounds are data configs, not uploaded executable code.
- Remotion props contain resolved, sanitized asset descriptors and allowlisted background configs only.
- Provider usage/cost metadata is recorded by backend evidence, not trusted from the client.
- OpenRouter BYOK and managed audio/PAYG cost ledgers remain separate.

## Links & Consequences

- `SPEC-remotion-video-editor-workflow-2026-05-11.md` said audio/music were future scope; this spec is that future scope and must not be implemented before the base video project model exists.
- `lab` needs a new video/audio API family rather than expanding feedback audio endpoints, because feedback storage is anonymous/support-oriented and not project/content/version-safe.
- `lab/api/services/feedback_storage.py` can inspire Bunny signed upload/playback mechanics, but V1 needs a content/video asset storage service with project ownership, durable public/render URLs and metadata.
- `lab/api/routers/reels.py` should remain focused on Instagram import and MVP reels where possible; richer video editor APIs should live in a separate videos router.
- `app` needs a route/order update for `/editor/:id/video` and possibly nested tabs inside the video editor, not a new app-shell nav item.
- `worker` must support audio props and procedural background props before preview/final validation can pass.
- Quota/PAYG behavior becomes visible to users when audio/music generation is attempted; app UI must explain managed usage blocks without exposing provider internals.
- Music generation introduces policy/legal copy obligations separate from generic AI image generation.

## Documentation Coherence

- Update `lab/README.md` or environment docs with `ELEVENLABS_API_KEY`, audio provider config, Bunny audio storage paths, quota behavior and music policy checks.
- Update `app/README.md` with video editor audio prerequisites once UI ships.
- Update `worker/README.md` with audio track props, music bed props, volume/fade semantics and animated background preset schemas.
- Add changelog entries for AI narration, music, background generation, quota behavior and provider-policy limitations.
- Add support docs explaining that V1 uses predefined voices, does not clone user voices, and does not guarantee music exclusivity or legal clearance beyond provider terms.
- Do not promise "podcast publishing" or "music rights guaranteed" in marketing copy for this spec.

## Edge Cases

- Source content changes after script generation but before audio rendering.
- Source content is deleted or moved to another project after audio is generated.
- Scene durations change and no longer fit generated narration.
- Provider returns audio longer or shorter than requested.
- Multi-speaker script has more speakers than selected voices.
- Two concurrent audio jobs target the same video version.
- User validates a preview, then swaps music before final render.
- Bunny object exists but metadata insert fails.
- Bunny metadata exists but object HEAD fails.
- OpenRouter script generation succeeds but managed audio quota fails afterward.
- Music prompt references a famous song, artist, label or substantial lyric.
- Music provider returns output with vocals despite instrumental preference unless the provider guarantees instrumental mode for the chosen request.
- Audio playback fails on Flutter Web or mobile while the asset is still valid.
- Signed audio preview URL expires during playback.
- Background animation creates unreadable text contrast or excessive motion.
- Background config renders fine in vertical but crops badly in landscape.
- User changes active project while an audio job is polling.
- A stale polling response arrives after route disposal.

## Implementation Tasks

- [ ] Task 1: Extend video project schema for audio and backgrounds
  - Fichier : `lab/api/models/videos.py`
  - Action : Add Pydantic models for `VideoAudioTrack`, `VideoMusicTrack`, `VideoAnimatedBackground`, `VideoMediaJob`, selected/candidate states, volume, fades, duration, placement and stale version metadata.
  - User story link : Lets the editor represent narration, music and backgrounds as part of the video version.
  - Depends on : Base Remotion video editor models from `SPEC-remotion-video-editor-workflow-2026-05-11.md`.
  - Validate with : model tests for valid/invalid audio tracks, background presets, stale version flags and unknown provider rejection.
  - Notes : Keep provider-specific metadata under a typed `provider_metadata` field; do not make arbitrary raw JSON the primary contract.

- [ ] Task 2: Add video media persistence tables
  - Fichier : `lab/api/services/video_project_store.py`
  - Action : Add migration-safe persistence for video audio jobs, generated audio assets, music candidates, background configs and selected media references per immutable video version.
  - User story link : Makes generated media durable and version-safe.
  - Depends on : Task 1.
  - Validate with : store tests using SQLite/libSQL test connection for create/list/select/stale/concurrency paths.
  - Notes : `JobStore` may mirror job status, but this store remains the source of truth for media attached to video versions.

- [ ] Task 3: Add a project-safe Bunny media storage service
  - Fichier : `lab/api/services/video_media_storage.py`
  - Action : Implement upload/download/playback helpers for audio/music assets using server-managed Bunny env vars, project/content/video path prefixes, MIME allowlist, max bytes, signed playback/render URLs and object existence checks.
  - User story link : Stores generated audio/music as durable assets usable by previews and final renders.
  - Depends on : Task 2.
  - Validate with : unit tests patching `httpx.AsyncClient` for upload success, upload failure, HEAD missing, MIME rejection and signed URL expiry.
  - Notes : Reuse ideas from `feedback_storage.py`, but do not reuse feedback paths or anonymous feedback token semantics.

- [ ] Task 4: Implement OpenRouter planning adapter for video audio scripts
  - Fichier : `lab/api/services/video_audio_planner.py`
  - Action : Generate structured narration/dialogue/music prompt plans from source content, storyboard scenes and format presets through `user_llm_service` or `pydantic_ai_runtime`, returning typed script segments and no raw provider secret.
  - User story link : Produces guided scripts without adding a separate podcast playground.
  - Depends on : Task 1 and strict BYOK runtime.
  - Validate with : tests proving missing/invalid OpenRouter blocks planning, valid BYOK returns typed plan, and no env LLM fallback is used.
  - Notes : Planning is skipped when the user edits/provides a valid script manually inside the guided editor.

- [ ] Task 5: Implement managed audio provider adapter
  - Fichier : `lab/api/services/elevenlabs_audio_provider.py`
  - Action : Add direct ElevenLabs HTTP integration for text-to-speech, text-to-dialogue and music compose, with allowlisted model ids, voice ids, output format, timeouts, chunking/rejection for long dialogue input, and normalized errors.
  - User story link : Renders narration, multi-speaker dialogue and music for video versions.
  - Depends on : Task 3.
  - Validate with : provider tests using mocked `httpx` responses for success bytes, character/request headers, 400/422 policy errors, 429 rate limits, timeout and empty audio.
  - Notes : Do not add the Node `@elevenlabs/elevenlabs-js` package to the Python backend.

- [ ] Task 6: Add music prompt policy validation
  - Fichier : `lab/api/services/music_policy.py`
  - Action : Reject or sanitize obvious artist names, song titles, label names, publisher names and lyric-like references before music provider calls, returning stable error codes.
  - User story link : Lets users generate music beds without putting the product into avoidable policy risk.
  - Depends on : Task 5.
  - Validate with : policy tests for blocked artist/title/lyrics examples, allowed mood/genre/use-case prompts and localized user errors.
  - Notes : This is a product safety filter, not a legal guarantee.

- [ ] Task 7: Add video media job orchestration
  - Fichier : `lab/api/services/video_media_orchestrator.py`
  - Action : Coordinate quota preflight/reservation, optional BYOK planning, managed audio/music provider call, Bunny upload, asset persistence, quota reconciliation, refund/release on failure and stale version marking.
  - User story link : Turns guided user actions into reliable asynchronous media assets.
  - Depends on : Tasks 2-6 and quota/billing service from the quotas spec.
  - Validate with : orchestration tests for happy path, quota block before provider call, provider failure refund, Bunny upload failure refund, duplicate job idempotency and stale video version.
  - Notes : If the quota service is not implemented when this starts, stop and implement or explicitly stub behind the quotas spec before calling paid providers.

- [ ] Task 8: Add video media API endpoints
  - Fichier : `lab/api/routers/videos.py`
  - Action : Add endpoints for creating audio/music/background jobs, polling status, listing candidates, selecting media for a video version, previewing signed audio, and clearing stale selections.
  - User story link : Exposes guided audio/background workflow to Flutter through the existing API boundary.
  - Depends on : Task 7.
  - Validate with : router tests for auth, ownership, foreign asset rejection, stale version conflicts, policy blocks, quota blocks and successful candidate selection.
  - Notes : Register the router in `lab/api/routers/__init__.py` and `lab/api/main.py`.

- [ ] Task 9: Attach generated media to content/video asset metadata
  - Fichier : `lab/status/service.py`
  - Action : Extend or add helper methods so server-validated `video_audio_ai` and `video_music_ai` assets can be represented through content asset metadata without accepting arbitrary client-supplied URLs.
  - User story link : Keeps generated media discoverable from content/video workflows and future library views.
  - Depends on : Task 8.
  - Validate with : status service tests for source/kind/mime metadata, ownership, tombstone and non-publishable candidate behavior.
  - Notes : Do not make generic `POST /api/status/content/{id}/assets` trust Flutter for AI media origin.

- [ ] Task 10: Extend Remotion scene props for audio and music
  - Fichier : `worker/src/schema/video-props.ts`
  - Action : Add typed props for narration tracks, music bed, volume, fades, loop/trim policy, asset URL descriptors, duration checks and selected background config.
  - User story link : Lets the worker render the selected media with the current video version.
  - Depends on : Base Remotion worker schema from the render/video specs and Task 8 API contract.
  - Validate with : TypeScript schema tests or build-time validation for valid/invalid props.
  - Notes : If the worker path differs at implementation time, apply this to the actual schema module created by the Remotion specs.

- [ ] Task 11: Implement Remotion audio mixing and animated backgrounds
  - Fichier : `worker/src/compositions/ContentGlowzSceneVideo.tsx`
  - Action : Render narration, music bed, fades, loop/trim behavior and allowlisted animated background presets from props.
  - User story link : Makes preview/final videos audibly and visually reflect selected audio/background choices.
  - Depends on : Task 10.
  - Validate with : worker render smoke tests using fixture audio and background configs for vertical and landscape presets.
  - Notes : V1 backgrounds should be procedural and bounded; do not fetch arbitrary remote JS/CSS/config.

- [ ] Task 12: Add Flutter models and API methods
  - Fichier : `app/lib/data/models/video_audio.dart`
  - Action : Add typed Dart models for audio formats, scripts, jobs, candidates, music assets, background presets and stale states.
  - User story link : Gives the editor a typed contract for audio/background state.
  - Depends on : Task 8.
  - Validate with : Dart model tests for JSON parsing, unknown status handling, missing optional fields and redacted signed URL display.
  - Notes : Add matching `ApiService` methods in `app/lib/data/services/api_service.dart`.

- [ ] Task 13: Add Riverpod state for video audio/background workflow
  - Fichier : `app/lib/providers/providers.dart`
  - Action : Add providers/notifiers for selected audio format, script plan, active audio job, active music job, candidates, selected assets, background preset/config, polling lifecycle and stale response rejection.
  - User story link : Keeps UI state coherent while jobs run asynchronously.
  - Depends on : Task 12.
  - Validate with : provider tests for start/poll/success/failure/project-change/stale-version transitions.
  - Notes : Render and provider jobs are online-only; do not queue audio generation offline.

- [ ] Task 14: Add editor-linked audio/background UI
  - Fichier : `app/lib/presentation/screens/editor/video_editor_screen.dart`
  - Action : Add guided tabs or sections inside the video editor for narration, music and animated backgrounds, with compact mobile-friendly controls, candidate preview, select/unselect, stale warnings and quota/BYOK errors.
  - User story link : Lets users enrich the current video without leaving the editor.
  - Depends on : Tasks 12-13 and base `/editor/:id/video` screen.
  - Validate with : widget tests for empty state, guided format selection, job running, candidate selection, stale warning, provider failure and narrow mobile layout.
  - Notes : If the base video screen is implemented under a different file name, update that file rather than creating a parallel editor.

- [ ] Task 15: Add route and editor entrypoint safeguards
  - Fichier : `app/lib/router.dart`
  - Action : Ensure `/editor/:id/video` route and Sentry sanitizer are ordered before generic `/editor/:id`; ensure audio/background UI is reachable only through video editor context.
  - User story link : Keeps this feature attached to the editor workflow.
  - Depends on : Task 14.
  - Validate with : router tests for `/editor/:id/video`, sanitized route name and no global audio route.
  - Notes : Do not add a new AppShell nav item for audio/podcast.

- [ ] Task 16: Add app audio preview playback
  - Fichier : `app/lib/presentation/screens/editor/video_audio_preview.dart`
  - Action : Add a reusable preview widget using existing `audioplayers` dependency to play signed audio preview URLs, with token redaction and refresh on expiry.
  - User story link : Lets users validate generated narration/music before selecting it.
  - Depends on : Task 14.
  - Validate with : widget tests for playable URL, missing URL, expired URL refresh and playback failure fallback.
  - Notes : Do not display signed query tokens in UI or diagnostics.

- [ ] Task 17: Update docs and env examples
  - Fichier : `lab/README.md`
  - Action : Document audio provider env vars, Bunny audio storage settings, OpenRouter planning split, quota preflight, policy limits, and local worker audio/background requirements.
  - User story link : Makes implementation and ops reproducible.
  - Depends on : Backend tasks.
  - Validate with : docs review plus `rg` for stale claims like standalone podcast studio or guaranteed music rights.
  - Notes : Also update `app/README.md`, `worker/README.md`, `.env.example` and changelog when those files exist in the implementation scope.

## Acceptance Criteria

- [ ] CA 1: Given an owned video project, when the user opens `/editor/:id/video`, then guided narration, music and background controls are visible in the video editor and no standalone podcast route is added.
- [ ] CA 2: Given missing OpenRouter BYOK and a request that needs script planning, when the user starts generation, then planning fails with a structured BYOK error before any LLM fallback or audio provider call.
- [ ] CA 3: Given an approved manual script, when the user generates audio without new planning, then missing OpenRouter BYOK does not block the managed audio provider call.
- [ ] CA 4: Given insufficient managed audio quota, when audio/music generation is requested, then the backend blocks before calling ElevenLabs and returns a recoverable quota error.
- [ ] CA 5: Given sufficient quota and valid ownership, when multi-speaker narration is generated, then the backend stores Bunny-backed audio metadata tied to the current video version and returns a pollable completed job.
- [ ] CA 6: Given a foreign content, project, video project or asset id, when a user requests generation or selection, then the API returns ownership-safe `403`/`404` and makes no provider call.
- [ ] CA 7: Given a music prompt referencing a protected artist, song title or substantial lyric, when generation is requested, then the backend rejects or sanitizes before provider submission and records a stable policy code.
- [ ] CA 8: Given provider success but Bunny upload failure, when the job finishes, then no usable audio asset is attached and user-facing usage is released/refunded.
- [ ] CA 9: Given scenes change after audio generation, when the user tries final render, then final render is blocked until audio is regenerated, reselected or explicitly accepted for the current version.
- [ ] CA 10: Given a selected narration track and music bed for the current version, when preview render completes, then the preview includes both tracks with configured volume/fades.
- [ ] CA 11: Given a selected animated background preset, when preview renders in vertical and landscape, then the background renders within safe bounds without arbitrary remote code or raw client URLs.
- [ ] CA 12: Given a signed audio preview URL expires, when the user presses play again, then the app refreshes media status instead of exposing the expired token.
- [ ] CA 13: Given the user changes active project while polling, when stale job responses arrive, then the UI ignores them and clears project-specific state.
- [ ] CA 14: Given final render is requested, when the current preview has not been user-validated for the exact audio/background version, then backend rejects final render.
- [ ] CA 15: Given diagnostics are captured on error, when reviewing logs, then no provider API keys, Bunny AccessKey, signed URL tokens, raw audio bytes or raw provider failure payloads are present.

## Test Strategy

- Backend unit tests for video audio models, policy validation, provider adapter error mapping, Bunny storage service and orchestrator state transitions.
- Backend router tests for Clerk auth, project ownership, BYOK planning errors, quota blocks, foreign asset rejection, stale version conflicts and candidate selection.
- Integration-style tests with mocked OpenRouter, mocked ElevenLabs and mocked Bunny upload to verify quota reservation, provider call, upload, asset persistence and refund/release paths.
- Remotion worker tests or smoke render scripts using fixture audio assets and procedural backgrounds for `vertical_9_16` and `landscape_16_9`.
- Flutter model/provider tests for job polling, stale responses, project changes, signed URL redaction and generated candidate selection.
- Flutter widget tests for compact editor audio/background controls on mobile and desktop widths.
- Manual QA: create a video from content, generate two-speaker narration, generate instrumental music bed, select animated background, preview, edit scene to force stale state, regenerate or accept, validate preview, final render.

## Risks

- Provider fit risk: OpenRouter covers TTS but not the full dialogue/music workflow needed here; direct ElevenLabs adds one managed provider and must be monitored for pricing/API changes.
- Legal/product risk: AI music has stricter prompt and rights constraints than image generation; mitigate with policy checks and conservative copy.
- Cost risk: Audio and music can become expensive; mitigate with quota hard-block before provider calls and refund/release on failed delivery.
- UX complexity risk: audio, music and backgrounds can make mobile video editing dense; mitigate with guided formats, sections and candidate/selected states rather than a full timeline.
- Staleness risk: audio generated for old scenes may be rendered accidentally; mitigate with immutable video version ids and stale checks before preview/final.
- Render risk: Remotion audio mixing/backgrounds may increase render time and failure modes; mitigate with bounded presets, fixture renders and capacity limits.
- Security risk: audio URLs and provider metadata may leak through diagnostics; mitigate with signed URLs, redaction and server-side identifiers.

## Execution Notes

- Read first:
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md`
  - `lab/api/services/user_llm_service.py`
  - `lab/api/services/feedback_storage.py`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
- Implementation order: backend models/store, storage/provider adapters, orchestrator/router, Remotion props/rendering, Flutter models/providers/UI, docs.
- Provider rule: use OpenRouter for structured text/planning when needed; use direct ElevenLabs for V1 multi-speaker audio and music; do not add a third audio/music provider in this chantier.
- Background rule: V1 animated backgrounds are Remotion procedural templates and trusted still-asset motion, not AI video generation.
- Stop and reroute if user voice cloning, user voice upload, podcast publishing, music rights guarantee, AI video backgrounds, or public pricing/checkout become required.
- Validation commands expected after implementation:
  - `python3 -m pytest tests/test_video_audio_models.py tests/test_video_media_orchestrator.py tests/test_video_media_router.py`
  - `flutter test test/data/video_audio_test.dart test/providers/video_audio_provider_test.dart test/presentation/video_editor_audio_test.dart`
  - worker build/render smoke command from `worker/README.md`
- Fresh external docs verdict: `fresh-docs checked`. Official OpenRouter docs support audio input/output and TTS, but current docs do not provide the complete music plus text-to-dialogue workflow. Official ElevenLabs docs support the direct V1 audio/music provider path, with music terms constraints that must shape validation and copy.

## Open Questions

None. Product assumptions locked for this draft: this is an editor-video extension, V1 includes narration multi-speaker and music, voices are predefined/admin-configured, UI is editor-linked, formats are guided, animated backgrounds are procedural Remotion configs, and direct ElevenLabs is the V1 managed audio provider because OpenRouter alone does not cover the full scope.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 16:55:05 UTC | sf-spec | GPT-5 Codex | Created draft spec from user clarification, local Remotion/video/audio code scan, contentglowz podcast/music prototypes, and fresh OpenRouter/ElevenLabs docs. | Draft saved. | /sf-ready Video editor AI audio, music, and animated backgrounds |
| 2026-05-11 17:09:43 UTC | sf-ready | GPT-5 Codex | Checked structure, metadata, user-story traceability, execution tasks, acceptance criteria, external docs freshness, adversarial workflow gaps, and security controls. | ready | /sf-start Video editor AI audio, music, and animated backgrounds |

## Current Chantier Flow

- sf-spec: done
- sf-ready: ready
- sf-start: not launched
- sf-verify: not launched
- sf-end: not launched
- sf-ship: not launched

Prochaine commande: `/sf-start Video editor AI audio, music, and animated backgrounds`
