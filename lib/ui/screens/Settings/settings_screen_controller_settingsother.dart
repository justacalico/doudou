part of 'settings_screen_controller.dart';

mixin _SettingsOtherMixin on _SettingsScreenControllerBase {
  Future<void> enableIgnoringBatteryOptimizations() async {
    await Permission.ignoreBatteryOptimizations.request();
    isIgnoringBatteryOptimizations.value =
        await Permission.ignoreBatteryOptimizations.isGranted;
  }

  Future<void> unlinkPiped() async {
    Get.find<PipedServices>().logout();
    isLinkedWithPiped.value = false;
    Get.find<LibraryPlaylistsController>().removePipedPlaylists();
    final box = await Hive.openBox(
        blacklistedPlaylistBoxName(activeServerId.value ?? 0));
    box.clear();
    ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
        Get.context!, AppLocalizations.of(Get.context!)!.unlinkAlert,
        size: SnackBarSize.MEDIUM));
    box.close();
  }

  Future<void> resetAppSettingsToDefault() async {
    await setBox.clear();
  }

  Future<void> closeAllDatabases() async {
    await Hive.close();
  }

  Future<void> resyncLibraryNow() async {
    await Get.find<LibrarySyncService>().syncAll(force: true);
  }

}
