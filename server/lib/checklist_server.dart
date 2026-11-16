/// The checklist server: runs [ChecklistStore] calls from the web app on the
/// shared database, and tells every connected client when data changes.
library;

import 'dart:async';
import 'dart:convert';

import 'package:checklist_core/checklist_core.dart';
import 'package:checklist_core/protocol.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Requests larger than this are refused. Backups are the largest bodies;
/// this leaves room for many thousands of items.
const maxBodyBytes = 20 * 1024 * 1024;

class ChecklistServer {
  /// Serves [store]. With [requireUser], every request must carry the
  /// `Remote-User` header the login proxy adds; turn it off only for local
  /// development. With [webRoot], also serves the web app's files from that
  /// directory, for development without Caddy.
  ChecklistServer(this.store, {this.requireUser = true, this.webRoot});

  final ChecklistStore store;
  final bool requireUser;
  final String? webRoot;

  final _clients = <WebSocketChannel>{};

  /// The number of clients connected to the events socket.
  int get clientCount => _clients.length;

  late final Handler handler = _buildHandler();

  Handler _buildHandler() {
    final events = webSocketHandler((WebSocketChannel channel, String? _) {
      _clients.add(channel);
      // Clients only listen; the stream ends when they disconnect.
      channel.stream.listen(
        (_) {},
        onDone: () => _clients.remove(channel),
        onError: (_) => _clients.remove(channel),
      );
    }, pingInterval: const Duration(seconds: 25));
    final files = webRoot == null
        ? null
        : createStaticHandler(webRoot!, defaultDocument: 'index.html');

    return (Request request) async {
      final path = request.url.path;
      if (path == 'api/rpc' || path == 'api/events') {
        final refusal = _checkAccess(request);
        if (refusal != null) return refusal;
        if (path == 'api/events') return events(request);
        return _rpc(request);
      }
      if (path.startsWith('api/')) return _error(404, 'notFound', 'Not found');
      if (files != null) return files(request);
      return Response.notFound('Not found');
    };
  }

  /// Rejects requests that didn't come through the login proxy, or that a
  /// page on another site made.
  Response? _checkAccess(Request request) {
    if (requireUser && (request.headers['remote-user'] ?? '').isEmpty) {
      return _error(401, 'unauthorized', 'Not logged in');
    }
    // Browsers send Origin with POSTs and WebSocket handshakes; refuse ones
    // from other sites so they can't act with our login cookie.
    final origin = request.headers['origin'];
    final host = request.headers['host'];
    if (origin != null && Uri.tryParse(origin)?.authority != host) {
      return _error(403, 'forbidden', 'Cross-site request refused');
    }
    return null;
  }

  Future<Response> _rpc(Request request) async {
    if (request.method != 'POST') {
      return _error(405, RpcErrorType.badRequest, 'Use POST');
    }
    if (request.mimeType != 'application/json') {
      return _error(415, RpcErrorType.badRequest, 'Send JSON');
    }

    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > maxBodyBytes) {
        return _error(413, RpcErrorType.badRequest, 'Request too large');
      }
    }

    final String method;
    final Map<String, Object?> args;
    switch (_tryDecode(bytes)) {
      case {'method': final String m, 'args': final Map<String, Object?> a}:
        method = m;
        args = a;
      default:
        return _error(400, RpcErrorType.badRequest, 'Expected {method, args}');
    }

    final Object? result;
    try {
      result = await dispatchRpc(store, method, args);
    } on RpcException catch (e) {
      final status = e.type == RpcErrorType.unknownMethod ? 404 : 400;
      return _error(status, e.type, e.message);
    } on FormatException catch (e) {
      return _error(400, RpcErrorType.format, e.message);
    } catch (e, stackTrace) {
      print('Error in $method: $e\n$stackTrace');
      return _error(500, RpcErrorType.internal, 'Server error');
    }

    if (mutatingMethods.contains(method)) {
      final user = request.headers['remote-user'] ?? '-';
      print('$user: $method');
      _broadcastChange();
    }
    return _json(200, {'result': result});
  }

  void _broadcastChange() {
    final message = jsonEncode({'type': 'changed'});
    for (final client in _clients.toList()) {
      try {
        client.sink.add(message);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  /// Disconnects every client.
  Future<void> close() async {
    for (final client in _clients.toList()) {
      await client.sink.close();
    }
    _clients.clear();
  }

  static Object? _tryDecode(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
  }

  static Response _json(int status, Object? body) => Response(
    status,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  );

  static Response _error(int status, String type, String message) =>
      _json(status, {
        'error': {'type': type, 'message': message},
      });
}
