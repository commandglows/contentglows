---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "contentglowz"
created: "2026-05-12"
created_at: "2026-05-12 19:57:05 UTC"
updated: "2026-05-12"
updated_at: "2026-05-12 19:57:05 UTC"
status: draft
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "medium"
user_story: "En tant que creatrice ContentGlowz authentifiee dans l'editeur video d'un contenu, je veux transcrire une video ou une piste audio puis editer les coupes, captions et segments depuis le texte, afin de produire des videos sociales plus lisibles, rythmees et efficaces sans ouvrir un studio de montage libre."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "worker"
  - "contentglowz/INSPIRATION.md"
  - "contentglowz/v0-cool-design-ressemble-gocharbon-connexion-reseaux-sociaux"
  - "contentglowz/remotion-template"
  - "Remotion video editor workflow"
  - "Video editor AI audio/music/backgrounds"
  - "Unified Project Asset Library"
  - "AI generation quotas/billing"
  - "Bunny Storage/CDN"
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
  - artifact: "shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "contentglowz/INSPIRATION.md"
    artifact_version: "unknown"
    required_status: "inspiration-only"
  - artifact: "contentglowz/v0-cool-design-ressemble-gocharbon-connexion-reseaux-sociaux"
    artifact_version: "local prototype"
    required_status: "inspiration-only"
  - artifact: "Remotion captions docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "Remotion Html5Audio docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "Remotion renderMedia docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "official"
  - artifact: "ElevenLabs Speech to Text docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "candidate-provider"
  - artifact: "OpenAI Speech to Text docs"
    artifact_version: "official docs checked 2026-05-12"
    required_status: "candidate-provider"
supersedes: []
evidence:
  - "User request 2026-05-12: create a ShipGlowz spec draft for Descript-like text-based media editing from the contentglowz inspiration folder."
  - "Product context: remain in the existing ContentGlowz app and stack; do not port contentglowz code or create a free studio/playground."
  - "Product context: optimize social content effectiveness, readability, rhythm, hook, captions, clean cuts and social formats, not artistic editing."
  - "contentglowz/INSPIRATION.md explicitly lists Descript as text-based audio/video editing through transcription."
  - "contentglowz/v0-cool-design-ressemble-gocharbon-connexion-reseaux-sociaux/components/studios/video-studio.tsx contains standalone upload, preview, split, timeline and layer UI ideas, but it is not stack-compatible and must stay inspiration-only."
  - "contentglowz/v0-cool-design-ressemble-gocharbon-connexion-reseaux-sociaux/components/studios/audio-studio.tsx contains standalone upload, waveform and playback controls, but no production transcript model."
  - "app/lib/router.dart currently exposes /editor/:id and no /editor/:id/video route; prior specs reserve the video editor entrypoint."
  - "app/lib/presentation/screens/editor/editor_screen.dart is the existing content editor surface with project asset access, markdown editing, save and publish controls."
  - "app/lib/data/services/api_service.dart and app/lib/providers/providers.dart already contain typed project asset APIs/providers and stale active-project response guards."
  - "lab/status/schemas.py and status/db.py already define project assets, media kinds, usages and events, but no transcript, caption track or text-edit-plan storage."
  - "lab/status/service.py currently rejects video_version asset target validation until the future video asset store ships."
  - "Repository scan found no production transcript/caption route or model for video/audio editing."
  - "Fresh docs checked 2026-05-12: official Remotion captions docs cover transcribing sources into the Remotion Caption type and using @remotion/captions utilities."
  - "Fresh docs checked 2026-05-12: official Remotion displaying captions docs show loading caption JSON, grouping captions into social-style pages and rendering them with <Sequence>."
  - "Fresh docs checked 2026-05-12: official Remotion Html5Audio docs support audio volume, trimBefore/trimAfter and render-time audio stream behavior relevant to cuts."
  - "Fresh docs checked 2026-05-12: official Remotion renderMedia docs are the programmatic rendering contract used by the existing render specs."
  - "Fresh docs checked 2026-05-12: official ElevenLabs Speech to Text docs describe audio/video transcription, word-level timestamps, speaker diarization and long-file limits."
  - "Fresh docs checked 2026-05-12: official OpenAI Speech to Text docs describe gpt-4o transcribe, diarized JSON and whisper-1 word timestamp support, with file-size tradeoffs."
next_step: "/sf-ready Text-Based Media Editing for Social Video"
---

## Title

Text-Based Media Editing for Social Video

## Status

Draft. This spec defines a Descript-like editing layer for the future ContentGlowz video editor: transcription, captions, clean cuts, scene splitting and text-driven media edit plans inside `/editor/:id/video`. It intentionally does not create a standalone studio. The spec is concrete enough for readiness review, but provider choice for speech-to-text must be confirmed before implementation starts.

## User Story

En tant que creatrice ContentGlowz authentifiee dans l'editeur video d'un contenu, je veux transcrire une video ou une piste audio puis editer les coupes, captions et segments depuis le texte, afin de produire des videos sociales plus lisibles, rythmees et efficaces sans ouvrir un studio de montage libre.

## Minimal Behavior Contract

