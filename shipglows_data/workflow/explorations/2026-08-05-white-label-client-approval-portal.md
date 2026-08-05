---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-08-05"
updated: "2026-08-05"
status: draft
source_skill: sg-explore
scope: "white-label client approval portal for agency content delivery"
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - app
  - lab
  - worker
  - project workspaces
  - brand profiles
  - feed publish preflight
  - branded video generation
evidence:
  - "https://appsumo.com/products/brandbay/"
  - "https://www.brandbay.io/agencies"
  - "https://www.brandbay.io/features"
  - "shipglows_data/product/app/product.md"
  - "app/lib/data/models/brand_profile.dart"
  - "app/lib/data/models/project_asset.dart"
  - "lab/api/services/brand_profile_store.py"
depends_on:
  - "project and workspace access model"
  - "brand profile and asset attribution contracts"
  - "feed-native publish preflight"
supersedes: []
next_step: "formalize only after agency-segment validation"
---

# Exploration Report: Portail client d'approbation white-label

## Starting Question

Comment ContentGlows peut-il servir les agences avec un portail client white-label sans devenir un DAM générique concurrent de BrandBay, Brandfolder ou Bynder ?

## Context Read

- `shipglows_data/product/app/product.md` - l'application couvre déjà les projets, le feed, la revue avant publication, les sources, les profils de marque et les rendus vidéo.
- `app/lib/data/models/brand_profile.dart` - un profil de marque par projet existe déjà : logo, couleurs, polices, ton, CTA et règles visuelles de vidéo.
- `app/lib/data/models/project_asset.dart` - les assets de projet et leurs usages existent ; l'attribution de source inclut déjà statut des droits et crédit requis.
- `lab/api/services/brand_profile_store.py` - les profils de marque sont persistants, versionnés et isolés par utilisateur/projet.

## Internet Research

