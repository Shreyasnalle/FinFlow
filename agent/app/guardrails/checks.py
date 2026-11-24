"""Deterministic checks that run before (and independent of) the classifier LLM."""

import re

from app.guardrails.verdict import Category

_SECRET_PATTERNS = [
    re.compile(r"gsk_[A-Za-z0-9]{20,}"),
    re.compile(r"fc-[A-Za-z0-9]{16,}"),
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
]
_LEAK_MARKERS = ("<user_data>", "<memory>", "How you work", "Internal reference code")
MAX_DRAFT_CHARS = 6000


def deterministic_check(draft: str, canary: str) -> Category | None:
    """Return a blocking category, or None if the draft passes these checks."""
    if not draft or not draft.strip():
        return Category.CHECK_FAILED
    if canary and canary in draft:
        return Category.PROMPT_LEAK_OR_MANIPULATION
    if any(m in draft for m in _LEAK_MARKERS):
        return Category.PROMPT_LEAK_OR_MANIPULATION
    if any(p.search(draft) for p in _SECRET_PATTERNS):
        return Category.PROMPT_LEAK_OR_MANIPULATION
    if len(draft) > MAX_DRAFT_CHARS:
        return Category.CHECK_FAILED
    return None