Depuis `/editor/:id/video`, ContentGlowz permet a une creatrice authentifiee de lancer une transcription asynchrone sur la version video, la narration, une piste audio ou un asset video owned, puis d'afficher un transcript horodate qui sert a creer des captions sociales, selectionner des mots/phrases pour couper ou masquer des segments, separer une scene, resynchroniser des captions et sauvegarder un plan d'edition versionne. Le systeme ne modifie jamais destructivement le media original: il produit une nouvelle version video avec un edit plan, des captions et des references serveur validees, puis exige une preview de cette version avant tout rendu final ou publication. En cas d'echec d'auth, droits, provider, quota, stockage, alignement, conflit de version ou rendu Remotion, la version precedente reste intacte et l'utilisateur voit un etat recuperable. Le cas facile a rater est la staleness: des qu'une piste audio, une scene, une duree ou un asset change, le transcript et les captions derives doivent etre marques obsoletes jusqu'a regeneration, re-alignement ou acceptation explicite.

## Success Behavior

- Given une creatrice Clerk authentifiee ouvre `/editor/:id/video` pour un contenu owned, when la video version courante contient une piste audio, narration ou video renderable, then l'onglet texte/captions affiche l'etat `not_transcribed`, `queued`, `processing`, `ready`, `failed` ou `stale`.
- Given une source media eligible est choisie, when la creatrice lance la transcription, then le backend cree un job asynchrone owner-scoped lie a `project_id`, `content_id`, `video_project_id`, `video_version_id`, `source_asset_id`, provider, modele, duree estimee, reservation de quota et `client_request_id` idempotent si fourni.
- Given la transcription reussit, when le resultat revient du provider, then le backend persiste un transcript versionne avec texte complet, segments, mots/tokens horodates, speaker labels si disponibles, langue, confidence/quality metadata, provider ids redacts, source hash, et statut `ready`.
- Given le transcript est ready, when l'utilisateur selectionne une phrase ou un groupe de mots, then l'UI montre la plage temporelle correspondante et propose des actions guidees: `cut_segment`, `mute_segment`, `split_scene_here`, `create_caption_page`, `highlight_words`, `replace_caption_text`, `mark_hook`, `mark_cta`.
- Given une action de coupe est confirmee, when l'utilisateur sauvegarde, then le backend cree une nouvelle video version contenant un edit plan non destructif avec plages `remove`, `mute`, `keep`, `split`, `caption_override`, et invalide la preview/final render existants.
- Given une caption sociale est generee depuis le transcript, when elle est affichee, then elle respecte les presets du format courant: lignes courtes, lecture mobile, safe area, accent words, hook first, CTA lisible, et aucune superposition incoherente avec les visuels.
- Given l'utilisateur corrige un mot dans une caption, when il sauvegarde, then le texte affiche est corrige sans changer le transcript source brut, avec provenance `manual_caption_override`.
- Given une preview est demandee, when l'edit plan et les captions sont valides, then le backend transforme la video version en props Remotion schema-validees et le worker rend une preview avec les coupes, silences, splits et captions attendus.
- Given une preview terminee correspond exactement a la video version courante, when l'utilisateur la valide, then le final render peut etre demande et reference la meme version, le meme transcript id et le meme edit plan.
- Proof of success is a durable transcript record, a non-destructive text-edit plan, caption track metadata, project asset linkage when applicable, stale handling, a Remotion preview that reflects the text edits, and tests for ownership, provider failure, stale versions, edit-plan validation and caption readability constraints.

## Error Behavior

- Missing, expired or invalid Clerk auth returns `401`; no transcription, edit plan, caption mutation, asset usage or render job is created.
- A foreign project, content, video project, video version, media asset, transcript or job id returns `403` or `404` without leaking title, transcript text, speaker labels, provider ids, storage paths or signed URLs.
- If the base video editor/version store is not implemented, the API refuses text-based media actions with a structured `video_editor_not_available` error rather than creating orphan transcript data.
- If the selected source has no durable audio/video stream, is local-only, tombstoned, degraded, expired, provider-temporary, missing storage, or incompatible with transcription limits, the job is blocked before provider call.
- If managed transcription quota is insufficient, the backend blocks before provider call and returns the existing quota/billing error shape.
- If provider config is missing, rate-limited, unavailable, times out, rejects the file or returns malformed words/segments, the job becomes `failed` with sanitized error details and no usable transcript is attached.
- If Bunny read/signed media preparation fails before provider call, no provider call is made; if storage/export fails after provider success, the transcript stays internal failed/degraded and user-facing usage is released/refunded according to the quota spec.
- If a transcript source hash no longer matches the current video version audio/render source, the transcript becomes `stale` and cannot unlock final render until re-transcribed, re-aligned, or explicitly accepted through a bounded stale-accept flow.
- If text edit ranges overlap incoherently, remove the whole duration, create gaps below minimum scene duration, break caption timing, or exceed render props limits, the edit plan is rejected and the previous valid version remains current.
- If two saves race, optimistic concurrency rejects the stale write and preserves the newer version.
- If captions would exceed safe-area/readability rules for the selected format, the UI must force wrap/reduce/split or block save with a typed `caption_readability_failed` error.
- If preview rendering fails, the edit plan remains editable but cannot unlock final render.
- What must never happen: raw provider keys or signed Bunny URLs reach Flutter, transcript text from one user/project is visible to another, client-supplied URLs become transcription input, the original media is destructively altered, a stale transcript unlocks final render, or a text deletion silently publishes without preview validation.

## Problem

