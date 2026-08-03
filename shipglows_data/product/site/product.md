---
artifact: product_context
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "site"
created: "2026-04-26"
updated: "2026-04-27"
status: "reviewed"
source_skill: sf-docs
scope: product
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: none
docs_impact: "yes"
evidence:
  - "README.md"
  - "CLAUDE.md"
  - "shipglows_data/business/business.md"
  - "shipglows_data/branding/branding.md"
  - "shipglows_data/technical/site/guidelines.md"
  - "src/config/site.ts"
  - "src/pages/index.astro"
  - "src/pages/launch.astro"
  - "src/pages/sign-in.astro"
  - "src/pages/sign-up.astro"
  - "src/content"
linked_artifacts:
  - "shipglows_data/business/business.md@1.0.0"
  - "shipglows_data/branding/branding.md@1.0.0"
  - "shipglows_data/technical/site/guidelines.md@1.0.0"
depends_on:
  - "shipglows_data/business/business.md@1.0.0"
  - "shipglows_data/branding/branding.md@1.0.0"
  - "shipglows_data/technical/site/guidelines.md@1.0.0"
supersedes: []
next_review: "2026-07-26"
target_user: "Fondateurs, équipes content ops, creators indépendants"
user_problem: "Besoin de transformer une idée de contenu en trajectoire de publication claire sans confusion entre site marketing et app produit."
desired_outcomes:
  - "Comprendre rapidement la promesse ContentGlowz."
  - "Valider les limites et le mode dégradé."
  - "Atteindre facilement l’entrée app via /launch ou auth."
  - "Aligner découverte, contenus éditoriaux et conversion."
non_goals:
  - "Le site n’exécute pas le traitement métier de génération de contenu."
  - "Le site ne gère pas la facturation directe ni les jobs backend."
  - "Le site ne remplace pas le handoff sécurisé côté app."
next_step: "/sf-docs audit shipglows_data/product/site/product.md"
---

# Contexte produit — site

## Utilisateur cible
- Founders et équipes content ops qui veulent piloter la publication avec moins de friction.
- Visiteurs intéressés par une solution qui livre des contenus déjà fabriqués, publiables vite, sans sacrifier la continuité.

## Problème
Le site positionne le produit, rassure sur les limites techniques et guide rapidement vers `app`.
Sans ce site, la promesse produit est morcelée entre pages, et le passage vers l’app est moins crédible.
`app` reste la source canonique pour les capacités produit et le contrat business.

## Sorties souhaitées
- Traiter la découverte, la preuve sociale, la preuve de valeur et la conversion initiale.
- Centraliser les pages de contenu (blog, guides, agents, SEO) sur une même grille éditoriale.
- Rendre les messages cohérents avec les contraintes réelles : automation-first, édition optionnelle, mode dégradé.

## Workflows principaux
1. Un prospect arrive sur la landing, comprend la proposition (`Hero`, features, pricing, FAQ).
2. Le site lui donne une voie de conversion claire (`/launch`, `/sign-in`, `/sign-up`).
3. Il comprend la continuité côté app : handoff web et reprise d’activité.
4. Les contenus de support (blog, docs, strategy, tutorials) renforcent la confiance et orientent la suite.

## Périmètre (in)
- Site marketing Astro public, SEO et conversion.
- Référencement des produits/robots via pages de contenu.
- Message de reprise en cas d’indisponibilité backend (honnêteté opérationnelle).

## Périmètre (out)
- Logique métier d’exécution complète du contenu.
- Auth native de bout en bout et publication multicanale (repos liés).
- Gestion des jobs backend, files d’attente et scoring avancé.

## Signaux de succès
- Taux d’entrée vers `/launch` stable et compréhensible.
- Messages de promesse cohérents avec `shipglows_data/branding/branding.md` et `shipglows_data/business/business.md`.
- Faible volume de copies contradictoires entre pages.

## Risques
- Réticence commerciale si la promesse de contenus prêts à publier dépasse l’opération réelle.
- Détérioration de confiance si la page ne rappelle pas le flux de reprise/handoff.
- Dérive de contenu quand les claims marketing ne suivent pas les changements d’app.
