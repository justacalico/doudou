import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
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
import 'async_mutex.dart';
import 'jellyfin_service_coordinator.dart';
import 'error_state_manager.dart';
import 'audio_session_coordinator.dart';
import 'player_state_transition_coordinator.dart';
import 'audio_operation_queue.dart';
import 'audio_state_machine.dart';
import 'operation_cancellation.dart';
import 'android_service_manager.dart';
import 'audio_position_manager.dart';
import 'state_persistence_manager.dart';
import 'radio_mode_state_manager.dart';
import 'touchbar_update_manager.dart';
import 'download_service_coordinator.dart';
import 'media_service_manager_coordinator.dart';

class DoudouAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  final DownloadService _downloadService;
  final MediaServiceManager? _mediaServiceManager;
  
  // Android foreground service management with immutable state
  final AndroidServiceManager _androidServiceManager = AndroidServiceManager();
  
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
  
  // State persistence with debouncing to prevent file corruption
  late final StatePersistenceManager _statePersistenceManager;
  
  // Radio mode state synchronization to prevent UI/streaming inconsistencies 
  late final RadioModeStateManager _radioModeStateManager;
  late final RadioModeOperationManager _radioModeOperationManager;
  
  // Touch Bar update synchronization for macOS to prevent visual glitches
  late final TouchBarUpdateManager _touchBarUpdateManager;
  
  // Download service coordination to prevent interference with audio streaming
  late final DownloadServiceCoordinator _downloadServiceCoordinator;
  
  // Media service manager coordination to prevent disposal race conditions
  late final MediaServiceManagerCoordinator? _mediaServiceManagerCoordinator;

  // Jellyfin service coordination to prevent API timeout race conditions
  late final JellyfinServiceCoordinator _jellyfinServiceCoordinator;

  // Centralized error state management to prevent conflicting error handling
  late final ErrorStateManager _errorStateManager;

  // iOS audio session coordination to prevent race conditions
  late final AudioSessionCoordinator _audioSessionCoordinator;

  // Player state transition coordination to prevent state machine race conditions
  late final PlayerStateTransitionCoordinator _playerStateTransitionCoordinator;

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

  // RACE CONDITION PROTECTION: Modern async synchronization
  // Replace custom spinlocks with proper async mutex
  final NamedMutexManager _mutexManager = NamedMutexManager();
  
  // Operation queue to prevent concurrent AudioPlayer operations
  final AudioOperationQueue _playerOperationQueue = AudioOperationQueue();
  
  // State machine for synchronized player state and user intent
  final AudioStateMachine _stateMachine = AudioStateMachine();
  
  // Cancellation manager for preventing operation race conditions
  final OperationCancellationManager _cancellationManager = OperationCancellationManager();
  
  // Position manager for atomic position updates
  final AudioPositionManager _positionManager = AudioPositionManager();

  // Legacy user intent tracking - will be replaced by state machine
  bool _userIntendedPlaying = false;
  bool _userExplicitlyPaused = false; // Track intentional user pause

  // Position tracking for pause/resume to prevent position jumping
  Duration? _pausedAtPosition;

  // Codec loop detection with synchronized access
  DateTime? _lastBufferingTime;
  int _bufferingLoopCount = 0;
  
  // Volume state protection
  double? _previousVolume;
  
  // Lyrics state protection - no longer needs locks with proper state management
  
  // Completion handling protection - managed by transition manager
  
  // Track loading protection to prevent concurrent loads causing "Loading interrupted"
  // Now handled by operation queue
  
  // Helper methods for safe state management using async mutex
  Future<void> _setConcatenationState(bool usingConcatenation, [ConcatenatingAudioSource? source]) async {
    return await _mutexManager.withLock('concatenationState', () async {
      _isUsingConcatenation = usingConcatenation;
      _concatenatingSource = source;
    });
  }
  
  Future<bool> _isConcatenationActive() async {
    return await _mutexManager.withLock('concatenationState', () async {
      return _isUsingConcatenation && _concatenatingSource != null;
    });
  }
  
  // Helper method for debounced state persistence to prevent file corruption
  void _savePlaybackStateDebounced({Duration? position, bool? isPlaying}) {
    if (position != null && isPlaying != null) {
      // Create specific save function for provided state
      final specificManager = StatePersistenceManager(
        saveFunction: () => _statePersistence.savePlaybackState(position, isPlaying),
        debounceDelay: const Duration(milliseconds: 300),
      );
      specificManager.requestSave();
    } else {
      // Use general manager for current player state
      _statePersistenceManager.requestSave();
    }
  }
  
  Future<void> _clearAudioSourceCache() async {
    return await _mutexManager.withLock('audioSourceCache', () async {
      _audioSourceCache.clear();
    });
  }
  
  Future<void> _setUserIntentAtomic(bool intendedPlaying) async {
    return await _mutexManager.withLock('userIntent', () async {
      if (kDebugMode) {
        print('Setting user intent atomically: $_userIntendedPlaying -> $intendedPlaying');
      }
      
      final previousIntent = _userIntendedPlaying;
      _userIntendedPlaying = intendedPlaying;
      
      // Clear explicit pause flag when user intends to play
      if (intendedPlaying) {
        _userExplicitlyPaused = false;
      }
      
      // Update audio session coordinator for interruption handling
      _audioSessionCoordinator.setUserIntendedPlaying(intendedPlaying);
      
      // Update state machine intent
      if (intendedPlaying) {
        _stateMachine.setIntent(UserIntent.play);
      } else {
        _stateMachine.setIntent(UserIntent.pause);
      }
      
      // If intent changed, trigger immediate state verification
      if (previousIntent != intendedPlaying) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _verifyUserIntentAlignment();
        });
      }
      
      if (kDebugMode) {
        print('User intent updated successfully: $intendedPlaying');
      }
    });
  }
  
  /// Verifies that the actual player state aligns with user intent and corrects if needed
  Future<void> _verifyUserIntentAlignment() async {
    // Skip verification during transitions to avoid interference
    if (_transitionManager.isTransitionInProgress || _stateManager.isHandlingCompletion) {
      return;
    }
    
    final playerPlaying = _player.playing;
    final userWantsPlaying = _userIntendedPlaying && !_userExplicitlyPaused;
    final processingState = _player.processingState;
    
    // Only verify for ready state to avoid interfering with loading/buffering
    if (processingState != ProcessingState.ready) {
      return;
    }
    
    if (playerPlaying != userWantsPlaying) {
      if (kDebugMode) {
        print('USER INTENT MISALIGNMENT: Player=$playerPlaying, UserWants=$userWantsPlaying, Intended=$_userIntendedPlaying, ExplicitPause=$_userExplicitlyPaused');
      }
      
      try {
        if (userWantsPlaying && !playerPlaying) {
          if (kDebugMode) {
            print('Correcting: Starting playback to align with user intent');
          }
          await _player.play();
        } else if (!userWantsPlaying && playerPlaying) {
          if (kDebugMode) {
            print('Correcting: Pausing playback to align with user intent');
          }
          await _player.pause();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to correct user intent alignment: $e');
        }
      }
    }
  }

  
  Future<void> _updateBufferingLoop() async {
    return await _mutexManager.withLock('bufferingState', () async {
      final now = DateTime.now();
      if (_lastBufferingTime != null && 
          now.difference(_lastBufferingTime!) < const Duration(seconds: 10)) {
        _bufferingLoopCount++;
      } else {
        _bufferingLoopCount = 0;
      }
      _lastBufferingTime = now;
    });
  }
  
  Future<bool> _shouldHandleCodecLoop() async {
    return await _mutexManager.withLock('bufferingState', () async {
      return _bufferingLoopCount >= 25;
    });
  }
  
  Future<void> _resetBufferingLoop() async {
    return await _mutexManager.withLock('bufferingState', () async {
      _bufferingLoopCount = 0;
      _lastBufferingTime = null;
    });
  }
  
  // Helper method to completely clear and reset player state
  Future<void> _resetPlayerStateCompletely() async {
    return await _playerOperationQueue.enqueue('resetPlayerState', () async {
      _logger.info('Completely resetting player state', 'AudioHandler');
      
      // Stop player first and wait for it to fully stop
      await _errorStateManager.executeWithErrorHandling(
        component: 'AudioHandler',
        operation: 'stopPlayer',
        category: ErrorCategory.playback,
        severity: ErrorSeverity.medium,
        action: () async {
          await _player.stop();
          
          // Wait for player to fully stop and release all resources
          await Future.delayed(const Duration(milliseconds: 200));
          
          _logger.info('Player stopped successfully', 'AudioHandler');
        },
        context: {'operation': 'resetPlayerState'},
      );
      
      // Clear all caches and state atomically
      await _clearAudioSourceCache();
      await _setConcatenationState(false, null);
      _preloader.clearAllPreloadedPlayers();
      
      // Reset transition states
      await _transitionManager.waitForTransitionComplete();
      _stateManager.setHandlingCompletion(false);
      _stateManager.setTransitioning(false);
      
      // CRITICAL FIX: Clear the current track reference to prevent old track confusion
      _stateManager.setCurrentTrack(null);
      
      // Additional delay to ensure all audio sources are properly released
      await Future.delayed(const Duration(milliseconds: 300));
      
      _logger.info('Player state reset completed', 'AudioHandler');
    });
  }

  // Helper method to update playback state while preventing automatic buffering pauses
  void _updatePlaybackState(PlaybackState newState) {
    if (kDebugMode) {
      print('=== _updatePlaybackState CALLED ===');
      print('DateTime: ${DateTime.now()}');
      print('Input newState.playing: ${newState.playing}');
      print('Input newState.processingState: ${newState.processingState}');
      print('Current _userIntendedPlaying: $_userIntendedPlaying');
      print('Current _userExplicitlyPaused: $_userExplicitlyPaused');
      print('Previous playbackState.playing: ${playbackState.value.playing}');
    }
    
    PlaybackState finalState = newState;
    
    // Simplified state synchronization - prioritize user intent over complex logic
    final shouldBePlaying = _getUserIntentedPlayState(newState);
    
    // Update state machine based on processing state
    switch (newState.processingState) {
      case AudioProcessingState.loading:
        _stateMachine.transitionTo(AudioPlayerState.loading);
        _positionManager.setBuffering(true);
        break;
      case AudioProcessingState.ready:
        _stateMachine.transitionTo(AudioPlayerState.ready);
        _positionManager.setBuffering(false);
        // For ready state, ensure UI reflects user intent
        finalState = newState.copyWith(playing: shouldBePlaying);
        break;
      case AudioProcessingState.buffering:
        _stateMachine.transitionTo(AudioPlayerState.buffering);
        _positionManager.setBuffering(true);
        // During buffering, maintain user intent in UI
        finalState = newState.copyWith(playing: shouldBePlaying);
        break;
      case AudioProcessingState.completed:
        _stateMachine.transitionTo(AudioPlayerState.completed);
        _positionManager.setBuffering(false);
        // Track completed - respect that unless radio mode continues
        finalState = newState.copyWith(playing: false);
        break;
      case AudioProcessingState.error:
        _stateMachine.transitionTo(AudioPlayerState.error);
        _positionManager.setBuffering(false);
        finalState = newState.copyWith(playing: false);
        break;
      case AudioProcessingState.idle:
        _stateMachine.transitionTo(AudioPlayerState.idle);
        _positionManager.setBuffering(false);
        finalState = newState.copyWith(playing: false);
        break;
    }
    
    // Verify actual player state alignment with intended state
    _verifyPlayerStateAlignment(finalState);
    
    // Always update the playback state stream for UI consistency
    try {
      if (kDebugMode) {
        print('=== FINAL PLAYBACK STATE UPDATE ===');
        print('finalState.playing: ${finalState.playing}');
        print('finalState.processingState: ${finalState.processingState}');
        print('shouldBePlaying (user intent): $shouldBePlaying');
        print('About to call playbackState.add(finalState)');
      }
      
      playbackState.add(finalState);
      
      if (kDebugMode) {
        print('Successfully updated playbackState stream');
        print('=== END _updatePlaybackState ===');
      }
    } catch (e) {
      if (kDebugMode) {
        print('=== PLAYBACK STATE UPDATE ERROR ===');
        print('Error updating playback state: $e');
      }
      
      // Handle the error through the service manager (Android-specific)
      if (Platform.isAndroid) {
        final newConfig = _androidServiceManager.handlePlaybackStateError(e);
        
        if (kDebugMode) {
          print('=== ANDROID AUDIOSERVICE ERROR HANDLED ===');
          print('New service state: ${newConfig.description}');
        }
        
        // If we transitioned to bypass mode, skip further AudioService operations
        if (newConfig.shouldBypass) {
          if (kDebugMode) {
            print('Android service manager: Bypassing AudioService for future operations');
          }
        } else {
          if (kDebugMode) {
            print('Error updating playback state (likely Android foreground service): $e');
            print('Attempting fallback playback state update...');
          }
          
          // Fallback: Try without media controls for Android service issues
          try {
            final fallbackState = finalState.copyWith(
              controls: [], // Remove controls that might trigger foreground service
              systemActions: const <MediaAction>{}, // Remove system actions
            );
            playbackState.add(fallbackState);
            
            if (kDebugMode) {
              print('Fallback playback state update successful');
            }
          } catch (fallbackError) {
            if (kDebugMode) {
              print('Fallback playback state update also failed: $fallbackError');
            }
          }
        }
      }
    }
    
    // Update Touch Bar with new playback state
    if (Platform.isMacOS) {
      _updateTouchBarPlaybackState();
    }
  }
  
  /// Determines the intended play state based on user intent and current conditions
  bool _getUserIntentedPlayState(PlaybackState newState) {
    // If user explicitly paused, respect that
    if (_userExplicitlyPaused) {
      return false;
    }
    
    // For ready and buffering states, use user intended playing state
    if (newState.processingState == AudioProcessingState.ready ||
        newState.processingState == AudioProcessingState.buffering) {
      return _userIntendedPlaying;
    }
    
    // For loading state, maintain user intent if available
    if (newState.processingState == AudioProcessingState.loading) {
      return _userIntendedPlaying;
    }
    
    // For completed, error, and idle states, should not be playing
    return false;
  }
  
  /// Verifies that player state aligns with the intended state and triggers recovery if needed
  void _verifyPlayerStateAlignment(PlaybackState finalState) {
    // Only check alignment for ready state to avoid interference during transitions
    if (finalState.processingState != AudioProcessingState.ready) {
      return;
    }
    
    // Check if player state and UI state are misaligned
    final playerActuallyPlaying = _player.playing;
    final uiShouldShowPlaying = finalState.playing;
    
    if (playerActuallyPlaying != uiShouldShowPlaying) {
      if (kDebugMode) {
        print('DETECTED STATE MISALIGNMENT: Player playing=$playerActuallyPlaying, UI playing=$uiShouldShowPlaying');
        print('User intended: $_userIntendedPlaying, User paused: $_userExplicitlyPaused');
      }
      
      // Schedule a recovery attempt after a short delay to avoid immediate conflicts
      Future.delayed(const Duration(milliseconds: 500), () {
        _attemptStateRecovery(uiShouldShowPlaying);
      });
    }
  }
  
  /// Attempts to recover from state misalignment
  Future<void> _attemptStateRecovery(bool shouldBePlaying) async {
    // Only attempt recovery if we're still in a misaligned state
    final currentlyPlaying = _player.playing;
    if (currentlyPlaying == shouldBePlaying) {
      return; // Already aligned
    }
    
    if (kDebugMode) {
      print('Attempting state recovery: should be playing=$shouldBePlaying, currently playing=$currentlyPlaying');
    }
    
    try {
      if (shouldBePlaying && !currentlyPlaying && _userIntendedPlaying && !_userExplicitlyPaused) {
        await _player.play();
        if (kDebugMode) {
          print('Recovery: Started playback');
        }
      } else if (!shouldBePlaying && currentlyPlaying && (!_userIntendedPlaying || _userExplicitlyPaused)) {
        await _player.pause();
        if (kDebugMode) {
          print('Recovery: Paused playback');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('State recovery failed: $e');
      }
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
    
    // Initialize state persistence manager with debouncing
    _statePersistenceManager = StatePersistenceManager(
      saveFunction: () async {
        // Save current player state when no position/playing state is provided
        final position = _player.position;
        final isPlaying = _player.playing;
        await _statePersistence.savePlaybackState(position, isPlaying);
      },
      debounceDelay: const Duration(milliseconds: 300),
    );
    
    // Initialize synchronized radio mode state management
    _radioModeStateManager = RadioModeStateManager();
    _radioModeOperationManager = RadioModeOperationManager(_radioModeStateManager);
    
    // Initialize synchronized Touch Bar update manager for macOS
    _touchBarUpdateManager = TouchBarUpdateManager();
    
    // Initialize download service coordinator to prevent streaming interference
    _downloadServiceCoordinator = DownloadServiceCoordinator(_downloadService);
    
    // Initialize Jellyfin service coordinator to prevent API timeout race conditions
    _jellyfinServiceCoordinator = JellyfinServiceCoordinator(_jellyfinService);
    
    // Initialize centralized error state manager
    _errorStateManager = ErrorStateManager();
    
    // Initialize iOS audio session coordinator
    _audioSessionCoordinator = AudioSessionCoordinator();
    
    // Initialize player state transition coordinator for atomic state management
    _playerStateTransitionCoordinator = PlayerStateTransitionCoordinator();
    
    // Initialize media service manager coordinator if available
    _mediaServiceManagerCoordinator = _mediaServiceManager != null 
        ? MediaServiceManagerCoordinator(_mediaServiceManager)
        : null;
    
    _logger.info('Audio components initialized', 'AudioHandler');
    
    // Initialize Touch Bar service on macOS with synchronized updates
    if (Platform.isMacOS) {
      _touchBarEnabled = true;
      _initializeTouchBar();
      _logger.info('TouchBar initialization started', 'AudioHandler');
    }
    
    // Initialize iOS audio session FIRST before any other audio setup (iOS only)
    if (Platform.isIOS) {
      _audioSessionCoordinator.initialize();
      
      // Listen for audio session events for coordinated handling
      _audioSessionCoordinator.events.listen((event) {
        _handleAudioSessionEvent(event);
      });
    }
    
    // Initialize player state transition coordinator
    _playerStateTransitionCoordinator.initialize();
    
    _init();
    _loadPlaybackState();
  }

  void _init() {
    // Enhanced player state listener for background compatibility with buffering fix
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = _mapProcessingState(playerState.processingState);
      
      // Validate state transition through coordinator (warn but don't block)
      final transitionEvent = _playerStateTransitionCoordinator.mapProcessingStateToEvent(playerState.processingState);
      if (!_playerStateTransitionCoordinator.wouldTransitionBeValid(transitionEvent)) {
        if (kDebugMode) {
          print('Invalid player state transition detected: ${_playerStateTransitionCoordinator.currentState} -> $transitionEvent');
        }
        // Continue processing but note the invalid transition
      }
      
      // Request coordinated state transition (non-blocking)
      _playerStateTransitionCoordinator.requestTransition(transitionEvent, context: {
        'isPlaying': isPlaying,
        'processingState': processingState,
        'userIntended': _userIntendedPlaying,
      });

      if (kDebugMode) {
        print('=== PLAYER STATE STREAM LISTENER ===');
        print('DateTime: ${DateTime.now()}');
        print('Raw player state - isPlaying: $isPlaying, processingState: $processingState');
        print('Current flags - _userIntendedPlaying: $_userIntendedPlaying, _userExplicitlyPaused: $_userExplicitlyPaused');
        print('Previous playback state playing: ${playbackState.value.playing}');
      }
      
      // Determine final playing state based on user intent and current state
      // IMPORTANT: Always respect user intent as the primary source of truth
      bool finalPlayingState;

      if (kDebugMode) {
        print('=== DETERMINING FINAL PLAYING STATE ===');
        print('Condition 1: _userExplicitlyPaused || !_userIntendedPlaying = ${_userExplicitlyPaused || !_userIntendedPlaying}');
        print('Condition 2: _userIntendedPlaying && !_userExplicitlyPaused = ${_userIntendedPlaying && !_userExplicitlyPaused}');
      }
      
      // If user explicitly paused, always show paused regardless of player state
      if (_userExplicitlyPaused || !_userIntendedPlaying) {
        finalPlayingState = false;
        if (kDebugMode) {
          print('DECISION: User paused state detected -> finalPlayingState = false');
          if (isPlaying) {
            print('Respecting explicit user pause - forcing playing: false');
          }
        }
      }
      // If user wants to play and hasn't explicitly paused, show playing unless there's an error or stopped state
      else if (_userIntendedPlaying && !_userExplicitlyPaused) {
        // Only show not playing if we're in a truly stopped/error state
        if (processingState == AudioProcessingState.idle && !isPlaying) {
          finalPlayingState = false;
          if (kDebugMode) {
            print('DECISION: User wants to play but player is idle -> finalPlayingState = false');
          }
        } else {
          // For all other states (ready, buffering, playing), show as playing if user intended
          finalPlayingState = true;
          if (kDebugMode) {
            print('DECISION: User intended playing -> finalPlayingState = true');
            if (!isPlaying) {
              print('User intended playing, showing as playing despite player state');
            }
          }
        }
      }
      // Fallback to actual player state (shouldn't happen with proper user intent)
      else {
        finalPlayingState = isPlaying;
        if (kDebugMode) {
          print('DECISION: Fallback to player state -> finalPlayingState = $isPlaying');
        }
      }
      
      // Always update playback state to keep system informed
      // Preserve current position during state changes to prevent 00:00 resets
      final currentPosition = playbackState.value.updatePosition;
      final playerPosition = _player.position;
      
      // Use stored pause position if available, otherwise use current player position
      // but preserve existing position if player position is 0 (reset state)
      Duration finalPosition;
      if (_pausedAtPosition != null && _userExplicitlyPaused) {
        finalPosition = _pausedAtPosition!;
        if (kDebugMode) {
          print('Using stored pause position: ${finalPosition.inMilliseconds}ms');
        }
      } else if (playerPosition.inMilliseconds > 0) {
        finalPosition = playerPosition;
      } else if (currentPosition.inMilliseconds > 0) {
        finalPosition = currentPosition;
        if (kDebugMode) {
          print('Preserving existing position: ${finalPosition.inMilliseconds}ms (player at ${playerPosition.inMilliseconds}ms)');
        }
      } else {
        finalPosition = Duration.zero;
      }
      
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
        updatePosition: finalPosition,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _stateManager.currentIndex,
      );
      
      _updatePlaybackState(newPlaybackState);
    });

    // Listen to current index changes for gapless transitions
    _player.currentIndexStream.listen((index) async {
      final isConcatenationActive = await _isConcatenationActive();
      
      if (index != null && isConcatenationActive && !_stateManager.isHandlingCompletion) {
        if (kDebugMode) {
          print('Gapless transition to index: $index (concatenation active)');
        }
        
        // Validate that the index is within current playlist bounds
        if (index >= _stateManager.playlist.length) {
          if (kDebugMode) {
            print('Index $index is out of bounds for current playlist (${_stateManager.playlist.length} tracks), ignoring');
          }
          return;
        }
        
        // Only update if this is a legitimate gapless transition
        if (index != _stateManager.currentIndex) {
          // Update state manager without stopping playback
          _stateManager.setCurrentIndex(index);
          
          // Update media item
          final track = _stateManager.playlist[index];
          mediaItem.add(_trackToMediaItem(track));
          
          // Trigger preloading of upcoming tracks
          Future.microtask(() {
            _preloader.preloadNextTracks(_stateManager.playlist, index);
          });
          
          // Update playback state with new index
          _updatePlaybackState(playbackState.value.copyWith(
            queueIndex: index,
          ));
          
          if (kDebugMode) {
            print('Updated to track: ${track.name} (index: $index)');
          }
        }
      } else if (index != null && !isConcatenationActive) {
        if (kDebugMode) {
          print('Received index change ($index) but concatenation is not active, ignoring');
        }
      }
    });

    // Enhanced position stream with atomic updates and debouncing
    _player.positionStream.listen((position) {
      if (kDebugMode) {
        print('=== POSITION STREAM LISTENER ===');
        print('DateTime: ${DateTime.now()}');
        print('Position: ${position.inMilliseconds}ms');
        print('_pausedAtPosition: ${_pausedAtPosition?.inMilliseconds}ms');
        print('_userExplicitlyPaused: $_userExplicitlyPaused');
        print('_userIntendedPlaying: $_userIntendedPlaying');
        print('_player.playing: ${_player.playing}');
      }
      
      // Only attempt position restoration if we have a stored pause position
      // and the player has resumed from an explicit pause
      if (_pausedAtPosition != null && _userExplicitlyPaused && _player.playing) {
        if (kDebugMode) {
          print('Position restoration triggered - current: ${position.inMilliseconds}ms, should be: ${_pausedAtPosition!.inMilliseconds}ms');
        }
        
        // Only seek if the position is significantly different (more than 500ms)
        // Increased threshold to prevent unnecessary seeks during normal playback
        final positionDiff = (position.inMilliseconds - _pausedAtPosition!.inMilliseconds).abs();
        if (positionDiff > 500) {
          if (kDebugMode) {
            print('Position jump detected (${positionDiff}ms), seeking to restore pause position');
          }
          
          // Seek back to the pause position asynchronously to avoid blocking the stream
          Future.microtask(() async {
            try {
              await _player.seek(_pausedAtPosition!);
              await _positionManager.recordSeek(_pausedAtPosition!);
              if (kDebugMode) {
                print('Successfully restored pause position to ${_pausedAtPosition!.inMilliseconds}ms');
              }
            } catch (e) {
              if (kDebugMode) {
                print('Failed to restore pause position: $e');
              }
            }
            // Clear the restoration flags ONLY when actually playing/resuming AND not explicitly paused
            // Do NOT clear _userExplicitlyPaused during position updates - only during explicit play commands
            if (_player.playing && _userIntendedPlaying && !_userExplicitlyPaused) {
              _pausedAtPosition = null;
            }
          });
          
          // Return early to avoid updating with the wrong position
          return;
        } else {
          // Position is close enough, clear the flags without seeking
          // BUT: only clear if we're actually playing/resuming, not just updating position while paused
          // Do NOT clear _userExplicitlyPaused during position updates - only during explicit play commands
          if (kDebugMode) {
            print('Position close enough (${positionDiff}ms), clearing pause restoration flags only if playing and not explicitly paused');
          }
          if (_player.playing && _userIntendedPlaying && !_userExplicitlyPaused) {
            _pausedAtPosition = null;
          }
        }
      }
      
      // Update position through position manager with protection against seek conflicts
      _positionManager.updatePositionDebounced(
        position, 
        (validatedPosition) {
          // Only update playback state if not currently transitioning
          if (!_transitionManager.isTransitionInProgress && 
              !_stateManager.isHandlingCompletion &&
              _player.processingState != ProcessingState.buffering) {
            _updatePlaybackState(playbackState.value.copyWith(
              updatePosition: validatedPosition,
            ));
          }
        },
        fromStream: true,
      );
      
      // Update TouchBar with current lyrics line (this is safe to do always)
      _updateTouchBarLyrics(position);
    });

    // Add playback event listener to handle errors gracefully
    _player.playbackEventStream.listen((event) {
      // Handle playback errors
      if (event.processingState == ProcessingState.idle) {
        // CRITICAL FIX: Don't recover if user explicitly paused
        // Only recover on unexpected idle states when user actually intended to play
        if (_stateManager.currentTrack != null && 
            _userIntendedPlaying && 
            !_userExplicitlyPaused && // Don't recover if user explicitly paused
            _player.playing == false) {
          _logger.warning('Playback went idle unexpectedly, attempting recovery', 'AudioHandler');
          if (kDebugMode) {
            print('Player went idle unexpectedly - attempting to recover');
          }
          
          // Try to recover by disabling gapless and reloading current track
          Future.delayed(const Duration(milliseconds: 500), () async {
            try {
              // Double-check user intent hasn't changed during delay
              if (!_userIntendedPlaying || _userExplicitlyPaused) {
                if (kDebugMode) {
                  print('User paused during recovery delay - cancelling recovery');
                }
                return;
              }
              
              // Disable gapless to avoid concatenation issues
              if (_isUsingConcatenation) {
                _logger.info('Disabling gapless playback due to error recovery', 'AudioHandler');
                await _setConcatenationState(false, null);
              }
              
              // Reload current track individually with user intent
              await _playIndividualTrack(_stateManager.currentTrack!, _userIntendedPlaying);
            } catch (e) {
              _logger.error('Error recovery failed: $e', 'AudioHandler');
            }
          });
        }
      }
    });

    // Simplified completion detection - only handle actual completion
    _player.processingStateStream.listen((state) async {
      final userIntent = _userIntendedPlaying; // Direct access to avoid mutex deadlock
      _logger.info('Processing state changed: $state (userIntended: $userIntent)', 'AudioHandler');
      if (kDebugMode) {
        print('Processing state changed: $state');
      }
      
      // Handle codec loops only in extreme cases - MUCH less aggressive
      if (state == ProcessingState.buffering) {
        await _updateBufferingLoop();
        
        // Check if we should handle codec loop atomically
        if (await _shouldHandleCodecLoop()) {
          _logger.warning('Detected extreme codec loop in buffering state after 25 attempts, forcing recovery', 'AudioHandler');
          if (kDebugMode) {
            print('Detected extreme codec loop in buffering state after 25 attempts, forcing recovery');
          }
          _handleCodecLoop();
          return;
        }
      } else {
        // Reset loop detection on state changes
        await _resetBufferingLoop();
      }
      
      // Log critical state changes
      if (state == ProcessingState.ready && userIntent) {
        _logger.info('Track is ready and user intended playing - playback should start', 'AudioHandler');
      } else if (state == ProcessingState.ready && !userIntent) {
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
        _savePlaybackStateDebounced(position: _player.position, isPlaying: playerState.playing);
        if (kDebugMode) {
          print('Stopped playback - saved state');
        }
      }
    });

    // Set initial playbook state with proper volume
    _player.setVolume(_stateManager.normalizeVolumeEnabled ? 0.8 : 1.0);
    
    // Android-specific initialization to prevent foreground service startup issues
    if (Platform.isAndroid) {
      // Start with minimal controls to avoid triggering foreground service prematurely
      playbackState.add(PlaybackState(
        controls: [MediaControl.play], // Minimal controls initially
        systemActions: const <MediaAction>{}, // No system actions initially
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      
      if (kDebugMode) {
        print('Android: Initialized with minimal controls to prevent foreground service issues');
      }
    } else {
      // Full controls for other platforms
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
      
      if (kDebugMode) {
        print('${Platform.operatingSystem}: Initialized with full media controls');
      }
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

  /// Handle audio session events from the coordinator
  void _handleAudioSessionEvent(AudioSessionEvent event) {
    if (kDebugMode) {
      print('AudioHandler: Audio session event - ${event.type}: ${event.message}');
    }
    
    switch (event.type) {
      case AudioSessionEventType.interrupted:
        _handleAudioInterruption(event);
        break;
      case AudioSessionEventType.deviceChanged:
        _handleDeviceChange(event);
        break;
      case AudioSessionEventType.error:
        _logger.warning('Audio session error: ${event.message}', 'AudioHandler');
        break;
      default:
        // Log other events for debugging
        _logger.debug('Audio session event: ${event.type} - ${event.message}', 'AudioHandler');
        break;
    }
  }

  /// Handle audio interruption events
  void _handleAudioInterruption(AudioSessionEvent event) {
    final interruption = event.context['type'];
    final userIntended = event.context['userIntended'] ?? false;
    
    if (interruption == 'AudioInterruptionType.pause') {
      // Audio was interrupted (e.g., phone call)
      if (_player.playing) {
        pause();
        if (kDebugMode) {
          print('Audio interrupted - paused playback');
        }
      }
    } else if (interruption == 'AudioInterruptionType.duck') {
      // Lower volume but continue playing
      if (kDebugMode) {
        print('Audio ducking - lowering volume');
      }
    } else if (interruption == 'AudioInterruptionType.unknown') {
      // Handle interruption ended
      if (userIntended && !_player.playing) {
        Future.delayed(const Duration(milliseconds: 500), () {
          play();
          if (kDebugMode) {
            print('Audio interruption ended - resuming playback');
          }
        });
      }
    }
  }

  /// Handle device change events
  void _handleDeviceChange(AudioSessionEvent event) {
    final devicesRemoved = event.context['devicesRemoved'] ?? 0;
    
    if (devicesRemoved > 0 && _player.playing) {
      // Assume headphones were disconnected - pause playback
      _setUserIntentAtomic(false); // User didn't explicitly pause
      pause();
      if (kDebugMode) {
        print('Audio device removed - paused playback');
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

  /// Recover from Android foreground service failures by restarting audio system
  Future<void> _recoverFromAndroidServiceFailure() async {
    if (!Platform.isAndroid) return;
    
    await _errorStateManager.executeWithRecovery(
      component: 'AndroidServiceManager',
      operation: 'serviceRecovery',
      category: ErrorCategory.system,
      action: () async {
        if (kDebugMode) {
          print('=== ANDROID SERVICE RECOVERY STARTED ===');
          print('Current track: ${_stateManager.currentTrack?.name}');
          print('User intended playing: $_userIntendedPlaying');
          print('Service state: ${_androidServiceManager.currentConfig.description}');
        }
        
        // Transition to bypass mode immediately for recovery
        final newConfig = _androidServiceManager.transitionToBypass(
          BypassReason.foregroundServiceError, 
          'Service recovery initiated'
        );
        
        if (kDebugMode) {
          print('Android service manager: Recovery mode enabled - ${newConfig.description}');
        }
        
        // Stop current player to reset state
        await _errorStateManager.executeWithErrorHandling(
          component: 'AudioHandler',
          operation: 'stopPlayerForRecovery',
          category: ErrorCategory.playback,
          severity: ErrorSeverity.medium,
          action: () async {
            await _player.stop();
            if (kDebugMode) {
              print('Stopped current player for recovery');
            }
          },
        );
        
        // Wait a moment for system to reset
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Clear concatenating source to reset audio pipeline
        _concatenatingSource = null;
        
        // If we have a current track, try to reload it
        if (_stateManager.currentTrack != null) {
          if (kDebugMode) {
            print('Reloading current track in bypass mode...');
          }
          
          // Force individual track playback without AudioService
          await _loadAndPlayTrackBypass(_stateManager.currentTrack!, _userIntendedPlaying);
          
          if (kDebugMode) {
            print('=== ANDROID BYPASS MODE RECOVERY COMPLETED ===');
          }
        }
      },
      maxRetries: 1,
    );
  }

  /// Upgrade Android controls to full set once playback is successfully working
  void _upgradeAndroidControlsAfterSuccess() {
    if (!Platform.isAndroid) return;
    
    // Skip if in bypass mode
    if (_androidServiceManager.shouldSkipAudioService()) {
      if (kDebugMode) {
        print('Android service manager: Skipping control upgrade - ${_androidServiceManager.currentConfig.description}');
      }
      return;
    }
    
    try {
      final currentState = playbackState.value;
      final upgradedState = currentState.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2, 3],
      );
      
      playbackState.add(upgradedState);
      
      if (kDebugMode) {
        print('Android: Upgraded to full media controls after successful playback');
      }
      
      _logger.info('Android: Upgraded to full media controls after successful playback', 'AudioHandler');
    } catch (e) {
      _logger.warning('Failed to upgrade Android controls: $e', 'AudioHandler');
      if (kDebugMode) {
        print('Failed to upgrade Android controls: $e');
      }
    }
  }

  /// Load and play track in Android bypass mode (pure just_audio, no AudioService)
  Future<void> _loadAndPlayTrackBypass(Track track, bool shouldPlay) async {
    if (!Platform.isAndroid) return;
    
    try {
      if (kDebugMode) {
        print('=== ANDROID BYPASS MODE TRACK LOADING ===');
        print('Track: ${track.name}');
        print('Should play: $shouldPlay');
      }
      
      // Clear pause position when loading a new track to prevent invalid seeks
      _pausedAtPosition = null;
      _userExplicitlyPaused = false;
      
      // Get stream URLs
      List<String> streamUrls = [];
      final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
      
      if (mediaServiceCoordinator != null) {
        final primaryUrl = mediaServiceCoordinator.getStreamUrl(track.id);
        if (primaryUrl != null && primaryUrl.isNotEmpty) {
          streamUrls.add(primaryUrl);
        }
        
        try {
          final altUrls = mediaServiceCoordinator.getAlternativeStreamUrls(track.id);
          streamUrls.addAll(altUrls);
        } catch (e) {
          if (kDebugMode) {
            print('Failed to get alternative URLs in bypass mode: $e');
          }
        }
      } else {
        // Fallback to JellyfinService
        streamUrls = [
          _jellyfinService.getStreamUrl(track.id),
          _jellyfinService.getDirectStreamUrl(track.id),
          _jellyfinService.getUniversalStreamUrl(track.id),
        ];
      }
      
      // Remove empty URLs
      streamUrls = streamUrls.where((url) => url.isNotEmpty).toList();
      
      if (kDebugMode) {
        print('Bypass mode URLs: ${streamUrls.length} available');
      }
      
      // Try each URL with timeout protection
      bool loaded = false;
      for (int i = 0; i < streamUrls.length && !loaded; i++) {
        final streamUrl = streamUrls[i];
        
        try {
          if (kDebugMode) {
            print('Bypass mode: Trying URL ${i + 1}/${streamUrls.length}');
          }
          
          // Set URL directly on player with timeout protection (no AudioService involved)
          await _player.setUrl(streamUrl).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('URL loading timed out', const Duration(seconds: 30));
            },
          );
          
          // Longer delay for network stability
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (shouldPlay && _userIntendedPlaying) {
            // Play with timeout protection
            await _player.play().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Play command timed out', const Duration(seconds: 10));
              },
            );
            if (kDebugMode) {
              print('Bypass mode: Started playback successfully');
            }
          }
          
          loaded = true;
          
          if (kDebugMode) {
            print('=== BYPASS MODE SUCCESS ===');
            print('Track loaded and playing: ${_player.playing}');
            print('URL: $streamUrl');
          }
          
        } catch (e) {
          if (kDebugMode) {
            print('Bypass mode URL ${i + 1} failed: $e');
          }
          
          if (i < streamUrls.length - 1) {
            // Wait before trying next URL
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
      }
      
      if (!loaded) {
        if (kDebugMode) {
          print('=== BYPASS MODE FAILED ===');
          print('All URLs failed in bypass mode');
        }
        throw Exception('Failed to load track in bypass mode: All URLs failed');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Bypass mode loading error: $e');
      }
      rethrow; // Re-throw so the calling code can handle it properly
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

  /// Create audio source for a track with fresh source creation to avoid stale URLs
  Future<AudioSource?> _createAudioSource(Track track) async {
    return await _mutexManager.withLock('audioSourceCache', () async {
      try {
        // Try local file first using coordinated download service
        final localFilePath = await _downloadServiceCoordinator.getLocalFilePath(track.id);
        if (localFilePath != null) {
          final localFile = File(localFilePath);
          if (await localFile.exists()) {
            final source = AudioSource.file(localFilePath);
            if (kDebugMode) {
              print('Created local file audio source for: ${track.name}');
            }
            return source;
          }
        }

        // Check preloaded audio source first (for gapless) with reference counting
        final preloadedSource = _preloader.getPreloadedAudioSource(track.id, 'concatenation_builder');
        if (preloadedSource != null) {
          if (kDebugMode) {
            print('Using preloaded audio source with reference for: ${track.name}');
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
        final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
        
        if (mediaServiceCoordinator != null) {
          // Use coordinated MediaServiceManager for current service - prefer alternative URLs
          final alt = mediaServiceCoordinator.getAlternativeStreamUrls(track.id);
          if (alt.isNotEmpty) {
            streamUrls = alt;
          } else {
            final primary = mediaServiceCoordinator.getStreamUrl(track.id);
            streamUrls = (primary != null && primary.isNotEmpty) ? [primary] : [];
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
            // Create fresh audio source without caching to avoid stale URLs
            AudioSource source;
            if (_shouldTranscodeTrack(track)) {
              final hlsUrl = _getHlsStreamUrl(track);
              source = hlsUrl.isNotEmpty 
                  ? HlsAudioSource(Uri.parse(hlsUrl))
                  : AudioSource.uri(Uri.parse(streamUrl));
            } else {
              source = AudioSource.uri(Uri.parse(streamUrl));
            }

            if (kDebugMode) {
              print('Created fresh stream audio source for: ${track.name}');
            }
            return source;
          } catch (e) {
            if (kDebugMode) {
              print('Error creating source for $streamUrl: $e');
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
    });
  }

  /// Build concatenating audio source with smart preloading
  Future<ConcatenatingAudioSource?> _buildConcatenatingSource(List<Track> tracks, [int? startIndex]) async {
    if (tracks.isEmpty) return null;

    final currentIndex = startIndex ?? _stateManager.currentIndex;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final maxTracksToPreload = isMobile ? 3 : 10; // Much more conservative on mobile
    
    if (kDebugMode) {
      print('Building concatenating source for ${tracks.length} tracks, starting at index $currentIndex');
      print('Mobile device: $isMobile, will preload max $maxTracksToPreload tracks');
    }

    final audioSources = <AudioSource>[];
    
    // For mobile: Create full structure but only preload nearby tracks
    // For desktop: Create all tracks (existing behavior)
    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final shouldPreload = !isMobile || (i >= currentIndex && i < currentIndex + maxTracksToPreload);
      
      AudioSource? audioSource;
      if (shouldPreload) {
        // Actually create and probe the audio source
        audioSource = await _createAudioSource(track);
        if (kDebugMode) {
          print('Preloaded track $i: ${track.name}');
        }
      } else {
        // For mobile: Skip creating placeholders that might be invalid
        // Only add tracks that we can actually create valid sources for
        if (kDebugMode) {
          print('Skipping placeholder for track $i: ${track.name} (mobile optimization)');
        }
        continue; // Skip this track instead of creating invalid placeholder
      }
      
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

    // Create concatenating source with whatever valid sources we have
    // Don't require all tracks to be available - mobile optimization
    if (audioSources.isNotEmpty) {
      if (kDebugMode) {
        print('Created concatenating source with ${audioSources.length}/${tracks.length} tracks');
      }
      return ConcatenatingAudioSource(children: audioSources);
    }

    if (kDebugMode) {
      print('No valid audio sources available for concatenation');
    }
    return null;
  }

  // Audio Service Methods - Enhanced for background compatibility
  @override
  Future<void> play() async {
    if (kDebugMode) {
      print('Play: Processing play command directly (no throttling)');
    }
    
    final now = DateTime.now();
    _logger.info('Play command received', 'AudioHandler');
    
    try {
      // Android service manager: Use direct player control if in bypass mode
      // Skip complex state coordination to avoid deadlocks in bypass mode
      if (_androidServiceManager.shouldSkipAudioService()) {
        if (kDebugMode) {
          print('Android service manager: Direct player play - ${_androidServiceManager.currentConfig.description}');
        }
        
        // Simple state validation for bypass mode - just check if already playing
        if (_player.playing && _userIntendedPlaying) {
          _logger.info('Play command ignored - already playing and user intended', 'AudioHandler');
          if (kDebugMode) {
            print('Play command ignored - player is already playing and user intended');
          }
          return;
        }
        
        // Set user intent atomically
        await _setUserIntentAtomic(true);
        _pausedAtPosition = null; // Clear stored pause position when resuming
        
        try {
          // If no track is loaded, try to load current track in bypass mode
          if (_stateManager.currentTrack != null && _player.audioSource == null) {
            await _loadAndPlayTrackBypass(_stateManager.currentTrack!, true);
          } else {
            await _player.play();
          }
          
          // Update playback state to reflect the play
          _updatePlaybackState(playbackState.value.copyWith(
            playing: true,
            processingState: _player.processingState == ProcessingState.ready 
                ? AudioProcessingState.ready 
                : AudioProcessingState.loading,
          ));
          
        } catch (e) {
          _logger.error('Play command failed in bypass mode: $e', 'AudioHandler');
          if (kDebugMode) {
            print('Play command failed in bypass mode: $e');
          }
          
          // Update playback state to reflect the error
          _updatePlaybackState(playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.error,
          ));
        }
        
        _logger.info('Play command completed successfully (bypass mode)', 'AudioHandler');
        if (kDebugMode) {
          print('Play command completed (bypass mode). User intended playing: $_userIntendedPlaying');
        }
        return;
      }
      
      // Full state coordination for non-bypass mode (Android/MediaSession)
      // Validate state transition before executing
      if (!_playerStateTransitionCoordinator.wouldTransitionBeValid(PlayerTransitionEvent.play)) {
        _logger.warning('Play command rejected - invalid state transition from ${_playerStateTransitionCoordinator.currentState}', 'AudioHandler');
        return;
      }
      
      // Request coordinated state transition
      final transitionAccepted = await _playerStateTransitionCoordinator.requestTransition(
        PlayerTransitionEvent.play,
        context: {'command': 'play', 'timestamp': now.millisecondsSinceEpoch},
      );
      
      if (!transitionAccepted) {
        _logger.warning('Play command queued due to ongoing state transition', 'AudioHandler');
        return;
      }
      
      // Cancel any ongoing gapless operations when new play command is issued
      _cancellationManager.createToken('playCommand', 'New play command cancelling previous operations');
      
      if (kDebugMode) {
        print('Play command received (Android Auto/MediaSession compatible) - Current user intent: $_userIntendedPlaying');
      }
      
      // Set user intent atomically
      await _setUserIntentAtomic(true);
      _pausedAtPosition = null; // Clear stored pause position when resuming
      
      _logger.info('User intent set to playing', 'AudioHandler');
      
      try {
        // Ensure we have a track to play
        if (_stateManager.currentTrack == null && _stateManager.playlist.isNotEmpty) {
          _logger.info('No current track, loading from playlist', 'AudioHandler');
          if (kDebugMode) {
            print('No current track, loading from playlist');
          }
          // Add timeout protection for _playCurrentTrack as it can hang
          await _playCurrentTrack().timeout(
            Duration(seconds: 5),
            onTimeout: () {
              _logger.warning('_playCurrentTrack timed out, attempting recovery', 'AudioHandler');
              throw TimeoutException('_playCurrentTrack timeout', Duration(seconds: 5));
            },
          );
        } else {
          _logger.info('Resuming existing track: ${_stateManager.currentTrack?.name}', 'AudioHandler');
          if (kDebugMode) {
            print('Playing existing track');
          }
          // Add timeout protection for player.play() as it can hang on network issues
          await _player.play().timeout(
            Duration(seconds: 3),
            onTimeout: () {
              _logger.warning('_player.play() timed out', 'AudioHandler');
              throw TimeoutException('_player.play() timeout', Duration(seconds: 3));
            },
          );
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
        
        // Check if this is an Android foreground service error
        if (Platform.isAndroid && e.toString().contains('ForegroundServiceStartNotAllowedException')) {
          _logger.warning('Android foreground service blocked - attempting fallback playback', 'AudioHandler');
          if (kDebugMode) {
            print('=== ANDROID FOREGROUND SERVICE BLOCKED ===');
            print('Attempting fallback audio playbook without media controls...');
          }
          
          try {
            // Try to restart the player with a simplified setup
            await _recoverFromAndroidServiceFailure();
            
            if (kDebugMode) {
              print('Android service failure recovery completed');
            }
          } catch (recoveryError) {
            _logger.error('Android service recovery failed: $recoveryError', 'AudioHandler');
            if (kDebugMode) {
              print('Android service recovery failed: $recoveryError');
            }
          }
        } else {
          // Try to recover by reloading current track for non-Android service errors
          if (_stateManager.currentTrack != null) {
            _logger.info('Attempting recovery by reloading current track', 'AudioHandler');
            await _resumeCurrentTrack();
          }
        }
      }
    } catch (e) {
      // Handle any errors that might prevent command completion
      if (kDebugMode) {
        print('Error in play command: $e');
      }
      _logger.error('Play command failed: $e', 'AudioHandler');
    }
  }

  @override
  Future<void> pause() async {
    if (kDebugMode) {
      print('Pause: Processing pause command directly (no throttling)');
    }
    
    final now = DateTime.now();
    _logger.info('Pause command received', 'AudioHandler');
    
    try {
      // Android service manager: Use direct player control if in bypass mode  
      // Skip complex state coordination to avoid deadlocks in bypass mode
      if (_androidServiceManager.shouldSkipAudioService()) {
        if (kDebugMode) {
          print('Android service manager: Direct player pause - ${_androidServiceManager.currentConfig.description}');
        }
        
        // Simple state validation for bypass mode - just check if already stopped
        if (!_player.playing && !_userIntendedPlaying) {
          _logger.info('Pause command ignored - already paused and user intended', 'AudioHandler');
          if (kDebugMode) {
            print('Pause command ignored - player is already paused and user intended');
          }
          return;
        }
        
        // Set user intent atomically and mark as explicit pause
        await _setUserIntentAtomic(false);
        _userExplicitlyPaused = true; // Mark as intentional pause
        await _player.pause();
        
        // Update playback state to reflect the pause
        _updatePlaybackState(playbackState.value.copyWith(
          playing: false,
        ));
        
        _logger.info('Pause command completed successfully (bypass mode)', 'AudioHandler');
        if (kDebugMode) {
          print('Pause command completed (bypass mode). User intended playing: $_userIntendedPlaying');
        }
        return;
      }
      
      // Full state coordination for non-bypass mode (Android/MediaSession)
      // Validate state transition before executing
      if (!_playerStateTransitionCoordinator.wouldTransitionBeValid(PlayerTransitionEvent.pause)) {
        _logger.warning('Pause command rejected - invalid state transition from ${_playerStateTransitionCoordinator.currentState}', 'AudioHandler');
        return;
      }
      
      // Request coordinated state transition
      final transitionAccepted = await _playerStateTransitionCoordinator.requestTransition(
        PlayerTransitionEvent.pause,
        context: {'command': 'pause', 'timestamp': now.millisecondsSinceEpoch},
      );
      
      if (!transitionAccepted) {
        _logger.warning('Pause command queued due to ongoing state transition', 'AudioHandler');
        return;
      }
      
      if (kDebugMode) {
        print('Pause command received (Android Auto/MediaSession compatible) - Current user intent: $_userIntendedPlaying');
      }
      
      // Set user intent atomically and mark as explicit pause
      await _setUserIntentAtomic(false);
      _userExplicitlyPaused = true; // Mark as intentional pause
      
      // Store current position to restore on resume (fix for position jumping bug)
      _pausedAtPosition = _player.position;
      if (kDebugMode) {
        print('Stored pause position: ${_pausedAtPosition?.inMilliseconds}ms');
      }
      
      _logger.info('User intent set to paused', 'AudioHandler');
      
      try {
        // Add timeout protection for player.pause() as it can hang on network issues
        await _player.pause().timeout(
          Duration(seconds: 2),
          onTimeout: () {
            _logger.warning('_player.pause() timed out', 'AudioHandler');
            throw TimeoutException('_player.pause() timeout', Duration(seconds: 2));
          },
        );
        
        // Immediately update playback state to reflect the pause
        // Force playing: false and preserve the current position
        final currentState = playbackState.value;
        _updatePlaybackState(currentState.copyWith(
          playing: false,
          updatePosition: _pausedAtPosition ?? currentState.updatePosition,
        ));
        
        // Add a small delay then force another state update to ensure UI gets the change
        await Future.delayed(const Duration(milliseconds: 50));
        _updatePlaybackState(playbackState.value.copyWith(
          playing: false,
          updatePosition: _pausedAtPosition ?? playbackState.value.updatePosition,
        ));
        
        _logger.info('Pause command completed successfully', 'AudioHandler');
        if (kDebugMode) {
          print('Pause command completed. User intended playing: $_userIntendedPlaying');
          print('Forced playback state to playing: false');
          print('Preserved position: ${_pausedAtPosition?.inMilliseconds}ms');
        }
      } catch (e) {
        _logger.error('Error in pause command: $e', 'AudioHandler');
        if (kDebugMode) {
          print('Error in pause command: $e');
        }
        
        // Force update playback state even if pause failed
        final currentState = playbackState.value;
        _updatePlaybackState(currentState.copyWith(
          playing: false,
          updatePosition: _pausedAtPosition ?? currentState.updatePosition,
        ));
        
        // Double-ensure the state sticks
        await Future.delayed(const Duration(milliseconds: 50));
        _updatePlaybackState(playbackState.value.copyWith(
          playing: false,
          updatePosition: _pausedAtPosition ?? playbackState.value.updatePosition,
        ));
      }
    } catch (e) {
      // Handle any errors that might prevent command completion
      if (kDebugMode) {
        print('Error in pause command: $e');
      }
      _logger.error('Pause command failed: $e', 'AudioHandler');
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
          final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
          final tracks = mediaServiceCoordinator != null 
            ? await mediaServiceCoordinator.getTracks(parentId: albumId)
            : await _jellyfinServiceCoordinator.getAlbumTracks(albumId);
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
          final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
          final tracks = mediaServiceCoordinator != null 
            ? await mediaServiceCoordinator.getPlaylistTracks(playlistId)
            : await _jellyfinServiceCoordinator.getPlaylistTracks(playlistId);
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
    // Validate state transition before executing
    if (!_playerStateTransitionCoordinator.wouldTransitionBeValid(PlayerTransitionEvent.stop)) {
      _logger.warning('Stop command rejected - invalid state transition from ${_playerStateTransitionCoordinator.currentState}', 'AudioHandler');
      return;
    }
    
    // Request coordinated state transition
    final transitionAccepted = await _playerStateTransitionCoordinator.requestTransition(
      PlayerTransitionEvent.stop,
      context: {'command': 'stop', 'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    
    if (!transitionAccepted) {
      _logger.warning('Stop command queued due to ongoing state transition', 'AudioHandler');
      return;
    }
    
    // Reset user intent on stop atomically
    await _setUserIntentAtomic(false);
    
    await _player.stop();
    _updatePlaybackState(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    // Validate state transition before executing
    if (!_playerStateTransitionCoordinator.wouldTransitionBeValid(PlayerTransitionEvent.seek)) {
      _logger.warning('Seek command rejected - invalid state transition from ${_playerStateTransitionCoordinator.currentState}', 'AudioHandler');
      return;
    }
    
    // Request coordinated state transition
    final transitionAccepted = await _playerStateTransitionCoordinator.requestTransition(
      PlayerTransitionEvent.seek,
      context: {'command': 'seek', 'position': position.inMilliseconds, 'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    
    if (!transitionAccepted) {
      _logger.warning('Seek command queued due to ongoing state transition', 'AudioHandler');
      return;
    }
    
    // Record seek operation in position manager to prevent race conditions
    await _positionManager.recordSeek(position);
    
    // Perform the actual seek
    await _player.seek(position);
    
    // Force position update to ensure UI reflects seek immediately
    await _positionManager.forcePositionUpdate(position);
    
    if (kDebugMode) {
      print('Seek completed to ${position.inSeconds}s');
    }
  }

  @override
  Future<void> skipToNext() async {
    _logger.info('Skip to next track requested (current: ${_stateManager.currentIndex}/${_stateManager.playlist.length - 1})', 'AudioHandler');
    
    // Cancel any ongoing gapless operations when skipping
    _cancellationManager.createToken('skipCommand', 'Skip to next track cancelling previous operations');
    
    if (kDebugMode) {
      print('Skip to next requested. Current: ${_stateManager.currentIndex}, Max: ${_stateManager.playlist.length - 1}');
    }
    
    // Add timeout wrapper for the entire skip operation
    try {
      await _executeSkipWithTimeout('skipToNext', () async {
        // Preserve playing state when skipping - if music was playing, it should continue playing
        final wasPlaying = playbackState.value.playing;
        if (wasPlaying) {
          await _setUserIntentAtomic(true);
          _logger.info('Preserving playing state during skip (user was listening)', 'AudioHandler');
        }
        
        // Unprotect current track before transitioning to next
        if (_stateManager.currentTrack != null) {
          await _downloadServiceCoordinator.unmarkTrackAsStreaming(_stateManager.currentTrack!.id);
        }
        
        // Use gapless transition if concatenation is active
        final isActive = await _isConcatenationActive();
        if (isActive) {
          final nextIndex = _stateManager.currentIndex + 1;
          if (nextIndex < _stateManager.playlist.length) {
            _logger.info('Using gapless skip to next track: $nextIndex', 'AudioHandler');
            if (kDebugMode) {
              print('Using gapless skip to next track: $nextIndex');
            }
            
            try {
              await _player.seekToNext();
              // State will be updated automatically via currentIndexStream
              _savePlaybackStateDebounced(position: _player.position, isPlaying: _player.playing);
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
            _savePlaybackStateDebounced(position: _player.position, isPlaying: _player.playing);
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
      });
    } catch (e) {
      _logger.error('Skip to next operation failed or timed out: $e', 'AudioHandler');
      if (kDebugMode) {
        print('Skip to next operation failed or timed out: $e');
      }
      // Force release transition lock and attempt recovery
      _transitionManager.forceRelease();
    }
  }
  
  /// Executes skip operations with timeout protection
  Future<void> _executeSkipWithTimeout(String operation, Future<void> Function() skipFunction) async {
    const timeoutDuration = Duration(seconds: 10);
    
    try {
      await skipFunction().timeout(timeoutDuration);
    } on TimeoutException {
      _logger.error('$operation timed out after ${timeoutDuration.inSeconds}s', 'AudioHandler');
      if (kDebugMode) {
        print('$operation timed out after ${timeoutDuration.inSeconds}s - attempting recovery');
      }
      
      // Force release any locks and attempt recovery
      _transitionManager.forceRelease();
      
      // Try to recover the UI state
      final currentState = playbackState.value;
      _updatePlaybackState(currentState.copyWith(
        processingState: AudioProcessingState.ready,
      ));
      
      throw TimeoutException('$operation timeout', timeoutDuration);
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
    
    // Unprotect the current track since it's finished streaming
    if (_stateManager.currentTrack != null) {
      await _downloadServiceCoordinator.unmarkTrackAsStreaming(_stateManager.currentTrack!.id);
    }
    
    // If using concatenation, the transition is automatic - just handle state updates
    if (_isUsingConcatenation && _concatenatingSource != null) {
      if (kDebugMode) {
        print('Track completion with gapless - letting concatenation handle transition');
      }
      
      // The currentIndexStream listener will handle state updates automatically
      // Just need to handle end-of-playlist scenarios
      if (_stateManager.currentIndex >= _stateManager.playlist.length - 1) {
        if (_radioModeStateManager.isEnabled && _stateManager.currentTrack != null) {
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
        _savePlaybackStateDebounced(position: _player.position, isPlaying: _player.playing);
        
        if (kDebugMode) {
          print('Successfully moved to next track: ${_stateManager.currentTrack!.name}');
        }
        
      } else if (_radioModeStateManager.isEnabled && _stateManager.currentTrack != null) {
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
    // Use synchronized expansion to prevent race conditions
    final expansionSuccessful = await _radioModeOperationManager.executeExpansion(() async {
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
        final isActive = await _isConcatenationActive();
        if (isActive) {
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
          _savePlaybackStateDebounced(position: _player.position, isPlaying: _player.playing);
          
          if (kDebugMode) {
            print('Radio mode: Added ${similarTracks.length} tracks');
          }
        }
      } else {
        // End of radio mode
        await _setConcatenationState(false, null);
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
          playing: false,
        ));
      }
    });
    
    if (kDebugMode && expansionSuccessful) {
      if (kDebugMode) {
        print('Radio mode expansion completed successfully');
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    _logger.info('Skip to previous track requested (current: ${_stateManager.currentIndex})', 'AudioHandler');
    
    // Cancel any ongoing gapless operations when skipping
    _cancellationManager.createToken('skipCommand', 'Skip to previous track cancelling previous operations');
    
    // Add timeout wrapper for the entire skip operation
    try {
      await _executeSkipWithTimeout('skipToPrevious', () async {
        // Preserve playing state when skipping - if music was playing, it should continue playing
        final wasPlaying = playbackState.value.playing;
        if (wasPlaying) {
          await _setUserIntentAtomic(true);
          _logger.info('Preserving playing state during skip to previous', 'AudioHandler');
        }
        
        // Unprotect current track before transitioning to previous
        if (_stateManager.currentTrack != null) {
          await _downloadServiceCoordinator.unmarkTrackAsStreaming(_stateManager.currentTrack!.id);
        }
        
        // Use gapless transition if concatenation is active
        final isActive = await _isConcatenationActive();
        if (isActive) {
          final prevIndex = _stateManager.currentIndex - 1;
          if (prevIndex >= 0) {
            _logger.info('Using gapless skip to previous track: $prevIndex', 'AudioHandler');
            if (kDebugMode) {
              print('Using gapless skip to previous track: $prevIndex');
            }
            
            try {
              await _player.seekToPrevious();
              // State will be updated automatically via currentIndexStream
              _savePlaybackStateDebounced(position: _player.position, isPlaying: _player.playing);
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
              _savePlaybackStateDebounced(position: _player.position, isPlaying: _player.playing);
              if (kDebugMode) {
                print('Skipping to previous song');
              }
            } else {
              _logger.info('Already at first track, restarting current track', 'AudioHandler');
              await _player.seek(Duration.zero);
              if (kDebugMode) {
                print('Already at first song, restarting');
              }
            }
          }
        } finally {
          _transitionManager.releaseTransitionLock();
          _logger.info('Skip to previous completed', 'AudioHandler');
        }
      });
    } catch (e) {
      _logger.error('Skip to previous operation failed or timed out: $e', 'AudioHandler');
      if (kDebugMode) {
        print('Skip to previous operation failed or timed out: $e');
      }
      // Force release transition lock and attempt recovery
      _transitionManager.forceRelease();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _stateManager.playlist.length) {
      
      // Cancel any ongoing gapless operations when jumping to specific track
      _cancellationManager.createToken('skipToQueueItem', 'Skip to queue item $index cancelling previous operations');
      
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
        
        // Unprotect current track before transitioning to queue item
        if (_stateManager.currentTrack != null) {
          await _downloadServiceCoordinator.unmarkTrackAsStreaming(_stateManager.currentTrack!.id);
        }
        
        // Reset completion handling flags
        _stateManager.setHandlingCompletion(false);
        _stateManager.setTransitioning(false);
        
        await _stateManager.setCurrentIndexAtomic(index);
        await _playCurrentTrack();
        _savePlaybackStateDebounced(position: _player.position, isPlaying: _player.playing);
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
    
    // Protect track from download interference while streaming
    await _downloadServiceCoordinator.markTrackAsStreaming(track.id);
    
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
    return await _playerOperationQueue.enqueue('gaplessPlayback', () async {
      
      // Create cancellation token for this gapless operation
      final cancellationToken = _cancellationManager.createToken(
        'gaplessPlayback', 
        'New gapless playback operation started'
      );
      
    try {
      // CRITICAL: Completely disconnect from old audio source and clear concatenation state
      // This prevents old queue from continuing to play while new one is being set up
      try {
        // Check for cancellation before starting
        cancellationToken.throwIfCancelled();
        
        // First, clear concatenation state to stop processing old events
        await _setConcatenationState(false, null);
        if (kDebugMode) {
          print('Cleared concatenation state before player stop');
        }
        
        // Check for cancellation before stopping player
        cancellationToken.throwIfCancelled();
        
        // Stop player completely and wait for full stop
        await _player.stop();
        await cancellationToken.delay(const Duration(milliseconds: 300));
        
        if (kDebugMode) {
          print('Player stopped and cleared, proceeding with new concatenating source');
        }
      } on OperationCancelledException {
        if (kDebugMode) {
          print('Gapless playback cancelled during player stop: ${cancellationToken.reason}');
        }
        return false;
      } catch (e) {
        if (kDebugMode) {
          print('Warning: Could not stop player cleanly: $e');
        }
      }
      
      // Check for cancellation before building concatenating source
      cancellationToken.throwIfCancelled();
      
      // Build concatenating source for current track and next few tracks
      final concatenatingSource = await _buildConcatenatingSource(_stateManager.playlist, _stateManager.currentIndex);
      
      // Check for cancellation after building source
      cancellationToken.throwIfCancelled();
      
      if (concatenatingSource != null) {
        if (kDebugMode) {
          print('Built concatenating source with ${concatenatingSource.children.length} tracks');
        }
        
        try {
          // Additional validation: ensure concatenating source has valid URIs
          bool hasValidSources = true;
          for (final source in concatenatingSource.children) {
            // Check for cancellation during validation
            cancellationToken.throwIfCancelled();
            
            if (source is ProgressiveAudioSource) {
              final uri = source.uri;
              if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'file')) {
                _logger.warning('Invalid URI scheme in concatenating source: ${uri.toString()}', 'AudioHandler');
                hasValidSources = false;
                break;
              }
            }
          }
          
          if (!hasValidSources) {
            throw Exception('Concatenating source contains invalid URIs');
          }
          
          // Final cancellation check before setting audio source
          cancellationToken.throwIfCancelled();
          
          // Set the concatenating source with current index
          await _player.setAudioSource(
            concatenatingSource, 
            initialIndex: _stateManager.currentIndex,
          );
          
          // Check for cancellation after setting source
          cancellationToken.throwIfCancelled();
          
          if (kDebugMode) {
            print('Successfully set new concatenating source');
          }
          
          // Store references for gapless operations atomically AFTER successful setAudioSource
          await _setConcatenationState(true, concatenatingSource);
          
          // Check for cancellation before resuming playback
          cancellationToken.throwIfCancelled();
          
          // Resume playing if user intended it
          final userIntent = _userIntendedPlaying; // Direct access to avoid nested mutex
          if (userIntent) {
            await _player.play();
            if (kDebugMode) {
              print('Started playing new concatenating source');
            }
          }
          
          // Final cancellation check before updating state
          cancellationToken.throwIfCancelled();
          
          // Update playback state
          _updatePlaybackState(playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: userIntent,
            queueIndex: _stateManager.currentIndex,
          ));
          
          // Start preloading for upcoming tracks
          Future.microtask(() {
            _preloader.preloadNextTracks(_stateManager.playlist, _stateManager.currentIndex);
          });
          
          return true;
        } on OperationCancelledException {
          if (kDebugMode) {
            print('Gapless playback cancelled during setup: ${cancellationToken.reason}');
          }
          return false;
        } catch (e) {
          _logger.error('Failed to set concatenating source: $e', 'AudioHandler');
          if (kDebugMode) {
            print('Failed to set concatenating source: $e');
          }
          rethrow; // Re-throw to trigger fallback
        }
      }
    } on OperationCancelledException {
      if (kDebugMode) {
        print('Gapless playback operation cancelled: ${cancellationToken.reason}');
      }
      return false;
    } catch (e) {
      _logger.warning('Gapless playback setup failed, will fall back to individual: $e', 'AudioHandler');
      if (kDebugMode) {
        print('Failed to set up gapless playback, falling back to individual: $e');
      }
    }
    
    return false;
    });
  }

  /// Play individual track
  Future<void> _playIndividualTrack(Track track, bool wasPlaying) async {
    return await _playerOperationQueue.enqueue('playIndividualTrack', () async {
      // Disable concatenation mode atomically
      await _setConcatenationState(false, null);
    
    // Use user intent instead of previous playing state for automatic transitions
    final shouldPlay = _userIntendedPlaying; // Direct access to avoid nested mutex
    
    if (kDebugMode) {
      print('Individual track playback - wasPlaying: $wasPlaying, userIntended: $shouldPlay, shouldPlay: $shouldPlay');
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
    });
  }

  Future<void> _loadAndPlayTrack(Track track, bool shouldPlay) async {
    return await _mutexManager.withLock('trackLoading', () async {
      _logger.info('Loading track: ${track.name}, shouldPlay: $shouldPlay', 'AudioHandler');
      if (kDebugMode) {
        print('Loading track: ${track.name}, should play: $shouldPlay');
      }
      
      // Clear pause position when loading a new track to prevent invalid seeks
      _pausedAtPosition = null;
      _userExplicitlyPaused = false;
      
      // Protect this track from preloader cleanup while loading
      _preloader.protectAudioSource(track.id);
    
    // Activate audio session before loading (iOS specific)
    await _audioSessionCoordinator.ensureActive();
    
    // Try local file first using coordinated download service
    final localFilePath = await _downloadServiceCoordinator.getLocalFilePath(track.id);
    
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
          
          // Get current user intent directly
          final userIntent = _userIntendedPlaying; // Direct access to avoid nested mutex
          if (userIntent && shouldPlay) {
            await _player.play();
            _logger.info('Auto-playing local file: ${track.name}', 'AudioHandler');
            if (kDebugMode) {
              print('Auto-playing local file: ${track.name} - user intended: $userIntent');
            }
          } else {
            _logger.info('Loaded local file (not auto-playing): ${track.name}', 'AudioHandler');
            if (kDebugMode) {
              print('Not auto-playing local file: ${track.name} - user intended: $userIntent, shouldPlay: $shouldPlay');
            }
          }
          
          // Update playback state after successful load
          // Use user intent directly instead of checking _player.playing
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
    
    // Use MediaServiceManagerCoordinator if available, otherwise fallback to JellyfinService
    final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
    
    if (mediaServiceCoordinator != null) {
      // Get multiple stream URLs for better fallback support
      streamUrls = [];
      
      // Try different stream URL approaches based on server type
      final serverType = mediaServiceCoordinator.currentServerType;
      _logger.debug('Using MediaServiceManagerCoordinator for ${serverType.toString()} service', 'AudioHandler');
      
      // For Plex, use async alternative URLs with part IDs (skip broken primary URL)
      // For other services, add primary URL first then alternatives
      if (serverType.toString().contains('plex')) {
        // Skip primary URL for Plex - use async alternatives with part IDs
        try {
          final altUrls = await mediaServiceCoordinator.getAlternativeStreamUrlsAsync(track.id);
          streamUrls.addAll(altUrls);
        } catch (e) {
          _logger.warning('Failed to get Plex async URLs: $e', 'AudioHandler');
          // Fallback to primary if async fails
          final primaryUrl = mediaServiceCoordinator.getStreamUrl(track.id);
          if (primaryUrl != null && primaryUrl.isNotEmpty) {
            streamUrls.add(primaryUrl);
          }
        }
      } else {
        // For non-Plex services, add primary URL first
        final primaryUrl = mediaServiceCoordinator.getStreamUrl(track.id);
        if (primaryUrl != null && primaryUrl.isNotEmpty) {
          streamUrls.add(primaryUrl);
        }
        
        // Add alternative URLs from service
        try {
          final altUrls = mediaServiceCoordinator.getAlternativeStreamUrls(track.id);
          streamUrls.addAll(altUrls);
        } catch (e) {
          _logger.warning('Failed to get alternative URLs: $e', 'AudioHandler');
        }
      }
      
      // Add service-specific URL variations for Navidrome
      if (serverType.toString().contains('navidrome') && streamUrls.isNotEmpty) {
        try {
          final primaryUrl = streamUrls.first; // Use first URL as base for variations
          final baseUrl = primaryUrl.split('?')[0];
          final queryParams = primaryUrl.contains('?') ? primaryUrl.split('?')[1] : '';
          
          if (queryParams.isNotEmpty) {
            streamUrls.addAll([
              '${baseUrl.replaceAll('/stream', '/download')}?$queryParams', // Download endpoint
              '$baseUrl?$queryParams&format=mp3',                        // Force MP3 format
              '$baseUrl?$queryParams&maxBitRate=128',                    // Lower bitrate
            ]);
          }
        } catch (e) {
          _logger.warning('Failed to generate Navidrome URL variations: $e', 'AudioHandler');
        }
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
          
          // Add small delay before setting URL to prevent interruption issues
          await Future.delayed(const Duration(milliseconds: 100));
          
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
          
          // Extended platform-specific delays for better stream loading stability
          if (Platform.isIOS) {
            await Future.delayed(const Duration(milliseconds: 1000)); // Extended delay for iOS
          } else if (Platform.isMacOS) {
            await Future.delayed(const Duration(milliseconds: 800)); // Extended delay for macOS  
          } else {
            await Future.delayed(const Duration(milliseconds: 400)); // Extended for Android
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
          
          // Android: Upgrade to full controls now that playback is working
          if (Platform.isAndroid) {
            _upgradeAndroidControlsAfterSuccess();
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
        
        // Special handling for "Loading interrupted" errors - give a longer recovery delay
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('loading interrupted') || errorString.contains('interrupted')) {
          _logger.info('Loading interrupted detected, adding recovery delay', 'AudioHandler');
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        // Special handling for Android "Connection aborted" errors from foreground service issues
        if (Platform.isAndroid && (errorString.contains('connection aborted') || 
                                   errorString.contains('foregroundservicestart'))) {
          _logger.warning('Android connection aborted - likely foreground service issue', 'AudioHandler');
          if (kDebugMode) {
            print('=== ANDROID CONNECTION ABORTED DETECTED ===');
            print('This is likely due to Android blocking the foreground service');
            print('Switching to Android service bypass mode...');
          }
          
          // Transition to bypass mode when connection issues are detected
          final newConfig = _androidServiceManager.transitionToBypass(
            BypassReason.foregroundServiceError,
            'Connection aborted during track loading'
          );
          
          if (kDebugMode) {
            print('Android service manager: ${newConfig.description}');
            print('Attempting to continue with pure just_audio...');
          }
          
          // Try to continue with bypass mode for remaining URLs
          try {
            for (int bypassIndex = i + 1; bypassIndex < streamUrls.length; bypassIndex++) {
              final bypassUrl = streamUrls[bypassIndex];
              
              if (kDebugMode) {
                print('Bypass mode: Trying URL ${bypassIndex + 1}/${streamUrls.length}');
              }
              
              try {
                await _player.stop();
                await Future.delayed(const Duration(milliseconds: 500));
                await _player.setUrl(bypassUrl);
                await Future.delayed(const Duration(milliseconds: 1000));
                
                if (shouldPlay && _userIntendedPlaying) {
                  await _player.play();
                }
                
                loaded = true;
                
                if (kDebugMode) {
                  print('=== BYPASS MODE RECOVERY SUCCESS ===');
                  print('Successfully loaded in bypass mode');
                  print('URL: $bypassUrl');
                }
                
                break; // Exit the bypass loop on success
                
              } catch (bypassError) {
                if (kDebugMode) {
                  print('Bypass mode URL ${bypassIndex + 1} failed: $bypassError');
                }
              }
            }
            
            // If bypass mode worked, exit the main URL loop
            if (loaded) {
              break;
            }
            
          } catch (bypassError) {
            if (kDebugMode) {
              print('Bypass mode recovery failed: $bypassError');
            }
          }
          
          try {
            // Reset player to clear any corrupted state (fallback)
            await _player.stop();
            await Future.delayed(const Duration(milliseconds: 1000)); // Longer delay for Android
            
            // Clear concatenating source to avoid ExoPlayer issues
            _concatenatingSource = null;
            
            if (kDebugMode) {
              print('Android recovery reset completed, continuing to next URL...');
            }
          } catch (resetError) {
            if (kDebugMode) {
              print('Android recovery reset failed: $resetError');
            }
          }
        }
        
        // Platform-specific URL retry logic  
        if ((Platform.isIOS || Platform.isMacOS) && i < streamUrls.length - 1) {
          _logger.info('Trying next stream URL...', 'AudioHandler');
          if (kDebugMode) {
            print('${Platform.isIOS ? "iOS" : "macOS"}: Trying next stream URL immediately...');
          }
          continue;
        }
        
        // Android retry logic with longer delays for foreground service recovery
        if (Platform.isAndroid && i < streamUrls.length - 1) {
          _logger.info('Android: Trying next stream URL after delay...', 'AudioHandler');
          if (kDebugMode) {
            print('Android: Trying next stream URL after recovery delay...');
          }
          await Future.delayed(const Duration(milliseconds: 800)); // Extra delay for Android
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
    });
  }

  // Custom methods for the app
  Future<void> playTrack(Track track) async {
    _logger.info('=== PLAY TRACK REQUEST START ===', 'AudioHandler');
    _logger.info('Track: ${track.name} (ID: ${track.id})', 'AudioHandler');
    _logger.info('Artist: ${track.artistName ?? "Unknown"}', 'AudioHandler');
    _logger.info('Album: ${track.albumName ?? "Unknown"}', 'AudioHandler');
    _logger.info('Duration: ${track.duration != null ? "${track.duration! ~/ 1000}s" : "Unknown"}', 'AudioHandler');
    
    // Set user intent to playing since this is an explicit play action - use atomic operation
    await _setUserIntentAtomic(true);
    _logger.info('User intent set to playing', 'AudioHandler');
    
    // CRITICAL FIX: Completely reset player state to prevent old queue from continuing
    await _resetPlayerStateCompletely();
    _logger.info('Completed player state reset', 'AudioHandler');
    
    await _queueManager.setSingleTrack(track);
    _logger.info('Set single track in queue manager', 'AudioHandler');
    
    // CRITICAL FIX: Immediately update the MediaItem to prevent UI confusion
    mediaItem.add(_trackToMediaItem(track));
    _logger.info('Updated MediaItem for single track', 'AudioHandler');
    
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
      print('Previous current track: ${_stateManager.currentTrack?.name ?? "None"}');
    }
    
    // Set user intent to playing since this is an explicit play action - use atomic operation
    await _setUserIntentAtomic(true);
    final userIntent = _userIntendedPlaying; // Direct access after setting
    
    // Clear explicit pause flag since we're starting new content
    _userExplicitlyPaused = false;
    
    if (kDebugMode) {
      print('Set _userIntendedPlaying to: $userIntent');
    }
    
    // CRITICAL FIX: Completely reset player state to prevent old queue from continuing
    await _resetPlayerStateCompletely();
    
    if (kDebugMode) {
      print('Completely reset player state');
    }
    
    // Set the new playlist and immediately verify the current track
    await _queueManager.setPlaylist(tracks, startIndex);
    
    // CRITICAL FIX: Immediately update the MediaItem to prevent UI confusion
    if (_stateManager.currentTrack != null) {
      mediaItem.add(_trackToMediaItem(_stateManager.currentTrack!));
    }
    
    if (kDebugMode) {
      print('Set new playlist: ${tracks.length} tracks, starting at index $startIndex');
      print('New current track: ${_stateManager.currentTrack?.name ?? "None"}');
    }
    
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
      final finalUserIntent = _userIntendedPlaying; // Direct access to avoid deadlock
      print('Final player state - playing: ${_player.playing}, userIntent: $finalUserIntent');
      print('Final current track: ${_stateManager.currentTrack?.name ?? "None"}');
      print('=== PLAYPLAYLIST DEBUG END ===');
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
          // Use MediaServiceManagerCoordinator if available, otherwise fall back to JellyfinService
          final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
          final imageUrl = mediaServiceCoordinator != null 
            ? mediaServiceCoordinator.getImageUrl(track.imageUrl!, width: 300, height: 300)
            : _jellyfinService.getImageUrl(track.imageUrl!, width: 300, height: 300);
          artUri = Uri.parse(imageUrl ?? '');
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

  Future<void> shuffle() async {
    _preloader.clearAllPreloadedPlayers();
    _audioSourceCache.clear();
    
    // If using concatenation, need to rebuild the concatenating source
    if (_isUsingConcatenation) {
      _isUsingConcatenation = false;
      _concatenatingSource = null;
    }
    
    await _queueManager.shuffle();
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

  Future<void> unshuffle() async {
    await _queueManager.unshuffle();
  }

  // Radio Mode functionality with synchronized state management
  Future<void> toggleRadioMode() async {
    await _radioModeOperationManager.executeOperation('toggleRadioMode', () async {
      await _radioModeStateManager.toggle();
      // Sync with state manager for backward compatibility
      _stateManager.setRadioModeEnabled(_radioModeStateManager.isEnabled);
    });
  }

  Future<void> enableRadioMode() async {
    await _radioModeOperationManager.executeOperation('enableRadioMode', () async {
      await _radioModeStateManager.enable();
      _stateManager.setRadioModeEnabled(true);
    });
  }

  Future<void> disableRadioMode() async {
    await _radioModeOperationManager.executeOperation('disableRadioMode', () async {
      await _radioModeStateManager.disable();
      _stateManager.setRadioModeEnabled(false);
    });
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
  bool get radioModeEnabled => _radioModeStateManager.isEnabled;
  int get queueLength => _stateManager.queueLength;
  
  /// Returns whether the user intends to play (regardless of current player state)
  bool get userIntendedPlaying => _userIntendedPlaying;

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

  Future<void> toggleMute() async {
    await _mutexManager.withLock('volumeState', () async {
      if (_player.volume > 0.0) {
        _previousVolume = _player.volume;
        await setVolume(0.0);
      } else {
        await setVolume(_previousVolume ?? 1.0);
      }
    });
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
        
        // Use MediaServiceManagerCoordinator if available to get multiple fallback URLs
        final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
        final streamUrls = <String>[];
        if (mediaServiceCoordinator != null) {
          // Prefer explicit alternative URLs if the service provides them
          List<String> alt;
          if (mediaServiceCoordinator.currentServerType.toString().contains('plex')) {
            alt = await mediaServiceCoordinator.getAlternativeStreamUrlsAsync(currentTrack.id);
          } else {
            alt = mediaServiceCoordinator.getAlternativeStreamUrls(currentTrack.id);
          }
          if (alt.isNotEmpty) {
            streamUrls.addAll(alt);
          } else {
            // Fallback to single canonical URL
            final primary = mediaServiceCoordinator.getStreamUrl(currentTrack.id);
            if (primary != null && primary.isNotEmpty) streamUrls.add(primary);
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
    // Use MediaServiceManagerCoordinator if available, otherwise fallback to JellyfinService
    final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
    final streamUrl = mediaServiceCoordinator != null 
      ? (mediaServiceCoordinator.getStreamUrl(track.id) ?? '')
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
    await _statePersistenceManager.dispose();
    _radioModeStateManager.dispose();
    _radioModeOperationManager.dispose();
    await _touchBarUpdateManager.dispose();
    await _downloadServiceCoordinator.dispose();
    await _jellyfinServiceCoordinator.dispose();
    await _errorStateManager.dispose();
    await _audioSessionCoordinator.dispose();
    _playerStateTransitionCoordinator.dispose();
    await _mediaServiceManagerCoordinator?.dispose();
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
            // Use MediaServiceManagerCoordinator if available, otherwise fall back to JellyfinService
            final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
            final imageUrl = album.imageUrl != null 
              ? (mediaServiceCoordinator != null 
                  ? (mediaServiceCoordinator.getImageUrl(album.imageUrl!, width: 300, height: 300) ?? '')
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
            // Use MediaServiceManagerCoordinator if available, otherwise fall back to JellyfinService
            final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
            final imageUrl = artist.imageUrl != null 
              ? (mediaServiceCoordinator != null 
                  ? (mediaServiceCoordinator.getImageUrl(artist.imageUrl!, width: 300, height: 300) ?? '')
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
              // Use MediaServiceManagerCoordinator if available, otherwise fall back to JellyfinService
              final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
              final tracks = mediaServiceCoordinator != null 
                ? await mediaServiceCoordinator.getTracks(parentId: albumId)
                : await _jellyfinServiceCoordinator.getAlbumTracks(albumId);
              
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
              final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
              final allAlbums = mediaServiceCoordinator != null 
                ? await mediaServiceCoordinator.getAlbums()
                : await _jellyfinServiceCoordinator.getAlbums();
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
                  // Use MediaServiceManagerCoordinator if available, otherwise fall back to JellyfinService
                  final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
                  final imageUrl = album.imageUrl != null 
                    ? (mediaServiceCoordinator != null 
                        ? (mediaServiceCoordinator.getImageUrl(album.imageUrl!, width: 300, height: 300) ?? '')
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
              // Use MediaServiceManagerCoordinator if available, otherwise fall back to JellyfinService
              final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
              final tracks = mediaServiceCoordinator != null 
                ? await mediaServiceCoordinator.getPlaylistTracks(playlistId)
                : await _jellyfinServiceCoordinator.getPlaylistTracks(playlistId);
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
        final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
        final tracks = mediaServiceCoordinator != null 
          ? await mediaServiceCoordinator.getTracks(parentId: albumId)
          : await _jellyfinServiceCoordinator.getAlbumTracks(albumId);
        if (tracks.isNotEmpty) {
          await playPlaylist(tracks, 0);
        }
      } else if (mediaItem.id.startsWith('playlist:')) {
        final playlistId = mediaItem.id.substring(9);
        final mediaServiceCoordinator = _mediaServiceManagerCoordinator;
        final tracks = mediaServiceCoordinator != null 
          ? await mediaServiceCoordinator.getPlaylistTracks(playlistId)
          : await _jellyfinServiceCoordinator.getPlaylistTracks(playlistId);
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

  /// Initialize Touch Bar service and set up callbacks with synchronization
  void _initializeTouchBar() async {
    if (!Platform.isMacOS) return;
    
    try {
      // Initialize the synchronized TouchBar manager
      final initialized = await _touchBarUpdateManager.initialize();
      
      if (initialized) {
        // Set up callbacks for TouchBar button presses
        await _touchBarUpdateManager.setCallbacks(
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
        
        _logger.info('TouchBar initialized with synchronized callbacks', 'AudioHandler');
        if (kDebugMode) {
          print('TouchBar initialized with synchronized callbacks');
        }
      } else {
        _touchBarEnabled = false;
        _logger.warning('TouchBar initialization failed', 'AudioHandler');
      }
    } catch (e) {
      _logger.error('Failed to initialize TouchBar: $e', 'AudioHandler');
      if (kDebugMode) {
        print('Failed to initialize TouchBar: $e');
      }
      _touchBarEnabled = false;
    }
  }

  void _updateTouchBarWithCurrentTrack() {
    if (!_touchBarEnabled) return;
    
    final currentTrack = _stateManager.currentTrack;
    _touchBarUpdateManager.updateNowPlaying(currentTrack);
  }

  void _updateTouchBarPlaybackState() {
    if (!_touchBarEnabled) return;
    
    final currentTrack = _stateManager.currentTrack;
    _touchBarUpdateManager.updatePlaybackState(
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
        _touchBarUpdateManager.updateLyrics(lyricsText);
        
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
      _touchBarUpdateManager.updateLyrics(null);
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
        _touchBarUpdateManager.updateLyrics(null);
        
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
      _touchBarUpdateManager.updateLyrics(null);
    }
  }

  void _disposeTouchBar() {
    if (_touchBarEnabled) {
      _touchBarUpdateManager.dispose();
      TouchBarService.dispose();
      _touchBarEnabled = false;
    }
  }
}