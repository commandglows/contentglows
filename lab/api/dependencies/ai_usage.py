"""Runtime composition for persistence-agnostic AI usage services."""

from __future__ import annotations

import asyncio
import json
import os
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

from fastapi import HTTPException

from api.services.ai_usage_policies import AIUsagePolicySet
from api.services.ai_usage_service import AIUsageService
from api.services.libsql_ai_usage_store import LibsqlAIUsageStore
from utils.libsql_async import create_client


@dataclass(frozen=True)
class AIUsageRuntime:
    service: AIUsageService
    policies: AIUsagePolicySet
    reservation_ttl_seconds: int


AIUsageRuntimeProvider = Callable[[], Awaitable[AIUsageRuntime]]


_runtime: AIUsageRuntime | None = None
_runtime_lock: asyncio.Lock | None = None


def _lock() -> asyncio.Lock:
    global _runtime_lock
    if _runtime_lock is None:
        _runtime_lock = asyncio.Lock()
    return _runtime_lock


async def get_ai_usage_runtime() -> AIUsageRuntime:
    """Build the concrete runtime at the API boundary from explicit config."""
    global _runtime
    if _runtime is not None:
        return _runtime
    async with _lock():
        if _runtime is not None:
            return _runtime
        database_url = os.getenv("TURSO_DATABASE_URL")
        auth_token = os.getenv("TURSO_AUTH_TOKEN")
        raw_policies = os.getenv("AI_USAGE_POLICIES_JSON")
        if not database_url or not auth_token or not raw_policies:
            raise HTTPException(
                status_code=503,
                detail="AI usage enforcement is not configured.",
            )
        try:
            policy_config = json.loads(raw_policies)
            if not isinstance(policy_config, list):
                raise ValueError("AI_USAGE_POLICIES_JSON must contain a list")
            policies = AIUsagePolicySet.from_config(policy_config)
            ttl_seconds = int(os.getenv("AI_USAGE_RESERVATION_TTL_SECONDS", "900"))
            if not 60 <= ttl_seconds <= 3600:
                raise ValueError("reservation TTL must be between 60 and 3600 seconds")
        except (TypeError, ValueError) as exc:
            raise HTTPException(
                status_code=503,
                detail="AI usage enforcement configuration is invalid.",
            ) from exc
        store = LibsqlAIUsageStore(
            db_client=create_client(url=database_url, auth_token=auth_token)
        )
        await store.ensure_tables()
        _runtime = AIUsageRuntime(
            service=AIUsageService(store=store),
            policies=policies,
            reservation_ttl_seconds=ttl_seconds,
        )
        return _runtime


def get_ai_usage_runtime_provider() -> AIUsageRuntimeProvider:
    """Inject a lazy provider so non-managed routes do not require quota config."""
    return get_ai_usage_runtime
