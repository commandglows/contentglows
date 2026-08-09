"""
Status Service - Singleton service for content lifecycle management.

Provides CRUD operations, status transitions with validation,
audit trail, and statistics.
"""

import json
import uuid
import sqlite3
import asyncio
import os
from datetime import datetime
from typing import Dict, Any, List, Optional

from api.services.asset_understanding import (
    AssetMediaEnvelope,
    AssetUnderstandingCredentialResolver,
    AssetUnderstandingError,
    AssetUnderstandingGuardrails,
    AssetUnderstandingProviderAdapter,
    NoopGeminiCompatibleAdapter,
)
from api.services.asset_understanding_normalizer import normalize_understanding_payload
from api.services.project_asset_storage import build_project_asset_storage_descriptor
from api.services.social_placement_registry import lookup_placement, validate_placement_id
from status.asset_categories import validate_project_asset_category
from status.db import get_connection, init_db
from status.audit import AuditActor, actor_from_string, coerce_actor
from status.schemas import (
    AssetSceneSegment,
    AssetSemanticTag,
    AssetSourceAttribution,
    AssetUnderstandingJobRecord,
    AssetUnderstandingResultRecord,
    ContentLifecycleStatus,
    ContentAssetRecord,
    ContentAssetStatus,
    ContentRecord,
    ProjectAssetLifecycleStatus,
    ProjectAssetEventRecord,
    ProjectAssetMediaKind,
    ProjectAssetRecord,
    ProjectAssetSource,
    ProjectAssetUsageRecord,
    StorageLocator,
    StatusChange,
    WorkDomainRecord,
    VALID_TRANSITIONS,
)
from agents.scheduler.schemas.publishing_schemas import ContentType, SourceRobot


class InvalidTransitionError(Exception):
    """Raised when a status transition is not allowed."""
    pass


class ContentNotFoundError(Exception):
    """Raised when a content record is not found."""
    pass


class ProjectAssetEligibilityError(Exception):
    """Raised when an asset cannot be used for a target/action."""
    pass


PROJECT_ASSET_MUTATION_ACTION_TARGETS: Dict[str, set[str]] = {
    "select_for_content": {"content"},
    "promote_reference": {"content"},
    "set_primary": {"content", "video_version"},
    "select_for_video_version": {"video_version"},
    "use_in_remotion_render": {"video_version"},
    "publish_media": {"content", "video_version"},
    "attach_video_source": {"video_source_folder"},
}
PROJECT_ASSET_READ_ACTIONS = {"preview_only", "historical_only"}
PROJECT_ASSET_SUPPORTED_ACTIONS = set(PROJECT_ASSET_MUTATION_ACTION_TARGETS) | PROJECT_ASSET_READ_ACTIONS
VIDEO_VERSION_MEDIA_KINDS = {
    ProjectAssetMediaKind.IMAGE.value,
    ProjectAssetMediaKind.THUMBNAIL.value,
    ProjectAssetMediaKind.VIDEO_COVER.value,
    ProjectAssetMediaKind.CAPTURE.value,
    ProjectAssetMediaKind.VIDEO.value,
    ProjectAssetMediaKind.AUDIO.value,
    ProjectAssetMediaKind.MUSIC.value,
    ProjectAssetMediaKind.BACKGROUND_CONFIG.value,
    ProjectAssetMediaKind.RENDER_OUTPUT.value,
}


def _run_async(awaitable):
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        return asyncio.run(awaitable)
    if loop.is_running():
        new_loop = asyncio.new_event_loop()
        try:
            return new_loop.run_until_complete(awaitable)
        finally:
            new_loop.close()
    return loop.run_until_complete(awaitable)


