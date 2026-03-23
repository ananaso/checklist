import 'package:checklist/checklist.dart';
import 'package:checklist/checklist_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database.dart';

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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(padding: EdgeInsetsGeometry.all(32), child: Checklist()),
      ),
    );
  }
}
