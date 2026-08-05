---
title: "Newsletter Robot - Guide Complet"
description: "Documentation technique pour le Newsletter Robot : installation, configuration, API, et bonnes pratiques."
---

# Newsletter Robot - Guide Technique

## Vue d'Ensemble

Le Newsletter Robot est un système multi-agents qui automatise :
1. **Lecture** des emails Gmail (newsletters concurrentes)
2. **Analyse** des tendances via Exa AI
3. **Génération** de contenu newsletter
4. **Distribution** via SendGrid ou Gmail drafts

## Installation Rapide

```bash
# Prérequis
python --version  # 3.11+

# Installation
cd ~/contentglows
pip install -r requirements.txt

# Configurer l'accès IMAP (voir section Configuration)

# Vérification
curl http://localhost:8000/newsletter/config/check
```

## Configuration

### Accès aux emails

Le robot lit les emails directement via IMAP avec un mot de passe d'application Gmail.

### Variables d'Environnement

```bash
# .env

# --- Core ---
OPENROUTER_API_KEY=sk-or-...        # LLM provider
EXA_API_KEY=...                      # Recherche web

# --- Accès aux emails ---
NEWSLETTER_IMAP_EMAIL=your-newsletters@gmail.com
NEWSLETTER_IMAP_PASSWORD=xxxx-xxxx-xxxx-xxxx  # Gmail App Password
NEWSLETTER_IMAP_FOLDER=Newsletters            # Optionnel
NEWSLETTER_IMAP_ARCHIVE=CONTENTGLOWS_DONE # Optionnel

# --- Envoi (optionnel) ---
SENDGRID_API_KEY=SG...
NEWSLETTER_FROM_EMAIL=newsletter@domain.com
NEWSLETTER_FROM_NAME="My Newsletter"
```

### Setup Gmail pour IMAP

1. **Créer compte Gmail dédié** : `your-newsletters@gmail.com`

2. **Activer 2FA** :
   - Google Account → Security → 2-Step Verification → Enable

3. **Générer App Password** :
   - Google Account → Security → App Passwords
   - Select "Mail" + "Other (Custom name)"
   - Copier le mot de passe 16 caractères

4. **Créer labels Gmail** :
   - `Newsletters` - pour les newsletters entrantes
   - `CONTENTGLOWS_DONE` - archive après traitement

5. **Créer filtre Gmail** :
   - Settings → Filters → Create new filter
   - From contains: `newsletter OR digest OR weekly`
   - Apply label: `Newsletters`

### Configuration Newsletter

```python
from agents.newsletter.schemas import NewsletterConfig, NewsletterTone

config = NewsletterConfig(
    name="Weekly Digest",
    topics=["SEO", "AI", "Marketing"],
    target_audience="Digital marketers",
    tone=NewsletterTone.PROFESSIONAL,
    competitor_emails=["newsletter@competitor.com"],
    include_email_insights=True,
    max_sections=5,
    include_intro=True,
    include_outro=True,
    include_cta=True,
    cta_text="Start Free Trial",
    cta_url="https://example.com/trial",
)
```

## Architecture

### Structure des Fichiers

```
agents/newsletter/
├── __init__.py
├── newsletter_agent.py      # 3 agents CrewAI
├── newsletter_crew.py       # Orchestrateur + archivage
├── tools/
│   ├── imap_tools.py        # IMAP direct (gratuit)
│   └── content_tools.py     # Exa AI research
├── schemas/
│   └── newsletter_schemas.py # Pydantic models
└── config/
    └── newsletter_config.py  # Configuration newsletter et IMAP
```

### Les 3 Agents

| Agent | Rôle | Tools |
|-------|------|-------|
| **Research** | Lit emails, analyse tendances | Gmail, Exa AI |
| **Writer** | Rédige contenu | LLM uniquement |
| **Coordinator** | Finalise output | Archivage IMAP, SendGrid |

## Utilisation

### Via Python

```python
from agents.newsletter import NewsletterCrew

crew = NewsletterCrew(use_gmail=True)
result = crew.generate_newsletter(config)

print(result["draft"]["subject_line"])
# "5 SEO Trends You Missed This Week"
```

### Via API REST

```bash
# Génération synchrone
curl -X POST http://localhost:8000/newsletter/generate \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Weekly SEO Digest",
    "topics": ["SEO", "AI"],
    "target_audience": "marketers",
    "competitor_emails": ["newsletter@moz.com"]
  }'

# Génération asynchrone (pour newsletters longues)
curl -X POST http://localhost:8000/newsletter/generate/async \
  -d '{"name": "...", "topics": [...]}'

# Vérifier statut
curl http://localhost:8000/newsletter/status/{job_id}
```

## Email Tools

