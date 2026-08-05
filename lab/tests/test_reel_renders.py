from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi import FastAPI
from fastapi.testclient import TestClient

from api.dependencies.auth import CurrentUser, require_current_user
from api.routers import reel_renders as router
from api.services.remotion_render_client import RemotionRenderUnavailableError
from api.services.render_artifact_tokens import (
    RenderArtifactTokenError,
    issue_artifact_token,
    verify_artifact_token,
)


@dataclass
class _FakeStatusService:
    body: str

    def get_content_body(self, _content_id: str):
        return {"body": self.body}


class _FakeJobStore:
    def __init__(self):
        self.jobs: dict[str, dict] = {}

    async def upsert(self, job_id: str, job_type: str, **fields):
        now = datetime.utcnow().isoformat()
        existing = self.jobs.get(job_id, {})
        payload = {
            "job_id": job_id,
            "job_type": job_type,
            "status": fields.pop("status", existing.get("status", "queued")),
            "progress": fields.pop("progress", existing.get("progress", 0)),
            "message": fields.pop("message", existing.get("message")),
            "created_at": existing.get("created_at", now),
            "updated_at": now,
        }
        payload.update({k: v for k, v in existing.items() if k not in payload})
        payload.update(fields)
        self.jobs[job_id] = payload
        return payload

    async def update(self, job_id: str, **fields):
        current = self.jobs.get(job_id)
        if not current:
            return
        current.update(fields)
        current["updated_at"] = datetime.utcnow().isoformat()

    async def get(self, job_id: str):
        job = self.jobs.get(job_id)
        return dict(job) if job else None

    async def list_by_type(self, job_type: str, limit: int = 50):
        jobs = [dict(job) for job in self.jobs.values() if job.get("job_type") == job_type]
        jobs.sort(key=lambda item: item.get("created_at", ""), reverse=True)
        return jobs[:limit]


class _FakeWorkerClient:
    def __init__(self):
        self.status_by_job_id: dict[str, dict] = {}

    async def create_render(self, payload):
        return {
            "workerJobId": payload["jobId"],
            "status": "queued",
            "progress": 0,
            "message": "Queued",
        }

    async def get_render(self, worker_job_id: str):
        if worker_job_id in self.status_by_job_id:
            return self.status_by_job_id[worker_job_id]
        return {"workerJobId": worker_job_id, "status": "queued", "progress": 0}

    async def cancel_render(self, worker_job_id: str):
        return {"workerJobId": worker_job_id, "status": "cancelled", "message": "Cancelled"}


def _build_client() -> TestClient:
    app = FastAPI()
    app.include_router(router.router)
    app.dependency_overrides[require_current_user] = lambda: CurrentUser(
        user_id="user-1",
        email="user@example.com",
        bearer_token="token",
    )
    return TestClient(app)


def _owned_content():
    return SimpleNamespace(id="content-1", title="Title", project_id="project-1")


def test_create_and_poll_completed_job_with_signed_artifact(monkeypatch, tmp_path: Path):
    client = _build_client()
    fake_store = _FakeJobStore()
    fake_worker = _FakeWorkerClient()
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setattr(router, "get_remotion_render_client", lambda: fake_worker)
    monkeypatch.setattr(router, "get_status_service", lambda: _FakeStatusService(body="A" * 400))
    monkeypatch.setattr(router, "require_owned_content_record", AsyncMock(return_value=_owned_content()))
    monkeypatch.setenv("RENDER_ARTIFACT_SIGNING_KEY", "test-signing-key")
    monkeypatch.setenv("CONTENTGLOWS_RENDER_DIR", str(tmp_path))

    create_response = client.post(
        "/api/reels/render-jobs",
        json={
            "content_id": "content-1",
            "template_id": "content-summary-v1",
            "duration_seconds": 60,
        },
    )
    assert create_response.status_code == 202
    job_id = create_response.json()["job_id"]

    preview_dir = tmp_path / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = preview_dir / f"{job_id}.mp4"
    artifact_path.write_bytes(b"video")

    fake_worker.status_by_job_id[job_id] = {
        "workerJobId": job_id,
        "status": "completed",
        "progress": 100,
        "artifact": {
            "artifactPath": f"previews/{job_id}.mp4",
            "byteSize": artifact_path.stat().st_size,
            "mimeType": "video/mp4",
            "fileName": artifact_path.name,
            "retentionExpiresAt": "2026-06-15T00:00:00+00:00",
            "deletionWarningAt": "2026-06-12T00:00:00+00:00",
        },
    }

    poll_response = client.get(f"/api/reels/render-jobs/{job_id}")
    assert poll_response.status_code == 200
    payload = poll_response.json()
    assert payload["status"] == "completed"
    assert payload["artifact"] is not None
    artifact_url = payload["artifact"]["artifact_url"]

    artifact_response = client.get(artifact_url)
    assert artifact_response.status_code == 200
    assert artifact_response.content == b"video"


