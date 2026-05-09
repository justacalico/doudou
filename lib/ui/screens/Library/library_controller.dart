import 'dart:async';
import 'dart:io';
import '/l10n/app_localizations.dart';
import '/utils/app_l10n.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:doudou/ui/widgets/snackbar.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import '../../../utils/house_keeping.dart';
import '../../widgets/add_to_playlist.dart';
import '/ui/widgets/sort_widget.dart';
import '../../../utils/server_storage.dart';
import '../Settings/settings_screen_controller.dart';
import '/services/piped_service.dart';
import '/services/library_sync_service.dart';
import '../../../utils/helper.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/media_Item_builder.dart';
import '/models/playlist.dart';
import '/models/server.dart';

class LibrarySongsController extends GetxController {
  late RxList<MediaItem> librarySongsList = RxList();
  final isSongFetched = false.obs;
  List<MediaItem> tempListContainer = [];
  SortWidgetController? sortWidgetController;
  final additionalOperationMode = OperationMode.none.obs;
  Worker? _syncWorker;
  int _lastSongsSyncVersion = -1;

  @override
  void onInit() {
    init();
    ever(Get.find<SettingsScreenController>().activeServerId, (_) async {
      if (!Get.isRegistered<LibrarySongsController>()) return;
      await init();
    });
    _syncWorker =
        ever(Get.find<LibrarySyncService>().syncVersionByKind, (_) async {
      final syncService = Get.find<LibrarySyncService>();
      final currVersion = syncService.syncVersionByKind[LibraryKind.songs] ?? 0;
      if (currVersion == _lastSongsSyncVersion) return;
      _lastSongsSyncVersion = currVersion;
      if (!Get.isRegistered<LibrarySongsController>()) return;
      final settings = Get.find<SettingsScreenController>();
      final server = settings.activeServer;
      if (server == null || server.type == ServerType.youtubeMusic) return;
      await init();
    });
    super.onInit();
  }

  Future<void> init() async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final useBackend = server != null && server.type != ServerType.youtubeMusic;

    final localSongs = await _loadLocalSongs();

