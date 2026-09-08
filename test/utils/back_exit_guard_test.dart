import 'package:doudou/utils/back_exit_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackExitGuard', () {
    test('first press does not confirm the exit', () {
      final guard = BackExitGuard();

      expect(guard.confirmExit(DateTime(2026, 1, 1)), isFalse);
    });

    test('a second press inside the window confirms the exit', () {
      final guard = BackExitGuard();
      final first = DateTime(2026, 1, 1);

      guard.confirmExit(first);

      expect(
        guard.confirmExit(first.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('a press after the window has expired does not confirm', () {
      final guard = BackExitGuard();
      final first = DateTime(2026, 1, 1);

      guard.confirmExit(first);

      expect(
        guard.confirmExit(first.add(const Duration(seconds: 3))),
        isFalse,
      );
    });

    test('a press right at the window boundary still confirms', () {
      final guard = BackExitGuard(window: const Duration(seconds: 2));
      final first = DateTime(2026, 1, 1);

      guard.confirmExit(first);

      expect(
        guard.confirmExit(first.add(const Duration(seconds: 2))),
        isTrue,
      );
    });

    test('after confirming, the next press starts a fresh window', () {
      final guard = BackExitGuard();
      var now = DateTime(2026, 1, 1);

      guard.confirmExit(now);
      now = now.add(const Duration(seconds: 1));
      expect(guard.confirmExit(now), isTrue);

      now = now.add(const Duration(seconds: 1));
      expect(guard.confirmExit(now), isFalse);
    });
  });
}
