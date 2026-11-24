import json

import pytest
from fastapi.testclient import TestClient
from langchain_core.messages import AIMessage

from app.agent.finance_agent import FinanceAgent
from app.agent.models import AgentError, AgentRequest
from app.api.routes import get_service
from app.guardrails.classifier import ResponseClassifier
from app.guardrails.verdict import Category, GuardrailDecision
from app.main import app
from app.service import ChatService
from app.status.events import Stage
from app.status.reporter import StatusReporter, describe
from tests.conftest import CANARY, ScriptedModel, StubClassifierLLM, StubWriter, tool_call

BLOCK = "\n<followups>\n- How can I cut my dining spend?\n- Am I on track for my Goa trip?\n- Which bills are due soon?\n</followups>"


def make_service(settings, registry, script, search=None, fail_classifier=False):
    agent = FinanceAgent(settings, registry, CANARY, llm=ScriptedModel(script=script),
                         search_client=search, followup_writer=StubWriter())
    decision = RuntimeError("x") if fail_classifier else GuardrailDecision(allowed=True, category=Category.OK)
    return ChatService(agent, ResponseClassifier(settings, CANARY, StubClassifierLLM(decision)))


async def collect(service, request):
    events = []

    async def sink(e):
        events.append(e)

    await service.handle(request, StatusReporter(sink))
    return events


async def test_status_sequence_with_skill_and_search(settings, registry, fake_search):
    script = [
        tool_call("load_skill", {"name": "market_and_news_lookup"}, "a"),
        tool_call("web_search", {"query": "repo rate today"}, "b"),
        AIMessage("Rate is 6.5%." + BLOCK),
    ]
    events = await collect(make_service(settings, registry, script, fake_search), AgentRequest(message="repo rate?"))
    stages = [e.stage for e in events]
    assert stages == [
        Stage.RECEIVED, Stage.READING_CONTEXT,
        Stage.THINKING, Stage.LOADING_SKILL,
        Stage.THINKING, Stage.SEARCHING_WEB, Stage.READING_RESULTS,
        Stage.THINKING, Stage.WRITING,
        Stage.FOLLOWUPS, Stage.CHECKING, Stage.DONE,
    ]
    assert [e.seq for e in events] == list(range(1, len(events) + 1))
    by_stage = {e.stage: e for e in events}
    assert "market and news lookup" in by_stage[Stage.LOADING_SKILL].message
    assert "repo rate today" in by_stage[Stage.SEARCHING_WEB].message


async def test_error_status_emitted(settings, registry):
    class Boom:
        async def run(self, request, reporter):
            raise AgentError("down")

    service = ChatService(Boom(), None)
    events = []

    async def sink(e):
        events.append(e)

    with pytest.raises(AgentError):
        await service.handle(AgentRequest(message="hi"), StatusReporter(sink))
    assert [e.stage for e in events] == [Stage.RECEIVED, Stage.ERROR]


async def test_broken_sink_never_breaks_the_agent(settings, registry):
    async def bad_sink(e):
        raise RuntimeError("frontend gone")

    service = make_service(settings, registry, [AIMessage("Hi!" + BLOCK)])
    out = await service.handle(AgentRequest(message="hi"), StatusReporter(bad_sink))
    assert out.reply == "Hi!"


def test_describe_sanitises_and_trims():
    msg, detail = describe(Stage.SEARCHING_WEB, {"query": "gold\nprice\x00 " + "x" * 200})
    assert "\n" not in msg and "\x00" not in msg and len(detail) <= 80
    assert describe(Stage.LOADING_SKILL, {"skill": ""})[0] == "Picking the right approach"


def parse_sse(text):
    events = []
    for block in text.strip().split("\n\n"):
        if block.startswith(":"):
            continue
        lines = dict(line.split(": ", 1) for line in block.splitlines())
        events.append((lines["event"], json.loads(lines["data"])))
    return events


@pytest.fixture
def client():
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_stream_endpoint_status_then_result(settings, registry, client):
    script = [tool_call("load_skill", {"name": "budgeting"}), AIMessage("Try a budget." + BLOCK)]
    app.dependency_overrides[get_service] = lambda: make_service(settings, registry, script)
    r = client.post("/chat/stream", json={"message": "help me budget", "user_data": {"cash": 5}})
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/event-stream")
    events = parse_sse(r.text)
    kinds = [k for k, _ in events]
    assert kinds[-1] == "result" and kinds.count("result") == 1 and set(kinds[:-1]) == {"status"}
    stages = [d["stage"] for k, d in events if k == "status"]
    assert stages[0] == "received" and stages[-1] == "done" and "loading_skill" in stages
    result = events[-1][1]
    assert result["reply"] == "Try a budget." and len(result["followups"]) == 3 and result["followups_source"] == "agent"


def test_stream_endpoint_error_event(client):
    class Broken:
        async def handle(self, request, reporter=None):
            raise AgentError("down")

    app.dependency_overrides[get_service] = lambda: Broken()
    events = parse_sse(client.post("/chat/stream", json={"message": "hi"}).text)
    assert events[-1][0] == "error" and "unavailable" in events[-1][1]["detail"]


def test_plain_chat_includes_followups(settings, registry, client):
    app.dependency_overrides[get_service] = lambda: make_service(settings, registry, [AIMessage("Hi!" + BLOCK)])
    body = client.post("/chat", json={"message": "hi"}).json()
    assert body["followups"][0] == "How can I cut my dining spend?"
