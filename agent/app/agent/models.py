"""Plain data types shared by the agent."""

from dataclasses import dataclass, field
from typing import Any, Literal

from pydantic import BaseModel, Field


class ChatTurn(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(max_length=4000)


class AgentRequest(BaseModel):
    """Everything the agent needs for one turn.

    `user_data` and `memory` are deliberately open (any JSON or text): the caller
    (backend / database layer) fills them in; the agent only renders them.
    """

    message: str
    user_id: str | None = None  # lets the backend look up this user's data and memory
    history: list[ChatTurn] = Field(default_factory=list)
    user_data: Any = None
    memory: Any = None


@dataclass
class RunState:
    """Per-request bookkeeping that tools read and the Python checker enforces."""

    loaded_skills: list[str] = field(default_factory=list)
    web_searches: int = 0
    sources: list[str] = field(default_factory=list)
    steps: int = 0


@dataclass
class AgentResult:
    draft: str
    skills_used: list[str]
    sources: list[str]
    steps: int
    followups: list[str] = field(default_factory=list)
    followups_source: str = "agent"  # agent | repair | fallback


class AgentError(RuntimeError):
    """The agent could not produce a draft (provider down, malformed tool loop...)."""
