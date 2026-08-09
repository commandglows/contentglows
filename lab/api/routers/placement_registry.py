"""Read-only endpoint for the canonical format and placement registry."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from api.dependencies.auth import CurrentUser, require_current_user
from api.services.social_placement_registry import registry_payload

router = APIRouter(prefix="/api/placement-registry", tags=["Placement Registry"])


@router.get("")
async def read_placement_registry(
    locale: Optional[str] = Query(None, max_length=10),
    current_user: CurrentUser = Depends(require_current_user),
):
    normalized = (locale or "en").lower().split("-")[0]
    try:
        return registry_payload(normalized)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
