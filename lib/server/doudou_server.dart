import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';

import '../models/server.dart';
import 'hmb_archive.dart';
import 'hosted_backends.dart';
import 'server_log.dart';
import 'sync_auth.dart';
import 'sync_boxes.dart';
import 'sync_codec.dart';
import 'sync_model.dart';
import 'webui_bundle.dart';

const int kDefaultSyncPort = 8461;
const String kSyncProtocolName = 'doudou-sync';
const int kSyncProtocolVersion = 1;

const String _metaBoxName = '_doudouMeta';
const int _maxBodyBytes = 64 * 1024 * 1024;
const int _maxImportBytes = 512 * 1024 * 1024;

/// Hosts the app's Hive boxes over HTTP so every logged in client works on
/// one shared library database. The server stores plain `.hive` files, the
/// same format the in-app backup writes, so `-importdb backup.hmb` seeds it
/// directly and `/api/export.hmb` produces a file the app can restore.
///
/// It also keeps a list of backends in the `DoudouBackends` box. Connected
/// clients read them through `/api/backends` and add them to their server
/// list, so the box stays inside `.hmb` backups while never being writable
/// through the generic box endpoints.
///
/// The web UI is served under `/app`: the Flutter web build embedded in
/// [kWebuiBundle] plus a small JSON api guarded by its own session tokens.
/// On first run (no user chosen password yet) `/app/api/setup` lets the UI
/// claim the server; afterwards a password login is required and the
/// password can be changed from the dashboard.
class DoudouSyncServer {
  DoudouSyncServer(
      {required this.dataDir, LoginRateLimiter? rateLimiter, ServerLog? log})
      : _loginLimiter = rateLimiter ?? LoginRateLimiter(),
        log = log ?? ServerLog();

  final String dataDir;
  final LoginRateLimiter _loginLimiter;
  final ServerLog log;

  HttpServer? _http;
  late final Box _meta;
  late Box _backends;
  final _openBoxes = <String, Box>{};
  final _boxLocks = <String, Future<void>>{};
  final _webuiSessions = <String, DateTime>{};
  final _fileCache = <String, List<int>>{};
  String? _token;
  String? _passwordHash;
  String? _salt;
  bool _passwordSet = false;
  late final DateTime _startedAt;

  /// The box that lists every backend handed out to clients. Kept as a
  /// normal `.hive` file so it travels inside `.hmb` backups, but it is
  /// reserved: the generic box endpoints refuse it so entries can only
  /// change through the validated api.
  static const String hostedBackendsBoxName = 'DoudouBackends';
  static const _sessionTtl = Duration(days: 7);

  String get dbDir => '$dataDir/db';
  String get token => _token!;
  int get port => _http?.port ?? 0;

  /// True once a human picked the server password (flag, prompt or web UI).
  /// While false the web UI offers first run setup.
  bool get passwordIsChosen => _passwordSet;

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
    _backends = await Hive.openBox(hostedBackendsBoxName);
    _loadOrCreateAuth(password);

