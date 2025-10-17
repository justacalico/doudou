import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';
import '../media_service_manager.dart';
import '../download_service.dart';
import '../touchbar_service.dart';
import '../lyrics_service.dart';
import '../logging_service.dart';
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
  final MediaServiceManager? _mediaServiceManager;
  
  // Touch Bar service for macOS
  bool _touchBarEnabled = false;
  
  // Lyrics state for TouchBar display
  LyricsResult? _currentLyrics;
  int _currentLyricsLineIndex = -1;
  String? _lastLyricsTrackId;
  
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

  // Logging service
  final LoggingService _logger = LoggingService();

  // RACE CONDITION PROTECTION: Synchronization primitives
  final Completer<void> _initializationCompleter = Completer<void>();
  final Map<String, Completer<void>> _operationLocks = {};
  
  // User intent tracking with atomic operations
  bool _userIntendedPlaying = false;
  final Completer<void> _userIntentLock = Completer<void>()..complete();

  // Command throttling with atomic timestamp updates
  DateTime? _lastPlayCommand;
  DateTime? _lastPauseCommand;
  static const Duration _commandThrottleDelay = Duration(milliseconds: 500);
  final Completer<void> _commandThrottleLock = Completer<void>()..complete();

  // Codec loop detection with synchronized access
  DateTime? _lastBufferingTime;
  int _bufferingLoopCount = 0;
  final Completer<void> _bufferingStateLock = Completer<void>()..complete();
  
  // Audio source cache protection
  final Completer<void> _audioSourceCacheLock = Completer<void>()..complete();
  
  // Concatenation state protection  
  final Completer<void> _concatenationStateLock = Completer<void>()..complete();
  
  // Volume state protection
  double? _previousVolume;
  final Completer<void> _volumeStateLock = Completer<void>()..complete();
  
  // Lyrics state protection
  final Completer<void> _lyricsStateLock = Completer<void>()..complete();
  
  // Completion handling protection
  final Completer<void> _completionHandlingLock = Completer<void>()..complete();
  
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
    
    // Update Touch Bar with new playback state
    if (Platform.isMacOS) {
      _updateTouchBarPlaybackState();
    }
  }

  DoudouAudioHandler(this._jellyfinService, this._downloadService, [this._mediaServiceManager]) {
    _logger.info('Initializing DoudouAudioHandler', 'AudioHandler');
    _logger.info('AudioPlayer created - Platform: ${Platform.operatingSystem}', 'AudioHandler');
    
    _stateManager = AudioStateManager();
    _preloader = AudioPreloader(_jellyfinService, _downloadService);
    _queueManager = AudioQueueManager(_stateManager);
    _radioMode = AudioRadioMode(_jellyfinService);
    _statePersistence = AudioStatePersistence(_stateManager);
    _transitionManager = AudioTransitionManager();
    
    _logger.info('Audio components initialized', 'AudioHandler');
    
    // Initialize Touch Bar service on macOS
    if (Platform.isMacOS) {
      _touchBarEnabled = true;
      _initializeTouchBar();
      _logger.info('TouchBar initialized successfully', 'AudioHandler');
    }
    
    // Initialize iOS audio session FIRST before any other audio setup (iOS only)
    if (Platform.isIOS) {
      _initializeAudioSession();
    }
    
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
      if (index != null && _isUsingConcatenation && !_stateManager.isHandlingCompletion) {
        if (kDebugMode) {
          print('Gapless transition to index: $index');
        }
        
        // Only update if this is a legitimate gapless transition
        if (index != _stateManager.currentIndex) {
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
      }
    });

    // Enhanced position stream for background tracking with reduced update frequency
    _player.positionStream.listen((position) {
      // Only update position if not currently transitioning to avoid conflicts
      if (!_transitionManager.isTransitionInProgress && 
          !_stateManager.isHandlingCompletion &&
          _player.processingState != ProcessingState.buffering) {
        _updatePlaybackState(playbackState.value.copyWith(
          updatePosition: position,
        ));
      }
      
      // Update TouchBar with current lyrics line (this is safe to do always)
      _updateTouchBarLyrics(position);
    });

    // Simplified completion detection - only handle actual completion
    _player.processingStateStream.listen((state) {
      _logger.info('Processing state changed: $state (userIntended: $_userIntendedPlaying)', 'AudioHandler');
      if (kDebugMode) {
        print('Processing state changed: $state');
      }
      
      // Handle codec loops only in extreme cases - MUCH less aggressive
      if (state == ProcessingState.buffering) {
        final now = DateTime.now();
        if (_lastBufferingTime != null && 
            now.difference(_lastBufferingTime!) < const Duration(seconds: 10)) {
          _bufferingLoopCount++;
          // Dramatically increased threshold to prevent false positives - was 15, now 25
          if (_bufferingLoopCount >= 25) {
            _logger.warning('Detected extreme codec loop in buffering state after 25 attempts, forcing recovery', 'AudioHandler');
            if (kDebugMode) {
              print('Detected extreme codec loop in buffering state after 25 attempts, forcing recovery');
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
      
      // Log critical state changes
      if (state == ProcessingState.ready && _userIntendedPlaying) {
        _logger.info('Track is ready and user intended playing - playback should start', 'AudioHandler');
      } else if (state == ProcessingState.ready && !_userIntendedPlaying) {
        _logger.info('Track is ready but user did not intend playing - paused state', 'AudioHandler');
      } else if (state == ProcessingState.idle) {
        _logger.warning('Processing state is IDLE - may indicate playback failure', 'AudioHandler');
      }
      
      // ONLY handle actual completion state - no forced completion
      // Add extra protection to prevent race conditions
      if (state == ProcessingState.completed && 
          !_transitionManager.isTransitionInProgress && 
          !_stateManager.isHandlingCompletion) {
        _logger.info('Track actually completed, handling transition...', 'AudioHandler');
        if (kDebugMode) {
          print('Track actually completed, handling transition...');
        }
        // Use a small delay to ensure any racing operations complete first
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_transitionManager.isTransitionInProgress && !_stateManager.isHandlingCompletion) {
            _handleTrackCompletion();
          }
        });
      }
    });

    // Monitor playback for state persistence and detailed logging
    _player.playerStateStream.listen((playerState) {
      _logger.info('Player state changed: playing=${playerState.playing}, processingState=${playerState.processingState} (userIntended: $_userIntendedPlaying)', 'AudioHandler');
      
      // Log critical state mismatches that might indicate Flatpak issues
      if (_userIntendedPlaying && !playerState.playing && playerState.processingState == ProcessingState.ready) {
        _logger.warning('CRITICAL: User intended playing but player is not playing despite being ready!', 'AudioHandler');
      }
      if (!_userIntendedPlaying && playerState.playing) {
        _logger.warning('CRITICAL: Player is playing but user did not intend to play!', 'AudioHandler');
      }
      
      // Only handle persistence, don't interfere with playback state
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
      await _loadAndPlayTrack(currentTrack, _userIntendedPlaying);
      
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
      await _loadAndPlayTrack(_stateManager.currentTrack!, _userIntendedPlaying);
      
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

      // Stream URLs fallback with service-agnostic approach
      List<String> streamUrls;
      final mediaServiceManager = _mediaServiceManager;
      
      if (mediaServiceManager != null) {
        // Use MediaServiceManager for current service - prefer alternative URLs
        final alt = mediaServiceManager.getAlternativeStreamUrls(track.id);
        if (alt.isNotEmpty) {
          streamUrls = alt;
        } else {
          final primary = mediaServiceManager.getStreamUrl(track.id);
          streamUrls = primary.isNotEmpty ? [primary] : [];
        }
      } else {
        // Fallback to JellyfinService with platform-optimized prioritization
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
      }

      for (final streamUrl in streamUrls) {
        if (streamUrl.isEmpty) continue;
        try {
          final ok = await _probeUrl(streamUrl);
          if (!ok) {
            if (kDebugMode) print('Skipping unreachable stream URL: $streamUrl');
            continue;
          }

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
        } catch (e) {
          if (kDebugMode) {
            print('Error while probing/creating source for $streamUrl: $e');
          }
          continue;
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

  // Audio Service Methods - Enhanced for background compatibility
  @override
  @override
  Future<void> play() async {
    final now = DateTime.now();
    _logger.info('Play command received', 'AudioHandler');
    
    // Throttle rapid play commands
    if (_lastPlayCommand != null && 
        now.difference(_lastPlayCommand!) < _commandThrottleDelay) {
      _logger.warning('Play command throttled - too recent (${now.difference(_lastPlayCommand!).inMilliseconds}ms ago)', 'AudioHandler');
      if (kDebugMode) {
        print('Play command throttled - too recent');
      }
      return;
    }
    
    // Prevent play immediately after pause
    if (_lastPauseCommand != null && 
        now.difference(_lastPauseCommand!) < _commandThrottleDelay) {
      _logger.warning('Play command blocked - recent pause command detected', 'AudioHandler');
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
    _logger.info('User intent set to playing', 'AudioHandler');
    
    try {
      // Ensure we have a track to play
      if (_stateManager.currentTrack == null && _stateManager.playlist.isNotEmpty) {
        _logger.info('No current track, loading from playlist', 'AudioHandler');
        if (kDebugMode) {
          print('No current track, loading from playlist');
        }
        await _playCurrentTrack();
      } else {
        _logger.info('Resuming existing track: ${_stateManager.currentTrack?.name}', 'AudioHandler');
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
      
      _logger.info('Play command completed successfully. Playing: ${_player.playing}', 'AudioHandler');
      if (kDebugMode) {
        print('Play command completed. User intended playing: $_userIntendedPlaying, Actually playing: ${_player.playing}');
      }
    } catch (e) {
      _logger.error('Error in play command: $e', 'AudioHandler');
      if (kDebugMode) {
        print('Error in play command: $e');
      }
      
      // Try to recover by reloading current track
      if (_stateManager.currentTrack != null) {
        _logger.info('Attempting recovery by reloading current track', 'AudioHandler');
        await _resumeCurrentTrack();
      }
    }
  }

  @override
  Future<void> pause() async {
    final now = DateTime.now();
    _logger.info('Pause command received', 'AudioHandler');
    
    // Throttle rapid pause commands
    if (_lastPauseCommand != null && 
        now.difference(_lastPauseCommand!) < _commandThrottleDelay) {
      _logger.warning('Pause command throttled - too recent', 'AudioHandler');
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
    _logger.info('User intent set to paused', 'AudioHandler');
    
    try {
      await _player.pause();
      
      _updatePlaybackState(playbackState.value.copyWith(
        playing: false,
      ));
      
      _logger.info('Pause command completed successfully', 'AudioHandler');
      if (kDebugMode) {
        print('Pause command completed. User intended playing: $_userIntendedPlaying');
      }
    } catch (e) {
      _logger.error('Error in pause command: $e', 'AudioHandler');
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
          
          // Get album tracks using appropriate service with error handling
          final mediaServiceManager = _mediaServiceManager;
          final tracks = mediaServiceManager != null 
            ? await mediaServiceManager.getTracks(parentId: albumId)
            : await _jellyfinService.getAlbumTracks(albumId);
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
          
          // Get playlist tracks using appropriate service with error handling
          final mediaServiceManager = _mediaServiceManager;
          final tracks = mediaServiceManager != null 
            ? await mediaServiceManager.getPlaylistTracks(playlistId)
            : await _jellyfinService.getPlaylistTracks(playlistId);
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
    _logger.info('Skip to next track requested (current: ${_stateManager.currentIndex}/${_stateManager.playlist.length - 1})', 'AudioHandler');
    
    if (kDebugMode) {
      print('Skip to next requested. Current: ${_stateManager.currentIndex}, Max: ${_stateManager.playlist.length - 1}');
    }
    
    // Preserve playing state when skipping - if music was playing, it should continue playing
    final wasPlaying = playbackState.value.playing;
    if (wasPlaying) {
      _userIntendedPlaying = true;
      _logger.info('Preserving playing state during skip (user was listening)', 'AudioHandler');
    }
    
    // Use gapless transition if concatenation is active
    if (_isUsingConcatenation && _concatenatingSource != null) {
      final nextIndex = _stateManager.currentIndex + 1;
      if (nextIndex < _stateManager.playlist.length) {
        _logger.info('Using gapless skip to next track: $nextIndex', 'AudioHandler');
        if (kDebugMode) {
          print('Using gapless skip to next track: $nextIndex');
        }
        
        try {
          await _player.seekToNext();
          // State will be updated automatically via currentIndexStream
          await _statePersistence.savePlaybackState(_player.position, _player.playing);
          _logger.info('Gapless skip successful', 'AudioHandler');
          return;
        } catch (e) {
          _logger.error('Gapless skip failed, falling back to traditional method: $e', 'AudioHandler');
          if (kDebugMode) {
            print('Gapless skip failed, falling back to traditional method: $e');
          }
        }
      }
    }
    
    // Fallback to traditional skip method
    // Use atomic transition manager to prevent race conditions
    if (!await _transitionManager.acquireTransitionLock('skipToNext')) {
      _logger.warning('Skip to next rejected - another transition in progress', 'AudioHandler');
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
        final nextTrack = _stateManager.currentTrack!;
        _logger.info('Skipping to track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${nextTrack.name}', 'AudioHandler');
        if (kDebugMode) {
          print('Skipping to track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${nextTrack.name}');
        }
        
        await _playCurrentTrack();
        await _statePersistence.savePlaybackState(_player.position, _player.playing);
        _logger.info('Skip to next completed successfully', 'AudioHandler');
      } else {
        _logger.info('Already at last track, cannot skip to next', 'AudioHandler');
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
    // Double-check if we're already handling completion to prevent duplicate calls
    if (_stateManager.isHandlingCompletion) {
      if (kDebugMode) {
        print('Track completion already being handled, ignoring duplicate call');
      }
      return;
    }
    
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
    
    // Set completion handling flag at the very start
    _stateManager.setHandlingCompletion(true);
    
    try {
      if (kDebugMode) {
        print('Track completed: ${_stateManager.currentTrack?.name}');
        print('User intended playing before completion: $_userIntendedPlaying');
      }
      
      // Preserve user intent during track completion - if music was playing, it should continue
      // _userIntendedPlaying should already be true if music was playing before completion
      
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
          print('User intended playing during transition: $_userIntendedPlaying');
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
    _logger.info('Skip to previous track requested (current: ${_stateManager.currentIndex})', 'AudioHandler');
    
    // Preserve playing state when skipping - if music was playing, it should continue playing
    final wasPlaying = playbackState.value.playing;
    if (wasPlaying) {
      _userIntendedPlaying = true;
      _logger.info('Preserving playing state during skip to previous', 'AudioHandler');
    }
    
    // Use gapless transition if concatenation is active
    if (_isUsingConcatenation && _concatenatingSource != null) {
      final prevIndex = _stateManager.currentIndex - 1;
      if (prevIndex >= 0) {
        _logger.info('Using gapless skip to previous track: $prevIndex', 'AudioHandler');
        if (kDebugMode) {
          print('Using gapless skip to previous track: $prevIndex');
        }
        
        try {
          await _player.seekToPrevious();
          // State will be updated automatically via currentIndexStream
          await _statePersistence.savePlaybackState(_player.position, _player.playing);
          _logger.info('Gapless skip to previous successful', 'AudioHandler');
          return;
        } catch (e) {
          _logger.error('Gapless skip to previous failed, falling back: $e', 'AudioHandler');
          if (kDebugMode) {
            print('Gapless skip to previous failed, falling back: $e');
          }
        }
      }
    }
    
    // Use atomic transition manager for traditional skip
    if (!await _transitionManager.acquireTransitionLock('skipToPrevious')) {
      _logger.warning('Skip to previous rejected - another transition in progress', 'AudioHandler');
      if (kDebugMode) {
        print('Skip to previous rejected - another transition in progress');
      }
      return;
    }
    
    try {
      // Reset completion handling flags
      _stateManager.setHandlingCompletion(false);
      _stateManager.setTransitioning(false);
      
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
        _logger.info('Restarting current song: ${_stateManager.currentTrack?.name}', 'AudioHandler');
        await _player.seek(Duration.zero);
        if (kDebugMode) {
          print('Restarting current song: ${_stateManager.currentTrack?.name}');
        }
      } else {
        if (await _stateManager.decrementCurrentIndexAtomic()) {
          _logger.info('Skipping to previous track: ${_stateManager.currentTrack?.name}', 'AudioHandler');
          await _playCurrentTrack();
          await _statePersistence.savePlaybackState(_player.position, _player.playing);
          if (kDebugMode) {
            print('Skipping to previous song');
          }
        }
      }
    } finally {
      _transitionManager.releaseTransitionLock();
      _logger.info('Skip to previous completed', 'AudioHandler');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _stateManager.playlist.length) {
      // Use atomic transition manager to prevent race conditions
      if (!await _transitionManager.acquireTransitionLock('skipToQueueItem')) {
        if (kDebugMode) {
          print('Skip to queue item rejected - another transition in progress');
        }
        return;
      }
      
      try {
        // Preserve playing state when skipping to queue item
        final wasPlaying = playbackState.value.playing;
        if (wasPlaying) {
          _userIntendedPlaying = true;
        }
        
        // Reset completion handling flags
        _stateManager.setHandlingCompletion(false);
        _stateManager.setTransitioning(false);
        
        await _stateManager.setCurrentIndexAtomic(index);
        await _playCurrentTrack();
        await _statePersistence.savePlaybackState(_player.position, _player.playing);
      } finally {
        _transitionManager.releaseTransitionLock();
      }
    }
  }

  // Enhanced track loading with gapless support and better error handling
  Future<void> _playCurrentTrack() async {
    _logger.info('_playCurrentTrack called - Playlist: ${_stateManager.playlist.length} tracks, Index: ${_stateManager.currentIndex}, User intent: $_userIntendedPlaying', 'AudioHandler');
    
    if (kDebugMode) {
      print('=== _playCurrentTrack DEBUG START ===');
      print('Playlist size: ${_stateManager.playlist.length}');
      print('Current index: ${_stateManager.currentIndex}');
      print('User intended playing: $_userIntendedPlaying');
    }
    
    if (_stateManager.playlist.isEmpty || _stateManager.currentIndex >= _stateManager.playlist.length) {
      _logger.error('Cannot play current track: playlist empty or index out of bounds', 'AudioHandler');
      if (kDebugMode) {
        print('Cannot play current track: playlist empty or index out of bounds');
        print('=== _playCurrentTrack DEBUG END (ERROR) ===');
      }
      return;
    }

    final track = _stateManager.currentTrack!;
    final artistInfo = track.artistName != null ? ' by ${track.artistName}' : '';
    _logger.info('Playing track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${track.name}$artistInfo', 'AudioHandler');
    
    if (kDebugMode) {
      print('Playing track ${_stateManager.currentIndex + 1}/${_stateManager.playlist.length}: ${track.name}');
    }
    
    // Update current media item immediately
    mediaItem.add(_trackToMediaItem(track));
    
    // Update Touch Bar with new track
    if (Platform.isMacOS) {
      _updateTouchBarWithCurrentTrack();
      _loadLyricsForCurrentTrack();
    }
    
    // Store playing state for background compatibility
    final wasPlaying = playbackState.value.playing;
    
    // Don't override user intent - if playPlaylist() set it to true, keep it
    // This preserves the user's explicit action to start playback
    if (kDebugMode) {
      print('Playing track with user intent: $_userIntendedPlaying, was previously playing: $wasPlaying');
    }
    
    // Try gapless playback first if enabled and conditions are met
    if (_stateManager.gaplessPlaybackEnabled && _stateManager.playlist.length > 1) {
      _logger.info('Attempting gapless playback for playlist', 'AudioHandler');
      if (kDebugMode) {
        print('Attempting gapless playback...');
      }
      final gaplessResult = await _tryGaplessPlayback();
      if (gaplessResult) {
        _logger.info('Successfully initiated gapless playback', 'AudioHandler');
        if (kDebugMode) {
          print('Successfully initiated gapless playback for playlist');
          print('=== _playCurrentTrack DEBUG END (GAPLESS) ===');
        }
        return;
      }
      _logger.warning('Gapless playback failed, falling back to individual track', 'AudioHandler');
      if (kDebugMode) {
        print('Gapless playback failed, falling back to individual track');
      }
    }
    
    // Fall back to individual track playback
    _logger.info('Using individual track playback', 'AudioHandler');
    if (kDebugMode) {
      print('Playing individual track...');
    }
    await _playIndividualTrack(track, wasPlaying);
    
    _logger.info('_playCurrentTrack completed', 'AudioHandler');
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
        // Use _userIntendedPlaying directly instead of checking _player.playing
        // because the player state might not be updated immediately after play() call
        _updatePlaybackState(playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
          playing: _userIntendedPlaying,
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

  /// Play individual track
  Future<void> _playIndividualTrack(Track track, bool wasPlaying) async {
    // Disable concatenation mode
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    
    // Use user intent instead of previous playing state for automatic transitions
    final shouldPlay = _userIntendedPlaying;
    
    if (kDebugMode) {
      print('Individual track playback - wasPlaying: $wasPlaying, userIntended: $_userIntendedPlaying, shouldPlay: $shouldPlay');
    }
    
    // Update to loading state preserving user intent
    _updatePlaybackState(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: _stateManager.currentIndex,
      playing: shouldPlay, // Use user intent, not previous state
    ));
    
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
    
    // Load and play the track using user intent
    await _loadAndPlayTrack(track, shouldPlay);
    
    // Start preloading after current track is loaded
    Future.delayed(const Duration(milliseconds: 200), () {
      _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
    });
  }

  Future<void> _loadAndPlayTrack(Track track, bool shouldPlay) async {
    _logger.info('Loading track: ${track.name}, shouldPlay: $shouldPlay', 'AudioHandler');
    if (kDebugMode) {
      print('Loading track: ${track.name}, should play: $shouldPlay');
    }
    
    // Activate audio session before loading (iOS specific)
    try {
      final audioSession = await AudioSession.instance;
      await audioSession.setActive(true);
      _logger.debug('Audio session activated', 'AudioHandler');
      if (kDebugMode) {
        print('Audio session activated for track loading');
      }
    } catch (e) {
      _logger.warning('Failed to activate audio session: $e', 'AudioHandler');
      if (kDebugMode) {
        print('Failed to activate audio session: $e');
      }
    }
    
    // Try local file first
    final localFilePath = _downloadService.getLocalFilePath(track.id);
    
    if (localFilePath != null) {
      final localFile = File(localFilePath);
      if (await localFile.exists()) {
        _logger.info('Found local file for track: ${track.name}', 'AudioHandler');
        try {
          await _player.setFilePath(localFilePath);
          
          // iOS needs longer delays for audio initialization
          if (Platform.isIOS) {
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          
          if (shouldPlay) {
            await _player.play();
            _logger.info('Auto-playing local file: ${track.name}', 'AudioHandler');
            if (kDebugMode) {
              print('Auto-playing local file: ${track.name} - should play: true');
            }
          } else {
            _logger.info('Loaded local file (not auto-playing): ${track.name}', 'AudioHandler');
            if (kDebugMode) {
              print('Not auto-playing local file: ${track.name} - should play: false');
            }
          }
          
          // Update playback state after successful load
          // Use shouldPlay directly instead of checking _player.playing
          // because the player state might not be updated immediately after play() call
          _updatePlaybackState(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: shouldPlay,
            queueIndex: _stateManager.currentIndex,
          ));
          
          _logger.info('Successfully loaded local file, playing: ${_player.playing}', 'AudioHandler');
          if (kDebugMode) {
            print('Successfully loaded local file: ${track.name}, playing: ${_player.playing}');
          }
          return;
        } catch (e) {
          _logger.error('Failed to play local file: $e', 'AudioHandler');
          if (kDebugMode) {
            print('Failed to play local file: $e');
          }
        }
      }
    }
    
    // Stream the track with enhanced error handling and platform-specific optimizations
    _logger.info('Streaming track: ${track.name} (Platform: ${Platform.operatingSystem})', 'AudioHandler');
    List<String> streamUrls;
    
    // Use MediaServiceManager if available, otherwise fallback to JellyfinService
    final mediaServiceManager = _mediaServiceManager;
    
    if (mediaServiceManager != null) {
      // Get multiple stream URLs for better fallback support
      streamUrls = [];
      
      // Try different stream URL approaches based on server type
      final serverType = mediaServiceManager.currentServerType;
      _logger.debug('Using MediaServiceManager for ${serverType.toString()} service', 'AudioHandler');
      
      // Add primary stream URL
      final primaryUrl = mediaServiceManager.getStreamUrl(track.id);
      if (primaryUrl.isNotEmpty) {
        streamUrls.add(primaryUrl);
      }
      
      // Add alternative URLs based on service type
      try {
        if (serverType.toString().contains('plex')) {
          // For Plex, try different file formats and endpoints
          final baseUrl = primaryUrl.split('?')[0]; // Remove query params
          final token = primaryUrl.contains('X-Plex-Token=') 
              ? primaryUrl.split('X-Plex-Token=')[1].split('&')[0] 
              : '';
          
          if (token.isNotEmpty) {
            final trackPath = baseUrl.replaceAll('/file.mp3', '');
            streamUrls.addAll([
              '$trackPath/file?X-Plex-Token=$token',                    // Direct file
              '$trackPath/file.mp3?audioBitrate=128&X-Plex-Token=$token', // Lower bitrate
              '$trackPath?X-Plex-Token=$token',                         // Universal endpoint
            ]);
          }
        } else if (serverType.toString().contains('navidrome')) {
          // For Navidrome, try different endpoints
          final baseUrl = primaryUrl.split('?')[0];
          final queryParams = primaryUrl.contains('?') ? primaryUrl.split('?')[1] : '';
          
          if (queryParams.isNotEmpty) {
            streamUrls.addAll([
              '${baseUrl.replaceAll('/stream', '/download')}?$queryParams', // Download endpoint
              '$baseUrl?$queryParams&format=mp3',                        // Force MP3 format
              '$baseUrl?$queryParams&maxBitRate=128',                    // Lower bitrate
            ]);
          }
        }
      } catch (e) {
        _logger.warning('Failed to generate alternative stream URLs: $e', 'AudioHandler');
      }
      
      // Remove duplicates and empty URLs
      streamUrls = streamUrls.where((url) => url.isNotEmpty).toSet().toList();
      _logger.debug('Generated ${streamUrls.length} stream URLs for ${serverType.toString()}', 'AudioHandler');
      
      if (kDebugMode) {
        print('=== STREAM URLs GENERATED ===');
        print('Service: ${serverType.toString()}');
        print('Total URLs: ${streamUrls.length}');
        for (int i = 0; i < streamUrls.length; i++) {
          print('URL ${i + 1}: ${streamUrls[i]}');
        }
        print('=== END STREAM URLs ===');
      }
    } else {
      // Fallback to JellyfinService for backward compatibility
      // Platform-specific URL prioritization for better compatibility
      if (Platform.isIOS) {
        streamUrls = [
          _jellyfinService.getStreamUrl(track.id),          // Transcoded (iOS preferred)
          _jellyfinService.getUniversalStreamUrl(track.id), // Universal fallback
          _jellyfinService.getDirectStreamUrl(track.id),    // Direct (last resort on iOS)
        ];
        _logger.debug('Using iOS-optimized Jellyfin stream URL order (fallback)', 'AudioHandler');
      } else if (Platform.isMacOS) {
        // macOS: Try universal first, then transcoded, then direct
        streamUrls = [
          _jellyfinService.getUniversalStreamUrl(track.id), // Universal (macOS preferred)
          _jellyfinService.getStreamUrl(track.id),          // Transcoded fallback
          _jellyfinService.getDirectStreamUrl(track.id),    // Direct (last resort)
        ];
        _logger.debug('Using macOS-optimized Jellyfin stream URL order (fallback)', 'AudioHandler');
      } else {
        streamUrls = [
          _jellyfinService.getDirectStreamUrl(track.id),    // Direct (Android preferred)
          _jellyfinService.getStreamUrl(track.id),          // Transcoded fallback
          _jellyfinService.getUniversalStreamUrl(track.id), // Universal fallback
        ];
        _logger.debug('Using Android-optimized Jellyfin stream URL order (fallback)', 'AudioHandler');
      }
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
          
          _logger.info('Attempting stream ${i + 1}/${streamUrls.length} ($platformOptimization)', 'AudioHandler');
          if (kDebugMode) {
            print('=== TRYING STREAM URL ${i + 1}/${streamUrls.length} ===');
            print('Platform optimization: $platformOptimization');
            print('Full URL: $streamUrl');
            print('Track: ${track.name} (ID: ${track.id})');
          }
          
          if (_shouldTranscodeTrack(track)) {
            final hlsUrl = _getHlsStreamUrl(track);
            if (hlsUrl.isNotEmpty) {
              _logger.info('Creating HLS audio source - URL: $hlsUrl', 'AudioHandler');
              await _player.setAudioSource(HlsAudioSource(Uri.parse(hlsUrl)));
              _logger.info('HLS audio source set successfully for: ${track.name}', 'AudioHandler');
              if (kDebugMode) {
                print('Using HLS stream for: ${track.name}');
              }
            } else {
              _logger.info('Setting regular stream URL: $streamUrl', 'AudioHandler');
              await _player.setUrl(streamUrl);
              _logger.info('Regular stream URL set successfully for: ${track.name}', 'AudioHandler');
              if (kDebugMode) {
                print('Using regular stream URL for: ${track.name}');
              }
            }
          } else {
            _logger.info('Setting direct stream URL: $streamUrl', 'AudioHandler');
            await _player.setUrl(streamUrl);
            _logger.info('Direct stream URL set successfully for: ${track.name}', 'AudioHandler');
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
          
          if (shouldPlay) {
            _logger.info('Attempting to play stream - calling _player.play()', 'AudioHandler');
            await _player.play();
            _logger.info('_player.play() completed - Player state: playing=${_player.playing}, processingState=${_player.processingState}', 'AudioHandler');
            if (kDebugMode) {
              print('Auto-playing stream: ${track.name} - should play: true');
            }
          } else {
            _logger.info('Stream loaded (not auto-playing): ${track.name}', 'AudioHandler');
            if (kDebugMode) {
              print('Not auto-playing stream: ${track.name} - should play: false');
            }
          }
          
          // Update playback state after successful load
          // Use shouldPlay directly instead of checking _player.playing
          // because the player state might not be updated immediately after play() call
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: shouldPlay,
            queueIndex: _stateManager.currentIndex,
          ));
          
          loaded = true;
          _logger.info('Successfully loaded stream, playing: ${_player.playing}', 'AudioHandler');
          if (kDebugMode) {
            print('=== STREAM LOAD SUCCESS ===');
            print('Successfully loaded stream: ${track.name}');
            print('Playing: ${_player.playing}');
            print('URL used: $streamUrl');
            print('=== STREAM LOAD SUCCESS END ===');
          }
          break;
        }
      } catch (e) {
        lastError = e as Exception?;
        _logger.warning('Failed to load stream URL ${i + 1}/${streamUrls.length}: $e', 'AudioHandler');
        if (kDebugMode) {
          print('=== STREAM LOAD FAILED ===');
          print('Failed URL ${i + 1}/${streamUrls.length}: $streamUrl');
          print('Error: $e');
          print('=== STREAM LOAD FAILED END ===');
        }
        
        // Platform-specific URL retry logic
        if ((Platform.isIOS || Platform.isMacOS) && i < streamUrls.length - 1) {
          _logger.info('Trying next stream URL...', 'AudioHandler');
          if (kDebugMode) {
            print('${Platform.isIOS ? "iOS" : "macOS"}: Trying next stream URL immediately...');
          }
          continue;
        }
      }
    }
    
    if (!loaded) {
      _logger.error('Failed to load any stream for track: ${track.name}, last error: $lastError', 'AudioHandler');
      
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
    _logger.info('=== PLAY TRACK REQUEST START ===', 'AudioHandler');
    _logger.info('Track: ${track.name} (ID: ${track.id})', 'AudioHandler');
    _logger.info('Artist: ${track.artistName ?? "Unknown"}', 'AudioHandler');
    _logger.info('Album: ${track.albumName ?? "Unknown"}', 'AudioHandler');
    _logger.info('Duration: ${track.duration != null ? "${track.duration! ~/ 1000}s" : "Unknown"}', 'AudioHandler');
    
    // Set user intent to playing since this is an explicit play action
    _userIntendedPlaying = true;
    _logger.info('User intent set to playing', 'AudioHandler');
    
    // Clear existing state - single track doesn't use concatenation
    _logger.info('Stopping existing player', 'AudioHandler');
    await _player.stop();
    _preloader.clearAllPreloadedPlayers();
    _audioSourceCache.clear();
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    _logger.info('Cleared existing player state and cache', 'AudioHandler');
    
    // Reset all transition states atomically
    await _transitionManager.waitForTransitionComplete();
    _stateManager.setHandlingCompletion(false);
    _stateManager.setTransitioning(false);
    _logger.info('Reset transition states', 'AudioHandler');
    
    _queueManager.setSingleTrack(track);
    _logger.info('Set single track in queue manager', 'AudioHandler');
    
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      queueIndex: 0,
    ));
    _logger.info('Updated playback state to loading', 'AudioHandler');
    
    _logger.info('Calling _playCurrentTrack()', 'AudioHandler');
    await _playCurrentTrack();
    _logger.info('=== PLAY TRACK REQUEST END ===', 'AudioHandler');
    
    if (kDebugMode) {
      print('Single track playbook initiated: ${track.name}');
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    _logger.info('Playing playlist: ${tracks.length} tracks, starting at index $startIndex', 'AudioHandler');
    
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
          // Use MediaServiceManager if available, otherwise fall back to JellyfinService
          final mediaServiceManager = _mediaServiceManager;
          final imageUrl = mediaServiceManager != null 
            ? mediaServiceManager.getImageUrl(track.imageUrl!, width: 300, height: 300)
            : _jellyfinService.getImageUrl(track.imageUrl!, width: 300, height: 300);
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

  bool get normalizeVolumeEnabled => _stateManager.normalizeVolumeEnabled;
  bool get gaplessPlaybackEnabled => _stateManager.gaplessPlaybackEnabled;
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  PlayerState get playerState => _player.playerState;

  // Volume control
  Stream<double> get volumeStream => _player.volumeStream;
  double get volume => _player.volume;
  
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  // Volume convenience methods
  double? _previousVolume;
  
  Future<void> toggleMute() async {
    if (_player.volume > 0.0) {
      _previousVolume = _player.volume;
      await setVolume(0.0);
    } else {
      await setVolume(_previousVolume ?? 1.0);
    }
  }
  
  Future<void> volumeUp([double step = 0.1]) async {
    await setVolume((_player.volume + step).clamp(0.0, 1.0));
  }
  
  Future<void> volumeDown([double step = 0.1]) async {
    await setVolume((_player.volume - step).clamp(0.0, 1.0));
  }

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
        
        // Use MediaServiceManager if available to get multiple fallback URLs
        final mediaServiceManager = _mediaServiceManager;
        final streamUrls = <String>[];
        if (mediaServiceManager != null) {
          // Prefer explicit alternative URLs if the service provides them
          final alt = mediaServiceManager.getAlternativeStreamUrls(currentTrack.id);
          if (alt.isNotEmpty) {
            streamUrls.addAll(alt);
          } else {
            // Fallback to single canonical URL
            final primary = mediaServiceManager.getStreamUrl(currentTrack.id);
            if (primary.isNotEmpty) streamUrls.add(primary);
          }
        } else {
          // Legacy Jellyfin-only fallback order
          streamUrls.addAll([
            _jellyfinService.getDirectStreamUrl(currentTrack.id),
            _jellyfinService.getStreamUrl(currentTrack.id),
            _jellyfinService.getUniversalStreamUrl(currentTrack.id),
          ]);
        }
        
        bool loaded = false;
        for (final streamUrl in streamUrls) {
          if (streamUrl.isEmpty) continue;
          try {
            final ok = await _probeUrl(streamUrl);
            if (!ok) {
              if (kDebugMode) print('Skipping unreachable URL: $streamUrl');
              continue;
            }
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
    // Use MediaServiceManager if available, otherwise fallback to JellyfinService
    final mediaServiceManager = _mediaServiceManager;
    final streamUrl = mediaServiceManager != null 
      ? mediaServiceManager.getStreamUrl(track.id)
      : _jellyfinService.getStreamUrl(track.id);
    if (streamUrl.isEmpty) return '';
    
    final baseUrl = streamUrl.split('/Audio/')[0];
    final urlParts = streamUrl.split('api_key=');
    if (urlParts.length < 2) return '';
    
    final apiKey = urlParts[1].split('&')[0];
    return '$baseUrl/Audio/${track.id}/main.m3u8?ApiKey=$apiKey&audioCodec=aac&audioSampleRate=44100&maxAudioBitDepth=16&audioBitRate=320000';
  }

  /// Probe a URL with a lightweight HEAD request to ensure it's reachable.
  /// Returns true if the URL responds with a 2xx status within a short timeout.
  Future<bool> _probeUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.openUrl('HEAD', uri);
      final response = await request.close().timeout(const Duration(seconds: 5));
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      client.close(force: true);
      if (kDebugMode) {
        print('Probe ${ok ? 'OK' : 'FAIL'} for $url (status: ${response.statusCode})');
      }
      return ok;
    } catch (e) {
      if (kDebugMode) {
        print('Probe error for $url: $e');
      }
      return false;
    }
  }

  Future<void> dispose() async {
    _statePersistence.dispose();
    _preloader.dispose();
    _audioSourceCache.clear();
    _isUsingConcatenation = false;
    _concatenatingSource = null;
    
    // Dispose Touch Bar on macOS
    if (Platform.isMacOS) {
      _disposeTouchBar();
    }
    
    try {
      await _player.dispose();
    } catch (e) {
      // Handle platform-specific limitations (e.g., MissingPluginException on Linux)
      if (kDebugMode) {
        print('Audio player disposal error (this may be expected on some platforms): $e');
      }
    }
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
          return _albums.map((album) {
            // Use MediaServiceManager if available, otherwise fall back to JellyfinService
            final mediaServiceManager = _mediaServiceManager;
            final imageUrl = album.imageUrl != null 
              ? (mediaServiceManager != null 
                  ? mediaServiceManager.getImageUrl(album.imageUrl!, width: 300, height: 300)
                  : _jellyfinService.getImageUrl(album.imageUrl!, width: 300, height: 300))
              : null;
            
            return MediaItem(
              id: 'album:${album.id}',
              title: album.name,
              album: album.name,
              artist: album.artistName ?? 'Unknown Artist',
              artUri: imageUrl != null ? Uri.parse(imageUrl) : null,
              playable: true,
              extras: {'browsable': true},
            );
          }).toList();

        case 'artists':
          if (_artists.isEmpty) {
            if (kDebugMode) {
              print('AudioHandler: No artists available');
            }
            return [];
          }
          return _artists.map((artist) {
            // Use MediaServiceManager if available, otherwise fall back to JellyfinService
            final mediaServiceManager = _mediaServiceManager;
            final imageUrl = artist.imageUrl != null 
              ? (mediaServiceManager != null 
                  ? mediaServiceManager.getImageUrl(artist.imageUrl!, width: 300, height: 300)
                  : _jellyfinService.getImageUrl(artist.imageUrl!, width: 300, height: 300))
              : null;
            
            return MediaItem(
              id: 'artist:${artist.id}',
              title: artist.name,
              album: '',
              artist: artist.name,
              artUri: imageUrl != null ? Uri.parse(imageUrl) : null,
              playable: false,
              extras: {'browsable': true},
            );
          }).toList();

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
              // Use MediaServiceManager if available, otherwise fall back to JellyfinService
              // Use MediaServiceManager if available, otherwise fall back to JellyfinService
              final mediaServiceManager = _mediaServiceManager;
              final tracks = mediaServiceManager != null 
                ? await mediaServiceManager.getTracks(parentId: albumId)
                : await _jellyfinService.getAlbumTracks(albumId);
              
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
              final mediaServiceManager = _mediaServiceManager;
              final allAlbums = mediaServiceManager != null 
                ? await mediaServiceManager.getAlbums()
                : await _jellyfinService.getAlbums();
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
                  // Use MediaServiceManager if available, otherwise fall back to JellyfinService
                  final mediaServiceManager = _mediaServiceManager;
                  final imageUrl = album.imageUrl != null 
                    ? (mediaServiceManager != null 
                        ? mediaServiceManager.getImageUrl(album.imageUrl!, width: 300, height: 300)
                        : _jellyfinService.getImageUrl(album.imageUrl!, width: 300, height: 300))
                    : null;
                  
                  return MediaItem(
                    id: 'album:${album.id}',
                    title: album.name,
                    album: album.name,
                    artist: album.artistName ?? 'Unknown Artist',
                    artUri: imageUrl != null ? Uri.parse(imageUrl) : null,
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
              // Use MediaServiceManager if available, otherwise fall back to JellyfinService
              final mediaServiceManager = _mediaServiceManager;
              final tracks = mediaServiceManager != null 
                ? await mediaServiceManager.getPlaylistTracks(playlistId)
                : await _jellyfinService.getPlaylistTracks(playlistId);
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
        final mediaServiceManager = _mediaServiceManager;
        final tracks = mediaServiceManager != null 
          ? await mediaServiceManager.getTracks(parentId: albumId)
          : await _jellyfinService.getAlbumTracks(albumId);
        if (tracks.isNotEmpty) {
          await playPlaylist(tracks, 0);
        }
      } else if (mediaItem.id.startsWith('playlist:')) {
        final playlistId = mediaItem.id.substring(9);
        final mediaServiceManager = _mediaServiceManager;
        final tracks = mediaServiceManager != null 
          ? await mediaServiceManager.getPlaylistTracks(playlistId)
          : await _jellyfinService.getPlaylistTracks(playlistId);
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

  /// Initialize Touch Bar service and set up callbacks
  void _initializeTouchBar() async {
    if (!Platform.isMacOS) return;
    
    try {
      // Initialize the TouchBar service
      await TouchBarService.initialize();
      
      // Set up callbacks for TouchBar button presses
      TouchBarService.setCallbacks(
        onPlayPause: () {
          if (playbackState.value.playing) {
            pause();
          } else {
            play();
          }
        },
        onPrevious: () => skipToPrevious(),
        onNext: () => skipToNext(),
        onFavorite: () {
          // Toggle favorite status for current track
          final currentTrack = _stateManager.currentTrack;
          if (currentTrack != null) {
            // This would need to be implemented to toggle favorite in Jellyfin
            if (kDebugMode) {
              print('TouchBar: Toggle favorite for ${currentTrack.name}');
            }
          }
        },
      );
      
      if (kDebugMode) {
        print('TouchBar initialized with callbacks');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize TouchBar: $e');
      }
      _touchBarEnabled = false;
    }
  }

  void _updateTouchBarWithCurrentTrack() {
    if (!_touchBarEnabled) return;
    
    final currentTrack = _stateManager.currentTrack;
    TouchBarService.updateNowPlaying(currentTrack);
  }

  void _updateTouchBarPlaybackState() {
    if (!_touchBarEnabled) return;
    
    final currentTrack = _stateManager.currentTrack;
    TouchBarService.updatePlaybackState(
      isPlaying: playbackState.value.playing,
      position: playbackState.value.position,
      duration: currentTrack?.duration != null 
        ? Duration(milliseconds: currentTrack!.duration!)
        : Duration.zero,
      isFavorite: currentTrack?.isFavorite ?? false,
    );
  }

  void _updateTouchBarLyrics(Duration position) {
    if (!_touchBarEnabled || _currentLyrics?.syncedLyrics == null) return;
    
    final syncedLyrics = _currentLyrics!.syncedLyrics!;
    if (syncedLyrics.isEmpty) return;
    
    // Find the current lyrics line based on position
    int newLineIndex = -1;
    for (int i = 0; i < syncedLyrics.length; i++) {
      if (syncedLyrics[i].timestamp <= position) {
        newLineIndex = i;
      } else {
        break;
      }
    }
    
    // Only update TouchBar if line actually changed and we have a valid line
    if (newLineIndex != _currentLyricsLineIndex && newLineIndex >= 0 && newLineIndex < syncedLyrics.length) {
      _currentLyricsLineIndex = newLineIndex;
      
      final lyricsText = syncedLyrics[newLineIndex].text;
      
      // Only update if we have valid lyrics text
      if (lyricsText.trim().isNotEmpty) {
        TouchBarService.updateLyrics(lyricsText);
        
        if (kDebugMode) {
          print('TouchBar lyrics updated: $lyricsText');
        }
      }
    }
    // Keep the last valid lyrics visible - don't clear when no current line
  }

  void _loadLyricsForCurrentTrack() async {
    if (!_touchBarEnabled) return;
    
    final currentTrack = _stateManager.currentTrack;
    if (currentTrack == null) {
      _currentLyrics = null;
      _currentLyricsLineIndex = -1;
      _lastLyricsTrackId = null;
      TouchBarService.updateLyrics(null);
      return;
    }
    
    // Skip if we already have lyrics for this track
    if (_lastLyricsTrackId == currentTrack.id && _currentLyrics != null) {
      return;
    }
    
    try {
      if (kDebugMode) {
        print('Loading lyrics for: ${currentTrack.name} - ${currentTrack.artistName ?? 'Unknown Artist'}');
      }
      
      final lyricsResult = await LyricsService.fetchLyrics(
        currentTrack.name,
        currentTrack.artistName ?? 'Unknown Artist',
      );
      
      if (lyricsResult != null && lyricsResult.hasSyncedLyrics) {
        _currentLyrics = lyricsResult;
        _currentLyricsLineIndex = -1;
        _lastLyricsTrackId = currentTrack.id;
        
        // Initialize TouchBar with first available lyrics line if playing
        if (lyricsResult.syncedLyrics!.isNotEmpty && _player.playing) {
          final currentPosition = _player.position;
          _updateTouchBarLyrics(currentPosition);
        }
        
        if (kDebugMode) {
          print('Loaded synced lyrics for TouchBar with ${lyricsResult.syncedLyrics?.length ?? 0} lines');
        }
      } else {
        _currentLyrics = null;
        _currentLyricsLineIndex = -1;
        _lastLyricsTrackId = currentTrack.id;
        TouchBarService.updateLyrics(null);
        
        if (kDebugMode) {
          print('No synced lyrics available for TouchBar');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading lyrics for TouchBar: $e');
      }
      _currentLyrics = null;
      _currentLyricsLineIndex = -1;
      _lastLyricsTrackId = currentTrack.id;
      TouchBarService.updateLyrics(null);
    }
  }

  void _disposeTouchBar() {
    if (_touchBarEnabled) {
      TouchBarService.dispose();
      _touchBarEnabled = false;
    }
  }
}