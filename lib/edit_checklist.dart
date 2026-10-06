import 'package:flutter/material.dart';

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
