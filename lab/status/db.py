"""Status database helpers backed by Turso/libsql.

This module intentionally no longer persists lifecycle data to a local SQLite
file. All durable status data is stored in Turso; only explicit in-memory or
temporary runtime state may remain local elsewhere in the app.
"""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path
from typing import Optional

from utils.libsql_sync import Connection, create_connection

MIGRATION_PATH = (
    Path(__file__).resolve().parent.parent / "api" / "migrations" / "004_status_lifecycle.sql"
)
VIDEO_TIMELINE_MIGRATION_PATH = (
    Path(__file__).resolve().parent.parent / "api" / "migrations" / "005_video_timelines.sql"
)
VIDEO_SOURCE_INTAKE_MIGRATION_PATH = (
    Path(__file__).resolve().parent.parent / "api" / "migrations" / "007_video_source_intake.sql"
)


def get_connection(db_path: Optional[str] = None) -> Connection:
    """Create a libsql connection to Turso or an explicit override URL."""

    url = (db_path or os.environ.get("TURSO_DATABASE_URL", "") or "").strip()
    auth_token = os.environ.get("TURSO_AUTH_TOKEN", "").strip()
    if not url:
        raise RuntimeError(
            "Status database not configured. Set TURSO_DATABASE_URL and TURSO_AUTH_TOKEN."
        )
    return create_connection(url=url, auth_token=auth_token)


def init_db(conn: Connection) -> None:
    """Create all status-domain tables if they do not exist."""

    if not MIGRATION_PATH.exists():
        raise RuntimeError(f"Missing status schema migration: {MIGRATION_PATH}")
    conn.executescript(MIGRATION_PATH.read_text(encoding="utf-8"))
    if VIDEO_TIMELINE_MIGRATION_PATH.exists():
        conn.executescript(VIDEO_TIMELINE_MIGRATION_PATH.read_text(encoding="utf-8"))
    if VIDEO_SOURCE_INTAKE_MIGRATION_PATH.exists():
        conn.executescript(VIDEO_SOURCE_INTAKE_MIGRATION_PATH.read_text(encoding="utf-8"))
    conn.commit()
    _run_migrations(conn)


