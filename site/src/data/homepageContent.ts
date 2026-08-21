export type Locale = 'en' | 'fr';

export interface HeroContent {
  ariaLabel: string;
  rotatingWords: string[];
  titlePrefix: string;
  titleSuffix: string;
  subtitle: string;
  primaryCta: string;
  secondaryCta: string;
  stats: Array<{ value: string; label: string }>;
  trust: string;
}

export interface ProblemContent {
  label: string;
  title: string;
  items: Array<{ icon: string; text: string }>;
  transition: string;
}

export interface SectionIntro {
  title: string;
  description: string;
}

export interface RobotsContent {
  intro: SectionIntro;
  steps: Array<{
    number?: string;
    badge?: string;
    title: string;
    icon: string;
    tagline: string;
    features: string[];
  }>;
}

export interface FeaturesContent {
  intro: SectionIntro;
  cards: Array<{ title: string; icon: string; body: string }>;
}

export interface TestimonialsContent {
  intro: SectionIntro;
  cards: Array<{ title: string; icon: string; quote: string }>;
}

export interface PricingPlan {
  name: string;
  price: string;
  priceCurrency: string;
  billingIncrement?: number;
  period?: string;
  billingNote: string;
  features: string[];
  cta: string;
  href: 'signIn' | 'creatorCheckout' | 'proCheckout';
  featured?: boolean;
  badge?: string;
  schemaDescription: string;
}

export interface PricingContent {
  intro: SectionIntro;
  note: string;
  plans: PricingPlan[];
}

export interface FaqItem {
  question: string;
  answer: string;
}

export interface FaqContent {
  intro: SectionIntro;
  items: FaqItem[];
}

export interface ClosingCtaContent {
  title: string;
  body: string;
  primaryCta: string;
  secondaryCta: string;
  note: string;
}

export interface HomePageContent {
  title: string;
  description: string;
  hero: HeroContent;
  problem: ProblemContent;
  robots: RobotsContent;
  features: FeaturesContent;
  testimonials: TestimonialsContent;
  pricing: PricingContent;
  faq: FaqContent;
  closingCta: ClosingCtaContent;
}

