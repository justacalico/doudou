import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../models/hm_streaming_data.dart';
import '../utils/helper.dart';

typedef StreamUrlFetch = Future<HMStreamingData> Function(
  String songId, {
  bool generateNewUrl,
  Map<String, dynamic>? extras,
});

/// Coalesces in-flight stream URL requests so tapping the same song twice (or
/// prefetching a song the user then plays) never fires two network calls.
/// Also exposes [prefetchNext] to warm the URL cache for the upcoming track
/// while the current one is still playing. [onResolved] runs after each
/// prefetched song resolves, letting callers kick off follow-up work like
/// downloading the audio bytes for offline playback.
class StreamPrefetcher {
  StreamPrefetcher(this._fetch, {this.onResolved});

  final StreamUrlFetch _fetch;
  final void Function(String songId, HMStreamingData data)? onResolved;

  final Map<String, Future<HMStreamingData>> _inFlight = {};

  static String _key(String songId, bool generateNewUrl) =>
      '$songId:$generateNewUrl';

  Future<HMStreamingData> resolve(
    String songId, {
    bool generateNewUrl = false,
    Map<String, dynamic>? extras,
  }) {
    final key = _key(songId, generateNewUrl);
    return _inFlight.putIfAbsent(
      key,
      () => _fetch(
        songId,
        generateNewUrl: generateNewUrl,
        extras: extras,
      ).whenComplete(() {
        _inFlight.remove(key);
      }),
    );
  }

  void prefetch(String songId, {Map<String, dynamic>? extras}) {
    unawaited(resolve(songId, extras: extras).then(
      (data) => onResolved?.call(songId, data),
      onError: (e) => printWarning('Prefetch failed for $songId: $e'),
    ));
  }

  void prefetchNext(List<MediaItem> queue, int? currentIndex,
      {int lookahead = 1}) {
    if (queue.isEmpty) return;
    // The index can be stale when the queue was just replaced (updateQueue
    // runs before playByIndex commits the new index). Clamping keeps the
    // prefetch pointed at a real track instead of skipping it entirely.
    final idx = (currentIndex ?? 0).clamp(0, queue.length - 1);
    for (var step = 1; step <= lookahead; step++) {
      final next = idx + step;
      if (next >= queue.length) return;
      final item = queue[next];
      if (_isPrefetchable(item)) {
        prefetch(item.id, extras: item.extras);
      }
    }
  }

  void prefetchCurrentAndNext(List<MediaItem> queue, int? currentIndex,
      {int lookahead = 1}) {
    if (queue.isEmpty) return;
    // Same stale-index handling as prefetchNext.
    final idx = (currentIndex ?? 0).clamp(0, queue.length - 1);
    final current = queue[idx];
    if (_isPrefetchable(current)) {
      prefetch(current.id, extras: current.extras);
    }
    prefetchNext(queue, idx, lookahead: lookahead);
  }

  bool _isPrefetchable(MediaItem item) {
    final backend = item.extras?['backendType']?.toString();
    return backend == null || backend == 'youtubeMusic';
  }

  bool get hasInFlightRequests => _inFlight.isNotEmpty;

  void clear() => _inFlight.clear();
}
