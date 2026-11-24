from enum import Enum

from pydantic import BaseModel, Field


class Category(str, Enum):
    OK = "ok"
    OFF_TOPIC = "off_topic"
    SPECIFIC_INVESTMENT_ADVICE = "specific_investment_advice"
    ILLEGAL_OR_FRAUD = "illegal_or_fraud"
    HARMFUL_CONTENT = "harmful_content"
    PROMPT_LEAK_OR_MANIPULATION = "prompt_leak_or_manipulation"
    PRIVACY_VIOLATION = "privacy_violation"
    CHECK_FAILED = "check_failed"  # we could not verify the draft, so we block (fail closed)
    OTHER = "other"


class GuardrailDecision(BaseModel):
    """What the classifier agent must return (structured output)."""

    allowed: bool = Field(description="True only if the draft is safe and in scope to show.")
    category: Category = Field(description="'ok' if allowed, otherwise the best-fitting reason.")
    topic: str = Field(
        default="",
        max_length=80,
        description="2-6 words naming what the USER asked about, e.g. 'writing code'. Empty if allowed.",
    )
    reason: str = Field(default="", max_length=300, description="One short sentence for logs.")
