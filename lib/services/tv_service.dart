import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
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
    if (_kCompileTimeTV) {
      isTV.value = true;
      return;
    }

    // Runtime detection — useful when the flag isn't passed
    if (!Platform.isAndroid) {
      isTV.value = false;
      return;
    }

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      // systemFeatures contains "android.software.leanback" on TV devices
      isTV.value = info.systemFeatures
          .any((f) => f == 'android.software.leanback');
    } catch (_) {
      isTV.value = false;
    }
  }
}
