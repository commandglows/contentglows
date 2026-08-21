"""Authenticated, owner-scoped AI usage and quota reads."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from pydantic import Field

from api.dependencies.ai_usage import (
    AIUsageRuntime,
    AIUsageRuntimeProvider,
    get_ai_usage_runtime_provider,
)
from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import require_owned_project_id
from api.models.ai_usage import (
    AIQuotaStatus,
    AIUsageAction,
    AIUsageBillingMode,
    AIUsageLedgerEntry,
    AIUsageLedgerEvent,
    AIUsageModel,
    AIUsageReservation,
    AIUsageReservationStatus,
    AIUsageScope,
    NonNegativeUnits,
)
from api.services.ai_usage_policies import (
    AIUsageActionPolicy,
    AIUsageFailureBehavior,
    AIUsageLimitBehavior,
)


router = APIRouter(prefix="/api/ai-usage", tags=["AI Usage"])


class AIUsagePreflightRequest(AIUsageModel):
    project_id: str = Field(min_length=1, max_length=128, pattern=r"^\S+$")
    action: AIUsageAction


class AIUsagePolicyMetadata(AIUsageModel):
    action: AIUsageAction
    billing_mode: AIUsageBillingMode
    estimated_units: NonNegativeUnits
    limit_behavior: AIUsageLimitBehavior
    provider_failure_behavior: AIUsageFailureBehavior


class AIUsagePreflightResponse(AIUsageModel):
    quota: AIQuotaStatus
    policy: AIUsagePolicyMetadata


class AIUsageSummaryResponse(AIUsageModel):
    project_id: str
    quotas: list[AIQuotaStatus]


class AIUsageHistoryResponse(AIUsageModel):
    project_id: str
    entries: list[AIUsageLedgerEntry]


class AIUsagePendingReservationsResponse(AIUsageModel):
    project_id: str
    reservations: list[AIUsageReservation]


class AIUsagePolicyListResponse(AIUsageModel):
    policies: list[AIUsagePolicyMetadata]


async def _runtime(provider: AIUsageRuntimeProvider) -> AIUsageRuntime:
    return await provider()


def _scope(current_user: CurrentUser, project_id: str) -> AIUsageScope:
    return AIUsageScope(user_id=current_user.user_id, project_id=project_id)


def _public_policy(policy: AIUsageActionPolicy) -> AIUsagePolicyMetadata:
    return AIUsagePolicyMetadata(
        action=policy.action,
        billing_mode=policy.billing_mode,
        estimated_units=policy.estimated_units,
        limit_behavior=policy.limit_behavior,
        provider_failure_behavior=policy.provider_failure_behavior,
    )


@router.get("/summary", response_model=AIUsageSummaryResponse)
async def get_usage_summary(
    project_id: str = Query(..., min_length=1, max_length=128),
    current_user: CurrentUser = Depends(require_current_user),
    runtime_provider: AIUsageRuntimeProvider = Depends(get_ai_usage_runtime_provider),
) -> AIUsageSummaryResponse:
    await require_owned_project_id(project_id, current_user)
    runtime = await _runtime(runtime_provider)
    scope = _scope(current_user, project_id)
    quotas = [
        await runtime.service.preflight(
            scope=scope,
            action=policy.action,
            required_units=policy.estimated_units,
        )
        for policy in runtime.policies.all()
    ]
    return AIUsageSummaryResponse(project_id=project_id, quotas=quotas)


@router.post("/preflight", response_model=AIUsagePreflightResponse)
async def preflight_usage(
    request: AIUsagePreflightRequest,
    current_user: CurrentUser = Depends(require_current_user),
    runtime_provider: AIUsageRuntimeProvider = Depends(get_ai_usage_runtime_provider),
) -> AIUsagePreflightResponse:
    await require_owned_project_id(request.project_id, current_user)
    runtime = await _runtime(runtime_provider)
    policy = runtime.policies.resolve(request.action)
    quota = await runtime.service.preflight(
        scope=_scope(current_user, request.project_id),
        action=request.action,
        required_units=policy.estimated_units,
    )
    return AIUsagePreflightResponse(quota=quota, policy=_public_policy(policy))


@router.get("/history", response_model=AIUsageHistoryResponse)
async def get_usage_history(
    project_id: str = Query(..., min_length=1, max_length=128),
    event: AIUsageLedgerEvent | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: CurrentUser = Depends(require_current_user),
    runtime_provider: AIUsageRuntimeProvider = Depends(get_ai_usage_runtime_provider),
) -> AIUsageHistoryResponse:
    await require_owned_project_id(project_id, current_user)
    runtime = await _runtime(runtime_provider)
    entries = await runtime.store.list_ledger_entries(
        scope=_scope(current_user, project_id),
        event=event,
        limit=limit,
    )
    return AIUsageHistoryResponse(project_id=project_id, entries=entries)


@router.get(
    "/reservations/pending",
    response_model=AIUsagePendingReservationsResponse,
)
async def get_pending_reservations(
    project_id: str = Query(..., min_length=1, max_length=128),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: CurrentUser = Depends(require_current_user),
    runtime_provider: AIUsageRuntimeProvider = Depends(get_ai_usage_runtime_provider),
) -> AIUsagePendingReservationsResponse:
    await require_owned_project_id(project_id, current_user)
    runtime = await _runtime(runtime_provider)
    scope = _scope(current_user, project_id)
    reservations: list[AIUsageReservation] = []
    for reservation_status in (
        AIUsageReservationStatus.RESERVED,
        AIUsageReservationStatus.PROVIDER_STARTED,
    ):
        reservations.extend(
            await runtime.store.list_reservations(
                scope=scope,
                status=reservation_status,
                limit=limit,
            )
        )
    reservations.sort(key=lambda item: item.updated_at, reverse=True)
    return AIUsagePendingReservationsResponse(
        project_id=project_id,
        reservations=reservations[:limit],
    )


@router.get("/policies", response_model=AIUsagePolicyListResponse)
async def get_usage_policies(
    _current_user: CurrentUser = Depends(require_current_user),
    runtime_provider: AIUsageRuntimeProvider = Depends(get_ai_usage_runtime_provider),
) -> AIUsagePolicyListResponse:
    runtime = await _runtime(runtime_provider)
    return AIUsagePolicyListResponse(
        policies=[_public_policy(policy) for policy in runtime.policies.all()]
    )
