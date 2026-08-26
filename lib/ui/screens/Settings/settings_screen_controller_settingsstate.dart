part of 'settings_screen_controller.dart';

mixin _SettingsStateMixin on _SettingsScreenControllerBase {
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

}
