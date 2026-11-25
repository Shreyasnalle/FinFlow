"""Gives the agent its context: the user's numbers and memory, looked up by user_id.

Values sent inline on the request win (that is the open input); otherwise they come from the stores.
"""

import asyncio
import logging
from datetime import date

from app.agent.models import AgentRequest
from app.context.numbers import build_context
from app.context.snapshot import Snapshot
from app.store.stores import MemoryStore, UserDataStore

log = logging.getLogger(__name__)


class ContextProvider:
    def __init__(self, data: UserDataStore, memory: MemoryStore):
        self._data, self._memory = data, memory

    async def resolve(self, request: AgentRequest, today: date | None = None) -> AgentRequest:
        if not request.user_id:
            return request
        updates: dict = {}
        if request.user_data is None:
            raw = await asyncio.to_thread(self._data.get, request.user_id)
            if raw is not None:
                try:
                    updates["user_data"] = build_context(Snapshot.model_validate(raw), today)
                except Exception as exc:  # a bad stored snapshot must not break chatting
                    log.warning("could not build context for a stored snapshot: %s", exc)
        if request.memory is None:
            text = await asyncio.to_thread(self._memory.read, request.user_id)
            if text.strip():
                updates["memory"] = text
        return request.model_copy(update=updates) if updates else request
