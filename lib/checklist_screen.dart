import 'package:checklist/checklist_view.dart';
import 'package:checklist/edit_checklist.dart';
import 'package:flutter/material.dart';

import 'database/database.dart';

/// One checklist: its items, with a button to edit them.
class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key, required this.checklist});

  final Checklist checklist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(checklist.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit list',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditChecklist(checklistId: checklist.id),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: ChecklistView(checklistId: checklist.id),
      ),
    );
  }
}
