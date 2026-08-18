-- Link webhooks and conversions for Dub.co-inspired link management.

CREATE TABLE IF NOT EXISTS LinkWebhook (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL,
    projectId TEXT,
    url TEXT NOT NULL,
    secret TEXT,
    events TEXT NOT NULL DEFAULT '[]',
    enabled INTEGER NOT NULL DEFAULT 1,
    createdAt INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS LinkWebhookDelivery (
    id TEXT PRIMARY KEY NOT NULL,
    webhookId TEXT NOT NULL,
    eventType TEXT NOT NULL,
    url TEXT NOT NULL,
    statusCode INTEGER,
    requestBody TEXT,
    responseBody TEXT,
    error TEXT,
    deliveredAt INTEGER,
    createdAt INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_link_webhook_user
    ON LinkWebhook(userId);

CREATE INDEX IF NOT EXISTS idx_link_webhook_delivery_webhook
    ON LinkWebhookDelivery(webhookId, createdAt);

CREATE TABLE IF NOT EXISTS LinkConversion (
    id TEXT PRIMARY KEY NOT NULL,
    linkId TEXT NOT NULL,
    userId TEXT NOT NULL,
    projectId TEXT,
    type TEXT NOT NULL,
    revenue REAL,
    currency TEXT,
    partnerId TEXT,
    metadata TEXT,
    createdAt INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_link_conversion_link
    ON LinkConversion(linkId, createdAt);

CREATE TABLE IF NOT EXISTS UtmTemplate (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL,
    projectId TEXT,
    name TEXT NOT NULL,
    utmSource TEXT,
    utmMedium TEXT,
    utmCampaign TEXT,
    utmTerm TEXT,
    utmContent TEXT,
    createdAt INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_utm_template_user
    ON UtmTemplate(userId);
