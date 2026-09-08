import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '/models/hm_streaming_data.dart';
import '/services/stream_service.dart';
import '/utils/helper.dart';
import '/utils/server_storage.dart';
import '/services/utils.dart';

/// Fetches and caches YouTube Music stream URLs. Keeps a single [YoutubeExplode]
/// open so subsequent calls reuse TCP/TLS sessions and any player-state that the
/// underlying library caches, instead of doing a cold start for every song.
class StreamResolver {
  factory StreamResolver({StreamProviderFetch? fetcher}) {
    if (fetcher != null) return StreamResolver._(fetcher, null);

    final yt = YoutubeExplode();
    Future<StreamProvider> defaultFetcher(String songId,
            {bool requireWatchPage = true}) =>
        StreamProvider.fetch(songId,
            youtubeExplode: yt, requireWatchPage: requireWatchPage);
    return StreamResolver._(defaultFetcher, yt);
  }

  StreamResolver._(this._fetcher, this._youtubeExplode);

  final StreamProviderFetch _fetcher;
  final YoutubeExplode? _youtubeExplode;
  final Map<String, _CachedStreamData> _memoryCache = {};
  final Map<String, Future<HMStreamingData>> _pending = {};
  final Map<String, Future<HMStreamingData>> _pendingForce = {};

  /// Resolves the stream URL for [songId], using the in-memory cache, the Hive
  /// URL cache, or a fresh network call in that order. [forceRefresh] ignores
  /// caches and starts a new network call.
  Future<HMStreamingData> resolve(String songId,
      {bool forceRefresh = false}) {
    songId = _stripPipedPrefix(songId);
    final pendingMap = forceRefresh ? _pendingForce : _pending;

    return pendingMap
        .putIfAbsent(
            songId,
            () => _doResolve(songId, forceRefresh: forceRefresh)
                .whenComplete(() {
              _pending.remove(songId);
              _pendingForce.remove(songId);
            }))
        .catchError((e) {
      return HMStreamingData(playable: false, statusMSG: e.toString());
    });
  }

  Future<HMStreamingData> _doResolve(String songId,
      {required bool forceRefresh}) async {
    if (!forceRefresh) {
      final cached = _memoryCache[songId];
      if (cached != null && !_isEntryExpired(songId, cached)) {
        return cached.data;
      }
    }

    if (!forceRefresh) {
      final box = await Hive.openBox(songsUrlCacheBoxName(currentServerId()));
      final cachedJson = box.get(songId);
      if (cachedJson is Map) {
        try {
          final data = HMStreamingData.fromJson(cachedJson);
          final url = data.audio?.url;
          if (data.playable &&
              url != null &&
              url.isNotEmpty &&
              !isExpired(url: url)) {
            _memoryCache[songId] = _CachedStreamData(data);
            return data;
          }
        } catch (_) {
          // corrupted cache entry, fetch fresh below
        }
      }
    }

    return _fetchAndCache(songId);
  }

  /// Resolves [songId] in the background. Errors are swallowed.
  void prefetch(String songId) {
    songId = _stripPipedPrefix(songId);
    unawaited(resolve(songId).then(
      (_) {},
      onError: (e) => printWarning('Prefetch failed for $songId: $e'),
    ));
  }

  /// Resolves the song at [currentIndex] and the next one so that starting
  /// playback and skipping to the next track both hit a ready URL.
  void prefetchQueue(List<MediaItem> queue, int? currentIndex) {
    if (queue.isEmpty) return;
    final start = (currentIndex ?? 0).clamp(0, queue.length - 1);
    final end = (start + 1).clamp(0, queue.length - 1);
    for (var i = start; i <= end; i++) {
      final item = queue[i];
      if (_isYouTubeMusicItem(item)) {
        prefetch(item.id);
      }
    }
  }

  void dispose() {
    _memoryCache.clear();
    _pending.clear();
    _pendingForce.clear();
    _youtubeExplode?.close();
  }

  Future<HMStreamingData> _fetchAndCache(String songId) async {
    try {
      final provider = await _fetcher(songId, requireWatchPage: false);
      final data = _toHMStreamingData(provider);

      if (data.playable) {
        _memoryCache[songId] = _CachedStreamData(data);
        final box = await Hive.openBox(songsUrlCacheBoxName(currentServerId()));
        box.put(songId, data.toJson());
      }

      return data;
    } catch (e) {
      return HMStreamingData(playable: false, statusMSG: e.toString());
    }
  }

  HMStreamingData _toHMStreamingData(StreamProvider provider) {
    if (!provider.playable) {
      return HMStreamingData(
          playable: false, statusMSG: provider.statusMSG);
    }

    final low = provider.lowQualityAudio;
    final high = provider.highestQualityAudio;
    if (high == null) {
      return HMStreamingData(
          playable: false, statusMSG: 'No audio stream found');
    }

    return HMStreamingData(
      playable: true,
      statusMSG: 'OK',
      lowQualityAudio: low,
      highQualityAudio: high,
    );
  }

  bool _isEntryExpired(String songId, _CachedStreamData cached) {
    final url = cached.data.audio?.url;
    if (url != null && url.isNotEmpty && isExpired(url: url)) {
      _memoryCache.remove(songId);
      return true;
    }

    if (DateTime.now().difference(cached.cachedAt).inMinutes > 30) {
      _memoryCache.remove(songId);
      return true;
    }
    return false;
  }

  bool _isYouTubeMusicItem(MediaItem item) {
    final backendType = item.extras?['backendType']?.toString();
    return backendType == null || backendType == 'youtubeMusic';
  }

  String _stripPipedPrefix(String songId) {
    if (songId.startsWith('MPED')) {
      return songId.substring(4);
    }
    return songId;
  }
}

/// Signature for the function that turns a song id into a [StreamProvider].
/// Used by [StreamResolver] so tests can inject a fake without touching
/// [YoutubeExplode].
typedef StreamProviderFetch = Future<StreamProvider> Function(
  String songId, {
  bool requireWatchPage,
});

class _CachedStreamData {
  final HMStreamingData data;
  final DateTime cachedAt;

  _CachedStreamData(this.data, {DateTime? cachedAt})
      : cachedAt = cachedAt ?? DateTime.now();
}