ContentGlowz is moving toward a guided Remotion video editor with AI audio, music, motion and project assets. The remaining Descript-like inspiration is highly valuable for social video production because editing through text is faster than manipulating a timeline, especially for hooks, captions and clean cuts. The repo currently has no production transcript/caption/edit-plan model, and the `contentglowz` demos are standalone upload studios rather than stack-compatible editor extensions. Without a clear spec, this feature could drift into a free-form media studio or a destructive timeline editor, both of which conflict with the product direction.

## Solution

Add a text-based editing layer to the existing/future video editor. The backend creates provider-backed transcripts from server-owned media, normalizes words/segments into a ContentGlowz transcript schema, lets Flutter present guided text actions, persists non-destructive edit plans on immutable video versions, and renders captions/cuts through Remotion. V1 focuses on social-content outcomes: faster hook cleanup, readable captions, clean cuts, scene splits and preview-gated final renders.

## Scope In

- Add a text/captions panel inside `/editor/:id/video`; no app-shell nav item and no standalone studio route.
- Transcribe eligible sources tied to the current video context: generated narration/audio assets, music-free voice tracks, render-output audio, imported reel/video assets after they are durable project assets, and future approved uploaded videos.
- Persist transcript records scoped by `user_id`, `project_id`, `content_id`, `video_project_id`, `video_version_id`, `source_asset_id`, source hash and provider metadata.
- Store normalized transcript data: full text, language, segments, words/tokens with start/end milliseconds, speaker labels when available, confidence/quality metadata, and provider response hash.
- Create caption tracks from transcript data using social presets: hook-first, word highlight, short line groups, CTA reveal, silent-safe captions, platform safe area, vertical-first with landscape compatibility.
- Support bounded text-driven edit operations: cut selected range, mute selected range, restore cut, split scene at phrase boundary, merge adjacent caption pages, edit caption display text, mark hook/CTA/proof segment, and regenerate captions for a selected scene.
- Store edit plans as non-destructive versioned data, not media overwrites.
- Invalidate preview/final readiness when transcript, caption track, source audio/video, scene duration, selected audio asset or edit plan changes.
- Add transcript/caption project-asset or media-like metadata so completed caption tracks and transcript derivatives are discoverable only where eligible in the project asset library.
- Add backend validation for ownership, source durability, provider limits, quota preflight, time ranges, edit-plan overlaps, minimum scene duration, caption safe areas, props size and stale version checks.
- Use Remotion `@remotion/captions` compatible caption data or an adapter that can convert to that shape for rendering.
- Render text edits through Remotion props: caption tracks, muted/cut time ranges, scene splits, audio/video segment descriptors and caption style presets.
- Add status polling and recoverable UI states for queued, processing, ready, stale, failed, applying edit and preview required.
- Add tests across backend models, provider adapters, asset eligibility, app state, UI, worker props and render smoke fixtures.

## Scope Out

- Standalone Descript clone, global podcast/audio/video studio, free playground or arbitrary upload workspace.
- Porting Next.js, Supabase, Vercel, React, canvas, upload or studio code from `contentglowz`.
- Full frame-accurate professional timeline, waveform editor, multitrack DAW, nested timeline, green-screen editor, color correction or CapCut effect marketplace.
- Destructive media editing; originals remain immutable assets.
- User voice cloning, overdub, voice isolation, speech-to-speech, dubbing or voice consent workflows.
- Automatically rewriting spoken content with AI and regenerating narration; that belongs to the audio generation workflow or a future spec.
- Public podcast publishing, RSS, Spotify/Apple Podcasts distribution or audio-only publishing.
- Generic binary upload implementation unless an upload spec has already made the source durable.
- Manual legal caption compliance guarantee, accessibility certification, translation workflows or multilingual subtitle publishing.
- Browser-side transcription as the default V1 path; V1 is backend/job driven.
- Direct Flutter calls to transcription providers, Remotion worker or Bunny storage internals.
- Public marketing copy promising Descript parity or guaranteed caption accuracy before production QA.

## Constraints

- Product decision: this is an editor-video extension for effective social content, not an artistic or free-form media studio.
- Product decision: V1 is guided and preview-gated. Text edits can propose cuts/captions quickly, but final render/publication requires preview validation.
- `app` remains Flutter and talks only to `lab`.
- `lab` remains the authenticated API boundary for provider calls, Bunny access, ownership checks, quota preflight, transcript persistence and render orchestration.
- Durable state uses Turso/libSQL-compatible schema patterns; schema changes must use the ContentGlowz Turso migration guardrails during implementation.
- Clerk auth and existing project/content ownership helpers remain mandatory for every route.
- Provider calls are backend-managed/PAYG unless the readiness decision explicitly chooses a BYOK transcription provider path.
- Client requests pass server ids, selected ranges and guided actions, not trusted final Remotion props, arbitrary URLs or provider model ids.
- Transcript text is potentially sensitive project content. It must be scoped, excluded from public analytics, redacted from diagnostics and never logged in full by default.
- Signed media URLs are transient access mechanisms only; they are not durable authority and must not be stored in Flutter state as source truth.
- Video text editing is online-only and must not enter the offline write queue.
- Existing publishing flow must not publish a video version whose transcript/caption/edit plan is stale or whose preview has not been validated.
- V1 should remain mobile-usable: compact transcript list, search, sentence groups, action sheet for selected text, and caption preview instead of dense desktop timeline controls.
- If `worker` has not yet been created by the Remotion specs, implementation must first finish the Remotion worker foundation rather than invent a second worker path.

## Dependencies

