import 'dart:collection';
import 'dart:io';

/// One line in the server log.
class ServerLogEntry {
  ServerLogEntry({
    required this.seq,
    required this.ts,
    required this.level,
    required this.message,
  });

  final int seq;
  final int ts;
  final String level;
  final String message;

  Map<String, Object?> toJson() =>
      {'seq': seq, 'ts': ts, 'level': level, 'msg': message};
}

/// In-memory ring buffer of server events shown by the web UI. Entries are
/// numbered so clients can poll with `?after=<seq>` and only receive what is
/// new. Everything logged here also goes to stdout so headless deployments
/// keep their normal log output.
class ServerLog {
  ServerLog({this.capacity = 1000, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final int capacity;
  final DateTime Function() _clock;
  final _entries = ListQueue<ServerLogEntry>();
  var _seq = 0;

  void info(String message) => _add('info', message);
  void warn(String message) => _add('warn', message);
  void error(String message) => _add('error', message);

  void _add(String level, String message) {
    final entry = ServerLogEntry(
      seq: ++_seq,
      ts: _clock().millisecondsSinceEpoch,
      level: level,
      message: message,
    );
    _entries.add(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    (level == 'error' ? stderr : stdout).writeln('[doudou-server] $message');
  }

  /// Entries with a sequence number greater than [after], and the current
  /// latest sequence.
  ({List<ServerLogEntry> entries, int latest}) since(int after) => (
        entries: _entries.where((e) => e.seq > after).toList(),
        latest: _seq,
      );
}
