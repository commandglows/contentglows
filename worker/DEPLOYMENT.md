# Remotion Cloud Run + GCS Deployment

ContentGlows deploys its own Remotion worker container to Cloud Run. Do not use `@remotion/cloudrun` as the primary deployment path for this worker; the current Remotion docs mark that package alpha/not actively developed.

## Runtime Contract

- Cloud Run service: private HTTP service running `worker`.
- Durable artifacts: private Google Cloud Storage bucket.
- Public auth boundary: `lab` only.
- Playback: `lab` signs short-lived GCS URLs after ownership checks.
- Worker output: artifact metadata only; never signed URLs.

## Required Env

Worker Cloud Run env/secrets:

- `REMOTION_WORKER_TOKEN`: server-to-server bearer token.
- `CONTENTGLOWS_RENDER_STORAGE=gcs`: production storage mode.
- `GCS_RENDER_BUCKET`: private render bucket.
- `GCS_RENDER_PREFIX`: object prefix, usually `renders`.
- `RENDER_ARTIFACT_RETENTION_DAYS`: default `30`.
- `REMOTION_SERVE_URL`: optional prebuilt Remotion bundle URL.

Backend env/secrets:

- `REMOTION_WORKER_URL`: private Cloud Run worker URL.
- `REMOTION_WORKER_TOKEN`: same secret value as worker.
- `CONTENTGLOWS_RENDER_STORAGE=gcs`.
- `GCS_RENDER_BUCKET`.
- `GCS_RENDER_PREFIX`.
- `GCS_SIGNED_URL_TTL_SECONDS`: default `3600`.

Local development can keep `CONTENTGLOWS_RENDER_STORAGE=local` or omit it. Production must not fall back to local disk.

## IAM Matrix

Use concrete project-specific names, but keep these permission boundaries:

- Worker service account: write completed MP4 objects under the configured bucket/prefix. No Project Editor/Owner, no public ACL changes, no broad bucket admin.
- Backend service account: invoke the private worker, read/check render objects, and sign URLs through service identity/IAM signing. No broad object write/delete.
- Deployer identity: build/push Artifact Registry images and deploy Cloud Run. No runtime artifact read by default.
- Cloud Run invoker: grant only the backend service identity, never `allUsers`.
- Secret operator: create/update secrets without committing values.

## Build And Deploy

Example commands, replacing project/region/name values:

```bash
gcloud artifacts repositories create contentglows --repository-format=docker --location=europe-west1
gcloud builds submit worker \
  --tag europe-west1-docker.pkg.dev/PROJECT_ID/contentglows/remotion-worker:latest
gcloud run deploy contentglows-remotion-worker \
  --image europe-west1-docker.pkg.dev/PROJECT_ID/contentglows/remotion-worker:latest \
  --region europe-west1 \
  --service-account contentglows-remotion-worker@PROJECT_ID.iam.gserviceaccount.com \
  --no-allow-unauthenticated \
  --memory 4Gi \
  --cpu 2 \
  --timeout 900 \
  --concurrency 1 \
  --set-env-vars CONTENTGLOWS_RENDER_STORAGE=gcs,GCS_RENDER_BUCKET=BUCKET_NAME,GCS_RENDER_PREFIX=renders
```

Set `REMOTION_WORKER_TOKEN` as a Cloud Run secret/env secret rather than a literal command-line value.

## Smoke Checks

1. `GET /health` returns `{"status":"ok","storageProvider":"gcs"}` and no bucket/object secrets.
2. `POST /renders` without `Authorization` returns `401`.
3. A backend-dispatched preview creates `renders/previews/<jobId>.mp4` in the private bucket.
4. Polling the backend job returns an `artifact.playback_url` signed by the backend.
5. Approving preview and requesting final creates a separate `renders/finals/<jobId>.mp4`.

Do not paste signed URLs with query strings into tickets or logs. Treat `X-Goog-Signature`, `token=`, and `Authorization` values as bearer secrets.
