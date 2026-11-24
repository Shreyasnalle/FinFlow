/// Money is stored as INTEGER minor units (paise/cents) to avoid float drift.
/// Timestamps in `occurred_at` / `due_date` are local-time ISO-8601 text
/// (what Dart's `DateTime.toIso8601String()` gives for a local DateTime), so
/// they sort lexicographically and `substr(x,1,7)` is the 'YYYY-MM' month key.
const List<String> v1Tables = [
  // Single-row profile + preferences. id is pinned to 1.
  r'''
CREATE TABLE user_profile (
  id          INTEGER PRIMARY KEY CHECK (id = 1),
  name        TEXT    NOT NULL DEFAULT 'User',
  mobile      TEXT    NOT NULL DEFAULT '',
  age         TEXT    NOT NULL DEFAULT '',
  profession  TEXT    NOT NULL DEFAULT '',
  pin_hash    TEXT    NOT NULL DEFAULT '',
  pin_salt    TEXT    NOT NULL DEFAULT '',
  theme_mode  INTEGER NOT NULL DEFAULT 1 CHECK (theme_mode IN (0, 1, 2)),
  currency    TEXT    NOT NULL DEFAULT '₹ INR',
  ai_api_key  TEXT    NOT NULL DEFAULT '',
  updated_at  INTEGER NOT NULL
)''',

  // Case-insensitive unique category names (fixes the old "Food" vs "food" hack).
  r'''
CREATE TABLE categories (
  id          INTEGER PRIMARY KEY,
  name        TEXT    NOT NULL COLLATE NOCASE UNIQUE
                      CHECK (length(trim(name)) > 0),
  created_at  INTEGER NOT NULL
)''',

  r'''
CREATE TABLE goals (
  id            TEXT PRIMARY KEY,
  title         TEXT    NOT NULL CHECK (length(trim(title)) > 0),
  target_minor  INTEGER NOT NULL CHECK (target_minor > 0),
  saved_minor   INTEGER NOT NULL DEFAULT 0 CHECK (saved_minor >= 0),
  status        TEXT    NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'completed')),
  completed_at  TEXT,
  created_at    INTEGER NOT NULL
)''',

  // anchor_day keeps "31st" bills on the last day of short months instead of
  // drifting (Jan 31 -> Feb 28 -> Mar 31, not Mar 28).
  r'''
CREATE TABLE recurring_bills (
  id            TEXT PRIMARY KEY,
  name          TEXT    NOT NULL CHECK (length(trim(name)) > 0),
  amount_minor  INTEGER NOT NULL CHECK (amount_minor > 0),
  due_date      TEXT    NOT NULL
                        CHECK (due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*'),
  anchor_day    INTEGER NOT NULL CHECK (anchor_day BETWEEN 1 AND 31),
  created_at    INTEGER NOT NULL
)''',

  // 'investment' counts as an outflow, same as 'expense', for balance purposes.
  r'''
CREATE TABLE transactions (
  id            TEXT PRIMARY KEY,
  amount_minor  INTEGER NOT NULL CHECK (amount_minor > 0),
  occurred_at   TEXT    NOT NULL
                        CHECK (occurred_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*'),
  month_key     TEXT GENERATED ALWAYS AS (substr(occurred_at, 1, 7)) STORED,
  category_id   INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  note          TEXT    NOT NULL DEFAULT '',
  kind          TEXT    NOT NULL CHECK (kind IN ('income', 'expense', 'investment')),
  source        TEXT    NOT NULL DEFAULT 'manual'
                        CHECK (source IN ('manual', 'bill', 'goal_save', 'transfer')),
  bill_id       TEXT REFERENCES recurring_bills(id) ON DELETE SET NULL,
  goal_id       TEXT REFERENCES goals(id) ON DELETE SET NULL,
  created_at    INTEGER NOT NULL
)''',

  r'''
CREATE TABLE budgets (
  category_id          INTEGER PRIMARY KEY REFERENCES categories(id) ON DELETE CASCADE,
  monthly_limit_minor  INTEGER NOT NULL CHECK (monthly_limit_minor > 0),
  updated_at           INTEGER NOT NULL
)''',

  r'''
CREATE TABLE assets (
  id           TEXT PRIMARY KEY,
  name         TEXT    NOT NULL CHECK (length(trim(name)) > 0),
  value_minor  INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
)''',

  r'''
CREATE TABLE asset_history (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id     TEXT    NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  value_minor  INTEGER NOT NULL,
  recorded_at  TEXT    NOT NULL
)''',

  // Trigger-maintained aggregate: one row per (month, category, kind).
  // SQLite has no materialized views, so this is the stand-in; analytics read
  // from here instead of scanning every transaction.
  r'''
CREATE TABLE monthly_rollup (
  month_key    TEXT    NOT NULL,
  category_id  INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  kind         TEXT    NOT NULL CHECK (kind IN ('income', 'expense', 'investment')),
  total_minor  INTEGER NOT NULL,
  txn_count    INTEGER NOT NULL,
  PRIMARY KEY (month_key, category_id, kind)
) WITHOUT ROWID''',

  // Agent memory (the old memory.md) as a zlib-compressed BLOB, plus a small
  // queryable table of distilled facts.
  r'''
CREATE TABLE agent_memory (
  id         INTEGER PRIMARY KEY CHECK (id = 1),
  version    INTEGER NOT NULL DEFAULT 1,
  content    BLOB    NOT NULL,
  raw_bytes  INTEGER NOT NULL CHECK (raw_bytes >= 0),
  sha256     TEXT    NOT NULL,
  updated_at INTEGER NOT NULL
)''',

  r'''
CREATE TABLE memory_facts (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  confidence  REAL NOT NULL DEFAULT 1.0 CHECK (confidence BETWEEN 0 AND 1),
  source      TEXT NOT NULL DEFAULT 'agent' CHECK (source IN ('agent', 'user', 'derived')),
  updated_at  INTEGER NOT NULL
) WITHOUT ROWID''',

  r'''
CREATE TABLE investor_profile (
  id                        INTEGER PRIMARY KEY CHECK (id = 1),
  risk_tolerance            TEXT CHECK (risk_tolerance IN ('conservative', 'moderate', 'aggressive')),
  horizon_years             INTEGER CHECK (horizon_years BETWEEN 1 AND 60),
  monthly_investable_minor  INTEGER CHECK (monthly_investable_minor >= 0),
  updated_at                INTEGER NOT NULL
)''',

  r'''
CREATE TABLE recommendations (
  id            TEXT PRIMARY KEY,
  created_at    TEXT NOT NULL,
  kind          TEXT NOT NULL,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  payload_json  TEXT,
  status        TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'accepted', 'dismissed'))
)''',

  r'''
CREATE TABLE chat_messages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id  TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content     TEXT NOT NULL,
  created_at  TEXT NOT NULL
)''',

  // Written only by triggers. Pruned to the newest 5000 rows by a trigger.
  r'''
CREATE TABLE audit_log (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name  TEXT NOT NULL,
  row_id      TEXT NOT NULL,
  action      TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_json    TEXT,
  new_json    TEXT,
  at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
)''',
];
