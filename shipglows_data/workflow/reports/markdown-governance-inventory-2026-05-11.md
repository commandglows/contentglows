# Markdown Governance Inventory Report

Date: 2026-05-11
Project: contentglowz
Scope command:

```bash
find . \( -path './.git' -o -path './site/node_modules' -o -path './lab/.flox' -o -path './lab/.pytest_cache' -o -path './contentglowz' \) -prune -o -type f -name '*.md' -printf '%p\n' | sort
```

## Summary

- Total Markdown files scanned: **194**
- In `shipglows_data/`: **76**
- Outside `shipglows_data/`: **118**
  - Runtime content under `site/src/content/**`: **46**
  - Non-workflow Markdown outside `shipglows_data` and runtime: **72**
- Migration moves executed: **74** files (all via `git mv`)
- New canonical families created/updated under `shipglows_data/workflow/`

## Migration Target Distribution

| Destination Family | Count |
|-------------------|------:|
| `specs` | 47 |
| `bugs` | 4 |
| `research` | 14 |
| `explorations` | 6 |
| `qa` | 1 |
| `reports` | 2 |

## Full Source → Target Mapping

| Source path | Canonical path |
|------------|----------------|
| app/bugs/BUG-2026-05-05-001.md | shipglows_data/workflow/bugs/app/BUG-2026-05-05-001.md |
| app/bugs/BUG-2026-05-05-002.md | shipglows_data/workflow/bugs/app/BUG-2026-05-05-002.md |
| app/specs/PRD-lifetime-deal-early-bird-payg.md | shipglows_data/workflow/specs/app/PRD-lifetime-deal-early-bird-payg.md |
| app/specs/SPEC-android-device-screen-capture.md | shipglows_data/workflow/specs/app/SPEC-android-device-screen-capture.md |
| app/specs/SPEC-android-privacy-capture-dynamic-redaction.md | shipglows_data/workflow/specs/app/SPEC-android-privacy-capture-dynamic-redaction.md |
| app/specs/SPEC-content-editing-full-body-preview.md | shipglows_data/workflow/specs/app/SPEC-content-editing-full-body-preview.md |
| app/specs/SPEC-content-editing-infrastructure.md | shipglows_data/workflow/specs/app/SPEC-content-editing-infrastructure.md |
| app/specs/SPEC-content-editor-multiformat.md | shipglows_data/workflow/specs/app/SPEC-content-editor-multiformat.md |
| app/specs/SPEC-content-pipeline-unification.md | shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md |
| app/specs/SPEC-local-capture-assets-linked-to-content.md | shipglows_data/workflow/specs/app/SPEC-local-capture-assets-linked-to-content.md |
| app/specs/SPEC-migrate-flutter-core-majors.md | shipglows_data/workflow/specs/app/SPEC-migrate-flutter-core-majors.md |
| app/specs/SPEC-mobile-flow-dashboard-swipe-actions.md | shipglows_data/workflow/specs/app/SPEC-mobile-flow-dashboard-swipe-actions.md |
| app/specs/SPEC-offline-sync-v2.md | shipglows_data/workflow/specs/app/SPEC-offline-sync-v2.md |
| app/specs/SPEC-privacy-capture-post-production-review.md | shipglows_data/workflow/specs/app/SPEC-privacy-capture-post-production-review.md |
| app/specs/SPEC-project-flows-selection-onboarding-archive.md | shipglows_data/workflow/specs/app/SPEC-project-flows-selection-onboarding-archive.md |
| app/specs/SPEC-shared-privacy-capture-contract.md | shipglows_data/workflow/specs/app/SPEC-shared-privacy-capture-contract.md |
| app/specs/SPEC-video-script-creation-workbench.md | shipglows_data/workflow/specs/app/SPEC-video-script-creation-workbench.md |
| app/specs/SPEC-web-privacy-capture-dynamic-redaction.md | shipglows_data/workflow/specs/app/SPEC-web-privacy-capture-dynamic-redaction.md |
| app/specs/SPEC-windows-privacy-capture-dynamic-redaction.md | shipglows_data/workflow/specs/app/SPEC-windows-privacy-capture-dynamic-redaction.md |
| app/specs/architecture-cible-fastapi-clerk-flutter.md | shipglows_data/workflow/specs/app/architecture-cible-fastapi-clerk-flutter.md |
| app/specs/conversation-local-capture-assets-linked-to-content-20260505.md | shipglows_data/workflow/specs/app/conversation-local-capture-assets-linked-to-content-20260505.md |
| app/specs/feedback-admin-v1-contentglowz.md | shipglows_data/workflow/specs/app/feedback-admin-v1-contentglowz.md |
| app/specs/feedback-backend-contract-fastapi.md | shipglows_data/workflow/specs/app/feedback-backend-contract-fastapi.md |
| app/specs/foundation-scrollable-nav-affiliations.md | shipglows_data/workflow/specs/app/foundation-scrollable-nav-affiliations.md |
| app/specs/late-integration-finalization.md | shipglows_data/workflow/specs/app/late-integration-finalization.md |
| app/specs/migrate-flutter-core-majors-baseline.md | shipglows_data/workflow/specs/app/migrate-flutter-core-majors-baseline.md |
| app/specs/spec-no-ui-jump-on-resume.md | shipglows_data/workflow/specs/app/spec-no-ui-jump-on-resume.md |
| lab/AGENT_MEMORY_RESEARCH.md | shipglows_data/workflow/research/lab/AGENT_MEMORY_RESEARCH.md |
| lab/BACKLINK_CHECKER.md | shipglows_data/workflow/research/lab/BACKLINK_CHECKER.md |
| lab/CONCURRENT.md | shipglows_data/workflow/research/lab/CONCURRENT.md |
| lab/CONTENT_GUIDELINES.md | shipglows_data/workflow/research/lab/CONTENT_GUIDELINES.md |
| lab/CONTENT_INVENTORY.md | shipglows_data/workflow/research/lab/CONTENT_INVENTORY.md |
| lab/COST-MODEL.md | shipglows_data/workflow/research/lab/COST-MODEL.md |
| lab/ENVIRONMENT_shipglows_data/technical/SETUP.md | shipglows_data/workflow/research/lab/ENVIRONMENT_shipglows_data/technical/SETUP.md |
| lab/SPEC-branding.md | shipglows_data/workflow/specs/lab/SPEC-branding.md |
| lab/SPEC-competitor-analysis.md | shipglows_data/workflow/specs/lab/SPEC-competitor-analysis.md |
| lab/SPEC-compliance.md | shipglows_data/workflow/specs/lab/SPEC-compliance.md |
| lab/SPEC-content-crawling.md | shipglows_data/workflow/specs/lab/SPEC-content-crawling.md |
| lab/SPEC-crawlee-hybrid.md | shipglows_data/workflow/specs/lab/SPEC-crawlee-hybrid.md |
| lab/SPEC-mcpc-universal-mcp.md | shipglows_data/workflow/specs/lab/SPEC-mcpc-universal-mcp.md |
| lab/SPEC-newsletter-receiving.md | shipglows_data/workflow/specs/lab/SPEC-newsletter-receiving.md |
| lab/SPEC-newsletter-sending.md | shipglows_data/workflow/specs/lab/SPEC-newsletter-sending.md |
| lab/SPEC-seo-monitoring.md | shipglows_data/workflow/specs/lab/SPEC-seo-monitoring.md |
| lab/SPEC-workflow-visualization.md | shipglows_data/workflow/specs/lab/SPEC-workflow-visualization.md |
| lab/TOOLS.md | shipglows_data/workflow/research/lab/TOOLS.md |
| lab/bugs/BUG-2026-05-06-001.md | shipglows_data/workflow/bugs/lab/BUG-2026-05-06-001.md |
| lab/bugs/BUG-2026-05-10-001.md | shipglows_data/workflow/bugs/lab/BUG-2026-05-10-001.md |
| lab/docs/license-inventory.md | shipglows_data/workflow/reports/lab/license-inventory.md |
| lab/docs/optional-integrations.md | shipglows_data/workflow/reports/lab/optional-integrations.md |
| lab/specs/ANALYSIS-drip-integration-with-existing.md | shipglows_data/workflow/specs/lab/ANALYSIS-drip-integration-with-existing.md |
| lab/specs/DRIP_IMPLEMENTATION.md | shipglows_data/workflow/specs/lab/DRIP_IMPLEMENTATION.md |
| lab/specs/SPEC-backend-persona-autofill-repo-understanding-user-keys.md | shipglows_data/workflow/specs/lab/SPEC-backend-persona-autofill-repo-understanding-user-keys.md |
| lab/specs/SPEC-dual-mode-ai-runtime-all-providers.md | shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md |
| lab/specs/SPEC-migrate-pydantic-ai-major.md | shipglows_data/workflow/specs/lab/SPEC-migrate-pydantic-ai-major.md |
| lab/specs/SPEC-progressive-content-release.md | shipglows_data/workflow/specs/lab/SPEC-progressive-content-release.md |
| lab/specs/SPEC-strict-byok-llm-app-visible-ai.md | shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md |
| lab/specs/social-listener.md | shipglows_data/workflow/specs/lab/social-listener.md |
| site/docs/conversations/conversation-feature-capture-ecran-video-20260504.md | shipglows_data/workflow/research/site/conversation-feature-capture-ecran-video-20260504.md |
| site/docs/copywriting/parcours-client.md | shipglows_data/workflow/research/site/parcours-client.md |
| site/docs/copywriting/persona.md | shipglows_data/workflow/research/site/persona.md |
| site/docs/copywriting/strategie.md | shipglows_data/workflow/research/site/strategie.md |
| site/docs/spec-i18n-structure.md | shipglows_data/workflow/research/site/spec-i18n-structure.md |
| site/specs/SPEC-migrate-astro-v6.md | shipglows_data/workflow/specs/site/SPEC-migrate-astro-v6.md |
| docs/centraliser-design-tokens-contentglowz-app-site.md | shipglows_data/workflow/specs/monorepo/centraliser-design-tokens-contentglowz-app-site.md |
| docs/explorations/2026-05-06-screen-text-obfuscation.md | shipglows_data/workflow/explorations/2026-05-06-screen-text-obfuscation.md |
| docs/explorations/2026-05-08-ios-privacy-capture-redaction.md | shipglows_data/workflow/explorations/2026-05-08-ios-privacy-capture-redaction.md |
| docs/explorations/2026-05-08-linux-privacy-capture-redaction.md | shipglows_data/workflow/explorations/2026-05-08-linux-privacy-capture-redaction.md |
| docs/explorations/2026-05-08-macos-privacy-capture-redaction.md | shipglows_data/workflow/explorations/2026-05-08-macos-privacy-capture-redaction.md |
| docs/explorations/2026-05-08-web-privacy-capture-redaction.md | shipglows_data/workflow/explorations/2026-05-08-web-privacy-capture-redaction.md |
| docs/explorations/2026-05-08-windows-privacy-capture-redaction.md | shipglows_data/workflow/explorations/2026-05-08-windows-privacy-capture-redaction.md |
| docs/qa/privacy-capture-platform-matrix.md | shipglows_data/workflow/qa/lab/privacy-capture-platform-matrix.md |
| research/android-privacy-screen-redaction-technologies.md | shipglows_data/workflow/research/shared/android-privacy-screen-redaction-technologies.md |
| specs/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md | shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md |
| specs/SPEC-user-imap-email-source-to-idea-pool-2026-05-10.md | shipglows_data/workflow/specs/monorepo/SPEC-user-imap-email-source-to-idea-pool-2026-05-10.md |