- Existing stack: Flutter app, FastAPI lab backend, Clerk auth, Turso/libSQL, Bunny Storage/CDN, Remotion worker, project asset library and quota/billing hooks.
- Local dependency evidence:
  - `app/pubspec.yaml`: Flutter SDK `^3.11.3`, Riverpod `^3.3.1`, GoRouter `^17.2.2`, Dio `^5.9.2`, audioplayers `^6.6.0`.
  - `contentglowz/remotion-template/package.json`: Remotion dependencies `^4.0.0`, React 19, `@remotion/renderer`, `@remotion/bundler`, TypeScript.
- Required prior specs:
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md`
  - `shipglows_data/workflow/specs/SPEC-ai-generation-quotas-billing-2026-05-11.md`
- Fresh external docs verdict: `fresh-docs checked`.
  - Remotion captions overview: `https://www.remotion.dev/docs/captions`
  - Remotion transcribing options: `https://www.remotion.dev/docs/captions/transcribing`
  - Remotion displaying captions: `https://www.remotion.dev/docs/captions/displaying`
  - Remotion exporting subtitles: `https://www.remotion.dev/docs/captions/exporting`
  - Remotion Html5Audio: `https://www.remotion.dev/docs/html5-audio`
  - Remotion renderMedia: `https://www.remotion.dev/docs/renderer/render-media`
  - ElevenLabs Speech to Text: `https://elevenlabs.io/docs/overview/capabilities/speech-to-text`
  - OpenAI Speech to Text: `https://developers.openai.com/api/docs/guides/speech-to-text`
- Documentation interpretation:
  - Remotion supports a caption workflow centered on a `Caption` type and `@remotion/captions`, with utilities for social caption grouping and Sequence-based rendering.
  - Remotion audio/video components can trim, mute, sequence and render media from validated props; ContentGlowz should generate an edit decision list rather than editing raw media files.
  - ElevenLabs STT is a natural provider candidate if the existing audio-provider decision remains ElevenLabs, because it supports audio/video input, word timestamps, diarization and long files.
  - OpenAI STT is an alternative candidate if the product wants OpenAI for transcription quality/diarization; it has stronger file-size constraints for common endpoints and would add/extend managed provider surface.

## Invariants

- A transcript belongs to exactly one source hash and video version context; it cannot silently migrate across versions.
- Text edits create a new immutable video version or a draft version mutation with optimistic concurrency; they never mutate original media assets.
- A final render requires a preview validated for the exact current video version, transcript id, caption track id and edit plan id.
- Transcript and caption data are project-private and tenant-scoped.
- Provider output is untrusted until normalized and validated by the backend.
- Captions must prefer readability over visual novelty: short lines, safe-area bounds, adequate contrast and no important-object occlusion where detectable.
- The app must keep manual preset/caption editing usable even if AI helper features are unavailable.
- Flutter must ignore stale async responses when active project/content/video context changes.
- Transcript-derived assets follow project asset tombstone/history rules and cannot be reused after tombstone except as historical provenance.
- Logs may include ids, state transitions, durations, provider names and sanitized error codes, but not full transcript text, signed URLs, raw provider payloads, provider keys or bearer tokens.

## Links & Consequences

- Backend data: requires Turso/libSQL schema additions for transcripts, caption tracks, edit plans, edit operations, job state or references to the existing jobs table, and audit events.
- Backend API: likely add `lab/api/routers/videos.py` or extend the router created by the Remotion video spec with transcription and text-edit endpoints.
- Backend asset library: project asset taxonomy likely needs `transcript`, `caption_track` and `text_edit_plan` or equivalent media-like sources such as `video_transcript_ai` and `caption_track_ai`.
- Backend quota: managed transcription duration must reserve/consume/release usage before/after provider calls.
- Backend security: ownership checks must validate project, content, video version, source asset, transcript and edit plan together.
- Flutter route/UI: `/editor/:id/video` needs a text/captions tab or panel; route sanitizer should distinguish `/editor/:id/video` before generic `/editor/:id`.
- Flutter offline behavior: transcription and render actions are online-only; offline UI should show disabled/retry state rather than queue mutations.
- Remotion worker: scene props must accept caption tracks and edit decision lists; worker must not fetch arbitrary URLs from Flutter.
- Bunny/CDN: source media for provider calls and preview/playback must use server-issued URLs or backend transfer, not durable client-provided URLs.
- Publishing: final publish/export must check preview validation against transcript/edit-plan state.
- Analytics/diagnostics: only aggregate action counts, states and durations; do not send transcript bodies or raw captions to analytics.

## Documentation Coherence

- Update `lab/README.md` or backend env docs with transcription provider config, provider choice, quota hooks, redaction rules and worker expectations.
- Update `app/README.md` or app docs with video text-editing states, online-only behavior and diagnostics caveats.
- Update `worker/README.md` when the worker exists: caption JSON contract, edit-plan props, fixture render commands and asset URL rules.
- Update `.env.example` files when provider variables are implemented.
- Update in-app localization strings for transcript states, caption warnings, stale transcript, quota/provider errors and preview-required messages.
- Update support docs only after QA with wording that avoids Descript parity, guaranteed accuracy or legal caption compliance claims.
- No public site or pricing copy changes are required for the draft. Public marketing must wait until the feature passes manual QA and provider/billing rules are settled.

## Edge Cases

