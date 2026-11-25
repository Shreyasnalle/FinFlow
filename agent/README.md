# FinFlow Finance Agent

Personalised finance agent for the FinFlow app. **The LLM is the brain; Python is the checker.**

```
user message (+ user_id)  ->  user's numbers (computed by Python) + memory.md   (looked up by user_id)
        |
   FinanceAgent (LangChain)  --> load_skill (16 skills) --> web_search (Firecrawl, only if a skill allows)
        |  draft + 3 follow-up questions
   Classifier agent (separate model call, no tools, no user data)
        |  allow / block
   memory step (skill: memory_update; only for allowed replies, only if worth remembering)
        |
   reply (draft) or a friendly out-of-scope message
```

## Layout
- `app/agent/` - prompt builder (LangChain `ChatPromptTemplate`, history trimming), tool-use loop, LLM factory
- `app/skills/` - registry plus `content/<skill>/SKILL.md` playbooks (add a feature = add a folder)
- `app/tools/` - `load_skill`, `web_search`
- `app/guardrails/` - classifier, deterministic checks (secret/prompt-leak canary), friendly refusal templates
- `app/context/`, `app/store/` - the user's synced data, numbers computed in Python, per-user storage
- `app/memory/` - memory.md: decision model, checker, keeper (see `docs/MEMORY_AND_CONTEXT.md`)
- `app/service.py` - context -> agent -> classifier -> memory -> reply; `app/api/` - FastAPI `POST /chat`, `/chat/stream`, `/users/...`

## Skills
A skill is a Markdown playbook (`app/skills/content/<name>/SKILL.md`) that tells the agent how to handle one kind of request.
The agent only sees a one-line menu of skills. For each question it calls `load_skill` for the best fit (or up to 3 when a
question spans topics), follows that playbook using the user's real numbers and memory, and may use `web_search` only if the
loaded skill allows it. Python validates every skill at startup (name must match its folder). **To add a feature, add a folder
with a `SKILL.md`; no Python changes.**

| Skill | What it does | Web search |
|---|---|---|
| `spending_analysis` | Shows where the money goes: ranked categories and shares, change vs the previous period, essentials vs discretionary, one-off spikes vs drift, and up to 3 realistic cuts with the saving each. | no |
| `budgeting` | Creates, reviews and fixes budgets: limits near real spending, a 50/30/20 reference, used vs limit per category, which ones are over, and one next step. | no |
| `savings_goals` | Tracks goals: remaining amount, monthly amount needed for a deadline or time to reach at the user's surplus, feasibility, and how to split money across several goals. | no |
| `bills_and_subscriptions` | Reviews recurring bills: what is due soon, total fixed cost and its share of income, which to cancel, downgrade or renegotiate (with the yearly saving), and warns if cash is short. | no |
| `cashflow_forecast` | Projects balance and runway month by month, runs one-variable what-ifs (income drops, new bill), and flags the month the balance would go negative. | no |
| `emergency_fund` | Sizes an emergency fund from essential spending (3 to 12 months by situation), shows the gap, and gives a monthly build plan. | no |
| `debt_management` | Plans loan and card payoff: avalanche vs snowball, months to debt-free and interest saved, prepay vs save. Never suggests new debt to invest. | yes (current lending rates) |
| `net_worth_and_assets` | Explains net worth and allocation: totals, liquid vs illiquid, concentration, and general rebalancing ideas (never specific securities). | no |
| `investing_education` | Teaches investing concepts (SIP, index funds, diversification, risk, compounding) with a worked example. Education only: no stock picks, no promised returns. | yes (current facts) |
| `market_and_news_lookup` | Looks up current external facts (interest rates, inflation, exchange rates, market news) with the date and source, then says what it means for the user. No predictions. | yes |
| `tax_basics` | General tax education: income vs deductions, tax-saving ideas, record keeping, setting money aside. Not filing or legal advice; legal planning only. | yes (current rules) |
| `big_purchase_planning` | Decides if and how to afford a large purchase: months to save, EMI vs cash total cost, keeps the emergency fund intact, and gives a clear verdict first. | no |
| `financial_literacy` | Explains money concepts simply (inflation, interest, credit score, insurance) with an everyday example and, when useful, one of the user's own numbers. | no |
| `money_habits_coaching` | Behavioural coaching: finds the spending pattern, suggests one small habit and a first step, and points to support if the user sounds distressed. | no |
| `monthly_review` | Summarises a period: income, spending, savings rate, top categories, budgets exceeded, goal progress, and one win, one issue and one focus for next month. | no |
| `app_help` | Helps use FinFlow: short numbered steps for transactions, budgets, goals, bills, assets, forecast, analytics, PDF export and settings. Admits when unsure instead of inventing steps. | no |

