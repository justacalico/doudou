/// Audio Service Factory - Creates and manages the AudioManager
/// 
/// This factory provides a simple API to initialize and access 
/// the global audio system.
library;

import 'package:flutter/foundation.dart';
import 'media_service_manager.dart';
import 'audio/global/global_audio.dart';

/// Simple audio service factory that creates the appropriate audio handler
/// based on the current platform
class AudioServiceFactory {
  static AudioServiceFactory? _instance;
  static AudioServiceFactory get instance => _instance ??= AudioServiceFactory._();
  AudioServiceFactory._();

  AudioManagerIntegration? _audioHandler;
  bool _initialized = false;

  /// Get the current audio handler
  AudioManagerIntegration get audioHandler {
    if (!_initialized || _audioHandler == null) {
      throw StateError('AudioServiceFactory not initialized. Call initialize() first.');
    }
    return _audioHandler!;
  }

  /// Initialize the appropriate audio handler for the current platform
  Future<void> initialize(MediaServiceManager mediaServiceManager) async {
    if (_initialized) return;

    try {
      if (kDebugMode) {
        print('AudioServiceFactory: Initializing for platform ${defaultTargetPlatform.name}...');
      }

      // Create the AudioManagerIntegration which handles all platforms
      _audioHandler = AudioManagerIntegration(
        mediaServiceManager: mediaServiceManager,
      );
      
      // Initialize the audio manager
      final success = await _audioHandler!.initialize();
      
      if (!success) {
        throw Exception('Failed to initialize AudioManager');
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
      await _audioHandler!.dispose();
    }
    _audioHandler = null;
    _initialized = false;
    _instance = null;
  }
}