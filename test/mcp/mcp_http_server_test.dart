import 'dart:convert';
import 'dart:io';

import 'package:doudou/mcp/mcp_http_server.dart';
import 'package:doudou/mcp/mcp_protocol.dart';
import 'package:doudou/mcp/mcp_server.dart';
import 'package:doudou/mcp/mcp_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late McpHttpServer http;
  late HttpClient client;

  Future<void> boot() async {
    final engine = DoudouMcpServer(
      serverName: 'doudou-test',
      serverVersion: '1.0.0',
      tools: [
        McpTool(
          name: 'ping_tool',
          description: 'Always ok',
          inputSchema: const {'type': 'object'},
          handler: (_) async => {'pong': true},
        ),
      ],
    );
    http = McpHttpServer(engine);
    await http.start(port: 0);
  }

  setUp(() async {
    client = HttpClient();
    await boot();
  });

  tearDown(() async {
    client.close(force: true);
    await http.stop();
  });

  Future<(int, String)> post(String path, Object? body,
      {String contentType = 'application/json'}) async {
    final req =
        await client.post('127.0.0.1', http.port, path);
    req.headers.contentType = ContentType.parse(contentType);
    req.write(body is String ? body : jsonEncode(body));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return (res.statusCode, text);
  }

  Future<(int, String)> send(String method, String path) async {
    final req = await client.open(method, '127.0.0.1', http.port, path);
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return (res.statusCode, text);
  }

  test('POST initialize returns a JSON-RPC result', () async {
    final (status, body) = await post('/mcp', {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {'protocolVersion': '2025-06-18'},
    });
    expect(status, HttpStatus.ok);
    final decoded = jsonDecode(body) as Map;
    expect(decoded['id'], 1);
    expect(decoded['result']['serverInfo']['name'], 'doudou-test');
  });

  test('POST tools/call executes the tool', () async {
    final (status, body) = await post('/mcp', {
      'jsonrpc': '2.0',
      'id': 9,
      'method': 'tools/call',
      'params': {'name': 'ping_tool'},
    });
    expect(status, HttpStatus.ok);
    final result = jsonDecode(body)['result'] as Map;
    expect(result['structuredContent'], {'pong': true});
  });

  test('notifications get 202 with no body', () async {
    final (status, body) = await post('/mcp', {
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    expect(status, HttpStatus.accepted);
    expect(body, isEmpty);
  });

  test('GET is declined with 405', () async {
    final (status, _) = await send('GET', '/mcp');
    expect(status, HttpStatus.methodNotAllowed);
  });

  test('DELETE is declined with 405', () async {
    final (status, _) = await send('DELETE', '/mcp');
    expect(status, HttpStatus.methodNotAllowed);
  });

  test('invalid JSON produces a parse error', () async {
    final (status, body) = await post('/mcp', '{not json');
    expect(status, HttpStatus.badRequest);
    final decoded = jsonDecode(body) as Map;
    expect(decoded['error']['code'], kRpcParseError);
  });

  test('unknown paths produce 404', () async {
    final (status, _) = await post('/elsewhere', {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'});
    expect(status, HttpStatus.notFound);
  });

  test('root path is accepted for lenient clients', () async {
    final (status, _) = await post('/', {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'});
    expect(status, HttpStatus.ok);
  });

  test('batch POST returns a batch response', () async {
    final (status, body) = await post('/mcp', [
      {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
      {'jsonrpc': '2.0', 'id': 2, 'method': 'ping'},
    ]);
    expect(status, HttpStatus.ok);
    expect(jsonDecode(body), hasLength(2));
  });
}
