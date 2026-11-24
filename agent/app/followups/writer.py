"""Repair step: ask the agent model to write ONLY the follow-ups when the reply lacked them."""

import logging

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel, Field

from app.agent.llm import build_chat_model
from app.agent.models import AgentRequest
from app.agent.prompt_builder import render_context
from app.config import Settings
from app.followups.checker import validate
from app.followups.rules import RULES_ONLY

log = logging.getLogger(__name__)

PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            "You write the follow-up question suggestions for FinFlow Coach, a personal-finance assistant.\n"
            "Return exactly three questions as structured output (ignore any output-format instructions).\n\n"
            "{rules}",
        ),
        (
            "human",
            "<user_data>\n{user_data}\n</user_data>\n\n<memory>\n{memory}\n</memory>\n\n"
            "<user_message>\n{user_message}\n</user_message>\n\n"
            "<assistant_answer>\n{answer}\n</assistant_answer>\n\n"
            "Write the three follow-up questions.",
        ),
    ]
)


class FollowUpSet(BaseModel):
    questions: list[str] = Field(min_length=3, max_length=3)


class FollowUpWriter:
    def __init__(self, settings: Settings, llm: BaseChatModel | None = None):
        self._s = settings
        model = llm or build_chat_model(
            settings.agent_model, settings.agent_temperature, settings, settings.agent_reasoning_effort
        )
        self._chain = PROMPT | model.with_structured_output(FollowUpSet, method="json_schema")

    async def write(self, request: AgentRequest, answer: str) -> list[str] | None:
        inputs = {
            "rules": RULES_ONLY,
            "user_data": render_context(request.user_data, self._s.max_context_chars),
            "memory": render_context(request.memory, self._s.max_context_chars),
            "user_message": request.message,
            "answer": answer,
        }
        for attempt in (1, 2):
            try:
                result = await self._chain.ainvoke(inputs)
                questions = validate(getattr(result, "questions", None))
                if questions:
                    return questions
                log.warning("follow-up repair attempt %d returned unusable questions", attempt)
            except Exception as exc:
                log.warning("follow-up repair attempt %d failed: %s", attempt, exc)
        return None
