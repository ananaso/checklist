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

  Future<int> addChecklistItem(ChecklistItemsCompanion item) {
    return into(checklistItems).insert(item);
  }

  Future updateChecklistItem(ChecklistItem item) {
    return (update(checklistItems)..where((ci) => ci.id.equals(item.id))).write(
      ChecklistItemsCompanion(title: Value(item.title)),
    );
  }

  Future deleteChecklistItem(int id) {
    return transaction(() async {
      // Helper to get position value of item that will be deleted
      final deletedItemPosition = selectOnly(checklistItems)
        ..addColumns([checklistItems.position])
        ..where(checklistItems.id.equals(id));

      // Move all higher-position items "up" by 1 position
      await (update(checklistItems)..where(
            (ci) => ci.position.isBiggerThan(
              subqueryExpression(deletedItemPosition),
            ),
          ))
          .write(
            ChecklistItemsCompanion.custom(
              position: checklistItems.position - Variable(1),
            ),
          );

      // delete the item
      await (delete(checklistItems)..where((ci) => ci.id.equals(id))).go();
    });
  }
}
