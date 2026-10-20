import 'dart:convert';

import 'package:checklist/checklist_dialogs.dart';
import 'package:checklist/checklist_screen.dart';
import 'package:checklist/edit_checklist.dart';
import 'package:file_picker/file_picker.dart';
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

  late final Stream<List<ChecklistGroup>> _groups = Provider.of<AppDatabase>(
    context,
    listen: false,
  ).watchGroups();

  Future<void> _createGroup() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const ChecklistNameDialog(
        heading: 'New group',
        confirmLabel: 'Create',
      ),
    );
    if (title == null) return;
    await database.createGroup(title);
  }

  Future<void> _renameGroup(ChecklistGroup group) async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => ChecklistNameDialog(
        heading: 'Rename group',
        confirmLabel: 'Rename',
        initialTitle: group.title,
      ),
    );
    if (title == null || title == group.title) return;
    await database.renameGroup(group.id, title);
  }

  Future<void> _deleteGroup(ChecklistGroup group) {
    final database = Provider.of<AppDatabase>(context, listen: false);
    return deleteGroupWithConfirmation(context, database, group);
  }

  Future<void> _moveToGroup(Checklist checklist) {
    final database = Provider.of<AppDatabase>(context, listen: false);
    return moveChecklistToGroup(context, database, checklist);
  }

  Widget _groupHeader(ChecklistGroup group, int count) {
    return ListTile(
      leading: Icon(
        group.isCollapsed ? Icons.chevron_right : Icons.expand_more,
      ),
      title: Text(
        '${group.title} ($count)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      trailing: PopupMenuButton<void>(
        tooltip: 'More',
        itemBuilder: (context) => [
          PopupMenuItem(
            onTap: () => _renameGroup(group),
            child: const Text('Rename'),
          ),
          PopupMenuItem(
            onTap: () => _deleteGroup(group),
            child: const Text('Delete'),
          ),
        ],
      ),
      onTap: () => Provider.of<AppDatabase>(
        context,
        listen: false,
      ).setGroupCollapsed(group.id, !group.isCollapsed),
    );
  }

  Widget _checklistTile(Checklist checklist, {bool indented = false}) {
    return ListTile(
      contentPadding: indented
          ? const EdgeInsetsDirectional.only(start: 32, end: 16)
          : null,
      leading: checklist.isFavorite ? const Icon(Icons.star) : null,
      title: Text(checklist.title),
      trailing: PopupMenuButton<void>(
        tooltip: 'More',
        itemBuilder: (context) => [
          PopupMenuItem(
            onTap: () => Provider.of<AppDatabase>(
              context,
              listen: false,
            ).setChecklistFavorite(checklist.id, !checklist.isFavorite),
            child: Text(checklist.isFavorite ? 'Unfavorite' : 'Favorite'),
          ),
          PopupMenuItem(
            onTap: () => _rename(checklist),
            child: const Text('Rename'),
          ),
          PopupMenuItem(
            onTap: () => _moveToGroup(checklist),
            child: const Text('Move to group…'),
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
  }

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    try {
      final json = await database.exportBackup();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final saved = await FilePicker.saveFile(
        fileName:
            'checklists-${now.year}-${two(now.month)}-${two(now.day)}.json',
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        dialogTitle: 'Export checklists',
      );
      if (saved != null) _showMessage('Exported checklists');
    } catch (error) {
      _showMessage('Export failed: $error');
    }
  }

  Future<void> _import() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    try {
      final file = await FilePicker.pickFile(dialogTitle: 'Import checklists');
      if (file == null) return;
      final json = utf8.decode(await file.readAsBytes());
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace all checklists?'),
          content: const Text(
            'Importing replaces every checklist currently in the app with '
            'the contents of the file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await database.importBackup(json);
      _showMessage('Imported checklists');
    } on FormatException catch (error) {
      _showMessage('Import failed: ${error.message}');
    } catch (error) {
      _showMessage('Import failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Checklists'),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'More',
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _createGroup,
                child: const Text('New group…'),
              ),
              PopupMenuItem(onTap: _export, child: const Text('Export…')),
              PopupMenuItem(onTap: _import, child: const Text('Import…')),
            ],
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _groups,
        builder: (context, groupsSnapshot) {
          return StreamBuilder(
            stream: _checklists,
            builder: (context, snapshot) {
              final groups = groupsSnapshot.data;
              final checklists = snapshot.data;
              if (groups == null || checklists == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (checklists.isEmpty && groups.isEmpty) {
                return const Center(child: Text('No checklists yet'));
              }
              // Favorites lead, from any group; then each group's other lists
              // under its header, then the ungrouped ones.
              final rows = <Widget>[
                for (final c in checklists)
                  if (c.isFavorite) _checklistTile(c),
                for (final group in groups) ...[
                  _groupHeader(
                    group,
                    checklists.where((c) => c.groupId == group.id).length,
                  ),
                  if (!group.isCollapsed)
                    for (final c in checklists)
                      if (c.groupId == group.id && !c.isFavorite)
                        _checklistTile(c, indented: true),
                ],
                for (final c in checklists)
                  if (!c.isFavorite && c.groupId == null) _checklistTile(c),
              ];
              return ListView(children: rows);
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
