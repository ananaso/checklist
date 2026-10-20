import 'package:checklist/database/database.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// A draft item. The key gives each row a stable identity (titles can repeat),
/// which [ReorderableListView] needs to track rows as they move.
class _DraftItem {
  _DraftItem(this.title, {this.id, Key? key}) : key = key ?? UniqueKey();

  final String title;

  /// The stored item this row edits, or null for one not saved yet. Saving
  /// keeps it, so the item's checks survive the edit.
  final int? id;
  final Key key;

  /// A copy with a new title but the same row identity.
  _DraftItem withTitle(String title) => _DraftItem(title, id: id, key: key);
}

/// An item title that edits in place. It shows plain text until tapped, since
/// a live text field per row is costly to lay out in a long list. Reports
/// changes on submit or when the field loses focus, so a typing session
/// becomes one undo step.
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

  bool _editing = false;

  void _startEditing() {
    setState(() => _editing = true);
    // autofocus is ignored while something else (the New Item field, another
    // row) holds focus, so ask for it once the field exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus || !_editing) return;
    _commit();
    if (mounted) setState(() => _editing = false);
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
    if (!_editing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _startEditing,
        // The same decorator the text field uses, so tapping doesn't shift
        // the row.
        child: InputDecorator(
          decoration: _titleDecoration,
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onSubmitted: (_) => _commit(),
      // Wrap long titles instead of scrolling horizontally; the text keyboard
      // keeps Enter as "done" rather than inserting a newline.
      maxLines: null,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      decoration: _titleDecoration,
    );
  }
}

const _titleDecoration = InputDecoration(border: InputBorder.none);

/// The space between two items. Faint at rest, with a touch target taller than
/// what's drawn; tapping it asks to insert an item here.
class _InsertGap extends StatelessWidget {
  const _InsertGap({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.3);
    return Semantics(
      button: true,
      label: 'Insert item here',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 28,
          child: Row(
            children: [
              Expanded(child: Divider(color: color, height: 1)),
              Icon(Icons.add, size: 16, color: color),
              Expanded(child: Divider(color: color, height: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field for typing a new item into the middle of the list. Submitting
/// reports the text; losing focus while empty reports a cancel.
class _InsertField extends StatefulWidget {
  const _InsertField({
    super.key,
    required this.onSubmitted,
    required this.onCancel,
  });

  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  @override
  State<_InsertField> createState() => _InsertFieldState();
}

class _InsertFieldState extends State<_InsertField> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
      widget.onCancel();
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
      autofocus: true,
      onSubmitted: widget.onSubmitted,
      decoration: const InputDecoration(labelText: 'New Item'),
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
  final ScrollController _scrollController = ScrollController();

  /// The gap an item is being typed into, where [i] means just before item [i],
  /// or null when none is open.
  int? _insertAt;

  /// Names of the lists this one inherits items from. Their items aren't
  /// editable here, so say why they're missing from the draft.
  List<String> _inheritedFrom = const [];

  @override
  void initState() {
    super.initState();
    final database = Provider.of<AppDatabase>(context, listen: false);
    // Load both together so the screen rebuilds once, not once per query.
    Future.wait([
      database.watchChecklistSections(widget.checklistId).first,
      database.getChecklistItems(widget.checklistId),
    ]).then((results) {
      if (!mounted) return;
      final sections = results[0] as List<ChecklistSection>;
      final existing = results[1] as List<ChecklistItem>;
      setState(() {
        _inheritedFrom = [
          for (final s in sections)
            if (s.source.id != widget.checklistId) s.label,
        ];
        _items.addAll(
          existing.map((item) => _DraftItem(item.title, id: item.id)),
        );
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
      // The open insert point is an index, which no longer means the same gap.
      _insertAt = null;
      _redoStack.add(List.of(_items));
      _items
        ..clear()
        ..addAll(_undoStack.removeLast());
    });
  }

  void _redo() {
    setState(() {
      _insertAt = null;
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
      _scrollToEnd();
    }
    _controller.clear();
    // Keep the keyboard open so several items can be entered in a row.
    _focusNode.requestFocus();
  }

  /// Brings the end of the list into view once the new item has been laid out.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Inserts the text typed at gap [index], then moves the insert field to the
  /// gap after the new item so a run of items can be typed in place.
  void _insertItem(int index, String text) {
    final title = text.trim();
    if (title.isEmpty) {
      _cancelInsert(index);
      return;
    }
    _edit(() => _items.insert(index, _DraftItem(title)));
    if (index + 1 >= _items.length) {
      // That was the end of the list, which the New Item field already covers.
      setState(() => _insertAt = null);
      _focusNode.requestFocus();
      _scrollToEnd();
    } else {
      setState(() => _insertAt = index + 1);
    }
  }

  void _cancelInsert(int index) {
    // A stale field closing after the insert point moved on must not close it.
    if (_insertAt == index) setState(() => _insertAt = null);
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
    await database.saveChecklistItems(widget.checklistId, [
      for (final item in _items) (id: item.id, title: item.title),
    ]);
    navigator.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// The gap before item [index]: a faint tap target, or the field for typing
  /// into it. There's none after the last item; the New Item field covers that.
  Widget _gap(int index) {
    if (_insertAt == index) {
      return _InsertField(
        key: ValueKey('insert-$index'),
        onSubmitted: (text) => _insertItem(index, text),
        onCancel: () => _cancelInsert(index),
      );
    }
    return _InsertGap(onTap: () => setState(() => _insertAt = index));
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
                  scrollController: _scrollController,
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorderItem: _reorder,
                  // Each row carries the gap before it, so the gaps follow
                  // their items when reordered.
                  itemBuilder: (context, index) => Column(
                    key: _items[index].key,
                    children: [
                      _gap(index),
                      ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: _EditableTitle(
                          title: _items[index].title,
                          onChanged: (title) => _edit(
                            () =>
                                _items[index] = _items[index].withTitle(title),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete',
                          onPressed: () => _edit(() => _items.removeAt(index)),
                        ),
                      ),
                    ],
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
