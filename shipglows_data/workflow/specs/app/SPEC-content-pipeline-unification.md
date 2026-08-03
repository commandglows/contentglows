---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: app
created: "2026-04-25"
updated: "2026-04-27"
status: ready
source_skill: sf-docs
scope: feature
owner: unknown
confidence: low
risk_level: medium
security_impact: unknown
docs_impact: yes
user_story: "unknown (legacy spec migrated to ShipGlowz metadata)"
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs audit shipglows_data/workflow/specs/app/SPEC-content-pipeline-unification.md"
---
# Spec: Unification du Content Pipeline — Sources, Angles, Formats

Date: 2026-03-25

## Titre

Unifier les pipelines de generation de contenu en un flux unique:
Sources d'idees → Idea Pool → Angle Strategist → Pipelines par format → Review Queue

## Probleme

Le backend a aujourd'hui trois pipelines deconnectes:

1. **Psychology Engine** — genere des angles a partir du recit createur + persona, mais:
   - `/api/psychology/render-extract` est un placeholder (texte statique)
   - aucune donnee SEO ou signal de demande externe ne nourrit les angles
   - pas de generation reelle multi-format

2. **SEO Crew** — pipeline 6 agents (Research → Strategy → Writing → Technical → Marketing → Editing), mais:
   - deconnecte du Psychology Engine
   - ne recoit jamais les angles du createur
   - pas de lien avec les personas

3. **Newsletter Crew** — pipeline dedie newsletter, mais:
   - independant des deux autres
   - le scheduler ne dispatch que les newsletters (`_run_seo_job` et `_run_article_job` sont des stubs)

Consequence: le produit ne peut pas encore realiser sa promesse fondamentale:
"L'IA genere du contenu aligne avec ta voix → tu swipes → c'est publie."

## Solution

Un flux unifie en 4 couches:

```
COUCHE 1 — SOURCES (asynchrones, alimentent l'Idea Pool)
COUCHE 2 — ANGLE GENERATION (croise createur × persona × signaux demande)
COUCHE 3 — CONTENT PIPELINES (un par format, frequence configurable)
COUCHE 4 — REVIEW QUEUE (swipe Flutter, deja en place)
```

---

## Architecture detaillee

### Couche 1 — Sources

Chaque source tourne de maniere asynchrone et alimente un **Idea Pool** commun.

| Source | Methode | Ce qu'elle produit | Frequence |
|--------|---------|--------------------|-----------|
| Newsletter Inbox | IMAP (existant dans `newsletter/tools/imap_tools.py`) | Sujets extraits, tendances, citations | Toutes les 6h |
| SEO Keywords | Advertools + SERP (existant dans `seo_research_tools.py`) | Opportunites keyword avec volume, difficulte, intent | Quotidien |
| Trending Topics | API plateforme (TikTok trending, Twitter/X trends, LinkedIn) | Hashtags tendance, sujets viraux | Toutes les 4h |
| Weekly Ritual | Saisie manuelle createur (existant dans Flutter) | Reflexions, wins, struggles, idees, pivots | Hebdomadaire |
| Competitor Watch | Exa AI (existant dans `research_analyst.py`) | Contenus concurrents performants, gaps identifies | Hebdomadaire |

**Schema Idea Pool:**

```python
class IdeaSource:
    id: str
    source_type: str          # "newsletter_inbox", "seo_keyword", "trending", "ritual", "competitor"
    raw_data: dict            # donnees brutes de la source
    extracted_topics: list[str]
    relevance_score: float    # 0-1, calcule par rapport au profil createur
    platform_signals: dict    # {"tiktok_volume": 12000, "google_search_volume": 5400, ...}
    created_at: datetime
    expires_at: datetime | None  # les trending expirent vite
```

### Couche 2 — Angle Generation (enrichi)

L'Angle Strategist actuel (`agents/psychology/angle_strategist.py`) est enrichi pour recevoir en plus des signaux de demande.

