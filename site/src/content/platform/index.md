---
title: "Platform Documentation"
description: "Everything you need to get started with ContentGlows. Connect your website, run SEO analysis, and automate your content strategy."
pubDate: 2026-02-02
author: "ContentGlows Team"
tags: ["platform", "documentation", "getting started", "api"]
featured: true
image: "/images/blog/platform-docs.jpg"
---

# Platform Documentation

Welcome to the ContentGlows platform. This documentation will help you connect your website, understand the analysis tools, and automate your SEO workflow.

---

## 🚀 Quick Start

### ⚡ Resilience

ContentGlows is usable during short backend disruptions. If API connectivity is interrupted, the app continues to show available cached data and stores supported edits in a local queue.
When the API recovers, queued actions are replayed automatically.

### 1. Connect Your Website (5 minutes)

Link your GitHub repository to start analyzing your content:

```bash
# Start onboarding
curl -X POST https://api.contentglows.com/api/projects/onboard \
  -H "Content-Type: application/json" \
  -d '{"github_url": "https://github.com/you/your-site"}'
```

[Full Guide: Connect Your Website →](./connect-your-website)

### 2. Run Your First Analysis (2 minutes)

Once connected, analyze your topical mesh:

```bash
curl -X POST https://api.contentglows.com/api/mesh/analyze \
  -H "Content-Type: application/json" \
  -d '{"repo_url": "https://github.com/you/your-site"}'
```

### 3. Get Recommendations

The platform returns:
- **Authority Score** (0-100) - How strong is your topical coverage
- **Content Gaps** - Topics your competitors cover that you don't
- **Linking Recommendations** - Internal links to add
- **Quick Wins** - Immediate actions to improve rankings

---

## 📚 Documentation

### Getting Started

| Guide | Description | Time |
|-------|-------------|------|
| [Connect Your Website](./connect-your-website) | Link your GitHub repo and configure settings | 5 min |
| [SEO Deployment](./seo-deployment) | Run SEO pipelines from the dashboard | 10 min |
| [Image Optimization](./image-optimization) | Generate and optimize images for your content | 5 min |
| [Social Listening](./social-listening) | Discover trending topics from Reddit, X, HN, YouTube | 5 min |
| [Content Quality Scoring](./content-quality-scoring) | Readability metrics and quality grades | 5 min |
| [Link Previews](./link-previews) | OpenGraph extraction for your content calendar | 2 min |
| [Understanding Your Analysis](./understanding-analysis) | What the scores and metrics mean | 10 min |
| [API Reference](./api-reference) | Complete API endpoint documentation | Reference |

### Core Features

| Feature | What It Does |
|---------|--------------|
| **Project Onboarding** | Auto-detects your framework, package manager, and content structure |
| **Topical Mesh Analysis** | Maps your internal linking and calculates authority scores |
| **Content Gap Analysis** | Compares your content against competitors |
| **SEO Recommendations** | Prioritized actions to improve rankings |
| **SEO Deployment** | Run content pipelines, batch process topics, schedule automation |
| **Image Optimization** | Generate hero images, social cards, and responsive variants via global CDN |
| **Cookie-Free Analytics** | Built-in pageview tracking — no cookies, no consent banner, EU-hosted, under 1KB script |
| **Social Listening** | Scan Reddit, X, HN, and YouTube for trending topics — auto-ranks by engagement and cross-platform convergence |
| **Content Quality Scoring** | 6 readability metrics (Flesch, Gunning Fog, SMOG...) with letter grades — catches hard-to-read content before publication |
| **Link Previews** | Instant OpenGraph extraction — see titles, descriptions, and images for any URL in your calendar |

---

## 🔧 Supported Frameworks

The platform auto-detects and optimizes for:

| Framework | Detection | Content Conventions |
|-----------|-----------|---------------------|
| **Astro** | `astro.config.mjs` | `src/content/`, `src/pages/` |
| **Next.js** | `next.config.js` | `content/`, `posts/`, `app/` |
| **Gatsby** | `gatsby-config.js` | `content/`, `src/pages/` |
| **Nuxt** | `nuxt.config.js` | `content/`, `pages/` |
| **Hugo** | `hugo.toml` | `content/` |
| **Jekyll** | `_config.yml` | `_posts/`, `_pages/` |

### Package Managers

Automatically detected from lock files:
- **pnpm** → `pnpm-lock.yaml`
- **yarn** → `yarn.lock`
- **npm** → `package-lock.json`

---

## 🎯 Platform Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                   CONTENTGLOWS WORKFLOW                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. CONNECT                                                 │
│     └─→ Add your GitHub repo URL                           │
│     └─→ Platform clones and analyzes structure             │
│     └─→ Auto-detects framework & content directories       │
│                                                             │
│  2. ANALYZE                                                 │
│     └─→ Maps all your content pages                        │
│     └─→ Calculates topical authority (0-100)               │
│     └─→ Identifies orphan pages and weak links             │
│                                                             │
│  3. CREATE & OPTIMIZE                                       │
│     └─→ Generate SEO-optimized content                     │
│     └─→ Create professional images automatically           │
│     └─→ Deliver via global CDN for speed                   │
│                                                             │
│  4. MONITOR                                                 │
│     └─→ Track authority score over time                    │
│     └─→ Get alerts on ranking changes                      │
│     └─→ Automated content suggestions                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 What You Get

### Topical Authority Score

Your overall SEO strength on a topic:

| Grade | Score | Meaning |
|-------|-------|---------|
| **A** | 85-100 | Excellent - Industry leading coverage |
| **B** | 70-84 | Good - Competitive position |
| **C** | 55-69 | Fair - Room for improvement |
| **D** | 40-54 | Poor - Significant gaps |
| **F** | 0-39 | Very Poor - Major work needed |

### Mesh Density

How well your pages link to each other:

```
Density = Actual Internal Links / Possible Links

0.50+ = Strong mesh (excellent)
0.40-0.49 = Good mesh
0.30-0.39 = Adequate mesh
<0.30 = Weak mesh (needs work)
```

### Actionable Recommendations

Every analysis includes:
- **Quick Wins** - Changes you can make today
- **Content Gaps** - Topics to write about
- **Link Suggestions** - Specific pages to connect
- **Priority Ranking** - What to do first

---

## 🔌 Integration Options

### REST API

Full programmatic access:

```python
import httpx

# Analyze your site
response = httpx.post(
    "https://api.contentglows.com/api/mesh/analyze",
    json={"repo_url": "https://github.com/you/your-site"},
    headers={"Authorization": "Bearer YOUR_API_KEY"}
)

analysis = response.json()
print(f"Authority Score: {analysis['authority_score']}/100")
```

### Dashboard

Visual interface for:
- Project management and robot monitoring
- [SEO Deployment](./seo-deployment) - Run pipelines, batch processing, scheduling
- Analysis history and log viewing
- Recommendation tracking

### CI/CD Integration

Add to your deployment pipeline:

```yaml
# .github/workflows/seo-check.yml
- name: SEO Analysis
  run: |
    curl -X POST https://api.contentglows.com/api/mesh/analyze \
      -H "Authorization: Bearer ${{ secrets.SEO_API_KEY }}" \
      -d '{"repo_url": "${{ github.repository }}"}'
```

---

## 💬 Need Help?

### Resources

- [API Reference](./api-reference) - Complete endpoint documentation
- [FAQ](#faq) - Common questions answered
- [Changelog](#changelog) - What's new

### Support

- **Email:** support@contentglows.com
- **Discord:** [Join our community](#discord)
- **GitHub:** [Report issues](https://github.com/commandglows/contentglows/issues)

---

**Last updated:** March 30, 2026
