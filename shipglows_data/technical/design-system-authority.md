---
artifact: design_system_authority
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-06-11"
updated: "2026-06-11"
status: "draft"
source_skill: "300-sf-docs"
scope: "design-system-authority"
owner: "Diane"
confidence: "high"
risk_level: "high"
security_impact: "no"
docs_impact: "yes"
content_surfaces:
  - "app"
  - "site"
linked_systems:
  - "tools/design-tokens/contentglows_theme.json"
  - "tools/design-tokens/generate_app_theme_tokens.mjs"
  - "app/lib/presentation/theme/app_theme_tokens.dart"
  - "app/lib/presentation/theme/app_theme.dart"
  - "site/src/layouts/Layout.astro"
depends_on:
  - artifact: "shipglows_data/technical/app/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/site/guidelines.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/app/context.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/technical/site/context.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
supersedes: []
evidence:
  - "Code scan: `app/lib/presentation/theme/app_theme_tokens.dart` and `app/lib/presentation/theme/app_theme.dart` are explicit Flutter token layers."
  - "Site scan: `site/src/layouts/Layout.astro` injects shared CSS variables from `tools/design-tokens/contentglows_theme.json`."
  - "Token generator source: `tools/design-tokens/generate_app_theme_tokens.mjs` transforms `tools/design-tokens/contentglows_theme.json` into `app_theme_tokens.dart`."
  - "Cross-project design-token drift baseline: `python3 /home/claude/shipglowz/tools/design_system_drift_check.py --root /home/claude/contentglows --warn-only --format markdown --max-findings 5000`."
next_step: "run 503-sf-audit-design-tokens contentglows"
---

# ContentGlows Design-System Authority

## 1) Canonical token sources

### App (Flutter)
- **Primary source**: `tools/design-tokens/contentglows_theme.json`
- **Token adapter**: `tools/design-tokens/generate_app_theme_tokens.mjs`
- **Theme mapping**: `app/lib/presentation/theme/app_theme_tokens.dart` and `app/lib/presentation/theme/app_theme.dart`

### Site (Astro)
- **Primary source**: `tools/design-tokens/contentglows_theme.json`
- **Theme injection**: `site/src/layouts/Layout.astro`

## 2) Authoritative rule

Any change introducing or modifying **colors, typography, spacing, radii, shadows, motion, or layout tokens** must go through the canonical files above first.

- Flutter UI must use `AppThemeTokens`, `AppSpacing`, `AppRadii`, `AppText`, and `Theme.of(context)` helpers.
- Site UI must use `var(--*)` tokens (or component-local variables derived from them).
- New visual values in non-authoritative files are only valid when:
  1. the value is clearly non-visual (for example media dimensions, API payloads), or
  2. an explicit temporary exception is approved in this document.

## 3) Required token map

### App tokens
- Colors: `AppThemeTokens.*`
- Typography: `AppThemeTokens.text*`, `AppText.*`
- Spacing: `AppThemeTokens.spacing*`, `AppSpacing.*`
- Motion: `AppThemeTokens.duration*`, `standardMotion`, `outMotion`, `springMotion`
- Shadows: via `AppTheme` palette and theme-level shadow usage
- Radii: `AppThemeTokens.radius*`, `AppRadii.*`
- Layout: `AppThemeTokens.mobileBreakpoint`, `tabletBreakpoint`, `desktopBreakpoint`

### Site tokens
- Palette: `--color-*`
- Typography scale: `--text-*`
- Spacing: `--space-*`
- Radii: `--radius-*`
- Shadows: `--shadow-*`
- Motion: `--duration-*`, `--ease-*`
- Layout: `--container-max-width`, `--section-gap`, `--hero-gap`, `--cta-width`

## 4) Enforcement guardrails (mandatory)

1. No ad-hoc `Color(0x...)`, hex (`#rrggbb`), `rgb(...)`, `oklch(...)`, or literal px/rem/em/dvh/vw/vh in UI code.
2. No inline `style` blocks/attributes for layout/typography/visual properties unless they resolve from token vars/constants.
3. Motion constants (`duration`, `cubic-bezier`, animation timing) must be tokenized.
4. No component-level `if (themeIsDark)` visual branches in production UI; branch at token/theme layer.
5. Any new hard-coded visual value in Flutter must be paired with a matching token update before merge.

## 5) Temporary exceptions

- `app/web_auth/clerk-auth.css` is an external Clerk auth shell and keeps legacy values until migrated behind shared tokens.
- `site/dist/**` and other generated build artifacts are non-authoritative.
- `lab/venv/**` and other dependency artifacts are out of scope of product UI contracts.

## 6) Change process

For every style-related commit:
1. Update canonical token source first (`tools/design-tokens/contentglows_theme.json`) or the token injection path that feeds both app and site.
2. Regenerate app tokens where relevant.
3. Consume the value through shared helpers/variables.
4. Run the token-drift check with generated/output artifacts excluded from evidence.

## 7) Acceptance criteria

- No new visual hard-coded values are introduced in production UI component code without a token update.
- Any visual styling change remains traceable to the canonical sources listed in section 1.
- Any direct visual exception is documented in this artifact before merge.
