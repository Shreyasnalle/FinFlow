from types import SimpleNamespace

import pytest
from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import AIMessage
from langchain_core.outputs import ChatGeneration, ChatResult
from langchain_core.runnables import RunnableLambda

from app.config import Settings
from app.skills.registry import SkillRegistry

CANARY = "FFX-testcanary"


class ScriptedModel(BaseChatModel):
    """Chat model that replays scripted AIMessages (and ignores bind_tools)."""

    script: list = []
    calls: int = 0

    @property
    def _llm_type(self) -> str:
        return "scripted"

    def bind_tools(self, tools, **kwargs):
        return self

    def _generate(self, messages, stop=None, run_manager=None, **kwargs):
        msg = self.script[min(self.calls, len(self.script) - 1)]
        self.calls += 1
        return ChatResult(generations=[ChatGeneration(message=msg)])


def tool_call(name: str, args: dict, id: str = "c1") -> AIMessage:
    return AIMessage(content="", tool_calls=[{"name": name, "args": args, "id": id}])


GOOD_QS = ["How can I cut my dining spend?", "Am I on track for my Goa trip?", "Which bills are due soon?"]


class StubWriter:
    """Stands in for FollowUpWriter (the repair call); records how often it was used."""

    def __init__(self, result=GOOD_QS):
        self.result, self.calls = result, 0

    async def write(self, request, answer):
        self.calls += 1
        return self.result


class StubClassifierLLM:
    """Mimics `llm.with_structured_output(schema)` returning a fixed decision or error."""

    def __init__(self, result):
        self.result, self.seen = result, []

    def with_structured_output(self, schema, **kwargs):
        def run(prompt_value):
            self.seen.append(prompt_value.to_string())
            if isinstance(self.result, Exception):
                raise self.result
            return self.result

        return RunnableLambda(run)


@pytest.fixture
def settings() -> Settings:
    return Settings(_env_file=None, groq_api_key="test", firecrawl_api_key=None)


@pytest.fixture
def registry() -> SkillRegistry:
    return SkillRegistry.from_directory()


@pytest.fixture
def fake_search():
    results = [
        SimpleNamespace(title="Repo rate", url="https://rbi.example/rate", description="6.5%"),
        SimpleNamespace(title="Inflation", url="https://stat.example/cpi", description="4.1%"),
    ]
    return SimpleNamespace(search=lambda q, limit=4: SimpleNamespace(web=results))
