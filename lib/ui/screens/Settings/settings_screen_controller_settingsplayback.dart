part of 'settings_screen_controller.dart';

mixin _SettingsPlaybackMixin on _SettingsScreenControllerBase {
  void toggleCachingSongsValue(bool value) {
    setBox.put("cacheSongs", value);
    cacheSongs.value = value;
  }

  void toggleSkipSilence(bool val) {
    Get.find<PlayerController>().toggleSkipSilence(val);
    setBox.put('skipSilenceEnabled', val);
    skipSilenceEnabled.value = val;
  }

  void toggleLoudnessNormalization(bool val) {
    Get.find<PlayerController>().toggleLoudnessNormalization(val);
    setBox.put("loudnessNormalizationEnabled", val);
    loudnessNormalizationEnabled.value = val;
  }

  void toggleRestorePlaybackSession(bool val) {
    setBox.put("restrorePlaybackSession", val);
    restorePlaybackSession.value = val;
  }

  Future<void> toggleCacheHomeScreenData(bool val) async {
    setBox.put("cacheHomeScreenData", val);
    cacheHomeScreenData.value = val;
    final boxName = homeScreenDataBoxName(activeServerId.value ?? 0);
    if (!val) {
      final box = await Hive.openBox(boxName);
      await box.clear();
    } else {
      await Hive.openBox(boxName);
      Get.find<HomeScreenController>().cachedHomeScreenData(updateAll: true);
    }
  }

  void toggleAutoDownloadFavoriteSong(bool val) {
    setBox.put("autoDownloadFavoriteSongEnabled", val);
    autoDownloadFavoriteSongEnabled.value = val;
  }

  void toggleCheckForUpdatesOnStartup(bool val) {
    setBox.put("checkForUpdatesOnStartup", val);
    checkForUpdatesOnStartup.value = val;
  }

  void togglePlaybackDiagnostics(bool val) {
    setBox.put(PlaybackDiagnosticsService.enabledKey, val);
    playbackDiagnosticsEnabled.value = val;
  }

  void toggleBackgroundPlay(bool val) {
    setBox.put('backgroundPlayEnabled', val);
    backgroundPlayEnabled.value = val;
  }

  void toggleKeepScreenAwake(bool val) {
    setBox.put('keepScreenAwake', val);
    keepScreenAwake.value = val;
  }

  void toggleAutoRadio(bool val) {
    setBox.put('autoRadioEnabled', val);
    autoRadioEnabled.value = val;
  }

  void toggleAutoOpenPlayer(bool val) {
    setBox.put('autoOpenPlayer', val);
    autoOpenPlayer.value = val;
  }

  void toggleStopPlyabackOnSwipeAway(bool val) {
    setBox.put('stopPlyabackOnSwipeAway', val);
    stopPlyabackOnSwipeAway.value = val;
  }

}
