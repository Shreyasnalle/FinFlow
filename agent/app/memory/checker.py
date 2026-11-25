"""Python checker for the memory step.

Two jobs:
1. Make sure the agent really DECIDED (update or skip with a reason) on every turn. No decision,
   a malformed one, or an `update` with nothing in it counts as "never decided" -> the keeper re-calls the agent.
2. Make sure only acceptable things get stored: short, neutral notes about the user, never secrets or
   instructions aimed at the assistant (a prompt-injection route into memory).
"""

import re
from dataclasses import dataclass, field

from app.memory.decision import MemoryDecision
from app.memory.document import SECTIONS, norm

MIN_LEN, MAX_LEN, MAX_ADDS = 10, 200, 3

_SECRET = re.compile(
    r"\d{9,}|\b(password|passcode|pin|cvv|otp|ssn|aadhaar|passport|api[ _-]?key|secret|token)\b|(gsk|sk|fc)[-_][A-Za-z0-9]{12,}",
    re.I,
)
_INSTRUCTION = re.compile(
    r"\b(ignore|disregard|forget|override|bypass)\b.{0,40}\b(instruction|rule|prompt|guardrail|polic)"
    r"|system prompt|\b(you|assistant|coach)\s+(must|should|will|shall)\b"
    r"|\b(always|never)\s+(answer|respond|reply|recommend|suggest|refuse|say|give|tell)\b"
    r"|from now on|\bnew rule",
    re.I,
)
_MARKUP = re.compile(r"[<>`]|https?://|www\.")


@dataclass
class ValidatedDecision:
    kind: str  # "update" | "skip"
    reason: str
    adds: list[tuple[str, str]] = field(default_factory=list)
    removes: list[str] = field(default_factory=list)


def acceptable(text: str) -> bool:
    text = " ".join(text.split())
    return (
        MIN_LEN <= len(text) <= MAX_LEN
        and not _SECRET.search(text)
        and not _INSTRUCTION.search(text)
        and not _MARKUP.search(text)
    )


def validate(decision: MemoryDecision | None, existing: dict[str, list[str]]) -> ValidatedDecision | None:
    """None means the agent never (validly) decided."""
    if decision is None:
        return None
    reason = " ".join(decision.reason.split())
    if decision.decision == "skip":
        return ValidatedDecision("skip", reason) if reason else None
    if not decision.add and not decision.remove:
        return None  # said "update" but gave nothing

    current = {norm(b): b for s in SECTIONS for b in existing.get(s, [])}
    adds, seen = [], set()
    for item in decision.add:
        text = " ".join(item.text.split())
        if acceptable(text) and norm(text) not in current and norm(text) not in seen:
            seen.add(norm(text))
            adds.append((item.section, text))
    adds = adds[:MAX_ADDS]
    removes = [current[norm(r)] for r in decision.remove if norm(r) in current]

    if not adds and not removes:  # a decision was made, but nothing in it may be stored
        return ValidatedDecision("skip", reason or "nothing acceptable to store")
    return ValidatedDecision("update", reason, adds, removes)
