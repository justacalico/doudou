import 'dart:async';
import 'dart:io';
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
  bool _gaplessPlaybackEnabled = true; // Default to enabled for better UX
  bool _radioModeEnabled = false; // Radio mode for endless playback
  final Duration _crossfadeDuration = const Duration(seconds: 3);
  
  // Preloading and caching
  final Map<String, AudioPlayer> _preloadedPlayers = {};
  final Set<String> _preloadingTracks = {};
  
  // Completion tracking to prevent race conditions
  bool _isHandlingCompletion = false;
  
  // Background completion detection helpers
  Duration? _lastKnownPosition;
  int _stuckCounter = 0;
  
  // Skip-to-previous behavior tracking
  DateTime? _lastSkipToPreviousTime;
  static const Duration _skipToPreviousThreshold = Duration(seconds: 5);
  static const double _restartThresholdPercentage = 0.20; // 20% of song duration
  
  // Periodic state saving
  Timer? _saveStateTimer;
  
  // Background completion checker as fallback
  Timer? _completionCheckTimer;

  DoudouAudioHandler(this._jellyfinService, this._downloadService) {
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

    // Auto-play next track when current track completes - enhanced for background playback
    _player.playerStateStream.listen((state) {
      // Primary completion detection through player state
      if (state.processingState == ProcessingState.completed && !_isHandlingCompletion) {
        if (kDebugMode) {
          print('Track completion detected via playerStateStream, handling...');
        }
        // Use a small delay to allow any ongoing gapless transitions to complete
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isHandlingCompletion) {
            _handleTrackCompletion();
          }
        });
      }
      
      // Enhanced background-friendly completion detection for locked screen
      if (!_isHandlingCompletion && state.playing) {
        final duration = _player.duration;
        final position = _player.position;
        
        if (duration != null && duration.inMilliseconds > 0) {
          final remaining = duration - position;
          final progressPercentage = position.inMilliseconds / duration.inMilliseconds;
          
          // Critical: Aggressive completion detection for background mode
          // This is essential for locked screen playback continuity  
          if (progressPercentage >= 0.97 || remaining.inMilliseconds <= 800) {
            // Multiple checks with delays to handle Android's background throttling
            Future.delayed(const Duration(milliseconds: 100), () {
              final currentDuration = _player.duration;
              final currentPosition = _player.position;
              final currentState = _player.playerState;
              
              if (currentDuration != null && 
                  currentPosition.inMilliseconds >= currentDuration.inMilliseconds - 300 &&
                  !_isHandlingCompletion && 
                  currentState.playing) {
                if (kDebugMode) {
                  print('Background state stream completion triggered at ${(currentPosition.inMilliseconds / currentDuration.inMilliseconds * 100).toStringAsFixed(1)}%');
                }
                _handleTrackCompletion();
              }
            });
          }
        }
      }
    });

    // Enhanced position stream listener for reliable background track progression
    _player.positionStream.listen((position) {
      final duration = _player.duration;
      final playerState = _player.playerState;
      
      // Always update the last known position for stuck detection
      _lastKnownPosition = position;
      
      if (duration != null && duration.inMilliseconds > 0 && playerState.playing) {
        final remaining = duration - position;
        final progressPercentage = position.inMilliseconds / duration.inMilliseconds;
        
        // Multiple fallback mechanisms for background playback
        
        // 1. Near end detection for gapless preparation
        if (_gaplessPlaybackEnabled && remaining.inMilliseconds <= 2000 && remaining.inMilliseconds > 1000 && !_isHandlingCompletion) {
          if (kDebugMode) {
            print('Gapless preparation: ${remaining.inMilliseconds}ms remaining, ensuring next track is preloaded...');
          }
          // Ensure next track is preloaded for gapless transition
          if (_currentIndex < _playlist.length - 1) {
            final nextTrack = _playlist[_currentIndex + 1];
            if (!_preloadedPlayers.containsKey(nextTrack.id) && !_preloadingTracks.contains(nextTrack.id)) {
              _preloadTrack(nextTrack);
            }
          }
        }
        
        // 2. Near end detection (1 second remaining)
        if (remaining.inMilliseconds <= 1000 && remaining.inMilliseconds > 500 && !_isHandlingCompletion) {
          if (kDebugMode) {
            print('Near end detected (${remaining.inMilliseconds}ms remaining), preparing for next track...');
          }
          // Start preparing next track if not already done
          if (_currentIndex < _playlist.length - 1) {
            _preloadNextTracks();
          }
        }
        
        // 3. Very close to end (500ms remaining) - trigger gapless transition if enabled
        if (remaining.inMilliseconds <= 500 && remaining.inMilliseconds > 100 && !_isHandlingCompletion) {
          if (_gaplessPlaybackEnabled && _currentIndex < _playlist.length - 1) {
            final nextTrack = _playlist[_currentIndex + 1];
            if (_preloadedPlayers.containsKey(nextTrack.id)) {
              if (kDebugMode) {
                print('Initiating gapless transition with ${remaining.inMilliseconds}ms remaining');
              }
              _handleTrackCompletion();
              return;
            }
          }
          
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
        
        // 4. Final fallback - stuck at end detection (more aggressive for background)
        if (remaining.inMilliseconds <= 200 && !_isHandlingCompletion) {
          Future.delayed(const Duration(milliseconds: 300), () {
            final stillAtEnd = _player.duration != null && 
                              (_player.duration!.inMilliseconds - _player.position.inMilliseconds) <= 300;
            
            if (stillAtEnd && !_isHandlingCompletion && _player.playerState.playing) {
              if (kDebugMode) {
                print('Detected stuck at end, forcing next track...');
              }
              _handleTrackCompletion();
            }
          });
        }
        
        // 5. Progressive completion detection for background mode (more aggressive)
        if (progressPercentage >= 0.975 && !_isHandlingCompletion) {
          // Use a more aggressive approach for background playback
          Future.delayed(const Duration(milliseconds: 200), () {
            final currentProgress = _player.position.inMilliseconds / (_player.duration?.inMilliseconds ?? 1);
            if (currentProgress >= 0.98 && !_isHandlingCompletion) {
              if (kDebugMode) {
                print('Background progressive completion: ${(currentProgress * 100).toStringAsFixed(2)}%');
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
      
      // Reset stuck detection counters
      _stuckCounter = 0;
      _lastKnownPosition = null;
      
      // Store current track info for verification
      final currentTrackName = _currentTrack?.name;
      final currentIndex = _currentIndex;
      
      // Check if we have a next track to play
      if (_currentIndex < _playlist.length - 1) {
        if (kDebugMode) {
          print('Moving to next track...');
        }
        
        final nextTrack = _playlist[_currentIndex + 1];
        
        // Use gapless transition if enabled and preloaded player is available
        if (_gaplessPlaybackEnabled && _preloadedPlayers.containsKey(nextTrack.id)) {
          if (kDebugMode) {
            print('Using gapless transition to: ${nextTrack.name}');
          }
          await _performGaplessTransition(nextTrack);
          
          // After gapless transition, verify we actually moved to the next track
          if (_currentIndex == currentIndex || _currentTrack?.name == currentTrackName) {
            if (kDebugMode) {
              print('ERROR: Gapless transition failed to advance track, forcing manual advance');
            }
            // Force advance to prevent getting stuck
            _currentIndex++;
            _currentTrack = nextTrack;
          }
        } else {
          // Regular transition - more robust for background playback
          _currentIndex++;
          
          if (kDebugMode) {
            print('Next track: ${nextTrack.name}');
          }
          
          // Update media item immediately for better background experience
          mediaItem.add(_trackToMediaItem(nextTrack));
          
          // Update playback state to show we're loading the next track
          // Preserve the current playing state to prevent pausing
          final wasPlaying = playbackState.value.playing;
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.loading,
            queueIndex: _currentIndex,
            playing: wasPlaying, // Maintain the current playing state
          ));
          
          // Play the next track with enhanced error handling for background mode
          try {
            await _playCurrentTrack();
            
            // Enhanced verification for background playback - wait longer and check multiple times
            // Also ensure we maintain the playing state throughout the transition
            final shouldBePlaying = playbackState.value.playing;
            for (int i = 0; i < 5; i++) {
              await Future.delayed(const Duration(milliseconds: 200));
              if (_player.playing) {
                break; // Successfully playing
              }
              
              if (i == 4) {
                // Final attempt - force play if we should be playing
                if (kDebugMode) {
                  print('Playback did not start after multiple attempts, forcing play...');
                }
                try {
                  if (shouldBePlaying) {
                    await _player.play();
                  }
                } catch (playError) {
                  if (kDebugMode) {
                    print('Force play failed: $playError');
                  }
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error during track transition, attempting recovery: $e');
            }
            // Attempt recovery by reloading the track
            try {
              await _loadAndPlayTrack(nextTrack);
              // Ensure it starts playing
              await Future.delayed(const Duration(milliseconds: 300));
              if (!_player.playing) {
                await _player.play();
              }
            } catch (recoveryError) {
              if (kDebugMode) {
                print('Recovery attempt failed: $recoveryError');
              }
            }
          }
          
          // Save state after successful transition
          await _savePlaybackState();
          
          if (kDebugMode) {
            print('Successfully transitioned to next track: ${nextTrack.name}');
          }
        }
      } else {
        // End of playlist reached
        if (_radioModeEnabled && _currentTrack != null) {
          if (kDebugMode) {
            print('Reached end of playlist, adding radio tracks...');
          }
          
          // Get similar tracks for radio mode
          final similarTracks = await _getSimilarTracks(_currentTrack!, limit: 15);
          
          if (similarTracks.isNotEmpty) {
            // Add similar tracks to the playlist
            _playlist.addAll(similarTracks);
            _queue.addAll(similarTracks);
            
            // Update audio service queue
            queue.add(_playlist.map(_trackToMediaItem).toList());
            
            // Move to the next track (first radio track)
            _currentIndex++;
            final nextTrack = _playlist[_currentIndex];
            
            if (kDebugMode) {
              print('Radio mode: Added ${similarTracks.length} tracks, now playing: ${nextTrack.name}');
            }
            
            // Update media item
            mediaItem.add(_trackToMediaItem(nextTrack));
            
            // Update playback state to loading
            playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.loading,
              queueIndex: _currentIndex,
              playing: true,
            ));
            
            // Play the radio track
            try {
              await _playCurrentTrack();
              
              // Verify playback started
              for (int i = 0; i < 5; i++) {
                await Future.delayed(const Duration(milliseconds: 200));
                if (_player.playing) {
                  break; // Successfully playing
                }
                
                if (i == 4) {
                  // Final attempt - force play
                  if (kDebugMode) {
                    print('Radio playback did not start, forcing play...');
                  }
                  try {
                    await _player.play();
                  } catch (playError) {
                    if (kDebugMode) {
                      print('Force play failed: $playError');
                    }
                  }
                }
              }
              
              // Save state after successful radio transition
              await _savePlaybackState();
              
              if (kDebugMode) {
                print('Successfully started radio mode with track: ${nextTrack.name}');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error playing radio track, stopping: $e');
              }
              
              // If radio track fails to play, stop playback
              playbackState.add(playbackState.value.copyWith(
                processingState: AudioProcessingState.completed,
                playing: false,
              ));
            }
          } else {
            if (kDebugMode) {
              print('No similar tracks found for radio mode, stopping playback');
            }
            
            // No similar tracks available, stop playback
            playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.completed,
              playing: false,
            ));
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
    // Check if track is downloaded locally first
    final localFilePath = _downloadService.getLocalFilePath(track.id);
    
    if (localFilePath != null) {
      // Verify that the local file exists before trying to play it
      final localFile = File(localFilePath);
      if (await localFile.exists()) {
        // Play local file
        if (kDebugMode) {
          print('Playing local file for track: ${track.name} from $localFilePath');
        }
        
        try {
          // Load the local file
          await _player.setFilePath(localFilePath);
        
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
            
            if (kDebugMode) {
              print('Successfully started playing local file: ${track.name}');
            }
            return; // Success! Exit early
          } else {
            if (kDebugMode) {
              print('Track changed during loading, cancelling play for: ${track.name}');
            }
            return;
          }
        } else {
          if (kDebugMode) {
            print('Failed to load local file for ${track.name} - player state: ${_player.processingState}');
          }
        }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to play local file for ${track.name}: $e');
          }
        }
      } else {
        if (kDebugMode) {
          print('Local file does not exist: $localFilePath');
        }
      }
      
      // If local file failed, fall back to streaming
      if (kDebugMode) {
        print('Local file playback failed for ${track.name}, falling back to streaming');
      }
    }
    
    // Stream from server (original logic)
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
    // Only preload if gapless playback is enabled or for general performance
    
    // Clean up old preloaded players first
    _cleanupOldPreloadedPlayers();
    
    // Preload next few tracks in the queue for instant playback
    final preloadCount = _gaplessPlaybackEnabled ? 2 : 1; // More aggressive preloading for gapless
    for (int i = 1; i <= preloadCount; i++) {
      final nextIndex = _currentIndex + i;
      if (nextIndex < _playlist.length) {
        final track = _playlist[nextIndex];
        if (!_preloadedPlayers.containsKey(track.id) && !_preloadingTracks.contains(track.id)) {
          _preloadTrack(track);
        }
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
      
      // Check if track is downloaded locally first
      final localFilePath = _downloadService.getLocalFilePath(track.id);
      
      bool loaded = false;
      
      if (localFilePath != null) {
        // Verify that the local file exists before trying to preload it
        final localFile = File(localFilePath);
        if (await localFile.exists()) {
          // Preload local file
          try {
            if (kDebugMode) {
              print('Preloading local file for track: ${track.name}');
            }
            
            // Set local file path and wait for it to be ready
            await player.setFilePath(localFilePath);
          
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
              throw TimeoutException('Local track preloading timed out', const Duration(seconds: 5));
            },
          );
          
          // Successfully preloaded
          _preloadedPlayers[track.id] = player;
          loaded = true;
          
          if (kDebugMode) {
            print('Successfully preloaded local track: ${track.name}');
          }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to preload local track ${track.name}: $e');
            }
            // Fall back to streaming
          }
        } else {
          if (kDebugMode) {
            print('Local file does not exist for preloading: $localFilePath');
          }
        }
      }
      
      if (!loaded) {
        // Fall back to streaming (original logic)
        // Try multiple stream URLs in order of preference
        final streamUrls = [
          _jellyfinService.getStreamUrl(track.id),
          _jellyfinService.getDirectStreamUrl(track.id),
          _jellyfinService.getUniversalStreamUrl(track.id),
        ];
        
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

  // Radio Mode functionality for endless playback
  void toggleRadioMode() {
    _radioModeEnabled = !_radioModeEnabled;
    
    if (kDebugMode) {
      print('Radio mode ${_radioModeEnabled ? 'enabled' : 'disabled'}');
    }
  }

  void enableRadioMode() {
    _radioModeEnabled = true;
    
    if (kDebugMode) {
      print('Radio mode enabled');
    }
  }

  void disableRadioMode() {
    _radioModeEnabled = false;
    
    if (kDebugMode) {
      print('Radio mode disabled');
    }
  }

  // Get similar tracks for radio mode based on current track
  Future<List<Track>> _getSimilarTracks(Track currentTrack, {int limit = 10}) async {
    try {
      // Get all tracks from the service
      final allTracks = await _jellyfinService.getAllTracks();
      
      // Filter out tracks we've already played recently (last 20 tracks)
      final recentTrackIds = _playlist.take(20).map((t) => t.id).toSet();
      final availableTracks = allTracks.where((track) => 
        track.id != currentTrack.id && !recentTrackIds.contains(track.id)
      ).toList();

      // Priority matching: same artist tracks first
      final sameArtistTracks = availableTracks.where((track) => 
        track.artistName == currentTrack.artistName && track.artistName != null
      ).toList();

      // Secondary matching: same album tracks
      final sameAlbumTracks = availableTracks.where((track) => 
        track.artistName != currentTrack.artistName &&
        track.albumName == currentTrack.albumName && track.albumName != null
      ).toList();

      // Tertiary matching: tracks from same album ID
      final similarTracks = availableTracks.where((track) => 
        track.artistName != currentTrack.artistName &&
        track.albumName != currentTrack.albumName &&
        track.albumId == currentTrack.albumId && track.albumId != null
      ).toList();

      // Shuffle each category to avoid predictable ordering
      sameArtistTracks.shuffle();
      sameAlbumTracks.shuffle();
      similarTracks.shuffle();

      // Combine results with weighted selection
      final result = <Track>[];
      
      // Add up to 50% same artist tracks
      final sameArtistCount = (limit * 0.5).round();
      result.addAll(sameArtistTracks.take(sameArtistCount));
      
      // Add up to 30% same album tracks
      final sameAlbumCount = ((limit - result.length) * 0.6).round();
      result.addAll(sameAlbumTracks.take(sameAlbumCount));
      
      // Fill remaining with similar tracks
      final remainingCount = limit - result.length;
      result.addAll(similarTracks.take(remainingCount));

      // If we still don't have enough, add random tracks
      if (result.length < limit) {
        final remainingAvailable = availableTracks.where((track) => 
          !result.any((r) => r.id == track.id)
        ).toList();
        remainingAvailable.shuffle();
        result.addAll(remainingAvailable.take(limit - result.length));
      }

      if (kDebugMode) {
        print('Generated ${result.length} similar tracks for radio mode');
        print('Same artist: ${sameArtistTracks.length}, Same album: ${sameAlbumTracks.length}, Similar: ${similarTracks.length}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting similar tracks for radio mode: $e');
      }
      return [];
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

  void setGaplessPlayback(bool enabled) {
    _gaplessPlaybackEnabled = enabled;
    if (kDebugMode) {
      print('Gapless playback ${enabled ? 'enabled' : 'disabled'}');
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
  bool get radioModeEnabled => _radioModeEnabled;
  int get queueLength => _queue.length;
  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;
  bool get normalizeVolumeEnabled => _normalizeVolumeEnabled;
  bool get gaplessPlaybackEnabled => _gaplessPlaybackEnabled;
  
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
        await prefs.setBool('radio_mode_enabled', _radioModeEnabled);
        
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
        _radioModeEnabled = prefs.getBool('radio_mode_enabled') ?? false;
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
    // Use a more frequent check for better background responsiveness
    // Check more frequently when near the end of a track for reliable background playback
    _completionCheckTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
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
    final playerState = _player.playerState;
    final isPlaying = playerState.playing;
    final processingState = playerState.processingState;
    
    // CRITICAL: Don't check for completion if we're already handling it or during transitions
    if (duration != null && isPlaying && !_isHandlingCompletion && duration.inMilliseconds > 0) {
      final remaining = duration - position;
      final progressPercentage = position.inMilliseconds / duration.inMilliseconds;
      
      // Enhanced completion detection for background playback
      bool shouldTriggerCompletion = false;
      
      // 1. Traditional end detection (less than 200ms remaining for better background handling)
      if (remaining.inMilliseconds <= 200 && remaining.inMilliseconds >= 0) {
        shouldTriggerCompletion = true;
        if (kDebugMode) {
          print('Background completion: Traditional end detection (${remaining.inMilliseconds}ms remaining)');
        }
      }
      
      // 2. Completion state detection (critical for background playback)
      else if (processingState == ProcessingState.completed) {
        shouldTriggerCompletion = true;
        if (kDebugMode) {
          print('Background completion: Processing state completed');
        }
      }
      
      // 3. More aggressive progress-based detection for background mode
      else if (progressPercentage >= 0.98) { // 98% complete for more reliable background detection
        shouldTriggerCompletion = true;
        if (kDebugMode) {
          print('Background progressive completion: ${(progressPercentage * 100).toStringAsFixed(2)}%');
        }
      }
      
      // 4. Stuck detection - if position hasn't advanced near the end (made more sensitive)
      else if (remaining.inMilliseconds <= 1500 && _lastKnownPosition != null) {
        final positionDiff = position.inMilliseconds - _lastKnownPosition!.inMilliseconds;
        if (positionDiff <= 100) { // Position advanced less than 100ms in 300ms check
          _stuckCounter++;
          if (_stuckCounter >= 3) { // Stuck for 900ms (more reliable)
            shouldTriggerCompletion = true;
            if (kDebugMode) {
              print('Background completion: Stuck detection (position not advancing)');
            }
          }
        } else {
          _stuckCounter = 0;
        }
      } else {
        _stuckCounter = 0;
      }
      
      _lastKnownPosition = position;
      
      // Double-check: Make sure we're still on the same track before triggering completion
      if (shouldTriggerCompletion && _currentTrack != null) {
        if (kDebugMode) {
          print('Background completion checker detected end of track: ${_currentTrack?.name}');
          print('Position: ${position.inMilliseconds}ms, Duration: ${duration.inMilliseconds}ms');
          print('Remaining: ${remaining.inMilliseconds}ms, Progress: ${(progressPercentage * 100).toStringAsFixed(2)}%');
          print('Processing State: $processingState');
        }
        
        // Use a short delay to prevent race conditions with any ongoing transitions
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!_isHandlingCompletion) { // Double-check before executing
            _handleTrackCompletion();
          }
        });
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
  
  Future<void> _performGaplessTransition(Track nextTrack) async {
    try {
      if (kDebugMode) {
        print('Performing gapless transition to: ${nextTrack.name}');
      }
      
      // CRITICAL: Temporarily disable completion checking during transition
      _isHandlingCompletion = true;
      
      // Get the preloaded player for the next track
      final preloadedPlayer = _preloadedPlayers[nextTrack.id];
      
      if (preloadedPlayer != null && preloadedPlayer.processingState == ProcessingState.ready) {
        // Store the current player for proper disposal
        final oldPlayer = _player;
        
        // Update current track and index immediately for responsive UI
        _currentIndex++;
        _currentTrack = nextTrack;
        
        // Update media item and state immediately
        mediaItem.add(_trackToMediaItem(nextTrack));
        
        // Transfer the preloaded audio source to the main player
        try {
          final audioSource = preloadedPlayer.audioSource;
          if (audioSource != null) {
            // Set the preloaded audio source on main player
            await _player.setAudioSource(audioSource);
            
            // Apply volume normalization if enabled
            _player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
            
            // Start playback immediately for seamless transition
            await _player.play();
            
            // Update playback state to playing
            playbackState.add(playbackState.value.copyWith(
              playing: true,
              processingState: AudioProcessingState.ready,
              queueIndex: _currentIndex,
            ));
            
            if (kDebugMode) {
              print('Gapless transition completed successfully using preloaded source');
            }
          } else {
            throw Exception('Preloaded player has no audio source');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to transfer preloaded source, reloading: $e');
          }
          
          // Fallback: reload the track normally
          await _loadAndPlayTrack(nextTrack);
        }
        
        // Clean up the preloaded player
        _preloadedPlayers.remove(nextTrack.id);
        await preloadedPlayer.dispose();
        
        // Stop the old player after successful transition
        try {
          await oldPlayer.stop();
        } catch (e) {
          if (kDebugMode) {
            print('Error stopping old player: $e');
          }
        }
      } else {
        if (kDebugMode) {
          print('No ready preloaded player found, performing regular transition');
        }
        
        // Update index and track info
        _currentIndex++;
        _currentTrack = nextTrack;
        
        // Update media item
        mediaItem.add(_trackToMediaItem(nextTrack));
        
        // Load and play the track normally
        await _loadAndPlayTrack(nextTrack);
      }
      
      // Wait a moment for the new track to fully initialize before re-enabling completion checking
      await Future.delayed(const Duration(seconds: 2));
      
      // Re-enable completion checking AFTER the transition is complete
      _isHandlingCompletion = false;
      
      // Start preloading next tracks for future gapless transitions
      _preloadNextTracks();
      
      // Save state
      await _savePlaybackState();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error in gapless transition: $e');
      }
      // Fallback to regular skip on any error
      await skipToNext();
    }
  }
}
