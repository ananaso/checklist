import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database.dart';

class NewItemTextField extends StatefulWidget {
  const NewItemTextField(this.listLength, {super.key});

  final int listLength;

  @override
  State<NewItemTextField> createState() => _NewItemTextFieldState();
}

class _NewItemTextFieldState extends State<NewItemTextField> {
  late AppDatabase database;

  final TextEditingController _controller = TextEditingController();

  void _saveItem(String itemText) {
    database.addChecklistItem(
      ChecklistItemsCompanion(
        title: Value(itemText),
        position: Value(widget.listLength),
      ),
    );
    setState(() {
      _controller.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    database = Provider.of<AppDatabase>(context, listen: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onSubmitted: _saveItem,
      decoration: const InputDecoration(labelText: "New Item"),
    );
  }
}
