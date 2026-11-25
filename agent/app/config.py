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

    # --- Rate limiting (POST /chat and /chat/stream; /health is never limited).
    # In-memory and per process: one worker, and counters reset on restart/sleep.
    # Per-client limits are generous because mobile carriers put many users behind one IP;
    # the global caps are what protect the model quota and cost.
    rate_limit_enabled: bool = True
    rate_limit_per_minute: int = 12  # per client IP, sliding 60 s window
    rate_limit_per_day: int = 200  # per client IP, per UTC day
    rate_limit_global_per_minute: int = 60  # all clients together
    rate_limit_global_per_day: int = 2000  # all clients together, per UTC day
    rate_limit_max_clients: int = 2000  # tracked IPs at once (oldest evicted); bounds memory
    # Behind a reverse proxy (e.g. Render) set the header carrying the client IP, normally
    # X-Forwarded-For. Clients can add their own entries to it, so the IP is read from the RIGHT:
    # `forwarded_hops` = how many entries the trusted proxies append (1 = the last entry).
    # Leave the header unset when the app is reached directly.
    rate_limit_client_ip_header: str | None = None
    rate_limit_forwarded_hops: int = 1
    rate_limit_debug_log_clients: bool = False  # temporary: log the resolved client and header chain
    # The /users endpoints (data sync, memory) have their own, separate budgets.
    rate_limit_users_per_minute: int = 30  # per client IP
    rate_limit_users_per_day: int = 1000  # per client IP
    rate_limit_users_global_per_minute: int = 120  # all clients together
    rate_limit_users_global_per_day: int = 5000  # all clients together

    # --- Request size: bodies bigger than this are rejected (HTTP 413) before being read into memory.
    # The biggest legitimate request is a data snapshot (<= 5000 transactions, well under 2 MB); a small
    # host such as Render's 512 MB free plan must not be able to run out of memory on one upload.
    max_request_bytes: int = 2_000_000

    # --- The /users endpoints (PUT data, GET context/memory, DELETE memory). They identify a user only by the
    # id in the URL and have no authentication yet, so turn them off (false) on any publicly reachable
    # deployment until authentication exists. Chat keeps working without them (data is sent inline).
    users_api_enabled: bool = True


@lru_cache
def get_settings() -> Settings:
    return Settings()
