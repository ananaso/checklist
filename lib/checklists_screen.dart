import 'package:checklist/checklist_dialogs.dart';
import 'package:checklist/checklist_screen.dart';
import 'package:checklist/edit_checklist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'database/database.dart';

/// Home screen: every checklist in the app. Tap one to open it.
class ChecklistsScreen extends StatefulWidget {
  const ChecklistsScreen({super.key});

  @override
  State<ChecklistsScreen> createState() => _ChecklistsScreenState();
}

class _ChecklistsScreenState extends State<ChecklistsScreen> {
  late final Stream<List<Checklist>> _checklists = Provider.of<AppDatabase>(
    context,
    listen: false,
  ).watchChecklists();

  Future<void> _create() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final navigator = Navigator.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const ChecklistNameDialog(
        heading: 'New checklist',
        confirmLabel: 'Create',
      ),
    );
    if (title == null) return;
    final checklist = await database.createChecklist(title);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => EditChecklist(checklistId: checklist.id),
      ),
    );
  }

  Future<void> _rename(Checklist checklist) async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => ChecklistNameDialog(
        heading: 'Rename checklist',
        confirmLabel: 'Rename',
        initialTitle: checklist.title,
      ),
    );
    if (title == null || title == checklist.title) return;
    await database.renameChecklist(checklist.id, title);
  }

  Future<void> _delete(Checklist checklist) async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    await deleteChecklistWithConfirmation(context, database, checklist);
  }

  Future<void> _editParents(Checklist checklist) {
    final database = Provider.of<AppDatabase>(context, listen: false);
    return editChecklistParents(context, database, checklist);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Checklists'),
      ),
      body: StreamBuilder(
        stream: _checklists,
        builder: (context, snapshot) {
          final checklists = snapshot.data;
          if (checklists == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (checklists.isEmpty) {
            return const Center(child: Text('No checklists yet'));
          }
          return ListView.builder(
            itemCount: checklists.length,
            itemBuilder: (context, index) {
              final checklist = checklists[index];
              return ListTile(
                title: Text(checklist.title),
                trailing: PopupMenuButton<void>(
                  tooltip: 'More',
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: () => _rename(checklist),
                      child: const Text('Rename'),
                    ),
                    PopupMenuItem(
                      onTap: () => _editParents(checklist),
                      child: const Text('Inherits from…'),
                    ),
                    PopupMenuItem(
                      onTap: () => _delete(checklist),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChecklistScreen(checklist: checklist),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: 'New checklist',
        child: const Icon(Icons.add),
      ),
    );
  }
}
