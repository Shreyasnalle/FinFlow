import pytest

from app.agent.models import RunState
from app.skills.registry import SkillRegistry
from app.tools.load_skill import make_load_skill_tool
from app.tools.web_search import make_web_search_tool


def test_all_skills_load_and_are_valid(registry):
    names = registry.names()
    assert len(names) >= 16
    for n in names:
        assert registry.get(n).body
    assert "budgeting" in registry.index()


def test_registry_rejects_name_folder_mismatch(tmp_path):
    d = tmp_path / "foo"
    d.mkdir()
    (d / "SKILL.md").write_text("---\nname: bar\ndescription: a long enough description\n---\nsome body text that is long enough")
    with pytest.raises(ValueError):
        SkillRegistry.from_directory(tmp_path)


async def test_load_skill_paths(registry, settings):
    state = RunState()
    tool = make_load_skill_tool(registry, state, settings)
    assert "unknown skill" in await tool.ainvoke({"name": "nope"})
    assert (await tool.ainvoke({"name": "Budgeting "})).startswith("# Skill: budgeting")
    assert "already loaded" in await tool.ainvoke({"name": "budgeting"})
    await tool.ainvoke({"name": "savings_goals"})
    await tool.ainvoke({"name": "emergency_fund"})
    assert "limit reached" in await tool.ainvoke({"name": "debt_management"})
    assert state.loaded_skills == ["budgeting", "savings_goals", "emergency_fund"]


async def test_web_search_requires_allowing_skill(registry, settings, fake_search):
    state = RunState()
    tool = make_web_search_tool(registry, state, settings, fake_search)
    assert "only available after" in await tool.ainvoke({"query": "repo rate today"})
    state.loaded_skills.append("budgeting")  # does not allow web search
    assert "only available after" in await tool.ainvoke({"query": "repo rate today"})


async def test_web_search_results_and_limit(registry, settings, fake_search):
    state = RunState(loaded_skills=["market_and_news_lookup"])
    tool = make_web_search_tool(registry, state, settings, fake_search)
    out = await tool.ainvoke({"query": "repo rate today"})
    assert "<web_results untrusted>" in out and "https://rbi.example/rate" in out
    assert state.sources == ["https://rbi.example/rate", "https://stat.example/cpi"]
    await tool.ainvoke({"query": "inflation now"})
    assert "limit reached" in await tool.ainvoke({"query": "third search"})


async def test_web_search_unconfigured_and_failure(registry, settings):
    state = RunState(loaded_skills=["market_and_news_lookup"])
    assert "NOT available" in await make_web_search_tool(registry, state, settings).ainvoke({"query": "gold price"})

    class Boom:
        def search(self, *a, **k):
            raise RuntimeError("down")

    out = await make_web_search_tool(registry, RunState(loaded_skills=["market_and_news_lookup"]), settings, Boom()).ainvoke({"query": "gold price"})
    assert "failed" in out
