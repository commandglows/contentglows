import pytest

from api.services.image_generation_store import ImageGenerationStore
from utils.libsql_async import create_client


@pytest.mark.asyncio
async def test_image_generation_store_persists_generations_and_references():
    store = ImageGenerationStore(db_client=create_client(url=":memory:"))
    await store.ensure_tables()

    reference = await store.create_reference(
        project_id="project-1",
        user_id="user-1",
        cdn_url="https://cdn.example.com/ref.jpg",
        primary_url="https://cdn.example.com/ref-800.jpg",
        mime_type="image/jpeg",
        width=1200,
        height=800,
        label="Main character",
        reference_type="character",
        approved=True,
    )
    assert reference["approved"] is True

    references = await store.list_references(
        project_id="project-1",
        user_id="user-1",
        approved_only=True,
    )
    assert [item["id"] for item in references] == [reference["id"]]

    generation = await store.create_generation(
        project_id="project-1",
        user_id="user-1",
        profile_id="ai-blog-hero",
        provider="flux",
        model="flux-2-pro",
        job_id="job-1",
        reservation_id="reservation-1",
        prompt="A precise editorial hero image",
        width=1440,
        height=810,
        seed=42,
        output_format="jpeg",
        reference_ids=[reference["id"]],
        visual_memory_applied=True,
    )
    assert generation["status"] == "queued"
    assert generation["reference_ids"] == [reference["id"]]
    assert generation["visual_memory_applied"] is True
    assert generation["reservation_id"] == "reservation-1"

    await store.mark_completed(
        generation["id"],
        user_id="user-1",
        cdn_url="https://cdn.example.com/out.jpg",
        primary_url="https://cdn.example.com/out-800.jpg",
        responsive_urls={"800": "https://cdn.example.com/out-800.jpg"},
        asset_id="asset-1",
        provider_request_id="bfl-1",
        provider_cost=4.5,
        provider_metadata={"status": "Ready"},
    )
    stored = await store.get_generation(generation["id"], user_id="user-1")
    assert stored["status"] == "completed"
    assert stored["cdn_url"] == "https://cdn.example.com/out.jpg"
    assert stored["asset_id"] == "asset-1"
    assert stored["responsive_urls"]["800"].endswith("out-800.jpg")


@pytest.mark.asyncio
async def test_image_reference_approval_blocks_approved_only_lists():
    store = ImageGenerationStore(db_client=create_client(url=":memory:"))
    await store.ensure_tables()
    reference = await store.create_reference(
        project_id="project-1",
        user_id="user-1",
        cdn_url="https://cdn.example.com/ref.jpg",
        mime_type="image/jpeg",
        approved=True,
    )

    await store.set_reference_approved(
        reference["id"],
        project_id="project-1",
        user_id="user-1",
        approved=False,
    )

    approved = await store.list_references(
        project_id="project-1",
        user_id="user-1",
        approved_only=True,
    )
    assert approved == []
