/// Embedded MCP (Model Context Protocol) server support.
///
/// Everything under `mcp/` is pure Dart (no Flutter imports) so the protocol
/// engine and the HTTP transport are fully unit testable. The app wires real
/// playback, queue and library access in `services/mcp_server_service.dart`.
library;

export 'mcp/mcp_http_server.dart';
export 'mcp/mcp_protocol.dart';
export 'mcp/mcp_server.dart';
export 'mcp/mcp_tools.dart';
