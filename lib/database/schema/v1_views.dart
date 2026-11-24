/// Read models. Everything here reads from the trigger-maintained
/// `monthly_rollup` (tiny) rather than scanning `transactions`.
const List<String> v1Views = [
  // Cash balance: income in, expense + investment out.
  r'''
CREATE VIEW v_balance AS
SELECT COALESCE(SUM(CASE kind WHEN 'income' THEN total_minor ELSE -total_minor END), 0)
         AS balance_minor
FROM monthly_rollup''',

  r'''
CREATE VIEW v_monthly_summary AS
SELECT month_key,
       SUM(CASE WHEN kind = 'income'     THEN total_minor ELSE 0 END) AS income_minor,
       SUM(CASE WHEN kind = 'expense'    THEN total_minor ELSE 0 END) AS expense_minor,
       SUM(CASE WHEN kind = 'investment' THEN total_minor ELSE 0 END) AS investment_minor,
       SUM(CASE WHEN kind = 'income' THEN total_minor ELSE -total_minor END) AS net_minor
FROM monthly_rollup
GROUP BY month_key''',

  // "Spending" in the app means every non-income row (expense + investment).
  r'''
CREATE VIEW v_category_spend AS
SELECT r.month_key, c.name AS category, SUM(r.total_minor) AS spent_minor
FROM monthly_rollup r
JOIN categories c ON c.id = r.category_id
WHERE r.kind <> 'income'
GROUP BY r.month_key, r.category_id''',

  r'''
CREATE VIEW v_budget_status AS
SELECT s.month_key,
       c.name                AS category,
       b.monthly_limit_minor AS limit_minor,
       s.spent_minor,
       MAX(s.spent_minor - b.monthly_limit_minor, 0) AS over_minor
FROM budgets b
JOIN categories c ON c.id = b.category_id
JOIN (SELECT month_key, category_id, SUM(total_minor) AS spent_minor
        FROM monthly_rollup
       WHERE kind <> 'income'
       GROUP BY month_key, category_id) s
  ON s.category_id = b.category_id''',

  r'''
CREATE VIEW v_goal_progress AS
SELECT id, title, target_minor, saved_minor, status,
       MAX(target_minor - saved_minor, 0) AS remaining_minor,
       ROUND(100.0 * MIN(saved_minor, target_minor) / target_minor, 1) AS percent
FROM goals''',

  r'''
CREATE VIEW v_net_worth AS
SELECT b.balance_minor AS cash_minor,
       COALESCE((SELECT SUM(value_minor) FROM assets), 0) AS assets_minor,
       b.balance_minor + COALESCE((SELECT SUM(value_minor) FROM assets), 0) AS net_worth_minor
FROM v_balance b''',
];
