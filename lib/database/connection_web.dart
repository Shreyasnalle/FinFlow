import 'package:sqlite3/wasm.dart';

/// Browser storage: SQLite compiled to WebAssembly (web/sqlite3.wasm), with the
/// database file persisted in IndexedDB.
Future<CommonDatabase> openConnection() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fileSystem = await IndexedDbFileSystem.open(dbName: 'finflow');
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
  return sqlite.open('finflow.db');
}

CommonDatabase openInMemory() =>
    throw UnsupportedError('In-memory databases are only used by native tests.');
