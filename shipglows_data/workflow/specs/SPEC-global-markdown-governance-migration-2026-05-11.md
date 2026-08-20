---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.1"
project: "contentglows"
created: "2026-05-11"
created_at: "2026-05-11 07:24:15 UTC"
updated: "2026-08-20"
updated_at: "2026-08-20 07:48:00 UTC"
status: reviewed
source_skill: sf-spec
source_model: "gpt-5"
scope: "migration"
owner: "Diane"
confidence: "high"
user_story: "As the ContentGlows operator, I want all durable governance, spec, research, QA, bug, and operational Markdown sources in the ContentGlows monorepo to live under `shipglows_data/**`, excluding `contentglows/**`, so there is no active source of truth scattered at repo root or in legacy folders."
risk_level: "high"
security_impact: "yes"
docs_impact: "yes"
linked_systems:
  - "app"
  - "lab"
  - "site"
  - "shipglows_data"
  - "specs"
  - "docs"
  - "research"
  - "bugs"
  - "site/src/content"
depends_on:
  - artifact: "shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md"
    artifact_version: "1.0.0"
    required_status: "ready"
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/lab/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/site/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes:
  - "shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md"
evidence:
  - "User decision 2026-05-11: 'y'a aucune exception. on va migrer'."
  - "User decision 2026-05-11 during sf-spec update: contentglows is ignored entirely and excluded from this migration."
  - "Global inventory 2026-05-11: 202 project Markdown files outside .git, node_modules, .flox and .pytest_cache."
  - "Audit found root legacy specs under shipglows_data/workflow/specs/lab/SPEC-*.md without ShipGlowz frontmatter."
  - "Audit found durable governance notes under lab/*.md such as CONTENT_GUIDELINES.md, COST-MODEL.md, ENVIRONMENT_shipglows_data/technical/SETUP.md and TOOLS.md."
  - "Audit found root-level workflow artifacts in legacy `shipglows_data/workflow/specs/app/`, `docs/`, `research/` and project-local bugs that were not under shipglows_data/workflow/** before migration."
  - "Astro runtime content schema in site/src/content.config.ts accepts content fields only and must not receive ShipGlowz metadata."
next_step: "/sf-ship shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md"
---

# Title

Global Markdown Governance Migration To ShipGlowz Data

## Status

Ready. This spec formalizes the 2026-05-11 operator decision that durable ContentGlows governance and workflow Markdown must no longer have active source-of-truth copies outside `shipglows_data/**`. Conventional files may remain only as tooling entrypoints, short pointers, excluded trackers, or runtime application content. `contentglows/**` is explicitly excluded from this migration and must not be moved, edited, indexed, linted, or converted by this chantier.

## User Story

As the ContentGlows operator, I want all durable governance, spec, research, QA, bug, and operational Markdown sources in the ContentGlows monorepo to live under `shipglows_data/**`, excluding `contentglows/**`, so there is no active source of truth scattered at repo root or in legacy folders.

## Minimal Behavior Contract

When a Markdown file in scope is a durable ShipGlowz artifact, spec, bug file, research record, QA matrix, audit, review, governance note, business source, technical source, editorial source, or reusable operational note, the migration classifies it, moves it to the canonical `shipglows_data/**` family, preserves its body except for required link updates or redaction, adds or fixes ShipGlowz frontmatter, updates internal references, and proves that no old active duplicate remains. If the file is Astro runtime content, an explicitly excluded tracker, a required tooling entrypoint, or any file under `contentglows/**`, it is not converted to a ShipGlowz artifact in this chantier. Failures stop the affected batch with a visible blocked report, and the easiest edge case to miss is breaking runtime/tooling schemas or leaking sensitive historical content while trying to make every Markdown file lintable.

## Success Behavior

