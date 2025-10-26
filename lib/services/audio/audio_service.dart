import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';
import '../download_service.dart';
import 'audio_handler.dart';
import 'audio_state.dart';

/// Modern, clean audio service that provides reliable cross-platform audio playback
/// without race conditions or complex synchronization primitives.
class DoudouAudioService {
  static DoudouAudioService? _instance;
  static DoudouAudioService get instance {
    _instance ??= DoudouAudioService._internal();
    return _instance!;
  }

  DoudouAudioService._internal();

  late DoudouAudioHandler _audioHandler;
  bool _initialized = false;

  // Reactive streams for UI updates
  final BehaviorSubject<AudioState> _audioStateController = BehaviorSubject<AudioState>.seeded(
    AudioState.initial(),
  );

  final BehaviorSubject<List<Track>> _playlistController = BehaviorSubject<List<Track>>.seeded([]);
  final BehaviorSubject<int?> _currentIndexController = BehaviorSubject<int?>.seeded(null);
  final BehaviorSubject<bool> _shuffleController = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<RepeatMode> _repeatModeController = BehaviorSubject<RepeatMode>.seeded(RepeatMode.none);

  // Public streams
  Stream<AudioState> get audioState => _audioStateController.stream;
  Stream<List<Track>> get playlist => _playlistController.stream;
  Stream<int?> get currentIndex => _currentIndexController.stream;
  Stream<bool> get shuffle => _shuffleController.stream;
  Stream<RepeatMode> get repeatMode => _repeatModeController.stream;

  // Current state getters
  AudioState get currentAudioState => _audioStateController.value;
  List<Track> get currentPlaylist => _playlistController.value;
  int? get currentTrackIndex => _currentIndexController.value;
  Track? get currentTrack => 
      currentTrackIndex != null && currentTrackIndex! < currentPlaylist.length 
          ? currentPlaylist[currentTrackIndex!]
          : null;
  bool get isShuffleEnabled => _shuffleController.value;
  RepeatMode get currentRepeatMode => _repeatModeController.value;

  /// Initialize the audio service
  Future<void> initialize(JellyfinService jellyfinService, DownloadService downloadService) async {
    if (_initialized) return;

    try {
      if (kDebugMode) {
        print('DoudouAudioService: Initializing audio service for ${Platform.operatingSystem}');
      }

      // Initialize AudioService if supported
      if (_isAudioServiceSupported()) {
        _audioHandler = await AudioService.init(
          builder: () => DoudouAudioHandler(jellyfinService, downloadService),
          config: AudioServiceConfig(
            androidNotificationChannelId: 'com.example.doudou.channel.audio',
            androidNotificationChannelName: 'Audio playback',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            androidNotificationChannelDescription: 'Music playback controls',
            androidNotificationIcon: 'drawable/ic_notification',
            androidShowNotificationBadge: true,
          ),
        );
      } else {
        // Direct audio handler for unsupported platforms
        _audioHandler = DoudouAudioHandler(jellyfinService, downloadService);
        await _audioHandler.initializeDirectly();
      }

      // Subscribe to audio handler state changes
      _setupStateStreams();

      _initialized = true;

      if (kDebugMode) {
        print('DoudouAudioService: Successfully initialized for ${Platform.operatingSystem}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioService: Failed to initialize: $e');
      }
      rethrow;
    }
  }

