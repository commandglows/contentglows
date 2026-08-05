from api.dependencies.auth import get_optional_current_user


def test_dev_auth_bypass_provides_deterministic_local_user(monkeypatch):
    monkeypatch.setenv("CONTENTGLOWS_RUNTIME_ENV", "dev")
    monkeypatch.setenv("CONTENTGLOWS_DEV_AUTH_BYPASS", "true")

    user = get_optional_current_user(credentials=None)

    assert user is not None
    assert user.user_id == "devserver-local-user"
    assert user.email == "devserver@contentglows.local"


def test_dev_auth_bypass_is_disabled_outside_dev(monkeypatch):
    monkeypatch.setenv("CONTENTGLOWS_RUNTIME_ENV", "prd")
    monkeypatch.setenv("CONTENTGLOWS_DEV_AUTH_BYPASS", "true")

    assert get_optional_current_user(credentials=None) is None
