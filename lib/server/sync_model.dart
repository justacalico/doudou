import 'sync_codec.dart';

/// A single remote box entry as it travels over the wire: a JSON safe value
/// plus the millisecond timestamp of the last write that won.
class RemoteEntry {
  RemoteEntry({required this.value, required this.ts});

  final Object? value; // already decoded via fromWireValue
  final int ts;
}

/// One mutation a client pushes to the server, or that the server records.
class SyncOp {
  SyncOp({required this.key, this.value, this.isDelete = false, this.ts = 0});

  factory SyncOp.put(String key, Object? value, int ts) =>
      SyncOp(key: key, value: value, ts: ts);

  factory SyncOp.delete(String key, int ts) =>
      SyncOp(key: key, isDelete: true, ts: ts);

  final String key;
  final Object? value; // plain Hive value; encoded by toWireValue on the wire
  final bool isDelete;
  final int ts;

  Map<String, Object?> toJson() => {
        'k': key,
        if (!isDelete) 'v': toWireValue(value),
        'del': isDelete,
        'ts': ts,
      };

  static SyncOp? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['k'];
    if (key == null) return null;
    return SyncOp(
      key: key.toString(),
      value: raw.containsKey('v') ? fromWireValue(raw['v']) : null,
      isDelete: raw['del'] == true,
      ts: (raw['ts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Full snapshot of a server box: live entries plus delete tombstones.
class BoxSnapshot {
  BoxSnapshot({
    required this.revision,
    required this.entries,
    required this.deleted,
  });

  final int revision;
  final Map<String, RemoteEntry> entries;
  final Map<String, int> deleted;

  static BoxSnapshot fromJson(Map<String, Object?> json) {
    final entries = <String, RemoteEntry>{};
    final rawEntries = json['entries'];
    if (rawEntries is Map) {
      rawEntries.forEach((k, v) {
        if (v is Map) {
          entries[k.toString()] = RemoteEntry(
            value: fromWireValue(v['v']),
            ts: (v['ts'] as num?)?.toInt() ?? 0,
          );
        }
      });
    }
    final deleted = <String, int>{};
    final rawDeleted = json['deleted'];
    if (rawDeleted is Map) {
      rawDeleted.forEach((k, v) {
        if (v is num) deleted[k.toString()] = v.toInt();
      });
    }
    return BoxSnapshot(
      revision: (json['rev'] as num?)?.toInt() ?? 0,
      entries: entries,
      deleted: deleted,
    );
  }
}
