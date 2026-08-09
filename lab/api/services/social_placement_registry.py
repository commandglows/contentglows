"""Static, versioned identifiers for content formats and publish placements.

The registry is deliberately code-defined for V1.  IDs are the contract shared
by the API, Flutter and persisted asset usages; labels and aliases are only
human-facing compatibility data and may evolve without changing an ID.
"""

from __future__ import annotations

from dataclasses import dataclass
from types import MappingProxyType
from typing import Mapping


REGISTRY_VERSION = "2026-05-13.1"
SUPPORTED_LOCALES = ("en", "fr")


class RegistryLookupError(ValueError):
    """Raised when a supplied registry value cannot be resolved."""

    def __init__(self, kind: str, value: str, supported_ids: tuple[str, ...]):
        self.kind = kind
        self.value = value
        self.supported_ids = supported_ids
        super().__init__(
            f"Unsupported {kind} id {value!r}; expected one of "
            f"{', '.join(supported_ids)}"
        )


def _labels(en: str, fr: str) -> Mapping[str, str]:
    return MappingProxyType({"en": en, "fr": fr})


def _normalize(value: str) -> str:
    """Normalize legacy strings without making IDs case-sensitive."""
    return "_".join(value.strip().lower().replace("-", "_").split())


@dataclass(frozen=True)
class RegistryEntry:
    id: str
    labels: Mapping[str, str]
    aliases: tuple[str, ...] = ()

    def label(self, locale: str = "en") -> str:
        return self.labels.get(locale, self.labels["en"])

    def as_dict(self, locale: str = "en") -> dict[str, object]:
        return {
            "id": self.id,
            "label": self.label(locale),
            "labels": dict(self.labels),
            "aliases": list(self.aliases),
        }


@dataclass(frozen=True)
class PlacementRule:
    """A platform/content-format rule for one stable placement ID."""

    placement_id: str
    platform_id: str
    format_ids: tuple[str, ...]
    required: bool = False
    recommended: bool = False
    media_kinds: tuple[str, ...] = ()
    mime_families: tuple[str, ...] = ()
    recommended_aspect_ratios: tuple[str, ...] = ()
    minimum_width: int | None = None
    minimum_height: int | None = None
    duration_seconds_min: float | None = None
    duration_seconds_max: float | None = None
    provider_media_intent: str = ""
    rule_strictness: str = "advisory"
    last_reviewed_at: str = "2026-05-13"
    doc_sources: tuple[str, ...] = ()

    def as_dict(self) -> dict[str, object]:
        return {
            "placement_id": self.placement_id,
            "platform_id": self.platform_id,
            "format_ids": list(self.format_ids),
            "required": self.required,
            "recommended": self.recommended,
            "media_kinds": list(self.media_kinds),
            "mime_families": list(self.mime_families),
            "recommended_aspect_ratios": list(self.recommended_aspect_ratios),
            "minimum_width": self.minimum_width,
            "minimum_height": self.minimum_height,
            "duration_seconds_min": self.duration_seconds_min,
            "duration_seconds_max": self.duration_seconds_max,
            "provider_media_intent": self.provider_media_intent,
            "rule_strictness": self.rule_strictness,
            "last_reviewed_at": self.last_reviewed_at,
            "doc_sources": list(self.doc_sources),
        }


@dataclass(frozen=True)
class PlacementEntry(RegistryEntry):
    rules: tuple[PlacementRule, ...] = ()

    def as_dict(self, locale: str = "en") -> dict[str, object]:
        result = super().as_dict(locale)
        result["rules"] = [rule.as_dict() for rule in self.rules]
        return result


def _entry(id: str, en: str, fr: str, *aliases: str) -> RegistryEntry:
    return RegistryEntry(id=id, labels=_labels(en, fr), aliases=tuple(aliases))


FORMAT_ENTRIES = (
    _entry("FMT_ARTICLE", "Article", "Article", "article", "blog", "blog_post", "blog_article"),
    _entry(
        "FMT_SOCIAL_POST",
        "Social post",
        "Publication sociale",
        "social",
        "social_post",
        "post",
    ),
    _entry("FMT_NEWSLETTER", "Newsletter", "Newsletter", "newsletter", "email_newsletter"),
    _entry(
        "FMT_VIDEO",
        "Video",
        "Vidéo",
        "video",
        "video_script",
        "long_video",
        "video_post",
    ),
    _entry("FMT_REEL", "Reel", "Reel", "reel", "reels", "instagram_reel"),
    _entry(
        "FMT_SHORT",
        "Short video",
        "Vidéo courte",
        "short",
        "shorts",
        "youtube_short",
        "youtube_shorts",
        "tiktok_short",
    ),
)

