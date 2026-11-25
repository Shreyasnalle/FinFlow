"""Live status: the agent reports raw updates here; they are turned into friendly
status events and handed to a sink function, which delivers them to the frontend.

    agent / service  --update()-->  StatusReporter  --sink(event)-->  (e.g. QueueSink -> SSE stream)

Status is best-effort: a broken sink must never break the agent.
"""

import logging
import re
import time
from collections.abc import Awaitable, Callable

from app.status.events import Stage, StatusEvent

log = logging.getLogger(__name__)

StatusSink = Callable[[StatusEvent], Awaitable[None]]

_CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def _clean(text: str, limit: int = 80) -> str:
    text = _CONTROL.sub(" ", str(text)).strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def describe(stage: Stage, info: dict) -> tuple[str, str | None]:
    """(message, detail) shown to the user for each kind of agent update."""
    if stage == Stage.RECEIVED:
        return "Got your question", None
    if stage == Stage.READING_CONTEXT:
        return "Looking at your finances and what I know about you", None
    if stage == Stage.THINKING:
        return ("Thinking it through" if info.get("step", 1) <= 1 else "Working through the details"), None
    if stage == Stage.LOADING_SKILL:
        label = _clean(info.get("skill", "")).replace("_", " ")
        return f"Using my {label} know-how" if label else "Picking the right approach", label or None
    if stage == Stage.SEARCHING_WEB:
        query = _clean(info.get("query", ""))
        return (f"Searching the web for “{query}”" if query else "Searching the web"), query or None
    if stage == Stage.READING_RESULTS:
        return "Reading what I found", None
    if stage == Stage.WRITING:
        return "Writing your answer", None
    if stage == Stage.FOLLOWUPS:
        return "Preparing follow-up suggestions", None
    if stage == Stage.CHECKING:
        return "Double-checking the answer", None
    if stage == Stage.REMEMBERING:
        return "Noting anything worth remembering", None
    if stage == Stage.DONE:
        return "Ready", None
    return "Something went wrong", None


class StatusReporter:
    def __init__(self, sink: StatusSink | None = None):
        self._sink = sink
        self._seq = 0

    async def update(self, stage: Stage, **info) -> None:
        """Called by the agent / service for every update."""
        if self._sink is None:
            return
        self._seq += 1
        message, detail = describe(stage, info)
        event = StatusEvent(seq=self._seq, stage=stage, message=message, detail=detail, ts=time.time())
        try:
            await self._sink(event)
        except Exception as exc:  # never let status break the answer
            log.warning("status sink failed: %s", exc)


NULL_REPORTER = StatusReporter(None)
