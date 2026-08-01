import 'package:checklist/database/database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Checklist extends StatefulWidget {
  const Checklist({super.key});

  @override
  State<Checklist> createState() => _ChecklistState();
}

class _ChecklistState extends State<Checklist> {
  late AppDatabase database;

  late Future<List<ChecklistItem>> persistedItems;

  @override
  void initState() {
    super.initState();
    database = Provider.of<AppDatabase>(context, listen: false);
    persistedItems = database.select(database.checklistItems).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: persistedItems,
      builder: (context, snapshot) {
        return Text('hello');
      },
    );
  }
}
