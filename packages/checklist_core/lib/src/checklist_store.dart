import 'database.dart';

/// Everything the app reads and changes about checklists.
///
/// [AppDatabase] implements it on a local SQLite database (the Android app,
/// and the server). [RemoteChecklistStore] implements it by calling the
/// server, which runs those same methods on its database (the web app).
abstract interface class ChecklistStore {
  // Checklists.

  /// Streams all checklists, favorites first, each group sorted alphabetically
  /// by title (ignoring case), re-emitting on changes.
  Stream<List<Checklist>> watchChecklists();

  /// Creates an empty checklist titled [title].
  Future<Checklist> createChecklist(String title);

  Future<void> renameChecklist(int id, String title);

  Future<void> setChecklistFavorite(int id, bool isFavorite);

  /// Files a checklist under [groupId], or under no group if null.
  Future<void> setChecklistGroup(int id, int? groupId);

  /// Deletes a checklist; see [AppDatabase.deleteChecklist].
  Future<void> deleteChecklist(int id, {bool copyToChildren = false});

  /// Moves [itemIds] out of [id] into a new list; see
  /// [AppDatabase.splitChecklist].
  Future<Checklist> splitChecklist(
    int id,
    Set<int> itemIds, {
    required String title,
    required SplitDirection direction,
  });

  // Groups.

  /// Streams all groups sorted alphabetically by title (ignoring case),
  /// re-emitting on changes.
  Stream<List<ChecklistGroup>> watchGroups();

  Future<ChecklistGroup> createGroup(String title);

  Future<void> renameGroup(int id, String title);

  Future<void> setGroupCollapsed(int id, bool isCollapsed);

  /// Deletes a group; its checklists become ungrouped.
  Future<void> deleteGroup(int id);

  // Inheritance.

  /// The ids of the lists [id] inherits from directly, in order.
  Future<List<int>> getChecklistParentIds(int id);

  /// Makes [childId] inherit from exactly [parentIds], in the given order.
  Future<void> setChecklistParents(int childId, List<int> parentIds);

  /// The lists that inherit directly from [id], sorted by title.
  Future<List<Checklist>> getChildren(int id);

  /// Every list that inherits from [id], directly or through other lists.
  Future<Set<int>> getDescendantIds(int id);

  // Items.

  /// Streams the items [id] shows, grouped by the list they come from;
  /// see [AppDatabase.watchChecklistSections].
  Stream<List<ChecklistSection>> watchChecklistSections(int id);

  /// Fetches a checklist's own items once, in list order.
  Future<List<ChecklistItem>> getChecklistItems(int checklistId);

  /// Makes a checklist's items exactly [items], in the given order; see
  /// [AppDatabase.saveChecklistItems].
  Future<void> saveChecklistItems(
    int checklistId,
    List<({int? id, String title})> items,
  );

  // Checks.

  /// The ids of the items checked off in [checklistId], once.
  Future<Set<int>> getCheckedItemIds(int checklistId);

  /// Streams the ids of the items checked off in [checklistId], re-emitting
  /// on changes.
  Stream<Set<int>> watchCheckedItemIds(int checklistId);

  /// Checks or unchecks [itemId] in [checklistId].
  Future<void> setItemChecked(int checklistId, int itemId, bool checked);

  /// Checks exactly [itemIds] in [checklistId], unchecking everything else.
  Future<void> setCheckedItemIds(int checklistId, Set<int> itemIds);

  // Backups.

  /// Serializes everything to a JSON string that [importBackup] can load.
  Future<String> exportBackup();

  /// Replaces all data with a backup made by [exportBackup]. Throws a
  /// [FormatException], leaving the data untouched, if [json] isn't a backup
  /// this version can read.
  Future<void> importBackup(String json);

  /// Releases the store's resources.
  Future<void> close();
}
