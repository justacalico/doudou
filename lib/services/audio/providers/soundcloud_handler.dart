import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/jellyfin_models.dart';
import '../../base_service.dart';
import '../../media_service_manager.dart';
import 'base_provider_handler.dart';

/// SoundCloud provider handler
/// 
/// Handles SoundCloud-specific playback logic:
/// - Uses async URL resolution (getAlternativeStreamUrlsAsync)
/// - Filters out api.soundcloud.com URLs (player can't send auth headers)
/// - Supports URL caching for gapless playback
/// - Supports preloading
class SoundCloudHandler extends BaseProviderHandler {
  @override
  ServerType get serverType => ServerType.soundcloud;

  @override
  Future<List<String>> getStreamUrls(
    Track track,
    MediaServiceManager mediaService, {
    String? cachedUrl,
    String? preloadedNextUrl,
    String? preloadedPreviousUrl,
  }) async {
    // Check cached URL first
    if (cachedUrl != null && cachedUrl.isNotEmpty && isValidStreamUrl(cachedUrl)) {
      if (kDebugMode) {
        debugPrint('[SoundCloudHandler] getStreamUrls: using cached URL for track id=${track.id}');
      }
      return [cachedUrl];
    }

    // Check preloaded URLs (desktop)
    if (preloadedNextUrl != null && isValidStreamUrl(preloadedNextUrl)) {
      if (kDebugMode) {
        debugPrint('[SoundCloudHandler] getStreamUrls: using preloaded NEXT URL for track id=${track.id}');
      }
      return [preloadedNextUrl];
    }

    if (preloadedPreviousUrl != null && isValidStreamUrl(preloadedPreviousUrl)) {
      if (kDebugMode) {
        debugPrint('[SoundCloudHandler] getStreamUrls: using preloaded PREV URL for track id=${track.id}');
      }
      return [preloadedPreviousUrl];
    }

    // Resolve URLs asynchronously
    if (kDebugMode) {
      debugPrint('[SoundCloudHandler] getStreamUrls: resolving async for track id=${track.id} name=${track.name}');
    }

    List<String> asyncUrls = await mediaService.getAlternativeStreamUrlsAsync(track.id);
    if (asyncUrls.isEmpty) {
      debugPrint('[SoundCloudHandler] getStreamUrls: No stream URLs for track id=${track.id} name=${track.name}');
      return [];
    }

    // Filter valid URLs (reject api.soundcloud.com URLs)
    var valid = <String>[];
    for (final url in asyncUrls) {
      if (url.isEmpty) continue;
      if (isValidStreamUrl(url)) {
        valid.add(url);
      }
    }

    if (kDebugMode && valid.isNotEmpty) {
      debugPrint('[SoundCloudHandler] getStreamUrls: ${valid.length} valid URL(s) for track id=${track.id}');
    }
    return valid;
  }

  @override
  Future<void> preloadStreamUrl(
    Track track,
    MediaServiceManager mediaService,
    void Function(String trackId, String url) onResolved,
  ) async {
    // Preload URL for gapless playback
    try {
      final urls = await mediaService.getAlternativeStreamUrlsAsync(track.id);
      for (final url in urls) {
        if (url.isEmpty) continue;
        if (isValidStreamUrl(url)) {
          onResolved(track.id, url);
          return;
        }
      }
    } catch (_) {
      // Ignore preload errors
    }
  }

  @override
  Future<AudioSource> createAudioSource(
    String url, {
    AudioSource? existingSource,
  }) async {
    // Standard AudioSource.uri() - no special handling
    return AudioSource.uri(Uri.parse(url));
  }

  @override
  bool shouldHandleCompletion({
    required PlayerState state,
    required Duration position,
    required Duration? duration,
    required DateTime? loadStartedAt,
    required DateTime? lastCompletionHandledAt,
  }) {
    // Standard completion handling - no special logic needed
    return true;
  }

  @override
  bool isValidStreamUrl(String url) {
    // Reject api.soundcloud.com URLs (player can't send Authorization header, so they 401)
    final lower = url.toLowerCase();
    if (lower.contains('api.soundcloud.com')) {
      return false;
    }
    // Only accept HTTP/HTTPS URLs
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    return true;
  }

  @override
  List<String> filterStreamUrls(List<String> urls) {
    return urls.where((url) => isValidStreamUrl(url)).toList();
  }

  @override
  bool supportsCaching() => true;

  @override
  bool supportsPreloading() => true;
}