def test_create_rejects_invalid_duration(monkeypatch):
    client = _build_client()
    monkeypatch.setattr(router, "job_store", _FakeJobStore())
    monkeypatch.setattr(router, "require_owned_content_record", AsyncMock(return_value=_owned_content()))
    monkeypatch.setattr(router, "get_status_service", lambda: _FakeStatusService(body="A"))

    response = client.post(
        "/api/reels/render-jobs",
        json={
            "content_id": "content-1",
            "template_id": "content-summary-v1",
            "duration_seconds": 30,
        },
    )
    assert response.status_code == 400
    assert "duration_seconds" in response.json()["detail"]


def test_create_returns_429_when_capacity_reached(monkeypatch):
    client = _build_client()
    fake_store = _FakeJobStore()
    fake_store.jobs["active-1"] = {
        "job_id": "active-1",
        "job_type": "reel_render",
        "status": "in_progress",
        "progress": 50,
        "message": "running",
        "user_id": "user-1",
        "content_id": "other-content",
        "project_id": "project-1",
        "template_id": "content-summary-v1",
        "render_mode": "preview",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setattr(router, "require_owned_content_record", AsyncMock(return_value=_owned_content()))
    monkeypatch.setattr(router, "get_status_service", lambda: _FakeStatusService(body="A"))

    response = client.post(
        "/api/reels/render-jobs",
        json={
            "content_id": "content-1",
            "template_id": "content-summary-v1",
            "duration_seconds": 60,
        },
    )
    assert response.status_code == 429
    assert response.headers["Retry-After"] == "60"


def test_create_returns_503_when_worker_is_not_configured(monkeypatch):
    client = _build_client()
    fake_store = _FakeJobStore()
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setattr(router, "require_owned_content_record", AsyncMock(return_value=_owned_content()))
    monkeypatch.setattr(router, "get_status_service", lambda: _FakeStatusService(body="A" * 120))

    def unavailable_client():
        raise RemotionRenderUnavailableError("REMOTION_WORKER_URL is required")

    monkeypatch.setattr(router, "get_remotion_render_client", unavailable_client)

    response = client.post(
        "/api/reels/render-jobs",
        json={
            "content_id": "content-1",
            "template_id": "content-summary-v1",
            "duration_seconds": 60,
        },
    )

    assert response.status_code == 503
    stored_job = next(iter(fake_store.jobs.values()))
    assert stored_job["status"] == "failed"
    assert stored_job["message"] == "Render worker unavailable"


def test_poll_does_not_fail_job_when_worker_is_temporarily_unavailable(monkeypatch):
    client = _build_client()
    fake_store = _FakeJobStore()
    fake_store.jobs["job-1"] = {
        "job_id": "job-1",
        "job_type": "reel_render",
        "status": "in_progress",
        "progress": 42,
        "message": "running",
        "user_id": "user-1",
        "content_id": "content-1",
        "project_id": "project-1",
        "template_id": "content-summary-v1",
        "render_mode": "preview",
        "duration_seconds": 60,
        "worker_job_id": "job-1",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setattr(router, "require_owned_content_record", AsyncMock(return_value=_owned_content()))
    monkeypatch.setattr(router, "get_status_service", lambda: _FakeStatusService(body="A"))

    def unavailable_client():
        raise RemotionRenderUnavailableError("worker down")

    monkeypatch.setattr(router, "get_remotion_render_client", unavailable_client)

    response = client.get("/api/reels/render-jobs/job-1")

    assert response.status_code == 200
    assert response.json()["status"] == "in_progress"
    assert fake_store.jobs["job-1"]["status"] == "in_progress"


def test_export_returns_existing_final_job(monkeypatch):
    client = _build_client()
    fake_store = _FakeJobStore()
    fake_store.jobs["preview-1"] = {
        "job_id": "preview-1",
        "job_type": "reel_render",
        "status": "completed",
        "progress": 100,
        "message": "done",
        "user_id": "user-1",
        "content_id": "content-1",
        "project_id": "project-1",
        "template_id": "content-summary-v1",
        "render_mode": "preview",
        "duration_seconds": 60,
        "worker_job_id": "preview-1",
        "input_props": {"title": "T", "hook": "H", "key_points": ["A"], "cta": "C"},
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    fake_store.jobs["final-1"] = {
        "job_id": "final-1",
        "job_type": "reel_render",
        "status": "queued",
        "progress": 0,
        "message": "queued",
        "user_id": "user-1",
        "content_id": "content-1",
        "project_id": "project-1",
        "template_id": "content-summary-v1",
        "render_mode": "final",
        "duration_seconds": 60,
        "parent_preview_job_id": "preview-1",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setattr(router, "get_remotion_render_client", lambda: _FakeWorkerClient())
    monkeypatch.setattr(router, "require_owned_content_record", AsyncMock(return_value=_owned_content()))
    monkeypatch.setattr(router, "get_status_service", lambda: _FakeStatusService(body="A"))

    response = client.post("/api/reels/render-jobs/preview-1/export", json={})
    assert response.status_code == 202
    assert response.json()["job_id"] == "final-1"


def test_cancel_render_job(monkeypatch):
    client = _build_client()
    fake_store = _FakeJobStore()
    fake_store.jobs["job-1"] = {
        "job_id": "job-1",
        "job_type": "reel_render",
        "status": "in_progress",
        "progress": 42,
        "message": "running",
        "user_id": "user-1",
        "content_id": "content-1",
        "project_id": "project-1",
        "template_id": "content-summary-v1",
        "render_mode": "preview",
        "worker_job_id": "job-1",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setattr(router, "get_remotion_render_client", lambda: _FakeWorkerClient())
    monkeypatch.setattr(router, "require_owned_content_record", AsyncMock(return_value=_owned_content()))
    monkeypatch.setattr(router, "get_status_service", lambda: _FakeStatusService(body="A"))

    response = client.delete("/api/reels/render-jobs/job-1")
    assert response.status_code == 200
    assert response.json()["status"] == "cancelled"


def test_artifact_endpoint_rejects_invalid_token(monkeypatch, tmp_path: Path):
    client = _build_client()
    fake_store = _FakeJobStore()
    fake_store.jobs["job-1"] = {
        "job_id": "job-1",
        "job_type": "reel_render",
        "status": "completed",
        "progress": 100,
        "message": "done",
        "user_id": "user-1",
        "content_id": "content-1",
        "project_id": "project-1",
        "template_id": "content-summary-v1",
        "render_mode": "preview",
        "artifact_path": "previews/job-1.mp4",
        "artifact_file_name": "job-1.mp4",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setenv("RENDER_ARTIFACT_SIGNING_KEY", "test-signing-key")
    monkeypatch.setenv("CONTENTGLOWS_RENDER_DIR", str(tmp_path))

    response = client.get("/api/reels/render-jobs/job-1/artifact?token=bad-token")
    assert response.status_code == 403


def test_artifact_endpoint_path_safety(monkeypatch, tmp_path: Path):
    client = _build_client()
    fake_store = _FakeJobStore()
    fake_store.jobs["job-1"] = {
        "job_id": "job-1",
        "job_type": "reel_render",
        "status": "completed",
        "progress": 100,
        "message": "done",
        "user_id": "user-1",
        "content_id": "content-1",
        "project_id": "project-1",
        "template_id": "content-summary-v1",
        "render_mode": "preview",
        "artifact_path": "../escape.mp4",
        "artifact_file_name": "escape.mp4",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    monkeypatch.setattr(router, "job_store", fake_store)
    monkeypatch.setenv("RENDER_ARTIFACT_SIGNING_KEY", "test-signing-key")
    monkeypatch.setenv("CONTENTGLOWS_RENDER_DIR", str(tmp_path))
    token, _ = issue_artifact_token(
        job_id="job-1",
        render_mode="preview",
        artifact_path="../escape.mp4",
    )

    response = client.get(f"/api/reels/render-jobs/job-1/artifact?token={token}")
    assert response.status_code == 403


def test_render_artifact_token_verification_checks_scope():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    token, _ = issue_artifact_token(
        job_id="job-1",
        render_mode="preview",
        artifact_path="previews/job-1.mp4",
        signing_key="k",
        now=now,
    )
    verify_artifact_token(
        token=token,
        job_id="job-1",
        render_mode="preview",
        artifact_path="previews/job-1.mp4",
        signing_key="k",
        now=now,
    )

    try:
        verify_artifact_token(
            token=token,
            job_id="job-1",
            render_mode="final",
            artifact_path="finals/job-1.mp4",
            signing_key="k",
            now=now,
        )
        assert False, "Expected scope verification to fail"
    except RenderArtifactTokenError:
        pass
