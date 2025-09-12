import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../models/jellyfin_models.dart';
import '../jellyfin_service.dart';

// Largely copied from just_audio's DefaultShuffleOrder, but with a mildly
// stupid hack to insert() to make Play Next work
class DoudouShuffleOrder extends ShuffleOrder {
  final Random _random;
  @override
  final indices = <int>[];

  DoudouShuffleOrder({Random? random}) : _random = random ?? Random();

  @override
  void shuffle({int? initialIndex}) {
    assert(initialIndex == null || indices.contains(initialIndex));
    if (indices.length <= 1) return;
    indices.shuffle(_random);
    if (initialIndex == null) return;

    const initialPos = 0;
    final swapPos = indices.indexOf(initialIndex);
    // Swap the indices at initialPos and swapPos.
    final swapIndex = indices[initialPos];
    indices[initialPos] = initialIndex;
    indices[swapPos] = swapIndex;
  }

  @override
  void insert(int index, int count) {
    // Offset indices after insertion point.
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= index) {
        indices[i] += count;
      }
    }

    final newIndices = List.generate(count, (i) => index + i);
    // This is the only modification from DefaultShuffleOrder: Only shuffle
    // inserted indices amongst themselves, but keep them contiguous
    newIndices.shuffle(_random);
    indices.insertAll(index, newIndices);
  }

  @override
  void removeRange(int start, int end) {
    final count = end - start;
    // Remove old indices.
    final oldIndices = List.generate(count, (i) => start + i).toSet();
    indices.removeWhere(oldIndices.contains);
    // Offset indices after deletion point.
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= end) {
        indices[i] -= count;
      }
    }
  }

  @override
  void clear() {
    indices.clear();
  }
}

