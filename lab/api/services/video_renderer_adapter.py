"""Renderer adapter boundary for ContentGlows video timelines."""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Protocol

from api.services.remotion_render_client import (
    RemotionRenderResponseError,
    RemotionRenderUnavailableError,
    get_remotion_render_client,
)
from api.services.render_artifacts import normalize_worker_artifact


class VideoRendererAdapterError(RuntimeError):
    """Base renderer adapter error."""


class VideoRendererUnavailableError(VideoRendererAdapterError):
    """Raised when no timeline renderer is available."""


class VideoRendererCapacityError(VideoRendererAdapterError):
    """Raised when render capacity is exhausted."""


@dataclass(frozen=True)
class VideoRenderDispatchResult:
    job_id: str
    status: str = "queued"
    progress: int = 0
    message: str | None = "Queued"
    worker_job_id: str | None = None
    artifact: dict[str, Any] | None = None


class VideoRendererAdapter(Protocol):
    async def request_render(
        self,
        *,
        job_id: str,
        render_mode: str,
        timeline_props: dict[str, Any],
        client_request_id: str | None = None,
    ) -> VideoRenderDispatchResult:
        """Queue a preview or final render for immutable timeline props."""

    async def get_render_status(self, *, job_id: str) -> VideoRenderDispatchResult:
        """Refresh status for a non-terminal render job."""


class UnavailableVideoRendererAdapter:
    async def request_render(
        self,
        *,
        job_id: str,
        render_mode: str,
        timeline_props: dict[str, Any],
        client_request_id: str | None = None,
    ) -> VideoRenderDispatchResult:
        raise VideoRendererUnavailableError(
            "ContentGlows timeline Remotion composition is not enabled yet"
        )

    async def get_render_status(self, *, job_id: str) -> VideoRenderDispatchResult:
        raise VideoRendererUnavailableError(
            "ContentGlows timeline Remotion composition is not enabled yet"
        )


def _normalize_status(value: str | None) -> str:
    mapping = {
        "queued": "queued",
        "in_progress": "in_progress",
        "in-progress": "in_progress",
        "running": "in_progress",
        "completed": "completed",
        "failed": "failed",
        "cancelled": "cancelled",
        "canceled": "cancelled",
    }
    return mapping.get((value or "").strip().lower(), "failed")


def _artifact_from_worker(
    artifact: dict[str, Any] | None,
    *,
    render_mode: str,
    expected_artifact: dict[str, Any] | None = None,
) -> dict[str, Any] | None:
    return normalize_worker_artifact(
        artifact,
        render_mode=render_mode,
        expected_artifact=expected_artifact,
    )


class RemotionTimelineRendererAdapter:
    async def request_render(
        self,
        *,
        job_id: str,
        render_mode: str,
        timeline_props: dict[str, Any],
        client_request_id: str | None = None,
    ) -> VideoRenderDispatchResult:
        payload = await self._create_worker_payload(
            job_id=job_id,
            render_mode=render_mode,
            timeline_props=timeline_props,
        )
        try:
            worker_payload = await get_remotion_render_client().create_render(payload)
        except RemotionRenderUnavailableError as exc:
            raise VideoRendererUnavailableError("Timeline renderer unavailable") from exc
        except RemotionRenderResponseError as exc:
            if exc.status_code == 429:
                raise VideoRendererCapacityError("Timeline renderer capacity reached") from exc
            raise VideoRendererUnavailableError("Timeline renderer rejected request") from exc
        return self._result_from_worker_payload(
            job_id=job_id,
            render_mode=render_mode,
            worker_payload=worker_payload,
        )

    async def get_render_status(self, *, job_id: str) -> VideoRenderDispatchResult:
        try:
            worker_payload = await get_remotion_render_client().get_render(job_id)
        except RemotionRenderUnavailableError as exc:
            raise VideoRendererUnavailableError("Timeline renderer unavailable") from exc
        except RemotionRenderResponseError as exc:
            raise VideoRendererUnavailableError("Timeline renderer rejected request") from exc
        render_mode = str(worker_payload.get("renderMode") or "preview")
        return self._result_from_worker_payload(
            job_id=job_id,
            render_mode=render_mode,
            worker_payload=worker_payload,
        )

    async def _create_worker_payload(
        self,
        *,
        job_id: str,
        render_mode: str,
        timeline_props: dict[str, Any],
    ) -> dict[str, Any]:
        format_payload = timeline_props.get("format")
        if not isinstance(format_payload, dict):
            raise VideoRendererUnavailableError("Timeline renderer props are missing format")
        fps = int(format_payload.get("fps") or 30)
        duration_frames = int(format_payload.get("duration_in_frames") or 0)
        if fps <= 0 or duration_frames <= 0:
            raise VideoRendererUnavailableError("Timeline renderer props have invalid duration")
        duration_seconds = max(1, math.ceil(duration_frames / fps))
        return {
            "jobId": job_id,
            "renderMode": render_mode,
            "durationSeconds": duration_seconds,
            "templateId": "contentglows-timeline-v1",
            "compositionId": "ContentGlowsTimelineVideo",
            "inputProps": timeline_props,
        }

    @staticmethod
    def _result_from_worker_payload(
        *,
        job_id: str,
        render_mode: str,
        worker_payload: dict[str, Any],
        expected_artifact: dict[str, Any] | None = None,
    ) -> VideoRenderDispatchResult:
        status = _normalize_status(str(worker_payload.get("status", "queued")))
        artifact = _artifact_from_worker(
            worker_payload.get("artifact") if isinstance(worker_payload.get("artifact"), dict) else None,
            render_mode=render_mode,
            expected_artifact=expected_artifact,
        )
        return VideoRenderDispatchResult(
            job_id=str(worker_payload.get("workerJobId") or job_id),
            status=status,
            progress=int(worker_payload.get("progress") or 0),
            message=worker_payload.get("message") or ("Completed" if status == "completed" else "Queued"),
            worker_job_id=str(worker_payload.get("workerJobId") or job_id),
            artifact=artifact,
        )


_renderer_adapter: VideoRendererAdapter | None = None


def get_video_renderer_adapter() -> VideoRendererAdapter:
    global _renderer_adapter
    if _renderer_adapter is None:
        _renderer_adapter = RemotionTimelineRendererAdapter()
    return _renderer_adapter


def set_video_renderer_adapter_for_tests(adapter: VideoRendererAdapter | None) -> None:
    global _renderer_adapter
    _renderer_adapter = adapter
