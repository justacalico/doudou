import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

/// Platform-specific implementation for desktop/mobile
/// This file contains Windows and Linux mpv configuration
class PlatformAudioConfig {
  PlatformAudioConfig._();

  /// Check if we're on Windows
  static bool get isWindows => Platform.isWindows;

  /// Check if we're on Linux
  static bool get isLinux => Platform.isLinux;

  /// Create mpv.conf with platform-specific options (WASAPI on Windows, ao+cache on Linux)
  static Future<void> createMpvConfig() async {
    try {
      String configDir;

      if (Platform.isWindows) {
        // On Windows, mpv reads from %APPDATA%/mpv/
        final appData = Platform.environment['APPDATA'];
        if (appData == null) {
          debugPrint('PlatformAudioConfig: APPDATA not found');
          return;
        }
        configDir = '$appData/mpv';
      } else {
        // On Linux/macOS, mpv reads from ~/.config/mpv/
        final home = Platform.environment['HOME'];
        if (home == null) {
          debugPrint('PlatformAudioConfig: HOME not found');
          return;
        }
        configDir = '$home/.config/mpv';
      }

      final dir = Directory(configDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final configFile = File('$configDir/mpv.conf');

      // Read existing config if present
      String existingContent = '';
      if (await configFile.exists()) {
        existingContent = await configFile.readAsString();
      }

      final List<String> linesToAppend = [];

      // Windows: disable WASAPI exclusive mode for system volume integration
      if (Platform.isWindows &&
          !existingContent.contains('audio-exclusive')) {
        linesToAppend.add(
            '# Doudou: Disable WASAPI exclusive mode for system volume integration');
        linesToAppend.add('audio-exclusive=no');
      }

      // Linux: explicit audio driver and cache dir to fix "ao not found" and lavf cache errors
      if (Platform.isLinux) {
        if (!existingContent.contains('ao=')) {
          linesToAppend.add('# Doudou: Explicit audio driver (fixes "Audio output auto not found")');
          linesToAppend.add('ao=pulse,pipewire,alsa');
        }
        if (!existingContent.contains('cache-dir=')) {
          final cacheDir = await getTemporaryDirectory();
          final mpvCacheDir = Directory('${cacheDir.path}/mpv');
          if (!await mpvCacheDir.exists()) {
            await mpvCacheDir.create(recursive: true);
          }
          linesToAppend.add('# Doudou: Writable cache dir (fixes "Failed to create file cache")');
          linesToAppend.add('cache-dir=${mpvCacheDir.path}');
        }
      }

      if (linesToAppend.isEmpty) {
        if (Platform.isWindows && existingContent.contains('audio-exclusive')) {
          debugPrint('PlatformAudioConfig: audio-exclusive already in mpv.conf');
        }
        return;
      }

      final newContent = existingContent.isEmpty
          ? '${linesToAppend.join('\n')}\n'
          : '$existingContent\n${linesToAppend.join('\n')}\n';

      await configFile.writeAsString(newContent);
      debugPrint('PlatformAudioConfig: Updated mpv.conf at $configDir');
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
