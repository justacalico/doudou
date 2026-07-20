import 'dart:io';

import 'package:args/args.dart';

/// Result of parsing the doudou-server CLI. Exactly one command flag is set.
class CliCommand {
  CliCommand._({
    required this.kind,
    this.host,
    this.port,
    this.username,
    this.password,
  });

  final CliKind kind;
  final String? host;
  final int? port;
  final String? username;
  final String? password;

  static CliCommand parse(List<String> argv) {
    // `-set login <user> <pass>` doesn't fit the args package's option model,
    // so pull it out and handle it before the parser sees it.
    if (argv.isNotEmpty && (argv.first == '-set' || argv.first == '--set')) {
      return _parseSetLogin(argv.skip(1).toList());
    }

    // The args package expects `--` for long flags, but the doudou-server CLI
    // uses single-dash long flags (e.g. `-start`). Normalise so the parser
    // sees `--start` etc. Short single-letter flags like `-h` are left alone.
    final normalised = argv.map((a) {
      if (a.startsWith('-') && !a.startsWith('--') && a.length > 2) {
        return '-$a';
      }
      return a;
    }).toList();

    final parser = _buildParser();

    ArgResults results;
    try {
      results = parser.parse(normalised);
    } on ArgParserException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(parser.usage);
      exitWithUsage(parser);
      return CliCommand._(kind: CliKind.help); // unreachable
    }

    if (results['help'] as bool) {
      stdout.writeln(_usage(parser));
      return CliCommand._(kind: CliKind.help);
    }

    final host = results['host'] as String?;
    final portStr = results['port'] as String?;
    int? port;
    if (portStr != null) {
      port = int.tryParse(portStr);
      if (port == null) {
        stderr.writeln('invalid port: $portStr');
        exitWithUsage(parser);
      }
    }

    if (results['start'] as bool) {
      return CliCommand._(kind: CliKind.start, host: host, port: port);
    }
    if (results['stop'] as bool) {
      return CliCommand._(kind: CliKind.stop);
    }
    if (results['clients'] as bool) {
      return CliCommand._(kind: CliKind.clients);
    }
    if (results['status'] as bool) {
      return CliCommand._(kind: CliKind.status);
    }
    if (results['health'] as bool) {
      return CliCommand._(kind: CliKind.health);
    }

    stdout.writeln(_usage(parser));
    return CliCommand._(kind: CliKind.help);
  }

  static CliCommand _parseSetLogin(List<String> rest) {
    final parser = _buildParser();
    if (rest.isEmpty || rest.first != 'login') {
      stderr.writeln('only `set login <user> <pass>` is supported');
      exitWithUsage(parser);
    }
    final args = rest.skip(1).toList();
    if (args.length < 2) {
      stderr.writeln('usage: doudou-server -set login <user> <pass>');
      exitWithUsage(parser);
    }
    return CliCommand._(
      kind: CliKind.setLogin,
      username: args[0],
      password: args[1],
    );
  }

  static ArgParser _buildParser() => ArgParser()
    ..addFlag('start', negatable: false, help: 'Start the server in the foreground.')
    ..addFlag('stop', negatable: false, help: 'Stop a running server on this machine.')
    ..addFlag('clients', negatable: false, help: 'List clients that have synced with this server.')
    ..addFlag('status', negatable: false, help: 'Show general info about this server.')
    ..addFlag('health', negatable: false, help: 'Probe the running server health endpoint.')
    ..addOption('host', help: 'Host to bind to (default 0.0.0.0).')
    ..addOption('port', help: 'Port to bind to (default 7427).')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  static void exitWithUsage(ArgParser parser) {
    stdout.writeln(_usage(parser));
    exit(1);
  }

  static String _usage(ArgParser parser) {
    return [
      'doudou-server - headless sync server for doudou',
      '',
      'Usage: doudou-server <command> [options]',
      '',
      'Commands:',
      '  -start                  Start the server (foreground)',
      '  -stop                   Stop a running server on this machine',
      '  -clients                Show clients that have synced',
      '  -status                 Show general info',
      '  -health                 Probe the running server health endpoint',
      '  -set login <user> <p>   Set the shared password clients must use',
      '',
      'Options:',
      parser.usage,
    ].join('\n');
  }
}

enum CliKind { start, stop, clients, status, health, setLogin, help }
