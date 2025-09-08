import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';
import '../download_service.dart';

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
  final Set<String> _preloadingTracks = {}; // Tracks currently being preloaded
  final Set<String> _bufferedTracks = {}; // Tracks with buffered content
  
  // Completion tracking to prevent race conditions
  bool _isHandlingCompletion = false;
  
  // Background completion detection helpers
  Duration? _lastKnownPosition;
  int _stuckCounter = 0;
  
  // Skip-to-previous behavior tracking
  DateTime? _lastSkipToPreviousTime;
  static const Duration _skipToPreviousThreshold = Duration(seconds: 5);
  static const double _restartThresholdPercentage = 0.20; // 20% of song duration
  
  // Pause tracking to prevent aggressive auto-play after manual pause
  DateTime? _lastPauseTime;
  
  // Periodic state saving
  Timer? _saveStateTimer;
  
  // Background completion checker as fallback
  Timer? _completionCheckTimer;

  DoudouAudioHandler(this._jellyfinService, this._downloadService) {
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
        queueIndex: _currentIndex,
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
      if (state == ProcessingState.completed && !_isHandlingCompletion) {
        if (kDebugMode) {
          print('Track completed, moving to next');
        }
        _handleTrackCompletion();
      }
    });

    // Start/stop periodic state saving based on playback state
    _player.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        _startPeriodicSaving();
      } else {
        _stopPeriodicSaving();
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
        print('Current playing state: ${playbackState.value.playing}');
        print('Player playing state: ${_player.playing}');
        print('Gapless playback enabled: $_gaplessPlaybackEnabled');
      }
      
      // Reset stuck detection counters
      _stuckCounter = 0;
      _lastKnownPosition = null;
      
      // Store current track info for verification
      final currentTrackName = _currentTrack?.name;
      final currentIndex = _currentIndex;
      
      // Preserve current playing state through the transition - CRITICAL
      final wasPlaying = playbackState.value.playing || _player.playing;
      
      // Check if we have a next track to play
      if (_currentIndex < _playlist.length - 1) {
        if (kDebugMode) {
          print('Moving to next track... (was playing: $wasPlaying)');
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
            print('Next track: ${nextTrack.name} (gapless disabled or no preloaded player)');
          }
          
          // Update media item immediately for better background experience
          mediaItem.add(_trackToMediaItem(nextTrack));
          
          // Update playback state to show we're loading the next track
          // Preserve the current playing state to prevent pausing
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.loading,
            queueIndex: _currentIndex,
            playing: wasPlaying, // Maintain the current playing state
          ));
          
          // Play the next track with enhanced error handling for background mode
          try {
            await _playCurrentTrack();
            
            // Make absolutely sure we're in the expected playing state after transition
            if (wasPlaying && !_player.playing) {
              if (kDebugMode) {
                print('Transition complete but not playing when it should be. Forcing playback...');
              }
              
              // Try multiple times to start playback in case of player state inconsistency
              for (int i = 0; i < 5; i++) {
                try {
                  await _player.play();
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (_player.playing) {
                    if (kDebugMode) {
                      print('Post-transition playback started on attempt ${i+1}');
                    }
                    break;
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Post-transition play attempt ${i+1} failed: $e');
                  }
                }
              }
              
              // Force state consistency as last resort
              if (!_player.playing) {
                if (kDebugMode) {
                  print('CRITICAL: All post-transition play attempts failed. Forcing state consistency.');
                }
                playbackState.add(playbackState.value.copyWith(
                  playing: true, // Force the state to match expectations
                ));
                // One final attempt
                _player.play().catchError((e) => {
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print('Final post-transition play attempt error: $e')
                  }
                });
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error during track transition, attempting recovery: $e');
            }
            // Attempt recovery by reloading the track
            try {
              await _loadAndPlayTrack(nextTrack);
              // Ensure it starts playing if it should be playing
              await Future.delayed(const Duration(milliseconds: 300));
              if (wasPlaying && !_player.playing) {
                if (kDebugMode) {
                  print('Recovery: Track should be playing but isn\'t, forcing play...');
                }
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
            print('Final playing state - should be: $wasPlaying, actually: ${_player.playing}');
          }
          
          // Final verification after regular transition
          if (wasPlaying && !_player.playing) {
            if (kDebugMode) {
              print('Regular transition: Final check - forcing play to maintain state...');
            }
            try {
              await _player.play();
            } catch (e) {
              if (kDebugMode) {
                print('Regular transition: Final play failed: $e');
              }
            }
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
            
            // Update playback state to loading, maintaining the playing state
            final shouldBePlaying = playbackState.value.playing;
            playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.loading,
              queueIndex: _currentIndex,
              playing: shouldBePlaying, // Maintain the current playing state
            ));
            
            // Play the radio track
            try {
              await _playCurrentTrack();
              
              // Verify playback started and maintain playing state
              for (int i = 0; i < 5; i++) {
                await Future.delayed(const Duration(milliseconds: 200));
                if (_player.playing) {
                  break; // Successfully playing
                }
                
                if (i == 4) {
                  // Final attempt - force play only if we should be playing
                  if (kDebugMode) {
                    print('Radio playback did not start, forcing play...');
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
    // Stop any currently playing audio first
    try {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 100)); // Allow stop to complete
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping player during single track play: $e');
      }
    }
    
    // Clear existing preloaded tracks
    _clearPreloadedPlayers();
    
    // Reset completion handling state
    _isHandlingCompletion = false;
    
    _playlist = [track];
    _currentIndex = 0;
    
    if (kDebugMode) {
      print('Playing single track: ${track.name}');
    }
    
    // Set state to playing since this is explicitly starting a single track
    // This is CRITICAL - the system needs to know we intend to play
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: 0,
    ));
    
    try {
      await _playCurrentTrack();
      
      // For single tracks, still preload similar tracks for better UX
      if (_playlist.length == 1) {
        Future.microtask(() async {
          try {
            final similarTracks = await _getSimilarTracks(track, limit: 3);
            if (similarTracks.isNotEmpty && kDebugMode) {
              if (kDebugMode) {
                print('Preloading ${similarTracks.length} similar tracks for better UX');
              }
              for (final similarTrack in similarTracks) {
                _preloadTrackAggressive(similarTrack, 10); // Low priority
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to preload similar tracks: $e');
            }
          }
        });
      }
      
      // CRITICAL: Verify that playback actually started
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (playbackState.value.playing && !_player.playing) {
        if (kDebugMode) {
          print('Single track started but not playing - forcing playback to start...');
        }
        
        // Retry playback multiple times if needed
        for (int i = 0; i < 5; i++) {
          try {
            await _player.play();
            await Future.delayed(const Duration(milliseconds: 200));
            
            if (_player.playing) {
              if (kDebugMode) {
                print('Successfully started single track playback on attempt ${i + 1}');
              }
              break;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Single track auto-play attempt ${i + 1} failed: $e');
            }
          }
        }
        
        // Final state check
        if (!_player.playing) {
          if (kDebugMode) {
            print('All single track auto-play attempts failed, but maintaining playing state');
          }
        }
      }
      
      if (kDebugMode) {
        print('Single track initialization complete. Playing: ${_player.playing}, State playing: ${playbackState.value.playing}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error during single track play: $e');
      }
      
      // Maintain playing state for consistency
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: true, // Keep this true so UI shows expected state
      ));
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    // Stop any currently playing audio and clear loading state
    try {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 100)); // Allow stop to complete
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping player during playlist initialization: $e');
      }
    }
    
    // Clear existing preloaded tracks
    _clearPreloadedPlayers();
    
    // Reset completion handling state
    _isHandlingCompletion = false;
    
    _playlist = tracks;
    _queue = List.from(tracks);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    _isShuffled = false;
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    if (kDebugMode) {
      print('Starting new playlist: ${tracks.length} tracks, starting at index $startIndex');
    }
    
    // Set state to playing since this is explicitly starting a new playlist
    // This is CRITICAL - the system needs to know we intend to play
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: _currentIndex,
    ));
    
    // Start playing current track with enhanced auto-play and aggressive buffering
    try {
      await _playCurrentTrack();
      
      // Immediately start aggressive preloading without waiting
      Future.microtask(() => _preloadNextTracks());
      
      // CRITICAL: Verify that playback actually started
      // Wait a bit for the track to load and then force play if needed
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (playbackState.value.playing && !_player.playing) {
        if (kDebugMode) {
          print('Playlist started but not playing - forcing playback to start...');
        }
        
        // Retry playback multiple times if needed
        for (int i = 0; i < 5; i++) {
          try {
            await _player.play();
            await Future.delayed(const Duration(milliseconds: 200));
            
            if (_player.playing) {
              if (kDebugMode) {
                print('Successfully started playlist playback on attempt ${i + 1}');
              }
              break;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Playlist auto-play attempt ${i + 1} failed: $e');
            }
          }
        }
        
        // Final state check and force consistency
        if (!_player.playing) {
          if (kDebugMode) {
            print('All playlist auto-play attempts failed, but maintaining playing state for user experience');
          }
          // Keep the playing state true so UI shows the right state
          // and user can manually trigger play if needed
        }
      }
      
      if (kDebugMode) {
        print('Playlist initialization complete. Playing: ${_player.playing}, State playing: ${playbackState.value.playing}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error during playlist initialization: $e');
      }
      
      // Even if there's an error, maintain the playing state for consistency
      // User can retry by tapping play if needed
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: true, // Keep this true so UI shows expected state
      ));
    }
    
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
    
    // Store the current playing state to maintain it through the transition
    final wasPlaying = playbackState.value.playing;
    
    // Update playback state to loading while preserving playing state
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: _currentIndex,
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
    if (_preloadedPlayers.containsKey(track.id)) {
      final preloadedPlayer = _preloadedPlayers.remove(track.id);
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
              queueIndex: _currentIndex,
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
    // Store the current playing state to maintain it through the loading process
    final wasPlaying = playbackState.value.playing;
    
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
          
          // Don't wait for ready state - let just_audio handle buffering
          if (wasPlaying) {
            _player.play(); // Don't await this - let it play when ready
          }
          
          if (kDebugMode) {
            print('Successfully loaded local file: ${track.name}');
          }
          return; // Success! Exit early
        } catch (e) {
          if (kDebugMode) {
            print('Failed to play local file for ${track.name}: $e');
          }
        }
      }
    }
    
    // Fast streaming - try best URL first, only one fallback
    await _loadAndPlayTrackFast(track, wasPlaying);
  }

  Future<void> _loadAndPlayTrackFast(Track track, bool wasPlaying) async {
    if (kDebugMode) {
      print('Ultra-fast loading track: ${track.name}');
    }
    
    // Get both URLs immediately for parallel testing
    final primaryUrl = _jellyfinService.getStreamUrl(track.id);
    final fallbackUrl = _jellyfinService.getDirectStreamUrl(track.id);
    
    // Try fallback URL first since primary is failing with 500 errors
    // This is a temporary optimization based on current server behavior
    try {
      if (kDebugMode) {
        print('Trying direct stream URL first (optimized): ${track.name}');
      }
      
      // Load direct stream URL immediately
      await _player.setUrl(fallbackUrl);
      
      // Apply volume normalization if enabled
      _player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
      
      // Start playing immediately without waiting - let buffering happen in background
      if (wasPlaying) {
        _player.play(); // Don't await - start immediately
        _bufferedTracks.add(track.id); // Mark as buffered
      }
      
      if (kDebugMode) {
        print('✓ Successfully loaded with direct stream URL: ${track.name}');
      }
      
      return; // Success - exit early
      
    } catch (e) {
      if (kDebugMode) {
        print('Direct stream failed, trying primary URL for: ${track.name}');
      }
      
      // Fallback to primary URL if direct stream fails
      try {
        await _player.setUrl(primaryUrl);
        
        // Apply volume normalization if enabled
        _player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
        
        if (wasPlaying) {
          _player.play(); // Don't await - start immediately
          _bufferedTracks.add(track.id); // Mark as buffered
        }
        
        if (kDebugMode) {
          print('✓ Successfully loaded with primary URL: ${track.name}');
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('✗ All URLs failed for track: ${track.name}');
          print('Direct stream error: $e');
          print('Primary URL error: $fallbackError');
        }
        
        // Set error state
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ));
      }
    }
  }

  void _preloadNextTracks() async {
    // Aggressive preloading for instant playback
    _cleanupOldPreloadedPlayers();
    
    // Always preload next 3 tracks for instant switching
    const preloadCount = 3; // Increased from 2/1 to always preload 3
    
    if (kDebugMode) {
      print('Starting aggressive preloading of next $preloadCount tracks...');
    }
    
    for (int i = 1; i <= preloadCount; i++) {
      final nextIndex = _currentIndex + i;
      if (nextIndex < _playlist.length) {
        final track = _playlist[nextIndex];
        if (!_preloadedPlayers.containsKey(track.id) && !_preloadingTracks.contains(track.id)) {
          // Start preloading immediately without waiting
          _preloadTrackAggressive(track, i);
        }
      }
    }
    
    // Also preload the previous track for instant skip-back
    if (_currentIndex > 0) {
      final prevTrack = _playlist[_currentIndex - 1];
      if (!_preloadedPlayers.containsKey(prevTrack.id) && !_preloadingTracks.contains(prevTrack.id)) {
        _preloadTrackAggressive(prevTrack, 0);
      }
    }
  }

  void _preloadTrackAggressive(Track track, int priority) async {
    // Don't preload if already preloaded or currently preloading
    if (_preloadedPlayers.containsKey(track.id) || _preloadingTracks.contains(track.id)) {
      return;
    }
    
    _preloadingTracks.add(track.id);
    
    if (kDebugMode) {
      print('Aggressively preloading track (priority $priority): ${track.name}');
    }
    
    try {
      final player = AudioPlayer();
      
      // Check if track is downloaded locally first
      final localFilePath = _downloadService.getLocalFilePath(track.id);
      
      bool loaded = false;
      
      if (localFilePath != null) {
        final localFile = File(localFilePath);
        if (await localFile.exists()) {
          try {
            await player.setFilePath(localFilePath);
            player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
            
            // For local files, wait briefly to ensure they're ready
            await Future.delayed(const Duration(milliseconds: 100));
            
            _preloadedPlayers[track.id] = player;
            _bufferedTracks.add(track.id);
            loaded = true;
            
            if (kDebugMode) {
              print('✓ Aggressively preloaded local track: ${track.name}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to aggressively preload local track ${track.name}: $e');
            }
          }
        }
      }
      
      if (!loaded) {
        // Stream preloading - use optimized URL selection
        final fallbackUrl = _jellyfinService.getDirectStreamUrl(track.id);
        final primaryUrl = _jellyfinService.getStreamUrl(track.id);
        
        // Try direct stream first (optimized based on server behavior)
        try {
          await player.setUrl(fallbackUrl);
          player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
          
          // Don't wait for full buffer - just start the buffering process
          _preloadedPlayers[track.id] = player;
          _bufferedTracks.add(track.id);
          loaded = true;
          
          if (kDebugMode) {
            print('✓ Started aggressive buffering (direct): ${track.name}');
          }
          
          // Let it buffer in the background without waiting
          player.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.ready) {
              if (kDebugMode) {
                print('✓ Background buffering complete for: ${track.name}');
              }
            }
          });
          
        } catch (e) {
          // Fallback to primary URL
          try {
            await player.setUrl(primaryUrl);
            player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
            
            _preloadedPlayers[track.id] = player;
            _bufferedTracks.add(track.id);
            loaded = true;
            
            if (kDebugMode) {
              print('✓ Started aggressive buffering (primary): ${track.name}');
            }
            
            player.playerStateStream.listen((state) {
              if (state.processingState == ProcessingState.ready) {
                if (kDebugMode) {
                  print('✓ Background buffering complete for: ${track.name}');
                }
              }
            });
            
          } catch (primaryError) {
            if (kDebugMode) {
              print('Failed to start aggressive buffering for ${track.name}: direct=$e, primary=$primaryError');
            }
            loaded = false;
          }
        }
      }
      
      if (!loaded) {
        player.dispose();
        if (kDebugMode) {
          print('✗ Could not aggressively preload track: ${track.name}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in aggressive preloading for ${track.name}: $e');
      }
    } finally {
      _preloadingTracks.remove(track.id);
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
        // Optimized streaming - try direct stream first
        final fallbackUrl = _jellyfinService.getDirectStreamUrl(track.id);
        final primaryUrl = _jellyfinService.getStreamUrl(track.id);
        
        // Try direct stream first (optimized based on server behavior)
        try {
          // Set URL and wait for it to be ready
          await player.setUrl(fallbackUrl);
          
          // Apply volume normalization if enabled
          player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
          
          if (kDebugMode) {
            print('Regular preload using direct URL: ${track.name}');
          }
          
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
            print('Successfully preloaded track (direct): ${track.name}');
          }
          
        } catch (e) {
          // Fallback to primary URL
          try {
            await player.setUrl(primaryUrl);
            player.setVolume(_normalizeVolumeEnabled ? 0.8 : 1.0);
            
            if (kDebugMode) {
              print('Regular preload using primary URL: ${track.name}');
            }
            
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
              print('Successfully preloaded track (primary): ${track.name}');
            }
            
          } catch (primaryError) {
            if (kDebugMode) {
              print('Failed to preload track ${track.name}: direct=$e, primary=$primaryError');
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
    if (kDebugMode) {
      print('Clearing all ${_preloadedPlayers.length} preloaded players');
    }
    
    for (final player in _preloadedPlayers.values) {
      player.dispose();
    }
    _preloadedPlayers.clear();
    _preloadingTracks.clear();
    _bufferedTracks.clear();
    
    if (kDebugMode) {
      print('Cleared all preloaded players and buffers');
    }
  }

  void _cleanupOldPreloadedPlayers() {
    final currentTrackId = _currentTrack?.id;
    final upcomingTrackIds = <String>{};
    
    // Collect IDs of upcoming tracks (next 3 tracks + previous track)
    const preloadCount = 3;
    
    // Add next tracks
    for (int i = 1; i <= preloadCount; i++) {
      final nextIndex = _currentIndex + i;
      if (nextIndex < _playlist.length) {
        upcomingTrackIds.add(_playlist[nextIndex].id);
      }
    }
    
    // Add previous track for instant skip-back
    if (_currentIndex > 0) {
      upcomingTrackIds.add(_playlist[_currentIndex - 1].id);
    }
    
    // Remove preloaded players that are no longer needed
    final keysToRemove = <String>[];
    for (final trackId in _preloadedPlayers.keys) {
      if (trackId != currentTrackId && !upcomingTrackIds.contains(trackId)) {
        keysToRemove.add(trackId);
      }
    }
    
    if (keysToRemove.isNotEmpty && kDebugMode) {
      if (kDebugMode) {
        print('Cleaning up ${keysToRemove.length} old preloaded tracks');
      }
    }
    
    for (final trackId in keysToRemove) {
      final player = _preloadedPlayers.remove(trackId);
      player?.dispose();
      _bufferedTracks.remove(trackId);
      if (kDebugMode) {
        print('Cleaned up preloaded player for track: $trackId');
      }
    }
    
    if (kDebugMode) {
      print('Currently buffered: ${_preloadedPlayers.length} tracks, Buffering: ${_preloadingTracks.length} tracks');
    }
  }

  void addToQueue(Track track) {
    _queue.add(track);
    _playlist.add(track);
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    // Always preload tracks that are added - they're likely to be played soon
    final position = _playlist.length - _currentIndex - 1; // Position from current track
    if (position <= 5) { // If within next 5 tracks, preload immediately
      if (kDebugMode) {
        print('Immediately preloading newly added track: ${track.name}');
      }
      _preloadTrackAggressive(track, position);
    }
  }

  void addNext(Track track) {
    // Insert the track right after the current track
    final insertIndex = _currentIndex + 1;
    
    _queue.insert(insertIndex, track);
    _playlist.insert(insertIndex, track);
    
    // Update audio service queue
    queue.add(_playlist.map(_trackToMediaItem).toList());
    
    // This track will play next - preload it immediately with highest priority
    if (kDebugMode) {
      print('Immediately preloading "play next" track: ${track.name}');
    }
    _preloadTrackAggressive(track, 1); // Highest priority
    
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

  // Transcoding support methods
  bool _shouldTranscodeTrack(Track track) {
    // Determine if track needs transcoding based on codec or other factors
    // For now, transcoding can be enabled for better compatibility
    return true; // Enable transcoding for all tracks for maximum compatibility
  }

  String _getHlsStreamUrl(Track track) {
    // Use the existing stream URL method as a base and modify it for HLS
    final streamUrl = _jellyfinService.getStreamUrl(track.id);
    if (streamUrl.isEmpty) return '';
    
    // Replace 'stream' with 'main.m3u8' and add HLS-specific parameters
    final baseUrl = streamUrl.split('/Audio/')[0];
    return '$baseUrl/Audio/${track.id}/main.m3u8?ApiKey=${_jellyfinService.getStreamUrl(track.id).split('api_key=')[1].split('&')[0]}&audioCodec=aac&audioSampleRate=44100&maxAudioBitDepth=16&audioBitRate=320000';
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
      
      // Store the current playing state before starting transition
      final wasPlaying = playbackState.value.playing || _player.playing;
      
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
            
            // Start playback only if we were playing before (for seamless transition)
            if (wasPlaying) {
              await _player.play();
              
              // Verify that playback actually started
              for (int i = 0; i < 12; i++) {
                await Future.delayed(const Duration(milliseconds: 75));
                if (_player.playing) {
                  if (kDebugMode && i > 0) {
                    if (kDebugMode) {
                      print('Gapless transition: Playback started after $i retries');
                    }
                  }
                  break; // Successfully playing
                }
                
                // Not playing yet, retry with shorter intervals
                if (i < 11) {
                  try {
                    if (kDebugMode) {
                      print('Gapless transition: Playback attempt ${i+1} failed, retrying...');
                    }
                    await _player.play();
                  } catch (playError) {
                    if (kDebugMode) {
                      print('Gapless transition: Play retry ${i+1} failed: $playError');
                    }
                  }
                }
              }
            }
            
            // Update playback state maintaining the previous playing state
            playbackState.add(playbackState.value.copyWith(
              playing: wasPlaying, // Maintain the previous playing state
              processingState: AudioProcessingState.ready,
              queueIndex: _currentIndex,
            ));
            
            if (kDebugMode) {
              print('Gapless transition completed - was playing: $wasPlaying, actual: ${_player.playing}');
              
              // Force state consistency as last resort
              if (wasPlaying && !_player.playing) {
                print('CRITICAL: Gapless transition inconsistency - forcing play state');
                playbackState.add(playbackState.value.copyWith(
                  playing: true, // Force the state to match expectations
                ));
                // One final attempt
                _player.play().catchError((e) => {
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print('Final gapless play attempt error: $e')
                  }
                });
              }
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
          
          // Double check playing state after fallback
          if (wasPlaying && !_player.playing) {
            if (kDebugMode) {
              print('Gapless fallback not playing when it should be, forcing play...');
            }
            await _player.play();
          }
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
        
        // Double check playing state after regular transition
        if (wasPlaying && !_player.playing) {
          if (kDebugMode) {
            print('Regular transition not playing when it should be, forcing play...');
          }
          await _player.play();
        }
      }
      
      // Wait a moment for the new track to fully initialize before re-enabling completion checking
      await Future.delayed(const Duration(milliseconds: 500)); // Reduced from 1 second
      
      // Final verification: ensure the track is playing if it should be
      if (wasPlaying && !_player.playing) {
        if (kDebugMode) {
          print('Gapless transition: Final check - track should be playing but isn\'t, forcing play...');
        }
        try {
          for (int i = 0; i < 3; i++) {
            await _player.play();
            await Future.delayed(const Duration(milliseconds: 100));
            if (_player.playing) break;
          }
          
          if (kDebugMode) {
            print('Gapless transition: Final play attempt result: ${_player.playing}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Gapless transition: Final play attempt failed: $e');
          }
        }
      }
      
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
