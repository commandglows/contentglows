from datetime import datetime

import pytest

from api.services import email_source_service as svc


class _FakeStatusService:
    def __init__(self):
        self.jobs = []

    def list_schedule_jobs(self, user_id=None, **_kwargs):
        if user_id is None:
            return list(self.jobs)
        return [job for job in self.jobs if job.get("user_id") == user_id]

    def create_schedule_job(self, **kwargs):
        job = {
            "id": "job-1",
            "user_id": kwargs.get("user_id"),
            "job_type": kwargs.get("job_type"),
            "project_id": kwargs.get("project_id"),
            "configuration": kwargs.get("configuration") or {},
            "schedule": kwargs.get("schedule"),
            "enabled": kwargs.get("enabled", True),
            "next_run_at": kwargs.get("next_run_at"),
        }
        self.jobs.append(job)
        return job

    def update_schedule_job(self, job_id, **kwargs):
        job = next(job for job in self.jobs if job["id"] == job_id)
        job.update(kwargs)
        return job

    def delete_schedule_job(self, job_id):
        self.jobs = [job for job in self.jobs if job["id"] != job_id]


@pytest.mark.asyncio
async def test_ensure_email_source_schedule_job_creates_managed_six_hour_job(monkeypatch):
    fake = _FakeStatusService()
    monkeypatch.setattr("status.service.get_status_service", lambda: fake)

    job = await svc.ensure_email_source_schedule_job(
        "user-1",
        project_id="project-1",
        metadata={
            "sourceFolder": "Newsletters",
            "archiveFolder": "CONTENTGLOWS_DONE",
        },
    )

    assert job["user_id"] == "user-1"
    assert job["project_id"] == "project-1"
    assert job["job_type"] == "ingest_newsletters"
    assert job["schedule"] == "every_6_hours"
    assert job["configuration"]["managed_by"] == "email_source"
    assert job["configuration"]["folder"] == "Newsletters"
    assert datetime.fromisoformat(job["next_run_at"])


@pytest.mark.asyncio
async def test_ensure_email_source_schedule_job_updates_existing_managed_job(monkeypatch):
    fake = _FakeStatusService()
    fake.jobs.append(
        {
            "id": "job-1",
            "user_id": "user-1",
            "job_type": "ingest_newsletters",
            "project_id": "old-project",
            "configuration": {"managed_by": "email_source", "folder": "Old"},
            "schedule": "daily",
            "enabled": False,
            "next_run_at": "2026-05-10T00:00:00",
        }
    )
    monkeypatch.setattr("status.service.get_status_service", lambda: fake)

    job = await svc.ensure_email_source_schedule_job(
        "user-1",
        project_id="project-2",
        metadata={
            "sourceFolder": "Inbox/Creators",
            "archiveFolder": "Done",
        },
    )

    assert len(fake.jobs) == 1
    assert job["project_id"] == "project-2"
    assert job["schedule"] == "every_6_hours"
    assert job["enabled"] is True
    assert job["configuration"]["folder"] == "Inbox/Creators"
    assert job["configuration"]["archive_folder"] == "Done"
