import 'package:checklist/database/database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChecklistView extends StatefulWidget {
  const ChecklistView({super.key, required this.checklistId});

  final int checklistId;

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<ChecklistView> {
  late final Stream<List<ChecklistItem>> _items;

  /// Ids of checked items. Local only; not persisted.
  final Set<int> _checked = {};

  @override
  void initState() {
    super.initState();
    _items = Provider.of<AppDatabase>(
      context,
      listen: false,
    ).watchChecklistItems(widget.checklistId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _items,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null) {
          return const CircularProgressIndicator();
        }
        return ListView(
          children: [
            for (final item in items)
              CheckboxListTile(
                title: Text(item.title),
                value: _checked.contains(item.id),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => setState(() {
                  if (value!) {
                    _checked.add(item.id);
                  } else {
                    _checked.remove(item.id);
                  }
                }),
              ),
          ],
        );
      },
    );
  }
}
