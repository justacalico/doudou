import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';

import 'hmb_archive.dart';
import 'sync_auth.dart';
import 'sync_codec.dart';
import 'sync_model.dart';

const int kDefaultSyncPort = 8461;
const String kSyncProtocolName = 'doudou-sync';
const int kSyncProtocolVersion = 1;

const String _metaBoxName = '_doudouMeta';
const int _maxBodyBytes = 64 * 1024 * 1024;

/// Hosts the app's Hive boxes over HTTP so every logged in client works on
/// one shared library database. The server stores plain `.hive` files, the
/// same format the in-app backup writes, so `-importdb backup.hmb` seeds it
/// directly and `/api/export.hmb` produces a file the app can restore.
class DoudouSyncServer {
  DoudouSyncServer({required this.dataDir, LoginRateLimiter? rateLimiter})
      : _loginLimiter = rateLimiter ?? LoginRateLimiter();

  final String dataDir;
  final LoginRateLimiter _loginLimiter;

  HttpServer? _http;
  late final Box _meta;
  final _openBoxes = <String, Box>{};
  final _boxLocks = <String, Future<void>>{};
  String? _token;
  String? _passwordHash;
  String? _salt;

  String get dbDir => '$dataDir/db';
  String get token => _token!;
  int get port => _http?.port ?? 0;

  /// The password generated on first run when none was supplied. Null when a
  /// password already existed or was passed in.
  String? generatedPassword;

  Future<void> start({
    int port = kDefaultSyncPort,
    InternetAddress? host,
    String? password,
  }) async {
    Directory(dbDir).createSync(recursive: true);
    Hive.init(dbDir);
    _meta = await Hive.openBox(_metaBoxName);
    _loadOrCreateAuth(password);

    _http = await HttpServer.bind(host ?? InternetAddress.anyIPv4, port);
    _http!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _http?.close(force: true);
    for (final box in _openBoxes.values) {
      await box.close();
    }
    _openBoxes.clear();
    await _meta.close();
  }

  void _loadOrCreateAuth(String? password) {
    final configFile = File('$dataDir/server.json');
    Map<String, Object?> config = {};
    if (configFile.existsSync()) {
      try {
        final text = configFile.readAsStringSync();
        final decoded = text.isEmpty ? null : jsonDecode(text);
        if (decoded is Map) config = Map<String, Object?>.from(decoded);
      } catch (_) {
        config = {};
      }
    }

    _token = config['token'] as String?;
    _salt = config['salt'] as String?;
    _passwordHash = config['passwordHash'] as String?;

    final random = Random.secure();
    _token ??= randomHex(random, 32);
    _salt ??= randomHex(random, 16);

    if (password == null && _passwordHash == null) {
      generatedPassword = _generatePassword(random);
      password = generatedPassword;
    }
    if (password != null) {
      _passwordHash = hashSyncPassword(password, _salt!);
    }
    if (generatedPassword != null) {
      // Keep the generated password recoverable: headless launches have no
      // terminal where the printed password could be read.
      final passwordFile = File('$dataDir/initial-password.txt');
      passwordFile.writeAsStringSync(generatedPassword!);
      if (!Platform.isWindows) {
        Process.runSync('chmod', ['600', passwordFile.path]);
      }
    }

    configFile.writeAsStringSync(jsonEncode({
      'token': _token,
      'salt': _salt,
      'passwordHash': _passwordHash,
    }));
  }

  String _generatePassword(Random random) {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(12, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  bool checkPassword(String password) => _passwordHash != null &&
      verifySyncPassword(password, _salt!, _passwordHash!);

  // -- request handling ----------------------------------------------------

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      await _route(request);
    } catch (e, st) {
      stderr.writeln('[doudou-server] request error: $e\n$st');
      _respond(request, 500, {'error': 'internal server error'});
    }
  }

