part of 'settings_screen_controller.dart';

mixin _SettingsStorageMixin on _SettingsScreenControllerBase {
  Future<void> setExportedLocation() async {
    if (PermissionService.isScopedStorage) {
      final picked = await ExportService.pickExportFolder(
          dialogTitle: l10nFromPrefs().selectExportFileFolder);
      if (picked == null) {
        return;
      }
      setBox.put("exportLocationPath", picked);
      exportLocationPath.value = picked;
      return;
    }

    if (!await PermissionService.getExtStoragePermission()) {
      return;
    }

    final String? pickedFolderPath = await FilePicker.platform
        .getDirectoryPath(dialogTitle: l10nFromPrefs().selectExportFileFolder);
    if (pickedFolderPath == '/' || pickedFolderPath == null) {
      return;
    }

    setBox.put("exportLocationPath", pickedFolderPath);
    exportLocationPath.value = pickedFolderPath;
  }

  Future<void> setDownloadLocation() async {
    if (PermissionService.isScopedStorage) {
      resetDownloadLocation();
      return;
    }

    if (!await PermissionService.getExtStoragePermission()) {
      return;
    }

    final String? pickedFolderPath = await FilePicker.platform
        .getDirectoryPath(dialogTitle: l10nFromPrefs().selectDownloadsFolder);
    if (pickedFolderPath == '/' || pickedFolderPath == null) {
      return;
    }

    setBox.put("downloadLocationPath", pickedFolderPath);
    downloadLocationPath.value = pickedFolderPath;
  }

  void resetDownloadLocation() {
    final defaultPath = "$_supportDir/Music";
    setBox.put("downloadLocationPath", defaultPath);
    downloadLocationPath.value = defaultPath;
  }

  Future<void> clearImagesCache() async {
    final tempImgDirPath =
        "${(await getApplicationCacheDirectory()).path}/libCachedImageData";
    final tempImgDir = Directory(tempImgDirPath);
    try {
      if (await tempImgDir.exists()) {
        await tempImgDir.delete(recursive: true);
      }
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=settings.clearImagesCache] Failed to clear image cache at $tempImgDirPath: $e\n$st');
    }
  }

}
