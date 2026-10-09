/// Protocol constants and JSON-RPC error types shared by the MCP engine and
/// the HTTP transport. Pure Dart, no Flutter imports.
library;

/// JSON-RPC version tag every request and response carries.
const String kJsonRpcVersion = '2.0';

/// Protocol revisions this server can speak. The newest entry is offered to
/// clients that ask for a version we do not know.
const List<String> kMcpSupportedProtocolVersions = [
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

const String kMcpLatestProtocolVersion = '2025-06-18';

/// Reserved method name prefixes per the MCP spec. Requests under these
/// namespaces that the server does not handle are ignored as notifications.
const String kMcpNotificationPrefix = 'notifications/';

// JSON-RPC 2.0 error codes.
const int kRpcParseError = -32700;
const int kRpcInvalidRequest = -32600;
const int kRpcMethodNotFound = -32601;
const int kRpcInvalidParams = -32602;
const int kRpcInternalError = -32603;

/// A JSON-RPC level failure. Thrown inside request dispatch to produce an
/// error response with the matching code; tool handlers should throw plain
/// exceptions instead so they surface as `isError` tool results.
class McpRpcError implements Exception {
  const McpRpcError(this.code, this.message, [this.data]);

  final int code;
  final String message;
  final Object? data;

  factory McpRpcError.invalidParams(String message) =>
      McpRpcError(kRpcInvalidParams, message);

  Map<String, Object?> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };

  @override
  String toString() => 'McpRpcError($code): $message';
}
