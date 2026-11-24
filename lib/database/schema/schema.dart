import 'v1_indexes.dart';
import 'v1_tables.dart';
import 'v1_triggers.dart';
import 'v1_views.dart';

/// Ordered migrations. `PRAGMA user_version` records how many have been applied.
/// To change the schema, append a new list; never edit a released one.
final List<List<String>> migrations = [
  [...v1Tables, ...v1Indexes, ...v1Views, ...v1Triggers],
];
