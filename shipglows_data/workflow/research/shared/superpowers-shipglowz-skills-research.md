---
artifact: research
project: "contentglowz / ShipGlowz"
created: "2026-05-17"
updated: "2026-05-17"
status: reviewed
source_skill: sf-research
scope: "Superpowers Claude plugin and implications for improving ShipGlowz skills"
confidence: high
risk_level: medium
security_impact: yes
docs_impact: yes
source_count: 13
evidence:
  - "https://claude.com/plugins/superpowers"
  - "https://github.com/obra/superpowers"
  - "https://github.com/obra/superpowers/tree/main/skills"
  - "https://raw.githubusercontent.com/obra/superpowers/main/README.md"
  - "https://raw.githubusercontent.com/obra/superpowers/main/skills/systematic-debugging/SKILL.md"
  - "https://raw.githubusercontent.com/obra/superpowers/main/skills/test-driven-development/SKILL.md"
  - "https://raw.githubusercontent.com/obra/superpowers/main/skills/writing-skills/SKILL.md"
  - "https://code.claude.com/docs/en/skills"
  - "https://agentskills.io/specification"
  - "https://arxiv.org/abs/2602.08004"
  - "https://arxiv.org/abs/2605.11418"
  - "https://arxiv.org/abs/2601.10338"
  - "https://arxiv.org/abs/2604.14228"
next_step: "/sf-spec Ameliorer les skills ShipGlowz avec les patterns Superpowers: TDD de skills, debugging systematique, revue en deux temps, worktrees optionnels, et gates supply-chain"
---

# Research: Superpowers et amelioration du set de skills ShipGlowz

> Generated 2026-05-17 - Sources: 13

## Executive Summary

Superpowers est pertinent pour ShipGlowz, mais comme source de patterns, pas comme dependance a installer telle quelle. Ses points forts sont la discipline d'execution: brainstorming avant code, plan tres actionnable, TDD strict, debugging par cause racine, sous-agents avec revue, verification avant cloture, et support worktree. ShipGlowz couvre deja une grande partie du lifecycle, mais peut gagner en fiabilite avec trois ajouts: un protocole TDD/RED-GREEN adapte aux skills, une doctrine de debugging plus stricte pour `sf-fix`/`sf-bug`, et une revue en deux temps pour les executions deleguees.

## Background

La page officielle Superpowers presente le plugin comme un framework de skills pour Claude Code couvrant brainstorming, developpement par sous-agents, revue de code, debugging, TDD et creation de skills. Le README du depot `obra/superpowers` decrit un workflow complet: clarification de besoin, design valide par l'utilisateur, plan d'implementation, execution par sous-agents, TDD, revue, puis finition de branche.

ShipGlowz a deja une architecture proche: specs, readiness, start, verify, end, ship, delegation, tracking de chantier, reporting, audit, debug, test, prod, docs et skill maintenance. L'audit local du 2026-05-17 mesure 61 skills, 0 violation, 0 warning, 0 risk separe, et un budget de decouverte estime a 6805/8000. La contrainte n'est donc pas "ajouter beaucoup de skills"; elle est d'ameliorer les gates sans alourdir l'index.

## Current State (2026)

### Superpowers

Le depot `obra/superpowers` expose 14 skills principaux dans `skills/`: `brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-plans`, et `writing-skills`.

Le README met l'accent sur des workflows obligatoires, pas des conseils optionnels. Les skills les plus differenciants pour ShipGlowz sont:

- `test-driven-development`: impose un test qui echoue avant le code, puis code minimal et refactor.
- `systematic-debugging`: impose la recherche de cause racine avant toute correction.
- `writing-skills`: applique une logique TDD a la documentation de skills via scenarios de pression.
- `requesting-code-review` et `subagent-driven-development`: structurent la revue entre taches et l'execution deleguee.
- `using-git-worktrees`: isole les branches de travail avant des changements longs ou paralleles.

### ShipGlowz

ShipGlowz a deja des equivalents partiels:

- `sf-spec`, `sf-ready`, `sf-start`, `sf-verify`, `sf-end`, `sf-ship` couvrent le lifecycle spec-first.
- `sf-fix`, `sf-bug`, `sf-check`, `sf-test`, `sf-prod`, `sf-browser`, `sf-auth-debug` couvrent les bugs, checks, QA, prod et preuves.
- `sf-skill-build`, `sf-skills-refresh`, `skill-instruction-layering.md`, `skill-context-budget.md` couvrent deja la maintenance de skills.
- `master-delegation-semantics.md` couvre delegation sequentielle et parallele avec ownership et stop conditions.

