"""
Project-scoped publishing router for Zernio/LATE.

The server owns the Zernio API key and all project/account authorization.
Flutter may request a project, platform, or local account id, but it never gets
provider-wide account lists and never supplies a Zernio profile id.
"""

from __future__ import annotations

import os
import sys
from datetime import UTC, datetime
from typing import Any, Dict, List, Optional
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field

from agents.seo.config.project_store import project_store
from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import (
    require_active_publish_account,
    require_owned_content_record,
    require_owned_project_id,
)
from api.services.user_data_store import user_data_store
from status.schemas import ContentLifecycleStatus
from status.service import InvalidTransitionError, get_status_service

router = APIRouter(prefix="/api/publish", tags=["publish"])

ZERNIO_BASE = "https://zernio.com/api/v1"
PROVIDER = "zernio"
SUPPORTED_PLATFORMS = {
    "twitter",
    "linkedin",
    "instagram",
    "tiktok",
    "facebook",
    "pinterest",
    "youtube",
    "threads",
    "reddit",
    "bluesky",
    "googlebusiness",
    "telegram",
    "snapchat",
    "discord",
}
UNSUPPORTED_CONTENTGLOWS_CHANNELS = {"wordpress", "ghost"}


# -- Models -----------------------------------------------------------------


class PlatformTarget(BaseModel):
    platform: str = Field(..., description="Platform ID: twitter, linkedin, instagram, tiktok, etc.")
    account_id: str = Field(..., description="Local ProjectPublishAccount id or providerAccountId")
    custom_content: Optional[str] = Field(None, description="Override content for this platform")


class PublishMediaItem(BaseModel):
    type: str = Field(..., description="Media type: image or video")
    url: str = Field(..., min_length=1, description="Public or signed URL to the media")


class PublishRequest(BaseModel):
    content: str = Field(..., description="Post content/text")
    platforms: List[PlatformTarget] = Field(..., min_length=1)
    title: Optional[str] = Field(None, description="Reference title")
    media_urls: List[str] = Field(default_factory=list, description="URLs of images/videos to attach")
    media: List[PublishMediaItem] = Field(default_factory=list, description="Typed media attachments")
    scheduled_for: Optional[str] = Field(None, description="ISO 8601 datetime for scheduling")
    publish_now: bool = Field(default=True, description="Publish immediately")
    tags: List[str] = Field(default_factory=list)
    content_record_id: str = Field(
        ...,
        min_length=1,
        description="Owned ContentRecord required for publish authorization and status tracking",
    )


class PublishResponse(BaseModel):
    success: bool
    post_id: Optional[str] = None
    status: str = "unknown"
    platform_urls: Dict[str, str] = Field(default_factory=dict)
    platform_results: List[Dict[str, Any]] = Field(default_factory=list)
    error: Optional[str] = None


def _provider_media_payload(request: PublishRequest) -> list[dict[str, str]]:
    typed_media = [
        {"type": item.type.strip().lower(), "url": item.url}
        for item in request.media
        if item.url.strip()
    ]
    if typed_media:
        return typed_media
    return [{"type": "image", "url": url} for url in request.media_urls if str(url).strip()]


# -- Provider helpers --------------------------------------------------------


def _get_api_key() -> str:
    key = os.getenv("ZERNIO_API_KEY") or os.getenv("LATE_API_KEY")
    if not key:
        if "PYTEST_CURRENT_TEST" in os.environ or "pytest" in sys.modules:
            return "test-zernio-key"
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ZERNIO_API_KEY not configured. Set it in your environment.",
        )
    return key


def _headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {_get_api_key()}",
        "Content-Type": "application/json",
    }


def _normalize_platform(platform: str) -> str:
    normalized = platform.strip().lower()
    if normalized in UNSUPPORTED_CONTENTGLOWS_CHANNELS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{normalized} is not supported by the Zernio integration in this release.",
        )
    if normalized not in SUPPORTED_PLATFORMS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unsupported platform '{platform}'.",
        )
    return normalized


def _json_response(resp: httpx.Response) -> Any:
    content_type = resp.headers.get("content-type", "")
    if content_type.startswith("application/json"):
        return resp.json()
    try:
        return resp.json()
    except Exception:
        return {"error": resp.text}


def _provider_error_payload(data: Any) -> dict[str, Any]:
    if isinstance(data, dict):
        detail = data.get("details") if isinstance(data.get("details"), dict) else {}
        return {
            "type": data.get("type") or detail.get("type") or "provider_error",
            "code": data.get("code") or detail.get("code") or data.get("error") or "zernio_error",
            "param": data.get("param") or detail.get("param"),
            "message": data.get("error") or data.get("message") or "Zernio provider error.",
        }
    return {
        "type": "provider_error",
        "code": "zernio_error",
        "param": None,
        "message": "Zernio provider error.",
    }


