import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'checklist_store.dart';
import 'database.dart';
import 'protocol.dart';

/// A call to the server failed, other than with a [FormatException].
class RemoteStoreException implements Exception {
  const RemoteStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A [ChecklistStore] that runs every call on the checklist server.
///
/// Streams fetch their data when listened to, and again whenever the server
/// reports a change (from this client or another one) over its events
/// WebSocket, so everyone sees the same lists live.
class RemoteChecklistStore implements ChecklistStore {
  /// Talks to the server's API at [apiBase], e.g. `https://host/api/`.
  ///
  /// [onUnauthorized] runs when the server (or the login proxy in front of
  /// it) rejects a call because the login expired; the web app reloads the
  /// page there, which leads to the login page. [client] and [connect] let
  /// tests send their own headers.
  RemoteChecklistStore(
    Uri apiBase, {
    http.Client? client,
    WebSocketChannel Function(Uri uri)? connect,
    void Function()? onUnauthorized,
  }) : _rpcUri = apiBase.resolve('rpc'),
       _eventsUri = _webSocketUri(apiBase.resolve('events')),
       _client = client ?? http.Client(),
       _connect = connect ?? WebSocketChannel.connect,
       _onUnauthorized = onUnauthorized;

  final Uri _rpcUri;
  final Uri _eventsUri;
  final http.Client _client;
  final WebSocketChannel Function(Uri uri) _connect;
  final void Function()? _onUnauthorized;

  /// Fires whenever data may have changed and streams should fetch again.
  final _changes = StreamController<void>.broadcast();

  var _closed = false;
  bool _eventsStarted = false;
  WebSocketChannel? _channel;

  /// Completes to cut a reconnect delay short.
  Completer<void> _wakeUp = Completer();

  static Uri _webSocketUri(Uri uri) =>
      uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws');

  /// Fetches everything being watched again, and reconnects the events
  /// socket right away if it's down. The app calls this when it comes back
  /// to the foreground, since phones drop sockets of backgrounded apps.
  void refresh() {
    if (_closed) return;
    _notify();
    if (!_wakeUp.isCompleted) _wakeUp.complete();
  }

