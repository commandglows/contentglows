---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "app"
created: "2026-04-25"
updated: "2026-04-25"
status: ready
source_skill: sf-spec
scope: "feature / bug"
owner: "ContentGlows"
confidence: medium
user_story: "En tant qu'utilisateur connecte de ContentGlows, je veux creer, modifier, deselectionner et archiver mes projets de facon coherente, afin de controler quelle source alimente l'application sans etre bloque par GitHub."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app Flutter client"
  - "lab FastAPI projects API"
  - "Turso/libSQL Project table"
  - "UserSettings.defaultProjectId"
  - "UserSettings.projectSelectionMode"
  - "Firecrawl-backed public URL analysis"
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "unknown"
    required_status: "active"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "unknown"
    required_status: "active"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "unknown"
    required_status: "active"
supersedes: []
evidence:
  - "app/lib/presentation/screens/feed/feed_screen.dart:453 opens /onboarding?intent=entry without project context"
  - "app/lib/presentation/screens/onboarding/onboarding_screen.dart:74 only preloads project data for mode=edit with projectId"
  - "app/lib/providers/providers.dart:1261 falls back to bootstrap default or first project when defaultProjectId is null"
  - "lab/api/models/project.py:166 requires github_url as HttpUrl for project creation"
  - "lab/agents/seo/config/project_store.py:41 defines Project.url as NOT NULL and has no archive columns"
next_step: "/sf-start Project flows selection onboarding archive"
---

## Title

Project Flows: Optional Source URL, Explicit No Selection, Active Project Editing, and Archive-First Deletion

## Status

Ready.

## User Story

En tant qu'utilisateur connecte de ContentGlows, je veux creer, modifier, deselectionner et archiver mes projets de facon coherente, afin de controler quelle source alimente l'application sans etre bloque par GitHub.

Primary actor: authenticated ContentGlows user.

Trigger: user lands on the app, sees an empty feed/dashboard, uses the project picker, or opens the Projects screen.

Observable result: project setup opens with the right existing project context, project creation can proceed without GitHub, "No project selected" actually removes project-scoped data from the app, and normal destructive UI archives projects instead of permanently deleting them.

## Problem

The current project flow mixes first workspace setup, project edit, project creation, and active selection in ways that create broken states:

- The empty dashboard opens `/onboarding?intent=entry`, but onboarding only preloads project fields for `mode=edit&projectId=...`, so an existing active project appears as blank setup.
- Project creation requires a GitHub URL in Flutter validation and backend Pydantic models, but product direction now supports projects sourced from non-GitHub public sites crawled with Firecrawl, and projects may be created before a source URL is known.
- The project picker displays "No project selected", but `activeProjectProvider` falls back to bootstrap default or the first project when `defaultProjectId` is null, so the UI still shows a project as active.
- The Projects screen duplicates the active project card above the full projects list.
- The visible "Delete project" action maps to hard delete on the backend, while the desired product behavior is archive-first with explicit permanent deletion later.

## Solution

Separate project source configuration from GitHub-only onboarding, make active project selection tri-state aware, and introduce an archive-first project lifecycle. The app should route dashboard setup to edit the current active project when one exists, allow creation with a name only or an optional public source URL, make "No project selected" a persisted explicit state, and reserve permanent deletion for a future explicit recovery-window flow.

## Scope In

- Flutter project setup/onboarding flow:
  - Rename/copy-adjust the first step away from GitHub-only language where appropriate.
  - Make source URL optional.
  - Accept GitHub URLs and generic public HTTP(S) URLs.
  - Continue to support GitHub repo picker when GitHub is connected.
  - Route empty-dashboard "Review creation settings" to edit the active project when one exists.

- Flutter active project state:
  - Persist explicit "no project selected" state.
  - Prevent fallback to bootstrap default or first project when explicit no-selection is active.
  - Invalidate project-scoped providers after selection changes.
  - Ensure project-scoped screens handle null active project without fetching all-project or stale project data.

