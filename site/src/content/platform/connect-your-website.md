---
title: "Connect Your Website"
description: "Link your GitHub repository to ContentGlows. Auto-detect your framework, configure content directories, and start analyzing in minutes."
pubDate: 2026-02-02
author: "ContentGlows Team"
tags: ["getting started", "onboarding", "github", "setup"]
featured: true
image: "/images/blog/connect-website.jpg"
---

# Connect Your Website

Link your GitHub repository to start analyzing your content structure, topical authority, and SEO opportunities. The platform auto-detects your tech stack and content directories.

**Time to complete:** 5 minutes

---

## 🚀 Quick Start

### Step 1: Start Onboarding

```bash
curl -X POST https://api.contentglows.com/api/projects/onboard \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "github_url": "https://github.com/yourusername/your-website"
  }'
```

**Response:**
```json
{
  "project_id": "proj_abc123",
  "status": "cloning",
  "message": "Project 'your-website' created. Ready for analysis."
}
```

### Step 2: Analyze Repository

```bash
curl -X POST https://api.contentglows.com/api/projects/proj_abc123/analyze \
  -H "Authorization: Bearer YOUR_API_KEY"
```

**Response:**
```json
{
  "project_id": "proj_abc123",
  "tech_stack": {
    "framework": "astro",
    "framework_version": "5.0.0",
    "package_manager": "pnpm",
    "confidence": 0.95
  },
  "content_directories": ["src/content", "src/pages"],
  "suggested_content_dir": "src/content",
  "total_content_files": 47,
  "framework_config_found": true
}
```

### Step 3: Confirm Settings

**Accept auto-detected settings:**
```bash
curl -X POST https://api.contentglows.com/api/projects/proj_abc123/confirm \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "project_id": "proj_abc123",
    "confirmed": true
  }'
```

**Or override content directory:**
```bash
curl -X POST https://api.contentglows.com/api/projects/proj_abc123/confirm \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "project_id": "proj_abc123",
    "confirmed": false,
    "content_directory_override": {
      "path": "blog",
      "file_extensions": [".md", ".mdx"]
    }
  }'
```

**Done!** Your website is now connected and ready for SEO analysis.

### Step 4: Enable Analytics (Optional)

During confirmation, you can opt in to cookie-free analytics by setting `analytics_enabled: true`. This injects a lightweight tracking script (<1KB) into your site layout, giving you pageview data directly in your dashboard.

```bash
curl -X POST https://api.contentglows.com/api/projects/proj_abc123/confirm \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "project_id": "proj_abc123",
    "confirmed": true,
    "analytics_enabled": true
  }'
```

**What you get with analytics enabled:**
- Pageviews, top pages, referrers, and daily trends per project
- SEO performance insights used by the AI agents for smarter recommendations
- Content gap analysis informed by real visitor data

**Privacy guarantees:**
- **Cookie-free** — no consent banner required
- **Under 1KB** — no impact on Core Web Vitals
- **EU-hosted** — GDPR/CCPA compliant by design
- **No IP storage** — country derived from CDN headers, then discarded

You can enable or disable analytics at any time via the project update endpoint:

```bash
curl -X PATCH https://api.contentglows.com/api/projects/proj_abc123 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"analytics_enabled": false}'
```

View your analytics in the dashboard or via the API:

```bash
curl https://api.contentglows.com/api/analytics/summary?projectId=proj_abc123 \
  -H "Authorization: Bearer YOUR_API_KEY"
```

---

## 📦 What Gets Detected

### Frameworks

| Framework | How It's Detected | Confidence |
|-----------|-------------------|------------|
| **Astro** | `astro.config.mjs`, `astro.config.js`, or `astro.config.ts` | 95% |
| **Next.js** | `next.config.js`, `next.config.mjs`, or `next.config.ts` | 95% |
| **Gatsby** | `gatsby-config.js` or `gatsby-config.ts` | 95% |
| **Nuxt** | `nuxt.config.js` or `nuxt.config.ts` | 95% |
| **Hugo** | `hugo.toml`, `hugo.yaml`, or `config.toml` with `content/` dir | 70-95% |
| **Jekyll** | `_config.yml` | 90% |

If no config file is found, the platform checks `package.json` dependencies (85% confidence).

### Package Managers

| Manager | Detection File |
|---------|----------------|
| **pnpm** | `pnpm-lock.yaml` |
| **yarn** | `yarn.lock` |
| **npm** | `package-lock.json` |
| **pip** | `requirements.txt` or `Pipfile.lock` |

### Content Directories

The platform looks for content in framework-specific locations:

| Framework | Directories Checked (in order) |
|-----------|--------------------------------|
| **Astro** | `src/content/`, `src/pages/`, `content/` |
| **Next.js** | `content/`, `posts/`, `pages/`, `app/` |
| **Gatsby** | `content/`, `src/pages/`, `blog/` |
| **Nuxt** | `content/`, `pages/` |
| **Hugo** | `content/` |
| **Jekyll** | `_posts/`, `_pages/`, `docs/` |

**Fallback directories:** `blog/`, `posts/`, `articles/`, `docs/`

---

## 🔄 Onboarding Workflow

```
┌──────────────────────────────────────────────────────────────┐
│                    ONBOARDING FLOW                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  POST /api/projects/onboard                                  │
│  ├─→ Creates project record                                  │
│  └─→ Status: CLONING                                         │
│                                                              │
│  POST /api/projects/{id}/analyze                             │
│  ├─→ Clones your GitHub repository                          │
│  ├─→ Detects framework (Astro, Next.js, etc.)               │
│  ├─→ Detects package manager (pnpm, yarn, npm)              │
│  ├─→ Finds content directories                               │
│  ├─→ Counts content files (.md, .mdx)                       │
│  └─→ Status: AWAITING_CONFIRMATION                          │
│                                                              │
│  POST /api/projects/{id}/confirm                             │
│  ├─→ Accept auto-detected settings, OR                       │
│  ├─→ Override with your preferences                          │
│  └─→ Status: COMPLETED ✅                                    │
│                                                              │
│  Ready for SEO analysis!                                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Status Values

| Status | Description |
|--------|-------------|
| `pending` | Project created, waiting to start |
| `cloning` | Repository being cloned |
| `analyzing` | Detecting framework and content |
| `awaiting_confirmation` | Detection complete, waiting for you |
| `completed` | Ready to use |
| `failed` | Error occurred (check message) |

---

## 🎛️ Configuration Options

### Content Directory Override

If auto-detection picks the wrong directory:

```json
{
  "content_directory_override": {
    "path": "articles",
    "auto_detected": false,
    "file_extensions": [".md", ".mdx", ".astro"]
  }
}
```

### SEO Config Overrides

Customize SEO validation rules:

```json
{
  "config_overrides": {
    "seo_config": {
      "min_word_count": 1500,
      "max_title_length": 60,
      "require_meta_description": true
    }
  }
}
```

### Linking Config Overrides

Customize internal linking rules:

```json
{
  "config_overrides": {
    "linking_config": {
      "min_internal_links": 3,
      "max_external_links": 10,
      "require_pillar_links": true
    }
  }
}
```

---

## 📋 API Reference

### Start Onboarding

```http
POST /api/projects/onboard
```

**Request Body:**
```json
{
  "github_url": "https://github.com/user/repo",
  "name": "My Website",           // Optional, defaults to repo name
  "description": "Marketing site" // Optional
}
```

**Response:**
```json
{
  "project_id": "proj_abc123",
  "status": "cloning",
  "message": "Project created"
}
```

### Analyze Project

```http
POST /api/projects/{project_id}/analyze
```

**Query Parameters:**
- `force_reclone` (boolean) - Force fresh clone, default: false

**Response:**
```json
{
  "project_id": "proj_abc123",
  "tech_stack": {
    "framework": "astro",
    "framework_version": "5.0.0",
    "package_manager": "pnpm",
    "confidence": 0.95
  },
  "content_directories": ["src/content", "src/pages"],
  "suggested_content_dir": "src/content",
  "total_content_files": 47,
  "framework_config_found": true
}
```

### Confirm Settings

```http
POST /api/projects/{project_id}/confirm
```

**Request Body:**
```json
{
  "project_id": "proj_abc123",
  "confirmed": true,
  "content_directory_override": null,  // Optional
  "config_overrides": null             // Optional
}
```

### List Projects

```http
GET /api/projects
```

**Response:**
```json
{
  "projects": [...],
  "total": 3,
  "default_project_id": "proj_abc123"
}
```

### Get Project

```http
GET /api/projects/{project_id}
```

### Update Project

```http
PATCH /api/projects/{project_id}
```

**Request Body:**
```json
{
  "name": "New Name",
  "description": "New description",
  "content_directory": {...},
  "config_overrides": {...}
}
```

### Delete Project

```http
DELETE /api/projects/{project_id}
```

### Set Default Project

```http
POST /api/projects/{project_id}/set-default
```

### Refresh Analysis

Re-analyze after repository changes:

```http
POST /api/projects/{project_id}/refresh
```

---

## 🔌 Code Examples

### Python

```python
import httpx

API_BASE = "https://api.contentglows.com"
API_KEY = "your_api_key"

