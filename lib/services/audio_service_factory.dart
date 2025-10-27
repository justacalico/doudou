import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'media_service_manager.dart';
import 'audio/mobile_audio_handler.dart';
import 'audio/desktop_audio_handler.dart';
import 'audio/web_audio_handler.dart';

/// Simple audio service factory that creates the appropriate audio handler
/// based on the current platform
class AudioServiceFactory {
  static AudioServiceFactory? _instance;
  static AudioServiceFactory get instance => _instance ??= AudioServiceFactory._();
  AudioServiceFactory._();

  dynamic _audioHandler;
  bool _initialized = false;

  /// Get the current audio handler
  dynamic get audioHandler {
    if (!_initialized) {
      throw StateError('AudioServiceFactory not initialized. Call initialize() first.');
    }
    return _audioHandler;
  }

  /// Initialize the appropriate audio handler for the current platform
  Future<void> initialize(MediaServiceManager mediaServiceManager) async {
    if (_initialized) return;

    try {
      if (kDebugMode) {
        print('AudioServiceFactory: Initializing for platform ${defaultTargetPlatform.name}...');
      }

      if (kIsWeb) {
        // Web platform - use WebAudioHandler directly
        _audioHandler = WebAudioHandler(mediaServiceManager);
        if (kDebugMode) {
          print('AudioServiceFactory: Created WebAudioHandler');
        }
      } else if (defaultTargetPlatform == TargetPlatform.android || 
                 defaultTargetPlatform == TargetPlatform.iOS) {
        // Mobile platforms - use AudioService with DoudouAudioHandler
        _audioHandler = await audio_service.AudioService.init(
          builder: () => DoudouAudioHandler(
            mediaServiceManager: mediaServiceManager,
          ),
          config: audio_service.AudioServiceConfig(
            androidNotificationChannelId: 'com.doudoubox.audio',
            androidNotificationChannelName: 'Doudou Audio',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        );
        if (kDebugMode) {
          print('AudioServiceFactory: Created DoudouAudioHandler with AudioService');
        }
      } else {
        // Desktop platforms - use DesktopAudioHandler directly
        _audioHandler = DesktopAudioHandler(mediaServiceManager);
        if (kDebugMode) {
          print('AudioServiceFactory: Created DesktopAudioHandler');
        }
      }

      _initialized = true;
      
      if (kDebugMode) {
        print('AudioServiceFactory: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioServiceFactory: Failed to initialize: $e');
      }
      rethrow;
    }
  }

  /// Check if the factory is initialized
  bool get isInitialized => _initialized;

  /// Get the platform type for conditional handling
  String get platformType {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    return 'unknown';
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_audioHandler != null) {
      if (_audioHandler is WebAudioHandler) {
        await (_audioHandler as WebAudioHandler).dispose();
      } else if (_audioHandler is DesktopAudioHandler) {
        await (_audioHandler as DesktopAudioHandler).dispose();
      } else if (_audioHandler is DoudouAudioHandler) {
        await (_audioHandler as DoudouAudioHandler).dispose();
      }
    }
    _audioHandler = null;
    _initialized = false;
    _instance = null;
  }
}