- Flutter project picker:
  - Make "No project selected" functional.
  - Add "Create project" action.
  - Keep available project switching.

- Flutter Projects screen:
  - Show active project as a compact summary/header, not a duplicate card.
  - List all non-archived projects as cards below.
  - Keep edit, switch, set default, and archive actions.
  - Add a visible archived section or filter if archived projects are returned.

- Backend projects API:
  - Allow create/update/onboard requests without `github_url`.
  - Support optional canonical `source_url` and project `type`: `github`, `website`, or `manual`.
  - Add `POST /api/projects/{project_id}/archive` and `POST /api/projects/{project_id}/unarchive`.
  - Exclude archived projects from default active fallback and `/api/bootstrap` default resolution unless explicitly requested by an archived view.

- Data model:
  - Add archive metadata to backend model and storage: `archivedAt`.
  - Add reserved hard-delete metadata to backend model and storage: `deletedAt`.
  - Expose `is_archived`, `archived_at`, `is_deleted`, and `deleted_at` consistently in project responses.

- Tests:
  - Unit/widget tests for onboarding routing, optional URL validation, no-selection, project picker menu, and Projects screen list behavior.
  - Backend tests for optional URL creation, non-GitHub URL creation, archive, unarchive, list filtering, and ownership checks.

## Scope Out

- Full Firecrawl analysis pipeline for project onboarding. This spec only ensures the project can store a public non-GitHub source URL and not be blocked by GitHub validation. No server-side crawl, fetch, scrape, analyze, or Firecrawl call is triggered for `website` or `manual` projects in this scope.
- Permanent deletion with 30-day recovery window implementation. This spec defines archive-first behavior and reserves hard delete for a later explicit flow.
- Billing, permissions by workspace role, team-level project sharing, or admin-only project management.
- Reworking all downstream content generation screens beyond null-active-project guards and stale-data prevention.
- New analytics events unless the product already has an event tracking helper in the touched files.

## Constraints

- Do not bypass `AppAccessState` route gating.
- Preserve degraded/offline behavior where current app patterns already support cached reads and queued writes.
- Project data is user-scoped. All backend mutations must continue to call `require_owned_project`; archive/unarchive/set-default must reject foreign, archived, or deleted projects according to this spec.
- The app must not infer "first project is active" after the user explicitly selects no project.
- Existing GitHub repository onboarding and connected repo picker must keep working.
- Project source URL may be empty, but project name remains required.
- Generic source URLs must be HTTP(S); arbitrary schemes such as `file:`, `javascript:`, `data:`, or internal-only URLs are rejected. V1 performs syntactic public HTTP(S) validation only because this spec does not trigger server-side fetching. SSRF-safe network validation for private IPs, localhost, link-local ranges, redirects to private networks, DNS rebinding, request timeouts, crawl size limits, and rate limits is mandatory in the later crawl/analysis spec before any server-side fetch is introduced.
- Existing cached/offline project IDs may be temporary IDs and must keep using current ID reconciliation patterns.
- Because `lab` uses Turso/libSQL, schema changes need migration/ensure-table guardrails and must avoid destructive table rebuilds without backup.

## Dependencies

- Flutter:
  - Riverpod providers in `app/lib/providers/providers.dart`.
  - GoRouter route callers in feed/settings/projects widgets.
  - Project models and API service in `app/lib/data`.

- Backend:
  - FastAPI router `lab/api/routers/projects.py`.
  - Pydantic models `lab/api/models/project.py`.
  - Turso-backed store `lab/agents/seo/config/project_store.py`.
  - Bootstrap route `lab/api/routers/me.py`.
  - User settings store for `defaultProjectId` and `projectSelectionMode`.

- External integrations:
  - GitHub OAuth/repo picker remains optional.
  - Firecrawl can consume public website URLs later; this spec only preserves a valid source URL for later crawl.

## Invariants