- Audio generated from script differs from actual spoken timing; transcript alignment must follow the rendered audio, not the original script.
- Music-heavy or no-speech videos may produce low-quality transcripts; UI should detect low confidence/no speech and suggest manual captions or skipping transcription.
- Multi-speaker content may have inconsistent speaker labels across provider runs; speaker labels should be editable display metadata, not hard identity truth.
- A selected text range begins/ends mid-word or across caption pages; backend should snap to token boundaries or require explicit confirmation.
- Removing a segment shortens video duration and invalidates downstream scene timings, captions, music bed, motion and CTA placement.
- Cutting all speech from a scene or leaving a scene below minimum duration should be blocked or require converting the scene to visual-only.
- Caption text correction must not modify raw transcript provenance or provider output hash.
- Captions with very long words, URLs or hashtags must wrap/split or shrink without overflowing buttons, cards or video safe area.
- A provider returns word timestamps but no segment punctuation; backend needs deterministic sentence/page grouping.
- A provider returns segment timestamps but no word timestamps; V1 must degrade to phrase-level editing and disable word-level cuts/highlights.
- A signed source URL expires while provider is processing; backend must retry preparation safely or mark failed without exposing the expired URL.
- A user changes active project during polling; Flutter must ignore stale job completion and not attach a foreign transcript.
- A tombstoned source asset has historical transcript data; it can remain readable as provenance but cannot drive new renders.
- Transcript contains private or sensitive words; diagnostics and analytics must not capture full text.
- Re-running transcription for the same source hash should be idempotent or show existing ready transcript unless provider/model/settings changed.

## Implementation Tasks

- [ ] Task 1: Define backend transcript, caption and edit-plan models
  - Fichier : `lab/api/models/video_text_editing.py`
  - Action : Add Pydantic request/response models for transcription jobs, source descriptors, transcript segments/words, caption tracks/pages, text edit operations, edit plans, stale states, provider metadata, quota metadata and error envelopes.
  - User story link : Gives the app a typed contract for editing media through text.
  - Depends on : Base video project/version concepts from the Remotion video editor spec.
  - Validate with : Pydantic unit tests for valid source, phrase-level fallback, overlapping ranges, stale transcript and redacted provider metadata.
  - Notes : Keep provider raw payloads out of responses.

- [ ] Task 2: Add Turso/libSQL-compatible persistence for transcripts and edit plans
  - Fichier : `lab/status/db.py`
  - Action : Add schema ensures or migrations for `video_transcripts`, `video_caption_tracks`, `video_text_edit_plans`, `video_text_edit_events` and indexes by user/project/content/video version/source hash.
  - User story link : Makes transcript and text edits durable, versioned and auditable.
  - Depends on : Task 1.
  - Validate with : migration/startup tests using empty DB and upgraded DB fixtures.
  - Notes : Follow ContentGlowz Turso migration guardrails; no destructive migration.

- [ ] Task 3: Add transcript/edit-plan store service
  - Fichier : `lab/api/services/video_text_editing_store.py`
  - Action : Implement create/list/get/update methods for transcript jobs, transcript records, caption tracks, edit plans, version hashes, stale markers and audit events.
  - User story link : Provides source-of-truth state for text-based media editing.
  - Depends on : Task 2.
  - Validate with : store tests for ownership filters, idempotency, stale marking, optimistic concurrency and event history.
  - Notes : Store full transcript text only in scoped records, never in global logs.

- [ ] Task 4: Extend project asset taxonomy for transcript-derived artifacts
  - Fichier : `lab/status/schemas.py`
  - Action : Add or otherwise model transcript/caption/edit-plan media-like sources so caption tracks and transcript derivatives can be discoverable in project asset workflows without being selectable for incompatible media placements.
  - User story link : Keeps caption/text artifacts tied to project assets and future reuse rules.
  - Depends on : Task 2 and Unified Project Asset Library contract.
  - Validate with : project asset eligibility tests for caption preview, video-version selection, tombstone/history and incompatible publish/render usage.
  - Notes : If implementation chooses not to put transcripts in `project_assets`, it must provide an equivalent project-scoped inventory and explain why asset library integration is deferred.

- [ ] Task 5: Add transcription provider abstraction
  - Fichier : `lab/api/services/transcription_provider.py`
  - Action : Define `TranscriptionProvider` interface, normalized result model, provider error taxonomy, file/source preparation contract, cost/duration metadata and redaction helpers.
  - User story link : Allows backend to transcribe media without locking UI to a vendor response shape.
  - Depends on : Task 1.
  - Validate with : unit tests for provider timeout, malformed segments, word-only, segment-only, diarized and no-speech responses.
  - Notes : Provider choice is an open question before readiness; implement only the selected provider adapter in V1.

- [ ] Task 6: Implement selected managed transcription adapter
  - Fichier : `lab/api/services/managed_transcription_provider.py`
  - Action : Implement the selected V1 adapter, likely ElevenLabs STT if the audio-provider consolidation decision holds, or OpenAI STT if readiness selects OpenAI; map provider output into normalized segments/words.
  - User story link : Produces timestamped transcript data for text editing and captions.
  - Depends on : Task 5 and provider decision in Open Questions.
  - Validate with : mocked provider tests for success, file too large, duration too long, rate limit, diarization, missing word timestamps and sanitized errors.
  - Notes : Do not implement both providers in V1 unless explicitly approved; avoid provider sprawl.

