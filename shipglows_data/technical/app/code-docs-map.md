---
artifact: code_docs_map
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: app
created: "2026-05-06"
updated: "2026-05-24"
status: draft
source_skill: sf-docs
scope: code-docs-map
owner: Diane
confidence: medium
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - lib/
  - android/
  - test/
  - pubspec.yaml
  - web_auth/
  - vercel.json
  - scripts/
depends_on:
  - artifact: "shipglows_data/technical/flutter-app-shell-and-capture.md"
    artifact_version: "0.1.0"
    required_status: draft
supersedes: []
evidence:
  - "Baseline map created after metadata compliance audit found no technical governance layer for app."
  - "Project-local platform notes added only for Clerk and Vercel because local auth/deploy behavior affects validation and production proof."
next_review: "2026-06-06"
next_step: "/sf-docs technical audit app"
---

# Code Docs Map

Use this map before editing Flutter routing, provider state, API/offline services, Android native capture, or app validation flows.

| Code path | Primary doc | Coverage | Reader trigger |
| --- | --- | --- | --- |
| `lib/main.dart` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | App bootstrapping and provider scope | Any boot, diagnostics, environment, or initialization change |
| `lib/router.dart` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | Guarded navigation and onboarding/demo routes | Any route, auth gate, resume, or app handoff change |
| `lib/providers/providers.dart` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | Riverpod state graph, pending content, projects, and offline state | Any provider contract, cache, queue, or user state change |
| `lib/data/services/api_service.dart` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | FastAPI calls, offline queue, content body, and capture asset API methods | Any API payload, retry, queue, auth, or content asset change |
| `lib/data/models/email_source.dart` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | Email source status and validation result parsing | Any email-source API payload or UI status contract change |
| `lib/presentation/screens/settings/integrations_screen.dart` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | Integration settings UI including AI runtime, OpenRouter, GitHub, automatic email source setup, and publishing channels | Any settings integration control, credential UX, or connection action change |
| `lib/data/services/capture_local_store.dart` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | Local capture history and capture/content links | Any capture persistence, deletion, migration, or link-state change |
| `lib/data/services/clerk_auth_service*.dart`, `web_auth/**`, `scripts/install-web-auth.sh`, `scripts/validate-clerk-runtime.sh` | `shipglows_data/technical/platforms/clerk.md` | ClerkJS auth routes, web runtime bridge, session restore, and FastAPI bearer-token handoff | Any Clerk route, auth bridge, token/session, auth runtime, or validation-script change |
| `vercel.json`, `scripts/vercel-*.sh` | `shipglows_data/technical/platforms/vercel.md` | Vercel Flutter web build, Dart defines, output routing, preview/production proof, and auth rewrite coupling | Any Vercel build, deploy, env-var, output-directory, rewrite, preview, or production-validation change |
| `android/app/src/main/kotlin/**` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | Android native screen capture bridge and permissions | Any MediaProjection, foreground service, or platform-channel change |
| `test/**` | `shipglows_data/technical/flutter-app-shell-and-capture.md` | Flutter regression coverage | Any test harness, fixture, onboarding, navigation, capture, or offline-sync validation change |

## Platform Usage Policy

Do not create a project-local platform note for every dependency. Current local
notes are limited to providers whose project-specific behavior changes agent
decisions or proof routes:

- `shipglows_data/technical/platforms/clerk.md`
- `shipglows_data/technical/platforms/vercel.md`

Flutter, Riverpod, GoRouter, Dio, SharedPreferences, Sentry, OpenRouter, Google
Search Console, GitHub, IMAP/email source, and standard Android surfaces do not
need standalone platform notes by default. Create a note only when a task changes
OAuth, secrets handling, scopes, SDK/API contract, storage, migrations,
observability, compliance, production proof, or local provider exceptions.

## Non-Coverage

- `build/` and generated Flutter output are not covered as source of truth; regenerate them from source when needed.

## Documentation Update Plan Format

```text
Documentation Update Plan:
- Status: complete | no impact | pending final integration | blocked
- Impacted docs:
  - shipglows_data/technical/<doc>.md: <required update or no change>
- Reason:
  - <why the docs are or are not current>
```

## Maintenance Rule

Update this map when covered files move, new Flutter/Android surfaces are introduced, or validation responsibilities change.
