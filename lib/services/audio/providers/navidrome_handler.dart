import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../../models/jellyfin_models.dart';
import '../../base_service.dart';
import '../../media_service_manager.dart';
import 'base_provider_handler.dart';

/// Navidrome/Jellyfin provider handler
/// 
/// Handles Navidrome/Jellyfin-specific playback logic:
/// - Uses direct stream URLs for faster playback
/// - Standard AudioSource.uri() playback
/// - Standard completion handling
/// - Supports caching and preloading
/// - Duration may not be reported immediately, uses track metadata as fallback
class NavidromeHandler extends BaseProviderHandler {
  @override
  ServerType get serverType => ServerType.subsonic; // Navidrome uses Subsonic API

  @override
  Future<List<String>> getStreamUrls(
    Track track,
    MediaServiceManager mediaService, {
    String? cachedUrl,
    String? preloadedNextUrl,
    String? preloadedPreviousUrl,
  }) async {
    // Check cached URL first
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[NavidromeHandler] getStreamUrls: using cached URL for track id=${track.id}');
      }
      return [cachedUrl];
    }

    // Check preloaded URLs (desktop)
    if (preloadedNextUrl != null) {
      if (kDebugMode) {
        debugPrint('[NavidromeHandler] getStreamUrls: using preloaded NEXT URL for track id=${track.id}');
      }
      return [preloadedNextUrl];
    }

    if (preloadedPreviousUrl != null) {
      if (kDebugMode) {
        debugPrint('[NavidromeHandler] getStreamUrls: using preloaded PREV URL for track id=${track.id}');
      }
      return [preloadedPreviousUrl];
    }

    // Try direct stream URL first (faster playback)
    final directUrl = mediaService.getDirectStreamUrl(track.id);
    if (directUrl.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[NavidromeHandler] getStreamUrls: using direct stream URL for track id=${track.id}');
      }
      return [directUrl];
    }

    // Fallback to transcoded stream URL
    final streamUrl = mediaService.getStreamUrl(track.id);
    if (streamUrl.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[NavidromeHandler] getStreamUrls: using transcoded stream URL for track id=${track.id}');
      }
      return [streamUrl];
    }

    if (kDebugMode) {
      debugPrint('[NavidromeHandler] getStreamUrls: No stream URLs for track id=${track.id} name=${track.name}');
    }
    return [];
  }

  @override
  Future<void> preloadStreamUrl(
    Track track,
    MediaServiceManager mediaService,
    void Function(String trackId, String url) onResolved,
  ) async {
    // Preload direct stream URL for gapless playback
    final directUrl = mediaService.getDirectStreamUrl(track.id);
    if (directUrl.isNotEmpty) {
      onResolved(track.id, directUrl);
      return;
    }

    // Fallback to transcoded URL
    final streamUrl = mediaService.getStreamUrl(track.id);
    if (streamUrl.isNotEmpty) {
      onResolved(track.id, streamUrl);
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
    // On Linux, MPV may emit completion events prematurely when duration is null.
    // Only accept completion if:
    // 1. We have a duration AND position is near the end (within 5 seconds)
    // 2. OR position is > 30 seconds (track played long enough to be real completion)
    
    if (duration != null && duration > Duration.zero) {
      // We have duration - only accept if position is near the end
      final timeRemaining = duration - position;
      if (timeRemaining.inSeconds > 5) {
        if (kDebugMode) {
          debugPrint('[NavidromeHandler] shouldHandleCompletion: rejecting - position=${position.inSeconds}s, duration=${duration.inSeconds}s, ${timeRemaining.inSeconds}s remaining');
        }
        return false;
      }
      // Position is within 5 seconds of end - accept completion
      return true;
    }
    
    // No duration - only accept if track played for at least 30 seconds
    // This prevents premature completion when MPV doesn't report duration
    if (position.inSeconds < 30) {
      if (kDebugMode) {
        debugPrint('[NavidromeHandler] shouldHandleCompletion: rejecting - no duration, position=${position.inSeconds}s < 30s');
      }
      return false;
    }
    
    // Track played for 30+ seconds without duration - likely real completion
    return true;
  }

  @override
  bool supportsCaching() => true;

  @override
  bool supportsPreloading() => true;

  @override
  bool shouldWaitForStreamReady() => false; // Duration may not be reported immediately

  @override
  Duration? getStreamReadyTimeout() => null; // Don't wait for duration
}

/// Jellyfin provider handler
/// 
/// Jellyfin uses the same playback logic as Navidrome (Subsonic API),
/// so we reuse the NavidromeHandler.
class JellyfinHandler extends NavidromeHandler {
  @override
  ServerType get serverType => ServerType.jellyfin;
}
