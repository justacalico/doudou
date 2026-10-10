import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '/mcp/mcp_bundle.dart';
import '/mcp/mcp_http_server.dart';
import '/mcp/mcp_server.dart';
import 'mcp/mcp_app_bridge.dart';
import 'mcp/mcp_toolset.dart';

/// Hosts an MCP (Model Context Protocol) server inside the app so AI
/// assistants and other MCP clients can control playback, manage the queue
/// and search the active music server.
///
/// Desktop only: the HTTP endpoint binds to loopback and is meant for local
/// clients (Claude Desktop, coding agents, ...) running on the same machine.
/// Nothing is exposed on the network.
class McpServerService extends GetxService {
  McpServerService({
    Box? prefs,
    McpAppBridge? bridge,
    bool? supported,
    McpHttpServer Function(DoudouMcpServer engine)? httpFactory,
  })  : _prefs = prefs ?? Hive.box('AppPrefs'),
        _bridge = bridge ?? GetxMcpAppBridge(),
        _supported = supported ?? isSupported,
        _httpFactory = httpFactory;

  static const enabledPrefsKey = 'mcpServerEnabled';
  static const portPrefsKey = 'mcpServerPort';
  static const defaultPort = 8462;
  static const serverName = 'doudou';

  /// MCP support matches the desktop builds; mobile and web never start the
  /// listener.
  static bool get isSupported =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  final Box _prefs;
  final McpAppBridge _bridge;
  final bool _supported;
  final McpHttpServer Function(DoudouMcpServer engine)? _httpFactory;

  final enabled = false.obs;
  final running = false.obs;
  final port = defaultPort.obs;
  final lastError = RxnString();

  McpHttpServer? _http;
  String _appVersion = '0.0.0';

  /// Address local MCP clients should connect to.
  String get listenUrl =>
      'http://127.0.0.1:${_http?.port ?? port.value}/mcp';

  @override
  void onInit() {
    super.onInit();
    if (!_supported) return;
    enabled.value = _prefs.get(enabledPrefsKey) == true;
    final storedPort = _prefs.get(portPrefsKey);
    if (storedPort is int && storedPort >= 1024 && storedPort <= 65535) {
      port.value = storedPort;
    }
    unawaited(_loadAppVersion());
    if (enabled.value) unawaited(start());
  }

  @override
  void onClose() {
    unawaited(_http?.stop());
    _http = null;
    super.onClose();
  }

  Future<void> _loadAppVersion() async {
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Package info is unavailable in tests; the fallback version only
      // shows up in the MCP serverInfo block.
    }
  }

  @visibleForTesting
  DoudouMcpServer buildEngine() => DoudouMcpServer(
        serverName: serverName,
        serverVersion: _appVersion,
        tools: buildDoudouMcpTools(_bridge),
        resources: buildDoudouMcpResources(_bridge),
        instructions:
            'Doudou music player. Tools control playback and the queue, '
            'search the active music server and read library playlists.',
      );

  /// `.mcpb` bundle bytes for the current listen address. Installing the
  /// bundle in an MCPB-capable client (e.g. Claude Desktop) launches a
  /// stdio bridge that talks to the app's HTTP endpoint.
  Uint8List buildBundle() =>
      buildMcpBundle(url: listenUrl, version: _appVersion);

  Future<void> start() async {
    if (_http != null) return;
    final http = _httpFactory?.call(buildEngine()) ??
        McpHttpServer(buildEngine());
    try {
      await http.start(port: port.value);
      _http = http;
      running.value = true;
      lastError.value = null;
    } on SocketException catch (e) {
      await http.stop();
      running.value = false;
      lastError.value = e.message;
    }
  }

  Future<void> stop() async {
    await _http?.stop();
    _http = null;
    running.value = false;
  }

  Future<void> setEnabled(bool value) async {
    if (enabled.value == value) return;
    enabled.value = value;
    // The in-memory value is written synchronously; waiting for the disk
    // flush would only delay the listener coming up.
    unawaited(_prefs.put(enabledPrefsKey, value));
    value ? await start() : await stop();
  }

  /// Persists [value] and restarts the listener when it is running. Returns
  /// false for ports outside the user range (1024-65535); port 0 stays
  /// reserved for tests binding an ephemeral port.
  Future<bool> setPort(int value) async {
    if (value < 1024 || value > 65535) return false;
    if (port.value == value) return true;
    port.value = value;
    unawaited(_prefs.put(portPrefsKey, value));
    if (_http != null) {
      await stop();
      await start();
    }
    return true;
  }
}
