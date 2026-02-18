import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'just_audio_media_kit_ext_stub.dart' if (dart.library.io) 'just_audio_media_kit_ext_io.dart';

export 'just_audio_media_kit_ext_stub.dart' if (dart.library.io) 'just_audio_media_kit_ext_io.dart';

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
      await PlatformAudioConfig.createMpvConfig();
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
    
    // Harmony-Music configuration: protocol whitelist for desktop (Windows/Linux)
    // Reference: Harmony-Music lib/services/audio_handler.dart – JustAudioMediaKit.protocolWhitelist
    if ((linux || windows || macOS) && !android && !iOS) {
      JustAudioMediaKit.protocolWhitelist = const ['http', 'https', 'file'];
    }
    
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
      PlatformAudioConfig.createMpvConfig().catchError((e) {
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
  static bool get isWindows => PlatformAudioConfig.isWindows;
  
  /// Check if exclusive mode should be disabled
  static bool get shouldDisableExclusiveMode => isWindows && !audioExclusive;
}
