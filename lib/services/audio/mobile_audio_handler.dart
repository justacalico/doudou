import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/jellyfin_models.dart';

import '../media_service_manager.dart';
import 'base_audio_handler.dart' as base_handler;
import 'audio_state_controller.dart';
import 'queue_manager.dart';

/// DoudouAudioHandler - Mobile audio handler for Android and iOS
/// Integrates with AudioService for background playback and system integration
class DoudouAudioHandler extends BaseAudioHandler {
  final MediaServiceManager _mediaServiceManager;
  final AudioStateController _stateController = AudioStateController();
  final AudioQueueManager _queueManager = AudioQueueManager();
  final AudioPlayer _player = AudioPlayer();

  // Stream subscriptions for proper cleanup
  late final List<StreamSubscription> _subscriptions = [];

  // Playback session management
  AudioSession? _session;

  // Radio mode state
  bool _radioModeEnabled = false;
  Timer? _radioModeTimer;
  
  // Loading timeout management
  Timer? _loadingTimeoutTimer;
  static const Duration _loadingTimeout = Duration(seconds: 30);

  // Foreground service management - ENHANCED
  int _foregroundServiceFailureCount = 0;
  DateTime? _lastForegroundServiceAttempt;
  static const int _maxConsecutiveFailures = 5;
  static const Duration _foregroundServiceRetryDelay = Duration(seconds: 3);
  Timer? _foregroundServiceRecoveryTimer;
  Timer? _foregroundServiceHeartbeatTimer;
  bool _foregroundServiceActive = false;
  
  // Power management
  bool _wakeLockActive = false;
  Timer? _wakeLockMonitorTimer;

  // Constructor
  DoudouAudioHandler({required MediaServiceManager mediaServiceManager})
    : _mediaServiceManager = mediaServiceManager {
    _initializeAudio();
  }

  /// Initialize audio system
  Future<void> _initializeAudio() async {
    try {
      if (kDebugMode) {
        print('DoudouAudioHandler: Initializing audio system...');
      }

      // Initialize audio session
      await _initializeAudioSession();

      // Set up player event listeners
      _setupPlayerListeners();

      // Set up state synchronization
      _setupStateSynchronization();

      // Start foreground service recovery monitor
      _startForegroundServiceMonitor();

      // Initialize power management optimizations
      _initializePowerManagement();

      if (kDebugMode) {
        print('DoudouAudioHandler: Audio system initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to initialize audio system: $e');
      }
      _stateController.updateError('Failed to initialize audio: $e');
    }
  }
  
  /// Initialize power management optimizations
  void _initializePowerManagement() {
    // Request battery optimization exemption on first run
    // This helps prevent Android from aggressively killing the service
    Future.microtask(() async {
      try {
        // This would be implemented using platform channels in a real app
        if (kDebugMode) {
          print('DoudouAudioHandler: Power management optimizations initialized');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Power management initialization failed: $e');
        }
      }
    });
  }

