import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/jellyfin_models.dart';
import '../../base_service.dart';
import '../../media_service_manager.dart';
import 'base_provider_handler.dart';

/// Local Music provider handler
/// 
/// Handles local music file playback:
/// - Uses file:// URLs
/// - Standard AudioSource.uri() playback
/// - Standard completion handling
/// - Supports caching and preloading
class LocalMusicHandler extends BaseProviderHandler {
  @override
  ServerType get serverType => ServerType.local;

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
      return [cachedUrl];
    }

    // Check preloaded URLs (desktop)
    if (preloadedNextUrl != null) {
      return [preloadedNextUrl];
    }

    if (preloadedPreviousUrl != null) {
      return [preloadedPreviousUrl];
    }

    // Try direct stream URL first
    final directUrl = mediaService.getDirectStreamUrl(track.id);
    if (directUrl.isNotEmpty) {
      return [directUrl];
    }

    // Fallback to transcoded stream URL
    final streamUrl = mediaService.getStreamUrl(track.id);
    if (streamUrl.isNotEmpty) {
      return [streamUrl];
    }

    return [];
  }

  @override
  Future<void> preloadStreamUrl(
    Track track,
    MediaServiceManager mediaService,
    void Function(String trackId, String url) onResolved,
  ) async {
    final directUrl = mediaService.getDirectStreamUrl(track.id);
    if (directUrl.isNotEmpty) {
      onResolved(track.id, directUrl);
      return;
    }

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
    return true;
  }

  @override
  bool supportsCaching() => true;

  @override
  bool supportsPreloading() => true;
}
