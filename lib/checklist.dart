import 'package:checklist/database.dart';
import 'package:checklist/error_text.dart';
import 'package:checklist/item.dart';
import 'package:checklist/new_item_text_field.dart';
import 'package:flutter/material.dart';

class Checklist extends StatelessWidget {
  const Checklist({required this.items, super.key});

  final Stream<List<ChecklistItem>>? items;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: items,
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
                  return Item(checklistItem);
                }).toList(),
              );
              children.add(NewItemTextField());
            case ConnectionState.done:
              children = [const ErrorText("Connection to database has closed")];
          }
        }

        return Column(mainAxisAlignment: .center, children: children);
      },
    );
  }
}
