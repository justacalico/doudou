/// Tool and resource definitions for the MCP engine. Pure Dart so the whole
/// tool surface can be unit tested without Flutter bindings.
library;

import 'mcp_protocol.dart';

/// Executes a tool call. [args] is the decoded `arguments` object (never null,
/// missing arguments arrive as an empty map). The returned value must be
/// encodable by `jsonEncode`; it is wrapped into a text content block by the
/// engine.
typedef McpToolHandler = Future<Object?> Function(Map<String, Object?> args);

/// Reads a resource. The returned value is encoded as JSON text unless it is
/// already a [String].
typedef McpResourceReader = Future<Object?> Function();

/// One entry of `tools/list`. [inputSchema] is a JSON Schema object describing
/// the accepted `arguments`.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final McpToolHandler handler;

  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// One entry of `resources/list`.
class McpResource {
  const McpResource({
    required this.uri,
    required this.name,
    required this.reader,
    this.description,
    this.mimeType = 'application/json',
  });

  final String uri;
  final String name;
  final String? description;
  final String mimeType;
  final McpResourceReader reader;

  Map<String, Object?> toJson() => {
        'uri': uri,
        'name': name,
        if (description != null) 'description': description,
        'mimeType': mimeType,
      };
}

/// Argument helpers. They throw [McpRpcError] with `invalidParams` so callers
/// get a proper JSON-RPC error instead of a tool-level failure.
class McpArgs {
  McpArgs._();

  static String string(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value is String && value.isNotEmpty) return value;
    throw McpRpcError.invalidParams('Missing or invalid "$key"');
  }

  static String? optString(Map<String, Object?> args, String key) {
    final value = args[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static int integer(Map<String, Object?> args, String key,
      {int? min, int? max}) {
    final parsed = _parseInt(args[key]);
    if (parsed == null) {
      throw McpRpcError.invalidParams('Missing or invalid "$key"');
    }
    _checkRange(key, parsed, min, max);
    return parsed;
  }

  static int? optInteger(Map<String, Object?> args, String key,
      {int? min, int? max}) {
    final raw = args[key];
    if (raw == null) return null;
    final parsed = _parseInt(raw);
    if (parsed == null) {
      throw McpRpcError.invalidParams('Missing or invalid "$key"');
    }
    _checkRange(key, parsed, min, max);
    return parsed;
  }

  static bool boolean(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value is bool) return value;
    throw McpRpcError.invalidParams('Missing or invalid "$key"');
  }

  static bool optBoolean(Map<String, Object?> args, String key,
      {bool fallback = false}) {
    final value = args[key];
    return value is bool ? value : fallback;
  }

  static Map<String, Object?>? object(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value is Map<String, Object?>) return value;
    if (value is Map) return Map<String, Object?>.from(value);
    return null;
  }

  static String enumValue(Map<String, Object?> args, String key,
      List<String> allowed) {
    final value = string(args, key);
    if (!allowed.contains(value)) {
      throw McpRpcError.invalidParams(
          '"$key" must be one of: ${allowed.join(', ')}');
    }
    return value;
  }

  static int? _parseInt(Object? value) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v),
        _ => null,
      };

  static void _checkRange(String key, int value, int? min, int? max) {
    if ((min != null && value < min) || (max != null && value > max)) {
      throw McpRpcError.invalidParams('"$key" must be between $min and $max');
    }
  }
}
