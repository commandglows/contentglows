---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "site"
created: "2026-06-12"
created_at: "2026-06-12 12:03:54 UTC"
updated: "2026-06-12"
updated_at: "2026-06-12 12:45:00 UTC"
status: ready
source_skill: 100-sf-spec
source_model: "GPT-5 Codex"
scope: "feature"
owner: "Diane"
confidence: "high"
user_story: "En tant que visiteur francophone ou anglophone du site ContentGlowz, je veux accéder aux pages coeur dans ma langue avec des URLs et métadonnées cohérentes, afin de comprendre l'offre et entrer dans l'app sans ambiguïté de langue ni dette SEO."
risk_level: "high"
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "Astro static routing"
  - "Layout metadata generation"
  - "Marketing conversion pages"
  - "App handoff routes"
  - "Sitemap and canonical SEO signals"
depends_on:
  - artifact: "site/CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/editorial/site/content-map.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/editorial/site/page-intent-map.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/editorial/site/editorial-update-gate.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/editorial/site/claim-register.md"
    artifact_version: "0.1.0"
    required_status: "draft"
  - artifact: "shipglows_data/technical/design-system-authority.md"
    artifact_version: "1.0.0"
    required_status: "draft"
supersedes: []
evidence:
  - "site/src/layouts/Layout.astro hardcodes html lang=en and emits canonical/og:url without locale alternates."
  - "site/src/pages/index.astro"
  - "site/src/pages/launch.astro"
  - "site/src/pages/sign-in.astro"
  - "site/src/pages/sign-up.astro"
  - "site/src/pages/privacy.astro"
  - "User decision 2026-06-12: site bilingue fr/en, root=en, scope=coeur."
next_step: "/101-sf-ready shipglows_data/workflow/specs/site/SPEC-bilingual-fr-en-routing-seo-metadata-core-pages-2026-06-12.md"
---

## Title
Implement bilingual `fr/en` routing and SEO metadata for ContentGlowz core site pages

## Status
Ready. Scope, locale decisions, proof path, and bounded implementation plan are explicit enough for immediate execution.

## User Story
En tant que visiteur francophone ou anglophone du site ContentGlowz, je veux accéder aux pages coeur dans ma langue avec des URLs et métadonnées cohérentes, afin de comprendre l'offre et entrer dans l'app sans ambiguïté de langue ni dette SEO.

Actor: visiteur marketing public.

Trigger: ouverture directe d'une URL coeur, navigation depuis le header/footer, ou indexation par un moteur de recherche.

Observable result: l'anglais reste servi à la racine (`/`, `/launch`, `/sign-in`, `/sign-up`, `/privacy`), le français vit sous `/fr/...`, chaque page annonce la bonne langue, et les alternates SEO n'existent que quand la paire EN/FR existe réellement.

## Minimal Behavior Contract
Le site sert cinq pages coeur en anglais à la racine et leurs équivalents français sous `/fr`, en passant à `Layout.astro` la locale, le `lang`, le canonical et les alternates `hreflang` exacts. Si une page n'a pas encore d'équivalent dans l'autre langue, elle garde un canonical correct mais n'émet pas de faux alternate. Les pages de handoff app (`/launch`, `/sign-in`, `/sign-up`) conservent leur redirection et leur transmission éventuelle de `redirect_url`. L'edge case facile à rater est la publication d'un `hreflang="fr"` ou `x-default` vers une page absente, ce qui créerait un signal SEO faux.

## Success Behavior
Après implémentation:

- `/`, `/launch`, `/sign-in`, `/sign-up`, `/privacy` restent en anglais.
- `/fr`, `/fr/launch`, `/fr/sign-in`, `/fr/sign-up`, `/fr/privacy` existent et rendent un contenu français naturel avec tutoiement et accents.
- `Layout.astro` reçoit une locale explicite par page et rend `<html lang="en">` ou `<html lang="fr">` selon la route.
- Chaque page coeur émet un `<link rel="canonical">` cohérent avec son URL publique.
- Chaque paire bilingue émet des alternates `hreflang="en"` et `hreflang="fr"`.
- Les pages anglaises racine émettent `x-default` vers la version anglaise.
- `og:url` suit le canonical localisé.
- Les pages de handoff conservent `noindex` et leur comportement de redirection.
- La navigation visible des pages coeur permet de changer de langue sans casser le tunnel.
- `npm run build` passe et le build statique génère les nouvelles routes `/fr/...`.

