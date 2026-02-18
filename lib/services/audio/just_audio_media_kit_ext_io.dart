import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Platform-specific implementation for desktop/mobile
/// This file contains Windows audio configuration that uses Platform APIs
class PlatformAudioConfig {
  PlatformAudioConfig._();
  
  /// Check if we're on Windows
  static bool get isWindows => Platform.isWindows;
  
  /// Create mpv.conf file with audio-exclusive=no (Windows)
  static Future<void> createMpvConfig() async {
    try {
      String configDir;

      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData == null) {
          debugPrint('PlatformAudioConfig: APPDATA not found');
          return;
        }
        configDir = '$appData/mpv';
      } else {
        return;
      }

      final dir = Directory(configDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final configFile = File('$configDir/mpv.conf');

      String existingContent = '';
      if (await configFile.exists()) {
        existingContent = await configFile.readAsString();
        if (existingContent.contains('audio-exclusive')) {
          debugPrint('PlatformAudioConfig: audio-exclusive already in mpv.conf');
          return;
        }
      }

      const optionsToAdd =
          '# Doudou: WASAPI shared mode for system volume integration\naudio-exclusive=no\n';
      final newContent =
          existingContent.isEmpty ? optionsToAdd : '$existingContent\n$optionsToAdd';

      await configFile.writeAsString(newContent);
      debugPrint('PlatformAudioConfig: Created mpv.conf at $configDir');
    } catch (e) {
      debugPrint('PlatformAudioConfig: Error creating mpv config: $e');
    }
  }
}

/// Mixin to add Windows audio configuration to audio handlers
mixin WindowsAudioConfigMixin {
  /// Configure a media_kit Player to disable WASAPI exclusive mode
  Future<void> configureWindowsAudio(Player player) async {
    if (!Platform.isWindows) return;
    
    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('audio-exclusive', 'no');
        debugPrint('WindowsAudioConfigMixin: Disabled WASAPI exclusive mode');
      }
    } catch (e) {
      debugPrint('WindowsAudioConfigMixin: Failed to configure: $e');
    }
  }
}
