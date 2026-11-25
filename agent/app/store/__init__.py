from functools import lru_cache

from app.store.db import Database
from app.store.stores import MemoryStore, UserDataStore


@lru_cache
def get_database() -> Database:
    return Database()


def get_data_store() -> UserDataStore:
    return UserDataStore(get_database())


def get_memory_store() -> MemoryStore:
    return MemoryStore(get_database())
