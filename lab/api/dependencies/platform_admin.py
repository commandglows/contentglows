"""Fail-closed FastAPI dependencies for platform capabilities."""

from __future__ import annotations

import asyncio
import os
from collections.abc import Awaitable, Callable

from fastapi import Depends, HTTPException, status

from api.dependencies.auth import CurrentUser, require_current_user
from api.models.platform_admin import (
    AuthorizedPlatformAdmin,
    PlatformAdminCapability,
)
from api.services.libsql_platform_admin_store import LibsqlPlatformAdminStore
from api.services.platform_admin_store import PlatformAdminStore
from utils.libsql_async import create_client


PlatformAdminStoreProvider = Callable[[], Awaitable[PlatformAdminStore]]

_store: PlatformAdminStore | None = None
_store_lock: asyncio.Lock | None = None


def _lock() -> asyncio.Lock:
    global _store_lock
    if _store_lock is None:
        _store_lock = asyncio.Lock()
    return _store_lock


async def get_platform_admin_store() -> PlatformAdminStore:
    global _store
    if _store is not None:
        return _store
    async with _lock():
        if _store is not None:
            return _store
        database_url = os.getenv("TURSO_DATABASE_URL")
        auth_token = os.getenv("TURSO_AUTH_TOKEN")
        if not database_url or not auth_token:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Platform authorization is unavailable.",
            )
        store = LibsqlPlatformAdminStore(
            db_client=create_client(url=database_url, auth_token=auth_token)
        )
        try:
            await store.ensure_schema()
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Platform authorization is unavailable.",
            ) from exc
        _store = store
        return store


def get_platform_admin_store_provider() -> PlatformAdminStoreProvider:
    return get_platform_admin_store


async def authorize_platform_capability(
    *,
    capability: PlatformAdminCapability,
    current_user: CurrentUser,
    store_provider: PlatformAdminStoreProvider,
) -> AuthorizedPlatformAdmin:
    try:
        store = await store_provider()
        grant = await store.get_grant_by_user(current_user.user_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Platform authorization is unavailable.",
        ) from exc
    if (
        grant is None
        or grant.user_id != current_user.user_id
        or not grant.allows(capability)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform admin access denied.",
        )
    return AuthorizedPlatformAdmin(
        actor_user_id=current_user.user_id,
        grant_id=grant.grant_id,
        grant_version=grant.version,
        capability=capability,
    )


def require_platform_capability(capability: PlatformAdminCapability):
    async def dependency(
        current_user: CurrentUser = Depends(require_current_user),
        store_provider: PlatformAdminStoreProvider = Depends(
            get_platform_admin_store_provider
        ),
    ) -> AuthorizedPlatformAdmin:
        return await authorize_platform_capability(
            capability=capability,
            current_user=current_user,
            store_provider=store_provider,
        )

    return dependency


def require_distinct_admin_target(
    admin: AuthorizedPlatformAdmin,
    *,
    target_user_id: str,
) -> None:
    if admin.actor_user_id == target_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform admin access denied.",
        )
