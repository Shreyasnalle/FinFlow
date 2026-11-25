"""In-memory rate limiting for the chat endpoints.

Why: the API is public and every chat spends model quota, so one noisy client (or a script) must
not be able to drain it. Two layers:

- per client IP: a sliding 60 s window plus a per-day count (stops one client hammering);
- global: the same two limits across all clients (caps total cost even if IPs are spoofed or rotated).

State lives in this process only, so run a single worker. Counters reset on restart or when a
sleeping host wakes up, which is acceptable for a free-tier deployment. Memory is bounded: each
client keeps at most `per_minute` timestamps and at most `max_clients` clients are tracked.
"""

import ipaddress
import logging
import math
import time
from collections import OrderedDict, deque
from dataclasses import dataclass
from functools import lru_cache
from threading import Lock
from typing import Callable

from fastapi import Depends, HTTPException, Request

from app.config import Settings, get_settings

log = logging.getLogger(__name__)

MINUTE = 60.0
DAY = 86400.0

SLOW_DOWN_MESSAGE = "You're sending messages too quickly. Please wait a moment and try again."
BUSY_MESSAGE = "The finance coach is busy right now. Please try again a little later."


@dataclass(frozen=True)
class Limits:
    per_minute: int
    per_day: int
    global_per_minute: int
    global_per_day: int
    max_clients: int

    @classmethod
    def from_settings(cls, s: Settings) -> "Limits":
        return cls(
            per_minute=max(1, s.rate_limit_per_minute),
            per_day=max(1, s.rate_limit_per_day),
            global_per_minute=max(1, s.rate_limit_global_per_minute),
            global_per_day=max(1, s.rate_limit_global_per_day),
            max_clients=max(1, s.rate_limit_max_clients),
        )

    @classmethod
    def users_from_settings(cls, s: Settings) -> "Limits":
        """Separate budgets for the /users endpoints (data sync and memory)."""
        return cls(
            per_minute=max(1, s.rate_limit_users_per_minute),
            per_day=max(1, s.rate_limit_users_per_day),
            global_per_minute=max(1, s.rate_limit_users_global_per_minute),
            global_per_day=max(1, s.rate_limit_users_global_per_day),
            max_clients=max(1, s.rate_limit_max_clients),
        )


@dataclass(frozen=True)
class Decision:
    allowed: bool
    retry_after: int = 0  # whole seconds, >= 1 when blocked
    scope: str = ""  # which limit blocked: ip-minute | ip-day | global-minute | global-day


