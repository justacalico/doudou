import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';
import 'audio_service_factory.dart';
import 'media_service_manager.dart';
import 'audio/web_audio_handler.dart';
import 'audio/mobile_audio_handler.dart';
import 'audio/desktop_audio_handler.dart';
import 'audio/base_audio_handler.dart';
import '../models/jellyfin_models.dart';

/// Simple wrapper to integrate new audio system with existing AppState
/// This provides a backwards-compatible interface while using the new architecture
class AudioServiceIntegration {
  static AudioServiceIntegration? _instance;
  static AudioServiceIntegration get instance => _instance ??= AudioServiceIntegration._();
  AudioServiceIntegration._();

  dynamic _audioHandler;
  bool _initialized = false;

  /// Initialize the audio service
  Future<void> initialize(MediaServiceManager mediaServiceManager) async {
    if (_initialized) return;

    try {
      final factory = AudioServiceFactory.instance;
      await factory.initialize(mediaServiceManager);
      _audioHandler = factory.audioHandler;
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Failed to initialize: $e');
      }
      rethrow;
    }
  }

  /// Get the current audio handler
  dynamic get audioHandler {
    if (!_initialized) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Not initialized, returning null');
      }
      return null;
    }
    return _audioHandler;
  }

  /// Check if initialized
  bool get isInitialized => _initialized;

  /// Get platform type
  String get platformType {
    if (!_initialized) return 'unknown';
    return AudioServiceFactory.instance.platformType;
  }

  /// Helper methods for common operations

  /// Play a track
  Future<void> playTrack(Track track) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        await (_audioHandler as WebAudioHandler).playTrack(track);
      } else if (_audioHandler is DesktopAudioHandler) {
        await (_audioHandler as DesktopAudioHandler).playTrack(track);
      } else if (_audioHandler is DoudouAudioHandler) {
        await (_audioHandler as DoudouAudioHandler).playTrack(track);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error playing track: $e');
      }
    }
  }

  /// Play a playlist
  Future<void> playPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    if (!_initialized || _audioHandler == null || tracks.isEmpty) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        // For web, use playPlaylist method
        await (_audioHandler as WebAudioHandler).playPlaylist(tracks, startIndex);
      } else if (_audioHandler is DesktopAudioHandler) {
        // For desktop, use playPlaylist method
        await (_audioHandler as DesktopAudioHandler).playPlaylist(tracks, startIndex);
      } else if (_audioHandler is DoudouAudioHandler) {
        // For mobile, use playPlaylist method
        await (_audioHandler as DoudouAudioHandler).playPlaylist(tracks, startIndex);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error playing playlist: $e');
      }
    }
  }

  /// Play/pause toggle
  Future<void> playPause() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        final handler = _audioHandler as WebAudioHandler;
        if (handler.currentState == AudioPlayerState.playing) {
          await handler.pause();
        } else {
          await handler.play();
        }
      } else if (_audioHandler is DesktopAudioHandler) {
        final handler = _audioHandler as DesktopAudioHandler;
        if (handler.currentState == AudioPlayerState.playing) {
          await handler.pause();
        } else {
          await handler.play();
        }
      } else if (_audioHandler is DoudouAudioHandler) {
        // For mobile, use AudioService play/pause
        await (_audioHandler as DoudouAudioHandler).play();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error toggling play/pause: $e');
      }
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        await (_audioHandler as WebAudioHandler).skipToNext();
      } else if (_audioHandler is DesktopAudioHandler) {
        await (_audioHandler as DesktopAudioHandler).skipToNext();
      } else if (_audioHandler is DoudouAudioHandler) {
        await (_audioHandler as DoudouAudioHandler).skipToNext();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error skipping to next: $e');
      }
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        await (_audioHandler as WebAudioHandler).skipToPrevious();
      } else if (_audioHandler is DesktopAudioHandler) {
        await (_audioHandler as DesktopAudioHandler).skipToPrevious();
      } else if (_audioHandler is DoudouAudioHandler) {
        await (_audioHandler as DoudouAudioHandler).skipToPrevious();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error skipping to previous: $e');
      }
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        await (_audioHandler as WebAudioHandler).setVolume(volume);
      } else if (_audioHandler is DesktopAudioHandler) {
        await (_audioHandler as DesktopAudioHandler).setVolume(volume);
      } else if (_audioHandler is DoudouAudioHandler) {
        await (_audioHandler as DoudouAudioHandler).setVolume(volume);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting volume: $e');
      }
    }
  }

  /// Stream getters for backwards compatibility with AppState
  
  Stream<PlayerState>? get playerStateStream {
    if (!_initialized || _audioHandler == null) return null;
    
    if (_audioHandler is WebAudioHandler) {
      return (_audioHandler as WebAudioHandler).playerStateStream;
    } else if (_audioHandler is DesktopAudioHandler) {
      return (_audioHandler as DesktopAudioHandler).playerStateStream;
    } else if (_audioHandler is DoudouAudioHandler) {
      return (_audioHandler as DoudouAudioHandler).playerStateStream;
    }
    return null;
  }

  Stream<audio_service.PlaybackState>? get playbackState {
    if (!_initialized || _audioHandler == null) return null;
    
    if (_audioHandler is DoudouAudioHandler) {
      return (_audioHandler as DoudouAudioHandler).playbackState.stream;
    }
    // For web/desktop, we need to create a compatible stream
    return null;
  }

  Stream<Duration>? get positionStream {
    if (!_initialized || _audioHandler == null) return null;
    
    if (_audioHandler is WebAudioHandler) {
      return (_audioHandler as WebAudioHandler).positionStream;
    } else if (_audioHandler is DesktopAudioHandler) {
      return (_audioHandler as DesktopAudioHandler).positionStream;
    } else if (_audioHandler is DoudouAudioHandler) {
      return (_audioHandler as DoudouAudioHandler).positionStream;
    }
    return null;
  }

  Stream<audio_service.MediaItem?>? get mediaItem {
    if (!_initialized || _audioHandler == null) return null;
    
    if (_audioHandler is DoudouAudioHandler) {
      return (_audioHandler as DoudouAudioHandler).mediaItem.stream;
    }
    // For web/desktop, return a compatible stream
    return null;
  }

  /// Additional methods that AppState expects

  Future<void> setGaplessPlayback(bool enabled) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        // Web doesn't need special gapless handling
      } else if (_audioHandler is DesktopAudioHandler) {
        // Desktop can implement if needed
      } else if (_audioHandler is DoudouAudioHandler) {
        // Mobile may have gapless options
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting gapless playback: $e');
      }
    }
  }

  Future<void> seek(Duration position) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        await (_audioHandler as WebAudioHandler).seek(position);
      } else if (_audioHandler is DesktopAudioHandler) {
        await (_audioHandler as DesktopAudioHandler).seek(position);
      } else if (_audioHandler is DoudouAudioHandler) {
        await (_audioHandler as DoudouAudioHandler).seek(position);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error seeking: $e');
      }
    }
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        (_audioHandler as WebAudioHandler).setRepeatMode(mode);
      } else if (_audioHandler is DesktopAudioHandler) {
        (_audioHandler as DesktopAudioHandler).setRepeatMode(mode);
      } else if (_audioHandler is DoudouAudioHandler) {
        // Convert RepeatMode to AudioServiceRepeatMode
        audio_service.AudioServiceRepeatMode audioServiceMode;
        switch (mode) {
          case RepeatMode.none:
            audioServiceMode = audio_service.AudioServiceRepeatMode.none;
            break;
          case RepeatMode.one:
            audioServiceMode = audio_service.AudioServiceRepeatMode.one;
            break;
          case RepeatMode.all:
            audioServiceMode = audio_service.AudioServiceRepeatMode.all;
            break;
        }
        await (_audioHandler as DoudouAudioHandler).setRepeatMode(audioServiceMode);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting repeat mode: $e');
      }
    }
  }

  Future<void> setShuffleMode(bool enabled) async {
    if (!_initialized || _audioHandler == null) return;

    try {
      if (_audioHandler is WebAudioHandler) {
        // Web handler doesn't have shuffle mode method yet - implement if needed
      } else if (_audioHandler is DesktopAudioHandler) {
        // Desktop handler doesn't have shuffle mode method yet - implement if needed
      } else if (_audioHandler is DoudouAudioHandler) {
        // Convert bool to AudioServiceShuffleMode
        final shuffleMode = enabled 
          ? audio_service.AudioServiceShuffleMode.all 
          : audio_service.AudioServiceShuffleMode.none;
        await (_audioHandler as DoudouAudioHandler).setShuffleMode(shuffleMode);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceIntegration: Error setting shuffle mode: $e');
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_audioHandler != null) {
      await AudioServiceFactory.instance.dispose();
    }
    _audioHandler = null;
    _initialized = false;
    _instance = null;
  }
}