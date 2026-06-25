import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Detects whether the app is running on an Android TV (leanback) device.
///
/// Uses a compile-time flag `TV` as the primary signal so we can short-circuit
/// device probes on non-TV builds. Falls back to runtime detection via
/// [DeviceInfoPlugin] for cases where the flag isn't set.
class TvService extends GetxController {
  static const _kCompileTimeTV = bool.fromEnvironment('TV', defaultValue: false);

  final isTV = false.obs;

  @override
  void onInit() {
    super.onInit();
    _detect();
  }

  Future<void> _detect() async {
    debugPrint('[TvService] _detect() called, _kCompileTimeTV=$_kCompileTimeTV');
    if (_kCompileTimeTV) {
      debugPrint('[TvService] compile-time TV flag is true, setting isTV=true');
      isTV.value = true;
      return;
    }

    // Runtime detection — useful when the flag isn't passed
    if (!Platform.isAndroid) {
      debugPrint('[TvService] not Android, setting isTV=false');
      isTV.value = false;
      return;
    }

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final hasLeanback = info.systemFeatures
          .any((f) => f == 'android.software.leanback');
      debugPrint('[TvService] androidInfo systemFeatures: ${info.systemFeatures}');
      debugPrint('[TvService] hasLeanback=$hasLeanback, setting isTV=$hasLeanback');
      isTV.value = hasLeanback;
    } catch (e) {
      debugPrint('[TvService] detection error: $e, setting isTV=false');
      isTV.value = false;
    }
  }
}
