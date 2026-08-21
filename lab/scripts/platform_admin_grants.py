"""Explicitly activated operations entrypoint for platform grants.

This module is intentionally not imported by the API and exposes no HTTP route.
"""

from __future__ import annotations

import argparse
import asyncio
import os
from datetime import UTC, datetime, timedelta

from api.models.platform_admin import (
    PlatformAdminBootstrapAuthority,
    PlatformAdminCapability,
)
from api.services.libsql_platform_admin_store import LibsqlPlatformAdminStore
from api.services.platform_admin_operations import PlatformAdminGrantOperations
from utils.libsql_async import create_client


_MAX_WINDOW = timedelta(minutes=15)


def _authority_from_environment(
    *,
    actor_user_id: str,
    operation_id: str,
    now: datetime,
) -> PlatformAdminBootstrapAuthority:
    if os.getenv("CONTENTGLOWS_PLATFORM_ADMIN_OPERATIONS") != "enabled":
        raise RuntimeError("Platform admin operations are disabled.")
    configured_operation_id = os.getenv("PLATFORM_ADMIN_OPERATION_ID", "").strip()
    if not configured_operation_id or configured_operation_id != operation_id:
        raise RuntimeError("Platform admin operation id is not authorized.")
    actors = {
        value.strip()
        for value in os.getenv("PLATFORM_ADMIN_BOOTSTRAP_ACTOR_USER_IDS", "").split(",")
        if value.strip()
    }
    if actor_user_id not in actors:
        raise RuntimeError("Platform admin actor is not authorized.")
    raw_expiry = os.getenv("PLATFORM_ADMIN_OPERATION_EXPIRES_AT", "").strip()
    try:
        expires_at = datetime.fromisoformat(raw_expiry.replace("Z", "+00:00"))
    except ValueError as exc:
        raise RuntimeError("Platform admin operation expiry is invalid.") from exc
    if expires_at.tzinfo is None or expires_at.utcoffset() is None:
        raise RuntimeError("Platform admin operation expiry must include a timezone.")
    if expires_at <= now or expires_at > now + _MAX_WINDOW:
        raise RuntimeError("Platform admin operation window is not active.")
    return PlatformAdminBootstrapAuthority(
        actor_user_id=actor_user_id,
        operation_id=operation_id,
        issued_at=now,
        expires_at=expires_at,
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage bounded platform grants")
    parser.add_argument("action", choices=("grant", "revoke"))
    parser.add_argument("--actor-user-id", required=True)
    parser.add_argument("--target-user-id", required=True)
    parser.add_argument("--operation-id", required=True)
    parser.add_argument("--reason", required=True)
    parser.add_argument(
        "--capability",
        action="append",
        choices=[capability.value for capability in PlatformAdminCapability],
        default=[],
    )
    return parser


async def _run(args: argparse.Namespace) -> None:
    now = datetime.now(UTC)
    authority = _authority_from_environment(
        actor_user_id=args.actor_user_id,
        operation_id=args.operation_id,
        now=now,
    )
    database_url = os.getenv("TURSO_DATABASE_URL")
    auth_token = os.getenv("TURSO_AUTH_TOKEN")
    if not database_url or not auth_token:
        raise RuntimeError("Platform authorization storage is unavailable.")
    store = LibsqlPlatformAdminStore(
        db_client=create_client(url=database_url, auth_token=auth_token)
    )
    await store.ensure_schema()
    operations = PlatformAdminGrantOperations(store=store)
    if args.action == "grant":
        grant = await operations.grant(
            authority=authority,
            target_user_id=args.target_user_id,
            capabilities=[PlatformAdminCapability(value) for value in args.capability],
            reason=args.reason,
        )
    else:
        if args.capability:
            raise RuntimeError("Revoke does not accept capabilities.")
        grant = await operations.revoke(
            authority=authority,
            target_user_id=args.target_user_id,
            reason=args.reason,
        )
    print(f"Platform grant operation recorded: {grant.grant_id} v{grant.version}")


def main() -> None:
    asyncio.run(_run(_parser().parse_args()))


if __name__ == "__main__":
    main()