    if (useBackend) {
      final remoteSongs = await Get.find<LibrarySyncService>()
          .getCachedSongs(currentServerId());
      librarySongsList.value = [...remoteSongs, ...localSongs];
      unawaited(
        Get.find<LibrarySyncService>().maybeSyncKindIfStale(LibraryKind.songs),
      );
    } else {
      librarySongsList.value = localSongs;
    }
    isSongFetched.value = true;
    startHouseKeeping();
  }

  Future<List<MediaItem>> loadAllSongsForShuffle() async {
    // Ensure the library is initialized once, then reuse the in-memory list
    // so shuffle operations are instant even for large libraries.
    if (!isSongFetched.value) {
      await init();
    }
    return librarySongsList.toList();
  }

  Future<List<MediaItem>> _loadLocalSongs() async {
    // Make sure that song cached in system or not cleared by system
    // if cleared then it will remove from database as well
    List<String> songsList = [];
    final cacheDir = (await getTemporaryDirectory()).path;
    final cachedDir = Directory("$cacheDir/cachedSongs/");
    if (await cachedDir.exists()) {
      int scanned = 0;
      await for (final f in cachedDir.list()) {
        final ext = f.path.replaceAll(RegExp(r'^.*\.'), '');
        if (ext == 'mime' || ext == 'part') continue;
        final match = RegExp(".cachedSongs/([^#]*)?.mp3").firstMatch(f.path);
        if (match != null) {
          songsList.add(match[1]!);
        }
        scanned++;
        if (scanned % 200 == 0) {
          await Future.delayed(Duration.zero);
        }
      }
      //printINFO("all files: $downloadedFiles \n $songsList");
    }

    final box = Hive.box(songsCacheBoxName(currentServerId()));
    int checked = 0;
    for (var element in box.keys) {
      if (!songsList.contains(element)) {
        box.delete(element);
      }
      checked++;
      if (checked % 200 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    final songs = box.values
        .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
        .whereType<MediaItem>()
        .toList();

    songs.addAll(Hive.box(songDownloadsBoxName(currentServerId()))
        .values
        .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
        .whereType<MediaItem>()
        .toList());

    // For YouTube Music, also include songs from library albums, playlists,
    // and favorites so the Library Songs view reflects the full library.
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTube = server != null && server.type == ServerType.youtubeMusic;

    if (isYouTube) {
      final serverId = currentServerId();
      final seenIds = songs.map((s) => s.id).toSet();

      // Songs from library albums (stored per-album by browseId).
      try {
        final albumsBox = await Hive.openBox(libraryAlbumsBoxName(serverId));
        int albumIndex = 0;
        for (final raw in albumsBox.values) {
          final album = Album.fromJson(raw as Map);
          final albumSongsBox = await Hive.openBox(album.browseId);
          for (final v in albumSongsBox.values) {
            final m = MediaItemBuilder.fromJson(v as Map);
            if (seenIds.add(m.id)) {
              songs.add(m);
            }
          }
          await albumSongsBox.close();
          albumIndex++;
          if (albumIndex % 8 == 0) {
            await Future.delayed(Duration.zero);
          }
        }
        await albumsBox.close();
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=library.shuffle.loadAlbumSongs] Failed to load album-sourced songs for serverId=$serverId: $e\n$st');
      }

      // Songs from library playlists (excluding special local playlists).
      try {
        if (Get.isRegistered<LibraryPlaylistsController>()) {
          final playlists =
              Get.find<LibraryPlaylistsController>().libraryPlaylists.toList();
          int playlistIndex = 0;
          for (final pl in playlists) {
            final id = pl.playlistId;
            if (id == 'LIBRP' ||
                id == 'LIBFAV' ||
                id == 'SongsCache' ||
                id == 'SongDownloads') {
              continue;
            }
            final boxId = playlistSongsBoxName(id);
            final plSongsBox = await Hive.openBox(boxId);
            for (final v in plSongsBox.values) {
              final m = MediaItemBuilder.fromJson(v as Map);
              if (seenIds.add(m.id)) {
                songs.add(m);
              }
            }
            await plSongsBox.close();
            playlistIndex++;
            if (playlistIndex % 6 == 0) {
              await Future.delayed(Duration.zero);
            }
          }
        }
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=library.shuffle.loadPlaylistSongs] Failed to load playlist-sourced songs for serverId=$serverId: $e\n$st');
      }

      // Songs from favorites box (YouTube Music stores favorites locally).
      try {
        final favBox = await Hive.openBox(libFavBoxName(serverId));
        for (final v in favBox.values) {
          final m = MediaItemBuilder.fromJson(v as Map);
          if (seenIds.add(m.id)) {
            songs.add(m);
          }
        }
        await favBox.close();
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=library.shuffle.loadFavoriteSongs] Failed to load favorite-sourced songs for serverId=$serverId: $e\n$st');
      }
    }

    return songs;
  }

  void onSort(SortType sortType, bool isAscending) {
    final songlist = librarySongsList.toList();
    sortSongsNVideos(songlist, sortType, isAscending);
    librarySongsList.value = songlist;
  }

  void onSearchStart(String? tag) {
    tempListContainer = librarySongsList.toList();
  }

  void onSearch(String value, String? tag) {
    final songlist = tempListContainer
        .where((element) =>
            element.title.toLowerCase().contains(value.toLowerCase()))
        .toList();
    librarySongsList.value = songlist;
  }

  void onSearchClose(String? tag) {
    librarySongsList.value = tempListContainer.toList();
    tempListContainer.clear();
  }

  /// remove song from library list and from storage only, not from database
  Future<void> removeSong(MediaItem item, bool isDownloaded,
      {String? url}) async {
    if (tempListContainer.isNotEmpty) {
      tempListContainer.remove(item);
    }
    librarySongsList.remove(item);
    String filePath = "";
    if (isDownloaded) {
      filePath = item.extras!['url'] ?? url;
    } else {
      final cacheDir = (await getTemporaryDirectory()).path;
      filePath = "$cacheDir/cachedSongs/${item.id}.mp3";
    }

    if (await (File(filePath)).exists()) {
      await (File(filePath)).delete();
    }

    final thumbFile = File(
        "${Get.find<SettingsScreenController>().supportDirPath}/thumbnails/${item.id}.png");
    if (await thumbFile.exists()) {
      await thumbFile.delete();
    }
  }