## Error Behavior
Si une page française coeur manque ou n'est pas prête:

- l'implémentation ne doit pas publier d'alternate vers une URL absente;
- la page existante conserve seulement son canonical et ses métadonnées locales;
- la navigation de changement de langue doit masquer ou désactiver l'entrée correspondante plutôt que pointer vers une 404;
- les pages de handoff ne doivent jamais perdre leur redirection app ni leur `redirect_url`;
- aucun contenu FR ne doit être servi avec `lang="en"` ni l'inverse;
- le chantier ne doit pas étendre en douce le blog ou les collections éditoriales hors scope.

## Problem
Le site marketing ContentGlowz contient déjà des surfaces EN et du contenu FR/EN mixte, mais son socle technique reste mono-locale. `Layout.astro` force actuellement `<html lang="en">`, le canonical est calculé uniquement depuis `Astro.url.pathname`, et aucun `hreflang` n'est émis. Sans stratégie de locale explicite, Google et les visiteurs voient un corpus bilingue mal signalé, et l'équipe ne peut pas corriger proprement les pages coeur sans choisir une structure d'URLs et de métadonnées.

Le produit a maintenant tranché la stratégie: anglais à la racine, français sous `/fr`, priorité aux pages coeur seulement. Le chantier doit traduire cette décision en contrat de routing et SEO sans promettre un blog bilingue global qui n'existe pas encore.

## Solution
Introduire une petite couche i18n site-side, limitée aux pages coeur:

1. définir un contrat de locale partagé (`en` racine, `fr` préfixé);
2. enrichir `Layout.astro` pour recevoir `locale`, `canonicalUrl`, `alternateLocales`, et calculer `lang`, `og:url`, `canonical`, `hreflang`, et éventuellement `x-default`;
3. créer les routes françaises `/fr/...` pour les cinq pages coeur;
4. extraire le contenu coeur dans une source locale simple et explicite, réutilisable par EN et FR sans dupliquer la logique de redirection ou la structure des sections;
5. ajuster navigation/footer/CTA visibles pour permettre le changement de langue seulement sur les pages coeur prises en charge.

La solution reste volontairement bornée: aucun routage de collections Markdown, aucun auto-detect par navigateur, aucune redirection géolocalisée, aucun fallback silencieux du blog vers `/fr`.

## Scope In
- `site/src/layouts/Layout.astro`
- `site/src/pages/index.astro`
- `site/src/pages/launch.astro`
- `site/src/pages/sign-in.astro`
- `site/src/pages/sign-up.astro`
- `site/src/pages/privacy.astro`
- nouvelles routes `site/src/pages/fr/*.astro` pour ces cinq surfaces
- composants communs ou helper(s) nécessaires au changement de langue sur les pages coeur
- source de données locale simple pour les strings coeur EN/FR si elle réduit la duplication
- métadonnées SEO coeur: `html lang`, canonical, `og:url`, `hreflang`, `x-default`, `noindex`
- validation build statique des routes coeur `/fr`

## Scope Out
- blog, `src/content/**`, collections dynamiques, et routes d'articles
- stratégie bilingue du sitemap global au-delà des pages coeur si le build actuel n'inclut pas encore ces surfaces
- détection automatique de langue par navigateur, cookie, ou géolocalisation
- traduction complète de tous les composants marketing non utilisés par les cinq pages coeur
- refonte copywriting/GTM au-delà de la traduction nécessaire pour EN/FR
- changement de branding, design-system, ou structure visuelle hors adaptations minimales de navigation de langue
- app Flutter et backend FastAPI

