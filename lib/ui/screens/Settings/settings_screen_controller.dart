import 'dart:async';
import '/l10n/app_localizations.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:doudou/services/permission_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../utils/server_storage.dart';
import '../../../utils/update_check_flag_file.dart';
import '/services/piped_service.dart';
import '/services/library_sync_service.dart';
import '/services/playback_diagnostics_service.dart';
import '/services/discord_rpc_service.dart';
import '../Library/library_controller.dart';
import '../../widgets/snackbar.dart';
import '../../../utils/helper.dart';
import '/services/music_service.dart';
import '/ui/player/player_controller.dart';
import '../Home/home_screen_controller.dart';
import '/ui/utils/theme_controller.dart';
import '/app/settings/app_settings_controller.dart';

import '/models/server.dart';
import '/services/backend/backend_factory.dart';
import '/services/backend/jellyfin_backend.dart';
import '/services/backend/music_backend.dart';
import '/services/backend/subsonic_backend.dart';
import '/services/backend/noop_backend.dart';

const bool kIsPlayStore =
    bool.fromEnvironment('PLAYSTORE', defaultValue: false);

enum SidebarMode { auto, collapsed, expanded }

enum NowPlayingLayout { sideView, playBar }

const supportedLocalesDisplay = {
  "en_AU": "English (Australian)",
  "zh": "简体中文",
  "ru": "Русский",
};

enum AnimationSpeed { off, fast, normal, slow }

enum SyncedLyricsHighlightStyle { block, karaoke }

class SettingsScreenController extends GetxController {
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

