"""Sinks: the 'another function' that receives status events and forwards them toward the frontend."""

import asyncio

from app.status.events import StatusEvent


class QueueSink:
    """Pushes events onto an asyncio queue that the SSE stream (app/api/stream.py) drains."""

    def __init__(self, queue: asyncio.Queue):
        self._queue = queue

    async def __call__(self, event: StatusEvent) -> None:
        await self._queue.put(("status", event.model_dump(mode="json")))
