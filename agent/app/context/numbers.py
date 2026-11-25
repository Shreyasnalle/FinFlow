"""Python computes the numbers; the LLM only reads and explains them (no model arithmetic)."""

import calendar
import math
from collections import defaultdict
from datetime import date, datetime

from app.context.snapshot import Snapshot


def _r(x: float) -> float:
    return round(float(x), 2)


def _month(d: date) -> tuple[int, int]:
    return d.year, d.month


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.month - 1 + n, 12)
    year, month = d.year + y, m + 1
    return date(year, month, min(d.day, calendar.monthrange(year, month)[1]))


def next_due(due: date, today: date) -> date:
    n = 0
    while add_months(due, n) < today and n < 1200:
        n += 1
    return add_months(due, n)


def build_context(snap: Snapshot, today: date | None = None) -> dict:
    today = today or date.today()
    this_m = _month(today)
    prev_m = _month(add_months(today.replace(day=1), -1))

    income: dict = defaultdict(float)
    spend: dict = defaultdict(float)
    invested: dict = defaultdict(float)
    by_cat: dict = defaultdict(float)
    for t in snap.transactions:
        m = _month(t.date.date())
        if t.is_income:
            income[m] += t.amount
        elif t.is_investment:
            invested[m] += t.amount
        else:
            spend[m] += t.amount
            if m == this_m:
                by_cat[t.category] += t.amount

    notes: list[str] = []
    if not snap.transactions:
        notes.append("No transactions logged yet.")

    cash = snap.cash_balance
    if cash is None:
        cash = sum(income.values()) - sum(spend.values()) - sum(invested.values())
        notes.append("Cash balance was derived from transactions.")

    complete = sorted(m for m in set(income) | set(spend) if m < this_m)[-3:]
    if complete:
        avg_net = sum(income[m] - spend[m] - invested[m] for m in complete) / len(complete)
        avg_spend = sum(spend[m] for m in complete) / len(complete)
        avg_income = sum(income[m] for m in complete) / len(complete)
    else:
        avg_net = income[this_m] - spend[this_m] - invested[this_m]
        avg_spend, avg_income = spend[this_m], income[this_m]
        if snap.transactions:
            notes.append("Averages use this month only (no earlier full months).")

    inc, sp = income[this_m], spend[this_m]
    this_month = {
        "income": _r(inc), "spending": _r(sp), "invested": _r(invested[this_m]),
        "net": _r(inc - sp - invested[this_m]),
        "savings_rate_pct": _r((inc - sp - invested[this_m]) / inc * 100) if inc > 0 else None,
    }
    change = _r((sp - spend[prev_m]) / spend[prev_m] * 100) if spend[prev_m] > 0 else None

    cats = sorted(by_cat.items(), key=lambda kv: kv[1], reverse=True)[:8]
    budgets = []
    for cat, limit in snap.budgets.items():
        used = by_cat.get(cat, 0.0)
        pct = used / limit * 100 if limit > 0 else 0
        budgets.append({"category": cat, "limit": _r(limit), "spent": _r(used), "used_pct": _r(pct),
                        "status": "over" if pct >= 100 else "near" if pct >= 80 else "ok"})

    goals = []
    for g in snap.goals:
        remaining = max(g.target_amount - g.saved_amount, 0.0)
        item = {"title": g.title, "target": _r(g.target_amount), "saved": _r(g.saved_amount),
                "remaining": _r(remaining),
                "progress_pct": _r(g.saved_amount / g.target_amount * 100) if g.target_amount > 0 else 0,
                "months_to_reach_at_avg_net": math.ceil(remaining / avg_net) if remaining > 0 and avg_net > 0 else None}
        if g.deadline:
            months_left = max(1, round((g.deadline.date() - today).days / 30))
            item["deadline"] = g.deadline.date().isoformat()
            item["months_left"] = months_left
            item["required_monthly"] = _r(remaining / months_left)
        goals.append(item)

    upcoming = sorted(
        ({"name": b.name, "amount": _r(b.amount), "next_due": nd.isoformat(), "days_until": (nd - today).days}
         for b in snap.bills for nd in [next_due(b.due_date.date(), today)]),
        key=lambda x: x["days_until"],
    )
    bills_total = sum(b.amount for b in snap.bills)
    base_income = avg_income or inc
    assets_total = sum(a.value for a in snap.assets)

    return {
        "as_of": today.isoformat(),
        "profile": {k: v for k, v in snap.profile.model_dump().items() if v},
        "cash_balance": _r(cash),
        "this_month": this_month,
        "last_month": {"income": _r(income[prev_m]), "spending": _r(spend[prev_m])},
        "spending_change_vs_last_month_pct": change,
        "avg_monthly_income": _r(avg_income), "avg_monthly_spending": _r(avg_spend), "avg_monthly_net": _r(avg_net),
        "runway_months": _r(cash / avg_spend) if avg_spend > 0 else None,
        "spending_by_category_this_month": [
            {"category": c, "amount": _r(a), "share_pct": _r(a / sp * 100) if sp > 0 else 0} for c, a in cats],
        "budgets": budgets,
        "goals": goals,
        "recurring_bills": {
            "monthly_total": _r(bills_total),
            "share_of_income_pct": _r(bills_total / base_income * 100) if base_income > 0 else None,
            "upcoming": upcoming[:8]},
        "assets": {
            "total": _r(assets_total),
            "allocation": [{"name": a.name, "value": _r(a.value),
                            "share_pct": _r(a.value / assets_total * 100) if assets_total > 0 else 0}
                           for a in sorted(snap.assets, key=lambda a: a.value, reverse=True)]},
        "net_worth_excluding_liabilities": _r(cash + assets_total),
        "recent_transactions": [
            {"date": t.date.date().isoformat(), "amount": _r(t.amount), "category": t.category,
             "type": "income" if t.is_income else "investment" if t.is_investment else "expense",
             "note": t.note[:40]}
            for t in sorted(snap.transactions, key=lambda t: t.date, reverse=True)[:10]],
        "data_notes": notes + ["Liabilities and debts are not tracked in the app."],
    }
