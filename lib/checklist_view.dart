import 'dart:async';

import 'package:checklist/database/database.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ChecklistView extends StatefulWidget {
  const ChecklistView({super.key, required this.checklistId});

  final int checklistId;

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

/// A row of the list: a section header or an item.
sealed class _Row {}

class _HeaderRow extends _Row {
  _HeaderRow(this.text);

  final String text;
}

class _ItemRow extends _Row {
  _ItemRow(this.item);

  final ChecklistItem item;
}

class _ChecklistViewState extends State<ChecklistView> {
  /// Last scroll offset per checklist, so reopening a list resumes where it
  /// was left. Kept in memory only; it resets when the app restarts.
  static final Map<int, double> _offsets = {};

  /// Last loaded sections and checks per checklist, so reopening a list paints
  /// immediately instead of waiting on the database. The streams below still
  /// refresh it right after.
  static final Map<int, List<ChecklistSection>> _sectionsCache = {};
  static final Map<int, Set<int>> _checkedCache = {};

  late final AppDatabase _database;
  late final ScrollController _scrollController;
  final List<StreamSubscription<void>> _subscriptions = [];

  List<ChecklistSection>? _sections;
  Set<int>? _checked;
  List<_Row> _rows = const [];

  @override
  void initState() {
    super.initState();
    final id = widget.checklistId;
    _database = Provider.of<AppDatabase>(context, listen: false);
    _sections = _sectionsCache[id];
    _checked = _checkedCache[id];
    _rows = _buildRows();
    _scrollController = ScrollController(initialScrollOffset: _offsets[id] ?? 0)
      ..addListener(_rememberOffset);
    _subscriptions.add(
      _database.watchChecklistSections(id).listen((sections) {
        // A refresh that matches what is already shown needs no rebuild.
        if (listEquals(sections, _sections)) return;
        _sectionsCache[id] = sections;
        if (!mounted) return;
        setState(() {
          _sections = sections;
          _rows = _buildRows();
        });
      }),
    );
    _subscriptions.add(
      _database.watchCheckedItemIds(id).listen((checked) {
        if (setEquals(checked, _checked)) return;
        _checkedCache[id] = checked;
        if (mounted) setState(() => _checked = checked);
      }),
    );
  }

  void _rememberOffset() {
    _offsets[widget.checklistId] = _scrollController.offset;
  }

  List<_Row> _buildRows() {
    final data = _sections;
    if (data == null) return const [];
    final sections = data.where((s) => s.items.isNotEmpty).toList();
    // Headers only matter once items come from more than this list.
    final showHeaders = sections.any((s) => s.source.id != widget.checklistId);
    return [
      for (final section in sections) ...[
        if (showHeaders)
          _HeaderRow(
            section.source.id == widget.checklistId
                ? 'This list'
                : 'From ${section.source.title}',
          ),
        for (final item in section.items) _ItemRow(item),
      ],
    ];
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wait for both, so items never flash unchecked before the checks arrive.
    final checked = _checked;
    if (_sections == null || checked == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      controller: _scrollController,
      // Padding inside the list scrolls with it, so items are visible right up
      // to the app bar and the screen's bottom edge. The bottom inset keeps
      // the last item clear of the system navigation bar.
      padding: EdgeInsets.fromLTRB(
        32,
        8,
        32,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        switch (_rows[index]) {
          case _HeaderRow(:final text):
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(text, style: Theme.of(context).textTheme.titleSmall),
            );
          case _ItemRow(:final item):
            return CheckboxListTile(
              key: ValueKey(item.id),
              title: Text(item.title),
              value: checked.contains(item.id),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) =>
                  _database.setItemChecked(widget.checklistId, item.id, value!),
            );
        }
      },
    );
  }
}
