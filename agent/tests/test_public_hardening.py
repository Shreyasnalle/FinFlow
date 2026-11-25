"""Protections for a publicly reachable deployment: /users rate limits, request-size cap, users on/off switch."""

import json

import pytest
from fastapi.testclient import TestClient

from app.api.body_limit import TOO_LARGE_MESSAGE
from app.api.rate_limit import Limits, RateLimiter, get_limiter, get_users_limiter
from app.api.routes import get_service
from app.config import Settings, get_settings
from app.main import app as default_app
from app.main import create_app
from app.service import ChatResult
from app.store import get_data_store, get_memory_store
from app.store.db import Database
from app.store.stores import MemoryStore, UserDataStore


class StubService:
    def __init__(self):
        self.calls = 0

    async def handle(self, request, reporter=None):
        self.calls += 1
        return ChatResult(reply="ok", followups=["a?", "b?", "c?"])


@pytest.fixture
def make_client():
    """Builds an app + client with the given settings; stores are in memory, the model is stubbed."""
    created = []

    def build(**overrides) -> tuple[TestClient, StubService]:
        settings = Settings(_env_file=None, groq_api_key="test", **overrides)
        app = create_app(settings)
        db, stub, limiters = Database(":memory:"), StubService(), {}
        app.dependency_overrides[get_settings] = lambda: settings
        app.dependency_overrides[get_service] = lambda: stub
        app.dependency_overrides[get_data_store] = lambda: UserDataStore(db)
        app.dependency_overrides[get_memory_store] = lambda: MemoryStore(db)
        app.dependency_overrides[get_limiter] = lambda: limiters.setdefault("chat", RateLimiter(Limits.from_settings(settings)))
        app.dependency_overrides[get_users_limiter] = lambda: limiters.setdefault(
            "users", RateLimiter(Limits.users_from_settings(settings))
        )
        created.append(app)
        return TestClient(app), stub

    yield build
    for app in created:
        app.dependency_overrides.clear()


# ---- /users rate limiting -------------------------------------------------------------------


def test_users_endpoints_are_rate_limited_with_their_own_budget(make_client):
    client, _ = make_client(rate_limit_users_per_minute=2)
    assert client.put("/users/abc/data", json={"transactions": []}).status_code == 200
    assert client.get("/users/abc/memory").status_code == 200
    blocked = client.delete("/users/abc/memory")
    assert blocked.status_code == 429 and 1 <= int(blocked.headers["retry-after"]) <= 60
    # the chat budget is separate, so syncing data cannot use up chat quota (or the reverse)
    assert client.post("/chat", json={"message": "hi"}).status_code == 200


def test_chat_budget_does_not_affect_users_endpoints(make_client):
    client, _ = make_client(rate_limit_per_minute=1)
    assert client.post("/chat", json={"message": "hi"}).status_code == 200
    assert client.post("/chat", json={"message": "hi"}).status_code == 429
    assert client.get("/users/abc/memory").status_code == 200


def test_users_global_cap_applies_across_clients(make_client):
    client, _ = make_client(rate_limit_users_global_per_minute=2, rate_limit_users_per_minute=50)
    assert client.get("/users/a/memory").status_code == 200
    assert client.get("/users/b/memory").status_code == 200
    assert client.get("/users/c/memory").status_code == 429


def test_every_users_route_is_limited(make_client):
    client, _ = make_client(rate_limit_users_per_minute=1)
    assert client.get("/users/abc/context").status_code == 200  # uses the one allowed request
    for call in (
        lambda: client.put("/users/abc/data", json={"transactions": []}),
        lambda: client.get("/users/abc/context"),
        lambda: client.get("/users/abc/memory"),
        lambda: client.delete("/users/abc/memory"),
    ):
        assert call().status_code == 429


# ---- request size cap ------------------------------------------------------------------------


def test_declared_oversized_body_is_refused_before_it_is_read(make_client):
    client, stub = make_client(max_request_bytes=1000)
    r = client.post("/chat", json={"message": "x" * 1900})  # valid for the schema, but over the cap
    assert r.status_code == 413 and r.json() == {"detail": TOO_LARGE_MESSAGE}
    assert stub.calls == 0


def test_chunked_body_without_content_length_is_cut_off(make_client):
    client, stub = make_client(max_request_bytes=1000)
    chunks = (b'{"message": "' + b"a" * 600, b"b" * 600 + b'"}')
    r = client.post("/chat", content=iter(chunks), headers={"content-type": "application/json"})
    assert r.status_code == 413
    assert stub.calls == 0


def test_normal_sized_requests_still_work(make_client):
    client, stub = make_client(max_request_bytes=1000)
    assert client.post("/chat", json={"message": "hi"}).status_code == 200
    assert client.get("/health").status_code == 200
    assert stub.calls == 1


def test_size_cap_applies_to_data_uploads_too(make_client):
    client, _ = make_client(max_request_bytes=1000)
    big = {"transactions": [{"date": "2026-01-01T00:00:00", "amount": 1, "note": "n" * 50} for _ in range(30)]}
    assert client.put("/users/abc/data", json=big).status_code == 413


def test_default_cap_fits_the_largest_legitimate_snapshot():
    """5000 transactions is the schema maximum; the default cap must not reject a valid full snapshot."""
    txn = {
        "date": "2026-11-24T18:30:00.123456",
        "amount": 1234567.89,
        "category": "Entertainment & Subscriptions",
        "note": "n" * 120,
        "is_income": False,
        "is_investment": False,
    }
    snapshot = {
        "profile": {"name": "N" * 40, "profession": "P" * 40, "currency": "₹ INR"},
        "cash_balance": 1.0,
        "transactions": [txn] * 5000,
        "budgets": {f"category {i}": 1000.0 for i in range(50)},
        "goals": [{"title": "t" * 60, "target_amount": 1.0, "saved_amount": 1.0}] * 100,
        "bills": [{"name": "b" * 60, "amount": 1.0, "due_date": "2026-11-24T00:00:00"}] * 200,
        "assets": [{"name": "a" * 60, "value": 1.0, "type": "t" * 20}] * 200,
    }
    size = len(json.dumps(snapshot).encode())
    assert size < Settings(_env_file=None).max_request_bytes, f"largest valid snapshot is {size} bytes"


# ---- users switch ----------------------------------------------------------------------------


def test_users_endpoints_can_be_switched_off(make_client):
    client, _ = make_client(users_api_enabled=False)
    for r in (
        client.get("/users/abc/memory"),
        client.put("/users/abc/data", json={}),
        client.get("/users/abc/context"),
        client.delete("/users/abc/memory"),
    ):
        assert r.status_code in (404, 405)
    # chat and health are unaffected
    assert client.get("/health").status_code == 200
    assert client.post("/chat", json={"message": "hi"}).status_code == 200


def test_users_endpoints_are_on_by_default_and_app_object_still_exists():
    assert Settings(_env_file=None).users_api_enabled is True
    paths = set(default_app.openapi()["paths"])
    assert "/users/{user_id}/data" in paths and "/chat" in paths and "/health" in paths
