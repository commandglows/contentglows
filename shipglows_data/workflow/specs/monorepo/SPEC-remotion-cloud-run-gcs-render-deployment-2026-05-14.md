---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglowz"
created: "2026-05-14"
created_at: "2026-05-14 20:30:29 UTC"
updated: "2026-05-14"
updated_at: "2026-05-14 21:17:45 UTC"
status: active
source_skill: sf-spec
source_model: "GPT-5 Codex"
scope: "deployment"
owner: "Diane"
confidence: "high"
user_story: "En tant que creatrice ContentGlowz authentifiee, je veux que les previews et rendus finaux de la timeline video soient produits par un renderer Remotion durable sur Google Cloud, afin de pouvoir obtenir des MP4 fiables hors machine locale sans exposer les secrets, les chemins de stockage ou les artefacts d'autres utilisateurs."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "lab"
  - "worker"
  - "app"
  - "Google Cloud Run"
  - "Google Cloud Storage"
  - "Artifact Registry"
  - "Turso/libSQL JobStore and video timeline store"
  - "Clerk auth"
  - "Remotion renderer"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-unified-contentglowz-video-timeline-2026-05-14.md"
    artifact_version: "0.1.0"
    required_status: "partial; local implementation verified, production durable renderer proof missing"
  - artifact: "shipglows_data/workflow/specs/monorepo/remotion-render-service-integration.md"
    artifact_version: "unknown"
    required_status: "implemented locally; production storage/deploy extension required"
  - artifact: "worker/README.md"
    artifact_version: "unknown"
    required_status: "reviewed"
  - artifact: "lab/README.md"
    artifact_version: "unknown"
    required_status: "reviewed"
  - artifact: "Remotion Cloud Run official setup/checklist/light-client docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official; Cloud Run package marked alpha and not actively developed"
  - artifact: "Google Cloud Run container/runtime/service identity docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
  - artifact: "Google Cloud Storage signed URL docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
  - artifact: "Firebase Cloud Functions version comparison docs"
    artifact_version: "accessed 2026-05-14"
    required_status: "official"
supersedes: []
evidence:
  - "sf-verify 2026-05-14: local timeline backend, Flutter UI and Remotion worker proof pass, but Cloud Run/GCS or equivalent production render-service proof is missing."
  - "sf-build 2026-05-14: explicitly blocked sf-end/sf-ship because no deployed preview -> approve -> final E2E proof exists."
  - "worker currently stores artifacts under CONTENTFLOW_RENDER_DIR and keeps worker job state in memory."
  - "lab currently resolves completed artifacts by checking local files via CONTENTFLOW_RENDER_DIR and then returns API-signed local artifact URLs."
  - "worker already exposes token-protected /renders, /renders/:workerJobId and DELETE endpoints plus /health."
  - "Remotion official docs accessed 2026-05-14: @remotion/cloudrun exists but is Alpha and not actively being developed, so this spec should not make it the primary production dependency."
  - "Remotion official Cloud Run checklist accessed 2026-05-14: production needs explicit memory, file-size, permissions, concurrency, instance limit, rate limit, timeout and license review."
  - "Google Cloud Run official docs accessed 2026-05-14: service containers must listen on 0.0.0.0:$PORT, request timeout applies, filesystem writes are in-memory and not persistent."
  - "Google Cloud service identity docs accessed 2026-05-14: Cloud Run services use service accounts as principals for Google APIs and should be granted only required roles."
  - "Google Cloud Storage signed URL docs accessed 2026-05-14: signed URLs provide time-limited access and include auth data in query parameters."
  - "Firebase official docs accessed 2026-05-14: Cloud Functions 2nd gen runs on Cloud Run, but this renderer is a long-running browser/FFmpeg service and should be deployed as a Cloud Run service unless a later event wrapper is needed."
  - "sf-ready 2026-05-14: first readiness pass was not ready until worker/GCS reconciliation and IAM/secrets/signing semantics were made deterministic."
next_step: "Deploy Cloud Run worker and run production GCS E2E proof"
---

## Title

Remotion Cloud Run GCS Render Deployment

## Status

Partial local implementation complete after targeted readiness correction. This spec is the production-readiness child chantier for the unified ContentGlowz video timeline. It does not replace the timeline model, Flutter editor, backend timeline API or Remotion composition. The local code now supports a deployable Cloud Run worker path with GCS artifact metadata and backend-signed playback URLs, but real Cloud Run deployment and private GCS E2E proof are still missing.

## User Story

En tant que creatrice ContentGlowz authentifiee, je veux que les previews et rendus finaux de la timeline video soient produits par un renderer Remotion durable sur Google Cloud, afin de pouvoir obtenir des MP4 fiables hors machine locale sans exposer les secrets, les chemins de stockage ou les artefacts d'autres utilisateurs.

## Minimal Behavior Contract

Depuis une timeline video ContentGlowz valide et versionnee, le backend peut demander une preview ou un rendu final a un service Remotion deploye sur Google Cloud Run, stocker le MP4 termine dans un bucket Google Cloud Storage prive, puis retourner a Flutter uniquement un statut pollable et une URL de lecture signee de courte duree pour l'utilisateur autorise. Si Cloud Run, Remotion, GCS, l'auth worker, la signature d'URL, la capacite ou la configuration echoue, le job devient observable comme recoverable ou failed sans perdre la timeline, sans annoncer un artefact pret, et sans exposer token, chemin local, bucket interne ou media d'un autre projet. L'edge case facile a rater est le stockage local: sur Cloud Run, le filesystem du conteneur n'est pas durable; un rendu ne doit donc jamais dependre de `CONTENTFLOW_RENDER_DIR` comme source de verite production.

