import 'package:checklist/checklist_screen.dart';
import 'package:flutter/material.dart';
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
      builder: (context) => const _ChecklistNameDialog(
        heading: 'New checklist',
        confirmLabel: 'Create',
      ),
    );
    if (title == null) return;
    final checklist = await database.createChecklist(title);
    navigator.push(
      MaterialPageRoute(
        builder: (context) => ChecklistScreen(checklist: checklist),
      ),
    );
  }

  Future<void> _rename(Checklist checklist) async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _ChecklistNameDialog(
        heading: 'Rename checklist',
        confirmLabel: 'Rename',
        initialTitle: checklist.title,
      ),
    );
    if (title == null || title == checklist.title) return;
    await database.renameChecklist(checklist.id, title);
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

/// Asks for a name; pops with the trimmed title, or null if cancelled.
class _ChecklistNameDialog extends StatefulWidget {
  const _ChecklistNameDialog({
    required this.heading,
    required this.confirmLabel,
    this.initialTitle = '',
  });

  final String heading;
  final String confirmLabel;
  final String initialTitle;

  @override
  State<_ChecklistNameDialog> createState() => _ChecklistNameDialogState();
}

class _ChecklistNameDialogState extends State<_ChecklistNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  void _submit() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.of(context).pop(title);
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
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(labelText: 'Name'),
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
