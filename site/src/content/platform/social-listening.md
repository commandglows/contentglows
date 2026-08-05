---
title: "Social Listening"
description: "Discover what your audience is talking about right now. Scan Reddit, X, Hacker News, and YouTube to find trending topics, detect cross-platform convergence, and fuel your content calendar with data-driven ideas."
pubDate: 2026-03-30
author: "ContentGlows Team"
tags: ["social listening", "idea generation", "content strategy", "reddit", "hacker news", "youtube", "trending"]
featured: true
image: "/images/blog/social-listening.jpg"
---

# Social Listening

Stop guessing what to write about. Social Listening scans Reddit, X, Hacker News, and YouTube for what people are discussing *right now* in your niche, then feeds the best ideas directly into your content calendar.

---

## Why Social Listening?

### The Problem

Most content teams rely on two sources for ideas:

- **SEO tools** tell you what people searched last month
- **Newsletters** tell you what other creators published last week

Both are lagging indicators. By the time you publish, the conversation has moved on.

What's missing is the **real-time signal**: what are actual people asking, debating, and sharing *today*?

### The Solution

Social Listening monitors 4 platforms simultaneously and identifies the topics worth writing about before your competitors do.

| Traditional Approach | With Social Listening |
|---------------------|----------------------|
| Manually browse Reddit and X | Automated scan across 4 platforms |
| Miss trends outside your usual feeds | Cross-platform convergence detection |
| No idea which topics have real demand | Engagement-ranked with velocity scoring |
| Hours of manual research | One API call, dozens of ranked ideas |

---

## How It Works

### 1. Multi-Platform Collection

Social Listening scans four platforms for your topics:

| Platform | What It Captures | Signal Type |
|----------|-----------------|-------------|
| **Reddit** | Subreddit discussions, upvotes, comment counts | Community engagement |
| **X / Twitter** | Tweets, threads, engagement metrics | Real-time buzz |
| **Hacker News** | Stories, points, discussion threads | Tech/startup signal |
| **YouTube** | Videos, views, descriptions | Long-form interest |

Each platform reveals a different facet of audience interest. Reddit shows what people ask. X shows what people share. HN shows what technologists care about. YouTube shows what people want explained.

### 2. Cross-Platform Convergence

This is where it gets powerful. When the **same topic** trends on 2+ platforms simultaneously, that's a strong signal.

```
"AI content marketing" trending on:
  Reddit (342 upvotes, 47 comments)  ──┐
  Hacker News (180 points, 45 comments) ──┤── Convergence detected!
                                          │   Score: 1.5x boost
                                          │   Tag: "converging"
```

A topic that only trends on Reddit might be a niche discussion. A topic that trends on Reddit *and* HN *and* YouTube? That's a content opportunity you can't afford to miss.

### 3. Engagement Velocity Scoring

Not all trending topics are equal. Social Listening ranks ideas using a composite score:

| Factor | Weight | What It Measures |
|--------|--------|-----------------|
| **Engagement** | 40% | Upvotes, likes, points, views |
| **Recency** | 30% | How fresh the conversation is |
| **Convergence** | 30% | Cross-platform presence |

A post with 50 upvotes in 2 days scores higher than one with 200 upvotes over 30 days. The velocity matters more than the absolute numbers.

### 4. Question Detection

Social Listening automatically identifies posts that are **questions** from your audience:

- Posts containing "?"
- Titles starting with "How", "Why", "What", "Is there", "Can I", "Should I"

Question signals are gold for content strategy: they represent explicit demand. Someone is actively looking for an answer you could provide.

### 5. Deduplication

Before injecting ideas, the system removes near-duplicates using trigram similarity matching. If three Reddit posts ask essentially the same question, you get one idea with the highest engagement — not three noise entries in your calendar.

---

## What You Get

Every idea injected into your calendar includes:

```json
{
  "title": "How to use AI for content marketing",
  "priority_score": 72.5,
  "trending_signals": {
    "platforms_found": ["reddit", "hn"],
    "total_engagement": 520,
    "engagement_velocity": 17.3,
    "convergence_score": 1.5,
    "question_signal": true
  },
  "tags": ["social_listening", "reddit", "hn", "question", "converging"]
}
```

### Rich Metadata

- **Source URL** — link back to the original discussion
- **Platform** — which platform it came from
- **Engagement metrics** — upvotes, comments, points
- **Author** — who started the conversation
- **Snippet** — first 300 characters of content
- **Convergence data** — which other platforms have the same topic

---

## Use Cases

### Content Calendar Fueling

Set up a weekly job to scan your niche topics:

```
Topics: ["content marketing", "seo automation", "ai writing"]
Days back: 7
Max ideas: 30
```

Every Monday, your Idea Pool gets 30 fresh, ranked ideas based on what people actually discussed that week.

### Trend Validation

Have an article idea? Check if the social signal supports it:

```
Topics: ["headless cms comparison 2026"]
Days back: 30
```

If the topic has high engagement and convergence, write it. If not, pivot to something with more demand.

### Competitor Gap Analysis

Monitor topics your competitors haven't covered yet. Combine Social Listening with your SEO data to find the sweet spot: **high social demand + low competition**.

### Question-Driven Content

Filter ideas by `question_signal: true` to find every question your audience is asking. Each one is a potential FAQ entry, how-to guide, or comparison article.

---

## Getting Started

### Via the Dashboard

Navigate to **Ideas > Ingest > Social Listening**, enter your topics, and click Run. Results appear in your Idea Pool within seconds.

### Via the API

```bash
curl -X POST https://api.contentglows.com/api/ideas/ingest/social \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "topics": ["content marketing", "seo tools"],
    "days_back": 30,
    "max_ideas": 50
  }'
```

**Response:**

```json
{
  "source": "social_listening",
  "ingested": 34,
  "sources": {
    "reddit": 12,
    "x": 8,
    "hn": 7,
    "youtube": 7
  }
}
```

### Scheduled Automation

Set up a recurring job to run Social Listening automatically:

| Frequency | Best For |
|-----------|----------|
| Daily | News-driven niches, fast-moving topics |
| Weekly | Most content teams (recommended) |
| Bi-weekly | Evergreen content strategies |

---

## Supported Platforms

| Platform | Status | Data Source |
|----------|--------|------------|
| Reddit | Available | Exa AI |
| X / Twitter | Available | Exa AI |
| Hacker News | Available | HN Algolia API (free) |
| YouTube | Available | Exa AI |
| TikTok | Coming soon | Planned for v2 |
| Instagram | Coming soon | Planned for v2 |
| Bluesky | Coming soon | Planned for v2 |

---

## Pricing

Social Listening uses your existing Exa AI credits. Hacker News scanning is completely free (no API key required). A typical scan with 3 topics across 4 platforms costs approximately 4 Exa API calls.

---

## Next Steps

- **[Content Quality Scoring](./content-quality-scoring)** — Check readability before publishing the articles you write from Social Listening ideas
- **[Link Previews](./link-previews)** — See rich previews for the source URLs attached to each idea
- **[SEO Deployment](./seo-deployment)** — Turn your best ideas into full SEO-optimized articles

---

**Last updated:** March 30, 2026
