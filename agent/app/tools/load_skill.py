from langchain_core.tools import StructuredTool
from pydantic import BaseModel, Field

from app.agent.models import RunState
from app.config import Settings
from app.skills.registry import SkillRegistry


class LoadSkillInput(BaseModel):
    name: str = Field(description="Exact skill name from the skills list.")


def make_load_skill_tool(registry: SkillRegistry, state: RunState, s: Settings) -> StructuredTool:
    async def load_skill(name: str) -> str:
        skill = registry.get(name)
        if skill is None:
            return f"ERROR: unknown skill '{name}'. Valid skills: {', '.join(registry.names())}"
        if skill.name in state.loaded_skills:
            return f"Skill '{skill.name}' is already loaded; use it."
        if len(state.loaded_skills) >= s.max_skills_per_query:
            return (
                f"ERROR: skill limit reached ({s.max_skills_per_query}). "
                f"Answer using the skills already loaded: {', '.join(state.loaded_skills)}."
            )
        state.loaded_skills.append(skill.name)
        return f"# Skill: {skill.name}\n\n{skill.body}"

    return StructuredTool.from_function(
        coroutine=load_skill,
        name="load_skill",
        description=(
            "Load an expert playbook for the user's request. Call this before answering any "
            "finance question. You may load more than one if the question spans topics."
        ),
        args_schema=LoadSkillInput,
    )
