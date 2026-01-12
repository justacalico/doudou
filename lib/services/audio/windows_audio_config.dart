import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Windows Audio Configuration Helper
/// 
/// This utility addresses a Windows-specific issue where the app's volume
/// slider bypasses the Windows system volume mixer when using WASAPI 
/// exclusive mode.
/// 
/// The underlying audio backend (mpv via media_kit) can use WASAPI in either:
/// - Exclusive mode: Bypasses Windows volume mixer, app has direct hardware access
/// - Shared mode: Respects Windows volume mixer, integrates with system audio
/// 
/// By default, mpv may use exclusive mode which causes the bug:
/// - Windows vol: 12, App vol: 100 → plays at 100 (ignores Windows)
/// - Windows vol: 100, App vol: 12 → plays at 12 (works correctly)
/// 
/// This file provides configuration to disable exclusive mode on Windows.
class WindowsAudioConfig {
  WindowsAudioConfig._();
  
  /// Whether WASAPI exclusive mode should be disabled
  /// 
  /// When true (default on Windows), audio will use WASAPI shared mode
  /// which respects the Windows volume mixer.
  static bool disableExclusiveMode = true;
  
  /// Check if we're running on Windows desktop
  static bool get isWindows =>
      !kIsWeb && (Platform.isWindows);
  
  /// Get the mpv property name for audio exclusive mode
  static String get audioExclusiveProperty => 'audio-exclusive';
  
  /// Get the value to disable exclusive mode
  static String get audioExclusiveDisabledValue => 'no';
  
  /// Get the value to enable exclusive mode
  static String get audioExclusiveEnabledValue => 'yes';
  
  /// Get the appropriate value based on configuration
  static String get audioExclusiveValue => 
      disableExclusiveMode ? audioExclusiveDisabledValue : audioExclusiveEnabledValue;
      
  /// Whether we should apply Windows-specific audio configuration
  static bool get shouldApplyWindowsConfig => isWindows && disableExclusiveMode;
  
  /// Configure a media_kit Player to disable WASAPI exclusive mode on Windows
  /// 
  /// This should be called after the player is created but before playback starts.
  /// The method accesses the underlying NativePlayer to set the mpv property.
  /// 
  /// [player] - The media_kit Player instance to configure
  static Future<void> configurePlayer(Player player) async {
    if (!shouldApplyWindowsConfig) return;
    
    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty(
          audioExclusiveProperty,
          audioExclusiveDisabledValue,
        );
        debugPrint('WindowsAudioConfig: Disabled WASAPI exclusive mode');
      }
    } catch (e) {
      debugPrint('WindowsAudioConfig: Failed to configure player: $e');
    }
  }
  
  /// Configure a media_kit Player using the NativePlayer directly
  /// 
  /// This is an alternative method when you have direct access to NativePlayer.
  /// 
  /// [nativePlayer] - The NativePlayer instance to configure
  static Future<void> configureNativePlayer(NativePlayer nativePlayer) async {
    if (!shouldApplyWindowsConfig) return;
    
    try {
      await nativePlayer.setProperty(
        audioExclusiveProperty,
        audioExclusiveDisabledValue,
      );
      debugPrint('WindowsAudioConfig: Disabled WASAPI exclusive mode');
    } catch (e) {
      debugPrint('WindowsAudioConfig: Failed to configure native player: $e');
    }
  }
}

