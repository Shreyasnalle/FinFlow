"""Pull the <followups> block out of the agent's reply."""

import re

_BLOCK = re.compile(r"<followups>(.*?)(?:</followups>|\Z)", re.S | re.I)
_BULLET = re.compile(r"^\s*(?:[-*•]|\d+[.)])\s*")


def extract(text: str) -> tuple[str, list[str]]:
    """Return (reply without the block, raw question lines found in the block)."""
    items: list[str] = []
    match = _BLOCK.search(text)
    if match:
        for line in match.group(1).splitlines():
            line = _BULLET.sub("", line).strip().strip('"“”')
            if line:
                items.append(line)
    clean = _BLOCK.sub("", text).strip()
    return clean, items