## Success Behavior

- Given un utilisateur Clerk authentifie possede une version timeline valide, when il demande une preview, then `lab` cree un job preview, appelle le worker Cloud Run avec un token serveur, et retourne un statut `queued` ou `in_progress` sans exposer l'URL Cloud Run ni les secrets.
- Given le worker Cloud Run termine un rendu, when `lab` poll le job, then le backend recupere des metadata d'artefact GCS privees, persiste `artifact_path`, taille, mime type, retention et `worker_job_id`, puis retourne une `artifact.playback_url` signee courte.
- Given la preview terminee est approuvee pour la version courante, when l'utilisateur demande un final render, then le final job est distinct, reference la meme version et le preview job approuve, et produit un MP4 GCS separe.
- Given l'URL signee expire, when Flutter rafraichit le job, then le backend regenere une URL signee si le job et l'utilisateur sont toujours autorises.
- Given le worker Cloud Run redemarre apres avoir termine un rendu, when le backend repoll le job and worker memory no longer knows the job, then the backend checks the deterministic expected GCS object key persisted before dispatch. If that object exists, the backend reconstructs completed artifact metadata from GCS; if it does not exist, the job becomes failed with a sanitized `render_artifact_unavailable` message.
- Given les controles de capacite sont atteints, when un rendu supplementaire est demande, then le backend retourne `429` avec `Retry-After: 60` et aucun nouveau render couteux n'est lance.
- Proof of success is a deployed Cloud Run worker health check, a private GCS object for preview and final renders, short-lived signed playback URLs generated by the backend, an E2E deployed preview -> approve -> final flow, and passing backend/worker tests for local and GCS storage modes.

## Error Behavior

- Missing, invalid or expired Clerk auth returns `401`; no render job, Cloud Run call or GCS object is created.
- Missing, invalid or mismatched `REMOTION_WORKER_URL`, `REMOTION_WORKER_TOKEN`, `GCS_RENDER_BUCKET`, service account permissions or signing capability returns `503`/failed job with sanitized configuration language only.
- Cloud Run `401`, `403`, `404`, `429`, `5xx`, timeout or network failure marks the job failed or temporarily unavailable according to existing retry semantics; Flutter sees a recoverable render status, not raw worker logs.
- GCS upload failure, signed URL failure, missing object, empty MP4, wrong content type or unsafe object key marks the job failed and never returns a playback URL.
- If a job is completed in worker memory but GCS upload metadata is absent, the backend treats the job as failed instead of claiming success.
- If the worker returns `404` for a previously dispatched job, the backend does not trust worker memory as authority. It checks the expected GCS object key persisted before dispatch. If the object exists and belongs to the job's expected render mode/prefix, it reconstructs completed artifact metadata from the object; otherwise it marks the job failed as `render_artifact_unavailable`.
- If a signed URL leaks into diagnostics or error bodies, tests must fail; query tokens are response-only browser handles, never durable authority.
- If Remotion render exceeds 180 seconds timeline duration, props size, Cloud Run timeout, memory, disk or instance limits, the system rejects before dispatch when possible or records a sanitized worker failure.
- If Cloud Run deploy is unavailable in the target GCP project or Remotion licensing blocks cloud rendering, implementation stops before shipping and records the production blocker.
- What must never happen: public bucket-by-default playback, client-supplied object keys, Flutter calling Cloud Run directly, worker token in app/site logs, local file paths returned as production artifact authority, cross-user artifact access, or final render created from stale preview.

## Problem

The unified video timeline now works locally, including backend asset resolution, Flutter editing, worker tests and an MP4 smoke render. It still cannot ship because production rendering is not durable: the worker stores job state in memory and writes MP4s to local disk, while `lab` serves artifacts by reading `CONTENTFLOW_RENDER_DIR`. Google Cloud Run containers can lose local filesystem state when instances stop, so local render storage is not a production artifact boundary.

There is also a product-boundary decision: Remotion's official Cloud Run package exists, but current official docs mark it Alpha and not actively developed. ContentGlowz should keep using mature Remotion renderer APIs inside its own worker container, deploy that worker to Cloud Run, and use GCS as the durable artifact store.

## Solution

Add a production storage/deployment layer to `worker` and `lab`: containerize the worker for Cloud Run, add a GCS-backed artifact store behind the existing local storage helper, return GCS object metadata to the backend, generate short-lived backend-signed playback URLs from `lab`, and document/deploy a Cloud Run service with least-privilege service accounts. Keep Flutter unchanged except for consuming the same existing job responses.

## Scope In

