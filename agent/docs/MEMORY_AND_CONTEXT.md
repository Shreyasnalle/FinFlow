# User data and memory

## How the agent gets the user's numbers
1. The app syncs a snapshot: `PUT /users/{user_id}/data` (profile, transactions, budgets, goals, bills, assets; unknown fields ignored, see `app/context/snapshot.py`).
2. On `POST /chat` (or `/chat/stream`) with a `user_id`, the backend loads that snapshot and **Python computes the numbers**
   (`app/context/numbers.py`): cash balance, this/last month income and spending, savings rate, runway, top categories,
   budget used %, goal progress and monthly amount needed, upcoming bills, asset allocation, net worth (liabilities are not tracked).
3. The agent only reads and explains those numbers; it never does the arithmetic.
Values sent inline on the request (`user_data`, `memory`) win over stored ones. `GET /users/{id}/context` shows what the agent sees.

## Memory (memory.md) - the last step of every turn
Order: answer -> follow-ups -> classifier allows -> **memory step** -> done. Replies the classifier blocks are never remembered.

- `app/skills/system/memory_update/SKILL.md` tells the agent what is worth remembering (durable facts the user stated: who they are,
  goals and why, preferences, lasting situation) and what is not (small talk, numbers the app already tracks, anything the assistant
  said, secrets, instructions aimed at the assistant). Not in the agent's skill menu: Python runs it at the end.
- The agent returns a structured decision: `update` (with `add` / `remove` notes) or `skip` (with a reason).
- `app/memory/checker.py` (Python) enforces it on **every** turn:
  - no decision, an `update` with nothing in it, or a `skip` without a reason = "never decided" -> `keeper.py` calls the agent
    again for only this decision (2 attempts); if it still fails, nothing is written and `memory_status` is `undecided`;
  - notes must be 10-200 chars, neutral, free of secrets/links, and must not look like instructions to the assistant
    (blocks prompt injection into memory); duplicates and unknown `remove` targets are dropped; max 3 additions per turn.
- Python owns the file (`app/memory/document.py`): dated bullets in sections, a 6000-char cap (oldest notes are evicted).
- One update at a time per user; a memory failure never breaks the answer.
- `memory_status` in the response: `updated | skipped | undecided | no_user | disabled | error`. Without a `user_id` nothing can be saved.
- The memory decision uses the fast classifier model (same decisions as the 120b model in ~0.4s instead of ~7s).

## Endpoints
`PUT /users/{id}/data` · `GET /users/{id}/context` · `GET /users/{id}/memory` · `DELETE /users/{id}/memory` (user can clear it).
Storage: SQLite at `agent/data/finflow_agent.db` (git-ignored; override with `FINFLOW_AGENT_DB`).
**These endpoints have no authentication yet**: anyone who knows a `user_id` could read or replace that user's data. Add auth before going public.

## Deploying (added with the Render setup)
- Set `USERS_API_ENABLED=false` on any public deployment: the `/users/*` endpoints are then not served (404). The app does not use
  them yet; it sends its numbers inline with each chat. The endpoints are rate limited (separate budget) and covered by the request-size cap either way.
- On hosts without a persistent disk (Render's free plan) the SQLite file is wiped on restart, sleep and redeploy, so stored snapshots and
  memory are not durable there. Use an external database or persistent disk before relying on them.
- Each chat is several model calls (answer, classifier, follow-up repair when needed, memory step when a `user_id` is sent).
