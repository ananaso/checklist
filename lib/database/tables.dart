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
}

class ChecklistItems extends Table with AutoIncrementingPrimaryKey, CreatedAt {
  IntColumn get checklistId =>
      integer().references(Checklists, #id, onDelete: KeyAction.cascade)();

  TextColumn get title => text()();

  IntColumn get position => integer()();
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
