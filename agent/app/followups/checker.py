"""Python checker: did the agent really produce three usable follow-up questions?"""

MIN_LEN, MAX_LEN, COUNT = 8, 100, 3
_BAD_CHARS = ("<", ">", "http", "www.", "```")


def validate(questions: list[str] | None) -> list[str] | None:
    """Return exactly three clean, unique questions, or None if the agent did not deliver."""
    if not questions:
        return None
    good: list[str] = []
    seen: set[str] = set()
    for q in questions:
        q = " ".join(str(q).split())
        key = q.lower()
        if not (MIN_LEN <= len(q) <= MAX_LEN) or not q.endswith("?") or key in seen:
            continue
        if any(b in key for b in _BAD_CHARS):
            continue
        seen.add(key)
        good.append(q)
    return good[:COUNT] if len(good) >= COUNT else None
