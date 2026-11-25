import json
import time

from app.store.db import Database


class UserDataStore:
    """The latest data snapshot the app synced for each user."""

    def __init__(self, db: Database):
        self._db = db

    def put(self, user_id: str, snapshot: dict) -> float:
        now = time.time()
        self._db.execute(
            "INSERT INTO user_snapshots (user_id, snapshot, updated_at) VALUES (?, ?, ?) "
            "ON CONFLICT(user_id) DO UPDATE SET snapshot = excluded.snapshot, updated_at = excluded.updated_at",
            (user_id, json.dumps(snapshot, default=str), now),
        )
        return now

    def get(self, user_id: str) -> dict | None:
        rows = self._db.execute("SELECT snapshot FROM user_snapshots WHERE user_id = ?", (user_id,))
        return json.loads(rows[0][0]) if rows else None

    def delete(self, user_id: str) -> None:
        self._db.execute("DELETE FROM user_snapshots WHERE user_id = ?", (user_id,))


class MemoryStore:
    """The agent's memory.md for each user (markdown text)."""

    def __init__(self, db: Database):
        self._db = db

    def read(self, user_id: str) -> str:
        rows = self._db.execute("SELECT content FROM user_memory WHERE user_id = ?", (user_id,))
        return rows[0][0] if rows else ""

    def write(self, user_id: str, content: str) -> None:
        self._db.execute(
            "INSERT INTO user_memory (user_id, content, updated_at) VALUES (?, ?, ?) "
            "ON CONFLICT(user_id) DO UPDATE SET content = excluded.content, updated_at = excluded.updated_at",
            (user_id, content, time.time()),
        )

    def delete(self, user_id: str) -> None:
        self._db.execute("DELETE FROM user_memory WHERE user_id = ?", (user_id,))
