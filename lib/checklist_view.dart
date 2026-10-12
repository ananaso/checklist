import 'package:checklist/database/database.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ChecklistView extends StatefulWidget {
  const ChecklistView({super.key, required this.checklistId});

  final int checklistId;

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<ChecklistView> {
  late final AppDatabase _database;
  late final Stream<List<ChecklistSection>> _sections;
  late final Stream<Set<int>> _checked;

  @override
  void initState() {
    super.initState();
    _database = Provider.of<AppDatabase>(context, listen: false);
    _sections = _database.watchChecklistSections(widget.checklistId);
    _checked = _database.watchCheckedItemIds(widget.checklistId);
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
        return StreamBuilder(
          stream: _checked,
          builder: (context, checkedSnapshot) {
            final checked = checkedSnapshot.data ?? const <int>{};
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
                      value: checked.contains(item.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) => _database.setItemChecked(
                        widget.checklistId,
                        item.id,
                        value!,
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
