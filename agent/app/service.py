"""The one entry point: user message -> finance agent -> classifier -> reply.

Nothing the agent writes (answer or follow-ups) reaches the user until the classifier allows it.
"""

import logging
import secrets
from dataclasses import dataclass, field

from app.agent.finance_agent import FinanceAgent
from app.agent.models import AgentError, AgentRequest
from app.config import Settings, get_settings
from app.followups.fallback import FALLBACK_FOLLOWUPS
from app.guardrails.classifier import ResponseClassifier
from app.guardrails.refusal_messages import refusal_for
from app.skills.registry import SkillRegistry
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


def review_text(draft: str, followups: list[str]) -> str:
    """What the classifier reviews: the answer plus the follow-ups that will be shown."""
    return draft + "\n\nSuggested follow-up questions:\n" + "\n".join(f"- {q}" for q in followups)


class ChatService:
    def __init__(self, agent: FinanceAgent, classifier: ResponseClassifier):
        self._agent = agent
        self._classifier = classifier

    @classmethod
    def create(cls, settings: Settings | None = None) -> "ChatService":
        s = settings or get_settings()
        canary = f"FFX-{secrets.token_hex(8)}"
        registry = SkillRegistry.from_directory()
        return cls(FinanceAgent(s, registry, canary), ResponseClassifier(s, canary))

    async def handle(self, request: AgentRequest, reporter: StatusReporter = NULL_REPORTER) -> ChatResult:
        await reporter.update(Stage.RECEIVED)
        try:
            result = await self._agent.run(request, reporter)
            await reporter.update(Stage.CHECKING)
            decision = await self._classifier.check(
                request.message, review_text(result.draft, result.followups)
            )
        except AgentError:
            await reporter.update(Stage.ERROR)
            raise

        await reporter.update(Stage.DONE)
        if decision.allowed:
            return ChatResult(
                reply=result.draft,
                skills_used=result.skills_used,
                sources=result.sources,
                followups=result.followups,
                followups_source=result.followups_source,
            )
        log.info("draft blocked: %s (%s)", decision.category.value, decision.reason)
        return ChatResult(
            reply=refusal_for(decision.category, decision.topic),
            blocked=True,
            category=decision.category.value,
            skills_used=result.skills_used,
            followups=list(FALLBACK_FOLLOWUPS),  # blocked reply still gets safe, useful buttons
            followups_source="fallback",
        )
