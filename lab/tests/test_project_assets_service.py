import sqlite3
from concurrent.futures import ThreadPoolExecutor

import pytest


@pytest.fixture
def status_service(monkeypatch):
    from status import service as status_service_module
    from status import StatusService

    def _sqlite_conn(_db_path=None):
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        return conn

    monkeypatch.setattr(status_service_module, "get_connection", _sqlite_conn)
    return StatusService()


def _create_content(status_service, *, project_id="project-1", user_id="user-1"):
    return status_service.create_content(
        title="Draft title",
        content_type="article",
        source_robot="manual",
        status="pending_review",
        project_id=project_id,
        user_id=user_id,
        content_preview="Preview",
    )


def _create_project_asset(
    status_service,
    *,
    content=None,
    project_id="project-1",
    user_id="user-1",
    mime_type="image/png",
    kind="image",
    status="uploaded",
    storage_uri="bunny://zone/path",
    metadata=None,
    file_name=None,
):
    content = content or _create_content(status_service, project_id=project_id, user_id=user_id)
    content_asset = status_service.create_content_asset(
        content_id=content.id,
        project_id=project_id,
        user_id=user_id,
        kind=kind,
        mime_type=mime_type,
        file_name=file_name,
        storage_uri=storage_uri,
        status=status,
        metadata=metadata,
    )
    assets = status_service.list_project_assets(project_id=project_id, user_id=user_id)
    return next(asset for asset in assets if asset.content_asset_id == content_asset.id)


def test_project_asset_category_assignment_filter_and_original_filename(status_service):
    asset = _create_project_asset(status_service, file_name="Original Campaign.PNG")

    assigned = status_service.assign_project_asset_category(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        category_id="editorial_visual",
        subcategory_id="infographic",
    )
    matching = status_service.list_project_assets(
        project_id="project-1",
        user_id="user-1",
        category_id="editorial_visual",
        subcategory_id="infographic",
    )
    non_matching = status_service.list_project_assets(
        project_id="project-1",
        user_id="user-1",
        category_id="brand_identity",
    )
    events = status_service.get_project_asset_events(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )

    assert assigned.category_id == "editorial_visual"
    assert assigned.subcategory_id == "infographic"
    assert assigned.file_name == "Original Campaign.PNG"
    assert assigned.original_file_name == "Original Campaign.PNG"
    assert [item.id for item in matching] == [asset.id]
    assert non_matching == []
    assert events[0].event_type == "category_assigned"
    assert events[0].metadata == {
        "category_id": "editorial_visual",
        "subcategory_id": "infographic",
    }


def test_project_asset_category_validation_is_atomic(status_service):
    asset = _create_project_asset(status_service)

    with pytest.raises(ValueError, match="Unsupported subcategory_id"):
        status_service.assign_project_asset_category(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
            category_id="brand_identity",
            subcategory_id="sound_effect",
        )

    unchanged = status_service.get_project_asset_detail(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )
    assert unchanged.category_id is None
    assert unchanged.subcategory_id is None


def test_project_asset_category_migration_is_idempotent(status_service):
    from status.db import init_db

    init_db(status_service._conn)
    columns = {
        row["name"]
        for row in status_service._conn.execute("PRAGMA table_info(project_assets)").fetchall()
    }
    indexes = {
        row["name"]
        for row in status_service._conn.execute("PRAGMA index_list(project_assets)").fetchall()
    }

    assert {"original_file_name", "category_id", "subcategory_id"} <= columns
    assert "idx_project_assets_category" in indexes


def _create_video_version(status_service, *, project_id="project-1", user_id="user-1", content=None):
    content = content or _create_content(status_service, project_id=project_id, user_id=user_id)
    status_service._conn.execute(
        """
        INSERT INTO video_timelines (
            id, user_id, project_id, content_id, format_preset, status,
            current_version_id, draft_revision, draft_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 'active', ?, 1, ?, ?, ?)
        """,
        (
            "timeline-1",
            user_id,
            project_id,
            content.id,
            "vertical_9_16",
            "video-version-1",
            "{}",
            "2026-05-14T12:00:00",
            "2026-05-14T12:00:00",
        ),
    )
    status_service._conn.execute(
        """
        INSERT INTO video_timeline_versions (
            id, timeline_id, user_id, project_id, content_id, format_preset,
            version_number, timeline_json, renderer_props_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
        """,
        (
            "video-version-1",
            "timeline-1",
            user_id,
            project_id,
            content.id,
            "vertical_9_16",
            "{}",
            "{}",
            "2026-05-14T12:00:00",
        ),
    )
    status_service._conn.commit()
    return "video-version-1"


