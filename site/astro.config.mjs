import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

const siteUrl = (process.env.APP_SITE_URL || 'https://contentglows.com').replace(/\/$/, '');

export default defineConfig({
  site: siteUrl,
  base: '/',
  integrations: [
    sitemap({
      filter: (page) => !page.includes('/drafts/'),
    }),
  ],
});
