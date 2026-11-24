const String _rollupAdd = r'''
  INSERT INTO monthly_rollup (month_key, category_id, kind, total_minor, txn_count)
  VALUES (substr(NEW.occurred_at, 1, 7), NEW.category_id, NEW.kind, NEW.amount_minor, 1)
  ON CONFLICT (month_key, category_id, kind) DO UPDATE SET
    total_minor = total_minor + excluded.total_minor,
    txn_count   = txn_count + 1;''';

const String _rollupSub = r'''
  UPDATE monthly_rollup
     SET total_minor = total_minor - OLD.amount_minor,
         txn_count   = txn_count - 1
   WHERE month_key = substr(OLD.occurred_at, 1, 7)
     AND category_id = OLD.category_id
     AND kind = OLD.kind;
  DELETE FROM monthly_rollup
   WHERE month_key = substr(OLD.occurred_at, 1, 7)
     AND category_id = OLD.category_id
     AND kind = OLD.kind
     AND txn_count <= 0;''';

const String _goalStatusSync = r'''
  UPDATE goals
     SET status = 'completed', completed_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
   WHERE id = NEW.id AND saved_minor >= target_minor AND status = 'active';
  UPDATE goals
     SET status = 'active', completed_at = NULL
   WHERE id = NEW.id AND saved_minor < target_minor AND status = 'completed';''';

String _audit(String table, String idExpr, String Function(String) json) => '''
CREATE TRIGGER trg_audit_${table}_ai AFTER INSERT ON $table BEGIN
  INSERT INTO audit_log (table_name, row_id, action, new_json)
  VALUES ('$table', ${idExpr.replaceAll('@', 'NEW')}, 'INSERT', ${json('NEW')});
END''';

String _auditUpdate(String table, String idExpr, String Function(String) json) => '''
CREATE TRIGGER trg_audit_${table}_au AFTER UPDATE ON $table BEGIN
  INSERT INTO audit_log (table_name, row_id, action, old_json, new_json)
  VALUES ('$table', ${idExpr.replaceAll('@', 'NEW')}, 'UPDATE', ${json('OLD')}, ${json('NEW')});
END''';

String _auditDelete(String table, String idExpr, String Function(String) json) => '''
CREATE TRIGGER trg_audit_${table}_ad AFTER DELETE ON $table BEGIN
  INSERT INTO audit_log (table_name, row_id, action, old_json)
  VALUES ('$table', ${idExpr.replaceAll('@', 'OLD')}, 'DELETE', ${json('OLD')});
END''';

List<String> _auditTriggers(
    String table, String idExpr, String Function(String) json) {
  return [
    _audit(table, idExpr, json),
    _auditUpdate(table, idExpr, json),
    _auditDelete(table, idExpr, json),
  ];
}

String _txnJson(String r) =>
    "json_object('amount_minor', $r.amount_minor, 'kind', $r.kind, "
    "'category_id', $r.category_id, 'occurred_at', $r.occurred_at, "
    "'source', $r.source, 'note', $r.note)";
String _goalJson(String r) =>
    "json_object('title', $r.title, 'target_minor', $r.target_minor, "
    "'saved_minor', $r.saved_minor, 'status', $r.status)";
String _assetJson(String r) =>
    "json_object('name', $r.name, 'value_minor', $r.value_minor)";
String _billJson(String r) =>
    "json_object('name', $r.name, 'amount_minor', $r.amount_minor, "
    "'due_date', $r.due_date)";
String _budgetJson(String r) =>
    "json_object('category_id', $r.category_id, "
    "'monthly_limit_minor', $r.monthly_limit_minor)";

