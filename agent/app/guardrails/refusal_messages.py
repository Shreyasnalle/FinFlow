"""Friendly messages shown when the classifier blocks a draft.

Fixed templates per category (never free-form model text), personalised only with
a short, sanitised `topic` naming what the user asked about.
"""

import re

from app.guardrails.verdict import Category

_HELP = (
    "I'm happy to help with your budget, spending, savings goals, bills, "
    "investing basics, or using the app. What would you like to look at?"
)

TEMPLATES: dict[Category, str] = {
    Category.OFF_TOPIC: "I'm your personal finance coach, so {topic} is outside what I can help with. " + _HELP,
    Category.SPECIFIC_INVESTMENT_ADVICE: (
        "I can't tell you to buy or sell specific stocks, funds or coins, or promise returns - "
        "that needs a licensed advisor. I can explain how it works, the risks, and how it fits your goals. "
        "Want me to do that?"
    ),
    Category.ILLEGAL_OR_FRAUD: (
        "I can't help with {topic} because it could involve breaking the law. "
        "I'm glad to help with legal ways to save, cut costs or plan your taxes."
    ),
    Category.HARMFUL_CONTENT: "I can't help with that. " + _HELP,
    Category.PROMPT_LEAK_OR_MANIPULATION: "I can't share or change how I work, but I can help with your finances. " + _HELP,
    Category.PRIVACY_VIOLATION: (
        "I can only talk about your own finances, not other people's. "
        "Want to look at your own budget or spending instead?"
    ),
    Category.CHECK_FAILED: (
        "Sorry, I couldn't double-check that answer just now, so I'm holding it back. "
        "Please try asking again in a moment."
    ),
    Category.OTHER: "That's beyond what I can help with here. " + _HELP,
}

_DEFAULT_TOPIC = "that request"


def _clean_topic(topic: str) -> str:
    topic = re.sub(r"[^\w\s,'-]", "", topic or "").strip()[:60]
    return topic or _DEFAULT_TOPIC


def refusal_for(category: Category, topic: str = "") -> str:
    template = TEMPLATES.get(category, TEMPLATES[Category.OTHER])
    return template.format(topic=_clean_topic(topic))
