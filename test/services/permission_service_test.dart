import 'package:doudou/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('PermissionService', () {
    test('isScopedStorage returns true on Android, false elsewhere', () {
      // GetPlatform reflects the host running the test (macOS in dev/CI).
      expect(PermissionService.isScopedStorage, GetPlatform.isAndroid);
    });

    test('getExtStoragePermission always returns true', () async {
      expect(await PermissionService.getExtStoragePermission(), isTrue);
    });
  });
}
