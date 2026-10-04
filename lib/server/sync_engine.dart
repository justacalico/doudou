import 'sync_client.dart';
import 'sync_codec.dart';
import 'sync_merge.dart';

/// Reads and persists the client's per-box sync bookkeeping.
abstract class SyncStateStore {
  Map<String, KeyBase> readBase(String boxName);
  Map<String, int> readDirtyTs(String boxName);
  int readRevision(String boxName);
  Future<void> write(
    String boxName, {
    required int revision,
    required Map<String, KeyBase> base,
    required Map<String, int> dirtyTs,
  });
}

/// Reads and mutates a local box's content.
abstract class LocalBoxStore {
  /// Current contents as string keys.
  Future<Map<String, Object?>> readAll(String boxName);
  Future<void> applyRemote(
    String boxName, {
    required Map<String, Object?> puts,
    required Set<String> deletes,
  });
}

/// Runs the client side of one box sync cycle against a server snapshot:
/// diff against the stored base, apply remote winners, push local winners,
/// persist the new base. Storage and transport independent so the whole
/// thing is testable with in-memory fakes and a real server.
class BoxSyncEngine {
  BoxSyncEngine({
    required this.client,
    required this.state,
    required this.local,
    int Function()? now,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final DoudouSyncClient client;
  final SyncStateStore state;
  final LocalBoxStore local;
  final int Function() _now;

  /// Syncs [boxName]. [remoteRevision] is the rev reported by /api/boxes when
  /// known, used to skip the snapshot fetch when nothing moved anywhere.
  /// Returns true when remote changes were applied locally.
  Future<bool> syncBox(String boxName, {int? remoteRevision}) async {
    final base = state.readBase(boxName);
    final dirtyTs = state.readDirtyTs(boxName);
    final storedRev = state.readRevision(boxName);
    final localEntries = await local.readAll(boxName);

    if (!_hasLocalChanges(localEntries, base) &&
        storedRev >= 0 &&
        remoteRevision != null &&
        remoteRevision == storedRev) {
      return false;
    }

    final remote = await client.getBox(boxName);
    final merge = mergeBoxState(
      local: localEntries,
      base: base,
      dirtyTs: dirtyTs,
      remote: remote,
      now: _now(),
    );

    final appliedRemote =
        merge.applyPuts.isNotEmpty || merge.applyDeletes.isNotEmpty;
    if (appliedRemote) {
      await local.applyRemote(boxName,
          puts: merge.applyPuts, deletes: merge.applyDeletes);
    }

    var rev = remote.revision;
    if (merge.pushOps.isNotEmpty) {
      rev = await client.pushOps(boxName, merge.pushOps);
    }

    await state.write(
      boxName,
      revision: rev,
      base: merge.newBase,
      dirtyTs: merge.newDirtyTs,
    );
    return appliedRemote;
  }

  bool _hasLocalChanges(
      Map<String, Object?> local, Map<String, KeyBase> base) {
    for (final entry in local.entries) {
      final b = base[entry.key];
      if (b == null || !b.exists || b.hash != valueHash(entry.value)) {
        return true;
      }
    }
    for (final entry in base.entries) {
      if (entry.value.exists && !local.containsKey(entry.key)) return true;
    }
    return false;
  }
}
