import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../storage/database.dart';

/// Validates the shared password sent by clients. The password is stored as a
/// sha256 hex digest in the settings table under `auth.passwordHash`. Until a
/// password is set via `doudou-server -set login`, all sync requests are
/// rejected with 401.
class AuthMiddleware {
  AuthMiddleware(this._db);

  final DoudouServerDatabase _db;

  Future<bool> isConfigured() async =>
      (await _db.getSetting('auth.passwordHash')) != null;

  Future<void> setPassword(String password) async {
    final hash = sha256.convert(utf8.encode(password)).toString();
    await _db.putSetting('auth.passwordHash', hash);
  }

  /// Returns true if the request carries a valid shared password. The password
  /// may be sent in the `X-Doudou-Key` header or as a `?key=` query param.
  Future<bool> handle(HttpRequest req) async {
    final configured = await isConfigured();
    if (!configured) {
      _unauthorized(req, 'server password not set');
      return false;
    }
    final provided = req.headers.value('x-doudou-key') ??
        req.uri.queryParameters['key'];
    if (provided == null || provided.isEmpty) {
      _unauthorized(req, 'missing key');
      return false;
    }
    final expected = await _db.getSetting('auth.passwordHash');
    final hash = sha256.convert(utf8.encode(provided)).toString();
    if (expected == null || hash != expected) {
      _unauthorized(req, 'bad key');
      return false;
    }
    return true;
  }

  void _unauthorized(HttpRequest req, String reason) {
    req.response
      ..statusCode = HttpStatus.unauthorized
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': reason}));
  }
}
