---
artifact: gtm_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "site"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: sf-docs
scope: gtm
owner: "Diane"
confidence: medium
risk_level: medium
docs_impact: "yes"
security_impact: unknown
evidence:
  - "shipglows_data/business/business.md"
  - "shipglows_data/branding/branding.md"
  - "CLAUDE.md"
  - "README.md"
  - "src/pages/index.astro"
  - "src/components/*.astro"
  - "src/pages/launch.astro"
linked_artifacts:
  - "shipglows_data/business/business.md@1.0.0"
  - "shipglows_data/branding/branding.md@1.0.0"
  - "shipglows_data/product/site/product.md@1.0.0"
depends_on:
  - "shipglows_data/business/business.md@1.0.0"
  - "shipglows_data/product/site/product.md@1.0.0"
supersedes: []
next_review: "2026-07-26"
next_step: "/sf-docs audit shipglows_data/gtm/site/gtm.md"
target_segment: "créateurs, founders et petites équipes marketing qui veulent une exécution de contenu rapide sans perdre le contrôle humain"
offer: "site d’acquisition + conversion qui valorise ContentGlowz comme couche d’exécution guidée, avec continuité même en cas de service API instable"
channels: "SEO (blog, guides), landing page, pages de pricing/FAQ, sign-up/sign-in, et redirection explicite vers l’app"
proof_points: "stack Astro SEO-first, handoff app via `/launch`, documentation dégradée explicite, promesse publicisée autour du contrôle humain"
---

# Contexte GTM — site

## Segment cible
- Segment principal : indépendants et équipes compactes qui préfèrent la continuité opérationnelle à la promesse magique.
- Segment secondaire : décideurs techniques sensibles à la cohérence produit entre acquisition et app.

## Offre
Tu expliques le produit comme un passage simple : du message public à un espace exécutable,
avec continuité, visibilité des limites et contrôle humain.
La vérité produit et business reste portée par `app`; le site convertit sans réécrire ce contrat.

## Positionnement
Tu positionnes le site comme preuve de clarté : pas de buzz IA, pas de promesse de publication autonome,
mais une trajectoire mesurable vers la préparation et la publication contrôlée.

## Canaux
- Trafic organique via pages éditoriales (`/blog`, `/docs`, `/tutorials`, `/seo-strategy`).
- Conversion directe via `Cta` + `Pricing` + `/launch`.
- Support de confiance via FAQ, privacy et pages produit.

## Parcours de conversion
1. Arrivée sur une page thématique ou la landing.
2. Validation de l’intérêt (features, preuves, FAQ).
3. Conversion via appel à l’action vers `/launch` ou `/sign-in`.
4. Entrée et routage app (`appSignInUrl`/`appEntryUrl`).

## Preuve et objections
- `Mode dégradé` présenté clairement pour limiter les promesses fragiles.
- Contenus techniques + cas d’usage pour prouver la maturité.
- Objection commune : « c’est automatique ? » → réponse claire : accompagnement + revue humaine.

## KPIs
- Taux de clic depuis la landing vers `/launch`.
- Taux de clic `/sign-in` vs `/sign-up`.
- Engagement sur pages de valeur (blog, tutorials, docs).
- Réduction des rebonds sur pages de conversion.