- `Project.name` is always non-empty after trimming.
- `Project.url` may be empty for manual/no-source projects.
- Canonical project source write field is `source_url`; backend accepts legacy `github_url` as an alias; backend responses keep `url` for compatibility with the existing Flutter model.
- Project selection mode is represented in user settings by `projectSelectionMode: "auto" | "selected" | "none"`.
- `defaultProjectId` is meaningful only when `projectSelectionMode == "selected"`.
- `projectSelectionMode == "auto"` preserves legacy fallback to a valid non-archived project.
- `projectSelectionMode == "none"` means no active project even if projects exist; backend bootstrap returns `default_project_id: null` and Flutter `activeProjectProvider` returns null.
- A project can be active only if it is owned by the user and not archived/deleted.
- Explicit no-selection must survive refresh/recompute until the user selects a project or creates a project that intentionally becomes active.
- A null active project means project-scoped reads should either pass no `projectId` only where the API contract is intentionally global, or show a no-project state instead of reusing stale project content.
- Archiving an active project must clear active selection or move to explicit no-selection; it must not silently select another project.
- Archived projects must not be offered in the top-right active project picker except through an archive management area.
- Hard delete is not exposed as the default project-card action.
- Archive API shape is fixed: default UI calls `POST /api/projects/{project_id}/archive`; reversible restore calls `POST /api/projects/{project_id}/unarchive`; `DELETE /api/projects/{project_id}` is reserved for hard-delete/internal or future explicit permanent deletion flow and is not used by default UI.
- Archive/unarchive requires an owned, non-deleted project. Unarchive must not revive hard-deleted projects.
- Backend errors and diagnostics must not log GitHub tokens, Firecrawl credentials, or other provider secrets. Source URLs are not secrets, but logs should avoid dumping full request payloads when credentials may be adjacent.

## Links & Consequences

- `activeProjectProvider` currently uses a fallback chain: user settings default, bootstrap default, project marked default, first project. This must become aware of `projectSelectionMode`.
- `AppSettings.copyWith` currently cannot set `defaultProjectId` to null via `defaultProjectId: null`; it has `clearDefaultProjectId`. The implementation must add `projectSelectionMode` and ensure mode changes plus null/default ID changes are preserved through API updates and local optimistic state.
- `ApiService.updateSettings` already checks `containsKey('defaultProjectId')`, so null can be sent, but cache and provider behavior must be verified.
- `/api/bootstrap` currently derives `default_project_id` from configured default or first project. It must read `projectSelectionMode`: `none` returns null, `selected` returns a valid non-archived configured project or null if invalid, and `auto` may use legacy fallback.
- Existing `Project` Pydantic model and Turso schema use `url TEXT NOT NULL`; V1 keeps that schema and stores no-source projects as `url = ""` to avoid a table rebuild.
- Current backend response model does not expose archive/delete metadata, while Flutter already expects `is_archived`, `is_deleted`, `archived_at`, and `deleted_at`. Aligning this contract reduces hidden client fallback.
- Archive-first behavior changes user-facing copy and support expectations: "Delete project" should become "Archive project" in default UI.

## Documentation Coherence

- Update `app/CHANGELOG.md` after implementation with source-agnostic project creation, explicit no-project selection, and archive-first project lifecycle.
- Review `shipglows_data/technical/app/guidelines.md`, `app/README.md`, and settings/onboarding support copy for GitHub-only project language. Update any text that says projects must be GitHub repositories.
- Review backend docs in `lab/README.md` or project API docs if they document `/api/projects` as GitHub-only or hard-delete-only.
- No pricing, public marketing page, or FAQ update is required in this spec because the change is inside authenticated app project management and does not alter packaging or public claims.
- Future Firecrawl crawl documentation is out of scope; this spec must not document non-GitHub URLs as actively crawled until the crawl pipeline exists.

## Edge Cases

