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

  Future reorderChecklistItem(int id, int oldPosition, int newPosition) {
    //   get item's current/old position
    //   all affected items are those between old and new position
    //   if new position < old position, increment affected item positions; else decrement
    //   update item to new position
    /*
     * Scene: 5 items on list, dragging middle item (#2, zero-index)
     * Scenario 1: drag higher on list (lower index)
     *  - Old position = 2
     *  - New position = 0
     *  - Affected items: 0-1
     *  - Update affected items to be position += 1
     *  - Update dragged item to new position (0)
     * Scenario 2: drag lower on list (higher index)
     *  - Old position = 2
     *  - New position = 4
     *  - Affected items: 3-4
     *  - Update affected items to be position -= 1
     *  - Update dragged item to new position (4)
     */

    return transaction(() async {
      final reorderedItemPosition = selectOnly(checklistItems)
        ..addColumns([checklistItems.position])
        ..where(checklistItems.id.equals(id));

      bool movingToLowerPosition = oldPosition > newPosition;
      int lowerPosition = movingToLowerPosition ? newPosition : oldPosition;
      int higherPosition = movingToLowerPosition ? oldPosition : newPosition;

      await (update(checklistItems)..where(
            (ci) => ci.position.isBetweenValues(lowerPosition, higherPosition),
          ))
          .write(
            ChecklistItemsCompanion.custom(
              position: movingToLowerPosition
                  ? checklistItems.position + Variable(1)
                  : checklistItems.position - Variable(1),
            ),
          );

      await (update(checklistItems)..where((ci) => ci.id.equals(id))).write(
        ChecklistItemsCompanion.custom(position: Variable(newPosition)),
      );
    });
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
