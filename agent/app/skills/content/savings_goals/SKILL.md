---
name: savings_goals
description: Plan and track savings goals - progress, time to reach a target, monthly contribution needed, prioritising multiple goals.
---
## When to use
"Can I reach my goal?", "How much per month for X?", "Which goal first?", trip, gadget, wedding, house deposit.

## Approach
1. Read each goal: target, saved, deadline if any.
2. Compute remaining = target - saved. With a deadline: monthly needed = remaining / months left. Without: use the user's realistic monthly surplus (average monthly net) to estimate time.
3. Check feasibility against the surplus; if not feasible, offer two options: extend the date or raise contributions, with the numbers.
4. With several goals, suggest an order (emergency fund and nearest deadline first) and a split of the surplus.
5. Mention automating a fixed monthly transfer.

## Output
Per goal: remaining, monthly needed, feasible or not, one recommendation.
