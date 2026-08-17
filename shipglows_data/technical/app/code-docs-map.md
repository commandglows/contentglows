---
artifact: code_docs_map
metadata_schema_version: "1.0"
artifact_version: "0.4.0"
project: app
created: "2026-05-06"
updated: "2026-08-09"
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
  - artifact: "shipglows_data/technical/app/flutter-app-shell-and-capture.md"
    artifact_version: "0.2.0"
    required_status: draft
supersedes: []
evidence:
  - "Baseline map created after metadata compliance audit found no technical governance layer for app."
  - "Project-local platform notes added only for Clerk and Vercel because local auth/deploy behavior affects validation and production proof."
next_review: "2026-09-09"
next_step: "/sf-docs technical audit app"
---

# Code Docs Map

Use this map before editing Flutter routing, provider state, API/offline services, Android native capture, or app validation flows.

| Code path | Primary doc | Coverage | Reader trigger |
| --- | --- | --- | --- |
| `lib/main.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | App bootstrapping and provider scope | Any boot, diagnostics, environment, or initialization change |
| `lib/router.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Guarded navigation and onboarding/demo routes | Any route, auth gate, resume, or app handoff change |
| `lib/providers/providers.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Riverpod state graph, pending content, projects, offline state, and project-scoped brand profiles | Any provider contract, cache, queue, user state, or brand-profile mutation change |
| `lib/data/services/api_service.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | FastAPI calls, offline queue, content body, capture asset API methods, and canonical branded-generation requests | Any API payload, retry, queue, auth, content asset, or brand-generation change |
| `lib/data/models/email_source.dart`, `lib/data/models/brand_profile.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Email-source and brand-profile API payload parsing | Any source/profile API payload or UI status contract change |
| `lib/data/models/affiliate_link.dart`, `lib/data/models/link_click.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Affiliate link, click telemetry, and variant payload parsing | Any link-management API payload or UI status contract change |
| `lib/presentation/screens/affiliations/affiliations_screen.dart`, `lib/presentation/screens/affiliations/affiliation_form_sheet.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Affiliations list, expired badge, slug input, and click/variant UI | Any affiliation UI, slug, click summary, or variant-management change |
| `lib/presentation/screens/settings/integrations_screen.dart`, `lib/presentation/screens/settings/settings_screen.dart`, `lib/presentation/screens/branding/brand_profiles_screen.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Integration and project-branding Settings UI, including canonical preview handoff | Any settings integration, project-brand rule, credential UX, connection, or preview-entry change |
| `lib/data/services/capture_local_store.dart` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Local capture history and capture/content links | Any capture persistence, deletion, migration, or link-state change |
| `lib/data/services/clerk_auth_service*.dart`, `lib/providers/providers.dart`, `android/app/src/main/kotlin/com/contentglows/contentglows_app/auth/**`, `android/app/src/main/kotlin/com/contentglows/contentglows_app/ContentGlowsApplication.kt`, `web_auth/**`, `scripts/install-web-auth.sh`, `scripts/validate-clerk-runtime.sh` | `shipglows_data/technical/app/platforms/clerk.md` | ClerkJS web routes, Kotlin Android bridge, native session restore, token handoff, and Android/web proof boundaries | Any Clerk route, native channel, token/session, auth runtime, provider configuration, or validation-script change |
| `vercel.json`, `scripts/vercel-*.sh` | `shipglows_data/technical/app/platforms/vercel.md` | Vercel Flutter web build, Dart defines, output routing, preview/production proof, and auth rewrite coupling | Any Vercel build, deploy, env-var, output-directory, rewrite, preview, or production-validation change |
| `android/app/src/main/kotlin/com/contentglows/contentglows_app/capture/**` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Android native screen capture bridge and permissions | Any MediaProjection, foreground service, or capture platform-channel change |
| `test/**` | `shipglows_data/technical/app/flutter-app-shell-and-capture.md` | Flutter regression coverage | Any test harness, fixture, onboarding, navigation, capture, offline-sync, or branding-preview validation change |

## Platform Usage Policy

Do not create a project-local platform note for every dependency. Current local
notes are limited to providers whose project-specific behavior changes agent
decisions or proof routes:

- `shipglows_data/technical/app/platforms/clerk.md`
- `shipglows_data/technical/app/platforms/vercel.md`

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
