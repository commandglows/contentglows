---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-05-24"
updated: "2026-05-24"
status: draft
source_skill: sf-explore
scope: "PDF comme source pour la boîte à idées ContentGlows"
owner: "Diane"
confidence: medium
risk_level: high
security_impact: yes
docs_impact: yes
linked_systems:
  - app
  - lab
  - site
  - Firecrawl Fire-PDF
evidence:
  - "https://www.firecrawl.dev/blog/fire-pdf-launch?utm_source=newsletter&utm_medium=email&utm_campaign=april-2026-product-update"
  - "shipglows_data/business/product.md"
  - "shipglows_data/product/app/product.md"
  - "shipglows_data/product/lab/product.md"
depends_on:
  - "app idea-pool workflow"
  - "lab research/content ingestion APIs"
supersedes: []
next_step: "/sf-spec ContentGlows PDF source to idea box"
---

# Exploration Report: PDF comme source pour la boîte à idées

## Starting Question

Et si les utilisateurs voulaient déposer un PDF comme source dans la boîte à idées pour générer des idées, angles et contenus prêts à relire ?

## Context Read

- `shipglows_data/business/product.md` - le site promet une exécution assistée par IA, humaine et contrôlée.
- `shipglows_data/product/app/product.md` - l'app porte les workflows idées, recherche, éditeur, personas et contenus.
- `shipglows_data/product/lab/product.md` - le lab porte les APIs, agents, recherche, contenus, jobs et observabilité.
- Firecrawl Fire-PDF launch post - source technique récente sur extraction PDF structurée.

## Internet Research

