import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [MusicServers, LibrarySnapshots, Clients, Settings])
class DoudouServerDatabase extends _$DoudouServerDatabase {
  DoudouServerDatabase() : super(_open());

  DoudouServerDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // -- settings -----------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> putSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingRow(key: key, value: value),
    );
  }

  // -- music servers ------------------------------------------------------

  Future<List<MusicServerRow>> listMusicServers() =>
      select(musicServers).get();

  Future<MusicServerRow?> findMusicServer(String id) async {
    final q = select(musicServers)..where((t) => t.id.equals(id));
    return q.getSingleOrNull();
  }

  Future<void> upsertMusicServer(MusicServersCompanion entry) =>
      into(musicServers).insertOnConflictUpdate(entry);

  Future<void> deleteMusicServer(String id) {
    return transaction(() async {
      await (delete(librarySnapshots)
            ..where((t) => t.musicServerId.equals(id)))
          .go();
      await (delete(musicServers)..where((t) => t.id.equals(id))).go();
    });
  }

  // -- library snapshots --------------------------------------------------

  Future<LibrarySnapshotRow?> getSnapshot(String serverId, String kind) async {
    final q = select(librarySnapshots)
      ..where((t) => t.musicServerId.equals(serverId))
      ..where((t) => t.kind.equals(kind));
    return q.getSingleOrNull();
  }

  Future<List<LibrarySnapshotRow>> listSnapshots(String serverId) async {
    final q = select(librarySnapshots)
      ..where((t) => t.musicServerId.equals(serverId));
    return q.get();
  }

  Future<void> saveSnapshot({
    required String musicServerId,
    required String kind,
    required String payload,
    required int version,
  }) async {
    await into(librarySnapshots).insertOnConflictUpdate(
      LibrarySnapshotsCompanion.insert(
        musicServerId: musicServerId,
        kind: kind,
        payload: payload,
        version: Value(version),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  // -- clients ------------------------------------------------------------

  Future<List<ClientRow>> listClients() => select(clients).get();

  Future<void> touchClient(String id, String name) async {
    final now = DateTime.now().toUtc();
    final existing = await (select(clients)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      await into(clients).insert(ClientsCompanion.insert(
        id: id,
        name: name,
        firstSeen: now,
        lastSeen: now,
      ));
    } else {
      await (update(clients)..where((t) => t.id.equals(id)))
          .write(ClientsCompanion(lastSeen: Value(now), name: Value(name)));
    }
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'doudou_server'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    final file = File(p.join(dbDir.path, 'doudou_server.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
