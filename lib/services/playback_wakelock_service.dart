import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../utils/helper.dart';

const _channel = MethodChannel('gitlab.openlyst.doudou/wakelock');

class PlaybackWakeLockService extends GetxService {
  bool _held = false;

  Future<void> acquire() async {
    if (_held) return;
    try {
      await _channel.invokeMethod<bool>('acquire');
      _held = true;
    } catch (e) {
      printERROR('Failed to acquire playback wakelock: $e');
    }
  }

  Future<void> release() async {
    if (!_held) return;
    try {
      await _channel.invokeMethod<bool>('release');
    } catch (e) {
      printERROR('Failed to release playback wakelock: $e');
    }
    _held = false;
  }

  @override
  void onClose() {
    unawaited(release());
    super.onClose();
  }
}