PLATFORM_ENTRIES = (
    _entry("PLAT_WORDPRESS", "WordPress", "WordPress", "wordpress", "wp"),
    _entry("PLAT_GHOST", "Ghost", "Ghost", "ghost"),
    _entry("PLAT_X", "X", "X", "x", "twitter", "twitter_x"),
    _entry("PLAT_LINKEDIN", "LinkedIn", "LinkedIn", "linkedin", "li"),
    _entry("PLAT_INSTAGRAM", "Instagram", "Instagram", "instagram", "ig"),
    _entry("PLAT_TIKTOK", "TikTok", "TikTok", "tiktok", "tt"),
    _entry("PLAT_YOUTUBE", "YouTube", "YouTube", "youtube", "yt"),
)


_PLATFORM_DOC_SOURCES: Mapping[str, tuple[str, ...]] = MappingProxyType(
    {
        "PLAT_WORDPRESS": ("shipglows_data/technical/lab/backend-runtime-and-product-apis.md",),
        "PLAT_GHOST": ("shipglows_data/technical/lab/backend-runtime-and-product-apis.md",),
        "PLAT_X": (
            "https://docs.x.com/x-api/media/upload-media",
            "https://docs.x.com/x-api/posts/manage-tweets/introduction",
        ),
        "PLAT_LINKEDIN": (
            "https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/posts-api?view=li-lms-2026-01",
            "https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/videos-api",
        ),
        "PLAT_INSTAGRAM": (
            "https://docs.zernio.com/platforms/instagram",
            "https://developers.facebook.com/docs/instagram-platform/content-publishing/",
        ),
        "PLAT_TIKTOK": (
            "https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide",
        ),
        "PLAT_YOUTUBE": (
            "https://developers.google.com/youtube/v3/docs/videos",
            "https://developers.google.com/youtube/v3/docs/thumbnails/set",
        ),
    }
)


def _rule(
    placement_id: str,
    platform_id: str,
    *format_ids: str,
    required: bool = False,
    recommended: bool = False,
    media_kinds: tuple[str, ...] = (),
    mime_families: tuple[str, ...] = (),
    recommended_aspect_ratios: tuple[str, ...] = (),
    provider_media_intent: str = "",
    rule_strictness: str = "advisory",
) -> PlacementRule:
    return PlacementRule(
        placement_id=placement_id,
        platform_id=platform_id,
        format_ids=format_ids,
        required=required,
        recommended=recommended,
        media_kinds=media_kinds,
        mime_families=mime_families or media_kinds,
        recommended_aspect_ratios=recommended_aspect_ratios,
        provider_media_intent=provider_media_intent,
        rule_strictness=rule_strictness,
        doc_sources=_PLATFORM_DOC_SOURCES[platform_id],
    )


def _placement(
    id: str,
    en: str,
    fr: str,
    aliases: tuple[str, ...],
    rules: tuple[PlacementRule, ...],
) -> PlacementEntry:
    return PlacementEntry(id=id, labels=_labels(en, fr), aliases=aliases, rules=rules)


