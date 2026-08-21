from datetime import UTC, datetime, timedelta

import pytest

from scripts.platform_admin_grants import _authority_from_environment


NOW = datetime(2026, 8, 21, 18, tzinfo=UTC)


def _configure(monkeypatch, *, expiry: datetime | None = None):
    monkeypatch.setenv("CONTENTGLOWS_PLATFORM_ADMIN_OPERATIONS", "enabled")
    monkeypatch.setenv("PLATFORM_ADMIN_OPERATION_ID", "operation-1")
    monkeypatch.setenv(
        "PLATFORM_ADMIN_BOOTSTRAP_ACTOR_USER_IDS",
        "operator-1,operator-2",
    )
    monkeypatch.setenv(
        "PLATFORM_ADMIN_OPERATION_EXPIRES_AT",
        (expiry or NOW + timedelta(minutes=10)).isoformat(),
    )


def test_operation_gate_requires_exact_actor_operation_and_short_window(monkeypatch):
    _configure(monkeypatch)
    authority = _authority_from_environment(
        actor_user_id="operator-1",
        operation_id="operation-1",
        now=NOW,
    )
    assert authority.actor_user_id == "operator-1"
    assert authority.operation_id == "operation-1"

    with pytest.raises(RuntimeError, match="actor"):
        _authority_from_environment(
            actor_user_id="operator-3",
            operation_id="operation-1",
            now=NOW,
        )
    with pytest.raises(RuntimeError, match="operation id"):
        _authority_from_environment(
            actor_user_id="operator-1",
            operation_id="another-operation",
            now=NOW,
        )

    _configure(monkeypatch, expiry=NOW + timedelta(minutes=16))
    with pytest.raises(RuntimeError, match="window"):
        _authority_from_environment(
            actor_user_id="operator-1",
            operation_id="operation-1",
            now=NOW,
        )


def test_operation_gate_is_disabled_by_default(monkeypatch):
    monkeypatch.delenv("CONTENTGLOWS_PLATFORM_ADMIN_OPERATIONS", raising=False)
    with pytest.raises(RuntimeError, match="disabled"):
        _authority_from_environment(
            actor_user_id="operator-1",
            operation_id="operation-1",
            now=NOW,
        )
