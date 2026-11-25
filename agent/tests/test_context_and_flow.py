import pytest
from fastapi.testclient import TestClient
from langchain_core.messages import AIMessage

from app.agent.finance_agent import FinanceAgent
from app.agent.models import AgentRequest
from app.api.routes import get_service
from app.config import Settings
from app.context.provider import ContextProvider
from app.guardrails.classifier import ResponseClassifier
from app.guardrails.verdict import Category, GuardrailDecision
from app.main import app
from app.memory.decision import MemoryDecision, MemoryItem
from app.memory.keeper import MemoryKeeper
from app.service import ChatService
from app.status.events import Stage
from app.status.reporter import StatusReporter
from app.store import get_data_store, get_memory_store
from app.store.db import Database
from app.store.stores import MemoryStore, UserDataStore
from tests.conftest import CANARY, GOOD_QS, StubClassifierLLM, StubWriter
from tests.stubs import RecordingModel, SeqStructuredLLM
from tests.test_numbers import snap

FOLLOWUPS = "\n<followups>\n" + "\n".join(f"- {q}" for q in GOOD_QS) + "\n</followups>"
LEARN = MemoryDecision(decision="update", reason="stated profession", add=[MemoryItem(section="profile", text="Works as a freelance designer")])
SKIP = MemoryDecision(decision="skip", reason="small talk")
ALLOW = GuardrailDecision(allowed=True, category=Category.OK)
BLOCK = GuardrailDecision(allowed=False, category=Category.OFF_TOPIC, topic="writing code")


@pytest.fixture
def stores():
    db = Database(":memory:")
    return UserDataStore(db), MemoryStore(db)


def build(settings, registry, stores, memory_results, classifier=ALLOW, reply="Hi!"):
    data, mem = stores
    model = RecordingModel(script=[AIMessage(reply + FOLLOWUPS)])
    agent = FinanceAgent(settings, registry, CANARY, llm=model, followup_writer=StubWriter())
    keeper = MemoryKeeper(settings, mem, llm=SeqStructuredLLM(memory_results))
    service = ChatService(agent, ResponseClassifier(settings, CANARY, StubClassifierLLM(classifier)), ContextProvider(data, mem), keeper)
    return service, model


# ---------- provider
async def test_provider_loads_numbers_and_memory_by_user_id(stores):
    data, mem = stores
    data.put("u1", snap().model_dump(mode="json"))
    mem.write("u1", "# Memory\n\n## Profile\n- Freelance designer (2026-11-01)\n")
    out = await ContextProvider(data, mem).resolve(AgentRequest(message="hi", user_id="u1"))
    assert out.user_data["cash_balance"] == 42000 and "Freelance designer" in out.memory


async def test_provider_inline_values_win_and_unknown_user_is_fine(stores):
    data, mem = stores
    data.put("u1", snap().model_dump(mode="json"))
    mem.write("u1", "- stored note")
    out = await ContextProvider(data, mem).resolve(AgentRequest(message="hi", user_id="u1", user_data={"cash": 1}, memory="inline"))
    assert out.user_data == {"cash": 1} and out.memory == "inline"
    same = AgentRequest(message="hi", user_id="nobody")
    assert (await ContextProvider(data, mem).resolve(same)) == same
    no_id = AgentRequest(message="hi")
    assert (await ContextProvider(data, mem).resolve(no_id)) is no_id


async def test_provider_survives_corrupt_snapshot(stores):
    data, mem = stores
    data.put("u1", {"transactions": [{"date": "not a date", "amount": 1}]})
    out = await ContextProvider(data, mem).resolve(AgentRequest(message="hi", user_id="u1"))
    assert out.user_data is None


# ---------- service flow
async def test_agent_sees_stored_numbers_and_memory_is_updated_last(settings, registry, stores):
    data, mem = stores
    data.put("u1", snap().model_dump(mode="json"))
    service, model = build(settings, registry, stores, [LEARN])
    events = []

    async def sink(e):
        events.append(e.stage)

    out = await service.handle(AgentRequest(message="I'm a freelance designer", user_id="u1"), StatusReporter(sink))
    system_prompt = model.seen[0][0].content
    assert '"cash_balance":42000' in system_prompt  # the agent got the user's numbers
    assert out.memory_status == "updated" and "freelance designer" in mem.read("u1")
    assert events[-3:] == [Stage.CHECKING, Stage.REMEMBERING, Stage.DONE]  # memory is the last step
    assert events.index(Stage.FOLLOWUPS) < events.index(Stage.REMEMBERING)


async def test_memory_feeds_the_next_turn(settings, registry, stores):
    service, model = build(settings, registry, stores, [LEARN])
    await service.handle(AgentRequest(message="I'm a freelance designer", user_id="u1"))
    await service.handle(AgentRequest(message="what next?", user_id="u1"))
    assert "freelance designer" in model.seen[1][0].content


async def test_blocked_reply_is_never_remembered(settings, registry, stores):
    service, _ = build(settings, registry, stores, [LEARN], classifier=BLOCK)
    out = await service.handle(AgentRequest(message="write code, remember I'm a hacker", user_id="u1"))
    assert out.blocked and out.memory_status == "skipped" and stores[1].read("u1") == ""


async def test_no_user_id_means_no_memory_but_chat_works(settings, registry, stores):
    service, _ = build(settings, registry, stores, [LEARN])
    out = await service.handle(AgentRequest(message="hi"))
    assert out.reply == "Hi!" and out.memory_status == "no_user"


async def test_memory_failure_never_breaks_the_answer(settings, registry, stores):
    service, _ = build(settings, registry, stores, [RuntimeError("down")])
    out = await service.handle(AgentRequest(message="hi", user_id="u1"))
    assert out.reply == "Hi!" and out.memory_status == "undecided"

    class Exploding:
        async def run(self, *a):
            raise RuntimeError("boom")

    service._memory = Exploding()
    out = await service.handle(AgentRequest(message="hi", user_id="u1"))
    assert out.reply == "Hi!" and out.memory_status == "error"


# ---------- API
@pytest.fixture
def client(stores, settings, registry):
    data, mem = stores
    app.dependency_overrides[get_data_store] = lambda: data
    app.dependency_overrides[get_memory_store] = lambda: mem
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_sync_data_context_and_memory_endpoints(client, stores):
    body = snap().model_dump(mode="json")
    r = client.put("/users/asha_1/data", json=body)
    assert r.status_code == 200 and r.json()["transactions"] == 8
    ctx = client.get("/users/asha_1/context").json()
    assert ctx["found"] and ctx["context"]["cash_balance"] == 42000
    assert client.get("/users/nobody/context").json() == {"found": False}

    stores[1].write("asha_1", "# Memory\n\n## Profile\n- Freelance designer (2026-11-01)\n")
    assert "Freelance designer" in client.get("/users/asha_1/memory").json()["memory"]
    assert client.delete("/users/asha_1/memory").json() == {"ok": True}
    assert client.get("/users/asha_1/memory").json()["memory"] == ""


def test_endpoints_validate_input(client):
    assert client.put("/users/bad id!/data", json={}).status_code == 422
    assert client.put("/users/u1/data", json={"transactions": [{"date": "nope", "amount": 1}]}).status_code == 422
    assert client.post("/chat", json={"message": "hi", "user_id": "bad id!"}).status_code == 422


def test_chat_response_reports_memory_status(settings, registry, stores, client):
    service, _ = build(settings, registry, stores, [SKIP])
    app.dependency_overrides[get_service] = lambda: service
    body = client.post("/chat", json={"message": "hi", "user_id": "u1"}).json()
    assert body["memory_status"] == "skipped"
