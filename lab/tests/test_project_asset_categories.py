import pytest

from status.asset_categories import (
    get_project_asset_category_catalog,
    suggested_project_asset_export_file_name,
    validate_project_asset_category,
)


def test_catalog_localizes_labels_without_changing_ids():
    english = get_project_asset_category_catalog("en-US")
    french = get_project_asset_category_catalog("fr-FR")

    assert english["version"] == french["version"]
    assert english["categories"][0]["category_id"] == "brand_identity"
    assert french["categories"][0]["category_id"] == "brand_identity"
    assert english["categories"][0]["label"] == "Brand identity"
    assert french["categories"][0]["label"] == "Identité de marque"


def test_category_validation_keeps_ai_tags_out_of_canonical_ids():
    with pytest.raises(ValueError, match="Unsupported category_id"):
        validate_project_asset_category("sunset")


def test_suggested_export_filename_is_safe_and_preserves_extension():
    suggestion = suggested_project_asset_export_file_name(
        asset_id="asset-123456789",
        category_id="editorial_visual",
        subcategory_id="infographic",
        original_file_name=r"..\..\Résumé final.PNG",
        file_name="renamed.png",
    )

    assert suggestion == "editorial_visual-infographic-resume-final.png"
    assert "/" not in suggestion
    assert "\\" not in suggestion