**Entrees:**
- Creator voice + positioning + narrative (existant)
- Persona data (existant)
- **NEW:** Idea Pool filtrees par pertinence (top N idees recentes)
- **NEW:** SEO opportunities (keywords avec volume + intent matches)
- **NEW:** Trending signals (par plateforme cible)

**Sortie enrichie:**

```python
class EnrichedAngle:
    # existant
    title: str
    hook: str
    angle: str
    content_type: str          # "blog_post", "newsletter", "short", "social_post"
    narrative_thread: str
    pain_point_addressed: str
    confidence: int

    # NEW
    target_formats: list[str]  # un angle peut generer plusieurs formats
    seo_data: dict | None      # {"primary_keyword": "...", "volume": 5400, "difficulty": 32}
    trending_data: dict | None # {"platform": "tiktok", "hashtags": [...], "velocity": "rising"}
    source_ideas: list[str]    # IDs des sources qui ont inspire cet angle
    priority_score: float      # calcule: confidence × relevance × demand_signal
```

**Logique de scoring par format:**
- Blog article: `confidence × seo_volume × (1 - keyword_difficulty)`
- Newsletter: `confidence × topic_freshness × persona_engagement`
- Short/Reel: `confidence × trending_velocity × hook_strength`
- Social post: `confidence × platform_relevance × shareability`

### Couche 3 — Content Pipelines (un par format)

Chaque format a son propre pipeline d'agents, ses metadonnees specifiques, et sa cadence configurable.

#### 3a. Blog Pipeline

```
Angle enrichi (avec SEO data)
  → SEO Crew existant (Research → Strategy → Writing → Technical → Marketing → Editing)
  → Output: article complet
```

**Metadonnees blog:**
```python
class BlogMetadata:
    primary_keyword: str
    secondary_keywords: list[str]
    search_volume: int
    keyword_difficulty: int
    word_count: int
    reading_time_minutes: int
    schema_types: list[str]    # Article, FAQ, HowTo
    internal_links: list[str]
    meta_title: str
    meta_description: str
    slug: str
```

#### 3b. Newsletter Pipeline

```
Angle enrichi (avec newsletter inbox insights)
  → Newsletter Crew existant (Research → Curate → Write → Review)
  → Output: newsletter formatee
```

**Metadonnees newsletter:**
```python
class NewsletterMetadata:
    subject_line: str
    preview_text: str
    sections: list[dict]       # titre, contenu, CTA par section
    estimated_read_time: int
    cta_primary: str
    cta_url: str
    source_references: list[str]  # newsletters/articles qui ont inspire
    ab_subject_variant: str | None
```

#### 3c. Short Pipeline (NEW — a creer)

```
Angle enrichi (avec trending data)
  → Short Creator Agent (nouveau)
     - Hook Writer: premiere phrase accrocheuse (< 3 sec)
     - Script Writer: script 30-60s avec timecodes
     - Hashtag Researcher: hashtags optimises par plateforme
  → Output: script court pret a filmer
```

**Metadonnees short:**
```python
class ShortMetadata:
    hook: str                  # phrase d'accroche (< 10 mots)
    script: str                # script avec timecodes
    duration_seconds: int      # 30, 60, ou 90
    target_platforms: list[str]  # tiktok, instagram_reels, youtube_shorts
    hashtags: dict[str, list[str]]  # par plateforme
    trending_sound: str | None
    cta: str
    visual_notes: str          # notes pour le montage
```

#### 3d. Social Pipeline (NEW — a creer)

```
Angle enrichi
  → Social Writer Agent (nouveau)
     - Platform Adapter: adapte le contenu par plateforme
     - Thread Builder: (Twitter/X) decoupe en thread si necessaire
     - Hashtag Optimizer: hashtags par plateforme
  → Output: posts adaptes par plateforme
```

