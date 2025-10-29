import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/jellyfin_models.dart';
import '../media_service_manager.dart';
import 'base_audio_handler.dart';
import 'audio_state_controller.dart';
import 'queue_manager.dart';

/// WebAudioHandler - Audio handler for web platform
/// Uses just_audio with web-specific optimizations
class WebAudioHandler {
  final MediaServiceManager _mediaServiceManager;
  final AudioStateController _stateController = AudioStateController();
  final AudioQueueManager _queueManager = AudioQueueManager();
  final AudioPlayer _player = AudioPlayer();

  // Stream subscriptions for proper cleanup
  late final List<StreamSubscription> _subscriptions = [];

  // Radio mode state
  bool _radioModeEnabled = false;
  Timer? _radioModeTimer;

  // Constructor
  WebAudioHandler(this._mediaServiceManager) {
    _initializeAudio();
  }

  /// Initialize audio system for web
  Future<void> _initializeAudio() async {
    try {
      if (kDebugMode) {
        print('WebAudioHandler: Initializing web audio system...');
      }

      // Set up player event listeners
      _setupPlayerListeners();

      if (kDebugMode) {
        print('WebAudioHandler: Web audio system initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Failed to initialize web audio system: $e');
      }
      _stateController.updateError('Failed to initialize web audio: $e');
    }
  }

