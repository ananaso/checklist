import 'package:drift/drift.dart';

mixin AutoIncrementingPrimaryKey on Table {
  // Primary key column
  late final id = integer().autoIncrement()();
}

mixin CreatedAt on Table {
  // Column for created at timestamp
  late final createdAt = dateTime().withDefault(currentDateAndTime)();
}

class ChecklistItems extends Table with AutoIncrementingPrimaryKey, CreatedAt {
  TextColumn get title => text()();

  IntColumn get position => integer()();
}