- Add a production-ready worker container definition for `worker`.
- Keep Remotion rendering inside the existing Node/Express worker using `@remotion/renderer`, `@remotion/bundler`, `selectComposition()` and `renderMedia()`.
- Add a storage abstraction in the worker with `local` and `gcs` modes.
- Add GCS upload support for completed preview/final MP4s, including safe object keys and retention metadata.
- Return GCS artifact metadata from worker to `lab` without returning signed URLs from the worker.
- Update `lab` artifact handling so timeline and reels render jobs can sign GCS playback URLs through backend-owned auth.
- Preserve existing local artifact token route for local development and tests.
- Add Cloud Run deployment scripts or docs for build, Artifact Registry image, Cloud Run service, env vars, health check and rollout.
- Use a dedicated Cloud Run service account with minimal GCS object permissions and no broad Editor role.
- Add an explicit IAM/secrets matrix covering the worker service account, backend service account, deployer identity, Cloud Run invoker and secret storage.
- Keep Cloud Run service private or effectively server-only; `lab` remains the only caller.
- Add tests for worker GCS key safety, upload metadata, backend GCS signed URL generation, missing object, expired URL refresh and token redaction.
- Add a deployed E2E checklist: timeline preview, approve, final render, playback URL refresh, worker restart/redeploy resilience.
- Update README/runbooks/changelog for local vs production render modes.

## Scope Out

- Replacing the ContentGlowz timeline model, timeline API or Flutter editor.
- Migrating all project assets from Bunny to GCS. Timeline source assets may remain Bunny/render-safe in this chantier.
- Using Remotion Timeline or Editor Starter UI.
- Making Flutter call Cloud Run or GCS directly.
- Building a custom renderer, codec stack or FFmpeg distribution from scratch.
- Implementing queue systems such as Cloud Tasks, Pub/Sub or Workflows unless a simple HTTP Cloud Run service cannot meet reliability during implementation.
- Using `@remotion/cloudrun` as the primary path while its own official docs mark it Alpha/not actively developed. It may be referenced only as documentation/inspiration or a later spike.
- Adding social publishing or platform uploads for final MP4s.
- Multi-region active-active rendering, GPU rendering, or large-duration professional video workloads beyond the existing 180-second V1 limit.
- Public bucket hosting or Cloud CDN for private user render artifacts.

## Constraints

- `lab` remains the public authenticated API boundary; worker/GCS are internal infrastructure.
- Cloud Run worker must listen on `0.0.0.0:$PORT`; hardcoded `127.0.0.1` or fixed local-only ports are invalid for production.
- Cloud Run local filesystem is not durable. Production completion requires a GCS object, not a local MP4 path.
- Worker auth still uses `REMOTION_WORKER_TOKEN` or stronger server-to-server auth. The token must never reach Flutter, web, logs or API responses.
- GCS buckets must be private by default. Browser playback uses signed URLs generated only after backend ownership checks.
- Signed URL query parameters are secrets. Diagnostics and app logs must redact them.
- Artifact object keys must be server-generated from job id/render mode and validated against path traversal, extension spoofing and cross-project access.
- Backend capacity limits still apply before dispatch: max one active render per user, max three active renders globally in local mode unless production config explicitly changes limits.
- Timeline duration remains <= 180 seconds, 30fps, supported presets only.
- Remotion package versions in the worker must stay pinned consistently; implementation must not mix mismatched Remotion package versions.
- Cloud Run and GCS configuration must be environment-driven and documented. Missing env vars fail closed.
- IAM must be least-privilege and identity-specific: worker writes render objects, backend reads/signs playback objects, deployer deploys services/images, and only backend or an approved service identity invokes the private worker.
- GCS signed URLs must be produced without committed service-account key files. Preferred path is backend service identity plus IAM `signBlob` capability; a JSON key file is a stop condition unless the user explicitly accepts that security tradeoff in a separate decision.
- Remotion commercial/cloud rendering license must be reviewed before production rollout if the organization crosses the relevant threshold.

## Dependencies

- Local worker package: `worker/package.json` with Remotion `4.0.458`, Express `5.1.0`, TypeScript `5.8.2`.
- Existing worker endpoints: `GET /health`, `POST /renders`, `GET /renders/:workerJobId`, `DELETE /renders/:workerJobId`.
- Existing backend worker client: `lab/api/services/remotion_render_client.py`.
- Existing backend renderer adapter: `lab/api/services/video_renderer_adapter.py`.
- Existing local artifact token helpers: `lab/api/services/render_artifact_tokens.py`.
- Existing timeline artifact routes: `lab/api/routers/video_timelines.py`.
- Existing reels artifact routes: `lab/api/routers/reel_renders.py`.
- Required new worker dependency: `@google-cloud/storage` pinned in `worker/package.json`.
- Required GCP services: Cloud Run service, Artifact Registry image, Cloud Storage bucket, IAM service account.
- Fresh external docs checked:
  - `fresh-docs checked`: Remotion Cloud Run setup docs at `https://www.remotion.dev/docs/cloudrun/setup`; docs mark Cloud Run support Alpha/not actively developed and describe service/site/render flow.
  - `fresh-docs checked`: Remotion Cloud Run production checklist at `https://www.remotion.dev/docs/cloudrun/checklist`; memory, file size, permissions, concurrency, instance limit, rate limiting, timeout and license need explicit review.
  - `fresh-docs checked`: Remotion Cloud Run light client at `https://www.remotion.dev/docs/cloudrun/light-client`; client APIs must not be called from browsers because credentials would leak.
  - `fresh-docs checked`: Google Cloud Run container runtime contract at `https://docs.cloud.google.com/run/docs/container-contract`; services must listen on `0.0.0.0:$PORT`, request timeout applies, and filesystem writes are not persistent.
  - `fresh-docs checked`: Google Cloud Run service identity docs at `https://docs.cloud.google.com/run/docs/configuring/services/service-identity`; service identity needs only roles required for called Google APIs.
  - `fresh-docs checked`: Google Cloud Storage signed URLs at `https://docs.cloud.google.com/storage/docs/access-control/signed-urls`; signed URLs are time-limited and include auth data in query parameters.
  - `fresh-docs checked`: Firebase Functions version comparison at `https://firebase.google.com/docs/functions/version-comparison`; 2nd gen functions run on Cloud Run, but this spec uses a direct Cloud Run service for renderer control.

