https://octopus.do/

---

## Firecrawl Web Agent — agent de recherche web structuré

**Lien :** https://github.com/firecrawl/web-agent
**Date de veille :** 2026-06-10
**Statut :** à surveiller / benchmark futur
**Pertinence :** lab (8/10)

**Pourquoi c'est un concurrent indirect :**
- Même zone fonctionnelle que les agents ContentGlowz de recherche, veille, SEO et extraction structurée.
- Le repo montre un pattern open-source moderne : skills `SKILL.md`, subagents parallèles, streaming et sorties JSON structurées.
- Firecrawl apporte l'infra web Search/Scrape/Interact, mais ne couvre pas notre promesse backend complète de workflows contenu, statut, planification et observabilité.

**À benchmarker plus tard :**
- Architecture des skills et subagents vs nos agents recherche/SEO.
- Gestion de la sortie structurée, du streaming et de la reprise d'exécution.
- Surface sécurité : validation URL, limites d'actions web, permissions, rétention et intégration Firecrawl Lockdown.
