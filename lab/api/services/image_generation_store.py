"""Persistent image generation and visual reference store.

This store is intentionally project-scoped and user-scoped. It backs async AI
image jobs and the approved visual references used by guided Image Robot flows.
"""

from __future__ import annotations

import hashlib
import json
import os
import uuid
from datetime import datetime
from typing import Any, Optional

from utils.libsql_async import create_client


IMAGE_GENERATION_COLUMNS = (
    "id",
    "project_id",
    "user_id",
    "profile_id",
    "provider",
    "model",
    "status",
    "job_id",
    "reservation_id",
    "prompt",
    "prompt_hash",
    "width",
    "height",
    "seed",
    "output_format",
    "cdn_url",
    "primary_url",
    "responsive_urls_json",
    "reference_ids_json",
    "visual_memory_applied",
    "provider_cost",
    "provider_request_id",
    "error_code",
    "error_message",
    "asset_id",
    "provider_metadata_json",
    "created_at",
    "updated_at",
    "started_at",
    "completed_at",
)

IMAGE_REFERENCE_COLUMNS = (
    "id",
    "project_id",
    "user_id",
    "cdn_url",
    "primary_url",
    "mime_type",
    "width",
    "height",
    "label",
    "reference_type",
    "approved",
    "created_at",
    "updated_at",
)


