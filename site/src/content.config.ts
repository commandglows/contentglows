import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const baseSchema = z.object({
  title: z.string(),
  description: z.string(),
  locale: z.enum(['en', 'fr']).optional().default('en'),
  pubDate: z.coerce.date().optional(),
  publishDate: z.coerce.date().optional(),
  date: z.coerce.date().optional(),
  heroImage: z.string().optional(),
  image: z.string().optional(),
  author: z.string().optional(),
  authors: z.array(z.string()).optional(),
  tags: z.array(z.string()).optional(),
  featured: z.boolean().optional().default(false),
  draft: z.boolean().optional().default(false),
  order: z.number().optional(),
  series: z.string().optional(),
  lastUpdated: z.coerce.date().optional(),
}).transform((data) => ({
  ...data,
  date: data.pubDate ?? data.publishDate ?? data.date ?? new Date(0),
  cover: data.heroImage ?? data.image ?? null,
  byline: data.author ?? data.authors?.join(', ') ?? 'ContentGlows Team',
}));

function contentCollection(base: string) {
  return defineCollection({
    loader: glob({ base, pattern: '**/[^_]*.{md,mdx}' }),
    schema: baseSchema,
  });
}

export const collections = {
  blog: contentCollection('./src/content/blog'),
  docs: contentCollection('./src/content/docs'),
  'ai-agents': contentCollection('./src/content/ai-agents'),
  platform: contentCollection('./src/content/platform'),
  'seo-strategy': contentCollection('./src/content/seo-strategy'),
  'startup-journey': contentCollection('./src/content/startup-journey'),
  'technical-optimization': contentCollection('./src/content/technical-optimization'),
  tutorials: contentCollection('./src/content/tutorials'),
};
