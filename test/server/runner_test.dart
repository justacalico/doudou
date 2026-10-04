import 'package:doudou/server/doudou_server.dart';
import 'package:doudou/server/runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isServerInvocation', () {
    test('detects -server among other flags', () {
      expect(isServerInvocation(['-server']), isTrue);
      expect(
          isServerInvocation(['-server', '--port', '9000']), isTrue);
      expect(
          isServerInvocation(['--port', '9000', '-server']), isTrue);
    });

    test('rejects lookalike flags and empty args', () {
      expect(isServerInvocation([]), isFalse);
      expect(isServerInvocation(['--server']), isFalse);
      expect(isServerInvocation(['-serverx']), isFalse);
      expect(isServerInvocation(['-s']), isFalse);
    });
  });

  group('parseServerArgs', () {
    test('defaults to the sync port and a home data dir', () {
      final parsed = parseServerArgs(['-server'])!;
      expect(parsed.port, kDefaultSyncPort);
      expect(parsed.bind, '0.0.0.0');
      expect(parsed.dataDir, contains('.doudou-server'));
      expect(parsed.imports, isEmpty);
      expect(parsed.help, isFalse);
    });

    test('parses -importdb paths, repeatable', () {
      final parsed = parseServerArgs(
          ['-server', '-importdb', '/tmp/a.hmb', '-importdb', 'b.hmb'])!;
      expect(parsed.imports, ['/tmp/a.hmb', 'b.hmb']);
    });

    test('parses port, bind, data dir and password', () {
      final parsed = parseServerArgs([
        '--port', '9100',
        '--bind', '127.0.0.1',
        '--data-dir', '/tmp/doudou-srv',
        '--password', 'pw123',
      ])!;
      expect(parsed.port, 9100);
      expect(parsed.bind, '127.0.0.1');
      expect(parsed.dataDir, '/tmp/doudou-srv');
      expect(parsed.password, 'pw123');
    });

    test('handles --help', () {
      expect(parseServerArgs(['--help'])!.help, isTrue);
      expect(parseServerArgs(['-h'])!.help, isTrue);
    });

    test('rejects missing values and invalid input', () {
      expect(parseServerArgs(['-importdb']), isNull);
      expect(parseServerArgs(['--port']), isNull);
      expect(parseServerArgs(['--port', 'abc']), isNull);
      expect(parseServerArgs(['--port', '99999']), isNull);
      expect(parseServerArgs(['--port', '0']), isNull);
      expect(parseServerArgs(['--data-dir']), isNull);
      expect(parseServerArgs(['--password']), isNull);
      expect(parseServerArgs(['--bogus-flag']), isNull);
    });

    test('positional arguments are ignored', () {
      final parsed = parseServerArgs(['-server', 'extra'])!;
      expect(parsed.imports, isEmpty);
    });
  });
}
