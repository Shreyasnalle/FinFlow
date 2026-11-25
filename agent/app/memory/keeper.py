"""The last step of every turn: the agent decides whether anything is worth remembering."""

import asyncio
import logging
from dataclasses import dataclass
from datetime import date

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.prompts import ChatPromptTemplate

from app.agent.llm import build_chat_model
from app.agent.models import AgentRequest
from app.config import Settings
from app.memory import checker, document
from app.memory.decision import MemoryDecision
from app.skills.registry import load_system_skill
from app.store.stores import MemoryStore

log = logging.getLogger(__name__)

PROMPT = ChatPromptTemplate.from_messages(
    [
        ("system", "{skill}\n{retry_note}"),
        (
            "human",
            "<current_memory>\n{memory}\n</current_memory>\n\n"
            "<recent_conversation>\n{conversation}\n</recent_conversation>\n\n"
            "<user_message>\n{user_message}\n</user_message>\n\n"
            "<assistant_reply>\n{reply}\n</assistant_reply>\n\n"
            "Make your decision now.",
        ),
    ]
)

RETRY_NOTE = (
    "\nIMPORTANT: your previous answer was missing or invalid. You MUST return a decision now: "
    "`skip` with a short reason, or `update` with at least one valid add or remove."
)


@dataclass
class MemoryOutcome:
    status: str  # updated | skipped | undecided | no_user
    reason: str = ""
    added: int = 0
    removed: int = 0


class MemoryKeeper:
    def __init__(self, settings: Settings, store: MemoryStore, llm: BaseChatModel | None = None, today=date.today):
        self._store, self._today = store, today
        self._skill = load_system_skill("memory_update").body
        # The decision is small and structured: the fast model made the same calls as the 120b one in
        # ~0.4s instead of ~7s, and it has its own rate-limit bucket.
        model = llm or build_chat_model(
            settings.classifier_model, 0.0, settings, settings.classifier_reasoning_effort
        )
        self._chain = PROMPT | model.with_structured_output(MemoryDecision, method="json_schema")
        self._locks: dict[str, asyncio.Lock] = {}

    async def _decide(self, inputs: dict, existing: dict) -> checker.ValidatedDecision | None:
        for attempt in (1, 2):  # attempt 2 = call the agent again, only for this decision
            try:
                raw = await self._chain.ainvoke({**inputs, "retry_note": RETRY_NOTE if attempt == 2 else ""})
            except Exception as exc:
                log.warning("memory decision attempt %d failed: %s", attempt, exc)
                continue
            validated = checker.validate(raw if isinstance(raw, MemoryDecision) else None, existing)
            if validated is not None:
                return validated
            log.warning("memory decision attempt %d was missing or invalid", attempt)
        return None

    async def run(self, request: AgentRequest, reply: str) -> MemoryOutcome:
        user_id = request.user_id
        if not user_id:
            return MemoryOutcome("no_user", "no user_id, nothing can be saved")
        async with self._locks.setdefault(user_id, asyncio.Lock()):  # one update at a time per user
            current = await asyncio.to_thread(self._store.read, user_id)
            existing = document.parse(current)
            inputs = {
                "skill": self._skill,
                "memory": current.strip() or "(empty)",
                "conversation": "\n".join(f"{t.role}: {t.content[:300]}" for t in request.history[-4:]) or "(none)",
                "user_message": request.message,
                "reply": reply,
            }
            decision = await self._decide(inputs, existing)
            if decision is None:
                return MemoryOutcome("undecided", "the agent did not give a valid decision")
            if decision.kind == "skip":
                return MemoryOutcome("skipped", decision.reason)
            new_doc, added, removed = document.apply(existing, decision.adds, decision.removes, self._today())
            await asyncio.to_thread(self._store.write, user_id, document.serialize(new_doc))
            return MemoryOutcome("updated", decision.reason, added, removed)
