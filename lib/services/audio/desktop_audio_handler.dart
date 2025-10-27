import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:rxdart/rxdart.dart';
import '../../models/jellyfin_models.dart' as models;
import '../media_service_manager.dart';
import 'base_audio_handler.dart';
import 'audio_state_controller.dart';
import 'queue_manager.dart';

/// DesktopAudioHandler - Audio handler for Linux, macOS, and Windows
/// Uses media_kit for enhanced codec support on desktop platforms
class DesktopAudioHandler implements BaseAudioHandler {
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
  DesktopAudioHandler(this._mediaServiceManager) {
    _initializeAudio();
  }

  /// Initialize audio system with media_kit
  Future<void> _initializeAudio() async {
    try {
      if (kDebugMode) {
        print('DesktopAudioHandler: Initializing desktop audio system...');
      }

      // Initialize media_kit for enhanced codec support
      MediaKit.ensureInitialized();
      
      // Configure just_audio to use media_kit
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        JustAudioMediaKit.ensureInitialized();
      }
      
      // Set up player event listeners
      _setupPlayerListeners();
      
      if (kDebugMode) {
        print('DesktopAudioHandler: Desktop audio system initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DesktopAudioHandler: Failed to initialize desktop audio system: $e');
      }
      _stateController.updateError('Failed to initialize desktop audio: $e');
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
    
    // Volume and speed synchronization
    _subscriptions.add(
      _player.volumeStream.listen(_stateController.updateVolume)
    );
    
    _subscriptions.add(
      _player.speedStream.listen(_stateController.updateSpeed)
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
      print('DesktopAudioHandler: Track completed');
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
        print('DesktopAudioHandler: Failed to fetch radio tracks: $e');
      }
      // Fallback to normal next track behavior
      await skipToNext();
    }
  }

  /// Fetch similar tracks for radio mode
  Future<List<Track>> _fetchSimilarTracks(Track track) async {
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
        print('DesktopAudioHandler: Error fetching similar tracks: $e');
      }
      return [];
    }
  }

  // BaseAudioHandler implementation

  @override
  Stream<AudioPlayerState> get stateStream => _stateController.stateStream;

  @override
  Stream<Duration> get positionStream => _stateController.positionStream;

  @override
  Stream<Duration?> get durationStream => _stateController.durationStream;

  @override
  Stream<PlaybackState> get playbackState => 
    CombineLatestStream.combine3(
      stateStream,
      positionStream,
      _player.speedStream,
      (state, position, speed) => PlaybackState(
        playing: state == AudioPlayerState.playing,
        processingState: AudioProcessingState.ready,
        updatePosition: position,
        speed: speed,
      )
    );

  @override
  Stream<List<MediaItem>> get queueStream => 
    _stateController.queueStream.map((tracks) => 
      tracks.map(_trackToMediaItem).toList()
    );

  @override
  Stream<MediaItem?> get mediaItem => 
    _stateController.currentTrackStream.map((track) => 
      track != null ? _trackToMediaItem(track) : null
    );

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  AudioPlayerState get currentState => _stateController.currentState;

  @override
  Duration get position => _stateController.position;

  @override
  Duration get duration => _stateController.duration;

  @override
  Track? get currentTrack => _stateController.currentTrack;

  @override
  List<Track> get queueTracks => _stateController.queue;

  @override
  List<Track> get upNext => _queueManager.getUpNext();

  @override
  double get volume => _stateController.volume;

  @override
  double get speed => _stateController.speed;

  @override
  bool get userIntendedPlaying => _stateController.userIntendedPlaying;

  @override
  PlayerState get playerState => _player.playerState;

  @override
  int? get currentIndex => _stateController.currentIndex;

  @override
  bool get hasNext => _queueManager.hasNext;

  @override
  bool get hasPrevious => _queueManager.hasPrevious;

  @override
  RepeatMode get repeatMode => _stateController.repeatMode;

  @override
  bool get shuffleEnabled => _stateController.shuffleEnabled;

  @override
  bool get gaplessPlaybackEnabled => _stateController.gaplessPlaybackEnabled;

  @override
  bool get radioModeEnabled => _radioModeEnabled;

  // Playback control methods

  @override
  Future<void> play() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DesktopAudioHandler: Play command received');
      }

      _stateController.updateUserIntent(true);

      try {
        await _player.play();
        if (kDebugMode) {
          print('DesktopAudioHandler: Play command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DesktopAudioHandler: Play failed: $e');
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
        print('DesktopAudioHandler: Pause command received');
      }

      _stateController.updateUserIntent(false);

      try {
        await _player.pause();
        if (kDebugMode) {
          print('DesktopAudioHandler: Pause command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DesktopAudioHandler: Pause failed: $e');
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
        print('DesktopAudioHandler: Stop command received');
      }

      _stateController.updateUserIntent(false);

      try {
        await _player.stop();
        _stateController.updateState(AudioPlayerState.idle);
        if (kDebugMode) {
          print('DesktopAudioHandler: Stop command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DesktopAudioHandler: Stop failed: $e');
        }
        _stateController.updateError('Stop failed: $e');
        rethrow;
      }
    });
  }

  @override
  Future<void> seek(Duration position) async {
    return _stateController.queueCommand(() async {
      try {
        await _player.seek(position);
        _stateController.updatePosition(position);
      } catch (e) {
        if (kDebugMode) {
          print('DesktopAudioHandler: Seek failed: $e');
        }
        _stateController.updateError('Seek failed: $e');
        rethrow;
      }
    });
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      _stateController.updateSpeed(speed);
    } catch (e) {
      if (kDebugMode) {
        print('DesktopAudioHandler: Set speed failed: $e');
      }
      _stateController.updateError('Set speed failed: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
      _stateController.updateVolume(volume);
    } catch (e) {
      if (kDebugMode) {
        print('DesktopAudioHandler: Set volume failed: $e');
      }
      _stateController.updateError('Set volume failed: $e');
    }
  }

  @override
  Future<void> playTrack(Track track) async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DesktopAudioHandler: Playing single track: ${track.name}');
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
          print('DesktopAudioHandler: Track loaded and playing');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DesktopAudioHandler: Failed to play track: $e');
        }
        _stateController.updateError('Failed to play track: $e');
        rethrow;
      }
    });
  }

  @override
  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DesktopAudioHandler: Playing playlist with ${tracks.length} tracks, starting at $startIndex');
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
          print('DesktopAudioHandler: Playlist loaded and playing');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DesktopAudioHandler: Failed to play playlist: $e');
        }
        _stateController.updateError('Failed to play playlist: $e');
        rethrow;
      }
    });
  }

  @override
  Future<void> skipToNext() async {
    final nextIndex = _queueManager.getNextTrackIndex();
    if (nextIndex != null) {
      await skipToQueueItem(nextIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final previousIndex = _queueManager.getPreviousTrackIndex();
    if (previousIndex != null) {
      await skipToQueueItem(previousIndex);
    }
  }

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
          print('DesktopAudioHandler: Skip to index failed: $e');
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
      
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.play();
      
    } catch (e) {
      _stateController.updateState(AudioPlayerState.error);
      _stateController.updateUserIntent(false);
      rethrow;
    }
  }

  /// Get stream URL for track
  String _getStreamUrl(Track track) {
    return _mediaServiceManager.getStreamUrl(track.id);
  }

  /// Convert Track to MediaItem for compatibility
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

  // Queue management

  @override
  void addToQueue(Track track) {
    _queueManager.addToQueue(track);
  }

  @override
  void addNext(Track track) {
    _queueManager.addNext(track);
  }

  @override
  void removeFromQueue(int index) {
    _queueManager.removeFromQueue(index);
  }

  @override
  void reorderQueue(int oldIndex, int newIndex) {
    _queueManager.reorderQueue(oldIndex, newIndex);
  }

  @override
  void clearQueue() {
    _queueManager.clearQueue();
  }

  // Playback modes

  @override
  void setRepeatMode(RepeatMode mode) {
    _stateController.updateRepeatMode(mode);
  }

  @override
  void toggleShuffle() {
    _queueManager.toggleShuffle();
  }

  @override
  void setGaplessPlayback(bool enabled) {
    _stateController.updateGaplessPlayback(enabled);
    
    // Configure gapless playback on the player if supported
    try {
      _player.setAudioSource(
        ConcatenatingAudioSource(
          children: [],
          useLazyPreparation: !enabled,
        )
      );
    } catch (e) {
      if (kDebugMode) {
        print('DesktopAudioHandler: Failed to configure gapless playback: $e');
      }
    }
  }

  @override
  void toggleRadioMode() {
    _radioModeEnabled = !_radioModeEnabled;
    _stateController.updateRadioMode(_radioModeEnabled);
  }

  @override
  void enableRadioMode() {
    _radioModeEnabled = true;
    _stateController.updateRadioMode(true);
  }

  @override
  void disableRadioMode() {
    _radioModeEnabled = false;
    _stateController.updateRadioMode(false);
  }

  // Lifecycle management

  @override
  Future<void> dispose() async {
    if (kDebugMode) {
      print('DesktopAudioHandler: Disposing...');
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
        print('DesktopAudioHandler: Error disposing player: $e');
      }
    }

    // Reset state
    _stateController.reset();

    if (kDebugMode) {
      print('DesktopAudioHandler: Disposed');
    }
  }
}