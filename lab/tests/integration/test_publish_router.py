from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from api.dependencies.auth import CurrentUser, require_current_user
from api.routers.publish import router as publish_router


class _FakeAsyncClient:
    def __init__(self, response):
        self._response = response
        self.post_calls = []
        self.get_calls = []
        self.delete_calls = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def post(self, *args, **kwargs):
        self.post_calls.append((args, kwargs))
        if isinstance(self._response, BaseException):
            raise self._response
        return self._response

    async def get(self, *args, **kwargs):
        self.get_calls.append((args, kwargs))
        return self._response

    async def delete(self, *args, **kwargs):
        self.delete_calls.append((args, kwargs))
        return self._response


def _build_client(*, authenticated: bool = True) -> TestClient:
    app = FastAPI()
    app.include_router(publish_router)
    if authenticated:
        app.dependency_overrides[require_current_user] = lambda: CurrentUser(
            user_id="user_123",
            email="user@example.com",
            bearer_token="test-token",
        )
    return TestClient(app)


def _owned_record(status="approved", metadata=None):
    return SimpleNamespace(
        id="content_1",
        project_id="project_a",
        user_id="user_123",
        content_type="social_post",
        status=status,
        metadata=metadata or {},
    )


def _authorized_account():
    return {
        "id": "local_acct_1",
        "userId": "user_123",
        "projectId": "project_a",
        "provider": "zernio",
        "platform": "twitter",
        "providerAccountId": "acct_1",
        "providerProfileId": "prof_1",
        "status": "active",
        "isDefault": True,
    }


def test_publish_accounts_requires_auth():
    client = _build_client(authenticated=False)
    response = client.get("/api/publish/accounts?project_id=project_a")
    assert response.status_code == 401
    assert response.json()["detail"] == "Missing bearer token"


def test_publish_accounts_are_project_scoped():
    client = _build_client()
    account = _authorized_account() | {
        "displayName": "Diane X",
        "username": "diane",
        "avatar": None,
        "createdAt": datetime.fromtimestamp(1),
        "updatedAt": datetime.fromtimestamp(2),
        "lastSyncedAt": datetime.fromtimestamp(3),
    }
    store = SimpleNamespace(
        list_publish_accounts=AsyncMock(return_value=[account]),
    )

    with (
        patch("api.routers.publish.require_owned_project_id", AsyncMock(return_value="project_a")),
        patch("api.routers.publish.user_data_store", store),
    ):
        response = client.get("/api/publish/accounts?project_id=project_a")

    assert response.status_code == 200
    payload = response.json()
    assert payload["accounts"] == [
        {
            "id": "local_acct_1",
            "projectId": "project_a",
            "provider": "zernio",
            "platform": "twitter",
            "accountId": "acct_1",
            "providerAccountId": "acct_1",
            "username": "diane",
            "display_name": "Diane X",
            "displayName": "Diane X",
            "avatar": None,
            "status": "active",
            "isDefault": True,
            "lastSyncedAt": "1970-01-01T00:00:03",
        }
    ]
    store.list_publish_accounts.assert_awaited_once_with(
        "user_123",
        "project_a",
        provider="zernio",
    )


def test_publish_rejects_forged_account_before_provider_call():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    fake_service.get_content.return_value = fake_record

    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch(
            "api.routers.publish.require_active_publish_account",
            AsyncMock(side_effect=HTTPException(status_code=403, detail="Forbidden")),
        ),
        patch("api.routers.publish.httpx.AsyncClient") as async_client,
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Hello world",
                "platforms": [{"platform": "twitter", "account_id": "forged_acct"}],
                "title": "Test publish",
                "content_record_id": "content_1",
                "publish_now": True,
            },
        )

    assert response.status_code == 403
    async_client.assert_not_called()


def test_publish_requires_content_record_id_before_provider_call():
    client = _build_client()

    with patch("api.routers.publish.httpx.AsyncClient") as async_client:
        response = client.post(
            "/api/publish",
            json={
                "content": "Hello world",
                "platforms": [{"platform": "twitter", "account_id": "acct_1"}],
                "publish_now": True,
            },
        )

    assert response.status_code == 422
    async_client.assert_not_called()


