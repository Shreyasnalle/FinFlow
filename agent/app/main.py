import logging

from fastapi import FastAPI

from app.api.body_limit import BodySizeLimitMiddleware
from app.api.routes import router
from app.api.users import router as users_router
from app.config import Settings, get_settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger(__name__)


def create_app(settings: Settings | None = None) -> FastAPI:
    s = settings or get_settings()
    app = FastAPI(title="FinFlow Finance Agent", version="0.1.0")
    app.add_middleware(BodySizeLimitMiddleware, max_bytes=s.max_request_bytes)
    app.include_router(router)
    if s.users_api_enabled:
        app.include_router(users_router)
    else:
        log.info("users API disabled (USERS_API_ENABLED=false): /users/* is not served")
    return app


app = create_app()
