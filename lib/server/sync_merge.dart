import 'sync_codec.dart';
import 'sync_model.dart';

/// What the client last knew about a key: whether it existed after the last
/// sync, the hash of its value, and the winning timestamp at that point.
class KeyBase {
  const KeyBase({required this.exists, this.hash, required this.ts});

  final bool exists;
  final String? hash;
  final int ts;

  Map<String, Object?> toJson() =>
      {'e': exists, if (hash != null) 'h': hash, 'ts': ts};

  static KeyBase? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return KeyBase(
      exists: raw['e'] == true,
      hash: raw['h']?.toString(),
      ts: (raw['ts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Outcome of merging one box. Pure data so the whole merge is unit testable
/// without Hive, GetX or the network.
class BoxMergeResult {
  BoxMergeResult({
    required this.pushOps,
    required this.applyPuts,
    required this.applyDeletes,
    required this.newBase,
    required this.newDirtyTs,
    required this.newDirtyKeys,
  });

  /// Ops to push to the server for keys where local won.
  final List<SyncOp> pushOps;

  /// Remote winning values to write into the local box.
  final Map<String, Object?> applyPuts;

  /// Keys the remote tombstoned that should be deleted locally.
  final Set<String> applyDeletes;

  /// Per key base state to persist after the merge completes.
  final Map<String, KeyBase> newBase;

  /// Keys that were locally dirty at merge time mapped to their dirty since
  /// timestamp. Persisted so conflicts stay deterministic across sync runs.
  final Map<String, int> newDirtyTs;

  /// Keys detected as locally changed during this merge (before resolution).
  final Set<String> newDirtyKeys;
}

/// Three way merge of one box.
///
/// [local] is the current Hive content (string keys). [base] is the state
/// recorded after the last successful sync. [dirtyTs] holds when each still
/// unresolved local change was first noticed. [remote] is the server snapshot.
///
/// Rules:
/// - Remote deletes only propagate through tombstones. A key that is missing
///   on the server without a tombstone means the server lost it (wipe, fresh
///   import), so the client pushes its copy back instead of deleting locally.
/// - When both sides changed a key, last write wins: remote timestamp versus
///   the local dirty-since timestamp ([now] for changes first seen this run).
BoxMergeResult mergeBoxState({
  required Map<String, Object?> local,
  required Map<String, KeyBase> base,
  required Map<String, int> dirtyTs,
  required BoxSnapshot remote,
  required int now,
}) {
  final pushOps = <SyncOp>[];
  final applyPuts = <String, Object?>{};
  final applyDeletes = <String>{};
  final newBase = <String, KeyBase>{};
  final newDirtyTs = <String, int>{};
  final newDirtyKeys = <String>{};

  final keys = <String>{
    ...local.keys,
    ...base.keys,
    ...remote.entries.keys,
    ...remote.deleted.keys,
  };

  for (final key in keys) {
    final baseK = base[key] ?? const KeyBase(exists: false, ts: 0);
    final localExists = local.containsKey(key);
    final localHash = localExists ? valueHash(local[key]) : null;
    final localChanged =
        localExists != baseK.exists || (localExists && localHash != baseK.hash);

    final remoteEntry = remote.entries[key];
    final remoteDeleteTs = remote.deleted[key];
    final remoteExists = remoteEntry != null;
    // Key we synced before that the server no longer knows about and never
    // tombstoned: the server side lost it, so heal rather than delete.
    final remoteForgot =
        !remoteExists && remoteDeleteTs == null && baseK.exists;
    final remoteTs = remoteExists ? remoteEntry.ts : (remoteDeleteTs ?? 0);
    final remoteChanged = remoteForgot ||
        (remoteExists
            ? (!baseK.exists || remoteTs != baseK.ts)
            : remoteDeleteTs != null && remoteDeleteTs != baseK.ts);

    if (!localChanged && !remoteChanged) {
      newBase[key] = baseK;
      continue;
    }

    if (localChanged) {
      newDirtyKeys.add(key);
      newDirtyTs[key] = dirtyTs[key] ?? now;
    }
    final dirtySince = dirtyTs[key] ?? now;

    final localWins =
        remoteForgot ? localExists : (localChanged && dirtySince >= remoteTs);

    if (localWins) {
      final pushTs = localChanged ? dirtySince : (baseK.ts > now ? baseK.ts : now);
      if (localExists) {
        pushOps.add(SyncOp.put(key, local[key], pushTs));
      } else {
        pushOps.add(SyncOp.delete(key, pushTs));
      }
      newBase[key] =
          KeyBase(exists: localExists, hash: localHash, ts: pushTs);
      newDirtyTs.remove(key);
    } else if (remoteChanged && !remoteForgot) {
      if (remoteExists) {
        applyPuts[key] = remoteEntry.value;
        newBase[key] = KeyBase(
            exists: true, hash: valueHash(remoteEntry.value), ts: remoteTs);
      } else {
        if (localExists) applyDeletes.add(key);
        newBase[key] = KeyBase(exists: false, ts: remoteTs);
      }
      newDirtyTs.remove(key);
    } else {
      // remoteForgot while the key is also gone locally: both sides dropped
      // it, just record it as deleted.
      newBase[key] =
          KeyBase(exists: false, ts: baseK.ts > remoteTs ? baseK.ts : remoteTs);
      newDirtyTs.remove(key);
    }
  }

  return BoxMergeResult(
    pushOps: pushOps,
    applyPuts: applyPuts,
    applyDeletes: applyDeletes,
    newBase: newBase,
    newDirtyTs: newDirtyTs,
    newDirtyKeys: newDirtyKeys,
  );
}