- [BrandBay — Agencies](https://www.brandbay.io/agencies) - Accessed 2026-08-05 - confirme le besoin agence : portail client unifié, upload, commentaires, approbation, permissions et partage sécurisé.
- [BrandBay — Features](https://www.brandbay.io/features) - Accessed 2026-08-05 - distingue la gestion d'assets, le multi-marques, le white-label, le partage et la sécurité comme proposition centrale.
- [BrandBay — AppSumo](https://appsumo.com/products/brandbay/) - Accessed 2026-08-05 - confirme le segment agences et les variantes d'accès client par liens ou utilisateurs ; la page affiche 55 avis et une note de 4,5/5 à cette date.

## Problem Framing

Une agence qui utilise ContentGlows pour créer du contenu pour des clients a besoin d'une étape claire entre « contenu généré » et « contenu publiable » : présenter une sélection lisible, recueillir une décision, conserver les retours, puis livrer uniquement la version approuvée.

Le problème à résoudre n'est pas le stockage universel d'assets. C'est la friction de validation entre agence et client, au plus près d'un contenu, de son contexte de marque et de son état de publication.

## Option Space

### Option A: portail DAM white-label complet

- Summary: bibliothèque multi-marques, hébergement d'assets, recherche, collections, liens publics, CNAME, rôles, upload et partage.
- Pros: offre agence facilement compréhensible ; valeur de portail autonome.
- Cons: entre directement en concurrence avec BrandBay et les DAM ; forte surface stockage, droits, partage, recherche, audit et support ; faible différenciation avec le cœur ContentGlows.

### Option B: portail client d'approbation white-label centré contenu

- Summary: une agence partage un espace client à son nom pour une campagne ou un projet. Le client consulte les contenus et vidéos préparés, leurs éléments de marque et leur statut, puis approuve ou demande des modifications.
- Pros: prolonge le feed, le préflight, les profils de marque, les sources et les rendus existants ; différenciation nette par rapport à un DAM ; valeur livrable pour une agence.
- Cons: nécessite un contrat d'accès invité, de permissions, de révocation, d'audit et de notification robuste.

### Option C: livraison par lien non interactif

- Summary: page publique ou protégée qui affiche les contenus finalisés, sans commentaire ni décision structurée.
- Pros: faible coût ; test rapide de la valeur de partage.
- Cons: ne résout pas l'aller-retour de validation ; pas de traçabilité d'approbation ; risque de devenir un export cosmétique.

## Comparison

| Critère | DAM complet | Portail d'approbation | Lien de livraison |
|---|---:|---:|---:|
| Différenciation ContentGlows | faible | forte | moyenne |
| Réutilisation des capacités existantes | faible | forte | moyenne |
| Complexité accès/sécurité | très élevée | élevée, bornable | moyenne |
| Valeur agence immédiate | élevée | élevée | moyenne |
| Risque de dilution produit | très élevé | faible | moyen |

## Emerging Recommendation

Explorer et, si le segment agence est confirmé, spécifier l'**option B** : un portail d'approbation white-label, non pas une bibliothèque d'assets autonome.

Le MVP devrait inclure :

1. un lien invité limité à un projet ou une campagne, expirant et révocable ;
2. une identité white-label légère : logo, couleurs et nom de l'agence, sans CNAME au départ ;
3. une liste de livrables avec aperçus, version, statut et contexte de marque ;
4. commentaires contextualisés et décision explicite « approuvé » ou « modifications demandées » ;
5. un historique d'approbation et un blocage de publication/livraison tant que la décision requise manque.

La différenciation proposée est : **« l'agence livre à son image des contenus prêts à publier, et le client valide précisément ce qui partira en production. »**

## Non-Decisions

- CNAME ou domaine personnalisé par agence.
- Paiement, quotas, packaging commercial ou plans agences.
- Gestion documentaire et stockage d'assets hors des contenus ContentGlows.
- Édition collaborative temps réel.
- Publication automatique vers les canaux externes après approbation.

## Rejected Paths

- Construire un DAM complet en premier - rejeté : cela duplique une catégorie existante et détourne les investissements de la génération et de la publication contrôlées.
- Lien public non authentifié par défaut - rejeté : incompatible avec les contenus clients et la traçabilité attendue.
- White-label CNAME dans le MVP - rejeté : dépend des flux d'e-mail, de domaine, d'authentification et de support ; la valeur peut être validée avec une identité visuelle dans un espace ContentGlows sécurisé.

## Risks And Unknowns

- Accès : les jetons invités doivent être à portée minimale, expirables, révocables et auditables ; aucune fuite inter-projet ou inter-tenant n'est acceptable.
- Validation : il faut définir précisément ce que « approuvé » autorise et si une nouvelle version invalide une approbation antérieure.
- Confidentialité : les aperçus, commentaires et métadonnées de contenu peuvent être sensibles pour un client.
- Identité : le white-label doit rester honnête sur le fournisseur technique et ne doit pas créer de confusion d'expéditeur ou d'authentification.
- Segment : il faut confirmer que les agences ContentGlows privilégient la validation de contenus plutôt que le stockage/partage d'assets, avant de consacrer une offre et une architecture dédiées.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: rapport fondé sur des sources publiques et sur les contrats produits locaux ; aucune donnée client n'est incluse.

## Decision Inputs For Spec

- User story seed: en tant qu'agence, je peux présenter une campagne de contenus sous mon identité afin que mon client approuve ou demande une modification de chaque livrable avant publication.
- Scope in seed: lien invité borné, identité white-label légère, aperçus, commentaires, décisions, statut, audit et révocation.
- Scope out seed: DAM, CNAME, stockage indépendant, recherche globale, gestion de fichiers client, publication automatique.
- Invariants/constraints seed: isolation stricte par projet/tenant ; lien révocable et expirant ; nouvelle version rend l'approbation précédente explicitement obsolète ; aucune publication n'est déclenchée sans l'autorisation définie.
- Validation seed: tests d'autorisation et d'isolation, tests expiration/révocation, tests de transition de version et d'approbation, test UI invité, preuve manuelle avec deux projets et deux invités distincts.

## Handoff

- Recommended next command: formaliser une spécification seulement après validation du segment agences.
- Why this next step: le sujet touche le produit, les droits d'accès, la sécurité, les modèles de données, le feed et la publication ; une implémentation sans contrat d'accès serait risquée.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-08-05 17:30:00 UTC | Potentiel agences / portail client white-label | Analyse BrandBay, sources publiques et contrats ContentGlows | Portail d'approbation white-label recommandé ; DAM complet écarté | Capturé au backlog pour validation de segment puis spécification |