- User has one project, selects "No project selected", refreshes app: top-right picker still shows "No project selected" and project-scoped screens do not fetch that project.
- User has no projects and opens dashboard setup: route opens create mode with empty name and optional source URL.
- User has active project and opens dashboard setup: route opens edit mode for that project with name/source/content types prefilled.
- User has projects but no active project and opens dashboard setup: route opens create mode or Projects screen action depending on CTA copy; it must not silently select the first project.
- User creates a project with only a name: project is created with empty source URL and can become active.
- User creates a project with `https://example.com`: project is accepted as website/public source, not rejected as non-GitHub.
- User enters invalid source URL text: project can still continue if the field is empty; non-empty invalid URL is rejected with clear copy.
- User enters `http://localhost`, private IP, or a URL that later redirects internally: V1 may store only syntactically valid HTTP(S) source strings, but no backend fetch occurs in this spec. Later crawl implementation must reject or safely handle these before fetching.
- User archives the active project: active selection becomes no project selected, stale feed/content/persona/idea data clears or shows empty/null-active states.
- User archives a non-active project: active project stays unchanged.
- User tries to archive another user's project by ID: backend returns 403.
- User tries to set archived project as default/active: backend rejects or client filters it out; no active state changes.
- Backend unavailable during selection clearing: current offline queue/cache behavior should preserve the intended null active state and show sync status if supported.
- Demo mode: demo project remains read-only and no destructive/archive action is exposed.

## Implementation Tasks

- [ ] Task 1: Define shared project selection settings contract
  - File: `app/lib/data/models/app_settings.dart`, `lab/api/models/user_data.py`, `lab/api/routers/me.py`
  - Action: Add `projectSelectionMode: "auto" | "selected" | "none"` to app settings parsing/serialization and backend settings/bootstrap handling. `defaultProjectId` is meaningful only when mode is `selected`; mode `none` forces bootstrap `default_project_id: null`; mode `auto` preserves legacy non-archived fallback.
  - User story link: Makes "No project selected" observable and persistent.
  - Depends on: None.
  - Validate with: Unit/router tests that settings parse/serialize `auto`, `selected`, and `none`, and that bootstrap preserves explicit none without falling back to the first project.
  - Notes: Do not use a sentinel in `defaultProjectId`; mode is the source of truth.

- [ ] Task 2: Make active project provider tri-state aware
  - File: `app/lib/providers/providers.dart`
  - Action: Update `activeProjectProvider`, `activeProjectIdProvider`, `ActiveProjectController.setActiveProject`, and current settings updates so explicit no-selection returns null without falling back to bootstrap default or first project. Keep legacy fallback only when the user has never made a project selection.
  - User story link: Fixes the picker entry that currently appears to do nothing.
  - Depends on: Task 1.
  - Validate with: Provider/unit tests for selected project, explicit no-selection, stale default ID, archived project, and no projects.
  - Notes: Invalidate all project-scoped providers already listed in `ActiveProjectController`; add any missing project-scoped providers discovered during implementation.

- [ ] Task 3: Update API settings/cache handling for explicit no-selection
  - File: `app/lib/data/services/api_service.dart`
  - Action: Ensure `updateSettings` writes and caches explicit no-selection without rewriting it through offline ID mapping or bootstrap fallback. Ensure `_syncBootstrapCache` does not restore a project when explicit no-selection is set.
  - User story link: Keeps selection clearing stable across refresh/offline mode.
  - Depends on: Task 1.
  - Validate with: `test/core/offline_sync_test.dart` additions for clearing project selection and reconciling temp IDs without rewriting `projectSelectionMode`.
  - Notes: Only `defaultProjectId` participates in offline ID mapping; `projectSelectionMode` is a plain enum string.

- [ ] Task 4: Route dashboard setup to the right project mode
  - File: `app/lib/presentation/screens/feed/feed_screen.dart`
  - Action: Replace hard-coded `/onboarding?intent=entry` with route building that sends active projects to `/onboarding?mode=edit&intent=entry&projectId=<id>` and sends no active project to `/onboarding?mode=create&intent=entry`.
  - User story link: Existing active project opens with real project data instead of blank fields.
  - Depends on: Task 2.
  - Validate with: Widget test where active project exists and tapping "Review creation settings" opens edit URL; test no active project opens create URL.
  - Notes: Apply to both action card and hero primary CTA.