## Invariants

- Timeline/version state stays in `lab` stores, not in the worker or GCS.
- Job identity is generated and owned by `lab`; worker cannot invent user/project ownership.
- Worker returns artifact metadata, never user-facing playback authority.
- Backend signs playback URLs only after verifying user, job, timeline/content and artifact ownership.
- Backend persisted artifact metadata plus GCS object existence are the completion authority after worker completion. Worker in-memory state is useful for progress only and cannot be the only authority after restart.
- The expected artifact provider and object key are generated by `lab` before dispatch and persisted on the job as `expected_artifact`. Worker completion enriches this into final artifact metadata; backend reconciliation may reconstruct final metadata from `expected_artifact` plus GCS object attributes.
- Local development continues to work without GCS by setting storage mode to `local`.
- Production mode cannot silently fall back to local disk when GCS env vars are missing.
- A completed job without a readable GCS object is not completed from the user's perspective.
- Preview and final artifacts remain distinct and cannot overwrite each other.
- Final render still requires the exact current version's approved preview.

## Links & Consequences

- `worker/server/render-storage.ts` must evolve from local filesystem helpers into a pluggable artifact store.
- `worker/server/index.ts` must initialize Cloud Run-compatible port/health/storage config and report storage mode safely.
- `lab/api/routers/video_timelines.py` and `lab/api/routers/reel_renders.py` must stop assuming completed artifacts are local files when artifact metadata indicates GCS.
- `lab/api/models/video_timeline.py` and `lab/api/models/reel_render.py` may need artifact model fields for provider/object key while keeping response shape stable for Flutter.
- `app` should not need API contract changes if `artifact.playback_url` remains the response field; app diagnostics redaction remains part of verification.
- Existing tests that assert local artifact path safety must remain valid in local mode.
- Deployment scripts/docs introduce GCP IAM and billing consequences; they must be explicit enough to avoid over-broad service accounts.
- Observability must distinguish worker unavailable, GCS upload failed, GCS object missing, signed URL failed, Remotion render failed and capacity exhausted.

## IAM and Secrets Matrix

| Identity | Runtime owner | Required permissions | Forbidden permissions | Secrets/config source |
| --- | --- | --- | --- | --- |
| `contentglowz-remotion-worker@PROJECT_ID.iam.gserviceaccount.com` | Cloud Run worker service | Write completed MP4 objects under the configured bucket/prefix; read/delete only its own temporary/render-prefix objects if cleanup is enabled; write structured logs | Project Editor/Owner, broad Storage Admin outside the render bucket, service account key creation, public bucket ACL mutation, direct access to user databases | Cloud Run env/secrets: `REMOTION_WORKER_TOKEN`, `CONTENTFLOW_RENDER_STORAGE=gcs`, `GCS_RENDER_BUCKET`, `GCS_RENDER_PREFIX`, `RENDER_ARTIFACT_RETENTION_DAYS`, optional `REMOTION_SERVE_URL` |
| `contentglowz-lab-api@PROJECT_ID.iam.gserviceaccount.com` | `lab` API runtime | Invoke private worker service; read/check render objects; generate signed URLs for render objects via service identity/IAM signing; read runtime secrets needed by backend | Storage object write/delete unless explicitly required by later cleanup spec, Project Editor/Owner, downloaded key-file dependency | Backend env/secrets: `REMOTION_WORKER_URL`, `REMOTION_WORKER_TOKEN`, `GCS_RENDER_BUCKET`, `GCS_RENDER_PREFIX`, `GCS_SIGNED_URL_TTL_SECONDS`, `RENDER_ARTIFACT_SIGNING_KEY` for local mode only |
| `contentglowz-deployer@PROJECT_ID.iam.gserviceaccount.com` or human deployer group | CI/operator deploy path | Build/push Artifact Registry images, deploy/update the worker Cloud Run service, set env/secrets, assign the worker service account | Runtime data access beyond deployment needs, broad bucket object read of user artifacts unless explicitly audited | CI secret store or operator auth, not committed files |
| Cloud Run invoker principal for worker | `lab` service identity or authenticated internal caller | `run.invoker` on the worker service only | `allUsers` public invocation, browser/client invocation, broad project invocation grants | IAM binding, not an app secret |
| Secret manager/admin operator | Security/operator only | Create/update worker token and deployment secrets | Reading user artifacts by default, committing secret values | Secret Manager or existing secret platform; values redacted in docs/logs |

Implementation must map these logical identities to actual GCP project ids and names in the deployment runbook. If the project uses a different existing service account, the runbook must state the exact equivalent permissions and why it is not broader than this matrix.

## Documentation Coherence

- Update `worker/README.md` with production Cloud Run/GCS env vars, Docker build/run, health check, local vs GCS storage modes, and smoke commands.
- Update `lab/README.md` with production render artifact flow, required env vars, GCS signed URL behavior and deployment E2E checklist.
- Add `worker/DEPLOYMENT.md` or `docs/technical/remotion-cloud-run-gcs.md` if command/runbook length would overload the README.
- Update `CHANGELOG.md`, `lab/CHANGELOG.md` and worker docs/changelog if present.
- Record that Remotion official Cloud Run package is Alpha/not actively developed; ContentGlowz uses its own Cloud Run worker container.
- Include a short operator note: signed playback URLs are bearer-like secrets and must not be copied into support tickets with query strings.