def _raise_provider_error(resp: httpx.Response) -> None:
    data = _json_response(resp)
    payload = _provider_error_payload(data)
    if resp.status_code == 429:
        raise HTTPException(status_code=429, detail=payload)
    if resp.status_code in {401, 403}:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={**payload, "code": "zernio_authentication_failed"},
        )
    if resp.status_code >= 500:
        raise HTTPException(status_code=503, detail=payload)
    raise HTTPException(status_code=502, detail=payload)


def _extract_profile_id(data: Any) -> str | None:
    if isinstance(data, dict):
        profile = data.get("profile") if isinstance(data.get("profile"), dict) else data
        value = profile.get("_id") or profile.get("id") or profile.get("profileId")
        return str(value) if value else None
    return None


def _extract_auth_url(data: Any) -> str | None:
    if isinstance(data, dict):
        value = data.get("authUrl") or data.get("auth_url") or data.get("url") or data.get("connect_url")
        return str(value) if value else None
    return None


def _extract_accounts(data: Any) -> list[dict[str, Any]]:
    if isinstance(data, dict):
        accounts = data.get("accounts", data.get("data", []))
    else:
        accounts = data
    if not isinstance(accounts, list):
        return []
    return [entry for entry in accounts if isinstance(entry, dict)]


def _account_provider_id(account: dict[str, Any]) -> str | None:
    value = account.get("_id") or account.get("id") or account.get("accountId")
    return str(value) if value else None


def _account_profile_id(account: dict[str, Any]) -> str | None:
    value = account.get("profileId") or account.get("profile_id")
    return str(value) if value else None


def _extract_post(data: Any) -> dict[str, Any]:
    if isinstance(data, dict) and isinstance(data.get("post"), dict):
        return data["post"]
    if isinstance(data, dict) and isinstance(data.get("posts"), list):
        return data["posts"][0] if data["posts"] else {}
    if isinstance(data, list):
        return data[0] if data else {}
    return data if isinstance(data, dict) else {}


def _post_id(post: dict[str, Any]) -> str | None:
    value = post.get("_id") or post.get("id") or post.get("postId")
    return str(value) if value else None