# Placement IDs are persisted in project_asset_usages and must never be renamed.
PLACEMENT_ENTRIES = (
    _placement(
        "PLC_BLOG_HERO",
        "Blog hero",
        "Visuel principal d’article",
        ("hero", "article_hero", "blog_header"),
        (
            _rule("PLC_BLOG_HERO", "PLAT_WORDPRESS", "FMT_ARTICLE", required=True, media_kinds=("image",), provider_media_intent="hero_image"),
            _rule("PLC_BLOG_HERO", "PLAT_GHOST", "FMT_ARTICLE", required=True, media_kinds=("image",), provider_media_intent="hero_image"),
        ),
    ),
    _placement(
        "PLC_INLINE_IMAGE",
        "Inline image",
        "Image dans le contenu",
        ("inline", "content_image"),
        (
            _rule("PLC_INLINE_IMAGE", "PLAT_WORDPRESS", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="inline_image"),
            _rule("PLC_INLINE_IMAGE", "PLAT_GHOST", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="inline_image"),
        ),
    ),
    _placement(
        "PLC_SOCIAL_POST_IMAGE",
        "Social post image",
        "Image de publication sociale",
        ("post_image", "social_image", "social_post_media"),
        (
            _rule("PLC_SOCIAL_POST_IMAGE", "PLAT_X", "FMT_SOCIAL_POST", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="post_image"),
            _rule("PLC_SOCIAL_POST_IMAGE", "PLAT_LINKEDIN", "FMT_SOCIAL_POST", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="post_image"),
            _rule("PLC_SOCIAL_POST_IMAGE", "PLAT_INSTAGRAM", "FMT_SOCIAL_POST", required=True, media_kinds=("image",), provider_media_intent="post_image"),
            _rule("PLC_SOCIAL_POST_IMAGE", "PLAT_TIKTOK", "FMT_SOCIAL_POST", recommended=True, media_kinds=("image",), provider_media_intent="post_image"),
        ),
    ),
    _placement(
        "PLC_LINK_THUMBNAIL",
        "Link thumbnail",
        "Miniature de lien",
        ("og_card", "og_image", "social_card", "link_preview"),
        (
            _rule("PLC_LINK_THUMBNAIL", "PLAT_WORDPRESS", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="link_thumbnail"),
            _rule("PLC_LINK_THUMBNAIL", "PLAT_GHOST", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="link_thumbnail"),
            _rule("PLC_LINK_THUMBNAIL", "PLAT_X", "FMT_SOCIAL_POST", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="link_thumbnail"),
            _rule("PLC_LINK_THUMBNAIL", "PLAT_LINKEDIN", "FMT_SOCIAL_POST", "FMT_ARTICLE", recommended=True, media_kinds=("image",), provider_media_intent="link_thumbnail"),
        ),
    ),
    _placement(
        "PLC_VIDEO_THUMBNAIL",
        "Video thumbnail",
        "Miniature vidéo",
        ("video_cover", "thumbnail", "video_thumb"),
        (
            _rule("PLC_VIDEO_THUMBNAIL", "PLAT_YOUTUBE", "FMT_VIDEO", "FMT_REEL", "FMT_SHORT", recommended=True, media_kinds=("image",), provider_media_intent="video_thumbnail"),
            _rule("PLC_VIDEO_THUMBNAIL", "PLAT_LINKEDIN", "FMT_VIDEO", recommended=True, media_kinds=("image",), provider_media_intent="video_thumbnail"),
        ),
    ),
    _placement(
        "PLC_VERTICAL_SHORT_VIDEO",
        "Vertical short video",
        "Vidéo courte verticale",
        ("vertical_video", "short_video", "vertical_short", "vertical_short_video"),
        (
            _rule("PLC_VERTICAL_SHORT_VIDEO", "PLAT_TIKTOK", "FMT_REEL", "FMT_SHORT", required=True, media_kinds=("video",), provider_media_intent="video"),
            _rule("PLC_VERTICAL_SHORT_VIDEO", "PLAT_INSTAGRAM", "FMT_REEL", "FMT_SHORT", required=True, media_kinds=("video",), provider_media_intent="video"),
            _rule("PLC_VERTICAL_SHORT_VIDEO", "PLAT_YOUTUBE", "FMT_REEL", "FMT_SHORT", required=True, media_kinds=("video",), provider_media_intent="video"),
        ),
    ),
    _placement(
        "PLC_LANDSCAPE_VIDEO",
        "Landscape video",
        "Vidéo horizontale",
        ("video", "long_video", "landscape"),
        (
            _rule("PLC_LANDSCAPE_VIDEO", "PLAT_YOUTUBE", "FMT_VIDEO", required=True, media_kinds=("video",), provider_media_intent="video"),
            _rule("PLC_LANDSCAPE_VIDEO", "PLAT_LINKEDIN", "FMT_VIDEO", recommended=True, media_kinds=("video",), provider_media_intent="video"),
        ),
    ),
    _placement(
        "PLC_REEL_COVER",
        "Reel cover",
        "Couverture du reel",
        ("cover", "reel_thumbnail", "reel_cover_image"),
        (
            _rule("PLC_REEL_COVER", "PLAT_INSTAGRAM", "FMT_REEL", recommended=True, media_kinds=("image",), provider_media_intent="reel_cover"),
            _rule("PLC_REEL_COVER", "PLAT_TIKTOK", "FMT_REEL", recommended=True, media_kinds=("image",), provider_media_intent="reel_cover"),
        ),
    ),
    _placement(
        "PLC_CAPTION_TRACK",
        "Caption track",
        "Piste de sous-titres",
        ("captions", "subtitles", "subtitle_track"),
        (
            _rule("PLC_CAPTION_TRACK", "PLAT_TIKTOK", "FMT_REEL", "FMT_SHORT", recommended=True, media_kinds=("caption", "text"), provider_media_intent="captions"),
            _rule("PLC_CAPTION_TRACK", "PLAT_INSTAGRAM", "FMT_REEL", "FMT_SHORT", recommended=True, media_kinds=("caption", "text"), provider_media_intent="captions"),
            _rule("PLC_CAPTION_TRACK", "PLAT_YOUTUBE", "FMT_VIDEO", "FMT_REEL", "FMT_SHORT", recommended=True, media_kinds=("caption", "text"), provider_media_intent="captions"),
        ),
    ),
    _placement(
        "PLC_AUDIO_TRACK",
        "Audio track",
        "Piste audio",
        ("audio", "soundtrack", "music_track"),
        (
            _rule("PLC_AUDIO_TRACK", "PLAT_TIKTOK", "FMT_REEL", "FMT_SHORT", recommended=True, media_kinds=("audio",), provider_media_intent="audio"),
            _rule("PLC_AUDIO_TRACK", "PLAT_INSTAGRAM", "FMT_REEL", "FMT_SHORT", recommended=True, media_kinds=("audio",), provider_media_intent="audio"),
            _rule("PLC_AUDIO_TRACK", "PLAT_YOUTUBE", "FMT_VIDEO", "FMT_REEL", "FMT_SHORT", recommended=True, media_kinds=("audio",), provider_media_intent="audio"),
        ),
    ),
)


