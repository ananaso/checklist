import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database.dart';

class Item extends StatefulWidget {
  const Item(this.item, {super.key});

  final ChecklistItem item;

  @override
  State<Item> createState() => _ItemState();
}

class _ItemState extends State<Item> {
  late TextEditingController _controller;
  bool isChecked = false;

  late FocusNode _node;
  bool _focused = false;
  late FocusAttachment _nodeAttachment;

  late AppDatabase database;

  void _toggleCheckbox(bool? value) {
    setState(() {
      isChecked = value!;
    });
  }

  void _onTap() {
    if (_focused) {
      _node.unfocus();
    } else {
      _node.requestFocus();
    }
  }

  void _updateItem(String updatedTitle) {
    database.updateChecklistItem(widget.item.copyWith(title: updatedTitle));
  }

  void _deleteItem() {
    database.deleteChecklistItem(widget.item.id);
  }

  void _handleFocusChange() {
    if (_node.hasFocus != _focused) {
      setState(() {
        _focused = _node.hasFocus;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title);
    _node = FocusNode();
    _node.addListener(_handleFocusChange);
    _nodeAttachment = _node.attach(context);
    database = Provider.of<AppDatabase>(context, listen: false);
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocusChange);
    // The attachment will automatically be detached in dispose().
    _node.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _nodeAttachment.reparent();
    return Row(
      children: [
        // Checkbox(value: isChecked, onChanged: _toggleCheckbox),
        // IconButton(onPressed: () {}, icon: Icon(Icons.keyboard_arrow_up)),
        // IconButton(onPressed: () {}, icon: Icon(Icons.keyboard_arrow_down)),
        Text('[${widget.item.position}] '),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: _node.hasFocus
                ? InputDecoration(border: UnderlineInputBorder())
                : null,
            onTap: _onTap,
            onSubmitted: _updateItem,
            focusNode: _node,
          ),
        ),
        IconButton(onPressed: _deleteItem, icon: Icon(Icons.delete)),
      ],
    );
  }
}
