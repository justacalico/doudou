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
    // Simple player state listener - trust just_audio to manage states
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = _mapProcessingState(playerState.processingState);
      
      // Update playback state based on actual player state
      playbackState.add(playbackState.value.copyWith(
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
      ));
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // Simple completion detection - only use ProcessingState.completed
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !_stateManager.isHandlingCompletion) {
        if (kDebugMode) {
          print('Track completed, moving to next');
        }
        _handleTrackCompletion();
      }
    });

    // Start/stop periodic state saving based on playback state
    _player.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        _statePersistence.startPeriodicSaving(_player.position, playerState.playing);
      } else {
        _statePersistence.stopPeriodicSaving();
        _statePersistence.savePlaybackState(_player.position, playerState.playing); // Save immediately when paused
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

  // Audio Service Methods
  @override
  Future<void> play() async {
    if (kDebugMode) {
      print('Play command received');
    }
    
    // Simple and direct approach - trust just_audio to handle playback
    await _player.play();
    
    // Update playback state immediately
    playbackState.add(playbackState.value.copyWith(
      playing: true,
    ));
    
    if (kDebugMode) {
      print('Play command completed');
    }
  }

  @override
  Future<void> pause() async {
    if (kDebugMode) {
      print('Pause command received');
    }
    
    await _player.pause();
    
    // Update playback state immediately
    playbackState.add(playbackState.value.copyWith(
      playing: false,
    ));
    
    if (kDebugMode) {
      print('Pause command completed');
    }
  }

  @override
  Future<void> stop() async {
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
      
      // Update state to show we're at the end
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
      ));
    }
  }

  Future<void> _handleTrackCompletion() async {
    if (_stateManager.isHandlingCompletion) {
      if (kDebugMode) {
        print('Already handling completion, skipping...');
      }
      return; // Prevent race conditions
    }
    
    _stateManager.setHandlingCompletion(true);
    
    try {
      if (kDebugMode) {
        print('Track completed: ${_stateManager.currentTrack?.name}');
      }
      
      // Simple logic: move to next track if available
      if (_stateManager.incrementCurrentIndex()) {
        await _playCurrentTrack();
        await _statePersistence.savePlaybackState(_player.position, _player.playing);
        
        if (kDebugMode) {
          print('Moved to next track: ${_stateManager.currentTrack!.name}');
        }
      } else if (_stateManager.radioModeEnabled && _stateManager.currentTrack != null) {
        // Add radio tracks and continue playing
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
          await _statePersistence.savePlaybackState(_player.position, _player.playing);
          
          if (kDebugMode) {
            print('Radio mode: Added ${similarTracks.length} tracks');
          }
        } else {
          // No similar tracks, stop playback
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
            playing: false,
          ));
        }
      } else {
        // End of playlist, stop playback
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
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final now = DateTime.now();
    final currentPosition = _player.position;
    final duration = _player.duration;
    
    // Calculate if we should restart current song or go to previous
    bool shouldRestartCurrentSong = false;
    
    if (duration != null && duration.inMilliseconds > 0) {
      // Check if we're past the restart threshold (20% of song or 5 seconds, whichever is smaller)
      final restartThresholdMs = (duration.inMilliseconds * _stateManager.restartThresholdPercentage).round();
      final minThresholdMs = Duration(seconds: 5).inMilliseconds;
      final thresholdMs = restartThresholdMs < minThresholdMs ? restartThresholdMs : minThresholdMs;
      
      if (currentPosition.inMilliseconds > thresholdMs) {
        // We're past the threshold, check if this is a double-tap within 5 seconds
        if (_stateManager.lastSkipToPreviousTime != null && 
            now.difference(_stateManager.lastSkipToPreviousTime!) < _stateManager.skipToPreviousThreshold) {
          // Double-tap within threshold - go to previous song
          shouldRestartCurrentSong = false;
        } else {
          // Single tap past threshold - restart current song
          shouldRestartCurrentSong = true;
        }
      } else {
        // We're within the threshold - always go to previous song
        shouldRestartCurrentSong = false;
      }
    } else {
      // No duration info - go to previous song
      shouldRestartCurrentSong = false;
    }
    
    _stateManager.setLastSkipToPreviousTime(now);
    
    if (shouldRestartCurrentSong) {
      // Restart current song by seeking to beginning
      await _player.seek(Duration.zero);
      if (kDebugMode) {
        print('Restarting current song: ${_stateManager.currentTrack?.name}');
      }
    } else {
      // Go to previous song (original behavior)
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

  // Custom methods for the app
  Future<void> playTrack(Track track) async {
    // Stop any currently playing audio first
    await _player.stop();
    
    // Clear existing preloaded tracks
    _preloader.clearAllPreloadedPlayers();
    
    // Reset completion handling state
    _stateManager.setHandlingCompletion(false);
    
    _queueManager.setSingleTrack(track);
    
    if (kDebugMode) {
      print('Playing single track: ${track.name}');
    }
    
    // Set state to playing immediately for instant UI response
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: 0,
    ));
    
    // Load and play the track - trust just_audio to handle the rest
    await _playCurrentTrack();
    
    if (kDebugMode) {
      print('Single track playback initiated');
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    // Stop any currently playing audio
    await _player.stop();
    
    // Clear existing preloaded tracks
    _preloader.clearAllPreloadedPlayers();
    
    // Reset completion handling state
    _stateManager.setHandlingCompletion(false);
    
    _queueManager.setPlaylist(tracks, startIndex);
    
    // Update audio service queue
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    if (kDebugMode) {
      print('Starting playlist: ${tracks.length} tracks, starting at index $startIndex');
    }
    
    // Set state to playing immediately for instant UI response
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: _stateManager.currentIndex,
    ));
    
    // Start playing current track - trust just_audio to handle the rest
    await _playCurrentTrack();
    
    // Start preloading next tracks in background
    Future.microtask(() => _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex));
    
    // Save the new playlist state
    await _statePersistence.savePlaybackState(_player.position, _player.playing);
    
    if (kDebugMode) {
      print('Playlist playback initiated');
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
    
    // Update current media item immediately for better background experience
    mediaItem.add(_trackToMediaItem(track));
    
    // Store the current playing state to maintain it through the transition
    final wasPlaying = playbackState.value.playing;
    
    // Update playback state to loading while preserving playing state
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: _stateManager.currentIndex,
      playing: wasPlaying, // Preserve the playing state
    ));
    
    // Stop current player first to ensure clean state and prevent interruptions
    try {
      await _player.stop();
      // Give the player time to fully stop to prevent "Loading interrupted" errors
      await Future.delayed(const Duration(milliseconds: 150)); 
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping player: $e');
      }
    }
    
    // Check if we have a preloaded player for this track
    final preloadedPlayer = _preloader.getPreloadedPlayer(track.id);
    if (preloadedPlayer != null) {
      try {
        // Check if the preloaded player is ready
        if (preloadedPlayer.audioSource != null && 
            preloadedPlayer.processingState == ProcessingState.ready) {
          
          // Set the same audio source on main player
          await _player.setAudioSource(preloadedPlayer.audioSource!);
          
          // Update state to ready before playing, maintaining the playing state
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: wasPlaying, // Maintain the previous playing state
            queueIndex: _stateManager.currentIndex,
          ));
          
          // Only start playing if we were playing before
          if (wasPlaying) {
            await _player.play();
          }
          
          if (kDebugMode) {
            print('Successfully ${wasPlaying ? "playing" : "loaded"} preloaded track: ${track.name}');
          }
          
          // Dispose the preloaded player
          preloadedPlayer.dispose();
          
          // Preload next tracks after successful play
          _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
          return;
          
        } else {
          // Preloaded player not ready, fall back to normal loading
          if (kDebugMode) {
            print('Preloaded player not ready for: ${track.name}, state: ${preloadedPlayer.processingState}');
          }
          preloadedPlayer.dispose();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to play preloaded track: $e');
        }
        // Dispose the preloaded player and fall back to normal loading
        preloadedPlayer.dispose();
      }
    }
    
    // Fallback to normal loading if no preloaded version or if preloaded failed
    await _loadAndPlayTrack(track);
    
    // Preload next tracks after successful play
    _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
  }

  Future<void> _loadAndPlayTrack(Track track) async {
    // Store the current playing state to maintain it through the loading process
    final wasPlaying = playbackState.value.playing;
    
    if (kDebugMode) {
      print('Loading track: ${track.name}');
    }
    
    // Check if track is downloaded locally first
    final localFilePath = _downloadService.getLocalFilePath(track.id);
    
    if (localFilePath != null) {
      final localFile = File(localFilePath);
      if (await localFile.exists()) {
        if (kDebugMode) {
          print('Playing local file: ${track.name}');
        }
        
        try {
          await _player.setFilePath(localFilePath);
          _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
          
          if (wasPlaying) {
            await _player.play();
          }
          
          return; // Success! Exit early
        } catch (e) {
          if (kDebugMode) {
            print('Failed to play local file for ${track.name}: $e');
          }
        }
      }
    }
    
    // Stream the track - try transcoding first for better compatibility
    try {
      AudioSource audioSource;
      
      if (_shouldTranscodeTrack(track)) {
        // Use HLS transcoding for maximum compatibility
        final hlsUrl = _getHlsStreamUrl(track);
        if (hlsUrl.isNotEmpty) {
          audioSource = HlsAudioSource(Uri.parse(hlsUrl));
          if (kDebugMode) {
            print('Using HLS transcoding for: ${track.name}');
          }
        } else {
          // Fallback to direct stream
          audioSource = AudioSource.uri(Uri.parse(_jellyfinService.getDirectStreamUrl(track.id)));
          if (kDebugMode) {
            print('HLS failed, using direct stream for: ${track.name}');
          }
        }
      } else {
        // Use direct stream
        audioSource = AudioSource.uri(Uri.parse(_jellyfinService.getDirectStreamUrl(track.id)));
        if (kDebugMode) {
          print('Using direct stream for: ${track.name}');
        }
      }
      
      await _player.setAudioSource(audioSource);
      _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
      
      if (wasPlaying) {
        await _player.play();
      }
      
      if (kDebugMode) {
        print('Successfully loaded: ${track.name}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load track ${track.name}: $e');
      }
      
      // Set error state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  // Queue management methods (delegate to queue manager)
  void addToQueue(Track track) {
    _queueManager.addToQueue(track);
    
    // Update audio service queue
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    // Preload if it's likely to be played soon
    final position = _stateManager.playlist.length - _stateManager.currentIndex - 1; // Position from current track
    _preloader.preloadQueueTrack(track, position);
  }

  void addNext(Track track) {
    _queueManager.addNext(track);
    
    // Update audio service queue
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    // This track will play next - preload it immediately
    _preloader.preloadPlayNextTrack(track);
  }

  void removeFromQueue(int index) {
    _queueManager.removeFromQueue(index);
    
    // Update audio service queue
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    // Clean up preloaded players
    _preloader.cleanupOldPreloadedPlayers(_stateManager.playlist, _stateManager.currentIndex);
  }

  void clearQueue() {
    _queueManager.clearQueue();
    
    // Clear preloaded players
    _preloader.clearAllPreloadedPlayers();
    
    // Update audio service
    queue.add(<MediaItem>[]);
    mediaItem.add(null);
    
    stop();
  }

  void shuffle() {
    // Clear preloaded players since order will change
    _preloader.clearAllPreloadedPlayers();
    
    _queueManager.shuffle();
    
    // Update audio service queue
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    // Restart preloading with new order
    _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
  }

  void unshuffle() {
    _queueManager.unshuffle();
  }

  // Radio Mode functionality for endless playback
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
      // Enable crossfade with 3-second duration
      // Apply volume based on normalization setting
      _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
      
      // Start preloading next tracks
      _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
    } else {
      // Disable crossfade and clear preloaded tracks
      _preloader.clearAllPreloadedPlayers();
    }
  }

  void setNormalizeVolume(bool enabled) {
    _stateManager.setNormalizeVolumeEnabled(enabled);
    
    // Apply volume normalization
    _player.setVolume(enabled ? 0.8 : 1.0);
  }

  void setGaplessPlayback(bool enabled) {
    _stateManager.setGaplessPlaybackEnabled(enabled);
  }

  // Getters (delegate to state manager)
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
    // Handle task removal (app swiped away)
    await stop();
  }

  Future<void> _loadPlaybackState() async {
    final stateData = await _statePersistence.loadPlaybackState();
    if (stateData != null) {
      // Update audio service queue
      queue.add(stateData.playlist.map(_trackToMediaItem).toList());
      
      // Update current media item
      mediaItem.add(_trackToMediaItem(stateData.playlist[stateData.currentIndex]));
      
      // Prepare the audio source
      try {
        final currentTrack = stateData.playlist[stateData.currentIndex];
        
        final streamUrls = [
          _jellyfinService.getStreamUrl(currentTrack.id),
          _jellyfinService.getDirectStreamUrl(currentTrack.id),
          _jellyfinService.getUniversalStreamUrl(currentTrack.id),
        ];
        
        bool loaded = false;
        for (final streamUrl in streamUrls) {
          try {
            await _player.setUrl(streamUrl);
            loaded = true;
            break;
          } catch (e) {
            if (kDebugMode) {
              print('Failed to load stream URL for restored track: $e');
            }
          }
        }
        
        if (loaded) {
          // Restore position
          if (stateData.savedPosition.inMilliseconds > 0) {
            await _player.seek(stateData.savedPosition);
          }
          
          // Resume playing if it was playing before
          if (stateData.wasPlaying) {
            await _player.play();
            _statePersistence.startPeriodicSaving(_player.position, _player.playing); // Start saving state if we resumed playing
            if (kDebugMode) {
              print('Automatically resumed playback: ${currentTrack.name}');
            }
          }
          
          // Update playback state
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

  // Transcoding support methods
  bool _shouldTranscodeTrack(Track track) {
    // For now, enable transcoding for all tracks for maximum compatibility
    // In the future, this could check codec types or file formats
    return true;
  }

  String _getHlsStreamUrl(Track track) {
    // Use the existing stream URL method as a base and construct HLS URL
    final streamUrl = _jellyfinService.getStreamUrl(track.id);
    if (streamUrl.isEmpty) return '';
    
    // Extract the base URL and construct HLS endpoint
    final baseUrl = streamUrl.split('/Audio/')[0];
    final urlParts = streamUrl.split('api_key=');
    if (urlParts.length < 2) return '';
    
    final apiKey = urlParts[1].split('&')[0];
    return '$baseUrl/Audio/${track.id}/main.m3u8?ApiKey=$apiKey&audioCodec=aac&audioSampleRate=44100&maxAudioBitDepth=16&audioBitRate=320000';
  }

  void dispose() {
    _statePersistence.dispose();
    _preloader.dispose();
    _player.dispose();
  }
}
