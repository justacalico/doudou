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

  // Foreground service management
  bool _foregroundServiceIssues = false;

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

  /// Initialize audio session for background playback
  Future<void> _initializeAudioSession() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());

      // Handle audio session interruptions (phone calls, notifications, etc.)
      _subscriptions.add(
        _session!.interruptionEventStream.listen(_handleAudioInterruption),
      );

      // Handle becoming noisy events (headphones unplugged, etc.)
      _subscriptions.add(
        _session!.becomingNoisyEventStream.listen(_handleBecomingNoisy),
      );

      if (kDebugMode) {
        print('DoudouAudioHandler: Audio session configured with interruption handling');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to configure audio session: $e');
      }
    }
  }

  /// Handle audio interruptions (phone calls, notifications, etc.)
  void _handleAudioInterruption(AudioInterruptionEvent event) {
    if (kDebugMode) {
      print('DoudouAudioHandler: Audio interruption: ${event.type}');
    }

    if (event.begin) {
      // Audio interruption began (phone call, notification, etc.)
      if (_player.playing) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Pausing due to audio interruption');
        }
        // Don't update user intent - they didn't choose to pause
        _player.pause();
        _stateController.updateState(base_handler.AudioPlayerState.paused);
      }
    } else {
      // Audio interruption ended
      if (_stateController.userIntendedPlaying && !_player.playing) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Resuming after audio interruption ended');
        }
        // Resume playback since user originally intended to play
        Future.microtask(() async {
          try {
            await _attemptForegroundService();
            await _player.play();
          } catch (e) {
            if (kDebugMode) {
              print('DoudouAudioHandler: Failed to resume after interruption: $e');
            }
            // Try to resume without foreground service
            try {
              await _player.play();
            } catch (playError) {
              if (kDebugMode) {
                print('DoudouAudioHandler: Player resume also failed: $playError');
              }
              _stateController.updateError('Failed to resume after interruption: $playError');
            }
          }
        });
      }
    }
  }

  /// Handle becoming noisy events (headphones unplugged, etc.)
  void _handleBecomingNoisy(dynamic event) {
    if (kDebugMode) {
      print('DoudouAudioHandler: Audio becoming noisy - pausing playbook');
    }

    // Pause playbook when audio becomes noisy (e.g., headphones unplugged)
    if (_player.playing) {
      // Update user intent since this is a user-affecting event
      _stateController.updateUserIntent(false);
      _player.pause();
      _stateController.updateState(base_handler.AudioPlayerState.paused);
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
    // Sync playback state to AudioService (with foreground service error handling)
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

    // Sync current track to MediaItem (with foreground service error handling)
    _subscriptions.add(
      _stateController.currentTrackStream.listen((track) {
        _safeUpdateMediaItem(track);
      }),
    );

    // Sync queue to AudioService (with foreground service error handling)
    _subscriptions.add(
      _stateController.queueStream.listen((tracks) {
        _safeUpdateQueue(tracks);
      }),
    );
  }

  /// Safely update playback state without triggering foreground service errors
  void _safeUpdatePlaybackState(PlaybackState state) {
    if (_foregroundServiceIssues) {
      // Skip updating AudioService state if we know foreground service has issues
      return;
    }

    try {
      playbackState.add(state);
    } catch (e) {
      _foregroundServiceIssues = true;
      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Playback state update failed, marking foreground service issues: $e',
        );
      }
    }
  }

  /// Safely update media item without triggering foreground service errors
  void _safeUpdateMediaItem(Track? track) {
    if (_foregroundServiceIssues) {
      // Skip updating AudioService MediaItem if we know foreground service has issues
      return;
    }

    try {
      if (track != null) {
        mediaItem.add(_trackToMediaItem(track));
      } else {
        mediaItem.add(null);
      }
    } catch (e) {
      _foregroundServiceIssues = true;
      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Media item update failed, marking foreground service issues: $e',
        );
      }
    }
  }

  /// Force MediaItem update for UI synchronization, ignoring foreground service issues
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
        print(
          'DoudouAudioHandler: Forced MediaItem update failed (continuing anyway): $e',
        );
      }
      // Don't set _foregroundServiceIssues here since this is specifically for UI updates
    }
  }

  /// Safely update queue without triggering foreground service errors
  void _safeUpdateQueue(List<Track> tracks) {
    if (_foregroundServiceIssues) {
      // Skip updating AudioService queue if we know foreground service has issues
      return;
    }

    try {
      queue.add(tracks.map(_trackToMediaItem).toList());
    } catch (e) {
      _foregroundServiceIssues = true;
      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Queue update failed, marking foreground service issues: $e',
        );
      }
    }
  }

  /// Force comprehensive UI synchronization for track changes
  void _forceUISynchronization(Track track, int index) {
    // Ensure state controller has the latest information first
    _stateController.updateCurrentIndex(index);
    _stateController.updateCurrentTrack(track);

    // Force MediaItem update for UI purposes (ignore foreground service issues for UI)
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
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _stateController.updateState(base_handler.AudioPlayerState.loading);
        break;
      case ProcessingState.ready:
        if (playerState.playing) {
          _stateController.updateState(base_handler.AudioPlayerState.playing);
          // Ensure foreground service is running when playing
          _attemptForegroundService();
        } else {
          // Check if we should auto-continue playback (important for background track transitions)
          if (_stateController.userIntendedPlaying &&
              _stateController.currentState ==
                  base_handler.AudioPlayerState.loading) {
            if (kDebugMode) {
              print(
                'DoudouAudioHandler: Track ready, auto-continuing playback in background',
              );
            }
            // Resume playback without blocking
            Future.microtask(() async {
              try {
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
        break;
    }
  }

  /// Handle processing state changes
  void _handleProcessingStateChange(ProcessingState state) {
    if (state == ProcessingState.ready) {
      _stateController.clearError();
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

      // Use normal skip for better UI responsiveness during auto-advance
      // Reset foreground service issues flag for auto-advance to ensure UI updates
      final hadForegroundIssues = _foregroundServiceIssues;
      _foregroundServiceIssues = false;

      try {
        await _performSkipToQueueItem(nextIndex);
      } finally {
        // Restore the original foreground service issues state after a short delay
        // This allows UI to update but prevents repeated foreground service attempts
        Future.delayed(const Duration(milliseconds: 100), () {
          _foregroundServiceIssues = hadForegroundIssues;
        });
      }
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
      // This is a placeholder - implement based on your media service capabilities
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
    // Implement similar track fetching based on your media service
    // This could use genre, artist, or other metadata
    try {
      // Example: Get tracks from the same artist
      final artistTracks = await _mediaServiceManager.getTracks(
        parentId: track.artistName,
        limit: 20,
      );

      // Filter out current track and already queued tracks
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

  /// Create PlaybackState for AudioService
  PlaybackState _createPlaybackState(
    base_handler.AudioPlayerState state,
    Duration position,
    double speed,
  ) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (state == base_handler.AudioPlayerState.playing)
          MediaControl.pause
        else
          MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapToAudioServiceProcessingState(state),
      playing: state == base_handler.AudioPlayerState.playing,
      updatePosition: position,
      bufferedPosition: _player.bufferedPosition,
      speed: speed,
      queueIndex: _stateController.currentIndex,
    );
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

  /// Convert Track to MediaItem
  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      album: track.albumName,
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      duration: track.duration != null
          ? Duration(milliseconds: track.duration!)
          : null,
      artUri: Uri.tryParse(
        _mediaServiceManager.getImageUrl(
          track.albumId ?? track.id,
          width: 300,
          height: 300,
        ),
      ),
      extras: {'trackId': track.id, 'albumId': track.albumId},
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

  // Additional streams for AudioService integration
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

  // Playbook control methods

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
      // Reset foreground service issues when user explicitly plays
      // (they might have brought app to foreground)
      _foregroundServiceIssues = false;

      // Try to start foreground service, but continue if it fails
      await _attemptForegroundService();

      await _player.play();
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

  /// Attempt to start foreground service, gracefully handle failure
  Future<void> _attemptForegroundService() async {
    // Skip if we know foreground service has issues
    if (_foregroundServiceIssues) {
      return;
    }

    try {
      // Update playback state to trigger foreground service
      final currentState = _stateController.currentState;
      final position = _stateController.position;
      final speed = _stateController.speed;

      final playbackState = _createPlaybackState(
        currentState,
        position,
        speed,
      ).copyWith(playing: true, processingState: AudioProcessingState.ready);

      _safeUpdatePlaybackState(playbackState);

      // Small delay to allow the service to process the state change
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      // Mark that we have foreground service issues to avoid repeated attempts
      _foregroundServiceIssues = true;

      if (kDebugMode) {
        print(
          'DoudouAudioHandler: Foreground service start failed (continuing anyway): $e',
        );
      }
      // Continue without foreground service - audio will still work in background
      // but without the persistent notification when app is backgrounded
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

    // Run the actual audio operation asynchronously without blocking UI
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

    // Update UI position immediately for responsiveness
    _stateController.updatePosition(position);

    // Run the actual seek operation asynchronously without blocking UI
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

    // Force UI synchronization for reliable track updates
    _forceMediaItemUpdate(track);

    // Run actual playback asynchronously
    _performPlayTrack(track);
  }

  Future<void> _performPlayTrack(Track track) async {
    try {
      // Get stream URL
      final streamUrl = _getStreamUrl(track);

      // Load and play the track
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

    // Update UI immediately
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
      // Play the starting track
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
      // Update UI immediately
      final queue = _stateController.queue;
      if (nextIndex < queue.length) {
        final nextTrack = queue[nextIndex];
        _stateController.updateCurrentIndex(nextIndex);
        _stateController.updateCurrentTrack(nextTrack);
        _stateController.updateState(base_handler.AudioPlayerState.loading);

        // Force UI synchronization for reliable track updates
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
      // Update UI immediately
      final queue = _stateController.queue;
      if (previousIndex >= 0 && previousIndex < queue.length) {
        final previousTrack = queue[previousIndex];
        _stateController.updateCurrentIndex(previousIndex);
        _stateController.updateCurrentTrack(previousTrack);
        _stateController.updateState(base_handler.AudioPlayerState.loading);

        // Force UI synchronization for reliable track updates
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

    // Update UI immediately with comprehensive synchronization
    final queue = _stateController.queue;
    if (index >= 0 && index < queue.length) {
      final track = queue[index];
      _stateController.updateCurrentIndex(index);
      _stateController.updateCurrentTrack(track);
      _stateController.updateState(base_handler.AudioPlayerState.loading);

      // Force UI synchronization to prevent desync
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

      // Reset foreground service issues flag for manual skips
      // (user is likely interacting with the app)
      _foregroundServiceIssues = false;

      await _playTrackAtIndex(index);
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Skip to index failed: $e');
      }
      _stateController.updateError('Skip failed: $e');
    }
  }

  /// Play track at specific queue index
  Future<void> _playTrackAtIndex(int index) async {
    final queue = _stateController.queue;
    final track = queue[index];

    _stateController.updateCurrentIndex(index);
    _stateController.updateCurrentTrack(track);

    final streamUrl = _getStreamUrl(track);
    await _loadAndPlayTrack(streamUrl);
  }

  /// Load and play track from URL (non-blocking)
  Future<void> _loadAndPlayTrack(String url) async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Loading audio source: $url');
    }

    _stateController.updateState(base_handler.AudioPlayerState.loading);
    _stateController.updateUserIntent(true);

    // Run loading operation asynchronously to prevent UI blocking
    _performLoadAndPlayTrack(url);
  }

  Future<void> _performLoadAndPlayTrack(String url) async {
    await _performLoadAndPlayTrackWithRetry(url, maxRetries: 3);
  }

  /// Load and play track with automatic retry for network resilience
  Future<void> _performLoadAndPlayTrackWithRetry(String url, {int maxRetries = 3}) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      attempts++;
      
      try {
        if (kDebugMode && attempts > 1) {
          print('DoudouAudioHandler: Retry attempt $attempts/$maxRetries for: $url');
        }

        // Set audio source without blocking UI
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
        if (kDebugMode) {
          print('DoudouAudioHandler: Audio source set successfully on attempt $attempts');
        }

        // Only start playback if user intended to play (important for background transitions)
        if (_stateController.userIntendedPlaying) {
          // Try to handle foreground service before starting playback
          await _attemptForegroundService();

          await _player.play();
          if (kDebugMode) {
            print('DoudouAudioHandler: Playback started successfully on attempt $attempts');
          }
        } else {
          if (kDebugMode) {
            print(
              'DoudouAudioHandler: Audio loaded but not playing (user did not intend to play)',
            );
          }
          _stateController.updateState(base_handler.AudioPlayerState.paused);
        }

        // Success - break out of retry loop
        return;

      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (kDebugMode) {
          print('DoudouAudioHandler: Load attempt $attempts failed: $e');
        }

        if (attempts < maxRetries) {
          // Wait before retrying (exponential backoff)
          final delayMs = 1000 * attempts; // 1s, 2s, 3s delays
          if (kDebugMode) {
            print('DoudouAudioHandler: Waiting ${delayMs}ms before retry...');
          }
          await Future.delayed(Duration(milliseconds: delayMs));
          
          // Check if user still wants to play before retrying
          if (!_stateController.userIntendedPlaying) {
            if (kDebugMode) {
              print('DoudouAudioHandler: User no longer wants to play, aborting retry');
            }
            return;
          }
        }
      }
    }

    // All retries failed
    if (kDebugMode) {
      print('DoudouAudioHandler: All $maxRetries attempts failed: $lastException');
    }
    _stateController.updateState(base_handler.AudioPlayerState.error);
    _stateController.updateUserIntent(false);
    _stateController.updateError('Failed to load track after $maxRetries attempts: $lastException');
  }

  /// Get stream URL for track
  String _getStreamUrl(Track track) {
    // Try direct stream first (no transcoding) for better compatibility
    final directUrl = _mediaServiceManager.getDirectStreamUrl(track.id);
    if (directUrl.isNotEmpty) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Using direct stream URL: $directUrl');
      }
      return directUrl;
    }

    // Fallback to transcoded stream
    final transcodedUrl = _mediaServiceManager.getStreamUrl(track.id);
    if (kDebugMode) {
      print('DoudouAudioHandler: Using transcoded stream URL: $transcodedUrl');
    }
    return transcodedUrl;
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

    // Cancel radio mode timer
    _radioModeTimer?.cancel();

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
