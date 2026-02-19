import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../../models/jellyfin_models.dart';
import '../../base_service.dart';
import '../../media_service_manager.dart';
import 'base_provider_handler.dart';

/// YouTube Music provider handler
/// 
/// Handles YouTube Music-specific playback logic:
/// - Uses ConcatenatingAudioSource (Harmony-Music pattern: clear + add one + play)
/// - Filters expired googlevideo.com URLs
/// - Complex completion handling to avoid spurious completion events
/// - No URL caching (URLs expire quickly)
/// - No preloading (URLs expire)
class YouTubeMusicHandler extends BaseProviderHandler {
  @override
  ServerType get serverType => ServerType.youtubeMusic;

  // Completion cooldown constants
  static const Duration _completionCooldown = Duration(seconds: 3);
  static const Duration _completionIgnoreAfterLoad = Duration(seconds: 5);
  static const Duration _minPositionBeforeCompletion = Duration(seconds: 5);
  static const Duration _trustCompletionAfterPlaying = Duration(seconds: 5);

  @override
  Future<List<String>> getStreamUrls(
    Track track,
    MediaServiceManager mediaService, {
    String? cachedUrl,
    String? preloadedNextUrl,
    String? preloadedPreviousUrl,
  }) async {
    // YouTube Music: never use cache or preloaded URLs – URLs expire quickly; always fetch fresh
    if (kDebugMode) {
      debugPrint('[YouTubeMusicHandler] getStreamUrls: resolving async for track id=${track.id} name=${track.name}');
    }

    // Fetch fresh URLs
    List<String> asyncUrls = await mediaService.getAlternativeStreamUrlsAsync(track.id);
    if (asyncUrls.isEmpty) {
      debugPrint('[YouTubeMusicHandler] getStreamUrls: No stream URLs for track id=${track.id} name=${track.name}');
      return [];
    }

    // Filter valid URLs and check for expiration
    var valid = <String>[];
    for (final url in asyncUrls) {
      if (url.isEmpty) continue;
      final lower = url.toLowerCase();
      if (lower.contains('api.soundcloud.com')) continue;
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        valid.add(url);
      }
    }

    // Drop expired URLs; refetch once if all expired
    if (valid.isNotEmpty) {
      valid = valid.where((url) => !isYouTubeUrlExpired(url)).toList();
      if (valid.isEmpty) {
        if (kDebugMode) {
          debugPrint('[YouTubeMusicHandler] getStreamUrls: all YouTube URLs expired, refetching for track id=${track.id}');
        }
        asyncUrls = await mediaService.getAlternativeStreamUrlsAsync(track.id);
        valid = asyncUrls
            .where((url) =>
                url.isNotEmpty &&
                (url.startsWith('http://') || url.startsWith('https://')) &&
                !url.toLowerCase().contains('api.soundcloud.com') &&
                !isYouTubeUrlExpired(url))
            .toList();
      }
    }

