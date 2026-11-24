import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

const _fileName = 'finflow.db';

Future<CommonDatabase> openConnection() async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, _fileName);

  Database open() {
    final db = sqlite3.open(path);
    // Fails with "file is not a database" for a file left by an older build
    // that encrypted it; that case is handled below.
    db.select('SELECT count(*) FROM sqlite_master');
    return db;
  }

  try {
    return open();
  } on SqliteException catch (e) {
    if (e.resultCode != 26) rethrow;
    // Keep the old (encrypted, now unreadable) file aside instead of deleting it.
    final aside = '$path.unreadable-${DateTime.now().millisecondsSinceEpoch}';
    for (final ext in const ['', '-wal', '-shm']) {
      final f = File('$path$ext');
      if (f.existsSync()) await f.rename('$aside$ext');
    }
    debugPrint('FinFlow: old database unreadable (${e.message}); moved to $aside');
    return open();
  }
}

CommonDatabase openInMemory() => sqlite3.openInMemory();