def _usage_count(status_service):
    row = status_service._conn.execute("SELECT COUNT(*) AS count FROM project_asset_usages").fetchone()
    return row["count"]


def test_select_project_asset_validates_content_target_same_project_and_user(status_service):
    from status.service import ProjectAssetEligibilityError

    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)

    usage = status_service.select_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="select_for_content",
        placement="hero",
        is_primary=True,
    )

    assert usage.target_id == content.id
    assert usage.is_primary is True
    assert _usage_count(status_service) == 1

    with pytest.raises(ProjectAssetEligibilityError):
        status_service.select_project_asset(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
            target_type="content",
            target_id=content.id,
            usage_action="unsupported_action",
        )
    assert _usage_count(status_service) == 1


def test_project_asset_selection_records_event_and_eligibility(status_service):
    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)

    eligible = status_service.get_project_asset_eligibility(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        usage_action="select_for_content",
        target_type="content",
        target_id=content.id,
    )
    assert eligible["eligible"] is True

    status_service.select_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="select_for_content",
        placement="hero",
        is_primary=True,
    )

    events = status_service.get_project_asset_events(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )
    assert events[0].event_type == "selected"
    assert events[0].target_id == content.id
    assert events[0].metadata["usage_action"] == "select_for_content"


def test_project_asset_eligibility_reports_invalid_target_without_mutation(status_service):
    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)

    result = status_service.get_project_asset_eligibility(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        usage_action="select_for_content",
        target_type="content",
        target_id="missing-content",
    )

    assert result["eligible"] is False
    assert "not found" in result["reason"]
    assert _usage_count(status_service) == 0


def test_select_project_asset_rejects_foreign_content_target_without_mutation(status_service):
    from status.service import ContentNotFoundError

    owned_content = _create_content(status_service, project_id="project-1", user_id="user-1")
    foreign_content = _create_content(status_service, project_id="project-2", user_id="user-1")
    asset = _create_project_asset(status_service, content=owned_content)

    with pytest.raises(ContentNotFoundError):
        status_service.select_project_asset(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
            target_type="content",
            target_id=foreign_content.id,
            usage_action="select_for_content",
            placement="hero",
            is_primary=True,
        )

    assert _usage_count(status_service) == 0


def test_select_project_asset_primary_replaces_existing_primary(status_service):
    content = _create_content(status_service)
    first_asset = _create_project_asset(status_service, content=content)
    second_asset = _create_project_asset(
        status_service,
        content=content,
        mime_type="image/jpeg",
        kind="image",
    )

    first_usage = status_service.select_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=first_asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="select_for_content",
        placement="hero",
        is_primary=True,
    )
    second_usage = status_service.select_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=second_asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="select_for_content",
        placement="hero",
        is_primary=True,
    )

    rows = status_service._conn.execute(
        """
        SELECT id, is_primary FROM project_asset_usages
        WHERE project_id = ? AND target_type = ? AND target_id = ? AND placement = ?
        ORDER BY created_at ASC
        """,
        ("project-1", "content", content.id, "hero"),
    ).fetchall()

    assert [row["id"] for row in rows] == [first_usage.id, second_usage.id]
    assert [row["is_primary"] for row in rows] == [0, 1]


def test_publish_primary_persists_canonical_placement_and_demotes_alias(status_service):
    content = _create_content(status_service)
    first_asset = _create_project_asset(status_service, content=content)
    second_asset = _create_project_asset(status_service, content=content, mime_type="image/jpeg")

    first = status_service.set_project_asset_primary(
        project_id="project-1",
        user_id="user-1",
        asset_id=first_asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="publish_media",
        placement="social_image",
    )
    second = status_service.set_project_asset_primary(
        project_id="project-1",
        user_id="user-1",
        asset_id=second_asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="publish_media",
        placement="PLC_SOCIAL_POST_IMAGE",
    )

    rows = status_service._conn.execute(
        "SELECT id,placement,is_primary FROM project_asset_usages ORDER BY created_at,id"
    ).fetchall()
    assert first.placement == second.placement == "PLC_SOCIAL_POST_IMAGE"
    assert [row["is_primary"] for row in rows] == [0, 1]


