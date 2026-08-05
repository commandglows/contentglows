from __future__ import annotations

from datetime import datetime, timezone

import pytest

from api.services.media_delivery import (
    DeliveryContext,
    FakeMediaDeliveryProvider,
    MediaDeliveryError,
    S3PresignedMediaDeliveryProvider,
)
from api.services.object_storage import StorageLocator


def _locator() -> StorageLocator:
    return StorageLocator(
        provider="s3",
        namespace="assets",
        object_key="contentglows/assets/private-object",
        version="version-secret",
        checksum_sha256="c" * 64,
    )


class RecordingPresignClient:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    def generate_presigned_url(self, operation, Params, ExpiresIn, HttpMethod=None):
        self.calls.append(
            {
                "operation": operation,
                "Params": Params,
                "ExpiresIn": ExpiresIn,
                "HttpMethod": HttpMethod,
            }
        )
        return "https://delivery.example/object?signature=private-token"


def test_s3_delivery_authorizes_before_issuing_short_lived_url() -> None:
    client = RecordingPresignClient()
    authorized: list[tuple[DeliveryContext, StorageLocator]] = []

    def authorizer(context: DeliveryContext, locator: StorageLocator) -> bool:
        authorized.append((context, locator))
        return context.project_id == "project-owned"

    provider = S3PresignedMediaDeliveryProvider(
        client=client,
        bucket="private-bucket",
        authorizer=authorizer,
        clock=lambda: datetime(2026, 7, 13, tzinfo=timezone.utc),
        max_ttl_seconds=300,
    )
    context = DeliveryContext(actor_id="user-1", project_id="project-owned", asset_id="asset-1")

    delivery = provider.issue_get(locator=_locator(), context=context, expires_in=120)

    assert authorized
    assert delivery.url.startswith("https://delivery.example/")
    assert "private-token" not in repr(delivery)
    assert client.calls[0]["operation"] == "get_object"
    assert client.calls[0]["ExpiresIn"] == 120
    assert client.calls[0]["Params"]["VersionId"] == "version-secret"


def test_delivery_denies_without_presigning_and_redacts_locator() -> None:
    client = RecordingPresignClient()
    provider = S3PresignedMediaDeliveryProvider(
        client=client,
        bucket="private-bucket",
        authorizer=lambda _context, _locator: False,
    )

    with pytest.raises(MediaDeliveryError) as exc_info:
        provider.issue_get(
            locator=_locator(),
            context=DeliveryContext(actor_id="attacker", project_id="other", asset_id="asset-1"),
            expires_in=60,
        )

    assert exc_info.value.code == "delivery_forbidden"
    assert client.calls == []
    assert "private-object" not in str(exc_info.value)
    assert "private-bucket" not in str(exc_info.value)


@pytest.mark.parametrize("expires_in", [0, 301, 3600])
def test_delivery_ttl_is_bounded(expires_in: int) -> None:
    provider = S3PresignedMediaDeliveryProvider(
        client=RecordingPresignClient(),
        bucket="private-bucket",
        authorizer=lambda _context, _locator: True,
        max_ttl_seconds=300,
    )

    with pytest.raises(MediaDeliveryError) as exc_info:
        provider.issue_get(
            locator=_locator(),
            context=DeliveryContext(actor_id="user", project_id="project", asset_id="asset"),
            expires_in=expires_in,
        )
    assert exc_info.value.code == "invalid_delivery_ttl"


def test_fake_delivery_is_deterministic_and_still_requires_authorization() -> None:
    context = DeliveryContext(actor_id="user", project_id="project", asset_id="asset")
    provider = FakeMediaDeliveryProvider(
        authorizer=lambda candidate, _locator: candidate == context,
        clock=lambda: datetime(2026, 7, 13, tzinfo=timezone.utc),
    )

    first = provider.issue_get(locator=_locator(), context=context, expires_in=60)
    second = provider.issue_get(locator=_locator(), context=context, expires_in=60)

    assert first.url.endswith("/delivery-0001?token=redacted-test-token-0001")
    assert second.url.endswith("/delivery-0002?token=redacted-test-token-0002")
