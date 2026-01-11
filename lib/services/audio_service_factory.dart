import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:audio_service/audio_service.dart' as audio_service;
import 'media_service_manager.dart';
import 'audio/unified_audio_handler.dart';

/// Simple audio service factory that creates the unified audio handler
/// for all platforms (mobile, desktop, and web)
/// 
/// Platform-specific media control integration:
/// - Android/iOS: AudioService with notifications
/// - macOS: AudioService with Control Center integration
/// - Linux: AudioService with MPRIS (via audio_service_mpris plugin)
/// - Windows: AudioService with SMTC (via audio_service_win plugin)
/// - Web: Direct handler (no system controls)
class AudioServiceFactory {
  static AudioServiceFactory? _instance;
  static AudioServiceFactory get instance =>
      _instance ??= AudioServiceFactory._();
  AudioServiceFactory._();

  UnifiedAudioHandler? _audioHandler;
  bool _initialized = false;

  /// Get the current audio handler
  UnifiedAudioHandler get audioHandler {
    if (!_initialized || _audioHandler == null) {
      throw StateError(
        'AudioServiceFactory not initialized. Call initialize() first.',
      );
    }
    return _audioHandler!;
  }

  /// Initialize the unified audio handler for all platforms
  Future<void> initialize(MediaServiceManager mediaServiceManager) async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        // Web platform - create handler directly (no AudioService)
        _audioHandler = UnifiedAudioHandler(mediaServiceManager);
      } else if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // Mobile platforms - use AudioService with UnifiedAudioHandler
        _audioHandler = await audio_service.AudioService.init(
          builder: () => UnifiedAudioHandler(mediaServiceManager),
          config: audio_service.AudioServiceConfig(
            androidNotificationChannelId: 'com.doudoubox.audio',
            androidNotificationChannelName: 'Doudou Audio',
            androidNotificationChannelDescription: 'Playing audio',
            androidShowNotificationBadge: true,
            androidNotificationClickStartsActivity: true,
            androidStopForegroundOnPause:
                false, // CRITICAL - don't stop foreground on pause
            androidNotificationIcon: 'mipmap/launcher_icon', // Use app icon
            preloadArtwork: true,
            fastForwardInterval: const Duration(seconds: 10),
            rewindInterval: const Duration(seconds: 10),
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.macOS ||
                 defaultTargetPlatform == TargetPlatform.linux ||
                 defaultTargetPlatform == TargetPlatform.windows) {
        // Desktop platforms - use AudioService for system media controls
        // macOS: Native Control Center integration
        // Linux: MPRIS integration via audio_service_mpris plugin
        // Windows: SMTC integration via audio_service_win plugin
        _audioHandler = await audio_service.AudioService.init(
          builder: () => UnifiedAudioHandler(mediaServiceManager),
          config: audio_service.AudioServiceConfig(
            androidNotificationChannelId: 'com.doudoubox.audio',
            androidNotificationChannelName: 'Doudou Audio',
            androidNotificationChannelDescription: 'Playing audio',
            preloadArtwork: true,
            fastForwardInterval: const Duration(seconds: 10),
            rewindInterval: const Duration(seconds: 10),
          ),
        );
      } else {
        // Unknown platform - create handler directly
        _audioHandler = UnifiedAudioHandler(mediaServiceManager);
      }

      _initialized = true;
    } catch (e) {
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
      await _audioHandler!.dispose();
    }
    _audioHandler = null;
    _initialized = false;
    _instance = null;
  }
}
