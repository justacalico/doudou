import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

import '/l10n/app_localizations.dart';
import '/ui/player/player_controller.dart';
import '/ui/screens/Home/home_screen_controller.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/utils/helper.dart';

/// Phone-side service that syncs playback state to the Wear OS app
/// and handles commands from the watch.
///
/// Uses watch_connectivity's application context for state updates
/// (throttled to ~1/sec) and messages for one-shot commands.
class WatchSyncService extends GetxService {
  final _watch = WatchConnectivity();
  StreamSubscription? _msgSub;
  StreamSubscription? _ctxSub;

  Timer? _stateThrottle;
  DateTime _lastStatePush = DateTime.fromMillisecondsSinceEpoch(0);

  // Reactive subscriptions
  final _subs = <StreamSubscription>[];

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  void _init() {
    // Listen for messages from the watch (commands)
    _msgSub = _watch.messageStream.listen((msg) {
      _handleWatchMessage(msg);
    });

    // Listen for context updates from the watch (rare, but handle anyway)
    _ctxSub = _watch.contextStream.listen((ctx) {
      printINFO('WatchSync: received context from watch: $ctx');
    });

    // Subscribe to player state changes
    final player = Get.find<PlayerController>();
    _subs.add(player.currentSong.listen((_) => _scheduleStatePush()));
    _subs.add(player.buttonState.listen((_) => _scheduleStatePush()));
    _subs.add(player.progressBarStatus.listen((_) => _scheduleStatePush()));
    _subs.add(player.isShuffleModeEnabled.listen((_) => _scheduleStatePush()));
    _subs.add(player.isLoopModeEnabled.listen((_) => _scheduleStatePush()));
    _subs.add(player.isCurrentSongFav.listen((_) => _scheduleStatePush()));
    _subs.add(player.volume.listen((_) => _scheduleStatePush()));
    _subs.add(player.currentQueue.listen((_) => _scheduleStatePush()));

    // Subscribe to settings changes
    final settings = Get.find<SettingsScreenController>();
    _subs.add(settings.activeServerId.listen((_) => _pushServerInfo()));
    _subs.add(settings.themeModetype.listen((_) => _pushServerInfo()));

    // Subscribe to favorites count
    if (Get.isRegistered<HomeScreenController>()) {
      final home = Get.find<HomeScreenController>();
      _subs.add(home.favoriteCount.listen((_) => _scheduleStatePush()));
    }

    // Push initial state after a short delay to let things settle
    Timer(const Duration(seconds: 2), () {
      _pushState();
      _pushServerInfo();
    });

    printINFO('WatchSyncService initialized');
  }

  void _scheduleStatePush() {
    // Throttle: max once per second
    final now = DateTime.now();
    final elapsed = now.difference(_lastStatePush).inMilliseconds;
    if (elapsed >= 1000) {
      _stateThrottle?.cancel();
      _pushState();
    } else {
      _stateThrottle?.cancel();
      _stateThrottle = Timer(Duration(milliseconds: 1000 - elapsed), () {
        _pushState();
      });
    }
  }

  void _pushState() {
    _lastStatePush = DateTime.now();

    final player = Get.find<PlayerController>();
    final song = player.currentSong.value;
    final progress = player.progressBarStatus.value;

    final state = <String, dynamic>{
      'type': 'playbackState',
      'songId': song?.id,
      'title': song?.title ?? '',
      'artist': song?.artist ?? '',
      'artUri': song?.artUri?.toString() ?? '',
      'isPlaying': player.buttonState.value == PlayButtonState.playing,
      'positionMs': progress.current.inMilliseconds,
      'durationMs': progress.total.inMilliseconds,
      'isShuffle': player.isShuffleModeEnabled.value,
      'isLoop': player.isLoopModeEnabled.value,
      'isFav': player.isCurrentSongFav.value,
      'queueLength': player.currentQueue.length,
      'queueIndex': player.currentSongIndex.value,
      'queue': player.currentQueue.take(50).map((item) => {
        'title': item.title,
        'artist': item.artist ?? '',
        'artUri': item.artUri?.toString() ?? '',
      }).toList(),
      'volume': player.volume.value,
    };

    // Add favorites count if available
    if (Get.isRegistered<HomeScreenController>()) {
      state['favoritesCount'] = Get.find<HomeScreenController>().favoriteCount.value;
    } else {
      state['favoritesCount'] = 0;
    }

    try {
      _watch.updateApplicationContext(state);
    } catch (e) {
      printWarning('WatchSync: failed to push state: $e');
    }
  }

