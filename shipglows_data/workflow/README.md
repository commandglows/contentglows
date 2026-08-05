# workflow data index

This directory is the canonical container for durable governance workflow Markdown for
the monorepo. Canonical paths under this folder are the active source of truth for
specifications, bugs, research, QA artifacts, reports, and workflow documents that are
outside runtime content.

Directory layout:

- `specs/` — workflow specs and migrated legacy spec-like documents
  - `specs/monorepo/` (legacy root specs and global migration specs)
  - `specs/app/` (application project specs)
  - `specs/lab/` (lab project specs and root `SPEC-*.md`)
  - `specs/site/` (site project specs)
- `bugs/` — bug records and issue traces
- `research/` — research dossiers and decision notes
- `explorations/` — exploration notes
- `qa/` — quality matrices and QA evidence
- `audits/` — formal audit outputs
- `reviews/` — review notes and peer review artifacts
- `conversations/` — feature conversation artifacts
- `archives/` — stable historical artifacts retained for traceability
- `reports/` — run reports, migration reports, and security preflights
- `TASKS.md` and `AUDIT_LOG.md` — monorepo-level operational trackers

Subproject-local trackers live with each subproject when they exist:

- `shipglows_data/workflow/app/TASKS.md`
- `shipglows_data/workflow/app/AUDIT_LOG.md`
- `shipglows_data/workflow/lab/TASKS.md`
- `shipglows_data/workflow/lab/AUDIT_LOG.md`
- `shipglows_data/workflow/site/TASKS.md`
- `shipglows_data/workflow/site/AUDIT_LOG.md`

Entry rule:

- Runtime content and editorial pages under `site/src/content/**` remain in
  `site/src/content`.
- `contentglows/**` is intentionally excluded from this migration.
