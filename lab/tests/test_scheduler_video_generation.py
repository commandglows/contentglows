from types import SimpleNamespace

import pytest

from scheduler.scheduler_service import SchedulerService


class _FakeStatusService:
    def __init__(self):
        self.contents = []
        self.schedule_jobs = []
        self.updated = []

    def list_content(self, status=None, content_type=None, source_robot=None, project_id=None, project_ids=None, limit=50, offset=0):
        items = self.contents
        if project_id is not None:
            items = [item for item in items if item.project_id == project_id]
        return items

    def update_content(self, content_id: str, **updates):
        self.updated.append((content_id, updates))
        return SimpleNamespace(id=content_id, **updates)

    def list_schedule_jobs(self, user_id=None, project_id=None, status=None, enabled_only=False):
        jobs = self.schedule_jobs
        if project_id is not None:
            jobs = [job for job in jobs if job.get("project_id") == project_id]
        return jobs

    def create_schedule_job(self, **payload):
        job = {
            "id": f"job-{len(self.schedule_jobs)+1}",
            "user_id": payload["user_id"],
            "project_id": payload.get("project_id"),
            "job_type": payload["job_type"],
            "schedule": payload["schedule"],
            "schedule_time": payload.get("schedule_time"),
            "schedule_day": payload.get("schedule_day"),
            "configuration": payload.get("configuration", {}),
            "enabled": payload.get("enabled", True),
            "next_run_at": payload.get("next_run_at"),
        }
        self.schedule_jobs.append(job)
        return job

    def update_schedule_job(self, job_id: str, **updates):
        for job in self.schedule_jobs:
            if job["id"] == job_id:
                job.update(updates)
                return job
        raise AssertionError(f"Unknown job {job_id}")

    def get_user_settings_raw(self):
        return {
            "robotSettings": {
                "contentFrequency": {"video_drafts_per_day": 2},
            }
        }


@pytest.mark.asyncio
async def test_reconcile_frequency_creates_auto_video_job(monkeypatch):
    fake_svc = _FakeStatusService()
    monkeypatch.setattr("scheduler.scheduler_service.get_status_service", lambda: fake_svc)
    monkeypatch.setattr("api.services.user_data_store.UserDataStore", lambda: fake_svc)

    scheduler = SchedulerService()
    await scheduler._reconcile_frequency_jobs(fake_svc)

    assert any(job["job_type"] == "auto_video" for job in fake_svc.schedule_jobs)


@pytest.mark.asyncio
async def test_scheduler_runs_bounded_media_reconciliation(monkeypatch):
    calls = []

    class _Reconciler:
        async def run_batch(self):
            calls.append("run")

    monkeypatch.setattr(
        "api.services.video_source_media_reconciliation.get_video_source_media_reconciliation_service",
        lambda: _Reconciler(),
    )

    await SchedulerService()._reconcile_media_uploads()

    assert calls == ["run"]


@pytest.mark.asyncio
async def test_auto_video_job_consumes_complete_content(monkeypatch):
    fake_svc = _FakeStatusService()
    fake_svc.contents = [
        SimpleNamespace(
            id="content-1",
            title="Video draft",
            content_type="video_script",
            source_robot="manual",
            status="approved",
            project_id="project-1",
            user_id="user-1",
            content_path=None,
            content_preview="Preview",
            content_hash=None,
            priority=3,
            tags=[],
            metadata={
                "content_complete_at": "2026-07-08T00:00:00+00:00",
                "video_generation_state": "ready",
            },
            target_url=None,
            reviewer_note=None,
            reviewed_by=None,
            review_actor_type=None,
            review_actor_id=None,
            review_actor_label=None,
            review_actor_metadata=None,
            created_at="2026-07-08T00:00:00+00:00",
            updated_at="2026-07-08T00:00:00+00:00",
            scheduled_for=None,
            published_at=None,
            synced_at=None,
        )
    ]

    async def _fake_ensure_run(
        *,
        content_record,
        current_user,
        status_service,
        format_preset,
        trigger_source,
        brand_profile_id=None,
        blueprint_id=None,
    ):
        assert content_record.id == "content-1"
        return SimpleNamespace(
            status="ready",
            readiness="ready_to_publish",
            timeline_id="timeline-1",
            version_id="version-1",
            preview_job_id="preview-1",
            final_job_id="final-1",
        )

    monkeypatch.setattr(
        "api.services.branded_video_generation_service.branded_video_generation_service.ensure_run",
        _fake_ensure_run,
    )
    monkeypatch.setattr("scheduler.scheduler_service.get_status_service", lambda: fake_svc)

    scheduler = SchedulerService()
    await scheduler._run_auto_video_job(
        {
            "id": "job-1",
            "user_id": "user-1",
            "project_id": "project-1",
            "configuration": {"target_count": 1},
        }
    )

    assert fake_svc.updated
    content_id, updates = fake_svc.updated[0]
    assert content_id == "content-1"
    assert updates["metadata"]["video_generation_state"] == "ready"
    assert updates["metadata"]["video_generation_readiness"] == "ready_to_publish"
    assert updates["metadata"]["video_generation_timeline_id"] == "timeline-1"
