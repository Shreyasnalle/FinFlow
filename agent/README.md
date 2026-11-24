# FinFlow Finance Agent

Personalised finance agent for the FinFlow app. **The LLM is the brain; Python is the checker.**

```
user message + user_data + memory      (data and memory are inputs, supplied by the backend/DB)
        |
   FinanceAgent (LangChain)  --> load_skill (16 skills) --> web_search (Firecrawl, only if a skill allows)
        |  draft
   Classifier agent (separate model call, no tools, no user data)
        |  allow / block
   reply (draft) or a friendly out-of-scope message
```

## Layout
- `app/agent/` - prompt builder (LangChain `ChatPromptTemplate`, history trimming), tool-use loop, LLM factory
- `app/skills/` - registry plus `content/<skill>/SKILL.md` playbooks (add a feature = add a folder)
- `app/tools/` - `load_skill`, `web_search`
- `app/guardrails/` - classifier, deterministic checks (secret/prompt-leak canary), friendly refusal templates
- `app/service.py` - agent -> classifier -> reply; `app/api/` - FastAPI `POST /chat`

## Follow-up questions
`app/followups/followups.md` is injected into every prompt: each reply must end with a `<followups>` block of three
questions. Python then checks it (`checker.py`: exactly 3, 8-100 chars, end in `?`, unique, no links). If the agent skipped
or botched it, the agent model is called again for just this job (`writer.py`); if that fails too, safe generic
suggestions are used. The classifier reviews the follow-ups together with the answer; blocked replies get the generic ones.
`followups_source` tells the frontend which path produced them (`agent` | `repair` | `fallback`).

## Live status
`agent/service -> StatusReporter.update(stage) -> sink(event) -> QueueSink -> SSE stream -> frontend`
(`app/status/`, `app/api/stream.py`). Use `POST /chat/stream` (same body as `/chat`): it sends many
`event: status` messages (`seq`, `stage`, `message` ready to render, optional `detail`), then one `event: result`
(the same JSON as `/chat`) or `event: error`, with a keep-alive comment every 15s. A failing sink never breaks the agent.
Stages: received, reading_context, thinking, loading_skill, searching_web, reading_results, writing, followups, checking, done.

## What Python enforces (the LLM cannot override)
Max steps, max skills per query, max web searches, web search only after a skill that allows it, tool-output
truncation, request size limits, a nudge if the agent answers without a skill, canary/secret leak checks,
and fail-closed when the classifier errors.

## Run
```bash
python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"
cp .env.example .env        # add GROQ_API_KEY (and FIRECRAWL_API_KEY or FIRECRAWL_API_URL)
.venv/bin/uvicorn app.main:app --port 8000
.venv/bin/python -m pytest             # offline tests
.venv/bin/python -m pytest -m live -s  # real Groq calls (made-up data)
```

`POST /chat` body: `{"message": "...", "history": [{"role":"user","content":"..."}], "user_data": {...}, "memory": "..."}`.
`user_data` and `memory` accept any JSON or text; the data layer that fills them can be added later in `app/service.py`.

## Moving to a paid model on EC2
Register another provider in `app/agent/llm.py` and set `LLM_PROVIDER`. Nothing else changes.