L'ecart principal est moins structurel que comportemental: Superpowers formule des "iron laws" tres contraignantes. ShipGlowz est plus riche en gouvernance, mais parfois moins mordant sur les preuves avant correction, les tests avant implementation et la revue post-tache.

## Options / Approaches

### Option 1: Installer Superpowers tel quel

**Pros**:
- Acces immediat a une methodologie mature et populaire.
- Bonnes pratiques deja packagees pour TDD, debugging, plan, revue et worktrees.
- Compatible avec Claude Code et reference aussi Codex dans le README.

**Cons**:
- Risque de conflit avec les conventions ShipGlowz: chantiers, specs, reporting, model routing, topology, tracking.
- Ajout d'un deuxieme routeur/lifecycle concurrent.
- Surface supply-chain accrue. Les etudes 2026 sur les skills montrent que les fichiers de skill ne sont pas de simples docs: ils influencent selection, gouvernance et permissions.

**Best for**: experimentation personnelle hors runtime ShipGlowz, pas pour le corpus ShipGlowz canonique.

### Option 2: Copier des skills Superpowers dans ShipGlowz

**Pros**:
- Rapide pour reprendre le wording fort de TDD/debug/revue.
- Permet de tester des protocols en conditions reelles.

**Cons**:
- Risque de duplication doctrinale et d'incoherence avec `skill-instruction-layering.md`.
- Maintenance plus couteuse.
- Import direct de texte externe sans adaptation aux contrats ShipGlowz.

**Best for**: spike local court, puis suppression ou integration propre.

### Option 3: Adapter les patterns dans les references ShipGlowz

**Pros**:
- Preserve le lifecycle ShipGlowz.
- Ameliore les gates qui comptent vraiment: TDD, cause racine, skill testing, revue en deux temps.
- Respecte le budget de decouverte: pas besoin d'ajouter beaucoup de skills.
- Peut etre spec-first et verifie avec les outils existants.

**Cons**:
- Demande un chantier multi-fichiers.
- Necessite de choisir ou mettre les gates pour eviter repetition et dilution.

**Best for**: recommandation principale.

## Best Practices Retenues

1. Ajouter un "TDD gate" explicite dans `sf-start`, `sf-fix`, `sf-bug` et/ou une reference partagee: pour tout changement comportemental, il faut soit un test qui echoue d'abord, soit une exception documentee.
2. Renforcer `sf-fix` avec un protocole cause-racine avant patch: reproduction, analyse changements recents, comparaison avec code qui marche, hypothese unique, changement minimal, verification.
3. Etendre `sf-skill-build` avec "TDD de skills": definir des scenarios de pression, verifier que le comportement actuel echoue ou est ambigu, modifier la skill, puis re-verifier.
4. Formaliser une revue en deux temps dans la delegation ShipGlowz: conformite au plan/spec, puis qualite code/risque/tests.
5. Ajouter un mode worktree optionnel pour chantiers longs, multi-agent ou a dirty worktree risque, sans le rendre obligatoire pour les petits fixes.
6. Garder les descriptions ShipGlowz compactes. Les docs Claude Code disent que les descriptions servent a la selection et que le corps complet reste charge apres invocation; la spec Agent Skills recommande aussi progressive disclosure et `SKILL.md` sous 500 lignes.
7. Ne pas installer de skills tiers sans vetting. Les papiers arXiv 2026 signalent des risques de selection biaisee, gouvernance evasive, exfiltration, privilege escalation et vulnerabilites plus frequentes quand des scripts executables sont bundles.

## Recommendations

Recommandation: ouvrir un chantier ShipGlowz dedie, pas installer Superpowers directement.

Scope propose:

1. `skills/references/development-discipline.md` ou equivalent: TDD gate, root-cause gate, verification-before-completion gate.
2. `skills/references/master-delegation-semantics.md`: ajouter la revue en deux temps comme exigence pour missions de code significatives.
3. `skills/sf-fix/SKILL.md` et `skills/sf-bug/SKILL.md`: imposer cause racine avant patch, avec compteur de tentatives et stop architectural apres echecs repetes.
4. `skills/sf-skill-build/SKILL.md`: ajouter des tests de skills par scenarios de pression avant modification de skill.
5. `skills/sf-start/SKILL.md` ou reference d'execution: exiger test-first quand applicable, exception documentee quand non applicable.
6. `sf-verify` ou `sf-check`: verifier que les claims de completion mentionnent les commandes/proofs reellement executes.

Priorite:

