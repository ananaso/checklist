import 'package:checklist/checklist.dart';
import 'package:checklist/edit_checklist.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database.dart' as db;
import 'database/database.dart' show AppDatabase;

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(
          create: (context) => AppDatabase(),
          dispose: (context, db) => db.close(),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checklist',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Checklist'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// The list being shown. Until lists can be created/chosen, it's the first.
  late final Future<db.Checklist> _checklist = Provider.of<AppDatabase>(
    context,
    listen: false,
  ).getFirstChecklist();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checklist,
      builder: (context, snapshot) {
        final checklist = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(checklist?.title ?? widget.title),
            actions: [
              if (checklist != null)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit list',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          EditChecklist(checklistId: checklist.id),
                    ),
                  ),
                ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: checklist == null
                  ? const CircularProgressIndicator()
                  : Checklist(checklistId: checklist.id),
            ),
          ),
          floatingActionButton: FloatingActionButton(onPressed: () {}),
        );
      },
    );
  }
}