//Additional operations
  final additionalOperationTempList = [].obs;
  final additionalOperationTempMap = <int, bool>{}.obs;

  void startAdditionalOperation(
      SortWidgetController sortWidgetController_, OperationMode mode) {
    sortWidgetController = sortWidgetController_;
    additionalOperationTempList.value = librarySongsList.toList();
    if (mode == OperationMode.addToPlaylist || mode == OperationMode.delete) {
      for (int i = 0; i < additionalOperationTempList.length; i++) {
        additionalOperationTempMap[i] = false;
      }
    }
    additionalOperationMode.value = mode;
  }

  void checkIfAllSelected() {
    sortWidgetController!.isAllSelected.value =
        !additionalOperationTempMap.containsValue(false);
  }

  void selectAll(bool selected) {
    for (int i = 0; i < additionalOperationTempList.length; i++) {
      additionalOperationTempMap[i] = selected;
    }
  }

  void performAdditionalOperation() {
    final currMode = additionalOperationMode.value;
    if (currMode == OperationMode.delete) {
      deleteMultipleSongs(selectedSongs()).then((value) {
        sortWidgetController?.setActiveMode(OperationMode.none);
        cancelAdditionalOperation();
      });
    } else if (currMode == OperationMode.addToPlaylist) {
      showDialog(
        context: Get.context!,
        builder: (context) => AddToPlaylist(selectedSongs()),
      ).whenComplete(() {
        Get.delete<AddToPlaylistController>();
        sortWidgetController?.setActiveMode(OperationMode.none);
        cancelAdditionalOperation();
      });
    }
  }

  Future<void> deleteMultipleSongs(List<MediaItem> songs) async {
    final downloadsBox = await Hive.openBox(songDownloadsBoxName(currentServerId()));
    final cacheBox = await Hive.openBox(songsCacheBoxName(currentServerId()));
    for (MediaItem element in songs) {
      if (downloadsBox.containsKey(element.id)) {
        await downloadsBox.delete(element.id);
        removeSong(element, true);
      } else {
        await cacheBox.delete(element.id);
        removeSong(element, false);
      }
    }
  }

  List<MediaItem> selectedSongs() {
    return additionalOperationTempMap.entries
        .map((item) {
          if (item.value) {
            return additionalOperationTempList[item.key];
          }
        })
        .whereType<MediaItem>()
        .toList();
  }

  void cancelAdditionalOperation() {
    sortWidgetController!.isAllSelected.value = false;
    sortWidgetController = null;
    additionalOperationMode.value = OperationMode.none;
    additionalOperationTempList.clear();
    additionalOperationTempMap.clear();
  }

  @override
  void onClose() {
    _syncWorker?.dispose();
    super.onClose();
  }
}

int _currentServerId() => currentServerId();

