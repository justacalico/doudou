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
  
  /// Initialize JustAudioMediaKit with Windows audio fix.
  /// Anandnet fork (Harmony) has no ensureInitialized; we only set protocolWhitelist and title.
  static Future<void> ensureInitializedAsync({
    bool linux = true,
    bool windows = true,
    bool android = false,
    bool iOS = false,
    bool macOS = false,
    String? libmpv,
  }) async {
    // Only create MPV config for Windows (audio-exclusive=no)
    // Linux MPV config is created dynamically only for YouTube Music
    if (isWindows && !audioExclusive) {
      await PlatformAudioConfig.createMpvConfig();
    }
    _setHarmonyConfig(linux: linux, windows: windows, macOS: macOS, android: android, iOS: iOS);
    debugPrint('JustAudioMediaKitExt: Initialized with audioExclusive=$audioExclusive');
  }
  
  /// Synchronous version (anandnet fork has no ensureInitialized; set protocolWhitelist + title only).
  static void ensureInitialized({
    bool linux = true,
    bool windows = true,
    bool android = false,
    bool iOS = false,
    bool macOS = false,
    String? libmpv,
  }) {
    // Only create MPV config for Windows (audio-exclusive=no)
    // Linux MPV config is created dynamically only for YouTube Music
    if (isWindows && !audioExclusive) {
      PlatformAudioConfig.createMpvConfig().catchError((e) {
        debugPrint('JustAudioMediaKitExt: Failed to create mpv config: $e');
      });
    }
    _setHarmonyConfig(linux: linux, windows: windows, macOS: macOS, android: android, iOS: iOS);
    debugPrint('JustAudioMediaKitExt: Initialized with audioExclusive=$audioExclusive');
  }

  static void _setHarmonyConfig({
    bool linux = true,
    bool windows = true,
    bool macOS = false,
    bool android = false,
    bool iOS = false,
  }) {
    if ((linux || windows || macOS) && !android && !iOS) {
      JustAudioMediaKit.protocolWhitelist = const ['http', 'https', 'file'];
    }
    JustAudioMediaKit.title = 'Doudou';
  }
  
  /// Check if we're on Windows
  static bool get isWindows => PlatformAudioConfig.isWindows;
  
  /// Check if exclusive mode should be disabled
  static bool get shouldDisableExclusiveMode => isWindows && !audioExclusive;
}
