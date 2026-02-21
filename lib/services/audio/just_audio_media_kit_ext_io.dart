import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

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

      // Windows: disable WASAPI exclusive mode for system volume integration.
      // Linux does not use mpv (uses audioplayers/GStreamer), so no Linux mpv config.
      if (Platform.isWindows &&
          !existingContent.contains('audio-exclusive')) {
        linesToAppend.add(
            '# Doudou: Disable WASAPI exclusive mode for system volume integration');
        linesToAppend.add('audio-exclusive=no');
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