export const homepageContent: Record<Locale, HomePageContent> = {
  en: {
    title: 'ContentGlows — Human-Led AI Content Workspace',
    description:
      'ContentGlows turns ideas into reviewed articles, newsletters, social posts, and video scripts with AI assistance, clear approval, scheduling, and supported publishing flows.',
    hero: {
      ariaLabel: 'articles, newsletters, social posts, video scripts',
      rotatingWords: ['articles', 'newsletters', 'social posts', 'video scripts'],
      titlePrefix: 'AI drafts your',
      titleSuffix: 'You stay in control.',
      subtitle:
        'ContentGlows is a human-led content workspace for creators and lean teams. Capture ideas, shape them with your voice, review every draft, then schedule or publish through the channels that are connected. If the backend is briefly unavailable, cached reads and supported queued edits help you keep momentum.',
      primaryCta: 'Continue with Google',
      secondaryCta: 'Open App',
      stats: [
        { value: '5 min', label: 'weekly ritual' },
        { value: '1', label: 'review queue' },
        { value: 'Safe', label: 'human approval' },
      ],
      trust: 'Built by a solo founder. Bootstrapped. No VC, no fluff.',
    },
    problem: {
      label: 'Sound familiar?',
      title: 'You have 100 content ideas.<br/>Zero published.',
      items: [
        { icon: '😩', text: 'Writing one blog post takes 3 hours. You need five per week.' },
        {
          icon: '🔄',
          text: 'Each platform needs a different format. LinkedIn, Twitter, newsletter, blog — same idea, four rewrites.',
        },
        { icon: '📉', text: "You start strong on Monday. By Thursday, you've posted nothing." },
      ],
      transition: 'ContentGlows fixes this.',
    },
    robots: {
      intro: {
        title: 'How It Works',
        description: 'Three steps. Your voice in, review-ready content out.',
      },
      steps: [
        {
          number: '1',
          title: 'Feed Your Voice',
          icon: '🧠',
          tagline: 'Weekly Ritual + Personas',
          features: [
            'Complete a 5-minute weekly ritual',
            'Define your audience personas',
            'AI suggestions use your voice, tone, and positioning',
            'Your narrative arc evolves over time',
            'You keep the final say before anything goes out',
          ],
        },
        {
          badge: 'The Workflow',
          title: 'AI Drafts Content',
          icon: '⚡',
          tagline: 'Multiple Formats, One Pipeline',
          features: [
            "Content angles matched to your audience's problems",
            'Articles, newsletters, social posts, shorts',
            'Real keyword data drives every piece',
            'Affiliate opportunities surfaced when they match',
            'Scheduling stays visible before publish',
          ],
        },
        {
          number: '3',
          title: 'Review & Approve',
          icon: '👆',
          tagline: 'Review in Seconds',
          features: [
            'Open the app on your phone',
            'Approve, skip, or edit before publishing',
            'Edit inline if needed',
            'Publish through supported connected channels',
            'Track performance in analytics',
            'If the backend is offline, supported edits are queued and retried',
          ],
        },
      ],
    },
    features: {
      intro: {
        title: 'From idea to reviewed content, without losing control.',
        description:
          'A practical workflow that turns your creator voice into multi-format drafts you can trust',
      },
      cards: [
        {
          title: 'Your Voice, Not Generic AI',
          icon: '🎯',
          body: 'A short weekly ritual and persona inputs give the system enough context to propose content that sounds closer to you, not a generic chatbot.',
        },
        {
          title: 'One Idea, Six Formats',
          icon: '🔀',
          body: 'Start from one idea and prepare the formats you actually need: blog post, newsletter, social post, short video script, or reel.',
        },
        {
          title: 'Content Built From Search Data',
          icon: '📊',
          body: 'Keyword data and competitor analysis inform article direction, so your drafts target real search demand instead of guesswork.',
        },
        {
          title: 'Publishing With Clear Limits',
          icon: '🚀',
          body: 'Connect supported social channels when you are ready. ContentGlows keeps account state, review, scheduling, and publish feedback visible in one workspace.',
        },
        {
          title: 'Usable During Short Outages',
          icon: '🛠️',
          body: 'When network or API access drops, supported parts of your workspace keep functioning in degraded mode: reads use the latest local cache and supported actions are queued for automatic sync when the backend is reachable again.',
        },
        {
          title: 'Review From Your Phone',
          icon: '📱',
          body: 'The app works on Android, iOS, and web. Review and approve content on the train, in line for coffee, or between meetings. 5 minutes a day.',
        },
      ],
    },
    testimonials: {
      intro: {
        title: "Who It's For",
        description:
          'ContentGlows is for people who have something to say but not enough time to say it everywhere',
      },
      cards: [
        {
          title: 'Solo Founders',
          icon: '🚀',
          quote:
            "You're building a product and need to ship content for SEO, social, and newsletters. But writing isn't your job. ContentGlows turns your weekly ritual into drafts you can review.",
        },
        {
          title: 'Content Creators',
          icon: '✍️',
          quote:
            'You have one idea. ContentGlows helps shape it into the formats you need: a blog post, a social post, a newsletter section, or a short video script.',
        },
        {
          title: 'SEO-Driven Sites',
          icon: '📈',
          quote:
            'DataForSEO-powered keyword research feeds the pipeline. Articles target real search volume, and SERP tracking shows what is working after publication.',
        },
        {
          title: 'Affiliate Marketers',
          icon: '💰',
          quote:
            'Register your affiliate programs. ContentGlows surfaces matching opportunities and keeps active, paused, and expired programs visible before links are used.',
        },
        {
          title: 'Small Agencies',
          icon: '🏢',
          quote:
            'Manage multiple projects with separate personas, voices, and publishing channels. The Pro plan gives unlimited projects. Scale content for all your clients from one dashboard.',
        },
        {
          title: 'Mobile-First Creators',
          icon: '📱',
          quote:
            'Review content from your phone on the train. Approve, skip, or edit from a mobile-first review flow designed for thumbs, not keyboards.',
        },
      ],
    },
    pricing: {
      intro: {
        title: 'Simple Pricing. Start Free.',
        description: 'No credit card required. Upgrade when your content scales.',
      },
      note:
        'Plan prices cover platform access, updates, and security patches. For compatible AI actions, use your own provider key (BYOK) or, where available, ContentGlows-managed usage billed separately on a pay-as-you-go basis. The app shows availability and usage before generation.',
      plans: [
        {
          name: 'Free',
          price: '0',
          priceCurrency: 'EUR',
          billingNote: 'Forever free',
          features: [
            '1 project',
            '5 content pieces/month',
            'Swipe approval feed',
            '1 publishing channel',
            'Basic analytics',
            'Community support',
          ],
          cta: 'Get Started',
          href: 'signIn',
          schemaDescription: '1 project, 5 content pieces/month, 1 publishing channel',
        },
        {
          name: 'Creator',
          price: '19',
          priceCurrency: 'EUR',
          billingIncrement: 1,
          period: '/mo',
          billingNote: 'Everything you need to publish consistently',
          features: [
            '3 projects',
            '50 content pieces/month',
            'All 6 content formats',
            'All publishing channels',
            'SEO keyword research',
            'Affiliate link management',
            'Content scheduling',
            'Full analytics',
            'Email support',
          ],
          cta: 'Start 14-Day Trial',
          href: 'creatorCheckout',
          featured: true,
          badge: 'Most Popular',
          schemaDescription:
            '3 projects, 50 content pieces/month, all formats and channels, SEO keyword research',
        },
        {
          name: 'Pro',
          price: '49',
          priceCurrency: 'EUR',
          billingIncrement: 1,
          period: '/mo',
          billingNote: 'For serious content creators and agencies',
          features: [
            'Unlimited projects',
            'Unlimited workspace content (AI usage separate)',
            'All Creator features',
            'Competitor analysis',
            'Ranking position tracking',
            'Content strategy analysis',
            'Custom audience personas',
            'Priority support',
            'API access',
          ],
          cta: 'Start 14-Day Trial',
          href: 'proCheckout',
          schemaDescription:
            'Unlimited projects and content, competitor analysis, SERP tracking, API access',
        },
      ],
    },
    faq: {
      intro: {
        title: 'Frequently Asked Questions',
        description: 'Everything you need to know about ContentGlows',
      },
      items: [
        {
          question: 'Does the AI really sound like me?',
          answer:
            'ContentGlows uses weekly rituals, audience personas, and positioning inputs to draft closer to your voice. You still review and edit before anything goes out.',
        },
        {
          question: 'What content formats are supported?',
          answer:
            'Blog articles, newsletters, social posts, short-form video scripts, reels, and YouTube video scripts are modeled in the workspace. You choose the formats that fit each idea.',
        },
        {
          question: 'Where can I publish from ContentGlows?',
          answer:
            'Supported social channels can be connected from Settings. External publishing depends on connected accounts and the current backend-supported channel flow; unsupported channels stay visible as blocked or manual paths.',
        },
        {
          question: 'Do I review every piece of content?',
          answer:
            'Yes. ContentGlows is human-led: AI drafts, you approve, skip, edit, schedule, or publish through supported connected flows.',
        },
        {
          question: 'How does SEO work?',
          answer:
            'ContentGlows uses DataForSEO for keyword data, competitor analysis, and SERP tracking. Articles can target keywords with real search volume, while rankings still depend on quality, site authority, and execution.',
        },
        {
          question: 'What about affiliate links?',
          answer:
            'Register your affiliate programs with keywords. ContentGlows can surface relevant matches when the topic fits, and you control which programs are active.',
        },
        {
          question: 'How are AI usage costs handled?',
          answer:
            'Your plan covers access to the ContentGlows platform. Compatible AI actions can use your own provider key (BYOK), billed directly by that provider. Where available, ContentGlows-managed AI usage is separate and pay as you go; the app checks availability and usage before generation. Exact public usage prices are not listed here yet.',
        },
        {
          question: 'Can I use it on mobile?',
          answer:
            'The Flutter app works on Android, iOS, and web. Review and approve content from anywhere. The swipe interface was designed mobile-first.',
        },
        {
          question: 'What happens if the backend is down?',
          answer:
            'The app enters a degraded mode: you can still access your workspace and continue reviewing cached content; most supported create/update actions are kept in a local queue and synced automatically when the API is back.',
        },
      ],
    },
    closingCta: {
      title: 'Ready to turn ideas into reviewed content?',
      body:
        'Start with a controlled workspace for ideas, drafts, review, scheduling, and supported publishing flows. Free plan, no credit card.',
      primaryCta: 'Start Free',
      secondaryCta: 'Read the Blog',
      note:
        'Built for real-world conditions: degraded mode, local queue sync for supported edits, and explicit recovery after outages.',
    },
  },
  fr: {
    title: 'ContentGlows — Espace de contenu IA avec validation humaine',
    description:
      "ContentGlows t'aide à transformer tes idées en articles, newsletters, posts sociaux et scripts vidéo relus, avec assistance IA, validation claire, planification et publication prise en charge.",
    hero: {
      ariaLabel: 'articles, newsletters, posts sociaux, scripts vidéo',
      rotatingWords: ['articles', 'newsletters', 'posts sociaux', 'scripts vidéo'],
      titlePrefix: 'L’IA prépare tes',
      titleSuffix: 'Tu gardes la main.',
      subtitle:
        "ContentGlows est un espace de contenu piloté par l'humain pour créateurs et petites équipes. Capture tes idées, affine-les avec ta voix, relis chaque brouillon, puis planifie ou publie via les canaux connectés. Si le backend est brièvement indisponible, les lectures en cache et les edits pris en charge en file locale t'aident à garder le rythme.",
      primaryCta: 'Continuer avec Google',
      secondaryCta: "Ouvrir l'app",
      stats: [
        { value: '5 min', label: 'rituel hebdo' },
        { value: '1', label: 'file de revue' },
        { value: 'Sûr', label: 'validation humaine' },
      ],
      trust: 'Construit par une solo founder. Bootstrappé. Pas de VC, pas de blabla.',
    },
    problem: {
      label: 'Ça te parle ?',
      title: 'Tu as 100 idées de contenu.<br/>Zéro publié.',
      items: [
        { icon: '😩', text: 'Écrire un article prend 3 heures. Il t’en faut cinq par semaine.' },
        {
          icon: '🔄',
          text: 'Chaque plateforme demande un format différent. LinkedIn, X, newsletter, blog — même idée, quatre réécritures.',
        },
        { icon: '📉', text: 'Tu démarres fort le lundi. Le jeudi, tu n’as encore rien publié.' },
      ],
      transition: 'ContentGlows remet de l’ordre là-dedans.',
    },
    robots: {
      intro: {
        title: 'Comment ça marche',
        description: 'Trois étapes. Ta voix en entrée, du contenu prêt à relire en sortie.',
      },
      steps: [
        {
          number: '1',
          title: 'Nourris ta voix',
          icon: '🧠',
          tagline: 'Rituel hebdo + personas',
          features: [
            'Complète un rituel hebdomadaire de 5 minutes',
            'Définis tes personas',
            'Les suggestions IA utilisent ta voix, ton ton et ton positionnement',
            'Ton arc narratif évolue au fil du temps',
            'Tu gardes le dernier mot avant toute sortie',
          ],
        },
        {
          badge: 'Le workflow',
          title: 'L’IA prépare le contenu',
          icon: '⚡',
          tagline: 'Plusieurs formats, un seul pipeline',
          features: [
            'Des angles alignés sur les vrais problèmes de ton audience',
            'Articles, newsletters, posts sociaux, formats courts',
            'Les vraies données mots-clés guident chaque pièce',
            'Les opportunités d’affiliation remontent quand elles sont pertinentes',
            'La planification reste visible avant publication',
          ],
        },
        {
          number: '3',
          title: 'Relis et valide',
          icon: '👆',
          tagline: 'Revue en quelques secondes',
          features: [
            "Ouvre l'app sur ton téléphone",
            'Valide, passe ou édite avant publication',
            'Modifie inline si besoin',
            'Publie via les canaux connectés pris en charge',
            'Suis les performances dans les analytics',
            'Si le backend tombe, les edits pris en charge sont mis en file puis rejoués',
          ],
        },
      ],
    },
    features: {
      intro: {
        title: 'Passe de l’idée au contenu relu, sans perdre le contrôle.',
        description:
          'Un workflow concret qui transforme ta voix de créateur en brouillons multi-formats auxquels tu peux faire confiance',
      },
      cards: [
        {
          title: 'Ta voix, pas une IA générique',
          icon: '🎯',
          body: 'Un court rituel hebdo et des personas donnent assez de contexte au système pour proposer un contenu plus proche de toi qu’un chatbot générique.',
        },
        {
          title: 'Une idée, six formats',
          icon: '🔀',
          body: 'Pars d’une idée et prépare les formats dont tu as vraiment besoin : article, newsletter, post social, script vidéo court ou reel.',
        },
        {
          title: 'Du contenu nourri par la recherche',
          icon: '📊',
          body: 'Les données mots-clés et l’analyse concurrentielle orientent les articles pour viser une vraie demande de recherche au lieu d’improviser.',
        },
        {
          title: 'Publier avec des limites claires',
          icon: '🚀',
          body: 'Connecte les canaux sociaux pris en charge quand tu es prêt. ContentGlows garde visibles l’état des comptes, la revue, la planification et le retour de publication.',
        },
        {
          title: 'Utilisable pendant les petites coupures',
          icon: '🛠️',
          body: 'Quand le réseau ou l’API décrochent, les parties prises en charge de ton espace restent utiles en mode dégradé : les lectures s’appuient sur le dernier cache local et les actions compatibles partent en file pour une synchro automatique.',
        },
        {
          title: 'Relis depuis ton téléphone',
          icon: '📱',
          body: "L'app fonctionne sur Android, iOS et web. Relis et valide dans le train, en file d'attente ou entre deux rendez-vous. 5 minutes par jour.",
        },
      ],
    },
    testimonials: {
      intro: {
        title: 'Pour qui ?',
        description:
          'ContentGlows sert les personnes qui ont des choses à dire mais pas assez de temps pour le dire partout',
      },
      cards: [
        {
          title: 'Solo founders',
          icon: '🚀',
          quote:
            'Tu construis un produit et tu dois publier pour le SEO, le social et les newsletters. Mais écrire n’est pas ton métier. ContentGlows transforme ton rituel hebdo en brouillons à relire.',
        },
        {
          title: 'Créateurs de contenu',
          icon: '✍️',
          quote:
            'Tu pars d’une seule idée. ContentGlows t’aide à la décliner dans les formats utiles : article, post social, section newsletter ou script vidéo court.',
        },
        {
          title: 'Sites pilotés par le SEO',
          icon: '📈',
          quote:
            'La recherche mots-clés alimentée par DataForSEO nourrit le pipeline. Les articles ciblent une vraie demande et le suivi SERP montre ce qui fonctionne après publication.',
        },
        {
          title: 'Marketeurs affiliation',
          icon: '💰',
          quote:
            'Enregistre tes programmes d’affiliation. ContentGlows fait remonter les opportunités compatibles et garde visibles les programmes actifs, en pause ou expirés avant usage.',
        },
        {
          title: 'Petites agences',
          icon: '🏢',
          quote:
            'Gère plusieurs projets avec personas, voix et canaux de publication distincts. Le plan Pro donne des projets illimités pour scaler le contenu de tous tes clients depuis un seul dashboard.',
        },
        {
          title: 'Créateurs mobile-first',
          icon: '📱',
          quote:
            'Relis depuis ton téléphone dans le train. Valide, passe ou édite via un flow de revue pensé pour les pouces, pas pour les claviers.',
        },
      ],
    },
    pricing: {
      intro: {
        title: 'Tarifs simples. Commence gratuitement.',
        description: 'Pas de carte bancaire requise. Tu upgrades quand ton contenu change d’échelle.',
      },
      note:
        'Le prix des plans couvre l’accès à la plateforme, les mises à jour et les correctifs de sécurité. Pour les actions IA compatibles, utilise ta propre clé fournisseur (BYOK) ou, lorsqu’il est disponible, l’usage géré par ContentGlows, facturé séparément à l’usage. L’app affiche la disponibilité et l’usage avant la génération.',
      plans: [
        {
          name: 'Free',
          price: '0',
          priceCurrency: 'EUR',
          billingNote: 'Gratuit pour toujours',
          features: [
            '1 projet',
            '5 contenus par mois',
            'Feed de validation swipe',
            '1 canal de publication',
            'Analytics de base',
            'Support communauté',
          ],
          cta: 'Commencer',
          href: 'signIn',
          schemaDescription: '1 projet, 5 contenus par mois, 1 canal de publication',
        },
        {
          name: 'Creator',
          price: '19',
          priceCurrency: 'EUR',
          billingIncrement: 1,
          period: '/mois',
          billingNote: 'Tout ce qu’il te faut pour publier régulièrement',
          features: [
            '3 projets',
            '50 contenus par mois',
            'Les 6 formats de contenu',
            'Tous les canaux de publication',
            'Recherche mots-clés SEO',
            'Gestion de liens affiliés',
            'Planification du contenu',
            'Analytics complètes',
            'Support email',
          ],
          cta: 'Démarrer l’essai 14 jours',
          href: 'creatorCheckout',
          featured: true,
          badge: 'Le plus choisi',
          schemaDescription:
            '3 projets, 50 contenus par mois, tous les formats et canaux, recherche mots-clés SEO',
        },
        {
          name: 'Pro',
          price: '49',
          priceCurrency: 'EUR',
          billingIncrement: 1,
          period: '/mois',
          billingNote: 'Pour les créateurs sérieux et les agences',
          features: [
            'Projets illimités',
            'Contenu illimité dans le workspace (usage IA séparé)',
            'Toutes les fonctions Creator',
            'Analyse concurrentielle',
            'Suivi des positions',
            'Analyse de stratégie de contenu',
            'Personas d’audience sur mesure',
            'Support prioritaire',
            'Accès API',
          ],
          cta: 'Démarrer l’essai 14 jours',
          href: 'proCheckout',
          schemaDescription:
            'Projets et contenus illimités, analyse concurrentielle, suivi SERP, accès API',
        },
      ],
    },
    faq: {
      intro: {
        title: 'Questions fréquentes',
        description: 'Tout ce qu’il te faut savoir sur ContentGlows',
      },
      items: [
        {
          question: 'Est-ce que l’IA peut vraiment sonner comme moi ?',
          answer:
            'ContentGlows s’appuie sur tes rituels hebdos, tes personas et ton positionnement pour proposer des brouillons plus proches de ta voix. Tu relis et tu édites toujours avant toute sortie.',
        },
        {
          question: 'Quels formats de contenu sont pris en charge ?',
          answer:
            'Articles de blog, newsletters, posts sociaux, scripts vidéo courts, reels et scripts YouTube sont modélisés dans l’espace de travail. Tu choisis les formats adaptés à chaque idée.',
        },
        {
          question: 'Où puis-je publier depuis ContentGlows ?',
          answer:
            'Les canaux sociaux pris en charge se connectent depuis les réglages. La publication externe dépend des comptes connectés et du flow backend actuellement supporté ; les canaux non supportés restent visibles comme bloqués ou manuels.',
        },
        {
          question: 'Est-ce que je relis chaque contenu ?',
          answer:
            'Oui. ContentGlows reste piloté par l’humain : l’IA prépare, puis tu valides, passes, édites, planifies ou publies via les flows connectés pris en charge.',
        },
        {
          question: 'Comment fonctionne le SEO ?',
          answer:
            'ContentGlows utilise DataForSEO pour les mots-clés, l’analyse concurrentielle et le suivi SERP. Les articles peuvent viser des mots-clés à vraie volumétrie, mais les résultats dépendent toujours de la qualité, de l’autorité du site et de l’exécution.',
        },
        {
          question: 'Et pour les liens affiliés ?',
          answer:
            'Enregistre tes programmes affiliés avec leurs mots-clés. ContentGlows peut faire remonter les correspondances pertinentes quand le sujet colle, et tu gardes le contrôle sur les programmes actifs.',
        },
        {
          question: 'Comment sont facturés les usages IA ?',
          answer:
            'Ton plan couvre l’accès à la plateforme ContentGlows. Les actions IA compatibles peuvent utiliser ta propre clé fournisseur (BYOK), facturée directement par ce fournisseur. Lorsqu’il est disponible, l’usage IA géré par ContentGlows est séparé et facturé à l’usage ; l’app vérifie la disponibilité et l’usage avant la génération. Les tarifs publics précis de cet usage ne sont pas encore affichés ici.',
        },
        {
          question: 'Puis-je l’utiliser sur mobile ?',
          answer:
            "L'app Flutter fonctionne sur Android, iOS et web. Tu peux relire et valider de partout. L'interface swipe a été pensée mobile-first.",
        },
        {
          question: 'Que se passe-t-il si le backend tombe ?',
          answer:
            "L'app passe en mode dégradé : tu gardes l'accès à ton espace et tu peux continuer à relire le contenu en cache ; la plupart des actions create/update prises en charge restent dans une file locale puis se synchronisent automatiquement quand l'API revient.",
        },
      ],
    },
    closingCta: {
      title: 'Prêt à transformer tes idées en contenu relu ?',
      body:
        'Commence avec un espace maîtrisé pour idées, brouillons, revue, planification et publication prise en charge. Plan gratuit, sans carte bancaire.',
      primaryCta: 'Commencer gratuitement',
      secondaryCta: 'Lire le blog',
      note:
        'Pensé pour la vraie vie : mode dégradé, synchro depuis file locale pour les edits pris en charge, et reprise explicite après incident.',
    },
  },
};
