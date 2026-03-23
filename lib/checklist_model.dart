import 'dart:collection';

import 'package:checklist/database/database.dart';
import 'package:flutter/foundation.dart';

class ChecklistModel extends ChangeNotifier {
  /// Internal, private state of the checklist.
  final List<ChecklistItem> _items = [];

  /// An unmodifiable view of the items in the checklist.
  UnmodifiableListView<ChecklistItem> get items => UnmodifiableListView(_items);

  /// Adds [item] to checklist. This and [removeAll] are the only ways to modify the
  /// checklist from the outside.
  void add(ChecklistItem item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  /// Removes all items from the checklist.
  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }
}
