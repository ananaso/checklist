import 'package:checklist_core/checklist_core.dart';
import 'package:web/web.dart' as web;

/// Connects to the checklist server the page was loaded from.
ChecklistStore openStore() {
  return RemoteChecklistStore(
    Uri.base.resolve('api/'),
    onUnauthorized: _reloadToLogIn,
  );
}

const _lastReloadKey = 'checklist.unauthorizedReloadAt';

/// Reloads the page, which the login proxy redirects to its login page when
/// the login has expired.
///
/// If the server still refuses right after such a reload, reloading again
/// would loop forever (e.g. a misconfigured proxy), so it only reloads once a
/// minute.
void _reloadToLogIn() {
  final storage = web.window.sessionStorage;
  final now = DateTime.now().millisecondsSinceEpoch;
  final last = int.tryParse(storage.getItem(_lastReloadKey) ?? '') ?? 0;
  if (now - last < const Duration(minutes: 1).inMilliseconds) return;
  storage.setItem(_lastReloadKey, '$now');
  web.window.location.reload();
}
