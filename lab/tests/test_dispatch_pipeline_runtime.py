import sys
import types
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import BackgroundTasks, HTTPException

from api.models.psychology import PipelineDispatchRequest
from api.routers import psychology as psychology_router


@pytest.mark.asyncio
async def test_dispatch_pipeline_article_uses_expected_runtime_matrix(monkeypatch):
    preflight = AsyncMock(return_value=SimpleNamespace())
    create_job = AsyncMock()
    monkeypatch.setattr(psychology_router.ai_runtime_service, "preflight_providers", preflight)
    monkeypatch.setattr(psychology_router, "_create_job", create_job)
    monkeypatch.setattr("utils.dedup.check_content_duplicate", lambda **_: None)

    captured = {}
    fake_status = types.ModuleType("status")
    fake_status.get_status_service = lambda: SimpleNamespace(
        create_content=lambda **kwargs: (
            captured.update(kwargs) or SimpleNamespace(id="content-1")
        ),
    )
    monkeypatch.setitem(sys.modules, "status", fake_status)

    response = await psychology_router.dispatch_pipeline(
        request=PipelineDispatchRequest(
            angle_data={"title": "Pipeline angle", "persona_id": "persona-1"},
            target_format="article",
            project_id="project-1",
        ),
        background_tasks=BackgroundTasks(),
        current_user=SimpleNamespace(user_id="user-1"),
    )

    assert response.status == "running"
    assert response.content_record_id == "content-1"
    assert preflight.await_args.kwargs["required_providers"] == ["openrouter", "exa"]
    assert preflight.await_args.kwargs["optional_providers"] == ["firecrawl"]
    assert captured["metadata"]["persona_id"] == "persona-1"
    create_job.assert_awaited_once()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("target_format", "required", "optional"),
    [
        ("newsletter", ["openrouter", "exa"], []),
        ("short", ["openrouter"], []),
        ("social_post", ["openrouter"], []),
    ],
)
async def test_dispatch_pipeline_non_article_formats_use_runtime_matrix(
    monkeypatch,
    target_format,
    required,
    optional,
):
    preflight = AsyncMock(return_value=SimpleNamespace())
    create_job = AsyncMock()
    monkeypatch.setattr(psychology_router.ai_runtime_service, "preflight_providers", preflight)
    monkeypatch.setattr(psychology_router, "_create_job", create_job)
    monkeypatch.setattr("utils.dedup.check_content_duplicate", lambda **_: None)

    fake_status = types.ModuleType("status")
    fake_status.get_status_service = lambda: SimpleNamespace(
        create_content=lambda **kwargs: SimpleNamespace(id=f"{target_format}-content-1"),
    )
    monkeypatch.setitem(sys.modules, "status", fake_status)

    response = await psychology_router.dispatch_pipeline(
        request=PipelineDispatchRequest(
            angle_data={"title": f"{target_format} angle"},
            target_format=target_format,
            project_id="project-1",
        ),
        background_tasks=BackgroundTasks(),
        current_user=SimpleNamespace(user_id="user-1"),
    )

    assert response.status == "running"
    assert preflight.await_args.kwargs["route"] == (
        f"psychology.dispatch_pipeline.{target_format}"
    )
    assert preflight.await_args.kwargs["required_providers"] == required
    assert preflight.await_args.kwargs["optional_providers"] == optional
    create_job.assert_awaited_once()


@pytest.mark.asyncio
async def test_dispatch_pipeline_duplicate_conflict_is_not_runtime_error(monkeypatch):
    monkeypatch.setattr(
        psychology_router.ai_runtime_service,
        "preflight_providers",
        AsyncMock(return_value=SimpleNamespace()),
    )
    create_job = AsyncMock()
    monkeypatch.setattr(psychology_router, "_create_job", create_job)
    monkeypatch.setattr(
        "utils.dedup.check_content_duplicate",
        lambda **_: {"id": "existing-1", "title": "Already there", "status": "draft"},
    )

    with pytest.raises(HTTPException) as exc:
        await psychology_router.dispatch_pipeline(
            request=PipelineDispatchRequest(
                angle_data={"title": "Existing title"},
                target_format="newsletter",
                project_id="project-1",
            ),
            background_tasks=BackgroundTasks(),
            current_user=SimpleNamespace(user_id="user-1"),
        )

    assert exc.value.status_code == 409
    assert exc.value.detail["kind"] == "business_conflict"
    assert exc.value.detail["code"] == "content_duplicate_conflict"
    create_job.assert_not_awaited()
