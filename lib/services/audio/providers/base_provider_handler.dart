import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../../models/jellyfin_models.dart';
import '../../base_service.dart';
import '../../media_service_manager.dart';

/// Base class for provider-specific audio handlers
/// 
/// Each provider (YouTube Music, SoundCloud, Navidrome, etc.) implements this interface
/// to handle provider-specific playback logic, URL resolution, and completion detection.
/// 
/// The main UnifiedAudioHandler delegates provider-specific operations to these handlers,
/// keeping the core playback logic clean and extensible.
abstract class BaseProviderHandler {
  /// Provider type this handler manages
  ServerType get serverType;

  /// Get stream URLs for a track
  /// 
  /// Returns a list of URLs to try in order (for fallback support).
  /// The handler should resolve URLs using the MediaServiceManager and apply
  /// any provider-specific filtering or validation.
  /// 
  /// [track] - The track to get URLs for
  /// [mediaService] - MediaServiceManager for accessing provider services
  /// [cachedUrls] - Previously cached/resolved URLs (if any)
  /// [preloadedUrls] - Preloaded URLs from desktop preloading system
  /// 
  /// Returns list of valid stream URLs, empty if none found
  Future<List<String>> getStreamUrls(
    Track track,
    MediaServiceManager mediaService, {
    String? cachedUrl,
    String? preloadedNextUrl,
    String? preloadedPreviousUrl,
  });

  /// Preload stream URL for a track (for gapless playback)
  /// 
  /// Called when queue is set or user is about to play a track.
  /// Providers that don't support preloading should do nothing.
  /// 
  /// [track] - The track to preload
  /// [mediaService] - MediaServiceManager for accessing provider services
  /// [onResolved] - Callback when URL is resolved (for caching)
  Future<void> preloadStreamUrl(
    Track track,
    MediaServiceManager mediaService,
    void Function(String trackId, String url) onResolved,
  );

  /// Create an AudioSource for playback
  /// 
  /// Providers can return custom AudioSource implementations (e.g., ConcatenatingAudioSource
  /// for YouTube Music) or standard AudioSource.uri() for most providers.
  /// 
  /// [url] - The stream URL to create source for
  /// [existingSource] - Existing source (e.g., ConcatenatingAudioSource) to reuse if applicable
  /// 
  /// Returns AudioSource ready for playback
  Future<AudioSource> createAudioSource(
    String url, {
    AudioSource? existingSource,
  });

  /// Check if a completion event should be handled
  /// 
  /// Providers can implement custom completion detection logic to filter out
  /// spurious completion events (e.g., YouTube Music ConcatenatingAudioSource).
  /// 
  /// [state] - Current player state
  /// [position] - Current playback position
  /// [duration] - Track duration (may be null)
  /// [loadStartedAt] - When track loading started (for cooldown checks)
  /// [lastCompletionHandledAt] - When last completion was handled (for cooldown)
  /// 
  /// Returns true if completion should be handled, false to ignore
  bool shouldHandleCompletion({
    required PlayerState state,
    required Duration position,
    required Duration? duration,
    required DateTime? loadStartedAt,
    required DateTime? lastCompletionHandledAt,
  });

  /// Handle track completion (provider-specific logic)
  /// 
  /// Called when a completion event is accepted. Most providers don't need
  /// custom handling here, but providers can override for special logic.
  Future<void> handleCompletion() async {
    // Default: no special handling needed
  }

  /// Validate if a stream URL is valid for this provider
  /// 
  /// Used to filter out invalid URLs (e.g., SoundCloud API URLs that require auth).
  /// 
  /// [url] - URL to validate
  /// Returns true if URL is valid for playback
  bool isValidStreamUrl(String url) => true;

  /// Filter stream URLs to remove invalid ones
  /// 
  /// Providers can override to remove URLs that won't work (e.g., expired YouTube URLs,
  /// SoundCloud API URLs, etc.).
  /// 
  /// [urls] - List of URLs to filter
  /// Returns filtered list of valid URLs
  List<String> filterStreamUrls(List<String> urls) {
    return urls.where((url) => isValidStreamUrl(url)).toList();
  }

  /// Whether this provider supports URL caching
  /// 
  /// Some providers (e.g., YouTube Music) have URLs that expire quickly,
  /// so caching should be disabled.
  bool supportsCaching() => true;

  /// Whether this provider supports URL preloading
  /// 
  /// Preloading can improve gapless playback, but some providers (e.g., YouTube Music)
  /// have URLs that expire, making preloading ineffective.
  bool supportsPreloading() => true;

  /// Get completion cooldown duration
  /// 
  /// Returns the minimum time between completion events to prevent spurious
  /// completions. Returns null if no cooldown needed.
  Duration? getCompletionCooldown() => null;

  /// Get duration to ignore completions after load starts
  /// 
  /// Some providers emit spurious completion events immediately after loading.
  /// Returns the duration to ignore completions after load starts, or null if not needed.
  Duration? getCompletionIgnoreAfterLoad() => null;

  /// Get minimum position before accepting completion
  /// 
  /// Prevents accepting very early completion events. Returns null if no minimum needed.
  Duration? getMinPositionBeforeCompletion() => null;

  /// Get duration to trust completion without position/duration checks
  /// 
  /// After playing for this duration, trust completion events even if position/duration
  /// checks fail (player may reset them at end). Returns null if not needed.
  Duration? getTrustCompletionAfterPlaying() => null;

  /// Check if a YouTube URL is expired
  /// 
  /// Helper method for YouTube Music handler. Other providers can ignore.
  bool isYouTubeUrlExpired(String url) => false;

  /// Wait for stream to be ready before proceeding
  /// 
  /// Some providers need to wait for the stream to actually load (duration > 0)
  /// before considering playback successful. Returns true if waiting is required.
  bool shouldWaitForStreamReady() => false;

  /// Get timeout for waiting for stream ready
  /// 
  /// Returns the timeout duration for waitForStreamReady, or null if not needed.
  Duration? getStreamReadyTimeout() => null;

  /// Whether to throw on stream ready timeout
  /// 
  /// If true, throws exception on timeout (for fallback URL handling).
  /// If false, continues even if timeout (for providers that don't report duration).
  bool throwOnStreamReadyTimeout() => false;
}
