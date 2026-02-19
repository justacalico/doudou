import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Platform-specific implementation for desktop/mobile
/// This file contains Windows audio configuration that uses Platform APIs
class PlatformAudioConfig {
  PlatformAudioConfig._();
  
  /// Check if we're on Windows
  static bool get isWindows => Platform.isWindows;
  
  /// Path to the MPV config file
  static String? _configFilePath;
  
  /// Original content of the MPV config file before Doudou modifications
  static String? _originalConfigContent;
  
  /// Create mpv.conf with platform-specific options:
  /// - Windows: audio-exclusive=no (WASAPI shared mode)
  /// - Linux: Only for YouTube Music (user-agent, referrer, cache=no)
  /// 
  /// [forYouTubeMusic] - If true (Linux only), creates config with YouTube-specific options
  static Future<void> createMpvConfig({bool forYouTubeMusic = false}) async {
    try {
      String configDir;
      String optionsToAdd;

      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData == null) return;
        configDir = '$appData/mpv';
        optionsToAdd =
            '# Doudou: WASAPI shared mode for system volume\naudio-exclusive=no\n'
            '# Doudou: User-Agent and Referrer for googlevideo.com (YouTube Music)\n'
            'user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n'
            'referrer="https://www.youtube.com/"\n';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home == null) return;
        configDir = '$home/.config/mpv';
        if (forYouTubeMusic) {
          optionsToAdd =
              '# Doudou: User-Agent and Referrer for googlevideo.com (YouTube Music)\n'
              'user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n'
              'referrer="https://www.youtube.com/"\n'
              '# Doudou: avoid lavf "Failed to create file cache" (blocks playback on server switch)\ncache=no\n';
        } else {
          // Minimal config for non-YouTube (Navidrome, etc.): ensure cache=no and audio output
          // so new MPV instances get consistent options and audio actually plays.
          // Use ao=auto so MPV auto-detects the best available driver (pulse, alsa, pipewire, etc.);
          // ao=pulse can leave no sound on some Linux setups (e.g. PipeWire-only or ALSA-only).
          optionsToAdd =
              '# Doudou: minimal options for non-YouTube playback (Navidrome, etc.)\n'
              'cache=no\n'
              '# Doudou: auto-detect audio output so audio actually plays\nao=auto\n';
        }
      } else {
        return;
      }

      final dir = Directory(configDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final configFile = File('$configDir/mpv.conf');
      _configFilePath = configFile.path;
      
      String existingContent = '';
      if (await configFile.exists()) {
        existingContent = await configFile.readAsString();
        // #region agent log
        try {
          final logFile = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-374c17.log');
          await logFile.writeAsString('{"sessionId":"374c17","location":"just_audio_media_kit_ext_io.dart:69","message":"Reading existing mpv.conf","data":{"exists":true,"contentLength":existingContent.length,"hasAo":existingContent.contains("ao="),"hasCacheNo":existingContent.contains("cache=no")},"timestamp":${DateTime.now().millisecondsSinceEpoch},"runId":"run1","hypothesisId":"A"}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
        // Store original content for cleanup
        _originalConfigContent = existingContent;
        
        // Remove any existing Doudou-added lines to avoid duplicates
        // Remove ao= lines (ao=pulse, ao=alsa, etc.)
        existingContent = existingContent.replaceAll(RegExp(r'^ao=.*$', multiLine: true), '');
        // Remove Doudou-added comment lines about audio output
        existingContent = existingContent.replaceAll(RegExp(r'^# Doudou:.*audio output.*$', multiLine: true), '');
        // Remove Doudou-added cache=no
        existingContent = existingContent.replaceAll(RegExp(r'^# Doudou:.*cache.*$', multiLine: true), '');
        existingContent = existingContent.replaceAll(RegExp(r'^cache=no$', multiLine: true), '');
        // Remove Doudou-added user-agent and referrer
        existingContent = existingContent.replaceAll(RegExp(r'^# Doudou:.*User-Agent.*$', multiLine: true), '');
        existingContent = existingContent.replaceAll(RegExp(r'^user-agent=.*$', multiLine: true), '');
        existingContent = existingContent.replaceAll(RegExp(r'^referrer=.*$', multiLine: true), '');
        // Remove Doudou-added audio-exclusive (Windows)
        existingContent = existingContent.replaceAll(RegExp(r'^# Doudou:.*WASAPI.*$', multiLine: true), '');
        existingContent = existingContent.replaceAll(RegExp(r'^audio-exclusive=no$', multiLine: true), '');
        // Clean up multiple consecutive newlines (but preserve single blank lines)
        existingContent = existingContent.replaceAll(RegExp(r'\n{3,}'), '\n\n');
        existingContent = existingContent.trim();
        
        final hasRequired = Platform.isWindows
            ? (existingContent.contains('audio-exclusive'))
            : (Platform.isLinux && existingContent.contains('cache=no') &&
                existingContent.contains('ao=') &&
                (forYouTubeMusic
                    ? (existingContent.contains('user-agent') && existingContent.contains('referrer'))
                    : true));
        // #region agent log
        try {
          final logFile2 = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-374c17.log');
          await logFile2.writeAsString('{"sessionId":"374c17","location":"just_audio_media_kit_ext_io.dart:99","message":"Checking if config has required options","data":{"hasRequired":hasRequired,"hasCacheNo":existingContent.contains("cache=no"),"hasAo":existingContent.contains("ao="),"forYouTubeMusic":forYouTubeMusic},"timestamp":${DateTime.now().millisecondsSinceEpoch},"runId":"run1","hypothesisId":"A"}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
        if (hasRequired) {
          // Already has required options, but store original if we haven't yet
          _originalConfigContent ??= existingContent;
          return;
        }
        // Add missing options
        var toAppend = '';
        if (Platform.isLinux) {
          if (!existingContent.contains('cache=no')) {
            toAppend += forYouTubeMusic
                ? '# Doudou: avoid lavf "Failed to create file cache"\ncache=no\n'
                : '# Doudou: minimal options for non-YouTube playback\ncache=no\n';
          }
          if (!forYouTubeMusic && !existingContent.contains('ao=')) {
            // #region agent log
            try {
              final logFile3 = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-374c17.log');
              await logFile3.writeAsString('{"sessionId":"374c17","location":"just_audio_media_kit_ext_io.dart:121","message":"Adding ao=auto to config","data":{"forYouTubeMusic":forYouTubeMusic},"timestamp":${DateTime.now().millisecondsSinceEpoch},"runId":"run1","hypothesisId":"A"}\n', mode: FileMode.append);
            } catch (_) {}
            // #endregion
            toAppend += '# Doudou: auto-detect audio output\nao=auto\n';
          }
          if (forYouTubeMusic) {
            if (!existingContent.contains('user-agent')) {
              toAppend += '# Doudou: User-Agent for googlevideo.com (YouTube Music)\n'
                  'user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n';
            }
            if (!existingContent.contains('referrer')) {
              toAppend += 'referrer="https://www.youtube.com/"\n';
            }
          }
        }
        if (Platform.isWindows && (!existingContent.contains('user-agent') || !existingContent.contains('referrer'))) {
          const uaLinux =
              '# Doudou: User-Agent for googlevideo.com (YouTube Music)\n'
              'user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n';
          const uaWindows =
              '# Doudou: User-Agent for googlevideo.com (YouTube Music)\n'
              'user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"\n';
          const referrerLine = 'referrer="https://www.youtube.com/"\n';
          final ua = Platform.isLinux ? uaLinux : uaWindows;
          if (!existingContent.contains('user-agent')) toAppend += ua;
          if (!existingContent.contains('referrer')) toAppend += referrerLine;
        }
        if (toAppend.isNotEmpty) {
          final finalContent = '$existingContent\n$toAppend';
          await configFile.writeAsString(finalContent);
          // #region agent log
          try {
            final logFile4 = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-374c17.log');
            await logFile4.writeAsString('{"sessionId":"374c17","location":"just_audio_media_kit_ext_io.dart:145","message":"Wrote config file with appended options","data":{"toAppendLength":toAppend.length,"finalContentLength":finalContent.length,"hasAo":finalContent.contains("ao="),"hasCacheNo":finalContent.contains("cache=no")},"timestamp":${DateTime.now().millisecondsSinceEpoch},"runId":"run1","hypothesisId":"A"}\n', mode: FileMode.append);
          } catch (_) {}
          // #endregion
          debugPrint('PlatformAudioConfig: added options to mpv.conf');
          return;
        }
      } else {
        // No existing file, store empty as original
        _originalConfigContent = '';
        // #region agent log
        try {
          final logFile5 = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-374c17.log');
          await logFile5.writeAsString('{"sessionId":"374c17","location":"just_audio_media_kit_ext_io.dart:150","message":"No existing mpv.conf file","data":{"forYouTubeMusic":forYouTubeMusic},"timestamp":${DateTime.now().millisecondsSinceEpoch},"runId":"run1","hypothesisId":"A"}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
      }

      final newContent =
          existingContent.isEmpty ? optionsToAdd : '$existingContent\n$optionsToAdd';
      await configFile.writeAsString(newContent);
      // #region agent log
      try {
        final logFile6 = File('/mnt/FUCKICE/Code/gitlab/Openlyst/doudou/.cursor/debug-374c17.log');
        await logFile6.writeAsString('{"sessionId":"374c17","location":"just_audio_media_kit_ext_io.dart:155","message":"Wrote new config file","data":{"newContentLength":newContent.length,"hasAo":newContent.contains("ao="),"hasCacheNo":newContent.contains("cache=no"),"optionsToAddLength":optionsToAdd.length},"timestamp":${DateTime.now().millisecondsSinceEpoch},"runId":"run1","hypothesisId":"A"}\n', mode: FileMode.append);
      } catch (_) {}
      // #endregion
      debugPrint('PlatformAudioConfig: mpv.conf at $configDir');
      
      // Log final config contents for debugging
      if (kDebugMode && Platform.isLinux) {
        try {
          final finalContent = await configFile.readAsString();
          debugPrint('[Linux Debug] PlatformAudioConfig: Final mpv.conf contents:');
          finalContent.split('\n').forEach((line) {
            if (line.trim().isNotEmpty) {
              debugPrint('[Linux Debug] PlatformAudioConfig:   $line');
            }
          });
        } catch (e) {
          debugPrint('[Linux Debug] PlatformAudioConfig: Failed to read final config: $e');
        }
      }
    } catch (e) {
      debugPrint('PlatformAudioConfig: $e');
    }
  }
  
  /// Clean up MPV config by removing Doudou-added options and restoring original content
  /// This should be called when the app closes to avoid leaving temporary config changes
  static Future<void> cleanupMpvConfig() async {
    if (_configFilePath == null || _originalConfigContent == null) {
      return; // Nothing to clean up
    }
    
    try {
      final configFile = File(_configFilePath!);
      if (!await configFile.exists()) {
        return;
      }
      
      String currentContent = await configFile.readAsString();
      
      // Remove all Doudou-added lines
      currentContent = currentContent.replaceAll(RegExp(r'^ao=.*$', multiLine: true), '');
      currentContent = currentContent.replaceAll(RegExp(r'^# Doudou:.*$', multiLine: true), '');
      currentContent = currentContent.replaceAll(RegExp(r'^cache=no$', multiLine: true), '');
      currentContent = currentContent.replaceAll(RegExp(r'^user-agent=.*$', multiLine: true), '');
      currentContent = currentContent.replaceAll(RegExp(r'^referrer=.*$', multiLine: true), '');
      currentContent = currentContent.replaceAll(RegExp(r'^audio-exclusive=no$', multiLine: true), '');
      // Clean up multiple consecutive newlines
      currentContent = currentContent.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      currentContent = currentContent.trim();
      
      // Restore original content (which didn't have Doudou additions)
      // If original was empty and current is now empty after removal, delete the file
      if (_originalConfigContent!.isEmpty && currentContent.isEmpty) {
        await configFile.delete();
        debugPrint('PlatformAudioConfig: removed temporary mpv.conf (was empty)');
      } else {
        // Restore original content
        await configFile.writeAsString(_originalConfigContent!);
        debugPrint('PlatformAudioConfig: restored original mpv.conf');
      }
      
      // Clear stored values
      _configFilePath = null;
      _originalConfigContent = null;
    } catch (e) {
      debugPrint('PlatformAudioConfig: cleanup failed: $e');
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
