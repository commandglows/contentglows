# Tasks — ContentGlowz Site

> **Priority:** 🔴 P0 blocker · 🟠 P1 high · 🟡 P2 normal · 🟢 P3 low · ⚪ deferred
> **Status:** 📋 todo · 🔄 in progress · ✅ done · ⛔ blocked · 💤 deferred

**Stack**: Astro 6.1, TypeScript, static Vercel deployment | **Phase**: Astro 6 cleanup shipped; Vercel post-ship verification pending

**Top priority**: Verify the post-cleanup Vercel deployment logs use `npm@11.12.1`, then re-audit the marketing site.

## Documentation Migration (2026-06-29)

### Done

- [x] Reduce `site/README.md`, `site/AGENT.md`, and `site/CLAUDE.md` to local façades pointing to canonical `shipglows_data/site/*` docs.
- [x] Confirm `site` already uses canonical technical, editorial, and workflow docs under the monorepo root `shipglows_data/`.
- [x] Run a semantic preservation pass so local `site` docs did not just disappear: runtime/build contract, auth handoff with `redirect_url`, localized `fr/*` surfaces, public navigation invariants, `noindex`, analytics gate, and degraded-mode messaging are now explicit in canonical docs.
- [x] Remove non-canonical `site/CHANGELOG.md`; durable release and migration history now lives in canonical workflow artifacts (`shipglows_data/workflow/CHANGELOG.md`, site specs, and `shipglows_data/workflow/site/TASKS.md`).

### Next
- [ ] Revisit whether any future site-only release note still needs a dedicated canonical tracker entry, or should go directly into shared workflow history.

---

## Migration

| Pri | Task | Status |
|-----|------|--------|
| 🔴 | Migrate `site` from Astro 5 to Astro 6 using the ready spec | ✅ done |
| 🟠 | Validate `npm run build` after migration and compare generated content routes, sitemap, `robots.txt`, and auth handoff pages | ✅ done |
| 🟡 | Update site docs and changelog after the migration ships | ✅ done |
| 🟠 | Ship bilingual `fr/en` blog routing with locale-aware metadata and locale-filtered indexes, tags, and articles | ✅ done |
| 🟠 | Verify post-cleanup Vercel build logs use `npm@11.12.1` after ship | 📋 todo |

---

## Completed Context

| Pri | Task | Status |
|-----|------|--------|
| ✅ | Website auth routes `/sign-in`, `/sign-up`, and `/launch` hand off authenticated users to the Flutter app | ✅ done |
| ✅ | Marketing copy documents degraded backend mode, cached reads, and local action queue behavior | ✅ done |
| ✅ | `shipglows_data/branding/branding.md` documents the website brand promise, tone, and UX language | ✅ done |

---

## Backlog

| Pri | Task | Status |
|-----|------|--------|
| 🟢 | Re-audit marketing site SEO, accessibility, and copy after Astro 6 deployment preview is available | 💤 deferred |
| ✅ | Publier le satellite TOFU `Quel prompt utiliser pour transformer une liste de concurrents en insights produit` pour capter l'intent commande/prompt et pousser vers les skills sans promettre de recherche manuelle | ✅ done |
| ✅ | Publier le satellite comparatif `Où trouver le vrai feedback utilisateur de vos concurrents` avec angle sources AppSumo / Play Store / Trustpilot / G2 / Capterra et maillage vers le cluster concurrents | ✅ done |
| ✅ | Publier le satellite BOFU léger `Comment prioriser sa roadmap grâce au feedback des clients de ses concurrents` pour couvrir le passage insight -> décision produit | ✅ done |
| 🟡 | Publier le satellite mobile `Comment transformer des avis Play Store en idées UX actionnables` pour capter la longue traine app/mobile et exploiter la source Play Store | 📋 todo |
| 🟡 | Publier le satellite partner `Ce que les pages AppSumo révèlent que les landing pages cachent` pour valoriser la source marketplace comme mine d'objections, scope réel et attentes d'achat | 📋 todo |
| 🟡 | Publier le satellite UX `Comment repérer les frictions d'onboarding chez vos concurrents` pour isoler un sous-problème fort et mailler vers feedback client + roadmap | 📋 todo |
| ✅ | Mettre à jour le maillage interne du cluster concurrents/feedback/roadmap avec un ordre de lecture explicite article d'entrée -> article méthode -> article sources -> article priorisation | ✅ done |
| ✅ | Publier une page dédiée `Templates de prompts pour analyser le feedback des clients de vos concurrents` pour donner des commandes prêtes à coller dans NoSkills selon les cas de veille | ✅ done |

---

## Audit Findings
<!-- Populated by /sf-audit — dated sections with Fixed: / Remaining: -->

✅ [site] task: Define site locale strategy and fix technical i18n metadata | status: done | area: translate

### Audit: Design Tokens (2026-05-10)

| Pri | Task | Status |
|-----|------|--------|
| 🔴 | Migrer les 223 valeurs CSS site hardcodées de typographie, spacing, radius et motion vers les variables générées depuis `tools/design-tokens/contentglowz_theme.json` | 🔄 in progress |
| 🟠 | Remplacer les couleurs directes restantes (`white`, `rgba`, hex affichés hors cas de documentation) par variables sémantiques | 📋 todo |
| 🟠 | Ajouter des variables CSS mobile-first compactes pour sections, cards, listes, CTA et pages article/blog | 📋 todo |
