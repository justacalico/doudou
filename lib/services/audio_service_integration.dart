import 'package:flutter/foundation.dart';
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
        // For web, set queue and play
        await (_audioHandler as WebAudioHandler).queue(tracks);
        if (startIndex < tracks.length) {
          await (_audioHandler as WebAudioHandler).playTrack(tracks[startIndex]);
        }
      } else if (_audioHandler is DesktopAudioHandler) {
        // For desktop, set queue and play
        await (_audioHandler as DesktopAudioHandler).setQueue(tracks, initialIndex: startIndex);
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