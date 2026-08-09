---
artifact: exploration_report
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "contentglows"
created: "2026-08-08"
updated: "2026-08-08"
status: draft
source_skill: sg-explore
scope: "ZeroRank-inspired AI visibility and content-action loop"
owner: "Diane"
confidence: high
risk_level: medium
security_impact: yes
docs_impact: yes
linked_systems:
  - app/lib/presentation/screens/analytics/search_console_panel.dart
  - app/lib/data/models/search_console.dart
  - app/lib/data/services/api_service.dart
  - lab/api/routers/search_console.py
  - lab/api/routers/psychology.py
  - shipglows_data/workflow/specs/lab/SPEC-google-search-console-intelligence.md
  - shipglows_data/workflow/BACKLOG.md
evidence:
  - "https://appsumo.com/products/zerorank-ai/ (accessed 2026-08-07)"
  - "Search Console panel already selects and ingests project-scoped opportunities into the Idea Pool."
  - "Search Console opportunity ingestion retains target query, target URL, reason, period, priority score and source evidence."
  - "The content pipeline already preserves Search Console evidence, target query/URL and source idea IDs in generated content metadata."
depends_on:
  - "project-scoped Google Search Console connection"
  - "Idea Pool review boundary"
  - "content pipeline source metadata"
supersedes: []
next_step: "validate the Opportunity-to-Brief quick win before formalizing broader AI visibility tracking"
---

# Exploration Report: De la visibilité IA au contenu prêt à publier

## Starting Question

Que peut apprendre ContentGlows de ZeroRank AI sans se détourner de sa promesse centrale : transformer des signaux en contenus prêts à valider et publier ? Quel premier incrément apporte une valeur visible sans construire un produit complet de suivi de réponses LLM ?

## Context Read

- `shipglows_data/business/project-competitors-and-inspirations.md` - ZeroRank est une inspiration de visibilité IA, pas un concurrent direct du pipeline de contenu.
- `shipglows_data/product/app/product.md` - l'application doit conserver des workflows explicites, contrôlables et publiables.
- `shipglows_data/workflow/specs/lab/SPEC-google-search-console-intelligence.md` - le contrat existant transforme déjà des opportunités Google Search Console en idées revues avant génération.
- `app/lib/presentation/screens/analytics/search_console_panel.dart` - l'interface permet de sélectionner les opportunités puis de les ajouter à l'Idea Pool.
- `app/lib/data/models/search_console.dart` - une opportunité porte déjà motif, requête/URL cible, résumé, niveau de confiance, score et preuve.
- `lab/api/routers/search_console.py` - l'ingestion est déjà project-scoped, dédupliquée et conserve les données de preuve.
- `lab/api/routers/psychology.py` - le pipeline de contenu conserve les preuves Search Console et les identifiants d'idée source.
- `shipglows_data/workflow/BACKLOG.md` - trois pistes différées existent déjà : score de visibilité IA, lacunes de requêtes et autorité de marque.

## Internet Research

