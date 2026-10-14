import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'platform/platform.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

/// Client for the JSON api the sync server exposes under /app/api. All
/// endpoints sit next to the app shell, so paths stay relative and work
/// from any host or port the server is reached through.
class WebuiApi {
  WebuiApi({http.Client? client, TokenStore? tokenStore})
    : _http = client ?? http.Client(),
      tokenStore = tokenStore ?? createTokenStore();

  final http.Client _http;
  final TokenStore tokenStore;

  String? get token => tokenStore.read();

  Future<Map<String, Object?>> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authorized = true,
  }) async {
    final uri = Uri(path: '/app/api$path');
    final request = http.Request(method, uri);
    final token = authorized ? tokenStore.read() : null;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _http.send(request);
    final text = await response.stream.bytesToString();
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } catch (_) {}
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'HTTP ${response.statusCode}';
      throw ApiException(error, statusCode: response.statusCode);
    }
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return {};
  }

  Future<ServerState> state() async =>
      ServerState.fromJson(await _call('GET', '/state', authorized: false));

  /// True when the stored token is still accepted by the server.
  Future<bool> tokenValid() async {
    if (token == null) return false;
    try {
      await _call('GET', '/boxes');
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> login(String password) async {
    final res = await _call(
      'POST',
      '/login',
      body: {'password': password},
      authorized: false,
    );
    tokenStore.write(res['token'] as String);
  }

  Future<void> setup(String password) async {
    final res = await _call(
      'POST',
      '/setup',
      body: {'password': password},
      authorized: false,
    );
    tokenStore.write(res['token'] as String);
  }

  Future<void> logout() async {
    try {
      await _call('POST', '/logout');
    } finally {
      tokenStore.clear();
    }
  }

  Future<void> changePassword(String current, String next) =>
      _call('POST', '/password', body: {'current': current, 'next': next});

  Future<List<HostedBackend>> backends() async {
    final res = await _call('GET', '/backends');
    final raw = res['backends'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => HostedBackend.fromJson(Map<String, Object?>.from(m)))
        .toList();
  }

  Future<HostedBackend> createBackend(HostedBackend backend) async {
    final res = await _call('POST', '/backends', body: backend.toJson());
    return HostedBackend.fromJson(res);
  }

  Future<void> updateBackend(HostedBackend backend) =>
      _call('PUT', '/backends/${backend.id}', body: backend.toJson());

  Future<void> deleteBackend(int id) => _call('DELETE', '/backends/$id');

  Future<List<SyncBox>> boxes() async {
    final res = await _call('GET', '/boxes');
    final raw = res['boxes'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SyncBox.fromJson(Map<String, Object?>.from(m)))
        .toList();
  }

  Future<LogPage> logs(int after) async {
    final res = await _call('GET', '/logs?after=$after');
    final raw = res['entries'];
    final entries = raw is List
        ? raw
              .whereType<Map>()
              .map((m) => LogEntry.fromJson(Map<String, Object?>.from(m)))
              .toList()
        : <LogEntry>[];
    return LogPage(
      entries: entries,
      latest: (res['latest'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ImportResult> importHmb(Uint8List bytes) async {
    final uri = Uri(path: '/app/api/import.hmb');
    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${tokenStore.read()}'
      ..headers['Content-Type'] = 'application/octet-stream'
      ..bodyBytes = bytes;
    final response = await _http.send(request);
    final text = await response.stream.bytesToString();
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {}
    if (response.statusCode != 200 || decoded is! Map) {
      final error = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'HTTP ${response.statusCode}';
      throw ApiException(error, statusCode: response.statusCode);
    }
    final body = decoded;
    List<String> names(String key) => body[key] is List
        ? (body[key] as List).map((e) => e.toString()).toList()
        : const [];
    return ImportResult(imported: names('imported'), skipped: names('skipped'));
  }

  /// Downloads the .hmb backup through the browser's save dialog.
  Future<void> downloadBackup() async {
    final uri = Uri(path: '/app/api/export.hmb');
    final request = http.Request('GET', uri)
      ..headers['Authorization'] = 'Bearer ${tokenStore.read()}';
    final response = await _http.send(request);
    final bytes = await response.stream.toBytes();
    if (response.statusCode != 200) {
      String message = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {}
      throw ApiException(message, statusCode: response.statusCode);
    }
    triggerDownload(bytes, 'doudou-backup.hmb');
  }
}