- Given the in-scope monorepo contains Markdown outside `shipglows_data/**`, when the inventory is produced, then every in-scope file has exactly one category: `canonical artifact`, `workflow artifact`, `runtime content`, `tracker excluded`, `tooling entrypoint`, `archive`, `delete candidate`, `blocked-classification`, or `blocked-security-review`.
- Given a file is a durable artifact, when it is migrated, then it lives under `shipglows_data/business`, `shipglows_data/technical`, `shipglows_data/editorial`, or `shipglows_data/workflow/<family>` with valid ShipGlowz frontmatter.
- Given a legacy file remains at the old path, when an agent or human opens it, then it is not a competing source of truth; it is either a short pointer, an excluded tracker, runtime content, or a required tooling entrypoint.
- Given a spec, bug file, research artifact, QA matrix, audit, or review is moved, when a link, `depends_on`, `next_step`, changelog entry, tracker entry, README, AGENT, or CLAUDE reference points to the old path, then the reference is updated to the canonical path or documented as historical evidence in the closure report.
- Given `site/src/content/**` is loaded by Astro, when migration completes, then the build and schema are not exposed to unsupported ShipGlowz metadata fields.
- Given an in-scope legacy note may contain secrets, tokens, private URLs, logs, private customer/project data, or sensitive operational data, when the batch is processed, then the file is scanned before moving and is either redacted before migration or recorded as `blocked-security-review` without copying sensitive content to a new canonical artifact.
- Given migration completes, when validation runs, then ShipGlowz metadata lint passes on canonical artifacts, legacy path searches return only allowed pointers or migration reports, `contentglows/**` remains unchanged, and Git status contains no unexplained deletion or application-code modification.

## Error Behavior

- If a file cannot be classified without a product or archive decision, add it to the closure report as `blocked-classification` and do not move it silently.
- If a file may contain secrets, tokens, private URLs, raw logs, private customer/project data, or sensitive operational data, do not migrate the raw body as authoritative content; redact it first or mark it `blocked-security-review`.
- If a move breaks a link, `depends_on`, `next_step`, tracker pointer, changelog reference, README reference, AGENT/CLAUDE instruction, or documentation import, stop the affected batch until the reference is corrected.
- If ShipGlowz metadata lint fails on a migrated canonical artifact, the file remains in the active work batch and the batch is not complete.
- If Astro runtime content or a tooling entrypoint breaks after migration, revert only the affected runtime/entrypoint batch and use a pointer/no-frontmatter strategy.
- If implementation detects any change under `contentglows/**`, stop and revert only those accidental `contentglows/**` changes before continuing.
- What must never happen: two active sources for the same contract, ShipGlowz frontmatter added to incompatible runtime content, sensitive content copied into a new canonical artifact without redaction review, deletion of an active spec without archive/pointer evidence, tracker history loss, or modifications to excluded `contentglows/**`.

## Problem

The previous migration consolidated the main business, branding, product, GTM, architecture, context, guidelines, content-map, and technical documentation contracts. It intentionally left functional specs, trackers, research, QA matrices, legacy notes, and some content folders out of scope. The result is still ambiguous for in-scope ContentGlows governance: `shipglows_data/workflow/specs/lab/SPEC-*.md`, `docs/`, `research/`, `shipglows_data/workflow/specs/app/`, and project-local bug folders contain durable artifacts outside `shipglows_data/**`, and some files lack required ShipGlowz frontmatter. `contentglows/**` also contains Markdown, but the operator explicitly decided to ignore it entirely for this chantier.

## Solution

Run a staged local filesystem governance migration that makes `shipglows_data/**` the only active umbrella for in-scope ContentGlows governance and workflow artifacts. Specs, bugs, research, audits, reviews, QA, conversations, explorations, reports, and archives move under `shipglows_data/workflow/**`; business, technical, and editorial contracts remain under their existing `shipglows_data` families; conventional root/project files become short pointers or documented runtime/tracker/tooling exclusions. `contentglows/**` remains untouched and is excluded from inventory, moves, lint gates, pointer conversion, and reference rewrites.

## Scope In

