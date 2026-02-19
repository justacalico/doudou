import 'package:flutter/foundation.dart';

/// Stub implementation for web platform
/// This file is used when building for web to avoid Platform API issues
class PlatformAudioConfig {
  PlatformAudioConfig._();
  
  /// Always false on web
  static bool get isWindows => false;

  /// No-op for web platform
  static Future<void> createMpvConfig({bool forYouTubeMusic = false}) async {
    debugPrint('PlatformAudioConfig: Stub - no mpv config on web');
  }
  
  /// Clean up MPV config by removing Doudou-added options and restoring original content
  /// This should be called when the app closes to avoid leaving temporary config changes
  static Future<void> cleanupMpvConfig() async {
    // No-op on web/stub
  }
}

/// Stub mixin for web platform
mixin WindowsAudioConfigMixin {
  /// No-op for web platform
  Future<void> configureWindowsAudio(dynamic player) async {
    // Web platform doesn't support Windows audio configuration
  }
}
