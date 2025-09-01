import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/jellyfin_models.dart';
import 'jellyfin_service.dart';
import 'download_service.dart';

class DoudouAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  final DownloadService _downloadService;
  
  List<Track> _playlist = [];
  List<Track> _queue = [];
  int _currentIndex = 0;
  Track? _currentTrack;
  bool _isShuffled = false;
  bool _smartCrossfadeEnabled = false;
  bool _normalizeVolumeEnabled = false;
  final Duration _crossfadeDuration = const Duration(seconds: 3);
  
  // Preloading and caching
  final Map<String, AudioPlayer> _preloadedPlayers = {};
  final Set<String> _preloadingTracks = {};
  
  // Completion tracking to prevent race conditions
  bool _isHandlingCompletion = false;
  
  // Skip-to-previous behavior tracking
  DateTime? _lastSkipToPreviousTime;
  static const Duration _skipToPreviousThreshold = Duration(seconds: 5);
  static const double _restartThresholdPercentage = 0.20; // 20% of song duration
  
  // Periodic state saving
  Timer? _saveStateTimer;
  
  // Background completion checker as fallback
  Timer? _completionCheckTimer;

  DoudouAudioHandler(this._jellyfinService) {
    _init();
    _loadPlaybackState();
  }

  void _init() {
    // Listen to player state changes and update audio service
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = _mapProcessingState(playerState.processingState);
      
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
        queueIndex: _currentIndex,
      ));
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // Auto-play next track when current track completes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_isHandlingCompletion) {
        if (kDebugMode) {
          print('Track completion detected via playerStateStream, handling...');
        }
        _handleTrackCompletion();
      }
    });

    // Enhanced position stream listener for reliable background track progression
    _player.positionStream.listen((position) {
      final duration = _player.duration;
      final playerState = _player.playerState;
      
      if (duration != null && duration.inMilliseconds > 0 && playerState.playing) {
        final remaining = duration - position;
        
        // Multiple fallback mechanisms for background playback
        
        // 1. Near end detection (1 second remaining)
        if (remaining.inMilliseconds <= 1000 && remaining.inMilliseconds > 500 && !_isHandlingCompletion) {
          if (kDebugMode) {
            print('Near end detected (${remaining.inMilliseconds}ms remaining), preparing for next track...');
          }
          // Start preparing next track if not already done
          if (_currentIndex < _playlist.length - 1) {
            _preloadNextTracks();
          }
        }
        
        // 2. Very close to end (500ms remaining) - aggressive fallback
        if (remaining.inMilliseconds <= 500 && remaining.inMilliseconds >= 0 && !_isHandlingCompletion) {
          if (kDebugMode) {
            print('Very close to end detected (${remaining.inMilliseconds}ms remaining), checking for completion...');
          }
          
          // Schedule a check for completion after a short delay
          Future.delayed(const Duration(milliseconds: 200), () {
            final currentPosition = _player.position;
            final currentDuration = _player.duration;
            
            if (currentDuration != null && currentPosition.inMilliseconds >= currentDuration.inMilliseconds - 100) {
              // We're essentially at the end, force completion handling
              if (!_isHandlingCompletion) {
                if (kDebugMode) {
                  print('Forced completion handling - position: ${currentPosition.inMilliseconds}ms, duration: ${currentDuration.inMilliseconds}ms');
                }
                _handleTrackCompletion();
              }
            }
          });
        }
        
        // 3. Stuck at end detection - if position hasn't changed for too long while at the end
        if (remaining.inMilliseconds <= 50 && !_isHandlingCompletion) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            final stillAtEnd = _player.duration != null && 
                              (_player.duration!.inMilliseconds - _player.position.inMilliseconds) <= 50;
            
            if (stillAtEnd && !_isHandlingCompletion && _player.playerState.playing) {
              if (kDebugMode) {
                print('Detected stuck at end, forcing next track...');
              }
              _handleTrackCompletion();
            }
          });
        }
      }
    });

    // Start/stop periodic state saving based on playback state
    _player.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        _startPeriodicSaving();
        _startCompletionChecker(); // Start background completion checker
      } else {
        _stopPeriodicSaving();
        _stopCompletionChecker(); // Stop background completion checker
        _savePlaybackState(); // Save immediately when paused
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

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
      print('Manual skip to next requested. Current: $_currentIndex, Max: ${_playlist.length - 1}');
    }
    
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      
      if (kDebugMode) {
        print('Skipping to track ${_currentIndex + 1}/${_playlist.length}: ${_playlist[_currentIndex].name}');
      }
      
      await _playCurrentTrack();
      await _savePlaybackState();
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
    if (_isHandlingCompletion) {
      if (kDebugMode) {
        print('Already handling completion, skipping...');
      }
      return; // Prevent race conditions
    }
    
    _isHandlingCompletion = true;
    
    try {
      if (kDebugMode) {
        print('Handling track completion for: ${_currentTrack?.name}');
        print('Current index: $_currentIndex, Playlist length: ${_playlist.length}');
        print('Has next track: ${_currentIndex < _playlist.length - 1}');
      }
      
      // Check if we have a next track to play
      if (_currentIndex < _playlist.length - 1) {
        if (kDebugMode) {
          print('Moving to next track...');
        }
        
        // Advance to next track
        _currentIndex++;
        
        // Get the next track
        final nextTrack = _playlist[_currentIndex];
        
        if (kDebugMode) {
          print('Next track: ${nextTrack.name}');
        }
        
        // Update media item immediately for better background experience
        mediaItem.add(_trackToMediaItem(nextTrack));
        
        // Update playback state to show we're loading the next track
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.loading,
          queueIndex: _currentIndex,
        ));
        
        // Play the next track
        await _playCurrentTrack();
        
        // Save state after successful transition
        await _savePlaybackState();
        
        if (kDebugMode) {
          print('Successfully transitioned to next track: ${nextTrack.name}');
        }
      } else {
        if (kDebugMode) {
          print('Reached end of playlist, stopping playback');
        }
        
        // End of playlist - update state to show completion
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
          playing: false,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling track completion: $e');
      }
      
      // On error, try to recover by updating the playback state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
    } finally {
      _isHandlingCompletion = false;
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
      final restartThresholdMs = (duration.inMilliseconds * _restartThresholdPercentage).round();
      final minThresholdMs = Duration(seconds: 5).inMilliseconds;
      final thresholdMs = restartThresholdMs < minThresholdMs ? restartThresholdMs : minThresholdMs;
      
      if (currentPosition.inMilliseconds > thresholdMs) {
        // We're past the threshold, check if this is a double-tap within 5 seconds
        if (_lastSkipToPreviousTime != null && 
            now.difference(_lastSkipToPreviousTime!) < _skipToPreviousThreshold) {
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
    
    _lastSkipToPreviousTime = now;
    
    if (shouldRestartCurrentSong) {
      // Restart current song by seeking to beginning
      await _player.seek(Duration.zero);
      if (kDebugMode) {
        print('Restarting current song: ${_currentTrack?.name}');
      }
    } else {
      // Go to previous song (original behavior)
      if (_currentIndex > 0) {
        _currentIndex--;
        await _playCurrentTrack();
        await _savePlaybackState();
        if (kDebugMode) {
          print('Skipping to previous song');
        }
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await _playCurrentTrack();
      await _savePlaybackState();
    }
  }

  // Custom methods for the app
  Future<void> playTrack(Track track) async {
    _playlist = [track];
    _currentIndex = 0;
    await _playCurrentTrack();
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    // Clear existing preloaded tracks
    _clearPreloadedPlayers();
    
    _playlist = tracks;
    _queue = List.from(tracks);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    _isShuffled = false;
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    // Start playing current track and immediately start preloading
    await _playCurrentTrack();
    
    // Save the new playlist state
    await _savePlaybackState();
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
    if (_playlist.isEmpty || _currentIndex >= _playlist.length) {
      if (kDebugMode) {
        print('Cannot play current track: playlist empty or index out of bounds');
      }
      return;
    }

    final track = _playlist[_currentIndex];
    _currentTrack = track;
    
    if (kDebugMode) {
      print('Playing track ${_currentIndex + 1}/${_playlist.length}: ${track.name}');
    }
    
    // Update current media item immediately for better background experience
    mediaItem.add(_trackToMediaItem(track));
    
    // Update playback state to loading
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: _currentIndex,
    ));
    
    // Stop current player first to ensure clean state
    try {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 50)); // Reduced delay for faster transitions
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping player: $e');
      }
    }
    
    // Check if we have a preloaded player for this track
    if (_preloadedPlayers.containsKey(track.id)) {
      final preloadedPlayer = _preloadedPlayers.remove(track.id);
      if (preloadedPlayer != null) {
        try {
          // Check if the preloaded player is ready
          if (preloadedPlayer.audioSource != null && 
              preloadedPlayer.processingState == ProcessingState.ready) {
            
            // Set the same audio source on main player
            await _player.setAudioSource(preloadedPlayer.audioSource!);
            
            // Update state to ready before playing
            playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.ready,
              playing: false,
              queueIndex: _currentIndex,
            ));
            
            await _player.play();
            
            if (kDebugMode) {
              print('Successfully playing preloaded track: ${track.name}');
            }
            
            // Dispose the preloaded player
            preloadedPlayer.dispose();
            
            // Preload next tracks after successful play
            _preloadNextTracks();
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
    }
    
    // Fallback to normal loading if no preloaded version or if preloaded failed
    await _loadAndPlayTrack(track);
    
    // Preload next tracks after successful play
    _preloadNextTracks();
  }

  Future<void> _loadAndPlayTrack(Track track) async {
    // Try multiple stream URLs in order of preference
    final streamUrls = [
      _jellyfinService.getStreamUrl(track.id),
      _jellyfinService.getDirectStreamUrl(track.id),
      _jellyfinService.getUniversalStreamUrl(track.id),
    ];
    
    bool loadedSuccessfully = false;
    
    for (int i = 0; i < streamUrls.length; i++) {
      final streamUrl = streamUrls[i];
      final streamType = ['stream', 'direct', 'universal'][i];
      
      try {
        if (kDebugMode) {
          print('Loading track: ${track.name} using $streamType URL');
        }
        
        // Load the audio source
        await _player.setUrl(streamUrl);
        
        // Apply volume normalization if enabled
        _player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
        
        // Wait for the player to be ready before playing
        int retries = 0;
        const maxRetries = 50; // 2.5 seconds total
        while (_player.processingState == ProcessingState.loading && retries < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 50));
          retries++;
        }
        
        // Check if loading was successful
        if (_player.processingState == ProcessingState.ready) {
          // Update state to ready before playing
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: false,
            queueIndex: _currentIndex,
          ));
          
          // Ensure the track is still the current one before playing
          if (_currentTrack?.id == track.id) {
            await _player.play();
            loadedSuccessfully = true;
            
            if (kDebugMode) {
              print('Successfully started playing: ${track.name} using $streamType URL');
            }
            break; // Success! Exit the loop
          } else {
            if (kDebugMode) {
              print('Track changed during loading, cancelling play for: ${track.name}');
            }
            break;
          }
        } else {
          if (kDebugMode) {
            print('Failed to load ${track.name} with $streamType URL - player state: ${_player.processingState}');
          }
        }
        
      } catch (e) {
        if (kDebugMode) {
          print('Failed to play with $streamType URL: $e');
        }
      }
    }
    
    if (!loadedSuccessfully) {
      if (kDebugMode) {
        print('All stream URLs failed for track: ${track.name}');
      }
      
      // Update playback state to indicate error
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
    }
  }

  void _preloadNextTracks() async {
    // Always preload next tracks for instant playback, regardless of crossfade setting
    
    // Clean up old preloaded players first
    _cleanupOldPreloadedPlayers();
    
    // Preload next few tracks in the queue (limit to 3 for better performance)
    const preloadCount = 3;
    for (int i = 1; i <= preloadCount; i++) {
      final nextIndex = _currentIndex + i;
      if (nextIndex < _playlist.length) {
        final track = _playlist[nextIndex];
        _preloadTrack(track);
      }
    }
  }

  void _preloadTrack(Track track) async {
    // Don't preload if already preloaded or currently preloading
    if (_preloadedPlayers.containsKey(track.id) || _preloadingTracks.contains(track.id)) {
      return;
    }
    
    _preloadingTracks.add(track.id);
    
    try {
      final player = AudioPlayer();
      
      // Try multiple stream URLs in order of preference
      final streamUrls = [
        _jellyfinService.getStreamUrl(track.id),
        _jellyfinService.getDirectStreamUrl(track.id),
        _jellyfinService.getUniversalStreamUrl(track.id),
      ];
      
      bool loaded = false;
      for (final streamUrl in streamUrls) {
        try {
          // Set URL and wait for it to be ready
          await player.setUrl(streamUrl);
          
          // Apply volume normalization if enabled
          player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
          
          // Wait for the player to be in ready state with a timeout
          final completer = Completer<void>();
          StreamSubscription? subscription;
          
          subscription = player.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.ready) {
              subscription?.cancel();
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          });
          
          // Wait up to 5 seconds for the track to be ready
          await completer.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              subscription?.cancel();
              throw TimeoutException('Track preloading timed out', const Duration(seconds: 5));
            },
          );
          
          // Successfully preloaded
          _preloadedPlayers[track.id] = player;
          loaded = true;
          
          if (kDebugMode) {
            print('Successfully preloaded track: ${track.name}');
          }
          break;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to preload track ${track.name}: $e');
          }
        }
      }
      
      if (!loaded) {
        player.dispose();
        if (kDebugMode) {
          print('Could not preload track: ${track.name}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading track ${track.name}: $e');
      }
    } finally {
      _preloadingTracks.remove(track.id);
    }
  }

  void _clearPreloadedPlayers() {
    for (final player in _preloadedPlayers.values) {
      player.dispose();
    }
    _preloadedPlayers.clear();
    _preloadingTracks.clear();
    
    if (kDebugMode) {
      print('Cleared all preloaded players');
    }
  }

  void _cleanupOldPreloadedPlayers() {
    final currentTrackId = _currentTrack?.id;
    final upcomingTrackIds = <String>{};
    
    // Collect IDs of upcoming tracks (next 3 tracks)
    const preloadCount = 3;
    for (int i = 1; i <= preloadCount; i++) {
      final nextIndex = _currentIndex + i;
      if (nextIndex < _playlist.length) {
        upcomingTrackIds.add(_playlist[nextIndex].id);
      }
    }
    
    // Remove preloaded players that are no longer needed
    final keysToRemove = <String>[];
    for (final trackId in _preloadedPlayers.keys) {
      if (trackId != currentTrackId && !upcomingTrackIds.contains(trackId)) {
        keysToRemove.add(trackId);
      }
    }
    
    for (final trackId in keysToRemove) {
      final player = _preloadedPlayers.remove(trackId);
      player?.dispose();
      if (kDebugMode) {
        print('Cleaned up preloaded player for track: $trackId');
      }
    }
  }

  void addToQueue(Track track) {
    _queue.add(track);
    _playlist.add(track);
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    // Always trigger preloading if this track is within preload range
    if (_playlist.length - _currentIndex <= 4) { // Preload if within next 3 tracks
      _preloadTrack(track);
    }
  }

  void addNext(Track track) {
    // Insert the track right after the current track
    final insertIndex = _currentIndex + 1;
    
    _queue.insert(insertIndex, track);
    _playlist.insert(insertIndex, track);
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    // Preload this track since it will play next
    _preloadTrack(track);
    
    if (kDebugMode) {
      print('Added track to play next: ${track.name} at position $insertIndex');
    }
  }

  void shuffle() {
    if (_playlist.length <= 1) return;
    
    // Clear preloaded players since order will change
    _clearPreloadedPlayers();
    
    _isShuffled = true;
    final currentTrack = _playlist[_currentIndex];
    
    // Remove current track from shuffling
    final remainingTracks = List<Track>.from(_playlist);
    remainingTracks.removeAt(_currentIndex);
    
    // Shuffle remaining tracks
    remainingTracks.shuffle();
    
    // Create new playlist with current track first, then shuffled tracks
    _playlist = [currentTrack, ...remainingTracks];
    _queue = List.from(_playlist);
    _currentIndex = 0;
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    // Restart preloading with new order
    _preloadNextTracks();
  }

  void unshuffle() {
    // Since we don't store the original playlist, we'll just disable shuffle mode
    _isShuffled = false;
    
    if (kDebugMode) {
      print('Unshuffle called - shuffle mode disabled');
    }
  }

  void clearQueue() {
    _playlist.clear();
    _queue.clear();
    _currentIndex = 0;
    _currentTrack = null;
    _isShuffled = false;
    
    // Clear preloaded players
    _clearPreloadedPlayers();
    
    // Update audio service
    queue.add(<MediaItem>[]);
    mediaItem.add(null);
    
    stop();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length || index == _currentIndex) return;
    
    _queue.removeAt(index);
    _playlist.removeAt(index);
    
    // Adjust current index if needed
    if (index < _currentIndex) {
      _currentIndex--;
    }
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    // Clean up preloaded players
    _cleanupOldPreloadedPlayers();
  }

  void setSmartCrossfade(bool enabled) {
    _smartCrossfadeEnabled = enabled;
    
    if (enabled) {
      // Enable crossfade with 3-second duration
      // Apply volume based on normalization setting
      _player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
      
      // Start preloading next tracks
      _preloadNextTracks();
      
      if (kDebugMode) {
        print('Smart crossfade enabled with ${_crossfadeDuration.inSeconds}s duration');
      }
    } else {
      // Disable crossfade and clear preloaded tracks
      _clearPreloadedPlayers();
      
      if (kDebugMode) {
        print('Smart crossfade disabled');
      }
    }
  }

  void setNormalizeVolume(bool enabled) {
    _normalizeVolumeEnabled = enabled;
    
    // Apply volume normalization
    _player.setVolume(enabled ? 0.8 : 1.0);
    
    if (kDebugMode) {
      print('Volume normalization ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  // Getters
  Track? get currentTrack => _currentTrack;
  List<Track> get playlist => _playlist;
  List<Track> get queueTracks => _queue;
  List<Track> get upNext => _currentIndex < _queue.length - 1 
      ? _queue.sublist(_currentIndex + 1) 
      : [];
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  bool get isShuffled => _isShuffled;
  int get queueLength => _queue.length;
  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;
  bool get normalizeVolumeEnabled => _normalizeVolumeEnabled;
  
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

  Future<void> _savePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save current playlist
      if (_playlist.isNotEmpty) {
        final playlistJson = _playlist.map((track) => track.toJson()).toList();
        await prefs.setString('current_playlist', jsonEncode(playlistJson));
        await prefs.setInt('current_index', _currentIndex);
        await prefs.setBool('is_shuffled', _isShuffled);
        
        // Save current position and playing state
        final position = _player.position.inMilliseconds;
        await prefs.setInt('playback_position', position);
        await prefs.setBool('was_playing', _player.playing);
        
        if (_currentTrack != null) {
          await prefs.setString('current_track_id', _currentTrack!.id);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving playback state: $e');
      }
    }
  }

  Future<void> _loadPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final playlistString = prefs.getString('current_playlist');
      if (playlistString != null) {
        final playlistJson = jsonDecode(playlistString) as List;
        _playlist = playlistJson.map((json) => Track.fromJson(json)).toList();
        _queue = List.from(_playlist);
        
        _currentIndex = prefs.getInt('current_index') ?? 0;
        _isShuffled = prefs.getBool('is_shuffled') ?? false;
        final wasPlaying = prefs.getBool('was_playing') ?? false;
        
        if (_playlist.isNotEmpty && _currentIndex < _playlist.length) {
          _currentTrack = _playlist[_currentIndex];
          
          // Update audio service queue
          queue.add(_playlist.map(_trackToMediaItem).toList());
          
          // Update current media item
          mediaItem.add(_trackToMediaItem(_currentTrack!));
          
          // Prepare the audio source
          try {
            final streamUrls = [
              _jellyfinService.getStreamUrl(_currentTrack!.id),
              _jellyfinService.getDirectStreamUrl(_currentTrack!.id),
              _jellyfinService.getUniversalStreamUrl(_currentTrack!.id),
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
              final savedPosition = prefs.getInt('playback_position') ?? 0;
              if (savedPosition > 0) {
                await _player.seek(Duration(milliseconds: savedPosition));
              }
              
              // Resume playing if it was playing before
              if (wasPlaying) {
                await _player.play();
                _startPeriodicSaving(); // Start saving state if we resumed playing
                if (kDebugMode) {
                  print('Automatically resumed playback: ${_currentTrack!.name}');
                }
              }
              
              // Update playback state
              playbackState.add(playbackState.value.copyWith(
                controls: [
                  MediaControl.skipToPrevious,
                  wasPlaying ? MediaControl.pause : MediaControl.play,
                  MediaControl.skipToNext,
                ],
                systemActions: const {
                  MediaAction.seek,
                  MediaAction.seekForward,
                  MediaAction.seekBackward,
                },
                androidCompactActionIndices: const [0, 1, 2],
                processingState: AudioProcessingState.ready,
                playing: wasPlaying,
                updatePosition: Duration(milliseconds: savedPosition),
                queueIndex: _currentIndex,
              ));
              
              if (kDebugMode) {
                print('Successfully restored playback state: ${_currentTrack!.name}');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error preparing restored track: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading playback state: $e');
      }
    }
  }

  void _startPeriodicSaving() {
    _stopPeriodicSaving(); // Clear any existing timer
    _saveStateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _savePlaybackState();
    });
  }

  void _stopPeriodicSaving() {
    _saveStateTimer?.cancel();
    _saveStateTimer = null;
  }

  void _startCompletionChecker() {
    _stopCompletionChecker(); // Clear any existing timer
    _completionCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkForCompletion();
    });
  }

  void _stopCompletionChecker() {
    _completionCheckTimer?.cancel();
    _completionCheckTimer = null;
  }

  void _checkForCompletion() {
    final duration = _player.duration;
    final position = _player.position;
    final isPlaying = _player.playing;
    
    if (duration != null && isPlaying && !_isHandlingCompletion) {
      final remaining = duration - position;
      
      // If we're stuck at the very end (less than 100ms remaining) and still playing
      if (remaining.inMilliseconds <= 100 && remaining.inMilliseconds >= 0) {
        if (kDebugMode) {
          print('Background completion checker detected end of track: ${_currentTrack?.name}');
          print('Position: ${position.inMilliseconds}ms, Duration: ${duration.inMilliseconds}ms, Remaining: ${remaining.inMilliseconds}ms');
        }
        _handleTrackCompletion();
      }
    }
  }

  void dispose() {
    _stopPeriodicSaving();
    _stopCompletionChecker();
    _savePlaybackState();
    _clearPreloadedPlayers();
    _player.dispose();
  }
}