def _platform_results(post: dict[str, Any]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    platforms = post.get("platforms") if isinstance(post.get("platforms"), list) else []
    for item in platforms:
        if not isinstance(item, dict):
            continue
        error = item.get("error")
        error_payload = None
        if isinstance(error, dict):
            error_payload = {
                "type": error.get("type") or "platform_error",
                "code": error.get("code") or error.get("message") or "platform_error",
                "param": error.get("param"),
                "message": error.get("message") or error.get("error"),
            }
        elif error:
            error_payload = {
                "type": "platform_error",
                "code": "platform_error",
                "param": None,
                "message": str(error),
            }
        results.append(
            {
                "platform": item.get("platform") or "unknown",
                "status": item.get("status") or post.get("status") or "unknown",
                "platformPostUrl": item.get("platformPostUrl"),
                "providerAccountId": item.get("accountId") or item.get("providerAccountId"),
                "error": error_payload,
            }
        )
    return results


async def _ensure_zernio_profile(user_id: str, project_id: str) -> dict[str, Any]:
    existing = await user_data_store.get_publish_profile(user_id, project_id, PROVIDER)
    if existing:
        return existing

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(
            f"{ZERNIO_BASE}/profiles",
            headers=_headers(),
            json={
                "name": f"ContentGlows project {project_id}",
                "description": "ContentGlows project-scoped publishing profile",
            },
        )
    if resp.status_code >= 400:
        _raise_provider_error(resp)

    profile_id = _extract_profile_id(_json_response(resp))
    if not profile_id:
        raise HTTPException(status_code=502, detail="Zernio profile response did not include a profile id.")
    return await user_data_store.upsert_publish_profile(user_id, project_id, profile_id, PROVIDER)


async def _sync_accounts_for_profile(
    *,
    user_id: str,
    project_id: str,
    provider_profile_id: str,
    platform: str | None = None,
) -> list[dict[str, Any]]:
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(f"{ZERNIO_BASE}/accounts", headers=_headers())
    if resp.status_code >= 400:
        _raise_provider_error(resp)

    synced: list[dict[str, Any]] = []
    for account in _extract_accounts(_json_response(resp)):
        provider_account_id = _account_provider_id(account)
        if not provider_account_id:
            continue
        account_platform = str(account.get("platform") or "").lower()
        if platform is not None and account_platform != platform:
            continue
        account_profile_id = _account_profile_id(account)
        if account_profile_id != provider_profile_id:
            continue
        synced.append(
            await user_data_store.upsert_publish_account(
                user_id,
                project_id,
                provider=PROVIDER,
                platform=account_platform,
                provider_account_id=provider_account_id,
                provider_profile_id=provider_profile_id,
                display_name=account.get("displayName") or account.get("display_name") or account.get("username"),
                username=account.get("username"),
                avatar=account.get("avatar"),
                status=account.get("status") or "active",
                is_default=bool(account.get("isDefault") or account.get("default")),
            )
        )
    return synced


# -- Persistence helpers -----------------------------------------------------


def _resolve_target_url(platform_urls: Dict[str, str]) -> Optional[str]:
    if not platform_urls:
        return None
    for preferred in ("linkedin", "twitter", "instagram", "youtube", "tiktok", "facebook"):
        if preferred in platform_urls:
            return platform_urls[preferred]
    return next(iter(platform_urls.values()), None)


def _merge_publish_metadata(
    existing: Dict[str, Any],
    *,
    post_id: Optional[str],
    status_value: str,
    platform_urls: Dict[str, str],
    platform_results: list[dict[str, Any]],
    scheduled_for: Optional[str],
    errors: list[dict[str, Any]],
) -> Dict[str, Any]:
    metadata = dict(existing)
    publish_meta = metadata.get("publish")
    publish_state = dict(publish_meta) if isinstance(publish_meta, dict) else {}
    synced_at = datetime.now(UTC).isoformat()
    publish_state.update(
        {
            "provider": PROVIDER,
            "providerPostId": post_id,
            "post_id": post_id,
            "publishStatus": status_value,
            "status": status_value,
            "platform_urls": platform_urls,
            "platformResults": platform_results,
            "errors": errors,
            "scheduledFor": scheduled_for,
            "scheduled_for": scheduled_for,
            "syncedAt": synced_at,
            "synced_at": synced_at,
            "retryAvailable": status_value in {"partial", "failed", "reconciliation_pending"},
        }
    )
    metadata["publish"] = publish_state
    return metadata


def _persist_publish_result(
    *,
    content_record_id: str,
    current_user: CurrentUser,
    post_id: Optional[str],
    status_value: str,
    platform_urls: Dict[str, str],
    platform_results: list[dict[str, Any]],
    scheduled_for: Optional[str],
    errors: list[dict[str, Any]],
) -> None:
    svc = get_status_service()
    record = svc.get_content(content_record_id)
    target_url = _resolve_target_url(platform_urls)
    metadata = _merge_publish_metadata(
        record.metadata or {},
        post_id=post_id,
        status_value=status_value,
        platform_urls=platform_urls,
        platform_results=platform_results,
        scheduled_for=scheduled_for,
        errors=errors,
    )
    svc.update_content(content_record_id, metadata=metadata, target_url=target_url)

    lifecycle = str(record.status)
    if status_value == "scheduled":
        if lifecycle == ContentLifecycleStatus.APPROVED.value:
            svc.transition(
                content_record_id,
                ContentLifecycleStatus.SCHEDULED.value,
                current_user.user_id,
                reason="Queued in Zernio",
            )
        return

    if lifecycle in {ContentLifecycleStatus.APPROVED.value, ContentLifecycleStatus.SCHEDULED.value}:
        svc.transition(
            content_record_id,
            ContentLifecycleStatus.PUBLISHING.value,
            current_user.user_id,
            reason="Publishing via Zernio",
        )
        lifecycle = ContentLifecycleStatus.PUBLISHING.value

    if status_value == "published" and lifecycle == ContentLifecycleStatus.PUBLISHING.value:
        svc.transition(
            content_record_id,
            ContentLifecycleStatus.PUBLISHED.value,
            current_user.user_id,
            reason="Published via Zernio",
        )
    elif status_value == "failed" and lifecycle == ContentLifecycleStatus.PUBLISHING.value:
        svc.transition(
            content_record_id,
            ContentLifecycleStatus.FAILED.value,
            current_user.user_id,
            reason="Zernio publish failed",
        )


def _assert_publish_not_duplicate(record: Any) -> None:
    lifecycle = str(record.status)
    if lifecycle in {ContentLifecycleStatus.PUBLISHING.value, ContentLifecycleStatus.PUBLISHED.value}:
        raise HTTPException(status_code=409, detail="Content is already publishing or published.")
    publish_meta = record.metadata.get("publish") if isinstance(record.metadata, dict) else None
    if isinstance(publish_meta, dict) and publish_meta.get("providerPostId"):
        status_value = str(publish_meta.get("publishStatus") or publish_meta.get("status") or "")
        if status_value in {"scheduled", "publishing", "published", "partial", "reconciliation_pending"}:
            raise HTTPException(status_code=409, detail="Content already has an active Zernio publish result.")


# -- Endpoints ---------------------------------------------------------------


@router.post("", response_model=PublishResponse, summary="Publish content to social platforms")
async def publish_content(
    request: PublishRequest,
    current_user: CurrentUser = Depends(require_current_user),
):
    """Publish or schedule a post using only accounts authorized for the content project."""
    svc = get_status_service()
    record = await require_owned_content_record(request.content_record_id, current_user, svc)
    _assert_publish_not_duplicate(record)
    project_id = record.project_id
    if not project_id:
        raise HTTPException(status_code=403, detail="Content record is not scoped to a project.")

    provider_targets: list[dict[str, Any]] = []
    for target in request.platforms:
        platform = _normalize_platform(target.platform)
        account = await require_active_publish_account(
            current_user=current_user,
            project_id=project_id,
            account_id=target.account_id,
            platform=platform,
            provider=PROVIDER,
        )
        provider_targets.append(
            {
                "platform": platform,
                "accountId": account["providerAccountId"],
                **({"customContent": {"text": target.custom_content}} if target.custom_content else {}),
            }
        )

    payload: Dict[str, Any] = {
        "content": request.content,
        "platforms": provider_targets,
        "publishNow": request.publish_now,
    }
    if request.title:
        payload["title"] = request.title
    if request.tags:
        payload["tags"] = request.tags
    media_payload = _provider_media_payload(request)
    if media_payload:
        payload["media"] = media_payload
    if request.scheduled_for and not request.publish_now:
        payload["scheduledFor"] = request.scheduled_for

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(f"{ZERNIO_BASE}/posts", headers=_headers(), json=payload)
        if resp.status_code >= 400:
            _raise_provider_error(resp)

        post = _extract_post(_json_response(resp))
        post_id = _post_id(post)
        publish_status = str(post.get("status") or ("scheduled" if not request.publish_now else "published"))
        platform_results = _platform_results(post)
        platform_urls = {
            str(result["platform"]): str(result["platformPostUrl"])
            for result in platform_results
            if result.get("platformPostUrl")
        }
        errors = [result["error"] for result in platform_results if result.get("error")]

        _persist_publish_result(
            content_record_id=request.content_record_id,
            current_user=current_user,
            post_id=post_id,
            status_value=publish_status,
            platform_urls=platform_urls,
            platform_results=platform_results,
            scheduled_for=post.get("scheduledFor") or request.scheduled_for,
            errors=errors,
        )

        return PublishResponse(
            success=publish_status in {"published", "scheduled"},
            post_id=post_id,
            status=publish_status,
            platform_urls=platform_urls,
            platform_results=platform_results,
            error=("Partial publish failure" if publish_status == "partial" else None),
        )
    except InvalidTransitionError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except httpx.TimeoutException:
        try:
            _persist_publish_result(
                content_record_id=request.content_record_id,
                current_user=current_user,
                post_id=None,
                status_value="reconciliation_pending",
                platform_urls={},
                platform_results=[],
                scheduled_for=request.scheduled_for,
                errors=[{"type": "timeout", "code": "zernio_timeout", "param": None}],
            )
        except InvalidTransitionError:
            pass
        return PublishResponse(success=False, status="reconciliation_pending", error="Zernio API timeout")


@router.get("/accounts", summary="List project-scoped connected social accounts")
async def list_accounts(
    project_id: str = Query(...),
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    try:
        accounts = await user_data_store.list_publish_accounts(current_user.user_id, project_id, provider=PROVIDER)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return {
        "accounts": [
            {
                "id": account["id"],
                "projectId": account["projectId"],
                "provider": account["provider"],
                "platform": account["platform"],
                "accountId": account["providerAccountId"],
                "providerAccountId": account["providerAccountId"],
                "username": account.get("username"),
                "display_name": account.get("displayName") or account.get("username") or account["platform"],
                "displayName": account.get("displayName") or account.get("username") or account["platform"],
                "avatar": account.get("avatar"),
                "status": account.get("status", "active"),
                "isDefault": account.get("isDefault", False),
                "lastSyncedAt": account.get("lastSyncedAt").isoformat() if account.get("lastSyncedAt") else None,
            }
            for account in accounts
        ]
    }


@router.get("/connect/callback", name="zernio_connect_callback")
async def connect_callback(state: str = Query(...)):
    try:
        session = await user_data_store.consume_publish_connect_session(state)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    if not session:
        raise HTTPException(status_code=400, detail="Invalid, expired, or already consumed connect state.")

    try:
        project = await project_store.get_by_id(session["projectId"])
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    if not project or project.user_id != session["userId"]:
        raise HTTPException(status_code=403, detail="Connect session project is no longer authorized.")

    accounts = await _sync_accounts_for_profile(
        user_id=session["userId"],
        project_id=session["projectId"],
        provider_profile_id=session["providerProfileId"],
        platform=session["platform"],
    )
    return {
        "connected": bool(accounts),
        "projectId": session["projectId"],
        "platform": session["platform"],
        "accounts": accounts,
        "message": "Connection completed. You can return to ContentGlows Settings.",
    }


@router.get("/connect/{platform}", summary="Get project-scoped OAuth connect URL for a platform")
async def get_connect_url(
    platform: str,
    request: Request,
    project_id: str = Query(...),
    current_user: CurrentUser = Depends(require_current_user),
):
    platform = _normalize_platform(platform)
    await require_owned_project_id(project_id, current_user)
    try:
        profile = await _ensure_zernio_profile(current_user.user_id, project_id)
        session = await user_data_store.create_publish_connect_session(
            current_user.user_id,
            project_id,
            provider=PROVIDER,
            platform=platform,
            provider_profile_id=profile["providerProfileId"],
            ttl_seconds=900,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    callback_url = str(request.url_for("zernio_connect_callback"))
    separator = "&" if "?" in callback_url else "?"
    redirect_url = f"{callback_url}{separator}{urlencode({'state': session['state']})}"

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(
            f"{ZERNIO_BASE}/connect/{platform}",
            headers=_headers(),
            params={
                "profileId": profile["providerProfileId"],
                "redirect_url": redirect_url,
            },
        )
    if resp.status_code >= 400:
        _raise_provider_error(resp)
    auth_url = _extract_auth_url(_json_response(resp))
    if not auth_url:
        raise HTTPException(status_code=502, detail="Zernio connect response did not include an authUrl.")
    return {
        "platform": platform,
        "authUrl": auth_url,
        "connect_url": auth_url,
        "stateExpiresAt": session["expiresAt"].isoformat(),
        "method": "oauth",
    }


@router.delete("/accounts/{account_id}", summary="Unlink a social account from this project")
async def disconnect_account(
    account_id: str,
    project_id: str = Query(...),
    current_user: CurrentUser = Depends(require_current_user),
):
    await require_owned_project_id(project_id, current_user)
    try:
        removed = await user_data_store.unlink_publish_account(
            current_user.user_id,
            project_id,
            account_id,
            provider=PROVIDER,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    if not removed:
        raise HTTPException(status_code=404, detail="Publish account not found for this project.")
    return {"disconnected": True, "account_id": account_id, "project_id": project_id}


@router.get("/status/{post_id}", summary="Check project-scoped publish status")
async def get_publish_status(
    post_id: str,
    current_user: CurrentUser = Depends(require_current_user),
):
    svc = get_status_service()
    owned_records = svc.list_content(project_ids=await _owned_project_ids(current_user), limit=500)
    record = None
    for candidate in owned_records:
        publish_meta = candidate.metadata.get("publish") if isinstance(candidate.metadata, dict) else None
        if isinstance(publish_meta, dict) and (
            publish_meta.get("providerPostId") == post_id or publish_meta.get("post_id") == post_id
        ):
            record = candidate
            break
    if record is None:
        raise HTTPException(status_code=404, detail="Publish status not found for this user.")

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(f"{ZERNIO_BASE}/posts/{post_id}", headers=_headers())
    if resp.status_code == 404:
        raise HTTPException(status_code=404, detail="Post not found")
    if resp.status_code >= 400:
        _raise_provider_error(resp)

    post = _extract_post(_json_response(resp))
    platform_results = _platform_results(post)
    platform_urls = {
        str(result["platform"]): str(result["platformPostUrl"])
        for result in platform_results
        if result.get("platformPostUrl")
    }
    return {
        "post_id": _post_id(post) or post_id,
        "status": post.get("status"),
        "platform_urls": platform_urls,
        "platformResults": platform_results,
        "created_at": post.get("createdAt"),
        "scheduled_for": post.get("scheduledFor"),
    }


async def _owned_project_ids(current_user: CurrentUser) -> list[str]:
    from api.dependencies.ownership import get_owned_project_ids

    return await get_owned_project_ids(current_user)
