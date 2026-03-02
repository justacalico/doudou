import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../terminate_restart_platform_interface.dart';

/// An implementation of [TerminateRestartPlatform] that uses method channels.
class MethodChannelTerminateRestart extends TerminateRestartPlatform {
  /// The method channel used to communicate with the native platform.
  @visibleForTesting
  static const MethodChannel methodChannel =
      MethodChannel('com.ahmedsleem.terminate_restart/restart');

  @override
  Future<bool> restartApp({
    bool clearData = false,
    bool preserveKeychain = false,
    bool preserveUserDefaults = false,
    bool terminate = true,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'restart', // Match native method name
        {
          'clearData': clearData,
          'preserveKeychain': preserveKeychain,
          'preserveUserDefaults': preserveUserDefaults,
          'terminate': terminate,
        },
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error restarting app: $e');
      return false;
    }
  }

  @override
  Future<void> gc() async {
    try {
      await methodChannel.invokeMethod<void>('gc');
    } catch (e) {
      debugPrint('Error during garbage collection: $e');
    }
  }
}
