// ignore: avoid_web_libraries_in_flutter
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Local HTTP proxy for streaming URLs that require custom headers (e.g. googlevideo.com).
/// MPV does not reliably apply http-header-fields from media_kit, so we proxy requests
/// and add headers server-side.
///
/// Currently no other file in the repo imports or calls this service. If you start using it
/// (e.g. from unified_audio_handler or a player), ensure [stop] is called on app shutdown
/// or when switching server so the HttpServer does not leak.
class StreamProxyService {
  StreamProxyService._();
  static final StreamProxyService instance = StreamProxyService._();

  HttpServer? _server;
  int? _port;
  int _nextId = 0;
  final Map<String, _ProxyEntry> _entries = {};
  static const _prefix = '/p/';
  static const _entryTtl = Duration(minutes: 5);

  bool get isRunning => _server != null;

  /// Returns a proxy URL for the given [url] with [headers] applied when fetching.
  /// Starts the server on first use.
  Future<String> register(String url, Map<String, String> headers) async {
    await ensureStarted();
    final id = '${_nextId++}_${DateTime.now().millisecondsSinceEpoch}';
    _entries[id] = _ProxyEntry(
      url: url,
      headers: Map.unmodifiable(headers),
      expiresAt: DateTime.now().add(_entryTtl),
    );
    final proxyUrl = 'http://127.0.0.1:$_port$_prefix$id';
    if (kDebugMode) {
      debugPrint('[StreamProxy] registered $id -> ${Uri.parse(url).host}');
    }
    return proxyUrl;
  }

  Future<void> ensureStarted() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handleRequest);
    if (kDebugMode) {
      debugPrint('[StreamProxy] started on port $_port');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = 405;
      request.response.close();
      return;
    }
    final path = request.uri.path;
    if (!path.startsWith(_prefix)) {
      request.response.statusCode = 404;
      request.response.close();
      return;
    }
    final id = path.substring(_prefix.length).split('/').first;
    var entry = _entries[id];
    if (entry != null && DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(id);
      entry = null;
    }
    if (entry == null) {
      request.response.statusCode = 404;
      request.response.close();
      return;
    }
    try {
      final reqHeaders = <String, String>{
        ...entry.headers,
        if (request.headers.value('range') != null) 'Range': request.headers.value('range')!,
      };
      final streamedReq = http.Request(request.method, Uri.parse(entry.url))
        ..headers.addAll(reqHeaders);
      final client = http.Client();
      try {
        final response = await client.send(streamedReq).timeout(const Duration(seconds: 30));
        request.response.statusCode = response.statusCode;
        response.headers.forEach((name, value) {
          if (_isPassThroughHeader(name)) {
            request.response.headers.set(name, value);
          }
        });
        if (request.method == 'GET') {
          await response.stream.pipe(request.response);
        } else {
          await request.response.close();
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StreamProxy] error for $id: $e');
      }
      request.response.statusCode = 502;
      request.response.close();
    } finally {
      // Keep entry for seeks/reconnects; TTL cleanup happens on next request
    }
  }

  bool _isPassThroughHeader(String name) {
    final n = name.toLowerCase();
    return n == 'content-type' ||
        n == 'content-length' ||
        n == 'accept-ranges' ||
        n == 'content-range';
  }

  void stop() {
    _server?.close();
    _server = null;
    _port = null;
    _entries.clear();
  }
}

class _ProxyEntry {
  final String url;
  final Map<String, String> headers;
  final DateTime expiresAt;

  _ProxyEntry({
    required this.url,
    required this.headers,
    required this.expiresAt,
  });
}
