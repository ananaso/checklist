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
}