- [ ] Task 7: Add transcription orchestration with quota and source preparation
  - Fichier : `lab/api/services/video_text_editing_orchestrator.py`
  - Action : Validate ownership/source durability, reserve quota, prepare server-side media access, call provider, persist normalized transcript/caption draft, release/consume quota, and mark stale/degraded states.
  - User story link : Makes transcription async, recoverable and safe for managed provider cost.
  - Depends on : Tasks 3, 5, 6 and quota/billing spec hooks.
  - Validate with : orchestration tests for idempotent request, quota block before provider call, provider failure refund, storage failure, stale source hash and successful transcript persistence.
  - Notes : Use existing job/state pattern or the video job store from base specs; do not create invisible background work.

- [ ] Task 8: Add video text-editing API routes
  - Fichier : `lab/api/routers/videos.py`
  - Action : Add endpoints under the video editor route namespace for start transcription, poll job, list transcripts, get transcript, create/update caption track, create/apply edit plan, mark stale/accepted, and preview readiness checks.
  - User story link : Exposes text-based editing to Flutter in the existing editor workflow.
  - Depends on : Tasks 1, 3 and 7.
  - Validate with : router tests for Clerk auth, ownership, foreign asset rejection, quota errors, stale version conflicts, invalid ranges and successful edit-plan creation.
  - Notes : If the base video editor creates a different router path, extend that path rather than creating a parallel public API.

- [ ] Task 9: Add project asset and video-version eligibility for transcript/caption usage
  - Fichier : `lab/status/service.py`
  - Action : Extend eligibility and target validation once the video version store exists so transcript/caption assets can be linked to owned video versions and blocked from incompatible content/publish actions.
  - User story link : Prevents cross-project reuse and stale captions in renders.
  - Depends on : Task 4 and base video asset store.
  - Validate with : service tests for video_version ownership, tombstoned source, stale transcript, incompatible media kind and historical-only access.
  - Notes : Current code explicitly rejects video_version validation; this task replaces that placeholder only after the video store ships.

- [ ] Task 10: Extend Remotion props schema for captions and text edit plans
  - Fichier : `worker/src/schema/video-props.ts`
  - Action : Add schema fields for transcript/caption track descriptors, caption style preset, caption pages/tokens, edit decision list, cut/mute/split ranges, source asset descriptors and version ids.
  - User story link : Lets Remotion render the same text edits that the user validated.
  - Depends on : Base Remotion worker from render/video specs and Task 8.
  - Validate with : worker schema tests for valid captions, invalid overlapping ranges, oversized props, missing asset descriptors and stale ids.
  - Notes : If worker path differs at implementation time, modify the actual schema module created by the Remotion specs.

- [ ] Task 11: Render captions and non-destructive text edits in Remotion
  - Fichier : `worker/src/compositions/ContentGlowzSceneVideo.tsx`
  - Action : Render caption pages using `@remotion/captions` compatible data, apply cut/mute/split ranges through Sequenced audio/video descriptors, and preserve scene layout/format presets.
  - User story link : Makes preview/final video reflect text edits and captions.
  - Depends on : Task 10.
  - Validate with : fixture render smoke tests for vertical and landscape formats with captions, cuts, muted range, restored range and stale prop rejection.
  - Notes : Do not fetch raw URLs from props that were not backend-resolved.

- [ ] Task 12: Add Flutter data models for transcript and text editing
  - Fichier : `app/lib/data/models/video_text_editing.dart`
  - Action : Add Dart models for transcript job, transcript, segment, word token, caption track, caption page, edit operation, edit plan, stale state and API errors.
  - User story link : Gives the editor a typed client contract.
  - Depends on : Task 1.
  - Validate with : model parsing tests for provider-normalized transcript, phrase-level fallback, stale caption and redacted metadata.
  - Notes : Do not store signed URLs or full provider payloads in durable app state.

- [ ] Task 13: Add ApiService methods for video text editing
  - Fichier : `app/lib/data/services/api_service.dart`
  - Action : Add methods for transcription job creation/polling, transcript fetch, caption track save, edit-plan save/apply, preview readiness and stale handling.
  - User story link : Connects Flutter UI to backend text-editing flows.
  - Depends on : Task 8 and Task 12.
  - Validate with : service tests using fake Dio responses for happy path, 401, 403/404, quota, stale conflict and provider failure.
  - Notes : Keep online-only behavior; do not queue transcription/edit-plan apply offline unless a later spec says so.

- [ ] Task 14: Add Riverpod controller for transcript/caption/edit state
  - Fichier : `app/lib/providers/video_text_editing_provider.dart`
  - Action : Add provider/notifier for current video text state, selected text range, transcript polling, caption draft, edit plan draft, apply/save mutations, stale response rejection and active project/content resets.
  - User story link : Manages the editor workflow without leaking stale async data across projects.
  - Depends on : Task 13.
  - Validate with : provider tests for project switch, polling completion, stale transcript, conflicting save and provider failure.
  - Notes : Mirror existing active-project stale guards from `ProjectAssetLibraryNotifier`.

- [ ] Task 15: Add editor-linked text/captions UI
  - Fichier : `app/lib/presentation/screens/editor/video_text_editor_panel.dart`
  - Action : Build a compact panel for transcript status, transcribe action, transcript search, sentence/word selection, guided action sheet, caption page editor, hook/CTA markers, stale warnings and preview-required state.
  - User story link : Lets users edit social videos through text inside the video editor.
  - Depends on : Task 14.
  - Validate with : Flutter widget tests for mobile and desktop widths, selected range actions, caption overflow warning, stale state and no-source state.
  - Notes : Keep controls guided and dense; avoid a desktop timeline clone.

