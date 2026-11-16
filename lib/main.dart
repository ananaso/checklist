import 'package:checklist/checklists_screen.dart';
import 'package:checklist_core/checklist_core.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'store/open_store.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<ChecklistStore>(
          create: (context) => openStore(),
          dispose: (context, store) => store.close(),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Phones drop the live-update connection of backgrounded apps, so catch
    // up on return.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final store = Provider.of<ChecklistStore>(context, listen: false);
        if (store is RemoteChecklistStore) store.refresh();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'Checklist',
          scrollBehavior: const NoStretchScrollBehavior(),
          theme: ThemeData(
            colorScheme:
                lightDynamic ??
                ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          darkTheme: ThemeData(
            colorScheme:
                darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
          ),
          home: const ChecklistsScreen(),
        );
      },
    );
  }
}
