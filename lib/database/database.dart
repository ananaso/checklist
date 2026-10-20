import 'dart:async';
import 'dart:convert';

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
  tables: [Checklists, ChecklistItems, ChecklistParents, ChecklistChecks],
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
        // Opt-in schema reset for debug runs while iterating on the tables:
        // flutter run --dart-define=RESET_DB=true
        if (kDebugMode && const bool.fromEnvironment('RESET_DB')) {
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
          // The child and everything below it saw these items through it.
          final viewers = [child.id, ...await getDescendantIds(child.id)];
          final checkedIds = {
            for (final viewer in viewers)
              viewer: await getCheckedItemIds(viewer),
          };
          for (final (i, item) in items.indexed) {
            final copy = await into(checklistItems).insertReturning(
              ChecklistItemsCompanion.insert(
                checklistId: child.id,
                title: item.title,
                position: existing.length + i,
              ),
            );
            // Keep their progress on items they showed before the copy.
            for (final viewer in viewers) {
              if (checkedIds[viewer]!.contains(item.id)) {
                await setItemChecked(viewer, copy.id, true);
              }
            }
          }
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
      final descendants = await getDescendantIds(id);
      await (delete(checklists)..where((c) => c.id.equals(id))).go();
      // Lists below may have lost items inherited through this one.
      await _pruneChecks(descendants);
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
      // Dropping a parent also drops its items from every list below.
      await _pruneChecks([childId, ...await getDescendantIds(childId)]);
    });
  }

  /// Removes the checks of each list in [checklistIds] on items that list no
  /// longer shows, such as those of an ancestor it stopped inheriting from.
  Future<void> _pruneChecks(Iterable<int> checklistIds) async {
    for (final id in checklistIds) {
      final visible = {
        for (final section in await _loadSections(id))
          for (final item in section.items) item.id,
      };
      await (delete(
            checklistChecks,
          )..where((c) => c.checklistId.equals(id) & c.itemId.isNotIn(visible)))
          .go();
    }
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
  /// Every item is new, so any checks on the old ones are lost.
  Future<void> replaceChecklistItems(int checklistId, List<String> titles) {
    return saveChecklistItems(checklistId, [
      for (final title in titles) (id: null, title: title),
    ]);
  }

  /// Makes a checklist's items exactly [items], in the given order. Entries
  /// with an [id] update that existing item in place, so its checks survive;
  /// entries without one are inserted. Items not listed are deleted.
  Future<void> saveChecklistItems(
    int checklistId,
    List<({int? id, String title})> items,
  ) {
    return transaction(() async {
      final keep = [
        for (final item in items)
          if (item.id != null) item.id!,
      ];
      await (delete(checklistItems)..where(
            (ci) => ci.checklistId.equals(checklistId) & ci.id.isNotIn(keep),
          ))
          .go();
      for (final (i, item) in items.indexed) {
        if (item.id == null) {
          await into(checklistItems).insert(
            ChecklistItemsCompanion.insert(
              checklistId: checklistId,
              title: item.title,
              position: i,
            ),
          );
        } else {
          await (update(checklistItems)..where(
                (ci) =>
                    ci.id.equals(item.id!) & ci.checklistId.equals(checklistId),
              ))
              .write(
                ChecklistItemsCompanion(
                  title: Value(item.title),
                  position: Value(i),
                ),
              );
        }
      }
    });
  }

  /// The ids of the items checked off in [checklistId], once.
  Future<Set<int>> getCheckedItemIds(int checklistId) async {
    final rows = await (select(
      checklistChecks,
    )..where((c) => c.checklistId.equals(checklistId))).get();
    return {for (final row in rows) row.itemId};
  }

  /// Streams the ids of the items checked off in [checklistId], re-emitting on
  /// changes.
  Stream<Set<int>> watchCheckedItemIds(int checklistId) {
    return (select(checklistChecks)
          ..where((c) => c.checklistId.equals(checklistId)))
        .watch()
        .map((rows) => {for (final row in rows) row.itemId});
  }

  /// Checks or unchecks [itemId] in [checklistId].
  Future<void> setItemChecked(int checklistId, int itemId, bool checked) async {
    if (checked) {
      await into(checklistChecks).insertOnConflictUpdate(
        ChecklistChecksCompanion.insert(
          checklistId: checklistId,
          itemId: itemId,
        ),
      );
    } else {
      await (delete(checklistChecks)..where(
            (c) => c.checklistId.equals(checklistId) & c.itemId.equals(itemId),
          ))
          .go();
    }
  }

  /// Checks exactly [itemIds] in [checklistId], unchecking everything else.
  /// With an empty set this resets the list.
  Future<void> setCheckedItemIds(int checklistId, Set<int> itemIds) {
    return transaction(() async {
      await (delete(
        checklistChecks,
      )..where((c) => c.checklistId.equals(checklistId))).go();
      await batch((b) {
        b.insertAll(checklistChecks, [
          for (final id in itemIds)
            ChecklistChecksCompanion.insert(
              checklistId: checklistId,
              itemId: id,
            ),
        ]);
      });
    });
  }

  /// Serializes every checklist, item, inheritance link and check to a JSON
  /// string that [importBackup] can load back.
  Future<String> exportBackup() async {
    final data = {
      'format': _backupFormat,
      'version': _backupVersion,
      'checklists': [
        for (final r in await select(checklists).get()) r.toJson(),
      ],
      'items': [for (final r in await select(checklistItems).get()) r.toJson()],
      'parents': [
        for (final r in await select(checklistParents).get()) r.toJson(),
      ],
      'checks': [
        for (final r in await select(checklistChecks).get()) r.toJson(),
      ],
    };
    return jsonEncode(data);
  }

  /// Replaces all data with the contents of a backup made by [exportBackup].
  /// Ids are kept, so links and checks stay intact. Throws a
  /// [FormatException], leaving the data untouched, if [json] isn't a backup
  /// this version can read.
  Future<void> importBackup(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const FormatException('Not a checklist backup file');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _backupFormat) {
      throw const FormatException('Not a checklist backup file');
    }
    final Map<String, dynamic> data = decoded;
    final version = data['version'];
    if (version is! int || version > _backupVersion) {
      throw FormatException('Unsupported backup version: $version');
    }

    List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final row in data[key] as List)
        parse(row as Map<String, dynamic>),
    ];

    final lists = rows('checklists', Checklist.fromJson);
    final items = rows('items', ChecklistItem.fromJson);
    final parents = rows('parents', ChecklistParent.fromJson);
    final checks = rows('checks', ChecklistCheck.fromJson);

    await transaction(() async {
      // Cascades to items, links and checks.
      await delete(checklists).go();
      await batch((b) {
        b.insertAll(checklists, lists);
        b.insertAll(checklistItems, items);
        b.insertAll(checklistParents, parents);
        b.insertAll(checklistChecks, checks);
      });
    });
  }
}

const _backupFormat = 'checklist-backup';
const _backupVersion = 1;
