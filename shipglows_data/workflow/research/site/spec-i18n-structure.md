---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "site"
created: "2026-04-27"
updated: "2026-04-27"
status: ready
source_skill: sf-spec
scope: "feature"
owner: "Diane"
confidence: medium
user_story: "En tant que mainteneuse du site marketing ContentGlowz, je veux préparer une structure i18n FR/EN dans le site Astro, afin de publier progressivement une version française sans casser les URLs anglaises, le SEO, ni les parcours de conversion vers l'application."
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
linked_systems:
  - "Astro static routing"
  - "Astro content collections"
  - "Astro i18n routing"
  - "Sitemap and SEO metadata"
  - "ContentGlowz app handoff URLs"
depends_on:
  - artifact: "shipglows_data/business/business.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "shipglows_data/branding/branding.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "CLAUDE.md"
    artifact_version: "1.0.0"
    required_status: "reviewed"
  - artifact: "README.md"
    artifact_version: "unknown"
    required_status: "unknown"
supersedes: []
evidence:
  - "package.json"
  - "astro.config.mjs"
  - "src/layouts/Layout.astro"
  - "src/layouts/BlogPost.astro"
  - "src/content.config.ts"
  - "src/config/site.ts"
  - "src/pages/**/*.astro"
  - "src/components/Navbar.astro"
  - "src/components/Footer.astro"
  - "https://docs.astro.build/en/guides/internationalization/"
  - "https://docs.astro.build/en/reference/modules/astro-i18n/"
  - "https://docs.astro.build/en/recipes/i18n/"
next_step: "/sf-start Implement i18n structure spec"
---

## Title
Prepare FR/EN i18n structure for ContentGlowz Site

## Status
Ready. Spec implementable without blocking gaps.

Baseline observed on 2026-04-27:

- Project path: `/home/claude/contentglowz/site`
- Framework: Astro `^5.17.1`
- Sitemap integration: `@astrojs/sitemap@^3.7.2`
- Current site URL: `https://contentglowz.winflowz.com`
- Current app handoff URLs: derived from `APP_WEB_URL`, `appSignInUrl`, and `appEntryUrl` in `src/config/site.ts`
- Current language state: site copy is mostly English, with a few French Markdown documents mixed into English content folders
- Current routing state: no `i18n` config in `astro.config.mjs`, no locale folders under `src/pages`, no locale-aware content helper, and `<html lang="en">` is hardcoded in `src/layouts/Layout.astro`
- Current repo state includes unrelated uncommitted changes in docs/package files. The i18n implementation must not revert or overwrite those changes.

## User Story
En tant que mainteneuse du site marketing ContentGlowz, je veux préparer une structure i18n FR/EN dans le site Astro, afin de publier progressivement une version française sans casser les URLs anglaises, le SEO, ni les parcours de conversion vers l'application.

Actor: mainteneuse du site marketing ContentGlowz.

Trigger: décision de rendre le site ContentGlowz publiable en anglais et en français.

Observable result: les routes anglaises existantes continuent de fonctionner sans préfixe, les routes françaises existent sous `/fr`, le layout expose la bonne langue HTML, les URLs canoniques et alternatives sont cohérentes, et le contenu français peut être ajouté progressivement sans publier des pages à moitié traduites.

## Minimal Behavior Contract
Le système accepte un site Astro actuellement monolingue, configure une langue par défaut anglaise non préfixée et une langue française sous `/fr`, puis fournit des helpers et conventions pour générer des liens, métadonnées, routes et contenus localisés sans dupliquer la logique métier. En cas de contenu français manquant, la version française ne doit pas publier une page partiellement traduite par accident: elle doit soit ne pas générer la route, soit revenir explicitement à une page anglaise seulement si ce fallback est déclaré et traçable. L'edge case facile à rater est le SEO: chaque page localisée doit avoir son propre canonical, son `html lang`, ses `hreflang` alternates et son URL de sitemap cohérents, sinon Google peut indexer la mauvaise variante ou considérer les pages comme des doublons.

## Success Behavior
Après implémentation:

- `/` reste la page d'accueil anglaise actuelle.
- `/blog`, `/platform`, `/ai-agents`, `/seo-strategy`, `/startup-journey`, `/technical-optimization`, `/tutorials`, `/privacy`, `/sign-in`, `/sign-up`, et `/launch` conservent leurs chemins publics anglais.
- `/fr` devient la page d'accueil française.
- Les futures pages françaises utilisent `/fr/[section]/[slug]`.
- `astro.config.mjs` déclare `i18n.locales = ["en", "fr"]`, `defaultLocale = "en"`, et `routing.prefixDefaultLocale = false`.
- `Layout.astro` reçoit une prop `locale` ou déduit `Astro.currentLocale`, puis rend `<html lang="en">` ou `<html lang="fr">`.
- `Layout.astro` rend `canonical` et `hreflang` pour les pages qui ont des variantes localisées connues.
- Les composants globaux (`Navbar`, `Footer`, CTA, home sections) utilisent un dictionnaire local léger pour les labels d'interface.
- Les collections Markdown gardent leurs collections existantes, mais ajoutent un champ `locale` et un champ `translationKey` dans le frontmatter.
- Les pages dynamiques ne génèrent une route française que si un document français existe avec `locale: fr` et `translationKey` correspondant.
- Le sitemap inclut les pages localisées publiées et continue d'exclure les drafts.
- Les liens vers l'app (`appSignInUrl`, `appEntryUrl`, checkout URLs) restent inchangés et ne sont pas localisés côté domaine.
- `npm run build` passe.

## Error Behavior
Si une étape échoue:

- Si une locale inconnue est demandée, Astro doit retourner 404 ou laisser le middleware i18n officiel valider la route, pas afficher une page anglaise avec `lang="fr"`.
- Si une traduction de composant manque, le helper doit tomber sur l'anglais et rendre le fallback seulement pour la string UI, pas publier une page française entière non relue.
- Si une traduction de contenu Markdown manque, la route française de ce contenu ne doit pas être générée.
- Si deux documents partagent le même `translationKey` dans une même locale, le build doit échouer via un script de validation ou un check explicite.
- Si une page française existe mais sans frontmatter SEO localisé (`title`, `description`), la page doit être bloquée par validation ou marquée draft.
- Aucune erreur ne doit modifier les URLs de connexion, exposer des secrets, ni casser les redirections vers `app`.

## Problem
`site` est aujourd'hui un site Astro statique sans structure i18n. Les pages et composants contiennent des liens absolus internes (`/blog`, `/#features`, etc.), le layout force `html lang="en"`, et les collections Markdown n'ont pas de champ de locale. Cela rend impossible un `sf-audit-translate sync` fiable sur le site: il n'existe pas de surface claire où ajouter les traductions ni de contrat SEO pour publier les variantes.

## Solution
Ajouter une fondation i18n progressive, alignée avec Astro 6 et les Content Layer collections, sans migrer tout le contenu dans la même tâche. La stratégie retenue est:

- anglais par défaut sans préfixe pour préserver les URLs actuelles;
- français sous `/fr` pour publier progressivement;
- dictionnaire TypeScript pour les labels UI courts;
- frontmatter `locale` et `translationKey` pour les contenus Markdown;
- helpers partagés pour construire les URLs localisées, les alternates et les filtres de collection;
- premières routes françaises limitées à la home et aux pages structurantes déjà traduisibles, puis extension aux collections quand les contenus FR existent.

## Scope In
- Configurer Astro i18n FR/EN.
- Ajouter des helpers i18n internes pour locales, URLs, labels, alternates et résolution de contenu.
- Rendre le layout locale-aware: `html lang`, canonical, `hreflang`, `og:locale`, et URLs absolues.
- Localiser `Navbar`, `Footer`, CTA principaux et page d'accueil via dictionnaire.
- Créer les routes françaises de base sous `src/pages/fr`.
- Étendre le schema de content collections avec `locale` et `translationKey`.
- Adapter les routes dynamiques pour filtrer par locale.
- Ajouter une validation de cohérence i18n ou un script de sanity check si nécessaire.
- Mettre à jour README/docs pour expliquer comment ajouter une page ou un article localisé.

## Scope Out
- Traduire tout le corpus Markdown existant.
- Changer le domaine ou utiliser des domaines par langue.
- Traduire les URLs de l'application Flutter ou les routes de handoff.
- Ajouter une librairie i18n lourde côté client.
- Faire une migration Astro 6 en même temps.
- Réécrire le design ou le positionnement marketing.
- Ajouter une détection navigateur avec redirection automatique dès la première passe. Une redirection automatique peut nuire au SEO et à la prévisibilité des URLs si elle est mal cadrée.