**Metadonnees social:**
```python
class SocialMetadata:
    platform: str              # twitter, linkedin, instagram
    format: str                # single, thread, carousel
    character_count: int
    hashtags: list[str]
    mentions: list[str]
    media_suggestion: str | None  # "infographic", "screenshot", "photo"
    best_posting_time: str | None
    thread_parts: list[str] | None  # si format=thread
```

### Couche 4 — Review Queue

La review queue Flutter existante (feed screen avec swipe) recoit le contenu genere.

**Changements necessaires:**
- Chaque `ContentItem` porte ses metadonnees specifiques au format dans le champ `metadata`
- L'editeur adapte son UI selon le `content_type` (preview newsletter, timecodes short, etc.)
- Le swipe droite (approve) enchaine vers le bon canal de publication

### Configuration utilisateur — Frequence par format

```python
class ContentFrequencyConfig:
    blog_posts_per_month: int      # default: 4
    newsletters_per_week: int      # default: 1
    shorts_per_day: int            # default: 1
    social_posts_per_day: int      # default: 2

    # Jours/heures preferes par format
    blog_preferred_days: list[str]   # ["monday", "thursday"]
    newsletter_preferred_day: str    # "tuesday"
    short_posting_times: list[str]   # ["09:00", "18:00"]
    social_posting_times: list[str]  # ["08:00", "12:00", "17:00"]
```

Le scheduler utilise cette config pour:
1. Calculer combien de contenus generer en avance (buffer de 2-3 jours)
2. Declencher les pipelines au bon rythme
3. Alimenter la review queue a la bonne cadence

---

## Scope In

- Remplacer le placeholder `render-extract` par de vrais pipelines de generation
- Enrichir l'Angle Strategist avec les signaux SEO et trending
- Creer le Short Pipeline (nouvel agent)
- Creer le Social Pipeline (nouvel agent)
- Connecter le SEO Crew existant au flux d'angles pour les articles blog
- Connecter le Newsletter Crew existant au flux d'angles
- Implementer l'Idea Pool comme couche d'agregation des sources
- Implementer la config de frequence par format
- Completer le scheduler (`_run_seo_job`, `_run_article_job` + nouveaux types)
- Ajouter les metadonnees par format dans `ContentItem.metadata`

## Scope Out

- Nouveaux connecteurs de sources (TikTok API, Twitter API) — phase ulterieure
- Preview visuel par plateforme dans Flutter — deja dans le backlog P2
- A/B testing de hooks — backlog P3
- Image generation (Robolly) — backlog P3
- Video generation automatique — hors scope

## Dependances

- Les agents CrewAI existants (SEO Crew, Newsletter Crew, Psychology agents) restent en place
- Le status tracking existant (`status/service.py`) est reutilise pour tous les pipelines
- L'API Flutter existante (`api_service.dart`) devra evoluer pour les nouvelles metadonnees
- La config de frequence s'integre dans `AppSettings` (deja expose via `/api/settings`)

## Risques

- **Performance**: generer du contenu multi-format est couteux en tokens LLM. Mitigation: generation asynchrone, buffer, prioritisation.
- **Qualite**: plus de formats = plus de contenu a reviewer. Mitigation: scoring strict, seuil de confidence minimum pour entrer en review queue.
- **Complexite scheduler**: orchestrer 4 pipelines a des cadences differentes. Mitigation: implementer format par format, commencer par blog (le plus mature).

## Ordre d'implementation suggere

1. **Idea Pool + enrichissement Angle Strategist** — fondation
2. **Blog Pipeline** — connecter SEO Crew aux angles (le plus de code existant)
3. **Newsletter Pipeline** — connecter Newsletter Crew aux angles
4. **Short Pipeline** — creer le nouvel agent
5. **Social Pipeline** — creer le nouvel agent
6. **Frequence config + scheduler complet** — orchestration
7. **Flutter: metadonnees par format dans l'editeur** — UX