## Edge Cases

- Cloud Run instance completes a render, then restarts before backend polls; GCS object must still prove completion.
- Backend polls a worker job that is unknown after worker restart: if the job's persisted `expected_artifact` points to an existing valid GCS object, reconstruct completion metadata and return the completed artifact; otherwise mark the job failed with `render_artifact_unavailable`.
- GCS upload succeeds but backend update fails; next poll should reconcile or remain safely failed without duplicate final artifacts.
- User requests final render while preview is completed but not approved for exact version.
- Cloud Run request timeout occurs while render continues or is killed.
- GCS signed URL expires while Flutter player is open.
- Bucket object key includes encoded traversal, non-MP4 extension, unexpected render mode or wrong job id.
- Service account lacks object create/read/sign permissions.
- Worker has multiple Cloud Run instances and in-memory job maps are not shared.
- Render job is cancelled while upload is in progress.
- Remotion bundle startup is slow and Cloud Run health check or cold start times out.
- Production env accidentally sets `CONTENTFLOW_RENDER_STORAGE=local`.
- Logs contain `X-Goog-Signature`, `token=`, `Authorization`, `REMOTION_WORKER_TOKEN` or bucket object paths that reveal user data.

## Implementation Tasks

- [x] Tache 1 : Decide and codify production render architecture.
  - Fichier : `shipglows_data/workflow/specs/monorepo/SPEC-remotion-cloud-run-gcs-render-deployment-2026-05-14.md`
  - Action : During readiness, confirm this spec's architecture: own Cloud Run service + GCS storage; do not use `@remotion/cloudrun` as primary because official docs mark it Alpha/not actively developed.
  - User story link : Prevents the app from depending on an unstable renderer deployment abstraction.
  - Depends on : None.
  - Validate with : `/sf-ready Remotion Cloud Run GCS render deployment`.
  - Notes : If readiness finds a stronger current official recommendation, revise before implementation.

- [x] Tache 1.5 : Codify IAM and reconciliation rules in docs/tests.
  - Fichier : `worker/DEPLOYMENT.md`
  - Action : Encode the IAM/secrets matrix and deterministic worker-restart reconciliation rule from this spec before implementation changes depend on them.
  - User story link : Prevents unsafe production permissions and ambiguous completed-job behavior.
  - Depends on : Tache 1.
  - Validate with : docs review and focused tests named in Taches 7, 10 and 11.
  - Notes : If real GCP identity names differ, map them explicitly without broadening permissions.

- [x] Tache 2 : Add worker production dependencies and env schema.
  - Fichier : `worker/package.json`
  - Action : Add pinned `@google-cloud/storage`, scripts for production start if needed, and document/validate env vars: `CONTENTFLOW_RENDER_STORAGE=local|gcs`, `GCS_RENDER_BUCKET`, `GCS_RENDER_PREFIX`, `GCS_SIGNED_URL_TTL_SECONDS`, `RENDER_ARTIFACT_RETENTION_DAYS`, `REMOTION_WORKER_TOKEN`, `REMOTION_SERVE_URL`.
  - User story link : Gives the worker a durable production storage mode.
  - Depends on : Tache 1.
  - Validate with : `npm install`, `npm run lint`, focused env tests.
  - Notes : Do not use broad dotenv secrets in committed files.

- [x] Tache 3 : Add Cloud Run container files.
  - Fichier : `worker/Dockerfile`
  - Action : Create a production Dockerfile that installs worker dependencies, builds/checks TypeScript if needed, includes Remotion/Chromium runtime requirements, starts `npm run start`, and listens on Cloud Run's `PORT`.
  - User story link : Makes the renderer deployable outside local development.
  - Depends on : Tache 2.
  - Validate with : `docker build` if Docker is available, otherwise documented build command plus CI/build fallback.
  - Notes : If Remotion/Chromium needs system packages, install explicitly and keep image size reasonable.

- [x] Tache 4 : Extract artifact storage interface.
  - Fichier : `worker/server/render-storage.ts`
  - Action : Refactor local path helpers into an interface that supports local and GCS implementations while preserving existing path safety behavior.
  - User story link : Prevents production from relying on Cloud Run local disk.
  - Depends on : Tache 2.
  - Validate with : `npm run test:storage`.
  - Notes : Keep local mode default for dev/test unless production env explicitly selects GCS.

- [x] Tache 5 : Implement GCS artifact storage.
  - Fichier : `worker/server/gcs-render-storage.ts`
  - Action : Upload completed MP4s to a private GCS bucket with safe object keys like `<prefix>/<renderMode>/<jobId>.mp4`, record metadata, and optionally delete temp local files after successful upload.
  - User story link : Makes completed previews/finals durable across worker restarts.
  - Depends on : Tache 4.
  - Validate with : unit tests using a fake Storage client; optional integration test behind explicit env vars.
  - Notes : Object keys are server-generated only; no client paths.

