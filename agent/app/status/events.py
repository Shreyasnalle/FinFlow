from enum import Enum

from pydantic import BaseModel


class Stage(str, Enum):
    RECEIVED = "received"
    READING_CONTEXT = "reading_context"
    THINKING = "thinking"
    LOADING_SKILL = "loading_skill"
    SEARCHING_WEB = "searching_web"
    READING_RESULTS = "reading_results"
    WRITING = "writing"
    FOLLOWUPS = "followups"
    CHECKING = "checking"
    DONE = "done"
    ERROR = "error"


class StatusEvent(BaseModel):
    """What the frontend receives. `message` is ready to render as-is."""

    seq: int  # 1, 2, 3... so the frontend can order or de-duplicate
    stage: Stage
    message: str
    detail: str | None = None
    ts: float  # unix seconds