class ImageGenerationStore:
    """Turso/libSQL store for Flux generation history and visual references."""

    def __init__(self, db_client: Any | None = None) -> None:
        self.db_client = db_client
        if self.db_client is None and os.getenv("TURSO_DATABASE_URL") and os.getenv("TURSO_AUTH_TOKEN"):
            self.db_client = create_client(
                url=os.getenv("TURSO_DATABASE_URL"),
                auth_token=os.getenv("TURSO_AUTH_TOKEN"),
            )

    async def ensure_tables(self) -> None:
        """Create image generation tables and indexes if needed."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS ImageGeneration (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                profile_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                model TEXT NOT NULL,
                status TEXT NOT NULL,
                job_id TEXT,
                reservation_id TEXT,
                prompt TEXT NOT NULL,
                prompt_hash TEXT NOT NULL,
                width INTEGER NOT NULL,
                height INTEGER NOT NULL,
                seed INTEGER,
                output_format TEXT NOT NULL,
                cdn_url TEXT,
                primary_url TEXT,
                responsive_urls_json TEXT NOT NULL DEFAULT '{}',
                reference_ids_json TEXT NOT NULL DEFAULT '[]',
                visual_memory_applied INTEGER NOT NULL DEFAULT 0,
                provider_cost REAL,
                provider_request_id TEXT,
                error_code TEXT,
                error_message TEXT,
                asset_id TEXT,
                provider_metadata_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                started_at TEXT,
                completed_at TEXT
            )
            """
        )
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS ImageReference (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                cdn_url TEXT NOT NULL,
                primary_url TEXT,
                mime_type TEXT NOT NULL,
                width INTEGER,
                height INTEGER,
                label TEXT,
                reference_type TEXT NOT NULL DEFAULT 'project_asset',
                approved INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        for statement in (
            "CREATE INDEX IF NOT EXISTS idx_image_generation_project ON ImageGeneration(project_id, created_at)",
            "CREATE INDEX IF NOT EXISTS idx_image_generation_user ON ImageGeneration(user_id, created_at)",
            "CREATE INDEX IF NOT EXISTS idx_image_generation_job ON ImageGeneration(job_id)",
            "CREATE INDEX IF NOT EXISTS idx_image_reference_project ON ImageReference(project_id, approved, created_at)",
            "CREATE INDEX IF NOT EXISTS idx_image_reference_user ON ImageReference(user_id, created_at)",
        ):
            await self.db_client.execute(statement)
        await self._ensure_column(
            "ImageGeneration",
            "reservation_id",
            "TEXT",
        )
        await self.db_client.execute(
            "CREATE INDEX IF NOT EXISTS idx_image_generation_reservation ON ImageGeneration(reservation_id)"
        )

    async def create_generation(
        self,
        *,
        project_id: str,
        user_id: str,
        profile_id: str,
        provider: str,
        model: str,
        job_id: str,
        prompt: str,
        width: int,
        height: int,
        seed: int | None = None,
        output_format: str = "jpeg",
        reference_ids: list[str] | None = None,
        visual_memory_applied: bool = False,
        reservation_id: str | None = None,
    ) -> dict[str, Any]:
        self._ensure_connected()
        now = datetime.utcnow().isoformat()
        generation_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO ImageGeneration (
                id, project_id, user_id, profile_id, provider, model, status, job_id,
                reservation_id,
                prompt, prompt_hash, width, height, seed, output_format, cdn_url,
                primary_url, responsive_urls_json, reference_ids_json,
                visual_memory_applied, provider_cost, provider_request_id,
                error_code, error_message, asset_id, provider_metadata_json,
                created_at, updated_at, started_at, completed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                generation_id,
                project_id,
                user_id,
                profile_id,
                provider,
                model,
                "queued",
                job_id,
                reservation_id,
                prompt,
                prompt_hash(prompt),
                width,
                height,
                seed,
                output_format,
                None,
                None,
                "{}",
                json.dumps(reference_ids or []),
                1 if visual_memory_applied else 0,
                None,
                None,
                None,
                None,
                None,
                "{}",
                now,
                now,
                None,
                None,
            ],
        )
        return await self.get_generation(generation_id, user_id=user_id) or {}

    async def mark_running(
        self,
        generation_id: str,
        *,
        user_id: str,
        provider_request_id: str | None = None,
        provider_cost: float | None = None,
        provider_metadata: dict[str, Any] | None = None,
    ) -> None:
        self._ensure_connected()
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            UPDATE ImageGeneration
            SET status = ?, provider_request_id = COALESCE(?, provider_request_id),
                provider_cost = COALESCE(?, provider_cost),
                provider_metadata_json = ?, started_at = COALESCE(started_at, ?),
                updated_at = ?, error_code = NULL, error_message = NULL
            WHERE id = ? AND user_id = ?
            """,
            [
                "running",
                provider_request_id,
                provider_cost,
                json.dumps(provider_metadata or {}),
                now,
                now,
                generation_id,
                user_id,
            ],
        )

    async def mark_completed(
        self,
        generation_id: str,
        *,
        user_id: str,
        cdn_url: str,
        primary_url: str | None,
        responsive_urls: dict[str, str] | None = None,
        asset_id: str | None = None,
        provider_request_id: str | None = None,
        provider_cost: float | None = None,
        provider_metadata: dict[str, Any] | None = None,
    ) -> None:
        self._ensure_connected()
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            UPDATE ImageGeneration
            SET status = ?, cdn_url = ?, primary_url = ?,
                responsive_urls_json = ?, asset_id = ?,
                provider_request_id = COALESCE(?, provider_request_id),
                provider_cost = COALESCE(?, provider_cost),
                provider_metadata_json = ?, error_code = NULL, error_message = NULL,
                updated_at = ?, completed_at = ?
            WHERE id = ? AND user_id = ?
            """,
            [
                "completed",
                cdn_url,
                primary_url,
                json.dumps(responsive_urls or {}),
                asset_id,
                provider_request_id,
                provider_cost,
                json.dumps(provider_metadata or {}),
                now,
                now,
                generation_id,
                user_id,
            ],
        )

    async def mark_failed(
        self,
        generation_id: str,
        *,
        user_id: str,
        error_code: str,
        error_message: str,
        provider_request_id: str | None = None,
        provider_metadata: dict[str, Any] | None = None,
    ) -> None:
        self._ensure_connected()
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            UPDATE ImageGeneration
            SET status = ?, error_code = ?, error_message = ?,
                provider_request_id = COALESCE(?, provider_request_id),
                provider_metadata_json = ?, updated_at = ?, completed_at = ?
            WHERE id = ? AND user_id = ?
            """,
            [
                "failed",
                error_code,
                error_message[:1000],
                provider_request_id,
                json.dumps(provider_metadata or {}),
                now,
                now,
                generation_id,
                user_id,
            ],
        )

    async def get_generation(self, generation_id: str, *, user_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        fields = ", ".join(IMAGE_GENERATION_COLUMNS)
        rs = await self.db_client.execute(
            f"SELECT {fields} FROM ImageGeneration WHERE id = ? AND user_id = ?",
            [generation_id, user_id],
        )
        if not rs.rows:
            return None
        return _generation_row_to_dict(rs.rows[0])

    async def list_generations(
        self,
        *,
        project_id: str,
        user_id: str,
        limit: int = 30,
    ) -> list[dict[str, Any]]:
        self._ensure_connected()
        fields = ", ".join(IMAGE_GENERATION_COLUMNS)
        rs = await self.db_client.execute(
            f"""
            SELECT {fields} FROM ImageGeneration
            WHERE project_id = ? AND user_id = ?
            ORDER BY created_at DESC
            LIMIT ?
            """,
            [project_id, user_id, limit],
        )
        return [_generation_row_to_dict(row) for row in rs.rows]

    async def create_reference(
        self,
        *,
        project_id: str,
        user_id: str,
        cdn_url: str,
        primary_url: str | None = None,
        mime_type: str = "image/jpeg",
        width: int | None = None,
        height: int | None = None,
        label: str | None = None,
        reference_type: str = "project_asset",
        approved: bool = True,
    ) -> dict[str, Any]:
        self._ensure_connected()
        now = datetime.utcnow().isoformat()
        reference_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO ImageReference (
                id, project_id, user_id, cdn_url, primary_url, mime_type, width,
                height, label, reference_type, approved, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                reference_id,
                project_id,
                user_id,
                cdn_url,
                primary_url,
                mime_type,
                width,
                height,
                label,
                reference_type,
                1 if approved else 0,
                now,
                now,
            ],
        )
        return await self.get_reference(reference_id, project_id=project_id, user_id=user_id) or {}

    async def get_reference(
        self,
        reference_id: str,
        *,
        project_id: str,
        user_id: str,
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        fields = ", ".join(IMAGE_REFERENCE_COLUMNS)
        rs = await self.db_client.execute(
            f"SELECT {fields} FROM ImageReference WHERE id = ? AND project_id = ? AND user_id = ?",
            [reference_id, project_id, user_id],
        )
        if not rs.rows:
            return None
        return _reference_row_to_dict(rs.rows[0])

    async def list_references(
        self,
        *,
        project_id: str,
        user_id: str,
        approved_only: bool = False,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        self._ensure_connected()
        fields = ", ".join(IMAGE_REFERENCE_COLUMNS)
        query = f"SELECT {fields} FROM ImageReference WHERE project_id = ? AND user_id = ?"
        params: list[Any] = [project_id, user_id]
        if approved_only:
            query += " AND approved = 1"
        query += " ORDER BY updated_at DESC, id DESC LIMIT ?"
        params.append(limit)
        rs = await self.db_client.execute(query, params)
        return [_reference_row_to_dict(row) for row in rs.rows]

    async def set_reference_approved(
        self,
        reference_id: str,
        *,
        project_id: str,
        user_id: str,
        approved: bool,
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            UPDATE ImageReference
            SET approved = ?, updated_at = ?
            WHERE id = ? AND project_id = ? AND user_id = ?
            """,
            [1 if approved else 0, now, reference_id, project_id, user_id],
        )
        return await self.get_reference(reference_id, project_id=project_id, user_id=user_id)

    async def update_reference(
        self,
        reference_id: str,
        *,
        project_id: str,
        user_id: str,
        approved: bool | None = None,
        label: str | None = None,
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        existing = await self.get_reference(reference_id, project_id=project_id, user_id=user_id)
        if not existing:
            return None
        now = datetime.utcnow().isoformat()
        await self.db_client.execute(
            """
            UPDATE ImageReference
            SET approved = ?, label = ?, updated_at = ?
            WHERE id = ? AND project_id = ? AND user_id = ?
            """,
            [
                1 if (existing["approved"] if approved is None else approved) else 0,
                existing["label"] if label is None else label,
                now,
                reference_id,
                project_id,
                user_id,
            ],
        )
        return await self.get_reference(reference_id, project_id=project_id, user_id=user_id)

    async def delete_reference(
        self,
        reference_id: str,
        *,
        project_id: str,
        user_id: str,
    ) -> None:
        self._ensure_connected()
        await self.db_client.execute(
            "DELETE FROM ImageReference WHERE id = ? AND project_id = ? AND user_id = ?",
            [reference_id, project_id, user_id],
        )

    def _ensure_connected(self) -> None:
        if not self.db_client:
            raise RuntimeError(
                "Image generation store not configured. Set TURSO_DATABASE_URL and TURSO_AUTH_TOKEN."
            )

    async def _ensure_column(
        self,
        table_name: str,
        column_name: str,
        column_definition: str,
    ) -> None:
        columns = await self.db_client.execute(f"PRAGMA table_info({table_name})")
        if any(str(row[1]) == column_name for row in columns.rows):
            return
        await self.db_client.execute(
            f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}"
        )


def prompt_hash(prompt: str) -> str:
    """Stable prompt hash for duplicate/debug analysis without exposing raw prompt."""
    return hashlib.sha256(prompt.encode("utf-8")).hexdigest()


def _loads_json(value: Any, fallback: Any) -> Any:
    if not value:
        return fallback
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return fallback


def _generation_row_to_dict(row: tuple[Any, ...]) -> dict[str, Any]:
    data = dict(zip(IMAGE_GENERATION_COLUMNS, row))
    data["responsive_urls"] = _loads_json(data.pop("responsive_urls_json"), {})
    data["reference_ids"] = _loads_json(data.pop("reference_ids_json"), [])
    data["provider_metadata"] = _loads_json(data.pop("provider_metadata_json"), {})
    data["visual_memory_applied"] = bool(data["visual_memory_applied"])
    return data


def _reference_row_to_dict(row: tuple[Any, ...]) -> dict[str, Any]:
    data = dict(zip(IMAGE_REFERENCE_COLUMNS, row))
    data["approved"] = bool(data["approved"])
    return data


image_generation_store = ImageGenerationStore()