- [ ] Task 5: Generalize onboarding project source validation and copy
  - File: `app/lib/core/project_onboarding_validation.dart`
  - Action: Replace GitHub-only validation with optional source URL validation. Empty is valid; GitHub URL is valid; generic public HTTP(S) URL is valid; non-HTTP(S) and malformed non-empty values are invalid. Keep `extractGithubRepositoryName` only for GitHub URLs.
  - User story link: Users can create projects from any source or no source yet.
  - Depends on: None.
  - Validate with: Existing validation tests plus cases for empty URL, `https://example.com`, invalid scheme, malformed URL, and GitHub repo name extraction.
  - Notes: Name remains required.

- [ ] Task 6: Update onboarding UI behavior and finish mutation
  - File: `app/lib/presentation/screens/onboarding/onboarding_screen.dart`
  - Action: Use source-neutral labels/copy, make source URL optional, preserve GitHub repo picker as an optional helper, preload active project in edit mode, and call create/update APIs with optional source URL. Ensure workspace setup legacy path also accepts empty/non-GitHub source.
  - User story link: Creation and editing work for GitHub, public website, and no URL.
  - Depends on: Tasks 4 and 5.
  - Validate with: Widget tests for edit prefill, empty URL create enabled when name exists, invalid non-empty URL blocks continue, and generic website URL accepted.
  - Notes: Avoid showing "Connect your GitHub repository" as the main requirement when the field is optional.

- [ ] Task 7: Add create-project action and functional no-selection to picker
  - File: `app/lib/presentation/widgets/project_picker_action.dart`
  - Action: Add a menu item for "Create project" linking to `/onboarding?mode=create&intent=project-manage`; make "No project selected" call the updated controller with explicit no-selection; show checkmark only next to no-selection when that mode is active.
  - User story link: Lets users create and clear selection from the always-visible top-right control.
  - Depends on: Task 2.
  - Validate with: Widget test for selecting no project and for create menu route.
  - Notes: If `PopupMenuButton<String?>` cannot distinguish action types cleanly, replace value strings with an internal enum/string command convention.

- [ ] Task 8: Simplify Projects screen active summary and card list
  - File: `app/lib/presentation/screens/projects/projects_screen.dart`
  - Action: Replace duplicate active project card with compact active summary showing active project name or "No project selected"; keep all non-archived projects as cards in the list; add create action; rename delete action to archive. Add archived section if archived projects are included by provider.
  - User story link: Project management becomes coherent and avoids duplicate active card confusion.
  - Depends on: Tasks 2 and 11.
  - Validate with: Widget tests for active summary, no-selection summary, all projects list, and archived project visibility.
  - Notes: Keep edit project link to onboarding edit mode.

- [ ] Task 9: Add null-active guards to project-scoped screens/providers
  - File: `app/lib/providers/providers.dart`
  - Action: Audit providers using `activeProjectIdProvider` and ensure null means no project-scoped data, not accidental global/stale data, for feed, history, personas, affiliations, ideas, content tools, work domains, drip, analytics/performance as applicable.
  - User story link: "No project selected" removes project-linked data from the app.
  - Depends on: Task 2.
  - Validate with: Focused provider tests and at least one widget smoke test for a null-active project screen.
  - Notes: Some endpoints may intentionally support global reads; document each intentional exception in code comments or tests.

- [ ] Task 10: Update Flutter project model/API for archive metadata and optional URL
  - File: `app/lib/data/models/project.dart`, `app/lib/data/services/api_service.dart`
  - Action: Ensure empty URL and generic source URLs parse/render correctly; write canonical `source_url` while accepting/reading response `url`; map backend archive/delete fields consistently; add `archiveProject` calling `POST /api/projects/{id}/archive` and `unarchiveProject` calling `POST /api/projects/{id}/unarchive`. Keep `deleteProject` only for future hard-delete flow or internal use.
  - User story link: Enables archive-first lifecycle and source-agnostic projects.
  - Depends on: Backend Tasks 11-14.
  - Validate with: API service/model tests for project response with empty URL, website URL, archived metadata, and deleted metadata.
  - Notes: Avoid showing blank subtitle rows in picker/cards when URL is empty.

