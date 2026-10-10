/// Builds `.mcpb` (MCP Bundle) archives for the embedded server.
///
/// The MCPB format only launches local stdio servers, so the bundle ships a
/// small Node bridge (`server/bridge.js`) that forwards stdio JSON-RPC to
/// the app's streamable-HTTP endpoint. Installing the bundle in Claude
/// Desktop or another MCPB client connects it to the running app.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const _bridgePath = 'server/bridge.js';

/// Node stdio -> streamable-HTTP bridge bundled inside every export.
/// Stdlib only, no npm dependencies. The endpoint comes from the
/// `DOUDOU_MCP_URL` environment variable baked into `manifest.json`.
const bridgeScript = r'''
const http = require('node:http');
const readline = require('node:readline');

const url = new URL(process.env.DOUDOU_MCP_URL || 'http://127.0.0.1:8462/mcp');

const rl = readline.createInterface({ input: process.stdin });

rl.on('line', (line) => {
  line = line.trim();
  if (!line) return;

  let id = null;
  try {
    const parsed = JSON.parse(line);
    if (parsed && !Array.isArray(parsed)) id = parsed.id ?? null;
  } catch (_) {}

  const req = http.request({
    hostname: url.hostname,
    port: url.port,
    path: url.pathname + url.search,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      'Content-Length': Buffer.byteLength(line),
    },
  }, (res) => {
    let body = '';
    res.setEncoding('utf8');
    res.on('data', (chunk) => { body += chunk; });
    res.on('end', () => {
      const trimmed = body.trim();
      if (res.statusCode === 202 || !trimmed) return;
      process.stdout.write(trimmed + '\n');
    });
  });

  req.on('error', () => {
    if (id === null) return;
    process.stdout.write(JSON.stringify({
      jsonrpc: '2.0',
      id,
      error: {
        code: -32603,
        message: 'Doudou MCP server is unreachable. ' +
            'Make sure Doudou is running and the MCP server is enabled.',
      },
    }) + '\n');
  });

  req.write(line);
  req.end();
});
''';

/// Builds the manifest for a bundle that targets [url] (the app's
/// streamable-HTTP endpoint, e.g. `http://127.0.0.1:8462/mcp`).
Map<String, Object?> buildMcpBundleManifest({
  required String url,
  required String version,
}) {
  return {
    'manifest_version': '0.3',
    'name': 'doudou',
    'display_name': 'Doudou',
    'version': version,
    'description': 'Control the Doudou music player: playback, queue, '
        'search and library playlists.',
    'author': {'name': 'Openlyst'},
    'license': 'GPL-3.0-only',
    'server': {
      'type': 'node',
      'entry_point': _bridgePath,
      'mcp_config': {
        'command': 'node',
        'args': ['\${__dirname}/$_bridgePath'],
        'env': {'DOUDOU_MCP_URL': url},
      },
    },
  };
}

/// Encodes the `.mcpb` archive (a zip holding `manifest.json` and the
/// stdio bridge) and returns its bytes.
Uint8List buildMcpBundle({
  required String url,
  required String version,
}) {
  final manifest = utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(buildMcpBundleManifest(url: url, version: version))}\n');
  final bridge = utf8.encode(bridgeScript);

  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
    ..addFile(ArchiveFile(_bridgePath, bridge.length, bridge));

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
