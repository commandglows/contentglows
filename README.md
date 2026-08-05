# ContentGlows

Canonical monorepo for the full ContentGlows platform.

## Repository Layout

- `site` - Astro marketing site
- `app` - Flutter application, including the web build deployed on Vercel
- `lab` - FastAPI backend and internal tooling
- `worker` - Remotion render worker

## Setup

Start with [shipglows_data/technical/SETUP.md](shipglows_data/technical/SETUP.md) after cloning the repository. It lists the required local tools, Flox commands, app/site/backend checks, and Turso CLI authentication flow.

## Deployment Model

- GitHub source of truth: `commandglows/contentglows`
- Vercel project `ContentGlows` uses `site` as its Root Directory
- Vercel project `ContentGlows-App` uses `app` as its Root Directory
- `lab` is maintained in this monorepo but deployed outside Vercel

## Working Rule

All ContentGlows surfaces now live in this single repository. Do not use the archived legacy repositories as active sources of truth.
