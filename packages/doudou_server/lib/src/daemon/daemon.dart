import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../server/auth.dart';
import '../server/http_server.dart';
import '../storage/database.dart';

/// Runs the server in the foreground. While running, a small JSON state file
/// (the "pid file") is written to the support dir so other CLI invocations can
/// find the bound port and talk to the control endpoint. The control endpoint
/// lives on the same HTTP server as the sync API, under /api/v1/control/* and
/// protected by the shared password (except /health which is open).
class DoudouDaemon {
  DoudouDaemon({required this.host, required this.port});

  final String host;
  final int port;

  late final DoudouServerDatabase db;
  late final AuthMiddleware auth;
  late final DoudouHttpServer http;

  Future<void> run() async {
    db = DoudouServerDatabase();
    auth = AuthMiddleware(db);
    http = DoudouHttpServer(db: db, auth: auth, host: host, port: port);

    final boundPort = await http.start();
    final stateFile = await _stateFilePath();
    await _writeState(stateFile, boundPort);

    // Re-write the state file periodically so the bound port stays current
    // and the file mtime reflects liveness.
    final keepalive = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _writeState(stateFile, boundPort),
    );

    final stopCompleter = Completer<void>();

    // Watch for a stop signal file written by `doudou-server -stop`.
    final stopWatcher = _watchStopSignal(stateFile, stopCompleter);

    // Stop on SIGINT everywhere. SIGTERM only exists on non-Windows.
    final sigint = ProcessSignal.sigint.watch().listen((_) {
      if (!stopCompleter.isCompleted) stopCompleter.complete();
    });
    StreamSubscription<ProcessSignal>? sigterm;
    if (!Platform.isWindows) {
      sigterm = ProcessSignal.sigterm.watch().listen((_) {
        if (!stopCompleter.isCompleted) stopCompleter.complete();
      });
    }

    stdout.writeln('doudou-server listening on $host:$boundPort');
    stdout.writeln('state file: ${stateFile.path}');
    stdout.writeln('press Ctrl+C or run `doudou-server -stop` to stop');

    await stopCompleter.future;

    keepalive.cancel();
    await stopWatcher.cancel();
    await sigint.cancel();
    await sigterm?.cancel();
    await http.stop();
    await db.close();
    try {
      if (stateFile.existsSync()) stateFile.deleteSync();
    } catch (_) {}
    stdout.writeln('doudou-server stopped');
  }

  Future<File> _stateFilePath() async {
    final dir = await getApplicationSupportDirectory();
    final stateDir = Directory(p.join(dir.path, 'doudou_server'));
    if (!stateDir.existsSync()) stateDir.createSync(recursive: true);
    return File(p.join(stateDir.path, 'server.json'));
  }

  Future<void> _writeState(File file, int boundPort) async {
    final state = {
      'pid': pid,
      'host': host,
      'port': boundPort,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await file.writeAsString(jsonEncode(state));
  }

  StreamSubscription<FileSystemEvent> _watchStopSignal(
    File stateFile,
    Completer<void> stopCompleter,
  ) {
    final dir = stateFile.parent;
    final stopFile = File(p.join(dir.path, 'stop.flag'));
    final watcher = dir.watch().where((event) {
      return event.type == FileSystemEvent.create &&
          event.path == stopFile.path;
    }).listen((_) {
      stopFile.deleteSync();
      if (!stopCompleter.isCompleted) stopCompleter.complete();
    });
    return watcher;
  }
}

/// Reads the state file written by a running daemon. Returns null if no daemon
/// appears to be running.
Future<ServerState?> readServerState() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'doudou_server', 'server.json'));
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return ServerState(
      pid: json['pid'] as int? ?? 0,
      host: json['host'] as String? ?? '127.0.0.1',
      port: json['port'] as int? ?? 0,
      startedAt: json['startedAt'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}

/// Writes a stop.flag file in the daemon's state dir so its watcher picks it
/// up and shuts down cleanly.
Future<bool> signalStop() async {
  final state = await readServerState();
  if (state == null) return false;
  final dir = await getApplicationSupportDirectory();
  final stopFile = File(p.join(dir.path, 'doudou_server', 'stop.flag'));
  stopFile.writeAsStringSync(DateTime.now().toUtc().toIso8601String());
  return true;
}

class ServerState {
  ServerState({
    required this.pid,
    required this.host,
    required this.port,
    required this.startedAt,
  });

  final int pid;
  final String host;
  final int port;
  final String startedAt;
}
