"""Per-user email source integration settings for IMAP inbox ingestion."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from api.services.user_data_store import user_data_store
from api.services.user_key_store import user_key_store

EMAIL_SOURCE_PASSWORD_PROVIDER = "email_source_imap_password"
EMAIL_SOURCE_SETTINGS_KEY = "emailSource"
EMAIL_SOURCE_SCHEDULE_MANAGED_BY = "email_source"
EMAIL_SOURCE_SCHEDULE_JOB_TYPE = "ingest_newsletters"

DEFAULT_IMAP_HOST = "imap.gmail.com"
DEFAULT_SOURCE_FOLDER = "Newsletters"
DEFAULT_ARCHIVE_FOLDER = "CONTENTGLOWS_DONE"
DEFAULT_SCAN_DAYS = 7
DEFAULT_MAX_RESULTS = 20


class EmailSourceConfigurationError(RuntimeError):
    """Raised when the current user has no usable email source config."""


def _normalized_metadata(payload: dict[str, Any] | None) -> dict[str, Any]:
    data = payload or {}
    email = str(data.get("email") or "").strip()
    host = str(data.get("host") or DEFAULT_IMAP_HOST).strip() or DEFAULT_IMAP_HOST
    source_folder = (
        str(data.get("sourceFolder") or data.get("source_folder") or DEFAULT_SOURCE_FOLDER)
        .strip()
        or DEFAULT_SOURCE_FOLDER
    )
    archive_folder = (
        str(data.get("archiveFolder") or data.get("archive_folder") or DEFAULT_ARCHIVE_FOLDER)
        .strip()
        or DEFAULT_ARCHIVE_FOLDER
    )
    project_id = data.get("projectId") or data.get("project_id")
    project_id = str(project_id).strip() if project_id else None
    return {
        "email": email,
        "host": host,
        "sourceFolder": source_folder,
        "archiveFolder": archive_folder,
        "projectId": project_id or None,
    }


def _find_managed_email_source_job(svc, user_id: str) -> dict[str, Any] | None:
    for job in svc.list_schedule_jobs(user_id=user_id):
        if job.get("job_type") != EMAIL_SOURCE_SCHEDULE_JOB_TYPE:
            continue
        config = job.get("configuration") or {}
        if config.get("managed_by") == EMAIL_SOURCE_SCHEDULE_MANAGED_BY:
            return job
    return None


def _schedule_configuration(metadata: dict[str, Any]) -> dict[str, Any]:
    return {
        "managed_by": EMAIL_SOURCE_SCHEDULE_MANAGED_BY,
        "days_back": DEFAULT_SCAN_DAYS,
        "max_results": DEFAULT_MAX_RESULTS,
        "folder": metadata.get("sourceFolder") or DEFAULT_SOURCE_FOLDER,
        "archive_folder": metadata.get("archiveFolder") or DEFAULT_ARCHIVE_FOLDER,
    }


async def ensure_email_source_schedule_job(
    user_id: str,
    *,
    project_id: str | None,
    metadata: dict[str, Any],
) -> dict[str, Any]:
    from status.service import get_status_service

    svc = get_status_service()
    existing = _find_managed_email_source_job(svc, user_id)
    payload = {
        "project_id": project_id,
        "configuration": _schedule_configuration(metadata),
        "schedule": "every_6_hours",
        "schedule_time": None,
        "timezone": "UTC",
        "enabled": True,
    }
    if existing:
        return svc.update_schedule_job(existing["id"], **payload)
    return svc.create_schedule_job(
        user_id=user_id,
        job_type=EMAIL_SOURCE_SCHEDULE_JOB_TYPE,
        next_run_at=datetime.utcnow().isoformat(),
        **payload,
    )


async def delete_email_source_schedule_job(user_id: str) -> None:
    from status.service import ContentNotFoundError, get_status_service

    svc = get_status_service()
    existing = _find_managed_email_source_job(svc, user_id)
    if not existing:
        return
    try:
        svc.delete_schedule_job(existing["id"])
    except ContentNotFoundError:
        return


async def get_email_source_metadata(user_id: str) -> dict[str, Any]:
    settings = await user_data_store.get_user_settings(user_id)
    robot_settings = settings.get("robotSettings")
    if not isinstance(robot_settings, dict):
        return _normalized_metadata(None)
    raw = robot_settings.get(EMAIL_SOURCE_SETTINGS_KEY)
    return _normalized_metadata(raw if isinstance(raw, dict) else None)


async def get_email_source_status(user_id: str) -> dict[str, Any]:
    metadata = await get_email_source_metadata(user_id)
    credential = await user_key_store.get_credential_status(
        user_id,
        provider=EMAIL_SOURCE_PASSWORD_PROVIDER,
    )
    configured = bool(metadata.get("email") and credential)
    return {
        "configured": configured,
        "email": metadata.get("email") or None,
        "host": metadata.get("host") or DEFAULT_IMAP_HOST,
        "sourceFolder": metadata.get("sourceFolder") or DEFAULT_SOURCE_FOLDER,
        "archiveFolder": metadata.get("archiveFolder") or DEFAULT_ARCHIVE_FOLDER,
        "projectId": metadata.get("projectId"),
        "validationStatus": (
            credential.get("validation_status", "unknown") if credential else "missing"
        ),
        "lastValidatedAt": credential.get("last_validated_at") if credential else None,
        "updatedAt": credential.get("updated_at") if credential else None,
    }


async def upsert_email_source(
    user_id: str,
    *,
    email: str,
    app_password: str | None = None,
    host: str = DEFAULT_IMAP_HOST,
    source_folder: str = DEFAULT_SOURCE_FOLDER,
    archive_folder: str = DEFAULT_ARCHIVE_FOLDER,
    project_id: str | None = None,
) -> dict[str, Any]:
    email = email.strip()
    if "@" not in email:
        raise ValueError("A valid email address is required.")
    if not project_id:
        settings = await user_data_store.get_user_settings(user_id)
        project_id = settings.get("defaultProjectId")
    metadata = _normalized_metadata(
        {
            "email": email,
            "host": host,
            "sourceFolder": source_folder,
            "archiveFolder": archive_folder,
            "projectId": project_id,
        }
    )

    if app_password is not None and app_password.strip():
        await user_key_store.upsert_secret(
            user_id,
            provider=EMAIL_SOURCE_PASSWORD_PROVIDER,
            secret=app_password.strip(),
            validation_status="unknown",
        )
    else:
        existing = await user_key_store.get_credential_status(
            user_id,
            provider=EMAIL_SOURCE_PASSWORD_PROVIDER,
        )
        if not existing:
            raise ValueError("An app password is required for the first email connection.")

    await user_data_store.update_user_settings(
        user_id,
        {"robotSettings": {EMAIL_SOURCE_SETTINGS_KEY: metadata}},
    )
    await ensure_email_source_schedule_job(
        user_id,
        project_id=metadata.get("projectId"),
        metadata=metadata,
    )
    return await get_email_source_status(user_id)


async def delete_email_source(user_id: str) -> None:
    await user_key_store.delete_credential(
        user_id,
        provider=EMAIL_SOURCE_PASSWORD_PROVIDER,
    )
    await user_data_store.update_user_settings(
        user_id,
        {"robotSettings": {EMAIL_SOURCE_SETTINGS_KEY: None}},
    )
    await delete_email_source_schedule_job(user_id)


async def get_email_source_secret(user_id: str) -> str | None:
    return await user_key_store.get_secret(
        user_id,
        provider=EMAIL_SOURCE_PASSWORD_PROVIDER,
    )


async def require_email_source_config(user_id: str) -> dict[str, Any]:
    metadata = await get_email_source_metadata(user_id)
    password = await get_email_source_secret(user_id)
    if not metadata.get("email") or not password:
        raise EmailSourceConfigurationError(
            "Connect an email source before scanning or ingesting inbox content."
        )
    return {**metadata, "appPassword": password}


async def set_email_source_validation_status(
    user_id: str,
    validation_status: str,
) -> dict[str, Any]:
    await user_key_store.set_validation_status(
        user_id,
        provider=EMAIL_SOURCE_PASSWORD_PROVIDER,
        validation_status=validation_status,
    )
    return await get_email_source_status(user_id)


async def validate_email_source(user_id: str) -> dict[str, Any]:
    from agents.newsletter.tools.imap_tools import IMAPNewsletterReader

    config = await require_email_source_config(user_id)
    status = "invalid"
    message = "Email source validation failed."
    try:
        reader = IMAPNewsletterReader(
            email=config["email"],
            app_password=config["appPassword"],
            host=config["host"],
        )
        reader.validate_connection(folder=config["sourceFolder"])
        status = "valid"
        message = "Email source is valid."
    except Exception as exc:
        await set_email_source_validation_status(user_id, "invalid")
        return {
            "valid": False,
            "validationStatus": "invalid",
            "message": f"{message} {str(exc)}",
        }

    await set_email_source_validation_status(user_id, status)
    return {"valid": True, "validationStatus": status, "message": message}