def test_publish_persists_metadata_and_published_transitions():
    client = _build_client()
    fake_record = _owned_record(metadata={"existing": "value"})
    fake_service = MagicMock()
    fake_service.get_content.return_value = fake_record

    http_response = MagicMock()
    http_response.status_code = 200
    http_response.headers = {"content-type": "application/json"}
    http_response.json.return_value = {
        "posts": [
            {
                "_id": "post_123",
                "status": "published",
                "platforms": [
                    {
                        "platform": "twitter",
                        "status": "published",
                        "platformPostUrl": "https://x.example/post_123",
                    }
                ],
            }
        ]
    }

    fake_client = _FakeAsyncClient(http_response)
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient", return_value=fake_client),
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Hello world",
                "platforms": [{"platform": "twitter", "account_id": "local_acct_1"}],
                "title": "Test publish",
                "content_record_id": "content_1",
                "publish_now": True,
            },
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["post_id"] == "post_123"
    assert payload["platform_urls"] == {"twitter": "https://x.example/post_123"}
    assert fake_client.post_calls[0][1]["json"]["platforms"] == [
        {"platform": "twitter", "accountId": "acct_1"}
    ]

    assert fake_service.update_content.call_count == 2
    _, kwargs = fake_service.update_content.call_args_list[-1]
    assert kwargs["target_url"] == "https://x.example/post_123"
    assert kwargs["metadata"]["existing"] == "value"
    publish_meta = kwargs["metadata"]["publish"]
    assert publish_meta["provider"] == "zernio"
    assert publish_meta["providerPostId"] == "post_123"
    assert publish_meta["post_id"] == "post_123"
    assert publish_meta["status"] == "published"
    assert publish_meta["platform_urls"] == {"twitter": "https://x.example/post_123"}
    assert publish_meta["platformResults"][0]["status"] == "published"
    assert publish_meta["mediaContract"] == "legacy_raw_urls"
    assert publish_meta["legacyMediaCount"] == 0
    assert "providerRequestId" in publish_meta

    assert fake_service.transition.call_count == 2
    assert fake_service.transition.call_args_list[0].args == (
        "content_1",
        "publishing",
        "user_123",
    )
    assert fake_service.transition.call_args_list[1].args == (
        "content_1",
        "published",
        "user_123",
    )


def test_publish_supports_typed_video_media_payload():
    client = _build_client()
    fake_record = _owned_record(metadata={"existing": "value"})
    fake_service = MagicMock()
    fake_service.get_content.return_value = fake_record

    http_response = MagicMock()
    http_response.status_code = 200
    http_response.headers = {"content-type": "application/json"}
    http_response.json.return_value = {
        "posts": [
            {
                "_id": "post_video_123",
                "status": "published",
                "platforms": [
                    {
                        "platform": "twitter",
                        "status": "published",
                        "platformPostUrl": "https://x.example/post_video_123",
                    }
                ],
            }
        ]
    }

    fake_client = _FakeAsyncClient(http_response)
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient", return_value=fake_client),
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Video post",
                "platforms": [{"platform": "twitter", "account_id": "local_acct_1"}],
                "content_record_id": "content_1",
                "publish_now": True,
                "media": [{"type": "video", "url": "https://cdn.example.test/final.mp4"}],
            },
        )

    assert response.status_code == 200
    assert fake_client.post_calls[0][1]["json"]["mediaItems"] == [
        {"type": "video", "url": "https://cdn.example.test/final.mp4"}
    ]
    assert "media" not in fake_client.post_calls[0][1]["json"]


def test_publish_persists_scheduled_state_without_published_transition():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    fake_service.get_content.return_value = fake_record

    http_response = MagicMock()
    http_response.status_code = 200
    http_response.headers = {"content-type": "application/json"}
    http_response.json.return_value = {
        "posts": [
            {
                "_id": "post_sched_1",
                "status": "scheduled",
                "scheduledFor": "2026-03-30T10:00:00Z",
                "platforms": [],
            }
        ]
    }

    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient", return_value=_FakeAsyncClient(http_response)),
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Scheduled post",
                "platforms": [{"platform": "twitter", "account_id": "local_acct_1"}],
                "content_record_id": "content_1",
                "publish_now": False,
                "scheduled_for": "2026-03-30T10:00:00Z",
            },
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "scheduled"

    assert fake_service.update_content.call_count == 2
    _, kwargs = fake_service.update_content.call_args_list[-1]
    assert kwargs["target_url"] is None
    assert kwargs["metadata"]["publish"]["status"] == "scheduled"
    assert kwargs["metadata"]["publish"]["scheduled_for"] == "2026-03-30T10:00:00Z"

    fake_service.transition.assert_called_once_with(
        "content_1",
        "scheduled",
        "user_123",
        reason="Queued in Zernio",
    )