- [x] Tache 6 : Wire worker storage mode into render completion.
  - Fichier : `worker/server/index.ts`
  - Action : Use the storage interface when render completes, return artifact metadata including provider `gcs`, bucket/object key or normalized artifact path, size, mime, retention and render mode.
  - User story link : Lets backend poll completed Cloud Run renders without local file access.
  - Depends on : Tache 5.
  - Validate with : worker storage tests and timeline smoke render in local mode.
  - Notes : Health response may expose storage mode but not bucket object secrets.

- [x] Tache 7 : Add worker tests for GCS mode.
  - Fichier : `worker/server/gcs-render-storage.test.ts`
  - Action : Cover object key safety, metadata shape, upload error handling, retention metadata, invalid bucket/prefix config and no signed URL leakage.
  - User story link : Proves production artifact safety before deployment.
  - Depends on : Tache 5.
  - Validate with : `tsx --test server/gcs-render-storage.test.ts`.
  - Notes : Use fakes/mocks; do not require real GCP credentials in normal tests.

- [x] Tache 8 : Add backend artifact provider model.
  - Fichier : `lab/api/services/render_artifacts.py`
  - Action : Introduce a shared artifact service that generates deterministic expected artifact descriptors before dispatch, supports local token URLs and GCS signed URLs, and can reconcile completed GCS artifacts from expected object keys.
  - User story link : Keeps Flutter response stable while backend storage changes.
  - Depends on : Tache 6.
  - Validate with : unit tests for local and GCS artifact payloads.
  - Notes : This service should centralize query-token redaction helpers if needed.

- [x] Tache 9 : Update backend worker artifact normalization.
  - Fichier : `lab/api/services/video_renderer_adapter.py`
  - Action : Normalize worker GCS metadata into backend artifact JSON without requiring local file existence.
  - User story link : Allows timeline jobs to complete from Cloud Run/GCS artifacts.
  - Depends on : Tache 8.
  - Validate with : backend adapter tests using fake worker payloads.
  - Notes : Preserve local worker payload compatibility.

- [x] Tache 10 : Update timeline artifact route/signing.
  - Fichier : `lab/api/routers/video_timelines.py`
  - Action : Generate `artifact.playback_url` via shared artifact service; local artifacts use existing HMAC route, GCS artifacts use GCS signed URL after ownership validation.
  - User story link : Lets users play timeline preview/final MP4s from durable storage.
  - Depends on : Tache 8 and Tache 9.
  - Validate with : `pytest lab/tests/test_video_timelines_router.py` plus new GCS signed URL cases.
  - Notes : Do not return bucket name/object key unless needed in sanitized operator-only metadata.

- [x] Tache 11 : Update reels artifact route/signing.
  - Fichier : `lab/api/routers/reel_renders.py`
  - Action : Use the same shared artifact service for reels render jobs so old and new render paths share production artifact behavior.
  - User story link : Prevents two render storage implementations from diverging.
  - Depends on : Tache 8.
  - Validate with : `pytest lab/tests/test_reel_renders.py`.
  - Notes : Keep existing local artifact endpoint tests.

- [x] Tache 12 : Add backend GCS storage dependency/config.
  - Fichier : `lab/requirements.lock`
  - Action : Add or confirm `google-cloud-storage` dependency and env-driven config for signed URL generation, bucket, TTL and credentials through service identity.
  - User story link : Lets backend sign playback URLs without exposing service credentials.
  - Depends on : Tache 8.
  - Validate with : import/pytest checks and docs.
  - Notes : `requirements.txt` and `requirements.lock` now include `google-cloud-storage`; production should still use Cloud Run service identity / ADC over downloaded service account keys.

- [x] Tache 13 : Add deployment scripts/runbook.
  - Fichier : `worker/DEPLOYMENT.md`
  - Action : Document GCP project prerequisites, Artifact Registry image build/push, Cloud Run deploy command, service account roles, env vars, health check, rollback and smoke checks.
  - User story link : Makes deployment repeatable and auditable.
  - Depends on : Tache 3 and Tache 5.
  - Validate with : docs review and a dry-run command list.
  - Notes : Include least-privilege roles and explicitly reject public bucket access.

- [ ] Tache 14 : Add production E2E verification script.
  - Fichier : `scripts/qa_video_timeline_render_e2e.md`
  - Action : Add a manual or scripted checklist for deployed timeline preview -> poll -> approve -> final -> poll -> playback URL refresh, including expected API statuses and failure captures.
  - User story link : Provides the missing proof that blocked previous ship.
  - Depends on : Tache 10 and Tache 13.
  - Validate with : Execute against deployed API/worker and record evidence in `shipglows_data/workflow/verification/`.
  - Notes : Avoid storing signed URLs with query strings in evidence.

- [x] Tache 15 : Update docs and changelog.
  - Fichier : `lab/README.md`
  - Action : Document production render storage mode, GCS signed URL behavior, required env vars and local/prod differences; update worker README and changelogs.
  - User story link : Makes operators understand how MP4 previews/finals work in production.
  - Depends on : Tache 8 through Tache 14.
  - Validate with : docs review and `/sf-verify`.
  - Notes : Mention Remotion license/cloud rendering review.

- [ ] Tache 16 : Run full local and deployed verification.
  - Fichier : `shipglows_data/workflow/verification/remotion-cloud-run-gcs-render-deployment-2026-05-14.md`
  - Action : Record local tests, worker smoke render, Cloud Run health, GCS object evidence, API poll evidence and playback URL refresh proof.
  - User story link : Converts the local implementation from partial to shippable.
  - Depends on : Tache 14 and Tache 15.
  - Validate with : `/sf-verify Remotion Cloud Run GCS render deployment`.
  - Notes : This task is required before `/sf-end` and `/sf-ship`.

