"""Convert canonical video timelines into Remotion input props."""

from __future__ import annotations

import json
from typing import Any

from api.models.video_timeline import FORMAT_DIMENSIONS, MAX_DURATION_FRAMES, ContentGlowsTimelineProps

MAX_RENDER_PROPS_BYTES = 64 * 1024


class TimelinePropsError(ValueError):
    """Raised when timeline props would be unsafe or too large."""


def build_remotion_timeline_props(
    *,
    timeline_id: str,
    version_id: str,
    timeline: dict[str, Any],
    assets: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Build deterministic Remotion props from a validated timeline document."""

    format_preset = timeline["format_preset"]
    width, height = FORMAT_DIMENSIONS[format_preset]
    duration_frames = int(timeline["duration_frames"])
    if duration_frames <= 0 or duration_frames > MAX_DURATION_FRAMES:
        raise TimelinePropsError("Timeline duration is outside render limits")

    _reject_client_media_urls(timeline)

    payload = ContentGlowsTimelineProps(
        timeline_id=timeline_id,
        version_id=version_id,
        format={
            "preset": format_preset,
            "width": width,
            "height": height,
            "fps": 30,
            "duration_in_frames": duration_frames,
        },
        tracks=[
            {
                "id": track["id"],
                "type": track["type"],
                "order": track["order"],
                "muted": track.get("muted", False),
            }
            for track in sorted(timeline["tracks"], key=lambda item: (item["order"], item["id"]))
        ],
        clips=[
            {
                "id": clip["id"],
                "track_id": clip["track_id"],
                "type": clip["clip_type"],
                "start_frame": clip["start_frame"],
                "duration_in_frames": clip["duration_frames"],
                "asset_ref": clip.get("asset_id"),
                "trim_start_frame": clip.get("trim_start_frame", 0),
                "text": clip.get("text"),
                "role": clip.get("role"),
                "volume": clip.get("volume"),
                "style": clip.get("style", {}),
            }
            for clip in sorted(timeline["clips"], key=lambda item: (item["start_frame"], item["id"]))
        ],
        assets=assets or {},
    ).model_dump(mode="json", exclude_none=True)

    compact = json.dumps(payload, separators=(",", ":"), sort_keys=True)
    if len(compact.encode("utf-8")) > MAX_RENDER_PROPS_BYTES:
        raise TimelinePropsError("Renderer props exceed 64KB limit")
    return json.loads(compact)


def _reject_client_media_urls(value: Any) -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            lowered = str(key).lower()
            if lowered in {"url", "uri", "path", "render_url", "playback_url"} and isinstance(item, str):
                if item.startswith(("http://", "https://", "file://", "/", "bunny://")):
                    raise TimelinePropsError("Timeline cannot contain direct media URLs or paths")
            _reject_client_media_urls(item)
    elif isinstance(value, list):
        for item in value:
            _reject_client_media_urls(item)
