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
  final favoritesCount = 0.obs;

  // Server info
  final activeServerId = 0.obs;
  final themeType = 'dark'.obs;
  final servers = <Map<String, dynamic>>[].obs;

  // Connection state
  final isReachable = false.obs;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  void _init() {
    // Check reachability (async on Android)
    _watch.isReachable.then((r) {
      isReachable.value = r;
    }).catchError((_) {});

    // Listen for context updates (state pushed from phone)
    _ctxSub = _watch.contextStream.listen((ctx) {
      _handleContext(ctx);
    });

    // Also check existing application context
    _watch.receivedApplicationContexts.then((existing) {
      if (existing.isNotEmpty) {
        _handleContext(existing.last);
      }
    }).catchError((_) {});

    // Request initial state from phone
    sendMessage({'command': 'getState'});

    printINFO('WearCommService initialized');
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
      favoritesCount.value = (ctx['favoritesCount'] as num?)?.toInt() ?? 0;
    } else if (type == 'serverInfo') {
      activeServerId.value = (ctx['activeServerId'] as num?)?.toInt() ?? 0;
      themeType.value = ctx['themeType']?.toString() ?? 'dark';
      final rawServers = ctx['servers'];
      if (rawServers is List) {
        servers.value = rawServers
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
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
  void setServer(int id) => sendMessage({'command': 'setServer', 'serverId': id});
  void setTheme(String theme) => sendMessage({'command': 'setTheme', 'theme': theme});

  @override
  void onClose() {
    _ctxSub?.cancel();
    _msgSub?.cancel();
    super.onClose();
  }
}
