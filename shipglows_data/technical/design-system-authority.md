---
artifact: design_system_authority
metadata_schema_version: "1.0"
artifact_version: "1.1.0"
project: "contentglows"
created: "2026-06-11"
updated: "2026-08-20"
status: "active"
source_skill: "sg-design"
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
  - "ShipGlows runtime owns the central design-drift contract and checker; ContentGlows does not duplicate that enforcement in project tooling."
  - "2026-08-20 source inspection confirmed the site consumes the shared JSON through Layout CSS variables and Flutter consumes generated tokens through AppTheme helpers."
next_step: "Run the central ShipGlows design-drift and visual proof path in a session that permits local execution."
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
- New visual values in non-authoritative files are valid only under the explicit
  exception policy in section 5.

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

## 5) Explicit exceptions

- User-provided brand colors and other project data remain data, not fixed UI
  decisions; their surrounding surfaces, states, and contrast treatment still
  resolve through the theme.
- Intrinsic media dimensions, aspect ratios, canvas coordinates, waveform/video
  timeline geometry, sampling values, and protocol or platform-required
  constants may remain local when naming them as design tokens would obscure
  their technical meaning.
- Values calculated from runtime constraints, `MediaQuery`, safe areas, keyboard
  insets, or content measurements remain local and adaptive.
- Generated outputs and the design playground may display resolved raw values as
  documentation, but they are not independent sources of visual truth.
- `app/web_auth/clerk-auth.css` remains an external Clerk shell exception until
  it can consume the shared source without weakening the provider integration.
- Build and dependency artifacts are non-authoritative and remain outside the
  product UI contract.

## 6) Change process

For every style-related change:
1. Update canonical token source first (`tools/design-tokens/contentglows_theme.json`) or the token injection path that feeds both app and site.
2. Regenerate app tokens where relevant.
3. Consume the value through shared helpers/variables.
4. Let ShipGlows run its central token-drift check with generated/output
   artifacts excluded from evidence; do not add a duplicate project-local guard.
5. Collect proportional visual and accessibility proof before claiming the
   design chantier verified or closed.

## 7) Acceptance criteria

- No new visual hard-coded values are introduced in production UI component code without a token update.
- Any visual styling change remains traceable to the canonical sources listed in section 1.
- Any direct visual exception is documented in this artifact before merge.
- ContentGlows owns token consumption; ShipGlows owns coherence verification.
