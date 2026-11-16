import 'package:checklist_core/checklist_core.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the on-device database.
ChecklistStore openStore() {
  return AppDatabase(
    driftDatabase(
      name: 'app_database',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
    // Opt-in schema reset for debug runs while iterating on the tables:
    // flutter run --dart-define=RESET_DB=true
    resetOnOpen: kDebugMode && const bool.fromEnvironment('RESET_DB'),
  );
}
