import type { CollectionEntry } from 'astro:content';
import type { HreflangLink, Locale } from './siteShell';

type BlogEntry = CollectionEntry<'blog'>;

const localeDateFormats: Record<Locale, string> = {
  en: 'en-US',
  fr: 'fr-FR',
};

const labels = {
  en: {
    blogTitle: 'Blog',
    blogDescription: 'Guides, case studies, and technical deep-dives on AI automation.',
    featured: 'Featured',
    allArticles: 'All articles',
    noArticles: 'No articles yet — check back soon.',
    backHome: 'Back to home',
    home: 'Home',
    by: 'By',
    minRead: 'min read',
    contents: 'Contents',
    relatedArticles: 'Related articles',
    readArticle: 'Read article',
    backToSection: 'Back to',
    tagTitle: 'Tag',
    articleCount: (count: number) => `${count} article${count !== 1 ? 's' : ''}`,
    backToBlog: 'Back to Blog',
    tagDescription: (label: string) => `Articles tagged "${label}" on the ContentGlows blog.`,
    ctaText:
      'Stop losing ideas in scattered tools. ContentGlows turns them into reviewed articles, social posts, and newsletters with you in control.',
    ctaStrong: 'Stop losing ideas in scattered tools.',
    ctaButton: 'Start Free',
  },
  fr: {
    blogTitle: 'Blog',
    blogDescription: "Guides, retours d'expérience et analyses techniques sur l'automatisation IA.",
    featured: 'À la une',
    allArticles: 'Tous les articles',
    noArticles: 'Aucun article pour le moment — reviens bientôt.',
    backHome: "Retour à l'accueil",
    home: 'Accueil',
    by: 'Par',
    minRead: 'min de lecture',
    contents: 'Sommaire',
    relatedArticles: 'Articles liés',
    readArticle: "Lire l'article",
    backToSection: 'Retour à',
    tagTitle: 'Tag',
    articleCount: (count: number) => `${count} article${count > 1 ? 's' : ''}`,
    backToBlog: 'Retour au blog',
    tagDescription: (label: string) => `Articles du blog ContentGlows tagués "${label}".`,
    ctaText:
      "Arrête de perdre tes idées dans des outils dispersés. ContentGlows les transforme en articles relus, posts sociaux et newsletters avec toi aux commandes.",
    ctaStrong: 'Arrête de perdre tes idées dans des outils dispersés.',
    ctaButton: 'Commencer gratuitement',
  },
} as const;

export function getEntryLocale(entry: BlogEntry): Locale {
  return entry.data.locale ?? 'en';
}

export function filterBlogEntriesByLocale(entries: BlogEntry[], locale: Locale) {
  return entries.filter((entry) => getEntryLocale(entry) === locale);
}

export function getBlogBasePath(locale: Locale) {
  return locale === 'fr' ? '/fr/blog' : '/blog';
}

export function getBlogPostPath(entry: BlogEntry, locale: Locale) {
  return `${getBlogBasePath(locale)}/${entry.id}`;
}

export function getTagSlug(tag: string) {
  return tag.toLowerCase().replace(/\s+/g, '-');
}

export function formatBlogDate(date: Date, locale: Locale, mode: 'long' | 'short' = 'long') {
  return date.toLocaleDateString(
    localeDateFormats[locale],
    mode === 'long'
      ? { year: 'numeric', month: 'long', day: 'numeric' }
      : { year: 'numeric', month: 'short', day: 'numeric' },
  );
}

export function getBlogLabels(locale: Locale) {
  return labels[locale];
}

export function getBlogIndexAlternates(locale: Locale): {
  canonicalUrl: string;
  alternateLocales: HreflangLink[];
  xDefaultUrl?: string;
} {
  const canonicalUrl = getBlogBasePath(locale);
  const alternateLocales: HreflangLink[] = [
    { hrefLang: 'en', href: getBlogBasePath('en') },
    { hrefLang: 'fr', href: getBlogBasePath('fr') },
  ];

  return {
    canonicalUrl,
    alternateLocales,
    xDefaultUrl: locale === 'en' ? getBlogBasePath('en') : undefined,
  };
}