- [Introducing Fire-PDF: Firecrawl's New PDF Parsing Engine](https://www.firecrawl.dev/blog/fire-pdf-launch?utm_source=newsletter&utm_medium=email&utm_campaign=april-2026-product-update) - Accessed 2026-05-24 - Firecrawl présente Fire-PDF comme un moteur Rust de parsing PDF qui convertit des PDF textuels, scannés ou mixtes en markdown structuré, avec classification par page, OCR ciblé, tables, formules et ordre de lecture.

## Problem Framing

Le cas d'usage est fort pour ContentGlows : beaucoup de sources utilisateur vivent déjà dans des PDFs, par exemple briefs clients, rapports, transcriptions exportées, livres blancs, cours, notes de formation, documents de marque ou études concurrentielles.

Le produit ne devrait pas traiter le PDF comme un simple fichier joint. La vraie valeur est :

1. extraire une source exploitable,
2. préserver les citations et zones de preuve,
3. transformer cette source en idées actionnables,
4. générer des contenus avec revue humaine,
5. garder une trace claire de ce qui vient du PDF et de ce qui est inféré par l'IA.

## Option Space

### Option A: URL PDF via Firecrawl

- Summary: l'utilisateur colle une URL vers un PDF public ; `lab` appelle Firecrawl et récupère du markdown structuré.
- Pros: rapide à tester, peu de stockage fichier côté ContentGlows, bonne compatibilité avec les sources publiques.
- Cons: ne couvre pas les PDFs privés, dépendance fournisseur, exposition potentielle de documents à un tiers, coûts à surveiller.

### Option B: Upload PDF privé puis extraction backend

- Summary: l'utilisateur téléverse un PDF dans l'app ; le backend stocke temporairement, extrait, indexe et supprime ou conserve selon politique.
- Pros: couvre les briefs privés et documents clients ; meilleur UX ; peut alimenter l'asset/source library.
- Cons: gros impact sécurité, rétention, quotas, antivirus, taille fichier, privacy, consentement et coûts OCR.

### Option C: MVP hybride limité

- Summary: commencer par URL PDF public + extraction Firecrawl, puis préparer l'abstraction `SourceDocument` pour upload privé plus tard.
- Pros: apprend vite sur la valeur utilisateur sans figer l'architecture ; évite de sous-estimer les exigences fichier privé.
- Cons: le MVP doit afficher clairement que les documents privés ne sont pas encore le cas d'usage recommandé.

## Comparison

| Critère | URL PDF public | Upload privé | MVP hybride limité |
|---|---:|---:|---:|
| Valeur immédiate | moyenne | haute | haute |
| Risque sécurité | moyen | élevé | moyen |
| Complexité backend | moyenne | élevée | moyenne |
| Coût OCR/parsing | variable | variable + stockage | contrôlé par quotas |
| Fit boîte à idées | bon | excellent | très bon |
| Délai de validation produit | court | long | court |

## Emerging Recommendation

La meilleure direction est un **MVP hybride limité** :

- App : ajouter une source `PDF URL` dans la boîte à idées, avec état d'extraction visible.
- Lab : créer un modèle conceptuel `SourceDocument` indépendant de Firecrawl.
- Pipeline : `PDF -> markdown structuré -> chunks/citations -> idées -> angles -> contenus`.
- Garde-fou : pas d'upload privé au premier lot tant que les règles sécurité, rétention, quotas et redaction ne sont pas spécifiées.

Fire-PDF est intéressant comme brique, mais il ne doit pas devenir le contrat produit. Le contrat ContentGlows doit rester : source fiable, idées traçables, contenu relisable, contrôle humain.

## Non-Decisions

- Choix final Firecrawl vs parser interne.
- Politique de stockage des PDFs privés.
- Taille maximale de fichier.
- Quotas par plan.
- Indexation long terme dans la bibliothèque d'assets/sources.

## Rejected Paths

- Upload privé immédiat sans spec sécurité - rejeté car risque élevé sur données client, rétention et coûts.
- Extraction texte brute sans structure ni citations - rejetée car elle affaiblit la confiance et produit des idées non auditables.
- Génération directe d'articles depuis PDF - rejetée car le produit doit garder une étape de boîte à idées et revue humaine.

## Risks And Unknowns

- Confidentialité : certains PDFs peuvent contenir données clients, juridiques, RH ou commerciales.
- Coût : OCR et vision-language models peuvent devenir chers sur documents longs ou scannés.
- Exactitude : tables, colonnes et scans peuvent produire des erreurs qui contaminent les idées.
- UX : l'utilisateur doit comprendre si l'extraction est terminée, partielle, échouée ou trop volumineuse.
- Source attribution : chaque idée devrait conserver un lien vers pages/extraits pertinents, pas seulement un résumé global.
- Vendor lock-in : l'abstraction backend doit permettre de remplacer Firecrawl ou d'ajouter un parseur local.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: le rapport ne contient aucun document utilisateur ni extrait sensible.

## Decision Inputs For Spec

- User story seed: en tant qu'opérateur contenu, je peux ajouter un PDF comme source dans la boîte à idées pour générer des idées de contenus traçables et relisables.
- Scope in seed: URL PDF public, extraction markdown, statut de job, idées liées à la source, citations/extraits courts, erreurs lisibles.
- Scope out seed: upload privé, stockage long terme de PDFs, publication automatique, extraction illimitée, documents confidentiels.
- Invariants/constraints seed: revue humaine obligatoire, statut visible, quotas, redaction/log safety, abstraction fournisseur, aucune promesse de fidélité parfaite.
- Validation seed: tests unitaires pipeline source, test parsing mocké, test job status, test UI état extraction, test erreur fournisseur, preuve manuelle avec un PDF public.

## Handoff

- Recommended next command: `/sf-spec ContentGlows PDF source to idea box`
- Why this next step: le sujet touche produit, backend, app, sécurité, coûts et expérience utilisateur ; une spec est nécessaire avant build.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-05-24 00:00:00 UTC | PDF comme source pour boîte à idées | Analyse produit + source Fire-PDF | MVP hybride limité recommandé | `/sf-spec ContentGlows PDF source to idea box` |