  @override
  Future<void> close() async {
    _closed = true;
    if (!_wakeUp.isCompleted) _wakeUp.complete();
    await _channel?.sink.close();
    _client.close();
    await _changes.close();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  // Calls.

  Future<Json> _call(String method, [Map<String, Json> args = const {}]) async {
    final http.Response response;
    try {
      response = await _client.post(
        _rpcUri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Makes the login proxy answer 401 rather than redirect to its
          // login page, which a script can't follow.
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: jsonEncode({'method': method, 'args': args}),
      );
    } on http.ClientException catch (error) {
      throw RemoteStoreException('Can\'t reach the server: ${error.message}');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      _onUnauthorized?.call();
      throw const RemoteStoreException('Not logged in');
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // Most likely a login page served in place of the API.
      _onUnauthorized?.call();
      throw RemoteStoreException(
        'Unexpected response from the server (${response.statusCode})',
      );
    }
    if (response.statusCode == 200 &&
        body is Map &&
        body.containsKey('result')) {
      if (mutatingMethods.contains(method)) _notify();
      return body['result'];
    }
    final error = body is Map ? body['error'] : null;
    final type = error is Map ? error['type'] : null;
    final message = error is Map ? '${error['message']}' : 'Server error';
    if (type == RpcErrorType.format) throw FormatException(message);
    throw RemoteStoreException(message);
  }

  // Live updates.

  /// A stream of [method]'s result, fetched on listen and after every change.
  /// Results equal to the previous one aren't emitted again.
  Stream<T> _watch<T>(
    String method,
    Map<String, Json> args,
    T Function(Json result) decode,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<void>? changes;
    String? last;
    var loading = false;
    var stale = false;
    var emitted = false;

    Future<void> load() async {
      // Changes during a fetch trigger one more fetch once it's done, so the
      // stream ends on the latest data without fetches piling up.
      if (loading) {
        stale = true;
        return;
      }
      loading = true;
      try {
        do {
          stale = false;
          final result = await _call(method, args);
          final encoded = jsonEncode(result);
          if (controller.isClosed || encoded == last) continue;
          last = encoded;
          emitted = true;
          controller.add(decode(result));
        } while (stale && !controller.isClosed);
      } catch (error, stackTrace) {
        // Before the first value there's nothing to show, so report it (this
        // also fails `.first`). After that, keep showing the last data; the
        // next change or reconnect fetches again.
        if (!emitted && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        loading = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        _startEvents();
        changes = _changes.stream.listen((_) => load());
        load();
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  /// Keeps a connection to the server's change events open until [close],
  /// reconnecting with growing delays when it drops.
  void _startEvents() {
    if (_eventsStarted || _closed) return;
    _eventsStarted = true;
    unawaited(_runEvents());
  }

  Future<void> _runEvents() async {
    const minDelay = Duration(seconds: 1);
    const maxDelay = Duration(seconds: 30);
    var delay = minDelay;
    while (!_closed) {
      try {
        final channel = _channel = _connect(_eventsUri);
        await channel.ready;
        delay = minDelay;
        // Catch up on anything that changed while disconnected.
        _notify();
        await for (final message in channel.stream) {
          if (message is String && message.contains('"changed"')) {
            _notify();
          }
        }
      } catch (_) {
        // Reconnect below.
      }
      _channel = null;
      if (_closed) break;
      // The socket may have been refused because the login expired; a call
      // finds out, and reports it to [_onUnauthorized].
      try {
        await _call('ping');
      } catch (_) {}
      _wakeUp = Completer();
      await Future.any([Future<void>.delayed(delay), _wakeUp.future]);
      delay = Duration(
        milliseconds: min(delay.inMilliseconds * 2, maxDelay.inMilliseconds),
      );
    }
  }

  // ChecklistStore.

  @override
  Stream<List<Checklist>> watchChecklists() =>
      _watch('checklists', const {}, decodeChecklists);

  @override
  Future<Checklist> createChecklist(String title) async => Checklist.fromJson(
    await _call('createChecklist', {'title': title}) as Map<String, dynamic>,
  );

  @override
  Future<void> renameChecklist(int id, String title) =>
      _call('renameChecklist', {'id': id, 'title': title});

  @override
  Future<void> setChecklistFavorite(int id, bool isFavorite) =>
      _call('setChecklistFavorite', {'id': id, 'isFavorite': isFavorite});

  @override
  Future<void> setChecklistGroup(int id, int? groupId) =>
      _call('setChecklistGroup', {'id': id, 'groupId': groupId});

  @override
  Future<void> deleteChecklist(int id, {bool copyToChildren = false}) =>
      _call('deleteChecklist', {'id': id, 'copyToChildren': copyToChildren});

  @override
  Future<Checklist> splitChecklist(
    int id,
    Set<int> itemIds, {
    required String title,
    required SplitDirection direction,
  }) async => Checklist.fromJson(
    await _call('splitChecklist', {
          'id': id,
          'itemIds': itemIds.toList(),
          'title': title,
          'direction': direction.name,
        })
        as Map<String, dynamic>,
  );

  @override
  Stream<List<ChecklistGroup>> watchGroups() => _watch(
    'groups',
    const {},
    (json) => [
      for (final g in json as List)
        ChecklistGroup.fromJson(g as Map<String, dynamic>),
    ],
  );

  @override
  Future<ChecklistGroup> createGroup(String title) async =>
      ChecklistGroup.fromJson(
        await _call('createGroup', {'title': title}) as Map<String, dynamic>,
      );

  @override
  Future<void> renameGroup(int id, String title) =>
      _call('renameGroup', {'id': id, 'title': title});

  @override
  Future<void> setGroupCollapsed(int id, bool isCollapsed) =>
      _call('setGroupCollapsed', {'id': id, 'isCollapsed': isCollapsed});

  @override
  Future<void> deleteGroup(int id) => _call('deleteGroup', {'id': id});

  @override
  Future<List<int>> getChecklistParentIds(int id) async =>
      (await _call('getChecklistParentIds', {'id': id}) as List).cast<int>();

  @override
  Future<void> setChecklistParents(int childId, List<int> parentIds) => _call(
    'setChecklistParents',
    {'childId': childId, 'parentIds': parentIds},
  );

  @override
  Future<List<Checklist>> getChildren(int id) async =>
      decodeChecklists(await _call('getChildren', {'id': id}));

  @override
  Future<Set<int>> getDescendantIds(int id) async =>
      (await _call('getDescendantIds', {'id': id}) as List).cast<int>().toSet();

  @override
  Stream<List<ChecklistSection>> watchChecklistSections(int id) => _watch(
    'checklistSections',
    {'id': id},
    (json) => [for (final s in json as List) decodeSection(s)],
  );

  @override
  Future<List<ChecklistItem>> getChecklistItems(int checklistId) async => [
    for (final i
        in await _call('getChecklistItems', {'checklistId': checklistId})
            as List)
      ChecklistItem.fromJson(i as Map<String, dynamic>),
  ];

  @override
  Future<void> saveChecklistItems(
    int checklistId,
    List<({int? id, String title})> items,
  ) => _call('saveChecklistItems', {
    'checklistId': checklistId,
    'items': [
      for (final item in items) {'id': item.id, 'title': item.title},
    ],
  });

  @override
  Future<Set<int>> getCheckedItemIds(int checklistId) async =>
      (await _call('checkedItemIds', {'checklistId': checklistId}) as List)
          .cast<int>()
          .toSet();

  @override
  Stream<Set<int>> watchCheckedItemIds(int checklistId) => _watch(
    'checkedItemIds',
    {'checklistId': checklistId},
    (json) => (json as List).cast<int>().toSet(),
  );

  @override
  Future<void> setItemChecked(int checklistId, int itemId, bool checked) =>
      _call('setItemChecked', {
        'checklistId': checklistId,
        'itemId': itemId,
        'checked': checked,
      });

  @override
  Future<void> setCheckedItemIds(int checklistId, Set<int> itemIds) => _call(
    'setCheckedItemIds',
    {'checklistId': checklistId, 'itemIds': itemIds.toList()},
  );

  @override
  Future<String> exportBackup() async => await _call('exportBackup') as String;

  @override
  Future<void> importBackup(String json) =>
      _call('importBackup', {'json': json});
}
