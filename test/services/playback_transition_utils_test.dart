import 'package:flutter_test/flutter_test.dart';
import 'package:doudou/services/playback_transition_utils.dart';

void main() {
  group('resolveEffectiveTrackDuration', () {
    test('returns player duration for non-iOS', () {
      final result = resolveEffectiveTrackDuration(
        isIOS: false,
        playerDuration: const Duration(seconds: 100),
        mediaDuration: const Duration(seconds: 90),
      );

      expect(result, const Duration(seconds: 100));
    });

    test('uses baseline duration when iOS reports doubled duration', () {
      final result = resolveEffectiveTrackDuration(
        isIOS: true,
        playerDuration: const Duration(seconds: 200),
        mediaDuration: const Duration(seconds: 100),
      );

      expect(result, const Duration(seconds: 100));
    });

    test('uses originalDurationMs over media duration for doubled iOS duration',
        () {
      final result = resolveEffectiveTrackDuration(
        isIOS: true,
        playerDuration: const Duration(milliseconds: 190000),
        mediaDuration: const Duration(milliseconds: 100000),
        originalDurationMs: 95000,
      );

      expect(result, const Duration(milliseconds: 95000));
    });

    test('falls back to media duration when player duration missing', () {
      final result = resolveEffectiveTrackDuration(
        isIOS: true,
        playerDuration: null,
        mediaDuration: const Duration(seconds: 88),
      );

      expect(result, const Duration(seconds: 88));
    });
  });

  group('shouldAutoAdvanceAtPosition', () {
    test('returns true at threshold', () {
      final shouldAdvance = shouldAutoAdvanceAtPosition(
        position: const Duration(milliseconds: 99500),
        effectiveDuration: const Duration(milliseconds: 100000),
        leadMs: 500,
      );

      expect(shouldAdvance, isTrue);
    });

    test('returns false before threshold', () {
      final shouldAdvance = shouldAutoAdvanceAtPosition(
        position: const Duration(milliseconds: 99200),
        effectiveDuration: const Duration(milliseconds: 100000),
        leadMs: 500,
      );

      expect(shouldAdvance, isFalse);
    });
  });

  group('shouldSuppressAutoAdvance', () {
    test('suppresses while song is loading', () {
      final suppressed = shouldSuppressAutoAdvance(
        isSongLoading: true,
        nowMs: 1000,
        suppressUntilMs: 500,
      );
      expect(suppressed, isTrue);
    });

    test('suppresses before suppression window expires', () {
      final suppressed = shouldSuppressAutoAdvance(
        isSongLoading: false,
        nowMs: 1000,
        suppressUntilMs: 1300,
      );
      expect(suppressed, isTrue);
    });

    test('does not suppress when not loading and window expired', () {
      final suppressed = shouldSuppressAutoAdvance(
        isSongLoading: false,
        nowMs: 1301,
        suppressUntilMs: 1300,
      );
      expect(suppressed, isFalse);
    });
  });

  group('AutoAdvanceGuard', () {
    test('prevents duplicate acquisition for same song and index', () {
      final guard = AutoAdvanceGuard();
      final first = guard.tryAcquire(songId: 'song-1', queueIndex: 1);
      final second = guard.tryAcquire(songId: 'song-1', queueIndex: 1);

      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('allows acquisition for next song', () {
      final guard = AutoAdvanceGuard();
      guard.tryAcquire(songId: 'song-1', queueIndex: 1);

      final next = guard.tryAcquire(songId: 'song-2', queueIndex: 2);
      expect(next, isTrue);
    });

    test('allows re-acquisition after reset', () {
      final guard = AutoAdvanceGuard();
      guard.tryAcquire(songId: 'song-1', queueIndex: 1);
      guard.reset();

      final again = guard.tryAcquire(songId: 'song-1', queueIndex: 1);
      expect(again, isTrue);
    });
  });
}
