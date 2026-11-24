import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';

import 'app_database.dart';

/// The agent's long-term memory (the old memory.md), stored as a
/// zlib-compressed BLOB with a SHA-256 integrity check, plus a small table of
/// distilled key/value facts that can be queried without decompressing.
class MemoryStore {
  MemoryStore(AppDatabase database) : _db = database.raw;

  final CommonDatabase _db;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Empty string if nothing is stored yet or the blob fails its checksum.
  String read() {
    final rows =
        _db.select('SELECT content, sha256 FROM agent_memory WHERE id = 1');
    if (rows.isEmpty) return '';
    final bytes = zlib.decode(rows.first['content'] as Uint8List);
    if (sha256.convert(bytes).toString() != rows.first['sha256']) {
      debugPrint('FinFlow: agent memory failed its checksum; ignoring it');
      return '';
    }
    return utf8.decode(bytes);
  }

  void write(String markdown) {
    final raw = utf8.encode(markdown);
    _db.execute(
        'INSERT INTO agent_memory (id, content, raw_bytes, sha256, updated_at) '
        'VALUES (1, ?, ?, ?, ?) ON CONFLICT (id) DO UPDATE SET '
        'content = excluded.content, raw_bytes = excluded.raw_bytes, '
        'sha256 = excluded.sha256, updated_at = excluded.updated_at',
        [zlib.encode(raw), raw.length, sha256.convert(raw).toString(), _now()]);
  }

  /// Bumped automatically by trigger trg_memory_au on every content change.
  int get version {
    final rows = _db.select('SELECT version FROM agent_memory WHERE id = 1');
    return rows.isEmpty ? 0 : rows.first['version'] as int;
  }

  Map<String, String> facts() => {
        for (final r in _db.select('SELECT key, value FROM memory_facts ORDER BY key'))
          r['key'] as String: r['value'] as String,
      };

  void upsertFact(String key, String value,
      {double confidence = 1.0, String source = 'agent'}) {
    _db.execute(
        'INSERT INTO memory_facts (key, value, confidence, source, updated_at) '
        'VALUES (?, ?, ?, ?, ?) ON CONFLICT (key) DO UPDATE SET '
        'value = excluded.value, confidence = excluded.confidence, '
        'source = excluded.source, updated_at = excluded.updated_at',
        [key, value, confidence, source, _now()]);
  }

  void deleteFact(String key) =>
      _db.execute('DELETE FROM memory_facts WHERE key = ?', [key]);
}
