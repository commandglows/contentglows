"""Authored contracts for generic owner-scoped job metadata."""

import pytest

from api.services.job_store import JobStore
from utils.libsql_async import create_client


@pytest.mark.asyncio
async def test_job_store_additive_schema_preserves_legacy_jobs():
    client = create_client(url=":memory:")
    await client.execute(
        """
        CREATE TABLE jobs (
            job_id TEXT PRIMARY KEY,
            job_type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            progress INTEGER NOT NULL DEFAULT 0,
            message TEXT,
            data TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    store = JobStore(db_client=client)

    await store.ensure_table()
    await store.ensure_table()
    legacy = await store.upsert(
        "legacy-1",
        "deployment",
        status="running",
        progress=25,
        current_step="build",
    )

    assert legacy["job_type"] == "deployment"
    assert legacy["current_step"] == "build"
    assert legacy["user_id"] is None
    assert legacy["reservation_id"] is None


@pytest.mark.asyncio
async def test_job_store_scopes_jobs_and_finds_recoverable_reservations():
    store = JobStore(db_client=create_client(url=":memory:"))
    await store.ensure_table()
    await store.upsert(
        "flux-1",
        "image_generation",
        user_id="user-1",
        project_id="project-1",
        reservation_id="reservation-1",
        cost_control_status="reconciliation_pending",
        generation_id="generation-1",
    )
    await store.upsert(
        "flux-2",
        "image_generation",
        user_id="user-2",
        project_id="project-1",
        reservation_id="reservation-2",
        cost_control_status="consumed",
    )

    assert await store.get_owned("flux-1", user_id="user-2") is None
    owned = await store.get_owned(
        "flux-1",
        user_id="user-1",
        project_id="project-1",
    )
    assert owned["generation_id"] == "generation-1"
    pending = await store.list_owned(
        user_id="user-1",
        project_id="project-1",
        job_type="image_generation",
        cost_control_status="reconciliation_pending",
    )
    assert [job["job_id"] for job in pending] == ["flux-1"]
    by_reservation = await store.get_by_reservation(
        "reservation-1",
        user_id="user-1",
        project_id="project-1",
    )
    assert by_reservation["job_id"] == "flux-1"
    assert await store.get_by_reservation(
        "reservation-1",
        user_id="user-2",
        project_id="project-1",
    ) is None


@pytest.mark.asyncio
async def test_job_store_rejects_owner_reassignment_and_preserves_metadata():
    store = JobStore(db_client=create_client(url=":memory:"))
    await store.ensure_table()
    await store.upsert(
        "flux-1",
        "image_generation",
        user_id="user-1",
        project_id="project-1",
        reservation_id="reservation-1",
        custom="kept",
    )

    with pytest.raises(ValueError, match="cannot be reassigned"):
        await store.upsert(
            "flux-1",
            "image_generation",
            user_id="user-2",
            project_id="project-1",
            status="completed",
        )

    await store.update(
        "flux-1",
        user_id="user-1",
        project_id="project-1",
        cost_control_status="consumed",
        progress=100,
    )
    stored = await store.get("flux-1")
    assert stored["user_id"] == "user-1"
    assert stored["custom"] == "kept"
    assert stored["cost_control_status"] == "consumed"
