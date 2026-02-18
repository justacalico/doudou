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
  /// - Windows: audio-exclusive=no (WASAPI shared mode for system volume)
  /// - Linux: cache=no (avoids lavf "Failed to create file cache" on stream playback, e.g. after server switch)
  static Future<void> createMpvConfig() async {
    try {
      String configDir;
      String optionsToAdd = '';

      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData == null) {
          debugPrint('PlatformAudioConfig: APPDATA not found');
          return;
        }
        configDir = '$appData/mpv';
        optionsToAdd = '# Doudou: WASAPI shared mode for system volume integration\naudio-exclusive=no\n';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home == null) {
          debugPrint('PlatformAudioConfig: HOME not found');
          return;
        }
        configDir = '$home/.config/mpv';
        optionsToAdd =
            '# Doudou: Disable demuxer cache to avoid lavf "Failed to create file cache" (streams, server switch)\ncache=no\n';
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home == null) {
          debugPrint('PlatformAudioConfig: HOME not found');
          return;
        }
        configDir = '$home/.config/mpv';
        // macOS: no extra options by default
        return;
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
        // Skip if we already added our options
        if (existingContent.contains('audio-exclusive') ||
            (Platform.isLinux && existingContent.contains('cache=no'))) {
          debugPrint('PlatformAudioConfig: Options already in mpv.conf');
          return;
        }
      }

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
