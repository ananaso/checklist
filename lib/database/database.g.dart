// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ChecklistsTable extends Checklists
    with TableInfo<$ChecklistsTable, Checklist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, createdAt, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Checklist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Checklist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Checklist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
    );
  }

  @override
  $ChecklistsTable createAlias(String alias) {
    return $ChecklistsTable(attachedDatabase, alias);
  }
}

class Checklist extends DataClass implements Insertable<Checklist> {
  final int id;
  final DateTime createdAt;
  final String title;
  const Checklist({
    required this.id,
    required this.createdAt,
    required this.title,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['title'] = Variable<String>(title);
    return map;
  }

  ChecklistsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      title: Value(title),
    );
  }

  factory Checklist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Checklist(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      title: serializer.fromJson<String>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'title': serializer.toJson<String>(title),
    };
  }

  Checklist copyWith({int? id, DateTime? createdAt, String? title}) =>
      Checklist(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        title: title ?? this.title,
      );
  Checklist copyWithCompanion(ChecklistsCompanion data) {
    return Checklist(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Checklist(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Checklist &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.title == this.title);
}

class ChecklistsCompanion extends UpdateCompanion<Checklist> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> title;
  const ChecklistsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.title = const Value.absent(),
  });
  ChecklistsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String title,
  }) : title = Value(title);
  static Insertable<Checklist> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? title,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (title != null) 'title': title,
    });
  }

  ChecklistsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? title,
  }) {
    return ChecklistsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }
}

class $ChecklistItemsTable extends ChecklistItems
    with TableInfo<$ChecklistItemsTable, ChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _checklistIdMeta = const VerificationMeta(
    'checklistId',
  );
  @override
  late final GeneratedColumn<int> checklistId = GeneratedColumn<int>(
    'checklist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES checklists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    checklistId,
    title,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChecklistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('checklist_id')) {
      context.handle(
        _checklistIdMeta,
        checklistId.isAcceptableOrUnknown(
          data['checklist_id']!,
          _checklistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checklistIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChecklistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      checklistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checklist_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ChecklistItemsTable createAlias(String alias) {
    return $ChecklistItemsTable(attachedDatabase, alias);
  }
}

class ChecklistItem extends DataClass implements Insertable<ChecklistItem> {
  final int id;
  final DateTime createdAt;
  final int checklistId;
  final String title;
  final int position;
  const ChecklistItem({
    required this.id,
    required this.createdAt,
    required this.checklistId,
    required this.title,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['checklist_id'] = Variable<int>(checklistId);
    map['title'] = Variable<String>(title);
    map['position'] = Variable<int>(position);
    return map;
  }

  ChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistItemsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      checklistId: Value(checklistId),
      title: Value(title),
      position: Value(position),
    );
  }

  factory ChecklistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChecklistItem(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      checklistId: serializer.fromJson<int>(json['checklistId']),
      title: serializer.fromJson<String>(json['title']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'checklistId': serializer.toJson<int>(checklistId),
      'title': serializer.toJson<String>(title),
      'position': serializer.toJson<int>(position),
    };
  }

  ChecklistItem copyWith({
    int? id,
    DateTime? createdAt,
    int? checklistId,
    String? title,
    int? position,
  }) => ChecklistItem(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    checklistId: checklistId ?? this.checklistId,
    title: title ?? this.title,
    position: position ?? this.position,
  );
  ChecklistItem copyWithCompanion(ChecklistItemsCompanion data) {
    return ChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      checklistId: data.checklistId.present
          ? data.checklistId.value
          : this.checklistId,
      title: data.title.present ? data.title.value : this.title,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItem(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('checklistId: $checklistId, ')
          ..write('title: $title, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, checklistId, title, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChecklistItem &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.checklistId == this.checklistId &&
          other.title == this.title &&
          other.position == this.position);
}

class ChecklistItemsCompanion extends UpdateCompanion<ChecklistItem> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<int> checklistId;
  final Value<String> title;
  final Value<int> position;
  const ChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.checklistId = const Value.absent(),
    this.title = const Value.absent(),
    this.position = const Value.absent(),
  });
  ChecklistItemsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required int checklistId,
    required String title,
    required int position,
  }) : checklistId = Value(checklistId),
       title = Value(title),
       position = Value(position);
  static Insertable<ChecklistItem> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<int>? checklistId,
    Expression<String>? title,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (checklistId != null) 'checklist_id': checklistId,
      if (title != null) 'title': title,
      if (position != null) 'position': position,
    });
  }

  ChecklistItemsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<int>? checklistId,
    Value<String>? title,
    Value<int>? position,
  }) {
    return ChecklistItemsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      checklistId: checklistId ?? this.checklistId,
      title: title ?? this.title,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (checklistId.present) {
      map['checklist_id'] = Variable<int>(checklistId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('checklistId: $checklistId, ')
          ..write('title: $title, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChecklistsTable checklists = $ChecklistsTable(this);
  late final $ChecklistItemsTable checklistItems = $ChecklistItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    checklists,
    checklistItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'checklists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('checklist_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ChecklistsTableCreateCompanionBuilder =
    ChecklistsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required String title,
    });
typedef $$ChecklistsTableUpdateCompanionBuilder =
    ChecklistsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> title,
    });

