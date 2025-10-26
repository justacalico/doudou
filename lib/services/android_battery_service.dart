import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AndroidBatteryService {
  static const MethodChannel _channel = MethodChannel('gitlab.openlyst.doudou/battery_optimization');
  
  /// Request battery optimization whitelist for the app
  static Future<bool> requestBatteryOptimization() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable on non-Android platforms
    }
    
    try {
      final bool result = await _channel.invokeMethod('requestBatteryOptimization');
      if (kDebugMode) {
        print('AndroidBatteryService: Requested battery optimization whitelist: $result');
      }
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AndroidBatteryService: Failed to request battery optimization: $e');
      }
      return false;
    }
  }
  
  /// Acquire wake lock for audio playback
  static Future<bool> acquireWakeLock() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable on non-Android platforms
    }
    
    try {
      final bool result = await _channel.invokeMethod('acquireWakeLock');
      if (kDebugMode) {
        print('AndroidBatteryService: Acquired wake lock: $result');
      }
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AndroidBatteryService: Failed to acquire wake lock: $e');
      }
      return false;
    }
  }
  
  /// Release wake lock
  static Future<bool> releaseWakeLock() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable on non-Android platforms
    }
    
    try {
      final bool result = await _channel.invokeMethod('releaseWakeLock');
      if (kDebugMode) {
        print('AndroidBatteryService: Released wake lock: $result');
      }
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AndroidBatteryService: Failed to release wake lock: $e');
      }
      return false;
    }
  }
}