    _http = await HttpServer.bind(host ?? InternetAddress.anyIPv4, port);
    _http!.listen(_handleRequest);
    _startedAt = DateTime.now();
    log.info('listening on ${_http!.address.address}:${_http!.port} '
        '(data dir $dataDir)');
    if (!_passwordSet) {
      log.info('no password chosen yet, open http://<host>:${_http!.port}/app/ '
          'to set one');
    }
  }

  Future<void> stop() async {
    await _http?.close(force: true);
    for (final box in _openBoxes.values) {
      await box.close();
    }
    _openBoxes.clear();
    await _backends.close();
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
    // Installs that predate the flag already carry a usable password, so a
    // missing entry counts as chosen and never reopens web UI setup.
    _passwordSet = config['passwordSet'] as bool? ?? (_passwordHash != null);

    final random = Random.secure();
    _token ??= randomHex(random, 32);
    _salt ??= randomHex(random, 16);

    if (password == null && _passwordHash == null) {
      generatedPassword = _generatePassword(random);
      password = generatedPassword;
    }
    if (password != null) {
      _passwordHash = hashSyncPassword(password, _salt!);
      if (password != generatedPassword) _passwordSet = true;
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

    _saveConfig(configFile);
  }

  void _saveConfig([File? configFile]) {
    (configFile ?? File('$dataDir/server.json')).writeAsStringSync(jsonEncode({
      'token': _token,
      'salt': _salt,
      'passwordHash': _passwordHash,
      'passwordSet': _passwordSet,
    }));
  }

  String _generatePassword(Random random) {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  bool checkPassword(String password) =>
      _passwordHash != null &&
      verifySyncPassword(password, _salt!, _passwordHash!);

  /// Replaces the server password. A fresh salt keeps old hashes useless;
  /// the sync token survives so connected clients keep working.
  void setPassword(String password) {
    _salt = randomHex(Random.secure(), 16);
    _passwordHash = hashSyncPassword(password, _salt!);
    _passwordSet = true;
    _saveConfig();
  }

  // -- request handling ----------------------------------------------------

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      await _route(request);
    } catch (e, st) {
      log.error('request error: $e\n$st');
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
        log.info('client logged in from $clientAddress');
        _respond(request, 200, {'token': _token});
      } else {
        _loginLimiter.recordFailure(clientAddress);
        log.warn('sync login failed from $clientAddress');
        _respond(request, 401, {'error': 'invalid password'});
      }
      return;
    }

    if (method == 'GET' && path == '/') {
      request.response
        ..statusCode = HttpStatus.movedPermanently
        ..headers.set(HttpHeaders.locationHeader, '/app/');
      await request.response.close();
      return;
    }

    if (path == '/app' || path.startsWith('/app/')) {
      await _routeWebui(request, path);
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

    if (method == 'GET' && path == '/api/backends') {
      _respond(
          request, 200, {'rev': _backendsRev(), 'backends': _listBackends()});
      return;
    }

    const boxPrefix = '/api/box/';
    if (path.startsWith(boxPrefix)) {
      final rest = path.substring(boxPrefix.length);
      final slash = rest.indexOf('/');
      final rawName = slash < 0 ? rest : rest.substring(0, slash);
      final name = Uri.decodeComponent(rawName);
      if (!isValidBoxName(name) ||
          name.startsWith('_') ||
          name.toLowerCase() == hostedBackendsBoxName.toLowerCase()) {
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

  // -- web ui --------------------------------------------------------------

  Future<void> _routeWebui(HttpRequest request, String path) async {
    if (path.startsWith('/app/api/')) {
      await _routeWebuiApi(request, path.substring('/app/api'.length));
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      _respond(request, 405, {'error': 'method not allowed'});
      return;
    }
    _serveStatic(request, path);
  }

  Future<void> _routeWebuiApi(HttpRequest request, String sub) async {
    final method = request.method;
    final clientAddress = request.connectionInfo?.remoteAddress.address ?? '';

    if (method == 'GET' && sub == '/state') {
      _respond(request, 200, {
        'name': kSyncProtocolName,
        'version': kSyncProtocolVersion,
        'setupRequired': !_passwordSet,
        'uptime': DateTime.now().difference(_startedAt).inSeconds,
      });
      return;
    }

    if (method == 'POST' && sub == '/login') {
      if (_loginLimiter.isLimited(clientAddress)) {
        _respond(request, 429, {'error': 'too many attempts'});
        return;
      }
      final body = await _readJsonBody(request);
      final password = body?['password'];
      if (password is String && checkPassword(password)) {
        _loginLimiter.recordSuccess(clientAddress);
        log.info('web ui login from $clientAddress');
        _respond(request, 200, {'token': _newWebuiSession()});
      } else {
        _loginLimiter.recordFailure(clientAddress);
        log.warn('web ui login failed from $clientAddress');
        _respond(request, 401, {'error': 'invalid password'});
      }
      return;
    }

    if (method == 'POST' && sub == '/setup') {
      if (_passwordSet) {
        _respond(request, 409, {'error': 'password already set'});
        return;
      }
      if (_loginLimiter.isLimited(clientAddress)) {
        _respond(request, 429, {'error': 'too many attempts'});
        return;
      }
      final body = await _readJsonBody(request);
      final password = body?['password'];
      if (password is! String || password.isEmpty) {
        _loginLimiter.recordFailure(clientAddress);
        _respond(request, 400, {'error': 'password is required'});
        return;
      }
      setPassword(password);
      _loginLimiter.recordSuccess(clientAddress);
      log.info('password set from the web ui ($clientAddress)');
      _respond(request, 200, {'token': _newWebuiSession()});
      return;
    }

    if (!_webuiAuthorized(request)) {
      _respond(request, 401, {'error': 'unauthorized'});
      return;
    }

    if (method == 'POST' && sub == '/logout') {
      _webuiSessions.remove(_bearerToken(request));
      _respond(request, 200, {});
      return;
    }

    if (method == 'POST' && sub == '/password') {
      final body = await _readJsonBody(request);
      final current = body?['current'];
      final next = body?['next'];
      if (current is! String || next is! String || next.isEmpty) {
        _respond(request, 400, {'error': 'current and next are required'});
        return;
      }
      if (!checkPassword(current)) {
        _respond(request, 401, {'error': 'invalid password'});
        return;
      }
      setPassword(next);
      // Other sessions stay revoked-adjacent: only the requester keeps its
      // token, anything else has to log in with the new password.
      _webuiSessions.removeWhere((token, _) => token != _bearerToken(request));
      log.info('password changed from the web ui ($clientAddress)');
      _respond(request, 200, {});
      return;
    }

    if (method == 'GET' && sub == '/boxes') {
      _respond(request, 200, {'boxes': await _listBoxes()});
      return;
    }

    if (method == 'GET' && sub == '/logs') {
      final after =
          int.tryParse(request.uri.queryParameters['after'] ?? '') ?? 0;
      final result = log.since(after);
      _respond(request, 200, {
        'entries': result.entries.map((e) => e.toJson()).toList(),
        'latest': result.latest,
      });
      return;
    }

    if (method == 'GET' && sub == '/export.hmb') {
      await _handleExport(request);
      return;
    }

    if (method == 'POST' && sub == '/import.hmb') {
      await _handleWebuiImport(request);
      return;
    }

    if (method == 'POST' && sub == '/reset') {
      final body = await _readJsonBody(request);
      final password = body?['password'];
      if (password is! String || !checkPassword(password)) {
        _respond(request, 401, {'error': 'invalid password'});
        return;
      }
      await resetDatabase();
      log.info('database reset from the web ui ($clientAddress)');
      _respond(request, 200, {});
      return;
    }

    if (sub == '/backends') {
      if (method == 'GET') {
        _respond(
            request, 200, {'rev': _backendsRev(), 'backends': _listBackends()});
        return;
      }
      if (method == 'POST') {
        await _handleBackendCreate(request);
        return;
      }
    }
    const backendPrefix = '/backends/';
    if (sub.startsWith(backendPrefix)) {
      final id = int.tryParse(sub.substring(backendPrefix.length));
      if (id == null) {
        _respond(request, 404, {'error': 'unknown backend'});
        return;
      }
      if (method == 'PUT') {
        await _handleBackendUpdate(request, id);
        return;
      }
      if (method == 'DELETE') {
        await _handleBackendDelete(request, id);
        return;
      }
    }

    _respond(request, 404, {'error': 'not found'});
  }

  String? _bearerToken(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  String _newWebuiSession() {
    final token = randomHex(Random.secure(), 32);
    _webuiSessions[token] = DateTime.now().add(_sessionTtl);
    return token;
  }

  bool _webuiAuthorized(HttpRequest request) {
    final token = _bearerToken(request);
    if (token == null) return false;
    final expiry = _webuiSessions[token];
    if (expiry == null) return false;
    if (expiry.isBefore(DateTime.now())) {
      _webuiSessions.remove(token);
      return false;
    }
    return true;
  }

  // -- hosted backends -----------------------------------------------------

  int _backendsRev() => (_meta.get('backendsRev') as num?)?.toInt() ?? 0;

  List<Map<String, Object?>> _listBackends() {
    final out = <HostedBackend>[];
    for (final key in _backends.keys) {
      final raw = _backends.get(key);
      if (raw is! Map) continue;
      final backend = HostedBackend.fromMap(raw);
      if (backend != null) out.add(backend);
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    return out.map((b) => b.toMap()).toList();
  }

  Future<void> _bumpBackendsRev() =>
      _meta.put('backendsRev', _backendsRev() + 1);

  HostedBackend? _findBackend(int id) {
    final raw = _backends.get('b_$id');
    if (raw is! Map) return null;
    return HostedBackend.fromMap(raw);
  }

  Future<void> _handleBackendCreate(HttpRequest request) async {
    final body = await _readJsonBody(request);
    if (body == null) {
      _respond(request, 400, {'error': 'invalid json body'});
      return;
    }
    final error = validateHostedBackend(body);
    if (error != null) {
      _respond(request, 400, {'error': error});
      return;
    }
    final id = (_meta.get('nextBackendId') as num?)?.toInt() ?? 1;
    await _meta.put('nextBackendId', id + 1);
    final backend = HostedBackend(
      id: id,
      name: (body['name'] as String).trim(),
      type: body['type'] as String,
      serverUrl: _blankToNull(body['serverUrl']),
      username: _blankToNull(body['username']),
      password: _blankToNull(body['password']),
    );
    await _backends.put('b_$id', backend.toMap());
    await _bumpBackendsRev();
    log.info('backend added: ${backend.name} (${backend.type})');
    _respond(request, 200, backend.toMap());
  }

  Future<void> _handleBackendUpdate(HttpRequest request, int id) async {
    final existing = _findBackend(id);
    if (existing == null) {
      _respond(request, 404, {'error': 'unknown backend'});
      return;
    }
    final body = await _readJsonBody(request);
    if (body == null) {
      _respond(request, 400, {'error': 'invalid json body'});
      return;
    }
    final merged = existing.toMap()
      ..addAll(body)
      ..['id'] = id;
    final error = validateHostedBackend(merged);
    if (error != null) {
      _respond(request, 400, {'error': error});
      return;
    }
    final backend = HostedBackend(
      id: id,
      name: (merged['name'] as String).trim(),
      type: merged['type'] as String,
      serverUrl: _blankToNull(merged['serverUrl']),
      username: _blankToNull(merged['username']),
      password: _blankToNull(merged['password']),
    );
    await _backends.put('b_$id', backend.toMap());
    await _bumpBackendsRev();
    log.info('backend updated: ${backend.name} (${backend.type})');
    _respond(request, 200, backend.toMap());
  }

  Future<void> _handleBackendDelete(HttpRequest request, int id) async {
    if (_findBackend(id) == null) {
      _respond(request, 404, {'error': 'unknown backend'});
      return;
    }
    await _backends.delete('b_$id');
    await _bumpBackendsRev();
    log.info('backend removed: id $id');
    _respond(request, 200, {});
  }

  String? _blankToNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // -- web ui import -------------------------------------------------------

  Future<void> _handleWebuiImport(HttpRequest request) async {
    if (request.contentLength > _maxImportBytes) {
      _respond(request, 413, {'error': 'file too large'});
      return;
    }
    final temp = await Directory.systemTemp.createTemp('doudou_import_');
    try {
      final file = File('${temp.path}/upload.hmb');
      final sink = file.openWrite();
      var received = 0;
      var tooLarge = false;
      await for (final chunk in request) {
        received += chunk.length;
        if (received > _maxImportBytes) {
          tooLarge = true;
          break;
        }
        sink.add(chunk);
      }
      await sink.close();
      if (tooLarge) {
        _respond(request, 413, {'error': 'file too large'});
        return;
      }
      final result = await importHmb(file.path);
      _respond(request, 200, {
        'imported': result.boxes,
        'skipped': result.skipped,
      });
    } on HmbImportException catch (e) {
      _respond(request, 400, {'error': e.message});
    } finally {
      await temp.delete(recursive: true);
    }
  }

  // -- static files --------------------------------------------------------

  List<int>? _bundleFile(String rel) {
    if (_fileCache.containsKey(rel)) return _fileCache[rel];
    final encoded = kWebuiBundle[rel];
    if (encoded == null) return null;
    final bytes = base64Decode(encoded);
    _fileCache[rel] = bytes;
    return bytes;
  }

  void _serveStatic(HttpRequest request, String path) {
    var rel = path.substring('/app'.length);
    if (rel.isEmpty || rel == '/') rel = '/index.html';
    rel = rel.substring(1);

    var gzipped = _bundleFile(rel);
    if (gzipped == null && !rel.contains('.')) {
      rel = 'index.html';
      gzipped = _bundleFile(rel);
    }
    if (gzipped == null) {
      if (kWebuiBundle.isEmpty) {
        request.response
          ..statusCode = 503
          ..headers.contentType = ContentType.text
          ..write('web ui not bundled in this build, '
              'run `dart tool/build_webui.dart` first');
        request.response.close();
        return;
      }
      _respond(request, 404, {'error': 'not found'});
      return;
    }

    final acceptsGzip = request.headers
            .value(HttpHeaders.acceptEncodingHeader)
            ?.contains('gzip') ??
        false;
    final response = request.response
      ..statusCode = 200
      ..headers.contentType = _contentTypeFor(rel)
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    if (acceptsGzip) {
      response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      response.add(gzipped);
    } else {
      response.add(gzip.decode(gzipped));
    }
    response.close();
  }

  ContentType _contentTypeFor(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'html' => ContentType.html,
      'js' => ContentType('text', 'javascript'),
      'css' => ContentType('text', 'css'),
      'json' || 'map' => ContentType.json,
      'wasm' => ContentType('application', 'wasm'),
      'png' => ContentType('image', 'png'),
      'svg' => ContentType('image', 'svg+xml'),
      'ico' => ContentType('image', 'x-icon'),
      'otf' => ContentType('font', 'otf'),
      'ttf' => ContentType('font', 'ttf'),
      'webmanifest' => ContentType('application', 'manifest+json'),
      'txt' => ContentType.text,
      _ => ContentType.binary,
    };
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
        .where((n) =>
            isValidBoxName(n) &&
            !n.startsWith('_') &&
            n.toLowerCase() != hostedBackendsBoxName.toLowerCase())
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

    final applied = (result['applied'] as num?)?.toInt() ?? 0;
    if (applied > 0) {
      log.info('applied $applied ops to $name (rev ${result['rev']})');
    }
    _respond(request, 200, result);
  }

  Future<void> _handleExport(HttpRequest request) async {
    for (final box in _openBoxes.values) {
      await box.compact();
    }
    final temp = await Directory.systemTemp.createTemp('doudou_export_');
    try {
      final outPath = '${temp.path}/doudou-backup.hmb';
      final names = await exportHmbFile(dbDir, outPath);
      if (names == null) {
        _respond(request, 404, {'error': 'no data to export'});
        return;
      }
      log.info('database exported (${names.length} boxes)');
      final bytes = await File(outPath).readAsBytes();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('application', 'zip')
        ..headers.set(
            'Content-Disposition', 'attachment; filename="doudou-backup.hmb"')
        ..add(bytes);
      await request.response.close();
    } finally {
      await temp.delete(recursive: true);
    }
  }

  /// Empties every synced box and the hosted backend list. Keys are
  /// tombstoned instead of just removed so connected clients apply the
  /// reset on their next pull instead of pushing the data straight back.
  Future<void> resetDatabase() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory(dbDir);
    if (dir.existsSync()) {
      final names = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .where((n) => n.endsWith('.hive'))
          .map((n) => n.substring(0, n.length - '.hive'.length))
          .where((n) =>
              isValidBoxName(n) &&
              !n.startsWith('_') &&
              n.toLowerCase() != hostedBackendsBoxName.toLowerCase())
          .toList();
      for (final fileName in names) {
        final name = (_meta.get('name:$fileName') as String?) ?? fileName;
        final box = await _box(name);
        if (box.isEmpty) continue;
        final deleted = _delMap(name);
        for (final key in box.keys) {
          deleted[key.toString()] = now;
        }
        await box.deleteAll(box.keys.toList());
        final lowered = name.toLowerCase();
        await _meta.delete('ts:$lowered');
        await _meta.put('del:$lowered', deleted);
        await _meta.put('rev:$lowered', _rev(lowered) + 1);
      }
    }
    await _backends.clear();
    await _bumpBackendsRev();
  }

  /// Imports a `.hmb` backup into the server database. Imported keys keep no
  /// per-key timestamps, so they are stamped with the import time and always
  /// lose against anything a client writes afterwards.
  ///
  /// When the backup came from the app its AppPrefs box lists the servers
  /// the device knew about. Each local entry is recreated as a hosted
  /// backend and its library data is retargeted to the hosted remote
  /// namespace, so it stays attached to the server it was saved under
  /// instead of going orphaned. The built-in default server (id 0) lives in
  /// the shared unsuffixed namespace, so its synced boxes are renamed into
  /// the hosted `_s_<id>` space as well.
  Future<HmbImportResult> importHmb(String hmbPath) async {
    // Close every hosted box before the .hive files get overwritten so a
    // stale file handle cannot rewrite the imported data on its next write.
    for (final entry in _openBoxes.entries.toList()) {
      await entry.value.close();
      _openBoxes.remove(entry.key);
    }
    await _backends.close();
    final result = importHmbFile(hmbPath, dbDir);
    _backends = await Hive.openBox(hostedBackendsBoxName);
    final idMap = await _importAppServers(result);
    await _retargetImportedBoxes(result, idMap);
    await _retargetPlaylistKeys(result, idMap);
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
    await _bumpBackendsRev();
    if (idMap.isNotEmpty) {
      log.info('imported ${idMap.length} servers from the backup');
    }
    log.info('imported $hmbPath (${result.boxes.length} boxes)');
    return result;
  }

  /// Recreates the app server list stored in an imported AppPrefs box as
  /// hosted backends. Returns the local server id to hosted remote id
  /// mapping used to retarget `_s_<id>` box files and `s_<id>_` playlist
  /// keys. Remote entries copied from another doudou server are skipped,
  /// and an entry already hosted (same type, url and username) reuses its
  /// backend id so a re-import does not duplicate it.
  Future<Map<int, int>> _importAppServers(HmbImportResult result) async {
    final idMap = <int, int>{};
    // An imported DoudouBackends box can hold ids beyond the stored counter;
    // keep the next id above them so new entries never overwrite old ones.
    final hosted = _listBackends()
        .map(HostedBackend.fromMap)
        .whereType<HostedBackend>()
        .toList();
    var nextId = (_meta.get('nextBackendId') as num?)?.toInt() ?? 1;
    for (final b in hosted) {
      if (b.id >= nextId) nextId = b.id + 1;
    }
    if (!result.boxes.any((b) => b.toLowerCase() == 'appprefs')) {
      await _meta.put('nextBackendId', nextId);
      return idMap;
    }
    final prefs = await Hive.openBox('AppPrefs');
    List<dynamic> servers;
    try {
      final raw = prefs.get('servers');
      servers = raw is List ? raw : const [];
    } finally {
      await prefs.close();
    }
    for (final entry in servers.whereType<Map>()) {
      final server = SettingsServer.fromMap(entry.cast<String, dynamic>());
      if (server.isRemote) continue;
      if (validateHostedBackend({
            'name': server.name,
            'type': server.type.name,
            'serverUrl': server.serverUrl,
            'username': server.username,
            'password': server.password,
          }) !=
          null) {
        continue;
      }
      final match = _matchBackend(hosted, server);
      final id = match?.id ?? nextId++;
      final backend = HostedBackend(
        id: id,
        name: server.name.trim(),
        type: server.type.name,
        serverUrl: _blankToNull(server.serverUrl),
        username: _blankToNull(server.username),
        password: _blankToNull(server.password),
      );
      await _backends.put('b_$id', backend.toMap());
      if (match == null) hosted.add(backend);
      idMap[server.id] = remoteServerId(id);
    }
    await _meta.put('nextBackendId', nextId);
    return idMap;
  }

  HostedBackend? _matchBackend(
      List<HostedBackend> hosted, SettingsServer server) {
    for (final b in hosted) {
      if (b.type == server.type.name &&
          (b.serverUrl ?? '') == (server.serverUrl ?? '') &&
          (b.username ?? '') == (server.username ?? '')) {
        return b;
      }
    }
    return null;
  }

  /// Renames imported `_s_<localId>` box files into the `_s_<remoteId>`
  /// namespace of the backend that server became, and fixes the reported
  /// box list so meta stamping targets the new names.
  Future<void> _retargetImportedBoxes(
      HmbImportResult result, Map<int, int> idMap) async {
    if (idMap.isEmpty) return;
    final pattern = RegExp(r'^(.*)_s_(\d+)$');
    // Server id 0 syncs the shared unsuffixed boxes, so importing it means
    // moving those files into the hosted backend namespace too.
    final zeroRemote = idMap[0];
    final zeroNames = zeroRemote == null
        ? const <String>{}
        : syncedBoxNames(0, const {})
            .where((n) => n != libraryPlaylistsBox)
            .map((n) => n.toLowerCase())
            .toSet();
    for (var i = 0; i < result.boxes.length; i++) {
      final match = pattern.firstMatch(result.boxes[i]);
      if (match == null) {
        if (zeroRemote == null ||
            !zeroNames.contains(result.boxes[i].toLowerCase())) {
          continue;
        }
        final oldName = result.boxes[i];
        final newName = '${oldName}_s_$zeroRemote';
        File('$dbDir/${oldName.toLowerCase()}.hive')
            .renameSync('$dbDir/${newName.toLowerCase()}.hive');
        result.boxes[i] = newName;
        for (final prefix in ['name', 'rev', 'baseTs', 'ts', 'del']) {
          await _meta.delete('$prefix:${oldName.toLowerCase()}');
        }
        continue;
      }
      final remote = idMap[int.tryParse(match.group(2)!) ?? -1];
      if (remote == null) continue;
      final oldName = result.boxes[i];
      final newName = '${match.group(1)}_s_$remote';
      File('$dbDir/${oldName.toLowerCase()}.hive')
          .renameSync('$dbDir/${newName.toLowerCase()}.hive');
      result.boxes[i] = newName;
      for (final prefix in ['name', 'rev', 'baseTs', 'ts', 'del']) {
        await _meta.delete('$prefix:${oldName.toLowerCase()}');
      }
    }
  }

  /// Rewrites the per-server keys inside an imported LibraryPlaylists box so
  /// playlists saved under a local server id land under the hosted remote id
  /// their library boxes were retargeted to.
  Future<void> _retargetPlaylistKeys(
      HmbImportResult result, Map<int, int> idMap) async {
    if (idMap.isEmpty ||
        !result.boxes.any((b) => b.toLowerCase() == 'libraryplaylists')) {
      return;
    }
    final box = await Hive.openBox(libraryPlaylistsBox);
    try {
      final pattern = RegExp(r'^s_(\d+)_(.+)$');
      final moves = <String, String>{};
      for (final key in box.keys) {
        final k = key.toString();
        final match = pattern.firstMatch(k);
        if (match == null) continue;
        final remote = idMap[int.tryParse(match.group(1)!) ?? -1];
        if (remote != null) moves[k] = 's_${remote}_${match.group(2)}';
      }
      for (final entry in moves.entries) {
        final value = box.get(entry.key);
        await box.delete(entry.key);
        await box.put(entry.value, value);
      }
    } finally {
      await box.close();
    }
  }
}
