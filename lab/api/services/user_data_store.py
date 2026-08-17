"""DB-backed store for authenticated user data migrated out of Next.js."""

from __future__ import annotations

import asyncio
import json
import os
import secrets
import string
import uuid
from datetime import datetime
from typing import Any

from api.services.crypto import get_crypto
from utils.libsql_async import create_client


def _ts(raw: Any) -> datetime:
    if isinstance(raw, datetime):
        return raw
    if isinstance(raw, (int, float)):
        return datetime.fromtimestamp(raw)
    if isinstance(raw, str):
        try:
            return datetime.fromisoformat(raw)
        except ValueError:
            return datetime.fromtimestamp(float(raw))
    return datetime.now()


def _json_load(raw: Any, fallback: Any) -> Any:
    if raw is None:
        return fallback
    if isinstance(raw, (dict, list)):
        return raw
    try:
        return json.loads(raw)
    except Exception:
        return fallback


def _json_dump(raw: Any) -> str | None:
    if raw is None:
        return None
    return json.dumps(raw)


def _deep_merge_dict(base: dict[str, Any], updates: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge dict updates while preserving unrelated keys."""
    merged = dict(base)
    for key, value in updates.items():
        if (
            key in merged
            and isinstance(merged[key], dict)
            and isinstance(value, dict)
        ):
            merged[key] = _deep_merge_dict(merged[key], value)
        else:
            merged[key] = value
    return merged


def _mask_api_keys(api_keys: dict[str, Any] | None) -> dict[str, Any] | None:
    if not api_keys:
        return None
    safe: dict[str, Any] = {}
    for key, value in api_keys.items():
        safe[key] = "••••••••" if value else None
    return safe


def _canonical_persona_payload(payload: dict[str, Any]) -> dict[str, Any]:
    """Normalize persona payload keys to snake_case for internal processing."""
    return {
        "project_id": payload.get("project_id", payload.get("projectId")),
        "name": payload.get("name"),
        "avatar": payload.get("avatar"),
        "demographics": payload.get("demographics"),
        "pain_points": payload.get("pain_points", payload.get("painPoints")),
        "goals": payload.get("goals"),
        "language": payload.get("language"),
        "content_preferences": payload.get(
            "content_preferences",
            payload.get("contentPreferences"),
        ),
        "confidence": payload.get("confidence"),
    }


class UserDataStore:
    """Small repository layer for user-owned app data."""

    def __init__(self) -> None:
        self.db_client = None
        self._oauth_state_lock = asyncio.Lock()
        if os.getenv("TURSO_DATABASE_URL") and os.getenv("TURSO_AUTH_TOKEN"):
            self.db_client = create_client(
                url=os.getenv("TURSO_DATABASE_URL"),
                auth_token=os.getenv("TURSO_AUTH_TOKEN"),
            )

    @staticmethod
    def _github_token_encryption_enabled() -> bool:
        return bool((os.getenv("USER_SECRETS_MASTER_KEY") or "").strip())

    def _require_github_token_encryption(self) -> None:
        if not self._github_token_encryption_enabled():
            raise RuntimeError(
                "USER_SECRETS_MASTER_KEY is required for GitHub integration operations."
            )

    @staticmethod
    def _looks_like_plaintext_github_token(token: str) -> bool:
        normalized = token.strip()
        if not normalized or any(ch.isspace() for ch in normalized):
            return False
        lowered = normalized.lower()
        if lowered.startswith(
            (
                "ghp_",
                "gho_",
                "ghu_",
                "ghs_",
                "ghr_",
                "github_pat_",
            )
        ):
            return True
        return len(normalized) == 40 and all(ch in string.hexdigits for ch in normalized)

    def _encrypt_github_token(self, token: str) -> str:
        if not token:
            return token
        self._require_github_token_encryption()
        return get_crypto().encrypt(token)

    def _decrypt_github_token(self, token: str) -> str:
        if not token:
            return token
        self._require_github_token_encryption()
        try:
            return get_crypto().decrypt(token)
        except RuntimeError:
            # Backward-compatibility for legacy plaintext rows.
            return token

    def _ensure_connected(self) -> None:
        if not self.db_client:
            raise RuntimeError(
                "Database not configured. Set TURSO_DATABASE_URL and TURSO_AUTH_TOKEN."
            )

    def _settings_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "theme": row[2],
            "language": row[3],
            "emailNotifications": bool(row[4]),
            "webhookUrl": row[5],
            "apiKeys": _mask_api_keys(_json_load(row[6], None)),
            "defaultProjectId": row[7],
            "projectSelectionMode": row[8] or "auto",
            "dashboardLayout": _json_load(row[9], None),
            "robotSettings": _json_load(row[10], None),
            "createdAt": _ts(row[11]),
            "updatedAt": _ts(row[12]),
        }

    def _creator_profile_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "projectId": row[2],
            "displayName": row[3],
            "voice": _json_load(row[4], None),
            "positioning": _json_load(row[5], None),
            "values": _json_load(row[6], []),
            "currentChapterId": row[7],
            "createdAt": _ts(row[8]),
            "updatedAt": _ts(row[9]),
        }

    def _persona_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "projectId": row[2],
            "name": row[3],
            "avatar": row[4],
            "demographics": _json_load(row[5], None),
            "painPoints": _json_load(row[6], []),
            "goals": _json_load(row[7], []),
            "language": _json_load(row[8], None),
            "contentPreferences": _json_load(row[9], None),
            "confidence": row[10] or 50,
            "createdAt": _ts(row[11]),
            "updatedAt": _ts(row[12]),
        }

    async def get_user_settings(self, user_id: str) -> dict[str, Any]:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, userId, theme, language, emailNotifications, webhookUrl,
                   apiKeys, defaultProjectId, projectSelectionMode, dashboardLayout, robotSettings,
                   createdAt, updatedAt
            FROM UserSettings
            WHERE userId = ?
            LIMIT 1
            """,
            [user_id],
        )
        if rs.rows:
            return self._settings_from_row(rs.rows[0])

        now = int(datetime.now().timestamp())
        settings_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO UserSettings (id, userId, theme, language, emailNotifications, projectSelectionMode, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [settings_id, user_id, "system", "en", True, "auto", now, now],
        )
        return await self.get_user_settings(user_id)

    async def update_user_settings(self, user_id: str, updates: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        current = await self.get_user_settings(user_id)
        update_fields: list[str] = ["updatedAt = ?"]
        params: list[Any] = [int(datetime.now().timestamp())]

        mapping = {
            "theme": "theme",
            "language": "language",
            "emailNotifications": "emailNotifications",
            "webhookUrl": "webhookUrl",
            "defaultProjectId": "defaultProjectId",
            "projectSelectionMode": "projectSelectionMode",
        }
        for key, column in mapping.items():
            if key in updates:
                update_fields.append(f"{column} = ?")
                params.append(updates[key])

        if "dashboardLayout" in updates:
            update_fields.append("dashboardLayout = ?")
            params.append(_json_dump(updates["dashboardLayout"]))

        if "robotSettings" in updates:
            incoming_robot_settings = updates["robotSettings"]
            if isinstance(incoming_robot_settings, dict):
                existing_robot_settings = current.get("robotSettings")
                if isinstance(existing_robot_settings, dict):
                    incoming_robot_settings = _deep_merge_dict(
                        existing_robot_settings,
                        incoming_robot_settings,
                    )
            update_fields.append("robotSettings = ?")
            params.append(_json_dump(incoming_robot_settings))

        params.append(user_id)
        await self.db_client.execute(
            f"UPDATE UserSettings SET {', '.join(update_fields)} WHERE userId = ?",
            params,
        )
        return await self.get_user_settings(user_id)

    async def get_effective_ai_runtime_mode(self, user_id: str) -> str:
        """Resolve persisted runtime mode, defaulting to BYOK."""
        settings = await self.get_user_settings(user_id)
        robot_settings = settings.get("robotSettings")
        if not isinstance(robot_settings, dict):
            return "byok"
        ai_runtime = robot_settings.get("aiRuntime")
        if not isinstance(ai_runtime, dict):
            return "byok"
        mode = ai_runtime.get("mode")
        if mode in {"byok", "platform"}:
            return mode
        return "byok"

    async def set_ai_runtime_mode(self, user_id: str, mode: str) -> dict[str, Any]:
        if mode not in {"byok", "platform"}:
            raise ValueError(f"Unsupported runtime mode '{mode}'")
        return await self.update_user_settings(
            user_id,
            {"robotSettings": {"aiRuntime": {"mode": mode}}},
        )

    async def ensure_user_settings_table(self) -> None:
        """Create UserSettings table if it doesn't exist (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS UserSettings (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL UNIQUE,
                theme TEXT NOT NULL DEFAULT 'system',
                language TEXT,
                emailNotifications INTEGER NOT NULL DEFAULT 1,
                webhookUrl TEXT,
                apiKeys TEXT,
                defaultProjectId TEXT,
                projectSelectionMode TEXT NOT NULL DEFAULT 'auto',
                dashboardLayout TEXT,
                robotSettings TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """
        )
        await self._ensure_user_settings_column(
            "projectSelectionMode",
            "TEXT NOT NULL DEFAULT 'auto'",
        )

    async def _ensure_user_settings_column(
        self,
        column_name: str,
        column_definition: str,
    ) -> None:
        rs = await self.db_client.execute("PRAGMA table_info(UserSettings)")
        existing = {
            row[1] for row in rs.rows if isinstance(row, (tuple, list)) and len(row) > 1
        }
        if column_name in existing:
            return
        await self.db_client.execute(
            f"ALTER TABLE UserSettings ADD COLUMN {column_name} {column_definition}"
        )

    async def ensure_creator_profile_table(self) -> None:
        """Create CreatorProfile table if it doesn't exist (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS CreatorProfile (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT,
                displayName TEXT,
                voice TEXT,
                positioning TEXT,
                "values" TEXT,
                currentChapterId TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """
        )

    async def ensure_customer_persona_table(self) -> None:
        """Create CustomerPersona table if it doesn't exist (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS CustomerPersona (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT,
                name TEXT NOT NULL,
                avatar TEXT,
                demographics TEXT,
                painPoints TEXT,
                goals TEXT,
                language TEXT,
                contentPreferences TEXT,
                confidence INTEGER NOT NULL DEFAULT 50,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """
        )

    async def ensure_github_integration_table(self) -> None:
        """Create table for encrypted GitHub token storage (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS UserGithubIntegration (
                userId TEXT PRIMARY KEY NOT NULL,
                token TEXT NOT NULL,
                githubUserId TEXT,
                githubUsername TEXT,
                scopes TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """
        )

    async def ensure_github_oauth_state_table(self) -> None:
        """Create table for temporary OAuth callback states (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS GithubOAuthState (
                state TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                expiresAt INTEGER NOT NULL,
                used INTEGER NOT NULL DEFAULT 0
            )
            """
        )

    async def ensure_publish_integration_tables(self) -> None:
        """Create project-scoped publish integration tables (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS ProjectPublishProfile (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT NOT NULL,
                provider TEXT NOT NULL,
                providerProfileId TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """
        )
        await self.db_client.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_publish_profile_scope
            ON ProjectPublishProfile(userId, projectId, provider)
            """
        )
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS ProjectPublishAccount (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT NOT NULL,
                provider TEXT NOT NULL,
                platform TEXT NOT NULL,
                providerAccountId TEXT NOT NULL,
                providerProfileId TEXT NOT NULL,
                displayName TEXT,
                username TEXT,
                avatar TEXT,
                status TEXT NOT NULL DEFAULT 'active',
                isDefault INTEGER NOT NULL DEFAULT 0,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                lastSyncedAt INTEGER
            )
            """
        )
        await self.db_client.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_publish_account_provider_scope
            ON ProjectPublishAccount(userId, projectId, provider, providerAccountId)
            """
        )
        await self.db_client.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_publish_account_project_platform
            ON ProjectPublishAccount(userId, projectId, provider, platform, status)
            """
        )
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS PublishConnectSession (
                state TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT NOT NULL,
                provider TEXT NOT NULL,
                platform TEXT NOT NULL,
                providerProfileId TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                expiresAt INTEGER NOT NULL,
                consumedAt INTEGER
            )
            """
        )
        await self.db_client.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_publish_connect_session_scope
            ON PublishConnectSession(userId, projectId, provider, platform, expiresAt)
            """
        )

    def _publish_account_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "projectId": row[2],
            "provider": row[3],
            "platform": row[4],
            "providerAccountId": row[5],
            "providerProfileId": row[6],
            "displayName": row[7],
            "username": row[8],
            "avatar": row[9],
            "status": row[10] or "active",
            "isDefault": bool(row[11]),
            "createdAt": _ts(row[12]),
            "updatedAt": _ts(row[13]),
            "lastSyncedAt": _ts(row[14]) if row[14] else None,
        }

    def _publish_profile_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "projectId": row[2],
            "provider": row[3],
            "providerProfileId": row[4],
            "createdAt": _ts(row[5]),
            "updatedAt": _ts(row[6]),
        }

    def _publish_session_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "state": row[0],
            "userId": row[1],
            "projectId": row[2],
            "provider": row[3],
            "platform": row[4],
            "providerProfileId": row[5],
            "createdAt": _ts(row[6]),
            "expiresAt": _ts(row[7]),
            "consumedAt": _ts(row[8]) if row[8] else None,
        }

    async def get_publish_profile(
        self,
        user_id: str,
        project_id: str,
        provider: str = "zernio",
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, userId, projectId, provider, providerProfileId, createdAt, updatedAt
            FROM ProjectPublishProfile
            WHERE userId = ? AND projectId = ? AND provider = ?
            LIMIT 1
            """,
            [user_id, project_id, provider],
        )
        if not rs.rows:
            return None
        return self._publish_profile_from_row(rs.rows[0])

    async def upsert_publish_profile(
        self,
        user_id: str,
        project_id: str,
        provider_profile_id: str,
        provider: str = "zernio",
    ) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        existing = await self.get_publish_profile(user_id, project_id, provider)
        if existing:
            await self.db_client.execute(
                """
                UPDATE ProjectPublishProfile
                SET providerProfileId = ?, updatedAt = ?
                WHERE id = ? AND userId = ?
                """,
                [provider_profile_id, now, existing["id"], user_id],
            )
        else:
            await self.db_client.execute(
                """
                INSERT INTO ProjectPublishProfile (
                    id, userId, projectId, provider, providerProfileId, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    str(uuid.uuid4()),
                    user_id,
                    project_id,
                    provider,
                    provider_profile_id,
                    now,
                    now,
                ],
            )
        profile = await self.get_publish_profile(user_id, project_id, provider)
        if not profile:
            raise RuntimeError("Failed to persist publish profile")
        return profile

    async def create_publish_connect_session(
        self,
        user_id: str,
        project_id: str,
        *,
        provider: str,
        platform: str,
        provider_profile_id: str,
        ttl_seconds: int = 900,
    ) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        state = secrets.token_urlsafe(32)
        await self.db_client.execute(
            """
            INSERT INTO PublishConnectSession (
                state, userId, projectId, provider, platform, providerProfileId,
                createdAt, expiresAt, consumedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
            """,
            [
                state,
                user_id,
                project_id,
                provider,
                platform,
                provider_profile_id,
                now,
                now + ttl_seconds,
            ],
        )
        return {
            "state": state,
            "userId": user_id,
            "projectId": project_id,
            "provider": provider,
            "platform": platform,
            "providerProfileId": provider_profile_id,
            "createdAt": _ts(now),
            "expiresAt": _ts(now + ttl_seconds),
            "consumedAt": None,
        }

    async def consume_publish_connect_session(self, state: str) -> dict[str, Any] | None:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        try:
            rs = await self.db_client.execute(
                """
                UPDATE PublishConnectSession
                SET consumedAt = ?
                WHERE state = ? AND expiresAt >= ? AND consumedAt IS NULL
                RETURNING state, userId, projectId, provider, platform, providerProfileId,
                          createdAt, expiresAt, consumedAt
                """,
                [now, state, now],
            )
            if rs.rows:
                return self._publish_session_from_row(rs.rows[0])
            return None
        except Exception as exc:
            message = str(exc).upper()
            if "RETURNING" not in message and "SQL_PARSE_ERROR" not in message:
                raise

        async with self._oauth_state_lock:
            rs = await self.db_client.execute(
                """
                SELECT state, userId, projectId, provider, platform, providerProfileId,
                       createdAt, expiresAt, consumedAt
                FROM PublishConnectSession
                WHERE state = ? AND expiresAt >= ?
                LIMIT 1
                """,
                [state, now],
            )
            if not rs.rows:
                return None
            session = self._publish_session_from_row(rs.rows[0])
            if session["consumedAt"] is not None:
                return None
            await self.db_client.execute(
                """
                UPDATE PublishConnectSession
                SET consumedAt = ?
                WHERE state = ? AND consumedAt IS NULL
                """,
                [now, state],
            )
            session["consumedAt"] = _ts(now)
            return session

    async def list_publish_accounts(
        self,
        user_id: str,
        project_id: str,
        *,
        provider: str = "zernio",
        include_inactive: bool = False,
    ) -> list[dict[str, Any]]:
        self._ensure_connected()
        query = """
            SELECT id, userId, projectId, provider, platform, providerAccountId,
                   providerProfileId, displayName, username, avatar, status,
                   isDefault, createdAt, updatedAt, lastSyncedAt
            FROM ProjectPublishAccount
            WHERE userId = ? AND projectId = ? AND provider = ?
        """
        params: list[Any] = [user_id, project_id, provider]
        if not include_inactive:
            query += " AND status = 'active'"
        query += " ORDER BY platform ASC, isDefault DESC, updatedAt DESC"
        rs = await self.db_client.execute(query, params)
        return [self._publish_account_from_row(row) for row in rs.rows]

    async def get_publish_account(
        self,
        user_id: str,
        project_id: str,
        account_id: str,
        *,
        provider: str = "zernio",
        platform: str | None = None,
        active_only: bool = True,
    ) -> dict[str, Any] | None:
        self._ensure_connected()
        query = """
            SELECT id, userId, projectId, provider, platform, providerAccountId,
                   providerProfileId, displayName, username, avatar, status,
                   isDefault, createdAt, updatedAt, lastSyncedAt
            FROM ProjectPublishAccount
            WHERE userId = ? AND projectId = ? AND provider = ?
              AND (id = ? OR providerAccountId = ?)
        """
        params: list[Any] = [user_id, project_id, provider, account_id, account_id]
        if platform is not None:
            query += " AND platform = ?"
            params.append(platform)
        if active_only:
            query += " AND status = 'active'"
        query += " LIMIT 1"
        rs = await self.db_client.execute(query, params)
        if not rs.rows:
            return None
        return self._publish_account_from_row(rs.rows[0])

    async def upsert_publish_account(
        self,
        user_id: str,
        project_id: str,
        *,
        provider: str,
        platform: str,
        provider_account_id: str,
        provider_profile_id: str,
        display_name: str | None = None,
        username: str | None = None,
        avatar: str | None = None,
        status: str = "active",
        is_default: bool = False,
    ) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        existing = await self.get_publish_account(
            user_id,
            project_id,
            provider_account_id,
            provider=provider,
            active_only=False,
        )
        if is_default:
            await self.db_client.execute(
                """
                UPDATE ProjectPublishAccount
                SET isDefault = 0, updatedAt = ?
                WHERE userId = ? AND projectId = ? AND provider = ? AND platform = ?
                """,
                [now, user_id, project_id, provider, platform],
            )
        if existing:
            await self.db_client.execute(
                """
                UPDATE ProjectPublishAccount
                SET platform = ?, providerProfileId = ?, displayName = ?, username = ?,
                    avatar = ?, status = ?, isDefault = ?, updatedAt = ?, lastSyncedAt = ?
                WHERE id = ? AND userId = ?
                """,
                [
                    platform,
                    provider_profile_id,
                    display_name,
                    username,
                    avatar,
                    status,
                    1 if is_default else int(existing.get("isDefault", False)),
                    now,
                    now,
                    existing["id"],
                    user_id,
                ],
            )
            account_id = existing["id"]
        else:
            account_id = str(uuid.uuid4())
            await self.db_client.execute(
                """
                INSERT INTO ProjectPublishAccount (
                    id, userId, projectId, provider, platform, providerAccountId,
                    providerProfileId, displayName, username, avatar, status,
                    isDefault, createdAt, updatedAt, lastSyncedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    account_id,
                    user_id,
                    project_id,
                    provider,
                    platform,
                    provider_account_id,
                    provider_profile_id,
                    display_name,
                    username,
                    avatar,
                    status,
                    1 if is_default else 0,
                    now,
                    now,
                    now,
                ],
            )
        account = await self.get_publish_account(
            user_id,
            project_id,
            account_id,
            provider=provider,
            active_only=False,
        )
        if not account:
            raise RuntimeError("Failed to persist publish account")
        return account

    async def unlink_publish_account(
        self,
        user_id: str,
        project_id: str,
        account_id: str,
        *,
        provider: str = "zernio",
    ) -> bool:
        self._ensure_connected()
        existing = await self.get_publish_account(
            user_id,
            project_id,
            account_id,
            provider=provider,
            active_only=True,
        )
        if not existing:
            return False
        await self.db_client.execute(
            """
            UPDATE ProjectPublishAccount
            SET status = 'inactive', isDefault = 0, updatedAt = ?
            WHERE id = ? AND userId = ? AND projectId = ?
            """,
            [int(datetime.now().timestamp()), existing["id"], user_id, project_id],
        )
        return True

    async def rotate_legacy_github_tokens(self) -> dict[str, int | bool]:
        """
        Re-encrypt legacy plaintext GitHub tokens when a master key is configured.

        Safe + idempotent behavior:
        - Encrypted rows are skipped.
        - Unknown non-decryptable formats are skipped to avoid data corruption.
        - Plaintext rows are conditionally updated using token match.
        """
        self._ensure_connected()
        if not self._github_token_encryption_enabled():
            return {
                "key_configured": False,
                "scanned": 0,
                "rotated": 0,
                "skipped": 0,
            }

        crypto = get_crypto()
        rs = await self.db_client.execute(
            "SELECT userId, token FROM UserGithubIntegration"
        )
        rows = list(rs.rows)
        now = int(datetime.now().timestamp())
        rotated = 0
        skipped = 0

        for row in rows:
            if not row or len(row) < 2:
                continue
            user_id = str(row[0])
            token_raw = row[1]
            if token_raw is None:
                continue

            token = str(token_raw)
            try:
                crypto.decrypt(token)
                continue
            except RuntimeError:
                if not self._looks_like_plaintext_github_token(token):
                    skipped += 1
                    continue

            encrypted_token = crypto.encrypt(token)
            await self.db_client.execute(
                """
                UPDATE UserGithubIntegration
                SET token = ?, updatedAt = ?
                WHERE userId = ? AND token = ?
                """,
                [encrypted_token, now, user_id, token],
            )
            rotated += 1

        return {
            "key_configured": True,
            "scanned": len(rows),
            "rotated": rotated,
            "skipped": skipped,
        }

    def _github_integration_from_row(self, row: tuple[Any, ...]) -> dict[str, Any] | None:
        if not row:
            return None
        return {
            "userId": row[0],
            "token": self._decrypt_github_token(str(row[1])) if row[1] else None,
            "githubUserId": row[2],
            "githubUsername": row[3],
            "scopes": _json_load(row[4], None),
            "createdAt": _ts(row[5]),
            "updatedAt": _ts(row[6]),
        }

    def _github_state_from_row(self, row: tuple[Any, ...]) -> tuple[str, int] | None:
        if not row:
            return None
        return row[0], int(row[1])

    async def get_github_integration(self, user_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        self._require_github_token_encryption()
        rs = await self.db_client.execute(
            """
            SELECT userId, token, githubUserId, githubUsername, scopes, createdAt, updatedAt
            FROM UserGithubIntegration
            WHERE userId = ?
            LIMIT 1
            """,
            [user_id],
        )
        if not rs.rows:
            return None
        return self._github_integration_from_row(rs.rows[0])

    async def upsert_github_integration(
        self,
        user_id: str,
        *,
        token: str,
        github_user_id: str | None = None,
        github_username: str | None = None,
        scopes: list[str] | None = None,
    ) -> dict[str, Any]:
        self._ensure_connected()
        self._require_github_token_encryption()
        now = int(datetime.now().timestamp())
        encrypted_token = self._encrypt_github_token(token)

        if await self.get_github_integration(user_id):
            await self.db_client.execute(
                """
                UPDATE UserGithubIntegration
                SET token = ?, githubUserId = ?, githubUsername = ?, scopes = ?, updatedAt = ?
                WHERE userId = ?
                """,
                [
                    encrypted_token,
                    github_user_id,
                    github_username,
                    _json_dump(scopes),
                    now,
                    user_id,
                ],
            )
        else:
            await self.db_client.execute(
                """
                INSERT INTO UserGithubIntegration (
                    userId, token, githubUserId, githubUsername, scopes, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    user_id,
                    encrypted_token,
                    github_user_id,
                    github_username,
                    _json_dump(scopes),
                    now,
                    now,
                ],
            )

        integration = await self.get_github_integration(user_id)
        if integration is None:
            raise RuntimeError("Failed to persist GitHub integration.")
        return integration

    async def delete_github_integration(self, user_id: str) -> None:
        self._ensure_connected()
        self._require_github_token_encryption()
        await self.db_client.execute(
            "DELETE FROM UserGithubIntegration WHERE userId = ?",
            [user_id],
        )

    async def create_github_oauth_state(self, user_id: str, ttl_seconds: int = 600) -> str:
        self._ensure_connected()
        self._require_github_token_encryption()
        import secrets

        state = secrets.token_urlsafe(32)
        now = int(datetime.now().timestamp())
        await self.db_client.execute(
            """
            INSERT INTO GithubOAuthState (state, userId, createdAt, expiresAt, used)
            VALUES (?, ?, ?, ?, 0)
            """,
            [state, user_id, now, now + ttl_seconds],
        )
        return state

    async def consume_github_oauth_state(self, state: str) -> str | None:
        self._ensure_connected()
        self._require_github_token_encryption()
        now = int(datetime.now().timestamp())
        try:
            rs = await self.db_client.execute(
                """
                UPDATE GithubOAuthState
                SET used = 1
                WHERE state = ? AND expiresAt >= ? AND used = 0
                RETURNING userId
                """,
                [state, now],
            )
            if rs.rows:
                return str(rs.rows[0][0])
            return None
        except Exception as exc:
            message = str(exc).upper()
            if "RETURNING" not in message and "SQL_PARSE_ERROR" not in message:
                raise

        async with self._oauth_state_lock:
            rs = await self.db_client.execute(
                """
                SELECT userId, used
                FROM GithubOAuthState
                WHERE state = ? AND expiresAt >= ?
                LIMIT 1
                """,
                [state, now],
            )
            user = self._github_state_from_row(rs.rows[0]) if rs.rows else None
            if not user:
                return None

            user_id, used = user
            if used:
                return None

            await self.db_client.execute(
                "UPDATE GithubOAuthState SET used = 1 WHERE state = ? AND used = 0",
                [state],
            )
            return user_id

    async def get_creator_profile(self, user_id: str, project_id: str | None = None) -> dict[str, Any] | None:
        self._ensure_connected()
        query = """
            SELECT id, userId, projectId, displayName, voice, positioning,
                   "values", currentChapterId, createdAt, updatedAt
            FROM CreatorProfile
            WHERE userId = ?
        """
        params: list[Any] = [user_id]
        if project_id is not None:
            query += " AND projectId = ?"
            params.append(project_id)
        query += " ORDER BY updatedAt DESC LIMIT 1"
        rs = await self.db_client.execute(query, params)
        if not rs.rows:
            return None
        return self._creator_profile_from_row(rs.rows[0])

    async def upsert_creator_profile(self, user_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        project_id = payload.get("projectId")
        existing = await self.get_creator_profile(user_id, project_id)
        now = int(datetime.now().timestamp())

        if existing:
            update_fields: list[str] = ["updatedAt = ?"]
            params: list[Any] = [now]
            mapping = {
                "displayName": "displayName",
                "currentChapterId": "currentChapterId",
            }
            for key, column in mapping.items():
                if key in payload:
                    update_fields.append(f"{column} = ?")
                    params.append(payload[key])
            for key in ("voice", "positioning", "values"):
                if key in payload:
                    column = '"values"' if key == "values" else key
                    update_fields.append(f"{column} = ?")
                    params.append(_json_dump(payload[key]))
            params.append(existing["id"])
            await self.db_client.execute(
                f"UPDATE CreatorProfile SET {', '.join(update_fields)} WHERE id = ?",
                params,
            )
        else:
            await self.db_client.execute(
                """
                INSERT INTO CreatorProfile (
                    id, userId, projectId, displayName, voice, positioning,
                    "values", currentChapterId, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    str(uuid.uuid4()),
                    user_id,
                    project_id,
                    payload.get("displayName"),
                    _json_dump(payload.get("voice")),
                    _json_dump(payload.get("positioning")),
                    _json_dump(payload.get("values")),
                    payload.get("currentChapterId"),
                    now,
                    now,
                ],
            )
        profile = await self.get_creator_profile(user_id, project_id)
        if not profile:
            raise RuntimeError("Failed to upsert creator profile")
        return profile

    async def list_personas(self, user_id: str, project_id: str | None = None) -> list[dict[str, Any]]:
        self._ensure_connected()
        query = """
            SELECT id, userId, projectId, name, avatar, demographics,
                   painPoints, goals, language, contentPreferences,
                   confidence, createdAt, updatedAt
            FROM CustomerPersona
            WHERE userId = ?
        """
        params: list[Any] = [user_id]
        if project_id is not None:
            query += " AND projectId = ?"
            params.append(project_id)
        query += " ORDER BY updatedAt DESC"
        rs = await self.db_client.execute(query, params)
        return [self._persona_from_row(row) for row in rs.rows]

    async def get_persona(self, user_id: str, persona_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, userId, projectId, name, avatar, demographics,
                   painPoints, goals, language, contentPreferences,
                   confidence, createdAt, updatedAt
            FROM CustomerPersona
            WHERE id = ? AND userId = ?
            LIMIT 1
            """,
            [persona_id, user_id],
        )
        if not rs.rows:
            return None
        return self._persona_from_row(rs.rows[0])

    async def create_persona(self, user_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        canonical = _canonical_persona_payload(payload)
        now = int(datetime.now().timestamp())
        persona_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO CustomerPersona (
                id, userId, projectId, name, avatar, demographics,
                painPoints, goals, language, contentPreferences,
                confidence, createdAt, updatedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                persona_id,
                user_id,
                canonical.get("project_id"),
                canonical["name"],
                canonical.get("avatar"),
                _json_dump(canonical.get("demographics")),
                _json_dump(canonical.get("pain_points") or []),
                _json_dump(canonical.get("goals") or []),
                _json_dump(canonical.get("language")),
                _json_dump(canonical.get("content_preferences")),
                canonical.get("confidence") or 50,
                now,
                now,
            ],
        )
        persona = await self.get_persona(user_id, persona_id)
        if not persona:
            raise RuntimeError("Failed to create persona")
        return persona

    async def update_persona(self, user_id: str, persona_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
        self._ensure_connected()
        existing = await self.get_persona(user_id, persona_id)
        if not existing:
            return None
        canonical = _canonical_persona_payload(payload)
        update_fields: list[str] = ["updatedAt = ?"]
        params: list[Any] = [int(datetime.now().timestamp())]
        scalar_fields = {
            "name": "name",
            "avatar": "avatar",
            "confidence": "confidence",
        }
        for key, column in scalar_fields.items():
            if key in canonical and canonical[key] is not None:
                update_fields.append(f"{column} = ?")
                params.append(canonical[key])
        json_fields = {
            "demographics": "demographics",
            "pain_points": "painPoints",
            "goals": "goals",
            "language": "language",
            "content_preferences": "contentPreferences",
        }
        for key, column in json_fields.items():
            if key in canonical and canonical[key] is not None:
                update_fields.append(f"{column} = ?")
                params.append(_json_dump(canonical[key]))
        params.extend([persona_id, user_id])
        await self.db_client.execute(
            f"UPDATE CustomerPersona SET {', '.join(update_fields)} WHERE id = ? AND userId = ?",
            params,
        )
        return await self.get_persona(user_id, persona_id)

    async def delete_persona(self, user_id: str, persona_id: str) -> bool:
        self._ensure_connected()
        persona = await self.get_persona(user_id, persona_id)
        if not persona:
            return False
        await self.db_client.execute(
            "DELETE FROM CustomerPersona WHERE id = ? AND userId = ?",
            [persona_id, user_id],
        )
        return True

    # ─── Affiliate Links ───────────────────────────────────────

    async def ensure_affiliate_table(self) -> None:
        """Create AffiliateLink table and link management tables if they don't exist (idempotent)."""
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS AffiliateLink (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                slug TEXT,
                description TEXT,
                contactUrl TEXT,
                loginUrl TEXT,
                researchSummary TEXT,
                researchedAt INTEGER,
                category TEXT,
                commission TEXT,
                keywords TEXT,
                status TEXT NOT NULL DEFAULT 'active',
                notes TEXT,
                expiresAt INTEGER,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """
        )
        try:
            await self.db_client.execute("ALTER TABLE AffiliateLink ADD COLUMN slug TEXT")
        except Exception:
            pass
        try:
            await self.db_client.execute(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_affiliate_slug_user
                ON AffiliateLink(userId, slug)
                WHERE slug IS NOT NULL
                """
            )
        except Exception:
            pass
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS LinkClick (
                id TEXT PRIMARY KEY NOT NULL,
                linkId TEXT NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT,
                slug TEXT NOT NULL,
                destinationUrl TEXT NOT NULL,
                variantIndex INTEGER DEFAULT 0,
                country TEXT,
                device TEXT,
                referrer TEXT,
                userAgent TEXT,
                createdAt INTEGER NOT NULL
            )
            """
        )
        try:
            await self.db_client.execute(
                "CREATE INDEX IF NOT EXISTS idx_link_click_link ON LinkClick(linkId, createdAt)"
            )
        except Exception:
            pass
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS LinkVariant (
                id TEXT PRIMARY KEY NOT NULL,
                linkId TEXT NOT NULL,
                userId TEXT NOT NULL,
                url TEXT NOT NULL,
                weight INTEGER NOT NULL DEFAULT 1,
                country TEXT,
                device TEXT,
                language TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
            )
            """
        )
        try:
            await self.db_client.execute(
                "CREATE INDEX IF NOT EXISTS idx_link_variant_link ON LinkVariant(linkId)"
            )
        except Exception:
            pass

    def _affiliate_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "projectId": row[2],
            "name": row[3],
            "url": row[4],
            "slug": row[5],
            "description": row[6],
            "contactUrl": row[7],
            "loginUrl": row[8],
            "researchSummary": row[9],
            "researchedAt": _ts(row[10]) if row[10] else None,
            "category": row[11],
            "commission": row[12],
            "keywords": _json_load(row[13], []),
            "status": row[14] or "active",
            "notes": row[15],
            "expiresAt": _ts(row[16]) if row[16] else None,
            "createdAt": _ts(row[17]),
            "updatedAt": _ts(row[18]),
        }

    async def _get_click_counts(self, user_id: str, link_ids: list[str]) -> dict[str, int]:
        if not link_ids:
            return {}
        placeholders = ",".join(["?"] * len(link_ids))
        rs = await self.db_client.execute(
            f"SELECT linkId, COUNT(*) FROM LinkClick WHERE userId = ? AND linkId IN ({placeholders}) GROUP BY linkId",
            [user_id, *link_ids],
        )
        return {row[0]: row[1] for row in rs.rows}

    async def list_affiliations(self, user_id: str, project_id: str | None = None) -> list[dict[str, Any]]:
        self._ensure_connected()
        query = """
            SELECT id, userId, projectId, name, url, slug, description,
                   contactUrl, loginUrl, researchSummary, researchedAt,
                   category, commission, keywords, status, notes,
                   expiresAt, createdAt, updatedAt
            FROM AffiliateLink
            WHERE userId = ?
        """
        params: list[Any] = [user_id]
        if project_id is not None:
            query += " AND projectId = ?"
            params.append(project_id)
        query += " ORDER BY createdAt DESC"
        rs = await self.db_client.execute(query, params)
        affiliations = [self._affiliate_from_row(row) for row in rs.rows]
        click_counts = await self._get_click_counts(user_id, [a["id"] for a in affiliations])
        for affiliation in affiliations:
            affiliation["clickCount"] = click_counts.get(affiliation["id"], 0)
        return affiliations

    async def get_affiliation(self, user_id: str, affiliation_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, userId, projectId, name, url, slug, description,
                   contactUrl, loginUrl, researchSummary, researchedAt,
                   category, commission, keywords, status, notes,
                   expiresAt, createdAt, updatedAt
            FROM AffiliateLink
            WHERE id = ? AND userId = ?
            LIMIT 1
            """,
            [affiliation_id, user_id],
        )
        if not rs.rows:
            return None
        affiliation = self._affiliate_from_row(rs.rows[0])
        click_counts = await self._get_click_counts(user_id, [affiliation_id])
        affiliation["clickCount"] = click_counts.get(affiliation_id, 0)
        return affiliation

    async def create_affiliation(self, user_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        affiliation_id = str(uuid.uuid4())
        expires_at = None
        if payload.get("expiresAt"):
            try:
                expires_at = int(datetime.fromisoformat(payload["expiresAt"]).timestamp())
            except (ValueError, TypeError):
                pass
        slug = payload.get("slug")
        if slug:
            slug = slug.strip().lower()
            if not slug:
                slug = None
        await self.db_client.execute(
            """
            INSERT INTO AffiliateLink (
                id, userId, projectId, name, url, slug, description,
                contactUrl, loginUrl, category, commission,
                keywords, status, notes, expiresAt, createdAt, updatedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                affiliation_id,
                user_id,
                payload.get("projectId"),
                payload["name"],
                payload["url"],
                slug,
                payload.get("description"),
                payload.get("contactUrl"),
                payload.get("loginUrl"),
                payload.get("category"),
                payload.get("commission"),
                _json_dump(payload.get("keywords") or []),
                payload.get("status") or "active",
                payload.get("notes"),
                expires_at,
                now,
                now,
            ],
        )
        affiliation = await self.get_affiliation(user_id, affiliation_id)
        if not affiliation:
            raise RuntimeError("Failed to create affiliation")
        return affiliation

    async def update_affiliation(self, user_id: str, affiliation_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
        self._ensure_connected()
        existing = await self.get_affiliation(user_id, affiliation_id)
        if not existing:
            return None
        if "slug" in payload:
            new_slug = payload["slug"]
            if new_slug:
                new_slug = new_slug.strip().lower()
                if not new_slug:
                    new_slug = None
            if new_slug != existing.get("slug"):
                rs = await self.db_client.execute(
                    "SELECT id FROM AffiliateLink WHERE userId = ? AND slug = ? AND id != ? LIMIT 1",
                    [user_id, new_slug, affiliation_id],
                )
                if rs.rows:
                    raise ValueError(f"Slug '{new_slug}' is already used")
        update_fields: list[str] = ["updatedAt = ?"]
        params: list[Any] = [int(datetime.now().timestamp())]
        scalar_fields = {
            "name": "name",
            "url": "url",
            "slug": "slug",
            "description": "description",
            "contactUrl": "contactUrl",
            "loginUrl": "loginUrl",
            "category": "category",
            "commission": "commission",
            "status": "status",
            "notes": "notes",
        }
        for key, column in scalar_fields.items():
            if key in payload:
                update_fields.append(f"{column} = ?")
                value = payload[key]
                if key == "slug" and value:
                    value = value.strip().lower()
                    if not value:
                        value = None
                params.append(value)
        if "keywords" in payload:
            update_fields.append("keywords = ?")
            params.append(_json_dump(payload["keywords"]))
        if "expiresAt" in payload:
            update_fields.append("expiresAt = ?")
            if payload["expiresAt"]:
                try:
                    params.append(int(datetime.fromisoformat(payload["expiresAt"]).timestamp()))
                except (ValueError, TypeError):
                    params.append(None)
            else:
                params.append(None)
        params.extend([affiliation_id, user_id])
        await self.db_client.execute(
            f"UPDATE AffiliateLink SET {', '.join(update_fields)} WHERE id = ? AND userId = ?",
            params,
        )
        return await self.get_affiliation(user_id, affiliation_id)

    async def delete_affiliation(self, user_id: str, affiliation_id: str) -> bool:
        self._ensure_connected()
        affiliation = await self.get_affiliation(user_id, affiliation_id)
        if not affiliation:
            return False
        await self.db_client.execute(
            "DELETE FROM AffiliateLink WHERE id = ? AND userId = ?",
            [affiliation_id, user_id],
        )
        return True

    async def get_affiliation_by_slug(self, slug: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, userId, projectId, name, url, slug, description,
                   contactUrl, loginUrl, researchSummary, researchedAt,
                   category, commission, keywords, status, notes,
                   expiresAt, createdAt, updatedAt
            FROM AffiliateLink
            WHERE slug = ? AND status = 'active'
            LIMIT 1
            """,
            [slug],
        )
        if not rs.rows:
            return None
        affiliation = self._affiliate_from_row(rs.rows[0])
        click_counts = await self._get_click_counts(affiliation["userId"], [affiliation["id"]])
        affiliation["clickCount"] = click_counts.get(affiliation["id"], 0)
        return affiliation

    async def create_link_click(self, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        click_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO LinkClick (
                id, linkId, userId, projectId, slug, destinationUrl,
                variantIndex, country, device, referrer, userAgent, createdAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                click_id,
                payload.get("linkId"),
                payload.get("userId", ""),
                payload.get("projectId"),
                payload.get("slug", ""),
                payload.get("destinationUrl", ""),
                payload.get("variantIndex", 0),
                payload.get("country"),
                payload.get("device"),
                payload.get("referrer"),
                payload.get("userAgent"),
                now,
            ],
        )
        return {"id": click_id, "createdAt": _ts(now)}

    async def list_link_clicks(self, user_id: str, link_id: str, limit: int = 100, offset: int = 0) -> list[dict[str, Any]]:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, linkId, userId, projectId, slug, destinationUrl,
                   variantIndex, country, device, referrer, userAgent, createdAt
            FROM LinkClick
            WHERE linkId = ? AND userId = ?
            ORDER BY createdAt DESC
            LIMIT ? OFFSET ?
            """,
            [link_id, user_id, limit, offset],
        )
        return [self._link_click_from_row(row) for row in rs.rows]

    async def get_link_click_summary(self, user_id: str, link_id: str) -> dict[str, Any]:
        self._ensure_connected()
        total = await self.db_client.execute(
            "SELECT COUNT(*) FROM LinkClick WHERE linkId = ? AND userId = ?",
            [link_id, user_id],
        )
        total_count = total.rows[0][0] if total.rows else 0
        countries = await self.db_client.execute(
            """
            SELECT country, COUNT(*) as cnt FROM LinkClick
            WHERE linkId = ? AND userId = ? AND country IS NOT NULL
            GROUP BY country ORDER BY cnt DESC LIMIT 10
            """,
            [link_id, user_id],
        )
        devices = await self.db_client.execute(
            """
            SELECT device, COUNT(*) as cnt FROM LinkClick
            WHERE linkId = ? AND userId = ? AND device IS NOT NULL
            GROUP BY device ORDER BY cnt DESC LIMIT 10
            """,
            [link_id, user_id],
        )
        referrers = await self.db_client.execute(
            """
            SELECT referrer, COUNT(*) as cnt FROM LinkClick
            WHERE linkId = ? AND userId = ? AND referrer IS NOT NULL
            GROUP BY referrer ORDER BY cnt DESC LIMIT 10
            """,
            [link_id, user_id],
        )
        daily = await self.db_client.execute(
            """
            SELECT DATE(createdAt, 'unixepoch') as day, COUNT(*) as cnt
            FROM LinkClick WHERE linkId = ? AND userId = ?
            GROUP BY day ORDER BY day DESC LIMIT 30
            """,
            [link_id, user_id],
        )
        return {
            "totalClicks": total_count,
            "countries": [{"country": r[0], "count": r[1]} for r in countries.rows],
            "devices": [{"device": r[0], "count": r[1]} for r in devices.rows],
            "referrers": [{"referrer": r[0], "count": r[1]} for r in referrers.rows],
            "daily": [{"day": r[0], "count": r[1]} for r in daily.rows],
        }

    def _link_click_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "linkId": row[1],
            "userId": row[2],
            "projectId": row[3],
            "slug": row[4],
            "destinationUrl": row[5],
            "variantIndex": row[6] or 0,
            "country": row[7],
            "device": row[8],
            "referrer": row[9],
            "userAgent": row[10],
            "createdAt": _ts(row[11]),
        }

    async def create_link_variant(self, user_id: str, link_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        variant_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO LinkVariant (id, linkId, userId, url, weight, country, device, language, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                variant_id,
                link_id,
                user_id,
                payload["url"],
                payload.get("weight") or 1,
                payload.get("country"),
                payload.get("device"),
                payload.get("language"),
                now,
                now,
            ],
        )
        return await self.get_link_variant(user_id, variant_id)

    async def get_link_variant(self, user_id: str, variant_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, linkId, userId, url, weight, country, device, language, createdAt, updatedAt
            FROM LinkVariant WHERE id = ? AND userId = ? LIMIT 1
            """,
            [variant_id, user_id],
        )
        if not rs.rows:
            return None
        return self._link_variant_from_row(rs.rows[0])

    async def list_link_variants(self, user_id: str, link_id: str) -> list[dict[str, Any]]:
        self._ensure_connected()
        rs = await self.db_client.execute(
            """
            SELECT id, linkId, userId, url, weight, country, device, language, createdAt, updatedAt
            FROM LinkVariant WHERE linkId = ? AND userId = ?
            """,
            [link_id, user_id],
        )
        return [self._link_variant_from_row(row) for row in rs.rows]

    async def update_link_variant(self, user_id: str, variant_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
        self._ensure_connected()
        existing = await self.get_link_variant(user_id, variant_id)
        if not existing:
            return None
        now = int(datetime.now().timestamp())
        fields: list[str] = ["updatedAt = ?"]
        params: list[Any] = [now]
        for key, column in (("url", "url"), ("weight", "weight"), ("country", "country"), ("device", "device"), ("language", "language")):
            if key in payload:
                fields.append(f"{column} = ?")
                params.append(payload[key])
        params.extend([variant_id, user_id])
        await self.db_client.execute(
            f"UPDATE LinkVariant SET {', '.join(fields)} WHERE id = ? AND userId = ?",
            params,
        )
        return await self.get_link_variant(user_id, variant_id)

    async def delete_link_variant(self, user_id: str, variant_id: str) -> bool:
        self._ensure_connected()
        rs = await self.db_client.execute(
            "DELETE FROM LinkVariant WHERE id = ? AND userId = ?",
            [variant_id, user_id],
        )
        return rs.rows_affected > 0

    def _link_variant_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "linkId": row[1],
            "userId": row[2],
            "url": row[3],
            "weight": row[4] or 1,
            "country": row[5],
            "device": row[6],
            "language": row[7],
            "createdAt": _ts(row[8]),
            "updatedAt": _ts(row[9]),
        }

    # ─── Activity Log ──────────────────────────────────────────

    async def ensure_activity_table(self) -> None:
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS ActivityLog (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT,
                action TEXT NOT NULL,
                robotId TEXT,
                status TEXT NOT NULL DEFAULT 'started',
                details TEXT,
                createdAt INTEGER NOT NULL
            )
            """
        )

    def _activity_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "projectId": row[2],
            "action": row[3],
            "robotId": row[4],
            "status": row[5] or "started",
            "details": _json_load(row[6], None),
            "createdAt": _ts(row[7]),
        }

    async def list_activity(self, user_id: str, project_id: str | None = None, limit: int = 50) -> list[dict[str, Any]]:
        self._ensure_connected()
        query = """
            SELECT id, userId, projectId, action, robotId, status, details, createdAt
            FROM ActivityLog
            WHERE userId = ?
        """
        params: list[Any] = [user_id]
        if project_id is not None:
            query += " AND projectId = ?"
            params.append(project_id)
        query += " ORDER BY createdAt DESC LIMIT ?"
        params.append(limit)
        rs = await self.db_client.execute(query, params)
        return [self._activity_from_row(row) for row in rs.rows]

    async def create_activity(self, user_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        activity_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO ActivityLog (id, userId, projectId, action, robotId, status, details, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                activity_id,
                user_id,
                payload.get("projectId"),
                payload["action"],
                payload.get("robotId"),
                payload.get("status") or "started",
                _json_dump(payload.get("details")),
                now,
            ],
        )
        rs = await self.db_client.execute(
            "SELECT id, userId, projectId, action, robotId, status, details, createdAt FROM ActivityLog WHERE id = ?",
            [activity_id],
        )
        return self._activity_from_row(rs.rows[0])

    # ─── Work Domains ──────────────────────────────────────────

    async def ensure_work_domain_table(self) -> None:
        self._ensure_connected()
        await self.db_client.execute(
            """
            CREATE TABLE IF NOT EXISTS WorkDomain (
                id TEXT PRIMARY KEY NOT NULL,
                userId TEXT NOT NULL,
                projectId TEXT NOT NULL,
                domain TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'idle',
                lastRunAt INTEGER,
                lastRunStatus TEXT,
                itemsPending INTEGER NOT NULL DEFAULT 0,
                itemsCompleted INTEGER NOT NULL DEFAULT 0,
                metadata TEXT,
                updatedAt INTEGER NOT NULL
            )
            """
        )

    def _work_domain_from_row(self, row: tuple[Any, ...]) -> dict[str, Any]:
        return {
            "id": row[0],
            "userId": row[1],
            "projectId": row[2],
            "domain": row[3],
            "status": row[4] or "idle",
            "lastRunAt": _ts(row[5]) if row[5] else None,
            "lastRunStatus": row[6],
            "itemsPending": row[7] or 0,
            "itemsCompleted": row[8] or 0,
            "metadata": _json_load(row[9], None),
            "updatedAt": _ts(row[10]),
        }

    _WD_COLS = "id, userId, projectId, domain, status, lastRunAt, lastRunStatus, itemsPending, itemsCompleted, metadata, updatedAt"

    async def list_work_domains(self, user_id: str, project_id: str | None = None) -> list[dict[str, Any]]:
        self._ensure_connected()
        query = f"SELECT {self._WD_COLS} FROM WorkDomain WHERE userId = ?"
        params: list[Any] = [user_id]
        if project_id is not None:
            query += " AND projectId = ?"
            params.append(project_id)
        query += " ORDER BY domain ASC"
        rs = await self.db_client.execute(query, params)
        return [self._work_domain_from_row(row) for row in rs.rows]

    async def get_work_domain(self, user_id: str, domain_id: str) -> dict[str, Any] | None:
        self._ensure_connected()
        rs = await self.db_client.execute(
            f"SELECT {self._WD_COLS} FROM WorkDomain WHERE id = ? AND userId = ? LIMIT 1",
            [domain_id, user_id],
        )
        if not rs.rows:
            return None
        return self._work_domain_from_row(rs.rows[0])

    async def create_work_domain(self, user_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        self._ensure_connected()
        now = int(datetime.now().timestamp())
        domain_id = str(uuid.uuid4())
        await self.db_client.execute(
            """
            INSERT INTO WorkDomain (id, userId, projectId, domain, status, metadata, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                domain_id, user_id,
                payload["projectId"], payload["domain"],
                payload.get("status") or "idle",
                _json_dump(payload.get("metadata")),
                now,
            ],
        )
        result = await self.get_work_domain(user_id, domain_id)
        if not result:
            raise RuntimeError("Failed to create work domain")
        return result

    async def update_work_domain(self, user_id: str, domain_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
        self._ensure_connected()
        existing = await self.get_work_domain(user_id, domain_id)
        if not existing:
            return None
        now = int(datetime.now().timestamp())
        fields: list[str] = ["updatedAt = ?"]
        params: list[Any] = [now]
        for key in ("status", "lastRunStatus"):
            if key in payload:
                fields.append(f"{key} = ?")
                params.append(payload[key])
        for key in ("itemsPending", "itemsCompleted"):
            if key in payload:
                fields.append(f"{key} = ?")
                params.append(payload[key])
        if "metadata" in payload:
            fields.append("metadata = ?")
            params.append(_json_dump(payload["metadata"]))
        if payload.get("status") in ("running",):
            fields.append("lastRunAt = ?")
            params.append(now)
        params.extend([domain_id, user_id])
        await self.db_client.execute(
            f"UPDATE WorkDomain SET {', '.join(fields)} WHERE id = ? AND userId = ?",
            params,
        )
        return await self.get_work_domain(user_id, domain_id)


user_data_store = UserDataStore()
