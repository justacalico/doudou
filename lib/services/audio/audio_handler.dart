import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';
import '../download_service.dart';

/// Clean, modern audio handler that avoids race conditions
class DoudouAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final JellyfinService _jellyfinService;
  final DownloadService _downloadService;

  // Simple state management
  bool _isInitialized = false;
  List<Track> _playlist = [];
  int? _currentIndex;
  bool _shuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  // Stream controllers for custom state
  final BehaviorSubject<Map<String, dynamic>> _customStateController =
      BehaviorSubject<Map<String, dynamic>>.seeded({});

  Stream<Map<String, dynamic>> get customState => _customStateController.stream;

  DoudouAudioHandler(this._jellyfinService, this._downloadService);

  /// Initialize the audio handler directly (without AudioService)
  Future<void> initializeDirectly() async {
    if (_isInitialized) return;

    try {
      await _initialize();
      _isInitialized = true;
      if (kDebugMode) {
        print('DoudouAudioHandler: Initialized directly for ${Platform.operatingSystem}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to initialize directly: $e');
      }
      rethrow;
    }
  }

  /// Common initialization logic
  Future<void> _initialize() async {
    // Platform-specific audio configuration
    await _configureAudioSession();

    // Set up player listeners
    _setupPlayerListeners();

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
      queueIndex: 0,
    ));

    if (kDebugMode) {
      print('DoudouAudioHandler: Audio handler initialized for ${Platform.operatingSystem}');
    }
  }

  /// Configure audio session for each platform
  Future<void> _configureAudioSession() async {
    try {
      if (Platform.isIOS) {
        // iOS: Configure audio session for background playback
        // The audio_service plugin handles most of this automatically
        if (kDebugMode) {
          print('DoudouAudioHandler: Configuring iOS audio session');
        }
      } else if (Platform.isAndroid) {
        // Android: Configure audio focus and MediaSession
        if (kDebugMode) {
          print('DoudouAudioHandler: Configuring Android audio focus');
        }
      } else if (Platform.isMacOS) {
        // macOS: Configure for system integration
        if (kDebugMode) {
          print('DoudouAudioHandler: Configuring macOS audio session');
        }
      } else if (Platform.isWindows) {
        // Windows: Configure for system media controls
        if (kDebugMode) {
          print('DoudouAudioHandler: Configuring Windows audio session');
        }
      } else if (Platform.isLinux) {
        // Linux: Configure for MPRIS integration
        if (kDebugMode) {
          print('DoudouAudioHandler: Configuring Linux audio session');
        }
      } else if (kIsWeb) {
        // Web: Configure for HTML5 audio
        if (kDebugMode) {
          print('DoudouAudioHandler: Configuring Web audio session');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Audio session configuration warning: $e');
      }
    }
  }

  /// Set up player event listeners
  void _setupPlayerListeners() {
    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      _updatePlaybackState();
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      if (playbackState.value.updatePosition != position) {
        _updatePlaybackState();
      }
    });

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      _updateCurrentMediaItem();
    });

    // Listen to current index changes (for gapless playback)
    _player.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        _updateCurrentMediaItem();
        _updateCustomState();
      }
    });

    // Listen to playback events for completion handling
    _player.playbackEventStream.listen((event) {
      _handlePlaybackEvent(event);
    });

    if (kDebugMode) {
      print('DoudouAudioHandler: Player listeners set up');
    }
  }

  /// Handle playback events (completion, errors, etc.)
  void _handlePlaybackEvent(PlaybackEvent event) {
    // Handle track completion
    if (event.processingState == ProcessingState.completed) {
      _handleTrackCompletion();
    }

    // Handle playback errors
    if (event.processingState == ProcessingState.idle && 
        _currentIndex != null && 
        _playlist.isNotEmpty &&
        _player.duration != null) {
      // Track unexpectedly went idle - attempt recovery
      if (kDebugMode) {
        print('DoudouAudioHandler: Unexpected idle state, attempting recovery');
      }
      _handlePlaybackError();
    }
  }

  /// Handle track completion and auto-advance
  void _handleTrackCompletion() async {
    if (kDebugMode) {
      print('DoudouAudioHandler: Track completed, handling auto-advance');
    }

    try {
      // Handle repeat one mode
      if (_repeatMode == AudioServiceRepeatMode.one) {
        await seek(Duration.zero);
        await play();
        return;
      }

      // Move to next track
      await skipToNext();
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Error handling track completion: $e');
      }
    }
  }

  /// Handle playback errors with simple recovery
  void _handlePlaybackError() {
    if (kDebugMode) {
      print('DoudouAudioHandler: Handling playback error, attempting recovery');
    }

    // Simple error recovery - try to reload current track after a delay
    Future.delayed(const Duration(seconds: 2), () async {
      if (_currentIndex != null && _currentIndex! < _playlist.length) {
        try {
          await _playTrackAtIndex(_currentIndex!);
          if (kDebugMode) {
            print('DoudouAudioHandler: Recovery successful');
          }
        } catch (e) {
          if (kDebugMode) {
            print('DoudouAudioHandler: Recovery failed: $e');
          }
          // Update state to show error
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            playing: false,
          ));
        }
      }
    });
  }

  /// Update the playback state based on current player state
  void _updatePlaybackState() {
    final playerState = _player.playerState;

    playbackState.add(PlaybackState(
      controls: _getMediaControls(playerState.playing),
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(playerState.processingState),
      playing: playerState.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
      shuffleMode: _shuffleEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      repeatMode: _repeatMode,
    ));
  }

  /// Get appropriate media controls based on playing state
  List<MediaControl> _getMediaControls(bool isPlaying) {
    return [
      MediaControl.skipToPrevious,
      isPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ];
  }

  /// Map just_audio ProcessingState to audio_service AudioProcessingState
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

  /// Update the current media item
  void _updateCurrentMediaItem() {
    if (_currentIndex != null &&
        _currentIndex! >= 0 &&
        _currentIndex! < _playlist.length) {
      final track = _playlist[_currentIndex!];
      mediaItem.add(_createMediaItem(track));
    }
  }

  /// Update custom state (for UI synchronization)
  void _updateCustomState() {
    _customStateController.add({
      'shuffle': _shuffleEnabled,
      'repeat': _repeatMode.index,
      'currentIndex': _currentIndex,
      'playlistLength': _playlist.length,
    });
  }

  /// Create a MediaItem from a Track
  MediaItem _createMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.name,
      artist: track.artistName ?? 'Unknown Artist',
      album: track.albumName ?? 'Unknown Album',
      duration: track.duration != null ? Duration(milliseconds: track.duration!) : null,
      artUri: track.imageUrl != null ? _buildImageUri(track.imageUrl!) : null,
      playable: true,
      extras: {
        'trackId': track.id,
        'albumId': track.albumId,
        'trackNumber': track.trackNumber,
      },
    );
  }

  /// Build image URI for track artwork
  Uri? _buildImageUri(String imageId) {
    try {
      final imageUrl = _jellyfinService.getImageUrl(imageId, type: 'Primary');
      if (imageUrl.isNotEmpty) {
        return Uri.parse(imageUrl);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to build image URI: $e');
      }
      return null;
    }
  }

  /// Get stream URL for a track with fallbacks
  Future<String?> _getStreamUrl(Track track) async {
    try {
      // Check for downloaded file first
      final localPath = await _downloadService.getLocalFilePath(track.id);
      if (localPath != null && await File(localPath).exists()) {
        return 'file://$localPath';
      }

      // Get streaming URL from Jellyfin
      return _jellyfinService.getStreamUrl(track.id);
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to get stream URL for ${track.name}: $e');
      }
      return null;
    }
  }

  /// Play a track at the specified index
  Future<void> _playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      _currentIndex = index;
      final track = _playlist[index];

      if (kDebugMode) {
        print('DoudouAudioHandler: Playing track at index $index: ${track.name}');
      }

      // Get stream URL with fallbacks
      final streamUrl = await _getStreamUrl(track);
      if (streamUrl == null) {
        throw Exception('No stream URL available for track: ${track.name}');
      }

      // Load the track with appropriate audio source
      AudioSource audioSource;
      if (streamUrl.startsWith('file://')) {
        audioSource = AudioSource.file(streamUrl.substring(7));
      } else {
        audioSource = AudioSource.uri(Uri.parse(streamUrl));
      }

      // Set up gapless playback if we have multiple tracks
      if (_playlist.length > 1) {
        await _setupGaplessPlayback(index, audioSource);
      } else {
        await _player.setAudioSource(audioSource);
      }

      // Update media item and state
      _updateCurrentMediaItem();
      _updateCustomState();
      _updatePlaybackState();

      if (kDebugMode) {
        print('DoudouAudioHandler: Successfully loaded track: ${track.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to play track at index $index: $e');
      }

      // Update state to show error
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
    }
  }

  /// Set up gapless playback with concatenating audio source
  Future<void> _setupGaplessPlayback(int currentIndex, AudioSource currentSource) async {
    try {
      final audioSources = <AudioSource>[];
      
      // Add current track
      audioSources.add(currentSource);
      
      // Add next few tracks for gapless playback (limit to 3 for performance)
      final tracksToPreload = 3;
      for (int i = 1; i <= tracksToPreload && (currentIndex + i) < _playlist.length; i++) {
        final nextTrack = _playlist[currentIndex + i];
        final nextStreamUrl = await _getStreamUrl(nextTrack);
        
        if (nextStreamUrl != null) {
          AudioSource nextSource;
          if (nextStreamUrl.startsWith('file://')) {
            nextSource = AudioSource.file(nextStreamUrl.substring(7));
          } else {
            nextSource = AudioSource.uri(Uri.parse(nextStreamUrl));
          }
          audioSources.add(nextSource);
        }
      }
      
      // Create concatenating source and set initial index
      final concatenatingSource = ConcatenatingAudioSource(children: audioSources);
      await _player.setAudioSource(concatenatingSource, initialIndex: 0);
      
      if (kDebugMode) {
        print('DoudouAudioHandler: Set up gapless playback with ${audioSources.length} tracks');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Failed to set up gapless playback, falling back to single track: $e');
      }
      // Fallback to single track
      await _player.setAudioSource(currentSource);
    }
  }

  // AudioHandler implementation
  @override
  Future<void> play() async {
    try {
      if (_playlist.isEmpty) {
        if (kDebugMode) {
          print('DoudouAudioHandler: Cannot play - no tracks in playlist');
        }
        return;
      }

      if (_player.audioSource == null && _currentIndex != null) {
        await _playTrackAtIndex(_currentIndex!);
      }

      await _player.play();

      if (kDebugMode) {
        print('DoudouAudioHandler: Play command executed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Play failed: $e');
      }
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();

      if (kDebugMode) {
        print('DoudouAudioHandler: Pause command executed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Pause failed: $e');
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();

      if (kDebugMode) {
        print('DoudouAudioHandler: Stop command executed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Stop failed: $e');
      }
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);

      if (kDebugMode) {
        print('DoudouAudioHandler: Seek to ${position.inSeconds}s');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Seek failed: $e');
      }
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_currentIndex == null || _playlist.isEmpty) return;

      int nextIndex;
      if (_shuffleEnabled) {
        final availableIndices = List.generate(_playlist.length, (i) => i)
            .where((i) => i != _currentIndex)
            .toList();
        if (availableIndices.isEmpty) return;
        nextIndex = availableIndices[DateTime.now().millisecondsSinceEpoch % availableIndices.length];
      } else {
        nextIndex = _currentIndex! + 1;

        if (nextIndex >= _playlist.length) {
          if (_repeatMode == AudioServiceRepeatMode.all) {
            nextIndex = 0;
          } else {
            return;
          }
        }
      }

      await _playTrackAtIndex(nextIndex);
      await play();

      if (kDebugMode) {
        print('DoudouAudioHandler: Skipped to next track at index $nextIndex');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Skip to next failed: $e');
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_currentIndex == null || _playlist.isEmpty) return;

      if (_player.position.inSeconds > 3) {
        await seek(Duration.zero);
        return;
      }

      int previousIndex;
      if (_shuffleEnabled) {
        final availableIndices = List.generate(_playlist.length, (i) => i)
            .where((i) => i != _currentIndex)
            .toList();
        if (availableIndices.isEmpty) return;
        previousIndex = availableIndices[DateTime.now().millisecondsSinceEpoch % availableIndices.length];
      } else {
        previousIndex = _currentIndex! - 1;

        if (previousIndex < 0) {
          if (_repeatMode == AudioServiceRepeatMode.all) {
            previousIndex = _playlist.length - 1;
          } else {
            previousIndex = 0;
          }
        }
      }

      await _playTrackAtIndex(previousIndex);
      await play();

      if (kDebugMode) {
        print('DoudouAudioHandler: Skipped to previous track at index $previousIndex');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Skip to previous failed: $e');
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      if (index >= 0 && index < _playlist.length) {
        await _playTrackAtIndex(index);
        await play();

        if (kDebugMode) {
          print('DoudouAudioHandler: Skipped to queue item at index $index');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Skip to queue item failed: $e');
      }
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    try {
      _playlist = queue.map((item) => Track(
        id: item.id,
        name: item.title,
        artistName: item.artist,
        albumName: item.album,
        duration: item.duration?.inMilliseconds,
        albumId: item.extras?['albumId'] as String?,
        trackNumber: item.extras?['trackNumber'] as int?,
        imageUrl: item.artUri?.toString(),
      )).toList();

      _currentIndex = _playlist.isNotEmpty ? 0 : null;
      super.queue.add(queue);
      _updateCustomState();

      if (kDebugMode) {
        print('DoudouAudioHandler: Updated queue with ${_playlist.length} tracks');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Update queue failed: $e');
      }
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    try {
      final track = Track(
        id: mediaItem.id,
        name: mediaItem.title,
        artistName: mediaItem.artist,
        albumName: mediaItem.album,
        duration: mediaItem.duration?.inMilliseconds,
        albumId: mediaItem.extras?['albumId'] as String?,
        trackNumber: mediaItem.extras?['trackNumber'] as int?,
        imageUrl: mediaItem.artUri?.toString(),
      );

      _playlist.add(track);
      _currentIndex ??= 0;

      final currentQueue = List<MediaItem>.from(queue.value);
      currentQueue.add(mediaItem);
      super.queue.add(currentQueue);
      _updateCustomState();

      if (kDebugMode) {
        print('DoudouAudioHandler: Added track to queue: ${track.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Add queue item failed: $e');
      }
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    try {
      if (index >= 0 && index < _playlist.length) {
        final removedTrack = _playlist.removeAt(index);

        if (_currentIndex != null) {
          if (index < _currentIndex!) {
            _currentIndex = _currentIndex! - 1;
          } else if (index == _currentIndex!) {
            if (_currentIndex! >= _playlist.length) {
              _currentIndex = _playlist.length - 1;
            }
            if (_playlist.isNotEmpty) {
              await _playTrackAtIndex(_currentIndex!);
            }
          }
        }

        final currentQueue = List<MediaItem>.from(queue.value);
        if (index < currentQueue.length) {
          currentQueue.removeAt(index);
          super.queue.add(currentQueue);
        }
        _updateCustomState();

        if (kDebugMode) {
          print('DoudouAudioHandler: Removed track from queue: ${removedTrack.name}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DoudouAudioHandler: Remove queue item failed: $e');
      }
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleEnabled = shuffleMode == AudioServiceShuffleMode.all;
    _updateCustomState();
    _updatePlaybackState();

    if (kDebugMode) {
      print('DoudouAudioHandler: Shuffle mode set to: $shuffleMode');
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    _updateCustomState();
    _updatePlaybackState();

    if (kDebugMode) {
      print('DoudouAudioHandler: Repeat mode set to: $repeatMode');
    }
  }

  /// Dispose of resources
  void dispose() {
    _player.dispose();
    _customStateController.close();
  }
}

/// Enum for image types (from Jellyfin API)
enum ImageType {
  primary,
  backdrop,
  banner,
  logo,
}