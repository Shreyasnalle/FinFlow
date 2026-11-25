import logging

from fastapi import FastAPI

from app.api.routes import router
from app.api.users import router as users_router

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

app = FastAPI(title="FinFlow Finance Agent", version="0.1.0")
app.include_router(router)
app.include_router(users_router)
