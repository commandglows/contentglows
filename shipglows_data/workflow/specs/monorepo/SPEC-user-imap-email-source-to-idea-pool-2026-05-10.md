---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: contentglows
created: "2026-05-10"
updated: "2026-05-10"
status: ready
source_skill: sf-build
scope: feature
owner: unknown
confidence: high
risk_level: high
security_impact: yes
docs_impact: yes
user_story: "En tant qu'utilisateur connecte de ContentGlows, je veux connecter une boite email IMAP et choisir le dossier lu afin que ContentGlows transforme automatiquement les nouveaux emails utiles en idees pour mon projet."
linked_systems:
  - app
  - lab
  - Gmail IMAP
  - UserProviderCredential
  - UserSettings.robotSettings
  - Idea Pool
depends_on:
  - artifact: "shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md"
    artifact_version: "unknown"
    required_status: ready
  - artifact: "shipglows_data/workflow/specs/lab/SPEC-newsletter-receiving.md"
    artifact_version: "unknown"
    required_status: draft
supersedes: []
evidence:
  - "lab/agents/newsletter/tools/imap_tools.py already implements IMAPNewsletterReader with env-backed credentials."
  - "lab/agents/sources/ingest.py ingests newsletters into source=passthrough newsletter_inbox but currently uses global env IMAP config."
  - "app/lib/presentation/screens/settings/integrations_screen.dart has no email integration UI."
next_step: "/sf-ship shipglows_data/workflow/specs/monorepo/SPEC-user-imap-email-source-to-idea-pool-2026-05-10.md"
---

# Spec: User IMAP Email Source To Idea Pool

## Objective

Recreate the missing user-facing email source flow so an authenticated ContentGlows user can connect an email inbox through IMAP, choose which mailbox folder/label is read, and let the backend automatically ingest useful emails into the Idea Pool as `newsletter_inbox` ideas every 6 hours.

## Product Contract

- The V1 connection method is IMAP with an app password. Composio remains out of the primary flow because it is paid and not needed for this use case.
- The app explains the practical requirement: for Gmail, the user must create a Gmail app password after enabling 2-step verification.
- The user configures:
  - email address
  - IMAP host, default `imap.gmail.com`
  - source folder/label, default `Newsletters`
  - processed/archive folder/label, default `CONTENTFLOW_DONE`
  - app password
  - target project, resolved from the active/default project
- The app can validate the connection without exposing the secret back to Flutter.
- Saving the source creates or updates a managed `ingest_newsletters` scheduler job.
- The scheduler checks the configured folder every 6 hours, extracts candidate ideas with the existing newsletter extractor/persona context, writes suitable ideas to the Idea Pool, and archives processed messages to the configured archive folder when possible.
- The user does not manually push emails to the Idea Pool from Settings.

## Scope In

- Backend per-user IMAP integration endpoints under `/api/settings/integrations/email-source`.
- Encrypted app-password storage using the existing `UserProviderCredential` table.
- Non-secret IMAP metadata stored in `UserSettings.robotSettings.emailSource`.
- Managed `schedule_jobs` row for recurring `ingest_newsletters` runs every 6 hours.
- IMAP reader support for explicitly passed user credentials and folders.
- Idea Pool newsletter ingestion updated to accept user-scoped IMAP config and user ownership.
- Flutter API client methods for status, upsert, validate, and delete.
- Minimal Flutter UI in Settings > Integrations for connecting email source and choosing folders.
- Tests for backend persistence/route contracts and ingestion user scoping where practical.

## Scope Out

- Gmail OAuth and `GmailToken` storage.
- Composio UI or paid managed connection flow.
- Full email body browser in V1.
- Sender preview in V1.
- User-triggered "send to Idea Pool" action in the app.
- Sending newsletters.
- Perfect duplicate detection beyond existing Idea Pool behavior.

## Security And Data Rules

