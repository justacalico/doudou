import 'dart:async';

import 'package:get/get.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

import '/utils/helper.dart';

/// Watch-side communication service. Receives state from the phone
/// and sends commands back. Exposes reactive state for the UI.
class WearCommService extends GetxService {
  final _watch = WatchConnectivity();
  StreamSubscription? _ctxSub;
  StreamSubscription? _msgSub;

  // Reactive state mirrored from phone
  final songTitle = ''.obs;
  final songArtist = ''.obs;
  final songArtUri = ''.obs;
  final isPlaying = false.obs;
  final positionMs = 0.obs;
  final durationMs = 0.obs;
  final isShuffle = false.obs;
  final isLoop = false.obs;
  final isFav = false.obs;
  final queueLength = 0.obs;
  final queueIndex = 0.obs;
  final queue = <Map<String, dynamic>>[].obs;
  final favoritesCount = 0.obs;
  final volume = 100.obs;
  final isMuted = false.obs;

  // Server info
  final activeServerId = 0.obs;
  final themeType = 'dark'.obs;
  final servers = <Map<String, dynamic>>[].obs;

  // About info
  final appName = ''.obs;
  final appVersion = ''.obs;
  final appBuildNumber = ''.obs;

  // Connection state
  final isReachable = false.obs;
  Timer? _reachabilityTimer;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  void _init() {
    checkReachability();

    // Listen for context updates (state pushed from phone)
    _ctxSub = _watch.contextStream.listen((ctx) {
      _handleContext(ctx);
      // Got data from phone, so we know it's reachable
      isReachable.value = true;
    });

    // Also check existing application context
    _watch.receivedApplicationContexts.then((existing) {
      if (existing.isNotEmpty) {
        _handleContext(existing.last);
        isReachable.value = true;
      }
    }).catchError((_) {});

    // Periodically check reachability every 5 seconds
    _reachabilityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkReachability();
    });

    // Request initial state from phone
    sendMessage({'command': 'getState'});

    printINFO('WearCommService initialized');
  }

  /// Check if the phone app is reachable and update [isReachable].
  Future<void> checkReachability() async {
    try {
      final r = await _watch.isReachable;
      isReachable.value = r;
      if (r) {
        // Nudge the phone to send fresh state
        sendMessage({'command': 'getState'});
      }
    } catch (_) {
      isReachable.value = false;
    }
  }

  /// Manual retry — re-checks reachability and requests state
  void retry() {
    checkReachability();
  }

  void _handleContext(Map<dynamic, dynamic> ctx) {
    final type = ctx['type']?.toString();
    if (type == 'playbackState') {
      songTitle.value = ctx['title']?.toString() ?? '';
      songArtist.value = ctx['artist']?.toString() ?? '';
      songArtUri.value = ctx['artUri']?.toString() ?? '';
      isPlaying.value = ctx['isPlaying'] == true;
      positionMs.value = (ctx['positionMs'] as num?)?.toInt() ?? 0;
      durationMs.value = (ctx['durationMs'] as num?)?.toInt() ?? 0;
      isShuffle.value = ctx['isShuffle'] == true;
      isLoop.value = ctx['isLoop'] == true;
      isFav.value = ctx['isFav'] == true;
      queueLength.value = (ctx['queueLength'] as num?)?.toInt() ?? 0;
      queueIndex.value = (ctx['queueIndex'] as num?)?.toInt() ?? 0;
      final rawQueue = ctx['queue'];
      if (rawQueue is List) {
        queue.value = rawQueue
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      favoritesCount.value = (ctx['favoritesCount'] as num?)?.toInt() ?? 0;
      volume.value = (ctx['volume'] as num?)?.toInt() ?? 100;
      isMuted.value = volume.value == 0;
    } else if (type == 'serverInfo') {
      activeServerId.value = (ctx['activeServerId'] as num?)?.toInt() ?? 0;
      themeType.value = ctx['themeType']?.toString() ?? 'dark';
      final rawServers = ctx['servers'];
      if (rawServers is List) {
        servers.value = rawServers
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
    } else if (type == 'aboutInfo') {
      appName.value = ctx['appName']?.toString() ?? '';
      appVersion.value = ctx['version']?.toString() ?? '';
      appBuildNumber.value = ctx['buildNumber']?.toString() ?? '';
    }
  }

  /// Send a command to the phone app
  void sendMessage(Map<String, dynamic> msg) {
    try {
      _watch.sendMessage(msg);
    } catch (e) {
      printWarning('WearComm: failed to send message: $e');
    }
  }

  // Convenience command methods
  void playPause() => sendMessage({'command': 'playPause'});
  void next() => sendMessage({'command': 'next'});
  void prev() => sendMessage({'command': 'prev'});
  void shuffleAll() => sendMessage({'command': 'shuffleAll'});
  void shuffleFavorites() => sendMessage({'command': 'shuffleFavorites'});
  void toggleFav() => sendMessage({'command': 'toggleFav'});
  void setVolume(int value) => sendMessage({'command': 'setVolume', 'value': value});
  void mute() => sendMessage({'command': 'mute'});
  void seek(int positionMs) => sendMessage({'command': 'seek', 'positionMs': positionMs});
  void playQueueItem(int index) => sendMessage({'command': 'playQueueItem', 'index': index});
  void setServer(int id) => sendMessage({'command': 'setServer', 'serverId': id});
  void setTheme(String theme) => sendMessage({'command': 'setTheme', 'theme': theme});

  @override
  void onClose() {
    _ctxSub?.cancel();
    _msgSub?.cancel();
    _reachabilityTimer?.cancel();
    super.onClose();
  }
}
