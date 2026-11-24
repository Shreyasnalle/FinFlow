import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import 'connection_native.dart' if (dart.library.js_interop) 'connection_web.dart' as platform;
import 'schema/schema.dart';

/// Owns the SQLite connection: opens it (a file on phones/desktop, IndexedDB in
/// the browser), applies PRAGMAs and runs migrations. All app data lives in
/// this one database.
class AppDatabase {
  AppDatabase._(this.raw);

  final CommonDatabase raw;

  static Future<AppDatabase> open() async => _setUp(await platform.openConnection());

  /// In-memory database, for tests (native only).
  @visibleForTesting
  static AppDatabase inMemory() => _setUp(platform.openInMemory());

  static AppDatabase _setUp(CommonDatabase db) {
    try {
      db.execute('PRAGMA foreign_keys = ON');
      for (final pragma in const [
        'PRAGMA journal_mode = WAL',
        'PRAGMA synchronous = NORMAL',
        'PRAGMA secure_delete = ON',
      ]) {
        // Not every storage backend (e.g. the browser's) supports these.
        try {
          db.execute(pragma);
        } catch (_) {}
      }
      _migrate(db);
      return AppDatabase._(db);
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  static void _migrate(CommonDatabase db) {
    final current = db.select('PRAGMA user_version').first.values.first as int;
    for (var v = current; v < migrations.length; v++) {
      db.execute('BEGIN');
      try {
        for (final stmt in migrations[v]) {
          db.execute(stmt);
        }
        db.execute('PRAGMA user_version = ${v + 1}');
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  void close() => raw.dispose();
}
