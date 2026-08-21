"""Bounded recovery for durable AI-usage reservations.

Candidate discovery is image-workflow specific; quota mutations remain behind
the persistence-agnostic AIUsageService and its scoped store port.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Any, Awaitable, Protocol

from api.dependencies.ai_usage import AIUsageRuntime, get_ai_usage_runtime
from api.models.ai_usage import (
    AIUsageAction,
    AIUsageReservationStatus,
    AIUsageScope,
    ProviderCostMetadata,
)
from api.services.ai_usage_policies import AIUsageFailureBehavior
from api.services.image_generation_store import ImageGenerationStore, image_generation_store
from api.services.job_store import JobStore, job_store

logger = logging.getLogger(__name__)


class _RuntimeProvider(Protocol):
    def __call__(self) -> Awaitable[AIUsageRuntime]: ...


@dataclass(frozen=True)
class AIUsageReconciliationResult:
    inspected: int = 0
    expired: int = 0
    settled: int = 0
    projected: int = 0
    deferred: int = 0
    failed: int = 0


class AIUsageReconciliationService:
    """Recover only transitions justified by persisted, tenant-scoped facts."""

    def __init__(
        self,
        *,
        generation_store: ImageGenerationStore,
        jobs: JobStore,
        runtime_provider: _RuntimeProvider,
        batch_size: int = 100,
    ) -> None:
        self._generations = generation_store
        self._jobs = jobs
        self._runtime_provider = runtime_provider
        self._batch_size = max(1, min(batch_size, 500))

    async def run_batch(self) -> AIUsageReconciliationResult:
        candidates = await self._generations.list_quota_reconciliation_candidates(
            limit=self._batch_size
        )
        if not candidates:
            return AIUsageReconciliationResult()
        runtime = await self._runtime_provider()
        counts = {
            "inspected": len(candidates),
            "expired": 0,
            "settled": 0,
            "projected": 0,
            "deferred": 0,
            "failed": 0,
        }
        expired_scopes: set[tuple[str, str]] = set()
        for candidate in candidates:
            try:
                scope = AIUsageScope(
                    user_id=candidate["user_id"],
                    project_id=candidate["project_id"],
                )
                if candidate["quota_status"] == "reserved":
                    scope_key = (scope.user_id, scope.project_id)
                    if scope_key not in expired_scopes:
                        expired_scopes.add(scope_key)
                        expired = await runtime.service.expire_stale_reservations(
                            scope=scope,
                            limit=self._batch_size,
                        )
                        counts["expired"] += len(expired)
                    await self._project_terminal_reservation(candidate, scope, runtime, counts)
                    continue
                await self._reconcile_pending(candidate, scope, runtime, counts)
            except Exception:
                counts["failed"] += 1
                logger.exception(
                    "AI usage reconciliation candidate failed",
                    extra={"generation_id": candidate.get("id")},
                )
        return AIUsageReconciliationResult(**counts)

    async def _project_terminal_reservation(
        self,
        candidate: dict[str, Any],
        scope: AIUsageScope,
        runtime: AIUsageRuntime,
        counts: dict[str, int],
    ) -> None:
        reservation = await runtime.store.get_reservation(
            candidate["reservation_id"], scope=scope
        )
        if reservation is None or reservation.status not in {
            AIUsageReservationStatus.CONSUMED,
            AIUsageReservationStatus.RELEASED,
            AIUsageReservationStatus.REFUNDED,
            AIUsageReservationStatus.EXPIRED,
        }:
            counts["deferred"] += 1
            return
        await self._generations.update_reconciliation(
            candidate["id"],
            user_id=scope.user_id,
            quota_status=reservation.status.value,
            quota_outcome=reservation.status.value,
            reconciled=True,
        )
        counts["projected"] += 1

    async def _reconcile_pending(
        self,
        candidate: dict[str, Any],
        scope: AIUsageScope,
        runtime: AIUsageRuntime,
        counts: dict[str, int],
    ) -> None:
        reservation = await runtime.store.get_reservation(
            candidate["reservation_id"], scope=scope
        )
        if reservation is None:
            counts["deferred"] += 1
            return
        if reservation.status in {
            AIUsageReservationStatus.CONSUMED,
            AIUsageReservationStatus.RELEASED,
            AIUsageReservationStatus.REFUNDED,
            AIUsageReservationStatus.EXPIRED,
        }:
            await self._project_terminal_reservation(candidate, scope, runtime, counts)
            return

        provider_cost = self._provider_cost(candidate)
        if candidate["status"] == "failed":
            policy = runtime.policies.resolve(AIUsageAction.FLUX_IMAGE_GENERATION)
            reason = candidate.get("error_code") or "generation_failed"
            if (
                reservation.status is AIUsageReservationStatus.PROVIDER_STARTED
                and policy.provider_failure_behavior is AIUsageFailureBehavior.REFUND
            ):
                settled = await runtime.service.refund(
                    scope=scope,
                    reservation_id=reservation.reservation_id,
                    reason=reason,
                    provider_cost=provider_cost,
                )
            else:
                settled = await runtime.service.release(
                    scope=scope,
                    reservation_id=reservation.reservation_id,
                    reason=reason,
                    provider_cost=provider_cost,
                )
            await self._record_settlement(candidate, settled.status.value)
            counts["settled"] += 1
            return

        job = await self._jobs.get_by_reservation(
            reservation.reservation_id,
            user_id=scope.user_id,
            project_id=scope.project_id,
        )
        if not job or not job.get("asset_id"):
            counts["deferred"] += 1
            return
        settled = await runtime.service.consume(
            scope=scope,
            reservation_id=reservation.reservation_id,
            provider_cost=provider_cost,
        )
        await self._record_settlement(candidate, settled.status.value)
        await self._jobs.update(
            job["job_id"],
            cost_control_status=settled.status.value,
            quota_outcome=settled.status.value,
        )
        counts["settled"] += 1

    async def _record_settlement(self, candidate: dict[str, Any], outcome: str) -> None:
        await self._generations.update_reconciliation(
            candidate["id"],
            user_id=candidate["user_id"],
            quota_status=outcome,
            quota_outcome=outcome,
            provider_cost_evidence=candidate.get("provider_cost_evidence") or None,
            reconciled=True,
        )

    @staticmethod
    def _provider_cost(candidate: dict[str, Any]) -> ProviderCostMetadata | None:
        evidence = candidate.get("provider_cost_evidence")
        return ProviderCostMetadata.model_validate(evidence) if evidence else None


def get_ai_usage_reconciliation_service() -> AIUsageReconciliationService:
    return AIUsageReconciliationService(
        generation_store=image_generation_store,
        jobs=job_store,
        runtime_provider=get_ai_usage_runtime,
        batch_size=int(os.getenv("AI_USAGE_RECONCILIATION_BATCH_SIZE", "100")),
    )
