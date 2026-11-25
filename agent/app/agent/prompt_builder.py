"""Builds the LangChain prompt: system (persona, skills, data, memory) + history + input."""

import json
from datetime import date
from pathlib import Path
from typing import Any

from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, trim_messages
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder

from app.agent.models import AgentRequest
from app.config import Settings
from app.followups.rules import FOLLOWUP_RULES
from app.skills.registry import SkillRegistry

SYSTEM_PROMPT = (Path(__file__).parent / "prompts" / "system.md").read_text(encoding="utf-8")

PROMPT = ChatPromptTemplate.from_messages(
    [
        ("system", SYSTEM_PROMPT),
        MessagesPlaceholder("history"),
        ("human", "{input}"),
    ]
)

_TAGS = ("</user_data>", "</memory>", "<user_data>", "<memory>")


def render_context(value: Any, limit: int) -> str:
    """Render open-ended user_data / memory (dict, list or text) as bounded text."""
    if value is None or value == "" or value == {} or value == []:
        return "(not provided)"
    text = value if isinstance(value, str) else json.dumps(value, separators=(",", ":"), default=str)  # compact: tokens are the bottleneck
    for tag in _TAGS:  # stop the data from closing/opening our delimiters
        text = text.replace(tag, "")
    if len(text) > limit:
        text = text[:limit] + "\n...(truncated)"
    return text


class PromptBuilder:
    def __init__(self, registry: SkillRegistry, settings: Settings, canary: str):
        self._registry = registry
        self._s = settings
        self._canary = canary

    def _history(self, request: AgentRequest) -> list[BaseMessage]:
        messages: list[BaseMessage] = [
            HumanMessage(t.content) if t.role == "user" else AIMessage(t.content)
            for t in request.history
        ]
        return trim_messages(
            messages,
            max_tokens=self._s.max_history_messages,
            token_counter=len,  # count messages, not tokens
            strategy="last",
            start_on="human",
            include_system=False,
        )

    def build(self, request: AgentRequest) -> list[BaseMessage]:
        return PROMPT.format_messages(
            today=date.today().strftime("%A, %d %B %Y"),
            canary=self._canary,
            max_skills=self._s.max_skills_per_query,
            max_searches=self._s.max_web_searches,
            skill_index=self._registry.index(),
            followup_rules=FOLLOWUP_RULES,
            user_data=render_context(request.user_data, self._s.max_context_chars),
            memory=render_context(request.memory, self._s.max_context_chars),
            history=self._history(request),
            input=request.message,
        )