  Future<void> _route(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    if (method == 'GET' && path == '/api/ping') {
      _respond(request, 200, {
        'name': kSyncProtocolName,
        'version': kSyncProtocolVersion,
      });
      return;
    }

    if (method == 'POST' && path == '/api/login') {
      final clientAddress = request.connectionInfo?.remoteAddress.address ?? '';
      if (_loginLimiter.isLimited(clientAddress)) {
        _respond(request, 429, {'error': 'too many attempts'});
        return;
      }
      final body = await _readJsonBody(request);
      if (body == null) {
        _respond(request, 400, {'error': 'invalid json body'});
        return;
      }
      final password = body['password'];
      if (password is String && checkPassword(password)) {
        _loginLimiter.recordSuccess(clientAddress);
        _respond(request, 200, {'token': _token});
      } else {
        _loginLimiter.recordFailure(clientAddress);
        _respond(request, 401, {'error': 'invalid password'});
      }
      return;
    }

    if (!_authorized(request)) {
      _respond(request, 401, {'error': 'unauthorized'});
      return;
    }

    if (method == 'GET' && path == '/api/boxes') {
      _respond(request, 200, {'boxes': await _listBoxes()});
      return;
    }

    if (method == 'GET' && path == '/api/export.hmb') {
      await _handleExport(request);
      return;
    }

    const boxPrefix = '/api/box/';
    if (path.startsWith(boxPrefix)) {
      final rest = path.substring(boxPrefix.length);
      final slash = rest.indexOf('/');
      final rawName = slash < 0 ? rest : rest.substring(0, slash);
      final name = Uri.decodeComponent(rawName);
      if (!isValidBoxName(name) || name.startsWith('_')) {
        _respond(request, 404, {'error': 'unknown box'});
        return;
      }
      if (method == 'GET' && slash < 0) {
        await _handleGetBox(request, name);
        return;
      }
      if (method == 'POST' && rest.substring(slash + 1) == 'ops') {
        await _handleOps(request, name);
        return;
      }
    }

    _respond(request, 404, {'error': 'not found'});
  }