  /// Initialize audio session for background playback
  Future<void> _initializeAudioSession() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());

      if (kDebugMode) {
        print('DoudouAudioHandler: Audio session configured');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to configure audio session: $e');
      }
    }
  }

  /// Start monitoring for foreground service recovery
  void _startForegroundServiceMonitor() {
    // Check every 15 seconds if we can recover from foreground service issues
    _foregroundServiceRecoveryTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _attemptForegroundServiceRecovery(),
    );
    
    // Heartbeat timer to keep foreground service alive during playback
    _startForegroundServiceHeartbeat();
    
    // Monitor power management
    _startPowerManagementMonitor();
  }
  
  /// Start heartbeat timer to maintain foreground service
  void _startForegroundServiceHeartbeat() {
    _foregroundServiceHeartbeatTimer?.cancel();
    _foregroundServiceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _maintainForegroundService(),
    );
  }
  
  /// Start power management monitoring
  void _startPowerManagementMonitor() {
    _wakeLockMonitorTimer?.cancel();
    _wakeLockMonitorTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkPowerManagement(),
    );
  }
  
  /// Maintain foreground service during active playback
  void _maintainForegroundService() {
    // Only maintain if we're playing or intending to play
    if (_stateController.currentState == base_handler.AudioPlayerState.playing ||
        _stateController.userIntendedPlaying) {
      
      if (!_foregroundServiceActive) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Foreground service not active, attempting restart');
        }
        _attemptForegroundService();
      } else {
        // Send heartbeat to keep service alive
        _sendForegroundServiceHeartbeat();
      }
    }
  }
  
  /// Send heartbeat to maintain foreground service
  void _sendForegroundServiceHeartbeat() {
    try {
      final currentState = _stateController.currentState;
      final position = _stateController.position;
      final speed = _stateController.speed;
      
      final heartbeatState = _createPlaybackState(currentState, position, speed);
      playbackState.add(heartbeatState);
      
      if (kDebugMode && DateTime.now().second % 30 == 0) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Foreground service heartbeat sent');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Heartbeat failed: $e');
      }
      _foregroundServiceActive = false;
    }
  }
  
  /// Check and maintain power management settings
  void _checkPowerManagement() {
    // During active playback, ensure we have proper power management
    if (_stateController.currentState == base_handler.AudioPlayerState.playing) {
      _ensureWakeLock();
    } else if (!_stateController.userIntendedPlaying) {
      _releaseWakeLock();
    }
  }
  
  /// Ensure wake lock is active during playback
  void _ensureWakeLock() {
    if (!_wakeLockActive) {
      _requestWakeLock();
    }
  }
  
  /// Request wake lock to prevent device sleep during playback
  void _requestWakeLock() {
    try {
      // Wake lock is implicitly handled by AudioService when in foreground
      // but we can add additional measures here if needed
      _wakeLockActive = true;
      
      if (kDebugMode) {
        print('DoudouAudioHandler: Wake lock requested');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Wake lock request failed: $e');
      }
    }
  }
  
  /// Release wake lock when not needed
  void _releaseWakeLock() {
    if (_wakeLockActive) {
      try {
        _wakeLockActive = false;
        
        if (kDebugMode) {
          print('DoudouAudioHandler: Wake lock released');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Wake lock release failed: $e');
        }
      }
    }
  }

  /// Attempt to recover from foreground service failures
  void _attemptForegroundServiceRecovery() {
    // Only attempt recovery if we had failures and enough time has passed
    if (_foregroundServiceFailureCount > 0 &&
        _lastForegroundServiceAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        _lastForegroundServiceAttempt!,
      );

      if (timeSinceLastAttempt > _foregroundServiceRetryDelay) {
        if (kDebugMode) {
          print(
            'DoudouAudioHandler: Attempting foreground service recovery...',
          );
        }

        // Reset failure count to allow retry
        _foregroundServiceFailureCount = 0;

        // If we're currently playing, try to re-establish foreground service
        if (_stateController.currentState ==
            base_handler.AudioPlayerState.playing) {
          _attemptForegroundService();
        }
      }
    }
  }

  /// Set up player event listeners
  void _setupPlayerListeners() {
    // Position stream - don't queue position updates for performance
    _subscriptions.add(
      _player.positionStream.listen((position) {
        _stateController.updatePosition(position);
      }),
    );

    // Duration stream
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        _stateController.updateDuration(duration ?? Duration.zero);
      }),
    );

    // Player state stream
    _subscriptions.add(
      _player.playerStateStream.listen(_handlePlayerStateChange),
    );

    // Processing state for loading detection
    _subscriptions.add(
      _player.processingStateStream.listen(_handleProcessingStateChange),
    );

    // Player completion
    _subscriptions.add(
      _player.playbackEventStream
          .where((event) => event.processingState == ProcessingState.completed)
          .listen((_) => _handleTrackCompletion()),
    );
  }

  /// Set up state synchronization with AudioService
  void _setupStateSynchronization() {
    // Sync playback state to AudioService
    _subscriptions.add(
      CombineLatestStream.combine3(
        _stateController.stateStream,
        _stateController.positionStream,
        _player.speedStream,
        (
          base_handler.AudioPlayerState state,
          Duration position,
          double speed,
        ) => _createPlaybackState(state, position, speed),
      ).listen((playbackState) {
        _safeUpdatePlaybackState(playbackState);
      }),
    );

    // Sync current track to MediaItem
    _subscriptions.add(
      _stateController.currentTrackStream.listen((track) {
        _safeUpdateMediaItem(track);
      }),
    );

    // Sync queue to AudioService
    _subscriptions.add(
      _stateController.queueStream.listen((tracks) {
        _safeUpdateQueue(tracks);
      }),
    );
  }

  /// Check if we should skip foreground service attempts
  bool get _shouldSkipForegroundService {
    return _foregroundServiceFailureCount >= _maxConsecutiveFailures &&
        _lastForegroundServiceAttempt != null &&
        DateTime.now().difference(_lastForegroundServiceAttempt!) <
            _foregroundServiceRetryDelay;
  }

  /// Safely update playback state with improved error handling
  void _safeUpdatePlaybackState(PlaybackState state) {
    if (_shouldSkipForegroundService) {
      return;
    }

    try {
      playbackState.add(state);
      _foregroundServiceActive = true;
      
      // Success - reset failure count
      if (_foregroundServiceFailureCount > 0) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Foreground service recovered');
        }
        _foregroundServiceFailureCount = 0;
      }
    } catch (e) {
      _foregroundServiceFailureCount++;
      _lastForegroundServiceAttempt = DateTime.now();
      _foregroundServiceActive = false;

      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Playback state update failed (attempt $_foregroundServiceFailureCount/$_maxConsecutiveFailures): $e',
        );
      }
      
      // If we're currently playing and the service dies, try immediate recovery
      if (_stateController.currentState == base_handler.AudioPlayerState.playing &&
          _foregroundServiceFailureCount < _maxConsecutiveFailures) {
        
        if (kDebugMode) {
          print('DoudouAudioHandler: Attempting immediate service recovery...');
        }
        
        Future.delayed(const Duration(milliseconds: 500), () {
          _attemptForegroundService();
        });
      }
    }
  }

  /// Safely update media item with improved error handling
  void _safeUpdateMediaItem(Track? track) {
    if (_shouldSkipForegroundService) {
      return;
    }

    try {
      if (track != null) {
        mediaItem.add(_trackToMediaItem(track));
      } else {
        mediaItem.add(null);
      }
      // Success - reset failure count
      if (_foregroundServiceFailureCount > 0) {
        _foregroundServiceFailureCount = 0;
      }
    } catch (e) {
      _foregroundServiceFailureCount++;
      _lastForegroundServiceAttempt = DateTime.now();

      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Media item update failed (attempt $_foregroundServiceFailureCount/$_maxConsecutiveFailures): $e',
        );
      }
    }
  }

  /// Force MediaItem update for UI synchronization
  void _forceMediaItemUpdate(Track? track) {
    try {
      if (track != null) {
        mediaItem.add(_trackToMediaItem(track));
      } else {
        mediaItem.add(null);
      }

      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Forced MediaItem update for UI synchronization: ${track?.name}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Forced MediaItem update failed: $e');
      }
    }
  }

  /// Safely update queue with improved error handling
  void _safeUpdateQueue(List<Track> tracks) {
    if (_shouldSkipForegroundService) {
      return;
    }

    try {
      queue.add(tracks.map(_trackToMediaItem).toList());
      // Success - reset failure count
      if (_foregroundServiceFailureCount > 0) {
        _foregroundServiceFailureCount = 0;
      }
    } catch (e) {
      _foregroundServiceFailureCount++;
      _lastForegroundServiceAttempt = DateTime.now();

      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Queue update failed (attempt $_foregroundServiceFailureCount/$_maxConsecutiveFailures): $e',
        );
      }
    }
  }

  /// Force comprehensive UI synchronization for track changes
  void _forceUISynchronization(Track track, int index) {
    // Ensure state controller has the latest information first
    _stateController.updateCurrentIndex(index);
    _stateController.updateCurrentTrack(track);

    // Force MediaItem update for UI purposes
    _forceMediaItemUpdate(track);

    // Safely update PlaybackState with correct queue index
    final currentPlaybackState = playbackState.valueOrNull ?? PlaybackState();
    final updatedPlaybackState = currentPlaybackState.copyWith(
      queueIndex: index,
    );
    _safeUpdatePlaybackState(updatedPlaybackState);

    if (kDebugMode) {
      print(
        'DoudouAudioHandler: Force UI sync - track: ${track.name}, index: $index',
      );
    }
  }

  /// Handle player state changes
  void _handlePlayerStateChange(PlayerState playerState) {
    switch (playerState.processingState) {
      case ProcessingState.idle:
        _stateController.updateState(base_handler.AudioPlayerState.idle);
        _foregroundServiceActive = false;
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _stateController.updateState(base_handler.AudioPlayerState.loading);
        // Be aggressive about foreground service during loading
        if (_stateController.userIntendedPlaying) {
          _attemptForegroundService();
        }
        break;
      case ProcessingState.ready:
        if (playerState.playing) {
          _stateController.updateState(base_handler.AudioPlayerState.playing);
          // Aggressively ensure foreground service is running when playing
          _attemptForegroundService();
          _ensureWakeLock();
        } else {
          // Check if we should auto-continue playback
          if (_stateController.userIntendedPlaying &&
              _stateController.currentState ==
                  base_handler.AudioPlayerState.loading) {
            if (kDebugMode) {
              print(
                'DoudouAudioHandler: Track ready, auto-continuing playback',
              );
            }
            // Resume playback without blocking - be more aggressive
            Future.microtask(() async {
              try {
                // Multiple attempts at foreground service
                await _attemptForegroundService();
                await Future.delayed(const Duration(milliseconds: 50));
                await _attemptForegroundService();
                await _player.play();
              } catch (e) {
                if (kDebugMode) {
                  print('DoudouAudioHandler: Auto-continue failed: $e');
                }
                // Continue anyway - foreground service failure shouldn't stop playback
                try {
                  await _player.play();
                } catch (playError) {
                  if (kDebugMode) {
                    print(
                      'DoudouAudioHandler: Player.play() also failed: $playError',
                    );
                  }
                  _stateController.updateError(
                    'Failed to continue playback: $playError',
                  );
                }
              }
            });
          }
          _stateController.updateState(base_handler.AudioPlayerState.paused);
        }
        break;
      case ProcessingState.completed:
        _stateController.updateState(base_handler.AudioPlayerState.completed);
        _foregroundServiceActive = false;
        break;
    }
  }

  /// Handle processing state changes
  void _handleProcessingStateChange(ProcessingState state) {
    if (state == ProcessingState.ready) {
      _stateController.clearError();
      // Cancel loading timeout when track is ready
      _cancelLoadingTimeout();
    } else if (state == ProcessingState.completed) {
      // Cancel loading timeout when track completes
      _cancelLoadingTimeout();
    }
  }

  /// Handle track completion
  Future<void> _handleTrackCompletion() async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Track completed');
    }

    // In radio mode, fetch and play similar tracks
    if (_radioModeEnabled) {
      await _handleRadioModeNext();
      return;
    }

    // Normal mode - advance to next track
    final nextIndex = _queueManager.getNextTrackIndex();
    if (nextIndex != null) {
      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Auto-advancing to next track (index: $nextIndex)',
        );
      }

      await _performSkipToQueueItem(nextIndex);
    } else {
      // End of queue
      _stateController.updateState(base_handler.AudioPlayerState.completed);
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
        print('DoudouAudioHandler: Failed to fetch radio tracks: $e');
      }
      // Fallback to normal next track behavior
      await skipToNext();
    }
  }

  /// Fetch similar tracks for radio mode
  Future<List<Track>> _fetchSimilarTracks(Track track) async {
    try {
      final artistTracks = await _mediaServiceManager.getTracks(
        parentId: track.artistName,
        limit: 20,
      );

      final currentQueue = _stateController.queue;
      final queueIds = currentQueue.map((t) => t.id).toSet();

      return artistTracks
          .where((t) => t.id != track.id && !queueIds.contains(t.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Error fetching similar tracks: $e');
      }
      return [];
    }
  }

  /// Create PlaybackState for AudioService with enhanced notification priority
  PlaybackState _createPlaybackState(
    base_handler.AudioPlayerState state,
    Duration position,
    double speed,
  ) {
    // Enhanced controls for better foreground service priority
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (state == base_handler.AudioPlayerState.playing)
        MediaControl.pause
      else
        MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];
    
    // Add rewind/fast forward if track is long enough
    final duration = _stateController.duration;
    if (duration.inSeconds > 30) {
      controls.insert(0, MediaControl.rewind);
      controls.add(MediaControl.fastForward);
    }
    
    return PlaybackState(
      controls: controls,
      systemActions: const {
        // Core playback actions
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.rewind,
        MediaAction.fastForward,
        
        // Transport controls
        MediaAction.stop,
        MediaAction.pause,
        MediaAction.play,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        
        // Queue management
        MediaAction.skipToQueueItem,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
        
        // Additional actions to increase notification importance
        MediaAction.playFromMediaId,
        MediaAction.playFromSearch,
        MediaAction.playFromUri,
      },
      androidCompactActionIndices: controls.length >= 5 
          ? const [1, 2, 3] // Skip rewind/FF in compact view if present
          : const [0, 1, 2],
      processingState: _mapToAudioServiceProcessingState(state),
      playing: state == base_handler.AudioPlayerState.playing,
      updatePosition: position,
      bufferedPosition: _player.bufferedPosition,
      speed: speed,
      queueIndex: _stateController.currentIndex,
      // Additional properties to make notification more persistent
      repeatMode: _mapToAudioServiceRepeatMode(_stateController.repeatMode),
      shuffleMode: _stateController.shuffleEnabled 
          ? AudioServiceShuffleMode.all 
          : AudioServiceShuffleMode.none,
    );
  }
  
  /// Map our repeat mode to AudioService repeat mode
  AudioServiceRepeatMode _mapToAudioServiceRepeatMode(base_handler.RepeatMode mode) {
    switch (mode) {
      case base_handler.RepeatMode.none:
        return AudioServiceRepeatMode.none;
      case base_handler.RepeatMode.one:
        return AudioServiceRepeatMode.one;
      case base_handler.RepeatMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  /// Map internal state to AudioService ProcessingState
  AudioProcessingState _mapToAudioServiceProcessingState(
    base_handler.AudioPlayerState state,
  ) {
    switch (state) {
      case base_handler.AudioPlayerState.idle:
        return AudioProcessingState.idle;
      case base_handler.AudioPlayerState.loading:
        return AudioProcessingState.loading;
      case base_handler.AudioPlayerState.playing:
      case base_handler.AudioPlayerState.paused:
        return AudioProcessingState.ready;
      case base_handler.AudioPlayerState.completed:
        return AudioProcessingState.completed;
      case base_handler.AudioPlayerState.error:
        return AudioProcessingState.error;
    }
  }

  /// Convert Track to MediaItem with enhanced metadata
  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      album: track.albumName ?? 'Unknown Album',
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      duration: track.duration != null
          ? Duration(milliseconds: track.duration!)
          : null,
      artUri: Uri.tryParse(
        _mediaServiceManager.getImageUrl(
          track.albumId ?? track.id,
          width: 512, // Higher resolution for better notification display
          height: 512,
        ),
      ),
      playable: true,
      extras: {
        'trackId': track.id,
        'albumId': track.albumId,
        'trackNumber': track.trackNumber,
        'isPlayable': true,
        'mediaType': 'audio',
        'playCount': track.playCount,
        'isFavorite': track.isFavorite,
        // Additional metadata to increase notification importance
        'description': '${track.artistName} - ${track.albumName}',
        'displayTitle': track.name,
        'displaySubtitle': '${track.artistName} • ${track.albumName}',
        'displayDescription': 'Playing from ${track.albumName ?? "Unknown Album"}',
        // Android Auto / Automotive compatibility
        'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
        'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 2,
      },
    );
  }

  // BaseAudioHandler implementation

  Stream<base_handler.AudioPlayerState> get stateStream =>
      _stateController.stateStream;

  Stream<Duration> get positionStream => _stateController.positionStream;

  Stream<Duration?> get durationStream => _stateController.durationStream;

  Stream<double> get volumeStream => _player.volumeStream;

  Stream<List<MediaItem>> get queueStream => queue.stream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<Track?> get currentTrackStream => _stateController.currentTrackStream;

  Stream<base_handler.RepeatMode> get repeatModeStream =>
      _stateController.repeatModeStream;

  Stream<bool> get shuffleEnabledStream =>
      _stateController.shuffleEnabledStream;

  Stream<double> get speedStream => _stateController.speedStream;

  Stream<String?> get errorStream => _stateController.errorStream;

  base_handler.AudioPlayerState get currentState =>
      _stateController.currentState;

  Duration get position => _stateController.position;

  Duration get duration => _stateController.duration;

  Track? get currentTrack => _stateController.currentTrack;

  List<Track> get queueTracks => _stateController.queue;

  List<Track> get upNext => _queueManager.getUpNext();

  double get volume => _stateController.volume;

  double get speed => _stateController.speed;

  bool get userIntendedPlaying => _stateController.userIntendedPlaying;

  PlayerState get playerState => _player.playerState;

  int? get currentIndex => _stateController.currentIndex;

  bool get hasNext => _queueManager.hasNext;

  bool get hasPrevious => _queueManager.hasPrevious;

  base_handler.RepeatMode get repeatMode => _stateController.repeatMode;

  bool get shuffleEnabled => _stateController.shuffleEnabled;

  bool get gaplessPlaybackEnabled => _stateController.gaplessPlaybackEnabled;

  bool get radioModeEnabled => _radioModeEnabled;

  // Playback control methods

  @override
  Future<void> play() async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Play command received');
    }

    // Update UI state immediately for responsiveness
    _stateController.updateUserIntent(true);
    _stateController.updateState(base_handler.AudioPlayerState.loading);

    // Run the actual audio operation asynchronously without blocking UI
    _performPlayOperation();
  }

  Future<void> _performPlayOperation() async {
    try {
      // Reset failure count when user explicitly plays
      _foregroundServiceFailureCount = 0;

      // Be very aggressive about establishing foreground service
      await _attemptForegroundService();
      
      // Multiple attempts to ensure foreground service is established
      for (int attempt = 0; attempt < 3; attempt++) {
        if (_foregroundServiceActive) break;
        
        await Future.delayed(Duration(milliseconds: 50 * (attempt + 1)));
        await _attemptForegroundService();
      }

      await _player.play();
      
      // Verify foreground service after play starts
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_foregroundServiceActive) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Foreground service not active after play, retrying...');
        }
        await _attemptForegroundService();
      }
      
      if (kDebugMode) {
        print('DoudouAudioHandler: Play command completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Play failed: $e');
      }
      _stateController.updateError('Play failed: $e');
      _stateController.updateUserIntent(false);
      _stateController.updateState(base_handler.AudioPlayerState.error);
    }
  }

  /// Attempt to start foreground service with enhanced retry logic
  Future<void> _attemptForegroundService() async {
    // Skip if we've had too many recent failures
    if (_shouldSkipForegroundService) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Skipping foreground service (cooling down)');
      }
      return;
    }

    try {
      // Step 1: Update MediaItem first to ensure we have content
      final currentTrack = _stateController.currentTrack;
      if (currentTrack != null) {
        mediaItem.add(_trackToMediaItem(currentTrack));
      }
      
      // Step 2: Create enhanced playback state with high priority
      final currentState = _stateController.currentState;
      final position = _stateController.position;
      final speed = _stateController.speed;

      final enhancedPlaybackState = _createPlaybackState(
        currentState,
        position,
        speed,
      ).copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
        // Add system actions to make the notification more important
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.rewind,
          MediaAction.fastForward,
          MediaAction.stop,
          MediaAction.pause,
          MediaAction.play,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
      );

      playbackState.add(enhancedPlaybackState);

      // Step 3: Longer delay to ensure foreground service starts properly
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Step 4: Send a second update to reinforce the foreground state
      final reinforcementState = enhancedPlaybackState.copyWith(
        updatePosition: _stateController.position,
        bufferedPosition: _player.bufferedPosition,
      );
      playbackState.add(reinforcementState);
      
      // Step 5: Mark as active
      _foregroundServiceActive = true;

      // Success - reset failure count and request wake lock
      if (_foregroundServiceFailureCount > 0) {
        if (kDebugMode) {
          print(
            'DoudouAudioHandler: Foreground service recovered after failures',
          );
        }
        _foregroundServiceFailureCount = 0;
      }
      
      // Ensure wake lock during active playback
      _ensureWakeLock();
      
      if (kDebugMode) {
        print('DoudouAudioHandler: Foreground service established successfully');
      }
      
    } catch (e) {
      _foregroundServiceFailureCount++;
      _lastForegroundServiceAttempt = DateTime.now();
      _foregroundServiceActive = false;

      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Foreground service attempt failed ($_foregroundServiceFailureCount/$_maxConsecutiveFailures): $e',
        );
      }

      // Don't throw - audio should continue even if foreground service fails
    }
  }

  @override
  Future<void> pause() async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Pause command received');
    }

    // Update UI state immediately for responsiveness
    _stateController.updateUserIntent(false);
    _stateController.updateState(base_handler.AudioPlayerState.paused);

    // Run the actual audio operation asynchronously
    _performPauseOperation();
  }

  Future<void> _performPauseOperation() async {
    try {
      await _player.pause();
      if (kDebugMode) {
        print('DoudouAudioHandler: Pause command completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Pause failed: $e');
      }
      _stateController.updateError('Pause failed: $e');
      _stateController.updateState(base_handler.AudioPlayerState.error);
    }
  }

  @override
  Future<void> stop() async {
    return _stateController.queueCommand(() async {
      if (kDebugMode) {
        print('DoudouAudioHandler: Stop command received');
      }

      _stateController.updateUserIntent(false);

      try {
        await _player.stop();
        _stateController.updateState(base_handler.AudioPlayerState.idle);
        if (kDebugMode) {
          print('DoudouAudioHandler: Stop command completed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Stop failed: $e');
        }
        _stateController.updateError('Stop failed: $e');
        rethrow;
      }
    });
  }

  @override
  Future<void> seek(Duration position) async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Seek to ${position.inSeconds}s requested');
    }

    // Update UI position immediately
    _stateController.updatePosition(position);

    // Run the actual seek operation asynchronously
    _performSeekOperation(position);
  }

  Future<void> _performSeekOperation(Duration position) async {
    try {
      await _player.seek(position);
      if (kDebugMode) {
        print('DoudouAudioHandler: Seek to ${position.inSeconds}s completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Seek failed: $e');
      }
      _stateController.updateError('Seek failed: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      _stateController.updateSpeed(speed);
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Set speed failed: $e');
      }
      _stateController.updateError('Set speed failed: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
      _stateController.updateVolume(volume);
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Set volume failed: $e');
      }
      _stateController.updateError('Set volume failed: $e');
    }
  }

  Future<void> playTrack(Track track) async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Playing single track: ${track.name}');
    }

    // Update UI immediately
    _queueManager.setQueue([track], startIndex: 0);
    _stateController.updateCurrentTrack(track);
    _stateController.updateState(base_handler.AudioPlayerState.loading);

    // Force UI synchronization
    _forceMediaItemUpdate(track);

    // Run actual playback asynchronously
    _performPlayTrack(track);
  }

  Future<void> _performPlayTrack(Track track) async {
    try {
      final streamUrl = _getStreamUrl(track);
      await _loadAndPlayTrack(streamUrl);

      if (kDebugMode) {
        print('DoudouAudioHandler: Track loaded and playing');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to play track: $e');
      }
      _stateController.updateError('Failed to play track: $e');
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (kDebugMode) {
      print(
        'DoudouAudioHandler: Playing playlist with ${tracks.length} tracks, starting at $startIndex',
      );
    }

    if (tracks.isEmpty) {
      _stateController.updateError('Cannot play empty playlist');
      return;
    }

    final validStartIndex = startIndex.clamp(0, tracks.length - 1);

    // Set up queue immediately for UI responsiveness
    _queueManager.setQueue(tracks, startIndex: validStartIndex);
    _stateController.updateCurrentTrack(tracks[validStartIndex]);
    _stateController.updateState(base_handler.AudioPlayerState.loading);

    // Run actual playback asynchronously
    _performPlayPlaylist(tracks, validStartIndex);
  }

  Future<void> _performPlayPlaylist(List<Track> tracks, int startIndex) async {
    try {
      await _playTrackAtIndex(startIndex);

      if (kDebugMode) {
        print('DoudouAudioHandler: Playlist loaded and playing');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to play playlist: $e');
      }
      _stateController.updateError('Failed to play playlist: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Skip to next requested');
    }

    final nextIndex = _queueManager.getNextTrackIndex();
    if (nextIndex != null) {
      final queue = _stateController.queue;
      if (nextIndex < queue.length) {
        final nextTrack = queue[nextIndex];
        _stateController.updateCurrentIndex(nextIndex);
        _stateController.updateCurrentTrack(nextTrack);
        _stateController.updateState(base_handler.AudioPlayerState.loading);

        // Force UI synchronization
        _forceMediaItemUpdate(nextTrack);
      }
      // Run actual skip operation asynchronously
      _performSkipToQueueItem(nextIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Skip to previous requested');
    }

    final previousIndex = _queueManager.getPreviousTrackIndex();
    if (previousIndex != null) {
      final queue = _stateController.queue;
      if (previousIndex >= 0 && previousIndex < queue.length) {
        final previousTrack = queue[previousIndex];
        _stateController.updateCurrentIndex(previousIndex);
        _stateController.updateCurrentTrack(previousTrack);
        _stateController.updateState(base_handler.AudioPlayerState.loading);

        // Force UI synchronization
        _forceMediaItemUpdate(previousTrack);
      }
      // Run actual skip operation asynchronously
      _performSkipToQueueItem(previousIndex);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Skip to queue item $index requested');
    }

    final queue = _stateController.queue;
    if (index >= 0 && index < queue.length) {
      final track = queue[index];
      _stateController.updateCurrentIndex(index);
      _stateController.updateCurrentTrack(track);
      _stateController.updateState(base_handler.AudioPlayerState.loading);

      // Force UI synchronization
      _forceUISynchronization(track, index);
    }

    // Run actual skip operation asynchronously
    _performSkipToQueueItem(index);
  }

  Future<void> _performSkipToQueueItem(int index) async {
    try {
      final queue = _stateController.queue;
      if (index < 0 || index >= queue.length) {
        throw Exception('Invalid queue index: $index');
      }

      // Reset failure count on manual skips (user interaction)
      _foregroundServiceFailureCount = 0;

      // Ensure media service is ready before attempting to play
      await _ensureMediaServiceReady();

      await _playTrackAtIndex(index);
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Skip to index failed: $e');
      }
      _stateController.updateError('Skip failed: $e');
    }
  }
  
  /// Ensure media service manager is ready for background operations
  Future<void> _ensureMediaServiceReady() async {
    try {
      // Add a small delay to ensure the service has time to respond
      // This is especially important when called from background/notification context
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Test the media service manager by trying to get a simple value
      final currentTrack = _stateController.currentTrack;
      if (currentTrack != null) {
        try {
          // Test if we can generate URLs - this will fail if service is not ready
          final testUrl = _mediaServiceManager.getStreamUrl(currentTrack.id);
          if (testUrl.isEmpty) {
            if (kDebugMode) {
              print('DoudouAudioHandler: Media service returned empty URL - may not be ready');
            }
            // Add additional delay for service to become ready
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          if (kDebugMode) {
            print('DoudouAudioHandler: Media service test failed: $e');
          }
          // Add additional delay for service to become ready
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (kDebugMode) {
        print('DoudouAudioHandler: Media service readiness check completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Media service readiness check failed: $e');
      }
      // Don't throw - this is just a precaution
    }
  }

  /// Play track at specific queue index with enhanced error handling
  Future<void> _playTrackAtIndex(int index) async {
    final queue = _stateController.queue;
    final track = queue[index];

    _stateController.updateCurrentIndex(index);
    _stateController.updateCurrentTrack(track);

    int urlRetryCount = 0;
    const maxUrlRetries = 3;
    const urlRetryDelay = Duration(milliseconds: 300);
    
    while (urlRetryCount <= maxUrlRetries) {
      try {
        final streamUrl = _getStreamUrl(track);
        
        if (streamUrl.isEmpty) {
          throw Exception('Stream URL is empty');
        }
        
        await _loadAndPlayTrack(streamUrl);
        return; // Success
        
      } catch (e) {
        urlRetryCount++;
        
        if (kDebugMode) {
          print('DoudouAudioHandler: URL generation attempt $urlRetryCount failed for ${track.name}: $e');
        }
        
        if (urlRetryCount > maxUrlRetries) {
          // All retries exhausted
          if (kDebugMode) {
            print('DoudouAudioHandler: Failed to get stream URL after $maxUrlRetries attempts');
          }
          
          // Cancel loading timeout on failure
          _cancelLoadingTimeout();
          
          _stateController.updateState(base_handler.AudioPlayerState.error);
          _stateController.updateError(
            'Unable to load "${track.name}". This may happen when using controls from the notification. Please open the app and try again.'
          );
          return;
        }
        
        // Wait before retrying URL generation
        if (kDebugMode) {
          print('DoudouAudioHandler: Retrying URL generation in ${urlRetryDelay.inMilliseconds}ms...');
        }
        await Future.delayed(urlRetryDelay);
      }
    }
  }

  /// Load and play track from URL
  Future<void> _loadAndPlayTrack(String url) async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Loading audio source: $url');
    }

    _stateController.updateState(base_handler.AudioPlayerState.loading);
    _stateController.updateUserIntent(true);

    // Start loading timeout timer
    _startLoadingTimeout();

    // Run loading operation asynchronously
    _performLoadAndPlayTrack(url);
  }
  
  /// Start loading timeout to prevent indefinite loading states
  void _startLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = Timer(_loadingTimeout, () {
      if (_stateController.currentState == base_handler.AudioPlayerState.loading) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Loading timeout reached - attempting recovery');
        }
        
        _stateController.updateState(base_handler.AudioPlayerState.error);
        _stateController.updateError('Track loading timed out. Please try again or check your connection.');
        
        // Try to recover by attempting to play again
        _attemptLoadingRecovery();
      }
    });
  }
  
  /// Cancel loading timeout when loading succeeds or fails
  void _cancelLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
  }
  
  /// Attempt to recover from loading timeout by retrying current track
  void _attemptLoadingRecovery() {
    final currentTrack = _stateController.currentTrack;
    if (currentTrack != null && _stateController.userIntendedPlaying) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Attempting loading recovery for: ${currentTrack.name}');
      }
      
      Future.delayed(const Duration(seconds: 2), () {
        if (_stateController.currentState == base_handler.AudioPlayerState.error) {
          try {
            final streamUrl = _getStreamUrl(currentTrack);
            _loadAndPlayTrack(streamUrl);
          } catch (e) {
            if (kDebugMode) {
              print('DoudouAudioHandler: Loading recovery failed: $e');
            }
          }
        }
      });
    }
  }

  Future<void> _performLoadAndPlayTrack(String url) async {
    int retryCount = 0;
    const maxRetries = 2;
    const retryDelay = Duration(milliseconds: 500);
    
    while (retryCount <= maxRetries) {
      try {
        if (kDebugMode) {
          print('DoudouAudioHandler: Setting audio source (attempt ${retryCount + 1}): $url');
        }
        
        // Set audio source
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
        if (kDebugMode) {
          print('DoudouAudioHandler: Audio source set successfully');
        }

        // Only start playback if user intended to play
        if (_stateController.userIntendedPlaying) {
          // Try to handle foreground service before starting playback
          await _attemptForegroundService();

          await _player.play();
          if (kDebugMode) {
            print('DoudouAudioHandler: Playback started successfully');
          }
        } else {
          if (kDebugMode) {
            print(
              'DoudouAudioHandler: Audio loaded but not playing (user did not intend to play)',
            );
          }
          _stateController.updateState(base_handler.AudioPlayerState.paused);
        }
        
        // Cancel loading timeout on success
        _cancelLoadingTimeout();
        
        // Success - break out of retry loop
        return;
        
      } catch (e) {
        retryCount++;
        
        if (kDebugMode) {
          print('DoudouAudioHandler: Load and play attempt $retryCount failed: $e');
        }
        
        if (retryCount > maxRetries) {
          // All retries exhausted
          if (kDebugMode) {
            print('DoudouAudioHandler: All retry attempts exhausted');
          }
          
          // Cancel loading timeout on failure
          _cancelLoadingTimeout();
          
          _stateController.updateState(base_handler.AudioPlayerState.error);
          _stateController.updateUserIntent(false);
          _stateController.updateError('Failed to load track after $maxRetries retries: $e');
          return;
        }
        
        // Wait before retrying
        if (kDebugMode) {
          print('DoudouAudioHandler: Retrying in ${retryDelay.inMilliseconds}ms...');
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  /// Get stream URL for track with enhanced error handling
  String _getStreamUrl(Track track) {
    try {
      // Try direct stream first (no transcoding)
      final directUrl = _mediaServiceManager.getDirectStreamUrl(track.id);
      if (directUrl.isNotEmpty) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Using direct stream URL: $directUrl');
        }
        return directUrl;
      }

      // Fallback to transcoded stream
      final transcodedUrl = _mediaServiceManager.getStreamUrl(track.id);
      if (transcodedUrl.isNotEmpty) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Using transcoded stream URL: $transcodedUrl');
        }
        return transcodedUrl;
      }
      
      // If both methods return empty, this is likely a background service issue
      if (kDebugMode) {
        print('DoudouAudioHandler: Both stream URL methods returned empty - possible background service issue');
      }
      
      throw Exception('Unable to generate stream URL for track: ${track.name}');
      
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Error getting stream URL for ${track.name}: $e');
      }
      
      // Re-throw to be handled by the calling method
      throw Exception('Failed to get stream URL: $e');
    }
  }

  // Queue management

  void addToQueue(Track track) {
    _queueManager.addToQueue(track);
  }

  void addNext(Track track) {
    _queueManager.addNext(track);
  }

  void removeFromQueue(int index) {
    _queueManager.removeFromQueue(index);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _queueManager.reorderQueue(oldIndex, newIndex);
  }

  void clearQueue() {
    _queueManager.clearQueue();
  }

  // Playback modes

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    // Convert AudioService repeat mode to our repeat mode
    base_handler.RepeatMode ourMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        ourMode = base_handler.RepeatMode.none;
        break;
      case AudioServiceRepeatMode.one:
        ourMode = base_handler.RepeatMode.one;
        break;
      case AudioServiceRepeatMode.all:
        ourMode = base_handler.RepeatMode.all;
        break;
      case AudioServiceRepeatMode.group:
        ourMode = base_handler.RepeatMode.all; // Map group to all
        break;
    }
    _stateController.updateRepeatMode(ourMode);
  }

  void toggleShuffle() {
    _queueManager.toggleShuffle();
  }

  void setGaplessPlayback(bool enabled) {
    _stateController.updateGaplessPlayback(enabled);
  }

  void toggleRadioMode() {
    _radioModeEnabled = !_radioModeEnabled;
    _stateController.updateRadioMode(_radioModeEnabled);
  }

  void enableRadioMode() {
    _radioModeEnabled = true;
    _stateController.updateRadioMode(true);
  }

  void disableRadioMode() {
    _radioModeEnabled = false;
    _stateController.updateRadioMode(false);
  }
  
  // Power management methods
  
  /// Handle device power state change (called when device is plugged/unplugged)
  void onPowerStateChanged({required bool isPlugged}) {
    if (kDebugMode) {
      print('DoudouAudioHandler: Power state changed - plugged: $isPlugged');
    }
    
    if (!isPlugged && _stateController.currentState == base_handler.AudioPlayerState.playing) {
      // Device was unplugged during playback - be extra aggressive about service
      if (kDebugMode) {
        print('DoudouAudioHandler: Device unplugged during playback, reinforcing foreground service');
      }
      
      // Reset failure count to allow aggressive retries
      _foregroundServiceFailureCount = 0;
      
      // Multiple reinforcement attempts
      _reinforceForegroundService();
      
      // Increase heartbeat frequency temporarily
      _increaseHeartbeatFrequency();
    }
  }
  
  /// Reinforce foreground service when device is unplugged
  void _reinforceForegroundService() {
    // Multiple rapid attempts to establish strong foreground service
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 100 * i), () {
        _attemptForegroundService();
      });
    }
    
    // Follow up with additional attempts
    Future.delayed(const Duration(seconds: 1), () {
      if (_stateController.currentState == base_handler.AudioPlayerState.playing) {
        _attemptForegroundService();
      }
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      if (_stateController.currentState == base_handler.AudioPlayerState.playing) {
        _attemptForegroundService();
      }
    });
  }
  
  /// Temporarily increase heartbeat frequency for better service persistence
  void _increaseHeartbeatFrequency() {
    // Cancel existing heartbeat
    _foregroundServiceHeartbeatTimer?.cancel();
    
    // Start high-frequency heartbeat for 60 seconds
    _foregroundServiceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 3), // Much more frequent
      (_) => _maintainForegroundService(),
    );
    
    // Return to normal frequency after 60 seconds
    Timer(const Duration(seconds: 60), () {
      _startForegroundServiceHeartbeat(); // Return to normal 10-second interval
    });
    
    if (kDebugMode) {
      print('DoudouAudioHandler: Increased heartbeat frequency for better service persistence');
    }
  }
  
  /// Request battery optimization exemption (to be called from main app)
  void requestBatteryOptimizationExemption() {
    if (kDebugMode) {
      print('DoudouAudioHandler: Battery optimization exemption requested');
      print('NOTE: This should be implemented with platform channels in the main app');
      print('The app should guide users to disable battery optimization for the app');
    }
  }

  // Lifecycle management

  Future<void> dispose() async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Disposing...');
    }

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Cancel all timers
    _radioModeTimer?.cancel();
    _foregroundServiceRecoveryTimer?.cancel();
    _foregroundServiceHeartbeatTimer?.cancel();
    _wakeLockMonitorTimer?.cancel();
    _loadingTimeoutTimer?.cancel();

    // Release wake lock
    _releaseWakeLock();

    // Mark foreground service as inactive
    _foregroundServiceActive = false;

    // Stop and dispose player
    try {
      await _player.stop();
      await _player.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Error disposing player: $e');
      }
    }

    // Reset state
    _stateController.reset();

    if (kDebugMode) {
      print('DoudouAudioHandler: Disposed');
    }
  }
}
