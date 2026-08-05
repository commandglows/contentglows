---
title: "Link Previews"
description: "See what your links look like before you share them. Instant OpenGraph extraction for your content calendar — titles, descriptions, images, and favicons from any URL."
pubDate: 2026-03-30
author: "ContentGlows Team"
tags: ["link preview", "opengraph", "content calendar", "social sharing", "metadata"]
featured: false
image: "/images/blog/link-previews.jpg"
---

# Link Previews

See a rich preview of any URL directly in your content calendar. Link Previews extracts OpenGraph metadata — title, description, image, favicon — so you know exactly what a link looks like before you reference it in your content.

---

## Why Link Previews?

### The Problem

Your content calendar is full of URLs: competitor articles, reference sources, inspiration links. But a bare URL tells you nothing:

```
https://example.com/blog/the-complete-guide-to-ai-seo-2026
```

Is it a 5,000-word guide or a 300-word listicle? Does it have a hero image? What's the actual title? You have to click every link to find out.

### The Solution

Link Previews fetches the metadata instantly and shows you a rich card:

```
┌──────────────────────────────────────────────┐
│ 🌐 Example Blog                              │
│                                              │
│ The Complete Guide to AI SEO in 2026         │
│ Everything you need to know about using      │
│ artificial intelligence for search engine...  │
│                                              │
│ 🖼  [hero-image.jpg]                         │
└──────────────────────────────────────────────┘
```

One glance. No clicks. No context switching.

---

## What It Extracts

| Field | Source | Fallback |
|-------|--------|----------|
| **Title** | `og:title` | `<title>` tag |
| **Description** | `og:description` | `<meta name="description">` |
| **Image** | `og:image` | None |
| **Site Name** | `og:site_name` | None |
| **Type** | `og:type` (article, website, etc.) | None |
| **Favicon** | `<link rel="icon">` | None |

The system follows a smart fallback chain: OpenGraph tags first, then standard HTML meta tags. Relative image URLs are automatically resolved to absolute paths.

---

## How It Works

### Simple API Call

```bash
curl "https://api.contentglows.com/api/preview?url=https://example.com/blog/post" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Response

```json
{
  "url": "https://example.com/blog/post",
  "title": "The Complete Guide to AI SEO in 2026",
  "description": "Everything you need to know about using AI for search engine optimization.",
  "image": "https://example.com/images/hero-ai-seo.jpg",
  "site_name": "Example Blog",
  "og_type": "article",
  "favicon": "https://example.com/favicon.ico"
}
```

---

## Use Cases

### Content Calendar

Every URL in your content calendar shows a rich preview card. Quickly scan your planned content, references, and competitor articles without opening a single tab.

### Competitor Research

When monitoring competitor articles, see their titles, descriptions, and hero images at a glance. Identify patterns in how they structure their metadata.

### Idea Pool Enrichment

URLs added to your Idea Pool automatically get enriched with preview data. A link from a newsletter or social media post becomes a fully contextualized idea with title, description, and visual.

### Social Sharing Validation

Before sharing a link on social media, check what the preview card will look like. Catch missing images, truncated descriptions, or wrong titles before they go live.

---

## Technical Details

- **Zero external dependencies** — built with httpx and BeautifulSoup, both already in the stack
- **Fast** — 8-second timeout with redirect following
- **Resilient** — graceful fallbacks when OG tags are missing
- **Relative URL resolution** — images and favicons with relative paths are resolved correctly

---

## Next Steps

- **[Social Listening](./social-listening)** — Feed your calendar with trending topic ideas (previews enrich them automatically)
- **[Content Quality Scoring](./content-quality-scoring)** — Score your articles before publishing
- **[Connect Your Website](./connect-your-website)** — Set up your project to start using all platform features

---

**Last updated:** March 30, 2026
