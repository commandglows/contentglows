from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException

from api.models.status import (
    AttachGlobalProjectAssetRequest,
    AssetTagModerationRequest,
    ProjectAssetRecommendationRequest,
    ProjectAssetCategoryAssignmentRequest,
    QueueAssetUnderstandingRequest,
    RetryAssetUnderstandingRequest,
    ClearProjectAssetPrimaryRequest,
    ProjectAssetEligibilityRequest,
    ProjectAssetPrimaryRequest,
    SelectProjectAssetRequest,
)
from api.routers import assets as router
from status.service import ContentNotFoundError, ProjectAssetEligibilityError


def _asset(asset_id: str = "asset-1", status: str = "active", media_kind: str = "image"):
    now = datetime.utcnow()
    return SimpleNamespace(
        id=asset_id,
        project_id="project-1",
        user_id="user-1",
        source_asset_id=None,
        content_asset_id="content-asset-1",
        media_kind=media_kind,
        source="content_asset",
        mime_type="image/png",
        file_name="file.png",
        storage_uri="bunny://zone/path",
        status=status,
        metadata={},
        created_at=now,
        updated_at=now,
        tombstoned_at=None,
        cleanup_eligible_at=None,
        model_dump=lambda: {
            "id": asset_id,
            "project_id": "project-1",
            "user_id": "user-1",
            "source_asset_id": None,
            "content_asset_id": "content-asset-1",
            "media_kind": media_kind,
            "source": "content_asset",
            "mime_type": "image/png",
            "file_name": "file.png",
            "storage_uri": "bunny://zone/path",
            "status": status,
            "metadata": {},
            "created_at": now,
            "updated_at": now,
            "tombstoned_at": None,
            "cleanup_eligible_at": None,
        },
    )


def _usage():
    now = datetime.utcnow()
    return SimpleNamespace(
        model_dump=lambda: {
            "id": "usage-1",
            "asset_id": "asset-1",
            "project_id": "project-1",
            "user_id": "user-1",
            "target_type": "content",
            "target_id": "content-1",
            "placement": "hero",
            "usage_action": "select_for_content",
            "is_primary": True,
            "metadata": {},
            "created_at": now,
            "updated_at": now,
            "deleted_at": None,
        }
    )


def _event():
    now = datetime.utcnow()
    return SimpleNamespace(
        model_dump=lambda: {
            "id": "event-1",
            "asset_id": "asset-1",
            "project_id": "project-1",
            "user_id": "user-1",
            "event_type": "selected",
            "target_type": "content",
            "target_id": "content-1",
            "placement": "hero",
            "metadata": {},
            "created_at": now,
        }
    )


