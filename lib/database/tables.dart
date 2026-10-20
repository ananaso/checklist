import 'package:drift/drift.dart';

mixin AutoIncrementingPrimaryKey on Table {
  // Primary key column
  late final id = integer().autoIncrement()();
}

mixin CreatedAt on Table {
  // Column for created at timestamp
  late final createdAt = dateTime().withDefault(currentDateAndTime)();
}

class Checklists extends Table with AutoIncrementingPrimaryKey, CreatedAt {
  TextColumn get title => text()();

  /// Favorites are listed before all other checklists.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

class ChecklistItems extends Table with AutoIncrementingPrimaryKey, CreatedAt {
  IntColumn get checklistId =>
      integer().references(Checklists, #id, onDelete: KeyAction.cascade)();

  TextColumn get title => text()();

  IntColumn get position => integer()();
}

/// An item checked off while working through [checklistId]. Keyed by the
/// viewing list, since an inherited item is checked independently in each
/// child.
class ChecklistChecks extends Table {
  IntColumn get checklistId =>
      integer().references(Checklists, #id, onDelete: KeyAction.cascade)();

  IntColumn get itemId =>
      integer().references(ChecklistItems, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get checkedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {checklistId, itemId};
}

/// Links a checklist to a list it inherits items from. [position] orders the
/// parents of one child.
class ChecklistParents extends Table {
  @ReferenceName('parentLinks')
  IntColumn get childId =>
      integer().references(Checklists, #id, onDelete: KeyAction.cascade)();

  @ReferenceName('childLinks')
  IntColumn get parentId =>
      integer().references(Checklists, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {childId, parentId};
}
