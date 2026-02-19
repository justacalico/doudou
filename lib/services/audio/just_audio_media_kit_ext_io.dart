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
          // so new MPV instances get consistent options and audio actually plays
          // Use ao=pulse (works with PipeWire via PulseAudio compatibility API)
          optionsToAdd =
              '# Doudou: minimal options for non-YouTube playback (Navidrome, etc.)\n'
              'cache=no\n'
              '# Doudou: use PulseAudio API (works with PipeWire)\nao=pulse\n';
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
          await configFile.writeAsString('$existingContent\n$toAppend');
          debugPrint('PlatformAudioConfig: added options to mpv.conf');
          return;
        }
      } else {
        // No existing file, store empty as original
        _originalConfigContent = '';
      }

      final newContent =
          existingContent.isEmpty ? optionsToAdd : '$existingContent\n$optionsToAdd';
      await configFile.writeAsString(newContent);
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
