import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:doudou/mcp/mcp_bundle.dart';
import 'package:doudou/mcp/mcp_http_server.dart';
import 'package:doudou/mcp/mcp_server.dart';
import 'package:doudou/mcp/mcp_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nodeAvailable = Process.runSync('node', ['--version']).exitCode == 0;

  Map<String, Object?> manifestOf(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('manifest.json');
    expect(entry, isNotNull);
    return jsonDecode(utf8.decode(entry!.content as List<int>))
        as Map<String, Object?>;
  }

  group('buildMcpBundle', () {
    test('writes a valid manifest pointing at the listen url', () {
      final bytes = buildMcpBundle(
          url: 'http://127.0.0.1:9999/mcp', version: '23.0.0');

      final manifest = manifestOf(bytes);
      expect(manifest['manifest_version'], '0.3');
      expect(manifest['name'], 'doudou');
      expect(manifest['version'], '23.0.0');
      expect(manifest['description'], isNotEmpty);
      expect((manifest['author'] as Map)['name'], isNotEmpty);

      final server = manifest['server'] as Map<String, Object?>;
      expect(server['type'], 'node');
      expect(server['entry_point'], 'server/bridge.js');

      final mcpConfig = server['mcp_config'] as Map<String, Object?>;
      expect(mcpConfig['command'], 'node');
      expect(mcpConfig['args'],
          contains(r'${__dirname}/server/bridge.js'));
      expect((mcpConfig['env'] as Map)['DOUDOU_MCP_URL'],
          'http://127.0.0.1:9999/mcp');
    });

    test('bundles the stdio bridge script', () {
      final bytes =
          buildMcpBundle(url: 'http://127.0.0.1:8462/mcp', version: '1.0.0');
      final archive = ZipDecoder().decodeBytes(bytes);

      final bridge = archive.findFile('server/bridge.js');
      expect(bridge, isNotNull);
      final script = utf8.decode(bridge!.content as List<int>);
      expect(script, contains('DOUDOU_MCP_URL'));
      expect(script, contains("require('node:http')"));
      expect(script, equals(bridgeScript));
    });
  });

  test(
    'the bundled bridge proxies stdio JSON-RPC to the HTTP endpoint',
    () async {
      final dir = await Directory.systemTemp.createTemp('doudou_mcpb_test');
      try {
        await File('${dir.path}/bridge.js').writeAsString(bridgeScript);

        final http = McpHttpServer(DoudouMcpServer(
          serverName: 'doudou-test',
          serverVersion: '9.9.9',
          tools: [
            McpTool(
              name: 'echo',
              description: 'Echoes arguments',
              inputSchema: const {'type': 'object'},
              handler: (args) async => {'echoed': args},
            ),
          ],
        ));
        await http.start(port: 0);

        final process = await Process.start(
          'node',
          ['${dir.path}/bridge.js'],
          environment: {
            'DOUDOU_MCP_URL': 'http://127.0.0.1:${http.port}/mcp',
          },
        );

        process.stdin.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '0'},
          },
        }));
        process.stdin.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/call',
          'params': {
            'name': 'echo',
            'arguments': {'hello': 'world'},
          },
        }));
        await process.stdin.close();

        final responses = await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .map(jsonDecode)
            .toList();

        expect(responses, hasLength(2));
        final init = responses
            .firstWhere((r) => (r as Map)['id'] == 1) as Map;
        expect(init['result']['serverInfo']['name'], 'doudou-test');
        final call = responses
            .firstWhere((r) => (r as Map)['id'] == 2) as Map;
        expect(jsonEncode(call['result']), contains('world'));

        await http.stop();
        process.kill();
      } finally {
        await dir.delete(recursive: true);
      }
    },
    skip: !nodeAvailable,
  );
}
