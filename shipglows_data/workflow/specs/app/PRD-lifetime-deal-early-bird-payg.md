---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: app
created: "2026-04-25"
updated: "2026-04-27"
status: draft
source_skill: sf-docs
scope: feature
owner: "Diane"
confidence: low
risk_level: medium
security_impact: unknown
docs_impact: yes
user_story: "En tant que fondatrice, je veux cadrer une offre Lifetime Deal BYOK economiquement soutenable pour lancer l'acquisition sans promesse de cout IA impossible a tenir."
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs audit shipglows_data/workflow/specs/app/PRD-lifetime-deal-early-bird-payg.md"
---
# PRD — Lifetime Deal Early Early Bird (BYOK / Pay-As-You-Go)

Date: 2026-04-23

Status: draft de travail

Owner: Founder / Product

## Questions ouvertes (bloquantes)

- Quel prix exact est retenu pour le lancement (et la devise de reference) ?
- Le deal couvre-t-il 1 utilisateur, 1 workspace, ou une petite equipe ?
- Quelle politique de remboursement est retenue pour la phase early ?

## Intention

Créer une offre fondatrice très tôt, avant l'ouverture complète du produit, pour:

- générer du cash flow maintenant;
- récompenser les premiers soutiens avec la meilleure offre possible;
- garder une structure de coûts saine grâce au mode BYOK;
- ne pas se piéger trop tôt dans une promesse "AI illimitée" économiquement risquée.

Le principe central:

- l'utilisateur achète un accès à vie à la plateforme;
- l'usage LLM reste en pay-as-you-go via sa propre clé;
- la plateforme facture l'accès produit, l'orchestration, l'interface, les workflows et la continuité de service;
- le fournisseur LLM facture la consommation variable.

## Résumé exécutif

L'offre à vendre n'est pas "de l'IA gratuite à vie".

L'offre à vendre est:

> un accès à vie à la couche produit ContentGlowz, avec un mode BYOK qui permet à chaque utilisateur de payer ses appels IA directement chez son provider, pendant que la plateforme fournit l'orchestration, les workflows, la mémoire de travail, l'UI et la couche métier.

Autrement dit:

- **Lifetime Deal** = accès à vie à la plateforme;
- **Pay-As-You-Go** = les coûts LLM ne transitent pas par nous;
- **Promesse économique** = faible coût marginal pour nous, meilleure soutenabilité du deal;
- **Promesse utilisateur** = pas d'abonnement mensuel pour accéder au produit, seulement ses coûts de consommation IA.

## Contexte produit

ContentGlowz n'est pas un simple chat IA.

La valeur du produit vient du système complet:

- cadrage projet / workspace;
- rituel hebdomadaire pour faire émerger la voix et le positionnement;
- personas;
- génération d'angles;
- dispatch vers plusieurs formats;
- research;
- newsletter;
- revue / validation / queue de contenu;
- mémoire projet et continuité de travail.

Le produit vend donc:

- une **méthode de production**;
- une **couche d'orchestration**;
- une **expérience produit spécialisée**;
- pas juste des tokens.

## Hypothèse d'offre

### Nom de travail

- Founding Supporter Lifetime Deal
- Early Early Bird Lifetime Access
- Founding BYOK Lifetime Pass

### Formulation simple

> Soutiens la construction maintenant, verrouille un accès à vie à ContentGlowz en mode BYOK, et paie ensuite tes consommations IA directement chez ton provider.

### Positionnement

Cette offre s'adresse aux personnes qui:

- aiment l'idée du produit;
- veulent accéder tôt à la plateforme;
- comprennent la logique BYOK;
- préfèrent éviter un abonnement SaaS supplémentaire;
- acceptent d'être des utilisateurs fondateurs d'un produit encore en construction.

## Cible

### Priorité 1

- créateurs solo;
- solopreneurs;
- consultants / freelances;
- petites agences de contenu;
- fondateurs qui produisent eux-mêmes leur contenu.

### Priorité 2

- équipes très petites qui peuvent fonctionner avec un compte principal;
- profils déjà familiers avec OpenRouter ou les API LLM;
- acheteurs de lifetime deals qui comprennent la différence entre "accès produit" et "coût d'usage".

## Problème utilisateur

Aujourd'hui, beaucoup d'utilisateurs vivent l'un de ces cas:

