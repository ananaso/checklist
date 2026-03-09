import 'package:checklist/checklist.dart';
import 'package:checklist/checklist_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(
          create: (context) => AppDatabase(),
          dispose: (context, db) => db.close(),
        ),
        ChangeNotifierProvider(create: (context) => ChecklistModel()),
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
  late AppDatabase database;

  late Stream<List<ChecklistItem>> checklistItems;

  // TODO: how do we add a new item?
  //  When User clicks the plus button
  //  Then an empty TextField is added after any other items in the list
  //  Perhaps this first view is the "edit" view of a checklist
  void _addItem() {
    // setState(() {
    //   items.add(Item());
    // });
  }

  @override
  void initState() {
    super.initState();
    database = Provider.of<AppDatabase>(context, listen: false);
    checklistItems = database.select(database.checklistItems).watch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsetsGeometry.all(32),
          child: Checklist(items: checklistItems),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }
}
