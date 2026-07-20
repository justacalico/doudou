import 'dart:io';

import 'package:flutter/widgets.dart';

import 'src/cli/args.dart';
import 'src/cli/commands.dart';

/// Entry point for the doudou-server CLI binary.
///
/// This is a headless Flutter desktop app: the Flutter binding is initialised
/// (so plugins like sqlite3_flutter_libs and path_provider work on every
/// desktop platform) but no widget tree is ever mounted. The CLI parser
/// dispatches to the requested command and the process exits when done.
Future<void> main(List<String> argv) async {
  WidgetsFlutterBinding.ensureInitialized();
  final cmd = CliCommand.parse(argv);
  await runCommand(cmd);
  // The desktop runners keep a message loop alive after main returns, so
  // force-exit once the command is done. The daemon path returns here only
  // after it has been stopped.
  exit(0);
}
