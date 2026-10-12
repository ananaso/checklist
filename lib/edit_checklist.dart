import 'package:checklist/database/database.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// A draft item. The key gives each row a stable identity (titles can repeat),
/// which [ReorderableListView] needs to track rows as they move.
class _DraftItem {
  _DraftItem(this.title, [Key? key]) : key = key ?? UniqueKey();

  final String title;
  final Key key;

  /// A copy with a new title but the same row identity.
  _DraftItem withTitle(String title) => _DraftItem(title, key);
}

/// An item title that edits in place. Reports changes on submit or when the
/// field loses focus, so a typing session becomes one undo step.
class _EditableTitle extends StatefulWidget {
  const _EditableTitle({required this.title, required this.onChanged});

  final String title;
  final ValueChanged<String> onChanged;

  @override
  State<_EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<_EditableTitle> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.title,
  );
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      // Blank titles aren't allowed; fall back to the current title.
      _controller.text = widget.title;
    } else if (text != widget.title) {
      widget.onChanged(text);
    }
  }

  @override
  void didUpdateWidget(_EditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The title changed from outside (e.g. undo/redo), so show it.
    if (widget.title != oldWidget.title && _controller.text != widget.title) {
      _controller.text = widget.title;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onSubmitted: (_) => _commit(),
      decoration: const InputDecoration(border: InputBorder.none),
    );
  }
}

class EditChecklist extends StatefulWidget {
  const EditChecklist({super.key, required this.checklistId});

  final int checklistId;

  @override
  State<EditChecklist> createState() => _EditChecklistState();
}

class _EditChecklistState extends State<EditChecklist> {
  /// Local draft of the list; nothing is persisted yet.
  final List<_DraftItem> _items = [];

  /// Snapshots of [_items] for undo/redo. The items are immutable, so a
  /// shallow copy of the list is a full snapshot.
  final List<List<_DraftItem>> _undoStack = [];
  final List<List<_DraftItem>> _redoStack = [];

  /// Saving is disabled until the existing items have loaded, so an early
  /// Save can't overwrite them with an empty list.
  bool _loaded = false;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Names of the lists this one inherits items from. Their items aren't
  /// editable here, so say why they're missing from the draft.
  List<String> _inheritedFrom = const [];

  @override
  void initState() {
    super.initState();
    final database = Provider.of<AppDatabase>(context, listen: false);
    database.watchChecklistSections(widget.checklistId).first.then((sections) {
      if (!mounted) return;
      setState(() {
        _inheritedFrom = [
          for (final s in sections)
            if (s.source.id != widget.checklistId) s.source.title,
        ];
      });
    });
    database.getChecklistItems(widget.checklistId).then((existing) {
      if (!mounted) return;
      setState(() {
        _items.addAll(existing.map((item) => _DraftItem(item.title)));
        _loaded = true;
      });
      // A new, empty list almost certainly wants items typed in right away.
      if (existing.isEmpty) _focusNode.requestFocus();
    });
  }

  /// Applies [change] to the draft, recording a snapshot first so it can be
  /// undone. Any new change invalidates the redo history.
  void _edit(void Function() change) {
    setState(() {
      _undoStack.add(List.of(_items));
      _redoStack.clear();
      change();
    });
  }

  void _undo() {
    setState(() {
      _redoStack.add(List.of(_items));
      _items
        ..clear()
        ..addAll(_undoStack.removeLast());
    });
  }

  void _redo() {
    setState(() {
      _undoStack.add(List.of(_items));
      _items
        ..clear()
        ..addAll(_redoStack.removeLast());
    });
  }

  void _addItem(String text) {
    final title = text.trim();
    if (title.isNotEmpty) {
      _edit(() => _items.add(_DraftItem(title)));
    }
    _controller.clear();
    // Keep the keyboard open so several items can be entered in a row.
    _focusNode.requestFocus();
  }

  void _reorder(int oldIndex, int newIndex) {
    _edit(() => _items.insert(newIndex, _items.removeAt(oldIndex)));
  }

  /// Whether leaving now would throw anything away. Undoing back to the
  /// original list leaves the undo stack empty, so that counts as clean.
  bool get _hasUnsavedChanges =>
      _undoStack.isNotEmpty || _controller.text.trim().isNotEmpty;

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    await _commitPendingEdit();
    if (!mounted) return;
    if (!_hasUnsavedChanges) {
      navigator.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes to this list will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) navigator.pop();
  }

  /// Unfocusing makes a title field being edited commit its text. Focus changes
  /// are applied in a microtask, so yield before reading the draft.
  Future<void> _commitPendingEdit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _save() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final navigator = Navigator.of(context);
    await _commitPendingEdit();
    // Text typed in the new item field but never submitted still counts.
    final pending = _controller.text.trim();
    if (pending.isNotEmpty) _items.add(_DraftItem(pending));
    await database.replaceChecklistItems(widget.checklistId, [
      for (final item in _items) item.title,
    ]);
    navigator.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always intercept leaving; _onPopInvoked decides whether to ask first.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Edit Checklist'),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: _undoStack.isEmpty ? null : _undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
              onPressed: _redoStack.isEmpty ? null : _redo,
            ),
            TextButton(
              onPressed: _loaded ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              if (_inheritedFrom.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Also includes items from ${_inheritedFrom.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorderItem: _reorder,
                  itemBuilder: (context, index) => ListTile(
                    key: _items[index].key,
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: _EditableTitle(
                      title: _items[index].title,
                      onChanged: (title) => _edit(
                        () => _items[index] = _items[index].withTitle(title),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete',
                      onPressed: () => _edit(() => _items.removeAt(index)),
                    ),
                  ),
                ),
              ),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: _addItem,
                decoration: const InputDecoration(labelText: 'New Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
