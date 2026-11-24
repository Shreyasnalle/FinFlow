"""Server-Sent Events: streams live status events, then the final result, to the frontend."""

import asyncio
import json
from collections.abc import AsyncIterator

KEEPALIVE_S = 15


def sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


async def event_stream(queue: asyncio.Queue, task: asyncio.Task) -> AsyncIterator[str]:
    """Yield queue items as SSE until the worker puts None. Cancels the worker if the client leaves."""
    try:
        while True:
            try:
                item = await asyncio.wait_for(queue.get(), timeout=KEEPALIVE_S)
            except asyncio.TimeoutError:
                yield ": keepalive\n\n"  # keeps proxies from closing a quiet connection
                continue
            if item is None:
                break
            kind, payload = item
            yield sse(kind, payload)
    finally:
        if not task.done():
            task.cancel()
