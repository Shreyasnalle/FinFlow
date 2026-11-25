from langchain_core.messages import AIMessage
from langchain_core.outputs import ChatGeneration, ChatResult
from langchain_core.runnables import RunnableLambda

from tests.conftest import ScriptedModel


class RecordingModel(ScriptedModel):
    """ScriptedModel that remembers the messages it was sent."""

    seen: list = []

    def _generate(self, messages, stop=None, run_manager=None, **kwargs):
        self.seen.append(messages)
        return super()._generate(messages, stop, run_manager, **kwargs)


class SeqStructuredLLM:
    """`with_structured_output` runnable that returns scripted results in order (repeating the last)."""

    def __init__(self, results):
        self.results, self.calls = list(results), 0

    def with_structured_output(self, schema, **kwargs):
        def run(_):
            r = self.results[min(self.calls, len(self.results) - 1)]
            self.calls += 1
            if isinstance(r, Exception):
                raise r
            return r

        return RunnableLambda(run)
