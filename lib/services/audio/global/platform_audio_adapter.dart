/// Platform Audio Adapter - Abstract interface for platform-specific audio implementations
/// 
/// This file defines the contract that all platform-specific audio implementations
/// must follow. The AudioManager uses this interface to remain platform-agnostic.
library;

import 'dart:async';
import '../../../models/jellyfin_models.dart';
import 'audio_state.dart';

/// Abstract interface for platform-specific audio player implementations.
/// 
/// Each platform (mobile, desktop, web) must implement this interface
/// to provide the actual audio playback functionality.
/// 
/// The AudioManager will use dependency injection to get the appropriate
/// implementation at runtime.
abstract class PlatformAudioAdapter {
  /// Initialize the platform audio player.
  /// 
  /// This should be called once at app startup before any playback.
  /// Returns a result indicating success or failure.
  Future<AudioResult<void>> initialize();
  
  /// Load an audio source for playback.
  /// 
  /// [url] is the audio file URL (can be local or remote).
  /// [track] contains metadata for the audio.
  /// 
  /// Returns the duration of the loaded audio on success.
  Future<AudioResult<Duration>> load(String url, Track track);
  
  /// Start or resume playback.
  Future<AudioResult<void>> play();
  
  /// Pause playback.
  Future<AudioResult<void>> pause();
  
  /// Stop playback and release the audio source.
  Future<AudioResult<void>> stop();
  
  /// Seek to a specific position.
  Future<AudioResult<void>> seek(Duration position);
  
  /// Set the playback volume (0.0 to 1.0).
  Future<AudioResult<void>> setVolume(double volume);
  
  /// Set the playback speed (0.25 to 4.0).
  Future<AudioResult<void>> setSpeed(double speed);
  
  /// Dispose of all resources.
  /// 
  /// After calling this, the adapter cannot be used again.
  Future<void> dispose();
  
  // Streams for state observation
  
  /// Stream of playback phase changes
  Stream<AudioPhase> get phaseStream;
  
  /// Stream of position updates (emits frequently during playback)
  Stream<Duration> get positionStream;
  
  /// Stream of duration changes
  Stream<Duration> get durationStream;
  
  /// Stream of buffered position updates
  Stream<Duration> get bufferedPositionStream;
  
  /// Stream of errors from the player
  Stream<AudioError> get errorStream;
  
  // Current state getters
  
  /// Current playback phase
  AudioPhase get currentPhase;
  
  /// Current playback position
  Duration get currentPosition;
  
  /// Current audio duration
  Duration get currentDuration;
  
  /// Current volume level
  double get currentVolume;
  
  /// Current playback speed
  double get currentSpeed;
  
  /// Whether the player is currently active (playing or paused with content)
  bool get isActive;
  
  /// Get the current audio URL being played
  String? get currentUrl;
}

/// Factory for creating platform-specific audio adapters.
/// 
/// This factory is used by the AudioManager to get the appropriate
/// adapter based on the current platform.
abstract class PlatformAudioAdapterFactory {
  /// Create an adapter for the current platform.
  /// 
  /// [mediaServiceManager] is passed for platforms that need it
  /// to build audio URLs.
  PlatformAudioAdapter create();
}

/// Configuration options for platform adapters
class PlatformAdapterConfig {
  /// Enable audio focus handling (mobile only)
  final bool handleAudioFocus;
  
  /// Enable background playback (mobile only)
  final bool enableBackgroundPlayback;
  
  /// Enable system media controls (notifications, lock screen)
  final bool enableSystemMediaControls;
  
  /// Enable gapless playback between tracks
  final bool enableGaplessPlayback;
  
  /// Audio session category (for iOS)
  final String? audioSessionCategory;
  
  /// Buffer size in milliseconds
  final int bufferSizeMs;
  
  /// Minimum buffer before playback starts
  final int minBufferMs;
  
  /// Maximum buffer size
  final int maxBufferMs;

  const PlatformAdapterConfig({
    this.handleAudioFocus = true,
    this.enableBackgroundPlayback = true,
    this.enableSystemMediaControls = true,
    this.enableGaplessPlayback = true,
    this.audioSessionCategory,
    this.bufferSizeMs = 50000,
    this.minBufferMs = 15000,
    this.maxBufferMs = 50000,
  });
  
  /// Default configuration
  static const PlatformAdapterConfig defaultConfig = PlatformAdapterConfig();
  
  /// Configuration optimized for mobile
  static const PlatformAdapterConfig mobile = PlatformAdapterConfig(
    handleAudioFocus: true,
    enableBackgroundPlayback: true,
    enableSystemMediaControls: true,
    bufferSizeMs: 50000,
    minBufferMs: 15000,
    maxBufferMs: 50000,
  );
  
  /// Configuration optimized for desktop
  static const PlatformAdapterConfig desktop = PlatformAdapterConfig(
    handleAudioFocus: false,
    enableBackgroundPlayback: false,
    enableSystemMediaControls: true,
    bufferSizeMs: 30000,
    minBufferMs: 10000,
    maxBufferMs: 30000,
  );
  
  /// Configuration optimized for web
  static const PlatformAdapterConfig web = PlatformAdapterConfig(
    handleAudioFocus: false,
    enableBackgroundPlayback: false,
    enableSystemMediaControls: false,
    bufferSizeMs: 20000,
    minBufferMs: 5000,
    maxBufferMs: 20000,
  );
}

/// Mixin providing common functionality for platform adapters
mixin PlatformAdapterMixin {
  /// Validate volume is in valid range
  double validateVolume(double volume) => volume.clamp(0.0, 1.0);
  
  /// Validate speed is in valid range
  double validateSpeed(double speed) => speed.clamp(0.25, 4.0);
  
  /// Validate position is within duration
  Duration validatePosition(Duration position, Duration duration) {
    if (position < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
  }
  
  /// Create an error result from an exception
  AudioResult<T> errorFromException<T>(
    Object exception,
    String operation, {
    Track? track,
    StackTrace? stackTrace,
  }) {
    return AudioResult.failure(
      AudioError.fromException(
        exception,
        operation,
        track: track,
        stackTrace: stackTrace,
      ),
    );
  }
}
