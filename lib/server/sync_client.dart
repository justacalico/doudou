import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'sync_model.dart';

/// Thrown when the server rejects a request or cannot be reached.
class SyncServerException implements Exception {
  SyncServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

/// HTTP client for the doudou sync server. Pure dart:io so the same client
/// works in the Flutter app, the CLI and tests.
class DoudouSyncClient {
  DoudouSyncClient({
    required this.baseUrl,
    this.token,
    Duration timeout = const Duration(seconds: 15),
    HttpClient? httpClient,
  })  : _timeout = timeout,
        _http = httpClient ?? HttpClient();

  /// Normalized base URL without a trailing slash, e.g. http://host:8461
  final String baseUrl;
  String? token;
  final Duration _timeout;
  final HttpClient _http;

  static String normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  void close() => _http.close();

  Future<Map<String, Object?>> ping() async {
    final res = await _request('GET', '/api/ping', authorized: false);
    return res;
  }

  /// Logs in with the server password and stores the returned bearer token.
  Future<void> login(String password) async {
    final res = await _request(
      'POST',
      '/api/login',
      body: {'password': password},
      authorized: false,
    );
    final t = res['token'];
    if (t is! String || t.isEmpty) {
      throw SyncServerException('Server did not return a token');
    }
    token = t;
  }

  Future<List<SyncBoxInfo>> listBoxes() async {
    final res = await _request('GET', '/api/boxes');
    final raw = res['boxes'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SyncBoxInfo(
              name: m['name'].toString(),
              revision: (m['rev'] as num?)?.toInt() ?? 0,
              keys: (m['keys'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<BoxSnapshot> getBox(String name) async {
    final res =
        await _request('GET', '/api/box/${Uri.encodeComponent(name)}');
    return BoxSnapshot.fromJson(res);
  }

  /// Pushes [ops] to a box and returns the new server revision.
  Future<int> pushOps(String name, List<SyncOp> ops) async {
    final res = await _request(
      'POST',
      '/api/box/${Uri.encodeComponent(name)}/ops',
      body: {'ops': ops.map((o) => o.toJson()).toList()},
    );
    return (res['rev'] as num?)?.toInt() ?? 0;
  }

  /// Downloads the whole server database as `.hmb` bytes.
  Future<List<int>> exportHmb() async {
    final request = await _http
        .getUrl(Uri.parse('$baseUrl/api/export.hmb'))
        .timeout(_timeout);
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final response = await request.close().timeout(_timeout);
    final builder = BytesBuilder();
    await response.forEach(builder.add);
    final bytes = builder.takeBytes();
    if (response.statusCode != 200) {
      throw SyncServerException(
        'Export failed (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return bytes;
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authorized = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    HttpClientRequest request;
    try {
      switch (method) {
        case 'POST':
          request = await _http.postUrl(uri).timeout(_timeout);
          break;
        default:
          request = await _http.getUrl(uri).timeout(_timeout);
      }
    } on Object catch (e) {
      throw SyncServerException('Cannot reach server: $e');
    }

    if (authorized && token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    HttpClientResponse response;
    try {
      response = await request.close().timeout(_timeout);
    } on Object catch (e) {
      throw SyncServerException('Request failed: $e');
    }
    final text = await utf8.decodeStream(response).timeout(_timeout);

    Object? decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = null;
      }
    }
    if (response.statusCode == 401) {
      throw SyncServerException('Unauthorized', statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg =
          decoded is Map && decoded['error'] != null ? decoded['error'] : text;
      throw SyncServerException(
        'HTTP ${response.statusCode}: $msg',
        statusCode: response.statusCode,
      );
    }
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }
}

class SyncBoxInfo {
  const SyncBoxInfo(
      {required this.name, required this.revision, required this.keys});

  final String name;
  final int revision;
  final int keys;
}
