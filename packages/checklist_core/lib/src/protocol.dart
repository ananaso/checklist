/// The wire format between [RemoteChecklistStore] and the checklist server.
///
/// Calls are `POST <api>/rpc` with a JSON body `{"method": ..., "args": {...}}`,
/// answered with `{"result": ...}` or `{"error": {"type": ..., "message": ...}}`.
/// The server runs each call on its [AppDatabase] through [dispatchRpc], so a
/// client can only do what [ChecklistStore] offers, never run arbitrary SQL.
///
/// After every call that changes data, the server sends `{"type": "changed"}`
/// over the WebSocket at `<api>/events`, and clients fetch again what they
/// show.
library;

import 'checklist_store.dart';
import 'database.dart';

/// JSON-encodable values, as decoded by `jsonDecode`.
typedef Json = Object?;

/// The error types a failed call reports.
abstract final class RpcErrorType {
  /// The arguments were missing or of the wrong type.
  static const badRequest = 'badRequest';

  /// No method by that name.
  static const unknownMethod = 'unknownMethod';

  /// The store threw a [FormatException], e.g. importing a file that isn't a
  /// backup. The client rethrows it as one.
  static const format = 'format';

  /// Anything else went wrong on the server.
  static const internal = 'internal';
}

/// A call the server rejects before running it.
class RpcException implements Exception {
  const RpcException(this.type, this.message);

  final String type;
  final String message;

  @override
  String toString() => 'RpcException($type): $message';
}

/// The methods that change data. After one succeeds, everyone watching is
/// told to fetch again.
const mutatingMethods = {
  'createChecklist',
  'renameChecklist',
  'setChecklistFavorite',
  'setChecklistGroup',
  'deleteChecklist',
  'splitChecklist',
  'createGroup',
  'renameGroup',
  'setGroupCollapsed',
  'deleteGroup',
  'setChecklistParents',
  'saveChecklistItems',
  'setItemChecked',
  'setCheckedItemIds',
  'importBackup',
};

/// Runs [method] with [args] on [store] and returns its JSON-encodable
/// result. Throws [RpcException] for an unknown method or bad arguments.
///
/// The `watch*` methods of [ChecklistStore] are offered as one-off fetches
/// named after what they return (`checklists`, `groups`, `checklistSections`,
/// `checkedItemIds`); clients fetch them again on each change event.
Future<Json> dispatchRpc(
  ChecklistStore store,
  String method,
  Map<String, Json> args,
) async {
  final a = _Args(args);
  switch (method) {
    case 'ping':
      return null;

    // Checklists.
    case 'checklists':
      return encodeChecklists(await store.watchChecklists().first);
    case 'createChecklist':
      return (await store.createChecklist(a.title('title'))).toJson();
    case 'renameChecklist':
      return _done(store.renameChecklist(a.int_('id'), a.title('title')));
    case 'setChecklistFavorite':
      return _done(
        store.setChecklistFavorite(a.int_('id'), a.bool_('isFavorite')),
      );
    case 'setChecklistGroup':
      return _done(
        store.setChecklistGroup(a.int_('id'), a.intOrNull('groupId')),
      );
    case 'deleteChecklist':
      return _done(
        store.deleteChecklist(
          a.int_('id'),
          copyToChildren: a.bool_('copyToChildren'),
        ),
      );
    case 'splitChecklist':
      final direction = a.string('direction');
      final created = await store.splitChecklist(
        a.int_('id'),
        a.intList('itemIds').toSet(),
        title: a.title('title'),
        direction: SplitDirection.values.firstWhere(
          (d) => d.name == direction,
          orElse: () => throw RpcException(
            RpcErrorType.badRequest,
            'Unknown split direction: $direction',
          ),
        ),
      );
      return created.toJson();

    // Groups.
    case 'groups':
      return [for (final g in await store.watchGroups().first) g.toJson()];
    case 'createGroup':
      return (await store.createGroup(a.title('title'))).toJson();
    case 'renameGroup':
      return _done(store.renameGroup(a.int_('id'), a.title('title')));
    case 'setGroupCollapsed':
      return _done(
        store.setGroupCollapsed(a.int_('id'), a.bool_('isCollapsed')),
      );
    case 'deleteGroup':
      return _done(store.deleteGroup(a.int_('id')));

    // Inheritance.
    case 'getChecklistParentIds':
      return await store.getChecklistParentIds(a.int_('id'));
    case 'setChecklistParents':
      return _done(
        store.setChecklistParents(a.int_('childId'), a.intList('parentIds')),
      );
    case 'getChildren':
      return encodeChecklists(await store.getChildren(a.int_('id')));
    case 'getDescendantIds':
      return (await store.getDescendantIds(a.int_('id'))).toList()..sort();

    // Items.
    case 'checklistSections':
      final sections = await store.watchChecklistSections(a.int_('id')).first;
      return [for (final s in sections) encodeSection(s)];
    case 'getChecklistItems':
      return [
        for (final i in await store.getChecklistItems(a.int_('checklistId')))
          i.toJson(),
      ];
    case 'saveChecklistItems':
      return _done(
        store.saveChecklistItems(a.int_('checklistId'), a.itemEdits()),
      );

    // Checks.
    case 'checkedItemIds':
      return (await store.getCheckedItemIds(a.int_('checklistId'))).toList()
        ..sort();
    case 'setItemChecked':
      return _done(
        store.setItemChecked(
          a.int_('checklistId'),
          a.int_('itemId'),
          a.bool_('checked'),
        ),
      );
    case 'setCheckedItemIds':
      return _done(
        store.setCheckedItemIds(
          a.int_('checklistId'),
          a.intList('itemIds').toSet(),
        ),
      );

    // Backups.
    case 'exportBackup':
      return await store.exportBackup();
    case 'importBackup':
      return _done(store.importBackup(a.string('json')));
  }
  throw RpcException(RpcErrorType.unknownMethod, 'Unknown method: $method');
}

