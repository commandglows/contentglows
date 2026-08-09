"""Server-authoritative placement planning and publish media resolution."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

from api.models.social_placements import (
    PlacementIssue,
    PlacementPlan,
    PlacementSlot,
    PlatformPlacementPlan,
    ProviderMediaItemSummary,
    PublishPlatformPreflight,
    PublishPreflightResponse,
    ResolvedProviderMediaItem,
)
from api.services.project_asset_storage import (
    ProjectAssetDeliveryError,
    resolve_project_asset_delivery_url,
)
from api.services.social_placement_registry import (
    PLATFORM_BY_ID,
    PLACEMENT_BY_ID,
    REGISTRY_VERSION,
    PlacementRule,
    rules_for,
    validate_format_id,
    validate_platform_id,
)


PFL_MISSING_REQUIRED = "PFL_MISSING_REQUIRED"
PFL_ASSET_NOT_FOUND = "PFL_ASSET_NOT_FOUND"
PFL_ASSET_FORBIDDEN = "PFL_ASSET_FORBIDDEN"
PFL_ASSET_STATUS_BLOCKED = "PFL_ASSET_STATUS_BLOCKED"
PFL_ASSET_INCOMPATIBLE = "PFL_ASSET_INCOMPATIBLE"
PFL_STORAGE_UNAVAILABLE = "PFL_STORAGE_UNAVAILABLE"
PFL_REGISTRY_STALE = "PFL_REGISTRY_STALE"
PFL_UNSUPPORTED_PLATFORM = "PFL_UNSUPPORTED_PLATFORM"
PFL_PROVIDER_CONTRACT_UNSUPPORTED = "PFL_PROVIDER_CONTRACT_UNSUPPORTED"
PFL_LEGACY_CONFLICT = "PFL_LEGACY_CONFLICT"


CONTENT_FORMAT_ALIASES = {
    "article": "FMT_ARTICLE",
    "seo-content": "FMT_ARTICLE",
    "newsletter": "FMT_NEWSLETTER",
    "video_script": "FMT_VIDEO",
    "short": "FMT_SHORT",
    "social_post": "FMT_SOCIAL_POST",
    "manual": "FMT_SOCIAL_POST",
    "image": "FMT_SOCIAL_POST",
}

MEDIA_FAMILIES = {
    "image": "image",
    "thumbnail": "image",
    "video_cover": "image",
    "capture": "image",
    "video": "video",
    "render_output": "video",
    "audio": "audio",
    "music": "audio",
}


@dataclass(frozen=True)
class PreflightResult:
    response: PublishPreflightResponse
    resolved_media_items: tuple[ResolvedProviderMediaItem, ...]


def _value(value: Any) -> str:
    return str(getattr(value, "value", value) or "")


def resolve_content_format(content: Any) -> str:
    metadata = getattr(content, "metadata", {})
    if isinstance(metadata, dict) and metadata.get("format_id"):
        return validate_format_id(str(metadata["format_id"]))
    raw = _value(getattr(content, "content_type", ""))
    if raw in CONTENT_FORMAT_ALIASES:
        return CONTENT_FORMAT_ALIASES[raw]
    return validate_format_id(raw)


def build_placement_plan(
    *, content: Any, platform_ids: Iterable[str], locale: str = "en"
) -> PlacementPlan:
    format_id = resolve_content_format(content)
    platforms: list[PlatformPlacementPlan] = []
    for value in platform_ids:
        platform_id = validate_platform_id(value)
        platform = PLATFORM_BY_ID[platform_id]
        slots = [_slot_for_rule(rule, locale=locale) for rule in rules_for(format_id, platform_id)]
        platforms.append(
            PlatformPlacementPlan(
                platform_id=platform_id,
                label=platform.label(locale),
                slots=slots,
            )
        )
    return PlacementPlan(
        registry_version=REGISTRY_VERSION,
        content_id=str(content.id),
        format_id=format_id,
        locale=locale,
        platforms=platforms,
    )


def run_publish_preflight(
    *,
    status_service: Any,
    content: Any,
    user_id: str,
    platform_ids: Iterable[str],
    requested_registry_version: str | None = None,
) -> PreflightResult:
    format_id = resolve_content_format(content)
    project_id = str(content.project_id)
    primary_pairs = status_service.list_primary_project_asset_usages(
        project_id=project_id,
        user_id=user_id,
        content_id=str(content.id),
    )
    primaries = {
        str(usage.placement): (usage, asset)
        for usage, asset in primary_pairs
        if usage.placement
    }
    all_issues: list[PlacementIssue] = []
    results: list[PublishPlatformPreflight] = []
    resolved: list[ResolvedProviderMediaItem] = []

    canonical_platforms = [validate_platform_id(value) for value in platform_ids]
    if requested_registry_version and requested_registry_version != REGISTRY_VERSION:
        for platform_id in canonical_platforms:
            all_issues.append(
                _issue(
                    PFL_REGISTRY_STALE,
                    "blocking",
                    platform_id,
                    message="The placement registry changed; refresh the plan before publishing.",
                )
            )

    for platform_id in canonical_platforms:
        platform_issues = [i for i in all_issues if i.platform_id == platform_id]
        slots: list[PlacementSlot] = []
        platform_media: list[ResolvedProviderMediaItem] = []
        for rule in rules_for(format_id, platform_id):
            usage, asset = primaries.get(rule.placement_id, (None, None))
            slot, media = _evaluate_rule(rule=rule, usage=usage, asset=asset)
            slots.append(slot)
            platform_issues.extend(slot.issues)
            if media is not None:
                platform_media.append(media)

        deduped: list[ResolvedProviderMediaItem] = []
        seen = set()
        for item in platform_media:
            key = (item.type, item.url)
            if key not in seen:
                seen.add(key)
                deduped.append(item)
        resolved.extend(deduped)
        can_publish = not any(issue.severity == "blocking" for issue in platform_issues)
        results.append(
            PublishPlatformPreflight(
                platform_id=platform_id,
                can_publish=can_publish,
                slots=slots,
                issues=platform_issues,
                media_items=[
                    ProviderMediaItemSummary(
                        type=item.type,
                        placement_id=item.placement_id,
                        asset_id=item.asset_id,
                    )
                    for item in deduped
                ],
            )
        )
        all_issues.extend(issue for issue in platform_issues if issue not in all_issues)

    response = PublishPreflightResponse(
        can_publish=all(result.can_publish for result in results),
        registry_version=REGISTRY_VERSION,
        content_id=str(content.id),
        format_id=format_id,
        platforms=results,
        issues=all_issues,
    )
    return PreflightResult(response=response, resolved_media_items=tuple(resolved))


def _slot_for_rule(rule: PlacementRule, *, locale: str) -> PlacementSlot:
    placement = PLACEMENT_BY_ID[rule.placement_id]
    return PlacementSlot(
        placement_id=rule.placement_id,
        label=placement.label(locale),
        required=rule.required,
        recommended=rule.recommended,
        media_kinds=list(rule.media_kinds),
        provider_media_intent=rule.provider_media_intent,
        rule_strictness=rule.rule_strictness,
    )


def _evaluate_rule(
    *, rule: PlacementRule, usage: Any, asset: Any
) -> tuple[PlacementSlot, ResolvedProviderMediaItem | None]:
    slot = _slot_for_rule(rule, locale="en")
    if usage is None:
        if rule.required:
            slot.issues.append(
                _issue(
                    PFL_MISSING_REQUIRED,
                    "blocking",
                    rule.platform_id,
                    placement_id=rule.placement_id,
                    message="A required media placement has no selected primary asset.",
                )
            )
            slot.state = "missing_required"
        elif rule.recommended:
            slot.issues.append(
                _issue(
                    PFL_MISSING_REQUIRED,
                    "warning",
                    rule.platform_id,
                    placement_id=rule.placement_id,
                    message="A recommended media placement has no selected primary asset.",
                )
            )
            slot.state = "missing_recommended"
        return slot, None

    slot.selected_asset_id = str(usage.asset_id)
    if asset is None:
        slot.state = "blocked"
        slot.issues.append(
            _issue(
                PFL_ASSET_NOT_FOUND,
                "blocking" if rule.required else "warning",
                rule.platform_id,
                placement_id=rule.placement_id,
                asset_id=str(usage.asset_id),
                message="The selected asset is unavailable in this project.",
            )
        )
        return slot, None

    status = _value(getattr(asset, "status", ""))
    if status != "active":
        slot.state = "blocked"
        slot.issues.append(
            _issue(
                PFL_ASSET_STATUS_BLOCKED,
                "blocking" if rule.required else "warning",
                rule.platform_id,
                placement_id=rule.placement_id,
                asset_id=str(asset.id),
                message="The selected asset is not active and durable for publishing.",
            )
        )
        return slot, None

    family = MEDIA_FAMILIES.get(_value(getattr(asset, "media_kind", "")))
    if family not in rule.media_kinds:
        slot.state = "incompatible"
        slot.issues.append(
            _issue(
                PFL_ASSET_INCOMPATIBLE,
                "blocking" if rule.required else "warning",
                rule.platform_id,
                placement_id=rule.placement_id,
                asset_id=str(asset.id),
                message="The selected asset media kind is incompatible with this placement.",
            )
        )
        return slot, None

    mime_type = str(getattr(asset, "mime_type", "") or "").lower()
    if mime_type and not any(mime_type.startswith(f"{item}/") for item in rule.mime_families):
        slot.state = "incompatible"
        slot.issues.append(
            _issue(
                PFL_ASSET_INCOMPATIBLE,
                "blocking" if rule.required else "warning",
                rule.platform_id,
                placement_id=rule.placement_id,
                asset_id=str(asset.id),
                message="The selected asset MIME family is incompatible with this placement.",
            )
        )
        return slot, None

    if not mime_type:
        slot.issues.append(
            _issue(
                PFL_ASSET_INCOMPATIBLE,
                "warning",
                rule.platform_id,
                placement_id=rule.placement_id,
                asset_id=str(asset.id),
                message="The asset MIME metadata is missing; provider validation remains advisory.",
            )
        )

    if family not in {"image", "video"}:
        slot.state = "provider_unsupported"
        slot.issues.append(
            _issue(
                PFL_PROVIDER_CONTRACT_UNSUPPORTED,
                "blocking" if rule.required else "warning",
                rule.platform_id,
                placement_id=rule.placement_id,
                asset_id=str(asset.id),
                message="The current publish provider cannot represent this placement.",
            )
        )
        return slot, None

    try:
        url = resolve_project_asset_delivery_url(
            getattr(asset, "storage_uri", None),
            getattr(asset, "storage_locator", None),
        )
    except ProjectAssetDeliveryError:
        slot.state = "storage_unavailable"
        slot.issues.append(
            _issue(
                PFL_STORAGE_UNAVAILABLE,
                "blocking" if rule.required else "warning",
                rule.platform_id,
                placement_id=rule.placement_id,
                asset_id=str(asset.id),
                message="The selected asset has no durable publishable storage descriptor.",
            )
        )
        return slot, None

    slot.state = "attached"
    return slot, ResolvedProviderMediaItem(
        type=family,
        url=url,
        platform_id=rule.platform_id,
        placement_id=rule.placement_id,
        asset_id=str(asset.id),
    )


def _issue(
    code: str,
    severity: str,
    platform_id: str,
    *,
    placement_id: str | None = None,
    asset_id: str | None = None,
    message: str,
) -> PlacementIssue:
    return PlacementIssue(
        code=code,
        severity=severity,
        platform_id=platform_id,
        placement_id=placement_id,
        asset_id=asset_id,
        message=message,
    )
