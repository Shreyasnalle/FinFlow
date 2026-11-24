"""Loads and validates skills from app/skills/content/<name>/SKILL.md."""

from pathlib import Path

import yaml

from app.skills.skill import Skill

CONTENT_DIR = Path(__file__).parent / "content"


class SkillRegistry:
    def __init__(self, skills: list[Skill]):
        names = [s.name for s in skills]
        if len(set(names)) != len(names):
            raise ValueError("Duplicate skill names")
        self._skills = {s.name: s for s in skills}

    @classmethod
    def from_directory(cls, directory: Path = CONTENT_DIR) -> "SkillRegistry":
        skills = [_parse(p) for p in sorted(directory.glob("*/SKILL.md"))]
        if not skills:
            raise ValueError(f"No skills found in {directory}")
        return cls(skills)

    def names(self) -> list[str]:
        return list(self._skills)

    def get(self, name: str) -> Skill | None:
        return self._skills.get(name.strip().lower())

    def index(self) -> str:
        """The short menu shown to the agent: name + one line each."""
        return "\n".join(f"- {s.name}: {s.description}" for s in self._skills.values())


def _parse(path: Path) -> Skill:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise ValueError(f"{path}: missing YAML frontmatter")
    _, front, body = text.split("---", 2)
    meta = yaml.safe_load(front) or {}
    skill = Skill(
        name=meta.get("name", ""),
        description=meta.get("description", ""),
        allows_web_search=bool(meta.get("allows_web_search", False)),
        body=body.strip(),
    )
    if skill.name != path.parent.name:
        raise ValueError(f"{path}: skill name '{skill.name}' must match its folder")
    return skill
