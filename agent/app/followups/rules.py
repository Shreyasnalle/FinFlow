from pathlib import Path

FOLLOWUP_RULES = (Path(__file__).parent / "followups.md").read_text(encoding="utf-8")
# The repair call returns structured output, so it does not need the inline format section.
RULES_ONLY = FOLLOWUP_RULES.split("## Output format")[0].strip()