  /// Check if AudioService is supported on this platform
  bool _isAudioServiceSupported() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Set up reactive streams from audio handler
  void _setupStateStreams() {
    // Listen to playback state changes
    _audioHandler.playbackState.listen((playbackState) {
      final currentState = _audioStateController.value;
      _audioStateController.add(currentState.copyWith(
        isPlaying: playbackState.playing,
        processingState: playbackState.processingState,
        position: playbackState.updatePosition,
        bufferedPosition: playbackState.bufferedPosition,
        speed: playbackState.speed,
      ));
    });

    // Listen to media item changes  
    _audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        final currentState = _audioStateController.value;
        _audioStateController.add(currentState.copyWith(
          duration: mediaItem.duration,
          title: mediaItem.title,
          artist: mediaItem.artist,
          album: mediaItem.album,
          artUri: mediaItem.artUri,
        ));
      }
    });

    // Listen to queue changes
    _audioHandler.queue.listen((queue) {
      final tracks = queue.map((item) => _mediaItemToTrack(item)).toList();
      _playlistController.add(tracks);
    });

    // Listen to playback mode changes
    _audioHandler.customState.listen((state) {
      if (state['shuffle'] != null) {
        _shuffleController.add(state['shuffle'] as bool);
      }
      if (state['repeat'] != null) {
        final repeatIndex = state['repeat'] as int;
        if (repeatIndex >= 0 && repeatIndex < RepeatMode.values.length) {
          _repeatModeController.add(RepeatMode.values[repeatIndex]);
        }
      }
      if (state['currentIndex'] != null) {
        _currentIndexController.add(state['currentIndex'] as int?);
      }
    });
  }

  /// Convert MediaItem back to Track
  Track _mediaItemToTrack(MediaItem item) {
    return Track(
      id: item.id,
      name: item.title,
      artistName: item.artist,
      albumName: item.album,
      duration: item.duration?.inMilliseconds,
      imageUrl: item.artUri?.toString(),
    );
  }

  // Playback control methods
  Future<void> play() async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.play();
  }

  Future<void> pause() async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.pause();
  }

  Future<void> stop() async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.stop();
  }

  Future<void> seek(Duration position) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.seek(position);
  }

  Future<void> skipToNext() async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.skipToNext();
  }

  Future<void> skipToPrevious() async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.skipToPrevious();
  }

  Future<void> skipToTrack(int index) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.skipToQueueItem(index);
  }

  // Playlist management
  Future<void> playPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    if (tracks.isEmpty) throw ArgumentError('Playlist cannot be empty');

    final mediaItems = tracks.map(_trackToMediaItem).toList();
    await _audioHandler.updateQueue(mediaItems);
    
    if (startIndex >= 0 && startIndex < tracks.length) {
      await _audioHandler.skipToQueueItem(startIndex);
    }
    
    await _audioHandler.play();
  }

  Future<void> addToQueue(Track track) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.addQueueItem(_trackToMediaItem(track));
  }

  Future<void> addToQueueAt(Track track, int index) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.addQueueItems([_trackToMediaItem(track)]);
    // TODO: Implement proper insertion at index if needed
  }

  Future<void> removeFromQueue(int index) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.removeQueueItemAt(index);
  }

  Future<void> clearQueue() async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.updateQueue([]);
  }

  // Playback modes
  Future<void> setShuffle(bool enabled) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    await _audioHandler.setShuffleMode(enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    if (!_initialized) throw StateError('AudioService not initialized');
    AudioServiceRepeatMode audioServiceMode;
    switch (mode) {
      case RepeatMode.none:
        audioServiceMode = AudioServiceRepeatMode.none;
        break;
      case RepeatMode.one:
        audioServiceMode = AudioServiceRepeatMode.one;
        break;
      case RepeatMode.all:
        audioServiceMode = AudioServiceRepeatMode.all;
        break;
    }
    await _audioHandler.setRepeatMode(audioServiceMode);
  }

  /// Convert Track to MediaItem
  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      album: track.albumName ?? 'Unknown Album',
      duration: track.duration != null ? Duration(milliseconds: track.duration!) : null,
      artUri: track.imageUrl != null ? Uri.parse(track.imageUrl!) : null,
      playable: true,
      extras: {
        'trackId': track.id,
        'albumId': track.albumId,
        'trackNumber': track.trackNumber,
      },
    );
  }

  /// Dispose of the service
  void dispose() {
    _audioStateController.close();
    _playlistController.close();
    _currentIndexController.close();
    _shuffleController.close();
    _repeatModeController.close();
    _initialized = false;
  }
}

enum RepeatMode {
  none,
  one,
  all,
}