  void _pushServerInfo() {
    final settings = Get.find<SettingsScreenController>();
    final servers = settings.servers
        .map((s) => {
              'id': s.id,
              'name': s.name,
              'type': s.type.name,
            })
        .toList();

    final ctx = <String, dynamic>{
      'type': 'serverInfo',
      'activeServerId': settings.activeServerId.value,
      'themeType': settings.themeModetype.value.name,
      'servers': servers,
    };

    try {
      _watch.updateApplicationContext(ctx);
    } catch (e) {
      printWarning('WatchSync: failed to push server info: $e');
    }

    // Also push full state since theme might affect display
    _scheduleStatePush();
  }

  void _handleWatchMessage(Map<dynamic, dynamic> msg) {
    final cmd = msg['command']?.toString();
    if (cmd == null) return;

    printINFO('WatchSync: received command: $cmd');

    try {
      switch (cmd) {
        case 'play':
          Get.find<PlayerController>().play();
          break;
        case 'pause':
          Get.find<PlayerController>().pause();
          break;
        case 'playPause':
          Get.find<PlayerController>().playPause();
          break;
        case 'next':
          Get.find<PlayerController>().next();
          break;
        case 'prev':
          Get.find<PlayerController>().prev();
          break;
        case 'shuffleAll':
          _shuffleAll();
          break;
        case 'shuffleFavorites':
          _shuffleFavorites();
          break;
        case 'toggleFav':
          Get.find<PlayerController>().toggleFavourite();
          break;
        case 'setVolume':
          final vol = (msg['value'] as num?)?.toInt() ?? 100;
          Get.find<PlayerController>().setVolume(vol);
          break;
        case 'mute':
          Get.find<PlayerController>().mute();
          break;
        case 'seek':
          final posMs = (msg['positionMs'] as num?)?.toInt() ?? 0;
          Get.find<PlayerController>().seek(Duration(milliseconds: posMs));
          break;
        case 'playQueueItem':
          final index = (msg['index'] as num?)?.toInt() ?? 0;
          Get.find<AudioHandler>().skipToQueueItem(index);
          break;
        case 'setServer':
          final id = msg['serverId'] as int;
          Get.find<SettingsScreenController>().setActiveServer(id);
          break;
        case 'setTheme':
          final themeName = msg['theme']?.toString();
          if (themeName != null) {
            _setTheme(themeName);
          }
          break;
        case 'getState':
          _pushState();
          _pushServerInfo();
          break;
        default:
          printWarning('WatchSync: unknown command: $cmd');
      }
    } catch (e, st) {
      printWarning('WatchSync: error handling command $cmd: $e\n$st');
    }
  }

  void _shuffleAll() {
    final ctx = Get.context;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx);
    Get.find<HomeScreenController>().shuffleAll(
      emptyMessage: l10n?.noSongsInLibrary ?? 'No songs in library',
      playFromName: l10n?.shuffleAll ?? 'Shuffle all',
    );
  }

  void _shuffleFavorites() {
    final ctx = Get.context;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx);
    Get.find<HomeScreenController>().shuffleFavorites(
      emptyMessage: l10n?.favoritesEmpty ?? 'Favourites is empty',
      playFromName: l10n?.favorites ?? 'Favourites',
    );
  }

  void _setTheme(String themeName) {
    ThemeType type;
    switch (themeName) {
      case 'dark':
        type = ThemeType.dark;
        break;
      case 'oled':
        type = ThemeType.oled;
        break;
      case 'light':
        type = ThemeType.light;
        break;
      default:
        return;
    }
    Get.find<SettingsScreenController>().onThemeChange(type);
  }

  @override
  void onClose() {
    _msgSub?.cancel();
    _ctxSub?.cancel();
    _stateThrottle?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}
