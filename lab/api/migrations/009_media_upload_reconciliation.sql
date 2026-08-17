ALTER TABLE video_source_upload_sessions
ADD COLUMN cleanup_locators_json TEXT NOT NULL DEFAULT '[]';

ALTER TABLE video_source_upload_sessions
ADD COLUMN cleanup_asset_ids_json TEXT NOT NULL DEFAULT '[]';

ALTER TABLE video_source_upload_sessions
ADD COLUMN reconcile_attempts INTEGER NOT NULL DEFAULT 0;

ALTER TABLE video_source_upload_sessions
ADD COLUMN reconcile_after TEXT;

ALTER TABLE video_source_upload_sessions
ADD COLUMN lease_token TEXT;

ALTER TABLE video_source_upload_sessions
ADD COLUMN lease_expires_at TEXT;

ALTER TABLE video_source_upload_sessions
ADD COLUMN last_reconcile_error TEXT;

CREATE INDEX IF NOT EXISTS idx_video_source_upload_reconciliation
ON video_source_upload_sessions(status, reconcile_after, lease_expires_at, updated_at);
