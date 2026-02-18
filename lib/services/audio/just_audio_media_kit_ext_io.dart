import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Platform-specific implementation for desktop/mobile
/// This file contains Windows audio configuration that uses Platform APIs
class PlatformAudioConfig {
  PlatformAudioConfig._();
  
  /// Check if we're on Windows
  static bool get isWindows => Platform.isWindows;
  
  /// Create mpv.conf with platform-specific options:
  /// - Windows: audio-exclusive=no (WASAPI shared mode)
  /// - Linux: cache=no (avoids lavf "Failed to create file cache" which blocks playback)
  static Future<void> createMpvConfig() async {
    try {
      String configDir;
      String optionsToAdd;

      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData == null) return;
        configDir = '$appData/mpv';
        optionsToAdd =
            '# Doudou: WASAPI shared mode for system volume\naudio-exclusive=no\n';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home == null) return;
        configDir = '$home/.config/mpv';
        optionsToAdd =
            '# Doudou: avoid lavf "Failed to create file cache" (blocks playback)\ncache=no\n';
      } else {
        return;
      }

      final dir = Directory(configDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final configFile = File('$configDir/mpv.conf');
      String existingContent = '';
      if (await configFile.exists()) {
        existingContent = await configFile.readAsString();
        if ((Platform.isWindows && existingContent.contains('audio-exclusive')) ||
            (Platform.isLinux && existingContent.contains('cache=no'))) {
          return;
        }
      }

      final newContent =
          existingContent.isEmpty ? optionsToAdd : '$existingContent\n$optionsToAdd';
      await configFile.writeAsString(newContent);
      debugPrint('PlatformAudioConfig: mpv.conf at $configDir');
    } catch (e) {
      debugPrint('PlatformAudioConfig: $e');
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
