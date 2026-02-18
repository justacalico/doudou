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
            '# Doudou: WASAPI shared mode for system volume\naudio-exclusive=no\n'
            '# Doudou: User-Agent for googlevideo.com (YouTube Music)\n'
            'user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home == null) return;
        configDir = '$home/.config/mpv';
        optionsToAdd =
            '# Doudou: avoid lavf "Failed to create file cache" (blocks playback)\ncache=no\n'
            '# Doudou: User-Agent for googlevideo.com (YouTube Music)\n'
            'user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n';
      } else {
        return;
      }

      final dir = Directory(configDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final configFile = File('$configDir/mpv.conf');
      String existingContent = '';
      if (await configFile.exists()) {
        existingContent = await configFile.readAsString();
        final hasRequired = Platform.isWindows
            ? (existingContent.contains('audio-exclusive') &&
                existingContent.contains('user-agent'))
            : (existingContent.contains('cache=no') &&
                existingContent.contains('user-agent'));
        if (hasRequired) {
          return;
        }
        // Add user-agent if missing (older configs may not have it)
        if (!existingContent.contains('user-agent')) {
          const uaLinux =
              '# Doudou: User-Agent for googlevideo.com (YouTube Music)\n'
              'user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n';
          const uaWindows =
              '# Doudou: User-Agent for googlevideo.com (YouTube Music)\n'
              'user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n';
          final ua = Platform.isLinux ? uaLinux : uaWindows;
          await configFile.writeAsString('$existingContent\n$ua');
          debugPrint('PlatformAudioConfig: added user-agent to mpv.conf');
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
