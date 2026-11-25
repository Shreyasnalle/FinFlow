"""The one entry point: user message -> finance agent -> classifier -> reply.

Nothing the agent writes (answer or follow-ups) reaches the user until the classifier allows it.
"""

import logging
import secrets
from dataclasses import dataclass, field

from app.agent.finance_agent import FinanceAgent
from app.agent.models import AgentError, AgentRequest
from app.config import Settings, get_settings
from app.context.provider import ContextProvider
from app.followups.fallback import FALLBACK_FOLLOWUPS
from app.guardrails.classifier import ResponseClassifier
from app.guardrails.refusal_messages import refusal_for
from app.memory.keeper import MemoryKeeper
from app.skills.registry import SkillRegistry
from app.store import get_data_store, get_memory_store
from app.store.db import Database
from app.store.stores import MemoryStore, UserDataStore
from app.status.events import Stage
from app.status.reporter import NULL_REPORTER, StatusReporter

log = logging.getLogger(__name__)


@dataclass
class ChatResult:
    reply: str
    blocked: bool = False
    category: str | None = None
    skills_used: list[str] = field(default_factory=list)
    sources: list[str] = field(default_factory=list)
    followups: list[str] = field(default_factory=list)
    followups_source: str = "fallback"
    memory_status: str = "disabled"


def review_text(draft: str, followups: list[str]) -> str:
    """What the classifier reviews: the answer plus the follow-ups that will be shown."""
    return draft + "\n\nSuggested follow-up questions:\n" + "\n".join(f"- {q}" for q in followups)


class ChatService:
    def __init__(
        self,
        agent: FinanceAgent,
        classifier: ResponseClassifier,
        context: ContextProvider | None = None,
        memory: MemoryKeeper | None = None,
    ):
        self._agent = agent
        self._classifier = classifier
        self._context = context
        self._memory = memory

    @classmethod
    def create(cls, settings: Settings | None = None, db_path: str | None = None) -> "ChatService":
        s = settings or get_settings()
        canary = f"FFX-{secrets.token_hex(8)}"
        registry = SkillRegistry.from_directory()
        if db_path:
            db = Database(db_path)
            data: UserDataStore = UserDataStore(db)
            memory: MemoryStore = MemoryStore(db)
        else:
            data, memory = get_data_store(), get_memory_store()
        return cls(
            FinanceAgent(s, registry, canary),
            ResponseClassifier(s, canary),
            ContextProvider(data, memory),
            MemoryKeeper(s, memory),
        )

    async def _remember(self, request: AgentRequest, reply: str, reporter: StatusReporter) -> str:
        """Last step of a turn. Never lets a memory problem break the answer."""
        if self._memory is None:
            return "disabled"
        await reporter.update(Stage.REMEMBERING)
        try:
            outcome = await self._memory.run(request, reply)
        except Exception:
            log.exception("memory step failed")
            return "error"
        log.info("memory: %s (%s)", outcome.status, outcome.reason)
        return outcome.status

    async def handle(self, request: AgentRequest, reporter: StatusReporter = NULL_REPORTER) -> ChatResult:
        await reporter.update(Stage.RECEIVED)
        if self._context is not None:
            request = await self._context.resolve(request)  # the user's numbers + memory, by user_id
        try:
            result = await self._agent.run(request, reporter)
            await reporter.update(Stage.CHECKING)
            decision = await self._classifier.check(
                request.message, review_text(result.draft, result.followups)
            )
        except AgentError:
            await reporter.update(Stage.ERROR)
            raise

        if decision.allowed:
            # Memory comes last: after the answer and follow-ups, and only for replies that were allowed.
            memory_status = await self._remember(request, result.draft, reporter)
            await reporter.update(Stage.DONE)
            return ChatResult(
                reply=result.draft,
                skills_used=result.skills_used,
                sources=result.sources,
                followups=result.followups,
                followups_source=result.followups_source,
                memory_status=memory_status,
            )
        await reporter.update(Stage.DONE)
        log.info("draft blocked: %s (%s)", decision.category.value, decision.reason)
        return ChatResult(
            reply=refusal_for(decision.category, decision.topic),
            blocked=True,
            category=decision.category.value,
            skills_used=result.skills_used,
            followups=list(FALLBACK_FOLLOWUPS),  # blocked reply still gets safe, useful buttons
            followups_source="fallback",
            memory_status="skipped",  # nothing from a blocked exchange is remembered
        )
