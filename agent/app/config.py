"""Central settings, read from environment / .env (never hard-code secrets)."""

from functools import lru_cache
from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[1]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ROOT / ".env", extra="ignore")

    # --- LLM provider (Groq now; a paid model on EC2 later, see app/agent/llm.py)
    llm_provider: str = "groq"
    groq_api_key: SecretStr | None = None
    agent_model: str = "openai/gpt-oss-120b"
    classifier_model: str = "openai/gpt-oss-20b"
    agent_temperature: float = 0.3
    agent_reasoning_effort: str | None = "low"  # gpt-oss models; ignored if None
    classifier_reasoning_effort: str | None = "low"
    llm_timeout_s: float = 45.0
    llm_max_retries: int = 2

    # --- Web search (Firecrawl: cloud key, or self-hosted URL)
    firecrawl_api_key: SecretStr | None = None
    firecrawl_api_url: str | None = None
    web_search_results: int = 4
    web_search_timeout_s: float = 30.0

    # --- Agent limits (the Python side enforces these, the LLM cannot exceed them)
    max_agent_steps: int = 6
    max_skills_per_query: int = 3
    max_web_searches: int = 2
    max_tool_output_chars: int = 6000
    max_context_chars: int = 12000  # user_data / memory, each

    # --- Request limits
    max_message_chars: int = 2000
    max_history_messages: int = 20


@lru_cache
def get_settings() -> Settings:
    return Settings()
