# Stratégie Copywriting — ContentGlowz

> Dernière mise à jour : 2026-04-06

## Positionnement
- **Promesse principale** : "Tu as des idées, l'IA les transforme en contenu multi-format, tu swipes pour publier"
- **Différenciateur** : Pipeline complet (idée → génération → review → publish) vs outils ponctuels (ChatGPT, Jasper)
- **Transformation** : Avant = 3h pour 1 article, 0 posts social. Après = 5 min/jour, 6 formats publiés automatiquement.

## Scores

| Dimension | Score | Diagnostic |
|-----------|-------|------------|
| Cohérence promesse/produit | B | Promesse claire ("swipe to publish"), mais pas de preuve visuelle du produit |
| Positionnement | C | Différenciateur implicite, jamais articulé explicitement vs alternatives |
| Pricing psychology | D | Pas d'ancrage, pas de framing valeur, pas de toggle annuel, boutons morts |
| Trust signals | D | Zéro preuve sociale. Pas de témoignage, pas de logo, pas de chiffre d'usage |
| Content-market fit | C | 42 articles TOFU de qualité, mais déconnectés du funnel de conversion |
| Fiabilité perçue | B | Le principe de fonctionnement en mode dégradé est introduit, à décliner sur les pages de conversion |

## Recommandations prioritisées

| Pri | Action | Pages | Impact |
|-----|--------|-------|--------|
| 🔴 | Connecter CTAs Pricing à un checkout réel (Polar.sh) | Pricing.astro | Bloquant — 0% conversion sans ça |
| 🔴 | Ajouter preuve sociale (même minimale : "built by solo founder", stats d'usage) | Testimonials, Hero | Fort — confiance = conversion |
| 🔴 | Ajouter CTA produit dans chaque article blog | BlogPost.astro | Fort — 42 pages TOFU sans conversion |
| 🔴 | Déplacer "Who It's For" avant Pricing | index.astro | Fort — identification avant prix |
| 🟠 | Réduire Features à 3-4 bénéfices en langage client | Features.astro | Moyen-Fort |
| 🟠 | Framer pricing en valeur ("freelance = 500€, ContentGlowz = 19€") | Pricing.astro | Moyen-Fort |
| 🟠 | Éliminer jargon technique (CrewAI, DataForSEO, OAuth, topical mesh) | Features, Robots, Pricing | Moyen |
| 🟠 | Ajouter CTA post-FAQ (moment de conviction max) | Nouveau composant | Moyen |
| 🟠 | Intégrer la promesse de continuité offline + queue dans les pages de conversion clés | Hero, FAQ, Features, ClosingCta, plateforme | Moyen |
| 🟡 | Section transformation Before/After visuelle | Nouveau composant | Moyen |
| 🟡 | CTA léger pour indécis (newsletter, free resource) | Hero ou Footer | Faible-Moyen |
| 🟡 | Remplacer liens sociaux morts (#) par vrais profils ou supprimer | Footer.astro | Faible |

## Quick wins
1. Réordonner index.astro : mettre Testimonials (Who It's For) avant Pricing → 0 effort, fort impact
2. Ajouter un CTA banner dans BlogPost.astro → 1 composant, 42 pages impactées
3. Ligne "Built by a solo founder. Bootstrapped." dans le Hero → authenticité immédiate
