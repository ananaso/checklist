import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database.dart';

class NewItemTextField extends StatefulWidget {
  const NewItemTextField({super.key});

  @override
  State<NewItemTextField> createState() => _NewItemTextFieldState();
}

class _NewItemTextFieldState extends State<NewItemTextField> {
  late AppDatabase database;

  final TextEditingController _controller = TextEditingController();

  void _saveItem(String itemText) {
    database.addChecklistItem(ChecklistItemsCompanion(title: Value(itemText)));
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