## Acceptance Criteria

- [ ] CA 1 : Given production env sets `CONTENTFLOW_RENDER_STORAGE=gcs`, when the worker starts on Cloud Run, then `/health` returns ok without exposing secrets and the service listens on Cloud Run's `PORT`.
- [ ] CA 2 : Given production env lacks `GCS_RENDER_BUCKET`, when the worker starts in GCS mode, then startup fails closed and no local-disk production fallback occurs.
- [ ] CA 3 : Given a valid preview job is created by `lab`, when the backend calls the Cloud Run worker, then the request uses server-side auth and Flutter never receives the worker URL or token.
- [ ] CA 4 : Given a render completes, when the worker stores the MP4, then a private GCS object exists at a server-generated safe key and local temp files are not the durable source of truth.
- [ ] CA 5 : Given the backend polls a completed GCS-backed job, when ownership checks pass, then the API returns `artifact.playback_url` as a short-lived signed URL and no bucket/object credentials leak.
- [ ] CA 6 : Given the signed playback URL expires, when Flutter refreshes job status, then the backend generates a fresh signed URL for the same owned artifact.
- [ ] CA 7 : Given another user or project asks for a job artifact, when the backend checks ownership, then it returns `404`/`403` without revealing object keys or render status.
- [ ] CA 8 : Given GCS upload fails after Remotion render succeeds locally, when the job is polled, then the job is failed or recoverable and no completed artifact is advertised.
- [ ] CA 9 : Given Cloud Run worker restarts after a completed render and the worker returns unknown job, when the job has a persisted deterministic expected GCS object key and that object exists, then the API reconstructs completed artifact metadata and returns a fresh signed playback URL.
- [ ] CA 9b : Given Cloud Run worker returns unknown job and the expected GCS object does not exist or does not match the job's expected provider/prefix/mode, when the backend refreshes the job, then it marks the job failed with sanitized `render_artifact_unavailable` and returns no playback URL.
- [ ] CA 10 : Given capacity limits are reached, when a new preview/final is requested, then the backend returns `429` with `Retry-After: 60` before dispatching Cloud Run work.
- [ ] CA 11 : Given the object key contains traversal, wrong extension, wrong render mode, encoded separators or mismatched job id, when worker/backend validates it, then the object is rejected and no signed URL is generated.
- [ ] CA 12 : Given Cloud Run returns `401`, `403`, timeout or `5xx`, when backend dispatches or polls, then the job state remains observable with sanitized message and no raw worker response leaks.
- [ ] CA 13 : Given the timeline draft changes after preview, when final render is requested, then existing version/preview gates still block stale final render independent of Cloud Run/GCS storage.
- [ ] CA 14 : Given production deployment is configured, when the E2E checklist runs, then preview -> approve -> final produces two distinct GCS MP4 objects and both can be played through backend-signed URLs.
- [ ] CA 15 : Given diagnostics capture API errors or job payloads, when they include signed URLs, then query tokens are redacted in app and backend/worker logs.
- [ ] CA 16 : Given local development runs without GCS env vars, when local worker tests and smoke render run, then local mode still passes existing storage and timeline tests.

## Test Strategy

- Worker unit tests for storage mode config, local path compatibility, GCS object key validation, fake upload metadata, upload failure and no signed URL leakage.
- Worker integration smoke: `npm run lint`, `npm run test:storage`, GCS tests, `npm run test:timeline`, local `npx remotion render` MP4 smoke.
- Backend unit tests for shared artifact service: local HMAC route payload, GCS signed URL payload, missing env, missing object, wrong provider and redaction.
- Backend router tests for timeline and reels completed job responses in both local and GCS modes.
- Backend security tests for cross-user artifact access and unsafe object keys.
- Backend reconciliation tests for worker `404`/unknown job with a valid persisted expected GCS object key versus missing/mismatched object.
- IAM/runbook review verifying worker, backend, deployer and invoker identities match the least-privilege matrix.
- Deployment checks: Cloud Run `/health`, authenticated `/renders` rejection without token, successful backend-dispatched render, GCS private object existence.
- Manual deployed E2E: create/open `/editor/:id/video`, save clean version, request preview, poll completed, approve, request final, poll completed, refresh playback URL after expiry or forced low TTL.
- Regression checks: existing Flutter analyze/tests, backend timeline/reel tests, worker tests and audit.

## Risks

- Cloud Run timeout/memory risk: Remotion rendering can exceed default settings. Mitigation: explicit timeout/memory config, 180-second V1 duration limit, smoke tests and production checklist.
- Artifact durability risk: local disk works in smoke tests but is unsafe on Cloud Run. Mitigation: production GCS mode must fail closed and E2E proof must inspect GCS.
- Security risk: signed URLs and worker tokens are bearer-like secrets. Mitigation: backend-only signing, redaction tests, private bucket and no Flutter worker access.
- IAM risk: broad service account permissions increase blast radius. Mitigation: dedicated service accounts and minimal Storage/Run roles.
- State consistency risk: worker memory does not survive restarts. Mitigation: GCS artifact authority plus backend job store; document reconciliation rule.
- Cost abuse risk: video renders can consume Cloud Run/GCS budget. Mitigation: keep backend capacity limits and explicit preview actions.
- Remotion Cloud Run package risk: official package is Alpha/not actively developed. Mitigation: deploy own worker container using mature Remotion renderer APIs.
- License risk: cloud rendering may require commercial seats depending on company size/use. Mitigation: explicit license review before production rollout.
- Deployment drift risk: local and Cloud Run envs diverge. Mitigation: runbook, env schema tests, health output and verification artifact.

