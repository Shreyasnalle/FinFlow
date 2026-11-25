from typing import Any

from pydantic import BaseModel, Field, field_validator

from app.agent.models import ChatTurn


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    # With a user_id the backend looks up the user's synced data and memory itself.
    user_id: str | None = Field(default=None, pattern=r"^[A-Za-z0-9_-]{1,64}$")
    history: list[ChatTurn] = Field(default_factory=list, max_length=40)
    # Open on purpose: filled by the backend / database layer, any JSON or text.
    user_data: Any = None
    memory: Any = None

    @field_validator("message")
    @classmethod
    def not_blank(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("message must not be blank")
        return v


class ChatResponse(BaseModel):
    reply: str
    blocked: bool = False
    category: str | None = None
    skills_used: list[str] = Field(default_factory=list)
    sources: list[str] = Field(default_factory=list)
    followups: list[str] = Field(default_factory=list)  # 3 tappable questions
    followups_source: str = "fallback"  # agent | repair | fallback
    memory_status: str = "disabled"  # updated | skipped | undecided | no_user | disabled | error