- [ ] Task 16: Integrate text/captions panel into the video editor route
  - Fichier : `app/lib/presentation/screens/editor/video_editor_screen.dart`
  - Action : Add a Text/Captions tab or section inside the existing/future video editor, wire preview/final gating to transcript/edit-plan freshness, and keep `/editor/:id/video` as the only entrypoint.
  - User story link : Ensures this is an editor extension, not a separate studio.
  - Depends on : Task 15 and base video editor UI.
  - Validate with : route/widget tests for `/editor/:id/video`, no global Descript route, preview blocked when stale, final render allowed only after validated preview.
  - Notes : If `video_editor_screen.dart` does not exist yet, implement this in the actual file created by the Remotion video editor spec.

- [ ] Task 17: Add docs and diagnostics redaction updates
  - Fichier : `lab/README.md`
  - Action : Document transcription provider env vars, quota hooks, Bunny media access, transcript retention/redaction, Remotion caption props and manual QA checklist.
  - User story link : Makes implementation operable and supportable.
  - Depends on : Provider and API implementation tasks.
  - Validate with : docs review plus `rg` for stale claims such as Descript clone, guaranteed captions, standalone studio or public transcript access.
  - Notes : Also update `app/README.md`, `worker/README.md`, `.env.example` and changelog when those files exist in implementation scope.

## Acceptance Criteria

- [ ] CA 1: Given an authenticated user owns a content/video project, when they open `/editor/:id/video`, then a Text/Captions surface is available inside the video editor and no standalone Descript/audio/video studio route is added.
- [ ] CA 2: Given no durable audio/video source exists for the current video version, when the user opens the Text/Captions surface, then transcription is disabled with a clear no-source state.
- [ ] CA 3: Given a durable owned source and sufficient quota, when transcription is requested, then the backend creates a pollable job tied to the exact video version/source hash.
- [ ] CA 4: Given insufficient quota, when transcription is requested, then the backend blocks before any provider call and returns a recoverable quota error.
- [ ] CA 5: Given a foreign source asset or video version id, when transcription or edit-plan apply is requested, then the API returns ownership-safe `403`/`404` and makes no provider or render call.
- [ ] CA 6: Given provider success with word timestamps, when the job completes, then the transcript contains normalized words, segments, language, provider metadata and redacted ids.
- [ ] CA 7: Given provider success without word timestamps, when the transcript is ready, then phrase-level captions are available and word-level cut/highlight actions are disabled.
- [ ] CA 8: Given provider failure, timeout or malformed response, when polling completes, then the job is failed, quota is released/refunded according to policy, and no usable transcript is attached.
- [ ] CA 9: Given a ready transcript, when the user selects a sentence and chooses cut, then the UI previews the affected time range and backend persists a non-destructive edit plan only after confirmation.
- [ ] CA 10: Given overlapping or invalid cut ranges, when the edit plan is saved, then the backend rejects the mutation and preserves the previous valid video version.
- [ ] CA 11: Given a user corrects caption display text, when saved, then the caption track changes while raw transcript provenance remains unchanged.
- [ ] CA 12: Given captions exceed safe-area/readability constraints, when the user tries to save or preview, then the app splits, wraps, shrinks or blocks with a typed readability warning.
- [ ] CA 13: Given transcript source audio/video changes after transcription, when the user requests final render, then the backend blocks with `transcript_stale` until re-transcribed, re-aligned or explicitly accepted.
- [ ] CA 14: Given a valid edit plan and caption track, when preview render is requested, then Remotion receives only backend-validated props and renders the expected cuts/captions.
- [ ] CA 15: Given preview completes for an older edit plan, when a newer plan exists, then the old preview cannot unlock final render.
- [ ] CA 16: Given final render is requested, when the current preview has not been user-validated for the exact transcript/edit-plan/caption ids, then the backend rejects final render.
- [ ] CA 17: Given a tombstoned transcript/caption asset, when future reuse is attempted, then the backend rejects new usage while preserving historical detail.
- [ ] CA 18: Given diagnostics are captured during provider or render errors, when logs are inspected, then no full transcript text, provider key, bearer token, signed URL token or raw provider payload is present.
- [ ] CA 19: Given active project changes during polling or save, when stale async responses arrive in Flutter, then the UI ignores them and does not attach transcript state to the new project.
- [ ] CA 20: Given manual caption editing is available, when the transcription provider is unavailable, then existing ready captions/edit plans remain editable but new transcription is disabled with a recoverable provider state.

## Test Strategy

