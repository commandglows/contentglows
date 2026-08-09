from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from api.dependencies.auth import CurrentUser, require_current_user
from api.routers.social_placements import router


def _client(*, authenticated=True):
    app = FastAPI()
    app.include_router(router)
    if authenticated:
        app.dependency_overrides[require_current_user] = lambda: CurrentUser(
            user_id="user-1", email="user@example.com", bearer_token="token"
        )
    return TestClient(app)


def _content(content_type="article"):
    return SimpleNamespace(
        id="content-1",
        project_id="project-1",
        user_id="user-1",
        content_type=content_type,
        metadata={},
    )


def test_plan_requires_auth():
    response = _client(authenticated=False).get(
        "/api/content/content-1/placement-plan?platform=twitter"
    )
    assert response.status_code == 401


def test_plan_accepts_repeated_platform_aliases_and_locale():
    svc = MagicMock()
    with (
        patch("api.routers.social_placements.get_status_service", return_value=svc),
        patch(
            "api.routers.social_placements.require_owned_content_record",
            AsyncMock(return_value=_content()),
        ),
    ):
        response = _client().get(
            "/api/content/content-1/placement-plan?platform=twitter&platform=linkedin&locale=fr-FR"
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["format_id"] == "FMT_ARTICLE"
    assert [item["platform_id"] for item in payload["platforms"]] == ["PLAT_X", "PLAT_LINKEDIN"]
    assert payload["locale"] == "fr"


def test_plan_unknown_platform_returns_supported_ids():
    svc = MagicMock()
    with (
        patch("api.routers.social_placements.get_status_service", return_value=svc),
        patch(
            "api.routers.social_placements.require_owned_content_record",
            AsyncMock(return_value=_content()),
        ),
    ):
        response = _client().get(
            "/api/content/content-1/placement-plan?platform=not-real"
        )

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["code"] == "PFL_UNSUPPORTED_PLATFORM"
    assert "PLAT_X" in detail["supported_platform_ids"]


def test_plan_hides_foreign_content_as_not_found():
    svc = MagicMock()
    with (
        patch("api.routers.social_placements.get_status_service", return_value=svc),
        patch(
            "api.routers.social_placements.require_owned_content_record",
            AsyncMock(side_effect=HTTPException(status_code=403, detail="Forbidden")),
        ),
    ):
        response = _client().get(
            "/api/content/content-1/placement-plan?platform=twitter"
        )

    assert response.status_code == 404
    assert response.json()["detail"] == "Content not found"


def test_preflight_authorizes_account_and_returns_sanitized_slots():
    svc = MagicMock()
    svc.list_primary_project_asset_usages.return_value = []
    authorized = AsyncMock(return_value={"id": "account-1"})
    with (
        patch("api.routers.social_placements.get_status_service", return_value=svc),
        patch(
            "api.routers.social_placements.require_owned_content_record",
            AsyncMock(return_value=_content("social_post")),
        ),
        patch("api.routers.social_placements.require_active_publish_account", authorized),
    ):
        response = _client().post(
            "/api/publish/preflight",
            json={
                "content_record_id": "content-1",
                "platforms": [{"platform": "instagram", "account_id": "account-1"}],
            },
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["can_publish"] is False
    assert "storage_uri" not in str(payload)
    authorized.assert_awaited_once_with(
        current_user=authorized.await_args.kwargs["current_user"],
        project_id="project-1",
        account_id="account-1",
        platform="instagram",
        provider="zernio",
    )

