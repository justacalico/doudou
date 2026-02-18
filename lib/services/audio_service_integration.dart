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
      rethrow;
    }
  }

  /// Get the current audio handler
  UnifiedAudioHandler? get audioHandler {
    if (!_initialized) {
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
      // Error playing track
    }
  }

  /// Play a playlist
  Future<void> playPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    if (!_initialized || _audioHandler == null || tracks.isEmpty) return;

    try {
      await _audioHandler!.playPlaylist(tracks, startIndex);
    } catch (e) {
      // Error playing playlist
    }
  }

  /// Play current track
  Future<void> play() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.play();
    } catch (e) {
      // Error playing
    }
  }

  /// Pause current track
  Future<void> pause() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.pause();
    } catch (e) {
      // Error pausing
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
      // Error toggling play/pause
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.skipToNext();
    } catch (e) {
      // Error skipping to next
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.skipToPrevious();
    } catch (e) {
      // Error skipping to previous
    }
  }

  /// True if the next back press will restart the current track (seek to 0). Use to avoid playing skip animation when only restarting.
  Future<bool> willBackRestartCurrentTrack() async {
    if (!_initialized || _audioHandler == null) return false;
    try {
      return await _audioHandler!.willBackRestartCurrentTrack();
    } catch (e) {
      return false;
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.seek(position);
    } catch (e) {
      // Error seeking
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.setVolume(volume);
    } catch (e) {
      // Error setting volume
    }
  }

  /// Skip to specific queue item
  Future<void> skipToQueueItem(int index) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.skipToQueueItem(index);
    } catch (e) {
      // Error skipping to queue item
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

  /// Alias for isShuffled for compatibility
  bool get shuffleEnabled {
    if (!_initialized || _audioHandler == null) return false;
    return _audioHandler!.shuffleEnabled;
  }

  /// Get current volume
  double get volume {
    if (!_initialized || _audioHandler == null) return 1.0;
    return _audioHandler!.volume;
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
      // Error setting repeat mode
    }
  }

  /// Set shuffle mode
  Future<void> setShuffleMode(bool enabled) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      await _audioHandler!.setShuffleMode(
        enabled
            ? audio_service.AudioServiceShuffleMode.all
            : audio_service.AudioServiceShuffleMode.none,
      );
    } catch (e) {
      // Error setting shuffle mode
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
      // Error setting gapless playback
    }
  }

  // === Queue Management ===

  /// Add track to queue
  Future<void> addToQueue(Track track) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.addToQueue(track);
    } catch (e) {
      // Error adding to queue
    }
  }

  /// Add track to play next
  Future<void> addNext(Track track) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.addNext(track);
    } catch (e) {
      // Error adding next
    }
  }

  /// Remove track from queue
  Future<void> removeFromQueue(int index) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.removeFromQueue(index);
    } catch (e) {
      // Error removing from queue
    }
  }

  /// Clear the entire queue
  Future<void> clearQueue() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.clearQueue();
    } catch (e) {
      // Error clearing queue
    }
  }

  /// Reset playback state for server switch without disposing. Keeps
  /// AudioService alive so audio works after switching server.
  Future<void> resetForServerSwitch() async {
    if (!_initialized || _audioHandler == null) return;
    try {
      await _audioHandler!.resetForServerSwitch();
    } catch (e) {
      // Ignore
    }
  }

  // === Radio Mode ===

  /// Toggle radio mode
  Future<void> toggleRadioMode() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.toggleRadioMode();
    } catch (e) {
      // Error toggling radio mode
    }
  }

  /// Enable radio mode
  Future<void> enableRadioMode() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.enableRadioMode();
    } catch (e) {
      // Error enabling radio mode
    }
  }

  /// Disable radio mode
  Future<void> disableRadioMode() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.disableRadioMode();
    } catch (e) {
      // Error disabling radio mode
    }
  }

  /// Set autoplay mode (automatically queue similar tracks when queue ends)
  void setAutoplay(bool enabled) {
    if (!_initialized || _audioHandler == null) return;

    try {
      _audioHandler!.setAutoplay(enabled);
    } catch (e) {
      // Error setting autoplay
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
