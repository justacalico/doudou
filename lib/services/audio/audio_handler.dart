import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';
import '../download_service.dart';
import 'audio_state_manager.dart';
import 'audio_preloader.dart';
import 'audio_queue_manager.dart';
import 'audio_radio_mode.dart';
import 'audio_state_persistence.dart';

class DoudouAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  final DownloadService _downloadService;
  
  // Component managers
  late final AudioStateManager _stateManager;
  late final AudioPreloader _preloader;
  late final AudioQueueManager _queueManager;
  late final AudioRadioMode _radioMode;
  late final AudioStatePersistence _statePersistence;

  // Background playback tracking
  Timer? _backgroundPlaybackTimer;
  bool _isInBackground = false;

  DoudouAudioHandler(this._jellyfinService, this._downloadService) {
    _stateManager = AudioStateManager();
    _preloader = AudioPreloader(_jellyfinService, _downloadService);
    _queueManager = AudioQueueManager(_stateManager);
    _radioMode = AudioRadioMode(_jellyfinService);
    _statePersistence = AudioStatePersistence(_stateManager);
    
    _init();
    _loadPlaybackState();
  }

  void _init() {
    // Enhanced player state listener for background compatibility
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = _mapProcessingState(playerState.processingState);
      
      // Always update playback state to keep system informed
      final newPlaybackState = playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _stateManager.currentIndex,
      );
      
      playbackState.add(newPlaybackState);
      
      // Handle state changes that might indicate background issues
      if (processingState == AudioProcessingState.error && _isInBackground) {
        _handleBackgroundError();
      }
    });

    // Enhanced position stream for background tracking
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // More robust completion detection with background handling
    _player.processingStateStream.listen((state) {
      if (kDebugMode) {
        print('Processing state changed: $state');
      }
      
      if (state == ProcessingState.completed && !_stateManager.isHandlingCompletion) {
        if (kDebugMode) {
          print('Track completed, handling transition...');
        }
        // Use a microtask to ensure this runs even in background
        Future.microtask(() => _handleTrackCompletion());
      }
    });

    // Monitor playback for background issues
    _player.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        _statePersistence.startPeriodicSaving(_player.position, playerState.playing);
        _startBackgroundMonitoring();
      } else {
        _statePersistence.stopPeriodicSaving();
        _statePersistence.savePlaybackState(_player.position, playerState.playing);
        _stopBackgroundMonitoring();
      }
    });

    // Set initial playback state
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  void _startBackgroundMonitoring() {
    _stopBackgroundMonitoring();
    
    // Reduce frequency to avoid interference with track transitions
    _backgroundPlaybackTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkBackgroundPlayback();
    });
  }

  void _stopBackgroundMonitoring() {
    _backgroundPlaybackTimer?.cancel();
    _backgroundPlaybackTimer = null;
  }

  void _checkBackgroundPlayback() {
    // Don't interfere during transitions or completion handling
    if (_stateManager.isHandlingCompletion || _stateManager.isTransitioning) {
      return;
    }
    
    final playerState = _player.playerState;
    
    // Only handle if we're truly stuck, not during normal completion
    if (playbackState.value.playing && 
        playerState.processingState == ProcessingState.idle) {
      
      if (kDebugMode) {
        print('Background playback issue detected. Player state: ${playerState.processingState}, Expected: playing');
      }
      
      _handleBackgroundPlaybackIssue();
    }
  }

  void _handleBackgroundPlaybackIssue() async {
    if (_stateManager.isHandlingCompletion) return;
    
    try {
      // Check if we should move to next track or restart current
      final position = _player.position;
      final duration = _player.duration;
      
      if (duration != null && position.inMilliseconds >= (duration.inMilliseconds * 0.95)) {
        // Track is essentially complete, move to next
        if (kDebugMode) {
          print('Track near completion, moving to next');
        }
        await _handleTrackCompletion();
      } else {
        // Try to resume current track
        if (kDebugMode) {
          print('Attempting to resume current track from background issue');
        }
        await _resumeCurrentTrack();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling background playback issue: $e');
      }
    }
  }

  void _handleBackgroundError() async {
    if (kDebugMode) {
      print('Handling background error, attempting to recover...');
    }
    
    try {
      // Try to reload and resume the current track
      await _resumeCurrentTrack();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to recover from background error: $e');
      }
    }
  }

  Future<void> _resumeCurrentTrack() async {
    if (_stateManager.currentTrack == null) return;
    
    final currentPosition = _player.position;
    final wasPlaying = playbackState.value.playing;
    
    try {
      await _loadAndPlayTrack(_stateManager.currentTrack!);
      
      // Restore position if we had one
      if (currentPosition.inMilliseconds > 0) {
        await _player.seek(currentPosition);
      }
      
      // Resume playing if we were playing before
      if (wasPlaying) {
        await _player.play();
      }
      
      if (kDebugMode) {
        print('Successfully resumed track from background issue');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to resume track: $e');
      }
    }
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // Audio Service Methods - Enhanced for background compatibility
  @override
  Future<void> play() async {
    if (kDebugMode) {
      print('Play command received (background safe)');
    }
    
    try {
      // Ensure we have a track to play
      if (_stateManager.currentTrack == null && _stateManager.playlist.isNotEmpty) {
        await _playCurrentTrack();
      } else {
        await _player.play();
      }
      
      // Always verify the play command worked
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Update state to reflect actual player state
      playbackState.add(playbackState.value.copyWith(
        playing: _player.playing, // Use actual player state
        processingState: _player.processingState == ProcessingState.ready 
            ? AudioProcessingState.ready 
            : AudioProcessingState.loading,
      ));
      
      if (kDebugMode) {
        print('Play command completed. Actually playing: ${_player.playing}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in play command: $e');
      }
      
      // Try to recover by reloading current track
      if (_stateManager.currentTrack != null) {
        await _resumeCurrentTrack();
      }
    }
  }

  @override
  Future<void> pause() async {
    if (kDebugMode) {
      print('Pause command received');
    }
    
    try {
      await _player.pause();
      
      playbackState.add(playbackState.value.copyWith(
        playing: false,
      ));
      
      if (kDebugMode) {
        print('Pause command completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in pause command: $e');
      }
    }
  }

  @override
  Future<void> stop() async {
    _stopBackgroundMonitoring();
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (kDebugMode) {
      print('Manual skip to next requested. Current: ${_stateManager.currentIndex}, Max: ${_stateManager.playlist.length - 1}');
    }
    
    // Reset completion and transition handling to prevent conflicts
    _stateManager.setHandlingCompletion(false);
    _stateManager.setTransitioning(false);
    
    if (_stateManager.incrementCurrentIndex()) {
      if (kDebugMode) {
        print('Skipping to track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${_stateManager.currentTrack!.name}');
      }
      
      await _playCurrentTrack();
      await _statePersistence.savePlaybackState(_player.position, _player.playing);
    } else {
      if (kDebugMode) {
        print('Already at last track, cannot skip to next');
      }
      
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
      ));
    }
  }

  Future<void> _handleTrackCompletion() async {
    if (_stateManager.isHandlingCompletion || _stateManager.isTransitioning) {
      if (kDebugMode) {
        print('Already handling completion or transitioning, skipping...');
      }
      return;
    }
    
    _stateManager.setHandlingCompletion(true);
    _stateManager.setTransitioning(true);
    
    try {
      if (kDebugMode) {
        print('Track completed: ${_stateManager.currentTrack?.name}');
      }
      
      // Store the playing state before transition
      final wasPlaying = playbackState.value.playing;
      
      // Stop background monitoring during transition to prevent interference
      _stopBackgroundMonitoring();
      
      if (_stateManager.incrementCurrentIndex()) {
        if (kDebugMode) {
          print('Moving to next track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${_stateManager.currentTrack!.name}');
        }
        
        await _playCurrentTrack();
        
        // Restart background monitoring if we were playing
        if (wasPlaying) {
          _startBackgroundMonitoring();
        }
        
        await _statePersistence.savePlaybackState(_player.position, _player.playing);
        
        if (kDebugMode) {
          print('Successfully moved to next track: ${_stateManager.currentTrack!.name}');
        }
      } else if (_stateManager.radioModeEnabled && _stateManager.currentTrack != null) {
        // Radio mode handling
        final similarTracks = await _radioMode.getSimilarTracks(
          _stateManager.currentTrack!, 
          _stateManager.playlist,
          limit: 15
        );
        if (similarTracks.isNotEmpty) {
          _queueManager.addTracksToPlaylist(similarTracks);
          queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
          
          _stateManager.incrementCurrentIndex();
          await _playCurrentTrack();
          
          if (wasPlaying) {
            _startBackgroundMonitoring();
          }
          
          await _statePersistence.savePlaybackState(_player.position, _player.playing);
          
          if (kDebugMode) {
            print('Radio mode: Added ${similarTracks.length} tracks');
          }
        } else {
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
            playing: false,
          ));
        }
      } else {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
          playing: false,
        ));
        
        if (kDebugMode) {
          print('Reached end of playlist');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling track completion: $e');
      }
      
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
    } finally {
      _stateManager.setHandlingCompletion(false);
      _stateManager.setTransitioning(false);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final now = DateTime.now();
    final currentPosition = _player.position;
    final duration = _player.duration;
    
    bool shouldRestartCurrentSong = false;
    
    if (duration != null && duration.inMilliseconds > 0) {
      final restartThresholdMs = (duration.inMilliseconds * _stateManager.restartThresholdPercentage).round();
      final minThresholdMs = Duration(seconds: 5).inMilliseconds;
      final thresholdMs = restartThresholdMs < minThresholdMs ? restartThresholdMs : minThresholdMs;
      
      if (currentPosition.inMilliseconds > thresholdMs) {
        if (_stateManager.lastSkipToPreviousTime != null && 
            now.difference(_stateManager.lastSkipToPreviousTime!) < _stateManager.skipToPreviousThreshold) {
          shouldRestartCurrentSong = false;
        } else {
          shouldRestartCurrentSong = true;
        }
      } else {
        shouldRestartCurrentSong = false;
      }
    } else {
      shouldRestartCurrentSong = false;
    }
    
    _stateManager.setLastSkipToPreviousTime(now);
    
    if (shouldRestartCurrentSong) {
      await _player.seek(Duration.zero);
      if (kDebugMode) {
        print('Restarting current song: ${_stateManager.currentTrack?.name}');
      }
    } else {
      if (_stateManager.decrementCurrentIndex()) {
        await _playCurrentTrack();
        await _statePersistence.savePlaybackState(_player.position, _player.playing);
        if (kDebugMode) {
          print('Skipping to previous song');
        }
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _stateManager.playlist.length) {
      _stateManager.setCurrentIndex(index);
      await _playCurrentTrack();
      await _statePersistence.savePlaybackState(_player.position, _player.playing);
    }
  }

  // Enhanced track loading with better error handling
  Future<void> _playCurrentTrack() async {
    if (_stateManager.playlist.isEmpty || _stateManager.currentIndex >= _stateManager.playlist.length) {
      if (kDebugMode) {
        print('Cannot play current track: playlist empty or index out of bounds');
      }
      return;
    }

    final track = _stateManager.currentTrack!;
    
    if (kDebugMode) {
      print('Playing track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${track.name}');
    }
    
    // Update current media item immediately
    mediaItem.add(_trackToMediaItem(track));
    
    // Store playing state for background compatibility
    final wasPlaying = playbackState.value.playing;
    
    // Update to loading state
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: _stateManager.currentIndex,
      playing: wasPlaying,
    ));
    
    // Stop current player safely with longer delay for codec cleanup
    try {
      await _player.stop();
      // Give codecs more time to properly cleanup
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping player: $e');
      }
    }
    
    // Try preloaded player first
    final preloadedPlayer = _preloader.getPreloadedPlayer(track.id);
    if (preloadedPlayer != null) {
      try {
        if (preloadedPlayer.audioSource != null && 
            preloadedPlayer.processingState == ProcessingState.ready) {
          
          await _player.setAudioSource(preloadedPlayer.audioSource!);
          
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: wasPlaying,
            queueIndex: _stateManager.currentIndex,
          ));
          
          if (wasPlaying) {
            // Add delay before playing to ensure everything is ready
            await Future.delayed(const Duration(milliseconds: 100));
            await _player.play();
          }
          
          if (kDebugMode) {
            print('Successfully played preloaded track: ${track.name}');
          }
          
          preloadedPlayer.dispose();
          _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
          return;
        } else {
          if (kDebugMode) {
            print('Preloaded player not ready, falling back to normal loading');
          }
          preloadedPlayer.dispose();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to use preloaded track: $e');
        }
        preloadedPlayer.dispose();
      }
    }
    
    // Load track normally with improved error handling
    await _loadAndPlayTrack(track);
    
    // Only start preloading after current track is fully loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
    });
  }

  Future<void> _loadAndPlayTrack(Track track) async {
    final wasPlaying = playbackState.value.playing;
    
    if (kDebugMode) {
      print('Loading track: ${track.name}');
    }
    
    // Try local file first
    final localFilePath = _downloadService.getLocalFilePath(track.id);
    
    if (localFilePath != null) {
      final localFile = File(localFilePath);
      if (await localFile.exists()) {
        try {
          await _player.setFilePath(localFilePath);
          _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
          
          if (wasPlaying) {
            await _player.play();
          }
          
          if (kDebugMode) {
            print('Successfully loaded local file: ${track.name}');
          }
          return;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to play local file: $e');
          }
        }
      }
    }
    
    // Stream the track with enhanced error handling
    final streamUrls = [
      _jellyfinService.getDirectStreamUrl(track.id),
      _jellyfinService.getStreamUrl(track.id),
      _jellyfinService.getUniversalStreamUrl(track.id),
    ];
    
    bool loaded = false;
    Exception? lastError;
    
    for (final streamUrl in streamUrls) {
      try {
        if (streamUrl.isNotEmpty) {
          if (_shouldTranscodeTrack(track)) {
            final hlsUrl = _getHlsStreamUrl(track);
            if (hlsUrl.isNotEmpty) {
              await _player.setAudioSource(HlsAudioSource(Uri.parse(hlsUrl)));
            } else {
              await _player.setUrl(streamUrl);
            }
          } else {
            await _player.setUrl(streamUrl);
          }
           
          _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
          
          if (wasPlaying) {
            await _player.play();
          }
          
          loaded = true;
          if (kDebugMode) {
            print('Successfully loaded stream: ${track.name}');
          }
          break;
        }
      } catch (e) {
        lastError = e as Exception?;
        if (kDebugMode) {
          print('Failed to load stream URL: $e');
        }
      }
    }
    
    if (!loaded) {
      if (kDebugMode) {
        print('Failed to load any stream for: ${track.name}, last error: $lastError');
      }
      
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
    }
  }

  // Custom methods for the app
  Future<void> playTrack(Track track) async {
    await _player.stop();
    _preloader.clearAllPreloadedPlayers();
    _stateManager.setHandlingCompletion(false);
    _stateManager.setTransitioning(false);
    
    _queueManager.setSingleTrack(track);
    
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: 0,
    ));
    
    await _playCurrentTrack();
    
    if (kDebugMode) {
      print('Single track playback initiated: ${track.name}');
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    await _player.stop();
    _preloader.clearAllPreloadedPlayers();
    _stateManager.setHandlingCompletion(false);
    _stateManager.setTransitioning(false);
    
    _queueManager.setPlaylist(tracks, startIndex);
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: _stateManager.currentIndex,
    ));
    
    await _playCurrentTrack();
    
    Future.microtask(() => _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex));
    await _statePersistence.savePlaybackState(_player.position, _player.playing);
    
    if (kDebugMode) {
      print('Playlist playback initiated: ${tracks.length} tracks');
    }
  }

  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      album: track.albumName,
      title: track.name,
      artist: track.artistName,
      duration: track.duration != null ? Duration(milliseconds: track.duration!) : null,
      artUri: track.imageUrl != null 
          ? Uri.parse(_jellyfinService.getImageUrl(track.imageUrl!, width: 300, height: 300))
          : null,
    );
  }

  // Queue management methods
  void addToQueue(Track track) {
    _queueManager.addToQueue(track);
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    final position = _stateManager.playlist.length - _stateManager.currentIndex - 1;
    _preloader.preloadQueueTrack(track, position);
  }

  void addNext(Track track) {
    _queueManager.addNext(track);
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    _preloader.preloadPlayNextTrack(track);
  }

  void removeFromQueue(int index) {
    _queueManager.removeFromQueue(index);
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    _preloader.cleanupOldPreloadedPlayers(_stateManager.playlist, _stateManager.currentIndex);
  }

  void clearQueue() {
    _queueManager.clearQueue();
    _preloader.clearAllPreloadedPlayers();
    queue.add(<MediaItem>[]);
    mediaItem.add(null);
    stop();
  }

  void shuffle() {
    _preloader.clearAllPreloadedPlayers();
    _queueManager.shuffle();
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
  }

  void unshuffle() {
    _queueManager.unshuffle();
  }

  // Radio Mode functionality
  void toggleRadioMode() {
    _stateManager.setRadioModeEnabled(!_stateManager.radioModeEnabled);
  }

  void enableRadioMode() {
    _stateManager.setRadioModeEnabled(true);
  }

  void disableRadioMode() {
    _stateManager.setRadioModeEnabled(false);
  }

  // Audio settings
  void setSmartCrossfade(bool enabled) {
    _stateManager.setSmartCrossfadeEnabled(enabled);
    
    if (enabled) {
      _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
      _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
    } else {
      _preloader.clearAllPreloadedPlayers();
    }
  }

  void setNormalizeVolume(bool enabled) {
    _stateManager.setNormalizeVolumeEnabled(enabled);
    _player.setVolume(enabled ? 0.8 : 1.0);
  }

  void setGaplessPlayback(bool enabled) {
    _stateManager.setGaplessPlaybackEnabled(enabled);
  }

  // Getters
  Track? get currentTrack => _stateManager.currentTrack;
  List<Track> get playlist => _stateManager.playlist;
  List<Track> get queueTracks => _stateManager.queueTracks;
  List<Track> get upNext => _stateManager.upNext;
  int get currentIndex => _stateManager.currentIndex;
  bool get isPlaying => _player.playing;
  bool get hasNext => _stateManager.hasNext;
  bool get hasPrevious => _stateManager.hasPrevious;
  bool get isShuffled => _stateManager.isShuffled;
  bool get radioModeEnabled => _stateManager.radioModeEnabled;
  int get queueLength => _stateManager.queueLength;
  bool get smartCrossfadeEnabled => _stateManager.smartCrossfadeEnabled;
  bool get normalizeVolumeEnabled => _stateManager.normalizeVolumeEnabled;
  bool get gaplessPlaybackEnabled => _stateManager.gaplessPlaybackEnabled;
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  PlayerState get playerState => _player.playerState;

  @override
  Future<void> onTaskRemoved() async {
    if (kDebugMode) {
      print('App task removed, stopping playback');
    }
    await stop();
  }

  Future<void> _loadPlaybackState() async {
    final stateData = await _statePersistence.loadPlaybackState();
    if (stateData != null) {
      queue.add(stateData.playlist.map(_trackToMediaItem).toList());
      mediaItem.add(_trackToMediaItem(stateData.playlist[stateData.currentIndex]));
      
      try {
        final currentTrack = stateData.playlist[stateData.currentIndex];
        
        final streamUrls = [
          _jellyfinService.getDirectStreamUrl(currentTrack.id),
          _jellyfinService.getStreamUrl(currentTrack.id),
          _jellyfinService.getUniversalStreamUrl(currentTrack.id),
        ];
        
        bool loaded = false;
        for (final streamUrl in streamUrls) {
          try {
            if (streamUrl.isNotEmpty) {
              await _player.setUrl(streamUrl);
              loaded = true;
              break;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to load stream URL for restored track: $e');
            }
          }
        }
        
        if (loaded) {
          if (stateData.savedPosition.inMilliseconds > 0) {
            await _player.seek(stateData.savedPosition);
          }
          
          if (stateData.wasPlaying) {
            await _player.play();
            _statePersistence.startPeriodicSaving(_player.position, _player.playing);
            if (kDebugMode) {
              print('Automatically resumed playback: ${currentTrack.name}');
            }
          }
          
          playbackState.add(playbackState.value.copyWith(
            controls: [
              MediaControl.skipToPrevious,
              stateData.wasPlaying ? MediaControl.pause : MediaControl.play,
              MediaControl.skipToNext,
            ],
            systemActions: const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
            },
            androidCompactActionIndices: const [0, 1, 2],
            processingState: AudioProcessingState.ready,
            playing: stateData.wasPlaying,
            updatePosition: stateData.savedPosition,
            queueIndex: stateData.currentIndex,
          ));
          
          if (kDebugMode) {
            print('Successfully restored playback state: ${currentTrack.name}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error preparing restored track: $e');
        }
      }
    }
  }

  // Background state management
  void setBackgroundState(bool isBackground) {
    _isInBackground = isBackground;
    
    if (kDebugMode) {
      print('App background state changed: $isBackground');
    }
  }

  // Transcoding support methods
  bool _shouldTranscodeTrack(Track track) {
    return true; // Enable transcoding for maximum compatibility
  }

  String _getHlsStreamUrl(Track track) {
    final streamUrl = _jellyfinService.getStreamUrl(track.id);
    if (streamUrl.isEmpty) return '';
    
    final baseUrl = streamUrl.split('/Audio/')[0];
    final urlParts = streamUrl.split('api_key=');
    if (urlParts.length < 2) return '';
    
    final apiKey = urlParts[1].split('&')[0];
    return '$baseUrl/Audio/${track.id}/main.m3u8?ApiKey=$apiKey&audioCodec=aac&audioSampleRate=44100&maxAudioBitDepth=16&audioBitRate=320000';
  }

  Future<void> dispose() async {
    _stopBackgroundMonitoring();
    _statePersistence.dispose();
    _preloader.dispose();
    await _player.dispose();
  }
}