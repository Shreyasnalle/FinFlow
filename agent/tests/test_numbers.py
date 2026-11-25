from datetime import date

from app.context.numbers import add_months, build_context, next_due
from app.context.snapshot import Snapshot

TODAY = date(2026, 11, 25)


def snap(**over):
    base = {
        "profile": {"name": "Asha", "currency": "INR"},
        "cash_balance": 42000,
        "transactions": [
            {"date": "2026-09-05", "amount": 60000, "category": "Salary", "is_income": True},
            {"date": "2026-09-10", "amount": 30000, "category": "Rent"},
            {"date": "2026-10-05", "amount": 60000, "category": "Salary", "is_income": True},
            {"date": "2026-10-12", "amount": 40000, "category": "Rent"},
            {"date": "2026-11-05", "amount": 60000, "category": "Salary", "is_income": True},
            {"date": "2026-11-06", "amount": 18000, "category": "Rent", "note": "November rent"},
            {"date": "2026-11-10", "amount": 9000, "category": "Food"},
            {"date": "2026-11-12", "amount": 5000, "category": "SIP", "is_investment": True},
        ],
        "budgets": {"Food": 10000, "Rent": 18000, "Fun": 5000},
        "goals": [{"title": "Goa trip", "target_amount": 30000, "saved_amount": 8000, "deadline": "2027-02-25"}],
        "bills": [{"name": "Netflix", "amount": 649, "due_date": "2026-10-28"}, {"name": "Gym", "amount": 2000, "due_date": "2026-11-27"}],
        "assets": [{"name": "Gold", "value": 30000}, {"name": "Mutual funds", "value": 70000}],
    }
    base.update(over)
    return Snapshot.model_validate(base)


def test_core_numbers():
    c = build_context(snap(), TODAY)
    assert c["cash_balance"] == 42000
    assert c["this_month"] == {"income": 60000, "spending": 27000, "invested": 5000, "net": 28000, "savings_rate_pct": 46.67}
    assert c["last_month"] == {"income": 60000, "spending": 40000}
    assert c["spending_change_vs_last_month_pct"] == -32.5
    assert c["avg_monthly_spending"] == 35000 and c["avg_monthly_net"] == 25000  # Sep + Oct
    assert c["runway_months"] == 1.2
    assert c["spending_by_category_this_month"][0] == {"category": "Rent", "amount": 18000, "share_pct": 66.67}
    assert c["profile"] == {"name": "Asha", "currency": "INR"}


def test_budgets_goals_bills_assets():
    c = build_context(snap(), TODAY)
    by = {b["category"]: b for b in c["budgets"]}
    assert by["Rent"]["status"] == "over" and by["Food"]["status"] == "near" and by["Fun"]["status"] == "ok"
    g = c["goals"][0]
    assert g["remaining"] == 22000 and g["progress_pct"] == 26.67 and g["months_to_reach_at_avg_net"] == 1
    assert g["months_left"] == 3 and g["required_monthly"] == 7333.33
    bills = c["recurring_bills"]
    assert bills["monthly_total"] == 2649
    assert [b["name"] for b in bills["upcoming"]] == ["Gym", "Netflix"]  # Gym due in 2 days; Netflix rolled to Dec 28
    assert bills["upcoming"][0]["days_until"] == 2
    assert c["assets"]["total"] == 100000 and c["assets"]["allocation"][0]["share_pct"] == 70
    assert c["net_worth_excluding_liabilities"] == 142000


def test_empty_snapshot_is_safe():
    c = build_context(Snapshot(), TODAY)
    assert c["cash_balance"] == 0 and c["runway_months"] is None
    assert "No transactions logged yet." in c["data_notes"]


def test_balance_derived_when_missing():
    c = build_context(snap(cash_balance=None), TODAY)
    assert c["cash_balance"] == 180000 - 97000 - 5000
    assert any("derived" in n for n in c["data_notes"])


def test_date_helpers():
    assert add_months(date(2026, 1, 31), 1) == date(2026, 2, 28)
    assert next_due(date(2025, 1, 15), TODAY) == date(2026, 12, 15)
    assert next_due(date(2026, 11, 25), TODAY) == TODAY
