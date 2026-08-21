from types import SimpleNamespace

import pytest

from api.models.ai_usage import AIUsageReservationStatus
from api.services.ai_usage_reconciliation import AIUsageReconciliationService


class _GenerationStore:
    def __init__(self, candidates):
        self.candidates = candidates
        self.updates = []

    async def list_quota_reconciliation_candidates(self, *, limit):
        assert limit == 10
        return self.candidates[:limit]

    async def update_reconciliation(self, generation_id, **values):
        self.updates.append((generation_id, values))


class _Jobs:
    def __init__(self, job=None):
        self.job = job
        self.updates = []

    async def get_by_reservation(self, reservation_id, **scope):
        return self.job

    async def update(self, job_id, **values):
        self.updates.append((job_id, values))


class _QuotaStore:
    def __init__(self, reservation):
        self.reservation = reservation

    async def get_reservation(self, reservation_id, *, scope):
        return self.reservation


class _QuotaService:
    def __init__(self, reservation):
        self.reservation = reservation
        self.consumed = []

    async def expire_stale_reservations(self, **kwargs):
        return []

    async def consume(self, **kwargs):
        self.consumed.append(kwargs)
        return SimpleNamespace(status=AIUsageReservationStatus.CONSUMED)


def _candidate(**overrides):
    candidate = {
        "id": "generation-1",
        "user_id": "user-1",
        "project_id": "project-1",
        "reservation_id": "reservation-1",
        "quota_status": "reconciliation_pending",
        "quota_outcome": None,
        "status": "running",
        "provider_cost_evidence": {},
        "error_code": None,
    }
    candidate.update(overrides)
    return candidate


@pytest.mark.asyncio
async def test_reconciliation_consumes_only_with_durable_asset_evidence():
    reservation = SimpleNamespace(
        reservation_id="reservation-1",
        status=AIUsageReservationStatus.PROVIDER_STARTED,
    )
    generations = _GenerationStore([_candidate()])
    jobs = _Jobs({"job_id": "job-1", "asset_id": "asset-1"})
    quota = _QuotaService(reservation)
    runtime = SimpleNamespace(
        store=_QuotaStore(reservation), service=quota, policies=SimpleNamespace()
    )
    reconciler = AIUsageReconciliationService(
        generation_store=generations,
        jobs=jobs,
        runtime_provider=lambda: _runtime(runtime),
        batch_size=10,
    )

    result = await reconciler.run_batch()

    assert result.settled == 1
    assert len(quota.consumed) == 1
    assert generations.updates[0][1]["quota_status"] == "consumed"


@pytest.mark.asyncio
async def test_reconciliation_defers_success_without_durable_asset_evidence():
    reservation = SimpleNamespace(
        reservation_id="reservation-1",
        status=AIUsageReservationStatus.PROVIDER_STARTED,
    )
    quota = _QuotaService(reservation)
    runtime = SimpleNamespace(
        store=_QuotaStore(reservation), service=quota, policies=SimpleNamespace()
    )
    reconciler = AIUsageReconciliationService(
        generation_store=_GenerationStore([_candidate()]),
        jobs=_Jobs(),
        runtime_provider=lambda: _runtime(runtime),
        batch_size=10,
    )

    result = await reconciler.run_batch()

    assert result.deferred == 1
    assert quota.consumed == []


async def _runtime(runtime):
    return runtime