## Constraints
- Respecter `CLAUDE.md`: en français, utiliser le tutoiement et des accents corrects.
- Préserver les URLs anglaises existantes.
- Garder le site statique et compatible `npm run build`.
- Ne pas dupliquer les composants entiers si un dictionnaire suffit.
- Ne pas publier de page française partielle.
- Les textes produit doivent rester alignés avec `shipglows_data/business/business.md` et `shipglows_data/branding/branding.md`: pas de promesse d'automatisation totale, garder le framing human-in-the-loop.

## Dependencies
- Astro `^5.17.1`, i18n routing officiel.
- `astro:i18n` helpers, notamment `getRelativeLocaleUrl` et APIs de génération de liens localisés.
- `@astrojs/sitemap` déjà installé.
- Content collections Astro via `astro:content`.
- Fresh external docs checked:
  - Astro i18n guide: https://docs.astro.build/en/guides/internationalization/
  - Astro i18n API reference: https://docs.astro.build/en/reference/modules/astro-i18n/
  - Astro i18n recipe for collections and dynamic routing: https://docs.astro.build/en/recipes/i18n/

## Invariants
- `en` est la locale par défaut.
- Les URLs anglaises ne reçoivent pas de préfixe `/en`.
- Les URLs françaises utilisent toujours `/fr`.
- Les routes auth/handoff restent globales: `/sign-in`, `/sign-up`, `/launch`.
- Chaque page publiée doit avoir un canonical vers elle-même dans sa locale.
- Les alternates ne listent que les variantes réellement publiées.
- Un contenu traduit est relié à son équivalent par `translationKey`, pas par titre.
- Les drafts ne sont pas publiés et ne doivent pas apparaître dans les alternates.

## Links & Consequences
- `astro.config.mjs`: active le middleware i18n Astro. Cela peut changer la validation des routes et doit être testé par build.
- `src/layouts/Layout.astro`: devient le point central SEO/i18n. Une erreur ici affecte toute l'indexation.
- `src/layouts/BlogPost.astro`: doit produire dates, breadcrumbs, labels et related posts dans la bonne locale.
- `src/components/Navbar.astro` et `src/components/Footer.astro`: tous les liens internes doivent passer par les helpers localisés.
- `src/pages/*.astro` et `src/pages/fr/*.astro`: les pages statiques doivent coexister sans casser la home actuelle.
- `src/content.config.ts`: le schema doit permettre `locale` et `translationKey`.
- `src/pages/*/[...slug].astro`: les collections doivent filtrer par locale et construire les chemins localisés.
- SEO: sitemap, canonical, `hreflang`, `og:locale`, JSON-LD breadcrumbs et URLs absolues doivent rester cohérents.
- Accessibility: le sélecteur de langue doit être un lien ou contrôle accessible avec libellé clair.

## Documentation Coherence
- Mettre à jour `README.md` avec la convention i18n:
  - anglais sans préfixe;
  - français sous `/fr`;
  - comment ajouter une string UI;
  - comment ajouter un contenu Markdown traduit.
- Mettre à jour `CLAUDE.md` si la règle de langue doit mentionner aussi le default locale anglais et la structure `/fr`.
- Ajouter une note dans `shipglows_data/editorial/site/content-map.md` ou doc équivalente si elle existe et est maintenue.
- Ne pas modifier `shipglows_data/business/business.md` et `shipglows_data/branding/branding.md` sauf si l'implémentation change les promesses produit.

## Edge Cases
- Page française sans équivalent anglais: autorisée seulement si `translationKey` est unique et si la navigation ne suppose pas d'alternate anglais.
- Page anglaise sans français: la route anglaise reste publiée, mais pas d'alternate `fr`.
- Tags de blog: les tags doivent être localisés ou considérés comme taxonomie anglaise partagée. Pour la première passe, garder les tags comme taxonomie partagée et ne générer les pages `/fr/blog/tag/*` que si les articles FR existent.
- Anchors home (`/#features`) doivent devenir `/fr#features` ou équivalent pour la locale française.
- Dates: utiliser `Intl.DateTimeFormat(locale)` au lieu de `toLocaleDateString('en-US')` hardcodé.
- Related posts: ne pas mélanger articles anglais et français.
- JSON-LD breadcrumbs: item URLs et labels doivent suivre la locale.
- French typography: espaces et ponctuation doivent respecter la règle projet, notamment autour de `:`, `;`, `?`, `!` si du contenu français est écrit directement.

