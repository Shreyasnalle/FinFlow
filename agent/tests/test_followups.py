from langchain_core.messages import AIMessage

from app.agent.finance_agent import FinanceAgent
from app.agent.models import AgentRequest
from app.followups.checker import validate
from app.followups.fallback import FALLBACK_FOLLOWUPS
from app.followups.parser import extract
from app.service import ChatService, review_text
from app.guardrails.classifier import ResponseClassifier
from app.guardrails.verdict import Category, GuardrailDecision
from tests.conftest import CANARY, GOOD_QS, ScriptedModel, StubClassifierLLM, StubWriter

BLOCK = "\n\n<followups>\n- How can I cut my dining spend?\n- Am I on track for my Goa trip?\n2. Which bills are due soon?\n</followups>"


def test_parser_extracts_and_strips_block():
    clean, items = extract("Save 20%." + BLOCK)
    assert clean == "Save 20%."
    assert items == GOOD_QS


def test_parser_handles_unclosed_and_missing_block():
    clean, items = extract("Answer.\n<followups>\n- One question here?\n- Another one here?")
    assert clean == "Answer." and len(items) == 2
    assert extract("Just an answer") == ("Just an answer", [])


def test_checker_rules():
    assert validate(GOOD_QS) == GOOD_QS
    assert validate(GOOD_QS + ["A fourth good question?"]) == GOOD_QS  # keeps first three
    assert validate(GOOD_QS[:2]) is None  # too few
    assert validate(None) is None and validate([]) is None
    assert validate(["no question mark here at all", GOOD_QS[1], GOOD_QS[2]]) is None
    assert validate(["Short?", GOOD_QS[1], GOOD_QS[2]]) is None
    assert validate([GOOD_QS[0], GOOD_QS[0], GOOD_QS[2]]) is None  # duplicate
    assert validate(["See http://x.com for more?", GOOD_QS[1], GOOD_QS[2]]) is None
    assert validate(["x" * 120 + "?", GOOD_QS[1], GOOD_QS[2]]) is None


def agent_with(settings, registry, reply, writer):
    return FinanceAgent(settings, registry, CANARY, llm=ScriptedModel(script=[AIMessage(reply)]), followup_writer=writer)


async def test_agent_followups_used_when_present(settings, registry):
    writer = StubWriter(["unused one?"] * 3)
    res = await agent_with(settings, registry, "Hello there!" + BLOCK, writer).run(AgentRequest(message="hi"))
    assert res.followups == GOOD_QS and res.followups_source == "agent" and writer.calls == 0
    assert "<followups>" not in res.draft and res.draft == "Hello there!"


async def test_agent_skipped_followups_triggers_repair(settings, registry):
    writer = StubWriter()
    res = await agent_with(settings, registry, "Hello there!", writer).run(AgentRequest(message="hi"))
    assert res.followups_source == "repair" and writer.calls == 1 and res.followups == GOOD_QS


async def test_agent_botched_followups_triggers_repair(settings, registry):
    writer = StubWriter()
    reply = "Hello!\n<followups>\n- Only one question here?\n</followups>"
    res = await agent_with(settings, registry, reply, writer).run(AgentRequest(message="hi"))
    assert res.followups_source == "repair" and writer.calls == 1


async def test_repair_failure_falls_back(settings, registry):
    res = await agent_with(settings, registry, "Hello!", StubWriter(None)).run(AgentRequest(message="hi"))
    assert res.followups == FALLBACK_FOLLOWUPS and res.followups_source == "fallback"


async def test_classifier_reviews_followups_too(settings, registry):
    stub = StubClassifierLLM(GuardrailDecision(allowed=True, category=Category.OK))
    agent = agent_with(settings, registry, "Hello there!" + BLOCK, StubWriter())
    service = ChatService(agent, ResponseClassifier(settings, CANARY, stub))
    out = await service.handle(AgentRequest(message="hi"))
    assert out.followups == GOOD_QS and not out.blocked
    assert "How can I cut my dining spend?" in stub.seen[0]
    assert review_text("a", ["q?"]).endswith("- q?")