## Constraints
- La décision produit est figée: `root=en`, français sous `/fr`, scope coeur uniquement.
- Les pages coeur anglaises existantes à la racine doivent continuer à fonctionner aux mêmes URLs.
- Les pages de handoff app gardent `noindex` et leur redirection immédiate.
- Le site reste statique Astro; pas de middleware de détection de locale.
- Le français visible doit respecter `CLAUDE.md`: tutoiement et accents corrects.
- Toute copy modifiée sur les pages publiques passe par l'Editorial Update Gate et doit rester prudente sur les claims AI, privacy, pricing et performance.
- Les alternates SEO doivent être exacts: ne jamais annoncer une page non publiée.
- La mise en oeuvre doit rester reviewable et éviter une duplication logique inutile entre EN et FR.
- Aucun changement ne doit casser les liens app issus de `src/config/site.ts`.
- Toute adaptation visuelle liée au switcher de langue, à la nav ou au footer doit réutiliser les tokens existants de `tools/design-tokens/contentglowz_theme.json` injectés par `Layout.astro`; aucun nouveau literal visuel ad hoc.

## Test Contract
- surface: `Astro marketing site core pages`
- proof_profile: `static-build + source inspection`
- proof_order:
  1. `npm run build`
  2. inspect generated routes for `/fr` core pages
  3. inspect rendered HTML for representative EN and FR pages
  4. optional browser smoke only if local HTML inspection leaves ambiguity
- checklist_path: `None, because static source/build proof is sufficient for this bounded phase`
- required_scenario_ids:
  - `core-en-home-metadata`
  - `core-fr-home-metadata`
  - `core-en-fr-hreflang-pair`
  - `core-handoff-redirect-preserved`
  - `core-language-switch-no-broken-link`
- required_results:
  - EN root page emits `lang=en`, canonical `/`, `hreflang` to `/fr`, and `x-default` to `/`
  - FR root page emits `lang=fr`, canonical `/fr`, and reciprocal alternate to `/`
  - EN and FR privacy pages emit localized canonical and reciprocal alternates
  - EN and FR handoff pages keep `noindex` and preserve redirect logic
  - build output contains `/fr/index.html`, `/fr/privacy/index.html`, and French handoff pages
- exception_with_proof:
  - Full browser QA may be skipped if static build output and source inspection prove route generation, metadata, and redirect scripts exactly.
- exception_without_proof: `None`

## Dependencies
Internal:

- `site/CLAUDE.md`: language and cross-repo contract notes.
- `shipglows_data/editorial/site/content-map.md`: scope authority for landing and conversion pages.
- `shipglows_data/editorial/site/page-intent-map.md`: route intent and CTA constraints.
- `shipglows_data/editorial/site/editorial-update-gate.md`: required editorial closure path for public-copy changes.
- `shipglows_data/editorial/site/claim-register.md`: claim guardrails for AI, privacy, pricing, and outcome wording.
- `shipglows_data/technical/design-system-authority.md`: token and styling guardrails for any visible navigation/switcher change.
- `site/src/config/site.ts`: canonical site URL and app handoff URLs.
- `site/src/layouts/Layout.astro`: current metadata authority.
- `site/src/components/*` used by the homepage and shared shell.

External docs freshness verdict:

- `fresh-docs not needed` for the spec and first implementation pass because the chosen routing strategy is fully defined by existing Astro static file conventions already used in the repo; no new framework feature or external service contract is required.

## Invariants
- `https://contentglowz.com` remains the canonical site origin unless `APP_SITE_URL` overrides it.
- English remains the default public locale at the root paths.
- French public core pages live under `/fr`.
- Core English pages keep their current public paths.
- App URLs continue to come from `src/config/site.ts`.
- Redirect pages stay `noindex`.
- No blog/article route behavior changes in this phase.

## Links & Consequences
Upstream:

- Root locale decision from the operator governs every metadata and route choice here.
- `siteUrl` from `src/config/site.ts` remains the base for canonical URLs.

Downstream:

- Navbar/footer/homepage CTA components may need locale-aware links or labels.
- SEO signals for core pages become trustworthy enough to extend later to collections.
- Future blog bilingual work should reuse the same locale contract rather than invent another one.
- If sitemap generation auto-discovers all pages, French core URLs will join the sitemap automatically after build; that is acceptable in phase 1.
- Any docs or future onboarding guidance referencing sign-in or sign-up paths should mention both locale entrypoints only if user-facing support needs it.

## Documentation Coherence
- Update this spec after implementation with exact file decisions and proof notes.
- Apply an Editorial Update Plan for any changed public copy on `/`, `/fr`, `/privacy`, or the handoff pages, even if the outcome is `no editorial impact` for some surfaces.
- Update `shipglows_data/workflow/site/TASKS.md` and closure artifacts during lifecycle end, not during spec creation.
- No README or product-doc update is required unless navigation labels or support copy become materially bilingual outside the five pages.
- If a reusable locale contract/helper is introduced, `site/CLAUDE.md` may need a short note after implementation for future agents.

## Edge Cases
- `/fr` should resolve as the French homepage, not require `/fr/` knowledge from callers.
- `Astro.url.pathname` may or may not contain a trailing slash in different environments; canonical building must normalize consistently.
- `x-default` should point only to English root-path pages, not to French URLs.
- French routes must not duplicate redirect logic incorrectly and accidentally remove `redirect_url` forwarding.
- Shared homepage components may contain embedded English copy; if they cannot be localized cleanly in this phase, they must be refactored into content-driven props rather than left mixed-language.
- Footer/nav links must not send French visitors back to English-only pages without an explicit decision.
- `privacy` text is legal-adjacent; translation must preserve meaning and not invent compliance claims.

## Implementation Tasks
- [ ] Task 1: Create the locale contract and metadata helpers
  - Files: `site/src/layouts/Layout.astro`, new helper(s) under `site/src/lib` or `src/data`
  - Action: add explicit props/types for `locale`, `canonicalUrl`, and `alternateLocales`; normalize localized canonical generation and `hreflang` rendering in one place.
  - Validation: source inspection shows no hardcoded `<html lang="en">` left for localized pages.

- [ ] Task 2: Extract or define bilingual content for the five core pages
  - Files: new locale data file(s) under `site/src/data` or page-local shared modules
  - Action: move user-facing strings for the five core pages into a small EN/FR structure, preserving redirect behavior and page intent.
  - Validation: each page can render EN and FR without mixed-language literals.

- [ ] Task 3: Localize the homepage and shared shell for core scope
  - Files: `site/src/pages/index.astro`, homepage components touched by visible copy, navbar/footer if needed
  - Action: feed localized props/content into homepage sections; add a safe language switcher or locale-aware links for supported pages.
  - Validation: EN homepage remains at `/`; FR homepage exists at `/fr`.

- [ ] Task 4: Create French route files for handoff and privacy pages
  - Files: `site/src/pages/fr/index.astro`, `fr/launch.astro`, `fr/sign-in.astro`, `fr/sign-up.astro`, `fr/privacy.astro`
  - Action: implement French routes by reusing shared content/logic and preserving `noindex` and redirect scripts where applicable.
  - Validation: build output contains each `/fr/...` route.

- [ ] Task 5: Ensure reciprocal alternate and canonical coverage only for published pairs
  - Files: all five EN pages, all five FR pages, `Layout.astro`
  - Action: pass exact alternate definitions per page and add `x-default` for English roots.
  - Validation: rendered EN/FR HTML shows reciprocal alternates and correct canonical/og:url.

- [ ] Task 6: Run bounded validation and capture proof
  - Files: generated `dist/**` and lifecycle artifacts
  - Action: run `npm run build`, inspect representative generated HTML, and record any remaining gap before closure.
  - Validation: required scenarios from the Test Contract all pass.

