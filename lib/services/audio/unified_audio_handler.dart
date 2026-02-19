import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

// Conditional imports for platform-specific features
import 'audio_state_controller.dart';
import 'queue_manager.dart';
import '../../models/jellyfin_models.dart';
import '../media_service_manager.dart';
import 'providers/base_provider_handler.dart';
import 'providers/youtube_music_handler.dart';
import 'providers/soundcloud_handler.dart';
import 'providers/navidrome_handler.dart';
import 'providers/subsonic_handler.dart';
import 'providers/plex_handler.dart';
import 'providers/local_music_handler.dart';

// Platform detection
bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);

/// Audio playback states
enum AudioPlayerState { idle, loading, playing, paused, completed, error }

/// Repeat modes for playback
enum RepeatMode { none, one, all }

/// UnifiedAudioHandler - Cross-platform audio handler
/// Works on mobile (Android/iOS), desktop (Linux/macOS/Windows), and web
/// Uses conditional logic for platform-specific features:
/// - Mobile: AudioService integration, foreground service, wake lock
/// - Desktop: media_kit backend, player recreation
/// - Web: CORS handling, simplified streams
class UnifiedAudioHandler extends BaseAudioHandler {
  UnifiedAudioHandler(this._mediaServiceManager) {
    _player = _createPlayer();
    _initializeAudio();
  }

  final MediaServiceManager _mediaServiceManager;
  final AudioStateController _stateController = AudioStateController();
  final AudioQueueManager _queueManager = AudioQueueManager();

  // Provider handler registry
  final Map<ServerType, BaseProviderHandler> _providerHandlers = {};
  BaseProviderHandler? _currentProviderHandler;
  DateTime? _lastLoadStartedAt;
  DateTime? _lastCompletionHandledAt;

  // Harmony-Music uses simple AudioPlayer() without userAgent/proxy config
  // User-Agent is set via mpv.conf (PlatformAudioConfig) instead

  // Player instance - may be recreated on desktop to prevent native callback crashes
  late AudioPlayer _player;

  AudioPlayer _createPlayer() {
    // Harmony-Music uses simple AudioPlayer() without headers/proxy
    // They use AudioSource.uri() without headers - just_audio handles googlevideo.com natively
    return AudioPlayer();
  }

  // Player generation ID for desktop callback invalidation
  final int _playerGeneration = 0;

  // Stream subscriptions for proper cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Disposed flag to prevent callbacks after cleanup
  bool _disposed = false;

  // Loading operation management
  int _loadOperationId = 0;

  // Guard against multiple rapid completion events (prevents skipping many tracks)
  bool _isHandlingCompletion = false;

  // Radio mode state
  bool _radioModeEnabled = false;
  Timer? _radioModeTimer;

  // Autoplay mode - automatically queue similar tracks when queue ends
  bool _autoplayEnabled = true;

  // Smart back-to-start behavior
  bool _smartBackToStartEnabled = true;
  DateTime? _lastBackPress;
  static const Duration _backPressInterval = Duration(seconds: 3);
  static const double _backRestartThreshold = 0.20; // 20%

  // === Mobile-specific state ===
  // Foreground service management
  int _foregroundServiceFailureCount = 0;
  DateTime? _lastForegroundServiceAttempt;
  static const int _maxConsecutiveFailures = 5;
  static const Duration _foregroundServiceRetryDelay = Duration(seconds: 3);
  Timer? _foregroundServiceRecoveryTimer;
  Timer? _foregroundServiceHeartbeatTimer;
  bool _foregroundServiceActive = false;

  // Power management (mobile)
  bool _wakeLockActive = false;
  Timer? _wakeLockMonitorTimer;

  // Loading timeout (mobile)
  Timer? _loadingTimeoutTimer;
  static const Duration _loadingTimeout = Duration(seconds: 30);

  // Platform channel for battery optimization (Android)
  static const MethodChannel _batteryChannel = MethodChannel(
    'app.channel/battery',
  );

  // Provider-specific audio source (e.g., ConcatenatingAudioSource for YouTube Music)
  AudioSource? _providerAudioSource;
  bool _providerAudioSourceAttached = false;

  // === Desktop-specific state ===
  // Preloading system for faster skips
  String? _preloadedNextUrl;
  String? _preloadedPreviousUrl;
  // Resolved stream URL cache (e.g. SoundCloud) for gapless / instant play
  final Map<String, String> _resolvedUrlCache = {};
  static const int _maxResolvedUrlCacheSize = 40;
  // Track IDs we're currently preloading (avoid duplicate work)
  final Set<String> _preloadingTrackIds = {};

  /// Initialize audio system based on platform
  Future<void> _initializeAudio() async {
    try {
      // Initialize provider handlers
      _initializeProviderHandlers();
      _updateProviderHandler();

      // Desktop: Initialize media_kit backend
      if (_isDesktop) {
        await _initializeDesktopBackend();
      }

      // Mobile: Initialize audio session
      if (_isMobile) {
        await _initializeMobileSession();
      }

      // Set up player event listeners
      _setupPlayerListeners();

      // Mobile: Set up state synchronization with AudioService
      if (_isMobile) {
        _setupMobileStateSynchronization();
        _startForegroundServiceMonitor();
        _initializePowerManagement();
      }
    } catch (e) {
      _stateController.updateError('Failed to initialize audio: $e');
    }
  }

  /// Initialize desktop audio backend (media_kit)
  Future<void> _initializeDesktopBackend() async {
    try {
      // Import and initialize media_kit conditionally
      // This is handled by just_audio_media_kit package
    } catch (e) {
      // Desktop backend initialization failed
    }
  }

  /// Initialize mobile audio session
  Future<void> _initializeMobileSession() async {
    // Audio session is automatically handled by audio_service package
  }

  /// Initialize provider handlers registry
  void _initializeProviderHandlers() {
    _providerHandlers[ServerType.youtubeMusic] = YouTubeMusicHandler();
    _providerHandlers[ServerType.soundcloud] = SoundCloudHandler();
    _providerHandlers[ServerType.subsonic] = NavidromeHandler();
    _providerHandlers[ServerType.jellyfin] = JellyfinHandler();
    _providerHandlers[ServerType.plex] = PlexHandler();
    _providerHandlers[ServerType.local] = LocalMusicHandler();
  }

  /// Update current provider handler based on active service
  void _updateProviderHandler() {
    final currentService = _mediaServiceManager.currentService;
    _currentProviderHandler = currentService != null
        ? _providerHandlers[currentService.serverType]
        : null;
  }

  /// Initialize power management (mobile only)
  void _initializePowerManagement() {
    if (!_isMobile) return;

    Future.microtask(() async {
      try {
        final isIgnored = await isBatteryOptimizationIgnored();
        if (!isIgnored) {
          await requestBatteryOptimizationExemption();
        }
      } catch (e) {
        // Power management initialization failed
      }
    });
  }

  /// Start foreground service monitor (mobile only)
  void _startForegroundServiceMonitor() {
    if (!_isMobile) return;

    _foregroundServiceRecoveryTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _attemptForegroundServiceRecovery(),
    );

