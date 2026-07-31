import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../utils/helper.dart';

const _channel = MethodChannel('gitlab.openlyst.doudou/wakelock');

class PlaybackWakeLockService extends GetxService {
  bool _held = false;
  Future<void> _pending = Future<void>.value();

  Future<void> acquire() => _enqueue(() async {
        if (_held) return;
        await _channel.invokeMethod<bool>('acquire');
        _held = true;
      });

  Future<void> release() => _enqueue(() async {
        if (!_held) return;
        await _channel.invokeMethod<bool>('release');
        _held = false;
      });

  Future<void> _enqueue(Future<void> Function() task) {
    final completer = Completer<void>();
    _pending = _pending.whenComplete(() async {
      try {
        await task();
        completer.complete();
      } catch (e) {
        printERROR('Playback wakelock operation failed: $e');
        completer.completeError(e);
      }
    });
    return completer.future;
  }

  @override
  void onClose() {
    unawaited(release());
    super.onClose();
  }
}
