import 'dart:io';

import 'package:args/args.dart';
import 'package:checklist_core/checklist_core.dart';
import 'package:checklist_server/checklist_server.dart';
import 'package:drift/native.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'listen',
      help: 'Address and port to listen on.',
      defaultsTo: '127.0.0.1:8090',
    )
    ..addOption(
      'database',
      help: 'Path of the SQLite database file (created if missing).',
      mandatory: true,
    )
    ..addOption(
      'web-root',
      help: 'Also serve the web app from this directory (for development).',
    )
    ..addFlag(
      'no-auth',
      negatable: false,
      help:
          'Accept requests without the Remote-User header the login proxy '
          'adds. Development only; requires a loopback --listen address.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults options;
  try {
    options = parser.parse(arguments);
    if (options.flag('help')) {
      print(parser.usage);
      return;
    }
  } on ArgParserException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    exit(64);
  }

  final listen = options.option('listen')!;
  final separator = listen.lastIndexOf(':');
  final host = separator < 0 ? null : listen.substring(0, separator);
  final port = separator < 0
      ? null
      : int.tryParse(listen.substring(separator + 1));
  if (host == null || port == null) {
    stderr.writeln('--listen must look like 127.0.0.1:8090');
    exit(64);
  }
  final address = InternetAddress.tryParse(host);
  final noAuth = options.flag('no-auth');
  if (noAuth && !(address?.isLoopback ?? host == 'localhost')) {
    stderr.writeln(
      '--no-auth is only allowed with a loopback --listen address',
    );
    exit(64);
  }

  final file = File(options.option('database')!);
  final database = AppDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Readers don't block the writer, and a crash can't corrupt the file.
        db.execute('PRAGMA journal_mode = WAL');
        db.execute('PRAGMA busy_timeout = 5000');
      },
    ),
  );
  // Open (and migrate) now, so a broken database fails at startup.
  await database.customSelect('SELECT 1').get();

  final server = ChecklistServer(
    database,
    requireUser: !noAuth,
    webRoot: options.option('web-root'),
  );
  final http = await shelf_io.serve(
    const Pipeline().addMiddleware(logRequests()).addHandler(server.handler),
    address ?? host,
    port,
  );
  print(
    'Checklist server listening on ${http.address.host}:${http.port}, '
    'database ${file.absolute.path}'
    '${noAuth ? ' (no auth: development only)' : ''}',
  );

  Future<void> shutDown(ProcessSignal signal) async {
    print('Shutting down ($signal)');
    await http.close();
    await server.close();
    await database.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().first.then(shutDown);
  ProcessSignal.sigterm.watch().first.then(shutDown);
}
