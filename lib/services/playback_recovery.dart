import 'dart:io';

import 'package:flutter/services.dart';

/// Retry policy for native player failures. The signed stream URL is usually
/// fine when the platform player reports a connection error, so recovery is
/// capped and spaced out instead of hammering load() in a tight loop.
const int maxPlayerRecoveryAttempts = 3;

/// A failure older than this is treated as a new incident and gets a fresh
/// retry budget, so a manual retry an hour later is not blocked by an old
/// failure streak.
const int playerRecoveryWindowMs = 60000;

const int _baseBackoffMs = 1000;
const int _maxBackoffMs = 8000;

/// NSURLError codes for a broken network path on iOS/macOS. These show up as
/// PlatformException codes when AVPlayer fails to open the stream.
const Set<int> _connectionPlatformCodes = {
  -1001, // timedOut
  -1003, // cannotFindHost
  -1004, // cannotConnectToHost
  -1005, // networkConnectionLost
  -1009, // notConnectedToInternet
  -1018, // internationalRoamingOff
  -1020, // dataNotAllowed
};

const List<String> _connectionErrorNeedles = [
  'could not connect',
  'connection closed',
  'connection reset',
  'connection refused',
  'connection timed out',
  'connection abort',
  'connection lost',
  'cannot connect',
  'cannot find host',
  'network is unreachable',
  'not connected to the internet',
  'no route to host',
  'failed host lookup',
  'broken pipe',
  'socketexception',
  'network_connection',
  'io_network',
];

/// Exponential backoff in milliseconds for the given 1-based attempt:
/// 1s, 2s, 4s, then capped at [_maxBackoffMs].
int playerRecoveryBackoffMs(int attempt) {
  if (attempt < 1) return 0;
  final shift = attempt - 1;
  final delay = _baseBackoffMs << (shift > 3 ? 3 : shift);
  return delay > _maxBackoffMs ? _maxBackoffMs : delay;
}

/// A single retry only proves the URL is fresh, not that the native session
/// is healthy. From the second attempt on, the platform player itself is
/// disposed and rebuilt so a stuck AVPlayer/ExoPlayer session is discarded.
bool shouldRecreatePlayerForAttempt(int attempt) => attempt >= 2;

/// Numeric platform error code when [error] is a [PlatformException] whose
/// code is numeric (e.g. '-1004'), otherwise null.
int? platformErrorCode(Object error) {
  if (error is PlatformException) return int.tryParse(error.code);
  return null;
}

/// Whether [error] looks like a network/connection failure reported by the
/// platform player, as opposed to a bad URL, bad container or decode error.
/// This class of error is the one that gets the native session stuck in the
/// wild (WiFi/cellular handoff, app backgrounding, sleep/wake).
bool isPlayerConnectionError(Object error) {
  if (error is SocketException) return true;
  if (error is PlatformException) {
    final code = int.tryParse(error.code);
    if (code != null && _connectionPlatformCodes.contains(code)) {
      return true;
    }
  }
  final text = error.toString().toLowerCase();
  return _connectionErrorNeedles.any(text.contains);
}

typedef StreamReachabilityCheck = Future<bool> Function(String? streamUrl);

/// Probes a TCP connection to the host of [streamUrl]. This answers the only
/// question that matters for playback recovery: can the device's network path
/// actually reach the stream server right now. Our own API calls succeeding is
/// not proof, they may be cached or go over a different interface.
///
/// Returns true when the check cannot be meaningfully performed (local files,
/// unknown urls) so recovery is not blocked by the probe itself.
Future<bool> canReachStreamHost(
  String? streamUrl, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (streamUrl == null || streamUrl.isEmpty) return true;
  final uri = Uri.tryParse(streamUrl);
  if (uri == null || uri.host.isEmpty) return true;
  if (uri.scheme == 'file') return true;
  final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
  try {
    final socket = await Socket.connect(uri.host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
