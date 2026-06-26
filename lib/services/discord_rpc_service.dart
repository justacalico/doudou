import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/models/durationstate.dart';
import '/ui/player/player_controller.dart';
import '/utils/helper.dart';

/// Just the player state we need for RPC updates.
/// This abstraction lets us test without the full PlayerController.
abstract class PlayerStateProvider {
  Rxn<MediaItem> get currentSong;
  Rx<PlayButtonState> get buttonState;
  Rx<ProgressBarState> get progressBarStatus;
}

/// Wraps the real FlutterDiscordRPC so we can mock it in tests.
abstract class DiscordRpcClient {
  Future<void> initialize(String appId);
  Future<void> connect({bool autoRetry});
  Future<void> disconnect();
  Future<void> setActivity({required RPCActivity activity});
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
  Future<void> setActivity({required RPCActivity activity}) =>
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
  DiscordRpcService({
    DiscordRpcClient? client,
    Box? box,
    PlayerStateProvider? player,
  })  : _client = client ?? _RealDiscordRpcClient(),
        _box = box ?? Hive.box("AppPrefs"),
        _player = player;

  final DiscordRpcClient _client;
  final Box _box;
  final PlayerStateProvider? _player;
  final _isReady = false.obs;
  final _isConnected = false.obs;
  bool _wasInitialized = false;

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
    if (!enabled) {
      printINFO('[DiscordRpc] skipping init — RPC is disabled');
      return;
    }

    final appId = _box.get('discordAppId') as String?;
    if (appId == null || appId.trim().isEmpty) {
      printWarning('[DiscordRpc] skipping init — no app ID configured');
      return;
    }

    try {
      printINFO('[DiscordRpc] initializing with app ID: ${appId.trim()}');
      await _client.initialize(appId.trim());
      _wasInitialized = true;
      _isReady.value = true;
      printINFO('[DiscordRpc] connecting to Discord...');
      await _client.connect(autoRetry: true);
      // connect(autoRetry: true) doesn't throw on initial failure —
      // it sets up a retry timer and returns. So we need to check
      // the actual connection state before proceeding.
      if (_client.isConnected) {
        printINFO('[DiscordRpc] connected, listening to player state');
        _listenToPlayer();
      } else {
        printWarning('[DiscordRpc] connect failed, will retry in background');
        // still set up listeners so activity updates when connection is established
        _listenToPlayer();
      }
    } catch (e) {
      printWarning('[DiscordRpc] init failed: $e');
    }
  }

  PlayerStateProvider get _playerState =>
      _player ?? Get.find<PlayerController>();

  void _listenToPlayer() {
    // Defensive: cancel any existing subscriptions before setting up new ones.
    _songSub?.cancel();
    _buttonSub?.cancel();
    _progressSub?.cancel();
    _connSub?.cancel();

    final player = _playerState;
    _songSub = player.currentSong.listen((_) => _scheduleUpdate());
    _buttonSub = player.buttonState.listen((_) => _scheduleUpdate());
    // Don't listen to progressBarStatus — it fires on every position tick
    // during playback and would starve the debounce timer so it never fires.
    // We read the progress value directly in _updateActivity instead.
    _connSub = _client.isConnectedStream.listen((c) {
      if (_isConnected.value == c) return;
      _isConnected.value = c;
      printINFO('[DiscordRpc] connection state changed: $c');
      if (c) _updateActivity();
    });
    _isConnected.value = _client.isConnected;
    // push initial state
    _updateActivity();
  }

  void _scheduleUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _updateActivity);
  }

  void _updateActivity() {
    if (!_isConnected.value) return;

    final player = _playerState;
    final song = player.currentSong.value;
    final isPlaying = player.buttonState.value == PlayButtonState.playing;

    if (song == null) {
      printINFO('[DiscordRpc] no song loaded, clearing activity');
      _client.clearActivity();
      return;
    }

    printINFO('[DiscordRpc] updating activity: ${song.title} — ${song.artist ?? "Unknown artist"} (${isPlaying ? "playing" : "paused"})');

    final progress = player.progressBarStatus.value;
    final posMs = progress.current.inMilliseconds;
    final durMs = progress.total.inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;

    final startTs = isPlaying && posMs > 0 ? (now - posMs).toInt() : null;
    final endTs = isPlaying && durMs > 0 ? (now - posMs + durMs).toInt() : null;

    final artUri = song.artUri;
    final hasValidArt = artUri != null && artUri.toString().isNotEmpty;
    final albumName = song.album?.isNotEmpty == true ? song.album : null;

    // YouTube Music songs don't have a backendType in extras (it's null for
    // the default YouTube Music server). Other backends set it to 'plex',
    // 'jellyfin', or 'subsonic'.
    final backendType = song.extras?['backendType']?.toString();
    final isYouTubeMusic = backendType == null;
    final buttons = <RPCButton>[
      const RPCButton(label: 'Download Doudou', url: 'https://gitlab.com/Openlyst/doudou'),
    ];
    if (isYouTubeMusic) {
      buttons.add(RPCButton(
        label: 'Open in YouTube Music',
        url: 'https://music.youtube.com/watch?v=${song.id}',
      ));
    }

    final activity = RPCActivity(
      state: song.artist?.isNotEmpty == true ? song.artist! : 'Unknown artist',
      details: song.title,
      activityType: ActivityType.listening,
      timestamps: RPCTimestamps(start: startTs, end: endTs),
      assets: RPCAssets(
        largeImage: hasValidArt ? artUri.toString() : 'doudou',
        largeText: albumName ?? 'Doudou',
      ),
      buttons: buttons,
    );

    _client.setActivity(activity: activity).catchError((e) {
      printWarning('[DiscordRpc] setActivity failed: $e');
    });
  }

  /// Called when the user toggles Discord RPC or changes the app ID.
  /// Will re-initialize if needed.
  Future<void> reconfigure() async {
    if (!isSupported) return;

    printINFO('[DiscordRpc] reconfiguring...');
    // tear down existing
    await _teardown();

    final enabled = _box.get('discordRpcEnabled') ?? false;
    if (!enabled) {
      printINFO('[DiscordRpc] RPC is disabled, staying disconnected');
      return;
    }

    final appId = _box.get('discordAppId') as String?;
    if (appId == null || appId.trim().isEmpty) {
      printWarning('[DiscordRpc] no app ID configured, cannot reconfigure');
      return;
    }

    try {
      // FlutterDiscordRPC.initialize can only be called once per process.
      // If we've already initialized, just reconnect.
      if (!_wasInitialized) {
        printINFO('[DiscordRpc] initializing with app ID: ${appId.trim()}');
        await _client.initialize(appId.trim());
        _wasInitialized = true;
      } else {
        printINFO('[DiscordRpc] already initialized, reconnecting...');
      }
      _isReady.value = true;
      await _client.connect(autoRetry: true);
      if (_client.isConnected) {
        printINFO('[DiscordRpc] reconnected successfully');
      } else {
        printWarning('[DiscordRpc] reconnect failed, will retry in background');
      }
      _listenToPlayer();
    } catch (e) {
      printWarning('[DiscordRpc] reconfigure failed: $e');
    }
  }

  Future<void> _teardown() async {
    printINFO('[DiscordRpc] tearing down...');
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
        printINFO('[DiscordRpc] disconnected');
      } catch (e) {
        printWarning('[DiscordRpc] error during teardown: $e');
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
