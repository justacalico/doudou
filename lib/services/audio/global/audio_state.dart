/// Global Audio State - Immutable state objects for the AudioManager
/// 
/// This file contains all the immutable state classes used by the global
/// AudioManager. All state objects are immutable to ensure thread safety
/// and prevent accidental mutations.
library;

import 'package:flutter/foundation.dart';
import '../../../models/jellyfin_models.dart';

/// The current phase of the audio player state machine.
/// 
/// State transitions:
/// ```
/// IDLE → LOADING → READY → PLAYING ↔ PAUSED → STOPPED → IDLE
///                    ↓         ↓         ↓
///                  ERROR ←←←←←←←←←←←←←←←←←
/// ```
enum AudioPhase {
  /// No audio loaded, player is inactive
  idle,
  
  /// Audio source is being loaded/buffered
  loading,
  
  /// Audio is loaded and ready to play
  ready,
  
  /// Audio is actively playing
  playing,
  
  /// Audio is paused (can resume)
  paused,
  
  /// Audio has been stopped (must reload to play)
  stopped,
  
  /// An error occurred during playback
  error,
  
  /// Audio track completed naturally
  completed,
}

/// Repeat mode for queue playback
enum AudioRepeatMode {
  /// No repeat - stop after queue ends
  none,
  
  /// Repeat current track
  one,
  
  /// Repeat entire queue
  all,
}

/// Shuffle mode for queue playback
enum AudioShuffleMode {
  /// Play in order
  none,
  
  /// Play in random order
  all,
}

/// Immutable audio state object.
/// 
/// This is the single source of truth for all audio state.
/// Create new instances using [copyWith] to update state.
/// 
/// Example:
/// ```dart
/// final newState = currentState.copyWith(phase: AudioPhase.playing);
/// ```
@immutable
class AudioState {
  /// Current phase of the audio player
  final AudioPhase phase;
  
  /// Current playback position
  final Duration position;
  
  /// Total duration of current track
  final Duration duration;
  
  /// Current volume (0.0 to 1.0)
  final double volume;
  
  /// Current playback speed (0.25 to 4.0)
  final double speed;
  
  /// Currently playing track (null if none)
  final Track? currentTrack;
  
  /// Current index in the queue
  final int? currentIndex;
  
  /// The playback queue
  final List<Track> queue;
  
  /// Current repeat mode
  final AudioRepeatMode repeatMode;
  
  /// Current shuffle mode
  final AudioShuffleMode shuffleMode;
  
  /// Whether gapless playback is enabled
  final bool gaplessPlayback;
  
  /// Whether radio mode is enabled (auto-queue similar tracks)
  final bool radioMode;
  
  /// Last error message (null if no error)
  final String? errorMessage;
  
  /// Timestamp when this state was created
  final DateTime timestamp;
  
  /// Whether the user explicitly requested playback
  final bool userIntendedPlaying;
  
  /// Buffered position (for streaming)
  final Duration bufferedPosition;

  const AudioState({
    this.phase = AudioPhase.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.speed = 1.0,
    this.currentTrack,
    this.currentIndex,
    this.queue = const [],
    this.repeatMode = AudioRepeatMode.none,
    this.shuffleMode = AudioShuffleMode.none,
    this.gaplessPlayback = false,
    this.radioMode = false,
    this.errorMessage,
    required this.timestamp,
    this.userIntendedPlaying = false,
    this.bufferedPosition = Duration.zero,
  });
  
  /// Create initial idle state
  factory AudioState.initial() => AudioState(
    timestamp: DateTime.now(),
  );
  
  /// Create a copy with updated fields
  AudioState copyWith({
    AudioPhase? phase,
    Duration? position,
    Duration? duration,
    double? volume,
    double? speed,
    Track? currentTrack,
    bool clearCurrentTrack = false,
    int? currentIndex,
    bool clearCurrentIndex = false,
    List<Track>? queue,
    AudioRepeatMode? repeatMode,
    AudioShuffleMode? shuffleMode,
    bool? gaplessPlayback,
    bool? radioMode,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? userIntendedPlaying,
    Duration? bufferedPosition,
  }) {
    return AudioState(
      phase: phase ?? this.phase,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      currentTrack: clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      currentIndex: clearCurrentIndex ? null : (currentIndex ?? this.currentIndex),
      queue: queue ?? this.queue,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      radioMode: radioMode ?? this.radioMode,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      timestamp: DateTime.now(),
      userIntendedPlaying: userIntendedPlaying ?? this.userIntendedPlaying,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
    );
  }
  
  /// Whether there is a next track in the queue
  bool get hasNext => currentIndex != null && currentIndex! < queue.length - 1;
  
  /// Whether there is a previous track in the queue
  bool get hasPrevious => currentIndex != null && currentIndex! > 0;
  
  /// Get remaining tracks after current
  List<Track> get upNext {
    if (currentIndex == null || queue.isEmpty) return [];
    if (currentIndex! >= queue.length - 1) return [];
    return queue.sublist(currentIndex! + 1);
  }
  
  /// Whether audio is currently playing or loading
  bool get isActive => phase == AudioPhase.playing || 
                       phase == AudioPhase.loading ||
                       phase == AudioPhase.paused;
  
  /// Whether playback can be resumed
  bool get canResume => phase == AudioPhase.paused || phase == AudioPhase.ready;
  
  /// Whether a new track can be loaded
  bool get canLoad => phase != AudioPhase.loading;
  
  /// Progress as a value between 0.0 and 1.0
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
  
