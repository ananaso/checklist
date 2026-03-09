import 'package:flutter/material.dart';

class Item extends StatefulWidget {
  const Item({required this.title, super.key});

  final String title;

  @override
  State<Item> createState() => _ItemState();
}

class _ItemState extends State<Item> {
  late TextEditingController _controller;
  bool isChecked = false;

  late FocusNode _node;
  bool _focused = false;
  late FocusAttachment _nodeAttachment;

  void _toggleCheckbox(bool? value) {
    setState(() {
      isChecked = value!;
    });
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
    _controller = TextEditingController();
    _node = FocusNode();
    _node.addListener(_handleFocusChange);
    _nodeAttachment = _node.attach(context);
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
        Checkbox(value: isChecked, onChanged: _toggleCheckbox),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: _node.hasFocus
                ? InputDecoration(border: UnderlineInputBorder())
                : null,
            onTap: () {
              if (_focused) {
                _node.unfocus();
              } else {
                _node.requestFocus();
              }
            },
            focusNode: _node,
          ),
        ),
      ],
    );
  }
}
