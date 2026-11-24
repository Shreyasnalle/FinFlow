"""Web search through Firecrawl (https://github.com/firecrawl/firecrawl).

Works with the Firecrawl cloud (FIRECRAWL_API_KEY) or a self-hosted instance
(FIRECRAWL_API_URL). Results are untrusted data, so they are wrapped, trimmed
and never treated as instructions.
"""

import asyncio
import logging

from firecrawl import Firecrawl
from langchain_core.tools import StructuredTool
from pydantic import BaseModel, Field

from app.agent.models import RunState
from app.config import Settings
from app.skills.registry import SkillRegistry

log = logging.getLogger(__name__)


class WebSearchInput(BaseModel):
    query: str = Field(min_length=3, max_length=200, description="A concise search query.")


def _client(s: Settings) -> Firecrawl | None:
    key = s.firecrawl_api_key.get_secret_value() if s.firecrawl_api_key else None
    if not key and not s.firecrawl_api_url:
        return None
    kwargs: dict = {"timeout": s.web_search_timeout_s}
    if key:
        kwargs["api_key"] = key
    if s.firecrawl_api_url:
        kwargs["api_url"] = s.firecrawl_api_url
    return Firecrawl(**kwargs)


def _format(results) -> tuple[str, list[str]]:
    lines, urls = [], []
    for i, r in enumerate(results, 1):
        title = (getattr(r, "title", None) or "").strip()
        url = (getattr(r, "url", None) or "").strip()
        desc = (getattr(r, "description", None) or "").strip()
        if not url:
            continue
        urls.append(url)
        lines.append(f"{i}. {title}\n   {url}\n   {desc}")
    return "\n".join(lines), urls


def make_web_search_tool(
    registry: SkillRegistry, state: RunState, s: Settings, client: Firecrawl | None = None
) -> StructuredTool:
    firecrawl = client or _client(s)

    async def web_search(query: str) -> str:
        # Python enforces the rules; the LLM only decides *whether* it needs the web.
        allowed = any(
            (sk := registry.get(n)) and sk.allows_web_search for n in state.loaded_skills
        )
        if not allowed:
            return "ERROR: web search is only available after loading a skill that allows it."
        if state.web_searches >= s.max_web_searches:
            return "ERROR: web search limit reached. Answer with what you have."
        if firecrawl is None:
            return "Web search is NOT available. Do not claim you searched or cite any source. Answer from general knowledge and clearly say the figure may be out of date and should be checked."
        state.web_searches += 1
        try:
            data = await asyncio.wait_for(
                asyncio.to_thread(firecrawl.search, query, limit=s.web_search_results),
                timeout=s.web_search_timeout_s,
            )
        except Exception as exc:  # network, quota, timeout: degrade gracefully
            log.warning("web_search failed: %s", exc)
            return "Web search failed. Do not cite any source. Answer from general knowledge and clearly say it may be out of date."
        text, urls = _format(getattr(data, "web", None) or [])
        if not text:
            return "No results found."
        state.sources.extend(u for u in urls if u not in state.sources)
        return f"<web_results untrusted>\n{text}\n</web_results>"

    return StructuredTool.from_function(
        coroutine=web_search,
        name="web_search",
        description=(
            "Search the web for current external facts (rates, prices, news, rules). "
            "Only use when a loaded skill allows it and the answer depends on up-to-date info."
        ),
        args_schema=WebSearchInput,
    )
