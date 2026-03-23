import 'package:checklist/database/database.dart';
import 'package:checklist/error_text.dart';
import 'package:checklist/item.dart';
import 'package:checklist/new_item_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Checklist extends StatefulWidget {
  const Checklist({super.key});

  @override
  State<Checklist> createState() => _ChecklistState();
}

class _ChecklistState extends State<Checklist> {
  late AppDatabase database;

  late Stream<List<ChecklistItem>> checklistItems;

  @override
  void initState() {
    super.initState();
    database = Provider.of<AppDatabase>(context, listen: false);
    checklistItems = database.select(database.checklistItems).watch();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: checklistItems,
      builder: (context, snapshot) {
        List<Widget> children = List.empty(growable: true);
        if (snapshot.hasError) {
          children = [
            ErrorText("Failed to load checklist items: ${snapshot.error}"),
          ];
        } else {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              children = [const ErrorText("No connection to database")];
            case ConnectionState.waiting:
              children = [const CircularProgressIndicator()];
            case ConnectionState.active:
              List<ChecklistItem> loadedItems = snapshot.data!;
              children.addAll(
                loadedItems.map((checklistItem) {
                  return Item(checklistItem, key: ValueKey(checklistItem.id));
                }).toList(),
              );
              children.add(NewItemTextField(loadedItems.length));
            case ConnectionState.done:
              children = [const ErrorText("Connection to database has closed")];
          }
        }

        return Column(mainAxisAlignment: .center, children: children);
      },
    );
  }
}
