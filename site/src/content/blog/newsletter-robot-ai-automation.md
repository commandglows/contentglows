---
title: "Newsletter Robot : une veille email automatisée avec IMAP et CrewAI"
description: "Découvrez l'architecture actuelle du Newsletter Robot ContentGlows : lecture Gmail par IMAP, recherche Exa et génération orchestrée avec CrewAI."
locale: "fr"
publishDate: "2026-02-02"
updatedDate: "2026-07-13"
tags: ["newsletter", "ai automation", "crewai", "imap", "email marketing", "content automation"]
heroImage: "/og-default.jpg"
featured: true
---

# Newsletter Robot : une veille email automatisée avec IMAP et CrewAI

Le Newsletter Robot transforme une boîte de réception dédiée en source de veille. Il lit les newsletters récentes, recherche des informations complémentaires et prépare un brouillon structuré.

L'architecture actuellement supportée repose sur trois briques :

- **IMAP** pour lire et archiver les emails ;
- **Exa** pour compléter la recherche ;
- **CrewAI** et OpenRouter pour orchestrer l'analyse et la rédaction.

## Pourquoi IMAP ?

IMAP couvre le besoin actuel sans ajouter un fournisseur d'intégration supplémentaire. Le backend utilise un mot de passe d'application Gmail, limite la lecture à un dossier dédié et peut déplacer les messages traités dans un dossier d'archive.

Cette solution garde une frontière simple : ContentGlows accède uniquement à la boîte configurée par l'opérateur. Une intégration gérée pourra être réévaluée plus tard si elle apporte un avantage produit clair et si elle reste compatible avec la version de CrewAI utilisée par le projet.

## Le flux de génération

Le pipeline suit trois étapes :

1. lire les newsletters du dossier IMAP configuré ;
2. analyser les thèmes et compléter les sources avec Exa ;
3. générer un brouillon validé par les schémas Pydantic.

```text
Gmail / IMAP
     |
     v
Research Agent ---- Exa
     |
     v
Writer Agent
     |
     v
NewsletterDraft
```

L'accès email est optionnel. Une requête peut désactiver les insights issus de la boîte de réception avec `include_email_insights: false`.

## Configuration Gmail

Créez un dossier Gmail réservé aux newsletters, activez IMAP et utilisez un mot de passe d'application plutôt que le mot de passe principal du compte.

```bash
NEWSLETTER_IMAP_EMAIL=your-newsletters@gmail.com
NEWSLETTER_IMAP_PASSWORD=xxxx-xxxx-xxxx-xxxx
NEWSLETTER_IMAP_HOST=imap.gmail.com
NEWSLETTER_IMAP_FOLDER=Newsletters
NEWSLETTER_IMAP_ARCHIVE=CONTENTGLOWS_DONE
```

Le compte doit rester dédié à la veille. Le dossier `Newsletters` délimite les messages à analyser et `CONTENTGLOWS_DONE` reçoit ceux qui ont été traités.

## Vérifier la configuration

```bash
curl "http://localhost:8000/newsletter/config/check?include_email_insights=true"
```

La réponse indique séparément la disponibilité d'OpenRouter, d'Exa, de SendGrid et d'IMAP. Si les insights email sont demandés alors qu'IMAP n'est pas configuré, l'API renvoie une erreur de dépendance explicite.

## Générer une newsletter

```bash
curl -X POST http://localhost:8000/newsletter/generate \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Weekly SEO Digest",
    "topics": ["SEO", "IA", "content marketing"],
    "target_audience": "Responsables marketing",
    "tone": "professional",
    "competitor_emails": ["newsletter@example.com"],
    "include_email_insights": true,
    "max_sections": 5
  }'
```

Le même workflow est disponible en Python :

```python
from agents.newsletter import NewsletterCrew
from agents.newsletter.schemas.newsletter_schemas import NewsletterConfig

config = NewsletterConfig(
    name="Weekly SEO Digest",
    topics=["SEO", "IA", "content marketing"],
    target_audience="Responsables marketing",
    competitor_emails=["newsletter@example.com"],
    include_email_insights=True,
)

crew = NewsletterCrew(use_gmail=True)
result = crew.generate_newsletter(config)
```

## Bonnes pratiques

- Utilisez une adresse Gmail dédiée à la veille.
- Filtrez automatiquement les abonnements vers le dossier configuré.
- Gardez la génération en mode brouillon avant tout envoi.
- Révoquez immédiatement le mot de passe d'application si le compte n'est plus utilisé.
- Désactivez les insights email pour les générations qui n'en ont pas besoin.

## Ce que cette architecture évite

Le runtime ne dépend plus d'un SDK d'intégration Gmail tiers. Cela réduit le graphe de dépendances Python, supprime une API devenue obsolète dans le code du projet et évite de rétrograder CrewAI pour satisfaire une contrainte de compatibilité.

Le choix reste réversible : une future intégration devra être évaluée sur ses bénéfices réels, sa maintenance, ses permissions et sa compatibilité avec la pile active.

[Consulter le guide complet](/docs/guides/newsletter-robot-guide)
