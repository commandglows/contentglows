from api import observability


class FakeSentrySdk:
    def __init__(self):
        self.init_kwargs = None
        self.captured = []

    def init(self, **kwargs):
        self.init_kwargs = kwargs

    def capture_exception(self, exc):
        self.captured.append(exc)
        return "event-id"


def test_init_sentry_disabled_without_dsn(monkeypatch):
    fake = FakeSentrySdk()
    monkeypatch.setattr(observability, "_INITIALIZED", False)
    monkeypatch.setattr(observability, "_sentry_sdk", fake)
    monkeypatch.delenv("SENTRY_DSN", raising=False)

    assert observability.init_sentry() is False
    assert fake.init_kwargs is None


def test_init_sentry_uses_lab_defaults(monkeypatch):
    fake = FakeSentrySdk()
    monkeypatch.setattr(observability, "_INITIALIZED", False)
    monkeypatch.setattr(observability, "_sentry_sdk", fake)
    monkeypatch.setenv("SENTRY_DSN", "https://public@example.ingest.sentry.io/1")
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("BACKEND_GIT_SHA", "abc123")
    monkeypatch.delenv("SENTRY_ENVIRONMENT", raising=False)
    monkeypatch.delenv("SENTRY_RELEASE", raising=False)
    monkeypatch.delenv("SENTRY_SAMPLE_RATE", raising=False)
    monkeypatch.delenv("SENTRY_TRACES_SAMPLE_RATE", raising=False)
    monkeypatch.delenv("SENTRY_SEND_DEFAULT_PII", raising=False)
    monkeypatch.delenv("SENTRY_DEBUG", raising=False)
    monkeypatch.delenv("SENTRY_DIST", raising=False)

    assert observability.init_sentry() is True

    assert fake.init_kwargs == {
        "dsn": "https://public@example.ingest.sentry.io/1",
        "sample_rate": 1.0,
        "traces_sample_rate": 0.0,
        "send_default_pii": False,
        "debug": False,
        "before_send": observability._before_send,
        "environment": "production",
        "release": "abc123",
    }


def test_init_sentry_uses_dist_when_configured(monkeypatch):
    fake = FakeSentrySdk()
    monkeypatch.setattr(observability, "_INITIALIZED", False)
    monkeypatch.setattr(observability, "_sentry_sdk", fake)
    monkeypatch.setenv("SENTRY_DSN", "https://public@example.ingest.sentry.io/1")
    monkeypatch.setenv("SENTRY_DIST", "run-42")
    monkeypatch.delenv("SENTRY_ENVIRONMENT", raising=False)
    monkeypatch.delenv("SENTRY_RELEASE", raising=False)

    assert observability.init_sentry() is True
    assert fake.init_kwargs["dist"] == "run-42"


def test_sentry_status_is_redacted(monkeypatch):
    monkeypatch.setattr(observability, "_INITIALIZED", True)
    monkeypatch.setenv("SENTRY_DSN", "https://public@example.ingest.sentry.io/1")
    monkeypatch.setenv("SENTRY_ENVIRONMENT", "production")
    monkeypatch.setenv("SENTRY_RELEASE", "contentglows-api@abc123")
    monkeypatch.setenv("SENTRY_DIST", "run-42")
    monkeypatch.setenv("SENTRY_SEND_DEFAULT_PII", "false")
    monkeypatch.delenv("SENTRY_TRACES_SAMPLE_RATE", raising=False)

    assert observability.sentry_status() == {
        "configured": True,
        "initialized": True,
        "environment": "production",
        "release": "contentglows-api@abc123",
        "dist": "run-42",
        "send_default_pii": False,
        "traces_sample_rate": "0.0",
    }


def test_capture_exception_is_noop_before_init(monkeypatch):
    fake = FakeSentrySdk()
    monkeypatch.setattr(observability, "_INITIALIZED", False)
    monkeypatch.setattr(observability, "_sentry_sdk", fake)

    assert observability.capture_exception(RuntimeError("boom")) is None
    assert fake.captured == []


def test_capture_exception_uses_sentry_when_initialized(monkeypatch):
    fake = FakeSentrySdk()
    exc = RuntimeError("boom")
    monkeypatch.setattr(observability, "_INITIALIZED", True)
    monkeypatch.setattr(observability, "_sentry_sdk", fake)

    assert observability.capture_exception(exc) == "event-id"
    assert fake.captured == [exc]
