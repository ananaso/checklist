import 'package:checklist/database/database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditChecklist extends StatefulWidget {
  const EditChecklist({super.key});

  @override
  State<EditChecklist> createState() => _EditChecklistState();
}

class _EditChecklistState extends State<EditChecklist> {
  /// Local draft of the list; nothing is persisted yet.
  final List<String> _items = [];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _addItem(String text) {
    final title = text.trim();
    if (title.isNotEmpty) {
      setState(() => _items.add(title));
    }
    _controller.clear();
    // Keep the keyboard open so several items can be entered in a row.
    _focusNode.requestFocus();
  }

  Future<void> _save() async {
    final database = Provider.of<AppDatabase>(context, listen: false);
    final navigator = Navigator.of(context);
    await database.replaceChecklistItems(_items);
    navigator.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Edit Checklist'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) =>
                    ListTile(title: Text(_items[index])),
              ),
            ),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: _addItem,
              decoration: const InputDecoration(labelText: 'New Item'),
            ),
          ],
        ),
      ),
    );
  }
}