headers = {"Authorization": f"Bearer {API_KEY}"}

# 1. Start onboarding
response = httpx.post(
    f"{API_BASE}/api/projects/onboard",
    json={"github_url": "https://github.com/you/your-site"},
    headers=headers
)
project_id = response.json()["project_id"]
print(f"Project ID: {project_id}")

# 2. Analyze
response = httpx.post(
    f"{API_BASE}/api/projects/{project_id}/analyze",
    headers=headers
)
detection = response.json()
print(f"Framework: {detection['tech_stack']['framework']}")
print(f"Content dir: {detection['suggested_content_dir']}")

# 3. Confirm
response = httpx.post(
    f"{API_BASE}/api/projects/{project_id}/confirm",
    json={"project_id": project_id, "confirmed": True},
    headers=headers
)
print("Project connected!")
```

### JavaScript/TypeScript

```typescript
const API_BASE = "https://api.contentglows.com";
const API_KEY = "your_api_key";

async function connectWebsite(githubUrl: string) {
  // 1. Start onboarding
  const onboardRes = await fetch(`${API_BASE}/api/projects/onboard`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${API_KEY}`
    },
    body: JSON.stringify({ github_url: githubUrl })
  });
  const { project_id } = await onboardRes.json();

  // 2. Analyze
  const analyzeRes = await fetch(
    `${API_BASE}/api/projects/${project_id}/analyze`,
    {
      method: "POST",
      headers: { "Authorization": `Bearer ${API_KEY}` }
    }
  );
  const detection = await analyzeRes.json();
  console.log(`Framework: ${detection.tech_stack.framework}`);

  // 3. Confirm
  await fetch(`${API_BASE}/api/projects/${project_id}/confirm`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${API_KEY}`
    },
    body: JSON.stringify({ project_id, confirmed: true })
  });

  return project_id;
}
```

### cURL Script

```bash
#!/bin/bash
# connect-website.sh

API_BASE="https://api.contentglows.com"
API_KEY="your_api_key"
GITHUB_URL="https://github.com/you/your-site"

# 1. Start onboarding
PROJECT_ID=$(curl -s -X POST "$API_BASE/api/projects/onboard" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"github_url\": \"$GITHUB_URL\"}" \
  | jq -r '.project_id')

echo "Project ID: $PROJECT_ID"

# 2. Analyze
curl -s -X POST "$API_BASE/api/projects/$PROJECT_ID/analyze" \
  -H "Authorization: Bearer $API_KEY" \
  | jq '.tech_stack'

# 3. Confirm
curl -s -X POST "$API_BASE/api/projects/$PROJECT_ID/confirm" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"project_id\": \"$PROJECT_ID\", \"confirmed\": true}"

echo "Done! Project connected."
```

---

## 🔄 Keeping Your Project Updated

### Refresh After Changes

When your repository changes (new content, structure updates):

```bash
curl -X POST https://api.contentglows.com/api/projects/proj_abc123/refresh \
  -H "Authorization: Bearer YOUR_API_KEY"
```

This will:
- Pull latest changes from GitHub
- Re-detect framework (catches version updates)
- Update content file counts
- **Preserve** your custom config overrides

### CI/CD Integration

Add to your deployment workflow:

```yaml
# .github/workflows/deploy.yml
- name: Refresh SEO Analysis
  run: |
    curl -X POST https://api.contentglows.com/api/projects/$PROJECT_ID/refresh \
      -H "Authorization: Bearer ${{ secrets.SEO_API_KEY }}"
```

---

## ❓ Troubleshooting

### "Project not found"

- Verify the project ID is correct
- Check if the project was created successfully

### Analysis fails

- Ensure your GitHub repository is public (or you've granted access)
- Verify the repository URL is correct
- Check if the repository exists

### Wrong framework detected

Detection priority:
1. Config file (`astro.config.mjs`, `next.config.js`, etc.)
2. `package.json` dependencies
3. Directory structure hints

**Override manually** in the confirm step if needed.

### No content directory found

- Use `content_directory_override` to specify manually
- Check your content is in markdown files (`.md`, `.mdx`)
- Verify the directory exists in your repository

### Low confidence score

Confidence below 70% means:
- No framework config file found
- Detection based on package.json or directory structure
- Consider adding a config file or overriding manually

---

## 🎯 Next Steps

Now that your website is connected:

1. **[Run SEO Analysis](/platform/api-reference#analyze)** - Get your topical authority score
2. **[View Recommendations](/platform/understanding-analysis)** - See prioritized improvements
3. **[Set Up Monitoring](/platform/api-reference#webhooks)** - Get alerts on changes

---

**Need help?** Contact support@contentglows.com or [join our Discord](#discord).