- Define target directories under `shipglows_data/workflow/specs`, `bugs`, `research`, `qa`, `explorations`, `audits`, `reviews`, `conversations`, `archives`, and `reports`.
- Exclude `.git`, `node_modules`, `.flox`, `.pytest_cache`, build outputs, vendored dependencies, and `contentglows/**` from the migration inventory and hard validation gates.
- Migrate active and historical specs from `shipglows_data/workflow/specs/app/**`, `shipglows_data/workflow/specs/app/**`, `shipglows_data/workflow/specs/lab/**`, `shipglows_data/workflow/specs/site/**`, `shipglows_data/workflow/specs/lab/SPEC-*.md`, and `docs/centraliser-design-tokens-contentglows-app-site.md`.
- Migrate bug files from `app/bugs/**` and `lab/bugs/**` to `shipglows_data/workflow/bugs/<project>/**`.
- Migrate research and exploration artifacts from `research/**` and `shipglows_data/workflow/explorations/**` to `shipglows_data/workflow/research/**` or `shipglows_data/workflow/explorations/**`.
- Migrate QA artifacts from `shipglows_data/workflow/qa/**` to `shipglows_data/workflow/qa/**`.
- Classify and migrate durable `lab` root notes such as `AGENT_MEMORY_RESEARCH.md`, `BACKLINK_CHECKER.md`, `CONTENT_GUIDELINES.md`, `CONTENT_INVENTORY.md`, `COST-MODEL.md`, `ENVIRONMENT_shipglows_data/technical/SETUP.md`, `TOOLS.md`, and other non-tracker root Markdown.
- Security-scan in-scope legacy notes before migration; redact sensitive content or mark files `blocked-security-review`.
- Fix incomplete frontmatter for migrated explorations, research, QA, bugs, specs, audits, and reviews.
- Replace old active files with deletion or a short pointer when a conventional entrypoint must remain.
- Update references in README, CHANGELOG, AGENT/CLAUDE, specs, docs, `depends_on`, `next_step`, bug pointers, trackers, and changelogs.
- Update local governance wording to remove ambiguity between legacy `shipglows_data/workflow/specs/app/` and `shipglows_data/workflow/specs`.

## Scope Out

- Any file or directory under `contentglows/**`; do not move, edit, lint, index, delete, add pointers to, or rewrite references inside `contentglows/**`.
- Editorial rewriting of Astro runtime content in `site/src/content/**`.
- Converting Astro runtime frontmatter to ShipGlowz frontmatter.
- Functional code changes to Flutter, FastAPI, Astro, Convex, Next.js, Remotion, or prototypes.
- Deleting trackers without an explicit decision: `TASKS.md`, `AUDIT_LOG.md`, `shipglows_data/workflow/qa/TEST_LOG.md`, `BUGS.md`, and `CHANGELOG.md` remain trackers or journals, although their entries may point to new canonical paths.
- Cleaning vendored dependencies, caches, generated outputs, or build outputs.
- Deep business validation of stale content; the migration may mark content `status: stale` or `deprecated` without rewriting the substance.

## Constraints

- The operator's "no exception" decision applies to in-scope ShipGlowz sources of truth: no active spec, bug record, research, QA artifact, or durable governance contract may remain outside `shipglows_data/**`.
- The later operator decision explicitly excludes `contentglows/**` from this chantier even if it contains durable-looking Markdown.
- Astro runtime content remains under `site/src/content/**` because the framework loads it from that path and its schema does not accept ShipGlowz fields.
- Operational trackers remain excluded from ShipGlowz frontmatter; if they contain durable decisions, extract those decisions to `shipglows_data/**` and leave a pointer.
- README files required by subprojects, templates, or tooling may remain as entrypoints, but they must not duplicate governance contracts.
- Use `git mv` where practical during implementation to preserve history.
- Do not touch or revert unrelated application-code changes already present in the worktree.
- Do not log secrets, private URLs, raw tokens, private customer/project data, or full sensitive excerpts in migration reports.

## Dependencies

- ShipGlowz metadata linter: `/home/claude/shipglowz/tools/shipglowz_metadata_lint.py`.
- Existing canonical contracts:
  - `shipglows_data/{business,editorial,technical,workflow}/app/**`
  - `shipglows_data/{business,editorial,technical,workflow}/lab/**`
  - `shipglows_data/{business,editorial,technical,workflow}/site/**`
- Existing runtime schema:
  - `site/src/content.config.ts`
- Prior migration spec:
  - `shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md`
- Local language doctrine:
  - `/home/claude/shipglowz/shipglows_data/technical/guidelines.md`
  - `/home/claude/shipglowz/shipglowz-spec-driven-workflow.md`