## Acceptance Criteria
- [ ] AC1: `Layout.astro` supports localized `lang`, canonical, `og:url`, and alternate rendering without hardcoded English-only metadata.
- [ ] AC2: Visiting `/` yields the English homepage; visiting `/fr` yields the French homepage.
- [ ] AC3: `/launch`, `/sign-in`, `/sign-up`, and `/privacy` each have a functioning French counterpart under `/fr/...`.
- [ ] AC4: Every published EN/FR core pair emits reciprocal `hreflang` links; English pages also emit `x-default` to the English URL.
- [ ] AC5: Redirect pages remain `noindex` and preserve current app handoff behavior, including `redirect_url` forwarding where already supported.
- [ ] AC6: No page in this phase emits an alternate link toward a missing locale page.
- [ ] AC7: French visible copy uses natural French with tutoiement and accents.
- [ ] AC8: `npm run build` passes and generates the new `/fr` core routes.

## Test Strategy
- Use project build as the primary regression gate.
- Inspect generated HTML for `/index.html`, `/fr/index.html`, `/privacy/index.html`, `/fr/privacy/index.html`, and at least one redirect page pair.
- Grep the generated HTML for `lang=`, canonical, `hreflang`, `og:url`, and `noindex`.
- If a nav language switcher is introduced, verify links in source and output HTML to ensure no broken target.

## Risks
- Shared homepage components may embed too much English copy, causing a wider-than-expected refactor.
- Partial bilingual nav can accidentally expose unsupported French routes outside scope.
- Legal/privacy translation can drift semantically if translated too loosely.
- If canonical normalization is inconsistent, the site can emit duplicate or malformed URLs.

## Execution Notes
- Read first: `site/CLAUDE.md`, `src/layouts/Layout.astro`, `src/pages/index.astro`, `src/pages/launch.astro`, `src/pages/sign-in.astro`, `src/pages/sign-up.astro`, `src/pages/privacy.astro`.
- Prefer a small explicit locale helper over scattering string concatenation and pathname logic across pages.
- Preserve current component structure where it still fits; refactor only enough to feed localized copy/links.
- If a language switch UI is added, keep it inside the current site token system and avoid introducing raw spacing/color/typography literals outside the canonical token layer.
- Do not add runtime locale detection, cookies, or external i18n libraries unless the existing code proves a compelling need.
- Validation commands:
  - `cd site && npm run build`
  - HTML inspection commands against `dist`
- Stop conditions:
  - if homepage shared components require a whole-site i18n refactor beyond the five pages,
  - if legal/privacy translation needs a policy decision not inferable from current English content,
  - if a required navigation locale switch would necessarily expose unsupported sections beyond scope.

## Open Questions
None.

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-06-12 12:03:54 UTC | 100-sf-spec | GPT-5 Codex | Created the bilingual core-pages spec from translation/SEO audit findings and explicit user decisions: bilingual fr/en, root=en, scope=coeur. | draft saved | /101-sf-ready shipglows_data/workflow/specs/site/SPEC-bilingual-fr-en-routing-seo-metadata-core-pages-2026-06-12.md |
| 2026-06-12 12:10:00 UTC | 101-sf-ready | GPT-5 Codex | Reviewed structure, user-story alignment, metadata/doc gates, design-system and editorial constraints, and bounded proof contract for the bilingual core-pages site chantier. | ready | /102-sf-start shipglows_data/workflow/specs/site/SPEC-bilingual-fr-en-routing-seo-metadata-core-pages-2026-06-12.md |
| 2026-06-12 12:20:30 UTC | 001-sf-build | GPT-5 Codex | Implemented the bilingual core-page routing, locale-aware shell, and EN/FR metadata contract; validated with local Astro build and generated HTML inspection. | partial | Closure and ship not run in this turn. |
| 2026-06-12 12:45:00 UTC | 005-sf-ship | GPT-5 Codex | Closed and shipped the bilingual core-pages chantier with tracker/changelog updates, bug gate review, local build proof, commit, and push to `main`. | shipped | /405-sf-prod site |

## Current Chantier Flow

100-sf-spec done -> 101-sf-ready ready -> 102-sf-start done -> 103-sf-verify local-proof-done -> 104-sf-end integrated-via-005-full-close -> 005-sf-ship shipped
