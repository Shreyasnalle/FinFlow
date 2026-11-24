"""Tool-use loop. The LLM decides what to do; this code enforces how far it may go."""

import asyncio
import logging

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, ToolMessage
from langchain_core.tools import BaseTool

from app.agent.models import AgentError, RunState
from app.config import Settings
from app.status.events import Stage
from app.status.reporter import StatusReporter

log = logging.getLogger(__name__)

NUDGE = (
    "(Internal check) You answered without loading a skill. Call load_skill for the "
    "best-fitting skill, then answer again following it."
)
FINALISE = "(Internal check) Step limit reached. Write the final answer now with what you have."


def text_of(message: AIMessage) -> str:
    content = message.content
    if isinstance(content, list):
        content = "".join(p.get("text", "") if isinstance(p, dict) else str(p) for p in content)
    return (content or "").strip()


async def _invoke(llm: BaseChatModel, messages: list[BaseMessage]) -> AIMessage:
    """One model call, retried once (Groq occasionally emits a malformed tool call)."""
    last: Exception | None = None
    for _ in range(2):
        try:
            return await llm.ainvoke(messages)
        except Exception as exc:
            last = exc
            log.warning("LLM call failed: %s", exc)
    raise AgentError("The AI service is unavailable right now.") from last


async def _run_tool(
    call: dict, tools: dict[str, BaseTool], s: Settings
) -> str:
    tool = tools.get(call["name"])
    if tool is None:
        return f"ERROR: unknown tool '{call['name']}'. Available: {', '.join(tools)}"
    try:
        out = await asyncio.wait_for(tool.ainvoke(call["args"]), timeout=s.web_search_timeout_s + 5)
    except Exception as exc:  # bad args (validation), timeouts, tool bugs
        return f"ERROR: tool call failed: {type(exc).__name__}: {str(exc)[:200]}"
    out = str(out)
    return out if len(out) <= s.max_tool_output_chars else out[: s.max_tool_output_chars] + "\n...(truncated)"


async def _announce(call: dict, reporter: StatusReporter) -> None:
    args = call.get("args") or {}
    if call["name"] == "load_skill":
        await reporter.update(Stage.LOADING_SKILL, skill=args.get("name", ""))
    elif call["name"] == "web_search":
        await reporter.update(Stage.SEARCHING_WEB, query=args.get("query", ""))


async def run_agent_loop(
    llm: BaseChatModel,
    messages: list[BaseMessage],
    tools: list[BaseTool],
    state: RunState,
    s: Settings,
    reporter: StatusReporter,
) -> str:
    by_name = {t.name: t for t in tools}
    bound = llm.bind_tools(tools)
    nudged = False

    for _ in range(s.max_agent_steps):
        state.steps += 1
        await reporter.update(Stage.THINKING, step=state.steps)
        ai = await _invoke(bound, messages)
        messages.append(ai)

        if not ai.tool_calls:
            await reporter.update(Stage.WRITING)
            reply = text_of(ai)
            # A substantive answer with no skill loaded breaks the contract: push back once.
            if not state.loaded_skills and not nudged and len(reply) > 200:
                nudged = True
                messages.append(HumanMessage(NUDGE))
                continue
            if reply:
                return reply
            raise AgentError("The model returned an empty answer.")

        for call in ai.tool_calls:
            await _announce(call, reporter)
            result = await _run_tool(call, by_name, s)
            if call["name"] == "web_search":
                await reporter.update(Stage.READING_RESULTS)
            messages.append(ToolMessage(content=result, tool_call_id=call["id"], name=call["name"]))

    # Out of steps: force a final answer without tools.
    messages.append(HumanMessage(FINALISE))
    reply = text_of(await _invoke(llm, messages))
    if not reply:
        raise AgentError("The model returned an empty answer.")
    return reply