class _Counter:
    """A sliding one-minute window plus a per-UTC-day count."""

    __slots__ = ("minute", "day_id", "day_count")

    def __init__(self) -> None:
        self.minute: deque[float] = deque()
        self.day_id = -1
        self.day_count = 0

    def _roll(self, now: float) -> None:
        cutoff = now - MINUTE
        while self.minute and self.minute[0] <= cutoff:
            self.minute.popleft()
        day = int(now // DAY)
        if day != self.day_id:
            self.day_id, self.day_count = day, 0

    def blocked_by(self, now: float, per_minute: int, per_day: int) -> tuple[int, str] | None:
        """(seconds until allowed, 'minute' | 'day') when over a limit, else None."""
        self._roll(now)
        if len(self.minute) >= per_minute:
            return max(1, math.ceil(self.minute[0] + MINUTE - now)), "minute"
        if self.day_count >= per_day:
            return max(1, math.ceil((self.day_id + 1) * DAY - now)), "day"
        return None

    def record(self, now: float) -> None:
        self._roll(now)  # a brand-new counter has no day bucket yet
        self.minute.append(now)
        self.day_count += 1


class RateLimiter:
    def __init__(self, limits: Limits, clock: Callable[[], float] = time.time) -> None:
        self._limits = limits
        self._clock = clock
        self._lock = Lock()
        self._global = _Counter()
        self._clients: OrderedDict[str, _Counter] = OrderedDict()

    @property
    def tracked_clients(self) -> int:
        return len(self._clients)

    def check(self, client: str) -> Decision:
        """Counts the request and returns allowed, or says which limit blocked it.

        A blocked request is not counted, so waiting out the penalty is enough."""
        lim, now = self._limits, self._clock()
        with self._lock:
            hit = self._global.blocked_by(now, lim.global_per_minute, lim.global_per_day)
            if hit:
                return Decision(False, hit[0], f"global-{hit[1]}")

            counter = self._clients.get(client)
            if counter is not None:
                hit = counter.blocked_by(now, lim.per_minute, lim.per_day)
                if hit:
                    self._clients.move_to_end(client)
                    return Decision(False, hit[0], f"ip-{hit[1]}")
            else:
                counter = self._clients[client] = _Counter()

            self._clients.move_to_end(client)
            while len(self._clients) > lim.max_clients:
                self._clients.popitem(last=False)  # forget the least recently seen client
            counter.record(now)
            self._global.record(now)
            return Decision(True)


def _normalise(ip: str) -> str | None:
    """A canonical key, or None if `ip` is not an IP. IPv6 clients are grouped by /64, because
    one subscriber controls a whole /64 and could otherwise dodge the limit by rotating addresses."""
    try:
        addr = ipaddress.ip_address(ip.strip())
    except ValueError:
        return None
    if addr.version == 6:
        return str(ipaddress.ip_network(f"{addr}/64", strict=False))
    return str(addr)


def client_key(request: Request, header: str | None, hops: int = 1) -> str:
    """Who is calling. Uses the proxy header only when one is configured, reading from the right
    (clients can freely add entries on the left); anything unusable falls back to the socket peer."""
    if header:
        raw = request.headers.get(header)
        if raw:
            parts = [p for p in (x.strip() for x in raw.split(",")) if p]
            if 1 <= hops <= len(parts):
                key = _normalise(parts[-hops])
                if key:
                    return key
    peer = request.client.host if request.client else ""
    return _normalise(peer) or peer or "unknown"


@lru_cache
def get_limiter() -> RateLimiter:
    """Budget for POST /chat and /chat/stream."""
    return RateLimiter(Limits.from_settings(get_settings()))


@lru_cache
def get_users_limiter() -> RateLimiter:
    """Separate budget for the /users endpoints, so syncing data can't use up chat quota (or the reverse)."""
    return RateLimiter(Limits.users_from_settings(get_settings()))


def _enforce(request: Request, limiter: RateLimiter, settings: Settings) -> None:
    if not settings.rate_limit_enabled:
        return
    key = client_key(request, settings.rate_limit_client_ip_header, settings.rate_limit_forwarded_hops)
    if settings.rate_limit_debug_log_clients:
        log.info(
            "rate-limit client=%s peer=%s chain=%s",
            key,
            request.client.host if request.client else None,
            request.headers.get(settings.rate_limit_client_ip_header or "", ""),
        )
    decision = limiter.check(key)
    if decision.allowed:
        return
    log.warning("rate limit hit: scope=%s retry_after=%ss", decision.scope, decision.retry_after)
    message = SLOW_DOWN_MESSAGE if decision.scope.startswith("ip-") else BUSY_MESSAGE
    raise HTTPException(status_code=429, detail=message, headers={"Retry-After": str(decision.retry_after)})


async def enforce_rate_limit(
    request: Request,
    limiter: RateLimiter = Depends(get_limiter),
    settings: Settings = Depends(get_settings),
) -> None:
    """FastAPI dependency for the chat endpoints: raises 429 with a Retry-After header when a limit is hit."""
    _enforce(request, limiter, settings)


async def enforce_users_rate_limit(
    request: Request,
    limiter: RateLimiter = Depends(get_users_limiter),
    settings: Settings = Depends(get_settings),
) -> None:
    """Same, with the separate budget for the /users endpoints."""
    _enforce(request, limiter, settings)
