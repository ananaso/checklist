import 'package:checklist/checklists_screen.dart';
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
      home: const ChecklistsScreen(),
    );
  }
}
