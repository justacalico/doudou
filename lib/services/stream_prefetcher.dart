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
/// while the current one is still playing.
class StreamPrefetcher {
  StreamPrefetcher(this._fetch);

  final StreamUrlFetch _fetch;

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
      (_) {},
      onError: (e) => printWarning('Prefetch failed for $songId: $e'),
    ));
  }

  void prefetchNext(List<MediaItem> queue, int? currentIndex) {
    if (queue.isEmpty) return;
    final idx = currentIndex ?? 0;
    if (idx < 0 || idx >= queue.length) return;
    final next = idx + 1;
    if (next < queue.length) {
      final item = queue[next];
      if (_isPrefetchable(item)) {
        prefetch(item.id, extras: item.extras);
      }
    }
  }

  void prefetchCurrentAndNext(List<MediaItem> queue, int? currentIndex) {
    if (queue.isEmpty) return;
    final idx = currentIndex ?? 0;
    if (idx < 0 || idx >= queue.length) return;
    final current = queue[idx];
    if (_isPrefetchable(current)) {
      prefetch(current.id, extras: current.extras);
    }
    prefetchNext(queue, idx);
  }

  bool _isPrefetchable(MediaItem item) {
    final backend = item.extras?['backendType']?.toString();
    return backend == null || backend == 'youtubeMusic';
  }

  bool get hasInFlightRequests => _inFlight.isNotEmpty;

  void clear() => _inFlight.clear();
}
