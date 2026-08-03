---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: contentglowz
created: "2026-05-04"
updated: "2026-05-04"
status: draft
source_skill: sf-docs
scope: setup
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - site
  - app
  - lab
  - Flox
  - Turso
depends_on:
  - artifact: "app/.flox/env/manifest.toml"
    artifact_version: "unknown"
    required_status: active
  - artifact: "lab/.flox/env/manifest.toml"
    artifact_version: "unknown"
    required_status: active
  - artifact: "site/package.json"
    artifact_version: "1.0.0"
    required_status: active
supersedes: []
evidence:
  - "README.md"
  - "app/.flox/env/manifest.toml"
  - "lab/.flox/env/manifest.toml"
  - "site/package.json"
  - "lab/.env.example"
next_step: "Review after the next clean clone"
---

# Setup After Cloning ContentGlowz

This repository is a monorepo with three active surfaces:

- `site`: Astro marketing/auth handoff site.
- `app`: Flutter product app and web bundle.
- `lab`: FastAPI backend, agents, scheduler, and Turso-backed services.

## 1. Clone

```bash
git clone git@github.com:diane-defores/contentglowz.git
cd contentglowz
```

## 2. Install System Prerequisites

Install these once on the machine:

- Git
- Flox
- Node.js `22.x` with npm `11.x` for `site`

Flox owns the project-local Flutter, Python, Turso CLI, pytest, and audit tooling for the app/lab surfaces.

## 3. Marketing Site

```bash
cd site
npm install
npm run dev
```

Useful checks:

```bash
npm run build
npm run preview
```

## 4. Flutter App

```bash
cd app
flox activate --command 'flutter pub get'
```

Useful checks:

```bash
flox activate --command 'flutter analyze'
flox activate --command 'flutter test'
```

For local web builds, pass the frontend runtime values as Dart defines through the existing scripts:

```bash
API_BASE_URL=https://api.contentglowz.com \
CLERK_PUBLISHABLE_KEY=pk_test_xxx \
APP_SITE_URL=https://contentglowz.com \
APP_WEB_URL=https://app.contentglowz.com \
FEEDBACK_ADMIN_EMAILS=admin@contentglowz.com \
./build.sh --serve
```

Do not put server secrets such as `ZERNIO_API_KEY`, `LATE_API_KEY`, Turso database tokens, or provider API keys into Flutter build defines.

## 5. Backend Lab

```bash
cd lab
flox activate --command 'python3 --version'
```

On first activation, Flox creates `.flox/cache/python-venv` and installs the Python `libsql` package there because it is not available as a Flox package. The first run can take a few minutes on ARM64.

Useful checks:

```bash
flox activate --command 'python3 -m pytest tests/test_status_content_body.py'
flox activate --command 'pip-audit -r requirements.txt'
```

For API runtime secrets, use Doppler when available:

```bash
doppler setup
doppler run -- uvicorn api.main:app --reload --port 8000
```

Local fallback:

```bash
cd lab
cp .env.example .env
# Edit .env locally. Never commit it.
```

## 6. Turso CLI Install and Connection

`lab` installs the Turso CLI through its project-local Flox environment. After cloning, do not install Turso globally with curl for normal project work; activate the repo-managed CLI from `lab`:

```bash
cd lab
flox activate --command 'turso --version'
flox activate --command 'tursodb --version'
```

Expected tools:

- `turso`: Turso Cloud CLI used for auth, database listing, and schema checks.
- `tursodb`: local Turso/libSQL shell.

If those commands are missing, repair the project-local Flox manifest from `lab`:

```bash
flox install turso turso-cli
```

Use a Turso API token for CLI commands:

```bash
export TURSO_API_TOKEN='your_turso_api_token'
flox activate --command 'turso auth whoami'
```

Run the current schema proof:

```bash
flox activate --command 'turso db shell <prod-turso-db> "PRAGMA table_info(content_records); PRAGMA table_info(content_bodies); PRAGMA table_info(content_edits);"'
```

Do not commit `TURSO_API_TOKEN`.

Do not confuse:

- `TURSO_API_TOKEN`: CLI token used by `turso db ...`, `turso auth whoami`, and other Turso Cloud commands.
- `TURSO_AUTH_TOKEN`: database runtime token used by the FastAPI app together with `TURSO_DATABASE_URL`.

## 7. Android APK CI

The Android release APK is a CI-owned build path. Do not run Android release
builds on this VM: the local environment is reserved for analysis, tests, and
web/lab work, and Android release builds are routed to x64 CI to avoid unstable
or crashing local toolchain behavior.

`.github/workflows/android-apk.yml` currently does two different things on the
Blacksmith runner label `blacksmith-4vcpu-ubuntu-2404`:

- on `push` and `pull_request`: Flutter checks only (`flutter analyze` and `flutter test`)
- on `workflow_dispatch`: the release APK build, then upload of the
  `contentglowz-android-apk` artifact

Treat GitHub Actions as the only approved place for Android release APK output.

Repository or organization prerequisite:

- Install and enable the Blacksmith GitHub app for the repository that receives pushes.

Optional GitHub Actions configuration:

- `CLERK_PUBLISHABLE_KEY` secret: compiled into the APK for the production Clerk flow.
- `API_BASE_URL`, `APP_SITE_URL`, and `APP_WEB_URL` repository variables: override the default runtime URLs if needed.

Useful CLI commands:

```bash
gh run list --workflow android-apk.yml --limit 5
gh run view <run-id> --log
gh run download <run-id> -n contentglowz-android-apk -D ./artifacts/android
adb install -r ./artifacts/android/app-release.apk
```

Operational rule:

- local VM: `flutter analyze`, `flutter test`, and bounded non-release checks only
- GitHub Actions + Blacksmith: release APK build and artifact production
- if documentation or notes still imply "build Android locally", treat them as stale

## 8. Fast Sanity Checklist

From a clean clone, these commands should be enough to prove the local toolchains are usable:

```bash
cd site
npm install
npm run build
```

```bash
cd app
flox activate --command 'flutter pub get'
flox activate --command 'flutter analyze'
```

```bash
cd lab
flox activate --command 'python3 -m pytest tests/test_status_content_body.py'
flox activate --command 'pip-audit -r requirements.txt'
```

Run Turso checks only after exporting `TURSO_API_TOKEN`.
