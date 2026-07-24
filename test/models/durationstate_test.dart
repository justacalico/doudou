import 'package:doudou/models/durationstate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressBarState', () {
    test('stores provided durations', () {
      final state = ProgressBarState(
        current: const Duration(seconds: 10),
        buffered: const Duration(seconds: 20),
        total: const Duration(seconds: 100),
      );

      expect(state.current, const Duration(seconds: 10));
      expect(state.buffered, const Duration(seconds: 20));
      expect(state.total, const Duration(seconds: 100));
    });

    test('accepts zero durations', () {
      final state = ProgressBarState(
        current: Duration.zero,
        buffered: Duration.zero,
        total: Duration.zero,
      );

      expect(state.current, Duration.zero);
      expect(state.buffered, Duration.zero);
      expect(state.total, Duration.zero);
    });

    test('fields are mutable', () {
      final state = ProgressBarState(
        current: const Duration(seconds: 1),
        buffered: const Duration(seconds: 2),
        total: const Duration(seconds: 3),
      );

      state.current = const Duration(seconds: 50);
      state.buffered = const Duration(seconds: 60);
      state.total = const Duration(seconds: 70);

      expect(state.current, const Duration(seconds: 50));
      expect(state.buffered, const Duration(seconds: 60));
      expect(state.total, const Duration(seconds: 70));
    });
  });
}