class LibraryPlaylistsController extends GetxController
    with GetTickerProviderStateMixin {
  late AnimationController controller;
  Worker? _syncWorker;
  int _lastPlaylistSyncVersion = -1;

  final playlistCreationMode = "local".obs;
  List<Playlist> _initPlst = [];
  List<Playlist> get initPlst => _initPlst;
  late RxList<Playlist> libraryPlaylists;
  final isContentFetched = false.obs;
  final creationInProgress = false.obs;
  final textInputController = TextEditingController();
  List<Playlist> tempListContainer = [];

  // Add these RxBool to track import progress
  final isImporting = false.obs;
  final importProgress = 0.0.obs;

  List<Playlist> _buildInitPlst() {
    final l10n = AppLocalizations.of(Get.context!)!;
    return [
      Playlist(
          title: l10n.recentlyPlayed,
          playlistId: "LIBRP",
          thumbnailUrl: Playlist.thumbPlaceholderUrl,
          isCloudPlaylist: false),
      Playlist(
          title: l10n.favorites,
          playlistId: "LIBFAV",
          thumbnailUrl: Playlist.thumbPlaceholderUrl,
          isCloudPlaylist: false),
      Playlist(
          title: l10n.cachedOrOffline,
          playlistId: "SongsCache",
          thumbnailUrl: Playlist.thumbPlaceholderUrl,
          isCloudPlaylist: false),
      Playlist(
          title: l10n.downloads,
          playlistId: "SongDownloads",
          thumbnailUrl: Playlist.thumbPlaceholderUrl,
          isCloudPlaylist: false)
    ];
  }

  @override
  void onInit() {
    _initPlst = _buildInitPlst();
    libraryPlaylists = RxList(_initPlst);
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
    refreshLib();
    ever(Get.find<SettingsScreenController>().activeServerId, (_) async {
      if (!Get.isRegistered<LibraryPlaylistsController>()) return;
      final id = currentServerId();
      await Hive.openBox(libFavBoxName(id));
      await Hive.openBox(recentlyPlayedBoxName(id));
      refreshLib();
    });
    _syncWorker =
        ever(Get.find<LibrarySyncService>().syncVersionByKind, (_) async {
      final syncService = Get.find<LibrarySyncService>();
      final currVersion =
          syncService.syncVersionByKind[LibraryKind.playlists] ?? 0;
      if (currVersion == _lastPlaylistSyncVersion) return;
      _lastPlaylistSyncVersion = currVersion;
      if (!Get.isRegistered<LibraryPlaylistsController>()) return;
      final settings = Get.find<SettingsScreenController>();
      final server = settings.activeServer;
      if (server == null || server.type == ServerType.youtubeMusic) return;
      refreshLib();
    });
    super.onInit();
  }

  void refreshLib() async {
    final serverId = _currentServerId();
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final useBackend = server != null && server.type != ServerType.youtubeMusic;

    if (useBackend) {
      final backendPlaylists = await Get.find<LibrarySyncService>()
          .getCachedPlaylists(currentServerId());
      libraryPlaylists.value = [..._initPlst, ...backendPlaylists];
      unawaited(Get.find<LibrarySyncService>()
          .maybeSyncKindIfStale(LibraryKind.playlists));
      isContentFetched.value = true;
      return;
    }

    final prefix = 's_${serverId}_';
    final box = await Hive.openBox("LibraryPlaylists");
    if (serverId == 0) {
      final legacyKeys = box.keys
          .where((k) => k is String && !k.toString().startsWith('s_'))
          .map((k) => k.toString())
          .toList();
      for (final key in legacyKeys) {
        if (box.containsKey(key)) {
          box.put(prefix + key, box.get(key));
          box.delete(key);
        }
      }
    }
    final keys = box.keys
        .where((k) => k is String && k.toString().startsWith(prefix))
        .toList();
    final list = <Playlist>[
      ..._initPlst,
      ...keys
          .map((k) => box.get(k.toString()))
          .whereType<Map>()
          .map<Playlist?>(
              (item) => Playlist.fromJson(Map<dynamic, dynamic>.from(item)))
          .whereType<Playlist>()
    ];
    libraryPlaylists.value = list;

    final appPrefsBox = Hive.box("AppPrefs");
    if (serverId == 0 &&
        appPrefsBox.containsKey("piped") &&
        appPrefsBox.get("piped")['isLoggedIn']) {
      await syncPipedPlaylist();
    }

    isContentFetched.value = true;
  }

  void updatePlaylistIntoDb(Playlist playlist) async {
    final box = await Hive.openBox("LibraryPlaylists");
    box.put(libraryPlaylistKey(_currentServerId(), playlist.playlistId),
        playlist.toJson());
    refreshLib();
  }

  void removePipedPlaylists() {
    for (Playlist plst in libraryPlaylists.toList()) {
      if (plst.isPipedPlaylist) {
        libraryPlaylists.remove(plst);
      }
    }
  }

  Future<void> syncPipedPlaylist() async {
    final res = await Get.find<PipedServices>().getAllPlaylists();
    final box =
        await Hive.openBox(blacklistedPlaylistBoxName(_currentServerId()));
    final blacklistedPlaylist = box.values.whereType<String>().toList();
    final libPipedPlaylistsId = libraryPlaylists
            .toList()
            .map((e) {
              if (e.isPipedPlaylist) {
                return e.playlistId;
              }
            })
            .whereType<String>()
            .toList() +
        blacklistedPlaylist;

    if (res.code == 1) {
      final cloudpipedPlaylistsId = res.response
          .map((e) {
            return e['id'];
          })
          .whereType<String>()
          .toList();
      //add new playlist from cloud
      for (dynamic playlist in res.response) {
        if (!libPipedPlaylistsId.contains(playlist['id'])) {
          final plst = Playlist(
            title: playlist['name'],
            playlistId: playlist['id'],
            description: "Piped Playlist",
            thumbnailUrl: playlist['thumbnail'],
            isPipedPlaylist: true,
          );
          libraryPlaylists.add(plst);
        }
      }

      //remove playist if removed from cloud
      for (Playlist playlist in libraryPlaylists.toList()) {
        if (!cloudpipedPlaylistsId.contains(playlist.playlistId) &&
            playlist.isPipedPlaylist) {
          libraryPlaylists.removeWhere(
              (element) => element.playlistId == playlist.playlistId);
        }
      }
    }
    box.close();
  }

  Future<bool> renamePlaylist(Playlist playlist) async {
    String title = textInputController.text;
    if (title.trim().isNotEmpty) {
      if (playlist.isPipedPlaylist) {
        final res = await Get.find<PipedServices>()
            .renamePlaylist(playlist.playlistId, title);
        if (res.code == 0) return false;
        playlist.newTitle = title;
      } else {
        final box = await Hive.openBox("LibraryPlaylists");
        title = "${title[0].toUpperCase()}${title.substring(1).toLowerCase()}";
        playlist.newTitle = title;
        box.put(libraryPlaylistKey(_currentServerId(), playlist.playlistId),
            playlist.toJson());
      }
      refreshLib();
      return true;
    }
    return false;
  }

  void changeCreationMode(String? val) {
    playlistCreationMode.value = val!;
  }

  Future<bool> createNewPlaylist(
      {bool createPlaylistNaddSong = false, List<MediaItem>? songItems}) async {
    String title = textInputController.text;
    if (title.trim().isNotEmpty) {
      dynamic newplst;

      if (playlistCreationMode.value == "piped") {
        creationInProgress.value = true;
        final res = await Get.find<PipedServices>().createPlaylist(title);
        if (res.code == 1) {
          newplst = Playlist(
              title: title,
              playlistId: "${res.response['playlistId']}",
              thumbnailUrl: songItems != null
                  ? songItems[0].artUri.toString()
                  : Playlist.thumbPlaceholderUrl,
              description: "Piped Playlist",
              isCloudPlaylist: true,
              isPipedPlaylist: true);
        } else {
          creationInProgress.value = false;
          return false;
        }
      } else {
        newplst = Playlist(
            title: title,
            playlistId: "LIB${DateTime.now().millisecondsSinceEpoch}",
            thumbnailUrl: songItems != null
                ? songItems[0].artUri.toString()
                : Playlist.thumbPlaceholderUrl,
            description: "Library Playlist",
            isCloudPlaylist: false);
        final box = await Hive.openBox("LibraryPlaylists");
        box.put(libraryPlaylistKey(_currentServerId(), newplst.playlistId),
            newplst.toJson());
      }

      libraryPlaylists.add(newplst);

      if (createPlaylistNaddSong && playlistCreationMode.value == "local") {
        final plastbox = await Hive.openBox(newplst.playlistId);
        for (MediaItem item in songItems!) {
          plastbox.add(MediaItemBuilder.toJson(item));
        }
        plastbox.close();
      } else if (createPlaylistNaddSong &&
          playlistCreationMode.value == "piped") {
        final songIds = songItems!.map((e) => e.id).toList();
        await Get.find<PipedServices>()
            .addToPlaylist(newplst.playlistId, songIds);
      }
      creationInProgress.value = false;
      return true;
    }
    return false;
  }

  Future<void> blacklistPipedPlaylist(Playlist playlist) async {
    final box =
        await Hive.openBox(blacklistedPlaylistBoxName(_currentServerId()));
    box.add(playlist.playlistId);
    libraryPlaylists.remove(playlist);
    box.close();
  }

  Future<void> resetBlacklistedPlaylist() async {
    final box =
        await Hive.openBox(blacklistedPlaylistBoxName(_currentServerId()));
    box.clear();
    syncPipedPlaylist();
  }

  void onSort(SortType sortType, bool isAscending) {
    final playlists = libraryPlaylists.toList();
    playlists.removeRange(0, 4);
    sortPlayLists(playlists, sortType, isAscending);
    playlists.insertAll(0, _initPlst);
    libraryPlaylists.value = playlists;
  }

  void onSearchStart(String? tag) {
    tempListContainer = libraryPlaylists.toList();
  }

  void onSearch(String value, String? tag) {
    final songlist = tempListContainer
        .where((element) =>
            element.title.toLowerCase().contains(value.toLowerCase()))
        .toList();
    libraryPlaylists.value = songlist;
  }

  void onSearchClose(String? tag) {
    libraryPlaylists.value = tempListContainer.toList();
    tempListContainer.clear();
  }

  @override
  void dispose() {
    textInputController.dispose();
    controller.dispose();
    _syncWorker?.dispose();
    super.dispose();
  }

  Future<void> importPlaylistFromJson(BuildContext context) async {
    final l10n = context.l10n;
    try {
      isImporting.value = true;
      importProgress.value = 0.1;

      // Show progress dialog
      if (context.mounted) {
        _showImportProgressDialog(context);
      }

      // Use file_picker to select JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: l10n.importPlaylist,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled the picker
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        isImporting.value = false;
        importProgress.value = 0.0;
        return;
      }

      importProgress.value = 0.2;

      final file = File(result.files.single.path!);
      if (!await file.exists()) {
        throw FileSystemException(l10n.fileNotFound);
      }

      final jsonString = await file.readAsString();
      importProgress.value = 0.3;

      final jsonData = jsonDecode(jsonString);
      importProgress.value = 0.4;

      // Validate JSON structure
      if (!jsonData.containsKey('playlistInfo') ||
          !jsonData.containsKey('songs')) {
        throw FormatException(l10n.invalidPlaylistFile);
      }

      // Create new playlist ID
      final playlistInfo = jsonData['playlistInfo'];
      final newPlaylistId = "LIB${DateTime.now().millisecondsSinceEpoch}";
      importProgress.value = 0.5;

      // Create playlist object
      final newPlaylist = Playlist(
        title: "${playlistInfo['title']} (${l10n.imported})",
        playlistId: newPlaylistId,
        thumbnailUrl: playlistInfo['thumbnailUrl'] ??
            (playlistInfo['thumbnails'] != null &&
                    playlistInfo['thumbnails'].isNotEmpty
                ? playlistInfo['thumbnails'][0]['url']
                : Playlist.thumbPlaceholderUrl),
        description: playlistInfo['description'] ?? l10n.importedPlaylist,
        isCloudPlaylist: false,
      );
      importProgress.value = 0.6;

      final box = await Hive.openBox("LibraryPlaylists");
      box.put(libraryPlaylistKey(_currentServerId(), newPlaylistId),
          newPlaylist.toJson());
      importProgress.value = 0.7;

      // Save songs to playlist
      final songsBox = await Hive.openBox(newPlaylistId);
      final songsList = jsonData['songs'] as List;

      // Update progress as songs are added
      final totalSongs = songsList.length;
      for (int i = 0; i < totalSongs; i++) {
        await songsBox.put(i, songsList[i]);
        // Update progress from 70% to 95% based on song import progress
        importProgress.value = 0.7 + (0.25 * (i + 1) / totalSongs);
      }

      await songsBox.close();
      importProgress.value = 1.0;

      // Close progress dialog if it's still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Refresh library to show the new playlist
      refreshLib();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          snackbar(
            context,
            "${l10n.playlistImportedMsg}: ${newPlaylist.title}",
            size: SnackBarSize.MEDIUM,
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if it's still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      printERROR("Error importing playlist: $e");

      String errorMsg = l10n.importError;
      if (e is FileSystemException) {
        errorMsg = l10n.importErrorFileAccess;
      } else if (e is FormatException) {
        errorMsg = l10n.importErrorFormat;
      } else if (e.toString().contains("invalidPlaylistFile")) {
        errorMsg = l10n.invalidPlaylistFile;
      } else if (e is HiveError) {
        errorMsg = l10n.importErrorDatabase;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            snackbar(context, errorMsg, size: SnackBarSize.MEDIUM));
      }
    } finally {
      isImporting.value = false;
      importProgress.value = 0.0;
    }
  }

  // Helper method to show import progress dialog
  void _showImportProgressDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text(
          context.l10n.importingPlaylist,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: Get.isRegistered<LibraryPlaylistsController>()
                      ? importProgress.value
                      : 0,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${(Get.isRegistered<LibraryPlaylistsController>() ? importProgress.value * 100 : 0).toInt()}%",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            )),
      ),
      barrierDismissible: false,
    );
  }
}

