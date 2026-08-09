from api.services.social_placement_registry import (
    REGISTRY_VERSION,
    registry_payload,
    validate_format_id,
    validate_platform_id,
    validate_placement_id,
)


def test_registry_ids_are_stable_and_labels_localize():
    en = registry_payload("en")
    fr = registry_payload("fr")
    assert en["registry_version"] == fr["registry_version"] == REGISTRY_VERSION
    assert [item["id"] for item in en["formats"]] == [item["id"] for item in fr["formats"]]
    assert next(item for item in fr["formats"] if item["id"] == "FMT_SHORT")["label"] == "Vidéo courte"


def test_legacy_aliases_resolve_to_immutable_ids():
    assert validate_format_id("reels") == "FMT_REEL"
    assert validate_platform_id("twitter") == "PLAT_X"
    assert validate_placement_id("vertical_short_video") == "PLC_VERTICAL_SHORT_VIDEO"


def test_unknown_ids_are_rejected():
    for resolver in (validate_format_id, validate_platform_id, validate_placement_id):
        try:
            resolver("not-real")
        except ValueError:
            pass
        else:
            raise AssertionError("unknown registry id was accepted")


def test_rule_provenance_is_platform_specific():
    payload = registry_payload("en")
    for rule in payload["placement_rules"]:
        sources = " ".join(rule["doc_sources"])
        if rule["platform_id"] == "PLAT_INSTAGRAM":
            assert "instagram" in sources.lower()
            assert "docs.x.com" not in sources
            assert "youtube" not in sources
        if rule["platform_id"] == "PLAT_X":
            assert "docs.x.com" in sources
            assert "youtube" not in sources
