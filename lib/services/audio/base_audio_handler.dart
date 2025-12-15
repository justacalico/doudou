import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/jellyfin_models.dart';

/// Audio playback states
enum AudioPlayerState { 
  idle, 
  loading, 
  playing, 
  paused, 
  completed, 
  error 
}

/// Repeat modes for playback
enum RepeatMode { 
  none, 
  one, 
  all 
}

/// Shuffle mode
enum ShuffleMode { 
  none, 
  all 
}

/// Abstract base interface for all audio handlers
/// Ensures consistent API across mobile, desktop, and web platforms
abstract class BaseAudioHandler {
  // Core playback streams
  Stream<AudioPlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<double> get volumeStream;
  Stream<PlaybackState> get playbackState;
  Stream<MediaItem?> get mediaItem;
  Stream<List<MediaItem>> get queueStream;
  Stream<PlayerState> get playerStateStream;
  
  // Current state getters
  AudioPlayerState get currentState;
  Duration get position;
  Duration get duration;
  Track? get currentTrack;
  List<Track> get queueTracks;
  List<Track> get upNext;
  double get volume;
  double get speed;
  bool get userIntendedPlaying;
  PlayerState get playerState;
  
  // Queue management
  int? get currentIndex;
  bool get hasNext;
  bool get hasPrevious;
  
  // Playback modes
  RepeatMode get repeatMode;
  bool get shuffleEnabled;
  bool get gaplessPlaybackEnabled;
  bool get radioModeEnabled;
  
  // Core playback control
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  
  // Track and playlist control
  Future<void> playTrack(Track track);
  Future<void> playPlaylist(List<Track> tracks, int startIndex);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToQueueItem(int index);
  
  // Queue management
  void addToQueue(Track track);
  void addNext(Track track);
  void removeFromQueue(int index);
  void reorderQueue(int oldIndex, int newIndex);
  void clearQueue();
  
  // Playback modes
  void setRepeatMode(RepeatMode mode);
  void toggleShuffle();
  void setGaplessPlayback(bool enabled);
  void toggleRadioMode();
  void enableRadioMode();
  void disableRadioMode();
  
  // Lifecycle management
  Future<void> dispose();
}

/// Audio state event for unified state management
class AudioStateEvent {
  final AudioPlayerState state;
  final Track? track;
  final Duration position;
  final Duration duration;
  final String? error;
  final DateTime timestamp;
  
  AudioStateEvent({
    required this.state,
    this.track,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Queue change event for queue updates
class QueueChangeEvent {
  final List<Track> queue;
  final int? currentIndex;
  final DateTime timestamp;
  
  QueueChangeEvent({
    required this.queue,
    this.currentIndex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}