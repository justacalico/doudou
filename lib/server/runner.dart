import 'dart:async';
import 'dart:io';

import 'doudou_server.dart';
import 'hmb_archive.dart';

/// Command line entry for the headless sync server. Works both when the app
/// binary is started with `-server` and through `dart run bin/doudou_server.dart`.
///
/// Usage:
///   doudou -server [options]
///
/// Options:
///   -importdb <path>   import a .hmb backup into the server database
///   --port <n>         port to listen on (default 8461)
///   --bind <address>   address to bind (default 0.0.0.0)
///   --data-dir <path>  server data directory (default ~/.doudou-server)
///   --password <pw>    set or replace the login password
///   -h, --help         show this help
Future<void> runDoudouServer(List<String> args) async {
  final parsed = parseServerArgs(args);
  if (parsed == null) {
    stdout.writeln(_usage);
    exit(1);
  }
  if (parsed.help) {
    stdout.writeln(_usage);
    exit(0);
  }

  final server = DoudouSyncServer(dataDir: parsed.dataDir);

  try {
    await server.start(
      port: parsed.port,
      host: _resolveHost(parsed.bind),
      password: parsed.password ?? _promptForPassword(parsed.dataDir),
    );
  } on SocketException catch (e) {
    stderr.writeln('Could not start server on port ${parsed.port}: '
        '${e.message}');
    exit(1);
  }

  for (final hmbPath in parsed.imports) {
    try {
      final result = await server.importHmb(hmbPath);
      stdout.writeln('Imported ${result.boxes.length} boxes from $hmbPath: '
          '${result.boxes.join(', ')}');
      if (result.skipped.isNotEmpty) {
        stdout.writeln('Skipped ${result.skipped.length} non-database '
            'entries inside the archive');
      }
    } on HmbImportException catch (e) {
      stderr.writeln('Import failed: ${e.message}');
    }
  }

  _printBanner(server, parsed);

  final shutdown = Completer<void>();
  final subscriptions = <StreamSubscription>[
    ProcessSignal.sigint.watch().listen((_) => shutdown.complete()),
    if (!Platform.isWindows)
      ProcessSignal.sigterm.watch().listen((_) => shutdown.complete()),
  ];
  await shutdown.future;
  for (final sub in subscriptions) {
    await sub.cancel();
  }
  stdout.writeln('\nShutting down...');
  await server.stop();
  // Under a desktop embedder the native host outlives main(), so the process
  // must be ended explicitly for the CLI to actually terminate.
  exit(0);
}

String? _promptForPassword(String dataDir) {
  // Only prompt when this is a first run (no stored password) on a terminal.
  final configFile = File('$dataDir/server.json');
  if (configFile.existsSync() || !stdin.hasTerminal) return null;
  stdout.write('Choose a password for the sync server: ');
  final first = stdin.readLineSync() ?? '';
  if (first.isEmpty) return null;
  stdout.write('Repeat the password: ');
  final second = stdin.readLineSync() ?? '';
  if (first != second) {
    stderr.writeln('Passwords did not match, a random one was generated.');
    return null;
  }
  return first;
}

void _printBanner(DoudouSyncServer server, ServerArgs parsed) {
  stdout.writeln('');
  stdout.writeln('Doudou sync server is running.');
  if (server.generatedPassword != null) {
    stdout.writeln('Generated server password: ${server.generatedPassword}');
    stdout.writeln('Store it somewhere safe, clients need it to log in.');
  }
  stdout.writeln('Connect from the app under Settings > Servers > Device sync');
  stdout.writeln('using one of these addresses:');
  NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  ).then((interfaces) {
    final addresses = interfaces
        .expand((i) => i.addresses)
        .where((a) => !a.isLoopback)
        .map((a) => a.address)
        .toList();
    if (addresses.isEmpty) {
      stdout.writeln('  http://127.0.0.1:${server.port}');
    }
    for (final address in addresses) {
      stdout.writeln('  http://$address:${server.port}');
    }
  });
}

InternetAddress _resolveHost(String bind) {
  if (bind == '0.0.0.0' || bind == 'any') return InternetAddress.anyIPv4;
  if (bind == '::' || bind == 'any6') return InternetAddress.anyIPv6;
  return InternetAddress(bind);
}

/// Whether the process was asked to run in server mode.
bool isServerInvocation(List<String> args) => args.contains('-server');

class ServerArgs {
  ServerArgs({
    required this.dataDir,
    required this.port,
    required this.bind,
    required this.imports,
    this.password,
    this.help = false,
  });

  final String dataDir;
  final int port;
  final String bind;
  final List<String> imports;
  final String? password;
  final bool help;
}

ServerArgs? parseServerArgs(List<String> args) {
  var dataDir =
      '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.'}'
      '/.doudou-server';
  var port = kDefaultSyncPort;
  var bind = '0.0.0.0';
  final imports = <String>[];
  String? password;
  var help = false;

  String? valueAfter(int i) => i + 1 < args.length ? args[i + 1] : null;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '-server':
        break; // marker flag, nothing to do
      case '-importdb':
        final path = valueAfter(i);
        if (path == null) return null;
        imports.add(path);
        i++;
      case '--port' || '-port' || '-p':
        final value = int.tryParse(valueAfter(i) ?? '');
        if (value == null || value <= 0 || value > 65535) return null;
        port = value;
        i++;
      case '--bind' || '-bind':
        final value = valueAfter(i);
        if (value == null) return null;
        bind = value;
        i++;
      case '--data-dir' || '-data-dir' || '-d':
        final value = valueAfter(i);
        if (value == null) return null;
        dataDir = value;
        i++;
      case '--password' || '-password':
        final value = valueAfter(i);
        if (value == null) return null;
        password = value;
        i++;
      case '-h' || '--help':
        help = true;
      default:
        if (arg.startsWith('-')) return null;
    }
  }
  return ServerArgs(
    dataDir: dataDir,
    port: port,
    bind: bind,
    imports: imports,
    password: password,
    help: help,
  );
}

const String _usage = '''
doudou -server [options]

Runs a headless doudou sync server. Clients connect from the app under
Settings > Servers > Device sync and share one library database.

Options:
  -importdb <path>   import a .hmb backup into the server database
  --port <n>         port to listen on (default $kDefaultSyncPort)
  --bind <address>   address to bind (default 0.0.0.0)
  --data-dir <path>  server data directory (default ~/.doudou-server)
  --password <pw>    set or replace the login password
  -h, --help         show this help
''';