**System skill (not in the agent's menu):** `app/skills/system/memory_update/SKILL.md` is run by Python as the very last step
of a turn. It tells the agent what is worth remembering about the user (durable facts the user stated) and what is not, and
the agent returns `update` or `skip` on every turn. Details and the Python checks are in `docs/MEMORY_AND_CONTEXT.md`.

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
Stages: received, reading_context, thinking, loading_skill, searching_web, reading_results, writing, followups, checking, remembering, done.

## What Python enforces (the LLM cannot override)
Max steps, max skills per query, max web searches, web search only after a skill that allows it, tool-output
truncation, request size limits, a nudge if the agent answers without a skill, canary/secret leak checks,
and fail-closed when the classifier errors.

## Rate limiting
`POST /chat` and `POST /chat/stream` are rate limited (`app/api/rate_limit.py`); `GET /health` never is, so
wake-up pings always work. Two layers: per client IP (default 12/minute, 200/day) and global across all clients
(default 60/minute, 2000/day). The global caps are what protect your model quota if IPs are spoofed or rotated.
A blocked request gets `429` with a `Retry-After` header and a friendly `detail`, never reaches the model, and
does not use up budget, so waiting out the penalty is enough.

The `/users/*` endpoints (data sync and memory) are limited the same way but with **their own budget**
(`RATE_LIMIT_USERS_*`, default 30/minute and 1000/day per IP, 120/minute and 5000/day overall), so syncing data
can't use up chat quota or the reverse.

- State is in memory and per process: run **one worker**; counters reset on restart or when a sleeping host wakes.
  Memory is bounded (at most 2000 tracked clients, about 2.4 MiB at the cap).
- Many mobile users can share one carrier IP, so keep the per-client limits generous and tune the global ones.
- IPv6 clients are grouped by /64.
- Behind a proxy set `RATE_LIMIT_CLIENT_IP_HEADER` (normally `X-Forwarded-For`). The IP is read from the **right**
  (`RATE_LIMIT_FORWARDED_HOPS`, default 1 = last entry) because clients can freely add entries on the left. If the
  header is missing or unusable, the socket address is used. Set `RATE_LIMIT_DEBUG_LOG_CLIENTS=true` briefly after
  deploying to check the resolved client IP in the logs, then turn it off.
- All settings are in `app/config.py` and documented in `.env.example`.

## Request size cap
Every request body is limited to `MAX_REQUEST_BYTES` (default 2,000,000). A bigger one gets `413` immediately, before
it is read into memory: a declared `Content-Length` is checked up front and chunked bodies are counted as they stream
in (`app/api/body_limit.py`). This matters on a small host: FastAPI otherwise reads the whole body into memory before
validating it. The default fits a maximal data snapshot (5000 transactions) with room to spare; a test guards that.

## Running it publicly
- **`USERS_API_ENABLED=false`** stops serving `/users/*` entirely (404). Those endpoints identify a user only by the
  id in the URL and have no authentication, so keep them off on any public deployment until that exists. Chat is
  unaffected: the app sends its data inline with each request.
- **Storage may not survive restarts.** The SQLite file (`FINFLOW_AGENT_DB`) holds synced snapshots and each user's
  memory. On a host without a persistent disk (Render's free plan) it is wiped on every restart, sleep and redeploy.
- **Each chat is several model calls** (answer, classifier, follow-up repair when needed, and the memory step when a
  `user_id` is sent), so the global rate limits are also your model-quota budget.
- Use one worker (the rate limiter is in memory).

## Run
```bash
python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"
cp .env.example .env        # add GROQ_API_KEY (and FIRECRAWL_API_KEY or FIRECRAWL_API_URL)
.venv/bin/uvicorn app.main:app --port 8000
.venv/bin/python -m pytest             # offline tests
.venv/bin/python -m pytest -m live -s  # real Groq calls (made-up data)
```

`POST /chat` body: `{"message": "...", "user_id": "...", "history": [{"role":"user","content":"..."}]}`.
With a `user_id` the backend looks up the user's synced data (`PUT /users/{id}/data`) and memory itself; inline `user_data` / `memory`
(any JSON or text) are still accepted and win over stored ones. See `docs/MEMORY_AND_CONTEXT.md`.

## Moving to a paid model on EC2
Register another provider in `app/agent/llm.py` and set `LLM_PROVIDER`. Nothing else changes.
