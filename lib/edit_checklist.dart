import 'package:flutter/material.dart';

class EditChecklist extends StatelessWidget {
  const EditChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Edit Checklist'),
      ),
      body: const Center(child: Text('edit view')),
    );
  }
}