- P1: `sf-fix`/`sf-bug` cause-racine et TDD bugfix. C'est le gain de qualite le plus direct.
- P2: `sf-skill-build` avec tests de skills. C'est important pour eviter des regressions de comportement dans le corpus.
- P2: revue en deux temps dans delegation. Utile pour les chantiers multi-etapes.
- P3: worktrees optionnels. Utile mais pas aussi central, car Codex et ShipGlowz ont deja des contraintes de dirty worktree et ownership.

## Risks

- Trop de dogmatisme peut ralentir les petits changements. La solution est une exception explicite et courte, pas l'absence de gate.
- Ajouter des references trop longues peut affaiblir la selection. L'audit actuel est sain; il faut privilegier references partagees compactes.
- Installer Superpowers comme plugin parallele peut creer des instructions concurrentes avec ShipGlowz, surtout sur delegation, plan, verification et ship.
- Les skills tiers avec scripts ou permissions doivent etre traites comme une supply-chain executable.

## Sources

- [Superpowers - Claude Plugin](https://claude.com/plugins/superpowers) - page officielle Anthropic du plugin, usages et positionnement.
- [obra/superpowers GitHub](https://github.com/obra/superpowers) - depot principal, workflow, compatibilite multi-harness et philosophie.
- [Superpowers skills tree](https://github.com/obra/superpowers/tree/main/skills) - inventaire des skills disponibles.
- [Superpowers README raw](https://raw.githubusercontent.com/obra/superpowers/main/README.md) - workflow de base, liste de skills et modes d'installation.
- [systematic-debugging](https://raw.githubusercontent.com/obra/superpowers/main/skills/systematic-debugging/SKILL.md) - protocole cause-racine en quatre phases.
- [test-driven-development](https://raw.githubusercontent.com/obra/superpowers/main/skills/test-driven-development/SKILL.md) - cycle red-green-refactor strict.
- [writing-skills](https://raw.githubusercontent.com/obra/superpowers/main/skills/writing-skills/SKILL.md) - adaptation de TDD a la creation/modification de skills.
- [Claude Code skills docs](https://code.claude.com/docs/en/skills) - modele officiel des skills, invocation, frontmatter, progressive disclosure.
- [Agent Skills Specification](https://agentskills.io/specification) - format standard, contraintes de frontmatter, references et validation.
- [Agent Skills: A Data-Driven Analysis](https://arxiv.org/abs/2602.08004) - analyse 2026 de 40k+ skills, adoption, redondance et risques.
- [Under the Hood of SKILL.md](https://arxiv.org/abs/2605.11418) - risques semantiques de selection, discovery et gouvernance des skills.
- [Agent Skills in the Wild](https://arxiv.org/abs/2601.10338) - analyse securite a grande echelle des marketplaces de skills.
- [Dive into Claude Code](https://arxiv.org/abs/2604.14228) - architecture Claude Code: plugins, skills, hooks, subagents, permissions et compaction.

## Chantier potentiel

Chantier potentiel: oui
Titre propose: Ameliorer les skills ShipGlowz avec les patterns Superpowers
Raison: Les recommandations touchent plusieurs skills et references ShipGlowz, avec decisions de lifecycle, tests, delegation, verification et securite supply-chain.
Severite: P2
Scope: ShipGlowz skills corpus, references de lifecycle, bug/fix/test/start/verify/skill-build/delegation workflows.
Evidence:
- Superpowers expose un workflow TDD/debug/revue plus strict que les gates ShipGlowz actuels.
- ShipGlowz est sous le budget de decouverte, donc une integration ciblee est possible sans suppression de skills.
- Les sources securite 2026 montrent qu'une installation directe de skills tiers augmente la surface de risque.
Spec recommandee: /sf-spec Ameliorer les skills ShipGlowz avec les patterns Superpowers: TDD de skills, debugging systematique, revue en deux temps, worktrees optionnels, et gates supply-chain
Prochaine etape: creer une spec ShipGlowz dediee avant modification du corpus.

## Chantier

non trace: aucun chantier unique ContentGlowz ne porte cette recherche ShipGlowz transverse.

Flux: sf-spec pending -> sf-ready pending -> sf-start pending -> sf-verify pending -> sf-end pending -> sf-ship pending
Reste a faire: creer une spec dediee si on decide d'integrer ces patterns dans ShipGlowz.
Prochaine etape: /sf-spec Ameliorer les skills ShipGlowz avec les patterns Superpowers: TDD de skills, debugging systematique, revue en deux temps, worktrees optionnels, et gates supply-chain
