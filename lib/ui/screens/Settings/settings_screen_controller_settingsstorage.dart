part of 'settings_screen_controller.dart';

mixin _SettingsStorageMixin on _SettingsScreenControllerBase {
  Future<void> setExportedLocation() async {
    if (PermissionService.isScopedStorage) {
      final defaultExport = "$_supportDir/Exports";
      await Directory(defaultExport).create(recursive: true);
      setBox.put("exportLocationPath", defaultExport);
      exportLocationPath.value = defaultExport;
      return;
    }

    if (!await PermissionService.getExtStoragePermission()) {
      return;
    }

    final String? pickedFolderPath = await FilePicker.platform
        .getDirectoryPath(dialogTitle: "Select export file folder");
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
        .getDirectoryPath(dialogTitle: "Select downloads folder");
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
