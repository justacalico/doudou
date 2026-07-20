import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../daemon/daemon.dart';
import '../server/auth.dart';
import '../storage/database.dart';
import 'args.dart';

/// Dispatches a parsed [CliCommand] to its implementation.
Future<void> runCommand(CliCommand cmd) async {
  switch (cmd.kind) {
    case CliKind.start:
      await _start(cmd);
      break;
    case CliKind.stop:
      await _stop();
      break;
    case CliKind.clients:
      await _clients();
      break;
    case CliKind.status:
      await _status();
      break;
    case CliKind.health:
      await _health();
      break;
    case CliKind.setLogin:
      await _setLogin(cmd);
      break;
    case CliKind.help:
      // Help is already printed by the parser.
      break;
  }
}

Future<void> _start(CliCommand cmd) async {
  final state = await readServerState();
  if (state != null && state.port != 0) {
    // Best-effort liveness check: if the health endpoint answers, refuse to
    // start a second instance.
    if (await _probe(state.host, state.port)) {
      stderr.writeln(
        'doudou-server already running on ${state.host}:${state.port} (pid ${state.pid})',
      );
      exit(1);
    }
  }
  final daemon = DoudouDaemon(
    host: cmd.host ?? '0.0.0.0',
    port: cmd.port ?? 7427,
  );
  await daemon.run();
}

Future<void> _stop() async {
  final ok = await signalStop();
  if (!ok) {
    stderr.writeln('no running doudou-server found');
    exit(1);
  }
  stdout.writeln('stop signal sent');
}

Future<void> _clients() async {
  final db = DoudouServerDatabase();
  try {
    final rows = await db.listClients();
    if (rows.isEmpty) {
      stdout.writeln('no clients have synced yet');
      return;
    }
    stdout.writeln('${rows.length} client(s):');
    for (final r in rows) {
      stdout.writeln(
        '  ${r.id}  ${r.name}  firstSeen=${r.firstSeen.toIso8601String()}  lastSeen=${r.lastSeen.toIso8601String()}',
      );
    }
  } finally {
    await db.close();
  }
}

Future<void> _status() async {
  final state = await readServerState();
  final db = DoudouServerDatabase();
  try {
    final servers = await db.listMusicServers();
    final clients = await db.listClients();
    final pwHash = await db.getSetting('auth.passwordHash');

    stdout.writeln('doudou-server status');
    if (state == null) {
      stdout.writeln('  running: no');
    } else {
      stdout.writeln('  running: yes');
      stdout.writeln('  pid: ${state.pid}');
      stdout.writeln('  listen: ${state.host}:${state.port}');
      stdout.writeln('  startedAt: ${state.startedAt}');
    }
    stdout.writeln('  password set: ${pwHash != null}');
    stdout.writeln('  music servers: ${servers.length}');
    for (final s in servers) {
      stdout.writeln('    - ${s.name} [${s.type}] ${s.url}');
    }
    stdout.writeln('  clients: ${clients.length}');
  } finally {
    await db.close();
  }
}

Future<void> _health() async {
  final state = await readServerState();
  if (state == null) {
    stderr.writeln('no running doudou-server found');
    exit(1);
  }
  final ok = await _probe(state.host, state.port);
  if (ok) {
    stdout.writeln('healthy: ${state.host}:${state.port}');
  } else {
    stderr.writeln('unhealthy: ${state.host}:${state.port} not responding');
    exit(1);
  }
}

Future<void> _setLogin(CliCommand cmd) async {
  final db = DoudouServerDatabase();
  try {
    final auth = AuthMiddleware(db);
    await auth.setPassword(cmd.password ?? '');
    if (cmd.username != null && cmd.username!.isNotEmpty) {
      await db.putSetting('auth.username', cmd.username!);
    }
    stdout.writeln('login updated');
  } finally {
    await db.close();
  }
}

Future<bool> _probe(String host, int port) async {
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://$host:$port/api/v1/health'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close(force: true);
    return res.statusCode == 200 && body.contains('"status":"ok"');
  } catch (_) {
    return false;
  }
}
