import 'package:doudou/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionService', () {
    test('isScopedStorage is a boolean', () {
      expect(PermissionService.isScopedStorage, isA<bool>());
    });

    test('getExtStoragePermission always returns true', () async {
      expect(await PermissionService.getExtStoragePermission(), isTrue);
    });
  });
}
