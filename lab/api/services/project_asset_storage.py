"""Storage descriptor helpers for project asset API responses.

These helpers only classify and redact persisted metadata. They do not upload,
delete, sign, or verify remote objects.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any, Dict, Optional
import os
from urllib.parse import urlsplit, urlunsplit

if TYPE_CHECKING:
    from status.schemas import StorageLocator


class ProjectAssetDeliveryError(ValueError):
    """Raised when persisted storage cannot yield a safe provider media URL."""


def build_project_asset_storage_descriptor(
    *,
    storage_uri: Optional[str],
    storage_locator: Optional["StorageLocator"] = None,
    status: str,
    media_kind: str,
    mime_type: Optional[str],
) -> Dict[str, Any]:
    """Return a client-safe storage descriptor for a project asset."""

    if storage_locator is not None:
        return _descriptor(
            state=f"durable_{storage_locator.provider}",
            provider=storage_locator.provider,
            media_kind=media_kind,
            mime_type=mime_type,
            render_safe=True,
            refresh_required=False,
        )

    if status == "local_only":
        return _descriptor(
            state="local_only",
            media_kind=media_kind,
            mime_type=mime_type,
            render_safe=False,
            refresh_required=False,
        )

    if not storage_uri:
        return _descriptor(
            state="missing",
            media_kind=media_kind,
            mime_type=mime_type,
            render_safe=False,
            refresh_required=True,
        )

    parsed = urlsplit(storage_uri)
    scheme = parsed.scheme.lower()
    host = (parsed.netloc or "").lower()

    if scheme == "bunny":
        return _descriptor(
            state="durable_bunny",
            media_kind=media_kind,
            mime_type=mime_type,
            redacted_uri="bunny://<redacted>",
            render_safe=True,
            refresh_required=False,
        )

    if scheme in {"http", "https"}:
        redacted_uri = urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))
        if _looks_like_bunny_host(host):
            return _descriptor(
                state="durable_bunny_http",
                media_kind=media_kind,
                mime_type=mime_type,
                redacted_uri=redacted_uri,
                render_safe=True,
                refresh_required=bool(parsed.query),
            )
        return _descriptor(
            state="provider_temporary",
            media_kind=media_kind,
            mime_type=mime_type,
            redacted_uri=redacted_uri,
            render_safe=False,
            refresh_required=True,
        )

    return _descriptor(
        state="unsupported_uri",
        media_kind=media_kind,
        mime_type=mime_type,
        render_safe=False,
        refresh_required=True,
    )


def _looks_like_bunny_host(host: str) -> bool:
    return (
        host.endswith(".b-cdn.net")
        or host.endswith(".bunnycdn.com")
        or host == "storage.bunnycdn.com"
    )


def resolve_project_asset_delivery_url(
    storage_uri: Optional[str], storage_locator: Optional["StorageLocator"] = None
) -> str:
    """Resolve only durable Bunny storage to a query-free HTTPS delivery URL."""

    if storage_locator is not None and storage_locator.provider.lower() == "bunny":
        configured = (os.getenv("BUNNY_CDN_HOSTNAME") or "").strip()
        configured_parsed = urlsplit(
            configured if "://" in configured else f"//{configured}"
        )
        hostname = (configured_parsed.netloc or configured_parsed.path).strip("/")
        path = storage_locator.object_key.lstrip("/")
        if hostname and path:
            return f"https://{hostname}/{path}"
        raise ProjectAssetDeliveryError("Bunny asset delivery path is incomplete")

    if not isinstance(storage_uri, str) or not storage_uri.strip():
        raise ProjectAssetDeliveryError("Asset storage is missing")

    parsed = urlsplit(storage_uri.strip())
    scheme = parsed.scheme.lower()
    if scheme == "bunny":
        configured = (os.getenv("BUNNY_CDN_HOSTNAME") or "").strip()
        if not configured:
            raise ProjectAssetDeliveryError("Bunny CDN hostname is not configured")
        configured_parsed = urlsplit(
            configured if "://" in configured else f"//{configured}"
        )
        hostname = (configured_parsed.netloc or configured_parsed.path).strip("/")
        path = parsed.path.lstrip("/")
        if not hostname or not path:
            raise ProjectAssetDeliveryError("Bunny asset delivery path is incomplete")
        return f"https://{hostname}/{path}"

    if scheme in {"http", "https"} and _looks_like_bunny_host(parsed.netloc.lower()):
        return urlunsplit(("https", parsed.netloc, parsed.path, "", ""))

    raise ProjectAssetDeliveryError("Asset storage is not durable Bunny media")


def _descriptor(
    *,
    state: str,
    media_kind: str,
    mime_type: Optional[str],
    redacted_uri: Optional[str] = None,
    provider: Optional[str] = None,
    render_safe: bool,
    refresh_required: bool,
) -> Dict[str, Any]:
    return {
        "state": state,
        "provider": provider,
        "media_kind": media_kind,
        "mime_type": mime_type,
        "redacted_uri": redacted_uri,
        "preview_url": None,
        "playback_url": None,
        "render_safe": render_safe,
        "refresh_required": refresh_required,
    }
