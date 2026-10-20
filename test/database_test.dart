import 'package:checklist/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders sections as "List: item, item" strings, in order.
List<String> shape(List<ChecklistSection> sections) => [
  for (final s in sections)
    '${s.source.title}: ${s.items.map((i) => i.title).join(', ')}',
];

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Checklist> list(String title, [List<String> items = const []]) async {
    final checklist = await db.createChecklist(title);
    await db.replaceChecklistItems(checklist.id, items);
    return checklist;
  }

  Future<List<String>> view(Checklist checklist) async =>
      shape(await db.watchChecklistSections(checklist.id).first);

  test('a child shows its parent\'s items, then its own', () async {
    final cycling = await list('Cycling', ['Bib shorts', 'Water bottles']);
    final outdoor = await list('Outdoor cycling', ['Helmet']);
    await db.setChecklistParents(outdoor.id, [cycling.id]);

    expect(await view(outdoor), [
      'Cycling: Bib shorts, Water bottles',
      'Outdoor cycling: Helmet',
    ]);
  });

  test('edits to the base list show up in the child stream', () async {
    final cycling = await list('Cycling', ['Bib shorts']);
    final indoor = await list('Indoor cycling', ['Sweatband']);
    await db.setChecklistParents(indoor.id, [cycling.id]);

    final emissions = <List<String>>[];
    final sub = db
        .watchChecklistSections(indoor.id)
        .listen((sections) => emissions.add(shape(sections)));
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await db.replaceChecklistItems(cycling.id, ['Bib shorts', 'Water bottles']);
    await pumpEventQueue();

    expect(emissions.last, [
      'Cycling: Bib shorts, Water bottles',
      'Indoor cycling: Sweatband',
    ]);
  });

  test('parents keep their order', () async {
    final a = await list('A', ['a']);
    final b = await list('B', ['b']);
    final child = await list('Child', ['c']);

    await db.setChecklistParents(child.id, [b.id, a.id]);
    expect(await view(child), ['B: b', 'A: a', 'Child: c']);
    expect(await db.getChecklistParentIds(child.id), [b.id, a.id]);
  });

  test('grandparents come first and a shared one appears once', () async {
    final base = await list('Base', ['x']);
    final left = await list('Left', ['l']);
    final right = await list('Right', ['r']);
    final child = await list('Child', ['c']);
    await db.setChecklistParents(left.id, [base.id]);
    await db.setChecklistParents(right.id, [base.id]);
    await db.setChecklistParents(child.id, [left.id, right.id]);

    expect(await view(child), ['Base: x', 'Left: l', 'Right: r', 'Child: c']);
  });

  test('getDescendantIds finds children at every depth', () async {
    final a = await list('A');
    final b = await list('B');
    final c = await list('C');
    final other = await list('Other');
    await db.setChecklistParents(b.id, [a.id]);
    await db.setChecklistParents(c.id, [b.id]);

    expect(await db.getDescendantIds(a.id), {b.id, c.id});
    expect(await db.getDescendantIds(other.id), isEmpty);
    expect((await db.getChildren(a.id)).map((c) => c.title), ['B']);
  });

  test('deleting a base list unlinks its children by default', () async {
    final base = await list('Base', ['x']);
    final child = await list('Child', ['c']);
    await db.setChecklistParents(child.id, [base.id]);

    await db.deleteChecklist(base.id);

    expect(await view(child), ['Child: c']);
    expect(await db.getChecklistParentIds(child.id), isEmpty);
  });

  test(
    'deleting with copyToChildren keeps the items and the grandparents',
    () async {
      final root = await list('Root', ['r']);
      final base = await list('Base', ['x', 'y']);
      final child = await list('Child', ['c']);
      await db.setChecklistParents(base.id, [root.id]);
      await db.setChecklistParents(child.id, [base.id]);

      await db.deleteChecklist(base.id, copyToChildren: true);

      expect(await view(child), ['Root: r', 'Child: c, x, y']);
      expect(await db.getChecklistParentIds(child.id), [root.id]);
    },
  );

  group('checks', () {
    Future<List<ChecklistItem>> items(Checklist checklist) =>
        db.getChecklistItems(checklist.id);

    test('are kept per viewing list, even for inherited items', () async {
      final base = await list('Base', ['x']);
      final a = await list('A');
      final b = await list('B');
      await db.setChecklistParents(a.id, [base.id]);
      await db.setChecklistParents(b.id, [base.id]);
      final x = (await items(base)).single;

      await db.setItemChecked(a.id, x.id, true);

      expect(await db.getCheckedItemIds(a.id), {x.id});
      expect(await db.getCheckedItemIds(b.id), isEmpty);
      expect(await db.getCheckedItemIds(base.id), isEmpty);
    });

    test('can be unchecked and reset for one list only', () async {
      final a = await list('A', ['x', 'y']);
      final b = await list('B', ['z']);
      final [x, y] = await items(a);
      final [z] = await items(b);
      await db.setItemChecked(a.id, x.id, true);
      await db.setItemChecked(a.id, y.id, true);
      await db.setItemChecked(b.id, z.id, true);

      await db.setItemChecked(a.id, x.id, false);
      expect(await db.getCheckedItemIds(a.id), {y.id});

      await db.setCheckedItemIds(a.id, {});
      expect(await db.getCheckedItemIds(a.id), isEmpty);
      expect(await db.getCheckedItemIds(b.id), {z.id});
    });

    test('survive saving, and removed items lose theirs', () async {
      final a = await list('A', ['x', 'y']);
      final [x, y] = await items(a);
      await db.setItemChecked(a.id, x.id, true);
      await db.setItemChecked(a.id, y.id, true);

      await db.saveChecklistItems(a.id, [
        (id: null, title: 'new'),
        (id: x.id, title: 'x renamed'),
      ]);

      expect((await items(a)).map((i) => i.title), ['new', 'x renamed']);
      expect(await db.getCheckedItemIds(a.id), {x.id});
    });

    test('on a base item disappear from its children when deleted', () async {
      final base = await list('Base', ['x']);
      final child = await list('Child');
      await db.setChecklistParents(child.id, [base.id]);
      final x = (await items(base)).single;
      await db.setItemChecked(child.id, x.id, true);

      await db.replaceChecklistItems(base.id, []);

      expect(await db.getCheckedItemIds(child.id), isEmpty);
    });

    test('on an unlinked parent\'s items are removed, down the tree', () async {
      final root = await list('Root', ['r']);
      final base = await list('Base', ['b']);
      final child = await list('Child', ['c']);
      await db.setChecklistParents(base.id, [root.id]);
      await db.setChecklistParents(child.id, [base.id]);
      final [r] = await items(root);
      final [b] = await items(base);
      final [c] = await items(child);
      for (final item in [r, b, c]) {
        await db.setItemChecked(child.id, item.id, true);
      }

      await db.setChecklistParents(base.id, []);
      expect(await db.getCheckedItemIds(child.id), {b.id, c.id});

      await db.setChecklistParents(child.id, []);
      expect(await db.getCheckedItemIds(child.id), {c.id});
    });

    test('on grandparent items are removed when the base is deleted', () async {
      final root = await list('Root', ['r']);
      final base = await list('Base', ['b']);
      final child = await list('Child', ['c']);
      await db.setChecklistParents(base.id, [root.id]);
      await db.setChecklistParents(child.id, [base.id]);
      final [r] = await items(root);
      final [c] = await items(child);
      await db.setItemChecked(child.id, r.id, true);
      await db.setItemChecked(child.id, c.id, true);

      await db.deleteChecklist(base.id);

      expect(await db.getCheckedItemIds(child.id), {c.id});
    });

    test('of grandchildren carry over to the copies too', () async {
      final base = await list('Base', ['x', 'y']);
      final child = await list('Child', ['c']);
      final grandchild = await list('Grandchild', ['g']);
      await db.setChecklistParents(child.id, [base.id]);
      await db.setChecklistParents(grandchild.id, [child.id]);
      final [x, _] = await items(base);
      await db.setItemChecked(grandchild.id, x.id, true);

      await db.deleteChecklist(base.id, copyToChildren: true);

      final copies = await items(child);
      final checked = await db.getCheckedItemIds(grandchild.id);
      expect(
        [
          for (final i in copies)
            if (checked.contains(i.id)) i.title,
        ],
        ['x'],
      );
      expect(await db.getCheckedItemIds(child.id), isEmpty);
    });

    test('carry over to the copies when a base list is deleted', () async {
      final base = await list('Base', ['x', 'y']);
      final child = await list('Child', ['c']);
      await db.setChecklistParents(child.id, [base.id]);
      final [x, _] = await items(base);
      await db.setItemChecked(child.id, x.id, true);

      await db.deleteChecklist(base.id, copyToChildren: true);

      final own = await items(child);
      final checked = await db.getCheckedItemIds(child.id);
      expect(
        [
          for (final i in own)
            if (checked.contains(i.id)) i.title,
        ],
        ['x'],
      );
    });
  });

  group('split', () {
    Future<Set<int>> ids(Checklist checklist, List<String> titles) async => {
      for (final item in await db.getChecklistItems(checklist.id))
        if (titles.contains(item.title)) item.id,
    };

    test('into a parent keeps what the list shows and its checks', () async {
      final l = await list('L', ['a', 'b', 'c', 'd']);
      final [_, b, ..._] = await db.getChecklistItems(l.id);
      await db.setItemChecked(l.id, b.id, true);

      final p = await db.splitChecklist(
        l.id,
        await ids(l, ['b', 'd']),
        title: 'P',
        direction: SplitDirection.parent,
      );

      expect(await view(l), ['P: b, d', 'L: a, c']);
      expect(await db.getChecklistParentIds(l.id), [p.id]);
      expect(await db.getCheckedItemIds(l.id), {b.id});
    });

    test('into a child moves the items and prunes the list\'s checks', () async {
      final l = await list('L', ['a', 'b', 'c']);
      final [a, b, _] = await db.getChecklistItems(l.id);
      await db.setItemChecked(l.id, a.id, true);
      await db.setItemChecked(l.id, b.id, true);

      final c = await db.splitChecklist(
        l.id,
        await ids(l, ['b']),
        title: 'C',
        direction: SplitDirection.child,
      );

      expect(await view(l), ['L: a, c']);
      expect(await view(c), ['L: a, c', 'C: b']);
      expect(await db.getCheckedItemIds(l.id), {a.id});
      expect(await db.getCheckedItemIds(c.id), isEmpty);
    });

    test('into a child re-points existing children to it', () async {
      final l = await list('L', ['a', 'b']);
      final x = await list('X', ['x']);
      await db.setChecklistParents(x.id, [l.id]);
      final [_, b] = await db.getChecklistItems(l.id);
      await db.setItemChecked(x.id, b.id, true);

      final c = await db.splitChecklist(
        l.id,
        {b.id},
        title: 'C',
        direction: SplitDirection.child,
      );

      expect(await db.getChecklistParentIds(x.id), [c.id]);
      expect(await view(x), ['L: a', 'C: b', 'X: x']);
      expect(await db.getCheckedItemIds(x.id), {b.id});
    });
  });

  group('backup', () {
    test('export then import into a fresh database round-trips', () async {
      final base = await list('Base', ['x', 'y']);
      final child = await list('Child', ['c']);
      await db.setChecklistParents(child.id, [base.id]);
      final [x, _] = await db.getChecklistItems(base.id);
      await db.setItemChecked(child.id, x.id, true);
      final json = await db.exportBackup();

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await other.createChecklist('Stale');
      await other.importBackup(json);

      expect(shape(await other.watchChecklistSections(child.id).first), [
        'Base: x, y',
        'Child: c',
      ]);
      expect(await other.getCheckedItemIds(child.id), {x.id});
      expect(await other.exportBackup(), json);
    });

    test('rejects bad files without touching existing data', () async {
      await list('Keep', ['a']);
      for (final bad in [
        'nope',
        '{}',
        '{"format":"checklist-backup","version":99}',
      ]) {
        await expectLater(db.importBackup(bad), throwsFormatException);
      }
      expect((await db.watchChecklists().first).map((c) => c.title), ['Keep']);
    });
  });
}
