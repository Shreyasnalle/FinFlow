from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.agent.models import AgentRequest
from app.api.rate_limit import DAY, BUSY_MESSAGE, SLOW_DOWN_MESSAGE, Limits, RateLimiter, client_key, get_limiter
from app.api.routes import get_service
from app.config import Settings, get_settings
from app.main import app
from app.service import ChatResult


class Clock:
    def __init__(self, t: float = 1_000_000.0):
        self.t = t

    def __call__(self) -> float:
        return self.t


def limiter(clock=None, **overrides) -> RateLimiter:
    base = dict(per_minute=3, per_day=100, global_per_minute=100, global_per_day=1000, max_clients=50)
    return RateLimiter(Limits(**{**base, **overrides}), clock or Clock())


# ---- the limiter itself ---------------------------------------------------------------------


def test_blocks_after_per_minute_limit_with_retry_after():
    clock = Clock()
    rl = limiter(clock)
    assert all(rl.check("a").allowed for _ in range(3))
    blocked = rl.check("a")
    assert not blocked.allowed and blocked.scope == "ip-minute"
    assert blocked.retry_after == 60  # the oldest request leaves the window in a full minute


def test_window_slides_and_frees_slots_gradually():
    clock = Clock()
    rl = limiter(clock)
    rl.check("a")  # t0
    clock.t += 30
    rl.check("a")
    rl.check("a")
    assert not rl.check("a").allowed
    clock.t += 31  # t0 request is now older than 60 s, the other two are not
    assert rl.check("a").allowed
    assert not rl.check("a").allowed


def test_clients_are_independent():
    rl = limiter()
    assert all(rl.check("a").allowed for _ in range(3))
    assert not rl.check("a").allowed
    assert rl.check("b").allowed


def test_blocked_requests_do_not_consume_budget():
    clock = Clock()
    rl = limiter(clock)
    for _ in range(3):
        rl.check("a")
    for _ in range(50):  # hammering while blocked must not extend the penalty
        assert not rl.check("a").allowed
    clock.t += 61
    assert rl.check("a").allowed


def test_per_day_limit_and_reset_at_utc_midnight():
    clock = Clock(5 * DAY + 100)
    rl = limiter(clock, per_minute=100, per_day=4)
    for _ in range(4):
        clock.t += 61
        assert rl.check("a").allowed
    clock.t += 61
    blocked = rl.check("a")
    assert not blocked.allowed and blocked.scope == "ip-day"
    assert blocked.retry_after == pytest.approx(6 * DAY - clock.t, abs=1)
    clock.t = 6 * DAY + 1
    assert rl.check("a").allowed


def test_global_limit_caps_all_clients_together():
    rl = limiter(global_per_minute=5, per_minute=100)
    results = [rl.check(f"client-{i}") for i in range(7)]
    assert [r.allowed for r in results] == [True] * 5 + [False] * 2
    assert results[5].scope == "global-minute"


def test_global_day_limit():
    clock = Clock(3 * DAY + 10)
    rl = limiter(clock, global_per_minute=100, global_per_day=3, per_minute=100)
    for i in range(3):
        clock.t += 61
        assert rl.check(f"c{i}").allowed
    clock.t += 61
    assert rl.check("new").scope == "global-day"


def test_memory_is_bounded_by_max_clients():
    rl = limiter(max_clients=10, global_per_minute=10_000, global_per_day=10_000)
    for i in range(500):
        assert rl.check(f"10.0.{i // 250}.{i % 250}").allowed
    assert rl.tracked_clients == 10


def test_least_recently_seen_client_is_evicted_first():
    rl = limiter(max_clients=2, per_minute=1)
    rl.check("a")
    rl.check("b")
    rl.check("a")  # blocked, but a is now the most recently seen
    rl.check("c")  # evicts b
    assert not rl.check("a").allowed  # a kept its history
    assert rl.check("b").allowed  # b was forgotten


# ---- identifying the client -----------------------------------------------------------------


def req(headers=None, host="9.9.9.9"):
    return SimpleNamespace(headers=headers or {}, client=SimpleNamespace(host=host) if host else None)


def test_client_key_uses_socket_peer_without_a_configured_header():
    assert client_key(req({"x-forwarded-for": "1.2.3.4"}), None) == "9.9.9.9"
    assert client_key(req(host=None), None) == "unknown"


def test_client_key_reads_from_the_right_so_clients_cannot_spoof():
    # the client prepended "6.6.6.6"; the trusted proxy appended the real address last
    r = req({"x-forwarded-for": "6.6.6.6, 203.0.113.7"})
    assert client_key(r, "x-forwarded-for", hops=1) == "203.0.113.7"
    # two trusted proxies append two entries: client address, then an internal hop
    r = req({"x-forwarded-for": "6.6.6.6, 203.0.113.7, 10.1.1.1"})
    assert client_key(r, "x-forwarded-for", hops=2) == "203.0.113.7"


