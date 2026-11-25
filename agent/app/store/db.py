"""Tiny SQLite layer for the backend's own data (user snapshots and agent memory).

The Flutter app keeps its data on the phone; the agent runs on a server, so the app syncs a
snapshot here (PUT /users/{id}/data) and the agent's memory lives here too.
"""

import sqlite3
import threading
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[2]


class StoreSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ROOT / ".env", extra="ignore")
    finflow_agent_db: str | None = None  # path to the SQLite file; default agent/data/finflow_agent.db


SCHEMA = """
CREATE TABLE IF NOT EXISTS user_snapshots (
  user_id TEXT PRIMARY KEY, snapshot TEXT NOT NULL, updated_at REAL NOT NULL);
CREATE TABLE IF NOT EXISTS user_memory (
  user_id TEXT PRIMARY KEY, content TEXT NOT NULL, updated_at REAL NOT NULL);
"""


class Database:
    def __init__(self, path: str | Path | None = None):
        path = str(path or StoreSettings().finflow_agent_db or ROOT / "data" / "finflow_agent.db")
        if path != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._lock = threading.Lock()
        with self._lock:
            self._conn.executescript(SCHEMA)
            self._conn.commit()

    def execute(self, sql: str, params: tuple = ()) -> list[tuple]:
        with self._lock:
            cur = self._conn.execute(sql, params)
            rows = cur.fetchall()
            self._conn.commit()
            return rows
