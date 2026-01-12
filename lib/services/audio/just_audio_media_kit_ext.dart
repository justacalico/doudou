import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';

/// Extended JustAudioMediaKit initialization with Windows audio fix
/// 
/// This utility extends the standard JustAudioMediaKit initialization to
/// disable WASAPI exclusive mode on Windows, which fixes the volume bypass bug.
/// 
/// The bug: When WASAPI exclusive mode is enabled, the app's volume slider
/// bypasses the Windows system volume mixer:
/// - Windows vol: 12, App vol: 100 → plays at 100 (ignores Windows)
/// - Windows vol: 100, App vol: 12 → plays at 12 (works correctly)
/// 
/// Solution: Set mpv's audio-exclusive=no to use WASAPI shared mode.
class JustAudioMediaKitExt {
  JustAudioMediaKitExt._();
  
  /// Static flag to control WASAPI exclusive mode on Windows
  /// Set to false to disable exclusive mode (recommended)
  static bool audioExclusive = false;
  
  /// Initialize JustAudioMediaKit with Windows audio fix
  /// 
  /// This method:
  /// 1. Creates mpv.conf with audio-exclusive=no on Windows
  /// 2. Calls the standard JustAudioMediaKit.ensureInitialized()
  /// 
  /// Call this instead of JustAudioMediaKit.ensureInitialized() in your main()
  static Future<void> ensureInitializedAsync({
    bool linux = true,
    bool windows = true,
    bool android = false,
    bool iOS = false,
    bool macOS = false,
    String? libmpv,
  }) async {
    // On Windows, create mpv config to disable exclusive mode
    if (isWindows && !audioExclusive) {
      await _createMpvConfig();
    }
    
    // Standard initialization
    JustAudioMediaKit.ensureInitialized(
      linux: linux,
      windows: windows,
      android: android,
      iOS: iOS,
      macOS: macOS,
      libmpv: libmpv,
    );
    
    // Set the title to show in Windows volume mixer
    JustAudioMediaKit.title = 'Doudou';
    
    debugPrint('JustAudioMediaKitExt: Initialized with audioExclusive=$audioExclusive');
  }
  
  /// Synchronous version of initialization
  /// Note: mpv config creation happens asynchronously in background
  static void ensureInitialized({
    bool linux = true,
    bool windows = true,
    bool android = false,
    bool iOS = false,
    bool macOS = false,
    String? libmpv,
  }) {
    // On Windows, create mpv config to disable exclusive mode (async, fire and forget)
    if (isWindows && !audioExclusive) {
      _createMpvConfig().catchError((e) {
        debugPrint('JustAudioMediaKitExt: Failed to create mpv config: $e');
      });
    }
    
    // Standard initialization
    JustAudioMediaKit.ensureInitialized(
      linux: linux,
      windows: windows,
      android: android,
      iOS: iOS,
      macOS: macOS,
      libmpv: libmpv,
    );
    
    // Set the title to show in Windows volume mixer
    JustAudioMediaKit.title = 'Doudou';
    
    debugPrint('JustAudioMediaKitExt: Initialized with audioExclusive=$audioExclusive');
  }
  
  /// Check if we're on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  
  /// Check if exclusive mode should be disabled
  static bool get shouldDisableExclusiveMode => isWindows && !audioExclusive;
  
  /// Create mpv.conf file with audio-exclusive=no
  /// 
  /// mpv reads configuration from:
  /// - Windows: %APPDATA%/mpv/mpv.conf
  /// - Linux: ~/.config/mpv/mpv.conf
  /// - macOS: ~/.config/mpv/mpv.conf
  static Future<void> _createMpvConfig() async {
    try {
      String configDir;
      
      if (Platform.isWindows) {
        // On Windows, mpv reads from %APPDATA%/mpv/
        final appData = Platform.environment['APPDATA'];
        if (appData == null) {
          debugPrint('JustAudioMediaKitExt: APPDATA not found');
          return;
        }
        configDir = '$appData/mpv';
      } else {
        // On Linux/macOS, mpv reads from ~/.config/mpv/
        final home = Platform.environment['HOME'];
        if (home == null) {
          debugPrint('JustAudioMediaKitExt: HOME not found');
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
        
        // Check if audio-exclusive is already set
        if (existingContent.contains('audio-exclusive')) {
          debugPrint('JustAudioMediaKitExt: audio-exclusive already in mpv.conf');
          return;
        }
      }
      
      // Append audio-exclusive=no
      final newContent = existingContent.isEmpty 
          ? '# Doudou: Disable WASAPI exclusive mode for system volume integration\naudio-exclusive=no\n'
          : '$existingContent\n# Doudou: Disable WASAPI exclusive mode for system volume integration\naudio-exclusive=no\n';
      
      await configFile.writeAsString(newContent);
      debugPrint('JustAudioMediaKitExt: Created mpv.conf with audio-exclusive=no at $configDir');
    } catch (e) {
      debugPrint('JustAudioMediaKitExt: Error creating mpv config: $e');
    }
  }
}

/// Mixin to add Windows audio configuration to audio handlers
/// 
/// This mixin provides methods to configure the underlying media_kit player
/// to disable WASAPI exclusive mode on Windows.
mixin WindowsAudioConfigMixin {
  /// Configure a media_kit Player to disable WASAPI exclusive mode
  Future<void> configureWindowsAudio(Player player) async {
    if (!JustAudioMediaKitExt.shouldDisableExclusiveMode) return;
    
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

