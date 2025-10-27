import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/jellyfin_models.dart';

import '../media_service_manager.dart';
import 'base_audio_handler.dart' as base_handler;
import 'audio_state_controller.dart';
import 'queue_manager.dart';

/// DoudouAudioHandler - Mobile audio handler for Android and iOS
/// Integrates with AudioService for background playback and system integration
class DoudouAudioHandler extends BaseAudioHandler {
  final MediaServiceManager _mediaServiceManager;
  final AudioStateController _stateController = AudioStateController();
  final AudioQueueManager _queueManager = AudioQueueManager();
  final AudioPlayer _player = AudioPlayer();
  
  // Stream subscriptions for proper cleanup
  late final List<StreamSubscription> _subscriptions = [];
  
  // Playback session management
  AudioSession? _session;
  
  // Radio mode state
  bool _radioModeEnabled = false;
  Timer? _radioModeTimer;
  
  // Constructor
  DoudouAudioHandler({
    required MediaServiceManager mediaServiceManager,
  }) : _mediaServiceManager = mediaServiceManager {
    _initializeAudio();
  }

  /// Initialize audio system
  Future<void> _initializeAudio() async {
    try {
      if (kDebugMode) {
        print('DoudouAudioHandler: Initializing audio system...');
      }

      // Initialize audio session
      await _initializeAudioSession();
      
      // Set up player event listeners
      _setupPlayerListeners();
      
      // Set up state synchronization
      _setupStateSynchronization();
      
      if (kDebugMode) {
        print('DoudouAudioHandler: Audio system initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to initialize audio system: $e');
      }
      _stateController.updateError('Failed to initialize audio: $e');
    }
  }