- [ ] Task 11: Relax backend project request models for optional source URL
  - File: `lab/api/models/project.py`
  - Action: Change create/onboard/update request models so canonical `source_url` is optional and legacy `github_url` remains accepted as an alias. Accept empty/missing URL. Validate non-empty URLs as syntactically valid HTTP(S), with GitHub recognized as `type = "github"`, non-GitHub HTTP(S) as `type = "website"`, and empty source as `type = "manual"`.
  - User story link: Backend no longer blocks non-GitHub or empty-source project creation.
  - Depends on: None.
  - Validate with: Pydantic model tests for no URL, GitHub URL, public website URL, invalid scheme, and legacy `github_url`.
  - Notes: Preserve backward compatibility for existing Flutter payloads using `github_url`; do not trigger crawl/fetch/analyze for `website` or `manual` in this spec.

- [ ] Task 12: Update backend project store schema/model for optional URL and archive fields
  - File: `lab/agents/seo/config/project_store.py`
  - Action: Add ensure-table migrations for `archivedAt` and `deletedAt` metadata if missing. Ensure `url` can be stored as empty string for no-source projects. Add store methods `archive`, `unarchive`, and `hard_delete` for reserved explicit deletion. Filter archived/deleted projects in default active queries where appropriate.
  - User story link: Supports archive-first lifecycle and optional source persistence.
  - Depends on: Task 11.
  - Validate with: Backend store/router tests using stubs plus migration smoke if available.
  - Notes: Because SQLite cannot trivially alter NOT NULL away, V1 may keep `url TEXT NOT NULL` and store empty string for no-source.

- [ ] Task 13: Update backend projects router contract
  - File: `lab/api/routers/projects.py`
  - Action: Update create/onboard/update logic to use optional canonical `source_url`, legacy `github_url` alias, and source type. Add `POST /api/projects/{id}/archive` and `POST /api/projects/{id}/unarchive`. Keep `DELETE /api/projects/{id}` as hard-delete/internal or future explicit flow, but do not call it from default Flutter UI.
  - User story link: UI actions have authoritative backend behavior.
  - Depends on: Tasks 11 and 12.
  - Validate with: Router tests for create no URL, create website URL, archive owned project, reject archive foreign project, unarchive, and no archived project set as default.
  - Notes: Archive/unarchive must require owned, non-deleted projects. Unarchive must not revive hard-deleted projects. Default UI calls archive, not hard delete.

- [ ] Task 14: Update backend bootstrap/default resolution
  - File: `lab/api/routers/me.py`
  - Action: Read `projectSelectionMode` from user settings. For `none`, return `default_project_id: null` even if projects exist. For `selected`, return the configured `defaultProjectId` only if it points to an owned, non-archived, non-deleted project; otherwise return null. For `auto` or missing legacy mode, use fallback to the first valid non-archived project.
  - User story link: App startup respects "No project selected".
  - Depends on: Tasks 1 and 12.
  - Validate with: `tests/test_bootstrap_routes.py` additions for explicit no-selection, archived default, deleted default, and first active fallback only in legacy/no-selection-unset state.
  - Notes: Keep workspace existence true when projects exist but none is selected.

- [ ] Task 15: Update localization and copy
  - File: `app/lib/l10n/app_localizations.dart`
  - Action: Add/adjust strings for "Source URL", "Optional", "Public website or GitHub URL", "Archive project", "Archived projects", "No source linked", and no-project states. Remove GitHub-only requirement copy from generic project setup.
  - User story link: User understands the new source-agnostic and archive-first behavior.
  - Depends on: Tasks 6, 7, and 8.
  - Validate with: Flutter analyzer and widget tests that rely on visible copy.
  - Notes: Keep English primary copy and French translations consistent with existing localization style.

