import 'package:material_ui/material_ui.dart';

import 'database/database.dart';

/// How to treat lists that inherit from a list being deleted.
enum _ChildHandling { unlink, copy }

/// Asks before deleting [checklist] and deletes it if confirmed; resolves true
/// only if it was deleted. If other lists inherit from it, also asks whether
/// they keep its items as their own or just lose them.
Future<bool> deleteChecklistWithConfirmation(
  BuildContext context,
  AppDatabase database,
  Checklist checklist,
) async {
  final children = await database.getChildren(checklist.id);
  if (!context.mounted) return false;

  final _ChildHandling? handling;
  if (children.isEmpty) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete checklist?'),
        content: Text(
          '"${checklist.title}" and all of its items will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    handling = confirmed == true ? _ChildHandling.unlink : null;
  } else {
    final names = children.map((c) => '"${c.title}"').join(', ');
    handling = await showDialog<_ChildHandling>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete checklist?'),
        content: Text(
          '"${checklist.title}" and all of its items will be deleted.\n\n'
          '$names inherit from it. They can keep its items as their own, '
          'or lose them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ChildHandling.unlink),
            child: const Text('Delete, remove items'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ChildHandling.copy),
            child: const Text('Delete, keep items'),
          ),
        ],
      ),
    );
  }
  if (handling == null) return false;
  await database.deleteChecklist(
    checklist.id,
    copyToChildren: handling == _ChildHandling.copy,
  );
  return true;
}

/// Lets the user choose which lists [checklist] inherits from, and saves the
/// choice. Lists that inherit from [checklist] aren't offered, which keeps
/// inheritance free of cycles.
Future<void> editChecklistParents(
  BuildContext context,
  AppDatabase database,
  Checklist checklist,
) async {
  final all = await database.watchChecklists().first;
  final descendants = await database.getDescendantIds(checklist.id);
  final current = await database.getChecklistParentIds(checklist.id);
  if (!context.mounted) return;

  final candidates = [
    for (final c in all)
      if (c.id != checklist.id && !descendants.contains(c.id)) c,
  ];
  final chosen = await showDialog<Set<int>>(
    context: context,
    builder: (context) =>
        _ParentPickerDialog(candidates: candidates, initial: current.toSet()),
  );
  if (chosen == null) return;
  // Keep the existing parents' order; new ones go after them.
  await database.setChecklistParents(checklist.id, [
    for (final id in current)
      if (chosen.contains(id)) id,
    for (final c in candidates)
      if (chosen.contains(c.id) && !current.contains(c.id)) c.id,
  ]);
}

/// Multi-select of lists to inherit from; pops with the chosen ids, or null if
/// cancelled.
class _ParentPickerDialog extends StatefulWidget {
  const _ParentPickerDialog({required this.candidates, required this.initial});

  final List<Checklist> candidates;
  final Set<int> initial;

  @override
  State<_ParentPickerDialog> createState() => _ParentPickerDialogState();
}

class _ParentPickerDialogState extends State<_ParentPickerDialog> {
  late final Set<int> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inherit items from'),
      content: widget.candidates.isEmpty
          ? const Text('There are no other checklists to inherit from.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in widget.candidates)
                    CheckboxListTile(
                      title: Text(c.title),
                      value: _chosen.contains(c.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) => setState(() {
                        if (value!) {
                          _chosen.add(c.id);
                        } else {
                          _chosen.remove(c.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_chosen),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

typedef _SplitChoice = ({
  SplitDirection direction,
  String title,
  Set<int> itemIds,
});

/// Lets the user move some of [checklist]'s own items into a new parent or
/// child list, and does so. Resolves to the new list's title, or null if
/// nothing was split.
Future<String?> splitChecklistWithDialog(
  BuildContext context,
  AppDatabase database,
  Checklist checklist,
) async {
  final items = await database.getChecklistItems(checklist.id);
  if (!context.mounted) return null;

  if (items.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split list'),
        content: const Text('This list has no items of its own to split.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return null;
  }

  final choice = await showDialog<_SplitChoice>(
    context: context,
    builder: (context) => _SplitDialog(items: items),
  );
  if (choice == null) return null;
  await database.splitChecklist(
    checklist.id,
    choice.itemIds,
    title: choice.title,
    direction: choice.direction,
  );
  return choice.title;
}

/// Picks items, a direction and a name for a split; pops with a
/// [_SplitChoice], or null if cancelled.
class _SplitDialog extends StatefulWidget {
  const _SplitDialog({required this.items});

  final List<ChecklistItem> items;

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  final TextEditingController _controller = TextEditingController();
  final Set<int> _chosen = {};
  SplitDirection _direction = SplitDirection.parent;
  String? _error;

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Name can\'t be empty');
      return;
    }
    Navigator.of(
      context,
    ).pop((direction: _direction, title: title, itemIds: _chosen));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Split list'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<SplitDirection>(
              segments: const [
                ButtonSegment(
                  value: SplitDirection.parent,
                  label: Text('New parent'),
                ),
                ButtonSegment(
                  value: SplitDirection.child,
                  label: Text('New child'),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (selection) =>
                  setState(() => _direction = selection.single),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _direction == SplitDirection.parent
                    ? 'The chosen items move to a new list that this one '
                          'inherits from.'
                    : 'The chosen items move to a new list that inherits '
                          'from this one.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'New list name',
                errorText: _error,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in widget.items)
                    CheckboxListTile(
                      title: Text(item.title),
                      value: _chosen.contains(item.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) => setState(() {
                        if (value!) {
                          _chosen.add(item.id);
                        } else {
                          _chosen.remove(item.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _chosen.isEmpty ? null : _submit,
          child: const Text('Split'),
        ),
      ],
    );
  }
}

/// Asks for a name; pops with the trimmed title, or null if cancelled.
class ChecklistNameDialog extends StatefulWidget {
  const ChecklistNameDialog({
    super.key,
    required this.heading,
    required this.confirmLabel,
    this.initialTitle = '',
  });

  final String heading;
  final String confirmLabel;
  final String initialTitle;

  @override
  State<ChecklistNameDialog> createState() => _ChecklistNameDialogState();
}

class _ChecklistNameDialogState extends State<ChecklistNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  String? _error;

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Name can\'t be empty');
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.heading),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: 'Name', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