def test_publish_partial_is_not_reported_as_full_success_or_published():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    fake_service.get_content.return_value = fake_record

    http_response = MagicMock()
    http_response.status_code = 200
    http_response.headers = {"content-type": "application/json"}
    http_response.json.return_value = {
        "post": {
            "_id": "post_partial_1",
            "status": "partial",
            "platforms": [
                {
                    "platform": "twitter",
                    "status": "published",
                    "platformPostUrl": "https://x.example/post_partial_1",
                },
                {
                    "platform": "linkedin",
                    "status": "failed",
                    "error": {"type": "platform_error", "code": "permissions_missing"},
                },
            ],
        }
    }

    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient", return_value=_FakeAsyncClient(http_response)),
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Partial post",
                "platforms": [{"platform": "twitter", "account_id": "local_acct_1"}],
                "content_record_id": "content_1",
            },
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is False
    assert payload["status"] == "partial"
    fake_service.transition.assert_called_once_with(
        "content_1",
        "publishing",
        "user_123",
        reason="Publishing via Zernio",
    )
    publish_meta = fake_service.update_content.call_args.kwargs["metadata"]["publish"]
    assert publish_meta["retryAvailable"] is True
    assert publish_meta["errors"][0]["code"] == "permissions_missing"


def test_connect_url_is_project_scoped_and_uses_backend_state():
    client = _build_client()
    http_response = MagicMock()
    http_response.status_code = 200
    http_response.headers = {"content-type": "application/json"}
    http_response.json.return_value = {"authUrl": "https://zernio.example/oauth"}
    store = SimpleNamespace(
        create_publish_connect_session=AsyncMock(
            return_value={
                "state": "opaque_state",
                "expiresAt": datetime.fromtimestamp(900),
            }
        )
    )

    with (
        patch("api.routers.publish.require_owned_project_id", AsyncMock(return_value="project_a")),
        patch("api.routers.publish._ensure_zernio_profile", AsyncMock(return_value={"providerProfileId": "prof_1"})),
        patch("api.routers.publish.user_data_store", store),
        patch("api.routers.publish.httpx.AsyncClient", return_value=_FakeAsyncClient(http_response)) as client_factory,
    ):
        response = client.get("/api/publish/connect/twitter?project_id=project_a")

    assert response.status_code == 200
    payload = response.json()
    assert payload["connect_url"] == "https://zernio.example/oauth"
    fake_client = client_factory.return_value
    params = fake_client.get_calls[0][1]["params"]
    assert params["profileId"] == "prof_1"
    assert "state=opaque_state" in params["redirect_url"]
    store.create_publish_connect_session.assert_awaited_once()


def test_connect_callback_refuses_project_that_no_longer_belongs_to_session_user():
    client = _build_client(authenticated=False)
    store = SimpleNamespace(
        consume_publish_connect_session=AsyncMock(
            return_value={
                "state": "opaque_state",
                "userId": "user_123",
                "projectId": "project_a",
                "provider": "zernio",
                "platform": "twitter",
                "providerProfileId": "prof_1",
            }
        )
    )
    project_store = SimpleNamespace(
        get_by_id=AsyncMock(return_value=SimpleNamespace(id="project_a", user_id="other_user"))
    )

    with (
        patch("api.routers.publish.user_data_store", store),
        patch("api.routers.publish.project_store", project_store),
        patch("api.routers.publish._sync_accounts_for_profile", AsyncMock()) as sync_accounts,
    ):
        response = client.get("/api/publish/connect/callback?state=opaque_state")

    assert response.status_code == 403
    sync_accounts.assert_not_awaited()


def test_disconnect_is_local_and_project_scoped():
    client = _build_client()
    store = SimpleNamespace(unlink_publish_account=AsyncMock(return_value=True))

    with (
        patch("api.routers.publish.require_owned_project_id", AsyncMock(return_value="project_a")),
        patch("api.routers.publish.user_data_store", store),
        patch("api.routers.publish.httpx.AsyncClient") as async_client,
    ):
        response = client.delete("/api/publish/accounts/local_acct_1?project_id=project_a")

    assert response.status_code == 200
    assert response.json()["disconnected"] is True
    async_client.assert_not_called()
    store.unlink_publish_account.assert_awaited_once_with(
        "user_123",
        "project_a",
        "local_acct_1",
        provider="zernio",
    )


