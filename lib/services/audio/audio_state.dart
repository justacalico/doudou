import 'package:audio_service/audio_service.dart';

/// Represents the current state of audio playback
class AudioState {
  final bool isPlaying;
  final bool isLoading;
  final bool isBuffering;
  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;
  final double speed;
  final AudioProcessingState processingState;
  final String? title;
  final String? artist;
  final String? album;
  final Uri? artUri;

  const AudioState({
    required this.isPlaying,
    required this.isLoading,
    required this.isBuffering,
    required this.position,
    required this.bufferedPosition,
    required this.speed,
    required this.processingState,
    this.duration,
    this.title,
    this.artist,
    this.album,
    this.artUri,
  });

  /// Create initial/empty audio state
  factory AudioState.initial() {
    return const AudioState(
      isPlaying: false,
      isLoading: false,
      isBuffering: false,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
      processingState: AudioProcessingState.idle,
    );
  }

  /// Check if audio is currently active (playing or loading/buffering)
  bool get isActive => isPlaying || isLoading || isBuffering;

  /// Check if playback is ready to play
  bool get isReady => processingState == AudioProcessingState.ready;

  /// Check if there's an error
  bool get hasError => processingState == AudioProcessingState.error;

  /// Create a copy of this state with updated values
  AudioState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? speed,
    AudioProcessingState? processingState,
    String? title,
    String? artist,
    String? album,
    Uri? artUri,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      speed: speed ?? this.speed,
      processingState: processingState ?? this.processingState,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artUri: artUri ?? this.artUri,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioState &&
        other.isPlaying == isPlaying &&
        other.isLoading == isLoading &&
        other.isBuffering == isBuffering &&
        other.position == position &&
        other.duration == duration &&
        other.bufferedPosition == bufferedPosition &&
        other.speed == speed &&
        other.processingState == processingState &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        other.artUri == artUri;
  }

  @override
  int get hashCode {
    return Object.hash(
      isPlaying,
      isLoading,
      isBuffering,
      position,
      duration,
      bufferedPosition,
      speed,
      processingState,
      title,
      artist,
      album,
      artUri,
    );
  }

  @override
  String toString() {
    return 'AudioState('
        'isPlaying: $isPlaying, '
        'processingState: $processingState, '
        'position: ${position.inSeconds}s, '
        'duration: ${duration?.inSeconds}s, '
        'title: $title'
        ')';
  }
}