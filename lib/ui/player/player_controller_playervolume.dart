part of 'player_controller.dart';

mixin _PlayerVolumeMixin on _PlayerControllerBase {
  Future<void> setVolume(int value) async {
    final uiVolume = value.clamp(0, 100);
    if (uiVolume > 0) {
      _lastNonZeroVolume = uiVolume;
    }
    // Human hearing is logarithmic, so a linear volume slider feels
    // like it jumps too fast at the low end. A quadratic curve gives
    // much better control at quiet volumes.
    final playerVolume = uiVolume == 0
        ? 0.0
        : pow(uiVolume / 100.0, 2.0).toDouble();
    _audioHandler.customAction("setVolume", {"value": playerVolume});
    volume.value = uiVolume;
    await Hive.box("AppPrefs").put("volume", uiVolume);
  }

  Future<void> mute() async {
    int vol;
    if (volume.value != 0) {
      vol = 0;
    } else {
      vol = await Hive.box("AppPrefs").get("volume", defaultValue: 100);
      if (vol == 0) {
        vol = _lastNonZeroVolume > 0 ? _lastNonZeroVolume : 100;
      }
    }
    await setVolume(vol);
  }

  void toggleSkipSilence(bool enable) {
    _audioHandler.customAction("toggleSkipSilence", {"enable": enable});
  }

  void toggleLoudnessNormalization(bool enable) {
    _audioHandler
        .customAction("toggleLoudnessNormalization", {"enable": enable});
  }

  Future<void> toggleLoopMode() async {
    isLoopModeEnabled.isFalse
        ? _audioHandler.setRepeatMode(AudioServiceRepeatMode.one)
        : _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
    isLoopModeEnabled.value = !isLoopModeEnabled.value;
    await Hive.box("AppPrefs")
        .put("isLoopModeEnabled", isLoopModeEnabled.value);
  }

  Future<void> toggleQueueLoopMode({bool showMessage = true}) async {
    if (isShuffleModeEnabled.isTrue && isQueueLoopModeEnabled.isTrue) {
      if (!showMessage) return;
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.queueLoopNotDisMsg1,
          size: SnackBarSize.BIG, duration: const Duration(seconds: 2)));
      return;
    }

    if (isRadioModeOn && isQueueLoopModeEnabled.isFalse) {
      if (!showMessage) return;
      ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
          Get.context!, AppLocalizations.of(Get.context!)!.queueLoopNotDisMsg2,
          size: SnackBarSize.BIG, duration: const Duration(seconds: 2)));
      return;
    }

    isQueueLoopModeEnabled.value = !isQueueLoopModeEnabled.value;
    await _audioHandler.customAction(
        "toggleQueueLoopMode", {"enable": isQueueLoopModeEnabled.value});
    await Hive.box("AppPrefs")
        .put("queueLoopModeEnabled", isQueueLoopModeEnabled.value);
  }

}