@pytest.mark.asyncio
async def test_list_project_assets_returns_items(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(list_project_assets=lambda **_: [_asset()])
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    response = await router.list_project_assets(
        project_id="project-1",
        current_user=SimpleNamespace(user_id="user-1"),
    )
    assert response.total == 1
    assert response.items[0].id == "asset-1"
    assert response.items[0].storage_uri is None
    assert response.items[0].storage_descriptor["state"] == "durable_bunny"
    assert response.items[0].suggested_export_file_name == "uncategorized-file.png"


@pytest.mark.asyncio
async def test_category_catalog_and_assignment_routes(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    captured = {}

    def _assign(**kwargs):
        captured.update(kwargs)
        asset = _asset()
        payload = asset.model_dump()
        payload["category_id"] = "editorial_visual"
        payload["subcategory_id"] = "infographic"
        payload["original_file_name"] = "file.png"
        asset.model_dump = lambda: payload
        return asset

    fake_service = SimpleNamespace(assign_project_asset_category=_assign)
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    catalog = await router.get_project_asset_category_catalog_route(
        project_id="project-1",
        locale="fr-FR",
        current_user=SimpleNamespace(user_id="user-1"),
    )
    assigned = await router.assign_project_asset_category(
        project_id="project-1",
        asset_id="asset-1",
        request=ProjectAssetCategoryAssignmentRequest(
            category_id="editorial_visual",
            subcategory_id="infographic",
        ),
        current_user=SimpleNamespace(user_id="user-1"),
    )

    assert catalog.locale == "fr"
    assert catalog.categories[0].label == "Identité de marque"
    assert assigned.category_id == "editorial_visual"
    assert assigned.suggested_export_file_name == "editorial_visual-infographic-file.png"
    assert captured["user_id"] == "user-1"


@pytest.mark.asyncio
async def test_get_project_asset_detail_returns_404(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(
        get_project_asset_detail=lambda **_: (_ for _ in ()).throw(ContentNotFoundError("not found"))
    )
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    with pytest.raises(HTTPException) as exc:
        await router.get_project_asset_detail(
            project_id="project-1",
            asset_id="missing",
            current_user=SimpleNamespace(user_id="user-1"),
        )
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_select_project_asset_returns_conflict_for_ineligible(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(
        select_project_asset=lambda **_: (_ for _ in ()).throw(ProjectAssetEligibilityError("ineligible"))
    )
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    with pytest.raises(HTTPException) as exc:
        await router.select_project_asset(
            project_id="project-1",
            asset_id="asset-1",
            request=SelectProjectAssetRequest(
                target_type="content",
                target_id="content-1",
                usage_action="select_for_content",
                is_primary=True,
            ),
            current_user=SimpleNamespace(user_id="user-1"),
        )
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_project_asset_eligibility_returns_result(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(
        get_project_asset_eligibility=lambda **_: {
            "asset_id": "asset-1",
            "usage_action": "select_for_content",
            "target_type": "content",
            "target_id": "content-1",
            "eligible": True,
            "reason": None,
        }
    )
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    response = await router.get_project_asset_eligibility(
        project_id="project-1",
        asset_id="asset-1",
        request=ProjectAssetEligibilityRequest(
            usage_action="select_for_content",
            target_type="content",
            target_id="content-1",
        ),
        current_user=SimpleNamespace(user_id="user-1"),
    )

    assert response.eligible is True


@pytest.mark.asyncio
async def test_get_project_asset_events_returns_items(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(get_project_asset_events=lambda **_: [_event()])
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    response = await router.get_project_asset_events(
        project_id="project-1",
        asset_id="asset-1",
        current_user=SimpleNamespace(user_id="user-1"),
    )

    assert response[0].event_type == "selected"


@pytest.mark.asyncio
async def test_set_and_clear_project_asset_primary(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(
        set_project_asset_primary=lambda **_: _usage(),
        clear_project_asset_primary=lambda **_: 1,
    )
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    primary = await router.set_project_asset_primary(
        project_id="project-1",
        asset_id="asset-1",
        request=ProjectAssetPrimaryRequest(
            target_type="content",
            target_id="content-1",
            usage_action="select_for_content",
            placement="hero",
        ),
        current_user=SimpleNamespace(user_id="user-1"),
    )
    cleared = await router.clear_project_asset_primary(
        project_id="project-1",
        request=ClearProjectAssetPrimaryRequest(
            target_type="content",
            target_id="content-1",
            placement="hero",
        ),
        current_user=SimpleNamespace(user_id="user-1"),
    )

    assert primary.is_primary is True
    assert cleared.cleared_count == 1


@pytest.mark.asyncio
async def test_cleanup_report_route(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(list_project_assets=lambda **_: [_asset(status="degraded")])
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    response = await router.get_project_asset_cleanup_report(
        project_id="project-1",
        current_user=SimpleNamespace(user_id="user-1"),
    )

    assert response.degraded[0].asset_id == "asset-1"
    assert response.physical_delete_allowed is False


@pytest.mark.asyncio
async def test_queue_understanding_route(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    now = datetime.utcnow()
    fake_job = SimpleNamespace(
        model_dump=lambda: {
            "id": "job-1",
            "asset_id": "asset-1",
            "project_id": "project-1",
            "user_id": "user-1",
            "media_type": "image",
            "provider": "gemini_compatible",
            "credential_source": "platform",
            "status": "queued",
            "idempotency_key": "idem-1",
            "retry_of_job_id": None,
            "error_code": None,
            "error_message": None,
            "attempts": 0,
            "metadata": {},
            "created_at": now,
            "updated_at": now,
        }
    )
    fake_service = SimpleNamespace(queue_asset_understanding_job=lambda **_: fake_job)
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    response = await router.queue_asset_understanding(
        project_id="project-1",
        asset_id="asset-1",
        request=QueueAssetUnderstandingRequest(idempotency_key="idem-1"),
        current_user=SimpleNamespace(user_id="user-1"),
    )
    assert response.id == "job-1"


@pytest.mark.asyncio
async def test_recommend_route(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    captured = {}
    def _recommend(**kwargs):
        captured.update(kwargs)
        return [{"asset_id": "asset-1", "score": 0.9, "fit_reasons": [], "warnings": [], "suggested_placements": []}]
    fake_service = SimpleNamespace(recommend_project_assets_for_brief=_recommend)
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    response = await router.recommend_project_assets(
        project_id="project-1",
        request=ProjectAssetRecommendationRequest(desired_tags=["deer"], include_global_candidates=True),
        current_user=SimpleNamespace(user_id="user-1"),
    )
    assert response.items[0].asset_id == "asset-1"
    assert captured["include_global_candidates"] is True


@pytest.mark.asyncio
async def test_retry_understanding_route_404(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(
        retry_asset_understanding_job=lambda **_: (_ for _ in ()).throw(ContentNotFoundError("not found"))
    )
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    with pytest.raises(HTTPException) as exc:
        await router.retry_asset_understanding(
            project_id="project-1",
            asset_id="asset-1",
            request=RetryAssetUnderstandingRequest(job_id="job-missing"),
            current_user=SimpleNamespace(user_id="user-1"),
        )
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_moderate_tags_route(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    now = datetime.utcnow()
    fake_job = SimpleNamespace(
        model_dump=lambda: {
            "id": "job-1",
            "asset_id": "asset-1",
            "project_id": "project-1",
            "user_id": "user-1",
            "media_type": "image",
            "provider": "gemini_compatible",
            "credential_source": "platform",
            "status": "completed",
            "idempotency_key": "idem-1",
            "retry_of_job_id": None,
            "error_code": None,
            "error_message": None,
            "attempts": 1,
            "metadata": {},
            "created_at": now,
            "updated_at": now,
        }
    )
    fake_result = SimpleNamespace(
        asset_id="asset-1",
        project_id="project-1",
        summary="ok",
        tags=[],
        segments=[],
        source_attribution=None,
        credential_source="platform",
        provider="gemini_compatible",
    )
    fake_service = SimpleNamespace(
        moderate_asset_understanding_tags=lambda **_: {"job": fake_job, "result": fake_result}
    )
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)
    response = await router.moderate_asset_understanding_tags(
        project_id="project-1",
        asset_id="asset-1",
        request=AssetTagModerationRequest(
            decisions=[{"action": "accept", "key": "deer", "label": "Deer"}],
            manual_tags=["Fast Motion"],
        ),
        current_user=SimpleNamespace(user_id="user-1"),
    )
    assert response.job.id == "job-1"


@pytest.mark.asyncio
async def test_attach_global_asset_route(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(attach_global_project_asset=lambda **_: _asset(asset_id="asset-attached"))
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    response = await router.attach_global_project_asset(
        project_id="project-1",
        request=AttachGlobalProjectAssetRequest(global_asset_id="asset-global"),
        current_user=SimpleNamespace(user_id="user-1"),
    )
    assert response.id == "asset-attached"


@pytest.mark.asyncio
async def test_attach_global_asset_route_404(monkeypatch):
    monkeypatch.setattr(router, "require_owned_project_id", AsyncMock(return_value="project-1"))
    fake_service = SimpleNamespace(
        attach_global_project_asset=lambda **_: (_ for _ in ()).throw(ContentNotFoundError("not found"))
    )
    monkeypatch.setattr(router, "get_status_service", lambda: fake_service)

    with pytest.raises(HTTPException) as exc:
        await router.attach_global_project_asset(
            project_id="project-1",
            request=AttachGlobalProjectAssetRequest(global_asset_id="missing"),
            current_user=SimpleNamespace(user_id="user-1"),
        )
    assert exc.value.status_code == 404