- [ ] Task 16: Add end-to-end regression tests for project flow
  - File: `app/test/presentation/screens/feed/feed_screen_test.dart`, `app/test/presentation/screens/projects/projects_screen_test.dart`, `app/test/core/project_onboarding_validation_test.dart`, `lab/tests/test_projects_create_route.py`, `lab/tests/test_bootstrap_routes.py`
  - Action: Add focused tests covering the acceptance criteria below.
  - User story link: Prevents regressions in observed broken flows.
  - Depends on: All implementation tasks.
  - Validate with: `flutter test` for app tests and `pytest` for backend tests.
  - Notes: If full suite is slow, run targeted files first, then broader checks before shipping.

## Acceptance Criteria

- [ ] CA 1: Given an authenticated user with an active project, when they tap "Review creation settings" on the empty dashboard, then onboarding opens in edit mode for that project and shows its existing name and source URL.
- [ ] CA 2: Given an authenticated user with no active project, when they tap "Review creation settings", then onboarding opens in create mode and does not silently select an existing project.
- [ ] CA 3: Given a project name and an empty source URL, when the user completes project setup, then the project is created successfully with no source URL.
- [ ] CA 4: Given a project name and `https://example.com`, when the user completes setup, then the project is created as a public website/manual source and is not rejected for being non-GitHub.
- [ ] CA 5: Given a non-empty malformed source URL, when the user tries to continue from the project step, then the app blocks progress and shows a clear validation message.
- [ ] CA 6: Given a connected GitHub account, when the user opens the repo picker, then selecting a repo still fills the source URL and may autofill the project name.
- [ ] CA 7: Given a selected active project, when the user chooses "No project selected" from the project picker, then the picker label changes to "No project selected" and no project item has a checkmark.
- [ ] CA 8: Given explicit no-selection and an app refresh/bootstrap, when the app reloads, then no project is selected and the first project is not auto-selected.
- [ ] CA 9: Given explicit no-selection, when project-scoped screens render, then they do not display stale data from the previously selected project.
- [ ] CA 10: Given the project picker menu, when the user chooses "Create project", then the app navigates to project create mode.
- [ ] CA 11: Given the Projects screen with an active project, when it renders, then the active project name appears in a compact summary and the project appears once in the projects list, not duplicated as a separate active card.
- [ ] CA 12: Given an active project, when the user archives it, then it disappears from active project choices and active selection becomes no project selected.
- [ ] CA 13: Given a non-active project, when the user archives it, then the current active project remains selected.
- [ ] CA 14: Given an archived project, when projects are listed normally, then it does not appear in active project picker options.
- [ ] CA 15: Given an archived project shown in archive management, when the user unarchives it, then it becomes available in the normal project list but is not automatically selected unless the user selects it.
- [ ] CA 16: Given a user attempts to archive or edit a project they do not own, when the backend handles the request, then it returns 403 and does not mutate data.
- [ ] CA 17: Given backend bootstrap and `projectSelectionMode == "none"`, when projects exist, then `workspace_exists` remains true and `default_project_id` remains null.
- [ ] CA 20: Given project creation with canonical `source_url`, when backend stores and returns the project, then response `url` matches the source URL for Flutter compatibility.
- [ ] CA 21: Given project creation with legacy `github_url`, when backend handles the request, then it maps it to canonical source URL behavior and marks source type as `github`.
- [ ] CA 22: Given a public website source URL, when the project is created in this spec, then no backend crawl, fetch, scrape, analyze, or Firecrawl call is triggered.
- [ ] CA 18: Given a legacy user with projects and no explicit selection setting, when bootstrap runs, then the existing fallback to a valid non-archived project may continue for backwards compatibility.
- [ ] CA 19: Given a demo session, when the user opens project management, then destructive/archive actions are disabled or hidden and demo source data remains fixed.

## Test Strategy

- Flutter unit tests:
  - `test/core/project_onboarding_validation_test.dart` for source URL validation.
  - Provider tests for `activeProjectProvider` tri-state behavior and settings serialization.
  - Offline sync tests for clearing selection and preserving explicit no-selection.

