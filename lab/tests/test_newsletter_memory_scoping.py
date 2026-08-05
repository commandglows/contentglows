from __future__ import annotations

import importlib.util
import sys
import types
from pathlib import Path


_MEMORY_TOOLS_PATH = (
    Path(__file__).resolve().parent.parent
    / "agents"
    / "newsletter"
    / "tools"
    / "memory_tools.py"
)


def _identity_tool_decorator(func=None, *args, **kwargs):
    if func is None:
        def _decorator(inner):
            return inner
        return _decorator
    return func


def _load_context_tools_module():
    fake_crewai = types.ModuleType("crewai")
    fake_tools = types.ModuleType("crewai.tools")
    fake_tools.tool = _identity_tool_decorator
    fake_crewai.tools = fake_tools
    sys.modules["crewai"] = fake_crewai
    sys.modules["crewai.tools"] = fake_tools

    spec = importlib.util.spec_from_file_location(
        "contentglows_newsletter_context_tools_migrated",
        _MEMORY_TOOLS_PATH,
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_memory_tools_require_bound_project_scope_and_do_not_fallback_global():
    module = _load_context_tools_module()
    module.clear_project_context_tool_scope()

    assert "missing project scope" in module.recall_project_context("brand").lower()
    assert "missing project scope" in module.recall_brand_voice().lower()
    assert "missing project scope" in module.recall_past_newsletters().lower()


def test_memory_tools_use_prebuilt_project_intelligence_context():
    module = _load_context_tools_module()
    module.set_project_context_tool_scope(
        user_id="user-1",
        project_id="project-1",
        context_prompt="--- PROJECT INTELLIGENCE CONTEXT ---\nAudience: founders",
    )

    assert "Audience: founders" in module.recall_brand_voice()
    assert "Project Intelligence" in module.recall_project_context("audience")