## Implementation Tasks
- [ ] Task 1: Configure Astro i18n routing
  - File: `astro.config.mjs`
  - Action: Add `i18n` with `locales: ["en", "fr"]`, `defaultLocale: "en"`, and `routing.prefixDefaultLocale: false`.
  - User story link: preserves existing English URLs while enabling `/fr`.
  - Depends on: none.
  - Validate with: `npm run build`.
  - Notes: Follow Astro official i18n routing docs.

- [ ] Task 2: Add shared i18n config and URL helpers
  - File: `src/i18n/config.ts`
  - Action: Create constants for supported locales, default locale, locale labels, `isLocale`, and path helpers for localized internal URLs.
  - User story link: provides one contract for localized navigation.
  - Depends on: Task 1.
  - Validate with: TypeScript/build import checks.
  - Notes: Prefer Astro helpers from `astro:i18n` where route generation needs config awareness.

- [ ] Task 3: Add UI translation dictionary
  - File: `src/i18n/ui.ts`
  - Action: Add typed dictionaries for navigation, footer, CTA, home labels, blog labels, and shared metadata strings.
  - User story link: enables reusable components to render in English or French.
  - Depends on: Task 2.
  - Validate with: build and a missing-key sanity check.
  - Notes: Keep copy concise and aligned with `shipglows_data/branding/branding.md`; French uses tutoiement.

- [ ] Task 4: Make `Layout.astro` locale-aware
  - File: `src/layouts/Layout.astro`
  - Action: Accept `locale`, `alternateUrls`, and locale-specific metadata; render `html lang`, canonical, `hreflang`, `og:locale`, and localized schema URLs.
  - User story link: makes localized pages SEO-safe.
  - Depends on: Task 2.
  - Validate with: inspect generated HTML for `/` and `/fr`.
  - Notes: Alternates should include only real published variants.

- [ ] Task 5: Localize navigation and footer
  - Files: `src/components/Navbar.astro`, `src/components/Footer.astro`
  - Action: Accept or derive `locale`; render localized labels and internal links; add an accessible language switcher.
  - User story link: lets visitors move between language variants without losing context.
  - Depends on: Tasks 2 and 3.
  - Validate with: desktop/mobile manual check and build.
  - Notes: Keep app handoff URLs unchanged.

- [ ] Task 6: Create localized home route
  - Files: `src/pages/index.astro`, `src/pages/fr/index.astro`, home section components as needed.
  - Action: Pass `locale` into shared home components and render French copy for `/fr`.
  - User story link: first observable French page.
  - Depends on: Tasks 3, 4, and 5.
  - Validate with: `/` English unchanged, `/fr` French rendered, `npm run build`.
  - Notes: Avoid duplicating whole component files unless the component structure diverges.

- [ ] Task 7: Extend content schema for locale mapping
  - File: `src/content.config.ts`
  - Action: Add optional or required `locale` and `translationKey` fields with defaults/migration plan.
  - User story link: allows Markdown content to be translated and linked safely.
  - Depends on: Task 2.
  - Validate with: `npm run build`.
  - Notes: For existing English docs, default `locale` can be `en` initially to reduce frontmatter churn.

- [ ] Task 8: Add content lookup helpers
  - File: `src/i18n/content.ts`
  - Action: Provide functions to filter collection entries by locale, find translations by `translationKey`, and build alternates.
  - User story link: prevents mixed-language collection routes.
  - Depends on: Task 7.
  - Validate with: helper usage in at least one collection route.
  - Notes: Detect duplicate `translationKey` per locale.

- [ ] Task 9: Adapt collection routes progressively
  - Files: `src/pages/blog/[...slug].astro`, `src/pages/blog/index.astro`, `src/pages/blog/tag/[tag].astro`, and one `src/pages/fr/...` route family for the first translated collection.
  - Action: Filter entries by locale, generate localized paths, localize index labels, dates, breadcrumbs and related posts.
  - User story link: enables content translation without cross-locale leaks.
  - Depends on: Task 8.
  - Validate with: build output route list and manual HTML inspection.
  - Notes: Start with `blog`; apply same pattern to other collections after validation.

- [ ] Task 10: Add i18n validation command
  - File: `scripts/check-i18n.mjs`
  - Action: Check duplicate `translationKey`, missing required frontmatter on FR pages, and missing UI dictionary keys.
  - User story link: blocks partial translations before publish.
  - Depends on: Tasks 3 and 8.
  - Validate with: `node scripts/check-i18n.mjs`.
  - Notes: Add to `package.json` as `check:i18n`.

