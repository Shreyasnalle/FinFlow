"""The classifier agent from the flow diagram: draft in, allow/block out.

It is a separate, tool-less model call that sees only the user's message and the
draft (no user data, no memory). Any failure blocks the draft (fail closed).
"""

import logging
from pathlib import Path

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.prompts import ChatPromptTemplate

from app.agent.llm import build_chat_model
from app.config import Settings
from app.guardrails.checks import deterministic_check
from app.guardrails.verdict import Category, GuardrailDecision

log = logging.getLogger(__name__)

POLICY = (Path(__file__).parent / "prompts" / "classifier.md").read_text(encoding="utf-8")

PROMPT = ChatPromptTemplate.from_messages(
    [
        ("system", POLICY),
        (
            "human",
            "<user_message>\n{user_message}\n</user_message>\n\n"
            "<draft_reply>\n{draft}\n</draft_reply>\n\n"
            "Classify the draft.",
        ),
    ]
)


class ResponseClassifier:
    def __init__(self, settings: Settings, canary: str, llm: BaseChatModel | None = None):
        model = llm or build_chat_model(
            settings.classifier_model, 0.0, settings, settings.classifier_reasoning_effort
        )
        self._chain = PROMPT | model.with_structured_output(GuardrailDecision, method="json_schema")
        self._canary = canary

    async def check(self, user_message: str, draft: str) -> GuardrailDecision:
        # 1. Cheap, deterministic checks first.
        blocked = deterministic_check(draft, self._canary)
        if blocked is not None:
            return GuardrailDecision(allowed=False, category=blocked, reason="deterministic check")

        # 2. The classifier LLM.
        decision = None
        for attempt in (1, 2):  # one retry: structured output is occasionally malformed
            try:
                decision = await self._chain.ainvoke({"user_message": user_message, "draft": draft})
                break
            except Exception as exc:
                log.warning("classifier attempt %d failed: %s", attempt, exc)
        if decision is None:
            return GuardrailDecision(allowed=False, category=Category.CHECK_FAILED, reason="classifier error")
        if not isinstance(decision, GuardrailDecision):
            return GuardrailDecision(allowed=False, category=Category.CHECK_FAILED, reason="unparseable")

        # 3. Enforce consistency so a confused model can never let something through.
        if decision.allowed and decision.category != Category.OK:
            decision.allowed = False
        if not decision.allowed and decision.category == Category.OK:
            decision.category = Category.OTHER
        return decision
