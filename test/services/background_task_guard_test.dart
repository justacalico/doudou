import 'dart:async';

import 'package:doudou/services/background_task_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> begins;
  late List<int> ends;
  late int nextId;
  late bool enabled;

  BackgroundTaskGuard buildGuard({
    Duration holdLimit = const Duration(seconds: 28),
    Future<int?> Function(String name)? begin,
  }) {
    return BackgroundTaskGuard(
      begin: begin ??
          (name) async {
            begins.add(name);
            return ++nextId;
          },
      end: (id) async => ends.add(id),
      enabled: () => enabled,
      holdLimit: holdLimit,
    );
  }

  setUp(() {
    begins = [];
    ends = [];
    nextId = 0;
    enabled = true;
  });

  test('acquire begins a native task and release ends it once', () async {
    final guard = buildGuard();

    final token = await guard.acquire();

    expect(begins, ['playback-transition']);
    expect(guard.isHeld, isTrue);

    await guard.release(token);
    expect(ends, [1]);
    expect(guard.isHeld, isFalse);

    await guard.release(token);
    expect(ends, [1]);
  });

  test('each acquire gets its own task so overlapping sections stay covered',
      () async {
    final guard = buildGuard();

    final first = await guard.acquire(name: 'a');
    final second = await guard.acquire(name: 'b');

    expect(begins, ['a', 'b']);
    expect(guard.activeHoldCount, 2);

    await guard.release(first);
    expect(ends, [1]);
    expect(guard.isHeld, isTrue);

    await guard.release(second);
    expect(ends, [1, 2]);
    expect(guard.isHeld, isFalse);
  });

  test('releaseAll ends every outstanding hold', () async {
    final guard = buildGuard();

    await guard.acquire(name: 'a');
    await guard.acquire(name: 'b');
    await guard.releaseAll();

    expect(ends, [1, 2]);
    expect(guard.isHeld, isFalse);
  });

  test('disabled platforms track the hold without touching the channel',
      () async {
    enabled = false;
    final guard = buildGuard();

    final token = await guard.acquire();
    expect(guard.isHeld, isTrue);
    expect(begins, isEmpty);

    await guard.release(token);
    expect(ends, isEmpty);
    expect(guard.isHeld, isFalse);
  });

  test('a null native id means the platform denied the task', () async {
    final guard = buildGuard(begin: (name) async => null);

    final token = await guard.acquire();
    expect(guard.isHeld, isTrue);

    await guard.release(token);
    expect(ends, isEmpty);
    expect(guard.isHeld, isFalse);
  });

  test('a hold force-releases after the limit and reports the expiry',
      () async {
    var expired = 0;
    final guard = buildGuard(holdLimit: const Duration(milliseconds: 20))
      ..onExpired = () => expired++;

    await guard.acquire();
    expect(guard.isHeld, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(expired, 1);
    expect(ends, [1]);
    expect(guard.isHeld, isFalse);
  });

  test('releaseAll while the platform begin is in flight still ends the task',
      () async {
    final gate = Completer<int?>();
    final guard = buildGuard(begin: (name) => gate.future);

    final pending = guard.acquire();
    expect(guard.isHeld, isTrue);

    await guard.releaseAll();
    expect(guard.isHeld, isFalse);
    expect(ends, isEmpty);

    gate.complete(9);
    await pending;

    expect(ends, [9]);
    expect(guard.isHeld, isFalse);
  });
}
