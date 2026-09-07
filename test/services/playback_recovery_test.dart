import 'dart:io';

import 'package:doudou/services/playback_recovery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('playerRecoveryBackoffMs', () {
    test('doubles per attempt and caps at 8 seconds', () {
      expect(playerRecoveryBackoffMs(1), 1000);
      expect(playerRecoveryBackoffMs(2), 2000);
      expect(playerRecoveryBackoffMs(3), 4000);
      expect(playerRecoveryBackoffMs(4), 8000);
      expect(playerRecoveryBackoffMs(7), 8000);
    });

    test('returns zero for invalid attempts', () {
      expect(playerRecoveryBackoffMs(0), 0);
      expect(playerRecoveryBackoffMs(-3), 0);
    });
  });

  group('shouldRecreatePlayerForAttempt', () {
    test('first retry keeps the player, later retries rebuild it', () {
      expect(shouldRecreatePlayerForAttempt(1), isFalse);
      expect(shouldRecreatePlayerForAttempt(2), isTrue);
      expect(shouldRecreatePlayerForAttempt(3), isTrue);
    });

    test('a dead stream proxy rebuilds on the first attempt', () {
      expect(shouldRecreatePlayerForAttempt(1, deadStreamProxy: true), isTrue);
      expect(shouldRecreatePlayerForAttempt(2, deadStreamProxy: true), isTrue);
      expect(shouldRecreatePlayerForAttempt(1, deadStreamProxy: false),
          isFalse);
    });
  });

  group('isDeadStreamProxyError', () {
    test('matches the iOS -1004 loopback refusal only on apple platforms', () {
      final error = PlatformException(
        code: '-1004',
        message: 'Could not connect to the server.',
        details: const {'index': 0},
      );
      expect(isDeadStreamProxyError(error, isApplePlatform: true), isTrue);
      expect(isDeadStreamProxyError(error, isApplePlatform: false), isFalse);
    });

    test('rejects other codes and non platform errors', () {
      expect(
          isDeadStreamProxyError(PlatformException(code: '-1001'),
              isApplePlatform: true),
          isFalse);
      expect(
          isDeadStreamProxyError(const SocketException('Connection refused'),
              isApplePlatform: true),
          isFalse);
      expect(isDeadStreamProxyError(Exception('x'), isApplePlatform: true),
          isFalse);
    });
  });

  group('isPlayerConnectionError', () {
    test('matches the iOS -1004 platform error from the bug report', () {
      final error = PlatformException(
        code: '-1004',
        message: 'Could not connect to the server.',
        details: const {'index': 0},
      );
      expect(isPlayerConnectionError(error), isTrue);
    });

    test('matches other NSURLError connection codes', () {
      for (final code in [
        '-1001',
        '-1003',
        '-1005',
        '-1009',
        '-1018',
        '-1020'
      ]) {
        expect(isPlayerConnectionError(PlatformException(code: code)), isTrue,
            reason: 'code $code should be a connection error');
      }
    });

    test('matches socket and connection text errors', () {
      expect(
          isPlayerConnectionError(const SocketException('Connection refused')),
          isTrue);
      expect(
          isPlayerConnectionError(
              Exception('Connection closed while receiving data')),
          isTrue);
      expect(
          isPlayerConnectionError(Exception('Failed host lookup: example.com')),
          isTrue);
      expect(
          isPlayerConnectionError(
              Exception('Software caused connection abort')),
          isTrue);
    });

    test('does not match unrelated errors', () {
      expect(isPlayerConnectionError(Exception('FormatException: bad data')),
          isFalse);
      expect(
          isPlayerConnectionError(PlatformException(
              code: 'abort', message: 'Loading interrupted')),
          isFalse);
      expect(isPlayerConnectionError(Exception('403 Forbidden')), isFalse);
      expect(isPlayerConnectionError(Exception('TrackNotFound')), isFalse);
    });
  });

  group('platformErrorCode', () {
    test('extracts numeric platform codes', () {
      expect(platformErrorCode(PlatformException(code: '-1004')), -1004);
      expect(platformErrorCode(PlatformException(code: '2001')), 2001);
    });

    test('returns null for non numeric codes and other error types', () {
      expect(platformErrorCode(PlatformException(code: 'abort')), isNull);
      expect(platformErrorCode(Exception('x')), isNull);
    });
  });

  group('canReachStreamHost', () {
    test('skips the probe for urls that do not need network', () async {
      expect(await canReachStreamHost(null), isTrue);
      expect(await canReachStreamHost(''), isTrue);
      expect(await canReachStreamHost('file:///tmp/song.mp3'), isTrue);
      expect(await canReachStreamHost('not a url'), isTrue);
    });

    test('returns true when the host accepts a tcp connection', () async {
      final server =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      try {
        expect(
          await canReachStreamHost('http://127.0.0.1:${server.port}/a.mp3'),
          isTrue,
        );
      } finally {
        await server.close();
      }
    });

    test('returns false when the host refuses the connection', () async {
      // Port 1 on loopback is never listening, the refusal is immediate.
      expect(
        await canReachStreamHost('http://127.0.0.1:1/a.mp3',
            timeout: const Duration(seconds: 2)),
        isFalse,
      );
    });
  });
}
