import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:checklist_core/checklist_core.dart';
import 'package:checklist_server/checklist_server.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// Adds the header the login proxy would, as user [user] (none if null).
class _ProxyClient extends http.BaseClient {
  _ProxyClient(this.user);

  final String? user;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (user != null) request.headers['Remote-User'] = user!;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Waits for [stream] to emit a value matching [matcher].
Future<T> until<T>(Stream<T> stream, bool Function(T) matcher) =>
    stream.firstWhere(matcher).timeout(const Duration(seconds: 5));

void main() {
  late AppDatabase db;
  late ChecklistServer server;
  late HttpServer http_;
  late Uri api;
  final stores = <RemoteChecklistStore>[];

  RemoteChecklistStore connect(
    String? user, {
    void Function()? onUnauthorized,
  }) {
    final store = RemoteChecklistStore(
      api,
      client: _ProxyClient(user),
      connect: (uri) =>
          IOWebSocketChannel.connect(uri, headers: {'Remote-User': ?user}),
      onUnauthorized: onUnauthorized,
    );
    stores.add(store);
    return store;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = ChecklistServer(db);
    http_ = await shelf_io.serve(server.handler, 'localhost', 0);
    api = Uri.parse('http://localhost:${http_.port}/api/');
  });

  tearDown(() async {
    for (final store in stores) {
      await store.close();
    }
    stores.clear();
    await server.close();
    await http_.close(force: true);
    await db.close();
  });

  test(
    'a checklist created by one person shows up live for the other',
    () async {
      final you = connect('you');
      final partner = connect('partner');

      final lists = partner.watchChecklists().asBroadcastStream();
      expect(await lists.first, isEmpty);

      await you.createChecklist('Groceries');
      final seen = await until(lists, (l) => l.isNotEmpty);
      expect(seen.map((c) => c.title), ['Groceries']);
    },
  );

  test('checks sync between people', () async {
    final you = connect('you');
    final partner = connect('partner');
    final list = await you.createChecklist('Groceries');
    await you.saveChecklistItems(list.id, [
      (id: null, title: 'Milk'),
      (id: null, title: 'Eggs'),
    ]);
    final items = await you.getChecklistItems(list.id);

    final checked = partner.watchCheckedItemIds(list.id).asBroadcastStream();
    expect(await checked.first, isEmpty);

    await you.setItemChecked(list.id, items.first.id, true);
    expect(await until(checked, (c) => c.isNotEmpty), {items.first.id});

    await you.setCheckedItemIds(list.id, {});
    expect(await until(checked, (c) => c.isEmpty), isEmpty);
  });

  test('inheritance, groups and splitting work through the server', () async {
    final store = connect('you');
    final cycling = await store.createChecklist('Cycling');
    await store.saveChecklistItems(cycling.id, [
      (id: null, title: 'Bib shorts'),
    ]);
    final outdoor = await store.createChecklist('Outdoor cycling');
    await store.saveChecklistItems(outdoor.id, [
      (id: null, title: 'Helmet'),
      (id: null, title: 'Lights'),
    ]);
    await store.setChecklistParents(outdoor.id, [cycling.id]);
    final group = await store.createGroup('Sport');
    await store.setChecklistGroup(cycling.id, group.id);

    final sections = await store.watchChecklistSections(outdoor.id).first;
    expect(
      [for (final s in sections) s.label],
      ['Cycling (Sport)', 'Outdoor cycling'],
    );
    expect(sections.last.items.map((i) => i.title), ['Helmet', 'Lights']);
    expect(await store.getChecklistParentIds(outdoor.id), [cycling.id]);
    expect(await store.getDescendantIds(cycling.id), {outdoor.id});
    expect((await store.getChildren(cycling.id)).single.id, outdoor.id);

    final lights = sections.last.items.last;
    final night = await store.splitChecklist(
      outdoor.id,
      {lights.id},
      title: 'Night riding',
      direction: SplitDirection.parent,
    );
    final after = await store.watchChecklistSections(outdoor.id).first;
    expect(
      [for (final s in after) s.source.title],
      ['Cycling', 'Night riding', 'Outdoor cycling'],
    );
    expect(night.title, 'Night riding');
  });

  test('backups round-trip, and bad files are a FormatException', () async {
    final store = connect('you');
    await store.createChecklist('Packing');
    final backup = await store.exportBackup();

    await expectLater(
      store.importBackup('not a backup'),
      throwsA(isA<FormatException>()),
    );
    await store.createChecklist('Extra');
    await store.importBackup(backup);
    final lists = await store.watchChecklists().first;
    expect(lists.map((c) => c.title), ['Packing']);
  });

  test('text survives the round trip unchanged', () async {
    final store = connect('you');
    const title = 'Épicerie 🛒 — ½ kg';
    await store.createChecklist(title);
    expect((await store.watchChecklists().first).single.title, title);
  });

  test('requests without the login proxy\'s header are refused', () async {
    var unauthorized = 0;
    final store = connect(null, onUnauthorized: () => unauthorized++);
    await expectLater(
      store.createChecklist('Sneaky'),
      throwsA(isA<RemoteStoreException>()),
    );
    expect(unauthorized, 1);
    expect(await db.watchChecklists().first, isEmpty);
  });

  test('requests from another site are refused', () async {
    final response = await http.post(
      api.resolve('rpc'),
      headers: {
        'Remote-User': 'you',
        'Content-Type': 'application/json',
        'Origin': 'https://evil.example',
      },
      body: jsonEncode({
        'method': 'createChecklist',
        'args': {'title': 'Sneaky'},
      }),
    );
    expect(response.statusCode, 403);
    expect(await db.watchChecklists().first, isEmpty);
  });

  test('malformed calls are rejected without touching data', () async {
    Future<http.Response> call(Object body) => http.post(
      api.resolve('rpc'),
      headers: {'Remote-User': 'you', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    expect(
      (await call({
        'method': 'createChecklist',
        'args': {'title': 42},
      })).statusCode,
      400,
    );
    expect(
      (await call({
        'method': 'createChecklist',
        'args': {'title': ''},
      })).statusCode,
      400,
    );
    expect(
      (await call({'method': 'dropAllTables', 'args': {}})).statusCode,
      404,
    );
    expect((await call(['nonsense'])).statusCode, 400);
    expect(await db.watchChecklists().first, isEmpty);
  });

  for (final viaRefresh in [false, true]) {
    test(
      'a client catches up after its connection drops'
      '${viaRefresh ? ' (app resumed)' : ' (automatic reconnect)'}',
      () async {
        final you = connect('you');
        final partner = connect('partner');
        final lists = partner.watchChecklists().asBroadcastStream();
        await lists.first;
        await until(
          Stream.periodic(
            const Duration(milliseconds: 20),
            (_) => server.clientCount,
          ),
          (n) => n == 1,
        );

        // The server drops everyone, then a change happens while they're away.
        await server.close();
        await you.createChecklist('While you were out');

        // Reconnecting fetches again: on its own after a delay, or right away
        // when the app comes back to the foreground.
        if (viaRefresh) partner.refresh();
        final seen = await until(lists, (l) => l.isNotEmpty);
        expect(seen.single.title, 'While you were out');
      },
    );
  }
}
