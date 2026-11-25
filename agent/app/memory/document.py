"""The memory.md format: a few sections of short dated bullets. Python owns the file, not the LLM."""

import re
from datetime import date

SECTIONS = ["profile", "goals", "preferences", "situation", "notes"]
TITLES = {"profile": "Profile", "goals": "Goals", "preferences": "Preferences", "situation": "Situation", "notes": "Notes"}
MAX_CHARS = 6000

_DATE = re.compile(r"\s*\((\d{4}-\d{2}-\d{2})\)\s*$")


def _bare(line: str) -> str:
    return _DATE.sub("", line).strip()


def norm(text: str) -> str:
    return " ".join(_bare(text).lower().split())


def parse(markdown: str) -> dict[str, list[str]]:
    doc: dict[str, list[str]] = {s: [] for s in SECTIONS}
    titles = {v.lower(): k for k, v in TITLES.items()}
    section = "notes"  # free-form lines from older notes land here
    for raw in (markdown or "").splitlines():
        line = raw.strip()
        if line.startswith("## "):
            section = titles.get(line[3:].strip().lower(), "notes")
        elif line.startswith(("- ", "* ")) and line[2:].strip():
            doc[section].append(line[2:].strip())
    return doc


def serialize(doc: dict[str, list[str]]) -> str:
    parts = ["# Memory"]
    for s in SECTIONS:
        if doc.get(s):
            parts.append(f"\n## {TITLES[s]}\n" + "\n".join(f"- {b}" for b in doc[s]))
    return "\n".join(parts) + "\n" if len(parts) > 1 else ""


def _age_key(item: tuple[str, str]) -> str:
    m = _DATE.search(item[1])
    return m.group(1) if m else "0000-00-00"  # undated = oldest


def apply(doc: dict, adds: list[tuple[str, str]], removes: list[str], today: date) -> tuple[dict, int, int]:
    """Return (new doc, added count, removed count). Enforces the size cap by dropping the oldest notes."""
    new = {s: list(doc.get(s, [])) for s in SECTIONS}
    drop = {norm(r) for r in removes}
    removed = 0
    for s in SECTIONS:
        kept = [b for b in new[s] if norm(b) not in drop]
        removed += len(new[s]) - len(kept)
        new[s] = kept
    existing = {norm(b) for s in SECTIONS for b in new[s]}
    added = 0
    for section, text in adds:
        if norm(text) in existing:
            continue
        new[section].append(f"{text.strip()} ({today.isoformat()})")
        existing.add(norm(text))
        added += 1
    while len(serialize(new)) > MAX_CHARS:
        flat = [(s, b) for s in SECTIONS for b in new[s]]
        if not flat:
            break
        s, b = min(flat, key=_age_key)
        new[s].remove(b)
    return new, added, removed
