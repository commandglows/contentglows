"""DB-backed job store for background tasks (deployment, content generation).

Persists job state in Turso/libsql so jobs survive API restarts.
"""

from __future__ import annotations

import json
import os
from datetime import datetime
from typing import Any

from utils.libsql_async import create_client


class JobStore:
    """Persists async job state in Turso."""

    def __init__(self, db_client: Any | None = None) -> None:
        self.db_client = db_client
        if os.getenv("TURSO_DATABASE_URL") and os.getenv("TURSO_AUTH_TOKEN"):
            if self.db_client is None:
                self.db_client = create_client(
                    url=os.getenv("TURSO_DATABASE_URL"),
                    auth_token=os.getenv("TURSO_AUTH_TOKEN"),
                )

    async def ensure_table(self) -> None:
        """Create jobs table if it doesn't exist (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS jobs (
                job_id    TEXT PRIMARY KEY,
                job_type  TEXT NOT NULL,
                status    TEXT NOT NULL DEFAULT 'pending',
                progress  INTEGER NOT NULL DEFAULT 0,
                message   TEXT,
                user_id   TEXT,
                project_id TEXT,
                org_id TEXT,
                reservation_id TEXT,
                cost_control_status TEXT,
                data      TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        for column_name, column_definition in (
            ("user_id", "TEXT"),
            ("project_id", "TEXT"),
            ("org_id", "TEXT"),
            ("reservation_id", "TEXT"),
            ("cost_control_status", "TEXT"),
        ):
            await self._ensure_column("jobs", column_name, column_definition)
        for statement in (
            "CREATE INDEX IF NOT EXISTS idx_jobs_owner ON jobs(user_id, project_id, updated_at)",
            "CREATE INDEX IF NOT EXISTS idx_jobs_reservation ON jobs(reservation_id)",
            "CREATE INDEX IF NOT EXISTS idx_jobs_cost_control ON jobs(cost_control_status, updated_at)",
        ):
            await self.db_client.execute(statement)

    async def upsert(self, job_id: str, job_type: str, **fields: Any) -> dict[str, Any]:
        """Create or update a job. Extra fields are stored in the `data` JSON column."""
        self._ensure_connected()
        now = datetime.utcnow().isoformat()
        status = fields.pop("status", "pending")
        progress = fields.pop("progress", 0)
        message = fields.pop("message", None)
        user_id = fields.pop("user_id", None)
        project_id = fields.pop("project_id", None)
        org_id = fields.pop("org_id", None)
        reservation_id = fields.pop("reservation_id", None)
        cost_control_status = fields.pop("cost_control_status", None)

        data_json = json.dumps(fields) if fields else None
        await self.db_client.execute(
            """
            INSERT INTO jobs (
                job_id, job_type, status, progress, message, user_id, project_id,
                org_id, reservation_id, cost_control_status, data, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(job_id) DO UPDATE SET
                status = excluded.status,
                progress = excluded.progress,
                message = excluded.message,
                user_id = COALESCE(jobs.user_id, excluded.user_id),
                project_id = COALESCE(jobs.project_id, excluded.project_id),
                org_id = COALESCE(jobs.org_id, excluded.org_id),
                reservation_id = COALESCE(excluded.reservation_id, jobs.reservation_id),
                cost_control_status = COALESCE(excluded.cost_control_status, jobs.cost_control_status),
                data = excluded.data,
                updated_at = excluded.updated_at
            WHERE (jobs.user_id IS NULL OR excluded.user_id IS NULL OR jobs.user_id = excluded.user_id)
              AND (jobs.project_id IS NULL OR excluded.project_id IS NULL OR jobs.project_id = excluded.project_id)
              AND (jobs.org_id IS NULL OR excluded.org_id IS NULL OR jobs.org_id = excluded.org_id)
            """,
            [
                job_id,
                job_type,
                status,
                progress,
                message,
                user_id,
                project_id,
                org_id,
                reservation_id,
                cost_control_status,
                data_json,
                now,
                now,
            ],
        )

        stored = await self.get(job_id) or {}
        self._require_compatible_scope(
            stored,
            user_id=user_id,
            project_id=project_id,
            org_id=org_id,
        )
        return stored

    async def update(self, job_id: str, **fields: Any) -> None:
        """Partial update of a job's mutable fields."""
        self._ensure_connected()
        now = datetime.utcnow().isoformat()

        current = await self.get(job_id)
        if not current:
            return
        status = fields.pop("status", current.get("status", "pending"))
        progress = fields.pop("progress", current.get("progress", 0))
        message = fields.pop("message", current.get("message"))
        user_id = fields.pop("user_id", current.get("user_id"))
        project_id = fields.pop("project_id", current.get("project_id"))
        org_id = fields.pop("org_id", current.get("org_id"))
        reservation_id = fields.pop("reservation_id", current.get("reservation_id"))
        cost_control_status = fields.pop(
            "cost_control_status",
            current.get("cost_control_status"),
        )
        self._require_compatible_scope(
            current,
            user_id=user_id,
            project_id=project_id,
            org_id=org_id,
        )
        existing_data = {
            k: v for k, v in current.items()
            if k not in (
                "job_id", "job_type", "status", "progress", "message",
                "user_id", "project_id", "org_id", "reservation_id",
                "cost_control_status", "created_at", "updated_at",
            )
        }
        existing_data.update(fields)
        data_json = json.dumps(existing_data) if existing_data else None
        await self.db_client.execute(
            """
            UPDATE jobs SET status = ?, progress = ?, message = ?, user_id = ?,
                project_id = ?, org_id = ?, reservation_id = ?,
                cost_control_status = ?, data = ?, updated_at = ?
            WHERE job_id = ?
            """,
            [
                status, progress, message, user_id, project_id, org_id,
                reservation_id, cost_control_status, data_json, now, job_id,
            ],
        )

    async def get(self, job_id: str) -> dict[str, Any] | None:
        """Retrieve a single job by ID."""
        self._ensure_connected()
        rs = await self.db_client.execute(
            f"SELECT {self._fields()} FROM jobs WHERE job_id = ?",
            [job_id],
        )
        if not rs.rows:
            return None
        return self._row_to_dict(rs.rows[0])

    async def list_by_type(self, job_type: str, limit: int = 50) -> list[dict[str, Any]]:
        """List jobs of a given type, most recent first."""
        self._ensure_connected()
        rs = await self.db_client.execute(
            f"SELECT {self._fields()} FROM jobs WHERE job_type = ? ORDER BY created_at DESC LIMIT ?",
            [job_type, limit],
        )
        return [self._row_to_dict(row) for row in rs.rows]

    async def get_owned(
        self,
        job_id: str,
        *,
        user_id: str,
        project_id: str | None = None,
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        query = f"SELECT {self._fields()} FROM jobs WHERE job_id = ? AND user_id = ?"
        args: list[Any] = [job_id, user_id]
        if project_id is not None:
            query += " AND project_id = ?"
            args.append(project_id)
        result = await self.db_client.execute(query, args)
        return self._row_to_dict(result.rows[0]) if result.rows else None

    async def list_owned(
        self,
        *,
        user_id: str,
        project_id: str | None = None,
        job_type: str | None = None,
        cost_control_status: str | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        self._ensure_connected()
        clauses = ["user_id = ?"]
        args: list[Any] = [user_id]
        for column, value in (
            ("project_id", project_id),
            ("job_type", job_type),
            ("cost_control_status", cost_control_status),
        ):
            if value is not None:
                clauses.append(f"{column} = ?")
                args.append(value)
        args.append(max(1, min(limit, 500)))
        result = await self.db_client.execute(
            f"SELECT {self._fields()} FROM jobs WHERE {' AND '.join(clauses)} "
            "ORDER BY updated_at DESC LIMIT ?",
            args,
        )
        return [self._row_to_dict(row) for row in result.rows]

    async def get_by_reservation(
        self,
        reservation_id: str,
        *,
        user_id: str,
        project_id: str,
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        result = await self.db_client.execute(
            f"SELECT {self._fields()} FROM jobs "
            "WHERE reservation_id = ? AND user_id = ? AND project_id = ?",
            [reservation_id, user_id, project_id],
        )
        return self._row_to_dict(result.rows[0]) if result.rows else None

    async def delete(self, job_id: str) -> None:
        """Delete a job."""
        self._ensure_connected()
        await self.db_client.execute("DELETE FROM jobs WHERE job_id = ?", [job_id])

    def _ensure_connected(self) -> None:
        if not self.db_client:
            raise RuntimeError(
                "Job store not configured. Set TURSO_DATABASE_URL and TURSO_AUTH_TOKEN."
            )

    async def _ensure_column(
        self,
        table_name: str,
        column_name: str,
        column_definition: str,
    ) -> None:
        result = await self.db_client.execute(f"PRAGMA table_info({table_name})")
        if any(str(row[1]) == column_name for row in result.rows):
            return
        await self.db_client.execute(
            f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}"
        )

    @staticmethod
    def _fields() -> str:
        return (
            "job_id, job_type, status, progress, message, user_id, project_id, "
            "org_id, reservation_id, cost_control_status, data, created_at, updated_at"
        )

    @staticmethod
    def _require_compatible_scope(
        stored: dict[str, Any],
        *,
        user_id: str | None,
        project_id: str | None,
        org_id: str | None,
    ) -> None:
        for field, requested in (
            ("user_id", user_id),
            ("project_id", project_id),
            ("org_id", org_id),
        ):
            current = stored.get(field)
            if current is not None and requested is not None and current != requested:
                raise ValueError(f"job {field} cannot be reassigned")

    @staticmethod
    def _row_to_dict(row: tuple) -> dict[str, Any]:
        base = {
            "job_id": row[0],
            "job_type": row[1],
            "status": row[2],
            "progress": row[3],
            "message": row[4],
            "user_id": row[5],
            "project_id": row[6],
            "org_id": row[7],
            "reservation_id": row[8],
            "cost_control_status": row[9],
            "created_at": row[11],
            "updated_at": row[12],
        }
        if row[10]:
            try:
                extra = json.loads(row[10])
                protected = {
                    "job_id", "job_type", "status", "progress", "message",
                    "created_at", "updated_at",
                }
                scoped = {
                    "user_id", "project_id", "org_id", "reservation_id",
                    "cost_control_status",
                }
                for key, value in extra.items():
                    if key in protected:
                        continue
                    if key in scoped and base.get(key) is not None:
                        continue
                    base[key] = value
            except (json.JSONDecodeError, TypeError):
                pass
        return base


# Singleton
job_store = JobStore()
