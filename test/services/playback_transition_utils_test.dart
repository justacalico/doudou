import 'package:doudou/services/playback_transition_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoAdvanceGuard', () {
    test('acquires on first call for a song', () {
      final guard = AutoAdvanceGuard();

      expect(guard.tryAcquire(songId: 's1', queueIndex: 0), isTrue);
    });

    test('blocks duplicate calls for the same song and index', () {
      final guard = AutoAdvanceGuard();

      guard.tryAcquire(songId: 's1', queueIndex: 0);
      expect(guard.tryAcquire(songId: 's1', queueIndex: 0), isFalse);
    });

    test('allows a new song after a different one', () {
      final guard = AutoAdvanceGuard();

      guard.tryAcquire(songId: 's1', queueIndex: 0);
      expect(guard.tryAcquire(songId: 's2', queueIndex: 1), isTrue);
    });

    test('allows same song after reset', () {
      final guard = AutoAdvanceGuard();

      guard.tryAcquire(songId: 's1', queueIndex: 0);
      guard.reset();
      expect(guard.tryAcquire(songId: 's1', queueIndex: 0), isTrue);
    });

    test('blocks same song at same index but allows different index', () {
      final guard = AutoAdvanceGuard();

      guard.tryAcquire(songId: 's1', queueIndex: 0);
      expect(guard.tryAcquire(songId: 's1', queueIndex: 1), isTrue);
    });
  });

  group('autoAdvanceLeadMsForPlatform', () {
    test('returns 200 for Windows', () {
      expect(
        autoAdvanceLeadMsForPlatform(isWindows: true, isLinux: false, isIOS: false),
        200,
      );
    });

    test('returns 700 for Linux', () {
      expect(
        autoAdvanceLeadMsForPlatform(isWindows: false, isLinux: true, isIOS: false),
        700,
      );
    });

    test('returns 500 for iOS', () {
      expect(
        autoAdvanceLeadMsForPlatform(isWindows: false, isLinux: false, isIOS: true),
        500,
      );
    });

    test('returns 0 for other platforms (e.g. macOS, Android)', () {
      expect(
        autoAdvanceLeadMsForPlatform(isWindows: false, isLinux: false, isIOS: false),
        0,
      );
    });

    test('Windows takes priority over Linux and iOS', () {
      expect(
        autoAdvanceLeadMsForPlatform(isWindows: true, isLinux: true, isIOS: true),
        200,
      );
    });

    test('Linux takes priority over iOS', () {
      expect(
        autoAdvanceLeadMsForPlatform(isWindows: false, isLinux: true, isIOS: true),
        700,
      );
    });
  });

  group('isDoubledDurationMs', () {
    test('returns true inside the 1.8x-2.2x band', () {
      expect(isDoubledDurationMs(360000, 200000), isTrue);
      expect(isDoubledDurationMs(400000, 200000), isTrue);
      expect(isDoubledDurationMs(440000, 200000), isTrue);
    });

    test('returns false outside the band', () {
      expect(isDoubledDurationMs(200000, 200000), isFalse);
      expect(isDoubledDurationMs(350000, 200000), isFalse);
      expect(isDoubledDurationMs(500000, 200000), isFalse);
    });
  });

  group('cleanDurationCandidatesMs', () {
    test('drops a candidate that is ~2x another candidate', () {
      // 360s looks like a doubled 180s, so it is removed.
      expect(
        cleanDurationCandidatesMs([360000, 180000]),
        [180000],
      );
    });

    test('keeps healthy equal candidates', () {
      expect(
        cleanDurationCandidatesMs([180000, 181000, 180500]),
        [180000, 181000, 180500],
      );
    });

    test('keeps candidates that differ by less than the doubled band', () {
      expect(
        cleanDurationCandidatesMs([200000, 240000]),
        [200000, 240000],
      );
    });

    test('filters out null and non-positive values', () {
      expect(
        cleanDurationCandidatesMs([null, 0, -5, 180000]),
        [180000],
      );
    });

    test('returns empty list when nothing is usable', () {
      expect(cleanDurationCandidatesMs([null, 0]), isEmpty);
    });
  });

  group('pickBaselineDurationMs', () {
    test('returns first usable candidate', () {
      expect(pickBaselineDurationMs([200000, 180000]), 200000);
    });

    test('skips an inflated first candidate', () {
      expect(pickBaselineDurationMs([360000, 180000]), 180000);
    });

    test('returns null when no candidate is usable', () {
      expect(pickBaselineDurationMs([null, 0, -1]), isNull);
    });
  });

  group('streamDurationEstimateMs', () {
    test('computes duration from size and bitrate', () {
      // 2.88 MB at 128 kbps = 180 seconds
      expect(
        streamDurationEstimateMs(sizeBytes: 2880000, bitrateBps: 128000),
        180000,
      );
    });

    test('returns null when size or bitrate is unknown', () {
      expect(
          streamDurationEstimateMs(sizeBytes: 0, bitrateBps: 128000), isNull);
      expect(
          streamDurationEstimateMs(sizeBytes: 2880000, bitrateBps: 0), isNull);
      expect(
          streamDurationEstimateMs(sizeBytes: -1, bitrateBps: -1), isNull);
    });
  });

  group('resolveEffectiveTrackDuration', () {
    test('returns mediaDuration when playerDuration is null', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: null,
        mediaDuration: const Duration(seconds: 200),
        originalDurationMs: 200000,
      );

      expect(result, const Duration(seconds: 200));
    });

    test('returns mediaDuration when playerDuration is zero', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: Duration.zero,
        mediaDuration: const Duration(seconds: 200),
        originalDurationMs: 200000,
      );

      expect(result, const Duration(seconds: 200));
    });

    test('returns playerDuration when no baseline available', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 210),
        mediaDuration: null,
        originalDurationMs: null,
      );

      expect(result, const Duration(seconds: 210));
    });

    test('detects doubled duration and returns baseline', () {
      // baseline 200s, player reports ~400s (within 1.8x-2.2x band)
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 400),
        mediaDuration: const Duration(seconds: 200),
        originalDurationMs: 200000,
      );

      expect(result, const Duration(seconds: 200));
    });

    test('detects doubled duration using mediaDuration as baseline', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(milliseconds: 410000),
        mediaDuration: const Duration(seconds: 200),
        originalDurationMs: null,
      );

      expect(result, const Duration(seconds: 200));
    });

    test('returns playerDuration when not doubled', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 210),
        mediaDuration: const Duration(seconds: 200),
        originalDurationMs: 200000,
      );

      expect(result, const Duration(seconds: 210));
    });

    test('returns playerDuration when duration is more than 2.2x baseline', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 500),
        mediaDuration: const Duration(seconds: 200),
        originalDurationMs: 200000,
      );

      expect(result, const Duration(seconds: 500));
    });

    test('returns playerDuration when duration is less than 1.8x baseline', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 350),
        mediaDuration: const Duration(seconds: 200),
        originalDurationMs: 200000,
      );

      expect(result, const Duration(seconds: 350));
    });

    test('corrects a doubled duration even when stored metadata is polluted', () {
      // A 180s song whose cached duration/originalDurationMs were corrupted to
      // the doubled 360s value. The 'length'-derived baseline still detects it.
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 360),
        mediaDuration: const Duration(seconds: 360),
        originalDurationMs: 360000,
        extraBaselineMs: [180000],
      );

      expect(result, const Duration(seconds: 180));
    });

    test('uses extra baseline when metadata is missing entirely', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 360),
        mediaDuration: null,
        originalDurationMs: null,
        extraBaselineMs: [180000],
      );

      expect(result, const Duration(seconds: 180));
    });

    test('returns playerDuration when player is not doubled vs extra baseline', () {
      final result = resolveEffectiveTrackDuration(
        playerDuration: const Duration(seconds: 190),
        mediaDuration: null,
        originalDurationMs: null,
        extraBaselineMs: [180000],
      );

      expect(result, const Duration(seconds: 190));
    });
  });

  group('shouldAutoAdvanceAtPosition', () {
    test('returns true when position passes threshold', () {
      // threshold = 200000ms - 200ms = 199800ms; 199900ms >= 199800ms
      expect(
        shouldAutoAdvanceAtPosition(
          position: const Duration(milliseconds: 199900),
          effectiveDuration: const Duration(seconds: 200),
          leadMs: 200,
        ),
        isTrue,
      );
    });

    test('returns false when position is before threshold', () {
      expect(
        shouldAutoAdvanceAtPosition(
          position: const Duration(seconds: 100),
          effectiveDuration: const Duration(seconds: 200),
          leadMs: 200,
        ),
        isFalse,
      );
    });

    test('returns true at exact threshold', () {
      // 200000ms - 200ms = 199800ms
      expect(
        shouldAutoAdvanceAtPosition(
          position: const Duration(milliseconds: 199800),
          effectiveDuration: const Duration(seconds: 200),
          leadMs: 200,
        ),
        isTrue,
      );
    });

    test('handles zero lead time', () {
      expect(
        shouldAutoAdvanceAtPosition(
          position: const Duration(seconds: 200),
          effectiveDuration: const Duration(seconds: 200),
          leadMs: 0,
        ),
        isTrue,
      );
    });

    test('clamps threshold to 0 when lead exceeds duration', () {
      expect(
        shouldAutoAdvanceAtPosition(
          position: Duration.zero,
          effectiveDuration: const Duration(seconds: 1),
          leadMs: 5000,
        ),
        isTrue,
      );
    });
  });

  group('shouldSuppressAutoAdvance', () {
    test('returns true when song is loading', () {
      expect(
        shouldSuppressAutoAdvance(
          isSongLoading: true,
          nowMs: 999999,
          suppressUntilMs: 0,
        ),
        isTrue,
      );
    });

    test('returns true when now is before suppressUntil', () {
      expect(
        shouldSuppressAutoAdvance(
          isSongLoading: false,
          nowMs: 100,
          suppressUntilMs: 500,
        ),
        isTrue,
      );
    });

    test('returns false when not loading and now is at suppressUntil', () {
      expect(
        shouldSuppressAutoAdvance(
          isSongLoading: false,
          nowMs: 500,
          suppressUntilMs: 500,
        ),
        isFalse,
      );
    });

    test('returns false when not loading and now is after suppressUntil', () {
      expect(
        shouldSuppressAutoAdvance(
          isSongLoading: false,
          nowMs: 1000,
          suppressUntilMs: 500,
        ),
        isFalse,
      );
    });
  });

  group('isSongLoadWedge', () {
    test('returns false when nothing is loading', () {
      expect(
        isSongLoadWedge(
          isSongLoading: false,
          loadingSinceMs: 1,
          nowMs: songLoadingWedgeMs + 1000,
        ),
        isFalse,
      );
    });

    test('returns false while a load is still inside the window', () {
      expect(
        isSongLoadWedge(
          isSongLoading: true,
          loadingSinceMs: 1000,
          nowMs: 1000 + songLoadingWedgeMs,
        ),
        isFalse,
      );
    });

    test('returns true once the load outlives the wedge window', () {
      expect(
        isSongLoadWedge(
          isSongLoading: true,
          loadingSinceMs: 1000,
          nowMs: 1000 + songLoadingWedgeMs + 1,
        ),
        isTrue,
      );
    });

    test('returns false when the load was never timestamped', () {
      expect(
        isSongLoadWedge(
          isSongLoading: true,
          loadingSinceMs: 0,
          nowMs: 999999999,
        ),
        isFalse,
      );
    });
  });
}
