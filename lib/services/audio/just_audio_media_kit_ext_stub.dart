import 'package:flutter/foundation.dart';

/// Stub implementation for web platform
/// This file is used when building for web to avoid Platform API issues
class PlatformAudioConfig {
  PlatformAudioConfig._();
  
  /// Always false on web
  static bool get isWindows => false;
  
  /// No-op for web platform
  static Future<void> createMpvConfig() async {
    debugPrint('PlatformAudioConfig: Stub - no mpv config on web');
  }
}

/// Stub mixin for web platform
mixin WindowsAudioConfigMixin {
  /// No-op for web platform
  Future<void> configureWindowsAudio(dynamic player) async {
    // Web platform doesn't support Windows audio configuration
  }
}
