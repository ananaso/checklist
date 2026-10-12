import 'package:flutter/material.dart';

/// Asks before deleting; resolves true only if the user confirmed.
Future<bool> confirmDeleteChecklist(BuildContext context, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete checklist?'),
      content: Text('"$title" and all of its items will be deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Asks for a name; pops with the trimmed title, or null if cancelled.
class ChecklistNameDialog extends StatefulWidget {
  const ChecklistNameDialog({
    super.key,
    required this.heading,
    required this.confirmLabel,
    this.initialTitle = '',
  });

  final String heading;
  final String confirmLabel;
  final String initialTitle;

  @override
  State<ChecklistNameDialog> createState() => _ChecklistNameDialogState();
}

class _ChecklistNameDialogState extends State<ChecklistNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  String? _error;

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Name can\'t be empty');
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.heading),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: 'Name', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