def test_asset_contract_rejects_legacy_fields_before_provider_call():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.httpx.AsyncClient") as provider,
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Conflict",
                "platforms": [{"platform": "instagram", "account_id": "acct_1"}],
                "content_record_id": "content_1",
                "media_contract_version": "asset_placements.v1",
                "media_urls": ["https://assets.example.com/image.png"],
            },
        )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "PFL_LEGACY_CONFLICT"
    provider.assert_not_called()


def test_legacy_media_rejects_private_url_before_provider_call():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient") as provider,
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Private media",
                "platforms": [{"platform": "twitter", "account_id": "acct_1"}],
                "content_record_id": "content_1",
                "media_urls": ["http://127.0.0.1/private.png"],
            },
        )

    assert response.status_code == 400
    provider.assert_not_called()
    fake_service.update_content.assert_not_called()


def test_asset_contract_blocks_missing_instagram_media_without_provider_call():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    fake_service.list_primary_project_asset_usages.return_value = []
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient") as provider,
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Instagram post",
                "platforms": [{"platform": "instagram", "account_id": "acct_1"}],
                "content_record_id": "content_1",
                "media_contract_version": "asset_placements.v1",
            },
        )

    assert response.status_code == 409
    assert response.json()["detail"]["can_publish"] is False
    assert response.json()["detail"]["issues"][0]["code"] == "PFL_MISSING_REQUIRED"
    provider.assert_not_called()
    fake_service.update_content.assert_not_called()


def test_asset_contract_blocks_missing_vertical_short_without_provider_call():
    client = _build_client()
    fake_record = _owned_record()
    fake_record.content_type = "short"
    fake_service = MagicMock()
    fake_service.list_primary_project_asset_usages.return_value = []
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient") as provider,
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Short",
                "platforms": [{"platform": "tiktok", "account_id": "acct_1"}],
                "content_record_id": "content_1",
                "media_contract_version": "asset_placements.v1",
            },
        )

    assert response.status_code == 409
    assert any(
        issue["placement_id"] == "PLC_VERTICAL_SHORT_VIDEO"
        for issue in response.json()["detail"]["issues"]
    )
    provider.assert_not_called()


@pytest.mark.parametrize(
    ("asset", "expected_code"),
    [
        (None, "PFL_ASSET_NOT_FOUND"),
        (
            SimpleNamespace(
                id="asset_1",
                status="tombstoned",
                media_kind="image",
                mime_type="image/png",
                storage_uri="bunny://zone/image.png",
            ),
            "PFL_ASSET_STATUS_BLOCKED",
        ),
        (
            SimpleNamespace(
                id="asset_1",
                status="active",
                media_kind="audio",
                mime_type="audio/mpeg",
                storage_uri="bunny://zone/audio.mp3",
            ),
            "PFL_ASSET_INCOMPATIBLE",
        ),
    ],
)
def test_asset_contract_never_calls_provider_for_invalid_primary(asset, expected_code):
    client = _build_client()
    fake_record = _owned_record()
    usage = SimpleNamespace(asset_id="asset_1", placement="PLC_SOCIAL_POST_IMAGE")
    fake_service = MagicMock()
    fake_service.list_primary_project_asset_usages.return_value = [(usage, asset)]
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient") as provider,
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Invalid asset",
                "platforms": [{"platform": "instagram", "account_id": "acct_1"}],
                "content_record_id": "content_1",
                "media_contract_version": "asset_placements.v1",
            },
        )

    assert response.status_code == 409
    assert any(issue["code"] == expected_code for issue in response.json()["detail"]["issues"])
    provider.assert_not_called()


def test_asset_contract_builds_media_items_from_server_resolved_primary(monkeypatch):
    monkeypatch.setenv("BUNNY_CDN_HOSTNAME", "content.example.b-cdn.net")
    client = _build_client()
    fake_record = _owned_record()
    usage = SimpleNamespace(asset_id="asset_1", placement="PLC_SOCIAL_POST_IMAGE")
    asset = SimpleNamespace(
        id="asset_1",
        status="active",
        media_kind="image",
        mime_type="image/png",
        storage_uri="bunny://zone/path/image.png?token=ignored",
    )
    fake_service = MagicMock()
    fake_service.list_primary_project_asset_usages.return_value = [(usage, asset)]
    fake_service.get_content.return_value = fake_record
    provider_response = MagicMock(
        status_code=200,
        headers={"content-type": "application/json"},
    )
    provider_response.json.return_value = {
        "post": {"id": "post_asset_1", "status": "published", "platforms": []}
    }
    fake_client = _FakeAsyncClient(provider_response)
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient", return_value=fake_client),
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Instagram post",
                "platforms": [{"platform": "instagram", "account_id": "acct_1"}],
                "content_record_id": "content_1",
                "media_contract_version": "asset_placements.v1",
                "registry_version": "2026-05-13.1",
            },
        )

    assert response.status_code == 200
    outbound = fake_client.post_calls[0][1]
    assert outbound["json"]["mediaItems"] == [
        {"type": "image", "url": "https://content.example.b-cdn.net/path/image.png"}
    ]
    assert "media" not in outbound["json"]
    assert outbound["headers"]["x-request-id"]
    publish_meta = fake_service.update_content.call_args_list[-1].kwargs["metadata"]["publish"]
    assert publish_meta["assetPlacements"] == [
        {
            "assetId": "asset_1",
            "placementId": "PLC_SOCIAL_POST_IMAGE",
            "platformId": "PLAT_INSTAGRAM",
        }
    ]
    assert publish_meta["providerMediaSummary"] == [{"type": "image"}]
    assert "url" not in str(publish_meta["providerMediaSummary"])


