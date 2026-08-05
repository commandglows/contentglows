from __future__ import annotations

import pytest
from pydantic import ValidationError

from api.models.video_timeline import VideoTimelineDocument
from api.services.remotion_timeline_props import TimelinePropsError, build_remotion_timeline_props


def _text_timeline(**overrides):
    payload = {
        "schema_version": "1.0",
        "format_preset": "vertical_9_16",
        "fps": 30,
        "tracks": [
            {"id": "overlay", "type": "overlay", "order": 0, "exclusive": False},
        ],
        "clips": [
            {
                "id": "title",
                "track_id": "overlay",
                "clip_type": "text",
                "start_frame": 0,
                "duration_frames": 90,
                "text": "A visible title",
            }
        ],
    }
    payload.update(overrides)
    return payload


def test_text_only_timeline_is_valid_and_derives_duration():
    timeline = VideoTimelineDocument(**_text_timeline())

    assert timeline.duration_frames == 90


def test_timeline_rejects_audio_only_documents():
    with pytest.raises(ValidationError, match="visible text, image, video, or background"):
        VideoTimelineDocument(
            schema_version="1.0",
            format_preset="vertical_9_16",
            fps=30,
            tracks=[{"id": "audio", "type": "audio", "order": 0, "exclusive": False}],
            clips=[
                {
                    "id": "music",
                    "track_id": "audio",
                    "clip_type": "music",
                    "start_frame": 0,
                    "duration_frames": 120,
                    "asset_id": "asset-music",
                }
            ],
        )


def test_timeline_rejects_overlap_on_exclusive_tracks():
    payload = _text_timeline(
        tracks=[{"id": "main", "type": "visual", "order": 0, "exclusive": True}],
        clips=[
            {
                "id": "image-1",
                "track_id": "main",
                "clip_type": "image",
                "start_frame": 0,
                "duration_frames": 90,
                "asset_id": "asset-1",
            },
            {
                "id": "image-2",
                "track_id": "main",
                "clip_type": "image",
                "start_frame": 60,
                "duration_frames": 90,
                "asset_id": "asset-2",
            },
        ],
    )

    with pytest.raises(ValidationError, match="overlap"):
        VideoTimelineDocument(**payload)


def test_timeline_rejects_media_clip_without_required_asset():
    payload = _text_timeline(
        tracks=[{"id": "main", "type": "visual", "order": 0, "exclusive": False}],
        clips=[
            {
                "id": "image-1",
                "track_id": "main",
                "clip_type": "image",
                "start_frame": 0,
                "duration_frames": 90,
            }
        ],
    )

    with pytest.raises(ValidationError, match="image clips require asset_id"):
        VideoTimelineDocument(**payload)


def test_timeline_rejects_unknown_fields_and_invalid_fps():
    with pytest.raises(ValidationError):
        VideoTimelineDocument(**_text_timeline(untrusted_field=True))
    with pytest.raises(ValidationError):
        VideoTimelineDocument(**_text_timeline(fps=24))


def test_remotion_props_are_deterministic_and_reject_client_urls():
    timeline = VideoTimelineDocument(**_text_timeline()).model_dump(mode="json")

    props = build_remotion_timeline_props(
        timeline_id="timeline-1",
        version_id="version-1",
        timeline=timeline,
    )

    assert props["composition_id"] == "ContentGlowsTimelineVideo"
    assert props["format"]["width"] == 1080
    assert props["format"]["duration_in_frames"] == 90

    timeline["clips"][0]["style"] = {"url": "https://provider.example.com/tmp.png"}
    with pytest.raises(TimelinePropsError, match="direct media URLs"):
        build_remotion_timeline_props(
            timeline_id="timeline-1",
            version_id="version-1",
            timeline=timeline,
        )
