import asyncio
import logging
from functools import lru_cache

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from app.agent.models import AgentError, AgentRequest
from app.api.rate_limit import enforce_rate_limit
from app.api.schemas import ChatRequest, ChatResponse
from app.api.stream import event_stream
from app.service import ChatService
from app.status.reporter import StatusReporter
from app.status.sink import QueueSink

log = logging.getLogger(__name__)
router = APIRouter()

FRIENDLY_ERROR = "The finance coach is unavailable right now. Please try again."


@lru_cache
def get_service() -> ChatService:
    return ChatService.create()


@router.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@router.post("/chat", response_model=ChatResponse, dependencies=[Depends(enforce_rate_limit)])
async def chat(body: ChatRequest, service: ChatService = Depends(get_service)) -> ChatResponse:
    """Plain request/response (no live status)."""
    try:
        result = await service.handle(AgentRequest(**body.model_dump()))
    except AgentError:
        raise HTTPException(status_code=503, detail=FRIENDLY_ERROR)
    return ChatResponse(**result.__dict__)


@router.post("/chat/stream", dependencies=[Depends(enforce_rate_limit)])
async def chat_stream(body: ChatRequest, service: ChatService = Depends(get_service)) -> StreamingResponse:
    """Server-Sent Events: many `status` events, then one `result` (or `error`) event."""
    queue: asyncio.Queue = asyncio.Queue()
    reporter = StatusReporter(QueueSink(queue))

    async def work() -> None:
        try:
            result = await service.handle(AgentRequest(**body.model_dump()), reporter)
            await queue.put(("result", ChatResponse(**result.__dict__).model_dump()))
        except AgentError:
            await queue.put(("error", {"detail": FRIENDLY_ERROR}))
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("chat stream failed")
            await queue.put(("error", {"detail": FRIENDLY_ERROR}))
        finally:
            await queue.put(None)

    task = asyncio.create_task(work())
    return StreamingResponse(
        event_stream(queue, task),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
