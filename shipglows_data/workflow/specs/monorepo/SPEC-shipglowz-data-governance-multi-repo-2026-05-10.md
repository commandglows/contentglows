---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: contentglows
created: "2026-05-10"
updated: "2026-05-10"
status: ready
source_skill: sf-docs
scope: update
owner: unknown
confidence: high
risk_level: high
security_impact: none
docs_impact: yes
user_story: "En tant qu'équipe ShipGlowz, nous voulons un emplacement canonique unique `shipglows_data/**` pour la gouvernance docs sur les 3 repos afin d'éviter drift, doublons et incohérences de migration."
linked_systems:
  - app
  - site
  - lab
depends_on: []
supersedes: []
evidence:
  - "Analyses agents GPT-5.3 Codex Spark (2026-05-10)"
next_step: "/sf-start shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md"
---

# Spec: Alignement de gouvernance documentaire vers `shipglows_data` (3 repos)

## Objectif

Aligner `app`, `site` et `lab` sur la doctrine ShipGlowz qui impose un emplacement canonique dans `shipglows_data/**` pour les artefacts de gouvernance, sans duplication de source de vérité.

## Scope In

- Migration des artefacts canonisés: business, branding, product, gtm, architecture, context, guidelines, content-map.
- Migration de la couche technique `docs/technical/**` vers `shipglows_data/technical/**`.
- Vérification `AGENT.md` racine + compatibilité `AGENTS.md` symlink.
- Mise à jour des liens et `depends_on` cassés par le changement de chemins.

## Scope Out

- Réécriture éditoriale du contenu métier.
- Migration des trackers opérationnels (`TASKS.md`, `AUDIT_LOG.md`, `shipglows_data/workflow/qa/TEST_LOG.md`, `BUGS.md`).
- Refonte des specs fonctionnelles hors impact de chemins.

## Canonical Mapping Contract

- `BUSINESS.md` -> `shipglows_data/business/business.md`
- `BRANDING.md` -> `shipglows_data/business/branding.md`
- `PRODUCT.md` -> `shipglows_data/business/product.md`
- `GTM.md` -> `shipglows_data/business/gtm.md`
- `ARCHITECTURE.md` -> `shipglows_data/technical/architecture.md`
- `CONTEXT.md` -> `shipglows_data/technical/context.md`
- `GUIDELINES.md` -> `shipglows_data/technical/guidelines.md`
- `CONTENT_MAP.md` -> `shipglows_data/editorial/content-map.md`
- `docs/technical/*.md` -> `shipglows_data/technical/*.md`
- `AGENT.md` reste en racine; `AGENTS.md` doit être un symlink vers `AGENT.md`

## État initial par repo (résumé)

### `app`

- Fichiers de gouvernance racine présents.
- `docs/technical` présent; `docs/editorial` absent.
- `AGENTS.md` absent.

### `site`

- Fichiers de gouvernance racine présents.
- `docs/technical` et `docs/editorial` présents.
- `AGENTS.md` absent.

### `lab`

- Fichiers de gouvernance racine présents.
- `docs/technical` présent; beaucoup de `.md` legacy hors frontmatter.
- `AGENTS.md` déjà en symlink.

## Risques principaux

1. Double source de vérité (racine + `shipglows_data` en parallèle).
2. Liens internes cassés (`README`, `specs`, `depends_on`, guides).
3. Incohérences de frontmatter pendant la migration.
4. Pollution du scope (migration accidentelle de trackers non ciblés).
5. Compatibilité agent incomplète si `AGENTS.md` non aligné.

## Plan d’exécution

1. Geler les changements docs non liés sur les 3 repos pendant la migration.
2. Créer l’arborescence cible `shipglows_data/business`, `shipglows_data/technical`, `shipglows_data/editorial`.
3. Migrer les artefacts canoniques depuis la racine vers `shipglows_data/**` (repo par repo).
4. Migrer `docs/technical/**` vers `shipglows_data/technical/**` (repo par repo).
5. Appliquer la règle `AGENT.md` racine + `AGENTS.md` symlink.
6. Mettre à jour toutes les références legacy vers les chemins canoniques.
7. Vérifier et corriger `depends_on`, `supersedes`, `evidence`, `next_step`.
8. Exécuter le linter de métadonnées sur les artefacts migrés.
9. Vérifier qu’aucun tracker exclu n’a été déplacé.
10. Produire un rapport de clôture par repo (`done` / `blocked` + écarts restants).

## Validation Commands

