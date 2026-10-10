import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wear OS removal', () {
    test('wear dependencies are gone from pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final dep in ['wear_plus', 'wearable_rotary', 'watch_connectivity']) {
        expect(pubspec.contains(dep), isFalse, reason: '$dep still in pubspec');
      }
    });

    test('wear dart entrypoint and ui are deleted', () {
      expect(File('lib/main_wear.dart').existsSync(), isFalse);
      expect(Directory('lib/ui/wear').existsSync(), isFalse);
      expect(File('lib/services/wear_comm_service.dart').existsSync(), isFalse);
      expect(File('lib/services/watch_sync_service.dart').existsSync(), isFalse);
    });

    test('main.dart no longer registers watch sync', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains('watch_sync_service'), isFalse);
      expect(main.contains('WatchSyncService'), isFalse);
    });

    test('gradle has no wear flavor or wearable dependency', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      expect(gradle.contains('play-services-wearable'), isFalse);
      expect(RegExp(r'^\s*wear\s*\{', multiLine: true).hasMatch(gradle), isFalse);
      expect(gradle.contains('kotlin-wearable'), isFalse);
    });

    test('wear build target is gone from CI', () {
      for (final path in [
        '.github/workflows/build.yml',
        'scripts/ci-build.sh',
        'scripts/ci-release.sh',
      ]) {
        final content = File(path).readAsStringSync();
        expect(content.contains('android-wear'), isFalse,
            reason: 'android-wear still referenced in $path');
        expect(content.contains('main_wear'), isFalse,
            reason: 'main_wear still referenced in $path');
      }
    });
  });
}
