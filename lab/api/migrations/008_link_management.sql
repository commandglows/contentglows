-- Link management: add slug to AffiliateLink, create LinkClick and LinkVariant tables.

ALTER TABLE AffiliateLink ADD COLUMN slug TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_affiliate_slug_user
    ON AffiliateLink(userId, slug)
    WHERE slug IS NOT NULL;

CREATE TABLE IF NOT EXISTS LinkClick (
    id TEXT PRIMARY KEY NOT NULL,
    linkId TEXT NOT NULL REFERENCES AffiliateLink(id),
    userId TEXT NOT NULL,
    projectId TEXT,
    slug TEXT NOT NULL,
    destinationUrl TEXT NOT NULL,
    variantIndex INTEGER DEFAULT 0,
    country TEXT,
    device TEXT,
    referrer TEXT,
    userAgent TEXT,
    createdAt INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_link_click_link
    ON LinkClick(linkId, createdAt);

CREATE TABLE IF NOT EXISTS LinkVariant (
    id TEXT PRIMARY KEY NOT NULL,
    linkId TEXT NOT NULL REFERENCES AffiliateLink(id),
    userId TEXT NOT NULL,
    url TEXT NOT NULL,
    weight INTEGER NOT NULL DEFAULT 1,
    country TEXT,
    device TEXT,
    language TEXT,
    createdAt INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_link_variant_link
    ON LinkVariant(linkId);