```bash
SHIPGLOWZ_ROOT="${SHIPGLOWZ_ROOT:-$HOME/shipglowz}"
"$SHIPGLOWZ_ROOT/tools/shipglowz_metadata_lint.py"
```

```bash
rg -n "BUSINESS\.md|PRODUCT\.md|ARCHITECTURE\.md|CONTEXT\.md|CONTENT_MAP\.md|docs/technical/" README.md specs docs shipglows_data 2>/dev/null
```

```bash
test ! -e AGENTS.md || { test -L AGENTS.md && test "$(readlink AGENTS.md)" = "AGENT.md"; }
```

```bash
find shipglows_data -type f -name "*.md" | sort
```

## Acceptance Criteria

- Chaque repo a ses artefacts canoniques dans `shipglows_data/**`.
- Aucun artefact canonique actif ne reste en double (hors compatibilité explicitement décidée).
- `AGENT.md` est canonique en racine et `AGENTS.md` est conforme (symlink ou absent si non requis).
- Linter métadonnées sans erreur bloquante.
- Liens docs/spécifications mis à jour vers les nouveaux chemins.

## Rollback

- Si un repo casse en cours de migration, revert du repo concerné uniquement.
- Bloquer la propagation aux autres repos jusqu’à correction de la cause racine.
- Rejouer la migration uniquement après validation des commandes ci-dessus sur un repo pilote.

## Minimal Behavior Contract

- Trigger: migration de gouvernance demandée sur `app`, `site`, `lab`.
- Input: artefacts legacy en racine et sous `docs/technical/**`.
- Output: artefacts canoniques déplacés vers `shipglows_data/**`, références mises à jour, compatibilité `AGENT.md`/`AGENTS.md` préservée.
- Failure behavior: si un repo ne peut pas être migré proprement, il est marqué `blocked` sans contaminer les deux autres.
- Easy edge case to miss: oubli de mise à jour des chemins dans `depends_on` et docs de gouvernance.

## Success Behavior

- Chaque repo possède son corpus canonique sous `shipglows_data/business`, `shipglows_data/technical`, `shipglows_data/editorial`.
- Les références internes critiques ne pointent plus vers les chemins legacy (hors exceptions de compatibilité explicitement conservées).
- Les validations de base de cohérence passent.

## Error Behavior

- En cas de lien cassé, frontmatter incohérent, ou conflit de chemin: stop du repo concerné, rapport `blocked`, pas de propagation implicite.
- État interdit: doubles sources actives (legacy + canonique) pour un même artefact sans justification de compatibilité.

## Invariants And Non-Goals

- Invariants:
  - `AGENT.md` reste canonique en racine.
  - `AGENTS.md` est uniquement un symlink de compatibilité vers `AGENT.md` (ou absent si non utilisé).
  - Les trackers opérationnels restent hors migration.
- Non-goals:
  - Réécriture éditoriale métier.
  - Refonte des specs fonctionnelles.

## Current Chantier Flow

- sf-spec: done
- sf-ready: done
- sf-start: done
- sf-verify: done
- sf-end: done
- sf-ship: done

## Skill Run History

| Date UTC | Skill | Model | Action | Result | Next step |
|----------|-------|-------|--------|--------|-----------|
| 2026-05-10 | sf-start | gpt-5.3-codex | readiness gate check on provided spec | rerouted (spec status is draft, not ready) | /sf-ready shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md |
| 2026-05-10 | sf-build | gpt-5.3-codex | spec hardening + readiness completion for lifecycle execution | implemented | /sf-start shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md |
| 2026-05-10 | sf-build | gpt-5.3-codex | migration exécution multi-repos + validation metadata/références | partial (implementation and verify done, close/ship not executed) | /sf-end shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md |
| 2026-05-10 | sf-end | gpt-5.3-codex | clôture chantier et vérification finale de cohérence | implemented | /sf-ship shipglows_data/workflow/specs/monorepo/SPEC-shipglowz-data-governance-multi-repo-2026-05-10.md |
| 2026-05-10 | sf-ship | gpt-5.3-codex | staging scope, commit et push sur main | implemented | none |
| 2026-05-10 | sf-docs | gpt-5 | audit des Markdown racine, symlinks et doublons après migration `shipglows_data` | checked (no exact duplicates; residual legacy references and metadata lint gaps found) | corriger les références legacy et frontmatter des 3 artefacts signalés |
| 2026-05-10 | sf-docs | gpt-5 | correction des références legacy et frontmatter signalés | implemented (metadata lint passed on 80 files) | none |
