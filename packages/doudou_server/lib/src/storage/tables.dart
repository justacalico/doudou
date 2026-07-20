import 'package:drift/drift.dart';

/// A music server that a doudou client has registered with this doudou-server.
/// Only the URL and display metadata are stored here. Credentials never leave
/// the client that owns them.
@DataClassName('MusicServerRow')
class MusicServers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get url => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-library snapshots keyed by (musicServerId, kind). The payload is the
/// JSON-encoded library as the client last pushed it. The server treats this
/// as the source of truth and hands it back to any client that asks.
@DataClassName('LibrarySnapshotRow')
class LibrarySnapshots extends Table {
  TextColumn get musicServerId => text()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {musicServerId, kind};
}

/// A doudou client that has authenticated with this server at least once.
@DataClassName('ClientRow')
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get firstSeen => dateTime()();
  DateTimeColumn get lastSeen => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key/value bag for server settings (shared password hash, listen host/port).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