- Backend unit tests for transcript/caption/edit-plan Pydantic models, range validation, source hash validation, caption readability constraints and provider error mapping.
- Backend store tests with SQLite/libSQL-compatible DB for schema initialization, transcript persistence, stale marking, idempotency, optimistic concurrency and event audit.
- Backend router tests for Clerk auth, ownership, project/content/video version matching, foreign asset rejection, quota block, invalid ranges, stale conflicts and successful edit-plan apply.
- Integration-style tests with mocked selected transcription provider, mocked Bunny source preparation and mocked quota ledger.
- Project asset tests for transcript/caption media-like taxonomy, eligibility, tombstone/history and incompatible publish/render actions.
- Remotion worker schema tests for caption props, edit decision list, oversized props, unsupported source descriptors and stale ids.
- Remotion fixture render smoke tests for vertical `9:16` and landscape `16:9` with captions, cuts, mute ranges, restored ranges and speaker labels.
- Flutter model tests for transcript/caption/edit-plan parsing and redacted metadata.
- Flutter provider tests for polling, stale active project/content context, failed job, stale transcript, edit-plan conflict and preview gating.
- Flutter widget tests for mobile/desktop Text/Captions panel, selected text actions, caption editor, overflow warning, no-source state and provider/quota error states.
- Manual QA: create a video version with narration, transcribe, correct captions, cut one sentence, split one scene, preview, edit audio to force stale transcript, re-transcribe or accept, validate preview, final render.

## Risks

- Product risk: a Descript-like feature can become a broad media studio. Mitigate by keeping V1 inside `/editor/:id/video`, with guided actions and no global upload/playground route.
- Provider risk: transcription provider choice affects cost, latency, language coverage, diarization and service sprawl. Mitigate with a readiness decision and a single V1 provider adapter.
- Data privacy risk: transcripts contain sensitive project content. Mitigate with tenant scoping, redaction, no full transcript logs and no public analytics payloads.
- Staleness risk: captions and edit plans can become wrong after audio/scene changes. Mitigate with source hashes, immutable version ids and render gating.
- Render risk: non-destructive cut plans can desync audio, captions, motion and scene durations. Mitigate with validation, fixture renders and preview-required final export.
- UX complexity risk: transcript, captions and cuts can overload mobile. Mitigate with sentence groups, action sheets and compact caption pages rather than timeline editing.
- Cost risk: long videos can create expensive transcription jobs. Mitigate with quota preflight, duration limits, idempotent transcripts and clear failure/refund rules.
- Accuracy risk: captions may be wrong or legally insufficient. Mitigate with manual correction, accuracy-neutral copy and no compliance guarantee.
- Scope dependency risk: base video editor, audio and asset library must exist first. Mitigate by treating this as a later layer and blocking implementation until prerequisites are active.

## Execution Notes

- Read first:
  - `shipglows_data/workflow/specs/monorepo/SPEC-remotion-video-editor-workflow-2026-05-11.md`
  - `shipglows_data/workflow/specs/monorepo/SPEC-video-editor-ai-audio-music-backgrounds-2026-05-11.md`
  - `shipglows_data/workflow/specs/SPEC-unified-project-asset-library-2026-05-11.md`
  - `app/lib/router.dart`
  - `app/lib/presentation/screens/editor/editor_screen.dart`
  - `app/lib/providers/providers.dart`
  - `lab/status/service.py`
  - `lab/status/db.py`
- Implementation order: base video/version availability, backend models/schema/store, provider adapter and orchestrator, routes, asset eligibility, Remotion props/rendering, Flutter models/services/providers/UI, docs.
- Provider rule for V1: implement one managed transcription provider only after readiness decision. Prefer reusing the existing managed audio provider if product wants fewer services; choose OpenAI only if its transcription/diarization tradeoffs are explicitly desired.
- Caption rule: store raw transcript and display captions separately so manual caption corrections do not falsify provider provenance.
- Edit rule: text edits are edit plans over immutable source media, not destructive rewrites.
- Render rule: final render must require validated preview for exact transcript/edit-plan/caption ids.
- Validation commands expected after implementation:
  - `python3 -m pytest tests/test_video_text_editing_models.py tests/test_video_text_editing_store.py tests/test_video_text_editing_router.py`
  - `flutter test test/data/video_text_editing_test.dart test/providers/video_text_editing_provider_test.dart test/presentation/video_text_editor_panel_test.dart`
  - worker build/render smoke command from `worker/README.md`
- Stop and reroute if the user asks for standalone studio, arbitrary media upload, Descript parity, destructive editing, voice overdub/cloning, legal caption compliance, translation/subtitle localization, or auto-publication without preview validation.
- Fresh external docs verdict: `fresh-docs checked` for Remotion captions/audio/rendering, ElevenLabs STT and OpenAI STT on 2026-05-12.

## Open Questions

- Provider V1: should transcription use ElevenLabs STT to consolidate with the existing managed audio direction, OpenAI STT for its transcription/diarization options, or a later local Whisper path? This blocks `/sf-ready`.
- Source scope V1: should this handle only videos/audio generated inside ContentGlowz first, or also imported/durable reel/video assets from day one? Draft assumes both if the source is a durable owned project asset, but implementation can narrow.
- Stale acceptance: when audio changed slightly after transcription, should users be allowed to explicitly accept an old transcript for preview, or should regeneration always be required? Draft allows a bounded explicit accept flow.
- Transcript retention: draft aligns transcript/caption history with project asset/version retention and tombstone behavior. Confirm if transcript text needs shorter retention than media assets.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-12 19:57:05 UTC | sf-spec | GPT-5 Codex | Created draft spec for Descript-like text-based media editing from contentglowz inspiration, local repo scan and fresh official Remotion/transcription docs. | Draft saved. | /sf-ready Text-Based Media Editing for Social Video |

## Current Chantier Flow

- sf-spec: done
- sf-ready: not launched
- sf-start: not launched
- sf-verify: not launched
- sf-end: not launched
- sf-ship: not launched

Prochaine commande: `/sf-ready Text-Based Media Editing for Social Video`