  /// Buffered progress as a value between 0.0 and 1.0
  double get bufferedProgress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AudioState) return false;
    
    return other.phase == phase &&
           other.position == position &&
           other.duration == duration &&
           other.volume == volume &&
           other.speed == speed &&
           other.currentTrack?.id == currentTrack?.id &&
           other.currentIndex == currentIndex &&
           listEquals(other.queue, queue) &&
           other.repeatMode == repeatMode &&
           other.shuffleMode == shuffleMode &&
           other.gaplessPlayback == gaplessPlayback &&
           other.radioMode == radioMode &&
           other.errorMessage == errorMessage &&
           other.userIntendedPlaying == userIntendedPlaying &&
           other.bufferedPosition == bufferedPosition;
  }

  @override
  int get hashCode => Object.hash(
    phase,
    position,
    duration,
    volume,
    speed,
    currentTrack?.id,
    currentIndex,
    queue.length,
    repeatMode,
    shuffleMode,
    gaplessPlayback,
    radioMode,
    errorMessage,
    userIntendedPlaying,
    bufferedPosition,
  );

  @override
  String toString() => 'AudioState('
      'phase: $phase, '
      'position: $position, '
      'duration: $duration, '
      'track: ${currentTrack?.name ?? "none"}, '
      'index: $currentIndex/${queue.length}'
      ')';
}

/// Represents an audio error with context
@immutable
class AudioError {
  /// The type of error
  final AudioErrorType type;
  
  /// Human-readable error message
  final String message;
  
  /// The operation that was being performed
  final String operation;
  
  /// The track that was involved (if any)
  final Track? track;
  
  /// The underlying exception (if any)
  final Object? exception;
  
  /// Stack trace (if available)
  final StackTrace? stackTrace;
  
  /// When the error occurred
  final DateTime timestamp;
  
  /// Whether this error is recoverable
  final bool isRecoverable;

  const AudioError({
    required this.type,
    required this.message,
    required this.operation,
    this.track,
    this.exception,
    this.stackTrace,
    required this.timestamp,
    this.isRecoverable = true,
  });
  
  factory AudioError.fromException(
    Object exception,
    String operation, {
    Track? track,
    StackTrace? stackTrace,
  }) {
    AudioErrorType type;
    String message;
    bool isRecoverable = true;
    
    final exceptionString = exception.toString().toLowerCase();
    
    if (exceptionString.contains('timeout')) {
      type = AudioErrorType.timeout;
      message = 'Operation timed out. Please try again.';
    } else if (exceptionString.contains('network') || 
               exceptionString.contains('connection') ||
               exceptionString.contains('socket')) {
      type = AudioErrorType.network;
      message = 'Network error. Please check your connection.';
    } else if (exceptionString.contains('format') ||
               exceptionString.contains('codec') ||
               exceptionString.contains('decode')) {
      type = AudioErrorType.format;
      message = 'Audio format not supported.';
      isRecoverable = false;
    } else if (exceptionString.contains('permission')) {
      type = AudioErrorType.permission;
      message = 'Permission denied for audio playback.';
      isRecoverable = false;
    } else if (exceptionString.contains('not found') ||
               exceptionString.contains('404')) {
      type = AudioErrorType.notFound;
      message = 'Audio file not found.';
      isRecoverable = false;
    } else {
      type = AudioErrorType.unknown;
      message = 'An unexpected error occurred: ${exception.toString()}';
    }
    
    return AudioError(
      type: type,
      message: message,
      operation: operation,
      track: track,
      exception: exception,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      isRecoverable: isRecoverable,
    );
  }

  @override
  String toString() => 'AudioError($type: $message during $operation)';
}

/// Types of audio errors
enum AudioErrorType {
  /// Network-related error
  network,
  
  /// Operation timed out
  timeout,
  
  /// Audio format not supported
  format,
  
  /// Permission denied
  permission,
  
  /// Audio file not found
  notFound,
  
  /// Player internal error
  player,
  
  /// State transition error
  state,
  
  /// Unknown error
  unknown,
}

/// Operation result wrapper for type-safe error handling
@immutable
class AudioResult<T> {
  final T? value;
  final AudioError? error;
  final bool isSuccess;

  const AudioResult.success(this.value) 
      : error = null, 
        isSuccess = true;
  
  const AudioResult.failure(this.error) 
      : value = null, 
        isSuccess = false;

  /// Map the success value
  AudioResult<R> map<R>(R Function(T value) mapper) {
    if (isSuccess && value != null) {
      return AudioResult.success(mapper(value as T));
    }
    return AudioResult.failure(error);
  }
  
  /// Get value or throw
  T get valueOrThrow {
    if (isSuccess && value != null) return value!;
    throw error ?? AudioError(
      type: AudioErrorType.unknown,
      message: 'No value available',
      operation: 'valueOrThrow',
      timestamp: DateTime.now(),
    );
  }
  
  /// Get value or default
  T valueOr(T defaultValue) {
    if (isSuccess && value != null) return value!;
    return defaultValue;
  }
}

/// Represents a pending audio operation
@immutable
class AudioOperation {
  /// Unique ID for this operation
  final String id;
  
  /// Type of operation
  final AudioOperationType type;
  
  /// When the operation was created
  final DateTime createdAt;
  
  /// Operation parameters
  final Map<String, dynamic> params;

  const AudioOperation({
    required this.id,
    required this.type,
    required this.createdAt,
    this.params = const {},
  });
  
  /// Check if operation has timed out
  bool hasTimedOut(Duration timeout) {
    return DateTime.now().difference(createdAt) > timeout;
  }
}

/// Types of audio operations
enum AudioOperationType {
  play,
  pause,
  resume,
  stop,
  seek,
  setVolume,
  setSpeed,
  loadTrack,
  loadPlaylist,
  skipNext,
  skipPrevious,
  skipToIndex,
}
