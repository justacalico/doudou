import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mcp_protocol.dart';
import 'mcp_server.dart';

/// Streamable-HTTP transport for [DoudouMcpServer].
///
/// The server exposes a single endpoint (`/mcp`, with `/` accepted for
/// lenient clients). POST bodies carry JSON-RPC messages and are answered
/// with `application/json`; notifications-only payloads get `202 Accepted`.
/// GET and DELETE are declined with 405 because this server does not keep
/// sessions or server-initiated SSE streams. Bodies are capped at 1 MiB.
class McpHttpServer {
  McpHttpServer(this._server);

  final DoudouMcpServer _server;
  HttpServer? _http;

  static const int _maxBodyBytes = 1024 * 1024;
  static const List<String> _acceptedPaths = ['/mcp', '/'];

  int get port => _http?.port ?? 0;
  bool get isRunning => _http != null;

  Future<void> start({
    required int port,
    InternetAddress? host,
  }) async {
    await stop();
    _http = await HttpServer.bind(
        host ?? InternetAddress.loopbackIPv4, port);
    _http!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _http?.close(force: true);
    _http = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    try {
      if (!_acceptedPaths.contains(request.uri.path)) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      switch (request.method) {
        case 'POST':
          await _handlePost(request);
        case 'GET' || 'DELETE':
          response.statusCode = HttpStatus.methodNotAllowed;
          response.headers.set(HttpHeaders.allowHeader, 'POST');
          await response.close();
        default:
          response.statusCode = HttpStatus.methodNotAllowed;
          await response.close();
      }
    } catch (_) {
      // A malformed or already-hijacked request must never take the listener
      // down; close best effort and move on.
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _handlePost(HttpRequest request) async {
    final response = request.response;
    final body = await _readBody(request);
    if (body == null) {
      response.statusCode = HttpStatus.requestEntityTooLarge;
      await response.close();
      return;
    }

    final Object? message;
    try {
      message = jsonDecode(body);
    } catch (_) {
      response.statusCode = HttpStatus.badRequest;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({
        'jsonrpc': kJsonRpcVersion,
        'id': null,
        'error': {
          'code': kRpcParseError,
          'message': 'Body is not valid JSON',
        },
      }));
      await response.close();
      return;
    }

    final result = await _server.handleMessage(message);
    if (result == null) {
      // Notifications only: nothing to send back.
      response.statusCode = HttpStatus.accepted;
      await response.close();
      return;
    }
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(result));
    await response.close();
  }

  /// Returns null when the body exceeds the size cap; the rest is drained so
  /// the connection stays healthy.
  Future<String?> _readBody(HttpRequest request) async {
    final length = request.contentLength;
    if (length > _maxBodyBytes) {
      await request.drain<void>();
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBodyBytes) {
        await request.drain<void>();
        return null;
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
