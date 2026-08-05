from types import SimpleNamespace

from api.services.branded_video_assembly import assemble_branded_timeline_draft


def test_assemble_branded_timeline_draft_uses_assets_and_brand_rules():
    content = SimpleNamespace(
        title="How to launch faster",
        content_preview="Three concrete ways to reduce production time without losing brand consistency.",
    )
    brand_profile = {
        "id": "brand-1",
        "font_heading": "Space Grotesk",
        "font_body": "Manrope",
        "primary_colors": ["#F8F4EC", "#1A1A1A"],
        "secondary_colors": ["#FF6A3D"],
        "motion_intensity": "high",
        "transition_family": "swipe",
        "cta_defaults": {"primaryText": "Start now"},
        "caption_style_defaults": {"textColor": "#FFFFFF"},
        "intro_module_enabled": True,
        "outro_module_enabled": True,
        "tone_keywords": ["clear", "bold"],
    }
    blueprint = {
        "id": "blueprint-1",
        "default_archetype": "ugc_ad",
        "scene_rules_json": {"sceneDurationFrames": 72},
        "layout_rules_json": {"assetFit": "contain", "titleAlign": "right", "titleFontSize": 180},
        "motion_rules_json": {"transitionFamily": "fade", "titleIntensity": "low"},
        "caption_rules_json": {"titleColor": "#00FF00"},
        "cta_rules_json": {"uppercase": True, "backgroundColor": "#000000"},
        "audio_rules_json": {"enabled": True, "musicAssetId": "music-1", "volume": 2},
        "export_rules_json": {"codec": "h265"},
    }
    assets = [
        SimpleNamespace(
            id="asset-1",
            media_kind="image",
            storage_uri="bunny://storage/library/a.png",
            status="active",
            mime_type="image/png",
        ),
        SimpleNamespace(
            id="asset-2",
            media_kind="video",
            storage_uri="https://contentglows-test.b-cdn.net/assets/b.mp4",
            status="active",
            mime_type="video/mp4",
        ),
    ]

    draft = assemble_branded_timeline_draft(
        content_record=content,
        brand_profile=brand_profile,
        blueprint=blueprint,
        project_assets=assets,
        format_preset="vertical_9_16",
    )

    assert draft["format_preset"] == "vertical_9_16"
    assert any(clip["clip_type"] in {"image", "video"} for clip in draft["clips"])
    assert any(clip["role"] == "hook_title" for clip in draft["clips"])
    assert any(clip["role"] == "cta" and clip["text"] == "Start now" for clip in draft["clips"])
    assert draft["duration_frames"] >= 100
    scene = next(clip for clip in draft["clips"] if clip["role"] == "scene")
    title = next(clip for clip in draft["clips"] if clip["role"] == "hook_title")
    cta = next(clip for clip in draft["clips"] if clip["role"] == "cta")
    assert scene["style"]["fit"] == "contain"
    assert scene["style"]["transition_family"] == "fade"
    assert title["style"]["align"] == "right"
    assert title["style"]["font_size"] == 140
    assert title["style"]["color"] == "#00FF00"
    assert cta["style"]["background_color"] == "#000000"
    assert draft["audio"] == {
        "enabled": True,
        "music_asset_id": "music-1",
        "volume": 1,
        "ducking": "none",
    }
    assert draft["render_policy"]["codec"] == "h265"


def test_assemble_branded_timeline_draft_falls_back_without_assets():
    content = SimpleNamespace(title="Fallback", content_preview=None)
    draft = assemble_branded_timeline_draft(
        content_record=content,
        brand_profile={
            "id": "brand-1",
            "primary_colors": ["#111111"],
            "secondary_colors": [],
            "motion_intensity": "low",
            "intro_module_enabled": True,
            "outro_module_enabled": False,
        },
        blueprint={"id": "blueprint-1", "default_archetype": "recap"},
        project_assets=[],
        format_preset="vertical_9_16",
    )

    assert any(clip["clip_type"] == "background" for clip in draft["clips"])
    assert any(clip["clip_type"] == "text" for clip in draft["clips"])
