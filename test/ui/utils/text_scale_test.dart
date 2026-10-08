import 'package:doudou/ui/utils/text_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appTextScaler', () {
    test('keeps the default scale', () {
      final scaler = appTextScaler(const TextScaler.linear(1.0));
      expect(scaler.scale(10), 10);
    });

    test('honours large accessibility text settings', () {
      // The old cap of 1.1 made system large-text settings nearly useless.
      final scaler = appTextScaler(const TextScaler.linear(1.5));
      expect(scaler.scale(10), 15);
    });

    test('still caps extreme scale factors', () {
      final scaler = appTextScaler(const TextScaler.linear(3.0));
      expect(scaler.scale(10), 16);
    });

    test('does not shrink below the minimum', () {
      final scaler = appTextScaler(const TextScaler.linear(0.5));
      expect(scaler.scale(10), 10);
    });
  });
}
