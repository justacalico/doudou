import 'package:doudou/server/sync_codec.dart';
import 'package:doudou/server/sync_merge.dart';
import 'package:doudou/server/sync_model.dart';
import 'package:flutter_test/flutter_test.dart';

BoxSnapshot snapshot({
  int rev = 1,
  Map<String, RemoteEntry> entries = const {},
  Map<String, int> deleted = const {},
}) =>
    BoxSnapshot(revision: rev, entries: entries, deleted: deleted);

RemoteEntry entry(Object? value, int ts) =>
    RemoteEntry(value: value, ts: ts);

void main() {
  const now = 1000000;

  group('mergeBoxState', () {
    test('does nothing when nothing changed', () {
      final result = mergeBoxState(
        local: {'a': 1},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf(1), ts: 10),
        },
        dirtyTs: const {},
        remote: snapshot(entries: {'a': entry(1, 10)}),
        now: now,
      );
      expect(result.pushOps, isEmpty);
      expect(result.applyPuts, isEmpty);
      expect(result.applyDeletes, isEmpty);
      expect(result.newBase['a']!.exists, isTrue);
      expect(result.newBase['a']!.ts, 10);
    });

    test('pushes new local keys to the server', () {
      final result = mergeBoxState(
        local: {'a': 1, 'b': 'new'},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf(1), ts: 10),
        },
        dirtyTs: const {},
        remote: snapshot(entries: {'a': entry(1, 10)}),
        now: now,
      );
      expect(result.pushOps, hasLength(1));
      expect(result.pushOps.single.key, 'b');
      expect(result.pushOps.single.value, 'new');
      expect(result.pushOps.single.isDelete, isFalse);
      expect(result.newBase['b']!.exists, isTrue);
    });

    test('pushes locally modified values', () {
      final result = mergeBoxState(
        local: {'a': 2},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf(1), ts: 10),
        },
        dirtyTs: const {},
        remote: snapshot(entries: {'a': entry(1, 10)}),
        now: now,
      );
      expect(result.pushOps.single.value, 2);
      expect(result.newBase['a']!.ts, now);
    });

    test('pushes local deletes', () {
      final result = mergeBoxState(
        local: const {},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf(1), ts: 10),
        },
        dirtyTs: const {},
        remote: snapshot(entries: {'a': entry(1, 10)}),
        now: now,
      );
      expect(result.pushOps.single.isDelete, isTrue);
      expect(result.newBase['a']!.exists, isFalse);
    });

    test('applies new remote keys locally', () {
      final result = mergeBoxState(
        local: const {},
        base: const {},
        dirtyTs: const {},
        remote: snapshot(entries: {'a': entry('remote', 50)}),
        now: now,
      );
      expect(result.pushOps, isEmpty);
      expect(result.applyPuts['a'], 'remote');
      expect(result.newBase['a']!.ts, 50);
    });

    test('applies remote tombstones locally', () {
      final result = mergeBoxState(
        local: {'a': 1},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf(1), ts: 10),
        },
        dirtyTs: const {},
        remote: snapshot(deleted: {'a': 60}),
        now: now,
      );
      expect(result.applyDeletes, contains('a'));
      expect(result.newBase['a']!.exists, isFalse);
      expect(result.newBase['a']!.ts, 60);
    });

    test('conflict: newer remote wins over older local change', () {
      final result = mergeBoxState(
        local: {'a': 'local'},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf('base'), ts: 10),
        },
        // change detected 2 minutes ago, remote write is newer
        dirtyTs: const {'a': now - 2000},
        remote: snapshot(entries: {'a': entry('remote', now - 1000)}),
        now: now,
      );
      expect(result.pushOps, isEmpty);
      expect(result.applyPuts['a'], 'remote');
      expect(result.newBase['a']!.ts, now - 1000);
    });

    test('conflict: newer local wins over older remote', () {
      final result = mergeBoxState(
        local: {'a': 'local'},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf('base'), ts: 10),
        },
        dirtyTs: const {'a': now - 500},
        remote: snapshot(entries: {'a': entry('remote', now - 1000)}),
        now: now,
      );
      expect(result.pushOps.single.value, 'local');
      expect(result.applyPuts, isEmpty);
    });

    test('conflict: local delete vs newer remote write keeps remote', () {
      final result = mergeBoxState(
        local: const {},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf('base'), ts: 10),
        },
        dirtyTs: const {'a': now - 2000},
        remote: snapshot(entries: {'a': entry('remote', now - 1000)}),
        now: now,
      );
      expect(result.pushOps, isEmpty);
      expect(result.applyPuts['a'], 'remote');
    });

    test('missing remote key without tombstone heals by pushing local', () {
      // server was wiped: key exists in base and local but not remotely
      final result = mergeBoxState(
        local: {'a': 1},
        base: {
          'a': KeyBase(exists: true, hash: _hashOf(1), ts: 10),
        },
        dirtyTs: const {},
        remote: snapshot(),
        now: now,
      );
      expect(result.applyDeletes, isEmpty);
      expect(result.pushOps.single.key, 'a');
      expect(result.pushOps.single.isDelete, isFalse);
    });

    test('first sync with empty base pushes local and pulls remote', () {
      final result = mergeBoxState(
        local: {'local': 1},
        base: const {},
        dirtyTs: const {},
        remote: snapshot(entries: {'remote': entry(2, 50)}),
        now: now,
      );
      expect(result.pushOps.map((o) => o.key), contains('local'));
      expect(result.applyPuts['remote'], 2);
    });

    test('keeps base for keys absent everywhere', () {
      final result = mergeBoxState(
        local: const {},
        base: const {},
        dirtyTs: const {},
        remote: snapshot(),
        now: now,
      );
      expect(result.newBase, isEmpty);
    });
  });
}

String _hashOf(Object? value) => valueHash(value);