- Flutter widget tests:
  - Feed empty-dashboard CTA routing for active/no-active states.
  - Project picker no-selection and create-project action.
  - Projects screen active summary, non-duplicated list, archive labels, and archived section.
  - Onboarding create/edit validation and prefill.

- Backend unit/router tests:
  - Pydantic request model optional URL behavior.
  - Project create route with no URL and website URL.
  - Archive/unarchive route ownership.
  - Bootstrap default resolution with explicit no-selection and archived projects.

- Manual verification:
  - Sign in, create project with GitHub URL.
  - Create project with public website URL.
  - Create project with name only.
  - Select no project, refresh browser, verify no stale project data.
  - Archive active project, verify picker and dashboard state.
  - Unarchive project, select it, edit settings.

- Suggested commands:
  - App targeted: `flutter test test/core/project_onboarding_validation_test.dart test/presentation/screens/feed/feed_screen_test.dart`
  - App full check: `flutter test`
  - Backend targeted: `pytest tests/test_projects_create_route.py tests/test_bootstrap_routes.py`

## Risks

- Data migration risk: current Project table has `url TEXT NOT NULL` and no archive columns. Use additive migrations and empty-string V1 compatibility to avoid destructive schema changes.
- State ambiguity risk: null `defaultProjectId` currently means "fallback to first project." The spec requires an explicit no-selection representation to avoid breaking legacy users.
- Stale data risk: clearing active project must invalidate all project-scoped providers, otherwise old content/personas/ideas may remain visible.
- Backend/client contract risk: Flutter already models archive/delete fields that backend does not currently return. Aligning fields requires coordinated changes.
- Security risk: public crawl source URLs can become SSRF-adjacent if backend later crawls arbitrary URLs. This spec requires HTTP(S)-only validation now; future Firecrawl execution must add public-network/allowlist protections and provider credential checks.
- Logging risk: GitHub and Firecrawl credentials must never be logged. Source URLs may appear in UI and diagnostics, but backend should avoid logging whole request bodies where credentials could be adjacent.
- Offline risk: changing selection while offline must not corrupt temp ID mapping or silently reselect a project from cached bootstrap.
- UX risk: users may expect "archive" to be reversible. UI copy must make archive reversible and avoid claiming permanent deletion.

## Execution Notes

- Read first:
  - `app/lib/providers/providers.dart`
  - `app/lib/presentation/screens/onboarding/onboarding_screen.dart`
  - `app/lib/presentation/widgets/project_picker_action.dart`
  - `lab/api/routers/projects.py`
  - `lab/agents/seo/config/project_store.py`

- Recommended implementation order:
  - Establish shared settings/no-selection contract in app model and backend bootstrap.
  - Add backend optional source URL and archive/unarchive contract.
  - Fix Flutter active project state and picker.
  - Relax validation and onboarding UI.
  - Align Projects screen and tests.

- Stop conditions:
  - If Turso production schema already has archive/delete columns with different names, adapt to existing names and update this spec before coding.
  - If existing project source/crawl specs already define a conflicting canonical source field, stop and update this spec before implementation rather than implementing both.
  - If implementation discovers any server-side fetch/crawl is triggered for `website` or `manual` project creation, stop and either disable that call in this scope or create a separate SSRF-safe crawl spec.

## Open Questions

None.

Decisions fixed for V1:

- URL is optional.
- Empty source is allowed and stored as a manual project with empty response `url`.
- Canonical request field is `source_url`; legacy `github_url` remains accepted.
- Public HTTP(S) non-GitHub URLs are allowed for future Firecrawl use, but no server-side crawl/fetch/analyze runs in this spec.
- Normal project removal archives by default through `POST /api/projects/{id}/archive`.
- Unarchive uses `POST /api/projects/{id}/unarchive`.
- Permanent deletion with a recovery window is deferred to a later spec; default Flutter UI does not call `DELETE`.
- Explicit no-selection is persisted with `projectSelectionMode: "none"`.
