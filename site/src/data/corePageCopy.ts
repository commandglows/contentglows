import type { Locale } from './siteShell';

export const handoffPageCopy = {
  launch: {
    en: {
      title: 'Opening ContentGlows App',
      description: 'Redirecting to the ContentGlows app.',
      eyebrow: 'Open app',
      heading: 'Opening the app entry...',
      body:
        'The old website handoff has been retired. ContentGlows now opens the app directly on the app domain, where sign-in and session restore both happen.',
      primaryCta: 'Open app entry',
      secondaryCta: 'Go to sign-in',
    },
    fr: {
      title: "Ouverture de l'application ContentGlows",
      description: "Redirection vers l'application ContentGlows.",
      eyebrow: "Ouvrir l'app",
      heading: "Ouverture de l'entrée de l'app...",
      body:
        "L'ancien handoff du site a été retiré. ContentGlows ouvre maintenant l'app directement sur le domaine de l'app, où la connexion et la restauration de session se font.",
      primaryCta: "Ouvrir l'entrée de l'app",
      secondaryCta: 'Aller à la connexion',
    },
  },
  signIn: {
    en: {
      title: 'Redirecting to App Sign-In - ContentGlows',
      description: 'Redirecting to the official ContentGlows app sign-in flow.',
      eyebrow: 'App auth',
      heading: 'Redirecting to the app sign-in...',
      body:
        'ContentGlows authentication now runs directly on app.contentglows.com with the official Clerk web flow.',
      primaryCta: 'Continue with Google',
    },
    fr: {
      title: "Redirection vers la connexion de l'app - ContentGlows",
      description: "Redirection vers le flux officiel de connexion de l'app ContentGlows.",
      eyebrow: "Connexion à l'app",
      heading: "Redirection vers la connexion de l'app...",
      body:
        "L'authentification ContentGlows se fait maintenant directement sur app.contentglows.com avec le flux web officiel de Clerk.",
      primaryCta: 'Continuer avec Google',
    },
  },
  signUp: {
    en: {
      title: 'Redirecting to App Sign-In - ContentGlows',
      description: 'Redirecting to the official ContentGlows app sign-in flow.',
      eyebrow: 'Account access',
      heading: 'Account creation moved to the app domain.',
      body:
        'ContentGlows no longer creates accounts on the marketing site. The official Clerk Google flow now lives directly on the app.',
      primaryCta: 'Continue with Google',
    },
    fr: {
      title: "Redirection vers la connexion de l'app - ContentGlows",
      description: "Redirection vers le flux officiel de connexion de l'app ContentGlows.",
      eyebrow: 'Accès au compte',
      heading: "La création de compte a été déplacée vers le domaine de l'app.",
      body:
        "ContentGlows ne crée plus de comptes sur le site marketing. Le flux officiel Google de Clerk vit maintenant directement dans l'app.",
      primaryCta: 'Continuer avec Google',
    },
  },
} as const;

export const privacyPageCopy = {
  en: {
    title: 'Privacy Policy | ContentGlows',
    description:
      'How ContentGlows uses your data and how to manage your analytics preferences.',
    heading: 'Privacy Policy',
    lastUpdated: 'Last updated: March 2026',
    sections: [
      {
        heading: 'Data Collected',
        paragraphs: [
          'ContentGlows uses its own lightweight, cookie-free analytics to understand how your sites are used: pages visited, referral source, UTM campaign parameters, and device type. No personally identifiable information is collected: no IP addresses are stored, no browser fingerprinting is used, and no third-party tracking scripts are loaded.',
        ],
      },
      {
        heading: 'Cookie-Free by Design',
        paragraphs: [
          'Our analytics system does not use cookies, localStorage, or any client-side storage mechanism. Each pageview is an independent, anonymous event. This means no consent banner is required, and the approach is designed to stay aligned with GDPR, CCPA, ePrivacy, and PECR requirements.',
        ],
      },
      {
        heading: 'Data Hosting',
        paragraphs: [
          'All analytics data is processed and stored exclusively in the European Union. We do not share data with third parties, advertising networks, or data brokers. You can export your data at any time from the dashboard.',
        ],
      },
      {
        heading: 'What We Track',
        bullets: [
          'Page URL and path (which pages are visited)',
          'Referrer (where visitors come from)',
          'UTM parameters (campaign tracking)',
          'Device type, browser, and OS (parsed server-side from the user-agent)',
          'Country (derived from CDN headers, with no IP stored)',
        ],
      },
      {
        heading: "What We Don't Track",
        bullets: [
          'IP addresses (never stored)',
          'Individual visitors (no session or visitor IDs)',
          'Browser fingerprints',
          'Scroll position, mouse movements, or clicks',
          'Form inputs or personal data',
        ],
      },
      {
        heading: 'Contact',
        paragraphs: [
          'For any data-related questions, contact us through the official channels listed on the site.',
        ],
      },
    ],
  },
  fr: {
    title: 'Politique de confidentialité | ContentGlows',
    description:
      'Comment ContentGlows utilise tes données et comment gérer tes préférences liées aux analytics.',
    heading: 'Politique de confidentialité',
    lastUpdated: 'Dernière mise à jour : mars 2026',
    sections: [
      {
        heading: 'Données collectées',
        paragraphs: [
          "ContentGlows utilise ses propres analytics légers et sans cookies pour comprendre comment tes sites sont utilisés : pages visitées, source de référence, paramètres de campagne UTM et type d'appareil. Aucune information personnellement identifiable n'est collectée : aucune adresse IP n'est stockée, aucun fingerprint navigateur n'est utilisé et aucun script de suivi tiers n'est chargé.",
        ],
      },
      {
        heading: 'Sans cookies par conception',
        paragraphs: [
          "Notre système d'analytics n'utilise ni cookies, ni localStorage, ni autre mécanisme de stockage côté client. Chaque page vue est un événement indépendant et anonyme. Cela signifie qu'aucune bannière de consentement n'est requise, et l'approche est conçue pour rester alignée avec les exigences du RGPD, du CCPA, d'ePrivacy et du PECR.",
        ],
      },
      {
        heading: 'Hébergement des données',
        paragraphs: [
          "Toutes les données d'analytics sont traitées et stockées exclusivement dans l'Union européenne. Nous ne partageons pas ces données avec des tiers, des réseaux publicitaires ou des courtiers en données. Tu peux exporter tes données à tout moment depuis le dashboard.",
        ],
      },
      {
        heading: 'Ce que nous suivons',
        bullets: [
          'URL et chemin de la page (quelles pages sont visitées)',
          "Référent (d'où viennent les visiteurs)",
          'Paramètres UTM (suivi de campagne)',
          "Type d'appareil, navigateur et OS (analysés côté serveur depuis le user-agent)",
          "Pays (dérivé des headers CDN, sans stockage d'IP)",
        ],
      },
      {
        heading: 'Ce que nous ne suivons pas',
        bullets: [
          'Adresses IP (jamais stockées)',
          'Visiteurs individuels (aucun identifiant de session ou de visiteur)',
          'Empreintes navigateur',
          'Position de scroll, mouvements de souris ou clics',
          'Saisies de formulaire ou données personnelles',
        ],
      },
      {
        heading: 'Contact',
        paragraphs: [
          'Pour toute question liée aux données, contacte-nous via les canaux officiels listés sur le site.',
        ],
      },
    ],
  },
} as const;

export function getHandoffCopy(
  page: keyof typeof handoffPageCopy,
  locale: Locale,
) {
  return handoffPageCopy[page][locale];
}

export function getPrivacyCopy(locale: Locale) {
  return privacyPageCopy[locale];
}