  /// Set up player event listeners
  void _setupPlayerListeners() {
    // Position stream
    _subscriptions.add(
      _player.positionStream.listen(_stateController.updatePosition),
    );

    // Duration stream
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        _stateController.updateDuration(duration ?? Duration.zero);
      }),
    );

    // Player state stream
    _subscriptions.add(
      _player.playerStateStream.listen(_handlePlayerStateChange),
    );

    // Processing state for loading detection
    _subscriptions.add(
      _player.processingStateStream.listen(_handleProcessingStateChange),
    );

    // Player completion
    _subscriptions.add(
      _player.playbackEventStream
          .where((event) => event.processingState == ProcessingState.completed)
          .listen((_) => _handleTrackCompletion()),
    );

    // Volume and speed synchronization
    _subscriptions.add(
      _player.volumeStream.listen(_stateController.updateVolume),
    );

    _subscriptions.add(
      _player.speedStream.listen(_stateController.updateSpeed),
    );

    // Update media session when track changes (if using web media session API)
    _subscriptions.add(
      _stateController.currentTrackStream.listen((track) {
        if (track != null) {
          _updateMediaSessionMetadata(track);
        }
      }),
    );
  }

  /// Handle player state changes
  void _handlePlayerStateChange(PlayerState playerState) {
    switch (playerState.processingState) {
      case ProcessingState.idle:
        _stateController.updateState(AudioPlayerState.idle);
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _stateController.updateState(AudioPlayerState.loading);
        break;
      case ProcessingState.ready:
        if (playerState.playing) {
          _stateController.updateState(AudioPlayerState.playing);
        } else {
          _stateController.updateState(AudioPlayerState.paused);
        }
        break;
      case ProcessingState.completed:
        _stateController.updateState(AudioPlayerState.completed);
        break;
    }

    // Update media session playback state
    _updateMediaSessionPlaybackState();
  }

  /// Update media session playback state (web-specific)
  void _updateMediaSessionPlaybackState() {
    // This would use the web Media Session API if needed
    // Implementation depends on your web integration requirements
  }

  /// Update media session metadata (web-specific)
  void _updateMediaSessionMetadata(Track track) {
    // This would use the web Media Session API if needed
    // Implementation depends on your web integration requirements
  }

  /// Handle processing state changes
  void _handleProcessingStateChange(ProcessingState state) {
    if (state == ProcessingState.ready) {
      _stateController.clearError();
    }
  }

  /// Handle track completion
  Future<void> _handleTrackCompletion() async {
    if (kDebugMode) {
      print('WebAudioHandler: Track completed');
    }

    // In radio mode, fetch and play similar tracks
    if (_radioModeEnabled) {
      await _handleRadioModeNext();
      return;
    }

    // Normal mode - advance to next track
    final nextIndex = _queueManager.getNextTrackIndex();
    if (nextIndex != null) {
      await skipToQueueItem(nextIndex);
    } else {
      // End of queue
      _stateController.updateState(AudioPlayerState.completed);
      _stateController.updateUserIntent(false);
    }
  }

  /// Handle radio mode - fetch similar tracks
  Future<void> _handleRadioModeNext() async {
    try {
      final currentTrack = _stateController.currentTrack;
      if (currentTrack == null) return;

      // Fetch similar tracks from the media service
      final similarTracks = await _fetchSimilarTracks(currentTrack);

      if (similarTracks.isNotEmpty) {
        // Add similar tracks to queue and play next
        for (final track in similarTracks.take(5)) {
          _queueManager.addToQueue(track);
        }
        await skipToNext();
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Failed to fetch radio tracks: $e');
      }
      // Fallback to normal next track behavior
      await skipToNext();
    }
  }

  /// Fetch similar tracks for radio mode
  Future<List<Track>> _fetchSimilarTracks(Track track) async {
    try {
      // This would need to be implemented based on your media service API
      // Example placeholder - you'll need to adjust this to match your API
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error fetching similar tracks: $e');
      }
      return [];
    }
  }

  // BaseAudioHandler implementation - Stream getters

  Stream<AudioPlayerState> get stateStream => _stateController.stateStream;

  Stream<Duration> get positionStream => _stateController.positionStream;

  Stream<Duration?> get durationStream => _stateController.durationStream;

  Stream<double> get volumeStream => _player.volumeStream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // Web-specific streams for AudioService compatibility
  Stream<PlaybackState> get playbackState => _createPlaybackStateStream();
  
  Stream<MediaItem?> get mediaItem => _createMediaItemStream();

  // Property getters

  AudioPlayerState get currentState => _stateController.currentState;

  Duration get position => _stateController.position;

  Duration get duration => _stateController.duration;

  Track? get currentTrack => _stateController.currentTrack;

  List<Track> get queueTracks => _stateController.queue;

  List<Track> get upNext => _queueManager.getUpNext();

  double get volume => _stateController.volume;

  double get speed => _stateController.speed;

  bool get userIntendedPlaying => _stateController.userIntendedPlaying;

  PlayerState get playerState => _player.playerState;

  int? get currentIndex => _stateController.currentIndex;

  bool get hasNext => _queueManager.hasNext;

  bool get hasPrevious => _queueManager.hasPrevious;

  RepeatMode get repeatMode => _stateController.repeatMode;

  bool get shuffleEnabled => _stateController.shuffleEnabled;

  bool get gaplessPlaybackEnabled => _stateController.gaplessPlaybackEnabled;

  bool get radioModeEnabled => _radioModeEnabled;

  // Playback control methods

  Future<void> play() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('WebAudioHandler: Play command received');
      }

      _stateController.updateUserIntent(true);

      try {
        await _player.play();
        if (kDebugMode) {
          print('WebAudioHandler: Play command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Play failed: $e');
        }
        _stateController.updateError('Play failed: $e');
        _stateController.updateUserIntent(false);
        rethrow;
      }
    });
  }

  Future<void> pause() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('WebAudioHandler: Pause command received');
      }

      _stateController.updateUserIntent(false);

      try {
        await _player.pause();
        if (kDebugMode) {
          print('WebAudioHandler: Pause command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Pause failed: $e');
        }
        _stateController.updateError('Pause failed: $e');
        rethrow;
      }
    });
  }

  Future<void> stop() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('WebAudioHandler: Stop command received');
      }

      _stateController.updateUserIntent(false);

      try {
        await _player.stop();
        _stateController.updateState(AudioPlayerState.idle);
        if (kDebugMode) {
          print('WebAudioHandler: Stop command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Stop failed: $e');
        }
        _stateController.updateError('Stop failed: $e');
        rethrow;
      }
    });
  }

  Future<void> seek(Duration position) async {
    return _stateController.queueCommand(() async {
      try {
        await _player.seek(position);
        _stateController.updatePosition(position);
        _updateMediaSessionPlaybackState();
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Seek failed: $e');
        }
        _stateController.updateError('Seek failed: $e');
        rethrow;
      }
    });
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      _stateController.updateSpeed(speed);
      _updateMediaSessionPlaybackState();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Set speed failed: $e');
      }
      _stateController.updateError('Set speed failed: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
      _stateController.updateVolume(volume);
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Set volume failed: $e');
      }
      _stateController.updateError('Set volume failed: $e');
    }
  }

  Future<void> playTrack(Track track) async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('WebAudioHandler: Playing single track: ${track.name}');
      }

      try {
        // Set up single track queue
        _queueManager.setQueue([track], startIndex: 0);
        _stateController.updateCurrentTrack(track);

        // Get stream URL
        final streamUrl = _getStreamUrl(track);

        // Load and play the track
        await _loadAndPlayTrack(streamUrl);

        if (kDebugMode) {
          print('WebAudioHandler: Track loaded and playing');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Failed to play track: $e');
        }
        _stateController.updateError('Failed to play track: $e');
        rethrow;
      }
    });
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print(
          'WebAudioHandler: Playing playlist with ${tracks.length} tracks, starting at $startIndex',
        );
      }

      try {
        if (tracks.isEmpty) {
          throw Exception('Cannot play empty playlist');
        }

        final validStartIndex = startIndex.clamp(0, tracks.length - 1);

        // Set up queue
        _queueManager.setQueue(tracks, startIndex: validStartIndex);

        // Play the starting track
        await _playTrackAtIndex(validStartIndex);

        if (kDebugMode) {
          print('WebAudioHandler: Playlist loaded and playing');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Failed to play playlist: $e');
        }
        _stateController.updateError('Failed to play playlist: $e');
        rethrow;
      }
    });
  }

  Future<void> skipToNext() async {
    final nextIndex = _queueManager.getNextTrackIndex();
    if (nextIndex != null) {
      await skipToQueueItem(nextIndex);
    }
  }

  Future<void> skipToPrevious() async {
    final previousIndex = _queueManager.getPreviousTrackIndex();
    if (previousIndex != null) {
      await skipToQueueItem(previousIndex);
    }
  }

  Future<void> skipToQueueItem(int index) async {
    return _stateController.queueCommand(() async {
      try {
        final queue = _stateController.queue;
        if (index < 0 || index >= queue.length) {
          throw Exception('Invalid queue index: $index');
        }

        await _playTrackAtIndex(index);
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Skip to index failed: $e');
        }
        _stateController.updateError('Skip failed: $e');
        rethrow;
      }
    });
  }

  /// Play track at specific queue index
  Future<void> _playTrackAtIndex(int index) async {
    final queue = _stateController.queue;
    final track = queue[index];

    _stateController.updateCurrentIndex(index);
    _stateController.updateCurrentTrack(track);

    final streamUrl = _getStreamUrl(track);
    await _loadAndPlayTrack(streamUrl);
  }

  /// Load and play track from URL
  Future<void> _loadAndPlayTrack(String url) async {
    try {
      _stateController.updateState(AudioPlayerState.loading);
      _stateController.updateUserIntent(true);

      // For web, we need to handle CORS issues by creating a blob URL
      final audioSource = await _createWebAudioSource(url);
      await _player.setAudioSource(audioSource);
      await _player.play();
    } catch (e) {
      _stateController.updateState(AudioPlayerState.error);
      _stateController.updateUserIntent(false);
      rethrow;
    }
  }

  /// Create web-compatible audio source
  Future<AudioSource> _createWebAudioSource(String url) async {
    if (kIsWeb) {
      try {
        if (kDebugMode) {
          print('WebAudioHandler: Creating web audio source for: $url');
        }
        
        // For web, try the direct stream URL first
        return AudioSource.uri(Uri.parse(url));
      } catch (e) {
        if (kDebugMode) {
          print('WebAudioHandler: Failed to create audio source: $e');
        }
        rethrow;
      }
    } else {
      return AudioSource.uri(Uri.parse(url));
    }
  }

  /// Get stream URL for track
  String _getStreamUrl(Track track) {
    if (kIsWeb) {
      // For web, try to get a direct download URL which might work better with CORS
      final directUrl = _mediaServiceManager.getDirectStreamUrl(track.id);
      if (directUrl.isNotEmpty) {
        if (kDebugMode) {
          print('WebAudioHandler: Using direct stream URL for web: $directUrl');
        }
        return directUrl;
      }
    }
    
    return _mediaServiceManager.getStreamUrl(track.id);
  }

  // Queue management

  void addToQueue(Track track) {
    _queueManager.addToQueue(track);
  }

  void addNext(Track track) {
    _queueManager.addNext(track);
  }

  void removeFromQueue(int index) {
    _queueManager.removeFromQueue(index);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _queueManager.reorderQueue(oldIndex, newIndex);
  }

  void clearQueue() {
    _queueManager.clearQueue();
  }

  // Playback modes

  void setRepeatMode(RepeatMode mode) {
    _stateController.updateRepeatMode(mode);
  }

  void toggleShuffle() {
    _queueManager.toggleShuffle();
  }

  void setGaplessPlayback(bool enabled) {
    _stateController.updateGaplessPlayback(enabled);
  }

  void toggleRadioMode() {
    _radioModeEnabled = !_radioModeEnabled;
    _stateController.updateRadioMode(_radioModeEnabled);
  }

  void enableRadioMode() {
    _radioModeEnabled = true;
    _stateController.updateRadioMode(true);
  }

  void disableRadioMode() {
    _radioModeEnabled = false;
    _stateController.updateRadioMode(false);
  }

  // Lifecycle management

  Future<void> dispose() async {
    if (kDebugMode) {
      print('WebAudioHandler: Disposing...');
    }

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Cancel radio mode timer
    _radioModeTimer?.cancel();

    // Stop and dispose player
    try {
      await _player.stop();
      await _player.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error disposing player: $e');
      }
    }

    // Reset state
    _stateController.reset();

    if (kDebugMode) {
      print('WebAudioHandler: Disposed');
    }
  }
}

// Web-specific types for compatibility
