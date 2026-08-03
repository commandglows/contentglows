---
artifact: technical_docs_index
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: app
created: "2026-05-06"
updated: "2026-05-06"
status: draft
source_skill: sf-docs
scope: technical-docs
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
depends_on: []
supersedes: []
evidence:
  - "app is a Flutter application with Android native integration and tests."
next_review: "2026-06-06"
next_step: "/sf-docs technical audit app"
---

# Technical Docs

This directory maps code areas that need durable technical context before future ShipGlowz edits.

Start with `code-docs-map.md`. Load only the mapped module context for the files being changed.

## Current Coverage

- `flutter-app-shell-and-capture.md`: Flutter app entrypoints, routing, provider state, offline/API services, Android capture integration, and focused validations.

## Maintenance Rule

Update this index and `code-docs-map.md` when a new app subsystem gets a technical module context or when mapped files move.
