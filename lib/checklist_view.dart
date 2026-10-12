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
  late final Stream<List<ChecklistSection>> _sections;

  /// Ids of checked items. Local only; not persisted.
  final Set<int> _checked = {};

  @override
  void initState() {
    super.initState();
    _sections = Provider.of<AppDatabase>(
      context,
      listen: false,
    ).watchChecklistSections(widget.checklistId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _sections,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const CircularProgressIndicator();
        }
        final sections = data.where((s) => s.items.isNotEmpty).toList();
        // Headers only matter once items come from more than this list.
        final showHeaders = sections.any(
          (s) => s.source.id != widget.checklistId,
        );
        return ListView(
          children: [
            for (final section in sections) ...[
              if (showHeaders)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    section.source.id == widget.checklistId
                        ? 'This list'
                        : 'From ${section.source.title}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              for (final item in section.items)
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
          ],
        );
      },
    );
  }
}