def test_client_key_falls_back_to_peer_on_unusable_headers():
    assert client_key(req({"x-forwarded-for": "not-an-ip"}), "x-forwarded-for") == "9.9.9.9"
    assert client_key(req({"x-forwarded-for": ""}), "x-forwarded-for") == "9.9.9.9"
    assert client_key(req({"x-forwarded-for": "203.0.113.7"}), "x-forwarded-for", hops=2) == "9.9.9.9"
    assert client_key(req({}), "x-forwarded-for") == "9.9.9.9"


def test_ipv6_clients_share_one_limit_per_slash_64():
    a = client_key(req({"x-forwarded-for": "2001:db8:1:2::1"}), "x-forwarded-for")
    b = client_key(req({"x-forwarded-for": "2001:db8:1:2:ffff:ffff:ffff:ffff"}), "x-forwarded-for")
    c = client_key(req({"x-forwarded-for": "2001:db8:1:3::1"}), "x-forwarded-for")
    assert a == b == "2001:db8:1:2::/64" and c != a


# ---- through the real endpoints -------------------------------------------------------------


class StubService:
    def __init__(self):
        self.calls = 0

    async def handle(self, request: AgentRequest, reporter=None):
        self.calls += 1
        return ChatResult(reply="ok", followups=["a?", "b?", "c?"])


@pytest.fixture
def api():
    stub = StubService()

    def configure(**setting_overrides):
        settings = Settings(_env_file=None, groq_api_key="test", **setting_overrides)
        app.dependency_overrides[get_settings] = lambda: settings
        app.dependency_overrides[get_limiter] = lambda: limiter_for(settings)
        app.dependency_overrides[get_service] = lambda: stub
        return TestClient(app)

    cache = {}

    def limiter_for(settings):  # one limiter per configure() call, shared by every request
        return cache.setdefault("rl", RateLimiter(Limits.from_settings(settings)))

    yield configure, stub
    app.dependency_overrides.clear()


def test_chat_returns_429_with_retry_after_and_never_reaches_the_model(api):
    configure, stub = api
    client = configure(rate_limit_per_minute=2)
    for _ in range(2):
        assert client.post("/chat", json={"message": "hi"}).status_code == 200
    r = client.post("/chat", json={"message": "hi"})
    assert r.status_code == 429
    assert r.json() == {"detail": SLOW_DOWN_MESSAGE}
    assert 1 <= int(r.headers["retry-after"]) <= 60
    assert stub.calls == 2  # the blocked request never spent any model quota


def test_stream_endpoint_is_limited_too(api):
    configure, stub = api
    client = configure(rate_limit_per_minute=1)
    assert client.post("/chat/stream", json={"message": "hi"}).status_code == 200
    r = client.post("/chat/stream", json={"message": "hi"})
    assert r.status_code == 429 and "retry-after" in r.headers


def test_chat_and_stream_share_one_budget(api):
    configure, _ = api
    client = configure(rate_limit_per_minute=1)
    assert client.post("/chat", json={"message": "hi"}).status_code == 200
    assert client.post("/chat/stream", json={"message": "hi"}).status_code == 429


def test_global_limit_message_differs_from_per_client_message(api):
    configure, _ = api
    client = configure(rate_limit_global_per_minute=1, rate_limit_per_minute=50)
    assert client.post("/chat", json={"message": "hi"}).status_code == 200
    r = client.post("/chat", json={"message": "hi"})
    assert r.status_code == 429 and r.json()["detail"] == BUSY_MESSAGE


def test_health_is_never_limited(api):
    configure, _ = api
    client = configure(rate_limit_per_minute=1, rate_limit_global_per_minute=1)
    client.post("/chat", json={"message": "hi"})
    assert all(client.get("/health").status_code == 200 for _ in range(30))


def test_disabled_limiter_never_blocks(api):
    configure, stub = api
    client = configure(rate_limit_enabled=False, rate_limit_per_minute=1, rate_limit_global_per_minute=1)
    assert all(client.post("/chat", json={"message": "hi"}).status_code == 200 for _ in range(5))
    assert stub.calls == 5


def test_proxy_header_separates_clients_and_ignores_spoofed_left_entries(api):
    configure, _ = api
    client = configure(
        rate_limit_per_minute=1, rate_limit_client_ip_header="X-Forwarded-For", rate_limit_forwarded_hops=1
    )
    post = lambda xff: client.post("/chat", json={"message": "hi"}, headers={"X-Forwarded-For": xff}).status_code
    assert post("1.1.1.1, 203.0.113.7") == 200
    assert post("2.2.2.2, 203.0.113.7") == 429  # new spoofed entry, same real client
    assert post("2.2.2.2, 198.51.100.9") == 200  # a genuinely different client


def test_invalid_body_still_counts_against_the_limit(api):
    configure, _ = api
    client = configure(rate_limit_per_minute=2)
    assert client.post("/chat", json={"message": "  "}).status_code == 422
    assert client.post("/chat", json={"message": "  "}).status_code == 422
    assert client.post("/chat", json={"message": "hi"}).status_code == 429