- Fresh external docs: `fresh-docs not needed`. The migration is local filesystem governance and does not depend on changing behavior of external frameworks or APIs. The only framework-sensitive point is local Astro schema preservation, verified from `site/src/content.config.ts`.

## Invariants

- `shipglows_data/**` is the only canonical home for ShipGlowz governance and workflow artifacts after this migration.
- `contentglows/**` is outside this chantier and must be unchanged after this migration.
- Runtime content is not a ShipGlowz governance artifact unless its framework schema explicitly accepts the ShipGlowz metadata fields.
- Trackers are not decision contracts and must not receive ShipGlowz frontmatter solely for lint compliance.
- A moved artifact keeps its body intact unless redaction or link update is required.
- Each moved artifact has one canonical path and no active duplicate at the old path.
- Every moved spec, bug, research, QA, audit or review has valid frontmatter and a clear `status`.
- Existing symlinks `AGENTS.md -> AGENT.md` remain valid until a separate agent-entrypoint policy replaces them.

## Links & Consequences

- `shipglows_data/workflow/specs/lab/SPEC-*.md`: root legacy specs become canonical specs or archived specs under `shipglows_data/workflow/specs/lab/`.
- `shipglows_data/workflow/specs/app/**`, `shipglows_data/workflow/specs/lab/**`, `shipglows_data/workflow/specs/site/**`, and root `shipglows_data/workflow/specs/app/**`: active specs move to `shipglows_data/workflow/specs/<project>/` or `shipglows_data/workflow/specs/monorepo/`.
- `app/bugs/**` and `lab/bugs/**`: bug records move to `shipglows_data/workflow/bugs/<project>/`.
- `shipglows_data/workflow/explorations/**` and `research/**`: research-like artifacts move to `shipglows_data/workflow/research/` or `shipglows_data/workflow/explorations/`.
- `shipglows_data/workflow/qa/**`: QA matrices move to `shipglows_data/workflow/qa/`.
- `site/docs/copywriting/**`: editorial governance contracts move to `shipglows_data/editorial/site/`; non-contract working drafts move to `shipglows_data/workflow/research/site/editorial/` with `status: draft` or `status: stale`.
- `contentglows/**`: no consequence in this chantier; it must remain untouched and omitted from migration reports except for one statement that it was intentionally excluded by operator decision.
- `README.md`, `CHANGELOG.md`, `TASKS.md`, `AUDIT_LOG.md`, `shipglows_data/workflow/qa/TEST_LOG.md`: update links and wording but do not turn trackers into canonical contracts.
- Downstream ShipGlowz skills must be pointed to the new workflow paths after migration; otherwise they will keep creating specs in legacy `shipglows_data/workflow/specs/app/`.
- Security posture: migrated governance files may preserve sensitive history only after redaction review; reports must record counts, paths, and decisions without exposing sensitive values.

## Documentation Coherence

- Update root `README.md` to describe the `shipglows_data/**` documentation layout.
- Update root `CHANGELOG.md` entries that still mention `docs/technical/` or `docs/editorial/` as canonical locations.
- Update project README files only where they point to moved specs, bugs, research, QA, or governance docs.
- Update `AGENT.md` and `CLAUDE.md` references only when they point to moved artifacts or old conventions.
- Add a compact `shipglows_data/README.md` or `shipglows_data/workflow/README.md` index if it does not exist after migration.
- Do not change public marketing copy unless a moved editorial artifact is public-facing and the link itself must change.
- Document `contentglows/**` as excluded from this migration only in the closure report; do not add or change `contentglows` files.

## Edge Cases

