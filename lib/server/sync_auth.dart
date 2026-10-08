import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Iterations for PBKDF2-HMAC-SHA256. Stored in the hash string so it can be
/// raised later without invalidating existing hashes.
const int kSyncPasswordIterations = 120000;

const _pbkdf2Prefix = 'pbkdf2';

/// Password hashing and login throttling for the sync server. Passwords are
/// stored as `pbkdf2\$<iterations>\$<hex>` so a stolen server.json is of no
/// use offline; hashes written by older versions (a single salted SHA-256
/// round) still verify and are upgraded when a new password is set.
String hashSyncPassword(String password, String salt,
    {int iterations = kSyncPasswordIterations}) {
  final digest = _pbkdf2(password, salt, iterations);
  return '$_pbkdf2Prefix\$$iterations\$${_hex(digest)}';
}

/// Legacy single-round format produced before PBKDF2 was introduced.
String legacyHashSyncPassword(String password, String salt) =>
    sha256.convert(utf8.encode('$salt:$password')).toString();

bool verifySyncPassword(String password, String salt, String storedHash) {
  final parts = storedHash.split('\$');
  List<int> expected;
  if (parts.length == 3 && parts[0] == _pbkdf2Prefix) {
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) return false;
    expected = _pbkdf2(password, salt, iterations);
    return constantTimeEquals(expected, _decodeHex(parts[2]));
  }
  final legacy = legacyHashSyncPassword(password, salt);
  return constantTimeEquals(utf8.encode(legacy), utf8.encode(storedHash));
}

List<int> _pbkdf2(String password, String salt, int iterations) {
  // PBKDF2: the password is the HMAC key, salt||blockIndex the message.
  final hmac = Hmac(sha256, utf8.encode(password));
  // One 32-byte block is a full sha256 output, so a single block suffices.
  var u = hmac.convert([
    ...utf8.encode(salt),
    0, 0, 0, 1,
  ]).bytes;
  final result = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return result;
}

/// Length-aware constant-time comparison; avoids early-exit timing signals
/// on password and token checks.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _decodeHex(String hex) {
  if (hex.length % 2 != 0) return const [];
  final out = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final v = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (v == null) return const [];
    out.add(v);
  }
  return out;
}

/// Sliding-window failure limiter for the login endpoint. After
/// [maxFailures] wrong passwords inside [window], further attempts are
/// rejected without checking the password until the window slides past.
class LoginRateLimiter {
  LoginRateLimiter({
    this.maxFailures = 5,
    this.window = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxFailures;
  final Duration window;
  final DateTime Function() _clock;
  final _failures = <String, _FailureWindow>{};

  /// True when [key] (the client address) is currently locked out.
  bool isLimited(String key) {
    final entry = _failures[key];
    if (entry == null) return false;
    if (_clock().difference(entry.firstFailure) > window) {
      _failures.remove(key);
      return false;
    }
    return entry.count >= maxFailures;
  }

  /// Records a failed attempt for [key].
  void recordFailure(String key) {
    final entry = _failures[key];
    final now = _clock();
    if (entry == null || now.difference(entry.firstFailure) > window) {
      _failures[key] = _FailureWindow(now, 1);
    } else {
      entry.count++;
    }
  }

  /// Clears the failure count for [key] after a successful login.
  void recordSuccess(String key) => _failures.remove(key);
}

class _FailureWindow {
  _FailureWindow(this.firstFailure, this.count);
  final DateTime firstFailure;
  int count;
}

/// Cryptographically random lowercase hex of [bytes] length.
String randomHex(Random random, int bytes) => List.generate(
    bytes, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
