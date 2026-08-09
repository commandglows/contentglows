import sqlite3

import pytest

from api.services.social_placement_preflight import (
    PFL_ASSET_STATUS_BLOCKED,
    PFL_MISSING_REQUIRED,
    build_placement_plan,
    run_publish_preflight,
)


@pytest.fixture
def status_service(monkeypatch):
    from status import service as service_module
    from status import StatusService

    def _connection(_db_path=None):
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        return conn

    monkeypatch.setattr(service_module, "get_connection", _connection)
    monkeypatch.setenv("BUNNY_CDN_HOSTNAME", "assets.example.b-cdn.net")
    return StatusService()


def _content(status_service, *, content_type="social_post", project_id="project-1", user_id="user-1"):
    return status_service.create_content(
        title="Post",
        content_type=content_type,
        source_robot="social" if content_type == "social_post" else "short",
        status="approved",
        project_id=project_id,
        user_id=user_id,
    )


def _asset(status_service, *, kind="image", mime_type="image/png"):
    return status_service.create_project_asset(
        project_id="project-1",
        user_id="user-1",
        media_kind=kind,
        source="manual_upload",
        mime_type=mime_type,
        storage_uri="bunny://zone/publishable-media",
    )


def test_article_plan_keeps_blog_and_social_slots_separate(status_service):
    content = status_service.create_content(
        title="Article",
        content_type="article",
        source_robot="article",
        status="approved",
        project_id="project-1",
        user_id="user-1",
    )

    plan = build_placement_plan(
        content=content,
        platform_ids=["wordpress", "twitter"],
        locale="fr",
    )

    assert plan.format_id == "FMT_ARTICLE"
    slots = {platform.platform_id: {slot.placement_id for slot in platform.slots} for platform in plan.platforms}
    assert "PLC_BLOG_HERO" in slots["PLAT_WORDPRESS"]
    assert {"PLC_SOCIAL_POST_IMAGE", "PLC_LINK_THUMBNAIL"} <= slots["PLAT_X"]


def test_x_text_only_is_allowed_with_recommendations(status_service):
    content = _content(status_service)

    result = run_publish_preflight(
        status_service=status_service,
        content=content,
        user_id="user-1",
        platform_ids=["twitter"],
    )

    assert result.response.can_publish is True
    assert result.resolved_media_items == ()
    assert all(issue.severity == "warning" for issue in result.response.issues)


def test_stale_registry_blocks_until_client_refreshes(status_service):
    content = _content(status_service)
    result = run_publish_preflight(
        status_service=status_service,
        content=content,
        user_id="user-1",
        platform_ids=["twitter"],
        requested_registry_version="stale-version",
    )

    assert result.response.can_publish is False
    assert any(issue.code == "PFL_REGISTRY_STALE" for issue in result.response.issues)


def test_instagram_missing_required_image_blocks(status_service):
    content = _content(status_service)

    result = run_publish_preflight(
        status_service=status_service,
        content=content,
        user_id="user-1",
        platform_ids=["instagram"],
    )

    assert result.response.can_publish is False
    assert any(
        issue.code == PFL_MISSING_REQUIRED and issue.placement_id == "PLC_SOCIAL_POST_IMAGE"
        for issue in result.response.issues
    )


def test_primary_alias_is_canonicalized_and_resolved_to_token_free_bunny_url(status_service):
    content = _content(status_service)
    asset = _asset(status_service)
    usage = status_service.set_project_asset_primary(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="publish_media",
        placement="social_image",
    )

    result = run_publish_preflight(
        status_service=status_service,
        content=content,
        user_id="user-1",
        platform_ids=["instagram"],
    )

    assert usage.placement == "PLC_SOCIAL_POST_IMAGE"
    assert result.response.can_publish is True
    assert result.resolved_media_items[0].url == "https://assets.example.b-cdn.net/publishable-media"
    assert result.response.platforms[0].media_items[0].asset_id == asset.id
    assert "url" not in result.response.platforms[0].media_items[0].model_dump()


def test_tombstoned_selected_asset_blocks_without_changing_usage(status_service):
    content = _content(status_service)
    asset = _asset(status_service)
    status_service.set_project_asset_primary(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="publish_media",
        placement="PLC_SOCIAL_POST_IMAGE",
    )
    status_service.tombstone_project_asset(
        project_id="project-1", user_id="user-1", asset_id=asset.id
    )

    result = run_publish_preflight(
        status_service=status_service,
        content=content,
        user_id="user-1",
        platform_ids=["instagram"],
    )

    assert result.response.can_publish is False
    assert any(issue.code == PFL_ASSET_STATUS_BLOCKED for issue in result.response.issues)
    assert status_service.get_project_asset_usage(
        project_id="project-1", user_id="user-1", asset_id=asset.id
    )[0].is_primary is True


def test_short_image_cannot_satisfy_required_video_slot(status_service):
    content = _content(status_service, content_type="short")
    image = _asset(status_service)
    status_service.set_project_asset_primary(
        project_id="project-1",
        user_id="user-1",
        asset_id=image.id,
        target_type="content",
        target_id=content.id,
        usage_action="publish_media",
        placement="PLC_VERTICAL_SHORT_VIDEO",
    )

    result = run_publish_preflight(
        status_service=status_service,
        content=content,
        user_id="user-1",
        platform_ids=["tiktok"],
    )

    assert result.response.can_publish is False
    slot = next(slot for slot in result.response.platforms[0].slots if slot.placement_id == "PLC_VERTICAL_SHORT_VIDEO")
    assert slot.state == "incompatible"


def test_primary_lookup_never_crosses_user_or_project_boundary(status_service):
    owned = _content(status_service)
    foreign = _content(status_service, project_id="project-2", user_id="user-2")
    foreign_asset = status_service.create_project_asset(
        project_id="project-2",
        user_id="user-2",
        media_kind="image",
        source="manual_upload",
        mime_type="image/png",
        storage_uri="bunny://zone/foreign.png",
    )
    status_service.set_project_asset_primary(
        project_id="project-2",
        user_id="user-2",
        asset_id=foreign_asset.id,
        target_type="content",
        target_id=foreign.id,
        usage_action="publish_media",
        placement="PLC_SOCIAL_POST_IMAGE",
    )

    assert status_service.list_primary_project_asset_usages(
        project_id="project-1", user_id="user-1", content_id=owned.id
    ) == []