- Existing specs contain `Skill Run History` pointing to old paths; preserve history and update only path references needed for future commands.
- Some legacy root `shipglows_data/workflow/specs/lab/SPEC-*.md` files are task checklists, not ready specs; migrate them as `status: draft` or `status: stale`, not `ready`.
- `shipglows_data/workflow/specs/lab/SPEC-newsletter-receiving.md` is explicitly superseded by the user IMAP spec and should be marked `deprecated` or moved to archive with a pointer to the active spec.
- Runtime Astro markdown has frontmatter without `artifact`; this is expected and must not be "fixed" with ShipGlowz fields.
- README files inside imported templates or prototype subprojects may be required by those projects; convert only duplicated governance content to pointers.
- Paths with spaces such as `app/Isa Build/README.md` need careful link handling and should not be moved without classifying ownership.
- Legacy notes can contain sensitive operational details; scan and redact before canonicalizing, and do not include sensitive snippets in reports.
- `contentglows/**` contains durable-looking Markdown, but it is explicitly excluded; broad `find` and `rg` commands must prune it so the implementation cannot accidentally migrate it.

## Implementation Tasks

- [x] Task 1: Freeze and snapshot in-scope Markdown inventory
  - File: `shipglows_data/workflow/reports/markdown-governance-inventory-2026-05-11.md`
  - Action: Generate a classified inventory of all in-scope project Markdown excluding `.git`, `node_modules`, `.flox`, `.pytest_cache`, build outputs, vendored dependencies, and `contentglows/**`.
  - User story link : Establishes the complete migration scope before moving files.
  - Depends on: none.
  - Validate with: `find . \( -path './.git' -o -path './site/node_modules' -o -path './lab/.flox' -o -path './lab/.pytest_cache' -o -path './contentglows' \) -prune -o -type f -name '*.md' -printf '%p\n' | sort`
  - Notes: Include current path, category, target path, security review status, and action. Do not list `contentglows/**` files except in an exclusion note.

- [x] Task 2: Create workflow corpus directories and indexes
  - File: `shipglows_data/workflow/README.md`
  - Action: Create `shipglows_data/workflow/{specs,bugs,research,qa,explorations,audits,reviews,conversations,archives,reports}` and a concise index describing ownership.
  - User story link : Creates the canonical target before moving artifacts.
  - Depends on: Task 1.
  - Validate with: `find shipglows_data/workflow -maxdepth 2 -type d | sort`
  - Notes: Keep index factual; do not duplicate artifact contents.

- [x] Task 3: Add security preflight classification
  - File: `shipglows_data/workflow/reports/markdown-governance-security-review-2026-05-11.md`
  - Action: Review in-scope legacy notes and reports for likely secrets, tokens, private URLs, raw logs, private customer/project data, and sensitive operational content before moving them.
  - User story link : Prevents canonical governance migration from spreading sensitive historical content.
  - Depends on: Task 1.
  - Validate with: `rg -n -i "api[_-]?key|token|secret|password|bearer|authorization|cookie|private|localhost|supabase|service[_-]?role|webhook|client_secret" . -g '*.md' -g '!contentglows/**' -g '!node_modules/**' -g '!site/node_modules/**'`
  - Notes: Record paths and decisions only. Do not paste secret values or long sensitive snippets into the report.

- [x] Task 4: Migrate active and historical specs
  - File: `shipglows_data/workflow/specs/**`
  - Action: Move specs from root `shipglows_data/workflow/specs/app/**`, project `*/specs/**`, `shipglows_data/workflow/specs/lab/SPEC-*.md`, and spec-like docs under `docs/**` into project-scoped workflow spec folders.
  - User story link : Removes the main class of Markdown exceptions named by the operator.
  - Depends on: Task 2.
  - Validate with: `find . \( -path './shipglows_data' -o -path './contentglows' \) -prune -o -type f -name 'SPEC-*.md' -printf '%p\n'`
  - Notes: Use `status: draft|ready|stale|deprecated` based on current evidence. Do not mark legacy task lists as ready.

- [x] Task 5: Migrate bug records
  - File: `shipglows_data/workflow/bugs/**`
  - Action: Move `app/bugs/**` and `lab/bugs/**`; fix `lab/bugs/BUG-2026-05-10-001.md` missing `depends_on`, `evidence`, `risk_level`, and `supersedes`.
  - User story link : Consolidates bug source-of-truth files.
  - Depends on: Task 2 and Task 3.
  - Validate with: `/home/claude/shipglowz/tools/shipglowz_metadata_lint.py shipglows_data/workflow/bugs`
  - Notes: Tracker files remain trackers and should point to migrated bug files.

