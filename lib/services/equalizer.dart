import 'package:doudou/native_bindings/andrid_utils.dart';
import 'package:jni/jni.dart';

import '/utils/helper.dart';

class EqualizerService {
  static bool openEqualizer(int sessionId) {
    try {
      JObject activity = JObject.fromReference(Jni.getCurrentActivity());
      JObject context =
          JObject.fromReference(Jni.getCachedApplicationContext());
      final success = Equalizer().openEqualizer(sessionId, context, activity);
      activity.release();
      context.release();
      return success;
    } catch (e, st) {
      printERROR('EqualizerService.openEqualizer failed: $e\n$st');
      return false;
    }
  }

  static void initAudioEffect(int sessionId) {
    try {
      JObject context =
          JObject.fromReference(Jni.getCachedApplicationContext());
      Equalizer().initAudioEffect(sessionId, context);
      context.release();
    } catch (e, st) {
      printERROR('EqualizerService.initAudioEffect failed: $e\n$st');
    }
  }

  static void endAudioEffect(int sessionId) {
    try {
      JObject context =
          JObject.fromReference(Jni.getCachedApplicationContext());
      Equalizer().endAudioEffect(sessionId, context);
      context.release();
    } catch (e, st) {
      printERROR('EqualizerService.endAudioEffect failed: $e\n$st');
    }
  }
}
