const List<String> v1Indexes = [
  // Newest-first lists and keyset pagination on (occurred_at, id).
  'CREATE INDEX idx_txn_occurred ON transactions(occurred_at DESC, id DESC)',
  // Per-category history and "all spending in category X this month".
  'CREATE INDEX idx_txn_category ON transactions(category_id, occurred_at DESC)',
  // Month scans / rollup rebuilds without touching the table rows.
  'CREATE INDEX idx_txn_month_kind ON transactions(month_key, kind, category_id, amount_minor)',
  // Partial indexes: only rows that actually link to a bill / goal.
  'CREATE INDEX idx_txn_bill ON transactions(bill_id) WHERE bill_id IS NOT NULL',
  'CREATE INDEX idx_txn_goal ON transactions(goal_id) WHERE goal_id IS NOT NULL',
  // Idempotency guard: the same bill can never be auto-charged twice for one due date.
  'CREATE UNIQUE INDEX uq_bill_occurrence ON transactions(bill_id, occurred_at) WHERE bill_id IS NOT NULL',
  'CREATE INDEX idx_asset_history ON asset_history(asset_id, recorded_at DESC)',
  'CREATE INDEX idx_bills_due ON recurring_bills(due_date)',
  'CREATE INDEX idx_reco_status ON recommendations(status, created_at DESC)',
  'CREATE INDEX idx_chat_session ON chat_messages(session_id, id)',
  'CREATE INDEX idx_audit_table_row ON audit_log(table_name, row_id)',
];
