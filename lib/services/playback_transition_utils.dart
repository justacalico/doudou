class AutoAdvanceGuard {
  bool _inProgress = false;
  String? _songId;
  int? _queueIndex;

  bool tryAcquire({
    required String songId,
    required int queueIndex,
  }) {
    if (_inProgress && _songId == songId && _queueIndex == queueIndex) {
      return false;
    }
    _inProgress = true;
    _songId = songId;
    _queueIndex = queueIndex;
    return true;
  }

  void reset() {
    _inProgress = false;
    _songId = null;
    _queueIndex = null;
  }
}

int autoAdvanceLeadMsForPlatform({
  required bool isWindows,
  required bool isLinux,
  required bool isIOS,
}) {
  if (isWindows) return 200;
  if (isLinux) return 700;
  if (isIOS) return 500;
  return 0;
}

bool isDoubledDurationMs(int valueMs, int baselineMs) {
  return valueMs >= (baselineMs * 1.8).round() &&
      valueMs <= (baselineMs * 2.2).round();
}

/// The iOS doubled-duration bug only ever inflates values, so a candidate
/// that is roughly 2x another candidate was produced by that bug (for example
/// a player-reported duration that got persisted into the cache) and cannot
/// be trusted as a baseline.
List<int> cleanDurationCandidatesMs(List<int?> candidates) {
  final values =
      candidates.whereType<int>().where((v) => v > 0).toList();
  return values
      .where((v) => !values
          .any((other) => other < v && isDoubledDurationMs(v, other)))
      .toList();
}

/// Picks the most trustworthy baseline duration from [candidates], in order,
/// after dropping inflated values. Returns null when nothing usable exists.
int? pickBaselineDurationMs(List<int?> candidates) {
  final clean = cleanDurationCandidatesMs(candidates);
  return clean.isEmpty ? null : clean.first;
}

/// Estimates the real track duration from the stream's byte size and bitrate.
/// YouTube audio streams are essentially constant bitrate, so this stays
/// accurate within a couple of percent. Returns null for unknown values.
int? streamDurationEstimateMs({
  required int sizeBytes,
  required int bitrateBps,
}) {
  if (sizeBytes <= 0 || bitrateBps <= 0) return null;
  return (sizeBytes * 8000) ~/ bitrateBps;
}

Duration? resolveEffectiveTrackDuration({
  Duration? playerDuration,
  Duration? mediaDuration,
  int? originalDurationMs,
  List<int?> extraBaselineMs = const [],
}) {
  if (playerDuration == null || playerDuration.inMilliseconds <= 0) {
    return mediaDuration;
  }

  final baselineCandidates = cleanDurationCandidatesMs([
    originalDurationMs,
    mediaDuration?.inMilliseconds,
    ...extraBaselineMs,
  ]);
  if (baselineCandidates.isEmpty) {
    return playerDuration;
  }

  final playerMs = playerDuration.inMilliseconds;
  for (final baselineMs in baselineCandidates) {
    if (isDoubledDurationMs(playerMs, baselineMs)) {
      return Duration(milliseconds: baselineMs);
    }
  }
  return playerDuration;
}

bool shouldAutoAdvanceAtPosition({
  required Duration position,
  required Duration effectiveDuration,
  required int leadMs,
}) {
  final thresholdMs =
      (effectiveDuration.inMilliseconds - leadMs).clamp(0, 1 << 30);
  return position.inMilliseconds >= thresholdMs;
}

bool shouldSuppressAutoAdvance({
  required bool isSongLoading,
  required int nowMs,
  required int suppressUntilMs,
}) {
  return isSongLoading || nowMs < suppressUntilMs;
}
