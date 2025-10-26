import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';
import '../download_service.dart';
import 'audio_service.dart';
import 'audio_state.dart';

/// Simple audio manager that provides a clean interface for UI components
/// This eliminates the need for complex state management across the app
class AudioManager {
  static AudioManager? _instance;
  static AudioManager get instance {
    _instance ??= AudioManager._internal();
    return _instance!;
  }

  AudioManager._internal();

  DoudouAudioService? _audioService;
  bool _initialized = false;

  // Combined streams for easy UI consumption
  final BehaviorSubject<AudioPlayerState> _playerStateController = 
      BehaviorSubject<AudioPlayerState>.seeded(AudioPlayerState.initial());

  Stream<AudioPlayerState> get playerState => _playerStateController.stream;
  AudioPlayerState get currentPlayerState => _playerStateController.value;

  // Individual streams (for components that only need specific data)
  Stream<AudioState> get audioState => _audioService?.audioState ?? const Stream.empty();
  Stream<List<Track>> get playlist => _audioService?.playlist ?? const Stream.empty();
  Stream<int?> get currentIndex => _audioService?.currentIndex ?? const Stream.empty();
  Stream<bool> get shuffle => _audioService?.shuffle ?? const Stream.empty();
  Stream<RepeatMode> get repeatMode => _audioService?.repeatMode ?? const Stream.empty();

  // Convenience getters
  Track? get currentTrack => _audioService?.currentTrack;
  List<Track> get currentPlaylist => _audioService?.currentPlaylist ?? [];
  bool get isPlaying => currentPlayerState.audioState.isPlaying;
  bool get isLoading => currentPlayerState.audioState.isLoading;
  Duration get position => currentPlayerState.audioState.position;
  Duration? get duration => currentPlayerState.audioState.duration;

  /// Initialize the audio manager
  Future<void> initialize(JellyfinService jellyfinService, DownloadService downloadService) async {
    if (_initialized) return;

    try {
      _audioService = DoudouAudioService.instance;
      await _audioService!.initialize(jellyfinService, downloadService);

      // Combine all streams into a single player state stream
      _setupCombinedStateStream();

      _initialized = true;

      if (kDebugMode) {
        print('AudioManager: Successfully initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioManager: Failed to initialize: $e');
      }
      rethrow;
    }
  }

  /// Set up the combined state stream for easy UI consumption
  void _setupCombinedStateStream() {
    if (_audioService == null) return;

    // Combine multiple streams into a single state
    Rx.combineLatest5(
      _audioService!.audioState,
      _audioService!.playlist,
      _audioService!.currentIndex,
      _audioService!.shuffle,
      _audioService!.repeatMode,
      (AudioState audioState, List<Track> playlist, int? currentIndex, 
       bool shuffle, RepeatMode repeatMode) {
        return AudioPlayerState(
          audioState: audioState,
          playlist: playlist,
          currentIndex: currentIndex,
          shuffle: shuffle,
          repeatMode: repeatMode,
        );
      },
    ).listen((playerState) {
      _playerStateController.add(playerState);
    });
  }

  // Playback control methods
  Future<void> play() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.play();
  }

  Future<void> pause() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.pause();
  }

  Future<void> stop() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.stop();
  }

  Future<void> seek(Duration position) async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.seek(position);
  }

  Future<void> skipToNext() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.skipToNext();
  }

  Future<void> skipToPrevious() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.skipToPrevious();
  }

  Future<void> skipToTrack(int index) async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.skipToTrack(index);
  }

  // Playlist management
  Future<void> playPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.playPlaylist(tracks, startIndex);
  }

  Future<void> playTrack(Track track) async {
    await playPlaylist([track], 0);
  }

  Future<void> addToQueue(Track track) async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.addToQueue(track);
  }

  Future<void> removeFromQueue(int index) async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.removeFromQueue(index);
  }

  Future<void> clearQueue() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.clearQueue();
  }

  // Playback modes
  Future<void> toggleShuffle() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    final currentShuffle = _audioService!.isShuffleEnabled;
    await _audioService!.setShuffle(!currentShuffle);
  }

  Future<void> setShuffle(bool enabled) async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.setShuffle(enabled);
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    await _audioService!.setRepeatMode(mode);
  }

  Future<void> cycleRepeatMode() async {
    if (!_initialized || _audioService == null) {
      throw StateError('AudioManager not initialized');
    }
    
    final currentMode = _audioService!.currentRepeatMode;
    RepeatMode nextMode;
    switch (currentMode) {
      case RepeatMode.none:
        nextMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        nextMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        nextMode = RepeatMode.none;
        break;
    }
    
    await setRepeatMode(nextMode);
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Dispose of the audio manager
  void dispose() {
    _playerStateController.close();
    _audioService?.dispose();
    _initialized = false;
  }
}

/// Combined player state for easy UI consumption
class AudioPlayerState {
  final AudioState audioState;
  final List<Track> playlist;
  final int? currentIndex;
  final bool shuffle;
  final RepeatMode repeatMode;

  const AudioPlayerState({
    required this.audioState,
    required this.playlist,
    required this.currentIndex,
    required this.shuffle,
    required this.repeatMode,
  });

  /// Create initial/empty player state
  factory AudioPlayerState.initial() {
    return AudioPlayerState(
      audioState: AudioState.initial(),
      playlist: const [],
      currentIndex: null,
      shuffle: false,
      repeatMode: RepeatMode.none,
    );
  }

  /// Get current track
  Track? get currentTrack => 
      currentIndex != null && currentIndex! < playlist.length 
          ? playlist[currentIndex!]
          : null;

  /// Check if there's a next track
  bool get hasNext => currentIndex != null && currentIndex! < playlist.length - 1;

  /// Check if there's a previous track
  bool get hasPrevious => currentIndex != null && currentIndex! > 0;

  /// Check if playlist has tracks
  bool get hasPlaylist => playlist.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioPlayerState &&
        other.audioState == audioState &&
        other.playlist == playlist &&
        other.currentIndex == currentIndex &&
        other.shuffle == shuffle &&
        other.repeatMode == repeatMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      audioState,
      playlist,
      currentIndex,
      shuffle,
      repeatMode,
    );
  }

  @override
  String toString() {
    return 'AudioPlayerState('
        'audioState: $audioState, '
        'playlist: ${playlist.length} tracks, '
        'currentIndex: $currentIndex, '
        'shuffle: $shuffle, '
        'repeatMode: $repeatMode'
        ')';
  }
}