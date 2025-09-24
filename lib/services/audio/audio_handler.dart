import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';
import '../download_service.dart';
import '../touchbar_service.dart';
import 'audio_state_manager.dart';
import 'audio_preloader.dart';
import 'audio_queue_manager.dart';
import 'audio_radio_mode.dart';
import 'audio_state_persistence.dart';
import 'audio_transition_manager.dart';

class DoudouAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  final DownloadService _downloadService;
  
  // Touch Bar service for macOS
  TouchBarService? _touchBarService;
  
  // Component managers
  late final AudioStateManager _stateManager;
  late final AudioPreloader _preloader;
  late final AudioQueueManager _queueManager;
  late final AudioRadioMode _radioMode;
  late final AudioStatePersistence _statePersistence;
  late final AudioTransitionManager _transitionManager;

  // Media browsing data for Android Auto
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Track> _tracks = [];
  List<Playlist> _playlists = [];

  // Gapless playback with ConcatenatingAudioSource
  ConcatenatingAudioSource? _concatenatingSource;
  bool _isUsingConcatenation = false;
  final Map<String, AudioSource> _audioSourceCache = {};

  // User intent tracking to prevent buffering pauses
  bool _userIntendedPlaying = false;

  // Command throttling to prevent conflicts
  DateTime? _lastPlayCommand;
  DateTime? _lastPauseCommand;
  static const Duration _commandThrottleDelay = Duration(milliseconds: 500);

  // Codec loop detection
  DateTime? _lastBufferingTime;
  int _bufferingLoopCount = 0;
  
  // Helper method to update playback state while preventing automatic buffering pauses
  void _updatePlaybackState(PlaybackState newState) {
    PlaybackState finalState = newState;
    
    // If we're buffering but user intended to play, override the playing state
    if (newState.processingState == AudioProcessingState.buffering && _userIntendedPlaying) {
      // Force playing state to true during buffering if user intended to play
      finalState = newState.copyWith(playing: true);
      
      if (kDebugMode) {
        print('Buffering detected but maintaining playback (user intended playing)');
      }
    }
    // If we're trying to set buffering state while currently playing, maintain playback
    else if (newState.processingState == AudioProcessingState.buffering && 
        playbackState.value.playing && 
        playbackState.value.processingState == AudioProcessingState.ready) {
      
      // Keep current state but show buffering processing state
      finalState = newState.copyWith(
        playing: _userIntendedPlaying, // Use user intent instead of current state
      );
      
      if (kDebugMode) {
        print('Network buffering - maintaining user intended playback state');
      }
    }
    
    playbackState.add(finalState);
    
    if (kDebugMode) {
      print('Updated playback state - Playing: ${finalState.playing}, Processing: ${finalState.processingState}');
    }
  }

  DoudouAudioHandler(this._jellyfinService, this._downloadService) {
    _stateManager = AudioStateManager();
    _preloader = AudioPreloader(_jellyfinService, _downloadService);
    _queueManager = AudioQueueManager(_stateManager);
    _radioMode = AudioRadioMode(_jellyfinService);
    _statePersistence = AudioStatePersistence(_stateManager);
    _transitionManager = AudioTransitionManager();
    
    // Initialize Touch Bar service on macOS
    if (Platform.isMacOS) {
      _touchBarService = TouchBarService();
      _initializeTouchBar();
    }
    
    // Initialize iOS audio session FIRST before any other audio setup
    _initializeAudioSession();
    
    _init();
    _loadPlaybackState();
  }

  void _init() {
    // Enhanced player state listener for background compatibility with buffering fix
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = _mapProcessingState(playerState.processingState);
      
      // Determine final playing state based on user intent and current state
      // IMPORTANT: Respect user intent over raw player state
      bool finalPlayingState;
      
      // If user explicitly paused, respect that regardless of player state
      if (!_userIntendedPlaying) {
        finalPlayingState = false;
        if (kDebugMode && isPlaying) {
          if (kDebugMode) {
            print('Player wants to play but user paused - respecting user intent');
          }
        }
      }
      // During buffering, use user intent to maintain playback
      else if (processingState == AudioProcessingState.buffering && _userIntendedPlaying) {
        finalPlayingState = true;
        if (kDebugMode) {
          print('Player buffering but user intended playing - maintaining playback state');
        }
      }
      // Otherwise use actual player state
      else {
        finalPlayingState = isPlaying;
      }
      
      // Always update playback state to keep system informed
      final newPlaybackState = playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (finalPlayingState) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: finalPlayingState,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _stateManager.currentIndex,
      );
      
      _updatePlaybackState(newPlaybackState);
    });

    // Listen to current index changes for gapless transitions
    _player.currentIndexStream.listen((index) {
      if (index != null && _isUsingConcatenation) {
        if (kDebugMode) {
          print('Gapless transition to index: $index');
        }
        
        // Update state manager without stopping playback
        _stateManager.setCurrentIndex(index);
        
        // Update media item
        if (index < _stateManager.playlist.length) {
          final track = _stateManager.playlist[index];
          mediaItem.add(_trackToMediaItem(track));
          
          // Trigger preloading of upcoming tracks
          Future.microtask(() {
            _preloader.preloadNextTracks(_stateManager.playlist, index);
          });
        }
        
        // Update playback state with new index
        _updatePlaybackState(playbackState.value.copyWith(
          queueIndex: index,
        ));
      }
    });

    // Enhanced position stream for background tracking
    _player.positionStream.listen((position) {
      // Only update position if not currently buffering to avoid conflicts
      if (_player.processingState != ProcessingState.buffering) {
        _updatePlaybackState(playbackState.value.copyWith(
          updatePosition: position,
        ));
      }
    });

    // Simplified completion detection - only handle actual completion
    _player.processingStateStream.listen((state) {
      if (kDebugMode) {
        print('Processing state changed: $state');
      }
      
      // Handle codec loops only in extreme cases - MUCH less aggressive
      if (state == ProcessingState.buffering) {
        final now = DateTime.now();
        if (_lastBufferingTime != null && 
            now.difference(_lastBufferingTime!) < const Duration(seconds: 5)) {
          _bufferingLoopCount++;
          // Dramatically increased threshold to prevent false positives - was 5, now 15
          if (_bufferingLoopCount >= 15) {
            if (kDebugMode) {
              print('Detected extreme codec loop in buffering state after 15 attempts, forcing recovery');
            }
            _handleCodecLoop();
            return;
          }
        } else {
          _bufferingLoopCount = 0;
        }
        _lastBufferingTime = now;
      } else {
        // Reset loop detection on state changes
        _bufferingLoopCount = 0;
        _lastBufferingTime = null;
      }
      
      // ONLY handle actual completion state - no forced completion
      if (state == ProcessingState.completed) {
        if (kDebugMode) {
          print('Track actually completed, handling transition...');
        }
        _handleTrackCompletion();
      }
    });

    // Monitor playback for state persistence only
    _player.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        // Only start periodic saving if not already started
        if (!_statePersistence.isPeriodicSavingActive) {
          _statePersistence.startPeriodicSaving(_player.position, playerState.playing);
          if (kDebugMode) {
            print('Started periodic saving (was not running)');
          }
        }
      } else {
        _statePersistence.stopPeriodicSaving();
        _statePersistence.savePlaybackState(_player.position, playerState.playing);
        if (kDebugMode) {
          print('Stopped playback - saved state');
        }
      }
    });

    // Set initial playback state with proper volume
    _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
    
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

  /// Initialize iOS audio session for proper background audio and interruption handling
  Future<void> _initializeAudioSession() async {
    try {
      // Get the audio session instance
      final audioSession = await AudioSession.instance;
      
      // Configure for music playback with proper iOS settings
      await audioSession.configure(const AudioSessionConfiguration.music());
      
      if (kDebugMode) {
        print('iOS Audio session configured for music playback');
      }
      
      // Listen for audio interruptions (phone calls, notifications, etc.)
      audioSession.interruptionEventStream.listen((event) {
        if (kDebugMode) {
          print('Audio interruption: ${event.type}');
        }
        
        if (event.type == AudioInterruptionType.pause) {
          // Audio was interrupted (e.g., phone call)
          if (_player.playing) {
            _userIntendedPlaying = true; // Remember user wanted to play
            pause();
            if (kDebugMode) {
              print('Audio interrupted - paused playback');
            }
          }
        } else if (event.type == AudioInterruptionType.duck) {
          // Lower volume but continue playing
          if (kDebugMode) {
            print('Audio ducking - lowering volume');
          }
        } else if (event.type == AudioInterruptionType.unknown) {
          // Handle unknown interruption
          if (_player.playing && _userIntendedPlaying) {
            Future.delayed(const Duration(milliseconds: 500), () {
              play();
              if (kDebugMode) {
                print('Audio interruption ended - resuming playback');
              }
            });
          }
        }
      });
      
      // Listen for "becoming noisy" events (headphones disconnected)
      audioSession.becomingNoisyEventStream.listen((_) {
        if (_player.playing) {
          _userIntendedPlaying = false; // User didn't explicitly pause, but we should stop
          pause();
          if (kDebugMode) {
            print('Audio becoming noisy (headphones disconnected) - paused playback');
          }
        }
      });
      
      // Handle iOS device gain changes (volume changes from control center, etc.)
      audioSession.devicesChangedEventStream.listen((event) {
        if (kDebugMode) {
          print('Audio devices changed: ${event.devicesAdded.length} added, ${event.devicesRemoved.length} removed');
        }
        
        // If headphones were removed and we're playing, pause
        if (event.devicesRemoved.isNotEmpty && _player.playing) {
          final removedDevices = event.devicesRemoved
              .where((device) => device.type == AudioDeviceType.bluetoothA2dp || 
                               device.type == AudioDeviceType.wiredHeadphones ||
                               device.type == AudioDeviceType.wiredHeadset)
              .toList();
          
          if (removedDevices.isNotEmpty) {
            _userIntendedPlaying = false;
            pause();
            if (kDebugMode) {
              print('Audio output device removed - paused playback');
            }
          }
        }
      });
      
      // Activate the audio session
      await audioSession.setActive(true);
      
      if (kDebugMode) {
        print('iOS Audio session activated successfully');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize iOS audio session: $e');
      }
      // Continue without iOS audio session - fallback for Android
    }
  }

  Future<void> _handleCodecLoop() async {
    // Don't interfere with transitions or other recovery processes
    if (_stateManager.isHandlingCompletion || _transitionManager.isTransitionInProgress) {
      return;
    }
    
    if (kDebugMode) {
      print('Handling codec loop by reloading track: ${_stateManager.currentTrack?.name}');
    }
    
    try {
      final currentTrack = _stateManager.currentTrack;
      if (currentTrack == null) return;
      
      final currentPosition = _player.position;
      
      // Simple stop and reload - no complex recovery logic
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Reload the track
      await _loadAndPlayTrack(currentTrack);
      
      // Restore position if significant
      if (currentPosition.inMilliseconds > 3000) {
        await _player.seek(currentPosition);
      }
      
      // Resume playing only if user intended to play
      if (_userIntendedPlaying) {
        await _player.play();
        if (kDebugMode) {
          print('Resumed playing after codec loop recovery - user intended playing');
        }
      } else {
        if (kDebugMode) {
          print('Not resuming after codec loop recovery - user paused');
        }
      }
      
      // Reset loop detection
      _bufferingLoopCount = 0;
      _lastBufferingTime = null;
      
      if (kDebugMode) {
        print('Codec loop recovery completed for: ${currentTrack.name}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to recover from codec loop: $e');
      }
    }
  }

  Future<void> _resumeCurrentTrack() async {
    if (_stateManager.currentTrack == null) return;
    
    final currentPosition = _player.position;
    
    try {
      await _loadAndPlayTrack(_stateManager.currentTrack!);
      
      // Restore position if we had one
      if (currentPosition.inMilliseconds > 0) {
        await _player.seek(currentPosition);
      }
      
      // Resume playing only if user intended to play  
      if (_userIntendedPlaying) {
        await _player.play();
        if (kDebugMode) {
          print('Resumed playing after background issue recovery - user intended playing');
        }
      } else {
        if (kDebugMode) {
          print('Not resuming after background issue recovery - user paused');
        }
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

  /// Create audio source for a track with caching
  Future<AudioSource?> _createAudioSource(Track track) async {
    // Check cache first
    if (_audioSourceCache.containsKey(track.id)) {
      if (kDebugMode) {
        print('Using cached audio source for: ${track.name}');
      }
      return _audioSourceCache[track.id]!;
    }

    try {
      // Try local file first
      final localFilePath = _downloadService.getLocalFilePath(track.id);
      if (localFilePath != null) {
        final localFile = File(localFilePath);
        if (await localFile.exists()) {
          final source = AudioSource.file(localFilePath);
          _audioSourceCache[track.id] = source;
          if (kDebugMode) {
            print('Created local file audio source for: ${track.name}');
          }
          return source;
        }
      }

      // Check preloaded audio source first (for gapless)
      final preloadedSource = _preloader.getPreloadedAudioSource(track.id);
      if (preloadedSource != null) {
        _audioSourceCache[track.id] = preloadedSource;
        if (kDebugMode) {
          print('Using preloaded audio source for: ${track.name}');
        }
        return preloadedSource;
      }

      // Check preloaded player (legacy)
      final preloadedPlayer = _preloader.getPreloadedPlayer(track.id);
      if (preloadedPlayer?.audioSource != null) {
        _audioSourceCache[track.id] = preloadedPlayer!.audioSource!;
        if (kDebugMode) {
          print('Using preloaded audio source for: ${track.name}');
        }
        return preloadedPlayer.audioSource!;
      }

      // Stream URLs fallback with platform-optimized prioritization
      List<String> streamUrls;
      if (Platform.isMacOS) {
        // macOS: Universal first, then transcoded, then direct
        streamUrls = [
          _jellyfinService.getUniversalStreamUrl(track.id),
          _jellyfinService.getStreamUrl(track.id),
          _jellyfinService.getDirectStreamUrl(track.id),
        ];
      } else {
        // Android/other: Direct first, then transcoded, then universal
        streamUrls = [
          _jellyfinService.getDirectStreamUrl(track.id),
          _jellyfinService.getStreamUrl(track.id),
          _jellyfinService.getUniversalStreamUrl(track.id),
        ];
      }

      for (final streamUrl in streamUrls) {
        if (streamUrl.isNotEmpty) {
          AudioSource source;
          
          if (_shouldTranscodeTrack(track)) {
            final hlsUrl = _getHlsStreamUrl(track);
            source = hlsUrl.isNotEmpty 
                ? HlsAudioSource(Uri.parse(hlsUrl))
                : AudioSource.uri(Uri.parse(streamUrl));
          } else {
            source = AudioSource.uri(Uri.parse(streamUrl));
          }
          
          _audioSourceCache[track.id] = source;
          if (kDebugMode) {
            print('Created stream audio source for: ${track.name}');
          }
          return source;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create audio source for ${track.name}: $e');
      }
    }

    return null;
  }

  /// Build concatenating audio source from playlist
  Future<ConcatenatingAudioSource?> _buildConcatenatingSource(List<Track> tracks) async {
    if (tracks.isEmpty) return null;

    final audioSources = <AudioSource>[];
    
    for (final track in tracks) {
      final audioSource = await _createAudioSource(track);
      if (audioSource != null) {
        audioSources.add(audioSource);
      } else {
        // If we can't create a source for a track, fall back to individual playback
        if (kDebugMode) {
          print('Failed to create audio source for concatenation: ${track.name}');
        }
        return null;
      }
    }

    if (audioSources.length == tracks.length) {
      return ConcatenatingAudioSource(children: audioSources);
    }

    return null;
  }

  /// Crossfade transition between tracks
  Future<void> _crossfadeToTrack(Track track) async {
    if (kDebugMode) {
      print('Starting crossfade transition to: ${track.name}');
    }

    try {
      // Create a secondary player for the new track
      final secondaryPlayer = AudioPlayer();
      
      // Load the new track on the secondary player
      final audioSource = await _createAudioSource(track);
      if (audioSource == null) {
        if (kDebugMode) {
          print('Failed to create audio source for crossfade, using direct transition');
        }
        await _loadAndPlayTrack(track);
        return;
      }

      await secondaryPlayer.setAudioSource(audioSource);
      
      // Start the crossfade
      final crossfadeDuration = _stateManager.crossfadeDuration;
      final steps = 20; // Number of volume steps
      final stepDuration = Duration(milliseconds: crossfadeDuration.inMilliseconds ~/ steps);
      
      // Start playing the new track at volume 0
      await secondaryPlayer.setVolume(0.0);
      await secondaryPlayer.play();
      
      // Gradually fade out old track and fade in new track
      for (int i = 0; i < steps; i++) {
        final progress = (i + 1) / steps;
        final oldVolume = (1.0 - progress) * (_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
        final newVolume = progress * (_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
        
        await _player.setVolume(oldVolume);
        await secondaryPlayer.setVolume(newVolume);
        
        await Future.delayed(stepDuration);
      }
      
      // Switch to the new player
      await _player.stop();
      await _player.setAudioSource(audioSource);
      await _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
      await _player.play();
      
      // Clean up secondary player
      await secondaryPlayer.dispose();
      
      // Update playback state
      _updatePlaybackState(playbackState.value.copyWith(
        processingState: AudioProcessingState.ready,
        playing: true,
        queueIndex: _stateManager.currentIndex,
      ));
      
      if (kDebugMode) {
        print('Crossfade transition completed for: ${track.name}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Crossfade failed, falling back to direct transition: $e');
      }
      await _loadAndPlayTrack(track);
    }
  }

  // Audio Service Methods - Enhanced for background compatibility
  @override
  @override
  Future<void> play() async {
    final now = DateTime.now();
    
    // Throttle rapid play commands
    if (_lastPlayCommand != null && 
        now.difference(_lastPlayCommand!) < _commandThrottleDelay) {
      if (kDebugMode) {
        print('Play command throttled - too recent');
      }
      return;
    }
    
    // Prevent play immediately after pause
    if (_lastPauseCommand != null && 
        now.difference(_lastPauseCommand!) < _commandThrottleDelay) {
      if (kDebugMode) {
        print('Play command blocked - recent pause command detected');
      }
      return;
    }
    
    _lastPlayCommand = now;
    
    if (kDebugMode) {
      print('Play command received (Android Auto/MediaSession compatible) - Current user intent: $_userIntendedPlaying');
    }
    
    // Set user intent to playing
    _userIntendedPlaying = true;
    
    try {
      // Ensure we have a track to play
      if (_stateManager.currentTrack == null && _stateManager.playlist.isNotEmpty) {
        if (kDebugMode) {
          print('No current track, loading from playlist');
        }
        await _playCurrentTrack();
      } else {
        if (kDebugMode) {
          print('Playing existing track');
        }
        await _player.play();
      }
      
      // Always verify the play command worked
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Update state to reflect actual player state, but force playing if user intended
      _updatePlaybackState(playbackState.value.copyWith(
        playing: true, // Force true since user explicitly requested play
        processingState: _player.processingState == ProcessingState.ready 
            ? AudioProcessingState.ready 
            : AudioProcessingState.loading,
      ));
      
      if (kDebugMode) {
        print('Play command completed. User intended playing: $_userIntendedPlaying, Actually playing: ${_player.playing}');
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
    final now = DateTime.now();
    
    // Throttle rapid pause commands
    if (_lastPauseCommand != null && 
        now.difference(_lastPauseCommand!) < _commandThrottleDelay) {
      if (kDebugMode) {
        print('Pause command throttled - too recent');
      }
      return;
    }
    
    _lastPauseCommand = now;
    
    if (kDebugMode) {
      print('Pause command received (Android Auto/MediaSession compatible) - Current user intent: $_userIntendedPlaying');
    }
    
    // Set user intent to not playing
    _userIntendedPlaying = false;
    
    try {
      await _player.pause();
      
      _updatePlaybackState(playbackState.value.copyWith(
        playing: false,
      ));
      
      if (kDebugMode) {
        print('Pause command completed. User intended playing: $_userIntendedPlaying');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in pause command: $e');
      }
    }
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    if (kDebugMode) {
      print('Android Auto: playFromMediaId called with ID: $mediaId');
    }

    try {
      // Safety check: ensure we have media library data
      if (_albums.isEmpty && _artists.isEmpty && _tracks.isEmpty && _playlists.isEmpty) {
        if (kDebugMode) {
          print('Android Auto: Cannot play - no media library data available');
        }
        // Don't throw - just return safely to prevent crash
        return;
      }

      // Parse the media ID to determine what to play
      if (mediaId.startsWith('album:')) {
        final albumId = mediaId.substring(6);
        if (kDebugMode) {
          print('Android Auto: Playing album with ID: $albumId');
        }
        
        try {
          // Find the album with safe fallback
          final album = _albums.where((album) => album.id == albumId).firstOrNull;
          if (album == null) {
            if (kDebugMode) {
              print('Android Auto: Album not found: $albumId');
            }
            return;
          }
          
          // Get album tracks from Jellyfin service with error handling
          final tracks = await _jellyfinService.getAlbumTracks(albumId);
          if (tracks.isNotEmpty) {
            await playPlaylist(tracks, 0);
            if (kDebugMode) {
              print('Android Auto: Successfully started album playback: ${album.name} (${tracks.length} tracks)');
            }
          } else {
            if (kDebugMode) {
              print('Android Auto: Album has no tracks: ${album.name}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Android Auto: Error playing album $albumId: $e');
          }
          // Don't rethrow - prevent crash
        }
      } 
      else if (mediaId.startsWith('artist:')) {
        final artistId = mediaId.substring(7);
        if (kDebugMode) {
          print('Android Auto: Playing artist with ID: $artistId');
        }
        
        try {
          // Find the artist with safe fallback
          final artist = _artists.where((artist) => artist.id == artistId).firstOrNull;
          if (artist == null) {
            if (kDebugMode) {
              print('Android Auto: Artist not found: $artistId');
            }
            return;
          }
          
          // Get tracks for this artist by filtering by artist name
          final artistTracks = _tracks.where((track) => 
            track.artistName != null && track.artistName == artist.name
          ).toList();
          
          if (artistTracks.isNotEmpty) {
            await playPlaylist(artistTracks, 0);
            if (kDebugMode) {
              print('Android Auto: Successfully started artist playback - ${artist.name} with ${artistTracks.length} tracks');
            }
          } else {
            if (kDebugMode) {
              print('Android Auto: No tracks found for artist: ${artist.name}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Android Auto: Error playing artist $artistId: $e');
          }
          // Don't rethrow - prevent crash
        }
      }
      else if (mediaId.startsWith('playlist:')) {
        final playlistId = mediaId.substring(9);
        if (kDebugMode) {
          print('Android Auto: Playing playlist with ID: $playlistId');
        }
        
        try {
          // Find the playlist for reference
          final playlist = _playlists.where((p) => p.id == playlistId).firstOrNull;
          
          // Get playlist tracks from Jellyfin service with error handling
          final tracks = await _jellyfinService.getPlaylistTracks(playlistId);
          if (tracks.isNotEmpty) {
            await playPlaylist(tracks, 0);
            if (kDebugMode) {
              print('Android Auto: Successfully started playlist playback: ${playlist?.name ?? playlistId} (${tracks.length} tracks)');
            }
          } else {
            if (kDebugMode) {
              print('Android Auto: Playlist has no tracks: ${playlist?.name ?? playlistId}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Android Auto: Error playing playlist $playlistId: $e');
          }
          // Don't rethrow - prevent crash
        }
      }
      else if (mediaId.startsWith('track:')) {
        final trackId = mediaId.substring(6);
        if (kDebugMode) {
          print('Android Auto: Playing track with ID: $trackId');
        }
        
        try {
          // Find the track with safe fallback
          final track = _tracks.where((track) => track.id == trackId).firstOrNull;
          if (track == null) {
            if (kDebugMode) {
              print('Android Auto: Track not found: $trackId');
            }
            return;
          }
          
          await playPlaylist([track], 0);
          if (kDebugMode) {
            print('Android Auto: Successfully started track playback: ${track.name}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Android Auto: Error playing track $trackId: $e');
          }
          // Don't rethrow - prevent crash
        }
      }
      else if (mediaId == 'shuffle_all') {
        if (kDebugMode) {
          print('Android Auto: Shuffle all tracks');
        }
        
        try {
          if (_tracks.isEmpty) {
            if (kDebugMode) {
              print('Android Auto: No tracks available to shuffle');
            }
            return;
          }
          
          final shuffledTracks = List<Track>.from(_tracks);
          shuffledTracks.shuffle();
          await playPlaylist(shuffledTracks, 0);
          shuffle(); // Enable shuffle mode
          
          if (kDebugMode) {
            print('Android Auto: Successfully started shuffle all with ${shuffledTracks.length} tracks');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Android Auto: Error shuffling tracks: $e');
          }
          // Don't rethrow - prevent crash
        }
      }
      else {
        if (kDebugMode) {
          print('Android Auto: Unknown media ID format: $mediaId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Android Auto: Critical error in playFromMediaId $mediaId: $e');
      }
      // Never throw from here - Android Auto should not crash the app
    }
  }

  @override
  Future<void> stop() async {
    // Reset user intent on stop
    _userIntendedPlaying = false;
    
    await _player.stop();
    _updatePlaybackState(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (kDebugMode) {
      print('Skip to next requested. Current: ${_stateManager.currentIndex}, Max: ${_stateManager.playlist.length - 1}');
    }
    
    // Use gapless transition if concatenation is active
    if (_isUsingConcatenation && _concatenatingSource != null) {
      final nextIndex = _stateManager.currentIndex + 1;
      if (nextIndex < _stateManager.playlist.length) {
        if (kDebugMode) {
          print('Using gapless skip to next track: $nextIndex');
        }
        
        try {
          await _player.seekToNext();
          // State will be updated automatically via currentIndexStream
          await _statePersistence.savePlaybackState(_player.position, _player.playing);
          return;
        } catch (e) {
          if (kDebugMode) {
            print('Gapless skip failed, falling back to traditional method: $e');
          }
        }
      }
    }
    
    // Fallback to traditional skip method
    // Use atomic transition manager to prevent race conditions
    if (!await _transitionManager.acquireTransitionLock('skipToNext')) {
      if (kDebugMode) {
        print('Skip to next rejected - another transition in progress');
      }
      return;
    }
    
    try {
      // Reset all completion and transition handling atomically
      _stateManager.setHandlingCompletion(false);
      _stateManager.setTransitioning(false);
      
      if (await _stateManager.incrementCurrentIndexAtomic()) {
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
    } finally {
      _transitionManager.releaseTransitionLock();
    }
  }

  Future<void> _handleTrackCompletion() async {
    // If using concatenation, the transition is automatic - just handle state updates
    if (_isUsingConcatenation && _concatenatingSource != null) {
      if (kDebugMode) {
        print('Track completion with gapless - letting concatenation handle transition');
      }
      
      // The currentIndexStream listener will handle state updates automatically
      // Just need to handle end-of-playlist scenarios
      if (_stateManager.currentIndex >= _stateManager.playlist.length - 1) {
        if (_stateManager.radioModeEnabled && _stateManager.currentTrack != null) {
          await _handleRadioModeExpansion();
        } else {
          // End of playlist
          _isUsingConcatenation = false;
          _concatenatingSource = null;
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
            playing: false,
          ));
        }
      }
      return;
    }
    
    // Traditional track completion handling for non-gapless mode
    // Use atomic transition manager to prevent race conditions with manual skips
    if (!await _transitionManager.acquireTransitionLock('trackCompletion')) {
      if (kDebugMode) {
        print('Track completion rejected - another transition in progress');
      }
      return;
    }
    
    try {
      if (kDebugMode) {
        print('Track completed: ${_stateManager.currentTrack?.name}');
      }
      
      // Simple, clean stop without aggressive delays
      try {
        await _player.stop();
      } catch (e) {
        if (kDebugMode) {
          print('Error stopping player during completion: $e');
        }
      }
      
      // Minimal delay for codec cleanup - reduced from 200ms
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Check if we can move to next track atomically
      if (await _stateManager.incrementCurrentIndexAtomic()) {
        if (kDebugMode) {
          print('Moving to next track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${_stateManager.currentTrack!.name}');
        }
        
        await _playCurrentTrack();
        await _statePersistence.savePlaybackState(_player.position, _player.playing);
        
        if (kDebugMode) {
          print('Successfully moved to next track: ${_stateManager.currentTrack!.name}');
        }
        
      } else if (_stateManager.radioModeEnabled && _stateManager.currentTrack != null) {
        await _handleRadioModeExpansion();
      } else {
        // End of playlist
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
      // Always reset states and release lock
      _stateManager.setHandlingCompletion(false);
      _stateManager.setTransitioning(false);
      _transitionManager.releaseTransitionLock();
    }
  }

  /// Handle radio mode expansion when reaching end of playlist
  Future<void> _handleRadioModeExpansion() async {
    // Radio mode handling
    final similarTracks = await _radioMode.getSimilarTracks(
      _stateManager.currentTrack!, 
      _stateManager.playlist,
      limit: 15
    );
    
    if (similarTracks.isNotEmpty) {
      await _queueManager.addTracksToPlaylist(similarTracks);
      queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
      
      // If using concatenation, add tracks to the concatenating source
      if (_isUsingConcatenation && _concatenatingSource != null) {
        for (final track in similarTracks) {
          final audioSource = await _createAudioSource(track);
          if (audioSource != null) {
            await _concatenatingSource!.add(audioSource);
          }
        }
        
        if (kDebugMode) {
          print('Radio mode: Added ${similarTracks.length} tracks to concatenating source');
        }
      } else {
        // Traditional radio mode handling
        await _stateManager.incrementCurrentIndexAtomic();
        await _playCurrentTrack();
        await _statePersistence.savePlaybackState(_player.position, _player.playing);
        
        if (kDebugMode) {
          print('Radio mode: Added ${similarTracks.length} tracks');
        }
      }
    } else {
      // End of radio mode
      _isUsingConcatenation = false;
      _concatenatingSource = null;
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
      ));
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Use gapless transition if concatenation is active
    if (_isUsingConcatenation && _concatenatingSource != null) {
      final prevIndex = _stateManager.currentIndex - 1;
      if (prevIndex >= 0) {
        if (kDebugMode) {
          print('Using gapless skip to previous track: $prevIndex');
        }
        
        try {
          await _player.seekToPrevious();
          // State will be updated automatically via currentIndexStream
          await _statePersistence.savePlaybackState(_player.position, _player.playing);
          return;
        } catch (e) {
          if (kDebugMode) {
            print('Gapless skip to previous failed, falling back: $e');
          }
        }
      }
    }
    
    // Fallback to traditional skip logic with restart behavior
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
      if (await _stateManager.decrementCurrentIndexAtomic()) {
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
      await _stateManager.setCurrentIndexAtomic(index);
      await _playCurrentTrack();
      await _statePersistence.savePlaybackState(_player.position, _player.playing);
    }
  }

  // Enhanced track loading with gapless support and better error handling
  Future<void> _playCurrentTrack() async {
    if (kDebugMode) {
      print('=== _playCurrentTrack DEBUG START ===');
      print('Playlist size: ${_stateManager.playlist.length}');
      print('Current index: ${_stateManager.currentIndex}');
      print('User intended playing: $_userIntendedPlaying');
    }
    
    if (_stateManager.playlist.isEmpty || _stateManager.currentIndex >= _stateManager.playlist.length) {
      if (kDebugMode) {
        print('Cannot play current track: playlist empty or index out of bounds');
        print('=== _playCurrentTrack DEBUG END (ERROR) ===');
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
    
    // Don't override user intent - if playPlaylist() set it to true, keep it
    // This preserves the user's explicit action to start playback
    if (kDebugMode) {
      print('Playing track with user intent: $_userIntendedPlaying, was previously playing: $wasPlaying');
    }
    
    // Try gapless playback first if enabled and conditions are met
    if (_stateManager.gaplessPlaybackEnabled && _stateManager.playlist.length > 1) {
      if (kDebugMode) {
        print('Attempting gapless playback...');
      }
      final gaplessResult = await _tryGaplessPlayback();
      if (gaplessResult) {
        if (kDebugMode) {
          print('Successfully initiated gapless playback for playlist');
          print('=== _playCurrentTrack DEBUG END (GAPLESS) ===');
        }
        return;
      }
      if (kDebugMode) {
        print('Gapless playback failed, falling back to individual track');
      }
    }
    
    // Fall back to individual track playback with crossfade if available
    if (kDebugMode) {
      print('Playing individual track...');
    }
    await _playIndividualTrack(track, wasPlaying);
    
    if (kDebugMode) {
      print('=== _playCurrentTrack DEBUG END ===');
    }
  }

  /// Attempt to set up gapless playback using ConcatenatingAudioSource
  Future<bool> _tryGaplessPlayback() async {
    try {
      // Build concatenating source for entire playlist
      final concatenatingSource = await _buildConcatenatingSource(_stateManager.playlist);
      
      if (concatenatingSource != null) {
        if (kDebugMode) {
          print('Built concatenating source with ${concatenatingSource.children.length} tracks');
        }
        
        // Set the concatenating source with current index
        await _player.setAudioSource(
          concatenatingSource, 
          initialIndex: _stateManager.currentIndex,
        );
        
        // Store references for gapless operations
        _concatenatingSource = concatenatingSource;
        _isUsingConcatenation = true;
        
        // Resume playing if user intended it
        if (_userIntendedPlaying) {
          await _player.play();
        }
        
        // Update playback state
        _updatePlaybackState(playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
          playing: _userIntendedPlaying ? _player.playing : false,
          queueIndex: _stateManager.currentIndex,
        ));
        
        // Start preloading for upcoming tracks
        Future.microtask(() {
          _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
        });
        
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set up gapless playback, falling back to individual: $e');
      }
    }
    
    return false;
  }

  /// Play individual track with crossfade support
  Future<void> _playIndividualTrack(Track track, bool wasPlaying) async {
    // Disable concatenation mode
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    
    // Update to loading state with user intent
    _updatePlaybackState(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: _stateManager.currentIndex,
      playing: _userIntendedPlaying, // Use user intent instead of wasPlaying
    ));
    
    // Apply crossfade if enabled and we have a current track playing
    bool useCrossfade = _stateManager.smartCrossfadeEnabled && 
                       wasPlaying && 
                       _player.playing;
    
    if (useCrossfade) {
      await _crossfadeToTrack(track);
    } else {
      // Minimal stop for codec cleanup - no excessive delays
      try {
        await _player.stop();
        await Future.delayed(const Duration(milliseconds: 100)); // Reduced from 300ms
      } catch (e) {
        if (kDebugMode) {
          print('Error stopping player: $e');
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Load and play the track
      await _loadAndPlayTrack(track);
    }
    
    // Start preloading after current track is loaded
    Future.delayed(const Duration(milliseconds: 200), () {
      _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
    });
  }

  Future<void> _loadAndPlayTrack(Track track) async {
    if (kDebugMode) {
      print('Loading track: ${track.name}, user intended playing: $_userIntendedPlaying');
    }
    
    // Activate audio session before loading (iOS specific)
    try {
      final audioSession = await AudioSession.instance;
      await audioSession.setActive(true);
      if (kDebugMode) {
        print('Audio session activated for track loading');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to activate audio session: $e');
      }
    }
    
    // Try local file first
    final localFilePath = _downloadService.getLocalFilePath(track.id);
    
    if (localFilePath != null) {
      final localFile = File(localFilePath);
      if (await localFile.exists()) {
        try {
          await _player.setFilePath(localFilePath);
          
          // iOS needs longer delays for audio initialization
          if (Platform.isIOS) {
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          
          if (_userIntendedPlaying) {
            await _player.play();
            if (kDebugMode) {
              print('Auto-playing local file: ${track.name} - user intended playing');
            }
          } else {
            if (kDebugMode) {
              print('Not auto-playing local file: ${track.name} - user paused');
            }
          }
          
          // Update playback state after successful load
          _updatePlaybackState(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: _userIntendedPlaying && _player.playing,
            queueIndex: _stateManager.currentIndex,
          ));
          
          if (kDebugMode) {
            print('Successfully loaded local file: ${track.name}, playing: ${_player.playing}');
          }
          return;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to play local file: $e');
          }
        }
      }
    }
    
    // Stream the track with enhanced error handling and platform-specific optimizations
    List<String> streamUrls;
    
    // Platform-specific URL prioritization for better compatibility
    if (Platform.isIOS) {
      streamUrls = [
        _jellyfinService.getStreamUrl(track.id),          // Transcoded (iOS preferred)
        _jellyfinService.getUniversalStreamUrl(track.id), // Universal fallback
        _jellyfinService.getDirectStreamUrl(track.id),    // Direct (last resort on iOS)
      ];
    } else if (Platform.isMacOS) {
      // macOS: Try universal first, then transcoded, then direct
      streamUrls = [
        _jellyfinService.getUniversalStreamUrl(track.id), // Universal (macOS preferred)
        _jellyfinService.getStreamUrl(track.id),          // Transcoded fallback
        _jellyfinService.getDirectStreamUrl(track.id),    // Direct (last resort)
      ];
    } else {
      streamUrls = [
        _jellyfinService.getDirectStreamUrl(track.id),    // Direct (Android preferred)
        _jellyfinService.getStreamUrl(track.id),          // Transcoded fallback
        _jellyfinService.getUniversalStreamUrl(track.id), // Universal fallback
      ];
    }
    
    bool loaded = false;
    Exception? lastError;
    
    for (int i = 0; i < streamUrls.length; i++) {
      final streamUrl = streamUrls[i];
      
      try {
        if (streamUrl.isNotEmpty) {
          String platformOptimization;
          if (Platform.isIOS) {
            platformOptimization = "iOS optimized";
          } else if (Platform.isMacOS) {
            platformOptimization = "macOS optimized";
          } else {
            platformOptimization = "Android optimized";
          }
          
          if (kDebugMode) {
            print('Attempting to load stream ${i + 1}/${streamUrls.length}: $platformOptimization order');
            print('Stream URL: $streamUrl');
          }
          
          if (_shouldTranscodeTrack(track)) {
            final hlsUrl = _getHlsStreamUrl(track);
            if (hlsUrl.isNotEmpty) {
              await _player.setAudioSource(HlsAudioSource(Uri.parse(hlsUrl)));
              if (kDebugMode) {
                print('Using HLS stream for: ${track.name}');
              }
            } else {
              await _player.setUrl(streamUrl);
              if (kDebugMode) {
                print('Using regular stream URL for: ${track.name}');
              }
            }
          } else {
            await _player.setUrl(streamUrl);
            if (kDebugMode) {
              print('Using direct stream URL for: ${track.name}');
            }
          }
          
          // Platform-specific delays for stream initialization and buffering
          if (Platform.isIOS) {
            await Future.delayed(const Duration(milliseconds: 800)); // Longer delay for iOS
          } else if (Platform.isMacOS) {
            await Future.delayed(const Duration(milliseconds: 500)); // Medium delay for macOS
          } else {
            await Future.delayed(const Duration(milliseconds: 200)); // Shorter for Android
          }
          
          if (_userIntendedPlaying) {
            await _player.play();
            if (kDebugMode) {
              print('Auto-playing stream: ${track.name} - user intended playing');
            }
          } else {
            if (kDebugMode) {
              print('Not auto-playing stream: ${track.name} - user paused');
            }
          }
          
          // Update playback state after successful load
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: _userIntendedPlaying && _player.playing,
            queueIndex: _stateManager.currentIndex,
          ));
          
          loaded = true;
          if (kDebugMode) {
            print('Successfully loaded stream: ${track.name}, playing: ${_player.playing}');
          }
          break;
        }
      } catch (e) {
        lastError = e as Exception?;
        if (kDebugMode) {
          print('Failed to load stream URL ${i + 1}/${streamUrls.length}: $e');
        }
        
        // Platform-specific URL retry logic
        if ((Platform.isIOS || Platform.isMacOS) && i < streamUrls.length - 1) {
          if (kDebugMode) {
            print('${Platform.isIOS ? "iOS" : "macOS"}: Trying next stream URL immediately...');
          }
          continue;
        }
      }
    }
    
    if (!loaded) {
      if (kDebugMode) {
        print('Failed to load any stream for: ${track.name}, last error: $lastError');
        if (Platform.isIOS) {
          print('iOS: Consider checking stream format compatibility');
        } else if (Platform.isMacOS) {
          print('macOS: Consider checking network permissions and stream format compatibility');
        }
      }
      
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
    }
  }

  // Custom methods for the app
  Future<void> playTrack(Track track) async {
    // Set user intent to playing since this is an explicit play action
    _userIntendedPlaying = true;
    
    // Clear existing state - single track doesn't use concatenation
    await _player.stop();
    _preloader.clearAllPreloadedPlayers();
    _audioSourceCache.clear();
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    
    // Reset all transition states atomically
    await _transitionManager.waitForTransitionComplete();
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
    
    if (kDebugMode) {
      print('=== PLAYPLAYLIST DEBUG START ===');
      print('Starting playPlaylist with ${tracks.length} tracks, startIndex: $startIndex');
      print('Track to play: ${tracks[startIndex].name}');
    }
    
    // Set user intent to playing since this is an explicit play action
    _userIntendedPlaying = true;
    
    if (kDebugMode) {
      print('Set _userIntendedPlaying to: $_userIntendedPlaying');
    }
    
    // Clear existing state
    await _player.stop();
    _preloader.clearAllPreloadedPlayers();
    _audioSourceCache.clear();
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    
    if (kDebugMode) {
      print('Cleared existing player state');
    }
    
    // Reset all transition states atomically
    await _transitionManager.waitForTransitionComplete();
    _stateManager.setHandlingCompletion(false);
    _stateManager.setTransitioning(false);
    
    _queueManager.setPlaylist(tracks, startIndex);
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    if (kDebugMode) {
      print('Set playlist and queue');
    }
    
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: _stateManager.currentIndex,
    ));
    
    if (kDebugMode) {
      print('Updated playback state to loading with playing: true');
    }
    
    await _playCurrentTrack();
    
    if (kDebugMode) {
      print('_playCurrentTrack() completed');
      print('Final player state - playing: ${_player.playing}, userIntent: $_userIntendedPlaying');
      print('=== PLAYPLAYLIST DEBUG END ===');
    }
    
    Future.microtask(() => _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex));
    await _statePersistence.savePlaybackState(_player.position, _player.playing);
    
    if (kDebugMode) {
      print('Playlist playback initiated: ${tracks.length} tracks, gapless: $_isUsingConcatenation');
    }
  }

  MediaItem _trackToMediaItem(Track track) {
    try {
      // Defensive programming - ensure track has required data
      final id = track.id;
      final title = track.name.isNotEmpty ? track.name : 'Unknown Track';
      final artist = track.artistName?.isNotEmpty == true ? track.artistName : 'Unknown Artist';
      final album = track.albumName?.isNotEmpty == true ? track.albumName : 'Unknown Album';
      
      // Safely handle duration
      Duration? duration;
      if (track.duration != null && track.duration! > 0) {
        try {
          duration = Duration(milliseconds: track.duration!);
        } catch (e) {
          if (kDebugMode) {
            print('Warning: Invalid duration for track ${track.name}: ${track.duration}');
          }
          duration = null;
        }
      }
      
      // Safely handle artwork URL
      Uri? artUri;
      if (track.imageUrl != null && track.imageUrl!.isNotEmpty) {
        try {
          final imageUrl = _jellyfinService.getImageUrl(track.imageUrl!, width: 300, height: 300);
          artUri = Uri.parse(imageUrl);
        } catch (e) {
          if (kDebugMode) {
            print('Warning: Invalid image URL for track ${track.name}: ${track.imageUrl}');
          }
          artUri = null;
        }
      }
      
      return MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artUri: artUri,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error creating MediaItem for track: $e');
        print('Track data - ID: ${track.id}, Name: ${track.name}, Artist: ${track.artistName}');
      }
      
      // Return a safe fallback MediaItem to prevent crashes
      return MediaItem(
        id: track.id,
        title: 'Unknown Track',
        artist: 'Unknown Artist',
        album: 'Unknown Album',
      );
    }
  }

  // Queue management methods with gapless support
  void addToQueue(Track track) async {
    await _queueManager.addToQueue(track);
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    // If using concatenation, add the track to the concatenating source
    if (_isUsingConcatenation && _concatenatingSource != null) {
      final audioSource = await _createAudioSource(track);
      if (audioSource != null) {
        await _concatenatingSource!.add(audioSource);
        if (kDebugMode) {
          print('Added track to concatenating source: ${track.name}');
        }
      }
    }
    
    final position = _stateManager.playlist.length - _stateManager.currentIndex - 1;
    _preloader.preloadQueueTrack(track, position);
  }

  void addNext(Track track) async {
    await _queueManager.addNext(track);
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    // If using concatenation, insert the track after current position
    if (_isUsingConcatenation && _concatenatingSource != null) {
      final audioSource = await _createAudioSource(track);
      if (audioSource != null) {
        final insertIndex = _stateManager.currentIndex + 1;
        await _concatenatingSource!.insert(insertIndex, audioSource);
        if (kDebugMode) {
          print('Inserted track into concatenating source at index $insertIndex: ${track.name}');
        }
      }
    }
    
    _preloader.preloadPlayNextTrack(track);
  }

  void removeFromQueue(int index) async {
    if (await _queueManager.removeFromQueue(index)) {
      queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
      
      // If using concatenation, remove from concatenating source
      if (_isUsingConcatenation && _concatenatingSource != null) {
        if (index < _concatenatingSource!.children.length) {
          await _concatenatingSource!.removeAt(index);
          if (kDebugMode) {
            print('Removed track from concatenating source at index: $index');
          }
        }
      }
      
      _preloader.cleanupOldPreloadedPlayers(_stateManager.playlist, _stateManager.currentIndex);
    }
  }

  void clearQueue() async {
    // Reset user intent when clearing queue
    _userIntendedPlaying = false;
    
    await _queueManager.clearQueue();
    _preloader.clearAllPreloadedPlayers();
    _audioSourceCache.clear();
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    queue.add(<MediaItem>[]);
    mediaItem.add(null);
    stop();
  }

  void shuffle() {
    _preloader.clearAllPreloadedPlayers();
    _audioSourceCache.clear();
    
    // If using concatenation, need to rebuild the concatenating source
    if (_isUsingConcatenation) {
      _isUsingConcatenation = false;
      _concatenatingSource = null;
    }
    
    _queueManager.shuffle();
    queue.add(_stateManager.playlist.map(_trackToMediaItem).toList());
    
    // Try to rebuild gapless playback if it was enabled
    if (_stateManager.gaplessPlaybackEnabled && _stateManager.playlist.length > 1) {
      Future.microtask(() async {
        final gaplessResult = await _tryGaplessPlayback();
        if (!gaplessResult) {
          _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
        }
      });
    } else {
      _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
    }
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
      // Only set volume when explicitly changing settings, not during playback
      _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
      
      // If gapless is disabled but crossfade is enabled, preload for smooth transitions
      if (!_stateManager.gaplessPlaybackEnabled) {
        _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
      }
    } else {
      // If both gapless and crossfade are disabled, clear preloaded players
      if (!_stateManager.gaplessPlaybackEnabled) {
        _preloader.clearAllPreloadedPlayers();
      }
    }
  }

  void setNormalizeVolume(bool enabled) {
    _stateManager.setNormalizeVolumeEnabled(enabled);
    // Only set volume when explicitly requested, not during track changes
    _player.setVolume(enabled ? 0.8 : 1.0);
  }

  void setGaplessPlayback(bool enabled) {
    _stateManager.setGaplessPlaybackEnabled(enabled);
    
    if (enabled) {
      // Try to enable gapless playback if we have a playlist
      if (_stateManager.playlist.length > 1 && !_isUsingConcatenation) {
        Future.microtask(() async {
          final gaplessResult = await _tryGaplessPlayback();
          if (kDebugMode) {
            print('Gapless playback ${gaplessResult ? 'enabled' : 'failed to enable'}');
          }
        });
      }
    } else {
      // Disable gapless and fall back to individual track playback
      if (_isUsingConcatenation) {
        _isUsingConcatenation = false;
        _concatenatingSource = null;
        _audioSourceCache.clear();
        
        if (kDebugMode) {
          print('Gapless playback disabled, fell back to individual tracks');
        }
      }
    }
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
            // Set user intent based on restored state
            _userIntendedPlaying = true;
            
            await _player.play();
            _statePersistence.startPeriodicSaving(_player.position, _player.playing);
            if (kDebugMode) {
              print('Automatically resumed playback: ${currentTrack.name}');
            }
          } else {
            _userIntendedPlaying = false;
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
    _statePersistence.dispose();
    _preloader.dispose();
    _audioSourceCache.clear();
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    await _player.dispose();
  }

  // Media browsing methods for Android Auto support
  
  /// Update the media library data for browsing
  void updateMediaLibrary({
    List<Album>? albums,
    List<Artist>? artists, 
    List<Track>? tracks,
    List<Playlist>? playlists,
  }) {
    if (albums != null) _albums = albums;
    if (artists != null) _artists = artists;
    if (tracks != null) _tracks = tracks;
    if (playlists != null) _playlists = playlists;
    
    if (kDebugMode) {
      print('AudioHandler: Updated media library - Albums: ${_albums.length}, Artists: ${_artists.length}, Tracks: ${_tracks.length}, Playlists: ${_playlists.length}');
    }
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    if (kDebugMode) {
      print('AudioHandler: getChildren called with parentMediaId: $parentMediaId');
    }

    try {
      // Ensure we have data available - return safe empty results if not
      if (_albums.isEmpty && _artists.isEmpty && _tracks.isEmpty && _playlists.isEmpty) {
        if (kDebugMode) {
          print('AudioHandler: No media library data available, returning safe empty result');
        }
        
        switch (parentMediaId) {
          case AudioService.browsableRootId:
            // Always return the main categories even if empty - Android Auto expects this structure
            return [
              MediaItem(
                id: 'albums',
                title: 'Albums',
                album: '',
                artist: '',
                playable: false,
                extras: {'browsable': true},
              ),
              MediaItem(
                id: 'artists',
                title: 'Artists',
                album: '',
                artist: '',
                playable: false,
                extras: {'browsable': true},
              ),
              MediaItem(
                id: 'playlists',
                title: 'Playlists',
                album: '',
                artist: '',
                playable: false,
                extras: {'browsable': true},
              ),
              MediaItem(
                id: 'tracks',
                title: 'All Songs',
                album: '',
                artist: '',
                playable: false,
                extras: {'browsable': true},
              ),
            ];
          default:
            // Return empty for any subcategory when no data
            return [];
        }
      }

      switch (parentMediaId) {
        case AudioService.browsableRootId:
          return [
            MediaItem(
              id: 'albums',
              title: 'Albums (${_albums.length})',
              album: '',
              artist: '',
              playable: false,
              extras: {'browsable': true},
            ),
            MediaItem(
              id: 'artists',
              title: 'Artists (${_artists.length})',
              album: '',
              artist: '',
              playable: false,
              extras: {'browsable': true},
            ),
            MediaItem(
              id: 'playlists',
              title: 'Playlists (${_playlists.length})',
              album: '',
              artist: '',
              playable: false,
              extras: {'browsable': true},
            ),
            MediaItem(
              id: 'tracks',
              title: 'All Songs (${_tracks.length})',
              album: '',
              artist: '',
              playable: false,
              extras: {'browsable': true},
            ),
          ];

        case 'albums':
          if (_albums.isEmpty) {
            if (kDebugMode) {
              print('AudioHandler: No albums available');
            }
            return [];
          }
          return _albums.map((album) => MediaItem(
            id: 'album:${album.id}',
            title: album.name,
            album: album.name,
            artist: album.artistName ?? 'Unknown Artist',
            artUri: album.imageUrl != null 
              ? Uri.parse(_jellyfinService.getImageUrl(album.imageUrl!, width: 300, height: 300))
              : null,
            playable: true,
            extras: {'browsable': true},
          )).toList();

        case 'artists':
          if (_artists.isEmpty) {
            if (kDebugMode) {
              print('AudioHandler: No artists available');
            }
            return [];
          }
          return _artists.map((artist) => MediaItem(
            id: 'artist:${artist.id}',
            title: artist.name,
            album: '',
            artist: artist.name,
            artUri: artist.imageUrl != null
              ? Uri.parse(_jellyfinService.getImageUrl(artist.imageUrl!, width: 300, height: 300))
              : null,
            playable: false,
            extras: {'browsable': true},
          )).toList();

        case 'playlists':
          if (_playlists.isEmpty) {
            if (kDebugMode) {
              print('AudioHandler: No playlists available');
            }
            return [];
          }
          return _playlists.map((playlist) => MediaItem(
            id: 'playlist:${playlist.id}',
            title: playlist.name,
            album: '',
            artist: 'Playlist',
            playable: true,
            extras: {'browsable': true},
          )).toList();

        case 'tracks':
          if (_tracks.isEmpty) {
            if (kDebugMode) {
              print('AudioHandler: No tracks available');
            }
            return [];
          }
          // Limit tracks for performance and prevent crashes with huge libraries
          final limitedTracks = _tracks.take(100).toList();
          return limitedTracks.map((track) {
            try {
              return _trackToMediaItem(track);
            } catch (e) {
              if (kDebugMode) {
                print('Error converting track to MediaItem: $e, track: ${track.name}');
              }
              // Return a safe fallback MediaItem to prevent crashes
              return MediaItem(
                id: track.id,
                title: track.name,
                artist: track.artistName ?? 'Unknown Artist',
                album: track.albumName ?? 'Unknown Album',
              );
            }
          }).toList();

        default:
          // Handle album, artist, or playlist contents with comprehensive error handling
          if (parentMediaId.startsWith('album:')) {
            final albumId = parentMediaId.substring(6);
            try {
              final tracks = await _jellyfinService.getAlbumTracks(albumId);
              if (tracks.isEmpty) {
                if (kDebugMode) {
                  print('No tracks found for album: $albumId');
                }
                return [];
              }
              return tracks.map((track) {
                try {
                  return _trackToMediaItem(track);
                } catch (e) {
                  if (kDebugMode) {
                    print('Error converting album track to MediaItem: $e');
                  }
                  return MediaItem(
                    id: track.id,
                    title: track.name,
                    artist: track.artistName ?? 'Unknown Artist',
                    album: track.albumName ?? 'Unknown Album',
                  );
                }
              }).toList();
            } catch (e) {
              if (kDebugMode) {
                print('Error loading album tracks: $e');
              }
              return [];
            }
          } else if (parentMediaId.startsWith('artist:')) {
            final artistId = parentMediaId.substring(7);
            try {
              // Find the artist name from the artist ID with null safety
              final artist = _artists.where((a) => a.id == artistId).firstOrNull;
              if (artist == null) {
                if (kDebugMode) {
                  print('Artist not found: $artistId');
                }
                return [];
              }
              
              // Get all albums and filter by artist name
              final allAlbums = await _jellyfinService.getAlbums();
              final artistAlbums = allAlbums.where((album) => 
                album.artistName == artist.name
              ).toList();
              
              if (artistAlbums.isEmpty) {
                if (kDebugMode) {
                  print('No albums found for artist: ${artist.name}');
                }
                return [];
              }
              
              return artistAlbums.map((album) {
                try {
                  return MediaItem(
                    id: 'album:${album.id}',
                    title: album.name,
                    album: album.name,
                    artist: album.artistName ?? 'Unknown Artist',
                    artUri: album.imageUrl != null 
                      ? Uri.parse(_jellyfinService.getImageUrl(album.imageUrl!, width: 300, height: 300))
                      : null,
                    playable: true,
                    extras: {'browsable': true},
                  );
                } catch (e) {
                  if (kDebugMode) {
                    print('Error creating MediaItem for album: $e');
                  }
                  return MediaItem(
                    id: 'album:${album.id}',
                    title: album.name,
                    album: album.name,
                    artist: album.artistName ?? 'Unknown Artist',
                    playable: true,
                    extras: {'browsable': true},
                  );
                }
              }).toList();
            } catch (e) {
              if (kDebugMode) {
                print('Error loading artist albums: $e');
              }
              return [];
            }
          } else if (parentMediaId.startsWith('playlist:')) {
            final playlistId = parentMediaId.substring(9);
            try {
              final tracks = await _jellyfinService.getPlaylistTracks(playlistId);
              if (tracks.isEmpty) {
                if (kDebugMode) {
                  print('No tracks found for playlist: $playlistId');
                }
                return [];
              }
              return tracks.map((track) {
                try {
                  return _trackToMediaItem(track);
                } catch (e) {
                  if (kDebugMode) {
                    print('Error converting playlist track to MediaItem: $e');
                  }
                  return MediaItem(
                    id: track.id,
                    title: track.name,
                    artist: track.artistName ?? 'Unknown Artist',
                    album: track.albumName ?? 'Unknown Album',
                  );
                }
              }).toList();
            } catch (e) {
              if (kDebugMode) {
                print('Error loading playlist tracks: $e');
              }
              return [];
            }
          }
          
          if (kDebugMode) {
            print('Unknown parentMediaId: $parentMediaId');
          }
          return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Critical error in getChildren: $e');
      }
      // Return a safe fallback to prevent complete Android Auto failure
      if (parentMediaId == AudioService.browsableRootId) {
        return [
          MediaItem(
            id: 'error',
            title: 'Content Unavailable',
            album: 'Please check connection and try refreshing',
            artist: 'Doudou',
            playable: false,
          ),
        ];
      }
      return [];
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    if (kDebugMode) {
      print('AudioHandler: playMediaItem called with: ${mediaItem.title}');
    }

    try {
      if (mediaItem.id.startsWith('album:')) {
        final albumId = mediaItem.id.substring(6);
        final tracks = await _jellyfinService.getAlbumTracks(albumId);
        if (tracks.isNotEmpty) {
          await playPlaylist(tracks, 0);
        }
      } else if (mediaItem.id.startsWith('playlist:')) {
        final playlistId = mediaItem.id.substring(9);
        final tracks = await _jellyfinService.getPlaylistTracks(playlistId);
        if (tracks.isNotEmpty) {
          await playPlaylist(tracks, 0);
        }
      } else {
        // Find the track and play it
        final track = _tracks.where((t) => t.id == mediaItem.id).firstOrNull;
        if (track != null) {
          await playTrack(track);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in playMediaItem: $e');
      }
    }
  }

  // Touch Bar Integration Methods
  Future<void> _initializeTouchBar() async {
    if (_touchBarService == null) return;
    
    try {
      await _touchBarService!.initialize();
      
      // Set up Touch Bar callbacks
      _touchBarService!.setCallbacks(
        onPlayPause: () async {
          if (playbackState.value.playing) {
            await pause();
          } else {
            await play();
          }
        },
        onPrevious: () async {
          await skipToPrevious();
        },
        onNext: () async {
          await skipToNext();
        },
        onSeek: (position) async {
          await seek(Duration(seconds: position.round()));
        },
        onToggleFavorite: () async {
          final currentTrack = _stateManager.currentTrack;
          if (currentTrack != null) {
            try {
              final newFavoriteStatus = !currentTrack.isFavorite;
              await _jellyfinService.setFavorite(currentTrack.id, newFavoriteStatus);
              
              // Update the track's favorite status
              currentTrack.isFavorite = newFavoriteStatus;
              
              // Update Touch Bar immediately
              _updateTouchBarFavoriteStatus(newFavoriteStatus);
              
              if (kDebugMode) {
                print('Toggled favorite for ${currentTrack.name}: $newFavoriteStatus');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Failed to toggle favorite: $e');
              }
            }
          }
        },
      );
      
      if (kDebugMode) {
        print('Touch Bar initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize Touch Bar: $e');
      }
    }
  }

  void _updateTouchBarWithCurrentTrack() {
    if (_touchBarService == null) return;
    
    final currentTrack = _stateManager.currentTrack;
    if (currentTrack != null) {
      _touchBarService!.updateNowPlaying(
        title: currentTrack.name,
        artist: currentTrack.artistName ?? 'Unknown Artist',
        duration: currentTrack.runTimeTicks != null 
          ? (currentTrack.runTimeTicks! / 10000000).toDouble()
          : 0.0,
      );
    } else {
      _touchBarService!.clearNowPlaying();
    }
  }

  void _updateTouchBarPlaybackState() {
    if (_touchBarService == null) return;
    
    final currentTrack = _stateManager.currentTrack;
    _touchBarService!.updatePlaybackState(
      isPlaying: playbackState.value.playing,
      position: playbackState.value.position.inSeconds.toDouble(),
      duration: currentTrack?.runTimeTicks != null 
        ? (currentTrack!.runTimeTicks! / 10000000).toDouble()
        : 0.0,
      isFavorite: currentTrack?.isFavorite ?? false,
    );
  }

  void _updateTouchBarFavoriteStatus(bool isFavorite) {
    if (_touchBarService == null) return;
    
    final currentTrack = _stateManager.currentTrack;
    _touchBarService!.updatePlaybackState(
      isPlaying: playbackState.value.playing,
      position: playbackState.value.position.inSeconds.toDouble(),
      duration: currentTrack?.runTimeTicks != null 
        ? (currentTrack!.runTimeTicks! / 10000000).toDouble()
        : 0.0,
      isFavorite: isFavorite,
    );
  }

  void _disposeTouchBar() {
    if (_touchBarService != null) {
      _touchBarService!.dispose();
      _touchBarService = null;
    }
  }
}