FORMAT_BY_ID = MappingProxyType({entry.id: entry for entry in FORMAT_ENTRIES})
PLATFORM_BY_ID = MappingProxyType({entry.id: entry for entry in PLATFORM_ENTRIES})
PLACEMENT_BY_ID = MappingProxyType({entry.id: entry for entry in PLACEMENT_ENTRIES})


def _alias_index(entries: tuple[RegistryEntry, ...]) -> Mapping[str, RegistryEntry]:
    index: dict[str, RegistryEntry] = {}
    for entry in entries:
        for value in (entry.id, *entry.aliases):
            key = _normalize(value)
            if key in index and index[key].id != entry.id:
                raise RuntimeError(f"Registry alias collision: {value!r}")
            index[key] = entry
    return MappingProxyType(index)


FORMAT_BY_ALIAS = _alias_index(FORMAT_ENTRIES)
PLATFORM_BY_ALIAS = _alias_index(PLATFORM_ENTRIES)
PLACEMENT_BY_ALIAS = _alias_index(PLACEMENT_ENTRIES)


def _lookup(
    value: str,
    aliases: Mapping[str, RegistryEntry],
    supported_ids: tuple[str, ...],
    kind: str,
) -> RegistryEntry | None:
    if not isinstance(value, str) or not value.strip():
        return None
    return aliases.get(_normalize(value))


def lookup_format(value: str) -> RegistryEntry | None:
    return _lookup(value, FORMAT_BY_ALIAS, tuple(FORMAT_BY_ID), "format")


def lookup_platform(value: str) -> RegistryEntry | None:
    return _lookup(value, PLATFORM_BY_ALIAS, tuple(PLATFORM_BY_ID), "platform")


def lookup_placement(value: str) -> PlacementEntry | None:
    return _lookup(value, PLACEMENT_BY_ALIAS, tuple(PLACEMENT_BY_ID), "placement")  # type: ignore[return-value]


def _validate(value: str, lookup, kind: str, supported_ids: tuple[str, ...]) -> str:
    entry = lookup(value)
    if entry is None:
        raise RegistryLookupError(kind, value, supported_ids)
    return entry.id


def validate_format_id(value: str) -> str:
    return _validate(value, lookup_format, "format", tuple(FORMAT_BY_ID))


def validate_platform_id(value: str) -> str:
    return _validate(value, lookup_platform, "platform", tuple(PLATFORM_BY_ID))


def validate_placement_id(value: str) -> str:
    return _validate(value, lookup_placement, "placement", tuple(PLACEMENT_BY_ID))


def registry_payload(locale: str = "en") -> dict[str, object]:
    """Return the deterministic, JSON-safe read model used by the API."""
    if locale not in SUPPORTED_LOCALES:
        raise ValueError(f"Unsupported locale {locale!r}; expected one of {SUPPORTED_LOCALES}")
    rules = [rule.as_dict() for placement in PLACEMENT_ENTRIES for rule in placement.rules]
    return {
        "registry_version": REGISTRY_VERSION,
        "locale": locale,
        "supported_locales": list(SUPPORTED_LOCALES),
        "formats": [entry.as_dict(locale) for entry in FORMAT_ENTRIES],
        "platforms": [entry.as_dict(locale) for entry in PLATFORM_ENTRIES],
        "placements": [entry.as_dict(locale) for entry in PLACEMENT_ENTRIES],
        "placement_rules": rules,
    }


def rules_for(format_id: str, platform_id: str) -> tuple[PlacementRule, ...]:
    """Return deterministic rules for one canonical content/platform pair."""

    canonical_format = validate_format_id(format_id)
    canonical_platform = validate_platform_id(platform_id)
    return tuple(
        rule
        for placement in PLACEMENT_ENTRIES
        for rule in placement.rules
        if rule.platform_id == canonical_platform and canonical_format in rule.format_ids
    )
