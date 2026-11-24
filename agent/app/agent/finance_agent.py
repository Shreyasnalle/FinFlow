"""The finance agent: LLM as the brain, Python as the strict checker around it."""

import logging

from langchain_core.language_models.chat_models import BaseChatModel

from app.agent.agent_loop import run_agent_loop
from app.agent.llm import build_chat_model
from app.agent.models import AgentError, AgentRequest, AgentResult, RunState
from app.agent.prompt_builder import PromptBuilder
from app.config import Settings
from app.followups.checker import validate
from app.followups.fallback import FALLBACK_FOLLOWUPS
from app.followups.parser import extract
from app.followups.writer import FollowUpWriter
from app.skills.registry import SkillRegistry
from app.status.events import Stage
from app.status.reporter import NULL_REPORTER, StatusReporter
from app.tools.load_skill import make_load_skill_tool
from app.tools.web_search import make_web_search_tool

log = logging.getLogger(__name__)


class FinanceAgent:
    def __init__(
        self,
        settings: Settings,
        registry: SkillRegistry,
        canary: str,
        llm: BaseChatModel | None = None,
        search_client=None,
        followup_writer: FollowUpWriter | None = None,
    ):
        self._s = settings
        self._registry = registry
        self._search_client = search_client
        self._llm = llm or build_chat_model(
            settings.agent_model, settings.agent_temperature, settings, settings.agent_reasoning_effort
        )
        self._prompts = PromptBuilder(registry, settings, canary)
        self._followups = followup_writer or FollowUpWriter(settings)

    async def run(self, request: AgentRequest, reporter: StatusReporter = NULL_REPORTER) -> AgentResult:
        state = RunState()  # fresh per request: tools and checker share it
        tools = [
            make_load_skill_tool(self._registry, state, self._s),
            make_web_search_tool(self._registry, state, self._s, self._search_client),
        ]
        await reporter.update(Stage.READING_CONTEXT)
        messages = self._prompts.build(request)
        raw = await run_agent_loop(self._llm, messages, tools, state, self._s, reporter)

        # Follow-ups: the agent must end its reply with them; Python verifies it did.
        await reporter.update(Stage.FOLLOWUPS)
        draft, found = extract(raw)
        if not draft:
            raise AgentError("The model returned only follow-ups and no answer.")
        questions, source = validate(found), "agent"
        if questions is None:  # missing or unusable: call the agent again for this task only
            log.info("agent skipped/botched follow-ups; running repair")
            questions, source = await self._followups.write(request, draft), "repair"
        if questions is None:
            questions, source = list(FALLBACK_FOLLOWUPS), "fallback"

        return AgentResult(
            draft=draft,
            skills_used=list(state.loaded_skills),
            sources=list(state.sources),
            steps=state.steps,
            followups=questions,
            followups_source=source,
        )
