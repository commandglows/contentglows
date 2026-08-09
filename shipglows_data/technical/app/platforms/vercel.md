---
artifact: technical_module_context
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: app
created: "2026-05-24"
updated: "2026-08-09"
status: draft
source_skill: sf-docs
scope: platform-usage-vercel
owner: Diane
confidence: high
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - shipglows_data/technical/app/code-docs-map.md
  - shipglows_data/technical/app/architecture.md
  - shipglows_data/technical/app/platforms/clerk.md
  - vercel.json
  - scripts/vercel-install.sh
  - scripts/vercel-build.sh
  - scripts/install-web-auth.sh
  - scripts/validate-clerk-runtime.sh
depends_on:
  - artifact: "shipglows_data/technical/external-platforms/vercel.md"
    artifact_version: "0.1.0"
    required_status: "draft"
supersedes: []
evidence:
  - "ContentGlows App uses a custom Flutter web build on Vercel with explicit install/build scripts."
  - "Vercel rewrites are coupled to ClerkJS auth routes and SPA fallback behavior."
next_review: "2026-06-24"
next_step: "/sf-docs technical audit app"
---

# Vercel Project Usage

## Purpose

Document how ContentGlows App deploys the Flutter web app on Vercel. This is
the project-local deployment contract. Use the global Vercel note for current
Vercel source links, CLI behavior, and platform semantics.

## Usage Summary

- Provider role: hosted Flutter web deployment for preview and production.
- Environments used: Vercel preview and production; local validation can emulate
  the web build and Clerk runtime.
- Validation surface: custom install/build scripts, `build/web` output,
  ClerkJS route rewrites, SPA fallback, Dart defines, hosted preview/prod proof.
- Owner: Diane.
- Last verified: 2026-05-24 by documentation audit, without hosted deploy retest.

## Local Configuration

| Item | Value or rule | Secret? | Notes |
| --- | --- | --- | --- |
| Vercel config | `vercel.json` | no | `framework: null`, output `build/web`. |
| Install command | `bash ./scripts/vercel-install.sh` | no | Downloads/enables Flutter web in the build environment. |
| Build command | `bash ./scripts/vercel-build.sh` | no | Runs `flutter build web --release` with Dart defines. |
| Output directory | `build/web` | no | Also receives generated ClerkJS auth route assets. |
| Auth rewrites | `/sign-in`, `/sign-up`, `/sso-callback` before `/(.*)` | no | Required for Clerk route pages. |
| Required env var keys | `API_BASE_URL`, `CLERK_PUBLISHABLE_KEY` | keys only | Record names only, never values. |
| Optional env var keys | `APP_SITE_URL`, `APP_WEB_URL`, `SENTRY_*`, build metadata | keys only | Used for runtime metadata and observability. |

## Runtime And Integration Notes

- `scripts/vercel-build.sh` injects runtime values via `--dart-define`.
- `CLERK_PUBLISHABLE_KEY` is intentionally compiled into the frontend bundle,
  but the value must not be recorded in docs.
- `scripts/install-web-auth.sh` runs after the Flutter build and writes ClerkJS
  route assets into `build/web`.
- `vercel.json` uses explicit auth-route rewrites before the catch-all SPA
  rewrite so Clerk callbacks do not render the Flutter entry document.
- If Doppler or another secret manager feeds Vercel, required public/frontend
  variables must be exposed to the correct Vercel environment before build.

## Invariants

- Vercel must build from the app repo with Flutter web enabled and output
  `build/web`.
- The catch-all rewrite must remain last.
- Missing `CLERK_PUBLISHABLE_KEY` must fail auth asset generation rather than
  shipping a broken auth runtime.
- `API_BASE_URL` must point to the intended FastAPI environment for the Vercel
  target.
- Hosted auth/callback or deployment-routing proof requires preview/production
  validation, not only local Flutter checks.

## Failure Modes

- Flutter SDK unavailable in Vercel -> check `scripts/vercel-install.sh`, cache
  paths, and Vercel build logs.
- Build succeeds but auth pages fail -> check `scripts/install-web-auth.sh`,
  `CLERK_PUBLISHABLE_KEY`, and auth rewrites.
- Preview points at the wrong backend -> check `API_BASE_URL` for that Vercel
  environment.
- Sentry release/environment mismatches -> check `SENTRY_*` Dart defines and
  Vercel build metadata.
- SPA refresh 404 or wrong page -> check `outputDirectory` and rewrite order.

## Security Notes

- Do not record Vercel tokens, Doppler secrets, private deployment URLs, raw
  build logs containing env values, or Clerk token/cookie output.
- Record environment variable keys and validation routes only.
- Treat build logs as potentially sensitive when Dart defines include provider
  configuration.

## Validation

```bash
flutter analyze
flutter test
CLERK_PUBLISHABLE_KEY=<redacted> ./scripts/validate-clerk-runtime.sh
```

For hosted proof, use Vercel preview/production evidence:

- build completed with `build/web` output
- `/sign-in`, `/sign-up`, and `/sso-callback` route to generated auth pages
- SPA routes refresh without 404
- authenticated `/api/bootstrap` succeeds against the intended FastAPI backend

## Reader Checklist

- `vercel.json` changed -> review output directory, build/install commands, and
  rewrite order.
- `scripts/vercel-*.sh` changed -> review Flutter install/build assumptions,
  Dart defines, and cache behavior.
- `scripts/install-web-auth.sh` or `web_auth/**` changed -> review both this
  note and `platforms/clerk.md`.
- Vercel env vars or deployment target changed -> verify `API_BASE_URL`,
  `CLERK_PUBLISHABLE_KEY`, `APP_WEB_URL`, and hosted proof expectations.
- Vercel docs/releases changed -> compare against the global Vercel note before
  changing deployment behavior.

## Maintenance Rule

Update this note when Vercel config, build/install scripts, output routing,
environment variables, hosted proof expectations, or Clerk/Vercel coupling
changes.