class StatusService:
    """
    Singleton service managing content lifecycle status.
    All robots use this to track content from creation to publication.
    """

    def __init__(self, db_path: Optional[str] = None):
        self._conn = get_connection(db_path)
        init_db(self._conn)

    # ─── Content CRUD ─────────────────────────────────

    def create_content(
        self,
        title: str,
        content_type: str,
        source_robot: str,
        status: str = ContentLifecycleStatus.TODO,
        project_id: Optional[str] = None,
        user_id: Optional[str] = None,
        content_path: Optional[str] = None,
        content_preview: Optional[str] = None,
        content_hash: Optional[str] = None,
        priority: int = 3,
        tags: Optional[List[str]] = None,
        metadata: Optional[Dict[str, Any]] = None,
        target_url: Optional[str] = None,
    ) -> ContentRecord:
        """Create a new content record."""
        now = datetime.utcnow().isoformat()
        content_id = str(uuid.uuid4())

        # Validate enum values
        ContentType(content_type)
        SourceRobot(source_robot)
        if isinstance(status, str):
            status = ContentLifecycleStatus(status)

        record = ContentRecord(
            id=content_id,
            title=title,
            content_type=content_type,
            source_robot=source_robot,
            status=status,
            project_id=project_id,
            user_id=user_id,
            content_path=content_path,
            content_preview=content_preview,
            content_hash=content_hash,
            priority=priority,
            tags=tags or [],
            metadata=metadata or {},
            target_url=target_url,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )

        self._conn.execute(
            """
            INSERT INTO content_records
            (id, title, content_type, source_robot, status, project_id, user_id,
             content_path, content_preview, content_hash, priority, tags,
             metadata, target_url, current_version, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                record.id,
                record.title,
                record.content_type,
                record.source_robot,
                record.status,
                record.project_id,
                record.user_id,
                record.content_path,
                record.content_preview,
                record.content_hash,
                record.priority,
                json.dumps(record.tags),
                json.dumps(record.metadata),
                record.target_url,
                record.current_version,
                now,
                now,
            ),
        )
        self._conn.commit()
        return record

    def get_content(self, content_id: str) -> ContentRecord:
        """Get a single content record by ID."""
        row = self._conn.execute(
            "SELECT * FROM content_records WHERE id = ?", (content_id,)
        ).fetchone()

        if not row:
            raise ContentNotFoundError(f"Content {content_id} not found")

        return self._row_to_record(row)

    def update_content(self, content_id: str, **kwargs: Any) -> ContentRecord:
        """Update content record fields (not status - use transition() for that)."""
        # Ensure record exists
        self.get_content(content_id)

        allowed_fields = {
            "title", "content_path", "content_preview", "content_hash",
            "priority", "tags", "metadata", "target_url", "project_id",
            "reviewer_note", "reviewed_by", "scheduled_for", "published_at",
            "current_version", "review_actor_type", "review_actor_id",
            "review_actor_label", "review_actor_metadata",
        }
        updates = {k: v for k, v in kwargs.items() if k in allowed_fields}
        if not updates:
            return self.get_content(content_id)

        # Serialize complex types
        if "tags" in updates:
            updates["tags"] = json.dumps(updates["tags"])
        if "metadata" in updates:
            updates["metadata"] = json.dumps(updates["metadata"])
        if "review_actor_metadata" in updates and updates["review_actor_metadata"] is not None:
            updates["review_actor_metadata"] = json.dumps(updates["review_actor_metadata"])
        if "scheduled_for" in updates and isinstance(updates["scheduled_for"], datetime):
            updates["scheduled_for"] = updates["scheduled_for"].isoformat()
        if "published_at" in updates and isinstance(updates["published_at"], datetime):
            updates["published_at"] = updates["published_at"].isoformat()

        updates["updated_at"] = datetime.utcnow().isoformat()

        set_clause = ", ".join(f"{k} = ?" for k in updates)
        values = list(updates.values()) + [content_id]

        self._conn.execute(
            f"UPDATE content_records SET {set_clause} WHERE id = ?",
            values,
        )
        self._conn.commit()
        return self.get_content(content_id)

    def list_content(
        self,
        status: Optional[str] = None,
        content_type: Optional[str] = None,
        source_robot: Optional[str] = None,
        project_id: Optional[str] = None,
        project_ids: Optional[List[str]] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[ContentRecord]:
        """List content records with optional filters."""
        query = "SELECT * FROM content_records WHERE 1=1"
        params: List[Any] = []

        if status:
            query += " AND status = ?"
            params.append(status)
        if content_type:
            query += " AND content_type = ?"
            params.append(content_type)
        if source_robot:
            query += " AND source_robot = ?"
            params.append(source_robot)
        if project_id:
            query += " AND project_id = ?"
            params.append(project_id)
        elif project_ids is not None:
            if not project_ids:
                return []
            placeholders = ", ".join("?" for _ in project_ids)
            query += f" AND project_id IN ({placeholders})"
            params.extend(project_ids)

        query += " ORDER BY updated_at DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])

        rows = self._conn.execute(query, params).fetchall()
        return [self._row_to_record(row) for row in rows]

    def delete_content(self, content_id: str) -> None:
        """Delete a content record and its history."""
        self.get_content(content_id)  # Ensure exists
        self._conn.execute("DELETE FROM content_records WHERE id = ?", (content_id,))
        self._conn.commit()

    # ─── Status Transitions ───────────────────────────

    def transition(
        self,
        content_id: str,
        to_status: str,
        changed_by: str | AuditActor,
        reason: Optional[str] = None,
    ) -> ContentRecord:
        """
        Transition a content record to a new status.
        Validates the transition against the allowed matrix.
        Creates an audit trail entry.
        """
        record = self.get_content(content_id)
        from_status = ContentLifecycleStatus(record.status)
        to_status_enum = ContentLifecycleStatus(to_status)

        # Validate transition
        allowed = VALID_TRANSITIONS.get(from_status, [])
        if to_status_enum not in allowed:
            raise InvalidTransitionError(
                f"Cannot transition from '{from_status.value}' to '{to_status_enum.value}'. "
                f"Allowed: {[s.value for s in allowed]}"
            )

        now = datetime.utcnow().isoformat()
        change_id = str(uuid.uuid4())
        actor = coerce_actor(changed_by)

        # Update status
        update_fields = {"status": to_status_enum.value, "updated_at": now}

        # Auto-set published_at when transitioning to PUBLISHED
        if to_status_enum == ContentLifecycleStatus.PUBLISHED:
            update_fields["published_at"] = now

        set_clause = ", ".join(f"{k} = ?" for k in update_fields)
        values = list(update_fields.values()) + [content_id]
        self._conn.execute(
            f"UPDATE content_records SET {set_clause} WHERE id = ?",
            values,
        )

        # Record the change
        self._conn.execute(
            """
            INSERT INTO status_changes (
                id, content_id, from_status, to_status, changed_by,
                actor_type, actor_id, actor_label, actor_metadata, reason, timestamp
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                change_id,
                content_id,
                from_status.value,
                to_status_enum.value,
                actor.actor_id,
                actor.actor_type,
                actor.actor_id,
                actor.actor_label,
                json.dumps(actor.actor_metadata) if actor.actor_metadata is not None else None,
                reason,
                now,
            ),
        )

        self._conn.commit()
        return self.get_content(content_id)

    def get_history(self, content_id: str) -> List[StatusChange]:
        """Get the full audit trail for a content record."""
        rows = self._conn.execute(
            "SELECT * FROM status_changes WHERE content_id = ? ORDER BY timestamp ASC",
            (content_id,),
        ).fetchall()

        return [
            self._row_to_status_change(row)
            for row in rows
        ]

    # ─── Statistics ───────────────────────────────────

    def get_stats(
        self,
        project_id: Optional[str] = None,
        project_ids: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Get content counts grouped by status."""
        query = "SELECT status, COUNT(*) as count FROM content_records"
        params: List[Any] = []

        if project_id:
            query += " WHERE project_id = ?"
            params.append(project_id)
        elif project_ids is not None:
            if not project_ids:
                counts = {s.value: 0 for s in ContentLifecycleStatus}
                return {"total": 0, "by_status": counts}
            placeholders = ", ".join("?" for _ in project_ids)
            query += f" WHERE project_id IN ({placeholders})"
            params.extend(project_ids)

        query += " GROUP BY status"
        rows = self._conn.execute(query, params).fetchall()

        counts = {s.value: 0 for s in ContentLifecycleStatus}
        for row in rows:
            counts[row["status"]] = row["count"]

        total = sum(counts.values())
        return {"total": total, "by_status": counts}

    # ─── Work Domains ─────────────────────────────────

    def get_domains(
        self,
        project_id: Optional[str] = None,
        project_ids: Optional[List[str]] = None,
    ) -> List[WorkDomainRecord]:
        """Get work domain records, optionally filtered by project."""
        query = "SELECT * FROM work_domains"
        params: List[Any] = []

        if project_id:
            query += " WHERE project_id = ?"
            params.append(project_id)
        elif project_ids is not None:
            if not project_ids:
                return []
            placeholders = ", ".join("?" for _ in project_ids)
            query += f" WHERE project_id IN ({placeholders})"
            params.extend(project_ids)

        query += " ORDER BY domain ASC"
        rows = self._conn.execute(query, params).fetchall()

        return [
            WorkDomainRecord(
                id=row["id"],
                project_id=row["project_id"],
                domain=row["domain"],
                status=row["status"],
                last_run_at=datetime.fromisoformat(row["last_run_at"]) if row["last_run_at"] else None,
                last_run_status=row["last_run_status"],
                items_pending=row["items_pending"],
                items_completed=row["items_completed"],
                metadata=json.loads(row["metadata"]),
                updated_at=datetime.fromisoformat(row["updated_at"]),
            )
            for row in rows
        ]

    def upsert_domain(
        self,
        project_id: str,
        domain: str,
        **kwargs: Any,
    ) -> WorkDomainRecord:
        """Create or update a work domain record."""
        now = datetime.utcnow().isoformat()

        existing = self._conn.execute(
            "SELECT * FROM work_domains WHERE project_id = ? AND domain = ?",
            (project_id, domain),
        ).fetchone()

        if existing:
            updates = {k: v for k, v in kwargs.items() if k in {
                "status", "last_run_at", "last_run_status",
                "items_pending", "items_completed", "metadata",
            }}
            if "metadata" in updates:
                updates["metadata"] = json.dumps(updates["metadata"])
            if "last_run_at" in updates and isinstance(updates["last_run_at"], datetime):
                updates["last_run_at"] = updates["last_run_at"].isoformat()
            updates["updated_at"] = now

            set_clause = ", ".join(f"{k} = ?" for k in updates)
            values = list(updates.values()) + [project_id, domain]
            self._conn.execute(
                f"UPDATE work_domains SET {set_clause} WHERE project_id = ? AND domain = ?",
                values,
            )
        else:
            domain_id = str(uuid.uuid4())
            metadata = kwargs.get("metadata", {})
            self._conn.execute(
                """
                INSERT INTO work_domains
                (id, project_id, domain, status, last_run_at, last_run_status,
                 items_pending, items_completed, metadata, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    domain_id,
                    project_id,
                    domain,
                    kwargs.get("status", "idle"),
                    kwargs.get("last_run_at", "").isoformat() if isinstance(kwargs.get("last_run_at"), datetime) else kwargs.get("last_run_at"),
                    kwargs.get("last_run_status"),
                    kwargs.get("items_pending", 0),
                    kwargs.get("items_completed", 0),
                    json.dumps(metadata),
                    now,
                ),
            )

        self._conn.commit()
        result = self._conn.execute(
            "SELECT * FROM work_domains WHERE project_id = ? AND domain = ?",
            (project_id, domain),
        ).fetchone()
        return WorkDomainRecord(
            id=result["id"],
            project_id=result["project_id"],
            domain=result["domain"],
            status=result["status"],
            last_run_at=datetime.fromisoformat(result["last_run_at"]) if result["last_run_at"] else None,
            last_run_status=result["last_run_status"],
            items_pending=result["items_pending"],
            items_completed=result["items_completed"],
            metadata=json.loads(result["metadata"]),
            updated_at=datetime.fromisoformat(result["updated_at"]),
        )

    # ─── Content Body ─────────────────────────────────

    def save_content_body(
        self,
        content_id: str,
        body: str,
        edited_by: str | AuditActor = "user",
        edit_note: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Save a new version of content body. Creates version history."""
        record = self.get_content(content_id)
        previous_version = record.current_version
        new_version = previous_version + 1
        now = datetime.utcnow().isoformat()
        body_id = str(uuid.uuid4())
        edit_id = str(uuid.uuid4())
        actor = coerce_actor(edited_by)

        # Insert new body version
        self._conn.execute(
            """
            INSERT INTO content_bodies (id, content_id, body, version, edited_by, edit_note, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (body_id, content_id, body, new_version, actor.actor_id, edit_note, now),
        )

        # Insert edit audit entry
        self._conn.execute(
            """
            INSERT INTO content_edits (
                id, content_id, edited_by, actor_type, actor_id, actor_label,
                actor_metadata, edit_note, previous_version, new_version, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                edit_id,
                content_id,
                actor.actor_id,
                actor.actor_type,
                actor.actor_id,
                actor.actor_label,
                json.dumps(actor.actor_metadata) if actor.actor_metadata is not None else None,
                edit_note,
                previous_version,
                new_version,
                now,
            ),
        )

        # Update current_version on content record
        self._conn.execute(
            "UPDATE content_records SET current_version = ?, updated_at = ? WHERE id = ?",
            (new_version, now, content_id),
        )
        self._conn.commit()

        return {
            "id": body_id,
            "content_id": content_id,
            "version": new_version,
            "edited_by": actor.actor_id,
            "actor_type": actor.actor_type,
            "actor_id": actor.actor_id,
            "actor_label": actor.actor_label,
            "actor_metadata": actor.actor_metadata,
            "edit_note": edit_note,
            "created_at": now,
        }

    def get_content_body(
        self,
        content_id: str,
        version: Optional[int] = None,
    ) -> Optional[Dict[str, Any]]:
        """Get content body, latest version or specific version."""
        self.get_content(content_id)  # Ensure exists

        if version is not None:
            row = self._conn.execute(
                "SELECT * FROM content_bodies WHERE content_id = ? AND version = ?",
                (content_id, version),
            ).fetchone()
        else:
            row = self._conn.execute(
                "SELECT * FROM content_bodies WHERE content_id = ? ORDER BY version DESC LIMIT 1",
                (content_id,),
            ).fetchone()

        if not row:
            return None

        return {
            "id": row["id"],
            "content_id": row["content_id"],
            "body": row["body"],
            "version": row["version"],
            "edited_by": row["edited_by"],
            "actor_type": actor_from_string(row["edited_by"]).actor_type,
            "actor_id": actor_from_string(row["edited_by"]).actor_id,
            "actor_label": actor_from_string(row["edited_by"]).actor_label,
            "actor_metadata": actor_from_string(row["edited_by"]).actor_metadata,
            "edit_note": row["edit_note"],
            "created_at": row["created_at"],
        }

    def get_edit_history(self, content_id: str) -> List[Dict[str, Any]]:
        """Get edit history for a content record."""
        self.get_content(content_id)  # Ensure exists

        rows = self._conn.execute(
            "SELECT * FROM content_edits WHERE content_id = ? ORDER BY created_at DESC",
            (content_id,),
        ).fetchall()

        return [
            {
                "id": row["id"],
                "content_id": row["content_id"],
                "edited_by": row["edited_by"],
                "actor_type": self._row_actor_type(row, fallback=row["edited_by"]),
                "actor_id": self._row_actor_id(row, fallback=row["edited_by"]),
                "actor_label": self._row_actor_label(row, fallback=row["edited_by"]),
                "actor_metadata": self._row_actor_metadata(row, fallback=row["edited_by"]),
                "edit_note": row["edit_note"],
                "previous_version": row["previous_version"],
                "new_version": row["new_version"],
                "created_at": row["created_at"],
            }
            for row in rows
        ]

    # ─── Content Assets ───────────────────────────────

    def list_content_assets(self, content_id: str) -> List[ContentAssetRecord]:
        """List non-deleted asset metadata records attached to content."""
        self.get_content(content_id)
        rows = self._conn.execute(
            """
            SELECT * FROM content_assets
            WHERE content_id = ? AND deleted_at IS NULL
            ORDER BY created_at DESC
            """,
            (content_id,),
        ).fetchall()
        return [self._row_to_asset(row) for row in rows]

    def create_content_asset(
        self,
        *,
        content_id: str,
        project_id: str,
        user_id: str,
        kind: str,
        mime_type: str,
        client_asset_id: Optional[str] = None,
        source: str = "device_capture",
        file_name: Optional[str] = None,
        byte_size: Optional[int] = None,
        width: Optional[int] = None,
        height: Optional[int] = None,
        duration_ms: Optional[int] = None,
        storage_uri: Optional[str] = None,
        status: str = ContentAssetStatus.LOCAL_ONLY,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> ContentAssetRecord:
        """Create or refresh asset metadata for a content record."""
        self.get_content(content_id)
        ContentAssetStatus(status)
        now = datetime.utcnow().isoformat()
        payload_metadata = metadata or {}

        existing = None
        if client_asset_id:
            existing = self._conn.execute(
                """
                SELECT * FROM content_assets
                WHERE content_id = ? AND client_asset_id = ? AND deleted_at IS NULL
                LIMIT 1
                """,
                (content_id, client_asset_id),
            ).fetchone()

        if existing:
            self._conn.execute(
                """
                UPDATE content_assets
                SET source = ?, kind = ?, mime_type = ?, file_name = ?, byte_size = ?,
                    width = ?, height = ?, duration_ms = ?, storage_uri = ?, status = ?,
                    metadata = ?, updated_at = ?
                WHERE id = ?
                """,
                (
                    source,
                    kind,
                    mime_type,
                    file_name,
                    byte_size,
                    width,
                    height,
                    duration_ms,
                    storage_uri,
                    status,
                    json.dumps(payload_metadata),
                    now,
                    existing["id"],
                ),
            )
            self._conn.commit()
            return self.get_content_asset(content_id, existing["id"])

        asset_id = str(uuid.uuid4())
        self._conn.execute(
            """
            INSERT INTO content_assets (
                id, content_id, project_id, user_id, client_asset_id, source,
                kind, mime_type, file_name, byte_size, width, height, duration_ms,
                storage_uri, status, metadata, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                asset_id,
                content_id,
                project_id,
                user_id,
                client_asset_id,
                source,
                kind,
                mime_type,
                file_name,
                byte_size,
                width,
                height,
                duration_ms,
                storage_uri,
                status,
                json.dumps(payload_metadata),
                now,
                now,
            ),
        )
        self._conn.commit()
        return self.get_content_asset(content_id, asset_id)

    def get_content_asset(self, content_id: str, asset_id: str) -> ContentAssetRecord:
        """Get one asset metadata record for content."""
        row = self._conn.execute(
            "SELECT * FROM content_assets WHERE content_id = ? AND id = ?",
            (content_id, asset_id),
        ).fetchone()
        if not row:
            raise ContentNotFoundError(f"Asset {asset_id} not found")
        return self._row_to_asset(row)

    def update_content_asset(
        self,
        content_id: str,
        asset_id: str,
        **kwargs: Any,
    ) -> ContentAssetRecord:
        """Update mutable asset metadata fields."""
        self.get_content_asset(content_id, asset_id)
        allowed = {"storage_uri", "status", "metadata"}
        updates = {k: v for k, v in kwargs.items() if k in allowed}
        if not updates:
            return self.get_content_asset(content_id, asset_id)

        if "status" in updates:
            ContentAssetStatus(updates["status"])
        if "metadata" in updates:
            updates["metadata"] = json.dumps(updates["metadata"] or {})
        updates["updated_at"] = datetime.utcnow().isoformat()

        set_clause = ", ".join(f"{k} = ?" for k in updates)
        values = list(updates.values()) + [content_id, asset_id]
        self._conn.execute(
            f"UPDATE content_assets SET {set_clause} WHERE content_id = ? AND id = ?",
            values,
        )
        self._conn.commit()
        return self.get_content_asset(content_id, asset_id)

    def delete_content_asset(self, content_id: str, asset_id: str) -> ContentAssetRecord:
        """Tombstone asset metadata without deleting the content record."""
        self.get_content_asset(content_id, asset_id)
        now = datetime.utcnow().isoformat()
        self._conn.execute(
            """
            UPDATE content_assets
            SET status = ?, deleted_at = ?, updated_at = ?
            WHERE content_id = ? AND id = ?
            """,
            (ContentAssetStatus.DELETED.value, now, now, content_id, asset_id),
        )
        self._conn.commit()
        return self.get_content_asset(content_id, asset_id)

    # ─── Unified Project Asset Library ───────────────

    def list_project_assets(
        self,
        *,
        project_id: str,
        user_id: str,
        media_kind: Optional[str] = None,
        source: Optional[str] = None,
        category_id: Optional[str] = None,
        subcategory_id: Optional[str] = None,
        include_tombstoned: bool = False,
        limit: int = 50,
        offset: int = 0,
    ) -> List[ProjectAssetRecord]:
        self._normalize_project_assets_from_content_assets(project_id=project_id, user_id=user_id)
        if media_kind:
            ProjectAssetMediaKind(media_kind)
        if source:
            ProjectAssetSource(source)
        category_id, subcategory_id = validate_project_asset_category(category_id, subcategory_id)

        query = "SELECT * FROM project_assets WHERE project_id = ? AND user_id = ?"
        params: List[Any] = [project_id, user_id]
        if not include_tombstoned:
            query += " AND status != ?"
            params.append(ProjectAssetLifecycleStatus.TOMBSTONED.value)
        if media_kind:
            query += " AND media_kind = ?"
            params.append(media_kind)
        if source:
            query += " AND source = ?"
            params.append(source)
        if category_id:
            query += " AND category_id = ?"
            params.append(category_id)
        if subcategory_id:
            query += " AND subcategory_id = ?"
            params.append(subcategory_id)
        query += " ORDER BY updated_at DESC, id DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])

        rows = self._conn.execute(query, params).fetchall()
        return [self._row_to_project_asset(row) for row in rows]

    def get_project_asset_detail(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
    ) -> ProjectAssetRecord:
        row = self._conn.execute(
            "SELECT * FROM project_assets WHERE id = ? AND project_id = ? AND user_id = ?",
            (asset_id, project_id, user_id),
        ).fetchone()
        if not row:
            raise ContentNotFoundError(f"Project asset {asset_id} not found")
        return self._row_to_project_asset(row)

    def create_project_asset(
        self,
        *,
        project_id: str,
        user_id: str,
        media_kind: str,
        source: str,
        mime_type: Optional[str] = None,
        file_name: Optional[str] = None,
        original_file_name: Optional[str] = None,
        category_id: Optional[str] = None,
        subcategory_id: Optional[str] = None,
        storage_uri: Optional[str] = None,
        storage_locator: Optional[StorageLocator] = None,
        source_asset_id: Optional[str] = None,
        content_asset_id: Optional[str] = None,
        status: str = ProjectAssetLifecycleStatus.ACTIVE.value,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> ProjectAssetRecord:
        ProjectAssetMediaKind(media_kind)
        ProjectAssetSource(source)
        ProjectAssetLifecycleStatus(status)
        category_id, subcategory_id = validate_project_asset_category(category_id, subcategory_id)
        if storage_locator is not None and not isinstance(storage_locator, StorageLocator):
            storage_locator = StorageLocator.model_validate(storage_locator)

        now = datetime.utcnow().isoformat()
        asset_id = str(uuid.uuid4())
        self._conn.execute(
            """
            INSERT INTO project_assets (
                id, project_id, user_id, source_asset_id, content_asset_id,
                media_kind, source, mime_type, file_name, original_file_name,
                category_id, subcategory_id, storage_uri,
                storage_provider, storage_namespace, storage_object_key,
                storage_version, storage_checksum_sha256, status,
                metadata, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                asset_id,
                project_id,
                user_id,
                source_asset_id,
                content_asset_id,
                media_kind,
                source,
                mime_type,
                file_name,
                original_file_name or file_name,
                category_id,
                subcategory_id,
                storage_uri,
                storage_locator.provider if storage_locator else None,
                storage_locator.namespace if storage_locator else None,
                storage_locator.object_key if storage_locator else None,
                storage_locator.version if storage_locator else None,
                storage_locator.checksum_sha256 if storage_locator else None,
                status,
                json.dumps(metadata or {}),
                now,
                now,
            ),
        )
        self._record_project_asset_event(
            asset_id=asset_id,
            project_id=project_id,
            user_id=user_id,
            event_type="created",
            metadata=metadata or {},
        )
        self._conn.commit()
        return self.get_project_asset_detail(
            project_id=project_id,
            user_id=user_id,
            asset_id=asset_id,
        )

    def assign_project_asset_category(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        category_id: Optional[str],
        subcategory_id: Optional[str] = None,
    ) -> ProjectAssetRecord:
        self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        category_id, subcategory_id = validate_project_asset_category(category_id, subcategory_id)
        now = datetime.utcnow().isoformat()
        self._conn.execute(
            """
            UPDATE project_assets
            SET category_id = ?, subcategory_id = ?, updated_at = ?
            WHERE id = ? AND project_id = ? AND user_id = ?
            """,
            (category_id, subcategory_id, now, asset_id, project_id, user_id),
        )
        self._record_project_asset_event(
            asset_id=asset_id,
            project_id=project_id,
            user_id=user_id,
            event_type="category_assigned" if category_id else "category_cleared",
            metadata={"category_id": category_id, "subcategory_id": subcategory_id},
        )
        self._conn.commit()
        return self.get_project_asset_detail(
            project_id=project_id,
            user_id=user_id,
            asset_id=asset_id,
        )

    def get_project_asset_usage(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
    ) -> List[ProjectAssetUsageRecord]:
        self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        rows = self._conn.execute(
            """
            SELECT * FROM project_asset_usages
            WHERE asset_id = ? AND project_id = ? AND user_id = ? AND deleted_at IS NULL
            ORDER BY updated_at DESC
            """,
            (asset_id, project_id, user_id),
        ).fetchall()
        return [self._row_to_project_asset_usage(row) for row in rows]

    def ensure_video_source_folder_usage_target(
        self, *, project_id: str, user_id: str, folder_id: str
    ) -> None:
        """Register a scoped projection target for the cross-store intake folder."""
        now = datetime.utcnow().isoformat()
        self._conn.execute(
            """
            INSERT INTO project_asset_usage_targets (
                target_type,target_id,project_id,user_id,created_at,updated_at
            ) VALUES ('video_source_folder',?,?,?,?,?)
            ON CONFLICT(target_type,target_id,project_id,user_id)
            DO UPDATE SET updated_at=excluded.updated_at
            """,
            (folder_id, project_id, user_id, now, now),
        )
        self._conn.commit()

    def unlink_project_asset_usage(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        target_type: str,
        target_id: str,
        source_id: str | None = None,
    ) -> int:
        """Soft-delete only matching usage links; the canonical asset is retained."""
        self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        rows = self._conn.execute(
            """
            SELECT id,metadata FROM project_asset_usages
            WHERE asset_id=? AND project_id=? AND user_id=? AND target_type=? AND target_id=?
              AND deleted_at IS NULL
            """,
            (asset_id, project_id, user_id, target_type, target_id),
        ).fetchall()
        usage_ids: list[str] = []
        for row in rows:
            metadata = json.loads(row["metadata"] or "{}")
            if source_id is None or metadata.get("source_id") == source_id:
                usage_ids.append(row["id"])
        if not usage_ids:
            return 0
        now = datetime.utcnow().isoformat()
        placeholders = ",".join("?" for _ in usage_ids)
        self._conn.execute(
            f"UPDATE project_asset_usages SET deleted_at=?,updated_at=? WHERE id IN ({placeholders})",
            (now, now, *usage_ids),
        )
        self._record_project_asset_event(
            asset_id=asset_id,
            project_id=project_id,
            user_id=user_id,
            event_type="usage_unlinked",
            target_type=target_type,
            target_id=target_id,
            metadata={"source_id": source_id, "usage_count": len(usage_ids)},
        )
        self._conn.commit()
        return len(usage_ids)

    def unlink_video_source_usages(
        self,
        *,
        project_id: str,
        user_id: str,
        folder_id: str,
        source_id: str,
    ) -> int:
        """Soft-delete every original/derived usage owned by one intake source."""
        rows = self._conn.execute(
            """
            SELECT id,asset_id,metadata FROM project_asset_usages
            WHERE project_id=? AND user_id=? AND target_type='video_source_folder'
              AND target_id=? AND deleted_at IS NULL
            """,
            (project_id, user_id, folder_id),
        ).fetchall()
        matches = [
            row
            for row in rows
            if json.loads(row["metadata"] or "{}").get("source_id") == source_id
        ]
        if not matches:
            return 0
        now = datetime.utcnow().isoformat()
        usage_ids = [row["id"] for row in matches]
        placeholders = ",".join("?" for _ in usage_ids)
        self._conn.execute(
            f"UPDATE project_asset_usages SET deleted_at=?,updated_at=? WHERE id IN ({placeholders})",
            (now, now, *usage_ids),
        )
        for row in matches:
            self._record_project_asset_event(
                asset_id=row["asset_id"],
                project_id=project_id,
                user_id=user_id,
                event_type="usage_unlinked",
                target_type="video_source_folder",
                target_id=folder_id,
                metadata={"source_id": source_id},
            )
        self._conn.commit()
        return len(matches)

    def get_project_asset_events(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
    ) -> List[ProjectAssetEventRecord]:
        self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        rows = self._conn.execute(
            """
            SELECT * FROM project_asset_events
            WHERE asset_id = ? AND project_id = ? AND user_id = ?
            ORDER BY created_at DESC, id DESC
            """,
            (asset_id, project_id, user_id),
        ).fetchall()
        return [self._row_to_project_asset_event(row) for row in rows]

    def ensure_video_version_usage_target(
        self,
        *,
        timeline: Dict[str, Any],
        version: Dict[str, Any],
    ) -> None:
        """Mirror a timeline/version target so project asset usage validation can audit it."""

        now = datetime.utcnow().isoformat()
        timeline_created_at = str(timeline.get("created_at") or now)
        timeline_updated_at = str(timeline.get("updated_at") or now)
        version_created_at = str(version.get("created_at") or now)
        self._conn.execute(
            """
            INSERT INTO video_timelines (
                id, user_id, project_id, content_id, format_preset, status,
                current_version_id, draft_revision, draft_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                current_version_id = excluded.current_version_id,
                draft_revision = excluded.draft_revision,
                draft_json = excluded.draft_json,
                updated_at = excluded.updated_at
            """,
            (
                timeline["id"],
                timeline["user_id"],
                timeline["project_id"],
                timeline["content_id"],
                timeline["format_preset"],
                timeline.get("status") or "active",
                version["id"],
                int(timeline.get("draft_revision") or 0),
                json.dumps(timeline.get("draft") or {}, separators=(",", ":"), sort_keys=True),
                timeline_created_at,
                timeline_updated_at,
            ),
        )
        self._conn.execute(
            """
            INSERT INTO video_timeline_versions (
                id, timeline_id, user_id, project_id, content_id, format_preset,
                version_number, timeline_json, renderer_props_json,
                approved_preview_job_id, preview_approved_at, client_request_id, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                timeline_json = excluded.timeline_json,
                renderer_props_json = excluded.renderer_props_json,
                approved_preview_job_id = excluded.approved_preview_job_id,
                preview_approved_at = excluded.preview_approved_at
            """,
            (
                version["id"],
                version["timeline_id"],
                version["user_id"],
                version["project_id"],
                version["content_id"],
                version["format_preset"],
                int(version.get("version_number") or 0),
                json.dumps(version.get("timeline") or {}, separators=(",", ":"), sort_keys=True),
                json.dumps(version.get("renderer_props") or {}, separators=(",", ":"), sort_keys=True),
                version.get("approved_preview_job_id"),
                version.get("preview_approved_at"),
                version.get("client_request_id"),
                version_created_at,
            ),
        )
        self._conn.commit()

    def get_project_asset_eligibility(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        usage_action: str,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        try:
            asset = self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
            self._ensure_asset_eligible(asset, usage_action, target_type=target_type)
            if usage_action in PROJECT_ASSET_MUTATION_ACTION_TARGETS:
                if not target_type or not target_id:
                    raise ProjectAssetEligibilityError(
                        f"usage_action '{usage_action}' requires target_type and target_id"
                    )
                self._ensure_usage_target_owned(
                    project_id=project_id,
                    user_id=user_id,
                    target_type=target_type,
                    target_id=target_id,
                    usage_action=usage_action,
                )
            return {
                "asset_id": asset_id,
                "usage_action": usage_action,
                "target_type": target_type,
                "target_id": target_id,
                "eligible": True,
                "reason": None,
            }
        except (ContentNotFoundError, ProjectAssetEligibilityError) as exc:
            return {
                "asset_id": asset_id,
                "usage_action": usage_action,
                "target_type": target_type,
                "target_id": target_id,
                "eligible": False,
                "reason": str(exc),
            }

    def select_project_asset(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        target_type: str,
        target_id: str,
        usage_action: str,
        placement: Optional[str] = None,
        is_primary: bool = False,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> ProjectAssetUsageRecord:
        asset = self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        self._ensure_asset_eligible(asset, usage_action, target_type=target_type)
        self._ensure_usage_target_owned(
            project_id=project_id,
            user_id=user_id,
            target_type=target_type,
            target_id=target_id,
            usage_action=usage_action,
        )
        placement = self._canonicalize_publish_placement(
            placement=placement,
            usage_action=usage_action,
        )
        now = datetime.utcnow().isoformat()

        usage_id = str(uuid.uuid4())
        self._conn.execute("BEGIN IMMEDIATE")
        try:
            if is_primary:
                self._demote_matching_primary_usages(
                    project_id=project_id,
                    user_id=user_id,
                    target_type=target_type,
                    target_id=target_id,
                    placement=placement,
                    now=now,
                )
            self._conn.execute(
                """
                INSERT INTO project_asset_usages (
                    id, asset_id, project_id, user_id, target_type, target_id, placement,
                    usage_action, is_primary, metadata, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    usage_id,
                    asset_id,
                    project_id,
                    user_id,
                    target_type,
                    target_id,
                    placement,
                    usage_action,
                    1 if is_primary else 0,
                    json.dumps(metadata or {}),
                    now,
                    now,
                ),
            )
            self._record_project_asset_event(
                asset_id=asset_id,
                project_id=project_id,
                user_id=user_id,
                event_type="selected",
                target_type=target_type,
                target_id=target_id,
                placement=placement,
                metadata={
                    "usage_action": usage_action,
                    "usage_id": usage_id,
                    "is_primary": is_primary,
                },
            )
            self._conn.commit()
        except Exception:
            self._conn.rollback()
            raise
        row = self._conn.execute("SELECT * FROM project_asset_usages WHERE id = ?", (usage_id,)).fetchone()
        return self._row_to_project_asset_usage(row)

    def list_primary_project_asset_usages(
        self,
        *,
        project_id: str,
        user_id: str,
        content_id: str,
    ) -> list[tuple[ProjectAssetUsageRecord, ProjectAssetRecord | None]]:
        """Return one newest owner-scoped primary per canonical publish placement."""

        self._ensure_usage_target_owned(
            project_id=project_id,
            user_id=user_id,
            target_type="content",
            target_id=content_id,
            usage_action="publish_media",
        )
        rows = self._conn.execute(
            """
            SELECT * FROM project_asset_usages
            WHERE project_id=? AND user_id=? AND target_type='content' AND target_id=?
              AND is_primary=1 AND deleted_at IS NULL AND placement IS NOT NULL
            ORDER BY updated_at DESC, id DESC
            """,
            (project_id, user_id, content_id),
        ).fetchall()
        resolved: dict[str, tuple[ProjectAssetUsageRecord, ProjectAssetRecord | None]] = {}
        for row in rows:
            entry = lookup_placement(row["placement"])
            if entry is None or entry.id in resolved:
                continue
            usage = self._row_to_project_asset_usage(row)
            try:
                asset = self.get_project_asset_detail(
                    project_id=project_id,
                    user_id=user_id,
                    asset_id=usage.asset_id,
                )
            except ContentNotFoundError:
                asset = None
            resolved[entry.id] = (usage.model_copy(update={"placement": entry.id}), asset)
        return list(resolved.values())

    def set_project_asset_primary(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        target_type: str,
        target_id: str,
        usage_action: str,
        placement: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> ProjectAssetUsageRecord:
        return self.select_project_asset(
            project_id=project_id,
            user_id=user_id,
            asset_id=asset_id,
            target_type=target_type,
            target_id=target_id,
            usage_action=usage_action,
            placement=placement,
            is_primary=True,
            metadata=metadata,
        )

    def clear_project_asset_primary(
        self,
        *,
        project_id: str,
        user_id: str,
        target_type: str,
        target_id: str,
        placement: Optional[str] = None,
    ) -> int:
        requested_entry = lookup_placement(placement) if placement else None
        canonical_placement = requested_entry.id if requested_entry else placement
        now = datetime.utcnow().isoformat()
        rows = self._conn.execute(
            """
            SELECT id, asset_id, placement FROM project_asset_usages
            WHERE project_id = ? AND user_id = ? AND target_type = ? AND target_id = ?
              AND is_primary = 1 AND deleted_at IS NULL
            """,
            (project_id, user_id, target_type, target_id),
        ).fetchall()
        matches = []
        for row in rows:
            existing_entry = lookup_placement(row["placement"]) if row["placement"] else None
            existing_placement = existing_entry.id if existing_entry else row["placement"]
            if existing_placement == canonical_placement:
                matches.append(row)
        if matches:
            placeholders = ",".join("?" for _ in matches)
            self._conn.execute(
                f"UPDATE project_asset_usages SET is_primary=0, updated_at=? WHERE id IN ({placeholders})",
                (now, *(row["id"] for row in matches)),
            )
        changed = len(matches)
        for row in matches:
            self._record_project_asset_event(
                asset_id=row["asset_id"],
                project_id=project_id,
                user_id=user_id,
                event_type="primary_cleared",
                target_type=target_type,
                target_id=target_id,
                placement=canonical_placement,
                metadata={"cleared_count": changed},
            )
        self._conn.commit()
        return changed

    @staticmethod
    def _canonicalize_publish_placement(
        *, placement: Optional[str], usage_action: str
    ) -> Optional[str]:
        if usage_action not in {"publish_media", "set_primary"}:
            return placement
        if not placement:
            raise ProjectAssetEligibilityError(
                f"usage_action '{usage_action}' requires a publish placement"
            )
        try:
            return validate_placement_id(placement)
        except ValueError as exc:
            raise ProjectAssetEligibilityError(str(exc)) from exc

    def _demote_matching_primary_usages(
        self,
        *,
        project_id: str,
        user_id: str,
        target_type: str,
        target_id: str,
        placement: Optional[str],
        now: str,
    ) -> None:
        rows = self._conn.execute(
            """
            SELECT id, placement FROM project_asset_usages
            WHERE project_id=? AND user_id=? AND target_type=? AND target_id=?
              AND is_primary=1 AND deleted_at IS NULL
            """,
            (project_id, user_id, target_type, target_id),
        ).fetchall()
        canonical = lookup_placement(placement).id if placement and lookup_placement(placement) else placement
        ids = []
        for row in rows:
            existing = lookup_placement(row["placement"])
            existing_value = existing.id if existing else row["placement"]
            if existing_value == canonical:
                ids.append(row["id"])
        if ids:
            placeholders = ",".join("?" for _ in ids)
            self._conn.execute(
                f"UPDATE project_asset_usages SET is_primary=0, updated_at=? WHERE id IN ({placeholders})",
                (now, *ids),
            )

    def tombstone_project_asset(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
    ) -> ProjectAssetRecord:
        self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        now = datetime.utcnow()
        cleanup_eligible_at = now.replace(microsecond=0).timestamp() + (30 * 24 * 3600)
        self._conn.execute(
            """
            UPDATE project_assets
            SET status = ?, tombstoned_at = ?, cleanup_eligible_at = ?, updated_at = ?
            WHERE id = ? AND project_id = ? AND user_id = ?
            """,
            (
                ProjectAssetLifecycleStatus.TOMBSTONED.value,
                now.isoformat(),
                datetime.utcfromtimestamp(cleanup_eligible_at).isoformat(),
                now.isoformat(),
                asset_id,
                project_id,
                user_id,
            ),
        )
        self._record_project_asset_event(
            asset_id=asset_id,
            project_id=project_id,
            user_id=user_id,
            event_type="tombstoned",
            metadata={"cleanup_eligible_at": datetime.utcfromtimestamp(cleanup_eligible_at).isoformat()},
        )
        self._conn.commit()
        return self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)

    def restore_project_asset(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
    ) -> ProjectAssetRecord:
        asset = self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        if asset.status != ProjectAssetLifecycleStatus.TOMBSTONED.value:
            return asset
        self._conn.execute(
            """
            UPDATE project_assets
            SET status = ?, tombstoned_at = NULL, cleanup_eligible_at = NULL, updated_at = ?
            WHERE id = ? AND project_id = ? AND user_id = ?
            """,
            (
                ProjectAssetLifecycleStatus.ACTIVE.value,
                datetime.utcnow().isoformat(),
                asset_id,
                project_id,
                user_id,
            ),
        )
        self._record_project_asset_event(
            asset_id=asset_id,
            project_id=project_id,
            user_id=user_id,
            event_type="restored",
        )
        self._conn.commit()
        return self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)

    def queue_asset_understanding_job(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        idempotency_key: str,
        provider: str = "gemini_compatible",
    ) -> AssetUnderstandingJobRecord:
        asset = self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        row = self._conn.execute(
            """
            SELECT * FROM asset_understanding_jobs
            WHERE user_id = ? AND project_id = ? AND asset_id = ? AND idempotency_key = ?
            LIMIT 1
            """,
            (user_id, project_id, asset_id, idempotency_key),
        ).fetchone()
        if row:
            return self._row_to_asset_understanding_job(row)

        guardrails = AssetUnderstandingGuardrails.from_env()
        media_type = "video" if asset.media_kind in {"video", "video_cover", "render_output"} else "image"
        resolver = AssetUnderstandingCredentialResolver()

        now = datetime.utcnow().isoformat()
        job_id = str(uuid.uuid4())
        status = "queued"
        credential_source = None
        error_code = None
        error_message = None
        metadata: Dict[str, Any] = {}
        try:
            resolved = _run_async(resolver.resolve(user_id=user_id, provider=provider))
            credential_source = resolved.source
            used_today = self._quota_used_today(
                user_id=user_id,
                credential_source=credential_source,
                media_type=media_type,
            )
            guardrails.validate_quota(
                media_type=media_type,
                credential_source=credential_source,
                used_today=used_today,
            )
            self._increment_quota(
                user_id=user_id,
                credential_source=credential_source,
                media_type=media_type,
            )
        except AssetUnderstandingError as exc:
            status = "blocked" if exc.code == "provider_not_configured" else "failed"
            error_code = exc.code
            error_message = exc.message
            metadata = {"retryable": exc.retryable, "details": exc.details}

        self._conn.execute(
            """
            INSERT INTO asset_understanding_jobs (
                id, asset_id, project_id, user_id, media_type, provider, credential_source,
                status, idempotency_key, retry_of_job_id, error_code, error_message,
                attempts, metadata, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                job_id,
                asset_id,
                project_id,
                user_id,
                media_type,
                provider,
                credential_source,
                status,
                idempotency_key,
                None,
                error_code,
                error_message,
                0,
                json.dumps(metadata),
                now,
                now,
            ),
        )
        self._record_project_asset_event(
            asset_id=asset_id,
            project_id=project_id,
            user_id=user_id,
            event_type="understanding_queued",
            metadata={"job_id": job_id, "status": status, "provider": provider},
        )
        self._conn.commit()
        return self.get_asset_understanding_job(project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job_id)

    def retry_asset_understanding_job(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        job_id: str,
    ) -> AssetUnderstandingJobRecord:
        previous = self.get_asset_understanding_job(
            project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job_id
        )
        max_retries = int(os.getenv("ASSET_UNDERSTANDING_MAX_RETRIES", "2"))
        if previous.attempts >= max_retries:
            raise ValueError(f"Retry limit reached for job {job_id}")
        return self.queue_asset_understanding_job(
            project_id=project_id,
            user_id=user_id,
            asset_id=asset_id,
            idempotency_key=f"retry:{job_id}:{datetime.utcnow().isoformat()}",
            provider=previous.provider,
        )

    def execute_asset_understanding_job(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        job_id: str,
        adapter: Optional[AssetUnderstandingProviderAdapter] = None,
    ) -> AssetUnderstandingJobRecord:
        job = self.get_asset_understanding_job(project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job_id)
        if job.status in {"completed", "blocked"}:
            return job
        if job.status == "failed":
            max_retries = int(os.getenv("ASSET_UNDERSTANDING_MAX_RETRIES", "2"))
            if job.attempts >= max_retries:
                return job

        guardrails = AssetUnderstandingGuardrails.from_env()
        running_project = self._count_running_jobs(project_id=project_id, user_id=user_id, scope="project", exclude_job_id=job_id)
        running_user = self._count_running_jobs(project_id=project_id, user_id=user_id, scope="user", exclude_job_id=job_id)
        if running_project >= guardrails.concurrency_per_project or running_user >= guardrails.concurrency_per_user:
            return job

        now = datetime.utcnow().isoformat()
        self._conn.execute(
            """
            UPDATE asset_understanding_jobs
            SET status = ?, attempts = attempts + 1, error_code = NULL, error_message = NULL, updated_at = ?
            WHERE id = ?
            """,
            ("running", now, job_id),
        )
        self._conn.commit()

        asset = self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        media = AssetMediaEnvelope(
            media_type=job.media_type,  # type: ignore[arg-type]
            size_bytes=asset.metadata.get("byte_size") if isinstance(asset.metadata, dict) else None,
            duration_seconds=asset.metadata.get("duration_seconds") if isinstance(asset.metadata, dict) else None,
        )
        try:
            guardrails.validate_media(media)
            provider_adapter = adapter or NoopGeminiCompatibleAdapter()
            if job.media_type == "video":
                payload = _run_async(provider_adapter.analyze_video(media=media, prompt_context={"asset_id": asset_id}))
            else:
                payload = _run_async(provider_adapter.analyze_image(media=media, prompt_context={"asset_id": asset_id}))
            self.save_asset_understanding_result(
                project_id=project_id,
                user_id=user_id,
                asset_id=asset_id,
                job_id=job_id,
                provider_payload=payload,
            )
            return self.get_asset_understanding_job(project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job_id)
        except Exception as exc:
            if isinstance(exc, AssetUnderstandingError):
                error_code = exc.code
                error_message = exc.message
                retryable = bool(exc.retryable)
            else:
                error_code = "provider_execution_failed"
                error_message = str(exc)
                retryable = True
            attempts_row = self._conn.execute(
                "SELECT attempts FROM asset_understanding_jobs WHERE id = ?",
                (job_id,),
            ).fetchone()
            attempts = int(attempts_row["attempts"]) if attempts_row else 1
            max_retries = int(os.getenv("ASSET_UNDERSTANDING_MAX_RETRIES", "2"))
            backoff_seconds = 2 ** max(0, attempts - 1)
            next_retry_at = datetime.utcfromtimestamp(datetime.utcnow().timestamp() + backoff_seconds).isoformat()
            status = "failed"
            metadata = {"retryable": retryable, "backoff_seconds": backoff_seconds, "next_retry_at": next_retry_at}
            if attempts >= max_retries:
                metadata["retry_capped"] = True
            self._conn.execute(
                """
                UPDATE asset_understanding_jobs
                SET status = ?, error_code = ?, error_message = ?, metadata = ?, updated_at = ?
                WHERE id = ?
                """,
                (status, error_code, error_message, json.dumps(metadata), datetime.utcnow().isoformat(), job_id),
            )
            self._conn.commit()
            return self.get_asset_understanding_job(project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job_id)

    def get_asset_understanding_job(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        job_id: str,
    ) -> AssetUnderstandingJobRecord:
        self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        row = self._conn.execute(
            """
            SELECT * FROM asset_understanding_jobs
            WHERE id = ? AND project_id = ? AND user_id = ? AND asset_id = ?
            LIMIT 1
            """,
            (job_id, project_id, user_id, asset_id),
        ).fetchone()
        if not row:
            raise ContentNotFoundError(f"Understanding job {job_id} not found")
        return self._row_to_asset_understanding_job(row)

    def get_latest_asset_understanding_status(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
    ) -> Dict[str, Any]:
        self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=asset_id)
        row = self._conn.execute(
            """
            SELECT * FROM asset_understanding_jobs
            WHERE project_id = ? AND user_id = ? AND asset_id = ?
            ORDER BY updated_at DESC, created_at DESC
            LIMIT 1
            """,
            (project_id, user_id, asset_id),
        ).fetchone()
        if not row:
            return {"job": None, "result": None}
        job = self._row_to_asset_understanding_job(row)
        result = self.get_asset_understanding_result(project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job.id)
        return {"job": job, "result": result}

    def save_asset_understanding_result(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        job_id: str,
        provider_payload: Dict[str, Any],
    ) -> AssetUnderstandingResultRecord:
        job = self.get_asset_understanding_job(project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job_id)
        normalized = normalize_understanding_payload(provider_payload)
        now = datetime.utcnow().isoformat()
        result_id = str(uuid.uuid4())
        self._conn.execute(
            """
            INSERT INTO asset_understanding_results (
                id, job_id, asset_id, project_id, user_id, provider, credential_source,
                summary, source_attribution, metadata, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                result_id,
                job_id,
                asset_id,
                project_id,
                user_id,
                job.provider,
                job.credential_source,
                normalized.summary,
                json.dumps(normalized.source_attribution.__dict__),
                json.dumps({}),
                now,
                now,
            ),
        )
        decisions = self._latest_tag_decisions(asset_id=asset_id, project_id=project_id, user_id=user_id)
        for tag in normalized.tags:
            decision = decisions.get(self._tag_decision_key(tag.key, tag.label), {})
            self._conn.execute(
                """
                INSERT INTO asset_understanding_tags (
                    id, result_id, asset_id, project_id, user_id, key, label, confidence, source,
                    accepted_by_user, rejected_by_user, metadata, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()),
                    result_id,
                    asset_id,
                    project_id,
                    user_id,
                    tag.key,
                    tag.label,
                    tag.confidence,
                    tag.source,
                    1 if bool(decision.get("accepted_by_user", tag.accepted_by_user)) else 0,
                    1 if bool(decision.get("rejected_by_user", tag.rejected_by_user)) else 0,
                    "{}",
                    now,
                ),
            )
        for segment in normalized.segments:
            self._conn.execute(
                """
                INSERT INTO asset_understanding_segments (
                    id, result_id, asset_id, project_id, user_id, start_seconds, end_seconds, label,
                    confidence, suggested_placement, metadata, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()),
                    result_id,
                    asset_id,
                    project_id,
                    user_id,
                    segment.start_seconds,
                    segment.end_seconds,
                    segment.label,
                    segment.confidence,
                    segment.suggested_placement,
                    "{}",
                    now,
                ),
            )
        self._conn.execute(
            "UPDATE asset_understanding_jobs SET status = ?, updated_at = ? WHERE id = ?",
            ("completed", now, job_id),
        )
        self._conn.commit()
        return self.get_asset_understanding_result(project_id=project_id, user_id=user_id, asset_id=asset_id, job_id=job_id)

    def moderate_asset_understanding_tags(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        decisions: List[Dict[str, Any]],
        manual_tags: List[str],
    ) -> Dict[str, Any]:
        data = self.get_latest_asset_understanding_status(project_id=project_id, user_id=user_id, asset_id=asset_id)
        if not data["job"] or not data["result"]:
            raise ContentNotFoundError(f"No understanding result found for asset {asset_id}")
        result = data["result"]
        now = datetime.utcnow().isoformat()
        for decision in decisions:
            action = (decision.get("action") or "").strip().lower()
            key = str(decision.get("key") or "").strip().lower()
            label = str(decision.get("label") or "").strip()
            if not action or not key or not label:
                continue
            self._conn.execute(
                """
                UPDATE asset_understanding_tags
                SET accepted_by_user = ?, rejected_by_user = ?
                WHERE result_id = ? AND lower(key) = ? AND label = ?
                """,
                (1 if action == "accept" else 0, 1 if action == "reject" else 0, result.id, key, label),
            )
            if action == "edit":
                edited_label = str(decision.get("edited_label") or "").strip()
                if edited_label:
                    self._conn.execute(
                        """
                        INSERT INTO asset_understanding_tags (
                            id, result_id, asset_id, project_id, user_id, key, label, confidence, source,
                            accepted_by_user, rejected_by_user, metadata, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            str(uuid.uuid4()),
                            result.id,
                            asset_id,
                            project_id,
                            user_id,
                            key,
                            edited_label[:128],
                            1.0,
                            "user_manual",
                            1,
                            0,
                            "{}",
                            now,
                        ),
                    )
        for raw_label in manual_tags:
            label = raw_label.strip()
            if not label:
                continue
            self._conn.execute(
                """
                INSERT INTO asset_understanding_tags (
                    id, result_id, asset_id, project_id, user_id, key, label, confidence, source,
                    accepted_by_user, rejected_by_user, metadata, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()),
                    result.id,
                    asset_id,
                    project_id,
                    user_id,
                    label.lower().replace(" ", "_")[:64],
                    label[:128],
                    1.0,
                    "user_manual",
                    1,
                    0,
                    "{}",
                    now,
                ),
            )
        self._conn.commit()
        return self.get_latest_asset_understanding_status(project_id=project_id, user_id=user_id, asset_id=asset_id)

    def get_asset_understanding_result(
        self,
        *,
        project_id: str,
        user_id: str,
        asset_id: str,
        job_id: str,
    ) -> Optional[AssetUnderstandingResultRecord]:
        row = self._conn.execute(
            """
            SELECT * FROM asset_understanding_results
            WHERE project_id = ? AND user_id = ? AND asset_id = ? AND job_id = ?
            LIMIT 1
            """,
            (project_id, user_id, asset_id, job_id),
        ).fetchone()
        if not row:
            return None
        tags = self._conn.execute(
            "SELECT * FROM asset_understanding_tags WHERE result_id = ? ORDER BY confidence DESC, id ASC",
            (row["id"],),
        ).fetchall()
        segments = self._conn.execute(
            "SELECT * FROM asset_understanding_segments WHERE result_id = ? ORDER BY start_seconds ASC, id ASC",
            (row["id"],),
        ).fetchall()
        return AssetUnderstandingResultRecord(
            id=row["id"],
            job_id=row["job_id"],
            asset_id=row["asset_id"],
            project_id=row["project_id"],
            user_id=row["user_id"],
            provider=row["provider"],
            credential_source=row["credential_source"],
            summary=row["summary"],
            source_attribution=AssetSourceAttribution(**json.loads(row["source_attribution"] or "{}")),
            tags=[self._row_to_asset_understanding_tag(item) for item in tags],
            segments=[self._row_to_asset_understanding_segment(item) for item in segments],
            metadata=json.loads(row["metadata"] or "{}"),
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
        )

    def recommend_project_assets_for_brief(
        self,
        *,
        project_id: str,
        user_id: str,
        desired_tags: List[str],
        limit: int = 10,
        include_global_candidates: bool = False,
    ) -> List[Dict[str, Any]]:
        self.list_project_assets(project_id=project_id, user_id=user_id)
        desired = {item.strip().lower() for item in desired_tags if item.strip()}
        rows = self._conn.execute(
            """
            SELECT t.asset_id, t.key, t.label, t.confidence, r.source_attribution, a.status, a.project_id
            FROM asset_understanding_tags t
            JOIN asset_understanding_results r ON r.id = t.result_id
            JOIN project_assets a ON a.id = t.asset_id
            WHERE a.project_id = ? AND a.user_id = ? AND a.status = 'active' AND t.rejected_by_user = 0
            ORDER BY t.confidence DESC
            """,
            (project_id, user_id),
        ).fetchall()
        if include_global_candidates:
            rows += self._conn.execute(
                """
                SELECT t.asset_id, t.key, t.label, t.confidence, r.source_attribution, a.status, a.project_id
                FROM asset_understanding_tags t
                JOIN asset_understanding_results r ON r.id = t.result_id
                JOIN project_assets a ON a.id = t.asset_id
                WHERE a.user_id = ?
                  AND a.project_id != ?
                  AND a.status = 'active'
                  AND t.rejected_by_user = 0
                  AND NOT EXISTS (
                    SELECT 1 FROM project_assets target
                    WHERE target.project_id = ?
                      AND target.user_id = ?
                      AND target.status != 'tombstoned'
                      AND (target.id = a.id OR target.source_asset_id = a.id)
                  )
                ORDER BY t.confidence DESC
                """,
                (user_id, project_id, project_id, user_id),
            ).fetchall()
        by_asset: Dict[str, Dict[str, Any]] = {}
        for row in rows:
            key = (row["key"] or "").lower()
            label = (row["label"] or "").lower()
            score = float(row["confidence"] or 0.0)
            if desired and key not in desired and label not in desired:
                continue
            attribution = json.loads(row["source_attribution"] or "{}")
            bucket = by_asset.setdefault(
                row["asset_id"],
                {
                    "score": 0.0,
                    "reasons": [],
                    "warnings": [],
                    "placements": set(),
                    "source_attribution": attribution,
                    "source_project_id": row["project_id"],
                    "candidate_type": "attached_project_asset"
                    if row["project_id"] == project_id
                    else "candidate_global_asset",
                    "requires_project_attachment": row["project_id"] != project_id,
                },
            )
            bucket["score"] += score
            bucket["reasons"].append({"tag": row["label"], "confidence": score, "fit_reason": f"Matches '{row['label']}'"})
            if attribution.get("rights_status", "unknown") == "unknown" or attribution.get("credit_required"):
                if "credit_required" not in bucket["warnings"]:
                    bucket["warnings"].append("credit_required")
            if key in {"b_roll", "broll", "motion"}:
                bucket["placements"].add("b_roll")
            if key in {"illustration", "reference"}:
                bucket["placements"].add("illustration")
            if key in {"thumbnail", "thumbnail_candidate"}:
                bucket["placements"].add("thumbnail_candidate")
        ranked = sorted(by_asset.items(), key=lambda item: item[1]["score"], reverse=True)[:limit]
        return [
            {
                "asset_id": asset_id,
                "score": round(payload["score"], 4),
                "candidate_type": payload["candidate_type"],
                "source_project_id": payload["source_project_id"],
                "requires_project_attachment": payload["requires_project_attachment"],
                "fit_reasons": payload["reasons"],
                "suggested_placements": sorted(payload["placements"]),
                "source_attribution": payload["source_attribution"],
                "warnings": payload["warnings"],
            }
            for asset_id, payload in ranked
        ]

    def attach_global_project_asset(
        self,
        *,
        project_id: str,
        user_id: str,
        global_asset_id: str,
    ) -> ProjectAssetRecord:
        source_row = self._conn.execute(
            """
            SELECT * FROM project_assets
            WHERE id = ? AND user_id = ? AND status = 'active'
            LIMIT 1
            """,
            (global_asset_id, user_id),
        ).fetchone()
        if not source_row:
            raise ContentNotFoundError(f"Global asset {global_asset_id} not found")
        if source_row["project_id"] == project_id:
            return self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=global_asset_id)

        existing = self._conn.execute(
            """
            SELECT * FROM project_assets
            WHERE project_id = ? AND user_id = ? AND source_asset_id = ? AND status != 'tombstoned'
            ORDER BY updated_at DESC
            LIMIT 1
            """,
            (project_id, user_id, global_asset_id),
        ).fetchone()
        if existing:
            return self._row_to_project_asset(existing)

        now = datetime.utcnow().isoformat()
        new_asset_id = str(uuid.uuid4())
        source_metadata = json.loads(source_row["metadata"] or "{}")
        source_metadata["global_library_source_asset_id"] = global_asset_id
        source_metadata["global_library_source_project_id"] = source_row["project_id"]
        self._conn.execute(
            """
            INSERT INTO project_assets (
                id, project_id, user_id, source_asset_id, content_asset_id,
                media_kind, source, mime_type, file_name, original_file_name,
                category_id, subcategory_id, storage_uri, status, metadata,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                new_asset_id,
                project_id,
                user_id,
                global_asset_id,
                None,
                source_row["media_kind"],
                source_row["source"],
                source_row["mime_type"],
                source_row["file_name"],
                source_row["original_file_name"],
                source_row["category_id"],
                source_row["subcategory_id"],
                source_row["storage_uri"],
                ProjectAssetLifecycleStatus.ACTIVE.value,
                json.dumps(source_metadata),
                now,
                now,
            ),
        )
        self._record_project_asset_event(
            asset_id=new_asset_id,
            project_id=project_id,
            user_id=user_id,
            event_type="attached_from_global_library",
            metadata={"global_asset_id": global_asset_id, "source_project_id": source_row["project_id"]},
        )
        self._conn.commit()
        return self.get_project_asset_detail(project_id=project_id, user_id=user_id, asset_id=new_asset_id)

    def _count_running_jobs(
        self,
        *,
        project_id: str,
        user_id: str,
        scope: str,
        exclude_job_id: Optional[str] = None,
    ) -> int:
        if scope == "project":
            query = "SELECT COUNT(*) as c FROM asset_understanding_jobs WHERE project_id = ? AND user_id = ? AND status = 'running'"
            params: List[Any] = [project_id, user_id]
        else:
            query = "SELECT COUNT(*) as c FROM asset_understanding_jobs WHERE user_id = ? AND status = 'running'"
            params = [user_id]
        if exclude_job_id:
            query += " AND id != ?"
            params.append(exclude_job_id)
        row = self._conn.execute(query, tuple(params)).fetchone()
        return int(row["c"] if row else 0)

    def _latest_tag_decisions(self, *, project_id: str, user_id: str, asset_id: str) -> Dict[str, Dict[str, bool]]:
        rows = self._conn.execute(
            """
            SELECT key, label, accepted_by_user, rejected_by_user
            FROM asset_understanding_tags
            WHERE project_id = ? AND user_id = ? AND asset_id = ?
            ORDER BY created_at DESC
            """,
            (project_id, user_id, asset_id),
        ).fetchall()
        decisions: Dict[str, Dict[str, bool]] = {}
        for row in rows:
            composite = self._tag_decision_key(row["key"], row["label"])
            if composite in decisions:
                continue
            decisions[composite] = {
                "accepted_by_user": bool(row["accepted_by_user"]),
                "rejected_by_user": bool(row["rejected_by_user"]),
            }
        return decisions

    @staticmethod
    def _tag_decision_key(key: str, label: str) -> str:
        return f"{(key or '').strip().lower()}::{(label or '').strip().lower()}"

    def _quota_used_today(self, *, user_id: str, credential_source: str, media_type: str) -> int:
        day_utc = datetime.utcnow().date().isoformat()
        row = self._conn.execute(
            """
            SELECT used_count FROM asset_understanding_quota_daily
            WHERE day_utc = ? AND user_id = ? AND credential_source = ? AND media_type = ?
            LIMIT 1
            """,
            (day_utc, user_id, credential_source, media_type),
        ).fetchone()
        return int(row["used_count"]) if row else 0

    def _increment_quota(self, *, user_id: str, credential_source: str, media_type: str) -> None:
        day_utc = datetime.utcnow().date().isoformat()
        now = datetime.utcnow().isoformat()
        self._conn.execute(
            """
            INSERT INTO asset_understanding_quota_daily (
                day_utc, user_id, credential_source, media_type, used_count, updated_at
            ) VALUES (?, ?, ?, ?, 1, ?)
            ON CONFLICT(day_utc, user_id, credential_source, media_type)
            DO UPDATE SET used_count = used_count + 1, updated_at = excluded.updated_at
            """,
            (day_utc, user_id, credential_source, media_type, now),
        )

    def _normalize_project_assets_from_content_assets(self, *, project_id: str, user_id: str) -> None:
        rows = self._conn.execute(
            """
            SELECT * FROM content_assets
            WHERE project_id = ? AND user_id = ? AND deleted_at IS NULL
            """,
            (project_id, user_id),
        ).fetchall()
        now = datetime.utcnow().isoformat()
        for row in rows:
            existing = self._conn.execute(
                "SELECT id FROM project_assets WHERE content_asset_id = ?",
                (row["id"],),
            ).fetchone()
            if existing:
                continue
            media_kind = self._infer_media_kind(row["kind"], row["mime_type"])
            status = (
                ProjectAssetLifecycleStatus.LOCAL_ONLY.value
                if row["status"] == ContentAssetStatus.LOCAL_ONLY.value
                else ProjectAssetLifecycleStatus.ACTIVE.value
            )
            self._conn.execute(
                """
                INSERT INTO project_assets (
                    id, project_id, user_id, source_asset_id, content_asset_id, media_kind, source,
                    mime_type, file_name, original_file_name, storage_uri, status, metadata,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()),
                    project_id,
                    user_id,
                    row["id"],
                    row["id"],
                    media_kind,
                    ProjectAssetSource.CONTENT_ASSET.value,
                    row["mime_type"],
                    row["file_name"],
                    row["file_name"],
                    row["storage_uri"],
                    status,
                    row["metadata"] or "{}",
                    row["created_at"] or now,
                    now,
                ),
            )
        self._conn.commit()

    def _ensure_asset_eligible(
        self,
        asset: ProjectAssetRecord,
        usage_action: str,
        *,
        target_type: Optional[str] = None,
    ) -> None:
        if usage_action not in PROJECT_ASSET_SUPPORTED_ACTIONS:
            raise ProjectAssetEligibilityError(f"Unsupported usage_action '{usage_action}'")
        if usage_action == "historical_only":
            return
        if usage_action == "preview_only":
            if asset.status == ProjectAssetLifecycleStatus.TOMBSTONED.value:
                raise ProjectAssetEligibilityError("Tombstoned assets are historical-only")
            return
        if asset.status in (
            ProjectAssetLifecycleStatus.TOMBSTONED.value,
            ProjectAssetLifecycleStatus.DEGRADED.value,
            ProjectAssetLifecycleStatus.LOCAL_ONLY.value,
        ):
            raise ProjectAssetEligibilityError(f"Asset status '{asset.status}' is not eligible for '{usage_action}'")
        if usage_action in {"promote_reference", "select_for_content"} and asset.media_kind not in {
            ProjectAssetMediaKind.IMAGE.value,
            ProjectAssetMediaKind.THUMBNAIL.value,
            ProjectAssetMediaKind.VIDEO_COVER.value,
            ProjectAssetMediaKind.CAPTURE.value,
        }:
            raise ProjectAssetEligibilityError(f"Incompatible media_kind '{asset.media_kind}' for '{usage_action}'")
        if (
            usage_action in {"select_for_video_version", "use_in_remotion_render"}
            or (usage_action == "publish_media" and target_type == "video_version")
        ):
            self._ensure_video_version_asset_eligible(asset, usage_action)
        if usage_action == "set_primary":
            if target_type == "content" and asset.media_kind not in {
                ProjectAssetMediaKind.IMAGE.value,
                ProjectAssetMediaKind.THUMBNAIL.value,
                ProjectAssetMediaKind.VIDEO_COVER.value,
                ProjectAssetMediaKind.CAPTURE.value,
            }:
                raise ProjectAssetEligibilityError(
                    f"Incompatible media_kind '{asset.media_kind}' for '{usage_action}' on '{target_type}'"
                )
            if target_type == "video_version":
                self._ensure_video_version_asset_eligible(asset, usage_action)

    def _ensure_video_version_asset_eligible(
        self,
        asset: ProjectAssetRecord,
        usage_action: str,
    ) -> None:
        if asset.media_kind not in VIDEO_VERSION_MEDIA_KINDS:
            raise ProjectAssetEligibilityError(f"Incompatible media_kind '{asset.media_kind}' for '{usage_action}'")
        if (
            asset.media_kind == ProjectAssetMediaKind.RENDER_OUTPUT.value
            and not bool(asset.metadata.get("render_output_safe"))
        ):
            raise ProjectAssetEligibilityError("render_output assets require explicit render_output_safe metadata")

        descriptor = build_project_asset_storage_descriptor(
            storage_uri=asset.storage_uri,
            storage_locator=asset.storage_locator,
            status=asset.status,
            media_kind=asset.media_kind,
            mime_type=asset.mime_type,
        )
        if not descriptor["render_safe"]:
            raise ProjectAssetEligibilityError("Asset is not render-safe for video rendering")
        if descriptor["refresh_required"] and descriptor["state"] != "durable_bunny_http":
            raise ProjectAssetEligibilityError("Asset requires refresh before video rendering")

    def _ensure_usage_target_owned(
        self,
        *,
        project_id: str,
        user_id: str,
        target_type: str,
        target_id: str,
        usage_action: str,
    ) -> None:
        allowed_targets = PROJECT_ASSET_MUTATION_ACTION_TARGETS.get(usage_action)
        if not allowed_targets:
            raise ProjectAssetEligibilityError(f"Unsupported usage_action '{usage_action}'")
        if target_type not in allowed_targets:
            expected = ", ".join(sorted(allowed_targets))
            raise ProjectAssetEligibilityError(
                f"usage_action '{usage_action}' requires target_type in [{expected}]"
            )

        if target_type == "content":
            row = self._conn.execute(
                """
                SELECT id FROM content_records
                WHERE id = ? AND project_id = ? AND user_id = ?
                LIMIT 1
                """,
                (target_id, project_id, user_id),
            ).fetchone()
            if not row:
                raise ContentNotFoundError(f"Content target {target_id} not found")
            return

        if target_type == "video_version":
            row = self._conn.execute(
                """
                SELECT id FROM video_timeline_versions
                WHERE id = ? AND project_id = ? AND user_id = ?
                LIMIT 1
                """,
                (target_id, project_id, user_id),
            ).fetchone()
            if not row:
                raise ContentNotFoundError(f"Video version target {target_id} not found")
            return

        if target_type == "video_source_folder":
            row = self._conn.execute(
                """
                SELECT target_id FROM project_asset_usage_targets
                WHERE target_type='video_source_folder' AND target_id=?
                  AND project_id=? AND user_id=?
                LIMIT 1
                """,
                (target_id, project_id, user_id),
            ).fetchone()
            if not row:
                raise ContentNotFoundError(f"Video source folder target {target_id} not found")
            return

        raise ProjectAssetEligibilityError(f"Unsupported target_type '{target_type}'")

    def _record_project_asset_event(
        self,
        *,
        asset_id: str,
        project_id: str,
        user_id: str,
        event_type: str,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        placement: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> None:
        self._conn.execute(
            """
            INSERT INTO project_asset_events (
                id, asset_id, project_id, user_id, event_type, target_type,
                target_id, placement, metadata, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                str(uuid.uuid4()),
                asset_id,
                project_id,
                user_id,
                event_type,
                target_type,
                target_id,
                placement,
                json.dumps(metadata or {}),
                datetime.utcnow().isoformat(),
            ),
        )

    @staticmethod
    def _infer_media_kind(kind: Optional[str], mime_type: Optional[str]) -> str:
        mime = (mime_type or "").lower()
        kind_value = (kind or "").lower()
        if mime.startswith("image/"):
            return ProjectAssetMediaKind.IMAGE.value
        if mime.startswith("audio/"):
            return ProjectAssetMediaKind.AUDIO.value
        if mime.startswith("video/"):
            return ProjectAssetMediaKind.VIDEO.value
        if "capture" in kind_value:
            return ProjectAssetMediaKind.CAPTURE.value
        return ProjectAssetMediaKind.CAPTURE.value

    # ─── Schedule Jobs ────────────────────────────────

    def create_schedule_job(self, **kwargs: Any) -> Dict[str, Any]:
        """Create a new schedule job."""
        now = datetime.utcnow().isoformat()
        job_id = str(uuid.uuid4())

        self._conn.execute(
            """
            INSERT INTO schedule_jobs
            (id, user_id, project_id, job_type, generator_id, configuration,
             schedule, cron_expression, schedule_day, schedule_time, timezone,
             enabled, next_run_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                job_id,
                kwargs.get("user_id", "system"),
                kwargs.get("project_id"),
                kwargs["job_type"],
                kwargs.get("generator_id"),
                json.dumps(kwargs.get("configuration", {})),
                kwargs["schedule"],
                kwargs.get("cron_expression"),
                kwargs.get("schedule_day"),
                kwargs.get("schedule_time"),
                kwargs.get("timezone", "UTC"),
                1 if kwargs.get("enabled", True) else 0,
                kwargs.get("next_run_at"),
                now,
                now,
            ),
        )
        self._conn.commit()

        return self.get_schedule_job(job_id)

    def get_schedule_job(self, job_id: str) -> Dict[str, Any]:
        """Get a schedule job by ID."""
        row = self._conn.execute(
            "SELECT * FROM schedule_jobs WHERE id = ?", (job_id,)
        ).fetchone()
        if not row:
            raise ContentNotFoundError(f"Schedule job {job_id} not found")
        return self._row_to_job(row)

    def list_schedule_jobs(
        self,
        user_id: Optional[str] = None,
        project_id: Optional[str] = None,
        enabled_only: bool = False,
    ) -> List[Dict[str, Any]]:
        """List schedule jobs with optional filters."""
        query = "SELECT * FROM schedule_jobs WHERE 1=1"
        params: List[Any] = []

        if user_id:
            query += " AND user_id = ?"
            params.append(user_id)
        if project_id:
            query += " AND project_id = ?"
            params.append(project_id)
        if enabled_only:
            query += " AND enabled = 1"

        query += " ORDER BY created_at DESC"
        rows = self._conn.execute(query, params).fetchall()
        return [self._row_to_job(row) for row in rows]

    def update_schedule_job(self, job_id: str, **kwargs: Any) -> Dict[str, Any]:
        """Update a schedule job."""
        self.get_schedule_job(job_id)  # Ensure exists
        now = datetime.utcnow().isoformat()

        allowed = {
            "project_id", "job_type", "generator_id", "configuration",
            "schedule", "cron_expression", "schedule_day", "schedule_time",
            "timezone", "enabled", "last_run_at", "last_run_status", "next_run_at",
        }
        updates = {k: v for k, v in kwargs.items() if k in allowed}
        if not updates:
            return self.get_schedule_job(job_id)

        if "configuration" in updates:
            updates["configuration"] = json.dumps(updates["configuration"])
        if "enabled" in updates:
            updates["enabled"] = 1 if updates["enabled"] else 0

        updates["updated_at"] = now
        set_clause = ", ".join(f"{k} = ?" for k in updates)
        values = list(updates.values()) + [job_id]

        self._conn.execute(
            f"UPDATE schedule_jobs SET {set_clause} WHERE id = ?", values
        )
        self._conn.commit()
        return self.get_schedule_job(job_id)

    def delete_schedule_job(self, job_id: str) -> None:
        """Delete a schedule job."""
        self.get_schedule_job(job_id)  # Ensure exists
        self._conn.execute("DELETE FROM schedule_jobs WHERE id = ?", (job_id,))
        self._conn.commit()

    def get_due_jobs(self) -> List[Dict[str, Any]]:
        """Get jobs that are due to run (next_run_at <= now and enabled)."""
        now = datetime.utcnow().isoformat()
        rows = self._conn.execute(
            "SELECT * FROM schedule_jobs WHERE enabled = 1 AND next_run_at IS NOT NULL AND next_run_at <= ?",
            (now,),
        ).fetchall()
        return [self._row_to_job(row) for row in rows]

    def _row_to_job(self, row: sqlite3.Row) -> Dict[str, Any]:
        """Convert a database row to a schedule job dict."""
        return {
            "id": row["id"],
            "user_id": row["user_id"],
            "project_id": row["project_id"],
            "job_type": row["job_type"],
            "generator_id": row["generator_id"],
            "configuration": json.loads(row["configuration"]) if row["configuration"] else {},
            "schedule": row["schedule"],
            "cron_expression": row["cron_expression"],
            "schedule_day": row["schedule_day"],
            "schedule_time": row["schedule_time"],
            "timezone": row["timezone"],
            "enabled": bool(row["enabled"]),
            "last_run_at": row["last_run_at"],
            "last_run_status": row["last_run_status"],
            "next_run_at": row["next_run_at"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    def _row_to_asset(self, row: sqlite3.Row) -> ContentAssetRecord:
        """Convert a database row to a ContentAssetRecord."""
        return ContentAssetRecord(
            id=row["id"],
            content_id=row["content_id"],
            project_id=row["project_id"],
            user_id=row["user_id"],
            client_asset_id=row["client_asset_id"],
            source=row["source"],
            kind=row["kind"],
            mime_type=row["mime_type"],
            file_name=row["file_name"],
            byte_size=row["byte_size"],
            width=row["width"],
            height=row["height"],
            duration_ms=row["duration_ms"],
            storage_uri=row["storage_uri"],
            status=row["status"],
            metadata=json.loads(row["metadata"]) if row["metadata"] else {},
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
            deleted_at=datetime.fromisoformat(row["deleted_at"]) if row["deleted_at"] else None,
        )

    def _row_to_project_asset(self, row: sqlite3.Row) -> ProjectAssetRecord:
        row_keys = set(row.keys())
        storage_locator = None
        if "storage_provider" in row_keys and row["storage_provider"]:
            storage_locator = StorageLocator(
                provider=row["storage_provider"],
                namespace=row["storage_namespace"],
                object_key=row["storage_object_key"],
                version=row["storage_version"],
                checksum_sha256=row["storage_checksum_sha256"],
            )
        return ProjectAssetRecord(
            id=row["id"],
            project_id=row["project_id"],
            user_id=row["user_id"],
            source_asset_id=row["source_asset_id"],
            content_asset_id=row["content_asset_id"],
            media_kind=row["media_kind"],
            source=row["source"],
            mime_type=row["mime_type"],
            file_name=row["file_name"],
            original_file_name=row["original_file_name"] if "original_file_name" in row_keys else row["file_name"],
            category_id=row["category_id"] if "category_id" in row_keys else None,
            subcategory_id=row["subcategory_id"] if "subcategory_id" in row_keys else None,
            storage_uri=row["storage_uri"],
            storage_locator=storage_locator,
            status=row["status"],
            metadata=json.loads(row["metadata"]) if row["metadata"] else {},
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
            tombstoned_at=datetime.fromisoformat(row["tombstoned_at"]) if row["tombstoned_at"] else None,
            cleanup_eligible_at=datetime.fromisoformat(row["cleanup_eligible_at"]) if row["cleanup_eligible_at"] else None,
        )

    def _row_to_project_asset_usage(self, row: sqlite3.Row) -> ProjectAssetUsageRecord:
        return ProjectAssetUsageRecord(
            id=row["id"],
            asset_id=row["asset_id"],
            project_id=row["project_id"],
            user_id=row["user_id"],
            target_type=row["target_type"],
            target_id=row["target_id"],
            placement=row["placement"],
            usage_action=row["usage_action"],
            is_primary=bool(row["is_primary"]),
            metadata=json.loads(row["metadata"]) if row["metadata"] else {},
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
            deleted_at=datetime.fromisoformat(row["deleted_at"]) if row["deleted_at"] else None,
        )

    def _row_to_project_asset_event(self, row: sqlite3.Row) -> ProjectAssetEventRecord:
        return ProjectAssetEventRecord(
            id=row["id"],
            asset_id=row["asset_id"],
            project_id=row["project_id"],
            user_id=row["user_id"],
            event_type=row["event_type"],
            target_type=row["target_type"],
            target_id=row["target_id"],
            placement=row["placement"],
            metadata=json.loads(row["metadata"]) if row["metadata"] else {},
            created_at=datetime.fromisoformat(row["created_at"]),
        )

    def _row_to_asset_understanding_job(self, row: sqlite3.Row) -> AssetUnderstandingJobRecord:
        return AssetUnderstandingJobRecord(
            id=row["id"],
            asset_id=row["asset_id"],
            project_id=row["project_id"],
            user_id=row["user_id"],
            media_type=row["media_type"],
            provider=row["provider"],
            credential_source=row["credential_source"],
            status=row["status"],
            idempotency_key=row["idempotency_key"],
            retry_of_job_id=row["retry_of_job_id"],
            error_code=row["error_code"],
            error_message=row["error_message"],
            attempts=row["attempts"],
            metadata=json.loads(row["metadata"] or "{}"),
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
        )

    @staticmethod
    def _row_to_asset_understanding_tag(row: sqlite3.Row) -> AssetSemanticTag:
        return AssetSemanticTag(
            key=row["key"],
            label=row["label"],
            confidence=float(row["confidence"]),
            source=row["source"],
            accepted_by_user=bool(row["accepted_by_user"]),
            rejected_by_user=bool(row["rejected_by_user"]),
        )

    @staticmethod
    def _row_to_asset_understanding_segment(row: sqlite3.Row) -> AssetSceneSegment:
        return AssetSceneSegment(
            start_seconds=float(row["start_seconds"]),
            end_seconds=float(row["end_seconds"]),
            label=row["label"],
            confidence=float(row["confidence"]),
            suggested_placement=row["suggested_placement"],
        )

    # ─── Sync Helpers ─────────────────────────────────

    def get_unsynced_records(self) -> List[ContentRecord]:
        """Get records where synced_at is NULL or older than updated_at."""
        rows = self._conn.execute(
            """
            SELECT * FROM content_records
            WHERE synced_at IS NULL OR synced_at < updated_at
            ORDER BY updated_at ASC
            """,
        ).fetchall()
        return [self._row_to_record(row) for row in rows]

    def mark_synced(self, content_id: str) -> None:
        """Mark a content record as synced."""
        now = datetime.utcnow().isoformat()
        self._conn.execute(
            "UPDATE content_records SET synced_at = ? WHERE id = ?",
            (now, content_id),
        )
        self._conn.commit()

    # ─── Private Helpers ──────────────────────────────

    def _row_to_record(self, row: sqlite3.Row) -> ContentRecord:
        """Convert a database row to a ContentRecord."""
        # Handle current_version column (may not exist in older DBs)
        try:
            current_version = row["current_version"]
        except (IndexError, KeyError):
            current_version = 0

        try:
            user_id = row["user_id"]
        except (IndexError, KeyError):
            user_id = None

        review_actor = self._review_actor_from_row(row)

        return ContentRecord(
            id=row["id"],
            title=row["title"],
            content_type=row["content_type"],
            source_robot=row["source_robot"],
            status=row["status"],
            project_id=row["project_id"],
            user_id=user_id,
            content_path=row["content_path"],
            content_preview=row["content_preview"],
            content_hash=row["content_hash"],
            priority=row["priority"],
            tags=json.loads(row["tags"]),
            metadata=json.loads(row["metadata"]),
            target_url=row["target_url"],
            reviewer_note=row["reviewer_note"],
            reviewed_by=review_actor.actor_id if review_actor else row["reviewed_by"],
            review_actor_type=review_actor.actor_type if review_actor else None,
            review_actor_id=review_actor.actor_id if review_actor else None,
            review_actor_label=review_actor.actor_label if review_actor else None,
            review_actor_metadata=review_actor.actor_metadata if review_actor else None,
            current_version=current_version,
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
            scheduled_for=datetime.fromisoformat(row["scheduled_for"]) if row["scheduled_for"] else None,
            published_at=datetime.fromisoformat(row["published_at"]) if row["published_at"] else None,
            synced_at=datetime.fromisoformat(row["synced_at"]) if row["synced_at"] else None,
        )

    def _review_actor_from_row(self, row: sqlite3.Row) -> Optional[AuditActor]:
        actor_id = self._safe_row_value(row, "review_actor_id")
        actor_type = self._safe_row_value(row, "review_actor_type")
        actor_label = self._safe_row_value(row, "review_actor_label")
        actor_metadata = self._safe_row_value(row, "review_actor_metadata")

        if actor_id or actor_type or actor_label or actor_metadata:
            return AuditActor(
                actor_type=actor_type or actor_from_string(row["reviewed_by"]).actor_type,
                actor_id=actor_id or row["reviewed_by"],
                actor_label=actor_label or actor_from_string(row["reviewed_by"]).actor_label,
                actor_metadata=self._parse_json(actor_metadata),
            )

        reviewed_by = self._safe_row_value(row, "reviewed_by")
        if reviewed_by:
            return actor_from_string(reviewed_by)
        return None

    def _row_to_status_change(self, row: sqlite3.Row) -> StatusChange:
        actor = self._actor_from_row(row, fallback=row["changed_by"])
        return StatusChange(
            id=row["id"],
            content_id=row["content_id"],
            from_status=row["from_status"],
            to_status=row["to_status"],
            changed_by=actor.actor_id,
            actor_type=actor.actor_type,
            actor_id=actor.actor_id,
            actor_label=actor.actor_label,
            actor_metadata=actor.actor_metadata,
            reason=row["reason"],
            timestamp=datetime.fromisoformat(row["timestamp"]),
        )

    def _actor_from_row(self, row: sqlite3.Row, fallback: Optional[str]) -> AuditActor:
        actor_id = self._safe_row_value(row, "actor_id")
        actor_type = self._safe_row_value(row, "actor_type")
        actor_label = self._safe_row_value(row, "actor_label")
        actor_metadata = self._safe_row_value(row, "actor_metadata")
        if actor_id or actor_type or actor_label or actor_metadata:
            return AuditActor(
                actor_type=actor_type or actor_from_string(fallback).actor_type,
                actor_id=actor_id or (fallback or "system"),
                actor_label=actor_label or actor_from_string(fallback).actor_label,
                actor_metadata=self._parse_json(actor_metadata),
            )
        return actor_from_string(fallback)

    def _row_actor_type(self, row: sqlite3.Row, fallback: Optional[str]) -> str:
        return self._actor_from_row(row, fallback=fallback).actor_type

    def _row_actor_id(self, row: sqlite3.Row, fallback: Optional[str]) -> str:
        return self._actor_from_row(row, fallback=fallback).actor_id

    def _row_actor_label(self, row: sqlite3.Row, fallback: Optional[str]) -> str:
        return self._actor_from_row(row, fallback=fallback).actor_label

    def _row_actor_metadata(
        self,
        row: sqlite3.Row,
        fallback: Optional[str],
    ) -> Optional[Dict[str, Any]]:
        return self._actor_from_row(row, fallback=fallback).actor_metadata

    @staticmethod
    def _parse_json(value: Optional[str]) -> Optional[Dict[str, Any]]:
        if not value:
            return None
        if isinstance(value, dict):
            return value
        return json.loads(value)

    @staticmethod
    def _safe_row_value(row: sqlite3.Row, key: str) -> Any:
        try:
            return row[key]
        except (IndexError, KeyError):
            return None


    # ─── Idea Pool CRUD ──────────────────────────────────

    def create_idea(
        self,
        source: str,
        title: str,
        raw_data: Optional[Dict[str, Any]] = None,
        seo_signals: Optional[Dict[str, Any]] = None,
        trending_signals: Optional[Dict[str, Any]] = None,
        tags: Optional[List[str]] = None,
        priority_score: Optional[float] = None,
        project_id: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Create a new idea in the pool."""
        now = datetime.utcnow().isoformat()
        idea_id = str(uuid.uuid4())

        self._conn.execute(
            """INSERT INTO idea_pool
               (id, source, title, raw_data, seo_signals, trending_signals,
                tags, priority_score, status, project_id, user_id, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'raw', ?, ?, ?, ?)""",
            (
                idea_id,
                source,
                title,
                json.dumps(raw_data or {}),
                json.dumps(seo_signals) if seo_signals else None,
                json.dumps(trending_signals) if trending_signals else None,
                json.dumps(tags or []),
                priority_score,
                project_id,
                user_id,
                now,
                now,
            ),
        )
        self._conn.commit()
        return self.get_idea(idea_id)

    def get_idea(self, idea_id: str) -> Dict[str, Any]:
        """Get a single idea by ID."""
        row = self._conn.execute(
            "SELECT * FROM idea_pool WHERE id = ?", (idea_id,)
        ).fetchone()
        if not row:
            raise ContentNotFoundError(f"Idea {idea_id} not found")
        return self._idea_from_row(row)

    def list_ideas(
        self,
        source: Optional[str] = None,
        status: Optional[str] = None,
        min_score: Optional[float] = None,
        project_id: Optional[str] = None,
        user_id: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[List[Dict[str, Any]], int]:
        """List ideas with optional filters. Returns (items, total)."""
        conditions = []
        params: list = []

        if source:
            conditions.append("source = ?")
            params.append(source)
        if status:
            conditions.append("status = ?")
            params.append(status)
        if min_score is not None:
            conditions.append("priority_score >= ?")
            params.append(min_score)
        if project_id:
            conditions.append("project_id = ?")
            params.append(project_id)
        if user_id:
            conditions.append("user_id = ?")
            params.append(user_id)

        where = f"WHERE {' AND '.join(conditions)}" if conditions else ""

        total = self._conn.execute(
            f"SELECT COUNT(*) FROM idea_pool {where}", params
        ).fetchone()[0]

        rows = self._conn.execute(
            f"""SELECT * FROM idea_pool {where}
                ORDER BY COALESCE(priority_score, 0) DESC, created_at DESC
                LIMIT ? OFFSET ?""",
            params + [limit, offset],
        ).fetchall()

        return [self._idea_from_row(r) for r in rows], total

    def update_idea(self, idea_id: str, **kwargs) -> Dict[str, Any]:
        """Update an idea's fields."""
        allowed = {
            "title", "seo_signals", "trending_signals", "tags",
            "priority_score", "status", "project_id",
        }
        updates = []
        params = []
        for key, value in kwargs.items():
            if key not in allowed:
                continue
            if key in ("seo_signals", "trending_signals"):
                updates.append(f"{key} = ?")
                params.append(json.dumps(value) if value is not None else None)
            elif key == "tags":
                updates.append(f"{key} = ?")
                params.append(json.dumps(value or []))
            else:
                updates.append(f"{key} = ?")
                params.append(value)

        if not updates:
            return self.get_idea(idea_id)

        updates.append("updated_at = ?")
        params.append(datetime.utcnow().isoformat())
        params.append(idea_id)

        self._conn.execute(
            f"UPDATE idea_pool SET {', '.join(updates)} WHERE id = ?",
            params,
        )
        self._conn.commit()
        return self.get_idea(idea_id)

    def delete_idea(self, idea_id: str) -> None:
        """Delete an idea."""
        self._conn.execute("DELETE FROM idea_pool WHERE id = ?", (idea_id,))
        self._conn.commit()

    def bulk_create_ideas(
        self,
        source: str,
        items: List[Dict[str, Any]],
        project_id: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> int:
        """Bulk insert ideas. Returns count created."""
        now = datetime.utcnow().isoformat()
        count = 0
        for item in items:
            title = item.get("title", "").strip()
            if not title:
                continue
            self._conn.execute(
                """INSERT INTO idea_pool
                   (id, source, title, raw_data, seo_signals, trending_signals,
                    tags, priority_score, status, project_id, user_id, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'raw', ?, ?, ?, ?)""",
                (
                    str(uuid.uuid4()),
                    source,
                    title,
                    json.dumps(item.get("raw_data", {})),
                    json.dumps(item["seo_signals"]) if item.get("seo_signals") else None,
                    json.dumps(item["trending_signals"]) if item.get("trending_signals") else None,
                    json.dumps(item.get("tags", [])),
                    item.get("priority_score"),
                    project_id,
                    user_id,
                    now,
                    now,
                ),
            )
            count += 1
        self._conn.commit()
        return count

    def _idea_from_row(self, row) -> Dict[str, Any]:
        """Convert a database row to an idea dict."""
        return {
            "id": row["id"],
            "source": row["source"],
            "title": row["title"],
            "raw_data": json.loads(row["raw_data"]),
            "seo_signals": json.loads(row["seo_signals"]) if row["seo_signals"] else None,
            "trending_signals": json.loads(row["trending_signals"]) if row["trending_signals"] else None,
            "tags": json.loads(row["tags"]),
            "priority_score": row["priority_score"],
            "status": row["status"],
            "project_id": row["project_id"],
            "user_id": row["user_id"] if "user_id" in row.keys() else None,
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    # ─── Content Deduplication ─────────────────────────

    def find_similar_content(
        self,
        title: str,
        user_id: Optional[str] = None,
        project_id: Optional[str] = None,
        statuses: Optional[List[str]] = None,
    ) -> List[ContentRecord]:
        """Find content records with similar titles using LIKE matching.

        Extracts significant words (>3 chars) from the title and checks
        if all of them appear in existing content titles. Scoped by
        user_id and project_id for multi-tenant isolation.
        """
        words = [w for w in title.lower().split() if len(w) > 3][:3]
        if not words:
            return []

        query = "SELECT * FROM content_records WHERE 1=1"
        params: list = []

        if user_id:
            query += " AND user_id = ?"
            params.append(user_id)
        if project_id:
            query += " AND project_id = ?"
            params.append(project_id)
        if statuses:
            placeholders = ", ".join("?" for _ in statuses)
            query += f" AND status IN ({placeholders})"
            params.extend(statuses)

        for word in words:
            query += " AND LOWER(title) LIKE ?"
            params.append(f"%{word}%")

        query += " LIMIT 5"
        rows = self._conn.execute(query, params).fetchall()
        return [self._row_to_record(row) for row in rows]


# ─── Singleton ────────────────────────────────────────

_service_instance: Optional[StatusService] = None


def get_status_service(db_path: Optional[str] = None) -> StatusService:
    """Get or create the singleton StatusService instance."""
    global _service_instance
    if _service_instance is None:
        _service_instance = StatusService(db_path)
    return _service_instance
