import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
  const resDir = 'android/app/src/main/res';

  group('android launcher assets', () {
    for (final density in densities) {
      test('mipmap-$density foreground matches drawable foreground', () {
        final mipmap =
            File('$resDir/mipmap-$density/ic_launcher_foreground.png');
        final drawable =
            File('$resDir/drawable-$density/ic_launcher_foreground.png');
        expect(mipmap.existsSync(), isTrue);
        expect(drawable.existsSync(), isTrue);
        expect(mipmap.readAsBytesSync(), drawable.readAsBytesSync());
      });

      test('mipmap-$density monochrome exists and is non-trivial', () {
        final mono = File('$resDir/mipmap-$density/ic_launcher_monochrome.png');
        expect(mono.existsSync(), isTrue);
        expect(mono.lengthSync(), greaterThan(1024));
      });
    }

    test('adaptive icon declares a monochrome layer', () {
      final xml =
          File('$resDir/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
      expect(xml, contains('<monochrome>'));
      expect(xml, contains('@mipmap/ic_launcher_monochrome'));
    });
  });
}
