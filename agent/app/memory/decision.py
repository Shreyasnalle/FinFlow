from typing import Literal

from pydantic import BaseModel, Field

Section = Literal["profile", "goals", "preferences", "situation", "notes"]


class MemoryItem(BaseModel):
    section: Section
    text: str = Field(max_length=300)


class MemoryDecision(BaseModel):
    """What the agent must return after every turn (structured output)."""

    decision: Literal["update", "skip"]
    reason: str = Field(default="", max_length=300, description="Why it was updated or skipped.")
    add: list[MemoryItem] = Field(default_factory=list, max_length=5)
    remove: list[str] = Field(default_factory=list, max_length=5, description="Exact outdated notes to delete.")