final List<String> v1Triggers = [
  // ── Transactions: consistency rules ──────────────────────────────────────
  r'''
CREATE TRIGGER trg_txn_bi_links BEFORE INSERT ON transactions
WHEN (NEW.goal_id IS NOT NULL AND NEW.source <> 'goal_save')
  OR (NEW.bill_id IS NOT NULL AND NEW.source <> 'bill')
  OR (NEW.source = 'goal_save' AND NEW.goal_id IS NULL)
  OR (NEW.source = 'bill' AND NEW.bill_id IS NULL)
BEGIN
  SELECT RAISE(ABORT, 'transaction source does not match its goal/bill link');
END''',

  r'''
CREATE TRIGGER trg_txn_bu_links BEFORE UPDATE OF source, goal_id, bill_id ON transactions
WHEN (NEW.goal_id IS NOT NULL AND NEW.source <> 'goal_save')
  OR (NEW.bill_id IS NOT NULL AND NEW.source <> 'bill')
BEGIN
  SELECT RAISE(ABORT, 'transaction source does not match its goal/bill link');
END''',

  // ── Transactions: rollup + goal progress ─────────────────────────────────
  '''
CREATE TRIGGER trg_txn_ai AFTER INSERT ON transactions BEGIN
$_rollupAdd
  UPDATE goals SET saved_minor = saved_minor + NEW.amount_minor WHERE id = NEW.goal_id;
END''',

  '''
CREATE TRIGGER trg_txn_ad AFTER DELETE ON transactions BEGIN
$_rollupSub
  UPDATE goals SET saved_minor = MAX(0, saved_minor - OLD.amount_minor) WHERE id = OLD.goal_id;
END''',

  '''
CREATE TRIGGER trg_txn_au AFTER UPDATE OF amount_minor, category_id, kind, occurred_at ON transactions BEGIN
$_rollupSub
$_rollupAdd
END''',

  r'''
CREATE TRIGGER trg_txn_au_goal AFTER UPDATE OF amount_minor ON transactions
WHEN NEW.goal_id IS NOT NULL AND NEW.amount_minor <> OLD.amount_minor
BEGIN
  UPDATE goals
     SET saved_minor = MAX(0, saved_minor + NEW.amount_minor - OLD.amount_minor)
   WHERE id = NEW.goal_id;
END''',

  // ── Goals: auto complete / reopen ────────────────────────────────────────
  '''
CREATE TRIGGER trg_goal_ai AFTER INSERT ON goals BEGIN
$_goalStatusSync
END''',

  '''
CREATE TRIGGER trg_goal_au AFTER UPDATE OF saved_minor, target_minor ON goals BEGIN
$_goalStatusSync
END''',

  // ── Assets: value history ────────────────────────────────────────────────
  r'''
CREATE TRIGGER trg_asset_ai AFTER INSERT ON assets BEGIN
  INSERT INTO asset_history (asset_id, value_minor, recorded_at)
  VALUES (NEW.id, NEW.value_minor, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'));
END''',

  r'''
CREATE TRIGGER trg_asset_au AFTER UPDATE OF value_minor ON assets
WHEN NEW.value_minor <> OLD.value_minor
BEGIN
  INSERT INTO asset_history (asset_id, value_minor, recorded_at)
  VALUES (NEW.id, NEW.value_minor, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'));
END''',

  // ── Agent memory: auto-bump version when the blob changes ────────────────
  r'''
CREATE TRIGGER trg_memory_au AFTER UPDATE OF content ON agent_memory
WHEN NEW.version = OLD.version
BEGIN
  UPDATE agent_memory SET version = OLD.version + 1 WHERE id = NEW.id;
END''',

  // ── Audit log: pruning ───────────────────────────────────────────────────
  r'''
CREATE TRIGGER trg_audit_prune AFTER INSERT ON audit_log BEGIN
  DELETE FROM audit_log WHERE id <= NEW.id - 5000;
END''',

  // ── Audit log: change capture ────────────────────────────────────────────
  ..._auditTriggers('transactions', '@.id', _txnJson),
  ..._auditTriggers('goals', '@.id', _goalJson),
  ..._auditTriggers('assets', '@.id', _assetJson),
  ..._auditTriggers('recurring_bills', '@.id', _billJson),
  ..._auditTriggers('budgets', 'CAST(@.category_id AS TEXT)', _budgetJson),
];
