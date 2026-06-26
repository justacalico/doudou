import 'dart:async';
import 'dart:io';

import 'package:flutter_discord_rpc/flutter_discord_rpc.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/ui/player/player_controller.dart';
import '/utils/helper.dart';

/// Wraps the real FlutterDiscordRPC so we can mock it in tests.
abstract class DiscordRpcClient {
  Future<void> initialize(String appId);
  Future<void> connect({bool autoRetry});
  Future<void> disconnect();
  Future<void> setActivity(RPCActivity activity);
  Future<void> clearActivity();
  Future<void> dispose();
  bool get isConnected;
  Stream<bool> get isConnectedStream;
}

class _RealDiscordRpcClient implements DiscordRpcClient {
  @override
  Future<void> initialize(String appId) =>
      FlutterDiscordRPC.initialize(appId);

  @override
  Future<void> connect({bool autoRetry = false}) =>
      FlutterDiscordRPC.instance.connect(autoRetry: autoRetry);

  @override
  Future<void> disconnect() => FlutterDiscordRPC.instance.disconnect();

  @override
  Future<void> setActivity(RPCActivity activity) =>
      FlutterDiscordRPC.instance.setActivity(activity: activity);

  @override
  Future<void> clearActivity() => FlutterDiscordRPC.instance.clearActivity();

  @override
  Future<void> dispose() => FlutterDiscordRPC.instance.dispose();

  @override
  bool get isConnected => FlutterDiscordRPC.instance.isConnected;

  @override
  Stream<bool> get isConnectedStream =>
      FlutterDiscordRPC.instance.isConnectedStream;
}

/// Service that manages Discord Rich Presence for desktop platforms.
///
/// Only active on Linux, macOS, and Windows. The user provides their own
/// Discord Application ID in settings — we need it to initialize the IPC
/// connection to Discord.
class DiscordRpcService extends GetxController {
  DiscordRpcService({DiscordRpcClient? client})
      : _client = client ?? _RealDiscordRpcClient();

  final DiscordRpcClient _client;

  final _box = Hive.box("AppPrefs");
  final _isReady = false.obs;
  final _isConnected = false.obs;

  StreamSubscription? _songSub;
  StreamSubscription? _buttonSub;
  StreamSubscription? _progressSub;
  StreamSubscription? _connSub;
  Timer? _debounce;

  bool get isReady => _isReady.value;
  bool get isConnected => _isConnected.value;

  static bool get isSupported =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  void onInit() {
    super.onInit();
    if (!isSupported) return;

    _maybeInit();
  }

  Future<void> _maybeInit() async {
    final enabled = _box.get('discordRpcEnabled') ?? false;
    if (!enabled) return;

    final appId = _box.get('discordAppId') as String?;
    if (appId == null || appId.trim().isEmpty) return;

    try {
      await _client.initialize(appId.trim());
      _isReady.value = true;
      await _client.connect(autoRetry: true);
      _listenToPlayer();
    } catch (e) {
      printWarning('[DiscordRpc] init failed: $e');
    }
  }

  void _listenToPlayer() {
    final player = Get.find<PlayerController>();
    _songSub = player.currentSong.listen((_) => _scheduleUpdate());
    _buttonSub = player.buttonState.listen((_) => _scheduleUpdate());
    _progressSub = player.progressBarStatus.listen((_) => _scheduleUpdate());
    _connSub = _client.isConnectedStream.listen((c) => _isConnected.value = c);
    _isConnected.value = _client.isConnected;
    // push initial state
    _updateActivity();
  }

  void _scheduleUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _updateActivity);
  }

  void _updateActivity() {
    final player = Get.find<PlayerController>();
    final song = player.currentSong.value;
    final isPlaying = player.buttonState.value == PlayButtonState.playing;

    if (song == null) {
      _client.clearActivity();
      return;
    }

    final progress = player.progressBarStatus.value;
    final posMs = progress.current.inMilliseconds;
    final durMs = progress.total.inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;

    final startTs = isPlaying && posMs > 0 ? now - posMs : null;
    final endTs = isPlaying && durMs > 0 ? now - posMs + durMs : null;

    final activity = RPCActivity(
      state: song.artist?.isNotEmpty == true ? song.artist! : 'Unknown artist',
      details: song.title,
      activityType: ActivityType.listening,
      timestamps: RPCTimestamps(start: startTs, end: endTs),
      assets: const RPCAssets(
        largeImage: 'doudou',
        largeText: 'Doudou',
      ),
    );

    _client.setActivity(activity: activity).catchError((e) {
      printWarning('[DiscordRpc] setActivity failed: $e');
    });
  }

  /// Called when the user toggles Discord RPC or changes the app ID.
  /// Will re-initialize if needed.
  Future<void> reconfigure() async {
    if (!isSupported) return;

    // tear down existing
    await _teardown();

    final enabled = _box.get('discordRpcEnabled') ?? false;
    if (!enabled) return;

    final appId = _box.get('discordAppId') as String?;
    if (appId == null || appId.trim().isEmpty) return;

    try {
      await _client.initialize(appId.trim());
      _isReady.value = true;
      await _client.connect(autoRetry: true);
      _listenToPlayer();
    } catch (e) {
      printWarning('[DiscordRpc] reconfigure failed: $e');
    }
  }

  Future<void> _teardown() async {
    _debounce?.cancel();
    _debounce = null;
    await _songSub?.cancel();
    _songSub = null;
    await _buttonSub?.cancel();
    _buttonSub = null;
    await _progressSub?.cancel();
    _progressSub = null;
    await _connSub?.cancel();
    _connSub = null;

    if (_isReady.value) {
      try {
        await _client.clearActivity();
        await _client.disconnect();
      } catch (_) {
        // best effort
      }
    }
    _isReady.value = false;
    _isConnected.value = false;
  }

  @override
  void onClose() {
    _teardown();
    super.onClose();
  }
}