- Never return the app password to the client.
- Store the app password only through the encrypted user-credential path.
- Keep email address, host, source folder, and archive folder as non-secret settings.
- Require authenticated user context for every route.
- Ingested ideas must be owned by `current_user.user_id`.
- Default source language should avoid claiming original authorship of source emails. The product may use emails for ideas and research, but generated content should transform and synthesize rather than copy long passages.

## Backend Contract

### `GET /api/settings/integrations/email-source`

Returns:

```json
{
  "configured": true,
  "email": "user@gmail.com",
  "host": "imap.gmail.com",
  "sourceFolder": "Newsletters",
  "archiveFolder": "CONTENTFLOW_DONE",
  "projectId": "project_123",
  "validationStatus": "valid",
  "lastValidatedAt": "2026-05-10T00:00:00",
  "updatedAt": "2026-05-10T00:00:00"
}
```

### `PUT /api/settings/integrations/email-source`

Request accepts `email`, `appPassword`, `host`, `sourceFolder`, `archiveFolder`, and optional `projectId`. The backend stores metadata/secrets and creates or updates the managed 6-hour ingestion job.

### `POST /api/settings/integrations/email-source/validate`

Attempts IMAP login and source-folder selection.

### `DELETE /api/settings/integrations/email-source`

Deletes stored secret and clears email source metadata.

### `POST /api/ideas/ingest/newsletters`

Uses the authenticated user's configured IMAP settings by default. This remains available as an API/manual backend trigger, but the app-facing flow relies on the scheduler job created by the email-source settings save.

## Acceptance Criteria

- Given an authenticated user stores a valid Gmail app password and IMAP metadata, when they validate, status becomes `valid`.
- Given an authenticated user saves an email source for an active project, a managed enabled `ingest_newsletters` schedule job exists for that user/project with `schedule="every_6_hours"`.
- Given the managed scheduler job runs, it reads the user's configured IMAP folder without using global env credentials.
- Given scheduled ingestion creates ideas, ideas are created with `source="newsletter_inbox"`, `user_id=current_user.user_id`, and the configured `project_id`.
- Given ingestion completes, processed emails are moved to the configured archive folder when IMAP supports it.
- Given no email source is configured, manual API ingestion returns a clear 409-style setup error and the scheduler skips user jobs without credentials.
- Flutter Settings > Integrations exposes a minimal email source panel with connect/update, validate, and delete controls only.
- Existing server-managed env IMAP behavior is not used for user-triggered app ingestion once per-user settings are present.
- Existing server-managed env IMAP behavior remains available only for legacy/system scheduler jobs.

## Validation Commands

```bash
cd lab && pytest tests/test_newsletter_router.py tests/test_settings_integrations_router.py
```

```bash
cd app && flutter test
```

## Current Chantier Flow

- sf-spec: done
- sf-ready: done
- sf-start: done
- sf-verify: done
- sf-end: done
- sf-ship: done

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-10 | sf-build | gpt-5 | create ready spec for user IMAP email source and begin implementation | implemented | /sf-start shipglows_data/workflow/specs/monorepo/SPEC-user-imap-email-source-to-idea-pool-2026-05-10.md |
| 2026-05-10 | sf-build | gpt-5 | implement per-user IMAP source, Flutter integration panel, Idea Pool ingestion, docs, and validation | partial (ship not run) | /sf-ship shipglows_data/workflow/specs/monorepo/SPEC-user-imap-email-source-to-idea-pool-2026-05-10.md |
| 2026-05-10 | sf-build | gpt-5 | revise email source to automatic 6-hour scheduler ingestion and remove user preview/manual ingest UI | implemented | /sf-ship shipglows_data/workflow/specs/monorepo/SPEC-user-imap-email-source-to-idea-pool-2026-05-10.md |
| 2026-05-10 | sf-ship | gpt-5 | quick ship email source automatic ingestion chantier trace | shipped | none |