class LibraryAlbumsController extends GetxController {
  late RxList<Album> libraryAlbums = RxList();
  final isContentFetched = false.obs;
  List<Album> tempListContainer = [];
  Worker? _syncWorker;
  int _lastAlbumSyncVersion = -1;

  @override
  void onInit() {
    refreshLib();
    ever(Get.find<SettingsScreenController>().activeServerId, (_) {
      if (!Get.isRegistered<LibraryAlbumsController>()) return;
      refreshLib();
    });
    _syncWorker = ever(Get.find<LibrarySyncService>().syncVersionByKind, (_) {
      final syncService = Get.find<LibrarySyncService>();
      final currVersion =
          syncService.syncVersionByKind[LibraryKind.albums] ?? 0;
      if (currVersion == _lastAlbumSyncVersion) return;
      _lastAlbumSyncVersion = currVersion;
      if (!Get.isRegistered<LibraryAlbumsController>()) return;
      final settings = Get.find<SettingsScreenController>();
      final server = settings.activeServer;
      if (server == null || server.type == ServerType.youtubeMusic) return;
      refreshLib();
    });
    super.onInit();
  }

  void refreshLib() async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final useBackend = server != null && server.type != ServerType.youtubeMusic;
    if (useBackend) {
      libraryAlbums.value = await Get.find<LibrarySyncService>()
          .getCachedAlbums(currentServerId());
      unawaited(
        Get.find<LibrarySyncService>().maybeSyncKindIfStale(LibraryKind.albums),
      );
    } else {
      final box = await Hive.openBox(libraryAlbumsBoxName(currentServerId()));
      libraryAlbums.value = box.values
          .map<Album?>((item) => Album.fromJson(item))
          .whereType<Album>()
          .toList();
    }
    isContentFetched.value = true;
  }

  @override
  void onClose() {
    _syncWorker?.dispose();
    super.onClose();
  }

  void onSort(SortType sortType, bool isAscending) {
    final albumList = libraryAlbums.toList();
    sortAlbumNSingles(albumList, sortType, isAscending);
    libraryAlbums.value = albumList;
  }

  void onSearchStart(String? tag) {
    tempListContainer = libraryAlbums.toList();
  }

  void onSearch(String value, String? tag) {
    final songlist = tempListContainer
        .where((element) =>
            element.title.toLowerCase().contains(value.toLowerCase()))
        .toList();
    libraryAlbums.value = songlist;
  }

  void onSearchClose(String? tag) {
    libraryAlbums.value = tempListContainer.toList();
    tempListContainer.clear();
  }
}

