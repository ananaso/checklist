import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Checklists, ChecklistItems],
) // , include: {'triggers.drift'}
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
        await customStatement('PRAGMA foreign_keys = ON');
        // Reset the DB whenever in debug mode
        if (kDebugMode) {
          final m = Migrator(this);
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
            await m.createTable(table);
          }
        }
        // Until there's UI for creating lists, make sure one always exists.
        if (await select(checklists).get().then((l) => l.isEmpty)) {
          await into(
            checklists,
          ).insert(ChecklistsCompanion.insert(title: 'My Checklist'));
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

  /// Streams all checklists, oldest first, re-emitting on changes.
  Stream<List<Checklist>> watchChecklists() {
    return (select(
      checklists,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).watch();
  }

  /// Streams a checklist's items in list order, re-emitting on changes.
  Stream<List<ChecklistItem>> watchChecklistItems(int checklistId) {
    return (select(checklistItems)
          ..where((ci) => ci.checklistId.equals(checklistId))
          ..orderBy([(ci) => OrderingTerm.asc(ci.position)]))
        .watch();
  }

  /// Fetches a checklist's items once, in list order.
  Future<List<ChecklistItem>> getChecklistItems(int checklistId) {
    return (select(checklistItems)
          ..where((ci) => ci.checklistId.equals(checklistId))
          ..orderBy([(ci) => OrderingTerm.asc(ci.position)]))
        .get();
  }

  /// Replaces a checklist's items with [titles], positioned in the given order.
  Future<void> replaceChecklistItems(int checklistId, List<String> titles) {
    return transaction(() async {
      await (delete(
        checklistItems,
      )..where((ci) => ci.checklistId.equals(checklistId))).go();
      await batch((b) {
        b.insertAll(checklistItems, [
          for (final (i, title) in titles.indexed)
            ChecklistItemsCompanion.insert(
              checklistId: checklistId,
              title: title,
              position: i,
            ),
        ]);
      });
    });
  }
}
