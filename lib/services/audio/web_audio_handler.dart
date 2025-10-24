import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'app_audio_handler_interface.dart';

/// Web-compatible audio handler using just_audio
/// This handler provides basic audio playback functionality for web platforms
class WebAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler implements AppAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  
  WebAudioHandler() {
    _init();
  }

  @override
  BaseAudioHandler get handler => this;

  Future<void> _init() async {
    // Listen to player state changes
    _player.playbackEventStream.listen(_broadcastState);
    
    // Listen to sequence state changes for queue updates
    _player.sequenceStateStream.listen(_updateQueue);
    
    // Set initial state
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
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
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error playing: $e');
      }
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error pausing: $e');
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error stopping: $e');
      }
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error seeking: $e');
      }
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      await _player.seekToNext();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error skipping to next: $e');
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      await _player.seekToPrevious();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error skipping to previous: $e');
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error skipping to queue item: $e');
      }
    }
  }

  /// Play a track from URL
  Future<void> playFromUrl(String url, {MediaItem? mediaItem}) async {
    try {
      // Update media item if provided
      if (mediaItem != null) {
        this.mediaItem.add(mediaItem);
      }

      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error playing from URL: $e');
      }
      // Set error state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  /// Set playlist from URLs
  Future<void> setPlaylist(List<String> urls, {List<MediaItem>? mediaItems, int? initialIndex}) async {
    try {
      final audioSources = urls.map((url) => AudioSource.uri(Uri.parse(url))).toList();
      final playlist = ConcatenatingAudioSource(children: audioSources);
      
      await _player.setAudioSource(playlist, initialIndex: initialIndex ?? 0);
      
      // Update queue if media items provided
      if (mediaItems != null) {
        queue.add(mediaItems);
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebAudioHandler: Error setting playlist: $e');
      }
      // Set error state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _getProcessingState(),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  void _updateQueue(SequenceState? sequenceState) {
    final sequence = sequenceState?.effectiveSequence;
    if (sequence != null) {
      // Update queue index
      final queueIndex = sequenceState?.currentIndex;
      playbackState.add(playbackState.value.copyWith(
        queueIndex: queueIndex,
      ));
    }
  }

  AudioProcessingState _getProcessingState() {
    if (_player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.buffering) {
      return AudioProcessingState.loading;
    } else if (_player.processingState == ProcessingState.completed) {
      return AudioProcessingState.completed;
    } else {
      return AudioProcessingState.ready;
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'setVolume':
        final volume = extras?['volume'] as double?;
        if (volume != null) {
          await _player.setVolume(volume);
        }
        break;
      case 'setSpeed':
        final speed = extras?['speed'] as double?;
        if (speed != null) {
          await _player.setSpeed(speed);
        }
        break;
      default:
        if (kDebugMode) {
          print('WebAudioHandler: Unknown custom action: $name');
        }
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await _player.dispose();
  }

  /// Web-specific configuration methods
  void setNormalizeVolume(bool enabled) {
    // Web implementation - could use Web Audio API for volume normalization
    if (kDebugMode) {
      print('WebAudioHandler: Volume normalization ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  void setGaplessPlayback(bool enabled) {
    // Web implementation - just_audio handles gapless playback
    if (kDebugMode) {
      print('WebAudioHandler: Gapless playback ${enabled ? 'enabled' : 'disabled'}');
    }
  }
}