- [ZeroRank AI — AppSumo](https://appsumo.com/products/zerorank-ai/) - Accessed 2026-08-07 - source des patterns pertinents : suivi de prompts, citations et concurrents ; recommandations de contenu ; génération/optimisation de contenu ; rapports et espaces clients.

## Problem Framing

ZeroRank rend visible un diagnostic : la marque apparaît-elle dans des réponses d'IA, qui est cité à sa place et quelles actions sont recommandées. La différence défendable de ContentGlows n'est pas d'afficher davantage de graphiques. C'est de transformer une opportunité prouvée en un brief, un contenu et une décision de publication, en conservant le contexte et la preuve.

Le risque serait de lancer un coûteux suivi quotidien de prompts, de modèles et de citations avant d'avoir démontré que ces signaux changent effectivement les contenus créés ou leur performance.

## Option Space

### Option A: Plateforme complète de visibilité IA

- Summary: suivre prompts, présence de marque, sentiment, citations, concurrents et évolutions sur plusieurs modèles/territoires.
- Pros: proposition de valeur claire pour agences et équipes SEO ; source de nouveaux signaux de contenu.
- Cons: coût récurrent par requête/modèle, volatilité des réponses, complexité de normalisation et besoin d'un protocole de mesure crédible ; trop éloigné du noyau de production de contenu pour un premier incrément.

### Option B: Boucle « opportunité vers brief » — quick win recommandé

- Summary: enrichir l'action existante « Ajouter à l'Idea Pool » avec un brief éditorial prêt à produire : objectif, requête/URL cible, preuve, angle recommandé, format conseillé et checklist de couverture.
- Pros: s'appuie sur les opportunités Search Console et Idea Pool déjà présentes ; valeur immédiate et visible ; pas de nouveau connecteur, de suivi LLM, ni de promesse de ranking ; la preuve reste attachée au contenu généré.
- Cons: le signal initial reste Google Search Console, pas une réponse directe d'un LLM ; la qualité de la recommandation de format doit être évaluée.

### Option C: Score de potentiel éditorial par contenu

- Summary: évaluer un contenu selon les signaux disponibles : opportunité de recherche, couverture du sujet, fraîcheur, angle, format et preuves attachées, puis recommander de créer, renforcer ou actualiser ce contenu.
- Pros: concret et compatible avec l'Idea Pool, les briefs et l'optimisation de contenus existants ; peut fonctionner sans appeler plusieurs LLM.
- Cons: nécessite une doctrine de score explicable ; la recommandation reste éditoriale et ne doit pas dériver vers un audit technique de site.

## Comparison

| Critère | Plateforme complète | Opportunité vers brief | Score de potentiel éditorial |
| --- | --- | --- | --- |
| Valeur proche du cœur ContentGlows | moyenne | forte | forte |
| Réutilisation de l'existant | faible | très forte | moyenne |
| Coût et dépendances externes | élevés | faibles | faibles à moyens |
| Délai de validation | long | court | moyen |
| Risque de promesse SEO excessive | élevé | faible | moyen |

## Emerging Recommendation

Le **quick win** est l'option B : faire d'une opportunité Search Console sélectionnée un **brief prêt à produire**, au lieu de la déposer comme une idée générique.

Le résultat utilisateur attendu : « cette requête a beaucoup d'impressions mais peu de clics ; ContentGlows recommande de renforcer cette page avec un comparatif/FAQ/guide, explique pourquoi, puis prépare le brief et conserve les métriques qui motivent le travail. »

Le périmètre minimal à explorer pour cette évolution :

1. une recommandation de format déterministe par type d'opportunité (`low_ctr_high_impressions`, page deux, requête sans contenu ciblé, baisse, requête en croissance) ;
2. un écran de confirmation court avant l'ajout à l'Idea Pool, affichant preuve, objectif, angle et format proposé ;
3. la persistance de ces champs dans l'idée, puis dans les métadonnées du contenu généré ;
4. une mesure de boucle utile : idée acceptée, brief généré, contenu produit, puis éventuelle amélioration observée dans la période suivante.

Cette évolution rend le principe de « veille de prompts » compréhensible sans le construire immédiatement : plus tard, une opportunité issue d'un prompt ou d'une citation IA pourra alimenter exactement le même brief et le même pipeline.

## Non-Decisions

- Aucun suivi quotidien/hebdomadaire de prompts ou d'appels à ChatGPT, Perplexity, Gemini, etc. n'est décidé.
- Aucune promesse de classement, citation ou hausse de trafic n'est retenue.
- Aucun modèle de prix, quota, pays, modèle IA ou fournisseur de données n'est choisi.
- Aucun partage client white-label, rapport PDF, API ou MCP n'est inclus dans le quick win.

## Rejected Paths

- Copier ZeroRank comme tableau de bord de visibilité IA en premier - rejeté : cela retarde la valeur différenciante de ContentGlows, qui est le passage au contenu actionnable.
- Générer automatiquement du contenu à partir d'un signal - rejeté : l'Idea Pool et le brief restent la frontière de revue utilisateur.
- Fusionner métriques Google et mesures d'IA dans un score unique - rejeté : leurs sources et leurs significations doivent rester distinctes et traçables.

## Risks And Unknowns

- Une recommandation de format ne doit pas être présentée comme une vérité de ranking : elle est une hypothèse éditoriale explicable.
- Les données Search Console sont privées et doivent rester isolées par utilisateur/projet ; la preuve ne doit jamais être exposée dans un mauvais espace.
- Il faudra vérifier que les utilisateurs comprennent et utilisent le brief avant d'investir dans le suivi de prompts.
- Un futur suivi IA devra définir une méthodologie stable : prompts représentatifs, fréquence, pays/langue, modèle, répétitions et gestion de la variabilité des réponses.

## Redaction Review

- Reviewed: yes
- Sensitive inputs seen: none
- Redactions applied: none
- Notes: le rapport ne contient ni identifiants OAuth, ni données Search Console de clients, ni secrets.

## Decision Inputs For Spec

- User story seed: en tant que responsable de contenu, je peux convertir une opportunité Search Console en brief avec sa preuve, son objectif et un format conseillé afin de produire le bon contenu sans repartir d'une idée vague.
- Scope in seed: enrichissement d'opportunité, recommandation déterministe de format, aperçu/confirmation, champs d'Idea Pool et propagation de provenance au contenu.
- Scope out seed: tracking multi-LLM, scraping de réponses IA, score d'autorité complet, outils de netlinking, rapports agences et génération automatique sans revue.
- Invariants/constraints seed: isolation stricte `user_id + project_id` ; distinction explicite entre faits Search Console et recommandation ; déduplication inchangée ; Idea Pool comme frontière de revue ; aucune promesse de résultat SEO/IA.
- Validation seed: tests de mapping opportunité-format, persistance/provenance, déduplication, autorisation projet, UI de confirmation et parcours idée-vers-contenu.

## Handoff

- Recommended next command: formaliser le quick win « Opportunité Search Console vers brief de contenu » si cette direction est confirmée.
- Why this next step: le comportement, la frontière de revue et les sources de données sont déjà clairs ; une spécification courte peut borner le changement sans lancer la plateforme de visibilité IA complète.

## Exploration Run History

| Date UTC | Prompt/Focus | Action | Result | Next step |
|----------|--------------|--------|--------|-----------|
| 2026-08-08 UTC | Enseignements de ZeroRank AI et quick win | Analyse de la fiche produit, de l'Idea Pool, de Search Console et de la transmission de preuve vers le pipeline | Quick win identifié : convertir les opportunités existantes en briefs éditoriaux guidés | Valider puis formaliser le périmètre minimal |
