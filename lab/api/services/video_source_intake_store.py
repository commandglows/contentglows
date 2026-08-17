"""Durable Turso/libSQL store for revisioned multimodal source intake."""

from __future__ import annotations

import json
import os
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from utils.libsql_async import create_client


ACTIVE_SOURCE_STATUSES = {
    "pending_validation",
    "processing",
    "ready",
    "metadata_unavailable",
    "failed",
    "replacement_pending",
    "orphan_cleanup_needed",
}
READINESS_BLOCKING_STATUSES = ACTIVE_SOURCE_STATUSES - {"ready"}


def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


def _json_dump(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)


def _json_load(value: Any, fallback: Any) -> Any:
    if value is None:
        return fallback
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, bytes):
        value = value.decode("utf-8", errors="ignore")
    try:
        return json.loads(value)
    except (TypeError, ValueError):
        return fallback


class IntakeStoreError(RuntimeError):
    pass


class IntakeNotFoundError(IntakeStoreError):
    pass


class IntakeConflictError(IntakeStoreError):
    def __init__(self, code: str, message: str, *, source_ids: list[str] | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.source_ids = source_ids or []


class VideoSourceIntakeStore:
    def __init__(self, db_client: Any | None = None) -> None:
        self.db_client = db_client
        if self.db_client is None and os.getenv("TURSO_DATABASE_URL") and os.getenv("TURSO_AUTH_TOKEN"):
            self.db_client = create_client(
                url=os.environ["TURSO_DATABASE_URL"],
                auth_token=os.environ["TURSO_AUTH_TOKEN"],
            )

    def _ensure_connected(self) -> None:
        if not self.db_client:
            raise RuntimeError("Database not configured. Set TURSO_DATABASE_URL and TURSO_AUTH_TOKEN.")

    async def ensure_tables(self) -> None:
        self._ensure_connected()
        statements = [
            """
            CREATE TABLE IF NOT EXISTS video_source_folders (
                id TEXT PRIMARY KEY, user_id TEXT NOT NULL, project_id TEXT NOT NULL,
                content_id TEXT NOT NULL, purpose TEXT NOT NULL DEFAULT 'video_source_intake',
                status TEXT NOT NULL DEFAULT 'collecting', revision INTEGER NOT NULL DEFAULT 0,
                ready_revision INTEGER, ready_by TEXT, ready_at TEXT,
                enqueue_status TEXT NOT NULL DEFAULT 'not_requested', generation_request_id TEXT,
                generation_error_code TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
                archived_at TEXT
            )
            """,
            """CREATE UNIQUE INDEX IF NOT EXISTS idx_video_source_folder_active
               ON video_source_folders(user_id, project_id, content_id, purpose)
               WHERE archived_at IS NULL""",
            """
            CREATE TABLE IF NOT EXISTS video_sources (
                id TEXT PRIMARY KEY, folder_id TEXT NOT NULL, user_id TEXT NOT NULL,
                project_id TEXT NOT NULL, source_type TEXT NOT NULL, status TEXT NOT NULL,
                asset_id TEXT, text_body TEXT, text_preview TEXT, raw_hash TEXT,
                normalized_hash TEXT, canonical_url TEXT, link_hostname TEXT,
                safe_metadata_json TEXT NOT NULL DEFAULT '{}', error_code TEXT,
                retryable INTEGER NOT NULL DEFAULT 0, idempotency_key TEXT NOT NULL,
                replacement_of_source_id TEXT, superseded_by_source_id TEXT,
                created_at TEXT NOT NULL, updated_at TEXT NOT NULL, removed_at TEXT
            )
            """,
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_video_source_idempotency ON video_sources(folder_id, idempotency_key)",
            "CREATE INDEX IF NOT EXISTS idx_video_sources_folder_active ON video_sources(folder_id, status, updated_at)",
            "CREATE INDEX IF NOT EXISTS idx_video_sources_asset ON video_sources(asset_id)",
            """
            CREATE TABLE IF NOT EXISTS video_source_upload_sessions (
                id TEXT PRIMARY KEY, source_id TEXT NOT NULL, folder_id TEXT NOT NULL,
                user_id TEXT NOT NULL, project_id TEXT NOT NULL, content_id TEXT NOT NULL,
                expected_revision INTEGER NOT NULL, source_type TEXT NOT NULL,
                file_name TEXT NOT NULL, mime_type TEXT NOT NULL, byte_size INTEGER NOT NULL,
                checksum_sha256 TEXT NOT NULL, provider_namespace TEXT NOT NULL,
                mode TEXT NOT NULL,
                provider_state_json TEXT NOT NULL DEFAULT '{}', status TEXT NOT NULL,
                idempotency_key TEXT NOT NULL, locator_json TEXT, expires_at TEXT NOT NULL,
                created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            )
            """,
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_video_source_upload_idempotency ON video_source_upload_sessions(folder_id, idempotency_key)",
            """
            CREATE TABLE IF NOT EXISTS video_source_generation_handoffs (
                id TEXT PRIMARY KEY, folder_id TEXT NOT NULL, user_id TEXT NOT NULL,
                project_id TEXT NOT NULL, content_id TEXT NOT NULL, ready_revision INTEGER NOT NULL,
                idempotency_key TEXT NOT NULL, descriptor_json TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'enqueue_pending', canonical_request_id TEXT,
                error_code TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            )
            """,
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_video_source_handoff_idempotency ON video_source_generation_handoffs(folder_id, ready_revision, idempotency_key)",
        ]
        for statement in statements:
            await self.db_client.execute(statement)

    @staticmethod
    def _folder(row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0], "user_id": row[1], "project_id": row[2], "content_id": row[3],
            "purpose": row[4], "status": row[5], "revision": int(row[6]),
            "ready_revision": int(row[7]) if row[7] is not None else None,
            "ready_by": row[8], "ready_at": row[9], "enqueue_status": row[10],
            "generation_request_id": row[11], "generation_error_code": row[12],
            "created_at": row[13], "updated_at": row[14], "archived_at": row[15],
        }

    @staticmethod
    def _source(row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0], "folder_id": row[1], "user_id": row[2], "project_id": row[3],
            "source_type": row[4], "status": row[5], "asset_id": row[6],
            "text_body": row[7], "text_preview": row[8], "raw_hash": row[9],
            "normalized_hash": row[10], "canonical_url": row[11], "link_hostname": row[12],
            "safe_metadata": _json_load(row[13], {}), "error_code": row[14],
            "retryable": bool(row[15]), "idempotency_key": row[16],
            "replacement_of_source_id": row[17], "superseded_by_source_id": row[18],
            "created_at": row[19], "updated_at": row[20], "removed_at": row[21],
        }

    @staticmethod
    def _handoff(row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0], "folder_id": row[1], "user_id": row[2], "project_id": row[3],
            "content_id": row[4], "ready_revision": int(row[5]), "idempotency_key": row[6],
            "descriptor": _json_load(row[7], {}), "status": row[8],
            "canonical_request_id": row[9], "error_code": row[10],
            "created_at": row[11], "updated_at": row[12],
        }

    async def create_or_open_folder(
        self, *, user_id: str, project_id: str, content_id: str
    ) -> tuple[dict[str, Any], bool]:
        self._ensure_connected()
        existing = await self.get_active_folder(
            user_id=user_id, project_id=project_id, content_id=content_id
        )
        if existing:
            return existing, False
        folder_id = str(uuid.uuid4())
        now = _now_iso()
        try:
            await self.db_client.execute(
                """
                INSERT INTO video_source_folders (
                    id, user_id, project_id, content_id, purpose, status, revision,
                    enqueue_status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, 'video_source_intake', 'collecting', 0, 'not_requested', ?, ?)
                """,
                [folder_id, user_id, project_id, content_id, now, now],
            )
        except Exception as exc:
            if "unique" not in str(exc).lower():
                raise
            existing = await self.get_active_folder(
                user_id=user_id, project_id=project_id, content_id=content_id
            )
            if existing:
                return existing, False
            raise
        folder = await self.get_folder(folder_id=folder_id, user_id=user_id)
        if folder is None:
            raise IntakeStoreError("Folder creation was not durable")
        return folder, True

    async def get_active_folder(
        self, *, user_id: str, project_id: str, content_id: str
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """SELECT id,user_id,project_id,content_id,purpose,status,revision,ready_revision,
                      ready_by,ready_at,enqueue_status,generation_request_id,generation_error_code,
                      created_at,updated_at,archived_at
               FROM video_source_folders
               WHERE user_id=? AND project_id=? AND content_id=?
                 AND purpose='video_source_intake' AND archived_at IS NULL LIMIT 1""",
            [user_id, project_id, content_id],
        )
        return self._folder(rs.rows[0]) if rs.rows else None

    async def get_folder(self, *, folder_id: str, user_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """SELECT id,user_id,project_id,content_id,purpose,status,revision,ready_revision,
                      ready_by,ready_at,enqueue_status,generation_request_id,generation_error_code,
                      created_at,updated_at,archived_at
               FROM video_source_folders WHERE id=? AND user_id=? AND archived_at IS NULL LIMIT 1""",
            [folder_id, user_id],
        )
        return self._folder(rs.rows[0]) if rs.rows else None

    async def list_sources(self, *, folder_id: str, user_id: str, include_removed: bool = False) -> list[dict[str, Any]]:
        self._ensure_connected()
        query = """SELECT id,folder_id,user_id,project_id,source_type,status,asset_id,text_body,
                          text_preview,raw_hash,normalized_hash,canonical_url,link_hostname,
                          safe_metadata_json,error_code,retryable,idempotency_key,
                          replacement_of_source_id,superseded_by_source_id,created_at,updated_at,removed_at
                   FROM video_sources WHERE folder_id=? AND user_id=?"""
        if not include_removed:
            query += " AND status NOT IN ('removed','superseded')"
        query += " ORDER BY created_at ASC, id ASC"
        rs = await self.db_client.execute(query, [folder_id, user_id])
        return [self._source(row) for row in rs.rows]

    async def get_source(self, *, folder_id: str, source_id: str, user_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """SELECT id,folder_id,user_id,project_id,source_type,status,asset_id,text_body,
                      text_preview,raw_hash,normalized_hash,canonical_url,link_hostname,
                      safe_metadata_json,error_code,retryable,idempotency_key,
                      replacement_of_source_id,superseded_by_source_id,created_at,updated_at,removed_at
               FROM video_sources WHERE id=? AND folder_id=? AND user_id=? LIMIT 1""",
            [source_id, folder_id, user_id],
        )
        return self._source(rs.rows[0]) if rs.rows else None

    async def _assert_revision(self, *, folder_id: str, user_id: str, expected_revision: int | None) -> dict[str, Any]:
        folder = await self.get_folder(folder_id=folder_id, user_id=user_id)
        if folder is None:
            raise IntakeNotFoundError("Source folder not found")
        if expected_revision is not None and folder["revision"] != expected_revision:
            raise IntakeConflictError("stale_revision", "The source folder changed. Refresh and retry.")
        return folder

    async def _increment_revision(self, *, folder: dict[str, Any]) -> None:
        next_status = "changed_after_ready" if folder["ready_revision"] is not None else "collecting"
        now = _now_iso()
        rs = await self.db_client.execute(
            """UPDATE video_source_folders
               SET revision=revision+1,status=?,enqueue_status='not_requested',
                   generation_request_id=NULL,generation_error_code=NULL,updated_at=?
               WHERE id=? AND user_id=? AND revision=? RETURNING revision""",
            [next_status, now, folder["id"], folder["user_id"], folder["revision"]],
        )
        if not rs.rows:
            raise IntakeConflictError("stale_revision", "The source folder changed. Refresh and retry.")

    async def add_source(
        self,
        *,
        folder_id: str,
        user_id: str,
        source_type: str,
        status: str,
        idempotency_key: str,
        expected_revision: int | None = None,
        asset_id: str | None = None,
        text_body: str | None = None,
        text_preview: str | None = None,
        raw_hash: str | None = None,
        normalized_hash: str | None = None,
        canonical_url: str | None = None,
        link_hostname: str | None = None,
        safe_metadata: dict[str, Any] | None = None,
        error_code: str | None = None,
        retryable: bool = False,
        replacement_of_source_id: str | None = None,
    ) -> tuple[dict[str, Any], bool]:
        folder = await self._assert_revision(
            folder_id=folder_id, user_id=user_id, expected_revision=expected_revision
        )
        replay = await self.db_client.execute(
            "SELECT id FROM video_sources WHERE folder_id=? AND idempotency_key=? LIMIT 1",
            [folder_id, idempotency_key],
        )
        if replay.rows:
            existing = await self.get_source(folder_id=folder_id, source_id=replay.rows[0][0], user_id=user_id)
            if existing is None:
                raise IntakeStoreError("Idempotent source result is unavailable")
            return existing, True
        active_count = await self.db_client.execute(
            """SELECT COUNT(*) FROM video_sources WHERE folder_id=? AND user_id=?
               AND status NOT IN ('removed','superseded')""",
            [folder_id, user_id],
        )
        if active_count.rows and int(active_count.rows[0][0]) >= 100:
            raise IntakeConflictError("source_limit_reached", "This folder already has 100 active sources.")
        since = (datetime.now(UTC) - timedelta(hours=1)).isoformat()
        recent_count = await self.db_client.execute(
            "SELECT COUNT(*) FROM video_sources WHERE user_id=? AND project_id=? AND created_at>=?",
            [user_id, folder["project_id"], since],
        )
        if recent_count.rows and int(recent_count.rows[0][0]) >= 20:
            raise IntakeConflictError("rate_limit_exceeded", "Too many source additions. Try again later.")
        if normalized_hash:
            duplicate = await self.db_client.execute(
                """SELECT id FROM video_sources WHERE folder_id=? AND user_id=?
                   AND normalized_hash=? AND status NOT IN ('removed','superseded') LIMIT 1""",
                [folder_id, user_id, normalized_hash],
            )
            if duplicate.rows:
                existing = await self.get_source(folder_id=folder_id, source_id=duplicate.rows[0][0], user_id=user_id)
                if existing:
                    return existing, True
        source_id = str(uuid.uuid4())
        now = _now_iso()
        await self.db_client.execute(
            """
            INSERT INTO video_sources (
                id,folder_id,user_id,project_id,source_type,status,asset_id,text_body,text_preview,
                raw_hash,normalized_hash,canonical_url,link_hostname,safe_metadata_json,error_code,
                retryable,idempotency_key,replacement_of_source_id,created_at,updated_at
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            [
                source_id, folder_id, user_id, folder["project_id"], source_type, status, asset_id,
                text_body, text_preview, raw_hash, normalized_hash, canonical_url, link_hostname,
                _json_dump(safe_metadata or {}), error_code, 1 if retryable else 0,
                idempotency_key, replacement_of_source_id, now, now,
            ],
        )
        await self._increment_revision(folder=folder)
        source = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if source is None:
            raise IntakeStoreError("Source creation was not durable")
        return source, False

    async def create_upload_session_record(
        self,
        *,
        session_id: str,
        source_id: str,
        folder_id: str,
        user_id: str,
        source_type: str,
        file_name: str,
        mime_type: str,
        byte_size: int,
        checksum_sha256: str,
        provider_namespace: str,
        provider_state: dict[str, Any],
        mode: str,
        expires_at: str,
        idempotency_key: str,
    ) -> dict[str, Any]:
        folder = await self._assert_revision(folder_id=folder_id, user_id=user_id, expected_revision=None)
        source = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if source is None:
            raise IntakeNotFoundError("Upload source not found")
        now = _now_iso()
        await self.db_client.execute(
            """INSERT INTO video_source_upload_sessions (
                   id,source_id,folder_id,user_id,project_id,content_id,expected_revision,
                   source_type,file_name,mime_type,byte_size,checksum_sha256,provider_namespace,
                   mode,provider_state_json,status,idempotency_key,
                   expires_at,created_at,updated_at
               ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            [session_id, source_id, folder_id, user_id, folder["project_id"], folder["content_id"],
             folder["revision"], source_type, file_name, mime_type, byte_size, checksum_sha256,
             provider_namespace, mode, _json_dump(provider_state), "created",
             idempotency_key, expires_at, now, now],
        )
        record = await self.get_upload_session(session_id=session_id, folder_id=folder_id, user_id=user_id)
        if record is None:
            raise IntakeStoreError("Upload session creation was not durable")
        return record

    async def get_upload_session(
        self, *, session_id: str, folder_id: str, user_id: str
    ) -> dict[str, Any] | None:
        rs = await self.db_client.execute(
            """SELECT id,source_id,folder_id,user_id,project_id,content_id,expected_revision,
                      source_type,file_name,mime_type,byte_size,checksum_sha256,provider_namespace,
                      mode,provider_state_json,status,idempotency_key,
                      locator_json,expires_at,created_at,updated_at
               FROM video_source_upload_sessions
               WHERE id=? AND folder_id=? AND user_id=? LIMIT 1""",
            [session_id, folder_id, user_id],
        )
        if not rs.rows:
            return None
        row = rs.rows[0]
        return {
            "id": row[0], "source_id": row[1], "folder_id": row[2], "user_id": row[3],
            "project_id": row[4], "content_id": row[5], "expected_revision": int(row[6]),
            "source_type": row[7], "file_name": row[8], "mime_type": row[9],
            "byte_size": int(row[10]), "checksum_sha256": row[11],
            "provider_namespace": row[12], "mode": row[13],
            "provider_state": _json_load(row[14], {}), "status": row[15],
            "idempotency_key": row[16], "locator": _json_load(row[17], None),
            "expires_at": row[18], "created_at": row[19], "updated_at": row[20],
        }

    async def find_upload_session_by_idempotency(
        self, *, folder_id: str, user_id: str, idempotency_key: str
    ) -> dict[str, Any] | None:
        rs = await self.db_client.execute(
            "SELECT id FROM video_source_upload_sessions WHERE folder_id=? AND user_id=? AND idempotency_key=? LIMIT 1",
            [folder_id, user_id, idempotency_key],
        )
        if not rs.rows:
            return None
        return await self.get_upload_session(
            session_id=rs.rows[0][0], folder_id=folder_id, user_id=user_id
        )

    async def update_upload_session(
        self,
        *,
        session_id: str,
        folder_id: str,
        user_id: str,
        status: str,
        locator: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        await self.db_client.execute(
            """UPDATE video_source_upload_sessions SET status=?,locator_json=?,updated_at=?
               WHERE id=? AND folder_id=? AND user_id=?""",
            [status, _json_dump(locator) if locator is not None else None, _now_iso(),
             session_id, folder_id, user_id],
        )
        record = await self.get_upload_session(session_id=session_id, folder_id=folder_id, user_id=user_id)
        if record is None:
            raise IntakeNotFoundError("Upload session not found")
        return record

    async def transition_upload_session(
        self,
        *,
        session_id: str,
        folder_id: str,
        user_id: str,
        from_status: str,
        to_status: str,
        locator: dict[str, Any] | None = None,
    ) -> bool:
        """Atomically claim one upload-session transition.

        Completion and cancellation can race across workers. The conditional
        update ensures that exactly one worker owns the next side effects.
        """
        result = await self.db_client.execute(
            """UPDATE video_source_upload_sessions
               SET status=?,locator_json=COALESCE(?,locator_json),updated_at=?
               WHERE id=? AND folder_id=? AND user_id=? AND status=?
               RETURNING id""",
            [to_status, _json_dump(locator) if locator is not None else None, _now_iso(),
             session_id, folder_id, user_id, from_status],
        )
        return bool(result.rows)

    async def update_source(
        self, *, folder_id: str, source_id: str, user_id: str, status: str,
        asset_id: str | None = None, safe_metadata: dict[str, Any] | None = None,
        error_code: str | None = None, retryable: bool = False,
    ) -> dict[str, Any]:
        existing = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if existing is None:
            raise IntakeNotFoundError("Source not found")
        await self.db_client.execute(
            """UPDATE video_sources SET status=?,asset_id=?,safe_metadata_json=?,error_code=?,
                      retryable=?,updated_at=? WHERE id=? AND folder_id=? AND user_id=?""",
            [status, asset_id, _json_dump(safe_metadata or existing["safe_metadata"]), error_code,
             1 if retryable else 0, _now_iso(), source_id, folder_id, user_id],
        )
        updated = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if updated is None:
            raise IntakeStoreError("Source update was not durable")
        return updated

    async def supersede_source(
        self, *, folder_id: str, source_id: str, replacement_source_id: str, user_id: str
    ) -> None:
        source = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        replacement = await self.get_source(
            folder_id=folder_id, source_id=replacement_source_id, user_id=user_id
        )
        if source is None or replacement is None:
            raise IntakeNotFoundError("Replacement source not found")
        if replacement["replacement_of_source_id"] != source_id or replacement["status"] != "ready":
            raise IntakeConflictError("replacement_not_ready", "The replacement is not ready.")
        now = _now_iso()
        await self.db_client.execute(
            """UPDATE video_sources SET status='superseded',superseded_by_source_id=?,updated_at=?
               WHERE id=? AND folder_id=? AND user_id=? AND status NOT IN ('removed','superseded')""",
            [replacement_source_id, now, source_id, folder_id, user_id],
        )

    async def begin_retry(
        self, *, folder_id: str, source_id: str, user_id: str, expected_revision: int
    ) -> dict[str, Any]:
        folder = await self._assert_revision(
            folder_id=folder_id, user_id=user_id, expected_revision=expected_revision
        )
        source = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if source is None or source["status"] not in {
            "failed", "metadata_unavailable", "orphan_cleanup_needed"
        }:
            raise IntakeConflictError("source_not_retryable", "This source cannot be retried.")
        await self.db_client.execute(
            """UPDATE video_sources SET status='processing',error_code=NULL,retryable=0,updated_at=?
               WHERE id=? AND folder_id=? AND user_id=?""",
            [_now_iso(), source_id, folder_id, user_id],
        )
        await self._increment_revision(folder=folder)
        updated = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if updated is None:
            raise IntakeStoreError("Source retry was not durable")
        return updated

    async def remove_source(
        self, *, folder_id: str, source_id: str, user_id: str, expected_revision: int
    ) -> dict[str, Any]:
        folder = await self._assert_revision(
            folder_id=folder_id, user_id=user_id, expected_revision=expected_revision
        )
        source = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if source is None or source["status"] in {"removed", "superseded"}:
            raise IntakeNotFoundError("Source not found")
        now = _now_iso()
        await self.db_client.execute(
            "UPDATE video_sources SET status='removed',removed_at=?,updated_at=? WHERE id=? AND folder_id=? AND user_id=?",
            [now, now, source_id, folder_id, user_id],
        )
        await self._increment_revision(folder=folder)
        updated = await self.get_source(folder_id=folder_id, source_id=source_id, user_id=user_id)
        if updated is None:
            raise IntakeStoreError("Source removal was not durable")
        return updated

    async def mark_ready(
        self, *, folder_id: str, user_id: str, expected_revision: int
    ) -> dict[str, Any]:
        folder = await self._assert_revision(
            folder_id=folder_id, user_id=user_id, expected_revision=expected_revision
        )
        sources = await self.list_sources(folder_id=folder_id, user_id=user_id)
        blocking = [source["id"] for source in sources if source["status"] in READINESS_BLOCKING_STATUSES]
        if not sources or blocking:
            raise IntakeConflictError(
                "sources_not_ready", "Resolve the blocked sources before continuing.", source_ids=blocking
            )
        now = _now_iso()
        rs = await self.db_client.execute(
            """UPDATE video_source_folders SET status='ready',ready_revision=?,ready_by=?,ready_at=?,
                      enqueue_status='not_requested',generation_request_id=NULL,generation_error_code=NULL,
                      updated_at=? WHERE id=? AND user_id=? AND revision=? RETURNING id""",
            [folder["revision"], user_id, now, now, folder_id, user_id, folder["revision"]],
        )
        if not rs.rows:
            raise IntakeConflictError("stale_revision", "The source folder changed. Refresh and retry.")
        ready = await self.get_folder(folder_id=folder_id, user_id=user_id)
        if ready is None:
            raise IntakeStoreError("Readiness update was not durable")
        return ready

    async def create_generation_handoff(
        self, *, folder_id: str, user_id: str, expected_revision: int, idempotency_key: str
    ) -> tuple[dict[str, Any], bool]:
        folder = await self._assert_revision(
            folder_id=folder_id, user_id=user_id, expected_revision=expected_revision
        )
        if folder["ready_revision"] != expected_revision or folder["status"] != "ready":
            folder = await self.mark_ready(
                folder_id=folder_id, user_id=user_id, expected_revision=expected_revision
            )
        existing_rs = await self.db_client.execute(
            """SELECT id,folder_id,user_id,project_id,content_id,ready_revision,idempotency_key,
                      descriptor_json,status,canonical_request_id,error_code,created_at,updated_at
               FROM video_source_generation_handoffs
               WHERE folder_id=? AND ready_revision=? AND idempotency_key=? LIMIT 1""",
            [folder_id, expected_revision, idempotency_key],
        )
        if existing_rs.rows:
            return self._handoff(existing_rs.rows[0]), False
        sources = await self.list_sources(folder_id=folder_id, user_id=user_id)
        source_ids = [source["id"] for source in sources if source["status"] == "ready"]
        descriptor = {
            "folder_id": folder_id,
            "project_id": folder["project_id"],
            "content_id": folder["content_id"],
            "sources_ready_revision": expected_revision,
            "source_ids": source_ids,
        }
        handoff_id = str(uuid.uuid4())
        now = _now_iso()
        try:
            await self.db_client.execute(
                """INSERT INTO video_source_generation_handoffs (
                       id,folder_id,user_id,project_id,content_id,ready_revision,idempotency_key,
                       descriptor_json,status,created_at,updated_at
                   ) VALUES (?,?,?,?,?,?,?,?, 'enqueue_pending',?,?)""",
                [handoff_id, folder_id, user_id, folder["project_id"], folder["content_id"],
                 expected_revision, idempotency_key, _json_dump(descriptor), now, now],
            )
        except Exception as exc:
            if "unique" not in str(exc).lower():
                raise
            replay = await self.create_generation_handoff(
                folder_id=folder_id, user_id=user_id, expected_revision=expected_revision,
                idempotency_key=idempotency_key,
            )
            return replay[0], False
        await self.db_client.execute(
            """UPDATE video_source_folders SET enqueue_status='enqueue_pending',
                      generation_error_code=NULL,updated_at=? WHERE id=? AND user_id=?""",
            [now, folder_id, user_id],
        )
        created_rs = await self.db_client.execute(
            """SELECT id,folder_id,user_id,project_id,content_id,ready_revision,idempotency_key,
                      descriptor_json,status,canonical_request_id,error_code,created_at,updated_at
               FROM video_source_generation_handoffs WHERE id=? AND user_id=? LIMIT 1""",
            [handoff_id, user_id],
        )
        return self._handoff(created_rs.rows[0]), True

    async def complete_generation_handoff(
        self, *, handoff_id: str, user_id: str, canonical_request_id: str
    ) -> dict[str, Any]:
        now = _now_iso()
        await self.db_client.execute(
            """UPDATE video_source_generation_handoffs SET status='enqueued',canonical_request_id=?,
                      error_code=NULL,updated_at=? WHERE id=? AND user_id=?""",
            [canonical_request_id, now, handoff_id, user_id],
        )
        await self.db_client.execute(
            """UPDATE video_source_folders SET enqueue_status='enqueued',generation_request_id=?,
                      generation_error_code=NULL,updated_at=?
               WHERE id=(SELECT folder_id FROM video_source_generation_handoffs WHERE id=? AND user_id=?)
                 AND user_id=?""",
            [canonical_request_id, now, handoff_id, user_id, user_id],
        )
        rs = await self.db_client.execute(
            """SELECT id,folder_id,user_id,project_id,content_id,ready_revision,idempotency_key,
                      descriptor_json,status,canonical_request_id,error_code,created_at,updated_at
               FROM video_source_generation_handoffs WHERE id=? AND user_id=? LIMIT 1""",
            [handoff_id, user_id],
        )
        if not rs.rows:
            raise IntakeNotFoundError("Generation handoff not found")
        return self._handoff(rs.rows[0])

    async def fail_generation_handoff(
        self, *, handoff_id: str, user_id: str, error_code: str
    ) -> dict[str, Any]:
        now = _now_iso()
        await self.db_client.execute(
            """UPDATE video_source_generation_handoffs SET status='enqueue_failed',error_code=?,
                      updated_at=? WHERE id=? AND user_id=?""",
            [error_code, now, handoff_id, user_id],
        )
        await self.db_client.execute(
            """UPDATE video_source_folders SET enqueue_status='enqueue_failed',generation_error_code=?,
                      generation_request_id=NULL,updated_at=?
               WHERE id=(SELECT folder_id FROM video_source_generation_handoffs WHERE id=? AND user_id=?)
                 AND user_id=?""",
            [error_code, now, handoff_id, user_id, user_id],
        )
        rs = await self.db_client.execute(
            """SELECT id,folder_id,user_id,project_id,content_id,ready_revision,idempotency_key,
                      descriptor_json,status,canonical_request_id,error_code,created_at,updated_at
               FROM video_source_generation_handoffs WHERE id=? AND user_id=? LIMIT 1""",
            [handoff_id, user_id],
        )
        if not rs.rows:
            raise IntakeNotFoundError("Generation handoff not found")
        return self._handoff(rs.rows[0])


video_source_intake_store = VideoSourceIntakeStore()
