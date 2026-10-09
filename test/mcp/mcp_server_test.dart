import 'dart:convert';

import 'package:doudou/mcp/mcp_protocol.dart';
import 'package:doudou/mcp/mcp_server.dart';
import 'package:doudou/mcp/mcp_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  McpTool echoTool() => McpTool(
        name: 'echo',
        description: 'Echoes back its arguments',
        inputSchema: const {'type': 'object'},
        handler: (args) async => {'echoed': args},
      );

  DoudouMcpServer server({List<McpTool>? tools, List<McpResource>? resources}) =>
      DoudouMcpServer(
        serverName: 'doudou-test',
        serverVersion: '1.2.3',
        tools: tools ?? [echoTool()],
        resources: resources ?? const [],
      );

  Future<Map<String, Object?>> call(
          DoudouMcpServer s, String method, [Object? params]) =>
      s.handleMessage({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        if (params != null) 'params': params,
      }).then((r) => Map<String, Object?>.from(r! as Map));

  group('initialize', () {
    test('echoes a supported protocol version', () async {
      final s = server();
      final res = await call(s, 'initialize',
          {'protocolVersion': '2025-03-26', 'clientInfo': {}});
      final result = res['result'] as Map;
      expect(result['protocolVersion'], '2025-03-26');
      expect(result['serverInfo'], {'name': 'doudou-test', 'version': '1.2.3'});
      expect((result['capabilities'] as Map).containsKey('tools'), isTrue);
    });

    test('falls back to the latest version for unknown requests', () async {
      final s = server();
      final res = await call(
          s, 'initialize', {'protocolVersion': '1999-01-01'});
      final result = res['result'] as Map;
      expect(result['protocolVersion'], kMcpLatestProtocolVersion);
    });

    test('does not advertise capabilities for empty surfaces', () async {
      final s = server(tools: const [], resources: const []);
      final res = await call(s, 'initialize', {'protocolVersion': '2025-06-18'});
      expect(
          (res['result'] as Map)['capabilities'], anyOf(isNull, isEmpty));
    });
  });

  group('tools', () {
    test('tools/list returns registered tools', () async {
      final s = server();
      final res = await call(s, 'tools/list');
      final tools = (res['result'] as Map)['tools'] as List;
      expect(tools, hasLength(1));
      expect(tools.first['name'], 'echo');
      expect(tools.first['inputSchema'], isA<Map>());
    });

    test('tools/call wraps the payload as text and structured content',
        () async {
      final s = server();
      final res = await call(s, 'tools/call',
          {'name': 'echo', 'arguments': {'a': 1}});
      final result = res['result'] as Map;
      expect(result['isError'], isFalse);
      final content = result['content'] as List;
      expect(content.first['type'], 'text');
      expect(jsonDecode(content.first['text'] as String),
          {'echoed': {'a': 1}});
      expect(result['structuredContent'], {'echoed': {'a': 1}});
    });

    test('tools/call without arguments still reaches the handler', () async {
      final s = server();
      final res = await call(s, 'tools/call', {'name': 'echo'});
      final result = res['result'] as Map;
      expect(result['structuredContent'], {'echoed': {}});
    });

    test('unknown tool is an invalid params error', () async {
      final s = server();
      final res = await call(s, 'tools/call', {'name': 'nope'});
      final error = res['error'] as Map;
      expect(error['code'], kRpcInvalidParams);
      expect(error['message'], contains('nope'));
    });

    test('handler exceptions become isError results', () async {
      final s = server(tools: [
        McpTool(
          name: 'boom',
          description: 'Always fails',
          inputSchema: const {'type': 'object'},
          handler: (_) async => throw StateError('kaput'),
        ),
      ]);
      final res = await call(s, 'tools/call', {'name': 'boom'});
      final result = res['result'] as Map;
      expect(result['isError'], isTrue);
      expect((result['content'] as List).first['text'], contains('kaput'));
    });

    test('handler McpRpcError surfaces as a protocol error', () async {
      final s = server(tools: [
        McpTool(
          name: 'strict',
          description: 'Rejects everything',
          inputSchema: const {'type': 'object'},
          handler: (_) async =>
              throw McpRpcError.invalidParams('missing thing'),
        ),
      ]);
      final res = await call(s, 'tools/call', {'name': 'strict'});
      expect((res['error'] as Map)['code'], kRpcInvalidParams);
    });
  });

  group('resources', () {
    test('resources/list and resources/read', () async {
      final s = server(resources: [
        McpResource(
          uri: 'doudou://test',
          name: 'Test',
          reader: () async => {'value': 42},
        ),
      ]);
      final list = await call(s, 'resources/list');
      final resources = (list['result'] as Map)['resources'] as List;
      expect(resources.first['uri'], 'doudou://test');

      final read =
          await call(s, 'resources/read', {'uri': 'doudou://test'});
      final contents = (read['result'] as Map)['contents'] as List;
      expect(jsonDecode(contents.first['text'] as String), {'value': 42});
    });

    test('reading an unknown resource fails with invalid params', () async {
      final s = server();
      final res =
          await call(s, 'resources/read', {'uri': 'doudou://missing'});
      expect((res['error'] as Map)['code'], kRpcInvalidParams);
    });
  });

  group('json-rpc plumbing', () {
    test('ping answers with an empty result', () async {
      final res = await call(server(), 'ping');
      expect(res['result'], isA<Map>());
    });

    test('unknown methods produce method not found', () async {
      final res = await call(server(), 'does/not/exist');
      expect((res['error'] as Map)['code'], kRpcMethodNotFound);
    });

    test('notifications produce no response', () async {
      final s = server();
      final res = await s.handleMessage({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });
      expect(res, isNull);
    });

    test('unknown notifications are swallowed', () async {
      final s = server();
      final res = await s.handleMessage({
        'jsonrpc': '2.0',
        'method': 'notifications/made_up',
      });
      expect(res, isNull);
    });

    test('batch requests collect all responses', () async {
      final s = server();
      final res = await s.handleMessage([
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
        {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
      ]);
      final list = res as List;
      expect(list, hasLength(2));
      expect(list[0]['id'], 1);
      expect(list[1]['id'], 2);
    });

    test('a batch of only notifications yields no response', () async {
      final res = await server().handleMessage([
        {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
      ]);
      expect(res, isNull);
    });

    test('non-object requests are rejected', () async {
      final res = await server().handleMessage('garbage');
      expect((res as Map)['error']['code'], kRpcInvalidRequest);
      expect(res['id'], isNull);
    });

    test('missing jsonrpc tag is rejected', () async {
      final res = await server()
          .handleMessage({'id': 7, 'method': 'ping'});
      expect((res as Map)['error']['code'], kRpcInvalidRequest);
      expect(res['id'], 7);
    });
  });
}
