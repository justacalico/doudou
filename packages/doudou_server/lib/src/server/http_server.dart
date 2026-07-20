import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../api/protocol.dart';
import '../storage/database.dart';
import 'auth.dart';

/// Runs the REST API. Routes are grouped under /api/v1. The health endpoint
/// is unauthenticated so the CLI's `-health` command can probe it without a
/// password.
class DoudouHttpServer {
  DoudouHttpServer({
    required this.db,
    required this.auth,
    required this.host,
    required this.port,
  });

  final DoudouServerDatabase db;
  final AuthMiddleware auth;
  final String host;
  final int port;

  HttpServer? _server;
  final _activeClients = <String, String>{}; // clientId -> name (in-memory)

  Future<int> start() async {
    _server = await HttpServer.bind(host, port);
    _server!.autoCompress = true;
    unawaited(_loop());
    return _server!.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  int get boundPort => _server?.port ?? port;

  Future<void> _loop() async {
    final server = _server;
    if (server == null) return;
    await for (final req in server) {
      try {
        await _dispatch(req);
      } catch (e, st) {
        _error(req, HttpStatus.internalServerError, '$e\n$st');
      } finally {
        await req.response.close();
      }
    }
  }

  Future<void> _dispatch(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method;

    // Health is unauthenticated.
    if (path == '/api/v1/health' && method == 'GET') {
      _json(req, {'status': 'ok', 'version': 1});
      return;
    }

    // Everything else requires auth.
    if (!await auth.handle(req)) return;

    if (path == '/api/v1/servers' && method == 'GET') {
      await _listServers(req);
    } else if (path == '/api/v1/servers' && method == 'PUT') {
      await _upsertServer(req);
    } else if (path.startsWith('/api/v1/servers/') && method == 'DELETE') {
      await _deleteServer(req, path.substring('/api/v1/servers/'.length));
    } else if (path == '/api/v1/snapshots' && method == 'GET') {
      await _listSnapshots(req);
    } else if (path == '/api/v1/snapshots' && method == 'PUT') {
      await _pushSnapshot(req);
    } else if (path == '/api/v1/snapshots' && method == 'GET') {
      await _listSnapshots(req);
    } else if (path == '/api/v1/clients/register' && method == 'POST') {
      await _registerClient(req);
    } else {
      _error(req, HttpStatus.notFound, 'not found: $method $path');
    }
  }

  // -- routes -------------------------------------------------------------

  Future<void> _listServers(HttpRequest req) async {
    final rows = await db.listMusicServers();
    _json(req, rows
        .map((r) => MusicServerDto(
              id: r.id,
              name: r.name,
              type: r.type,
              url: r.url,
              isDefault: r.isDefault,
            ).toJson())
        .toList());
  }

  Future<void> _upsertServer(HttpRequest req) async {
    final body = await _readJson(req);
    final dto = MusicServerDto.fromJson(body);
    await db.upsertMusicServer(MusicServersCompanion.insert(
      id: dto.id,
      name: dto.name,
      type: dto.type,
      url: dto.url,
      isDefault: Value(dto.isDefault),
      updatedAt: DateTime.now().toUtc(),
    ));
    _json(req, dto.toJson());
  }

  Future<void> _deleteServer(HttpRequest req, String id) async {
    await db.deleteMusicServer(id);
    _json(req, {'deleted': id});
  }

  Future<void> _listSnapshots(HttpRequest req) async {
    final serverId = req.uri.queryParameters['musicServerId'];
    if (serverId == null) {
      _error(req, HttpStatus.badRequest, 'missing musicServerId');
      return;
    }
    final rows = await db.listSnapshots(serverId);
    _json(req, rows
        .map((r) => SnapshotDto(
              musicServerId: r.musicServerId,
              kind: r.kind,
              version: r.version,
              updatedAtMs: r.updatedAt.millisecondsSinceEpoch,
              payload: r.payload,
            ).toJson())
        .toList());
  }

  Future<void> _pushSnapshot(HttpRequest req) async {
    final body = await _readJson(req);
    final dto = SnapshotDto.fromJson(body);
    final existing = await db.getSnapshot(dto.musicServerId, dto.kind);
    // Server is source of truth: accept the push if the client's version is
    // newer than what we have, or if we have nothing yet.
    if (existing != null && dto.version <= existing.version) {
      _json(req, {
        'accepted': false,
        'version': existing.version,
        'reason': 'stale',
      });
      return;
    }
    final nextVersion = dto.version == 0
        ? (existing?.version ?? 0) + 1
        : dto.version;
    await db.saveSnapshot(
      musicServerId: dto.musicServerId,
      kind: dto.kind,
      payload: dto.payload,
      version: nextVersion,
    );
    _json(req, {'accepted': true, 'version': nextVersion});
  }

  Future<void> _registerClient(HttpRequest req) async {
    final body = await _readJson(req);
    final id = body['id'] as String? ?? '';
    final name = body['name'] as String? ?? 'client';
    if (id.isEmpty) {
      _error(req, HttpStatus.badRequest, 'missing id');
      return;
    }
    await db.touchClient(id, name);
    _activeClients[id] = name;
    _json(req, {'registered': id});
  }

  // -- helpers ------------------------------------------------------------

  Future<Map<String, dynamic>> _readJson(HttpRequest req) async {
    final raw = await req.fold<String>('', (acc, chunk) => acc + utf8.decode(chunk));
    if (raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void _json(HttpRequest req, Object? body) {
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }

  void _error(HttpRequest req, int status, String message) {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': message}));
  }
}
