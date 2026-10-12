import 'package:checklist/checklist_dialogs.dart';
import 'package:checklist/checklist_view.dart';
import 'package:checklist/edit_checklist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'database/database.dart';

/// One checklist: its items, with buttons to rename, edit, or delete it.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.checklist});

  final Checklist checklist;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late String _title = widget.checklist.title;

  /// Ids of the checked items, to disable "Uncheck all" when there are none.
  late final Stream<Set<int>> _checked = Provider.of<AppDatabase>(
    context,
    listen: false,
  ).watchCheckedItemIds(widget.checklist.id);

  Future<void> _rename() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => ChecklistNameDialog(
        heading: 'Rename checklist',
        confirmLabel: 'Rename',
        initialTitle: _title,
      ),
    );
    if (title == null || title == _title) return;
    await database.renameChecklist(widget.checklist.id, title);
    if (mounted) setState(() => _title = title);
  }

  Future<void> _delete() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final navigator = Navigator.of(context);
    final deleted = await deleteChecklistWithConfirmation(
      context,
      database,
      widget.checklist,
    );
    if (deleted) navigator.pop();
  }

  /// Unchecks every item, offering to put the checks back.
  Future<void> _uncheckAll() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.checklist.id;
    final previous = await database.getCheckedItemIds(id);
    if (previous.isEmpty) return;
    await database.setCheckedItemIds(id, {});
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Unchecked all items'),
          // Snackbars with an action otherwise stay until dismissed.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => database.setCheckedItemIds(id, previous),
          ),
        ),
      );
  }

  Future<void> _editParents() {
    final database = Provider.of<AppDatabase>(context, listen: false);
    return editChecklistParents(context, database, widget.checklist);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_title),
        actions: [
          StreamBuilder(
            stream: _checked,
            builder: (context, snapshot) => IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Uncheck all',
              onPressed: snapshot.data?.isNotEmpty == true ? _uncheckAll : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: 'Rename list',
            onPressed: _rename,
          ),
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'Inherits from',
            onPressed: _editParents,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit list',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    EditChecklist(checklistId: widget.checklist.id),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete list',
            onPressed: _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: ChecklistView(checklistId: widget.checklist.id),
      ),
    );
  }
}