- [ ] Task 11: Update docs
  - Files: `README.md`, `CLAUDE.md`, optionally `shipglows_data/editorial/site/content-map.md`
  - Action: Document i18n conventions and contributor workflow.
  - User story link: lets future translation work use the structure consistently.
  - Depends on: implementation tasks.
  - Validate with: docs mention `/fr`, `translationKey`, and `check:i18n`.
  - Notes: Keep docs factual and short.

## Acceptance Criteria
- [ ] CA 1: Given the current production English URLs, when the i18n structure is enabled, then `/`, `/blog`, `/privacy`, `/sign-in`, `/sign-up`, and `/launch` still build and keep their original public paths.
- [ ] CA 2: Given a visitor opens `/fr`, when the page loads, then visible global UI and home content are in French and the HTML tag is `lang="fr"`.
- [ ] CA 3: Given a visitor opens `/`, when the page loads, then visible global UI and home content remain English and the HTML tag is `lang="en"`.
- [ ] CA 4: Given a page has both EN and FR variants, when its HTML is inspected, then canonical points to the current locale URL and `hreflang` lists both variants.
- [ ] CA 5: Given an English content entry has no French translation, when the site builds, then no French route is generated for that entry.
- [ ] CA 6: Given a French content entry has missing title or description, when the i18n check runs, then it fails with the file path and missing field.
- [ ] CA 7: Given two entries in the same locale share a `translationKey`, when the i18n check runs, then it fails with both file paths.
- [ ] CA 8: Given a user uses the language switcher on a page with an equivalent translation, when they click FR/EN, then they land on the equivalent localized URL.
- [ ] CA 9: Given a user uses the language switcher on a page without an equivalent translation, when they click FR/EN, then they land on the localized home or section index, not a broken URL.
- [ ] CA 10: Given `npm run build` runs, when the build completes, then sitemap generation succeeds and drafts remain excluded.
- [ ] CA 11: Given app CTA links are rendered in any locale, when inspected, then they still point to `appSignInUrl`, `appEntryUrl`, or configured checkout URLs.

## Test Strategy
- Static build: `npm run build`.
- i18n validation: `npm run check:i18n` after adding the script.
- HTML sanity checks:
  - inspect `dist/index.html` for `lang="en"`, canonical root, and English copy;
  - inspect `dist/fr/index.html` for `lang="fr"`, `/fr` canonical, and French copy;
  - inspect one localized content page for `hreflang`.
- Manual browser check with `npm run preview`:
  - `/`;
  - `/fr`;
  - `/blog`;
  - one translated `/fr/blog/...` page after a sample FR entry exists;
  - mobile navbar language switcher.
- SEO check:
  - verify sitemap includes localized pages that exist;
  - verify no alternate points to a missing route.

## Risks
- SEO duplicate risk if canonical and alternates are wrong.
- Translation quality risk if French pages are generated from English fallbacks too broadly.
- Maintenance risk if each component duplicates full EN/FR markup instead of using helpers.
- Routing regression risk from enabling Astro i18n middleware.
- Content drift risk if `translationKey` is not enforced.
- Brand risk if French copy switches to vouvoiement or overpromises app automation.

## Execution Notes
- Read first:
  - `astro.config.mjs`
  - `src/layouts/Layout.astro`
  - `src/components/Navbar.astro`
  - `src/content.config.ts`
  - `src/pages/blog/[...slug].astro`
- Implementation order:
  - configure Astro i18n;
  - create helpers and dictionaries;
  - make layout SEO-aware;
  - localize global navigation/footer;
  - add `/fr` home;
  - add content schema and route helpers;
  - migrate one collection route as reference;
  - add validation and docs.
- Use Astro official i18n routing rather than custom middleware for the first pass.
- Keep `prefixDefaultLocale: false`.
- Do not introduce client-side i18n libraries.
- Stop and reroute if enabling Astro i18n breaks existing English paths in a way that requires moving all current pages under `/en`; preserving current URLs is a hard requirement.
- Stop and ask for product review if French copy requires business promises not present in `shipglows_data/business/business.md` or `shipglows_data/branding/branding.md`.

## Open Questions
None blocking for the structural spec. Implementation should proceed with English as default unprefixed and French under `/fr`.