  void invalidateBackendCache() {
    _cachedBackend = null;
    _cachedBackendServerId = null;
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

  @override
  void onInit() {
    _setInitValue();
    _createInAppSongDownDir();
    PackageInfo.fromPlatform().then((info) {
      _currentVersion.value = info.version;
      if (updateCheckFlag) _checkNewVersion();
    });
    super.onInit();
  }

  get currentVision => currentVersion;
  get isCurrentPathsupportDownDir =>
      "$_supportDir/Music" == downloadLocationPath.toString();
  String get supportDirPath => _supportDir;

  _checkNewVersion() {
    newVersionCheck(currentVersion).then((v) {
      if (v != null) {
        isNewVersionAvailable.value = true;
        latestAvailableVersion.value = v;
      }
    });
  }

  Future<String> _createInAppSongDownDir() async {
    _supportDir = (await getApplicationSupportDirectory()).path;
    final directory = Directory("$_supportDir/Music/");
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return "$_supportDir/Music";
  }

  Future<void> _setInitValue() async {
    final isDesktop = GetPlatform.isDesktop;
    const supported = ['en_AU', 'zh', 'ru'];
    final appLang = setBox.get('currentAppLanguageCode') ?? "en_AU";
    final normalized = appLang == "zh_Hant" ||
            appLang == "zh_Hans" ||
            appLang == "zh-CN" ||
            appLang == "zh-TW"
        ? "zh"
        : supported.contains(appLang)
            ? appLang
            : "en_AU";
    currentAppLanguageCode.value = normalized;
    if (normalized != appLang) setBox.put('currentAppLanguageCode', normalized);
    isBottomNavBarEnabled.value = false;
    setBox.put("isBottomNavBarEnabled", false);
    final rawSidebarMode = setBox.get("sidebarMode");
    final modeIndex = rawSidebarMode is int ? rawSidebarMode : 0;
    sidebarMode.value =
        (modeIndex >= 0 && modeIndex < SidebarMode.values.length)
            ? SidebarMode.values[modeIndex]
            : SidebarMode.auto;
    final rawNowPlayingLayout = setBox.get("nowPlayingLayout");
    final npIndex = rawNowPlayingLayout is int ? rawNowPlayingLayout : 0;
    nowPlayingLayout.value =
        (npIndex >= 0 && npIndex < NowPlayingLayout.values.length)
            ? NowPlayingLayout.values[npIndex]
            : NowPlayingLayout.sideView;
    noOfHomeScreenContent.value = setBox.get("noOfHomeScreenContent") ?? 3;

    final legacyDisabled = setBox.get("isTransitionAnimationDisabled") ?? false;
    final rawAnimSpeed = setBox.get("animationSpeed");
    if (rawAnimSpeed is int &&
        rawAnimSpeed >= 0 &&
        rawAnimSpeed < AnimationSpeed.values.length) {
      animationSpeed.value = AnimationSpeed.values[rawAnimSpeed];
    } else {
      animationSpeed.value =
          legacyDisabled ? AnimationSpeed.off : AnimationSpeed.fast;
      setBox.put("animationSpeed", animationSpeed.value.index);
    }
    isTransitionAnimationDisabled.value =
        animationSpeed.value == AnimationSpeed.off || legacyDisabled;
    setBox.put(
        "isTransitionAnimationDisabled", isTransitionAnimationDisabled.value);
    cacheSongs.value = setBox.get('cacheSongs') ?? false;
    final rawThemeModeType = setBox.get('themeModeType');
    final parsedThemeModeType = themeTypeFromStorage(rawThemeModeType);
    themeModetype.value = parsedThemeModeType;
    if (rawThemeModeType is! int ||
        rawThemeModeType < 0 ||
        rawThemeModeType >= ThemeType.values.length) {
      setBox.put('themeModeType', themeTypeToStorage(parsedThemeModeType));
    }
    skipSilenceEnabled.value =
        isDesktop ? false : setBox.get("skipSilenceEnabled");
    loudnessNormalizationEnabled.value = isDesktop
        ? false
        : (setBox.get("loudnessNormalizationEnabled") ?? false);
    autoOpenPlayer.value = (setBox.get("autoOpenPlayer") ?? true);
    restorePlaybackSession.value =
        setBox.get("restrorePlaybackSession") ?? false;
    cacheHomeScreenData.value = setBox.get("cacheHomeScreenData") ?? true;
    checkForUpdatesOnStartup.value =
        setBox.get("checkForUpdatesOnStartup") ?? true;
    playbackDiagnosticsEnabled.value =
        setBox.get(PlaybackDiagnosticsService.enabledKey) ?? false;
    discordRpcEnabled.value = setBox.get('discordRpcEnabled') ?? false;
    discordAppId.value = setBox.get('discordAppId') ?? '';
    streamingQuality.value =
        AudioQuality.values[setBox.get('streamingQuality')];
    playerUi.value = isDesktop ? 0 : (setBox.get('playerUi') ?? 0);
    backgroundPlayEnabled.value = setBox.get("backgroundPlayEnabled") ?? true;
    keepScreenAwake.value = setBox.get("keepScreenAwake") ?? false;
    autoRadioEnabled.value = setBox.get("autoRadioEnabled") ?? true;
    final downloadPath =
        setBox.get('downloadLocationPath') ?? await _createInAppSongDownDir();
    final isExternalDownPath = downloadPath.contains('/storage/emulated/');
    if ((isDesktop && downloadPath.contains("emulated")) ||
        (PermissionService.isScopedStorage && isExternalDownPath)) {
      final defaultPath = await _createInAppSongDownDir();
      setBox.put("downloadLocationPath", defaultPath);
      downloadLocationPath.value = defaultPath;
    } else {
      downloadLocationPath.value = downloadPath;
    }

    final exportPath =
        setBox.get("exportLocationPath") ?? "/storage/emulated/0/Music";
    if (PermissionService.isScopedStorage &&
        exportPath.contains('/storage/emulated/')) {
      final defaultExport = "$_supportDir/Exports";
      await Directory(defaultExport).create(recursive: true);
      setBox.put("exportLocationPath", defaultExport);
      exportLocationPath.value = defaultExport;
    } else {
      exportLocationPath.value = exportPath;
    }
    downloadingFormat.value = setBox.get('downloadingFormat') ?? "m4a";
    discoverContentType.value = setBox.get('discoverContentType') ?? "QP";
    slidableActionEnabled.value = setBox.get('slidableActionEnabled') ?? true;
    if (setBox.containsKey("piped")) {
      isLinkedWithPiped.value = setBox.get("piped")['isLoggedIn'];
    }
    stopPlyabackOnSwipeAway.value =
        setBox.get('stopPlyabackOnSwipeAway') ?? false;
    if (GetPlatform.isAndroid) {
      isIgnoringBatteryOptimizations.value =
          (await Permission.ignoreBatteryOptimizations.isGranted);
    }
    autoDownloadFavoriteSongEnabled.value =
        setBox.get("autoDownloadFavoriteSongEnabled") ?? false;
    lyricsDynamicColorEnabled.value =
        setBox.get("lyricsDynamicColorEnabled") ?? true;
    final rawLyricsHighlightStyle = setBox.get("syncedLyricsHighlightStyle");
    final styleIndex =
        rawLyricsHighlightStyle is int ? rawLyricsHighlightStyle : 0;
    syncedLyricsHighlightStyle.value = (styleIndex >= 0 &&
            styleIndex < SyncedLyricsHighlightStyle.values.length)
        ? SyncedLyricsHighlightStyle.values[styleIndex]
        : SyncedLyricsHighlightStyle.karaoke;
    if (rawLyricsHighlightStyle is! int ||
        styleIndex < 0 ||
        styleIndex >= SyncedLyricsHighlightStyle.values.length) {
      setBox.put("syncedLyricsHighlightStyle",
          SyncedLyricsHighlightStyle.karaoke.index);
    }

    String defaultServerDisplayName() {
      final ctx = Get.context;
      if (ctx != null) {
        final l10n = AppLocalizations.of(ctx);
        if (l10n != null) return l10n.youtubeMusic;
      }
      return 'YouTube Music';
    }

    final defaultServer = SettingsServer(
      id: SettingsServer.defaultServerId,
      name: defaultServerDisplayName(),
      type: ServerType.youtubeMusic,
      isDefault: true,
    );
    final savedServers = setBox.get('servers');
    if (savedServers is List && savedServers.isNotEmpty) {
      servers.assignAll(
        savedServers
            .whereType<Map>()
            .map((e) => SettingsServer.fromMap(e.cast<String, dynamic>()))
            .toList(),
      );
    } else if (!kIsPlayStore) {
      servers.assignAll([defaultServer]);
    } else {
      final demoSeeded = setBox.get('demoServerSeeded') == true;
      if (!demoSeeded) {
        final demoServer = SettingsServer(
          id: DateTime.now().millisecondsSinceEpoch,
          name: 'Jellyfin Demo',
          type: ServerType.jellyfin,
          isDefault: false,
          serverUrl: 'https://demo.jellyfin.org/stable',
          username: 'demo',
          password: '',
        );
        servers.assignAll([demoServer]);
        activeServerId.value = demoServer.id;
        setBox.put('demoServerSeeded', true);
        demoServerNoticePending.value = true;
      }
    }
    final savedActive = setBox.get('activeServerId');
    if (savedActive is int &&
        servers.any((server) => server.id == savedActive)) {
      activeServerId.value = savedActive;
    } else if (servers.isNotEmpty && activeServerId.value == null) {
      final nonDefault =
          servers.firstWhereOrNull((server) => !server.isDefault);
      activeServerId.value = (nonDefault ?? servers.first).id;
    }
    _persistServers();

    // Migrate data from global boxes to server-specific boxes
    await _migrateGlobalToServerSpecific();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<SettingsScreenController>()) return;
      _onActiveServerChanged();
      if (Get.isRegistered<LibrarySyncService>()) {
        unawaited(Get.find<LibrarySyncService>().maybeSyncAllIfStale());
      } else {
        Get.find<LibrarySyncService>();
        unawaited(Get.find<LibrarySyncService>().maybeSyncAllIfStale());
      }
    });
  }

  void setAppLanguage(String? val) {
    if (val == null) return;
    final locale = val == 'en_AU' ? const Locale('en', 'AU') : Locale(val);
    final langCode = val;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.updateLocale(locale);
      Get.find<MusicServices>().hlCode = langCode;
      Get.find<HomeScreenController>().loadContentFromNetwork(silent: true);
      currentAppLanguageCode.value = langCode;
      setBox.put('currentAppLanguageCode', langCode);
      Get.find<AppSettingsController>().setLocale(langCode);
    });
  }

  void setContentNumber(int? no) {
    noOfHomeScreenContent.value = no!;
    setBox.put("noOfHomeScreenContent", no);
  }

  void setStreamingQuality(dynamic val) {
    setBox.put("streamingQuality", AudioQuality.values.indexOf(val));
    streamingQuality.value = val;
  }

  void setPlayerUi(dynamic val) {
    final playerCon = Get.find<PlayerController>();
    setBox.put("playerUi", val);
    if (val == 1 && playerCon.gesturePlayerStateAnimationController == null) {
      playerCon.initGesturePlayerStateAnimationController();
    }

    playerUi.value = val;
  }

  void enableBottomNavBar(bool val) {
    final homeScrCon = Get.find<HomeScreenController>();
    final playerCon = Get.find<PlayerController>();
    if (val) {
      homeScrCon.onSideBarTabSelected(5);
      isBottomNavBarEnabled.value = true;
    } else {
      isBottomNavBarEnabled.value = false;
      homeScrCon.onSideBarTabSelected(7);
    }
    if (!Get.find<PlayerController>().initFlagForPlayer) {
      playerCon.playerPanelMinHeight.value =
          val ? 80.0 : 80.0 + Get.mediaQuery.viewPadding.bottom;
    }
    setBox.put("isBottomNavBarEnabled", val);
  }

  void setSidebarMode(SidebarMode? mode) {
    if (mode == null) return;
    sidebarMode.value = mode;
    setBox.put("sidebarMode", mode.index);
  }

  void setNowPlayingLayout(NowPlayingLayout? layout) {
    if (layout == null) return;
    nowPlayingLayout.value = layout;
    setBox.put("nowPlayingLayout", layout.index);
  }

  void setLyricsDynamicColorEnabled(bool value) {
    lyricsDynamicColorEnabled.value = value;
    setBox.put("lyricsDynamicColorEnabled", value);
  }

  void setSyncedLyricsHighlightStyle(SyncedLyricsHighlightStyle style) {
    syncedLyricsHighlightStyle.value = style;
    setBox.put("syncedLyricsHighlightStyle", style.index);
  }

  void setAnimationSpeed(AnimationSpeed speed) {
    animationSpeed.value = speed;
    setBox.put('animationSpeed', speed.index);
    final disabled = speed == AnimationSpeed.off;
    isTransitionAnimationDisabled.value = disabled;
    setBox.put('isTransitionAnimationDisabled', disabled);
  }

  void toggleSlidableAction(bool val) {
    setBox.put("slidableActionEnabled", val);
    slidableActionEnabled.value = val;
  }

  void changeDownloadingFormat(String? val) {
    setBox.put("downloadingFormat", val);
    downloadingFormat.value = val!;
  }

  Future<void> setExportedLocation() async {
    if (PermissionService.isScopedStorage) {
      final defaultExport = "$_supportDir/Exports";
      await Directory(defaultExport).create(recursive: true);
      setBox.put("exportLocationPath", defaultExport);
      exportLocationPath.value = defaultExport;
      return;
    }

    if (!await PermissionService.getExtStoragePermission()) {
      return;
    }

    final String? pickedFolderPath = await FilePicker.platform
        .getDirectoryPath(dialogTitle: "Select export file folder");
    if (pickedFolderPath == '/' || pickedFolderPath == null) {
      return;
    }

    setBox.put("exportLocationPath", pickedFolderPath);
    exportLocationPath.value = pickedFolderPath;
  }

  Future<void> setDownloadLocation() async {
    if (PermissionService.isScopedStorage) {
      resetDownloadLocation();
      return;
    }

    if (!await PermissionService.getExtStoragePermission()) {
      return;
    }

    final String? pickedFolderPath = await FilePicker.platform
        .getDirectoryPath(dialogTitle: "Select downloads folder");
    if (pickedFolderPath == '/' || pickedFolderPath == null) {
      return;
    }

    setBox.put("downloadLocationPath", pickedFolderPath);
    downloadLocationPath.value = pickedFolderPath;
  }

  void disableTransitionAnimation(bool val) {
    setBox.put('isTransitionAnimationDisabled', val);
    isTransitionAnimationDisabled.value = val;
    if (val) {
      animationSpeed.value = AnimationSpeed.off;
      setBox.put('animationSpeed', AnimationSpeed.off.index);
    } else {
      if (animationSpeed.value == AnimationSpeed.off) {
        animationSpeed.value = AnimationSpeed.fast;
        setBox.put('animationSpeed', AnimationSpeed.fast.index);
      }
    }
  }

  Future<void> clearImagesCache() async {
    final tempImgDirPath =
        "${(await getApplicationCacheDirectory()).path}/libCachedImageData";
    final tempImgDir = Directory(tempImgDirPath);
    try {
      if (await tempImgDir.exists()) {
        await tempImgDir.delete(recursive: true);
      }
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=settings.clearImagesCache] Failed to clear image cache at $tempImgDirPath: $e\n$st');
    }
  }

  void resetDownloadLocation() {
    final defaultPath = "$_supportDir/Music";
    setBox.put("downloadLocationPath", defaultPath);
    downloadLocationPath.value = defaultPath;
  }

  void addServerWithCredentials(
    ServerType type, {
    String? serverUrl,
    String? username,
    String? password,
  }) {
    String name;
    if (type == ServerType.youtubeMusic) {
      name = _serverTypeLabel(type);
    } else {
      name = serverUrl?.trim().isNotEmpty == true
          ? (serverUrl!
              .replaceFirst(RegExp(r'^https?://'), '')
              .split('/')
              .first)
          : _serverTypeLabel(type);
      final existingOfType = servers.where((s) => s.type == type).length;
      if (existingOfType > 0) name = '$name #${existingOfType + 1}';
    }
    final server = SettingsServer(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      type: type,
      isDefault: false,
      serverUrl: serverUrl?.trim().isEmpty == true ? null : serverUrl?.trim(),
      username: username?.trim().isEmpty == true ? null : username?.trim(),
      password: password?.trim().isEmpty == true ? null : password?.trim(),
    );
    servers.add(server);
    _persistServers();
  }

  void updateServer(
    int id, {
    String? serverUrl,
    String? username,
    String? password,
  }) {
    final idx = servers.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final s = servers[idx];
    if (s.isDefault) return;
    servers[idx] = s.copyWith(
      serverUrl: serverUrl ?? s.serverUrl,
      username: username ?? s.username,
      password:
          password != null ? (password.isEmpty ? null : password) : s.password,
    );
    _persistServers();
  }

  void removeServer(int id) {
    if (id == SettingsServer.defaultServerId) return;
    servers.removeWhere((s) => s.id == id);
    if (activeServerId.value == id) {
      if (servers.isEmpty) {
        activeServerId.value = null;
      } else {
        final nonDefault =
            servers.firstWhereOrNull((server) => !server.isDefault);
        activeServerId.value = (nonDefault ?? servers.first).id;
      }
    }
    _persistServers();
    _onActiveServerChanged();
  }

  void setActiveServer(int id) {
    if (!servers.any((s) => s.id == id)) return;
    if (activeServerId.value == id) return;
    activeServerId.value = id;
    setBox.put('activeServerId', id);
    _onActiveServerChanged();
  }

  String _serverTypeLabel(ServerType type) {
    switch (type) {
      case ServerType.youtubeMusic:
        return AppLocalizations.of(Get.context!)!.youtubeMusic;
      case ServerType.subsonic:
        return AppLocalizations.of(Get.context!)!.subsonic;
      case ServerType.jellyfin:
        return AppLocalizations.of(Get.context!)!.jellyfin;
      case ServerType.plex:
        return AppLocalizations.of(Get.context!)!.plex;
    }
  }

  void _persistServers() {
    setBox.put(
      'servers',
      servers.map((s) => s.toMap()).toList(),
    );
  }

  void _onActiveServerChanged() {
    invalidateBackendCache();
    if (Get.isRegistered<PlayerController>()) {
      final player = Get.find<PlayerController>();
      player.clearQueue();
      player.pause();
    }

    if (Get.isRegistered<HomeScreenController>()) {
      final home = Get.find<HomeScreenController>();
      home.invalidateHomeLibrarySections();
      home.loadContentFromNetwork(silent: true);
    }

    if (Get.isRegistered<LibrarySongsController>()) {
      final ctrl = Get.find<LibrarySongsController>();
      ctrl.tempListContainer.clear();
      ctrl.librarySongsList.clear();
      ctrl.isSongFetched.value = false;
      // ignore: discarded_futures
      ctrl.init();
    }

    if (Get.isRegistered<LibraryPlaylistsController>()) {
      final ctrl = Get.find<LibraryPlaylistsController>();
      ctrl.tempListContainer = [];
      ctrl.libraryPlaylists.value =
          Get.find<LibraryPlaylistsController>().initPlst;
      ctrl.isContentFetched.value = false;
      // ignore: discarded_futures
      ctrl.refreshLib();
    }

    if (Get.isRegistered<LibraryAlbumsController>()) {
      final ctrl = Get.find<LibraryAlbumsController>();
      ctrl.tempListContainer = [];
      ctrl.libraryAlbums.clear();
      ctrl.isContentFetched.value = false;
      // ignore: discarded_futures
      ctrl.refreshLib();
    }

    if (Get.isRegistered<LibraryArtistsController>()) {
      final ctrl = Get.find<LibraryArtistsController>();
      ctrl.tempListContainer = [];
      ctrl.libraryArtists.clear();
      ctrl.isContentFetched.value = false;
      // ignore: discarded_futures
      ctrl.refreshLib();
    }
    if (Get.isRegistered<LibrarySyncService>()) {
      unawaited(Get.find<LibrarySyncService>().maybeSyncAllIfStale());
    }
  }

  void onThemeChange(dynamic val) {
    final type = val as ThemeType;
    Get.find<AppSettingsController>().setThemeModeType(themeTypeToStorage(type));
    themeModetype.value = type;
    Get.find<ThemeController>().changeThemeModeType(type);
  }

  void onContentChange(dynamic value) {
    setBox.put('discoverContentType', value);
    discoverContentType.value = value;
    Get.find<HomeScreenController>().changeDiscoverContent(value);
  }

  void toggleCachingSongsValue(bool value) {
    setBox.put("cacheSongs", value);
    cacheSongs.value = value;
  }

  void toggleSkipSilence(bool val) {
    Get.find<PlayerController>().toggleSkipSilence(val);
    setBox.put('skipSilenceEnabled', val);
    skipSilenceEnabled.value = val;
  }

  void toggleLoudnessNormalization(bool val) {
    Get.find<PlayerController>().toggleLoudnessNormalization(val);
    setBox.put("loudnessNormalizationEnabled", val);
    loudnessNormalizationEnabled.value = val;
  }

  void toggleRestorePlaybackSession(bool val) {
    setBox.put("restrorePlaybackSession", val);
    restorePlaybackSession.value = val;
  }

  Future<void> toggleCacheHomeScreenData(bool val) async {
    setBox.put("cacheHomeScreenData", val);
    cacheHomeScreenData.value = val;
    final boxName = homeScreenDataBoxName(activeServerId.value ?? 0);
    if (!val) {
      final box = await Hive.openBox(boxName);
      await box.clear();
    } else {
      await Hive.openBox(boxName);
      Get.find<HomeScreenController>().cachedHomeScreenData(updateAll: true);
    }
  }

  void toggleAutoDownloadFavoriteSong(bool val) {
    setBox.put("autoDownloadFavoriteSongEnabled", val);
    autoDownloadFavoriteSongEnabled.value = val;
  }

  void toggleCheckForUpdatesOnStartup(bool val) {
    setBox.put("checkForUpdatesOnStartup", val);
    checkForUpdatesOnStartup.value = val;
  }

  void togglePlaybackDiagnostics(bool val) {
    setBox.put(PlaybackDiagnosticsService.enabledKey, val);
    playbackDiagnosticsEnabled.value = val;
  }

  void toggleDiscordRpc(bool val) {
    setBox.put('discordRpcEnabled', val);
    discordRpcEnabled.value = val;
    if (Get.isRegistered<DiscordRpcService>()) {
      Get.find<DiscordRpcService>().reconfigure();
    }
  }

  void setDiscordAppId(String val) {
    final trimmed = val.trim();
    setBox.put('discordAppId', trimmed);
    discordAppId.value = trimmed;
  }

  Future<void> clearPlaybackDiagnostics() async {
    await Get.find<PlaybackDiagnosticsService>().clear();
  }

  Future<String?> exportPlaybackDiagnostics() async {
    return Get.find<PlaybackDiagnosticsService>().exportToPickedLocation();
  }

  int get playbackDiagnosticsCount =>
      Get.find<PlaybackDiagnosticsService>().eventCount;

  String getPlaybackDiagnosticsText({int limit = 400, bool pretty = false}) {
    final diag = Get.find<PlaybackDiagnosticsService>();
    if (pretty) {
      return diag.getEventsAsPrettyText(limit: limit);
    }
    return diag.getEventsAsJsonl(limit: limit);
  }

  Future<bool> copyPlaybackDiagnosticsToClipboard(
      {int limit = 400, bool pretty = false}) async {
    final text = getPlaybackDiagnosticsText(limit: limit, pretty: pretty);
    if (text.trim().isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  void toggleBackgroundPlay(bool val) {
    setBox.put('backgroundPlayEnabled', val);
    backgroundPlayEnabled.value = val;
  }

  void toggleKeepScreenAwake(bool val) {
    setBox.put('keepScreenAwake', val);
    keepScreenAwake.value = val;
  }

  void toggleAutoRadio(bool val) {
    setBox.put('autoRadioEnabled', val);
    autoRadioEnabled.value = val;
  }

  Future<void> enableIgnoringBatteryOptimizations() async {
    await Permission.ignoreBatteryOptimizations.request();
    isIgnoringBatteryOptimizations.value =
        await Permission.ignoreBatteryOptimizations.isGranted;
  }

  void toggleAutoOpenPlayer(bool val) {
    setBox.put('autoOpenPlayer', val);
    autoOpenPlayer.value = val;
  }

  Future<void> unlinkPiped() async {
    Get.find<PipedServices>().logout();
    isLinkedWithPiped.value = false;
    Get.find<LibraryPlaylistsController>().removePipedPlaylists();
    final box = await Hive.openBox(
        blacklistedPlaylistBoxName(activeServerId.value ?? 0));
    box.clear();
    ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
        Get.context!, AppLocalizations.of(Get.context!)!.unlinkAlert,
        size: SnackBarSize.MEDIUM));
    box.close();
  }

  Future<void> resetAppSettingsToDefault() async {
    await setBox.clear();
  }

  void toggleStopPlyabackOnSwipeAway(bool val) {
    setBox.put('stopPlyabackOnSwipeAway', val);
    stopPlyabackOnSwipeAway.value = val;
  }

  Future<void> closeAllDatabases() async {
    await Hive.close();
  }

  Future<void> resyncLibraryNow() async {
    await Get.find<LibrarySyncService>().syncAll(force: true);
  }

  Future<String> get dbDir async {
    if (GetPlatform.isDesktop) {
      return "$supportDirPath/db";
    } else {
      return (await getApplicationDocumentsDirectory()).path;
    }
  }

  Future<String?> testServerConnection(SettingsServer server) async {
    if (server.type == ServerType.youtubeMusic) return null;
    try {
      final backend = createBackend(server);
      if (backend is JellyfinBackend) {
        await backend.getLibraryPlaylists();
      } else if (backend is SubsonicBackend) {
        await backend.getLibraryPlaylists();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _migrateGlobalToServerSpecific() async {
    const migrationKey = 'serverDataMigrationCompleted';
    if (setBox.get(migrationKey) == true) {
      return;
    }

    try {
      const serverId = SettingsServer.defaultServerId;

      // Migrate SongsCache
      if (await Hive.boxExists('SongsCache')) {
        final oldBox = await Hive.openBox('SongsCache');
        final newBoxName = songsCacheBoxName(serverId);
        final newBox = await Hive.openBox(newBoxName);

        if (oldBox.isNotEmpty && newBox.isEmpty) {
          for (final key in oldBox.keys) {
            await newBox.put(key, oldBox.get(key));
          }
          printINFO(
              'Migrated ${oldBox.length} items from SongsCache to $newBoxName');
        }
        await oldBox.close();
        await Hive.deleteBoxFromDisk('SongsCache');
      }

      // Migrate SongDownloads
      if (await Hive.boxExists('SongDownloads')) {
        final oldBox = await Hive.openBox('SongDownloads');
        final newBoxName = songDownloadsBoxName(serverId);
        final newBox = await Hive.openBox(newBoxName);

        if (oldBox.isNotEmpty && newBox.isEmpty) {
          for (final key in oldBox.keys) {
            await newBox.put(key, oldBox.get(key));
          }
          printINFO(
              'Migrated ${oldBox.length} items from SongDownloads to $newBoxName');
        }
        await oldBox.close();
        await Hive.deleteBoxFromDisk('SongDownloads');
      }

      // Migrate LIBFAV
      if (await Hive.boxExists('LIBFAV')) {
        final oldBox = await Hive.openBox('LIBFAV');
        final newBoxName = libFavBoxName(serverId);
        final newBox = await Hive.openBox(newBoxName);

        if (oldBox.isNotEmpty && newBox.isEmpty) {
          for (final key in oldBox.keys) {
            await newBox.put(key, oldBox.get(key));
          }
          printINFO(
              'Migrated ${oldBox.length} items from LIBFAV to $newBoxName');
        }
        await oldBox.close();
        await Hive.deleteBoxFromDisk('LIBFAV');
      }

      // Migrate SongsUrlCache
      if (await Hive.boxExists('SongsUrlCache')) {
        final oldBox = await Hive.openBox('SongsUrlCache');
        final newBoxName = songsUrlCacheBoxName(serverId);
        final newBox = await Hive.openBox(newBoxName);

        if (oldBox.isNotEmpty && newBox.isEmpty) {
          for (final key in oldBox.keys) {
            await newBox.put(key, oldBox.get(key));
          }
          printINFO(
              'Migrated ${oldBox.length} items from SongsUrlCache to $newBoxName');
        }
        await oldBox.close();
        await Hive.deleteBoxFromDisk('SongsUrlCache');
      }

      setBox.put(migrationKey, true);
      printINFO('Server data migration completed');
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=settings.migrateGlobalToServerSpecific] Migration failed: $e\n$st');
    }
  }
}
