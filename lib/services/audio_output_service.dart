import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/audio_output_device.dart';
import '../utils/helper.dart';

const _channel = MethodChannel('gitlab.openlyst.doudou/audio_output');

typedef AudioOutputInvoker = Future<T?> Function<T>(String method,
    [dynamic arguments]);

Future<T?> _platformInvoke<T>(String method, [dynamic arguments]) {
  return _channel.invokeMethod<T>(method, arguments);
}

/// Lists and switches the audio output route on Android and iOS.
///
/// Android routes through `MediaRouter` (framework class) so Bluetooth, cast
/// and the default phone route are real selectable targets. iOS only permits
/// toggling the built-in receiver/speaker override in code; picking any other
/// route requires the system picker, surfaced through [showSystemPicker].
class AudioOutputService {
  AudioOutputService({
    AudioOutputInvoker? invoke,
    bool Function()? supported,
  })  : _invoke = invoke ?? _platformInvoke,
        _supported = supported ??
            (() => GetPlatform.isAndroid || GetPlatform.isIOS);

  final AudioOutputInvoker _invoke;
  final bool Function() _supported;

  bool get isSupported => _supported();

  Future<List<AudioOutputDevice>> devices() async {
    if (!isSupported) return const [];
    try {
      final raw = await _invoke<List<dynamic>>('getDevices');
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(AudioOutputDevice.fromMap)
          .toList();
    } on MissingPluginException {
      return const [];
    } catch (e, st) {
      printWarning('AudioOutputService.devices failed: $e\n$st');
      return const [];
    }
  }

  Future<bool> select(AudioOutputDevice device) async {
    if (!isSupported || !device.selectable) return false;
    try {
      return await _invoke<bool>('selectDevice', {'id': device.id}) ?? false;
    } on MissingPluginException {
      return false;
    } catch (e, st) {
      printWarning('AudioOutputService.select failed: $e\n$st');
      return false;
    }
  }

  /// Opens the platform route picker. Only implemented on iOS, where it is
  /// the only way to reach AirPlay/Bluetooth targets.
  Future<bool> showSystemPicker() async {
    if (!isSupported) return false;
    try {
      return await _invoke<bool>('showSystemPicker') ?? false;
    } on MissingPluginException {
      return false;
    } catch (e, st) {
      printWarning('AudioOutputService.showSystemPicker failed: $e\n$st');
      return false;
    }
  }
}