List<Json> encodeChecklists(List<Checklist> lists) => [
  for (final c in lists) c.toJson(),
];

List<Checklist> decodeChecklists(Json json) => [
  for (final c in json as List) Checklist.fromJson(c as Map<String, dynamic>),
];

Map<String, Json> encodeSection(ChecklistSection section) => {
  'source': section.source.toJson(),
  'items': [for (final i in section.items) i.toJson()],
  'groupTitle': section.groupTitle,
};

ChecklistSection decodeSection(Json json) {
  final map = json as Map<String, dynamic>;
  return ChecklistSection(
    Checklist.fromJson(map['source'] as Map<String, dynamic>),
    [
      for (final i in map['items'] as List)
        ChecklistItem.fromJson(i as Map<String, dynamic>),
    ],
    map['groupTitle'] as String?,
  );
}

/// Waits for a call that returns nothing.
Future<Json> _done(Future<void> call) async {
  await call;
  return null;
}

/// Reads typed arguments, rejecting anything of the wrong shape.
class _Args {
  _Args(this._args);

  final Map<String, Json> _args;

  Never _bad(String name, String expected) => throw RpcException(
    RpcErrorType.badRequest,
    'Argument "$name" must be $expected',
  );

  int int_(String name) => switch (_args[name]) {
    final int v => v,
    _ => _bad(name, 'an integer'),
  };

  int? intOrNull(String name) => switch (_args[name]) {
    null => null,
    final int v => v,
    _ => _bad(name, 'an integer or null'),
  };

  bool bool_(String name) => switch (_args[name]) {
    final bool v => v,
    _ => _bad(name, 'true or false'),
  };

  String string(String name) => switch (_args[name]) {
    final String v => v,
    _ => _bad(name, 'a string'),
  };

  /// A checklist, group or item title: non-empty and of a sane length.
  String title(String name) {
    final value = string(name);
    if (value.isEmpty || value.length > 1000) {
      _bad(name, 'between 1 and 1000 characters');
    }
    return value;
  }

  List<int> intList(String name) => switch (_args[name]) {
    final List<Object?> v when v.every((e) => e is int) => v.cast<int>(),
    _ => _bad(name, 'a list of integers'),
  };

  List<({int? id, String title})> itemEdits() {
    final value = _args['items'];
    if (value is! List) _bad('items', 'a list of {id, title}');
    return [
      for (final item in value)
        switch (item) {
          {'id': final int? id, 'title': final String title}
              when title.isNotEmpty && title.length <= 1000 =>
            (id: id, title: title),
          _ => _bad('items', 'a list of {id, title}'),
        },
    ];
  }
}
