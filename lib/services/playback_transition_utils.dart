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

Duration? resolveEffectiveTrackDuration({
  Duration? playerDuration,
  Duration? mediaDuration,
  int? originalDurationMs,
}) {
  if (playerDuration == null || playerDuration.inMilliseconds <= 0) {
    return mediaDuration;
  }

  int? baselineMs = originalDurationMs;
  if ((baselineMs == null || baselineMs <= 0) &&
      mediaDuration != null &&
      mediaDuration.inMilliseconds > 0) {
    baselineMs = mediaDuration.inMilliseconds;
  }

  if (baselineMs == null || baselineMs <= 0) {
    return playerDuration;
  }

  final playerMs = playerDuration.inMilliseconds;
  final isDoubled = playerMs >= (baselineMs * 1.8).round() &&
      playerMs <= (baselineMs * 2.2).round();
  if (isDoubled) {
    return Duration(milliseconds: baselineMs);
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
