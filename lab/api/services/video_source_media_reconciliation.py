"""Bounded recovery for expired, orphaned and stalled media uploads."""

from __future__ import annotations

import asyncio
import logging
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Callable

from api.services.object_storage import ObjectStorageError, StorageLocator
from api.services.video_source_media_service import VideoSourceMediaService, get_video_source_media_service


logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class MediaReconciliationSummary:
    inspected: int = 0
    expired: int = 0
    cleaned: int = 0
    contained: int = 0
    deferred: int = 0
    exhausted: int = 0


class VideoSourceMediaReconciliationService:
    def __init__(
        self,
        *,
        media_service: VideoSourceMediaService,
        clock: Callable[[], datetime] | None = None,
        max_attempts: int = 5,
        lease_seconds: int = 120,
        stale_processing_seconds: int = 1800,
    ) -> None:
        self.media_service = media_service
        self.store = media_service.store
        self.clock = clock or (lambda: datetime.now(UTC))
        self.max_attempts = max_attempts
        self.lease_seconds = lease_seconds
        self.stale_processing_seconds = stale_processing_seconds

    async def run_batch(self, *, limit: int = 25) -> MediaReconciliationSummary:
        now = self.clock()
        candidates = await self.store.list_upload_reconciliation_candidates(
            now=now,
            stale_before=now - timedelta(seconds=self.stale_processing_seconds),
            limit=limit,
        )
        totals = {"inspected": 0, "expired": 0, "cleaned": 0, "contained": 0,
                  "deferred": 0, "exhausted": 0}
        for record in candidates:
            token = str(uuid.uuid4())
            claimed = await self.store.claim_upload_reconciliation(
                session_id=record["id"], expected_status=record["status"], lease_token=token,
                lease_expires_at=now + timedelta(seconds=self.lease_seconds), now=now,
            )
            if not claimed:
                continue
            totals["inspected"] += 1
            record["reconcile_attempts"] += 1
            result = await self._reconcile(record=record, lease_token=token, now=now)
            totals[result] += 1
        summary = MediaReconciliationSummary(**totals)
        _emit_event("batch_completed", result="ok", count=summary.inspected)
        return summary

    async def _reconcile(self, *, record: dict, lease_token: str, now: datetime) -> str:
        if record["status"] == "created":
            return await self._expire(record=record, lease_token=lease_token)
        if record["status"] == "processing":
            return await self._contain_stalled(record=record, lease_token=lease_token)
        return await self._cleanup(record=record, lease_token=lease_token, now=now)

    async def _expire(self, *, record: dict, lease_token: str) -> str:
        session = self.media_service._restore_public_session(record)
        try:
            restorer = getattr(
                self.media_service.storage,
                "restore_session_for_cleanup",
                self.media_service.storage.restore_session,
            )
            await asyncio.to_thread(restorer, session, record["provider_state"])
            await asyncio.to_thread(self.media_service.storage.abort_upload, session)
        except ObjectStorageError as exc:
            if exc.code not in {"upload_aborted", "upload_session_expired"}:
                return await self._defer(record, lease_token, exc.code, self.clock())
        await self.store.finish_upload_reconciliation(
            session_id=record["id"], lease_token=lease_token,
            status="expired", error_code="upload_session_expired",
        )
        await self.store.update_source(
            folder_id=record["folder_id"], source_id=record["source_id"],
            user_id=record["user_id"], status="failed",
            error_code="upload_session_expired", retryable=True,
        )
        _emit_event("session_expired", result="repaired", attempts=record["reconcile_attempts"])
        return "expired"

    async def _contain_stalled(self, *, record: dict, lease_token: str) -> str:
        await self.store.finish_upload_reconciliation(
            session_id=record["id"], lease_token=lease_token,
            status="reconciliation_required", error_code="stalled_processing_requires_review",
        )
        await self.store.update_source(
            folder_id=record["folder_id"], source_id=record["source_id"],
            user_id=record["user_id"], status="failed",
            error_code="stalled_processing_requires_review", retryable=True,
        )
        _emit_event("processing_stalled", result="contained", attempts=record["reconcile_attempts"])
        return "contained"

    async def _cleanup(self, *, record: dict, lease_token: str, now: datetime) -> str:
        error_code: str | None = None
        for value in record["cleanup_locators"]:
            try:
                locator = StorageLocator(**value)
                await asyncio.to_thread(self.media_service.storage.delete_version, locator)
            except Exception as exc:
                error_code = getattr(exc, "code", "object_cleanup_failed")
                break
        if error_code is None and record["cleanup_asset_ids"]:
            try:
                await asyncio.to_thread(
                    self.media_service.asset_writer.rollback,
                    user_id=record["user_id"], project_id=record["project_id"],
                    folder_id=record["folder_id"], source_id=record["source_id"],
                    asset_ids=record["cleanup_asset_ids"],
                )
            except Exception:
                error_code = "asset_cleanup_failed"
        if error_code is not None:
            return await self._defer(record, lease_token, error_code, now)
        await self.store.finish_upload_reconciliation(
            session_id=record["id"], lease_token=lease_token,
            status="failed", error_code="upload_cleanup_completed",
        )
        await self.store.update_source(
            folder_id=record["folder_id"], source_id=record["source_id"],
            user_id=record["user_id"], status="failed",
            error_code="upload_cleanup_completed", retryable=True,
        )
        _emit_event("orphan_cleanup", result="repaired", attempts=record["reconcile_attempts"])
        return "cleaned"

    async def _defer(
        self, record: dict, lease_token: str, error_code: str, now: datetime
    ) -> str:
        terminal = record["reconcile_attempts"] >= self.max_attempts
        delay = min(3600, 30 * (2 ** max(0, record["reconcile_attempts"] - 1)))
        await self.store.defer_upload_reconciliation(
            session_id=record["id"], lease_token=lease_token,
            reconcile_after=now + timedelta(seconds=delay), error_code=error_code,
            terminal=terminal,
        )
        if terminal:
            await self.store.update_source(
                folder_id=record["folder_id"], source_id=record["source_id"],
                user_id=record["user_id"], status="orphan_cleanup_needed",
                error_code="orphan_cleanup_exhausted", retryable=False,
            )
        _emit_event(
            "reconciliation_failed", result="exhausted" if terminal else "deferred",
            code=error_code, attempts=record["reconcile_attempts"],
        )
        return "exhausted" if terminal else "deferred"


def _emit_event(
    event: str, *, result: str, code: str | None = None,
    attempts: int | None = None, count: int | None = None,
) -> None:
    fields = {"event": event, "result": result}
    if code is not None:
        fields["code"] = code
    if attempts is not None:
        fields["attempts"] = attempts
    if count is not None:
        fields["count"] = count
    logger.info("media_upload_reconciliation", extra={"media_reconciliation": fields})


def get_video_source_media_reconciliation_service() -> VideoSourceMediaReconciliationService:
    return VideoSourceMediaReconciliationService(media_service=get_video_source_media_service())