### IMAP Tools (Backend par défaut)

```python
from agents.newsletter.tools.imap_tools import IMAPNewsletterReader

reader = IMAPNewsletterReader()

# Toutes les newsletters (7 jours)
newsletters = reader.fetch_newsletters(
    folder="Newsletters",
    max_results=20,
    days_back=7
)

# Concurrents spécifiques
competitor_emails = reader.fetch_by_senders(
    sender_emails=["newsletter@moz.com", "digest@ahrefs.com"]
)

# Archiver après traitement
reader.archive_multiple([email.uid for email in newsletters])
```

### CrewAI Tools (IMAP)

```python
from agents.newsletter.tools.imap_tools import (
    read_recent_newsletters,      # Lit newsletters récentes
    read_competitor_newsletters,  # Lit concurrents spécifiques
    archive_processed_newsletter, # Archive un email
    archive_multiple_newsletters, # Archive plusieurs emails
)
```

## Schémas de Données

### NewsletterConfig

```python
class NewsletterConfig(BaseModel):
    name: str                           # Nom newsletter
    topics: List[str]                   # Sujets à couvrir
    tone: NewsletterTone                # professional/casual/friendly
    target_audience: str                # Description audience
    competitor_emails: List[str] = []   # Emails concurrents
    include_email_insights: bool = True # Lire Gmail
    max_sections: int = 5               # Nombre de sections
    include_intro: bool = True
    include_outro: bool = True
    include_cta: bool = True
    cta_text: Optional[str] = None
    cta_url: Optional[str] = None
```

### NewsletterDraft

```python
class NewsletterDraft(BaseModel):
    config: NewsletterConfig
    subject_line: str           # <50 caractères
    preview_text: str           # <100 caractères
    sections: List[NewsletterSection]
    html_content: Optional[str]
    plain_text: Optional[str]
    word_count: int
    estimated_read_time: int    # minutes
    email_sources: List[str]    # IDs emails utilisés
    web_sources: List[str]      # URLs utilisées
```

## Personnalisation

### Changer le LLM

```python
from agents.newsletter.config import get_newsletter_config

# Utiliser GPT-4 au lieu de Claude
config = get_newsletter_config({
    "llm_model": "openrouter/openai/gpt-4-turbo"
})

# Ou Mixtral pour réduire les coûts
config = get_newsletter_config({
    "llm_model": "openrouter/mistralai/mixtral-8x7b-32768"
})
```

### Templates HTML Personnalisés

```python
# Créer templates dans agents/newsletter/templates/
# Utiliser Jinja2 pour le rendu

from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader('templates'))
template = env.get_template('newsletter_template.html')

html = template.render(
    subject=draft.subject_line,
    sections=draft.sections,
    cta_text=config.cta_text,
)
```

## Dépannage

### Erreur : "IMAP credentials required"

```bash
# Vérifier variables d'environnement
echo $NEWSLETTER_IMAP_EMAIL
echo $NEWSLETTER_IMAP_PASSWORD

# Les définir
export NEWSLETTER_IMAP_EMAIL="your@gmail.com"
export NEWSLETTER_IMAP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

### Erreur : "Authentication failed" (IMAP)

1. Vérifier que le App Password est correct (16 caractères, sans espaces)
2. Vérifier que 2FA est activé sur le compte Gmail
3. Vérifier que IMAP est activé : Gmail Settings → Forwarding and POP/IMAP → Enable IMAP

### Erreur : "No newsletters found"

```python
# IMAP: Vérifier les folders
reader.fetch_newsletters(
    folder="INBOX",  # Essayer INBOX au lieu de Newsletters
    days_back=30     # Étendre la période
)

```

### Erreur : "Folder not found" (IMAP)

Créer les labels Gmail :
- `Newsletters`
- `CONTENTGLOWS_DONE`

Le système fallback vers INBOX si les labels n'existent pas.

### Erreur : "Rate limit exceeded"

```python
# Ajouter délai entre les appels
import time

for email in emails:
    process(email)
    time.sleep(1)  # 1 seconde entre chaque
```

## Performance

| Métrique | Valeur Typique |
|----------|----------------|
| Temps génération | 2-5 minutes |
| Coût par newsletter | $0.10-0.20 |
| Emails lus | 10-50 |
| Mots générés | 1000-2000 |

## Ressources

- [Guide Plateforme](/docs/platform/newsletter-robot) - Vue d'ensemble marketing et cas d'usage
- [Architecture Multi-Agents](/docs/agents/newsletter-agents) - Comment les agents IA collaborent
- [Annonce IMAP Gratuit](/blog/newsletter-robot-imap-gratuit) - Nouvelle intégration sans frais
- [CrewAI Documentation](https://docs.crewai.com)
