part of 'settings_screen_controller.dart';

mixin _SettingsScreenControllerBase on GetxController {

  final settingsSectionKeys = List.generate(8, (_) => GlobalKey());
  late String _supportDir;
  final cacheSongs = false.obs;
  final setBox = Hive.box("AppPrefs");
  final themeModetype = ThemeType.system.obs;
  final skipSilenceEnabled = false.obs;
  final loudnessNormalizationEnabled = false.obs;
  final noOfHomeScreenContent = 3.obs;
  final streamingQuality = AudioQuality.High.obs;
  final playerUi = 0.obs;
  final slidableActionEnabled = true.obs;
  final isIgnoringBatteryOptimizations = false.obs;
  final autoOpenPlayer = false.obs;
  final discoverContentType = "QP".obs;
  final isNewVersionAvailable = false.obs;
  final latestAvailableVersion = ''.obs;
  final isLinkedWithPiped = false.obs;
  final stopPlyabackOnSwipeAway = false.obs;
  final currentAppLanguageCode = "en_AU".obs;
  final downloadLocationPath = "".obs;
  final exportLocationPath = "".obs;
  final downloadingFormat = "".obs;
  final autoDownloadFavoriteSongEnabled = false.obs;
  final isTransitionAnimationDisabled = false.obs;
  final animationSpeed = AnimationSpeed.fast.obs;
  final isBottomNavBarEnabled = false.obs;
  final sidebarMode = SidebarMode.auto.obs;
  final nowPlayingLayout = NowPlayingLayout.sideView.obs;
  final lyricsDynamicColorEnabled = true.obs;
  final syncedLyricsHighlightStyle = SyncedLyricsHighlightStyle.karaoke.obs;
  final backgroundPlayEnabled = true.obs;
  final keepScreenAwake = false.obs;
  final restorePlaybackSession = false.obs;
  final autoRadioEnabled = true.obs;
  final cacheHomeScreenData = true.obs;
  final checkForUpdatesOnStartup = true.obs;
  final playbackDiagnosticsEnabled = false.obs;
  final discordRpcEnabled = false.obs;
  final discordAppId = ''.obs;
  final _currentVersion = ''.obs;
  final servers = <SettingsServer>[].obs;
  final activeServerId = RxnInt();
  final demoServerNoticePending = false.obs;

  String get currentVersion =>
      _currentVersion.value.isEmpty ? '0.0.0' : _currentVersion.value;

  SettingsServer? get activeServer {
    final id = activeServerId.value;
    if (id != null) {
      try {
        return servers.firstWhere((s) => s.id == id);
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=settings.activeServer.resolveById] Active server id=$id not found, using fallback: $e\n$st');
      }
    }
    if (servers.isEmpty) return null;
    try {
      return servers.firstWhere((s) => !s.isDefault);
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=settings.activeServer.resolvePrimary] No non-default server found, using first entry: $e\n$st');
      return servers.first;
    }
  }

  static SettingsServer get _defaultServer => SettingsServer(
        id: SettingsServer.defaultServerId,
        name: 'YouTube Music',
        type: ServerType.youtubeMusic,
        isDefault: true,
      );

  MusicBackend? _cachedBackend;
  int? _cachedBackendServerId;

  MusicBackend get currentBackend {
    final active = activeServer;
    if (active != null) {
      if (_cachedBackendServerId != active.id) {
        _cachedBackend = createBackend(active);
        _cachedBackendServerId = active.id;
      }
      return _cachedBackend!;
    }
    if (kIsPlayStore && servers.isEmpty) return NoOpBackend();
    return createBackend(_defaultServer);
  }

  double get animationSpeedFactor {
    switch (animationSpeed.value) {
      case AnimationSpeed.off:
        return 0.0;
      case AnimationSpeed.fast:
        return 0.7;
      case AnimationSpeed.normal:
        return 1.0;
      case AnimationSpeed.slow:
        return 1.4;
    }
  }

  get currentVision => currentVersion;
  get isCurrentPathsupportDownDir =>
      "$_supportDir/Music" == downloadLocationPath.toString();
  String get supportDirPath => _supportDir;

  int get playbackDiagnosticsCount =>
      Get.find<PlaybackDiagnosticsService>().eventCount;

  Future<String> get dbDir async {
    if (GetPlatform.isDesktop) {
      return "$supportDirPath/db";
    } else {
      return (await getApplicationDocumentsDirectory()).path;
    }
  }

void onInit();
  _checkNewVersion();
  Future<String> _createInAppSongDownDir();
  Future<void> _setInitValue();
  void _persistServers();
  void _onActiveServerChanged();
  Future<void> _migrateGlobalToServerSpecific();
  Future<String?> testServerConnection(SettingsServer server);
  void addServerWithCredentials( ServerType type, { String? serverUrl, String? username, String? password, });
  void updateServer( int id, { String? serverUrl, String? username, String? password, });
  void removeServer(int id);
  void setActiveServer(int id);
  String _serverTypeLabel(ServerType type);
  void invalidateBackendCache();
  void setAppLanguage(String? val);
  void setContentNumber(int? no);
  void setStreamingQuality(dynamic val);
  void setPlayerUi(dynamic val);
  void enableBottomNavBar(bool val);
  void setSidebarMode(SidebarMode? mode);
  void setNowPlayingLayout(NowPlayingLayout? layout);
  void setLyricsDynamicColorEnabled(bool value);
  void setSyncedLyricsHighlightStyle(SyncedLyricsHighlightStyle style);
  void setAnimationSpeed(AnimationSpeed speed);
  void toggleSlidableAction(bool val);
  void changeDownloadingFormat(String? val);
  void disableTransitionAnimation(bool val);
  void onThemeChange(dynamic val);
  void onContentChange(dynamic value);
  Future<void> setExportedLocation();
  Future<void> setDownloadLocation();
  void resetDownloadLocation();
  Future<void> clearImagesCache();
  void toggleCachingSongsValue(bool value);
  void toggleSkipSilence(bool val);
  void toggleLoudnessNormalization(bool val);
  void toggleRestorePlaybackSession(bool val);
  Future<void> toggleCacheHomeScreenData(bool val);
  void toggleAutoDownloadFavoriteSong(bool val);
  void toggleCheckForUpdatesOnStartup(bool val);
  void togglePlaybackDiagnostics(bool val);
  void toggleBackgroundPlay(bool val);
  void toggleKeepScreenAwake(bool val);
  void toggleAutoRadio(bool val);
  void toggleAutoOpenPlayer(bool val);
  void toggleStopPlyabackOnSwipeAway(bool val);
  void toggleDiscordRpc(bool val);
  void setDiscordAppId(String val);
  Future<void> clearPlaybackDiagnostics();
  Future<String?> exportPlaybackDiagnostics();
  String getPlaybackDiagnosticsText({int limit = 400, bool pretty = false});
  Future<bool> copyPlaybackDiagnosticsToClipboard( {int limit = 400, bool pretty = false});
  Future<void> enableIgnoringBatteryOptimizations();
  Future<void> unlinkPiped();
  Future<void> resetAppSettingsToDefault();
  Future<void> closeAllDatabases();
  Future<void> resyncLibraryNow();

}

