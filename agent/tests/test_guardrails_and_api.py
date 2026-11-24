import pytest
from fastapi.testclient import TestClient
from langchain_core.messages import AIMessage

from app.agent.finance_agent import FinanceAgent
from app.agent.models import AgentError
from app.api.routes import get_service
from app.guardrails.checks import deterministic_check
from app.guardrails.classifier import ResponseClassifier
from app.guardrails.refusal_messages import TEMPLATES, refusal_for
from app.guardrails.verdict import Category, GuardrailDecision
from app.main import app
from app.service import ChatService
from tests.conftest import CANARY, ScriptedModel, StubClassifierLLM, StubWriter


def D(allowed, cat, topic=""):
    return GuardrailDecision(allowed=allowed, category=cat, topic=topic)


def test_deterministic_checks():
    assert deterministic_check("", CANARY) == Category.CHECK_FAILED
    assert deterministic_check(f"code {CANARY}", CANARY) == Category.PROMPT_LEAK_OR_MANIPULATION
    assert deterministic_check("key gsk_abcdefghijklmnopqrstuvwx", CANARY) == Category.PROMPT_LEAK_OR_MANIPULATION
    assert deterministic_check("see <user_data> here", CANARY) == Category.PROMPT_LEAK_OR_MANIPULATION
    assert deterministic_check("Save 20% of income.", CANARY) is None


def test_every_category_has_a_friendly_message():
    for cat in Category:
        if cat != Category.OK:
            assert refusal_for(cat, "writing code")
    assert "writing code" in refusal_for(Category.OFF_TOPIC, "writing code")
    assert "{" not in refusal_for(Category.ILLEGAL_OR_FRAUD, "")
    assert "<script>" not in refusal_for(Category.OFF_TOPIC, "<script>alert(1)</script>")
    assert set(TEMPLATES) >= set(Category) - {Category.OK}


async def test_classifier_allow_block_and_consistency(settings):
    allow = ResponseClassifier(settings, CANARY, StubClassifierLLM(D(True, Category.OK)))
    assert (await allow.check("q", "Save more.")).allowed
    # confused model: allowed=True but category says otherwise -> must block
    confused = ResponseClassifier(settings, CANARY, StubClassifierLLM(D(True, Category.OFF_TOPIC)))
    assert not (await confused.check("q", "draft")).allowed
    # blocked with category ok -> normalised to other
    odd = await ResponseClassifier(settings, CANARY, StubClassifierLLM(D(False, Category.OK))).check("q", "draft")
    assert not odd.allowed and odd.category == Category.OTHER


async def test_classifier_fails_closed(settings):
    boom = ResponseClassifier(settings, CANARY, StubClassifierLLM(RuntimeError("api down")))
    d = await boom.check("q", "draft")
    assert not d.allowed and d.category == Category.CHECK_FAILED
    junk = ResponseClassifier(settings, CANARY, StubClassifierLLM("not a decision"))
    assert (await junk.check("q", "draft")).category == Category.CHECK_FAILED


def make_service(settings, registry, draft, decision):
    agent = FinanceAgent(settings, registry, CANARY, llm=ScriptedModel(script=[AIMessage(draft)]), followup_writer=StubWriter())
    return ChatService(agent, ResponseClassifier(settings, CANARY, StubClassifierLLM(decision)))


@pytest.fixture
def client():
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_api_allowed_and_blocked(settings, registry, client):
    app.dependency_overrides[get_service] = lambda: make_service(settings, registry, "Save 20%.", D(True, Category.OK))
    r = client.post("/chat", json={"message": "how to save?", "user_data": {"cash": 5}, "memory": "x"})
    assert r.status_code == 200 and r.json()["reply"] == "Save 20%." and not r.json()["blocked"]

    app.dependency_overrides[get_service] = lambda: make_service(
        settings, registry, "def f(): ...", D(False, Category.OFF_TOPIC, "writing code")
    )
    r = client.post("/chat", json={"message": "write python"}).json()
    assert r["blocked"] and r["category"] == "off_topic" and "writing code" in r["reply"] and "def f" not in r["reply"]
    assert len(r["followups"]) == 3 and r["followups_source"] == "fallback"  # blocked still gets safe buttons


def test_api_validation_and_failure(settings, registry, client):
    assert client.post("/chat", json={"message": "   "}).status_code == 422
    assert client.post("/chat", json={"message": "x" * 2001}).status_code == 422
    assert client.post("/chat", json={}).status_code == 422

    class Broken:
        async def handle(self, request):
            raise AgentError("down")

    app.dependency_overrides[get_service] = lambda: Broken()
    assert client.post("/chat", json={"message": "hi"}).status_code == 503
    assert client.get("/health").json() == {"status": "ok"}