## Execution Notes

- Read first:
  - `worker/server/index.ts`
  - `worker/server/render-storage.ts`
  - `lab/api/services/remotion_render_client.py`
  - `lab/api/services/video_renderer_adapter.py`
  - `lab/api/routers/video_timelines.py`
  - `lab/api/routers/reel_renders.py`
  - `worker/README.md`
- Implementation order: worker storage abstraction -> GCS implementation/tests -> backend artifact service -> router/model updates -> deployment files/docs -> local checks -> deployed E2E.
- Do not introduce `@remotion/cloudrun` as the main renderer dependency unless readiness explicitly revises this spec; official docs currently warn it is Alpha/not actively developed.
- Prefer Cloud Run service over Firebase Functions for the renderer because the worker is an HTTP service with browser/FFmpeg runtime, larger memory/timeout needs and explicit container concerns. Firebase Functions 2nd gen may remain a future event wrapper, not the renderer process.
- Prefer service identity / Application Default Credentials over downloaded service account keys.
- If Docker is unavailable locally, implementation may still add Dockerfile/runbook and validate with npm/backend tests, but `/sf-verify` remains partial until a real Cloud Run deploy proof exists.
- Suggested validation commands:
  - `npm --prefix worker run lint`
  - `npm --prefix worker run test:storage`
  - `npm --prefix worker run test:timeline`
  - `tsx --test worker/server/gcs-render-storage.test.ts`
  - `python3 -m pytest lab/tests/test_video_timelines_router.py lab/tests/test_reel_renders.py`
  - `flutter analyze` and targeted timeline tests if app response fields change
  - Cloud Run health and deployed E2E checklist from Tache 14
- Stop conditions:
  - GCP billing/project/permissions unavailable.
  - Remotion license blocks cloud rendering.
  - Cloud Run cannot satisfy render timeout/memory for 180-second V1 videos.
  - GCS signed URL generation cannot be done without unsafe key files.
  - IAM cannot be made at least as narrow as the matrix in this spec.
  - Implementation would require Flutter to call Cloud Run/GCS directly.

## Open Questions

None blocking for the spec. Default decisions:

- Production renderer target: custom `worker` deployed as Cloud Run service.
- Durable artifact store: private Google Cloud Storage bucket.
- Playback authority: backend-generated short-lived GCS signed URLs after ownership checks.
- Firebase Functions: not the renderer process in V1; may be used later only as a wrapper/event trigger if a separate need appears.
- `@remotion/cloudrun`: not primary because current official docs mark it Alpha/not actively developed.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-14 20:30:29 UTC | sf-spec | GPT-5 Codex | Created production renderer deployment spec from partial timeline verification, local worker/backend inspection, and fresh Remotion/Google/Firebase official docs | draft saved | /sf-ready Remotion Cloud Run GCS render deployment |
| 2026-05-14 20:52:37 UTC | sf-build | GPT-5 Codex with GPT-5.5 readiness review | Resolved readiness blockers by adding deterministic worker-restart/GCS reconciliation and explicit IAM/secrets/signing matrix | rerouted; spec corrected for readiness | /sf-ready Remotion Cloud Run GCS render deployment |
| 2026-05-14 20:55:10 UTC | sf-build | GPT-5 Codex with GPT-5.5 readiness review | Removed remaining reconciliation ambiguity by requiring backend to persist deterministic expected artifact keys before worker dispatch | rerouted; spec corrected for readiness | /sf-ready Remotion Cloud Run GCS render deployment |
| 2026-05-14 20:56:00 UTC | sf-ready | GPT-5.5 readiness review | Rechecked readiness blockers after deterministic expected artifact key correction | ready | /sf-start Remotion Cloud Run GCS render deployment |
| 2026-05-14 21:05:17 UTC | sf-build | GPT-5 Codex | Implemented local worker GCS storage, backend artifact signing/reconciliation path, Docker/runbook/docs, and focused tests | partial; local checks passed, production deploy proof missing | Deploy Cloud Run worker and run production GCS E2E proof |
| 2026-05-14 21:14:17 UTC | sf-build | GPT-5 Codex with read-only sf-verify review | Closed local verification blockers: regenerated Python lock, persisted expected GCS artifact before timeline dispatch, rejected GCS mismatch, streamed uploads, sanitized worker render failures, reran focused checks | partial; local blockers resolved, production deploy proof missing | Deploy Cloud Run worker and run production GCS E2E proof |
| 2026-05-14 21:17:45 UTC | sf-ship | GPT-5 Codex | Shipped local Remotion Cloud Run/GCS renderer foundation for iteration and moved production proof work into TASKS.md | shipped partial | Deploy Cloud Run worker and run production GCS E2E proof |

## Current Chantier Flow

- sf-spec: done
- sf-ready: done
- sf-start: done (local implementation)
- sf-verify: partial (local checks passed; production proof missing)
- sf-end: not launched
- sf-ship: shipped partial
- Prochaine commande: deploy Cloud Run worker and run production GCS E2E proof
