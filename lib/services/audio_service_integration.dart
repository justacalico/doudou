/// Audio Service Integration - Bridge for existing AppState
/// 
/// This provides a backwards-compatible interface to the new global audio system.
library;

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';
import 'audio_service_factory.dart';
import 'media_service_manager.dart';
import 'audio/global/global_audio.dart';
import '../models/jellyfin_models.dart';

/// Simple wrapper to integrate new audio system with existing AppState
/// This provides a backwards-compatible interface while using the new architecture
class AudioServiceIntegration {
  static AudioServiceIntegration? _instance;
  static AudioServiceIntegration get instance => _instance ??= AudioServiceIntegration._();
  AudioServiceIntegration._();

  AudioManagerIntegration? _audioHandler;
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
  AudioManagerIntegration? get audioHandler {
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

  // ============================================================
  // Helper methods for common operations
  // ============================================================

  /// Play a track
  Future<void> playTrack(Track track) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.playTrack(track);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error playing track: $e');
    }
  }

  /// Play a playlist
  Future<void> playPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    if (!_initialized || _audioHandler == null || tracks.isEmpty) return;
    try {
      await _audioHandler!.playPlaylist(tracks, startIndex);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error playing playlist: $e');
    }
  }

  /// Play current track
  Future<void> play() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.play();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error playing: $e');
    }
  }

  /// Pause current track
  Future<void> pause() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.pause();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error pausing: $e');
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
      if (kDebugMode) print('AudioServiceIntegration: Error toggling play/pause: $e');
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.skipToNext();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error skipping to next: $e');
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.skipToPrevious();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error skipping to previous: $e');
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.setVolume(volume);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error setting volume: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.seek(position);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error seeking: $e');
    }
  }

  /// Skip to specific queue item
  Future<void> skipToQueueItem(int index) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.skipToQueueItem(index);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error skipping to queue item: $e');
    }
  }

  /// Set repeat mode
  Future<void> setRepeatMode(RepeatMode mode) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.setRepeatMode(mode);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error setting repeat mode: $e');
    }
  }

  /// Set shuffle mode
  Future<void> setShuffleMode(bool enabled) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      if (enabled != _audioHandler!.shuffleEnabled) {
        _audioHandler!.toggleShuffle();
      }
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error setting shuffle mode: $e');
    }
  }

  /// Disable shuffle mode
  Future<void> unshuffle() async => setShuffleMode(false);

  /// Shuffle current queue
  Future<void> shuffle() async => setShuffleMode(true);

  // ============================================================
  // Stream getters for backwards compatibility with AppState
  // ============================================================

  Stream<PlayerState>? get playerStateStream => _audioHandler?.playerStateStream;
  Stream<audio_service.PlaybackState>? get playbackState => _audioHandler?.playbackState;
  Stream<Duration>? get positionStream => _audioHandler?.positionStream;
  Stream<Duration?>? get durationStream => _audioHandler?.durationStream;
  Stream<double>? get volumeStream => _audioHandler?.volumeStream;
  Stream<audio_service.MediaItem?>? get mediaItem => _audioHandler?.mediaItem;
  Stream<Track?>? get currentTrackStream => 
      _initialized ? AudioManager.instance.stateStream.map((s) => s.currentTrack) : null;

  // ============================================================
  // Property getters
  // ============================================================

  bool get userIntendedPlaying => _audioHandler?.userIntendedPlaying ?? false;
  Track? get currentTrack => _audioHandler?.currentTrack;
  bool get hasPrevious => _audioHandler?.hasPrevious ?? false;
  bool get hasNext => _audioHandler?.hasNext ?? false;
  Duration get duration => _audioHandler?.duration ?? Duration.zero;
  bool get isShuffled => _audioHandler?.shuffleEnabled ?? false;
  RepeatMode get repeatMode => _audioHandler?.repeatMode ?? RepeatMode.none;
  int? get currentIndex => _audioHandler?.currentIndex;
  List<Track> get queueTracks => _audioHandler?.queueTracks ?? [];
  List<Track> get upNext => _audioHandler?.upNext ?? [];
  bool get radioModeEnabled => _audioHandler?.radioModeEnabled ?? false;

  // ============================================================
  // Queue management
  // ============================================================

  Future<void> addToQueue(Track track) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.addToQueue(track);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error adding to queue: $e');
    }
  }

  Future<void> addNext(Track track) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.addNext(track);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error adding next: $e');
    }
  }

  Future<void> removeFromQueue(int index) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.removeFromQueue(index);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error removing from queue: $e');
    }
  }

  Future<void> clearQueue() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.clearQueue();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error clearing queue: $e');
    }
  }

  // ============================================================
  // Radio mode
  // ============================================================

  Future<void> toggleRadioMode() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.toggleRadioMode();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error toggling radio mode: $e');
    }
  }

  Future<void> enableRadioMode() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.enableRadioMode();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error enabling radio mode: $e');
    }
  }

  Future<void> disableRadioMode() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.disableRadioMode();
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error disabling radio mode: $e');
    }
  }

  // ============================================================
  // Optional methods
  // ============================================================

  Future<void> updateMediaLibrary(List<Track> tracks, List<Album> albums, List<Artist> artists, List<Playlist> playlists) async {
    if (kDebugMode) print('AudioServiceIntegration: Media library updated with ${tracks.length} tracks');
  }

  Future<void> setGaplessPlayback(bool enabled) async {
    if (!_initialized || _audioHandler == null) return;
    try {
      _audioHandler!.setGaplessPlayback(enabled);
    } catch (e) {
      if (kDebugMode) print('AudioServiceIntegration: Error setting gapless playback: $e');
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