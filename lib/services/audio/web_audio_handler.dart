import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/jellyfin_models.dart';
import '../media_service_manager.dart';
import 'base_audio_handler.dart';
import 'audio_state_controller.dart';
import 'queue_manager.dart';

/// WebAudioHandler - Audio handler for web platform
/// Uses just_audio with web-specific optimizations and media session integration
class WebAudioHandler implements BaseAudioHandler {
  final MediaServiceManager _mediaServiceManager;
  final AudioStateController _stateController = AudioStateController();
  final AudioQueueManager _queueManager = AudioQueueManager();
  final AudioPlayer _player = AudioPlayer();
  
  // Stream subscriptions for proper cleanup
  late final List<StreamSubscription> _subscriptions = [];
  
  // Radio mode state
  bool _radioModeEnabled = false;
  Timer? _radioModeTimer;
  
  // Web-specific media session
  html.MediaSession? _mediaSession;
  
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
      
      // Set up web media session
      _setupMediaSession();
      
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

  /// Set up web media session for system integration
  void _setupMediaSession() {
    try {
      _mediaSession = html.window.navigator.mediaSession;
      
      if (_mediaSession != null) {
        // Set up media session action handlers
        _mediaSession!.setActionHandler('play', (details) => play());
        _mediaSession!.setActionHandler('pause', (details) => pause());
        _mediaSession!.setActionHandler('previoustrack', (details) => skipToPrevious());
        _mediaSession!.setActionHandler('nexttrack', (details) => skipToNext());
        _mediaSession!.setActionHandler('seekto', (details) {
          if (details.seekTime != null) {
            seek(Duration(seconds: details.seekTime!.round()));
          }
        });
        
        if (kDebugMode) {
          print('WebAudioHandler: Media session configured');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Failed to configure media session: $e');
      }
    }
  }

  /// Update media session metadata
  void _updateMediaSessionMetadata(Track track) {
    try {
      if (_mediaSession != null) {
        _mediaSession!.metadata = html.MediaMetadata({
          'title': track.name,
          'artist': track.artistName ?? 'Unknown Artist',
          'album': track.albumName ?? '',
          'artwork': [
            {
              'src': _mediaServiceManager.getImageUrl(
                track.albumId ?? track.id,
                width: 512,
                height: 512,
              ),
              'sizes': '512x512',
              'type': 'image/jpeg',
            }
          ],
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Failed to update media session metadata: $e');
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
    
    // Volume and speed synchronization
    _subscriptions.add(
      _player.volumeStream.listen(_stateController.updateVolume)
    );
    
    _subscriptions.add(
      _player.speedStream.listen(_stateController.updateSpeed)
    );
    
    // Update media session when track changes
    _subscriptions.add(
      _stateController.currentTrackStream.listen((track) {
        if (track != null) {
          _updateMediaSessionMetadata(track);
        }
      })
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

  /// Update media session playback state
  void _updateMediaSessionPlaybackState() {
    try {
      if (_mediaSession != null) {
        final state = _stateController.currentState;
        final position = _stateController.position;
        final speed = _stateController.speed;
        
        String playbackState = 'none';
        switch (state) {
          case AudioPlayerState.playing:
            playbackState = 'playing';
            break;
          case AudioPlayerState.paused:
            playbackState = 'paused';
            break;
          case AudioPlayerState.loading:
            playbackState = 'playing'; // Show as playing while loading
            break;
          default:
            playbackState = 'none';
        }
        
        _mediaSession!.setPositionState(html.MediaPositionState(
          duration: _stateController.duration.inSeconds.toDouble(),
          playbackRate: speed,
          position: position.inSeconds.toDouble(),
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Failed to update media session playback state: $e');
      }
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
        print('WebAudioHandler: Error fetching similar tracks: $e');
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
      (state, position, speed) => WebPlaybackState(
        playing: state == AudioPlayerState.playing,
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('WebAudioHandler: Playing playlist with ${tracks.length} tracks, starting at $startIndex');
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

  /// Convert Track to WebMediaItem for compatibility
  WebMediaItem _trackToMediaItem(Track track) {
    return WebMediaItem(
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

class WebPlaybackState implements PlaybackState {
  final bool playing;
  final Duration updatePosition;
  final double speed;
  
  WebPlaybackState({
    required this.playing,
    required this.updatePosition,
    required this.speed,
  });
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class WebMediaItem implements MediaItem {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final Uri? artUri;
  final Map<String, dynamic>? extras;
  
  WebMediaItem({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.artUri,
    this.extras,
  });
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}