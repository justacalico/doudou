import 'package:get/get.dart';

class PermissionService {
  // Always treat Android as scoped storage.
  // App-specific directories require zero permissions on all Android versions.
  static bool get isScopedStorage => GetPlatform.isAndroid;

  static Future<bool> getExtStoragePermission() async {
    // App-specific directories (supportDir, externalFilesDir, etc.)
    // do NOT require any storage permission on any Android version.
    // We removed broad storage permissions from the manifest to comply
    // with Google Play All Files Access policy.
    return true;
  }
}
