import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';
import 'audio_service_factory.dart';
import 'media_service_manager.dart';
import 'audio/unified_audio_handler.dart';
import '../models/jellyfin_models.dart';

/// Simple wrapper to integrate the unified audio system with existing AppState
/// This provides a backwards-compatible interface while using the new unified architecture
class AudioServiceIntegration {
  static AudioServiceIntegration? _instance;
  static AudioServiceIntegration get instance =>
      _instance ??= AudioServiceIntegration._();
  AudioServiceIntegration._();

  UnifiedAudioHandler? _audioHandler;
  bool _initialized = false;

  /// Initialize the audio service
  Future<void> initialize(MediaServiceManager mediaServiceManager) async {
    if (_initialized) return;

    try {
      final factory = AudioServiceFactory.instance;
      await factory.initialize(mediaServiceManager);
      _audioHandler = factory.audioHandler;
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Failed to initialize: $e');
      }
      rethrow;
    }
  }

  /// Get the current audio handler
  UnifiedAudioHandler? get audioHandler {
    if (!_initialized) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Not initialized, returning null');
      }
      return null;
    }
    return _audioHandler;
  }

  /// Check if initialized
  bool get isInitialized => _initialized;

  /// Get platform type
  String get platformType {
    if (!_initialized) return 'unknown';
    return AudioServiceFactory.instance.platformType;
  }

  // === Playback Control ===

  /// Play a track
  Future<void> playTrack(Track track) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.playTrack(track);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error playing track: $e');
      }
    }
  }

  /// Play a playlist
  Future<void> playPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    if (!_initialized || _audioHandler == null || tracks.isEmpty) return;

    try {
      await _audioHandler!.playPlaylist(tracks, startIndex);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error playing playlist: $e');
      }
    }
  }

  /// Play current track
  Future<void> play() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.play();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error playing: $e');
      }
    }
  }

  /// Pause current track
  Future<void> pause() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.pause();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error pausing: $e');
      }
    }
  }

  /// Play/pause toggle
  Future<void> playPause() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler!.currentState == AudioPlayerState.playing) {
        await _audioHandler!.pause();
      } else {
        await _audioHandler!.play();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error toggling play/pause: $e');
      }
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.skipToNext();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error skipping to next: $e');
      }
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.skipToPrevious();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error skipping to previous: $e');
      }
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.seek(position);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error seeking: $e');
      }
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.setVolume(volume);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting volume: $e');
      }
    }
  }

  /// Skip to specific queue item
  Future<void> skipToQueueItem(int index) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.skipToQueueItem(index);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error skipping to queue item: $e');
      }
    }
  }

  // === Stream Getters ===

  Stream<PlayerState>? get playerStateStream {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.playerStateStream;
  }

  Stream<audio_service.PlaybackState>? get playbackState {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.playbackState.stream;
  }

  Stream<Duration>? get positionStream {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.positionStream;
  }

  Stream<Duration?>? get durationStream {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.durationStream;
  }

  Stream<double>? get volumeStream {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.volumeStream;
  }

  Stream<audio_service.MediaItem?>? get mediaItem {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.mediaItem.stream;
  }

  Stream<Track?>? get currentTrackStream {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.currentTrackStream;
  }

  // === Property Getters ===

  /// Get user intended playing state
  bool get userIntendedPlaying {
    if (!_initialized || _audioHandler == null) return false;
    return _audioHandler!.currentState == AudioPlayerState.playing;
  }

  /// Get current track
  Track? get currentTrack {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.currentTrack;
  }

  /// Check if there is a previous track available
  bool get hasPrevious {
    if (!_initialized || _audioHandler == null) return false;
    return _audioHandler!.hasPrevious;
  }

  /// Check if there is a next track available
  bool get hasNext {
    if (!_initialized || _audioHandler == null) return false;
    return _audioHandler!.hasNext;
  }

  /// Get current track duration
  Duration get duration {
    if (!_initialized || _audioHandler == null) return Duration.zero;
    return _audioHandler!.duration;
  }

  /// Check if shuffle is enabled
  bool get isShuffled {
    if (!_initialized || _audioHandler == null) return false;
    return _audioHandler!.shuffleEnabled;
  }

  /// Get current repeat mode
  RepeatMode get repeatMode {
    if (!_initialized || _audioHandler == null) return RepeatMode.none;
    return _audioHandler!.repeatMode;
  }

  /// Get current queue index
  int? get currentIndex {
    if (!_initialized || _audioHandler == null) return null;
    return _audioHandler!.currentIndex;
  }

  /// Get current queue tracks
  List<Track> get queueTracks {
    if (!_initialized || _audioHandler == null) return [];
    return _audioHandler!.queueTracks;
  }

  /// Get up next tracks
  List<Track> get upNext {
    if (!_initialized || _audioHandler == null) return [];
    return _audioHandler!.upNext;
  }

  /// Check if radio mode is enabled
  bool get radioModeEnabled {
    if (!_initialized || _audioHandler == null) return false;
    return _audioHandler!.radioModeEnabled;
  }

  // === Playback Mode Control ===

  /// Set repeat mode
  Future<void> setRepeatMode(RepeatMode mode) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.setRepeatModeValue(mode);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting repeat mode: $e');
      }
    }
  }

  /// Set shuffle mode
  Future<void> setShuffleMode(bool enabled) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (enabled && !_audioHandler!.shuffleEnabled) {
        _audioHandler!.toggleShuffle();
      } else if (!enabled && _audioHandler!.shuffleEnabled) {
        _audioHandler!.toggleShuffle();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting shuffle mode: $e');
      }
    }
  }

  /// Shuffle current queue
  Future<void> shuffle() async {
    await setShuffleMode(true);
  }

  /// Disable shuffle mode
  Future<void> unshuffle() async {
    await setShuffleMode(false);
  }

  /// Set gapless playback
  Future<void> setGaplessPlayback(bool enabled) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.setGaplessPlayback(enabled);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting gapless playback: $e');
      }
    }
  }

  // === Queue Management ===

  /// Add track to queue
  Future<void> addToQueue(Track track) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.addToQueue(track);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error adding to queue: $e');
      }
    }
  }

  /// Add track to play next
  Future<void> addNext(Track track) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.addNext(track);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error adding next: $e');
      }
    }
  }

  /// Remove track from queue
  Future<void> removeFromQueue(int index) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.removeFromQueue(index);
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error removing from queue: $e');
      }
    }
  }

  /// Clear the entire queue
  Future<void> clearQueue() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.clearQueue();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error clearing queue: $e');
      }
    }
  }

  // === Radio Mode ===

  /// Toggle radio mode
  Future<void> toggleRadioMode() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.toggleRadioMode();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error toggling radio mode: $e');
      }
    }
  }

  /// Enable radio mode
  Future<void> enableRadioMode() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.enableRadioMode();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error enabling radio mode: $e');
      }
    }
  }

  /// Disable radio mode
  Future<void> disableRadioMode() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.disableRadioMode();
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error disabling radio mode: $e');
      }
    }
  }

  // === Utility Methods ===

  /// Update media library (optional method for compatibility)
  Future<void> updateMediaLibrary(
    List<Track> tracks,
    List<Album> albums,
    List<Artist> artists,
    List<Playlist> playlists,
  ) async {
    if (!_initialized || _audioHandler == null) return;

    // The unified handler doesn't need explicit media library updates
    if (kDebugMode) {
      print(
        'AudioServiceIntegration: Media library updated with ${tracks.length} tracks',
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_audioHandler != null) {
      await AudioServiceFactory.instance.dispose();
    }
    _audioHandler = null;
    _initialized = false;
    _instance = null;
  }
}