def test_publish_primary_rejects_unknown_or_missing_placement(status_service):
    from status.service import ProjectAssetEligibilityError

    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)
    for placement in (None, "not-real"):
        with pytest.raises(ProjectAssetEligibilityError):
            status_service.set_project_asset_primary(
                project_id="project-1",
                user_id="user-1",
                asset_id=asset.id,
                target_type="content",
                target_id=content.id,
                usage_action="publish_media",
                placement=placement,
            )
    assert _usage_count(status_service) == 0


def test_concurrent_publish_primary_selection_keeps_exactly_one_primary(monkeypatch, tmp_path):
    from status import service as service_module
    from status import StatusService

    database = tmp_path / "primary-race.sqlite"

    def _connection(db_path=None):
        conn = sqlite3.connect(str(db_path or database), timeout=5, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        return conn

    monkeypatch.setattr(service_module, "get_connection", _connection)
    setup = StatusService(str(database))
    content = _create_content(setup)
    first_asset = _create_project_asset(setup, content=content)
    second_asset = _create_project_asset(setup, content=content, mime_type="image/jpeg")
    first_service = StatusService(str(database))
    second_service = StatusService(str(database))

    def select(service, asset_id):
        return service.set_project_asset_primary(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset_id,
            target_type="content",
            target_id=content.id,
            usage_action="publish_media",
            placement="PLC_SOCIAL_POST_IMAGE",
        )

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [
            pool.submit(select, first_service, first_asset.id),
            pool.submit(select, second_service, second_asset.id),
        ]
        [future.result() for future in futures]

    rows = setup._conn.execute(
        """
        SELECT asset_id FROM project_asset_usages
        WHERE project_id='project-1' AND user_id='user-1' AND target_type='content'
          AND target_id=? AND placement='PLC_SOCIAL_POST_IMAGE'
          AND is_primary=1 AND deleted_at IS NULL
        """,
        (content.id,),
    ).fetchall()
    assert len(rows) == 1


def test_clear_project_asset_primary_records_event(status_service):
    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)
    status_service.set_project_asset_primary(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="content",
        target_id=content.id,
        usage_action="select_for_content",
        placement="hero",
    )

    changed = status_service.clear_project_asset_primary(
        project_id="project-1",
        user_id="user-1",
        target_type="content",
        target_id=content.id,
        placement="hero",
    )

    events = status_service.get_project_asset_events(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )
    assert changed == 1
    assert events[0].event_type == "primary_cleared"


def test_set_project_asset_primary_rejects_incompatible_content_media_kind_without_mutation(status_service):
    from status.service import ProjectAssetEligibilityError

    content = _create_content(status_service)
    asset = _create_project_asset(
        status_service,
        content=content,
        mime_type="audio/mpeg",
        kind="audio",
    )

    with pytest.raises(ProjectAssetEligibilityError, match="Incompatible media_kind"):
        status_service.set_project_asset_primary(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
            target_type="content",
            target_id=content.id,
            usage_action="set_primary",
            placement="hero",
        )

    assert _usage_count(status_service) == 0


def test_tombstone_restore_records_events(status_service):
    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)

    tombstoned = status_service.tombstone_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )
    restored = status_service.restore_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )

    events = status_service.get_project_asset_events(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
    )
    assert tombstoned.status == "tombstoned"
    assert restored.status == "active"
    assert [event.event_type for event in events[:2]] == ["restored", "tombstoned"]


def test_select_project_asset_rejects_wrong_target_type_without_mutation(status_service):
    from status.service import ProjectAssetEligibilityError

    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)

    with pytest.raises(ProjectAssetEligibilityError, match="requires target_type"):
        status_service.select_project_asset(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
            target_type="video_version",
            target_id="video-version-1",
            usage_action="select_for_content",
        )

    assert _usage_count(status_service) == 0


