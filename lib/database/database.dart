import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// One group of items in a checklist's view: the items of [source], which is
/// either the checklist itself or one of its ancestors.
class ChecklistSection {
  const ChecklistSection(this.source, this.items);

  final Checklist source;
  final List<ChecklistItem> items;
}

@DriftDatabase(
  tables: [Checklists, ChecklistItems, ChecklistParents],
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

  /// Creates an empty checklist titled [title].
  Future<Checklist> createChecklist(String title) {
    return into(
      checklists,
    ).insertReturning(ChecklistsCompanion.insert(title: title));
  }

  Future<void> renameChecklist(int id, String title) {
    return (update(checklists)..where((c) => c.id.equals(id))).write(
      ChecklistsCompanion(title: Value(title)),
    );
  }

  /// Deletes a checklist; its items and inheritance links go with it via the
  /// cascading foreign keys.
  ///
  /// Lists that inherit from it lose those items, unless [copyToChildren] is
  /// set: then each child first receives the list's own items as items of its
  /// own, and inherits from the list's parents in its place, so nothing it
  /// showed disappears.
  Future<void> deleteChecklist(int id, {bool copyToChildren = false}) {
    return transaction(() async {
      if (copyToChildren) {
        final items = await getChecklistItems(id);
        final parentIds = await getChecklistParentIds(id);
        for (final child in await getChildren(id)) {
          final existing = await getChecklistItems(child.id);
          await batch((b) {
            b.insertAll(checklistItems, [
              for (final (i, item) in items.indexed)
                ChecklistItemsCompanion.insert(
                  checklistId: child.id,
                  title: item.title,
                  position: existing.length + i,
                ),
            ]);
          });
          final merged = <int>{};
          for (final parentId in await getChecklistParentIds(child.id)) {
            if (parentId == id) {
              merged.addAll(parentIds);
            } else {
              merged.add(parentId);
            }
          }
          await setChecklistParents(child.id, merged.toList());
        }
      }
      await (delete(checklists)..where((c) => c.id.equals(id))).go();
    });
  }

  /// The ids of the lists [id] inherits from directly, in order.
  Future<List<int>> getChecklistParentIds(int id) async {
    final rows =
        await (select(checklistParents)
              ..where((p) => p.childId.equals(id))
              ..orderBy([(p) => OrderingTerm.asc(p.position)]))
            .get();
    return [for (final row in rows) row.parentId];
  }

  /// Makes [childId] inherit from exactly [parentIds], in the given order.
  Future<void> setChecklistParents(int childId, List<int> parentIds) {
    return transaction(() async {
      await (delete(
        checklistParents,
      )..where((p) => p.childId.equals(childId))).go();
      await batch((b) {
        b.insertAll(checklistParents, [
          for (final (i, parentId) in parentIds.indexed)
            ChecklistParentsCompanion.insert(
              childId: childId,
              parentId: parentId,
              position: i,
            ),
        ]);
      });
    });
  }

  /// The lists that inherit directly from [id], sorted by title.
  Future<List<Checklist>> getChildren(int id) {
    final query =
        select(checklists).join([
            innerJoin(
              checklistParents,
              checklistParents.childId.equalsExp(checklists.id),
            ),
          ])
          ..where(checklistParents.parentId.equals(id))
          ..orderBy([
            OrderingTerm.asc(checklists.title.collate(Collate.noCase)),
          ]);
    return query.map((row) => row.readTable(checklists)).get();
  }

  /// Every list that inherits from [id], directly or through other lists.
  /// Making [id] inherit from one of these would create a cycle.
  Future<Set<int>> getDescendantIds(int id) async {
    final descendants = <int>{};
    var frontier = [id];
    while (frontier.isNotEmpty) {
      final rows = await (select(
        checklistParents,
      )..where((p) => p.parentId.isIn(frontier))).get();
      frontier = [
        for (final row in rows)
          if (descendants.add(row.childId)) row.childId,
      ];
    }
    return descendants;
  }

  /// Streams the items [id] shows, grouped by the list they come from:
  /// ancestors first (each list's own ancestors before it, parents in order,
  /// every list once), then [id]'s own items. Re-emits when any list, item, or
  /// link changes, since a base list's edits show up in its children.
  Stream<List<ChecklistSection>> watchChecklistSections(int id) {
    late final StreamController<List<ChecklistSection>> controller;
    StreamSubscription<void>? subscription;
    var latest = 0;

    // Loads can overlap when changes arrive in quick succession; only the
    // newest one may emit, so a slow stale load can't overwrite fresh data.
    Future<void> emit() async {
      final request = ++latest;
      try {
        final sections = await _loadSections(id);
        if (request == latest && !controller.isClosed) controller.add(sections);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController(
      onListen: () {
        emit();
        subscription = tableUpdates(
          TableUpdateQuery.onAllTables([
            checklists,
            checklistItems,
            checklistParents,
          ]),
        ).listen((_) => emit());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  Future<List<ChecklistSection>> _loadSections(int id) async {
    final order = <int>[];
    final visited = <int>{};
    Future<void> visit(int listId) async {
      if (!visited.add(listId)) return;
      for (final parentId in await getChecklistParentIds(listId)) {
        await visit(parentId);
      }
      order.add(listId);
    }

    await visit(id);
    final sections = <ChecklistSection>[];
    for (final listId in order) {
      final list = await (select(
        checklists,
      )..where((c) => c.id.equals(listId))).getSingleOrNull();
      // A list deleted mid-load, or the one being viewed after its deletion.
      if (list == null) continue;
      sections.add(ChecklistSection(list, await getChecklistItems(listId)));
    }
    return sections;
  }

  /// Streams all checklists, sorted alphabetically by title (ignoring case),
  /// re-emitting on changes.
  Stream<List<Checklist>> watchChecklists() {
    return (select(checklists)..orderBy([
          (c) => OrderingTerm.asc(c.title.collate(Collate.noCase)),
          (c) => OrderingTerm.asc(c.id),
        ]))
        .watch();
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
