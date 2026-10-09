import 'dart:convert';

import 'mcp_protocol.dart';
import 'mcp_tools.dart';

/// Transport-agnostic MCP engine. Decodes JSON-RPC 2.0 messages and answers
/// the MCP method surface: initialize, ping, tools/list, tools/call,
/// resources/list and resources/read.
///
/// Everything the server can do is described by the [tools] and [resources]
/// lists handed to the constructor, which keeps this class free of any app
/// dependencies and trivially testable.
class DoudouMcpServer {
  DoudouMcpServer({
    required this.serverName,
    required this.serverVersion,
    List<McpTool>? tools,
    List<McpResource>? resources,
    this.instructions,
  })  : tools = List.unmodifiable(tools ?? const []),
        resources = List.unmodifiable(resources ?? const []);

  final String serverName;
  final String serverVersion;
  final List<McpTool> tools;
  final List<McpResource> resources;

  /// Optional human-readable hint returned in the initialize result.
  final String? instructions;

  /// The revision settled during `initialize`. Until a client initializes,
  /// the latest supported revision is assumed.
  String protocolVersion = kMcpLatestProtocolVersion;

  /// Handles one decoded JSON value: a single request object or a batch
  /// array. Returns the response to send back (a map or a list of maps), or
  /// null when the input only carried notifications.
  Future<Object?> handleMessage(Object? message) async {
    if (message is List) {
      if (message.isEmpty) {
        return _errorResponse(null, const McpRpcError(
            kRpcInvalidRequest, 'Empty batch request'));
      }
      final responses = <Object?>[];
      for (final entry in message) {
        final response = await _handleOne(entry);
        if (response != null) responses.add(response);
      }
      return responses.isEmpty ? null : responses;
    }
    return _handleOne(message);
  }

  Future<Map<String, Object?>?> _handleOne(Object? message) async {
    if (message is! Map) {
      return _errorResponse(null,
          const McpRpcError(kRpcInvalidRequest, 'Request must be an object'));
    }
    final request = Map<String, Object?>.from(message);
    final id = request['id'];
    final isNotification = !request.containsKey('id');

    try {
      if (request['jsonrpc'] != kJsonRpcVersion) {
        throw const McpRpcError(
            kRpcInvalidRequest, '"jsonrpc" must be "2.0"');
      }
      final method = request['method'];
      if (method is! String || method.isEmpty) {
        throw const McpRpcError(
            kRpcInvalidRequest, '"method" must be a non-empty string');
      }
      final params = request['params'];
      final result = await _dispatch(
          method, params is Map ? Map<String, Object?>.from(params) : null);
      return isNotification
          ? null
          : {'jsonrpc': kJsonRpcVersion, 'id': id, 'result': result};
    } on McpRpcError catch (e) {
      return isNotification ? null : _errorResponse(id, e);
    } catch (e) {
      return isNotification
          ? null
          : _errorResponse(
              id, McpRpcError(kRpcInternalError, '$e'));
    }
  }

  Future<Object?> _dispatch(String method, Map<String, Object?>? params) {
    switch (method) {
      case 'initialize':
        return Future.value(_initialize(params));
      case 'ping':
        return Future.value(const <String, Object?>{});
      case 'tools/list':
        return Future.value(
            {'tools': tools.map((t) => t.toJson()).toList()});
      case 'tools/call':
        return _callTool(params);
      case 'resources/list':
        return Future.value(
            {'resources': resources.map((r) => r.toJson()).toList()});
      case 'resources/read':
        return _readResource(params);
      case 'resources/templates/list':
        return Future.value(
            const {'resourceTemplates': <Object?>[]});
      case 'prompts/list':
        return Future.value(const {'prompts': <Object?>[]});
      case 'logging/setLevel':
        // Accepted but ignored: the app has its own diagnostics surface.
        return Future.value(const <String, Object?>{});
      default:
        if (method.startsWith(kMcpNotificationPrefix)) {
          return Future.value(const <String, Object?>{});
        }
        throw McpRpcError(kRpcMethodNotFound, 'Unknown method: $method');
    }
  }

  Map<String, Object?> _initialize(Map<String, Object?>? params) {
    final requested = params?['protocolVersion'];
    if (requested is String &&
        kMcpSupportedProtocolVersions.contains(requested)) {
      protocolVersion = requested;
    } else {
      // Unknown or missing version: answer with the newest we speak so the
      // client can decide whether to continue (per spec it may disconnect).
      protocolVersion = kMcpLatestProtocolVersion;
    }
    return {
      'protocolVersion': protocolVersion,
      'capabilities': {
        if (tools.isNotEmpty) 'tools': {'listChanged': false},
        if (resources.isNotEmpty)
          'resources': {'subscribe': false, 'listChanged': false},
      },
      'serverInfo': {'name': serverName, 'version': serverVersion},
      if (instructions != null) 'instructions': instructions,
    };
  }

  Future<Object?> _callTool(Map<String, Object?>? params) async {
    if (params == null) {
      throw const McpRpcError(kRpcInvalidParams, 'tools/call needs params');
    }
    final name = params['name'];
    if (name is! String || name.isEmpty) {
      throw const McpRpcError(
          kRpcInvalidParams, 'tools/call needs a tool "name"');
    }
    final rawArgs = params['arguments'];
    final Map<String, Object?> args;
    if (rawArgs == null) {
      args = const {};
    } else if (rawArgs is Map) {
      args = Map<String, Object?>.from(rawArgs);
    } else {
      throw const McpRpcError(
          kRpcInvalidParams, '"arguments" must be an object');
    }

    McpTool? tool;
    for (final candidate in tools) {
      if (candidate.name == name) {
        tool = candidate;
        break;
      }
    }
    if (tool == null) {
      throw McpRpcError(kRpcInvalidParams, 'Unknown tool: $name');
    }

    final Object? payload;
    try {
      payload = await tool.handler(args);
    } on McpRpcError {
      rethrow;
    } catch (e) {
      // Tool-level failures are reported inside the result per spec, not as
      // JSON-RPC errors, so agents can read and recover from them.
      return {
        'content': [
          {'type': 'text', 'text': 'Error: $e'}
        ],
        'isError': true,
      };
    }
    return _toolResult(payload);
  }

  Future<Object?> _readResource(Map<String, Object?>? params) async {
    final uri = params?['uri'];
    if (uri is! String || uri.isEmpty) {
      throw const McpRpcError(
          kRpcInvalidParams, 'resources/read needs a "uri"');
    }
    for (final resource in resources) {
      if (resource.uri == uri) {
        final payload = await resource.reader();
        return {
          'contents': [
            {
              'uri': uri,
              'mimeType': resource.mimeType,
              'text': payload is String ? payload : jsonEncode(payload),
            }
          ],
        };
      }
    }
    throw McpRpcError(kRpcInvalidParams, 'Unknown resource: $uri');
  }

  /// Successful tool calls carry the payload both as JSON text (widely
  /// supported by clients) and as structured content for clients that parse
  /// it directly.
  Map<String, Object?> _toolResult(Object? payload) {
    final structured = payload is Map<String, Object?>
        ? payload
        : <String, Object?>{'result': payload};
    return {
      'content': [
        {
          'type': 'text',
          'text': payload is String ? payload : jsonEncode(payload),
        }
      ],
      'structuredContent': structured,
      'isError': false,
    };
  }

  Map<String, Object?> _errorResponse(Object? id, McpRpcError error) => {
        'jsonrpc': kJsonRpcVersion,
        'id': id,
        'error': error.toJson(),
      };
}