- ils paient déjà plusieurs outils IA différents;
- ils veulent une vraie machine de production, pas juste une fenêtre de chat;
- ils n'ont pas envie d'un abonnement de plus;
- ils veulent maîtriser leur coût variable;
- ils veulent choisir leurs modèles eux-mêmes.

Le Lifetime Deal BYOK répond à ça:

- un seul paiement pour la plateforme;
- pas de surprise sur la facture mensuelle SaaS;
- contrôle fin du coût IA;
- liberté de changer de modèles au fil du temps.

## Proposition de valeur

### Promesse coeur

> Paie une fois pour la plateforme. Utilise-la à vie. Branche ta propre clé IA. Garde le contrôle sur tes coûts.

### Promesses secondaires

- tu possèdes ton rythme de dépense IA;
- tu bénéficies de la couche produit sans abonnement mensuel;
- tu profites des futures améliorations du coeur produit BYOK;
- tu soutiens la construction du produit à un moment où ton support a le plus d'impact.

## Définition exacte du Lifetime Deal

Pour éviter toute ambiguïté, le deal doit être défini proprement.

### Ce que le Lifetime Deal inclut

- accès à vie à la plateforme ContentGlowz en mode BYOK;
- accès aux workflows coeur du produit dans ce mode;
- accès aux évolutions du produit tant qu'elles restent dans le périmètre BYOK coeur;
- stockage standard du compte et du workspace;
- orchestration applicative, UI, mémoire produit, paramètres, historique et logique métier;
- support fondateur raisonnable pendant la phase early.

### Ce que le Lifetime Deal n'inclut pas

- consommation LLM illimitée;
- crédits OpenRouter;
- budget API offert à vie;
- services tiers payants illimités;
- prestations humaines;
- SLA entreprise;
- promesse automatique d'inclusion de tous les futurs modes operator-paid.

### Définition recommandée de "lifetime"

> Accès à vie signifie accès pendant toute la durée de vie commerciale du produit ContentGlowz, pour le compte acheté, sur le périmètre explicitement inclus par l'offre.

Cette formulation doit rester honnête et défendable.

## Comment fonctionne le mode BYOK / Pay-As-You-Go

### Explication simple

1. l'utilisateur crée son compte ContentGlowz;
2. il ajoute sa clé OpenRouter dans l'application;
3. l'application utilise cette clé pour les actions IA compatibles;
4. OpenRouter facture directement l'utilisateur selon sa consommation;
5. ContentGlowz ne refacture pas ces tokens dans le mode BYOK;
6. le Lifetime Deal couvre l'accès au produit, pas la consommation variable.

### Ce que l'utilisateur paie réellement

- **une fois**: le Lifetime Deal ContentGlowz;
- **au fil de l'eau**: sa consommation LLM chez son provider.

### Ce que nous payons encore

Même en BYOK, nous gardons certains coûts:

- serveurs;
- base de données;
- auth;
- stockage;
- orchestration;
- monitoring;
- certaines intégrations serveur;
- support;
- maintenance produit.

Donc le mode BYOK ne veut pas dire "coût zéro pour nous".
Il veut dire:

- coûts variables LLM fortement réduits;
- structure de coûts plus prévisible;
- possibilité réelle de soutenir un Lifetime Deal.

## Comment expliquer le paiement à l'utilisateur

### Version ultra simple

> Tu paies une fois pour avoir la plateforme à vie. Ensuite, quand tu l'utilises avec ta propre clé, tu paies seulement ta consommation IA à ton provider.

### Version plus pédagogique

> ContentGlowz te fournit l'application, les workflows, le système de production, la mémoire, l'orchestration et l'expérience produit. Pour la génération IA, tu peux brancher ta propre clé OpenRouter. Dans ce cas, les appels modèles sont facturés directement par OpenRouter selon ton usage réel. Ton Lifetime Deal couvre donc l'accès au produit, pas les tokens.

### Bénéfices psychologiques

- pas de "double abonnement" opaque;
- pas de peur d'exploser un forfait caché;
- impression de contrôle;
- sentiment de payer pour une vraie valeur produit, pas pour des marges sur tokens.

## Recommandation stratégique

La meilleure architecture commerciale cible est probablement:

- **Mode 1 — BYOK / Pay-As-You-Go**
  - utilisateur apporte sa clé;
  - il paie sa conso à son provider;
  - nous facturons l'accès à la plateforme.

- **Mode 2 — Managed / Operator-Paid**
  - plus tard;
  - nous fournissons la consommation;
  - abonnement ou crédits inclus;
  - UX plus simple;
  - marge et packaging différents.

