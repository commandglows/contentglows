"""Persistent store for canonical ContentGlows video timelines."""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime
from typing import Any

from utils.libsql_async import create_client


VIDEO_TIMELINES_SQL = """
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
"""

VIDEO_VERSIONS_SQL = """
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
"""

VIDEO_JOBS_SQL = """
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
"""


class VideoTimelineStoreError(RuntimeError):
    """Base store error."""


class VideoTimelineNotFoundError(VideoTimelineStoreError):
    """Raised when a timeline/version/job cannot be found for the owner."""


class VideoTimelineConflictError(VideoTimelineStoreError):
    """Raised when optimistic concurrency fails."""


class VideoTimelineStore:
    """Async libSQL store for timeline drafts, immutable versions and render links."""

    def __init__(self, db_client: Any | None = None) -> None:
        self.db_client = db_client
        if self.db_client is None and os.getenv("TURSO_DATABASE_URL") and os.getenv("TURSO_AUTH_TOKEN"):
            self.db_client = create_client(
                url=os.getenv("TURSO_DATABASE_URL"),
                auth_token=os.getenv("TURSO_AUTH_TOKEN"),
            )

    async def ensure_tables(self) -> None:
        self._ensure_connected()
        await self.db_client.execute(VIDEO_TIMELINES_SQL)
        await self.db_client.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_video_timelines_active_content
            ON video_timelines(user_id, project_id, content_id, format_preset)
            WHERE status = 'active'
            """
        )
        await self.db_client.execute(
            "CREATE INDEX IF NOT EXISTS idx_video_timelines_project ON video_timelines(project_id, user_id, updated_at)"
        )
        await self.db_client.execute(VIDEO_VERSIONS_SQL)
        await self.db_client.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_video_timeline_versions_number ON video_timeline_versions(timeline_id, version_number)"
        )
        await self.db_client.execute(
            "CREATE INDEX IF NOT EXISTS idx_video_timeline_versions_owner ON video_timeline_versions(project_id, user_id, created_at)"
        )
        await self.db_client.execute(VIDEO_JOBS_SQL)
        await self.db_client.execute(
            "CREATE INDEX IF NOT EXISTS idx_video_timeline_jobs_version ON video_timeline_render_jobs(timeline_id, version_id, render_mode, created_at)"
        )
        await self.db_client.execute(
            "CREATE INDEX IF NOT EXISTS idx_video_timeline_jobs_owner ON video_timeline_render_jobs(project_id, user_id, status, updated_at)"
        )

    async def create_or_get_active(
        self,
        *,
        user_id: str,
        project_id: str,
        content_id: str,
        format_preset: str,
        draft: dict[str, Any],
    ) -> tuple[dict[str, Any], bool]:
        self._ensure_connected()
        existing = await self.get_active_by_content(
            user_id=user_id,
            project_id=project_id,
            content_id=content_id,
            format_preset=format_preset,
        )
        if existing:
            return existing, False

        now = datetime.utcnow().isoformat()
        timeline_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO video_timelines (
                id, user_id, project_id, content_id, format_preset, status,
                current_version_id, draft_revision, draft_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, 'active', NULL, 0, ?, ?, ?)
            """,
            [
                timeline_id,
                user_id,
                project_id,
                content_id,
                format_preset,
                json.dumps(draft, separators=(",", ":"), sort_keys=True),
                now,
                now,
            ],
        )
        timeline = await self.get_timeline(timeline_id=timeline_id, user_id=user_id)
        return timeline, True

    async def get_active_by_content(
        self,
        *,
        user_id: str,
        project_id: str,
        content_id: str,
        format_preset: str,
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, user_id, project_id, content_id, format_preset, status,
                   current_version_id, draft_revision, draft_json, created_at, updated_at
            FROM video_timelines
            WHERE user_id = ? AND project_id = ? AND content_id = ?
              AND format_preset = ? AND status = 'active'
            LIMIT 1
            """,
            [user_id, project_id, content_id, format_preset],
        )
        if not rs.rows:
            return None
        return self._timeline_row_to_dict(rs.rows[0])

    async def get_timeline(self, *, timeline_id: str, user_id: str) -> dict[str, Any]:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, user_id, project_id, content_id, format_preset, status,
                   current_version_id, draft_revision, draft_json, created_at, updated_at
            FROM video_timelines
            WHERE id = ? AND user_id = ? AND status = 'active'
            LIMIT 1
            """,
            [timeline_id, user_id],
        )
        if not rs.rows:
            raise VideoTimelineNotFoundError("Timeline not found")
        return self._timeline_row_to_dict(rs.rows[0])

    async def save_draft(
        self,
        *,
        timeline_id: str,
        user_id: str,
        base_version_id: str | None,
        draft_revision: int,
        timeline: dict[str, Any],
    ) -> dict[str, Any]:
        current = await self.get_timeline(timeline_id=timeline_id, user_id=user_id)
        self._assert_edit_base(current, base_version_id=base_version_id, draft_revision=draft_revision)
        now = datetime.utcnow().isoformat()
        next_revision = int(current["draft_revision"]) + 1
        await self.db_client.execute(
            """
            UPDATE video_timelines
            SET draft_json = ?, draft_revision = ?, updated_at = ?
            WHERE id = ? AND user_id = ?
            """,
            [
                json.dumps(timeline, separators=(",", ":"), sort_keys=True),
                next_revision,
                now,
                timeline_id,
                user_id,
            ],
        )
        return await self.get_timeline(timeline_id=timeline_id, user_id=user_id)

    async def create_version(
        self,
        *,
        timeline_id: str,
        user_id: str,
        version_id: str | None = None,
        base_version_id: str | None,
        draft_revision: int,
        timeline: dict[str, Any],
        renderer_props: dict[str, Any],
        client_request_id: str | None = None,
    ) -> dict[str, Any]:
        current = await self.get_timeline(timeline_id=timeline_id, user_id=user_id)
        if client_request_id:
            existing = await self.get_version_by_client_request(
                timeline_id=timeline_id,
                user_id=user_id,
                client_request_id=client_request_id,
            )
            if existing:
                return existing
        self._assert_edit_base(current, base_version_id=base_version_id, draft_revision=draft_revision)

        next_number = await self._next_version_number(timeline_id)
        version_id = version_id or str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            INSERT INTO video_timeline_versions (
                id, timeline_id, user_id, project_id, content_id, format_preset,
                version_number, timeline_json, renderer_props_json,
                approved_preview_job_id, preview_approved_at, client_request_id, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?)
            """,
            [
                version_id,
                timeline_id,
                user_id,
                current["project_id"],
                current["content_id"],
                current["format_preset"],
                next_number,
                json.dumps(timeline, separators=(",", ":"), sort_keys=True),
                json.dumps(renderer_props, separators=(",", ":"), sort_keys=True),
                client_request_id,
                now,
            ],
        )
        await self.db_client.execute(
            """
            UPDATE video_timelines
            SET current_version_id = ?, draft_json = ?, draft_revision = ?, updated_at = ?
            WHERE id = ? AND user_id = ?
            """,
            [
                version_id,
                json.dumps(timeline, separators=(",", ":"), sort_keys=True),
                int(current["draft_revision"]) + 1,
                now,
                timeline_id,
                user_id,
            ],
        )
        await self.db_client.execute(
            """
            UPDATE video_timeline_render_jobs
            SET stale = 1, updated_at = ?
            WHERE timeline_id = ? AND user_id = ? AND version_id <> ?
            """,
            [now, timeline_id, user_id, version_id],
        )
        return await self.get_version(version_id=version_id, user_id=user_id)

    async def get_version(self, *, version_id: str, user_id: str) -> dict[str, Any]:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, timeline_id, user_id, project_id, content_id, format_preset,
                   version_number, timeline_json, renderer_props_json,
                   approved_preview_job_id, preview_approved_at, client_request_id, created_at
            FROM video_timeline_versions
            WHERE id = ? AND user_id = ?
            LIMIT 1
            """,
            [version_id, user_id],
        )
        if not rs.rows:
            raise VideoTimelineNotFoundError("Timeline version not found")
        return self._version_row_to_dict(rs.rows[0])

    async def get_version_by_client_request(
        self,
        *,
        timeline_id: str,
        user_id: str,
        client_request_id: str,
    ) -> dict[str, Any] | None:
        rs = await self.db_client.execute(
            """
            SELECT id, timeline_id, user_id, project_id, content_id, format_preset,
                   version_number, timeline_json, renderer_props_json,
                   approved_preview_job_id, preview_approved_at, client_request_id, created_at
            FROM video_timeline_versions
            WHERE timeline_id = ? AND user_id = ? AND client_request_id = ?
            LIMIT 1
            """,
            [timeline_id, user_id, client_request_id],
        )
        if not rs.rows:
            return None
        return self._version_row_to_dict(rs.rows[0])

    async def approve_preview(self, *, version_id: str, user_id: str, preview_job_id: str) -> dict[str, Any]:
        version = await self.get_version(version_id=version_id, user_id=user_id)
        job = await self.get_job(job_id=preview_job_id, user_id=user_id)
        if (
            job["version_id"] != version_id
            or job["timeline_id"] != version["timeline_id"]
            or job["render_mode"] != "preview"
            or job["status"] != "completed"
            or job["stale"]
            or not job.get("artifact")
        ):
            raise VideoTimelineConflictError("Preview job cannot be approved")
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            UPDATE video_timeline_versions
            SET approved_preview_job_id = ?, preview_approved_at = ?
            WHERE id = ? AND user_id = ?
            """,
            [preview_job_id, now, version_id, user_id],
        )
        return await self.get_version(version_id=version_id, user_id=user_id)

    async def create_render_job(
        self,
        *,
        job_id: str,
        timeline_id: str,
        version_id: str,
        user_id: str,
        project_id: str,
        render_mode: str,
        status: str,
        progress: int = 0,
        message: str | None = None,
        artifact: dict[str, Any] | None = None,
        worker_job_id: str | None = None,
        parent_preview_job_id: str | None = None,
        client_request_id: str | None = None,
    ) -> dict[str, Any]:
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            INSERT INTO video_timeline_render_jobs (
                job_id, timeline_id, version_id, user_id, project_id, render_mode,
                status, progress, message, artifact_json, worker_job_id,
                parent_preview_job_id, client_request_id, stale, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
            """,
            [
                job_id,
                timeline_id,
                version_id,
                user_id,
                project_id,
                render_mode,
                status,
                progress,
                message,
                json.dumps(artifact, separators=(",", ":"), sort_keys=True) if artifact else None,
                worker_job_id,
                parent_preview_job_id,
                client_request_id,
                now,
                now,
            ],
        )
        return await self.get_job(job_id=job_id, user_id=user_id)

    async def update_render_job(self, *, job_id: str, user_id: str, **fields: Any) -> dict[str, Any]:
        current = await self.get_job(job_id=job_id, user_id=user_id)
        allowed = {
            "status",
            "progress",
            "message",
            "artifact",
            "worker_job_id",
            "stale",
        }
        updates = {key: value for key, value in fields.items() if key in allowed}
        if not updates:
            return current
        if "artifact" in updates:
            artifact_value = updates.pop("artifact")
            updates["artifact_json"] = (
                json.dumps(artifact_value, separators=(",", ":"), sort_keys=True)
                if artifact_value is not None
                else None
            )
        updates["updated_at"] = datetime.utcnow().isoformat()
        set_clause = ", ".join(f"{key} = ?" for key in updates)
        await self.db_client.execute(
            f"UPDATE video_timeline_render_jobs SET {set_clause} WHERE job_id = ? AND user_id = ?",
            list(updates.values()) + [job_id, user_id],
        )
        return await self.get_job(job_id=job_id, user_id=user_id)

    async def get_job(self, *, job_id: str, user_id: str) -> dict[str, Any]:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT job_id, timeline_id, version_id, user_id, project_id, render_mode,
                   status, progress, message, artifact_json, worker_job_id,
                   parent_preview_job_id, client_request_id, stale, created_at, updated_at
            FROM video_timeline_render_jobs
            WHERE job_id = ? AND user_id = ?
            LIMIT 1
            """,
            [job_id, user_id],
        )
        if not rs.rows:
            raise VideoTimelineNotFoundError("Render job not found")
        return self._job_row_to_dict(rs.rows[0])

    async def get_job_for_signed_artifact(self, *, job_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT job_id, timeline_id, version_id, user_id, project_id, render_mode,
                   status, progress, message, artifact_json, worker_job_id,
                   parent_preview_job_id, client_request_id, stale, created_at, updated_at
            FROM video_timeline_render_jobs
            WHERE job_id = ?
            LIMIT 1
            """,
            [job_id],
        )
        if not rs.rows:
            return None
        return self._job_row_to_dict(rs.rows[0])

    async def find_render_job(
        self,
        *,
        timeline_id: str,
        version_id: str,
        user_id: str,
        render_mode: str,
        statuses: set[str],
        parent_preview_job_id: str | None = None,
    ) -> dict[str, Any] | None:
        rows = await self.list_render_jobs(
            timeline_id=timeline_id,
            version_id=version_id,
            user_id=user_id,
            render_mode=render_mode,
        )
        for job in rows:
            if job["status"] not in statuses or job["stale"]:
                continue
            if parent_preview_job_id is not None and job.get("parent_preview_job_id") != parent_preview_job_id:
                continue
            return job
        return None

    async def list_render_jobs(
        self,
        *,
        timeline_id: str,
        version_id: str,
        user_id: str,
        render_mode: str | None = None,
    ) -> list[dict[str, Any]]:
        self._ensure_connected()
        query = """
            SELECT job_id, timeline_id, version_id, user_id, project_id, render_mode,
                   status, progress, message, artifact_json, worker_job_id,
                   parent_preview_job_id, client_request_id, stale, created_at, updated_at
            FROM video_timeline_render_jobs
            WHERE timeline_id = ? AND version_id = ? AND user_id = ?
        """
        params: list[Any] = [timeline_id, version_id, user_id]
        if render_mode:
            query += " AND render_mode = ?"
            params.append(render_mode)
        query += " ORDER BY created_at DESC"
        rs = await self.db_client.execute(query, params)
        return [self._job_row_to_dict(row) for row in rs.rows]

    async def list_active_render_jobs(self, *, limit: int = 500) -> list[dict[str, Any]]:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT job_id, timeline_id, version_id, user_id, project_id, render_mode,
                   status, progress, message, artifact_json, worker_job_id,
                   parent_preview_job_id, client_request_id, stale, created_at, updated_at
            FROM video_timeline_render_jobs
            WHERE status IN ('queued', 'in_progress') AND stale = 0
            ORDER BY created_at DESC
            LIMIT ?
            """,
            [limit],
        )
        return [self._job_row_to_dict(row) for row in rs.rows]

    async def _next_version_number(self, timeline_id: str) -> int:
        rs = await self.db_client.execute(
            "SELECT COALESCE(MAX(version_number), 0) FROM video_timeline_versions WHERE timeline_id = ?",
            [timeline_id],
        )
        return int(rs.rows[0][0] or 0) + 1

    @staticmethod
    def _assert_edit_base(
        current: dict[str, Any],
        *,
        base_version_id: str | None,
        draft_revision: int,
    ) -> None:
        if int(current["draft_revision"]) != draft_revision:
            raise VideoTimelineConflictError("Timeline draft revision is stale")
        if current.get("current_version_id") != base_version_id:
            raise VideoTimelineConflictError("Timeline base version is stale")

    def _ensure_connected(self) -> None:
        if not self.db_client:
            raise RuntimeError(
                "Video timeline store not configured. Set TURSO_DATABASE_URL and TURSO_AUTH_TOKEN."
            )

    @staticmethod
    def _loads(value: str | None, fallback: Any) -> Any:
        if not value:
            return fallback
        try:
            return json.loads(value)
        except (json.JSONDecodeError, TypeError):
            return fallback

    @classmethod
    def _timeline_row_to_dict(cls, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "user_id": row[1],
            "project_id": row[2],
            "content_id": row[3],
            "format_preset": row[4],
            "status": row[5],
            "current_version_id": row[6],
            "draft_revision": row[7],
            "draft": cls._loads(row[8], {}),
            "created_at": row[9],
            "updated_at": row[10],
        }

    @classmethod
    def _version_row_to_dict(cls, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "timeline_id": row[1],
            "user_id": row[2],
            "project_id": row[3],
            "content_id": row[4],
            "format_preset": row[5],
            "version_number": row[6],
            "timeline": cls._loads(row[7], {}),
            "renderer_props": cls._loads(row[8], {}),
            "approved_preview_job_id": row[9],
            "preview_approved_at": row[10],
            "client_request_id": row[11],
            "created_at": row[12],
        }

    @classmethod
    def _job_row_to_dict(cls, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "job_id": row[0],
            "timeline_id": row[1],
            "version_id": row[2],
            "user_id": row[3],
            "project_id": row[4],
            "render_mode": row[5],
            "status": row[6],
            "progress": row[7],
            "message": row[8],
            "artifact": cls._loads(row[9], None),
            "worker_job_id": row[10],
            "parent_preview_job_id": row[11],
            "client_request_id": row[12],
            "stale": bool(row[13]),
            "created_at": row[14],
            "updated_at": row[15],
        }


video_timeline_store = VideoTimelineStore()
