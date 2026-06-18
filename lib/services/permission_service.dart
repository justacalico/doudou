import 'package:get/get.dart';
import '/native_bindings/andrid_utils.dart' show SDKInt;

class PermissionService {
  static bool get isScopedStorage =>
      GetPlatform.isAndroid && SDKInt.Companion.getSDKInt() >= 30;

  static Future<bool> getExtStoragePermission() async {
    // App-specific directories (supportDir, externalFilesDir, etc.)
    // do NOT require any storage permission on any Android version.
    // We removed broad storage permissions from the manifest to comply
    // with Google Play All Files Access policy.
    return true;
  }
}