### Recommandation pour le Lifetime Deal

Le Lifetime Deal doit promettre **à vie le mode BYOK**, pas à vie le mode operator-paid.

C'est le point qui protège l'économie de l'offre.

Formulation recommandée:

> Le Lifetime Deal garantit l'accès à vie à ContentGlowz en mode BYOK. Si des plans managés ou avec crédits sont lancés plus tard, ils pourront exister comme options séparées.

## Pourquoi cette offre est forte

### Pour l'utilisateur

- il verrouille un prix unique;
- il évite un futur abonnement récurrent;
- il garde le contrôle sur sa stack et ses coûts d'usage;
- il soutient un produit qu'il veut voir exister.

### Pour nous

- cash flow immédiat;
- validation de demande;
- communauté fondatrice;
- faible risque de ruine unitaire par usage LLM;
- base propre pour ajouter plus tard des plans managés plus rentables.

## Risques à éviter dans le copywriting

Ne pas dire:

- "IA illimitée"
- "génération gratuite à vie"
- "tous les coûts inclus"
- "tout futur plan inclus à vie"

Préférer:

- "accès à vie à la plateforme"
- "mode BYOK inclus"
- "tu gardes le contrôle de ta consommation"
- "les coûts IA restent facturés par ton provider"

## Offre produit recommandée

### Contenu minimal de l'offre

- 1 compte fondateur;
- accès à vie à la plateforme en mode BYOK;
- accès au coeur des workflows BYOK;
- mises à jour du coeur produit BYOK;
- onboarding fondateur;
- badge / statut fondateur;
- canal de feedback prioritaire;
- éventuels bonus non critiques:
  - accès anticipé aux nouvelles fonctionnalités;
  - groupe privé;
  - session onboarding groupée;
  - template / playbooks fondateurs.

### Garde-fous recommandés

- nombre de deals limité;
- périmètre clair;
- clause anti-revente;
- usage raisonnable / fair use pour les ressources serveur;
- pas de promesse sur les futurs coûts de services tiers non-LLM.

## Questions pricing à trancher plus tard

Ne pas figer ici les montants.

Questions ouvertes:

- prix exact du Lifetime Deal;
- nombre maximal de deals vendus;
- bonus fondateurs inclus ou non;
- une personne / un workspace ou plus;
- politique de remboursement;
- éventuel prix de réservation avant lancement;
- date de conversion du supporter en compte lifetime actif.

## Option de pré-lancement recommandée

Comme le produit n'est pas encore "disponible" dans son état final, il peut être plus sain de vendre d'abord:

- soit une **Founding Supporter Reservation**;
- soit un **Founding Pass**;
- soit un **préachat Lifetime Deal** avec onboarding progressif.

### Approche recommandée

- phase 1: page d'intérêt + paiement de soutien / réservation;
- phase 2: onboarding manuel des fondateurs;
- phase 3: activation normale dans le produit.

Cela permet de vendre sans prétendre que tout est déjà industrialisé.

## Objections et réponses

### "Pourquoi je paierais un lifetime deal si je dois aussi mettre ma clé ?"

Parce que la valeur n'est pas la clé. La valeur est la plateforme: le workflow, l'orchestration, la mémoire, l'interface, les systèmes de production et le gain de temps. La clé finance seulement la consommation variable.

### "Donc je paie deux fois ?"

Non, tu paies deux choses différentes:

- une fois pour l'accès à la plateforme;
- ensuite ta consommation réelle à ton provider.

Sans ça, il faudrait te vendre un abonnement récurrent qui intègre des coûts variables difficiles à maîtriser.

### "Est-ce que vous allez lancer un abonnement plus tard ?"

Probablement oui. Et c'est normal. Le mode lifetime doit rester le meilleur deal BYOK, tandis que des offres plus simples et plus assistées pourront exister en parallèle.

### "Est-ce que le lifetime deal inclura aussi les futurs plans managés ?"

Non par défaut. Ce serait dangereux économiquement. Le deal doit garantir l'accès BYOK à vie. Toute extension future éventuelle doit être présentée comme un bonus, pas comme une promesse de base.

### "Que se passe-t-il si je change de provider ou de modèle ?"

Tant que la plateforme supporte ton mode BYOK cible, tu gardes la souplesse de faire évoluer ta consommation sans changer de deal plateforme.

## Message marketing brut

### Headline candidate

Paie une fois. Garde la plateforme à vie. Branche ta propre IA.

