/// Opens the app's [ChecklistStore]: a local database on Android, the
/// checklist server on the web.
library;

export 'open_store_native.dart'
    if (dart.library.js_interop) 'open_store_web.dart';