def _run_migrations(conn: Connection) -> None:
    """Add columns/indexes needed by older lifecycle rows, idempotently."""

    for stmt in [
        "ALTER TABLE idea_pool ADD COLUMN user_id TEXT",
        "ALTER TABLE content_records ADD COLUMN user_id TEXT",
        "ALTER TABLE content_records ADD COLUMN current_version INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE content_records ADD COLUMN review_actor_type TEXT",
        "ALTER TABLE content_records ADD COLUMN review_actor_id TEXT",
        "ALTER TABLE content_records ADD COLUMN review_actor_label TEXT",
        "ALTER TABLE content_records ADD COLUMN review_actor_metadata TEXT",
        "ALTER TABLE status_changes ADD COLUMN actor_type TEXT",
        "ALTER TABLE status_changes ADD COLUMN actor_id TEXT",
        "ALTER TABLE status_changes ADD COLUMN actor_label TEXT",
        "ALTER TABLE status_changes ADD COLUMN actor_metadata TEXT",
        "ALTER TABLE content_edits ADD COLUMN actor_type TEXT",
        "ALTER TABLE content_edits ADD COLUMN actor_id TEXT",
        "ALTER TABLE content_edits ADD COLUMN actor_label TEXT",
        "ALTER TABLE content_edits ADD COLUMN actor_metadata TEXT",
        "ALTER TABLE project_assets ADD COLUMN storage_provider TEXT",
        "ALTER TABLE project_assets ADD COLUMN storage_namespace TEXT",
        "ALTER TABLE project_assets ADD COLUMN storage_object_key TEXT",
        "ALTER TABLE project_assets ADD COLUMN storage_version TEXT",
        "ALTER TABLE project_assets ADD COLUMN storage_checksum_sha256 TEXT",
        "ALTER TABLE project_assets ADD COLUMN original_file_name TEXT",
        "ALTER TABLE project_assets ADD COLUMN category_id TEXT",
        "ALTER TABLE project_assets ADD COLUMN subcategory_id TEXT",
        """
        CREATE TABLE IF NOT EXISTS content_assets (
            id TEXT PRIMARY KEY,
            content_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            client_asset_id TEXT,
            source TEXT NOT NULL DEFAULT 'device_capture',
            kind TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            file_name TEXT,
            byte_size INTEGER,
            width INTEGER,
            height INTEGER,
            duration_ms INTEGER,
            storage_uri TEXT,
            status TEXT NOT NULL DEFAULT 'local_only',
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS project_assets (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            source_asset_id TEXT,
            content_asset_id TEXT,
            media_kind TEXT NOT NULL,
            source TEXT NOT NULL,
            mime_type TEXT,
            file_name TEXT,
            original_file_name TEXT,
            category_id TEXT,
            subcategory_id TEXT,
            storage_uri TEXT,
            storage_provider TEXT,
            storage_namespace TEXT,
            storage_object_key TEXT,
            storage_version TEXT,
            storage_checksum_sha256 TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            tombstoned_at TEXT,
            cleanup_eligible_at TEXT
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS project_asset_usages (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            target_type TEXT NOT NULL,
            target_id TEXT NOT NULL,
            placement TEXT,
            usage_action TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0,
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS project_asset_usage_targets (
            target_type TEXT NOT NULL,
            target_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (target_type, target_id, project_id, user_id)
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS project_asset_events (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            event_type TEXT NOT NULL,
            target_type TEXT,
            target_id TEXT,
            placement TEXT,
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS asset_understanding_jobs (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            media_type TEXT NOT NULL,
            provider TEXT NOT NULL,
            credential_source TEXT,
            status TEXT NOT NULL,
            idempotency_key TEXT NOT NULL,
            retry_of_job_id TEXT,
            error_code TEXT,
            error_message TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS asset_understanding_results (
            id TEXT PRIMARY KEY,
            job_id TEXT NOT NULL,
            asset_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            provider TEXT NOT NULL,
            credential_source TEXT,
            summary TEXT,
            source_attribution TEXT NOT NULL DEFAULT '{}',
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS asset_understanding_tags (
            id TEXT PRIMARY KEY,
            result_id TEXT NOT NULL,
            asset_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            key TEXT NOT NULL,
            label TEXT NOT NULL,
            confidence REAL NOT NULL,
            source TEXT NOT NULL DEFAULT 'ai_suggestion',
            accepted_by_user INTEGER NOT NULL DEFAULT 0,
            rejected_by_user INTEGER NOT NULL DEFAULT 0,
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS asset_understanding_segments (
            id TEXT PRIMARY KEY,
            result_id TEXT NOT NULL,
            asset_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            start_seconds REAL NOT NULL,
            end_seconds REAL NOT NULL,
            label TEXT NOT NULL,
            confidence REAL NOT NULL,
            suggested_placement TEXT,
            metadata TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS asset_understanding_quota_daily (
            day_utc TEXT NOT NULL,
            user_id TEXT NOT NULL,
            credential_source TEXT NOT NULL,
            media_type TEXT NOT NULL,
            used_count INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (day_utc, user_id, credential_source, media_type)
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS video_timelines (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            content_id TEXT NOT NULL,
            format_preset TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            current_version_id TEXT,
            draft_revision INTEGER NOT NULL DEFAULT 0,
            draft_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS video_timeline_versions (
            id TEXT PRIMARY KEY,
            timeline_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            content_id TEXT NOT NULL,
            format_preset TEXT NOT NULL,
            version_number INTEGER NOT NULL,
            timeline_json TEXT NOT NULL,
            renderer_props_json TEXT NOT NULL DEFAULT '{}',
            approved_preview_job_id TEXT,
            preview_approved_at TEXT,
            client_request_id TEXT,
            created_at TEXT NOT NULL
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS video_timeline_render_jobs (
            job_id TEXT PRIMARY KEY,
            timeline_id TEXT NOT NULL,
            version_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            render_mode TEXT NOT NULL,
            status TEXT NOT NULL,
            progress INTEGER NOT NULL DEFAULT 0,
            message TEXT,
            artifact_json TEXT,
            worker_job_id TEXT,
            parent_preview_job_id TEXT,
            client_request_id TEXT,
            stale INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """,
    ]:
        try:
            conn.execute(stmt)
        except sqlite3.OperationalError:
            pass
        except Exception as exc:
            message = str(exc).lower()
            if (
                "duplicate column" in message
                or "already exists" in message
                or "no such table" in message
            ):
                continue
            raise

    conn.execute(
        """
        UPDATE project_assets
        SET original_file_name = file_name
        WHERE original_file_name IS NULL AND file_name IS NOT NULL
        """
    )

    for stmt in [
        "CREATE INDEX IF NOT EXISTS idx_ideas_user ON idea_pool(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_content_user ON content_records(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_content_updated_at ON content_records(updated_at)",
        "CREATE INDEX IF NOT EXISTS idx_content_review_actor_id ON content_records(review_actor_id)",
        "CREATE INDEX IF NOT EXISTS idx_jobs_user ON schedule_jobs(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_jobs_project ON schedule_jobs(project_id)",
        "CREATE INDEX IF NOT EXISTS idx_changes_actor_id ON status_changes(actor_id)",
        "CREATE INDEX IF NOT EXISTS idx_edits_actor_id ON content_edits(actor_id)",
        "CREATE INDEX IF NOT EXISTS idx_assets_content ON content_assets(content_id)",
        "CREATE INDEX IF NOT EXISTS idx_assets_project ON content_assets(project_id)",
        "CREATE INDEX IF NOT EXISTS idx_assets_user ON content_assets(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_assets_client ON content_assets(content_id, client_asset_id)",
        "CREATE INDEX IF NOT EXISTS idx_project_assets_project ON project_assets(project_id)",
        "CREATE INDEX IF NOT EXISTS idx_project_assets_user ON project_assets(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_project_assets_kind ON project_assets(project_id, media_kind)",
        "CREATE INDEX IF NOT EXISTS idx_project_assets_source ON project_assets(project_id, source)",
        "CREATE INDEX IF NOT EXISTS idx_project_assets_category ON project_assets(project_id, category_id, subcategory_id, updated_at)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_project_assets_content_asset ON project_assets(content_asset_id) WHERE content_asset_id IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS idx_project_asset_usages_asset ON project_asset_usages(asset_id)",
        "CREATE INDEX IF NOT EXISTS idx_project_asset_usages_target ON project_asset_usages(project_id, target_type, target_id)",
        "CREATE INDEX IF NOT EXISTS idx_project_asset_usage_targets_owner ON project_asset_usage_targets(project_id, user_id, target_type)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_project_asset_usages_primary ON project_asset_usages(project_id, target_type, target_id, placement) WHERE is_primary = 1 AND deleted_at IS NULL",
        "CREATE INDEX IF NOT EXISTS idx_project_asset_events_asset ON project_asset_events(asset_id, created_at)",
        "CREATE INDEX IF NOT EXISTS idx_project_asset_events_project ON project_asset_events(project_id, created_at)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_asset_understanding_jobs_idempotency ON asset_understanding_jobs(user_id, project_id, asset_id, idempotency_key)",
        "CREATE INDEX IF NOT EXISTS idx_asset_understanding_jobs_status ON asset_understanding_jobs(project_id, user_id, status, updated_at)",
        "CREATE INDEX IF NOT EXISTS idx_asset_understanding_jobs_asset ON asset_understanding_jobs(asset_id, updated_at)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_asset_understanding_results_job ON asset_understanding_results(job_id)",
        "CREATE INDEX IF NOT EXISTS idx_asset_understanding_results_asset ON asset_understanding_results(asset_id, updated_at)",
        "CREATE INDEX IF NOT EXISTS idx_asset_understanding_tags_asset ON asset_understanding_tags(asset_id, confidence)",
        "CREATE INDEX IF NOT EXISTS idx_asset_understanding_tags_project ON asset_understanding_tags(project_id, key, confidence)",
        "CREATE INDEX IF NOT EXISTS idx_asset_understanding_segments_asset ON asset_understanding_segments(asset_id, start_seconds)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_video_timelines_active_content ON video_timelines(user_id, project_id, content_id, format_preset) WHERE status = 'active'",
        "CREATE INDEX IF NOT EXISTS idx_video_timelines_project ON video_timelines(project_id, user_id, updated_at)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_video_timeline_versions_number ON video_timeline_versions(timeline_id, version_number)",
        "CREATE INDEX IF NOT EXISTS idx_video_timeline_versions_owner ON video_timeline_versions(project_id, user_id, created_at)",
        "CREATE INDEX IF NOT EXISTS idx_video_timeline_jobs_version ON video_timeline_render_jobs(timeline_id, version_id, render_mode, created_at)",
        "CREATE INDEX IF NOT EXISTS idx_video_timeline_jobs_owner ON video_timeline_render_jobs(project_id, user_id, status, updated_at)",
    ]:
        conn.execute(stmt)
    conn.commit()
