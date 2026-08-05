---
artifact: product
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: lab
created: "2026-04-26"
updated: "2026-04-27"
status: reviewed
scope: product
source_skill: sf-docs
owner: "Diane"
confidence: medium
risk_level: medium
security_impact: unknown
docs_impact: yes
evidence:
  - README.md
  - CLAUDE.md
  - shipglows_data/business/business.md
  - shipglows_data/branding/branding.md
  - shipglows_data/technical/lab/guidelines.md
  - shipglows_data/workflow/specs/lab/SPEC-backend-persona-autofill-repo-understanding-user-keys.md
  - shipglows_data/workflow/specs/lab/SPEC-dual-mode-ai-runtime-all-providers.md
  - shipglows_data/workflow/specs/lab/ANALYSIS-drip-integration-with-existing.md
  - shipglows_data/workflow/specs/lab/DRIP_IMPLEMENTATION.md
  - shipglows_data/workflow/specs/lab/SPEC-strict-byok-llm-app-visible-ai.md
  - shipglows_data/workflow/specs/lab/social-listener.md
depends_on:
  - shipglows_data/business/business.md@1.0.0
  - shipglows_data/branding/branding.md@1.0.0
  - shipglows_data/technical/lab/guidelines.md@1.0.0
supersedes: []
next_review: "2026-07-26"
next_step: /sf-docs audit shipglows_data/product/lab/product.md
---

# shipglows_data/product/lab/product.md

## Positionnement produit

`lab` est le noyau backend de **ContentGlows** côté service. Il fournit les API FastAPI, les orchestrations asynchrones, les pipelines IA et les services de planification nécessaires pour les produits clients (`app`) et web (`site`).

La promesse opérationnelle du dépôt est la suivante :

- garder des flux de contenu **cohérents** entre l’application, l’API et les jobs de fond,
- orchestrer des capacités d’analyse, de génération et de planification sans casser les contrats de production,
- fournir des points de contrôle explicites (statuts, coûts, jobs, audits) pour sécuriser les décisions automatisées.

## Utilité métier

Ce backend résout trois problèmes concrets :

- **Stabiliser la logique produit** : unifier les contrats projets, paramètres, status et intégrations entre l’app Flutter et les services web.
- **Accélérer l’activation de contenu** : centraliser la création de contenu, la recherche de signaux (veille, idées, SEO), la planification et la publication.
- **Réduire les risques opérationnels** : rendre les flux asynchrones observables (jobs, scheduler, journaux, métriques d’état) et résilients aux erreurs.

## Principales capacités couvertes

- Authentification web et intégrations (Clerk/webhook) via `api/routers/auth_web.py` et dépendances associées.
- Gestion utilisateurs, profils créateur et paramètres (`/api/me`, `/api/settings`, `/api/creator-profile`).
- Gestion des projets, contenus, idées et personas (`/api/projects`, `/api/content`, `/api/ideas`, `/api/personas`).
- Orchestration IA par route et pipeline (`/api/psychology`, `/api/research`, `/api/mesh`, `/api/newsletter`, `/api/dispatch-pipeline`).
- Orchestration temporelle via scheduler : jobs récurrents, exécution différée, transitions de statut, publication progressive (drip).
- Automation de contenus publiables (drip / publication par lot + frontmatter) et suivi de statut.
- Vérification, prévisualisation et santé des opérations (health, version, observabilité, métriques, status).
- Gestion d’images/flux médias, feedback utilisateurs et analytics.

## Public priorisé (hypothèse)

- Opérateurs produit et contenus internes qui utilisent déjà les workflows Flutter.
- Équipes qui veulent une API unique pour : recherche, stratégie de contenu, veille, pipeline de génération, planification et livraison.
- Utilisateurs de pilotage opérationnel (statuts, jobs, analyses) avant tout usage public direct.

## Non-objectifs

- Ce dépôt n’implémente pas directement l’expérience UI finale ni les parcours d’onboarding visuels complets.
- Ce dépôt n’est pas une application d’hébergement frontend de production.
- La logique métier de monétisation finale n’est pas portée ici ; elle dépend du produit global et de ses contrats de commercialisation.

## Contrats implicites et limites

- Les promesses de service reposent sur des intégrations existantes (routers, services, jobs).
- Les changements de contrats API publics (`/api/*`) doivent être reflétés dans les changements de documentation et d’observabilité associés.
- Les changements de sécurité (auth, clés utilisateur, accès OpenRouter, tokens) ont un impact produit ; ils doivent être traités comme décisions à haut risque.
