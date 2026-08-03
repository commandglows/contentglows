---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: app
created: "2026-05-24"
updated: "2026-05-24"
status: draft
source_skill: sf-docs
scope: platform-usage-clerk
owner: Diane
confidence: high
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - shipglows_data/technical/code-docs-map.md
  - shipglows_data/technical/app/architecture.md
  - shipglows_data/technical/flutter-app-shell-and-capture.md
  - web_auth/
  - lib/data/services/clerk_auth_service_web.dart
  - scripts/install-web-auth.sh
  - scripts/validate-clerk-runtime.sh
  - vercel.json
depends_on:
  - artifact: "shipglows_data/technical/external-platforms/clerk.md"
    artifact_version: "0.1.0"
    required_status: "draft"
supersedes: []
evidence:
  - "Contentglowz App uses a dedicated ClerkJS web runtime instead of the removed Flutter beta SDK path."
  - "Local auth routes and SPA rewrites are project-specific enough to justify a project usage note."
next_review: "2026-06-24"
next_step: "/sf-docs technical audit app"
---

# Clerk Project Usage

## Purpose

Document how Contentglowz App uses Clerk on web and Android. This is the
project-local auth contract. Use the global Clerk note for current Clerk source
links and SDK behavior.

## Usage Summary

- Provider role: session authority for authenticated Flutter app access.
- Environments used: local validation, Vercel preview, Vercel production.
- Validation surface: ClerkJS route runtime, Flutter session restore, FastAPI
  bearer-token calls, SPA/auth rewrites.
- Owner: Diane.
- Last verified: 2026-05-24 by documentation audit, without live auth retest.

## Local Configuration

| Item | Value or rule | Secret? | Notes |
| --- | --- | --- | --- |
| Publishable key | `CLERK_PUBLISHABLE_KEY` | key only | Compiled into the frontend bundle; do not record values. |
| API base URL | `API_BASE_URL` | no | Flutter sends authenticated FastAPI requests to this origin. |
| App web URL | `APP_WEB_URL` | no | Used by generated Clerk auth runtime pages. |
| Auth routes | `/sign-in`, `/sign-up`, `/sso-callback` | no | Must be routed to dedicated HTML pages, not the Flutter SPA entry. |
| Runtime bridge | `window.contentglowzClerkBridge` | no | Dart web auth service calls this bridge. |
| Token path | `clerk.session.getToken()` -> FastAPI bearer token | sensitive runtime value | Never log or store raw tokens in docs. |
| Android SDK | `com.clerk:clerk-android-api:1.0.36` | no | API-only; Flutter retains UI. |
| Android key | `CLERK_PUBLISHABLE_KEY` | key only | Environment or ignored Gradle property; never commit its value. |
| Android callback | `clerk://com.contentglowz.app.callback` | no | Clerk Android SDK's registered receiver handles this exact callback; allowlist it in Clerk and never retain its parameters. |

## Runtime And Integration Notes

- `web_auth/clerk-runtime.js.template` loads Clerk UI/runtime scripts from the
  frontend API derived from `CLERK_PUBLISHABLE_KEY`.
- `scripts/install-web-auth.sh` copies the auth HTML/CSS assets into
  `build/web` and renders `clerk-runtime.js` with build-time values.
- `lib/data/services/clerk_auth_service_web.dart` restores sessions through the
  bridge and forwards fresh tokens to the app API client.
- `vercel.json` must preserve rewrites for `/sign-in`, `/sign-up`, and
  `/sso-callback` before the catch-all SPA rewrite.
- Password auth through the old Flutter beta SDK is intentionally disabled on
  web production; use the dedicated ClerkJS auth routes.
- Android initializes Clerk once in `ContentGlowzApplication`. Its Kotlin
  MethodChannel owns Clerk's native OAuth launch in the system browser, session
  restore, fresh token retrieval, and sign-out. Clerk Android's own registered
  `SSOReceiverActivity` owns the `clerk://com.contentglowz.app.callback`
  callback handling;
  `clerk_auth_service_android.dart`
  only transports the active token in memory to Flutter.
- Google OAuth configuration is external: enable Clerk Native API, register
  the Android package in Clerk, allowlist `clerk://com.contentglowz.app.callback`,
  and enable the Google connection for sign-up and sign-in. Record neither
  keys nor fingerprints in this repository.

## Invariants

- Auth callback routes must not fall through to `/index.html`.
- `CLERK_PUBLISHABLE_KEY` must be present for auth-enabled web builds.
- The app must handle missing/expired Clerk sessions without exposing token
  values or silently losing queued user work.
- Flutter must obtain user identity and bearer tokens through the ClerkJS bridge,
  not by reintroducing the removed Clerk Flutter beta web path. Android instead
  obtains its token from Clerk Android and never shares a web session.
- Android OAuth callbacks are handled by Clerk's manifest-registered receiver
  for the exact `clerk://com.contentglowz.app.callback` scheme/host; Flutter
  never receives callback parameters.
- FastAPI remains the data authority; Clerk is only the session identity layer.

## Failure Modes

- Missing `CLERK_PUBLISHABLE_KEY` -> auth routes cannot be generated and
  `scripts/install-web-auth.sh` must fail.
- Missing `clerk-runtime.js` in `build/web` -> Dart bridge restore fails with a
  runtime error.
- Rewrites ordered incorrectly -> `/sign-in`, `/sign-up`, or `/sso-callback`
  return the Flutter SPA instead of the auth route.
- Clerk session restore loops -> check route guard behavior, backend bootstrap,
  and duplicate app-access refreshes.
- Token rejected by FastAPI -> validate backend Clerk/JWT settings before
  changing frontend auth state.

## Security Notes

- Do not store raw Clerk tokens, cookies, private account URLs, or provider logs
  in docs or task notes.
- `CLERK_PUBLISHABLE_KEY` is a publishable frontend key, but record only the
  variable name and environment location, not the value.
- Keep server-only auth verification and any sensitive JWT handling in FastAPI.

## Validation

```bash
./scripts/validate-clerk-runtime.sh
```

For hosted validation, use the Vercel preview/production URL and verify:

- `/sign-in`, `/sign-up`, and `/sso-callback` render ClerkJS auth pages.
- Sign-in redirects back into the Flutter app.
- Session restore survives page refresh.
- `/api/bootstrap` loads with the Clerk bearer token and does not bounce back to
  the entry/auth screen.

For Android, build with `-PcontentglowzAuthEnabled=true` and the key supplied
through CI/environment, then prove Google sign-in, cancellation, restart,
sign-out and FastAPI bootstrap on a configured physical device. Roll back by
shipping a build with the Android action disabled; never fall back to a token
or code in a browser URL.

## Reader Checklist

- `web_auth/**` changed -> review route assets, runtime bridge, and this note.
- `lib/data/services/clerk_auth_service*.dart` changed -> review token/session
  invariants and FastAPI bearer-token behavior.
- `vercel.json` rewrites changed -> verify auth route precedence before SPA
  fallback.
- Build scripts changed -> verify `CLERK_PUBLISHABLE_KEY`, `APP_WEB_URL`, and
  runtime asset injection.
- Clerk docs/releases changed -> compare against the global Clerk note before
  changing local auth behavior.

## Maintenance Rule

Update this note when auth routes, Clerk runtime loading, token/session
semantics, Vercel rewrites, validation scripts, or Clerk/FastAPI auth boundaries
change.