final class $$ChecklistsTableReferences
    extends BaseReferences<_$AppDatabase, $ChecklistsTable, Checklist> {
  $$ChecklistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChecklistItemsTable, List<ChecklistItem>>
  _checklistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.checklistItems,
    aliasName: 'checklists__id__checklist_items__checklist_id',
  );

  $$ChecklistItemsTableProcessedTableManager get checklistItemsRefs {
    final manager = $$ChecklistItemsTableTableManager(
      $_db,
      $_db.checklistItems,
    ).filter((f) => f.checklistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_checklistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChecklistsTableFilterComposer
    extends Composer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> checklistItemsRefs(
    Expression<bool> Function($$ChecklistItemsTableFilterComposer f) f,
  ) {
    final $$ChecklistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.checklistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableFilterComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChecklistsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChecklistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  Expression<T> checklistItemsRefs<T extends Object>(
    Expression<T> Function($$ChecklistItemsTableAnnotationComposer a) f,
  ) {
    final $$ChecklistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.checklistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChecklistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChecklistsTable,
          Checklist,
          $$ChecklistsTableFilterComposer,
          $$ChecklistsTableOrderingComposer,
          $$ChecklistsTableAnnotationComposer,
          $$ChecklistsTableCreateCompanionBuilder,
          $$ChecklistsTableUpdateCompanionBuilder,
          (Checklist, $$ChecklistsTableReferences),
          Checklist,
          PrefetchHooks Function({bool checklistItemsRefs})
        > {
  $$ChecklistsTableTableManager(_$AppDatabase db, $ChecklistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChecklistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChecklistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChecklistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> title = const Value.absent(),
              }) => ChecklistsCompanion(
                id: id,
                createdAt: createdAt,
                title: title,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required String title,
              }) => ChecklistsCompanion.insert(
                id: id,
                createdAt: createdAt,
                title: title,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChecklistsTable, Checklist>(table),
                  $$ChecklistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({checklistItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (checklistItemsRefs) db.checklistItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (checklistItemsRefs)
                    await $_getPrefetchedData<
                      Checklist,
                      $ChecklistsTable,
                      ChecklistItem
                    >(
                      currentTable: table,
                      referencedTable: $$ChecklistsTableReferences
                          ._checklistItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ChecklistsTableReferences(
                            db,
                            table,
                            p0,
                          ).checklistItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.checklistId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ChecklistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChecklistsTable,
      Checklist,
      $$ChecklistsTableFilterComposer,
      $$ChecklistsTableOrderingComposer,
      $$ChecklistsTableAnnotationComposer,
      $$ChecklistsTableCreateCompanionBuilder,
      $$ChecklistsTableUpdateCompanionBuilder,
      (Checklist, $$ChecklistsTableReferences),
      Checklist,
      PrefetchHooks Function({bool checklistItemsRefs})
    >;
typedef $$ChecklistItemsTableCreateCompanionBuilder =
    ChecklistItemsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required int checklistId,
      required String title,
      required int position,
    });
typedef $$ChecklistItemsTableUpdateCompanionBuilder =
    ChecklistItemsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<int> checklistId,
      Value<String> title,
      Value<int> position,
    });

final class $$ChecklistItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ChecklistItemsTable, ChecklistItem> {
  $$ChecklistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChecklistsTable _checklistIdTable(_$AppDatabase db) => db.checklists
      .createAlias('checklist_items__checklist_id__checklists__id');

  $$ChecklistsTableProcessedTableManager get checklistId {
    final $_column = $_itemColumn<int>('checklist_id')!;

    final manager = $$ChecklistsTableTableManager(
      $_db,
      $_db.checklists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_checklistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$ChecklistsTableFilterComposer get checklistId {
    final $$ChecklistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checklistId,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableFilterComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChecklistsTableOrderingComposer get checklistId {
    final $$ChecklistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checklistId,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableOrderingComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$ChecklistsTableAnnotationComposer get checklistId {
    final $$ChecklistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checklistId,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableAnnotationComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChecklistItemsTable,
          ChecklistItem,
          $$ChecklistItemsTableFilterComposer,
          $$ChecklistItemsTableOrderingComposer,
          $$ChecklistItemsTableAnnotationComposer,
          $$ChecklistItemsTableCreateCompanionBuilder,
          $$ChecklistItemsTableUpdateCompanionBuilder,
          (ChecklistItem, $$ChecklistItemsTableReferences),
          ChecklistItem,
          PrefetchHooks Function({bool checklistId})
        > {
  $$ChecklistItemsTableTableManager(
    _$AppDatabase db,
    $ChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChecklistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChecklistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> checklistId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => ChecklistItemsCompanion(
                id: id,
                createdAt: createdAt,
                checklistId: checklistId,
                title: title,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required int checklistId,
                required String title,
                required int position,
              }) => ChecklistItemsCompanion.insert(
                id: id,
                createdAt: createdAt,
                checklistId: checklistId,
                title: title,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChecklistItemsTable, ChecklistItem>(table),
                  $$ChecklistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({checklistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (checklistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.checklistId,
                                referencedTable: $$ChecklistItemsTableReferences
                                    ._checklistIdTable(db),
                                referencedColumn:
                                    $$ChecklistItemsTableReferences
                                        ._checklistIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChecklistItemsTable,
      ChecklistItem,
      $$ChecklistItemsTableFilterComposer,
      $$ChecklistItemsTableOrderingComposer,
      $$ChecklistItemsTableAnnotationComposer,
      $$ChecklistItemsTableCreateCompanionBuilder,
      $$ChecklistItemsTableUpdateCompanionBuilder,
      (ChecklistItem, $$ChecklistItemsTableReferences),
      ChecklistItem,
      PrefetchHooks Function({bool checklistId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChecklistsTableTableManager get checklists =>
      $$ChecklistsTableTableManager(_db, _db.checklists);
  $$ChecklistItemsTableTableManager get checklistItems =>
      $$ChecklistItemsTableTableManager(_db, _db.checklistItems);
}
