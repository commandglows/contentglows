"""Authenticated runtime mode and provider integration settings endpoints."""

from __future__ import annotations

from datetime import datetime

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import AliasChoices, BaseModel, ConfigDict, Field

from api.dependencies.auth import CurrentUser, require_current_user
from api.dependencies.ownership import require_owned_project_id
from api.models.ai_runtime import (
    AIRuntimeModeUpdateRequest,
    AIRuntimeSettingsResponse,
    ProviderCredentialDeleteResponse,
    ProviderCredentialStatus,
    ProviderCredentialUpsertRequest,
)
from api.models.user_data import (
    OpenRouterCredentialStatus,
    OpenRouterCredentialUpsertRequest,
    OpenRouterCredentialValidateResponse,
)
from api.services.ai_runtime_service import AIRuntimeServiceError, ai_runtime_service
from api.services.email_source_service import (
    EmailSourceConfigurationError,
    delete_email_source,
    get_email_source_status,
    upsert_email_source,
    validate_email_source,
)
from api.services.user_key_store import user_key_store

router = APIRouter(tags=["Settings Integrations"])

_OPENROUTER_PROVIDER = "openrouter"
_OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"


class EmailSourceStatus(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    configured: bool = False
    email: str | None = None
    host: str = "imap.gmail.com"
    source_folder: str = Field(
        default="Newsletters",
        validation_alias=AliasChoices("sourceFolder", "source_folder"),
        serialization_alias="sourceFolder",
    )
    archive_folder: str = Field(
        default="CONTENTGLOWS_DONE",
        validation_alias=AliasChoices("archiveFolder", "archive_folder"),
        serialization_alias="archiveFolder",
    )
    project_id: str | None = Field(
        default=None,
        validation_alias=AliasChoices("projectId", "project_id"),
        serialization_alias="projectId",
    )
    validation_status: str = Field(
        default="unknown",
        validation_alias=AliasChoices("validationStatus", "validation_status"),
        serialization_alias="validationStatus",
    )
    last_validated_at: datetime | None = Field(
        default=None,
        validation_alias=AliasChoices("lastValidatedAt", "last_validated_at"),
        serialization_alias="lastValidatedAt",
    )
    updated_at: datetime | None = Field(
        default=None,
        validation_alias=AliasChoices("updatedAt", "updated_at"),
        serialization_alias="updatedAt",
    )


class EmailSourceUpsertRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    email: str
    app_password: str | None = Field(
        default=None,
        min_length=8,
        validation_alias=AliasChoices("appPassword", "app_password"),
        serialization_alias="appPassword",
    )
    host: str = "imap.gmail.com"
    source_folder: str = Field(
        default="Newsletters",
        validation_alias=AliasChoices("sourceFolder", "source_folder"),
        serialization_alias="sourceFolder",
    )
    archive_folder: str = Field(
        default="CONTENTGLOWS_DONE",
        validation_alias=AliasChoices("archiveFolder", "archive_folder"),
        serialization_alias="archiveFolder",
    )
    project_id: str | None = Field(
        default=None,
        validation_alias=AliasChoices("projectId", "project_id"),
        serialization_alias="projectId",
    )


class EmailSourceValidateResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    valid: bool
    validation_status: str = Field(serialization_alias="validationStatus")
    message: str


def _raise_runtime_error(exc: AIRuntimeServiceError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc


def _to_openrouter_status(status: ProviderCredentialStatus) -> OpenRouterCredentialStatus:
    return OpenRouterCredentialStatus(
        provider="openrouter",
        configured=status.configured,
        masked_secret=status.masked_secret,
        validation_status=status.validation_status,
        last_validated_at=status.last_validated_at,
        updated_at=status.updated_at,
    )


@router.get(
    "/api/settings/ai-runtime",
    response_model=AIRuntimeSettingsResponse,
    summary="Get AI runtime settings",
)
async def get_ai_runtime(
    current_user: CurrentUser = Depends(require_current_user),
) -> AIRuntimeSettingsResponse:
    return await ai_runtime_service.get_runtime_settings(current_user.user_id)


@router.put(
    "/api/settings/ai-runtime",
    response_model=AIRuntimeSettingsResponse,
    summary="Update AI runtime mode",
)
async def put_ai_runtime(
    request: AIRuntimeModeUpdateRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> AIRuntimeSettingsResponse:
    try:
        return await ai_runtime_service.set_runtime_mode(
            user_id=current_user.user_id,
            mode=request.mode,
        )
    except AIRuntimeServiceError as exc:
        _raise_runtime_error(exc)


@router.get(
    "/api/settings/integrations/openrouter",
    response_model=OpenRouterCredentialStatus,
    summary="Get OpenRouter credential status",
)
async def get_openrouter_credential(
    current_user: CurrentUser = Depends(require_current_user),
) -> OpenRouterCredentialStatus:
    """Compatibility wrapper backed by generic provider settings."""
    status = await get_provider_credential(
        provider=_OPENROUTER_PROVIDER,
        current_user=current_user,
    )
    return _to_openrouter_status(status)


@router.put(
    "/api/settings/integrations/openrouter",
    response_model=OpenRouterCredentialStatus,
    summary="Store OpenRouter credential",
)
async def put_openrouter_credential(
    request: OpenRouterCredentialUpsertRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> OpenRouterCredentialStatus:
    """Compatibility wrapper backed by generic provider settings."""
    status = await put_provider_credential(
        provider=_OPENROUTER_PROVIDER,
        request=ProviderCredentialUpsertRequest(secret=request.api_key),
        current_user=current_user,
    )
    return _to_openrouter_status(status)


@router.delete(
    "/api/settings/integrations/openrouter",
    response_model=dict[str, bool],
    summary="Delete OpenRouter credential",
)
async def delete_openrouter_credential(
    current_user: CurrentUser = Depends(require_current_user),
) -> dict[str, bool]:
    """Compatibility wrapper backed by generic provider settings."""
    payload = await delete_provider_credential(
        provider=_OPENROUTER_PROVIDER,
        current_user=current_user,
    )
    return {"deleted": payload.deleted}


@router.get(
    "/api/settings/integrations/email-source",
    response_model=EmailSourceStatus,
    summary="Get email source integration status",
)
async def get_email_source_integration(
    current_user: CurrentUser = Depends(require_current_user),
) -> EmailSourceStatus:
    try:
        return EmailSourceStatus(**await get_email_source_status(current_user.user_id))
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.put(
    "/api/settings/integrations/email-source",
    response_model=EmailSourceStatus,
    summary="Store email source IMAP settings",
)
async def put_email_source_integration(
    request: EmailSourceUpsertRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> EmailSourceStatus:
    try:
        if request.project_id is not None:
            await require_owned_project_id(request.project_id, current_user)
        status = await upsert_email_source(
            current_user.user_id,
            email=request.email,
            app_password=request.app_password,
            host=request.host,
            source_folder=request.source_folder,
            archive_folder=request.archive_folder,
            project_id=request.project_id,
        )
        return EmailSourceStatus(**status)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.delete(
    "/api/settings/integrations/email-source",
    response_model=dict[str, bool],
    summary="Delete email source IMAP settings",
)
async def delete_email_source_integration(
    current_user: CurrentUser = Depends(require_current_user),
) -> dict[str, bool]:
    try:
        await delete_email_source(current_user.user_id)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return {"deleted": True}


@router.post(
    "/api/settings/integrations/email-source/validate",
    response_model=EmailSourceValidateResponse,
    summary="Validate email source IMAP settings",
)
async def validate_email_source_integration(
    current_user: CurrentUser = Depends(require_current_user),
) -> EmailSourceValidateResponse:
    try:
        result = await validate_email_source(current_user.user_id)
        return EmailSourceValidateResponse(**result)
    except EmailSourceConfigurationError as exc:
        return EmailSourceValidateResponse(
            valid=False,
            validation_status="missing",
            message=str(exc),
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get(
    "/api/settings/integrations/{provider}",
    response_model=ProviderCredentialStatus,
    summary="Get provider credential status",
)
async def get_provider_credential(
    provider: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> ProviderCredentialStatus:
    try:
        return await ai_runtime_service.get_provider_status(
            user_id=current_user.user_id,
            provider=provider,
        )
    except AIRuntimeServiceError as exc:
        _raise_runtime_error(exc)


@router.put(
    "/api/settings/integrations/{provider}",
    response_model=ProviderCredentialStatus,
    summary="Store provider credential",
)
async def put_provider_credential(
    provider: str,
    request: ProviderCredentialUpsertRequest,
    current_user: CurrentUser = Depends(require_current_user),
) -> ProviderCredentialStatus:
    try:
        return await ai_runtime_service.upsert_provider_secret(
            user_id=current_user.user_id,
            provider=provider,
            secret=request.secret,
        )
    except AIRuntimeServiceError as exc:
        _raise_runtime_error(exc)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.delete(
    "/api/settings/integrations/{provider}",
    response_model=ProviderCredentialDeleteResponse,
    summary="Delete provider credential",
)
async def delete_provider_credential(
    provider: str,
    current_user: CurrentUser = Depends(require_current_user),
) -> ProviderCredentialDeleteResponse:
    try:
        payload = await ai_runtime_service.delete_provider_secret(
            user_id=current_user.user_id,
            provider=provider,
        )
    except AIRuntimeServiceError as exc:
        _raise_runtime_error(exc)
    return ProviderCredentialDeleteResponse(**payload)


@router.post(
    "/api/settings/integrations/openrouter/validate",
    response_model=OpenRouterCredentialValidateResponse,
    summary="Validate stored OpenRouter credential",
)
async def validate_openrouter_credential(
    current_user: CurrentUser = Depends(require_current_user),
) -> OpenRouterCredentialValidateResponse:
    try:
        api_key = await user_key_store.get_secret(
            current_user.user_id,
            provider=_OPENROUTER_PROVIDER,
        )
    except RuntimeError:
        api_key = None
    if not api_key:
        return OpenRouterCredentialValidateResponse(
            provider="openrouter",
            valid=False,
            validation_status="missing",
            message="No OpenRouter key configured.",
        )

    validation_status = "invalid"
    message = "OpenRouter key is invalid."
    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            response = await client.get(
                _OPENROUTER_MODELS_URL,
                headers={"Authorization": f"Bearer {api_key}"},
            )
        if response.status_code < 400:
            validation_status = "valid"
            message = "OpenRouter key is valid."
    except Exception:
        validation_status = "invalid"
        message = "OpenRouter validation request failed."

    try:
        await user_key_store.set_validation_status(
            current_user.user_id,
            provider=_OPENROUTER_PROVIDER,
            validation_status=validation_status,
        )
    except RuntimeError:
        pass
    return OpenRouterCredentialValidateResponse(
        provider="openrouter",
        valid=validation_status == "valid",
        validation_status=validation_status,
        message=message,
    )
