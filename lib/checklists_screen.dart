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
          return ListView.builder(
            itemCount: checklists.length,
            itemBuilder: (context, index) {
              final checklist = checklists[index];
              return ListTile(
                title: Text(checklist.title),
                trailing: const Icon(Icons.chevron_right),
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
    );
  }
}
