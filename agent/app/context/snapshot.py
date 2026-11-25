"""The data the app syncs to the backend. Lenient on purpose: unknown fields are ignored."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class _Loose(BaseModel):
    model_config = ConfigDict(extra="ignore")


class Profile(_Loose):
    name: str = ""
    profession: str = ""
    currency: str = ""


class Txn(_Loose):
    date: datetime
    amount: float = Field(ge=0)
    category: str = "Other"
    note: str = ""
    is_income: bool = False
    is_investment: bool = False


class Goal(_Loose):
    title: str
    target_amount: float = Field(ge=0)
    saved_amount: float = Field(default=0, ge=0)
    deadline: datetime | None = None


class Bill(_Loose):
    name: str
    amount: float = Field(ge=0)
    due_date: datetime


class Asset(_Loose):
    name: str
    value: float
    type: str = ""


class Snapshot(_Loose):
    profile: Profile = Field(default_factory=Profile)
    cash_balance: float | None = None
    transactions: list[Txn] = Field(default_factory=list, max_length=5000)
    budgets: dict[str, float] = Field(default_factory=dict)
    goals: list[Goal] = Field(default_factory=list, max_length=100)
    bills: list[Bill] = Field(default_factory=list, max_length=200)
    assets: list[Asset] = Field(default_factory=list, max_length=200)