### Alternatives

- Le Lifetime Deal le plus simple: la plateforme à vie, tes coûts IA sous contrôle.
- Soutiens ContentGlowz tôt, verrouille ton accès à vie, paie seulement ta conso réelle.
- L'accès à vie au système. Les tokens restent chez ton provider.

### Subheadline candidate

ContentGlowz t'offre la machine de production complète. En mode BYOK, tu conserves le contrôle de ta facture IA en branchant ta propre clé OpenRouter.

### Bullets de vente

- accès à vie à ContentGlowz en mode BYOK;
- aucun abonnement mensuel requis pour utiliser la plateforme;
- tu paies tes appels IA directement à ton provider;
- tu soutiens le produit au moment où ton aide compte le plus;
- tu verrouilles l'offre fondatrice la plus agressive avant le pricing final.

## Angle de vente recommandé

Ne pas vendre seulement:

- "un bon deal"

Vendre:

- "une façon plus saine d'acheter un produit IA"

Le récit:

1. la plupart des outils IA mélangent produit + tokens + marge;
2. ça rend les prix opaques et les deals fragiles;
3. ContentGlowz sépare la plateforme de la consommation;
4. le Lifetime Deal devient enfin crédible;
5. les premiers supporters récupèrent la meilleure version de cette logique.

## Structure de landing page recommandée

### Section 1 — Hero

- headline forte;
- sous-titre clair sur BYOK;
- CTA:
  - rejoindre la liste;
  - réserver son deal;
  - soutenir le projet.

### Section 2 — Pourquoi cette offre existe

- produit encore tôt;
- besoin de soutiens fondateurs;
- meilleure récompense pour les premiers.

### Section 3 — Comment ça marche

- tu achètes l'accès;
- tu connectes ta clé;
- tu utilises la plateforme;
- ton provider facture ta conso.

### Section 4 — Ce que tu achètes vraiment

- système;
- workflow;
- couche produit;
- pas seulement des prompts.

### Section 5 — Ce qui est inclus / non inclus

Tableau simple, sans ambiguïté.

### Section 6 — Pourquoi c'est potentiellement le meilleur deal

- pas d'abonnement;
- pas de promesse intenable;
- contrôle des coûts;
- upside long terme si le produit grossit.

### Section 7 — FAQ

- "Pourquoi BYOK ?"
- "Pourquoi un lifetime deal maintenant ?"
- "Qu'est-ce qui est à vie exactement ?"
- "Est-ce que je dois déjà avoir une clé ?"
- "Est-ce qu'il y aura des plans abonnés plus tard ?"

## Garde-fous juridiques et commerciaux

À prévoir avant vente publique:

- conditions exactes du lifetime deal;
- définition écrite de "lifetime";
- politique de remboursement;
- périmètre BYOK clairement listé;
- clause sur l'évolution future des plans managés;
- usage raisonnable des services serveur;
- non-transférabilité éventuelle.

## Métriques de succès

### Court terme

- nombre d'inscrits intéressés;
- taux de clic vers l'offre;
- nombre de supporters payants;
- cash collecté;
- taux de réponse positif au message BYOK.

### Moyen terme

- activation des fondateurs;
- usage réel du mode BYOK;
- rétention à 30 / 90 jours;
- conversion future vers options managées;
- qualité du feedback produit fondateur.

## Décision produit recommandée à ce stade

Oui pour:

- préparer et tester un Lifetime Deal BYOK;
- le positionner comme offre fondatrice;
- garder ouverte une future gamme operator-paid.

Non pour:

- promettre l'illimité;
- promettre tous les futurs plans;
- transformer dès maintenant tous les services non-LLM en BYOK.

## Version courte de la thèse

> Le Lifetime Deal n'achète pas des tokens. Il achète le système. Les tokens restent à la charge de l'utilisateur via BYOK. C'est précisément ce qui rend le deal crédible, soutenable et désirable.

## Questions à reprendre plus tard

- Quel prix exact donne assez de cash maintenant sans brader trop tôt la valeur future ?
- Faut-il vendre un vrai LTD tout de suite ou d'abord une réservation fondateur ?
- Le deal couvre-t-il 1 utilisateur, 1 workspace, ou 1 petite équipe ?
- Quel niveau de fair use faut-il poser sur les coûts serveur et sur les services tiers non-LLM ?
- Quel bonus minimum peut rendre l'offre irrésistible sans fragiliser l'économie long terme ?