  bool _authorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || _token == null) return false;
    return constantTimeEquals(
        utf8.encode(header), utf8.encode('Bearer $_token'));
  }

  Future<Map<String, Object?>?> _readJsonBody(HttpRequest request) async {
    if (request.contentLength > _maxBodyBytes) return null;
    String text;
    try {
      text = await utf8.decoder.bind(request).join();
    } catch (_) {
      return null;
    }
    if (text.length > _maxBodyBytes) return null;
    if (text.isEmpty) return {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {}
    return null;
  }

  void _respond(HttpRequest request, int status, Map<String, Object?> body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    request.response.close();
  }

  // -- box storage ---------------------------------------------------------

  Future<Box> _box(String name) async {
    // Hive stores box files lowercased. Route every casing through the first
    // recorded name so we never open the same file as two distinct boxes.
    final metaKey = 'name:${name.toLowerCase()}';
    var canonical = _meta.get(metaKey) as String?;
    if (canonical == null) {
      canonical = name;
      await _meta.put(metaKey, name);
    }
    return _openBoxes[canonical] ??= await Hive.openBox(canonical);
  }

  // Meta keys are lowercased because box file names are: the same box can be
  // reached through different client casings and through .hmb file names.
  int _rev(String box) =>
      (_meta.get('rev:${box.toLowerCase()}') as num?)?.toInt() ?? 0;

  int _baseTs(String box) =>
      (_meta.get('baseTs:${box.toLowerCase()}') as num?)?.toInt() ?? 0;

  Map<String, int> _tsMap(String box) {
    final raw = _meta.get('ts:${box.toLowerCase()}');
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  Map<String, int> _delMap(String box) {
    final raw = _meta.get('del:${box.toLowerCase()}');
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  Future<List<Map<String, Object?>>> _listBoxes() async {
    final dir = Directory(dbDir);
    if (!dir.existsSync()) return [];
    final names = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .where((n) => n.endsWith('.hive'))
        .map((n) => n.substring(0, n.length - '.hive'.length))
        .where((n) => isValidBoxName(n) && !n.startsWith('_'))
        .toList();
    final out = <Map<String, Object?>>[];
    for (final fileName in names) {
      final name = (_meta.get('name:$fileName') as String?) ?? fileName;
      final box = await _box(name);
      out.add({'name': name, 'rev': _rev(name), 'keys': box.length});
    }
    return out;
  }

  Future<void> _handleGetBox(HttpRequest request, String name) async {
    final box = await _box(name);
    final tsMap = _tsMap(name);
    final baseTs = _baseTs(name);
    final entries = <String, Object?>{};
    for (final key in box.keys) {
      final k = key.toString();
      entries[k] = {
        'v': toWireValue(box.get(key)),
        'ts': tsMap[k] ?? baseTs,
      };
    }
    _respond(request, 200, {
      'rev': _rev(name),
      'entries': entries,
      'deleted': _delMap(name),
    });
  }

  /// Serializes writes per box so concurrent clients cannot interleave.
  Future<T> _serialized<T>(String box, Future<T> Function() task) {
    final previous = _boxLocks[box] ?? Future.value();
    final completer = Completer<T>();
    _boxLocks[box] = previous.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _handleOps(HttpRequest request, String name) async {
    final body = await _readJsonBody(request);
    final rawOps = body?['ops'];
    if (rawOps is! List) {
      _respond(request, 400, {'error': 'expected {"ops": [...]}'});
      return;
    }
    final ops = rawOps.map(SyncOp.fromJson).whereType<SyncOp>().toList();

    final result = await _serialized(name.toLowerCase(), () async {
      final box = await _box(name);
      final tsMap = _tsMap(name);
      final delMap = _delMap(name);
      var applied = 0;
      final rejected = <String>[];

      for (final op in ops) {
        final existing = <int>[
          tsMap[op.key] ?? 0,
          delMap[op.key] ?? 0,
        ].reduce(max);
        // Last write wins per key. Equal timestamps lose to whatever is
        // stored so repeats are idempotent.
        if (op.ts <= existing) {
          rejected.add(op.key);
          continue;
        }
        if (op.isDelete) {
          if (box.containsKey(op.key)) await box.delete(op.key);
          tsMap.remove(op.key);
          delMap[op.key] = op.ts;
        } else {
          await box.put(op.key, op.value);
          tsMap[op.key] = op.ts;
          delMap.remove(op.key);
        }
        applied++;
      }

      var rev = _rev(name);
      if (applied > 0) {
        rev++;
        final key = name.toLowerCase();
        await _meta.put('rev:$key', rev);
        await _meta.put('ts:$key', tsMap);
        await _meta.put('del:$key', delMap);
      }
      return {'rev': rev, 'applied': applied, 'rejected': rejected};
    });

    _respond(request, 200, result);
  }

  Future<void> _handleExport(HttpRequest request) async {
    for (final box in _openBoxes.values) {
      await box.compact();
    }
    final temp =
        await Directory.systemTemp.createTemp('doudou_export_');
    try {
      final outPath = '${temp.path}/doudou-backup.hmb';
      final names = await exportHmbFile(dbDir, outPath);
      if (names == null) {
        _respond(request, 404, {'error': 'no data to export'});
        return;
      }
      final bytes = await File(outPath).readAsBytes();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('application', 'zip')
        ..headers.set('Content-Disposition',
            'attachment; filename="doudou-backup.hmb"')
        ..add(bytes);
      await request.response.close();
    } finally {
      await temp.delete(recursive: true);
    }
  }

  /// Imports a `.hmb` backup into the server database. Imported keys keep no
  /// per-key timestamps, so they are stamped with the import time and always
  /// lose against anything a client writes afterwards.
  Future<HmbImportResult> importHmb(String hmbPath) async {
    // Close every hosted box before the .hive files get overwritten so a
    // stale file handle cannot rewrite the imported data on its next write.
    for (final entry in _openBoxes.entries.toList()) {
      await entry.value.close();
      _openBoxes.remove(entry.key);
    }
    final result = importHmbFile(hmbPath, dbDir);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final boxName in result.boxes) {
      // Imported files replace the box wholesale: reset meta so stale
      // timestamps and tombstones from a previous import cannot shadow data.
      final key = boxName.toLowerCase();
      await _meta.delete('ts:$key');
      await _meta.delete('del:$key');
      await _meta.put('baseTs:$key', now);
      await _meta.put('rev:$key', _rev(key) + 1);
    }
    return result;
  }
}
