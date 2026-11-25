"""Rejects oversized request bodies (HTTP 413) before they are read into memory.

Why: FastAPI reads a request's whole body into memory before validating it, so without a cap a single huge
upload could exhaust a small host (Render's free plan has 512 MB). Two checks:

- a declared `Content-Length` over the limit is refused immediately, before reading anything;
- a body with no (or a wrong) `Content-Length`, such as chunked uploads, is counted as it streams in and
  cut off once it passes the limit.
"""

from fastapi.exceptions import HTTPException
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

TOO_LARGE_MESSAGE = "That request is too large."
_BODYLESS = {"GET", "HEAD", "OPTIONS"}


class _TooLarge(HTTPException):
    """Raised from the body stream. It must be an HTTPException: FastAPI turns any other error raised while
    reading a body into a generic 400, but lets an HTTPException through to become a proper 413."""

    def __init__(self) -> None:
        super().__init__(status_code=413, detail=TOO_LARGE_MESSAGE)


class BodySizeLimitMiddleware:
    def __init__(self, app: ASGIApp, max_bytes: int) -> None:
        self.app = app
        self.max_bytes = max(1, max_bytes)

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope.get("method", "GET") in _BODYLESS:
            await self.app(scope, receive, send)
            return

        declared = _declared_length(scope)
        if declared is not None and declared > self.max_bytes:
            await _reject(scope, receive, send)
            return

        received = 0
        started = False

        async def limited_receive() -> Message:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_bytes:
                    raise _TooLarge()
            return message

        async def tracking_send(message: Message) -> None:
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, tracking_send)
        except _TooLarge:
            if not started:  # the app never got to answer: tell the client why
                await _reject(scope, receive, send)


def _declared_length(scope: Scope) -> int | None:
    for name, value in scope.get("headers", []):
        if name == b"content-length":
            try:
                return int(value)
            except ValueError:
                return None
    return None


async def _reject(scope: Scope, receive: Receive, send: Send) -> None:
    await JSONResponse({"detail": TOO_LARGE_MESSAGE}, status_code=413)(scope, receive, send)
