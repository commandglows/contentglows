"""PydanticAI runtime adapter for request-scoped OpenRouter use."""

from __future__ import annotations

from typing import Any, TypeVar

OutputT = TypeVar("OutputT")
DEFAULT_OPENROUTER_MODEL = "openai/gpt-4o-mini"


class PydanticAIRuntimeError(RuntimeError):
    """Raised when PydanticAI cannot be constructed safely."""


def _clean_api_key(api_key: str) -> str:
    cleaned = api_key.strip() if isinstance(api_key, str) else ""
    if not cleaned:
        raise PydanticAIRuntimeError("OpenRouter API key is required for PydanticAI runtime.")
    return cleaned


def build_openrouter_model(
    *,
    api_key: str,
    model_name: str = DEFAULT_OPENROUTER_MODEL,
    app_url: str | None = None,
    app_title: str | None = "ContentGlows",
) -> Any:
    """Build a PydanticAI OpenRouter model with an explicit request-scoped key."""
    cleaned_key = _clean_api_key(api_key)
    try:
        from pydantic_ai.models.openrouter import OpenRouterModel
        from pydantic_ai.providers.openrouter import OpenRouterProvider
    except Exception as exc:  # pragma: no cover - exercised through tests with monkeypatches.
        raise PydanticAIRuntimeError(
            "pydantic-ai OpenRouter support is unavailable in this runtime."
        ) from exc

    provider_kwargs: dict[str, str] = {"api_key": cleaned_key}
    if app_url:
        provider_kwargs["app_url"] = app_url
    if app_title:
        provider_kwargs["app_title"] = app_title
    return OpenRouterModel(
        model_name,
        provider=OpenRouterProvider(**provider_kwargs),
    )


def build_openrouter_agent(
    *,
    api_key: str,
    output_type: type[OutputT] | Any = str,
    model_name: str = DEFAULT_OPENROUTER_MODEL,
    system_prompt: str | tuple[str, ...] = (),
    deps_type: type[Any] | None = None,
    retries: int = 1,
    output_retries: int | None = 1,
) -> Any:
    """Build a PydanticAI Agent using the current v1 API surface."""
    try:
        from pydantic_ai import Agent
    except Exception as exc:  # pragma: no cover - exercised through tests with monkeypatches.
        raise PydanticAIRuntimeError("pydantic-ai is unavailable in this runtime.") from exc

    kwargs: dict[str, Any] = {
        "model": build_openrouter_model(api_key=api_key, model_name=model_name),
        "output_type": output_type,
        "system_prompt": system_prompt,
        "retries": retries,
        "output_retries": output_retries,
    }
    if deps_type is not None:
        kwargs["deps_type"] = deps_type
    return Agent(**kwargs)


def result_output(result: Any) -> Any:
    """Return a PydanticAI v1 result output without accepting legacy `.data`."""
    missing = object()
    output = getattr(result, "output", missing)
    if output is missing:
        raise PydanticAIRuntimeError("PydanticAI result did not expose an output value.")
    return output


async def resolve_openrouter_key(user_id: str, *, route: str) -> str:
    """Resolve OpenRouter lazily so importing this adapter stays lightweight."""
    from api.services.user_llm_service import user_llm_service

    return await user_llm_service.get_openrouter_key(user_id, route=route)


async def run_openrouter_structured(
    user_id: str,
    *,
    system_prompt: str,
    user_prompt: str,
    output_type: type[OutputT] | Any,
    model_name: str = DEFAULT_OPENROUTER_MODEL,
    route: str = "runtime.openrouter",
    deps: Any = None,
    deps_type: type[Any] | None = None,
) -> OutputT:
    """Resolve the user-scoped OpenRouter key and run a typed PydanticAI request."""
    api_key = await resolve_openrouter_key(user_id, route=route)
    agent = build_openrouter_agent(
        api_key=api_key,
        model_name=model_name,
        output_type=output_type,
        system_prompt=system_prompt,
        deps_type=deps_type,
    )
    run_kwargs: dict[str, Any] = {}
    if deps is not None:
        run_kwargs["deps"] = deps
    result = await agent.run(user_prompt, **run_kwargs)
    return result_output(result)