- [x] Task 6: Migrate research, explorations and QA
  - File: `shipglows_data/workflow/research/**`, `shipglows_data/workflow/explorations/**`, `shipglows_data/workflow/qa/**`
  - Action: Move `research/**`, `shipglows_data/workflow/explorations/**`, and `shipglows_data/workflow/qa/**`; normalize incomplete frontmatter while preserving bodies.
  - User story link : Removes dispersed decision evidence and QA artifacts.
  - Depends on: Task 2 and Task 3.
  - Validate with: `/home/claude/shipglowz/tools/shipglowz_metadata_lint.py shipglows_data/workflow/research shipglows_data/workflow/explorations shipglows_data/workflow/qa`
  - Notes: Web and Windows exploration files currently use runtime-style frontmatter and need ShipGlowz metadata.

- [x] Task 7: Classify and migrate `lab` root legacy docs
  - File: `shipglows_data/{business,editorial,technical,workflow}/lab/**` and `shipglows_data/workflow/**`
  - Action: Move durable lab notes such as `CONTENT_GUIDELINES.md`, `CONTENT_INVENTORY.md`, `COST-MODEL.md`, `ENVIRONMENT_shipglows_data/technical/SETUP.md`, `TOOLS.md`, `AGENT_MEMORY_RESEARCH.md`, `BACKLINK_CHECKER.md`, and `CONCURRENT.md` into the appropriate canonical family or archive after security preflight.
  - User story link : Eliminates the largest remaining root Markdown cluster.
  - Depends on: Task 2 and Task 3.
  - Validate with: `find lab -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort`
  - Notes: `AGENT.md`, `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `TASKS.md`, `AUDIT_LOG.md`, and `shipglows_data/workflow/qa/TEST_LOG.md` need separate handling as entrypoints or trackers.

- [x] Task 8: Convert legacy source files to pointers or remove duplicates
  - File: legacy Markdown paths identified by Tasks 4-7.
  - Action: Delete old copies when no tool requires them; otherwise replace with a short pointer to the canonical `shipglows_data/**` path.
  - User story link : Enforces no parallel source of truth.
  - Depends on: Tasks 4-7.
  - Validate with: `rg -n "source of truth|canonical|shipglows_data" README.md app lab site shipglows_data -g '*.md' -g '!contentglows/**'`
  - Notes: Do not leave full duplicate bodies as compatibility files.

- [x] Task 9: Update references and command targets
  - File: `README.md`, `CHANGELOG.md`, `AGENT.md`, `CLAUDE.md`, `TASKS.md`, migrated specs, migrated bugs, and workflow indexes.
  - Action: Replace links, `depends_on`, `next_step`, bug pointers, changelog references, and validation commands that still target legacy paths.
  - User story link : Keeps future agents from recreating legacy paths.
  - Depends on: Task 8.
  - Validate with: `rg -n "shipglows_data/workflow/specs/lab/SPEC-|/specs/|^specs/|docs/technical|docs/editorial|docs/explorations|docs/qa|^research/" . -g '*.md' -g '!site/src/content/**' -g '!contentglows/**'`
  - Notes: Allow references only inside migration reports that explicitly document old-to-new mappings.

- [x] Task 10: Validate metadata, runtime boundaries, and exclusions
  - File: `shipglows_data/**` and `site/src/content.config.ts`
  - Action: Run metadata lint on canonical artifacts, verify Astro runtime content was not converted to ShipGlowz schema, and verify `contentglows/**` has no diff.
  - User story link : Proves the migration is coherent without breaking runtime content.
  - Depends on: Task 9.
  - Validate with: `/home/claude/shipglowz/tools/shipglowz_metadata_lint.py shipglows_data`
  - Notes: Use `--all-markdown` only as an audit signal, not as a hard gate for runtime content, trackers, or excluded `contentglows/**`.

- [x] Task 11: Produce closure report
  - File: `shipglows_data/workflow/reports/markdown-governance-migration-closure-2026-05-11.md`
  - Action: Document moved files, pointer files, excluded runtime content, excluded trackers, archived files, redaction/security decisions, linter output, blocked classifications, `contentglows/**` exclusion, and rollback notes.
  - User story link : Gives the operator a final proof that no source-of-truth exception remains.
  - Depends on: Task 10.
  - Validate with: `git status --short` and `git diff --check`
  - Notes: Include exact validation commands and results. Do not include secret values or sensitive excerpts.

## Acceptance Criteria

- [x] CA 1: Given an in-scope project Markdown is a durable ShipGlowz artifact, when migration completes, then it is stored under `shipglows_data/**` with valid ShipGlowz frontmatter.
- [x] CA 2: Given a spec exists under legacy `shipglows_data/workflow/specs/app/`, `*/specs/`, `shipglows_data/workflow/specs/lab/SPEC-*.md`, or in-scope spec-like `docs/*.md`, when migration completes, then the active copy is under `shipglows_data/workflow/specs/**`.
- [x] CA 3: Given a bug record exists under `*/bugs/**`, when migration completes, then the active copy is under `shipglows_data/workflow/bugs/**` and passes metadata lint.
- [x] CA 4: Given a research, exploration, or QA artifact exists under in-scope `research/**` or `docs/**`, when migration completes, then the active copy is under `shipglows_data/workflow/research`, `explorations`, or `qa`.
- [x] CA 5: Given a runtime content file exists under `site/src/content/**`, when migration completes, then it still satisfies `site/src/content.config.ts` and has not received unsupported ShipGlowz fields.
- [x] CA 6: Given a tracker file exists, when migration completes, then it remains a tracker or pointer and does not become a decision contract with copied durable content.
- [x] CA 7: Given an in-scope legacy file remains outside `shipglows_data/**`, when opened after migration, then it is a short pointer, runtime content, tooling entrypoint, excluded tracker, or explicitly blocked item.
- [x] CA 8: Given old paths are searched, when `rg` runs for legacy locations, then only migration reports, historical evidence, or explicit pointer files mention them.
- [x] CA 9: Given metadata lint runs on canonical `shipglows_data/**` artifacts, when migration completes, then it passes without missing required fields.
- [x] CA 10: Given a fresh agent opens the repo, when it needs a spec, bug, research, QA, audit, or review, then repo guidance points it to `shipglows_data/workflow/**`.
- [x] CA 11: Given `contentglows/**` exists, when migration completes, then `git diff -- contentglows` is empty and migration reports state that it was intentionally excluded.
- [x] CA 12: Given a legacy file triggers the security preflight, when migration completes, then the file is redacted before canonical migration or listed as `blocked-security-review` without exposing sensitive values in reports.
- [x] CA 13: Given a file cannot be classified without a new product/archive decision, when migration completes, then it is listed as `blocked-classification` and no silent move is performed.
- [x] CA 14: Given a rollback is needed for one migration batch, when it is applied, then unrelated batches remain intact and no user code changes are reverted.

## Test Strategy

- Inventory checks:
  - `find . \( -path './.git' -o -path './site/node_modules' -o -path './lab/.flox' -o -path './lab/.pytest_cache' -o -path './contentglows' \) -prune -o -type f -name '*.md' -printf '%p\n' | sort`
  - `find . \( -path './shipglows_data' -o -path './contentglows' \) -prune -o -type f -name '*.md' -printf '%p\n' | sort`
- Security checks:
  - `rg -n -i "api[_-]?key|token|secret|password|bearer|authorization|cookie|private|localhost|supabase|service[_-]?role|webhook|client_secret" . -g '*.md' -g '!contentglows/**' -g '!node_modules/**' -g '!site/node_modules/**'`
- Metadata checks:
  - `/home/claude/shipglowz/tools/shipglowz_metadata_lint.py shipglows_data`
  - Optional audit only: `/home/claude/shipglowz/tools/shipglowz_metadata_lint.py --all-markdown <classified paths>`
- Reference checks:
  - `rg -n "shipglows_data/workflow/specs/lab/SPEC-|docs/technical|docs/editorial|docs/explorations|docs/qa|^research/|^specs/" . -g '*.md' -g '!site/src/content/**' -g '!contentglows/**'`
- Runtime checks:
  - `npm --prefix site run build` if site dependencies are installed and no unrelated build blockers exist.
- Git hygiene:
  - `git diff --check`
  - `git status --short`
  - `git diff -- contentglows`

## Risks

- High: moving specs can break ShipGlowz lifecycle commands that still assume `shipglows_data/workflow/specs/app/**`.
- High: adding ShipGlowz metadata to Astro runtime content can break content collections or public pages.
- High: legacy governance notes may contain secrets, private URLs, raw logs, or sensitive operational content that must not be copied into canonical artifacts or reports without redaction.
- Medium: legacy docs may be stale; migrating them as reviewed would create false authority.
- Medium: deleting old files too early can break links in changelogs, specs, README or trackers.
- Medium: broad search/move commands could accidentally touch excluded `contentglows/**` unless every command prunes it.
- Low: using pointer files may still look like exceptions unless they are short and clearly non-canonical.

## Execution Notes

- Read first:
  - `shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md`
  - `shipglows_data/workflow/specs/app/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md`
  - `site/src/content.config.ts`
  - `shipglows_data/technical/app/guidelines.md`
  - `shipglows_data/technical/lab/guidelines.md`
  - `shipglows_data/technical/site/guidelines.md`
- Implement by batches, not all at once: inventory, workflow directories, security preflight, specs, bugs, research/QA, lab legacy docs, pointers, references, validation, closure report.
- Prefer `git mv` during implementation to preserve history.
- Do not use `--all-markdown` as a success gate until runtime content and trackers are excluded from the hard gate.
- Avoid new packages and avoid custom parsing beyond shell inventory plus ShipGlowz metadata lint unless a batch proves it needs a dedicated script.
- Use structured move/classification tables in reports rather than ad hoc prose when listing many files.
- Stop condition: any runtime build failure caused by content frontmatter, any metadata lint failure in canonical artifacts, any unclassified full-body in-scope legacy Markdown left outside `shipglows_data/**`, any suspected sensitive content without redaction decision, or any diff under `contentglows/**`.
- Reroute condition: if an in-scope file cannot be classified without a product/archive decision, record `blocked-classification`; if a file requires security judgment beyond obvious redaction, record `blocked-security-review`.
- Fresh external docs verdict: `fresh-docs not needed`; local repo files define the migration behavior.

## Open Questions

- None. The operator confirmed on 2026-05-11 that `contentglows/**` is ignored entirely for this chantier. Runtime content and trackers are non-governance categories rather than forced ShipGlowz artifacts.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-11 | sf-spec | gpt-5 | création de la spec de migration Markdown globale sans exception de source de vérité | draft saved | /sf-ready shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md |
| 2026-05-11 | sf-ready | gpt-5 | readiness gate avant migration globale des Markdown | not ready | /sf-spec Global Markdown Governance Migration To ShipGlowz Data |
| 2026-05-11 | sf-spec | gpt-5 | updated spec after readiness gate: excluded contentglows, added security preflight, expanded acceptance criteria, aligned internal contract language | draft saved | /sf-ready shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md |
| 2026-05-11 | sf-ready | gpt-5 | readiness gate after spec update: checked structure, behavior contract, dependencies, security, language doctrine, and execution notes | ready | /sf-start shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md |
| 2026-05-11 | sf-start | gpt-5.4-codex | migration execution and validation for canonical markdown governance completed with path cleanup + new reports | implemented | /sf-verify shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md |
| 2026-05-11 | sf-verify | gpt-5 | verified migration execution and documentation consistency against spec contract, including metadata lint and legacy-path sweeps | verified | /sf-end shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md |
| 2026-05-11 | sf-end | gpt-5 | clôture documentaire/trace de migration markdown terminée, avec références TASKS/CHANGELOG et état de flux | closed | /sf-ship shipglows_data/workflow/specs/SPEC-global-markdown-governance-migration-2026-05-11.md |
| 2026-05-11 | sf-ship | gpt-5 | shipped global markdown governance migration and active-reference cleanup | shipped | none |

## Current Chantier Flow

- sf-spec: done
- sf-ready: ready
- sf-start: implemented
- sf-verify: verified
- sf-end: closed
- sf-ship: shipped

Next step: none