  /// Initialize audio session for background playback
  Future<void> _initializeAudioSession() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());
      
      if (kDebugMode) {
        print('DoudouAudioHandler: Audio session configured');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to configure audio session: $e');
      }
    }
  }

  /// Set up player event listeners
  void _setupPlayerListeners() {
    // Position stream
    _subscriptions.add(
      _player.positionStream.listen(_stateController.updatePosition)
    );
    
    // Duration stream  
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        _stateController.updateDuration(duration ?? Duration.zero);
      })
    );
    
    // Player state stream
    _subscriptions.add(
      _player.playerStateStream.listen(_handlePlayerStateChange)
    );
    
    // Processing state for loading detection
    _subscriptions.add(
      _player.processingStateStream.listen(_handleProcessingStateChange)
    );
    
    // Player completion
    _subscriptions.add(
      _player.playbackEventStream
          .where((event) => event.processingState == ProcessingState.completed)
          .listen((_) => _handleTrackCompletion())
    );
  }

  /// Set up state synchronization with AudioService
  void _setupStateSynchronization() {
    // Sync playback state to AudioService
    _subscriptions.add(
      CombineLatestStream.combine3(
        _stateController.stateStream,
        _stateController.positionStream,
        _player.speedStream,
        (base_handler.AudioPlayerState state, Duration position, double speed) => 
            _createPlaybackState(state, position, speed),
      ).listen((playbackState) {
        this.playbackState.add(playbackState);
      })
    );
    
    // Sync current track to MediaItem
    _subscriptions.add(
      _stateController.currentTrackStream.listen((track) {
        if (track != null) {
          mediaItem.add(_trackToMediaItem(track));
        } else {
          mediaItem.add(null);
        }
      })
    );
    
    // Sync queue to AudioService
    _subscriptions.add(
      _stateController.queueStream.listen((tracks) {
        queue.add(tracks.map(_trackToMediaItem).toList());
      })
    );
  }

  /// Handle player state changes
  void _handlePlayerStateChange(PlayerState playerState) {
    switch (playerState.processingState) {
      case ProcessingState.idle:
        _stateController.updateState(base_handler.AudioPlayerState.idle);
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _stateController.updateState(base_handler.AudioPlayerState.loading);
        break;
      case ProcessingState.ready:
        if (playerState.playing) {
          _stateController.updateState(base_handler.AudioPlayerState.playing);
        } else {
          _stateController.updateState(base_handler.AudioPlayerState.paused);
        }
        break;
      case ProcessingState.completed:
        _stateController.updateState(base_handler.AudioPlayerState.completed);
        break;
    }
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
      print('DoudouAudioHandler: Track completed');
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
      _stateController.updateState(base_handler.AudioPlayerState.completed);
      _stateController.updateUserIntent(false);
    }
  }

  /// Handle radio mode - fetch similar tracks
  Future<void> _handleRadioModeNext() async {
    try {
      final currentTrack = _stateController.currentTrack;
      if (currentTrack == null) return;

      // Fetch similar tracks from the media service
      // This is a placeholder - implement based on your media service capabilities
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
        print('DoudouAudioHandler: Failed to fetch radio tracks: $e');
      }
      // Fallback to normal next track behavior
      await skipToNext();
    }
  }

  /// Fetch similar tracks for radio mode
  Future<List<Track>> _fetchSimilarTracks(Track track) async {
    // Implement similar track fetching based on your media service
    // This could use genre, artist, or other metadata
    try {
      // Example: Get tracks from the same artist
      final artistTracks = await _mediaServiceManager.getTracks(
        parentId: track.artistName,
        limit: 20,
      );
      
      // Filter out current track and already queued tracks
      final currentQueue = _stateController.queue;
      final queueIds = currentQueue.map((t) => t.id).toSet();
      
      return artistTracks
          .where((t) => t.id != track.id && !queueIds.contains(t.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Error fetching similar tracks: $e');
      }
      return [];
    }
  }

  /// Create PlaybackState for AudioService
  PlaybackState _createPlaybackState(
    base_handler.AudioPlayerState state,
    Duration position,
    double speed,
  ) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (state == base_handler.AudioPlayerState.playing) 
          MediaControl.pause 
        else 
          MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapToAudioServiceProcessingState(state),
      playing: state == base_handler.AudioPlayerState.playing,
      updatePosition: position,
      bufferedPosition: _player.bufferedPosition,
      speed: speed,
      queueIndex: _stateController.currentIndex,
    );
  }

  /// Map internal state to AudioService ProcessingState
  AudioProcessingState _mapToAudioServiceProcessingState(base_handler.AudioPlayerState state) {
    switch (state) {
      case base_handler.AudioPlayerState.idle:
        return AudioProcessingState.idle;
      case base_handler.AudioPlayerState.loading:
        return AudioProcessingState.loading;
      case base_handler.AudioPlayerState.playing:
      case base_handler.AudioPlayerState.paused:
        return AudioProcessingState.ready;
      case base_handler.AudioPlayerState.completed:
        return AudioProcessingState.completed;
      case base_handler.AudioPlayerState.error:
        return AudioProcessingState.error;
    }
  }

  /// Convert Track to MediaItem
  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      album: track.albumName,
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      duration: track.duration != null ? Duration(milliseconds: track.duration!) : null,
      artUri: Uri.tryParse(_mediaServiceManager.getImageUrl(
        track.albumId ?? track.id,
        width: 300,
        height: 300,
      )),
      extras: {
        'trackId': track.id,
        'albumId': track.albumId,
      },
    );
  }

  // BaseAudioHandler implementation

  Stream<base_handler.AudioPlayerState> get stateStream => _stateController.stateStream;

  Stream<Duration> get positionStream => _stateController.positionStream;

  Stream<Duration?> get durationStream => _stateController.durationStream;

  Stream<List<MediaItem>> get queueStream => queue.stream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  base_handler.AudioPlayerState get currentState => _stateController.currentState;

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

  base_handler.RepeatMode get repeatMode => _stateController.repeatMode;

  bool get shuffleEnabled => _stateController.shuffleEnabled;

  bool get gaplessPlaybackEnabled => _stateController.gaplessPlaybackEnabled;

  bool get radioModeEnabled => _radioModeEnabled;

  // Playbook control methods

  @override
  Future<void> play() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DoudouAudioHandler: Play command received');
      }

      _stateController.updateUserIntent(true);

      try {
        await _player.play();
        if (kDebugMode) {
          print('DoudouAudioHandler: Play command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Play failed: $e');
        }
        _stateController.updateError('Play failed: $e');
        _stateController.updateUserIntent(false);
        rethrow;
      }
    });
  }

  @override
  Future<void> pause() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DoudouAudioHandler: Pause command received');
      }

      _stateController.updateUserIntent(false);

      try {
        await _player.pause();
        if (kDebugMode) {
          print('DoudouAudioHandler: Pause command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Pause failed: $e');
        }
        _stateController.updateError('Pause failed: $e');
        rethrow;
      }
    });
  }

  @override
  Future<void> stop() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DoudouAudioHandler: Stop command received');
      }

      _stateController.updateUserIntent(false);

      try {
        await _player.stop();
        _stateController.updateState(base_handler.AudioPlayerState.idle);
        if (kDebugMode) {
          print('DoudouAudioHandler: Stop command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Stop failed: $e');
        }
        _stateController.updateError('Stop failed: $e');
        rethrow;
      }
    });
  }

  @override
  @override
  Future<void> seek(Duration position) async {
    return _stateController.queueCommand(() async {
      try {
        await _player.seek(position);
        _stateController.updatePosition(position);
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Seek failed: $e');
        }
        _stateController.updateError('Seek failed: $e');
        rethrow;
      }
    });
  }

  @override
  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      _stateController.updateSpeed(speed);
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Set speed failed: $e');
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
        print('DoudouAudioHandler: Set volume failed: $e');
      }
      _stateController.updateError('Set volume failed: $e');
    }
  }

  Future<void> playTrack(Track track) async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DoudouAudioHandler: Playing single track: ${track.name}');
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
          print('DoudouAudioHandler: Track loaded and playing');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Failed to play track: $e');
        }
        _stateController.updateError('Failed to play track: $e');
        rethrow;
      }
    });
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DoudouAudioHandler: Playing playlist with ${tracks.length} tracks, starting at $startIndex');
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
          print('DoudouAudioHandler: Playlist loaded and playing');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Failed to play playlist: $e');
        }
        _stateController.updateError('Failed to play playlist: $e');
        rethrow;
      }
    });
  }

  @override
  @override
  Future<void> skipToNext() async {
    final nextIndex = _queueManager.getNextTrackIndex();
    if (nextIndex != null) {
      await skipToQueueItem(nextIndex);
    }
  }

  @override
  @override
  Future<void> skipToPrevious() async {
    final previousIndex = _queueManager.getPreviousTrackIndex();
    if (previousIndex != null) {
      await skipToQueueItem(previousIndex);
    }
  }

  @override
  @override
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
          print('DoudouAudioHandler: Skip to index failed: $e');
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
      _stateController.updateState(base_handler.AudioPlayerState.loading);
      _stateController.updateUserIntent(true);
      
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.play();
      
    } catch (e) {
      _stateController.updateState(base_handler.AudioPlayerState.error);
      _stateController.updateUserIntent(false);
      rethrow;
    }
  }

  /// Get stream URL for track
  String _getStreamUrl(Track track) {
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

  @override
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    // Convert AudioService repeat mode to our repeat mode
    base_handler.RepeatMode ourMode;
    switch (mode) {
      case AudioServiceRepeatMode.none:
        ourMode = base_handler.RepeatMode.none;
        break;
      case AudioServiceRepeatMode.one:
        ourMode = base_handler.RepeatMode.one;
        break;
      case AudioServiceRepeatMode.all:
        ourMode = base_handler.RepeatMode.all;
        break;
      case AudioServiceRepeatMode.group:
        ourMode = base_handler.RepeatMode.all; // Map group to all
        break;
    }
    _stateController.updateRepeatMode(ourMode);
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
      print('DoudouAudioHandler: Disposing...');
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
        print('DoudouAudioHandler: Error disposing player: $e');
      }
    }

    // Reset state
    _stateController.reset();

    if (kDebugMode) {
      print('DoudouAudioHandler: Disposed');
    }
  }
}