def test_timeout_retry_reuses_request_id_and_reconciles_existing_post():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    fake_service.get_content.return_value = fake_record

    def apply_update(_content_id, **kwargs):
        if "metadata" in kwargs:
            fake_record.metadata = kwargs["metadata"]
        return fake_record

    fake_service.update_content.side_effect = apply_update

    def apply_transition(_content_id, next_status, _actor, **_kwargs):
        fake_record.status = next_status

    fake_service.transition.side_effect = apply_transition
    timeout_client = _FakeAsyncClient(__import__("httpx").TimeoutException("timeout"))
    provider_response = MagicMock(status_code=200, headers={"content-type": "application/json"})
    provider_response.json.return_value = {
        "existingPost": True,
        "post": {"id": "post_existing", "status": "published", "platforms": []},
    }
    existing_client = _FakeAsyncClient(provider_response)
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch("api.routers.publish.httpx.AsyncClient", side_effect=[timeout_client, existing_client]),
    ):
        first = client.post(
            "/api/publish",
            json={
                "content": "Retry me",
                "platforms": [{"platform": "twitter", "account_id": "acct_1"}],
                "content_record_id": "content_1",
            },
        )
        second = client.post(
            "/api/publish",
            json={
                "content": "Retry me",
                "platforms": [{"platform": "twitter", "account_id": "acct_1"}],
                "content_record_id": "content_1",
            },
        )

    assert first.json()["status"] == "reconciliation_pending"
    assert second.json()["post_id"] == "post_existing"
    first_id = timeout_client.post_calls[0][1]["headers"]["x-request-id"]
    second_id = existing_client.post_calls[0][1]["headers"]["x-request-id"]
    assert first_id == second_id
    publish_meta = fake_record.metadata["publish"]
    assert publish_meta["existingPost"] is True
    assert [call.args[1] for call in fake_service.transition.call_args_list] == [
        "publishing",
        "published",
    ]


def test_provider_rejection_is_persisted_as_sanitized_failure():
    client = _build_client()
    fake_record = _owned_record()
    fake_service = MagicMock()
    fake_service.get_content.return_value = fake_record
    provider_response = MagicMock(status_code=400, headers={"content-type": "application/json"})
    provider_response.json.return_value = {
        "code": "invalid_media",
        "message": "secret provider body must not escape",
        "details": {"token": "provider-secret"},
    }
    with (
        patch("api.routers.publish.get_status_service", return_value=fake_service),
        patch("api.routers.publish.require_owned_content_record", AsyncMock(return_value=fake_record)),
        patch("api.routers.publish.require_active_publish_account", AsyncMock(return_value=_authorized_account())),
        patch(
            "api.routers.publish.httpx.AsyncClient",
            return_value=_FakeAsyncClient(provider_response),
        ),
    ):
        response = client.post(
            "/api/publish",
            json={
                "content": "Rejected",
                "platforms": [{"platform": "PLAT_X", "account_id": "acct_1"}],
                "content_record_id": "content_1",
            },
        )

    assert response.status_code == 502
    assert response.json()["detail"] == {
        "type": "provider_error",
        "code": "invalid_media",
        "param": None,
        "message": "The publish provider rejected the request.",
    }
    publish_meta = fake_service.update_content.call_args_list[-1].kwargs["metadata"]["publish"]
    assert publish_meta["status"] == "failed"
    assert publish_meta["errors"] == [{"type": "provider_error", "code": "invalid_media"}]
    assert "provider-secret" not in str(publish_meta)
    assert "secret provider body" not in str(publish_meta)
