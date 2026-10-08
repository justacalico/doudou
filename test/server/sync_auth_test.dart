import 'package:doudou/server/sync_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hashSyncPassword / verifySyncPassword', () {
    test('matches the RFC PBKDF2-HMAC-SHA256 vectors', () {
      // Well-known PBKDF2-HMAC-SHA256 vectors guard against a wrong
      // key/message order in the implementation.
      expect(
        hashSyncPassword('password', 'salt', iterations: 1),
        'pbkdf2\$1\$'
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        hashSyncPassword('password', 'salt', iterations: 2),
        'pbkdf2\$2\$'
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
      expect(
        hashSyncPassword('password', 'salt', iterations: 4096),
        'pbkdf2\$4096\$'
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('verifies a hash it produced', () {
      final hash = hashSyncPassword('hunter2', 'somesalt', iterations: 500);
      expect(verifySyncPassword('hunter2', 'somesalt', hash), isTrue);
      expect(verifySyncPassword('wrong', 'somesalt', hash), isFalse);
      expect(verifySyncPassword('hunter2', 'othersalt', hash), isFalse);
    });

    test('verifies the legacy single-sha256 format', () {
      final legacy = legacyHashSyncPassword('pw', 'salt');
      expect(verifySyncPassword('pw', 'salt', legacy), isTrue);
      expect(verifySyncPassword('nope', 'salt', legacy), isFalse);
    });

    test('rejects malformed stored hashes', () {
      expect(verifySyncPassword('pw', 'salt', ''), isFalse);
      expect(verifySyncPassword('pw', 'salt', 'pbkdf2\$abc\$00'), isFalse);
      expect(verifySyncPassword('pw', 'salt', 'pbkdf2\$-5\$00'), isFalse);
      expect(verifySyncPassword('pw', 'salt', 'pbkdf2\$10\$zz'), isFalse);
    });
  });

  group('constantTimeEquals', () {
    test('accepts identical byte lists', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('rejects different bytes and lengths', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });

  group('LoginRateLimiter', () {
    var now = DateTime(2026, 1, 1);

    LoginRateLimiter makeLimiter({int maxFailures = 3}) {
      return LoginRateLimiter(
        maxFailures: maxFailures,
        window: const Duration(minutes: 10),
        clock: () => now,
      );
    }

    test('allows attempts below the limit', () {
      final limiter = makeLimiter();
      limiter.recordFailure('1.2.3.4');
      limiter.recordFailure('1.2.3.4');
      expect(limiter.isLimited('1.2.3.4'), isFalse);
    });

    test('locks out after maxFailures', () {
      final limiter = makeLimiter();
      for (var i = 0; i < 3; i++) {
        limiter.recordFailure('1.2.3.4');
      }
      expect(limiter.isLimited('1.2.3.4'), isTrue);
      // Other clients are unaffected.
      expect(limiter.isLimited('5.6.7.8'), isFalse);
    });

    test('the window slides and allows attempts again', () {
      final limiter = makeLimiter();
      for (var i = 0; i < 3; i++) {
        limiter.recordFailure('1.2.3.4');
      }
      expect(limiter.isLimited('1.2.3.4'), isTrue);
      now = now.add(const Duration(minutes: 11));
      expect(limiter.isLimited('1.2.3.4'), isFalse);
    });

    test('a success clears the failure count', () {
      final limiter = makeLimiter();
      limiter.recordFailure('1.2.3.4');
      limiter.recordFailure('1.2.3.4');
      limiter.recordSuccess('1.2.3.4');
      limiter.recordFailure('1.2.3.4');
      limiter.recordFailure('1.2.3.4');
      expect(limiter.isLimited('1.2.3.4'), isFalse);
    });
  });
}
