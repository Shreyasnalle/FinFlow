from pydantic import BaseModel, Field


class Skill(BaseModel):
    """An expert playbook the agent can load. Authored as Markdown, see content/."""

    name: str = Field(pattern=r"^[a-z][a-z0-9_]*$")
    description: str = Field(min_length=10, max_length=300)
    allows_web_search: bool = False
    body: str = Field(min_length=20)
