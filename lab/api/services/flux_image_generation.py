"""Black Forest Labs FLUX image generation integration."""

from __future__ import annotations

import base64
import binascii
import ipaddress
import json
import os
import socket
import tempfile
import time
from dataclasses import dataclass, field
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests

from api.models.ai_usage import (
    ProviderCostConfidence,
    ProviderCostMetadata,
    ProviderCostUnit,
)


SUPPORTED_OUTPUT_FORMATS = {"jpeg", "png", "webp"}
MAX_REFERENCE_IMAGES = 8
DEFAULT_FLUX_MODEL = "flux-2-pro"
DEFAULT_BFL_BASE_URL = "https://api.bfl.ai/v1"
DEFAULT_MAX_DOWNLOAD_BYTES = 25 * 1024 * 1024


class FluxImageGenerationError(Exception):
    """Normalized provider error safe to expose to API clients."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        status_code: int | None = None,
        provider_metadata: dict[str, Any] | None = None,
        provider_request_id: str | None = None,
        provider_cost_metadata: ProviderCostMetadata | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.provider_metadata = provider_metadata or {}
        self.provider_request_id = provider_request_id
        self.provider_cost_metadata = provider_cost_metadata


@dataclass
class FluxGenerationResult:
    """Successful FLUX output stored as a local temporary file."""

    local_path: str
    provider_request_id: str
    model: str
    width: int
    height: int
    output_format: str
    seed: int | None = None
    provider_cost: float | None = None
    provider_cost_metadata: ProviderCostMetadata | None = None
    provider_metadata: dict[str, Any] = field(default_factory=dict)
    started_at: datetime | None = None
    completed_at: datetime | None = None
    duration_ms: int | None = None


class FluxImageGenerator:
    """Synchronous FLUX client used from FastAPI background tasks."""

    def __init__(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
        poll_interval_seconds: float | None = None,
        timeout_seconds: int | None = None,
        max_download_bytes: int | None = None,
    ) -> None:
        self.api_key = api_key or os.getenv("BFL_API_KEY") or os.getenv("BLACK_FOREST_LABS_API_KEY")
        self.base_url = (base_url or os.getenv("BFL_API_BASE_URL") or DEFAULT_BFL_BASE_URL).rstrip("/")
        self.model = model or os.getenv("BFL_IMAGE_MODEL") or os.getenv("FLUX_IMAGE_MODEL") or DEFAULT_FLUX_MODEL
        self.poll_interval_seconds = poll_interval_seconds or float(os.getenv("BFL_POLL_INTERVAL_SECONDS", "1.0"))
        self.timeout_seconds = timeout_seconds or int(os.getenv("BFL_GENERATION_TIMEOUT_SECONDS", "180"))
        self.max_download_bytes = max_download_bytes or int(
            os.getenv("BFL_MAX_RESULT_DOWNLOAD_BYTES", str(DEFAULT_MAX_DOWNLOAD_BYTES))
        )

    def generate_to_file(
        self,
        *,
        prompt: str,
        width: int,
        height: int,
        seed: int | None = None,
        output_format: str = "jpeg",
        reference_urls: list[str] | None = None,
        safety_tolerance: int = 2,
    ) -> FluxGenerationResult:
        """Submit a FLUX request, poll until ready, and download the signed output URL."""
        if not self.api_key:
            raise FluxImageGenerationError(
                "provider_not_configured",
                "BFL_API_KEY is not configured.",
            )

        output_format = output_format.lower()
        if output_format not in SUPPORTED_OUTPUT_FORMATS:
            raise FluxImageGenerationError(
                "invalid_output_format",
                f"Unsupported FLUX output format: {output_format}",
            )
        if width < 64 or height < 64 or width % 16 != 0 or height % 16 != 0:
            raise FluxImageGenerationError(
                "invalid_dimensions",
                "FLUX dimensions must be at least 64px and multiples of 16.",
            )

        references = (reference_urls or [])[:MAX_REFERENCE_IMAGES]
        payload = self._build_payload(
            prompt=prompt,
            width=width,
            height=height,
            seed=seed,
            output_format=output_format,
            reference_urls=references,
            safety_tolerance=safety_tolerance,
        )
        started_at = datetime.now(UTC)
        started_monotonic = time.monotonic()
        try:
            submitted = self._submit(payload)
        except FluxImageGenerationError as exc:
            failed_at = datetime.now(UTC)
            exc.provider_metadata = {
                **exc.provider_metadata,
                "request_started_at": started_at.isoformat(),
                "failed_at": failed_at.isoformat(),
                "duration_ms": round((time.monotonic() - started_monotonic) * 1000),
                "actual_cost_unknown": True,
            }
            raise
        submitted_at = datetime.now(UTC)
        request_id = str(submitted.get("id") or "")
        polling_url = submitted.get("polling_url")
        if not request_id or not polling_url:
            raise FluxImageGenerationError(
                "provider_bad_response",
                "FLUX response did not include id and polling_url.",
                provider_metadata=_redacted_metadata(submitted),
            )

        provider_cost_metadata = normalize_bfl_cost_metadata(
            submitted,
            model=self.model,
            provider_request_id=request_id,
            captured_at=submitted_at,
        )
        try:
            result_payload = self._poll_until_ready(
                polling_url=str(polling_url),
                provider_request_id=request_id,
            )
            sample_url = _extract_sample_url(result_payload)
            if sample_url.startswith("/") and Path(sample_url).exists():
                local_path = sample_url
            else:
                local_path = self._download_result(sample_url, output_format=output_format)
        except FluxImageGenerationError as exc:
            failed_at = datetime.now(UTC)
            if exc.provider_request_id is None:
                exc.provider_request_id = request_id
            if exc.provider_cost_metadata is None:
                exc.provider_cost_metadata = provider_cost_metadata
            exc.provider_metadata = {
                **exc.provider_metadata,
                "cost_evidence": provider_cost_metadata.model_dump(
                    mode="json",
                    by_alias=True,
                ),
                "request_started_at": started_at.isoformat(),
                "submitted_at": submitted_at.isoformat(),
                "failed_at": failed_at.isoformat(),
                "duration_ms": round((time.monotonic() - started_monotonic) * 1000),
            }
            raise
        completed_at = datetime.now(UTC)
        duration_ms = round((time.monotonic() - started_monotonic) * 1000)
        provider_metadata = {
            "submit": _redacted_metadata(submitted),
            "result": _redacted_metadata(result_payload),
            "cost_evidence": provider_cost_metadata.model_dump(
                mode="json",
                by_alias=True,
            ),
            "request_started_at": started_at.isoformat(),
            "submitted_at": submitted_at.isoformat(),
            "completed_at": completed_at.isoformat(),
            "duration_ms": duration_ms,
        }
        return FluxGenerationResult(
            local_path=local_path,
            provider_request_id=request_id,
            model=self.model,
            width=width,
            height=height,
            seed=seed,
            output_format=output_format,
            provider_cost=(
                float(provider_cost_metadata.actual_cost)
                if provider_cost_metadata.actual_cost is not None
                else None
            ),
            provider_cost_metadata=provider_cost_metadata,
            provider_metadata=provider_metadata,
            started_at=started_at,
            completed_at=completed_at,
            duration_ms=duration_ms,
        )

    def _build_payload(
        self,
        *,
        prompt: str,
        width: int,
        height: int,
        seed: int | None,
        output_format: str,
        reference_urls: list[str],
        safety_tolerance: int,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "prompt": prompt,
            "width": width,
            "height": height,
            "output_format": output_format,
            "safety_tolerance": max(0, min(5, safety_tolerance)),
        }
        if seed is not None:
            payload["seed"] = seed
        for index, reference_url in enumerate(reference_urls):
            key = "input_image" if index == 0 else f"input_image_{index + 1}"
            payload[key] = reference_url
        return payload

    def _submit(self, payload: dict[str, Any]) -> dict[str, Any]:
        endpoint = f"{self.base_url}/{self.model}"
        try:
            response = requests.post(
                endpoint,
                headers={
                    "accept": "application/json",
                    "x-key": self.api_key,
                    "Content-Type": "application/json",
                },
                json=payload,
                timeout=(10, 45),
            )
        except requests.Timeout as exc:
            raise FluxImageGenerationError("provider_timeout", "FLUX submit request timed out.") from exc
        except requests.RequestException as exc:
            raise FluxImageGenerationError("provider_unavailable", "FLUX submit request failed.") from exc

        if response.status_code >= 400:
            raise _http_error(response)
        return _json_response(response)

    def _poll_until_ready(self, *, polling_url: str, provider_request_id: str) -> dict[str, Any]:
        deadline = time.monotonic() + self.timeout_seconds
        while time.monotonic() < deadline:
            try:
                response = requests.get(
                    polling_url,
                    headers={"accept": "application/json", "x-key": self.api_key},
                    timeout=(10, 30),
                )
            except requests.Timeout as exc:
                raise FluxImageGenerationError(
                    "provider_timeout",
                    "FLUX polling request timed out.",
                    provider_request_id=provider_request_id,
                ) from exc
            except requests.RequestException as exc:
                raise FluxImageGenerationError(
                    "provider_unavailable",
                    "FLUX polling request failed.",
                    provider_request_id=provider_request_id,
                ) from exc

            if response.status_code >= 400:
                error = _http_error(response)
                error.provider_request_id = provider_request_id
                raise error

            payload = _json_response(response)
            status = str(payload.get("status", "")).lower()
            if status in {"ready", "succeeded", "completed", "success"}:
                return payload
            if status in {"error", "failed", "rejected", "content_moderated"}:
                raise FluxImageGenerationError(
                    "provider_rejected",
                    "FLUX generation failed.",
                    provider_metadata=_redacted_metadata(payload),
                    provider_request_id=provider_request_id,
                )
            time.sleep(self.poll_interval_seconds)

        raise FluxImageGenerationError(
            "provider_timeout",
            "FLUX generation timed out before completion.",
            provider_request_id=provider_request_id,
        )

    def _download_result(self, sample_url: str, *, output_format: str) -> str:
        parsed = _validate_public_url(sample_url)
        suffix = ".jpg" if output_format == "jpeg" else f".{output_format}"
        try:
            response = requests.get(sample_url, timeout=(10, 45), stream=True)
            response.raise_for_status()
            content_type = response.headers.get("Content-Type", "").split(";")[0].strip().lower()
            if content_type and not content_type.startswith("image/"):
                raise FluxImageGenerationError(
                    "provider_bad_response",
                    f"FLUX result was not an image: {content_type}",
                )

            with tempfile.NamedTemporaryFile(prefix="flux-", suffix=suffix, delete=False) as handle:
                total = 0
                for chunk in response.iter_content(chunk_size=1024 * 64):
                    if not chunk:
                        continue
                    total += len(chunk)
                    if total > self.max_download_bytes:
                        path = handle.name
                        handle.close()
                        Path(path).unlink(missing_ok=True)
                        raise FluxImageGenerationError(
                            "provider_result_too_large",
                            "FLUX result exceeded the configured download size limit.",
                        )
                    handle.write(chunk)
                return handle.name
        except FluxImageGenerationError:
            raise
        except requests.Timeout as exc:
            raise FluxImageGenerationError("provider_timeout", "FLUX result download timed out.") from exc
        except requests.RequestException as exc:
            raise FluxImageGenerationError(
                "provider_unavailable",
                f"FLUX result download failed for {parsed.netloc}.",
            ) from exc


def image_type_dimensions(image_type: str) -> tuple[int, int]:
    """Return FLUX-safe dimensions aligned to common ContentGlows placements."""
    mapping = {
        "hero_image": (1536, 864),
        "section_image": (1280, 720),
        "og_card": (1200, 672),
        "thumbnail": (1280, 720),
    }
    return mapping.get(image_type, (1280, 720))


def _extract_sample_url(payload: dict[str, Any]) -> str:
    result = payload.get("result")
    if isinstance(result, dict):
        sample = result.get("sample") or result.get("url")
        if sample:
            return str(sample)
    for key in ("sample", "url", "image_url"):
        if payload.get(key):
            return str(payload[key])
    encoded = payload.get("image") or payload.get("image_base64")
    if encoded:
        return _base64_to_tempfile(str(encoded))
    raise FluxImageGenerationError(
        "provider_bad_response",
        "FLUX ready response did not include an image URL or base64 payload.",
        provider_metadata=_redacted_metadata(payload),
    )


def _base64_to_tempfile(encoded: str) -> str:
    try:
        data = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise FluxImageGenerationError(
            "provider_bad_response",
            "FLUX base64 result could not be decoded.",
        ) from exc
    with tempfile.NamedTemporaryFile(prefix="flux-", suffix=".png", delete=False) as handle:
        handle.write(data)
        return handle.name


def _http_error(response: requests.Response) -> FluxImageGenerationError:
    status_code = response.status_code
    code = "provider_error"
    if status_code == 400 or status_code == 422:
        code = "provider_rejected"
    elif status_code in {401, 403}:
        code = "provider_auth_error"
    elif status_code == 402:
        code = "provider_credit_exhausted"
    elif status_code == 429:
        code = "provider_rate_limited"
    elif status_code >= 500:
        code = "provider_unavailable"

    metadata: dict[str, Any] = {"status_code": status_code}
    try:
        metadata["body"] = _redacted_metadata(response.json())
    except ValueError:
        metadata["body"] = response.text[:500]
    return FluxImageGenerationError(
        code,
        f"FLUX request failed with HTTP {status_code}.",
        status_code=status_code,
        provider_metadata=metadata,
    )


def _json_response(response: requests.Response) -> dict[str, Any]:
    try:
        payload = response.json()
    except ValueError as exc:
        raise FluxImageGenerationError(
            "provider_bad_response",
            "FLUX response was not valid JSON.",
        ) from exc
    if not isinstance(payload, dict):
        raise FluxImageGenerationError(
            "provider_bad_response",
            "FLUX response had an unexpected JSON shape.",
        )
    return payload


def _validate_public_url(url: str):
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise FluxImageGenerationError(
            "provider_bad_response",
            "FLUX result URL must be an absolute http(s) URL.",
        )
    try:
        infos = socket.getaddrinfo(parsed.hostname, None)
    except socket.gaierror as exc:
        raise FluxImageGenerationError(
            "provider_bad_response",
            "FLUX result URL host could not be resolved.",
        ) from exc
    for info in infos:
        address = info[4][0]
        ip = ipaddress.ip_address(address)
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved:
            raise FluxImageGenerationError(
                "provider_bad_response",
                "FLUX result URL resolved to a non-public address.",
            )
    return parsed


def normalize_bfl_cost_metadata(
    submitted: dict[str, Any],
    *,
    model: str,
    provider_request_id: str,
    captured_at: datetime | None = None,
) -> ProviderCostMetadata:
    """Normalize BFL response evidence without converting credits to money."""
    cost = _coerce_non_negative_decimal(submitted.get("cost"))
    input_mp = _coerce_non_negative_decimal(submitted.get("input_mp"))
    output_mp = _coerce_non_negative_decimal(submitted.get("output_mp"))
    return ProviderCostMetadata(
        provider="bfl",
        provider_action="flux_image_generation",
        model=model,
        provider_request_id=provider_request_id,
        actual_cost=cost,
        cost_unit=ProviderCostUnit.PROVIDER_CREDIT,
        input_mp=input_mp,
        output_mp=output_mp,
        confidence=(
            ProviderCostConfidence.EXACT
            if cost is not None
            else ProviderCostConfidence.UNKNOWN
        ),
        captured_at=captured_at or datetime.now(UTC),
        evidence={
            "cost_source": "bfl_submit_response",
            "actual_cost_unknown": cost is None,
            "input_mp_unknown": input_mp is None,
            "output_mp_unknown": output_mp is None,
        },
    )


def _coerce_non_negative_decimal(value: Any) -> Decimal | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        normalized = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return None
    if not normalized.is_finite() or normalized < 0:
        return None
    return normalized


def _redacted_metadata(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {"value": str(value)[:500]}
    redacted = json.loads(json.dumps(value, default=str))
    for key in ("sample", "url", "image", "image_base64"):
        if key in redacted:
            redacted[key] = "<redacted>"
    result = redacted.get("result")
    if isinstance(result, dict):
        for key in ("sample", "url", "image", "image_base64"):
            if key in result:
                result[key] = "<redacted>"
    return redacted
