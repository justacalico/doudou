import 'package:flutter/foundation.dart';

import 'package:doudou/native_bindings/andrid_utils.dart';
import 'package:jni/jni.dart';

class EqualizerService {
  static bool openEqualizer(int sessionId) {
    try {
      JObject activity = JObject.fromReference(Jni.getCurrentActivity());
      JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
      final success = Equalizer().openEqualizer(sessionId, context, activity);
      activity.release();
      context.release();
      return success;
    } catch (e, st) {
      debugPrint('EqualizerService.openEqualizer failed: $e\n$st');
      return false;
    }
  }

  static void initAudioEffect(int sessionId) {
    try {
      JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
      Equalizer().initAudioEffect(sessionId, context);
      context.release();
    } catch (e, st) {
      debugPrint('EqualizerService.initAudioEffect failed: $e\n$st');
    }
  }

  static void endAudioEffect(int sessionId) {
    try {
      JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
      Equalizer().endAudioEffect(sessionId, context);
      context.release();
    } catch (e, st) {
      debugPrint('EqualizerService.endAudioEffect failed: $e\n$st');
    }
  }
}
