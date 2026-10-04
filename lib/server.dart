/// Headless sync server support.
///
/// Everything under `server/` is pure Dart (no Flutter imports) so it runs
/// both inside the app binary (`-server` flag) and standalone via
/// `dart run bin/doudou_server.dart`.
library;

export 'server/doudou_server.dart';
export 'server/runner.dart';
export 'server/sync_boxes.dart';
export 'server/sync_client.dart';
export 'server/sync_codec.dart';
export 'server/sync_merge.dart';
export 'server/sync_model.dart';
export 'server/hmb_archive.dart';
