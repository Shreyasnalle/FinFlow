"""Endpoints for the app to sync a user's data to the backend and to view/clear what the coach remembers.

NOTE: these identify the user only by the `user_id` in the path. Add real authentication before
exposing them publicly; anyone who knows an id could read or replace that user's data.
"""

import asyncio
from datetime import date

from fastapi import APIRouter, Depends, Path

from app.api.rate_limit import enforce_users_rate_limit
from app.context.numbers import build_context
from app.context.snapshot import Snapshot
from app.store import get_data_store, get_memory_store
from app.store.stores import MemoryStore, UserDataStore

router = APIRouter(prefix="/users", tags=["users"], dependencies=[Depends(enforce_users_rate_limit)])
UserId = Path(pattern=r"^[A-Za-z0-9_-]{1,64}$")


@router.put("/{user_id}/data")
async def put_data(snapshot: Snapshot, user_id: str = UserId, store: UserDataStore = Depends(get_data_store)) -> dict:
    """Replace the user's latest data snapshot (profile, transactions, budgets, goals, bills, assets)."""
    updated = await asyncio.to_thread(store.put, user_id, snapshot.model_dump(mode="json"))
    return {"ok": True, "updated_at": updated, "transactions": len(snapshot.transactions)}


@router.get("/{user_id}/context")
async def get_context(user_id: str = UserId, store: UserDataStore = Depends(get_data_store)) -> dict:
    """The computed numbers the agent sees (useful for checking what was synced)."""
    raw = await asyncio.to_thread(store.get, user_id)
    if raw is None:
        return {"found": False}
    return {"found": True, "context": build_context(Snapshot.model_validate(raw), date.today())}


@router.get("/{user_id}/memory")
async def get_memory(user_id: str = UserId, store: MemoryStore = Depends(get_memory_store)) -> dict:
    """What the coach has remembered about the user (markdown)."""
    return {"memory": await asyncio.to_thread(store.read, user_id)}


@router.delete("/{user_id}/memory")
async def clear_memory(user_id: str = UserId, store: MemoryStore = Depends(get_memory_store)) -> dict:
    await asyncio.to_thread(store.delete, user_id)
    return {"ok": True}