    if (kDebugMode && valid.isNotEmpty) {
      debugPrint('[YouTubeMusicHandler] getStreamUrls: ${valid.length} valid URL(s) for track id=${track.id}');
    }
    return valid;
  }

  @override
  Future<void> preloadStreamUrl(
    Track track,
    MediaServiceManager mediaService,
    void Function(String trackId, String url) onResolved,
  ) async {
    // YouTube Music: skipped – URLs expire quickly; we fetch fresh on play
    return;
  }

  @override
  Future<AudioSource> createAudioSource(
    String url, {
    AudioSource? existingSource,
  }) async {
    // YouTube Music uses ConcatenatingAudioSource pattern (Harmony-Music style)
    // Reuse existing ConcatenatingAudioSource if available
    if (existingSource is ConcatenatingAudioSource) {
      // Clear and add new URL to existing source
      await existingSource.clear();
      await existingSource.add(AudioSource.uri(Uri.parse(url)));
      return existingSource;
    }

    // Create new ConcatenatingAudioSource if none exists
    final concatSource = ConcatenatingAudioSource(
      children: [],
      useLazyPreparation: false,
    );
    await concatSource.add(AudioSource.uri(Uri.parse(url)));
    return concatSource;
  }

  @override
  bool shouldHandleCompletion({
    required PlayerState state,
    required Duration position,
    required Duration? duration,
    required DateTime? loadStartedAt,
    required DateTime? lastCompletionHandledAt,
  }) {
    // YouTube Music: ConcatenatingAudioSource clear()+add() can cause spurious completion
    // events when switching tracks. Ignore completion while loading only in the first few
    // seconds after load (spurious from clear+add); after that, desktop may stay in
    // "loading" (e.g. buffering) so we must still accept real completion.

    // Ignore if we're loading and load started recently
    final loadingAndRecentLoad = state.processingState == ProcessingState.loading &&
        loadStartedAt != null &&
        DateTime.now().difference(loadStartedAt) < _completionIgnoreAfterLoad;
    if (loadingAndRecentLoad) {
      if (kDebugMode) {
        debugPrint('[YouTubeMusicHandler] shouldHandleCompletion: ignoring YT completion while loading');
      }
      return false;
    }

    // Ignore if within cooldown period
    if (lastCompletionHandledAt != null &&
        DateTime.now().difference(lastCompletionHandledAt) < _completionCooldown) {
      if (kDebugMode) {
        debugPrint('[YouTubeMusicHandler] shouldHandleCompletion: ignoring YT completion (cooldown)');
      }
      return false;
    }

    // Ignore if load started recently
    if (loadStartedAt != null &&
        DateTime.now().difference(loadStartedAt) < _completionIgnoreAfterLoad) {
      if (kDebugMode) {
        debugPrint('[YouTubeMusicHandler] shouldHandleCompletion: ignoring YT completion (recent load)');
      }
      return false;
    }

    // If we've been playing long enough, trust completion without position/duration checks
    // (player may reset them at end). On desktop/media_kit state may stay "loading"
    // (e.g. buffering), so do not require state==playing.
    final playingLongEnough = loadStartedAt != null &&
        DateTime.now().difference(loadStartedAt) >= _trustCompletionAfterPlaying;
    if (!playingLongEnough) {
      // Reject if we don't have a real duration (spurious from clear/add)
      if (duration == null || duration <= Duration.zero) {
        if (kDebugMode) {
          debugPrint('[YouTubeMusicHandler] shouldHandleCompletion: ignoring YT completion (no duration)');
        }
        return false;
      }

      // Reject if track barely started (spurious completion right after load).
      // For short tracks, accept when within 1s of end.
      final minPosition = duration > _minPositionBeforeCompletion + const Duration(seconds: 1)
          ? _minPositionBeforeCompletion
          : duration - const Duration(seconds: 1);
      if (position < minPosition) {
        if (kDebugMode) {
          debugPrint('[YouTubeMusicHandler] shouldHandleCompletion: ignoring YT completion (position=$position, min=$minPosition)');
        }
        return false;
      }

      // Reject if not near end of track (not a real completion).
      // Use 10s margin so we accept real completion (player may report position slightly early).
      if (position < duration - const Duration(seconds: 10)) {
        if (kDebugMode) {
          debugPrint('[YouTubeMusicHandler] shouldHandleCompletion: ignoring spurious YT completion (position=$position, duration=$duration)');
        }
        return false;
      }
    }

    return true;
  }

  @override
  bool isValidStreamUrl(String url) {
    // Reject SoundCloud URLs (shouldn't happen, but filter anyway)
    if (url.toLowerCase().contains('api.soundcloud.com')) {
      return false;
    }
    // Reject expired YouTube URLs
    if (isYouTubeUrlExpired(url)) {
      return false;
    }
    return true;
  }

  @override
  List<String> filterStreamUrls(List<String> urls) {
    return urls.where((url) => isValidStreamUrl(url)).toList();
  }

  @override
  bool supportsCaching() => false; // URLs expire quickly

  @override
  bool supportsPreloading() => false; // URLs expire quickly

  @override
  Duration? getCompletionCooldown() => _completionCooldown;

  @override
  Duration? getCompletionIgnoreAfterLoad() => _completionIgnoreAfterLoad;

  @override
  Duration? getMinPositionBeforeCompletion() => _minPositionBeforeCompletion;

  @override
  Duration? getTrustCompletionAfterPlaying() => _trustCompletionAfterPlaying;

  @override
  bool isYouTubeUrlExpired(String url) {
    if (!url.contains('googlevideo.com')) return false;
    try {
      final uri = Uri.parse(url);
      final expireStr = uri.queryParameters['expire'];
      if (expireStr == null) return false;
      final expireSec = int.tryParse(expireStr);
      if (expireSec == null) return false;
      const marginSec = 60;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireSec - marginSec;
    } catch (_) {
      return false;
    }
  }

  @override
  bool shouldWaitForStreamReady() => true; // Wait for duration > 0

  @override
  Duration? getStreamReadyTimeout() => const Duration(seconds: 5);

  @override
  bool throwOnStreamReadyTimeout() => true; // Throw to try next fallback URL
}