class LibraryArtistsController extends GetxController {
  RxList<Artist> libraryArtists = RxList();
  final isContentFetched = false.obs;
  List<Artist> tempListContainer = [];
  Worker? _syncWorker;
  int _lastArtistSyncVersion = -1;

  @override
  void onInit() {
    refreshLib();
    ever(Get.find<SettingsScreenController>().activeServerId, (_) {
      if (!Get.isRegistered<LibraryArtistsController>()) return;
      refreshLib();
    });
    _syncWorker = ever(Get.find<LibrarySyncService>().syncVersionByKind, (_) {
      final syncService = Get.find<LibrarySyncService>();
      final currVersion =
          syncService.syncVersionByKind[LibraryKind.artists] ?? 0;
      if (currVersion == _lastArtistSyncVersion) return;
      _lastArtistSyncVersion = currVersion;
      if (!Get.isRegistered<LibraryArtistsController>()) return;
      final settings = Get.find<SettingsScreenController>();
      final server = settings.activeServer;
      if (server == null || server.type == ServerType.youtubeMusic) return;
      refreshLib();
    });
    super.onInit();
  }

  void refreshLib() async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final useBackend = server != null && server.type != ServerType.youtubeMusic;
    if (useBackend) {
      libraryArtists.value = await Get.find<LibrarySyncService>()
          .getCachedArtists(currentServerId());
      unawaited(Get.find<LibrarySyncService>()
          .maybeSyncKindIfStale(LibraryKind.artists));
    } else {
      final box = await Hive.openBox(libraryArtistsBoxName(currentServerId()));
      libraryArtists.value = box.values
          .map<Artist?>((item) => Artist.fromJson(item))
          .whereType<Artist>()
          .toList();
    }
    isContentFetched.value = true;
  }

  @override
  void onClose() {
    _syncWorker?.dispose();
    super.onClose();
  }

  void onSort(SortType sortType, bool isAscending) {
    final artistList = libraryArtists.toList();
    sortArtist(artistList, sortType, isAscending);
    libraryArtists.value = artistList;
  }

  void onSearchStart(String? tag) {
    tempListContainer = libraryArtists.toList();
  }

  void onSearch(String value, String? tag) {
    final songlist = tempListContainer
        .where((element) =>
            element.name.toLowerCase().contains(value.toLowerCase()))
        .toList();
    libraryArtists.value = songlist;
  }

  void onSearchClose(String? tag) {
    libraryArtists.value = tempListContainer.toList();
    tempListContainer.clear();
  }
}