/// This provider handles the currently playing music so that multiple widgets
/// can control music. Based on Finamp's reliable audio implementation.
class DoudouAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  ConcatenatingAudioSource _queueAudioSource = ConcatenatingAudioSource(
    children: [],
    shuffleOrder: DoudouShuffleOrder(),
  );
  final JellyfinService _jellyfinService;

  /// Set when shuffle mode is changed. If true, [onUpdateQueue] will create a
  /// shuffled [ConcatenatingAudioSource].
  bool shuffleNextQueue = false;

  /// Set when creating a new queue. Will be used to set the first index in a
  /// new queue.
  int? nextInitialIndex;

  /// Set to true when we're stopping the audio service. Used to avoid playback
  /// progress reporting.
  bool _isStopping = false;

  /// Holds the current sleep timer, if any.
  bool _sleepTimerIsSet = false;
  Duration _sleepTimerDuration = Duration.zero;
  Timer? _sleepTimer;

  List<int>? get shuffleIndices => _player.shuffleIndices;

  DoudouAudioHandler(this._jellyfinService) {
    if (kDebugMode) {
      print("Starting DoudouAudioHandler");
    }

    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen((event) async {
      final prevState = playbackState.valueOrNull;
      final prevIndex = prevState?.queueIndex;
      final prevItem = mediaItem.valueOrNull;
      final currentState = _transformEvent(event);
      final currentIndex = currentState.queueIndex;

      playbackState.add(currentState);

      if (currentIndex != null) {
        final currentItem = _getQueueItem(currentIndex);

        // Differences in queue index or item id are considered track changes
        if (currentIndex != prevIndex || currentItem.id != prevItem?.id) {
          mediaItem.add(currentItem);
          onTrackChanged(currentItem, currentState, prevItem, prevState);
        }
      }

      if (playbackState.valueOrNull != null &&
          playbackState.valueOrNull?.processingState !=
              AudioProcessingState.idle &&
          playbackState.valueOrNull?.processingState !=
              AudioProcessingState.completed &&
          !_isStopping) {
        await _updatePlaybackProgress();
      }
    });

    // Special processing for state transitions.
    _player.processingStateStream.listen((event) {
      if (event == ProcessingState.completed) {
        stop();
      }
    });

    // PlaybackEvent doesn't include shuffle/loops so we listen for changes here
    _player.shuffleModeEnabledStream.listen(
        (_) => playbackState.add(_transformEvent(_player.playbackEvent)));
    _player.loopModeStream.listen(
        (_) => playbackState.add(_transformEvent(_player.playbackEvent)));
  }

  @override
  Future<void> play() {
    // If a sleep timer has been set and the timer went off
    //  causing play to pause, if the user starts to play
    //  audio again, and the sleep timer hasn't been explicitly
    //  turned off, then reset the sleep timer.
    // This is useful if the sleep timer pauses play too early
    //  and the user wants to continue listening
    if (_sleepTimerIsSet && _sleepTimer == null) {
      // restart the sleep timer for another period
      setSleepTimer(_sleepTimerDuration);
    }

    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    try {
      if (kDebugMode) {
        print("Stopping audio service");
      }

      _isStopping = true;

      // Stop playing audio.
      await _player.stop();

      // Seek to the start of the first item in the queue
      await _player.seek(Duration.zero, index: 0);

      _sleepTimerIsSet = false;
      _sleepTimerDuration = Duration.zero;

      _sleepTimer?.cancel();
      _sleepTimer = null;

      await super.stop();

      _isStopping = false;
    } catch (e) {
      if (kDebugMode) {
        print("Error stopping audio service: $e");
      }
      return Future.error(e);
    }
  }

  @override
  @Deprecated("Use addQueueItems instead")
  Future<void> addQueueItem(MediaItem mediaItem) async {
    addQueueItems([mediaItem]);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    try {
      final sources =
          await Future.wait(mediaItems.map((i) => _mediaItemToAudioSource(i)));
      await _queueAudioSource.addAll(sources);
      queue.add(_queueFromSource());
    } catch (e) {
      if (kDebugMode) {
        print("Error adding queue items: $e");
      }
      return Future.error(e);
    }
  }

  Future<void> insertQueueItemsNext(List<MediaItem> mediaItems) async {
    try {
      var idx = _player.currentIndex;
      if (idx != null) {
        if (_player.shuffleModeEnabled) {
          var next = _player.shuffleIndices.indexOf(idx);
          idx = next == -1 ? null : next + 1;
        } else {
          ++idx;
        }
      }
      idx ??= 0;

      final sources =
          await Future.wait(mediaItems.map((i) => _mediaItemToAudioSource(i)));
      await _queueAudioSource.insertAll(idx, sources);
      queue.add(_queueFromSource());
    } catch (e) {
      if (kDebugMode) {
        print("Error inserting queue items: $e");
      }
      return Future.error(e);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    try {
      // Convert the MediaItems to AudioSources
      List<AudioSource> audioSources = [];
      for (final mediaItem in queue) {
        audioSources.add(await _mediaItemToAudioSource(mediaItem));
      }

      // Create a new ConcatenatingAudioSource with the new queue.
      _queueAudioSource = ConcatenatingAudioSource(
        children: audioSources,
        shuffleOrder: DoudouShuffleOrder(),
      );

      try {
        await _player.setAudioSource(
          _queueAudioSource,
          initialIndex: nextInitialIndex,
        );
      } on PlayerException catch (e) {
        if (kDebugMode) {
          print("Player error code ${e.code}: ${e.message}");
        }
      } on PlayerInterruptedException catch (e) {
        if (kDebugMode) {
          print("Player interrupted: ${e.message}");
        }
      } catch (e) {
        if (kDebugMode) {
          print("Player error ${e.toString()}");
        }
      }
      super.queue.add(_queueFromSource());

      // Sets the media item for the new queue. This will be whatever is
      // currently playing from the new queue (for example, the first song in
      // an album). If the player is shuffling, set the index to the player's
      // current index. Otherwise, set it to nextInitialIndex. nextInitialIndex
      // is much more stable than the current index as we know the value is set
      // when running this function.
      if (_player.shuffleModeEnabled) {
        if (_player.currentIndex == null) {
          if (kDebugMode) {
            print("_player.currentIndex is null during onUpdateQueue, not setting new media item");
          }
        } else {
          mediaItem.add(_getQueueItem(_player.currentIndex!));
        }
      } else {
        if (nextInitialIndex == null) {
          if (kDebugMode) {
            print("nextInitialIndex is null during onUpdateQueue, not setting new media item");
          }
        } else {
          mediaItem.add(_getQueueItem(nextInitialIndex!));
        }
      }

      shuffleNextQueue = false;
      nextInitialIndex = null;
    } catch (e) {
      if (kDebugMode) {
        print("Error updating queue: $e");
      }
      return Future.error(e);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (!_player.hasPrevious || _player.position.inSeconds >= 5) {
        await _player.seek(Duration.zero, index: _player.currentIndex);
      } else {
        await _player.seek(Duration.zero, index: _player.previousIndex);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error skipping to previous: $e");
      }
      return Future.error(e);
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      await _player.seekToNext();
    } catch (e) {
      if (kDebugMode) {
        print("Error skipping to next: $e");
      }
      return Future.error(e);
    }
  }

  Future<void> skipToIndex(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
    } catch (e) {
      if (kDebugMode) {
        print("Error skipping to index: $e");
      }
      return Future.error(e);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      if (kDebugMode) {
        print("Error seeking: $e");
      }
      return Future.error(e);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    try {
      switch (shuffleMode) {
        case AudioServiceShuffleMode.all:
          await _player.setShuffleModeEnabled(true);
          shuffleNextQueue = true;
          break;
        case AudioServiceShuffleMode.none:
          await _player.setShuffleModeEnabled(false);
          shuffleNextQueue = false;
          break;
        default:
          return Future.error(
              "Unsupported AudioServiceRepeatMode! Received ${shuffleMode.toString()}, requires all or none.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error setting shuffle mode: $e");
      }
      return Future.error(e);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    try {
      switch (repeatMode) {
        case AudioServiceRepeatMode.all:
          await _player.setLoopMode(LoopMode.all);
          break;
        case AudioServiceRepeatMode.none:
          await _player.setLoopMode(LoopMode.off);
          break;
        case AudioServiceRepeatMode.one:
          await _player.setLoopMode(LoopMode.one);
          break;
        default:
          return Future.error(
            "Unsupported AudioServiceRepeatMode! Received ${repeatMode.toString()}, requires all, none, or one.",
          );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error setting repeat mode: $e");
      }
      return Future.error(e);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    try {
      await _queueAudioSource.removeAt(index);
      queue.add(_queueFromSource());
    } catch (e) {
      if (kDebugMode) {
        print("Error removing queue item: $e");
      }
      return Future.error(e);
    }
  }

  /// Report track changes to the Jellyfin Server if the user is not offline.
  Future<void> onTrackChanged(
    MediaItem currentItem,
    PlaybackState currentState,
    MediaItem? previousItem,
    PlaybackState? previousState,
  ) async {
    if (kDebugMode) {
      print("Track changed to: ${currentItem.title}");
    }

    // We'll implement this later for Jellyfin integration
    // For now, just log the track change
  }

  void setNextInitialIndex(int index) {
    nextInitialIndex = index;
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    // When we're moving an item forwards, we need to reduce newIndex by 1
    // to account for the current item being removed before re-insertion.
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    await _queueAudioSource.move(oldIndex, newIndex);
    queue.add(_queueFromSource());
    if (kDebugMode) {
      print("Queue reordered");
    }
  }

  /// Sets the sleep timer with the given [duration].
  Timer setSleepTimer(Duration duration) {
    _sleepTimerIsSet = true;
    _sleepTimerDuration = duration;

    _sleepTimer = Timer(duration, () async {
      _sleepTimer = null;
      return await pause();
    });
    return _sleepTimer!;
  }

  /// Cancels the sleep timer and clears it.
  void clearSleepTimer() {
    _sleepTimerIsSet = false;
    _sleepTimerDuration = Duration.zero;

    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  /// Transform a just_audio event into an audio_service state.
  ///
  /// This method is used from the constructor. Every event received from the
  /// just_audio player will be transformed into an audio_service state so that
  /// it can be broadcast to audio_service clients.
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: _audioServiceRepeatMode(_player.loopMode),
    );
  }

  Future<void> _updatePlaybackProgress() async {
    try {
      // We'll implement progress reporting here later
      // For now, just skip it
    } catch (e) {
      if (kDebugMode) {
        print("Error updating playback progress: $e");
      }
      return Future.error(e);
    }
  }

  MediaItem _getQueueItem(int index) {
    return _queueAudioSource.sequence[index].tag as MediaItem;
  }

  List<MediaItem> _queueFromSource() {
    return _queueAudioSource.sequence.map((e) => e.tag as MediaItem).toList();
  }

  /// Syncs the list of MediaItems (_queue) with the internal queue of the player.
  /// Called by onAddQueueItem and onUpdateQueue.
  Future<AudioSource> _mediaItemToAudioSource(MediaItem mediaItem) async {
    // For now, we'll use a simple URL-based approach
    // Later we can add download support and transcoding
    
    final trackId = mediaItem.id;
    final streamUrl = _jellyfinService.getStreamUrl(trackId);
    
    if (streamUrl.isNotEmpty) {
      return AudioSource.uri(Uri.parse(streamUrl), tag: mediaItem);
    } else {
      return Future.error("Unable to get stream URL for track: ${mediaItem.title}");
    }
  }

  // Custom methods for app integration
  Future<void> playTrack(Track track) async {
    final mediaItem = _trackToMediaItem(track);
    await updateQueue([mediaItem]);
    await play();
  }

  Future<void> playPlaylist(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    
    final mediaItems = tracks.map(_trackToMediaItem).toList();
    setNextInitialIndex(startIndex);
    await updateQueue(mediaItems);
    await play();
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

  // Queue management methods
  void addToQueue(Track track) async {
    await addQueueItems([_trackToMediaItem(track)]);
  }

  void addNext(Track track) async {
    await insertQueueItemsNext([_trackToMediaItem(track)]);
  }

  void removeFromQueue(int index) async {
    await removeQueueItemAt(index);
  }

  void clearQueue() async {
    await updateQueue([]);
    await stop();
  }

  void shuffle() async {
    await setShuffleMode(AudioServiceShuffleMode.all);
  }

  void unshuffle() async {
    await setShuffleMode(AudioServiceShuffleMode.none);
  }

  // Radio Mode functionality (not implemented yet)
  void toggleRadioMode() {
    // TODO: Implement radio mode
  }

  void enableRadioMode() {
    // TODO: Implement radio mode
  }

  void disableRadioMode() {
    // TODO: Implement radio mode
  }

  // Getters
  List<Track> get playlist => queue.valueOrNull?.map((item) => _mediaItemToTrack(item)).toList() ?? [];
  List<Track> get queueTracks => playlist; // Same as playlist for now
  List<Track> get upNext => currentIndex < playlist.length - 1 ? playlist.sublist(currentIndex + 1) : [];
  Track? get currentTrack => mediaItem.valueOrNull != null ? _mediaItemToTrack(mediaItem.valueOrNull!) : null;
  int get currentIndex => playbackState.valueOrNull?.queueIndex ?? 0;
  bool get isPlaying => _player.playing;
  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;
  bool get isShuffled => _player.shuffleModeEnabled;
  bool get radioModeEnabled => false; // Not implemented yet
  
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  PlayerState get playerState => _player.playerState;

  Track _mediaItemToTrack(MediaItem mediaItem) {
    return Track(
      id: mediaItem.id,
      name: mediaItem.title,
      artistName: mediaItem.artist,
      albumName: mediaItem.album,
      duration: mediaItem.duration?.inMilliseconds,
      imageUrl: mediaItem.artUri?.toString(),
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    if (kDebugMode) {
      print('App task removed, stopping playback');
    }
    await stop();
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    await _player.dispose();
  }
}

AudioServiceRepeatMode _audioServiceRepeatMode(LoopMode loopMode) {
  switch (loopMode) {
    case LoopMode.off:
      return AudioServiceRepeatMode.none;
    case LoopMode.one:
      return AudioServiceRepeatMode.one;
    case LoopMode.all:
      return AudioServiceRepeatMode.all;
  }
}
