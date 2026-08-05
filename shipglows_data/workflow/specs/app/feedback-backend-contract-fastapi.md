---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-04-25"
updated: "2026-04-27"
status: ready
source_skill: sf-docs
scope: feature
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
user_story: "En tant qu'utilisateur, je veux pouvoir envoyer du feedback texte/audio et, en tant qu'admin autorise, consulter et traiter ce feedback depuis l'app."
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs audit shipglows_data/workflow/specs/app/feedback-backend-contract-fastapi.md"
---
# Feedback Backend Contract for ContentGlows

## Scope

This contract matches the Flutter client currently wired in `lib/data/services/api_service.dart`.

The frontend expects a FastAPI backend behind `API_BASE_URL`, authenticated with Clerk bearer tokens when present.

The feature must support:

- text feedback from authenticated users
- text feedback from anonymous users
- audio feedback with pre-signed upload flow
- in-app admin listing and filtering
- mark-as-reviewed action

## Environment

Required backend env vars:

- `FEEDBACK_ADMIN_EMAILS`
  comma-separated allowlist of lowercase admin emails
- storage credentials needed to generate a pre-signed upload URL

Optional frontend env var already added:

- `FEEDBACK_ADMIN_EMAILS`
  used only to hide/show the admin entry point in the UI

Server-side allowlist remains the source of truth.

## Auth Rules

### Public submission routes

These routes must accept:

- authenticated requests with a valid Clerk bearer token
- anonymous requests with no token

If a valid Clerk token is present, the backend should enrich the stored row with:

- `userId`
- `userEmail`

If there is no valid auth context, the row must still be accepted and stored with:

- `userId = null`
- `userEmail = null`

### Admin routes

These routes must require:

- a valid authenticated Clerk user
- a normalized email present in `FEEDBACK_ADMIN_EMAILS`

If auth is missing or invalid:

- return `401`

If auth is valid but email is not allowlisted:

- return `403`

## Data Model

Suggested database table: `feedback_entries`

Fields:

- `id: string`
- `type: "text" | "audio"`
- `message: string | null`
- `audio_storage_id: string | null`
- `audio_url: string | null`
- `duration_ms: integer | null`
- `platform: string`
- `locale: string`
- `user_id: string | null`
- `user_email: string | null`
- `status: "new" | "reviewed"`
- `created_at: datetime`
- `reviewed_at: datetime | null`
- `reviewed_by_user_id: string | null`
- `reviewed_by_email: string | null`

Indexes:

- `(created_at desc)`
- `(status, created_at desc)`
- `(type, created_at desc)`

## Response Shape

The frontend parser accepts either camelCase or snake_case. Standardize on camelCase for new routes.

### FeedbackEntry

```json
{
  "id": "fb_01hsz7z4m9",
  "type": "audio",
  "message": null,
  "audioStorageId": "feedback/2026/04/fb_01hsz7z4m9.wav",
  "audioUrl": "https://cdn.example.com/feedback/2026/04/fb_01hsz7z4m9.wav",
  "durationMs": 18400,
  "platform": "web",
  "locale": "fr-FR",
  "userId": "user_2vYx...",
  "userEmail": "admin@contentglows.app",
  "status": "new",
  "createdAt": "2026-04-19T15:42:31.123Z"
}
```

## Endpoints

### `POST /api/feedback/text`

Purpose:

- create a text feedback entry

Auth:

- optional

Request body:

```json
{
  "message": "Le flow onboarding bloque sur mobile.",
  "platform": "web",
  "locale": "fr-FR",
  "userEmail": "optional-client-hint@example.com"
}
```

Rules:

- `message` required, trimmed, max 5000 chars
- ignore client `userEmail` if authenticated context is present
- if anonymous, either ignore `userEmail` completely or only keep it if you explicitly want unauthenticated email hints
- set `type = "text"`
- set `status = "new"`

Success response: `200` or `201`

```json
{
  "id": "fb_01hsz7z4m9",
  "type": "text",
  "message": "Le flow onboarding bloque sur mobile.",
  "audioStorageId": null,
  "audioUrl": null,
  "durationMs": null,
  "platform": "web",
  "locale": "fr-FR",
  "userId": null,
  "userEmail": null,
  "status": "new",
  "createdAt": "2026-04-19T15:42:31.123Z"
}
```

Errors:

- `400` invalid payload
- `413` message too large
- `500` persistence failure

### `POST /api/feedback/audio/upload-url`

Purpose:

- create a pre-signed upload target for one audio file

Auth:

- optional

Request body:

```json
{
  "mimeType": "audio/wav",
  "fileName": "feedback-1713541351000.wav"
}
```

Rules:

- only allow expected MIME types for v1, ideally `audio/wav`
- generate a storage key and return a direct upload URL
- the storage key returned here becomes `audioStorageId`

Success response:

```json
{
  "uploadUrl": "https://storage.example.com/presigned-put-url",
  "storageId": "feedback/2026/04/19/fb_01hsz7z4m9.wav",
  "method": "PUT",
  "headers": {
    "Content-Type": "audio/wav"
  }
}
```

Errors:

- `400` unsupported MIME type
- `500` failed to generate upload URL

### `POST /api/feedback/audio`

Purpose:

- finalize an audio feedback entry after the client uploaded the file

Auth:

- optional

Request body:

```json
{
  "audioStorageId": "feedback/2026/04/19/fb_01hsz7z4m9.wav",
  "durationMs": 18400,
  "platform": "web",
  "locale": "fr-FR",
  "userEmail": "optional-client-hint@example.com"
}
```

Rules:

- verify the referenced object exists or is plausibly present in storage
- derive a public or signed playback URL into `audioUrl`
- set `type = "audio"`
- `durationMs` required, must be `> 0`
- `message = null`
- `status = "new"`

Success response:

```json
{
  "id": "fb_01hsz7z4m9",
  "type": "audio",
  "message": null,
  "audioStorageId": "feedback/2026/04/19/fb_01hsz7z4m9.wav",
  "audioUrl": "https://cdn.example.com/feedback/2026/04/19/fb_01hsz7z4m9.wav",
  "durationMs": 18400,
  "platform": "web",
  "locale": "fr-FR",
  "userId": "user_2vYx...",
  "userEmail": "admin@contentglows.app",
  "status": "new",
  "createdAt": "2026-04-19T15:42:31.123Z"
}
```

Errors:

- `400` invalid payload
- `404` upload object not found
- `409` upload target expired or already consumed if you enforce one-shot semantics
- `500` finalize failure

### `GET /api/feedback/admin`

Purpose:

- list feedback entries for the in-app admin view

Auth:

- required admin

Query params:

- `status`: optional, one of `new`, `reviewed`
- `type`: optional, one of `text`, `audio`

Examples:

- `/api/feedback/admin`
- `/api/feedback/admin?status=new`
- `/api/feedback/admin?type=audio`
- `/api/feedback/admin?status=new&type=text`

Success response:

```json
{
  "items": [
    {
      "id": "fb_01hsz7z4m9",
      "type": "audio",
      "message": null,
      "audioStorageId": "feedback/2026/04/19/fb_01hsz7z4m9.wav",
      "audioUrl": "https://cdn.example.com/feedback/2026/04/19/fb_01hsz7z4m9.wav",
      "durationMs": 18400,
      "platform": "web",
      "locale": "fr-FR",
      "userId": "user_2vYx...",
      "userEmail": "admin@contentglows.app",
      "status": "new",
      "createdAt": "2026-04-19T15:42:31.123Z"
    }
  ]
}
```

Rules:

- sort newest first
- cap v1 page size if needed, but if you paginate later, add `cursor` explicitly and update the frontend
- always include `audioUrl` for audio rows if playback should work in admin

Errors:

- `401` unauthenticated
- `403` authenticated but not allowlisted

### `POST /api/feedback/admin/{feedback_id}/review`

Purpose:

- mark one feedback entry as reviewed

Auth:

- required admin

Path param:

- `feedback_id`

Request body:

- empty body is fine for v1

Success response:

```json
{
  "ok": true,
  "id": "fb_01hsz7z4m9",
  "status": "reviewed",
  "reviewedAt": "2026-04-19T16:10:05.000Z"
}
```

Rules:

- idempotent: calling twice should still return success
- set:
  - `status = "reviewed"`
  - `reviewed_at = now`
  - `reviewed_by_user_id`
  - `reviewed_by_email`

Errors:

- `401` unauthenticated
- `403` authenticated but not allowlisted
- `404` feedback not found

## Backend Validation Notes

Normalize before storage:

- `platform = lowercase(trim(platform))`
- `locale = trim(locale)`
- `user_email = lowercase(trim(user_email))`

Recommended guardrails:

- reject empty text messages after trim
- reject audio finalize calls with missing `audioStorageId`
- reject unsupported MIME types at upload-url stage
- ensure the generated playback URL is readable by the app runtime

## Suggested FastAPI Pydantic Models

```python
class FeedbackTextCreate(BaseModel):
    message: constr(min_length=1, max_length=5000)
    platform: constr(min_length=1, max_length=32)
    locale: constr(min_length=1, max_length=32)
    userEmail: EmailStr | None = None

class FeedbackAudioUploadUrlRequest(BaseModel):
    mimeType: str
    fileName: str

class FeedbackAudioCreate(BaseModel):
    audioStorageId: constr(min_length=1, max_length=512)
    durationMs: conint(gt=0, le=15 * 60 * 1000)
    platform: constr(min_length=1, max_length=32)
    locale: constr(min_length=1, max_length=32)
    userEmail: EmailStr | None = None
```

## Suggested Admin Helper

```python
def require_feedback_admin(user: ClerkUser) -> ClerkUser:
    allowed = {
        email.strip().lower()
        for email in os.getenv("FEEDBACK_ADMIN_EMAILS", "").split(",")
        if email.strip()
    }
    email = (user.email or "").strip().lower()
    if not email:
        raise HTTPException(status_code=403, detail="Missing authenticated email")
    if email not in allowed:
        raise HTTPException(status_code=403, detail="Feedback admin access denied")
    return user
```

## End-to-End Scenarios

### Authenticated text feedback

1. client calls `POST /api/feedback/text` with Clerk bearer token
2. backend stores entry with `userId` and `userEmail`
3. admin list returns that row with status `new`

### Anonymous text feedback

1. client calls `POST /api/feedback/text` with no auth
2. backend stores entry with null identity
3. admin list returns `userEmail = null`

### Audio feedback

1. client requests upload target from `POST /api/feedback/audio/upload-url`
2. client uploads WAV bytes directly to returned `uploadUrl`
3. client calls `POST /api/feedback/audio`
4. backend verifies storage object and stores row with `audioUrl`
5. admin list can play back the audio

### Forbidden admin access

1. signed-in user not in allowlist calls `GET /api/feedback/admin`
2. backend returns `403`

## Non-Goals for v1

- email notifications
- retro-migration of old local-only feedback
- separate web backoffice
- pagination/infinite scroll unless volume requires it immediately