def test_select_project_asset_allows_render_safe_image_for_video_version(status_service):
    content = _create_content(status_service)
    version_id = _create_video_version(status_service, content=content)
    asset = _create_project_asset(status_service, content=content)

    usage = status_service.select_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="video_version",
        target_id=version_id,
        usage_action="select_for_video_version",
        placement="clip-1",
    )

    assert usage.target_id == version_id
    assert usage.usage_action == "select_for_video_version"
    assert _usage_count(status_service) == 1


def test_select_project_asset_rejects_missing_video_version_target(status_service):
    from status.service import ContentNotFoundError

    content = _create_content(status_service)
    asset = _create_project_asset(
        status_service,
        content=content,
        mime_type="audio/mpeg",
        kind="audio",
    )

    with pytest.raises(ContentNotFoundError, match="Video version target"):
        status_service.select_project_asset(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
            target_type="video_version",
            target_id="video-version-1",
            usage_action="select_for_video_version",
        )

    assert _usage_count(status_service) == 0


def test_select_project_asset_rejects_provider_temporary_asset_for_video_version(status_service):
    from status.service import ProjectAssetEligibilityError

    content = _create_content(status_service)
    version_id = _create_video_version(status_service, content=content)
    asset = _create_project_asset(
        status_service,
        content=content,
        storage_uri="https://provider.example.com/tmp.png?token=secret",
    )

    with pytest.raises(ProjectAssetEligibilityError, match="not render-safe"):
        status_service.select_project_asset(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset.id,
            target_type="video_version",
            target_id=version_id,
            usage_action="select_for_video_version",
        )

    assert _usage_count(status_service) == 0


def test_video_source_usage_unlink_retains_canonical_asset(status_service):
    content = _create_content(status_service)
    asset = _create_project_asset(status_service, content=content)
    status_service.ensure_video_source_folder_usage_target(
        project_id="project-1", user_id="user-1", folder_id="folder-1"
    )
    status_service.select_project_asset(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="video_source_folder",
        target_id="folder-1",
        usage_action="attach_video_source",
        metadata={"source_id": "source-1"},
    )

    changed = status_service.unlink_project_asset_usage(
        project_id="project-1",
        user_id="user-1",
        asset_id=asset.id,
        target_type="video_source_folder",
        target_id="folder-1",
        source_id="source-1",
    )

    assert changed == 1
    assert status_service.get_project_asset_usage(
        project_id="project-1", user_id="user-1", asset_id=asset.id
    ) == []
    retained = status_service.get_project_asset_detail(
        project_id="project-1", user_id="user-1", asset_id=asset.id
    )
    assert retained.status != "tombstoned"


def test_video_source_unlink_removes_original_and_derived_usages_only(status_service):
    content = _create_content(status_service)
    original = _create_project_asset(status_service, content=content)
    derived = status_service.create_project_asset(
        project_id="project-1",
        user_id="user-1",
        media_kind="thumbnail",
        source="manual_upload",
        mime_type="image/webp",
        storage_uri="bunny://zone/preview.webp",
        source_asset_id=original.id,
    )
    status_service.ensure_video_source_folder_usage_target(
        project_id="project-1", user_id="user-1", folder_id="folder-1"
    )
    for asset_id, role in ((original.id, "original"), (derived.id, "preview")):
        status_service.select_project_asset(
            project_id="project-1",
            user_id="user-1",
            asset_id=asset_id,
            target_type="video_source_folder",
            target_id="folder-1",
            usage_action="attach_video_source",
            metadata={"source_id": "source-1", "derived_role": role},
        )

    changed = status_service.unlink_video_source_usages(
        project_id="project-1",
        user_id="user-1",
        folder_id="folder-1",
        source_id="source-1",
    )

    assert changed == 2
    for asset in (original, derived):
        assert status_service.get_project_asset_usage(
            project_id="project-1", user_id="user-1", asset_id=asset.id
        ) == []
        retained = status_service.get_project_asset_detail(
            project_id="project-1", user_id="user-1", asset_id=asset.id
        )
        assert retained.status != "tombstoned"
