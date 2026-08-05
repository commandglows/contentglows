function normalizeUrl(value: string | undefined, fallback: string) {
  return (value ?? fallback).replace(/\/$/, '');
}

function normalizeBuildValue(value: string | undefined, fallback: string) {
  const normalized = value?.trim();
  return normalized && normalized.length > 0 ? normalized : fallback;
}

function normalizeOptionalAbsoluteUrl(value: string | undefined) {
  const normalized = value?.trim();
  if (!normalized) {
    return undefined;
  }

  try {
    return new URL(normalized).toString();
  } catch {
    return undefined;
  }
}

export const siteUrl = normalizeUrl(
  import.meta.env.APP_SITE_URL,
  'https://contentglows.com',
);

export const appWebUrl = normalizeUrl(
  import.meta.env.APP_WEB_URL,
  'https://app.contentglows.com',
);

export const appSignInUrl = `${appWebUrl}/sign-in`;

export const appEntryUrl = `${appWebUrl}/#/entry`;

const polarCreatorCheckoutEnvUrl = normalizeOptionalAbsoluteUrl(
  import.meta.env.POLAR_CREATOR_CHECKOUT_URL,
);

const polarProCheckoutEnvUrl = normalizeOptionalAbsoluteUrl(
  import.meta.env.POLAR_PRO_CHECKOUT_URL,
);

export const creatorCheckoutUrl =
  polarCreatorCheckoutEnvUrl ?? `${appSignInUrl}?plan=creator`;

export const proCheckoutUrl =
  polarProCheckoutEnvUrl ?? `${appSignInUrl}?plan=pro`;

export const apiBaseUrl = normalizeUrl(
  import.meta.env.API_BASE_URL,
  'https://api.contentglows.com',
);

export const buildCommitSha = normalizeBuildValue(
  import.meta.env.VERCEL_GIT_COMMIT_SHA,
  'unknown',
);

export const buildEnvironment = normalizeBuildValue(
  import.meta.env.VERCEL_ENV,
  import.meta.env.PROD ? 'production' : 'development',
);

export const buildTimestamp = normalizeBuildValue(
  import.meta.env.BUILD_TIMESTAMP,
  new Date().toISOString(),
);
