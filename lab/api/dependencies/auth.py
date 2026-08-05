"""Authentication dependencies for protected API routes."""

from __future__ import annotations

import os

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from api.auth.clerk import (
    ClerkAuthenticationError,
    ClerkConfigurationError,
    validate_clerk_token,
)


class CurrentUser(BaseModel):
    """Normalized authenticated user context."""

    user_id: str
    email: str | None = None
    bearer_token: str


bearer_scheme = HTTPBearer(auto_error=False)

_DEV_BYPASS_USER_ID = "devserver-local-user"
_DEV_BYPASS_EMAIL = "devserver@contentglows.local"
_DEV_BYPASS_TOKEN = "devserver-auth-bypass"


def _dev_auth_bypass_enabled() -> bool:
    """Return whether the explicit, development-only auth bypass is enabled."""
    return (
        os.getenv("CONTENTGLOWS_RUNTIME_ENV", "").strip().lower()
        == "dev"
        and os.getenv("CONTENTGLOWS_DEV_AUTH_BYPASS", "").strip().lower()
        in {"1", "true", "yes", "on"}
    )


def _dev_bypass_user() -> CurrentUser:
    """Provide the deterministic local user used by the devserver only."""
    return CurrentUser(
        user_id=_DEV_BYPASS_USER_ID,
        email=_DEV_BYPASS_EMAIL,
        bearer_token=_DEV_BYPASS_TOKEN,
    )


def get_optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> CurrentUser | None:
    """Return the current Clerk user when a bearer token is present, else None."""
    if _dev_auth_bypass_enabled():
        return _dev_bypass_user()

    if credentials is None:
        return None
    if credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    try:
        claims = validate_clerk_token(credentials.credentials)
    except ClerkConfigurationError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except ClerkAuthenticationError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc

    return CurrentUser(
        user_id=claims.user_id,
        email=claims.email,
        bearer_token=credentials.credentials,
    )


def require_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> CurrentUser:
    """Require a valid Clerk bearer token and return the current user."""
    current_user = get_optional_current_user(credentials)
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )
    return current_user
