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
        if (snapshot.hasError) {
          return Center(
            child: ErrorText(
              "Failed to load checklist items: ${snapshot.error}",
            ),
          );
        } else {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return Center(child: ErrorText("No connection to database"));
            case ConnectionState.waiting:
              return Center(child: CircularProgressIndicator());
            case ConnectionState.active:
              List<ChecklistItem> loadedItems = snapshot.data!;
              return ReorderableListView(
                buildDefaultDragHandles: false,
                onReorder: (int oldIndex, int newIndex) {
                  database.reorderChecklistItem(
                    loadedItems.elementAt(oldIndex).id,
                    oldIndex,
                    newIndex,
                  );
                },
                footer: NewItemTextField(loadedItems.length),
                children: loadedItems.map((checklistItem) {
                  return ListTile(
                    key: ValueKey(checklistItem.id),
                    leading: ReorderableDragStartListener(
                      index: loadedItems.indexOf(checklistItem),
                      child: Icon(Icons.drag_handle),
                    ),
                    title: Item(key: ValueKey(checklistItem.id), checklistItem),
                  );
                }).toList(),
              );
            case ConnectionState.done:
              return Center(
                child: ErrorText("Connection to database has closed"),
              );
          }
        }
      },
    );
  }
}
