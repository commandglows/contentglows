"""Canonical, versioned category registry for project media assets.

Category identifiers are stable storage/API tokens. Localized labels are
presentation data and must never be persisted as the asset category value.
AI understanding tags remain a separate, many-valued suggestion layer.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import PurePath
from typing import Any, Dict, Optional


PROJECT_ASSET_CATEGORY_REGISTRY_VERSION = "2026-08-07.1"
PROJECT_ASSET_CATEGORY_DEFAULT_LOCALE = "en"
PROJECT_ASSET_CATEGORY_SUPPORTED_LOCALES = ("en", "fr")


PROJECT_ASSET_CATEGORIES = (
    {
        "category_id": "brand_identity",
        "labels": {"en": "Brand identity", "fr": "Identité de marque"},
        "subcategories": (
            {"subcategory_id": "logo", "labels": {"en": "Logo", "fr": "Logo"}},
            {"subcategory_id": "brand_mark", "labels": {"en": "Brand mark", "fr": "Symbole de marque"}},
            {"subcategory_id": "brand_system", "labels": {"en": "Brand system", "fr": "Système de marque"}},
        ),
    },
    {
        "category_id": "product_service",
        "labels": {"en": "Product and service", "fr": "Produit et service"},
        "subcategories": (
            {"subcategory_id": "product_shot", "labels": {"en": "Product shot", "fr": "Visuel produit"}},
            {"subcategory_id": "service_demo", "labels": {"en": "Service demo", "fr": "Démonstration de service"}},
            {"subcategory_id": "interface_capture", "labels": {"en": "Interface capture", "fr": "Capture d’interface"}},
        ),
    },
    {
        "category_id": "people_lifestyle",
        "labels": {"en": "People and lifestyle", "fr": "Personnes et quotidien"},
        "subcategories": (
            {"subcategory_id": "portrait", "labels": {"en": "Portrait", "fr": "Portrait"}},
            {"subcategory_id": "team", "labels": {"en": "Team", "fr": "Équipe"}},
            {"subcategory_id": "customer_story", "labels": {"en": "Customer story", "fr": "Témoignage client"}},
            {"subcategory_id": "lifestyle", "labels": {"en": "Lifestyle", "fr": "Mode de vie"}},
        ),
    },
    {
        "category_id": "editorial_visual",
        "labels": {"en": "Editorial visual", "fr": "Visuel éditorial"},
        "subcategories": (
            {"subcategory_id": "illustration", "labels": {"en": "Illustration", "fr": "Illustration"}},
            {"subcategory_id": "infographic", "labels": {"en": "Infographic", "fr": "Infographie"}},
            {"subcategory_id": "quote_card", "labels": {"en": "Quote card", "fr": "Carte citation"}},
            {"subcategory_id": "data_visualization", "labels": {"en": "Data visualization", "fr": "Visualisation de données"}},
        ),
    },
    {
        "category_id": "social_campaign",
        "labels": {"en": "Social and campaign", "fr": "Social et campagne"},
        "subcategories": (
            {"subcategory_id": "social_post", "labels": {"en": "Social post", "fr": "Publication sociale"}},
            {"subcategory_id": "story_reel", "labels": {"en": "Story or reel", "fr": "Story ou reel"}},
            {"subcategory_id": "ad_creative", "labels": {"en": "Ad creative", "fr": "Création publicitaire"}},
            {"subcategory_id": "thumbnail", "labels": {"en": "Thumbnail", "fr": "Miniature"}},
        ),
    },
    {
        "category_id": "video_media",
        "labels": {"en": "Video", "fr": "Vidéo"},
        "subcategories": (
            {"subcategory_id": "b_roll", "labels": {"en": "B-roll", "fr": "Plan de coupe"}},
            {"subcategory_id": "intro_outro", "labels": {"en": "Intro or outro", "fr": "Intro ou outro"}},
            {"subcategory_id": "screen_recording", "labels": {"en": "Screen recording", "fr": "Enregistrement d’écran"}},
            {"subcategory_id": "final_render", "labels": {"en": "Final render", "fr": "Rendu final"}},
        ),
    },
    {
        "category_id": "voice_audio",
        "labels": {"en": "Voice and spoken audio", "fr": "Voix et audio parlé"},
        "subcategories": (
            {"subcategory_id": "narration", "labels": {"en": "Narration", "fr": "Narration"}},
            {"subcategory_id": "voiceover", "labels": {"en": "Voice-over", "fr": "Voix off"}},
            {"subcategory_id": "interview", "labels": {"en": "Interview", "fr": "Interview"}},
            {"subcategory_id": "podcast", "labels": {"en": "Podcast", "fr": "Podcast"}},
        ),
    },
    {
        "category_id": "music_sound",
        "labels": {"en": "Music and sound", "fr": "Musique et son"},
        "subcategories": (
            {"subcategory_id": "music_bed", "labels": {"en": "Music bed", "fr": "Fond musical"}},
            {"subcategory_id": "jingle", "labels": {"en": "Jingle", "fr": "Jingle"}},
            {"subcategory_id": "sound_effect", "labels": {"en": "Sound effect", "fr": "Effet sonore"}},
        ),
    },
    {
        "category_id": "background_template",
        "labels": {"en": "Background and template", "fr": "Fond et modele"},
        "subcategories": (
            {"subcategory_id": "static_background", "labels": {"en": "Static background", "fr": "Fond statique"}},
            {"subcategory_id": "animated_background", "labels": {"en": "Animated background", "fr": "Fond animé"}},
            {"subcategory_id": "video_template", "labels": {"en": "Video template", "fr": "Modèle vidéo"}},
        ),
    },
)


_CATEGORY_BY_ID = {entry["category_id"]: entry for entry in PROJECT_ASSET_CATEGORIES}
_SAFE_EXTENSION = re.compile(r"^\.[a-zA-Z0-9]{1,10}$")


def normalize_category_locale(locale: Optional[str]) -> str:
    normalized = (locale or PROJECT_ASSET_CATEGORY_DEFAULT_LOCALE).strip().lower().replace("_", "-")
    language = normalized.split("-", 1)[0]
    return language if language in PROJECT_ASSET_CATEGORY_SUPPORTED_LOCALES else PROJECT_ASSET_CATEGORY_DEFAULT_LOCALE


def get_project_asset_category_catalog(locale: Optional[str] = None) -> Dict[str, Any]:
    resolved_locale = normalize_category_locale(locale)
    categories = []
    for category in PROJECT_ASSET_CATEGORIES:
        categories.append(
            {
                "category_id": category["category_id"],
                "label": category["labels"][resolved_locale],
                "subcategories": [
                    {
                        "subcategory_id": subcategory["subcategory_id"],
                        "label": subcategory["labels"][resolved_locale],
                    }
                    for subcategory in category["subcategories"]
                ],
            }
        )
    return {
        "version": PROJECT_ASSET_CATEGORY_REGISTRY_VERSION,
        "locale": resolved_locale,
        "supported_locales": list(PROJECT_ASSET_CATEGORY_SUPPORTED_LOCALES),
        "categories": categories,
    }


def validate_project_asset_category(
    category_id: Optional[str],
    subcategory_id: Optional[str] = None,
) -> tuple[Optional[str], Optional[str]]:
    normalized_category = (category_id or "").strip() or None
    normalized_subcategory = (subcategory_id or "").strip() or None
    if normalized_category is None:
        if normalized_subcategory is not None:
            raise ValueError("subcategory_id requires category_id")
        return None, None

    category = _CATEGORY_BY_ID.get(normalized_category)
    if category is None:
        raise ValueError(f"Unsupported category_id '{normalized_category}'")
    if normalized_subcategory is not None:
        allowed = {item["subcategory_id"] for item in category["subcategories"]}
        if normalized_subcategory not in allowed:
            raise ValueError(
                f"Unsupported subcategory_id '{normalized_subcategory}' for category_id '{normalized_category}'"
            )
    return normalized_category, normalized_subcategory


def suggested_project_asset_export_file_name(
    *,
    asset_id: str,
    category_id: Optional[str],
    subcategory_id: Optional[str],
    original_file_name: Optional[str],
    file_name: Optional[str],
) -> str:
    """Return a portable suggestion without mutating the stored/original name."""

    raw_name = original_file_name or file_name or f"asset-{asset_id[:8]}"
    safe_base_name = PurePath(raw_name.replace("\\", "/")).name
    suffix = PurePath(safe_base_name).suffix
    safe_suffix = suffix.lower() if _SAFE_EXTENSION.fullmatch(suffix) else ""
    stem = safe_base_name[: -len(suffix)] if safe_suffix else safe_base_name
    ascii_stem = unicodedata.normalize("NFKD", stem).encode("ascii", "ignore").decode("ascii")
    safe_stem = re.sub(r"[^a-zA-Z0-9]+", "-", ascii_stem).strip("-").lower()
    safe_stem = safe_stem[:80].rstrip("-") or f"asset-{asset_id[:8]}"
    prefix_parts = [category_id or "uncategorized"]
    if subcategory_id:
        prefix_parts.append(subcategory_id)
    suggestion = "-".join((*prefix_parts, safe_stem))
    return f"{suggestion[:128].rstrip('-')}{safe_suffix}"
