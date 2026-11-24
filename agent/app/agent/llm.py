"""LLM factory. The rest of the code only sees a LangChain `BaseChatModel`.

To move from the free Groq cloud to a paid model on EC2 later, register another
provider here (e.g. an OpenAI-compatible vLLM endpoint) and set LLM_PROVIDER.
Nothing else in the agent, skills or guardrail needs to change.
"""

from collections.abc import Callable

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_groq import ChatGroq

from app.config import Settings


def _groq(model: str, temperature: float, s: Settings, reasoning_effort: str | None = None) -> BaseChatModel:
    if s.groq_api_key is None:
        raise RuntimeError("GROQ_API_KEY is not set (put it in agent/.env).")
    return ChatGroq(
        model=model,
        temperature=temperature,
        api_key=s.groq_api_key,
        timeout=s.llm_timeout_s,
        max_retries=s.llm_max_retries,
        reasoning_effort=reasoning_effort if "gpt-oss" in model else None,
    )


PROVIDERS: dict[str, Callable[..., BaseChatModel]] = {
    "groq": _groq,
}


def build_chat_model(
    model: str, temperature: float, settings: Settings, reasoning_effort: str | None = None
) -> BaseChatModel:
    try:
        factory = PROVIDERS[settings.llm_provider]
    except KeyError:
        raise RuntimeError(
            f"Unknown LLM_PROVIDER '{settings.llm_provider}'. Known: {sorted(PROVIDERS)}"
        ) from None
    return factory(model, temperature, settings, reasoning_effort)