    _foregroundServiceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _maintainForegroundService(),
    );

    _wakeLockMonitorTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkPowerManagement(),
    );
  }

  /// Set up player event listeners with platform-appropriate debouncing
  void _setupPlayerListeners() {
    final capturedGeneration = _playerGeneration;
    final capturedPlayer = _player;

    // Helper to check if callback should be ignored (desktop only)
    bool shouldIgnore() =>
        _disposed || (_isDesktop && capturedGeneration != _playerGeneration);

    // Position stream - throttle on desktop for performance
    if (_isDesktop) {
      _subscriptions.add(
        capturedPlayer.positionStream
            .throttleTime(const Duration(milliseconds: 100))
            .listen((pos) {
              try {
                if (!shouldIgnore()) _stateController.updatePosition(pos);
              } catch (e) {
                // Ignore - callback may have fired after disposal
              }
            }),
      );
    } else {
      _subscriptions.add(
        _player.positionStream.listen(_stateController.updatePosition),
      );
    }

    // Duration stream
    if (_isDesktop) {
      _subscriptions.add(
        capturedPlayer.durationStream
            .debounceTime(const Duration(milliseconds: 100))
            .listen((duration) {
              try {
                if (!shouldIgnore()) {
                  _stateController.updateDuration(duration ?? Duration.zero);
                }
              } catch (e) {
                // Ignore
              }
            }),
      );
    } else {
      _subscriptions.add(
        _player.durationStream.listen((duration) {
          _stateController.updateDuration(duration ?? Duration.zero);
        }),
      );
    }

    // Player state stream
    _subscriptions.add(
      (_isDesktop ? capturedPlayer : _player).playerStateStream.listen((state) {
        try {
          if (!shouldIgnore()) _handlePlayerStateChange(state);
        } catch (e) {
          // Ignore
        }
      }),
    );

    // Processing state stream
    _subscriptions.add(
      (_isDesktop ? capturedPlayer : _player).processingStateStream.listen((
        state,
      ) {
        try {
          if (!shouldIgnore()) _handleProcessingStateChange(state);
        } catch (e) {
          // Ignore
        }
      }),
    );

    // Player completion
    _subscriptions.add(
      (_isDesktop ? capturedPlayer : _player).playbackEventStream
          .where((event) => event.processingState == ProcessingState.completed)
          .listen((_) {
            try {
              if (!shouldIgnore()) _handleTrackCompletion();
            } catch (e) {
              // Ignore
            }
          }),
    );

    // Volume and speed synchronization
    if (_isDesktop) {
      _subscriptions.add(
        capturedPlayer.volumeStream
            .debounceTime(const Duration(milliseconds: 50))
            .listen((vol) {
              try {
                if (!shouldIgnore()) _stateController.updateVolume(vol);
              } catch (e) {
                // Ignore
              }
            }),
      );

      _subscriptions.add(
        capturedPlayer.speedStream
            .debounceTime(const Duration(milliseconds: 50))
            .listen((speed) {
              try {
                if (!shouldIgnore()) _stateController.updateSpeed(speed);
              } catch (e) {
                // Ignore
              }
            }),
      );
    } else {
      _subscriptions.add(
        _player.volumeStream.listen(_stateController.updateVolume),
      );
      _subscriptions.add(
        _player.speedStream.listen(_stateController.updateSpeed),
      );
    }

    // Web: Update media session when track changes
    if (kIsWeb) {
      _subscriptions.add(
        _stateController.currentTrackStream.listen((track) {
          if (track != null) _updateWebMediaSession(track);
        }),
      );
    }
  }

  /// Set up mobile state synchronization with AudioService
  void _setupMobileStateSynchronization() {
    if (!_isMobile) return;

    // Sync playback state to AudioService
    _subscriptions.add(
      CombineLatestStream.combine3(
        _stateController.stateStream,
        _stateController.positionStream,
        _player.speedStream,
        (AudioPlayerState state, Duration position, double speed) =>
            _createPlaybackState(state, position, speed),
      ).listen((state) {
        _safeUpdatePlaybackState(state);
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

  /// Handle player state changes
  void _handlePlayerStateChange(PlayerState playerState) {
    if (_disposed) return;

    switch (playerState.processingState) {
      case ProcessingState.idle:
        _stateController.updateState(AudioPlayerState.idle);
        if (_isMobile) _foregroundServiceActive = false;
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _stateController.updateState(AudioPlayerState.loading);
        if (_isMobile && _stateController.userIntendedPlaying) {
          _attemptForegroundService();
        }
        break;
      case ProcessingState.ready:
        if (playerState.playing) {
          _stateController.updateState(AudioPlayerState.playing);
          if (_isMobile) {
            _attemptForegroundService();
            _ensureWakeLock();
          }
        } else {
          // Check if we should auto-continue playback
          if (_stateController.userIntendedPlaying &&
              _stateController.currentState == AudioPlayerState.loading) {
            Future.microtask(() async {
              try {
                if (_isMobile) await _attemptForegroundService();
                await _player.play();
              } catch (e) {
                // Auto-continue failed
              }
            });
          }
          _stateController.updateState(AudioPlayerState.paused);
        }
        break;
      case ProcessingState.completed:
        _stateController.updateState(AudioPlayerState.completed);
        if (_isMobile) _foregroundServiceActive = false;
        break;
    }

    // Update playback state stream for all platforms
    _updatePlaybackStateStream();
  }

  /// Handle processing state changes
  void _handleProcessingStateChange(ProcessingState state) {
    if (_disposed) return;

    if (state == ProcessingState.ready) {
      _stateController.clearError();
      if (_isMobile) _cancelLoadingTimeout();
    } else if (state == ProcessingState.completed) {
      if (_isMobile) _cancelLoadingTimeout();
    }
  }

  /// Handle track completion
  Future<void> _handleTrackCompletion() async {
    if (_disposed) return;
    if (_isHandlingCompletion) return;

    // Check with provider handler if completion should be handled
    final state = _player.playerState;
    final position = _player.position;
    final duration = _player.duration;
    
    if (_currentProviderHandler != null) {
      final shouldHandle = _currentProviderHandler!.shouldHandleCompletion(
        state: state,
        position: position,
        duration: duration,
        loadStartedAt: _lastLoadStartedAt,
        lastCompletionHandledAt: _lastCompletionHandledAt,
      );
      
      if (!shouldHandle) {
        if (kDebugMode) {
          debugPrint('[Playback] _handleTrackCompletion: provider handler rejected completion');
        }
        return;
      }
    }

    _isHandlingCompletion = true;
    try {
      if (_isMobile) _cancelLoadingTimeout();

      // Call provider-specific completion handling if needed
      if (_currentProviderHandler != null) {
        await _currentProviderHandler!.handleCompletion();
      }

      // In radio mode, fetch and play similar tracks
      if (_radioModeEnabled) {
        await _handleRadioModeNext();
        return;
      }

      // Normal mode - advance to next track (or repeat same if repeat one)
      final currentIndex = _stateController.currentIndex;
      final nextIndex = _queueManager.getNextTrackIndex();
      if (nextIndex != null) {
        final isRepeatOne = _stateController.repeatMode == RepeatMode.one;
        if (nextIndex == currentIndex && isRepeatOne) {
          // Repeat one: seek to start and play (avoid full reload)
          try {
            await _player.seek(Duration.zero);
            if (_stateController.userIntendedPlaying) await _player.play();
          } catch (_) { /* ignore seek/play on repeat-one */ }
          return;
        }
        if (_isDesktop) {
          await _playNextTrackWithRetry(nextIndex);
        } else {
          await _performSkipToQueueItem(nextIndex);
        }
      } else {
        // Queue ended - check if autoplay is enabled
        if (_autoplayEnabled) {
          await _handleAutoplayNext();
        } else {
          _stateController.updateState(AudioPlayerState.completed);
          _stateController.updateUserIntent(false);
        }
      }
    } finally {
      _isHandlingCompletion = false;
      _lastCompletionHandledAt = DateTime.now();
    }
  }

  /// Play next track with retry logic (desktop).
  /// Retries the same track up to maxRetries; does NOT skip to next track on
  /// failure, to avoid silently jumping over multiple tracks (e.g. SoundCloud).
  Future<void> _playNextTrackWithRetry(
    int startIndex, {
    int maxRetries = 3,
  }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await skipToQueueItem(startIndex);
        return;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          _stateController.updateError('Failed to play track: $e');
          _stateController.updateState(AudioPlayerState.error);
          _stateController.updateUserIntent(false);
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }


  /// Handle radio mode - fetch similar tracks
  Future<void> _handleRadioModeNext() async {
    try {
      final currentTrack = _stateController.currentTrack;
      if (currentTrack == null) return;

      final similarTracks = await _fetchSimilarTracks(currentTrack);

      if (similarTracks.isNotEmpty) {
        for (final track in similarTracks.take(5)) {
          _queueManager.addToQueue(track);
        }
        await skipToNext();
      }
    } catch (e) {
      await skipToNext();
    }
  }

  /// Handle autoplay - fetch similar tracks when queue ends
  Future<void> _handleAutoplayNext() async {
    try {
      final currentTrack = _stateController.currentTrack;
      if (currentTrack == null) {
        _stateController.updateState(AudioPlayerState.completed);
        _stateController.updateUserIntent(false);
        return;
      }

      final similarTracks = await _fetchSimilarTracks(currentTrack);

      if (similarTracks.isNotEmpty) {
        // Add similar tracks to queue
        for (final track in similarTracks.take(10)) {
          _queueManager.addToQueue(track);
        }
        // Play the first similar track
        await skipToNext();
      } else {
        _stateController.updateState(AudioPlayerState.completed);
        _stateController.updateUserIntent(false);
      }
    } catch (e) {
      _stateController.updateState(AudioPlayerState.completed);
      _stateController.updateUserIntent(false);
    }
  }

  Future<List<Track>> _fetchSimilarTracks(Track track) async {
    try {
      final currentQueue = _stateController.queue;
      final queueIds = currentQueue.map((t) => t.id).toSet();
      final List<Track> similarTracks = [];

      // Strategy 1: Get more tracks from the same artist (by artist name)
      if (track.artistName != null && track.artistName!.isNotEmpty) {
        try {
          // Search for tracks by the same artist
          final allTracks = await _mediaServiceManager.getTracks(limit: 100);
          final artistTracks = allTracks
              .where(
                (t) =>
                    t.artistName == track.artistName &&
                    t.id != track.id &&
                    !queueIds.contains(t.id),
              )
              .toList();
          similarTracks.addAll(artistTracks.take(20));
        } catch (e) {
          // Failed to fetch artist tracks
        }
      }

      // Strategy 2: Get more tracks from the same album
      if (track.albumId != null && similarTracks.length < 10) {
        try {
          final albumTracks = await _mediaServiceManager.getTracks(
            parentId: track.albumId,
            limit: 30,
          );
          for (final t in albumTracks) {
            if (t.id != track.id &&
                !queueIds.contains(t.id) &&
                !similarTracks.any((s) => s.id == t.id)) {
              similarTracks.add(t);
            }
          }
        } catch (e) {
          // Failed to fetch album tracks
        }
      }

      // Strategy 3: If we still don't have enough, get random tracks
      if (similarTracks.length < 5) {
        try {
          final randomTracks = await _mediaServiceManager.getTracks(limit: 30);
          // Shuffle to get variety
          randomTracks.shuffle();
          for (final t in randomTracks) {
            if (t.id != track.id &&
                !queueIds.contains(t.id) &&
                !similarTracks.any((s) => s.id == t.id)) {
              similarTracks.add(t);
              if (similarTracks.length >= 15) break;
            }
          }
        } catch (e) {
          // Failed to fetch random tracks
        }
      }

      // Shuffle similar tracks for variety
      similarTracks.shuffle();
      return similarTracks;
    } catch (e) {
      return [];
    }
  }

  // === Stream Getters ===

  Stream<AudioPlayerState> get stateStream => _stateController.stateStream;

  Stream<Duration> get positionStream => _stateController.positionStream;

  Stream<Duration?> get durationStream => _stateController.durationStream;

  Stream<double> get volumeStream => _player.volumeStream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<Track?> get currentTrackStream => _stateController.currentTrackStream;

  Stream<RepeatMode> get repeatModeStream => _stateController.repeatModeStream;

  Stream<bool> get shuffleEnabledStream =>
      _stateController.shuffleEnabledStream;

  Stream<double> get speedStream => _stateController.speedStream;

  Stream<String?> get errorStream => _stateController.errorStream;

  // === Property Getters ===

  AudioPlayerState get currentState => _stateController.currentState;

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

  RepeatMode get repeatMode => _stateController.repeatMode;

  bool get shuffleEnabled => _stateController.shuffleEnabled;

  bool get gaplessPlaybackEnabled => _stateController.gaplessPlaybackEnabled;

  bool get radioModeEnabled => _radioModeEnabled;

  bool get autoplayEnabled => _autoplayEnabled;

  // === Playback Control Methods ===

  @override
  Future<void> play() async {
    _stateController.updateUserIntent(true);
    _stateController.updateState(AudioPlayerState.loading);

    try {
      if (_isMobile) {
        _foregroundServiceFailureCount = 0;
        await _attemptForegroundService();
      }

      await _player.play();
    } catch (e) {
      _stateController.updateError('Play failed: $e');
      _stateController.updateUserIntent(false);
      _stateController.updateState(AudioPlayerState.error);
    }
  }

  @override
  Future<void> pause() async {
    _stateController.updateUserIntent(false);
    _stateController.updateState(AudioPlayerState.paused);

    try {
      await _player.pause();
    } catch (e) {
      _stateController.updateError('Pause failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    return _stateController.queueCommand(() async {
      _stateController.updateUserIntent(false);

      try {
        await _player.stop();
        _stateController.updateState(AudioPlayerState.idle);
        // Reset provider audio source attachment on stop
        _providerAudioSourceAttached = false;
      } catch (e) {
        _stateController.updateError('Stop failed: $e');
      }
    });
  }

  @override
  Future<void> seek(Duration position) async {
    _stateController.updatePosition(position);

    try {
      await _player.seek(position);
    } catch (e) {
      _stateController.updateError('Seek failed: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    _stateController.updateSpeed(speed);

    try {
      await _player.setSpeed(speed);
    } catch (e) {
      _stateController.updateError('Set speed failed: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    _stateController.updateVolume(volume);

    try {
      await _player.setVolume(volume);
    } catch (e) {
      _stateController.updateError('Set volume failed: $e');
    }
  }

  /// Play a single track
  Future<void> playTrack(Track track) async {
    _queueManager.setQueue([track], startIndex: 0);
    _stateController.updateCurrentTrack(track);
    _stateController.updateState(AudioPlayerState.loading);

    // Update UI streams for all platforms
    _updateMediaItem(track);
    _updatePlaybackStateStream();

    try {
      final urls = await _getStreamUrls(track);
      if (urls.isEmpty) {
        _stateController.updateError('No stream URL available for this track');
        _stateController.updateState(AudioPlayerState.error);
        return;
      }
      await _loadAndPlayTrackWithFallbacks(urls);
    } catch (e) {
      _stateController.updateError('Failed to play track: $e');
      _stateController.updateState(AudioPlayerState.error);
    }
  }

  /// Play a playlist
  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) {
      _stateController.updateError('Cannot play empty playlist');
      return;
    }

    final validStartIndex = startIndex.clamp(0, tracks.length - 1);

    _queueManager.setQueue(tracks, startIndex: validStartIndex);
    _stateController.updateCurrentTrack(tracks[validStartIndex]);
    _stateController.updateState(AudioPlayerState.loading);

    // Preload first track (and next) for providers that need async resolution (e.g. SoundCloud)
    preloadStreamUrl(tracks[validStartIndex].id);
    if (validStartIndex + 1 < tracks.length) {
      preloadStreamUrl(tracks[validStartIndex + 1].id);
    }

    // Update UI streams for all platforms
    _updateMediaItem(tracks[validStartIndex]);
    _updatePlaybackStateStream();

    try {
      await _playTrackAtIndex(validStartIndex);
    } catch (e) {
      _stateController.updateError('Failed to play playlist: $e');
      _stateController.updateState(AudioPlayerState.error);
    }
  }

  @override
  Future<void> skipToNext() async {
    final nextIndex = _queueManager.getNextTrackIndex();
    if (nextIndex != null) {
      final queue = _stateController.queue;
      if (nextIndex < queue.length) {
        final nextTrack = queue[nextIndex];
        _stateController.updateCurrentIndex(nextIndex);
        _stateController.updateCurrentTrack(nextTrack);
        _stateController.updateState(AudioPlayerState.loading);

        // Update UI streams for all platforms
        _updateMediaItem(nextTrack);
        _updatePlaybackStateStream();
      }
      await _performSkipToQueueItem(nextIndex);
    }
  }

  /// True if the next back press will restart the current track (seek to 0) instead of going to previous. Used by UI to avoid playing skip animation when only restarting.
  Future<bool> willBackRestartCurrentTrack() async {
    if (!_smartBackToStartEnabled) return false;
    final now = DateTime.now();
    final lastPress = _lastBackPress;
    final withinInterval =
        lastPress != null && now.difference(lastPress) < _backPressInterval;
    final duration = _player.duration;
    final position = _player.position;
    final hasDuration = duration != null && duration.inMilliseconds > 0;
    final progress = hasDuration
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    return !withinInterval && progress > _backRestartThreshold;
  }

  @override
  Future<void> skipToPrevious() async {
    if (_smartBackToStartEnabled) {
      final now = DateTime.now();
      final lastPress = _lastBackPress;
      final withinInterval =
          lastPress != null && now.difference(lastPress) < _backPressInterval;

      final duration = _player.duration;
      final position = _player.position;
      final hasDuration = duration != null && duration.inMilliseconds > 0;
      final progress = hasDuration
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;

      // First press after threshold: restart track instead of previous
      if (!withinInterval && progress > _backRestartThreshold) {
        _lastBackPress = now;
        await _player.seek(Duration.zero);
        _stateController.updatePosition(Duration.zero);
        _updatePlaybackStateStream();
        return;
      }

      // Second press within interval or already near start -> go previous
      _lastBackPress = now;
    }

    final previousIndex = _queueManager.getPreviousTrackIndex();
    if (previousIndex != null) {
      final queue = _stateController.queue;
      if (previousIndex >= 0 && previousIndex < queue.length) {
        final previousTrack = queue[previousIndex];
        _stateController.updateCurrentIndex(previousIndex);
        _stateController.updateCurrentTrack(previousTrack);
        _stateController.updateState(AudioPlayerState.loading);

        // Update UI streams for all platforms
        _updateMediaItem(previousTrack);
        _updatePlaybackStateStream();
      }
      await _performSkipToQueueItem(previousIndex);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final queue = _stateController.queue;
    if (index >= 0 && index < queue.length) {
      final track = queue[index];
      _stateController.updateCurrentIndex(index);
      _stateController.updateCurrentTrack(track);
      _stateController.updateState(AudioPlayerState.loading);

      // Update UI streams for all platforms
      _forceUISynchronization(track, index);
    }

    await _performSkipToQueueItem(index);
  }

  Future<void> _performSkipToQueueItem(int index) async {
    try {
      final queue = _stateController.queue;
      if (index < 0 || index >= queue.length) {
        throw Exception('Invalid queue index: $index');
      }

      if (_isMobile) _foregroundServiceFailureCount = 0;

      await _playTrackAtIndex(index);
    } catch (e) {
      _stateController.updateError('Skip failed: $e');
      _stateController.updateState(AudioPlayerState.error);
      rethrow;
    }
  }

  Future<void> _playTrackAtIndex(int index) async {
    final queue = _stateController.queue;
    final track = queue[index];

    _stateController.updateCurrentIndex(index);
    _stateController.updateCurrentTrack(track);

    final urls = await _getStreamUrls(track);
    if (urls.isEmpty) {
      _stateController.updateError('No stream URL available for this track');
      _stateController.updateState(AudioPlayerState.error);
      return;
    }
    await _loadAndPlayTrackWithFallbacks(urls);

    // Preload adjacent tracks for faster skips (desktop uses preloaded URLs; mobile/web use cache)
    _preloadAdjacentTracks(index);
  }

  /// Preload adjacent tracks (desktop + async for SoundCloud etc.)
  void _preloadAdjacentTracks(int currentIndex) {
    final queue = _stateController.queue;

    if (currentIndex + 1 < queue.length) {
      final nextTrack = queue[currentIndex + 1];
      final direct = _mediaServiceManager.getDirectStreamUrl(nextTrack.id);
      if (direct.isNotEmpty) {
        _preloadedNextUrl = direct;
      } else {
        _preloadedNextUrl = null;
        _preloadStreamUrlIntoNextPrev(nextTrack.id, isNext: true);
      }
    } else {
      _preloadedNextUrl = null;
    }

    if (currentIndex - 1 >= 0) {
      final previousTrack = queue[currentIndex - 1];
      final direct = _mediaServiceManager.getDirectStreamUrl(previousTrack.id);
      if (direct.isNotEmpty) {
        _preloadedPreviousUrl = direct;
      } else {
        _preloadedPreviousUrl = null;
        _preloadStreamUrlIntoNextPrev(previousTrack.id, isNext: false);
      }
    } else {
      _preloadedPreviousUrl = null;
    }
  }

  void _preloadStreamUrlIntoNextPrev(String trackId, {required bool isNext}) {
    if (trackId.isEmpty || _preloadingTrackIds.contains(trackId)) return;
    
    _updateProviderHandler();
    
    // Check if provider supports preloading
    if (_currentProviderHandler == null || !_currentProviderHandler!.supportsPreloading()) {
      return;
    }
    
    if (_resolvedUrlCache.containsKey(trackId)) {
      final url = _resolvedUrlCache[trackId]!;
      if (isNext) {
        _preloadedNextUrl = url;
      } else {
        _preloadedPreviousUrl = url;
      }
      return;
    }
    
    // Find track in queue
    final queue = _stateController.queue;
    final track = queue.firstWhere(
      (t) => t.id == trackId,
      orElse: () => Track(
        id: trackId,
        name: '',
        artists: [],
        duration: 0,
      ),
    );
    
    if (track.id.isEmpty) return;
    
    _preloadingTrackIds.add(trackId);
    _currentProviderHandler!.preloadStreamUrl(
      track,
      _mediaServiceManager,
      (id, url) {
        _preloadingTrackIds.remove(id);
        if (_disposed) return;
        _cacheResolvedUrl(id, url);
        if (isNext) {
          _preloadedNextUrl = url;
        } else {
          _preloadedPreviousUrl = url;
        }
      },
    ).catchError((e) {
      if (kDebugMode) {
        debugPrint('[Playback] preloadStreamUrl: failed for trackId=$trackId: $e');
      }
      _preloadingTrackIds.remove(trackId);
    });
  }

  /// Apply current volume and speed from state to the player.
  /// Needed after loading a new track so the new stream respects user settings
  /// (e.g. on desktop the player is recreated and defaults to 1.0).
  Future<void> _applyVolumeAndSpeedToPlayer() async {
    if (_disposed) return;
    try {
      await _player.setVolume(_stateController.volume);
      await _player.setSpeed(_stateController.speed);
    } catch (e) {
      // Ignore
    }
  }

  /// Wait until the stream has actually loaded (duration > 0, ready or buffering).
  /// Used for YT (throws on timeout so fallback URLs are tried) and optionally for desktop non-YT (don't throw).
  Future<void> _waitForStreamReady({
    required Duration timeout,
    required int operationId,
    bool throwOnTimeout = true,
  }) async {
    final completer = Completer<void>();
    StreamSubscription<PlayerState>? subState;
    StreamSubscription<Duration?>? subDuration;
    Timer? timeoutTimer;

    void check() {
      if (_disposed || _loadOperationId != operationId) {
        if (!completer.isCompleted) completer.complete();
        return;
      }
      final state = _player.playerState;
      final duration = _player.duration;
      final position = _player.position;
      // Accept ready or buffering (stream has started); duration > 0 means URL opened successfully.
      final hasDuration = duration != null && duration > Duration.zero;
      final canPlay = state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.buffering;
      
      if (hasDuration && canPlay) {
        if (!completer.isCompleted) completer.complete();
      }
    }

    subState = _player.playerStateStream.listen((_) => check());
    subDuration = _player.durationStream.listen((_) => check());
    check();

    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        if (throwOnTimeout) {
          completer.completeError(
            TimeoutException('YT stream did not become ready within ${timeout.inSeconds}s', timeout),
          );
        } else {
          completer.complete();
        }
      }
    });

    try {
      await completer.future;
    } finally {
      await subState.cancel();
      await subDuration.cancel();
      timeoutTimer.cancel();
    }
  }

  /// Load and play track from URL
  Future<void> _loadAndPlayTrack(String url) async {
    if (_disposed) return;

    // Harmony 1:1: no proxy; direct googlevideo.com URL for YT on mobile and desktop.
    final isYouTube = url.contains('googlevideo.com');
    if (kDebugMode) {
      final track = _stateController.currentTrack;
      debugPrint('[Playback] _loadAndPlayTrack: track=${track?.name ?? "?"} id=${track?.id ?? "?"} '
          'urlHost=${Uri.tryParse(url)?.host ?? "?"} isYouTube=$isYouTube');
    }

    _stateController.updateState(AudioPlayerState.loading);
    _stateController.updateUserIntent(true);

    if (_isMobile) _startLoadingTimeout();

    // Web: Stop current audio before loading new track
    if (kIsWeb) {
      try {
        await _player.stop();
      } catch (e) {
        // Ignore
      }
    }

    // Update provider handler if service changed
    _updateProviderHandler();
    
    // Create audio source using provider handler
    _lastLoadStartedAt = DateTime.now();
    final currentOperationId = ++_loadOperationId;
    
    AudioSource audioSource;
    try {
      if (_currentProviderHandler != null) {
        // Use provider-specific audio source (e.g., ConcatenatingAudioSource for YouTube Music)
        audioSource = await _currentProviderHandler!.createAudioSource(
          url,
          existingSource: _providerAudioSource,
        );
        // Store provider-specific source for reuse
        if (audioSource is ConcatenatingAudioSource) {
          _providerAudioSource = audioSource;
        }
      } else {
        // Default: standard AudioSource.uri()
        audioSource = AudioSource.uri(Uri.parse(url));
        _providerAudioSource = null;
      }
    } catch (e) {
      // Fallback to standard source if provider handler fails
      audioSource = AudioSource.uri(Uri.parse(url));
      _providerAudioSource = null;
    }

    // Desktop (non-YT): use same player, set source and play – no recreation so Navidrome/Jellyfin/etc. start quickly.
    // YouTube Music uses the branch above (concat source + wait for stream ready).
    if (_isDesktop) {
      final currentOperationId = ++_loadOperationId;

      try {
        if (kDebugMode) {
          debugPrint('[Playback] _loadAndPlayTrack: calling setAudioSource (desktop)');
        }
        
        // Check if provider source needs to be attached
        // ConcatenatingAudioSource (YouTube Music) is reused and only attached once
        if (audioSource is ConcatenatingAudioSource) {
          if (!_providerAudioSourceAttached) {
            await _player.setAudioSource(audioSource);
            _providerAudioSourceAttached = true;
          }
          // Source is already attached, just play (content was updated via clear+add)
        } else {
          await _player.setAudioSource(audioSource).timeout(const Duration(seconds: 10));
          _providerAudioSourceAttached = false;
        }

        if (_disposed || currentOperationId != _loadOperationId) return;

        // Give the player a moment to initialize the source
        await Future.delayed(const Duration(milliseconds: 200));
        if (_disposed || currentOperationId != _loadOperationId) return;
        
        if (kDebugMode) {
          debugPrint('[Playback] _loadAndPlayTrack: calling play() (desktop)');
        }

        // Play and wait for stream to be ready if provider requires it
        if (_stateController.userIntendedPlaying) {
          try {
            await _player.play().timeout(const Duration(seconds: 3));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[Playback] _loadAndPlayTrack: play() failed: $e');
            }
          }
          
          if (_disposed || currentOperationId != _loadOperationId) return;
          
          // Wait for stream ready if provider requires it
          if (_currentProviderHandler != null && _currentProviderHandler!.shouldWaitForStreamReady()) {
            final timeout = _currentProviderHandler!.getStreamReadyTimeout() ?? const Duration(seconds: 5);
            final throwOnTimeout = _currentProviderHandler!.throwOnStreamReadyTimeout();
            try {
              await _waitForStreamReady(
                timeout: timeout,
                operationId: currentOperationId,
                throwOnTimeout: throwOnTimeout,
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[Playback] _loadAndPlayTrack: waitForStreamReady failed: $e');
              }
              if (throwOnTimeout) {
                rethrow;
              }
            }
          }
          
          if (_disposed || currentOperationId != _loadOperationId) return;
          
          // If stream is ready but not playing, try play() again
          final playerState = _player.playerState;
          final duration = _player.duration;
          if ((duration != null && duration > Duration.zero) && !playerState.playing) {
            if (kDebugMode) {
              debugPrint('[Playback] _loadAndPlayTrack: stream ready but not playing, retrying play()');
            }
            try {
              await _player.play().timeout(const Duration(seconds: 2));
              await Future.delayed(const Duration(milliseconds: 300));
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[Playback] _loadAndPlayTrack: retry play() failed: $e');
              }
            }
          }
        }
        
        if (_disposed || currentOperationId != _loadOperationId) return;
        if (kDebugMode) {
          debugPrint('[Playback] _loadAndPlayTrack: play() succeeded (desktop)');
        }
        
        await _applyVolumeAndSpeedToPlayer();
        
        if (_disposed || currentOperationId != _loadOperationId) return;
        
        // Set state to playing
        if (_stateController.userIntendedPlaying) {
          final finalPlayerState = _player.playerState;
          final finalDuration = _player.duration;
          final finalPosition = _player.position;
          final streamReady = finalDuration != null && finalDuration > Duration.zero;
          final positionAdvancing = finalPosition.inMilliseconds > 100;
          
          if (finalPlayerState.playing || streamReady || positionAdvancing) {
            _stateController.updateState(AudioPlayerState.playing);
          } else {
            if (kDebugMode) {
              debugPrint('[Playback] _loadAndPlayTrack: ERROR - stream not ready and player not playing');
            }
            _stateController.updateState(AudioPlayerState.error);
            _stateController.updateUserIntent(false);
            _stateController.updateError('Failed to start playback: stream did not load');
            return;
          }
        }
        // Set duration from track metadata so progress bar shows correctly if player doesn't report duration immediately.
        final track = _stateController.currentTrack;
        if (track?.duration != null && track!.duration! > 0) {
          _stateController.updateDuration(Duration(milliseconds: track.duration!));
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Playback] _loadAndPlayTrack: FAILED (desktop): $e');
          debugPrint('[Playback] stackTrace: $st');
        }
        _stateController.updateState(AudioPlayerState.error);
        _stateController.updateUserIntent(false);
        _stateController.updateError('Failed to load track: $e');
        rethrow;
      }
    } else {
      // Mobile and Web
      try {
        if (kIsWeb) {
          await _tryLoadWithFallbacks(url);
        } else {
          if (kDebugMode) {
            debugPrint('[Playback] _loadAndPlayTrack: calling setAudioSource (mobile)');
          }
          
          // Handle ConcatenatingAudioSource on mobile (YouTube Music)
          if (audioSource is ConcatenatingAudioSource) {
            if (!_providerAudioSourceAttached) {
              await _player.setAudioSource(audioSource);
              _providerAudioSourceAttached = true;
            }
          } else {
            await _player.setAudioSource(audioSource);
            _providerAudioSourceAttached = false;
          }

          if (_stateController.userIntendedPlaying) {
            if (_isMobile) await _attemptForegroundService();
            await _player.play();
          }
          
          // Wait for stream ready if provider requires it (mobile)
          if (_currentProviderHandler != null && _currentProviderHandler!.shouldWaitForStreamReady()) {
            final timeout = _currentProviderHandler!.getStreamReadyTimeout() ?? const Duration(seconds: 5);
            final throwOnTimeout = _currentProviderHandler!.throwOnStreamReadyTimeout();
            try {
              await _waitForStreamReady(
                timeout: timeout,
                operationId: currentOperationId,
                throwOnTimeout: throwOnTimeout,
              );
            } catch (e) {
              if (throwOnTimeout) {
                rethrow;
              }
            }
          }
          
          if (kDebugMode) {
            debugPrint('[Playback] _loadAndPlayTrack: play() succeeded (mobile)');
          }
        }

        if (_isMobile) _cancelLoadingTimeout();
        await _applyVolumeAndSpeedToPlayer();
        
        // Set state to playing
        if (_stateController.userIntendedPlaying) {
          _stateController.updateState(AudioPlayerState.playing);
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Playback] _loadAndPlayTrack: FAILED (mobile): $e');
          debugPrint('[Playback] stackTrace: $st');
        }
        if (_isMobile) _cancelLoadingTimeout();
        _stateController.updateState(AudioPlayerState.error);
        _stateController.updateUserIntent(false);
        _stateController.updateError('Failed to load track: $e');
        rethrow;
      }
    }
  }

  /// Try to load audio with fallbacks for CORS (web only)
  Future<void> _tryLoadWithFallbacks(String primaryUrl) async {
    List<String> urlsToTry = [primaryUrl];

    if (kIsWeb && _stateController.currentTrack != null) {
      urlsToTry.addAll(
        _mediaServiceManager.getAlternativeStreamUrls(
          _stateController.currentTrack!.id,
        ),
      );
    }

    Exception? lastError;

    for (int i = 0; i < urlsToTry.length; i++) {
      final url = urlsToTry[i];
      // Harmony-style: no headers (just_audio handles URLs natively)
      final source = AudioSource.uri(Uri.parse(url));
      try {
        await _player.setAudioSource(source);
        await _player.play();
        return;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i < urlsToTry.length - 1 && _isCorsError(e)) {
          continue;
        }
      }
    }

    throw lastError ?? Exception('All stream URLs failed to load');
  }

  bool _isCorsError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('cors') ||
        errorString.contains('cross-origin') ||
        errorString.contains('blocked') ||
        errorString.contains('access-control');
  }

  /// True if a YouTube (googlevideo.com) URL is expired or within 60s of expiry.

  /// Load and play track, trying each URL until one succeeds (fallback support)
  Future<void> _loadAndPlayTrackWithFallbacks(List<String> urls) async {
    if (urls.isEmpty) return;
    
    _updateProviderHandler();
    
    // Filter URLs using provider handler
    List<String> validUrls = urls;
    if (_currentProviderHandler != null) {
      validUrls = _currentProviderHandler!.filterStreamUrls(urls);
    } else {
      // Default filtering
      validUrls = urls.where((url) {
        if (url.isEmpty) return false;
        final lower = url.toLowerCase();
        return lower.startsWith('http://') || lower.startsWith('https://');
      }).toList();
    }
    
    if (validUrls.isEmpty) {
      throw Exception('No valid stream URLs after filtering');
    }
    
    Object? lastError;
    for (var i = 0; i < validUrls.length; i++) {
      final url = validUrls[i];
      try {
        await _loadAndPlayTrack(url);
        final track = _stateController.currentTrack;
        // Cache successful URL if provider supports caching
        if (track != null && 
            _currentProviderHandler != null && 
            _currentProviderHandler!.supportsCaching()) {
          _cacheResolvedUrl(track.id, url);
        }
        if (kDebugMode && i > 0) {
          debugPrint('[Playback] _loadAndPlayTrackWithFallbacks: succeeded with URL #${i + 1} of ${validUrls.length}');
        }
        return;
      } catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('[Playback] _loadAndPlayTrackWithFallbacks: URL #${i + 1} failed: $e, trying next');
        }
        // Don't wait between attempts - try next URL immediately
      }
    }
    throw lastError ?? Exception('All stream URLs failed to load');
  }

  /// Get stream URLs for track (list for fallback support; single URL for others)
  /// Delegates to provider handler for URL resolution
  Future<List<String>> _getStreamUrls(Track track) async {
    _updateProviderHandler();
    
    // Get cached and preloaded URLs
    final cachedUrl = _resolvedUrlCache[track.id];
    final currentIndex = _stateController.currentIndex;
    final queue = _stateController.queue;
    String? preloadedNextUrl;
    String? preloadedPreviousUrl;
    
    if (_isDesktop && currentIndex != null) {
      if (currentIndex + 1 < queue.length &&
          queue[currentIndex + 1].id == track.id) {
        preloadedNextUrl = _preloadedNextUrl;
      }
      if (currentIndex - 1 >= 0 &&
          queue[currentIndex - 1].id == track.id) {
        preloadedPreviousUrl = _preloadedPreviousUrl;
      }
    }
    
    // Delegate to provider handler
    if (_currentProviderHandler != null) {
      final urls = await _currentProviderHandler!.getStreamUrls(
        track,
        _mediaServiceManager,
        cachedUrl: cachedUrl,
        preloadedNextUrl: preloadedNextUrl,
        preloadedPreviousUrl: preloadedPreviousUrl,
      );
      
      // Remove from cache if used
      if (cachedUrl != null && urls.contains(cachedUrl)) {
        _resolvedUrlCache.remove(track.id);
      }
      
      // Clear preloaded URLs if used
      if (preloadedNextUrl != null && urls.contains(preloadedNextUrl)) {
        _preloadedNextUrl = null;
      }
      if (preloadedPreviousUrl != null && urls.contains(preloadedPreviousUrl)) {
        _preloadedPreviousUrl = null;
      }
      
      // Cache first URL if provider supports caching
      if (urls.isNotEmpty && _currentProviderHandler!.supportsCaching()) {
        _cacheResolvedUrl(track.id, urls.first);
      }
      
      return urls;
    }
    
    // Fallback: try direct stream URL
    final directUrl = _mediaServiceManager.getDirectStreamUrl(track.id);
    if (directUrl.isNotEmpty) {
      return [directUrl];
    }
    
    // Fallback: transcoded stream URL
    final streamUrl = _mediaServiceManager.getStreamUrl(track.id);
    if (streamUrl.isNotEmpty) {
      return [streamUrl];
    }
    
    return [];
  }

  void _cacheResolvedUrl(String trackId, String url) {
    if (_resolvedUrlCache.length >= _maxResolvedUrlCacheSize) {
      final firstKey = _resolvedUrlCache.keys.first;
      _resolvedUrlCache.remove(firstKey);
    }
    _resolvedUrlCache[trackId] = url;
  }

  /// Preload stream URL for a track (e.g. SoundCloud). Call when queue is set or user is about to play.
  /// Delegates to provider handler if preloading is supported.
  void preloadStreamUrl(String trackId) {
    if (trackId.isEmpty || _preloadingTrackIds.contains(trackId)) return;
    if (_resolvedUrlCache.containsKey(trackId)) return;
    
    _updateProviderHandler();
    
    // Check if provider supports preloading
    if (_currentProviderHandler == null || !_currentProviderHandler!.supportsPreloading()) {
      return;
    }
    
    // Find track in queue
    final queue = _stateController.queue;
    final track = queue.firstWhere(
      (t) => t.id == trackId,
      orElse: () => Track(
        id: trackId,
        name: '',
        artists: [],
        duration: 0,
      ),
    );
    
    if (track.id.isEmpty) return;
    
    _preloadingTrackIds.add(trackId);
    _currentProviderHandler!.preloadStreamUrl(
      track,
      _mediaServiceManager,
      (id, url) {
        _preloadingTrackIds.remove(id);
        if (_disposed) return;
        _cacheResolvedUrl(id, url);
      },
    ).catchError((_) {
      _preloadingTrackIds.remove(trackId);
    });
  }

  // === Queue Management ===

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

  /// Reset playback state for server switch. Keeps handler alive (no dispose)
  /// so AudioService does not need to be re-initialized.
  Future<void> resetForServerSwitch() async {
    if (_disposed) return;
    await stop();
    clearQueue();
    _stateController.updateCurrentTrack(null);
    _stateController.updateState(AudioPlayerState.idle);
    _stateController.updatePosition(Duration.zero);
    _stateController.updateDuration(Duration.zero);
    _stateController.updateQueue([], currentIndex: null);
    _updateMediaItem(null);
    _updatePlaybackStateStream();
    _preloadedNextUrl = null;
    _preloadedPreviousUrl = null;
    _resolvedUrlCache.clear();
    _preloadingTrackIds.clear();
    // Reset provider audio source when switching servers
    _providerAudioSource = null;
    _providerAudioSourceAttached = false;
    _updateProviderHandler();
  }

  // === Playback Modes ===

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    RepeatMode ourMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        ourMode = RepeatMode.none;
        break;
      case AudioServiceRepeatMode.one:
        ourMode = RepeatMode.one;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        ourMode = RepeatMode.all;
        break;
    }
    _stateController.updateRepeatMode(ourMode);
    _updatePlaybackStateStream();
  }

  void setRepeatModeValue(RepeatMode mode) {
    _stateController.updateRepeatMode(mode);
    _updatePlaybackStateStream();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shouldEnable = shuffleMode != AudioServiceShuffleMode.none;
    final isEnabled = _stateController.shuffleEnabled;

    if (shouldEnable != isEnabled) {
      _queueManager.toggleShuffle();
    } else {
      _stateController.updateShuffleEnabled(shouldEnable);
    }

    _updatePlaybackStateStream();
  }

  void toggleShuffle() {
    _queueManager.toggleShuffle();
    _updatePlaybackStateStream();
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

  void setAutoplay(bool enabled) {
    _autoplayEnabled = enabled;
  }

  void setSmartBackToStartEnabled(bool enabled) {
    _smartBackToStartEnabled = enabled;
  }

  // === Mobile-specific Methods ===

  bool get _shouldSkipForegroundService {
    return _foregroundServiceFailureCount >= _maxConsecutiveFailures &&
        _lastForegroundServiceAttempt != null &&
        DateTime.now().difference(_lastForegroundServiceAttempt!) <
            _foregroundServiceRetryDelay;
  }

  Future<void> _attemptForegroundService() async {
    if (!_isMobile || _shouldSkipForegroundService) return;

    try {
      final currentTrack = _stateController.currentTrack;
      if (currentTrack != null) {
        mediaItem.add(_trackToMediaItem(currentTrack));
      }

      final state = _createPlaybackState(
        _stateController.currentState,
        _stateController.position,
        _stateController.speed,
      );

      playbackState.add(state);
      await Future.delayed(const Duration(milliseconds: 100));

      _foregroundServiceActive = true;
      if (_foregroundServiceFailureCount > 0) {
        _foregroundServiceFailureCount = 0;
      }

      _ensureWakeLock();
    } catch (e) {
      _foregroundServiceFailureCount++;
      _lastForegroundServiceAttempt = DateTime.now();
      _foregroundServiceActive = false;
    }
  }

  void _attemptForegroundServiceRecovery() {
    if (!_isMobile) return;

    if (_foregroundServiceFailureCount > 0 &&
        _lastForegroundServiceAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        _lastForegroundServiceAttempt!,
      );

      if (timeSinceLastAttempt > _foregroundServiceRetryDelay) {
        _foregroundServiceFailureCount = 0;

        if (_stateController.currentState == AudioPlayerState.playing) {
          _attemptForegroundService();
        }
      }
    }
  }

  void _maintainForegroundService() {
    if (!_isMobile) return;

    if (_stateController.currentState == AudioPlayerState.playing ||
        _stateController.userIntendedPlaying) {
      if (!_foregroundServiceActive) {
        _attemptForegroundService();
      } else {
        _sendForegroundServiceHeartbeat();
      }
    }
  }

  void _sendForegroundServiceHeartbeat() {
    if (!_isMobile) return;

    try {
      final state = _createPlaybackState(
        _stateController.currentState,
        _stateController.position,
        _stateController.speed,
      );
      playbackState.add(state);
    } catch (e) {
      _foregroundServiceActive = false;
    }
  }

  void _checkPowerManagement() {
    if (!_isMobile) return;

    if (_stateController.currentState == AudioPlayerState.playing) {
      _ensureWakeLock();
    } else if (!_stateController.userIntendedPlaying) {
      _releaseWakeLock();
    }
  }

  void _ensureWakeLock() {
    if (!_isMobile || _wakeLockActive) return;
    _requestWakeLock();
  }

  void _requestWakeLock() async {
    if (!_isMobile) return;

    try {
      // Wake lock is handled by audio_service on mobile
      _wakeLockActive = true;
    } catch (e) {
      // Wake lock request failed
    }
  }

  void _releaseWakeLock() async {
    if (!_isMobile || !_wakeLockActive) return;

    try {
      _wakeLockActive = false;
    } catch (e) {
      // Wake lock release failed
    }
  }

  void _startLoadingTimeout() {
    if (!_isMobile) return;

    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = Timer(_loadingTimeout, () {
      if (_stateController.currentState == AudioPlayerState.loading) {
        _stateController.updateState(AudioPlayerState.error);
        _stateController.updateError(
          'Track loading timed out. Please try again or check your connection.',
        );
      }
    });
  }

  void _cancelLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
  }

  void _safeUpdatePlaybackState(PlaybackState state) {
    if (!_isMobile || _shouldSkipForegroundService) return;

    try {
      playbackState.add(state);
      _foregroundServiceActive = true;
      if (_foregroundServiceFailureCount > 0) {
        _foregroundServiceFailureCount = 0;
      }
    } catch (e) {
      _foregroundServiceFailureCount++;
      _lastForegroundServiceAttempt = DateTime.now();
      _foregroundServiceActive = false;
    }
  }

  /// Update mediaItem stream for UI (works on all platforms)
  void _updateMediaItem(Track? track) {
    try {
      if (track != null) {
        mediaItem.add(_trackToMediaItem(track));
      } else {
        mediaItem.add(null);
      }
    } catch (e) {
      // Failed to update mediaItem
    }
  }

  /// Update playbackState stream for UI (works on all platforms)
  void _updatePlaybackStateStream() {
    try {
      final state = _createPlaybackState(
        _stateController.currentState,
        _stateController.position,
        _stateController.speed,
      );
      playbackState.add(state);
    } catch (e) {
      // Failed to update playbackState
    }
  }

  void _safeUpdateMediaItem(Track? track) {
    // Mobile-specific foreground service tracking
    if (_isMobile && _shouldSkipForegroundService) return;

    try {
      if (track != null) {
        mediaItem.add(_trackToMediaItem(track));
      } else {
        mediaItem.add(null);
      }
      if (_isMobile && _foregroundServiceFailureCount > 0) {
        _foregroundServiceFailureCount = 0;
      }
    } catch (e) {
      if (_isMobile) {
        _foregroundServiceFailureCount++;
        _lastForegroundServiceAttempt = DateTime.now();
      }
    }
  }

  void _safeUpdateQueue(List<Track> tracks) {
    // Mobile-specific foreground service tracking
    if (_isMobile && _shouldSkipForegroundService) return;

    try {
      queue.add(tracks.map(_trackToMediaItem).toList());
      if (_isMobile && _foregroundServiceFailureCount > 0) {
        _foregroundServiceFailureCount = 0;
      }
    } catch (e) {
      if (_isMobile) {
        _foregroundServiceFailureCount++;
        _lastForegroundServiceAttempt = DateTime.now();
      }
    }
  }

  void _forceMediaItemUpdate(Track? track) {
    // Now works on all platforms
    try {
      if (track != null) {
        mediaItem.add(_trackToMediaItem(track));
      }
    } catch (e) {
      // Ignore
    }
  }

  void _forceUISynchronization(Track track, int index) {
    _stateController.updateCurrentIndex(index);
    _stateController.updateCurrentTrack(track);
    _forceMediaItemUpdate(track);

    try {
      final currentPlaybackState = playbackState.valueOrNull ?? PlaybackState();
      final updatedPlaybackState = currentPlaybackState.copyWith(
        queueIndex: index,
      );
      _safeUpdatePlaybackState(updatedPlaybackState);
    } catch (e) {
      // Ignore
    }
  }

  PlaybackState _createPlaybackState(
    AudioPlayerState state,
    Duration position,
    double speed,
  ) {
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (state == AudioPlayerState.playing)
        MediaControl.pause
      else
        MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];

    return PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.stop,
        MediaAction.pause,
        MediaAction.play,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapToAudioServiceProcessingState(state),
      playing: state == AudioPlayerState.playing,
      updatePosition: position,
      bufferedPosition: _player.bufferedPosition,
      speed: speed,
      queueIndex: _stateController.currentIndex,
      repeatMode: _mapToAudioServiceRepeatMode(_stateController.repeatMode),
      shuffleMode: _stateController.shuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  AudioServiceRepeatMode _mapToAudioServiceRepeatMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return AudioServiceRepeatMode.none;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  AudioProcessingState _mapToAudioServiceProcessingState(
    AudioPlayerState state,
  ) {
    switch (state) {
      case AudioPlayerState.idle:
        return AudioProcessingState.idle;
      case AudioPlayerState.loading:
        return AudioProcessingState.loading;
      case AudioPlayerState.playing:
      case AudioPlayerState.paused:
        return AudioProcessingState.ready;
      case AudioPlayerState.completed:
        return AudioProcessingState.completed;
      case AudioPlayerState.error:
        return AudioProcessingState.error;
    }
  }

  MediaItem _trackToMediaItem(Track track) {
    // Prefer track.imageUrl when it's already a full URL (SoundCloud, Plex, Subsonic)
    String imageUrl = '';
    if (track.imageUrl != null &&
        (track.imageUrl!.startsWith('http://') ||
            track.imageUrl!.startsWith('https://'))) {
      imageUrl = track.imageUrl!;
    }
    if (imageUrl.isEmpty) {
      imageUrl = _mediaServiceManager.getImageUrl(
        track.albumId ?? track.id,
        width: 512,
        height: 512,
      );
    }

    // Only use artUri if it's a valid HTTP/HTTPS URL
    // file:// URIs cause errors with SMTC/flutter_cache_manager on Windows
    Uri? artUri;
    if (imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      artUri = Uri.tryParse(imageUrl);
    }

    return MediaItem(
      id: track.id,
      album: track.albumName ?? 'Unknown Album',
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      duration: track.duration != null
          ? Duration(milliseconds: track.duration!)
          : null,
      artUri: artUri,
      playable: true,
      extras: {
        'trackId': track.id,
        'albumId': track.albumId,
        'trackNumber': track.trackNumber,
        'localImageUrl':
            imageUrl, // Store for UI display (supports file:// URIs)
      },
    );
  }

  Future<void> requestBatteryOptimizationExemption() async {
    if (!_isMobile) return;

    try {
      await _batteryChannel.invokeMethod('requestBatteryOptimizationExemption');
    } catch (e) {
      // Failed to request battery optimization exemption
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (!_isMobile) return true;

    try {
      final bool isIgnored = await _batteryChannel.invokeMethod(
        'isBatteryOptimizationIgnored',
      );
      return isIgnored;
    } catch (e) {
      return false;
    }
  }

  // === Web-specific Methods ===

  void _updateWebMediaSession(Track track) {
    // Web Media Session API would be updated here if needed
  }

  // === Lifecycle Management ===

  Future<void> dispose() async {
    _disposed = true;

    // Reset provider audio source
    _providerAudioSource = null;
    _providerAudioSourceAttached = false;

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      try {
        await subscription.cancel();
      } catch (e) {
        // Ignore
      }
    }
    _subscriptions.clear();

    // Cancel all timers
    _radioModeTimer?.cancel();
    _foregroundServiceRecoveryTimer?.cancel();
    _foregroundServiceHeartbeatTimer?.cancel();
    _wakeLockMonitorTimer?.cancel();
    _loadingTimeoutTimer?.cancel();

    // Release wake lock
    if (_isMobile) {
      _releaseWakeLock();
      _foregroundServiceActive = false;
    }

    // Clear preloaded URLs and cache
    _preloadedNextUrl = null;
    _preloadedPreviousUrl = null;
    _resolvedUrlCache.clear();
    _preloadingTrackIds.clear();

    // Stop and dispose player
    try {
      await _player.stop();
      await _player.dispose();
    } catch (e) {
      // Error disposing player
    }

    // Reset state
    _stateController.reset();
  }
}
