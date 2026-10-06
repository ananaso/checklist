import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [ChecklistItems]) // , include: {'triggers.drift'}
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (openingDetails) async {
        // Reset the DB whenever in debug mode
        if (kDebugMode) {
          final m = Migrator(this);
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
            await m.createTable(table);
          }
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'app_database',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
      // If you need web support, see https://drift.simonbinder.eu/platforms/web/
    );
  }

  /// Streams all items in list order, re-emitting whenever they change.
  Stream<List<ChecklistItem>> watchChecklistItems() {
    return (select(
      checklistItems,
    )..orderBy([(ci) => OrderingTerm.asc(ci.position)])).watch();
  }

  /// Fetches all items once, in list order.
  Future<List<ChecklistItem>> getChecklistItems() {
    return (select(
      checklistItems,
    )..orderBy([(ci) => OrderingTerm.asc(ci.position)])).get();
  }

  /// Replaces the whole list with [titles], positioned in the given order.
  Future<void> replaceChecklistItems(List<String> titles) {
    return transaction(() async {
      await delete(checklistItems).go();
      await batch((b) {
        b.insertAll(checklistItems, [
          for (final (i, title) in titles.indexed)
            ChecklistItemsCompanion.insert(title: title, position: i),
        ]);
      });
    });
  }
}
