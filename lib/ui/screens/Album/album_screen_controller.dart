import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:doudou/base_class/playlist_album_screen_con_base.dart';
import 'package:doudou/models/album.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/utils/helper.dart';
import 'package:hive/hive.dart';

import '../../../mixins/additional_operation_mixin.dart';
import '../../../models/media_Item_builder.dart';
import '../Home/home_screen_controller.dart';
import '../Library/library_controller.dart';
import '../Settings/settings_screen_controller.dart';
import '../../../models/server.dart';
import '../../../utils/server_storage.dart';

///AlbumScreenController handles album screen
///
///Album title,image,songs
class AlbumScreenController extends PlaylistAlbumScreenControllerBase
    with AdditionalOperationMixin, GetSingleTickerProviderStateMixin {
  final album =
      Album(title: "", browseId: "", thumbnailUrl: "", artists: []).obs;
  final isOfflineAlbum = false.obs;

  // Title animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _heightAnimation;

  AnimationController get animationController => _animationController;
  Animation<double> get scaleAnimation => _scaleAnimation;
  Animation<double> get heightAnimation => _heightAnimation;


  @override
  void onInit() {
    super.onInit();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1.0).animate(animationController);

    _heightAnimation = Tween<double>(begin: 10.0, end: 90.0).animate(
        CurvedAnimation(
            parent: animationController, curve: Curves.easeOutBack));

    final args = Get.arguments as (Album?, String);
    fetchAlbumDetails(args.$1, args.$2);
    Future.delayed(const Duration(milliseconds: 200),
        () => Get.find<HomeScreenController>().whenHomeScreenOnTop());
  }

  @override
  void fetchAlbumDetails(Album? album_, String albumId) async {
    try {
      if (album_ != null) {
        album.value = album_;
        animationController.forward();
      }
      final settings = Get.find<SettingsScreenController>();
      final server = settings.activeServer;
      final isYouTube = server?.type == ServerType.youtubeMusic;

      // Check if the album is offline (only for YouTube Music)
      if (isYouTube && !await checkIfAddedToLibrary(albumId)) {
        // Fetch album details online from YouTube Music
        final content = await musicServices.getPlaylistOrAlbumSongs(
            albumId: albumId);
        content['browseId'] = albumId;
        album.value = Album.fromJson(content);
        animationController.forward();
        songList.value = List<MediaItem>.from(content['tracks']);
      } else {
        if (isYouTube) {
          // If the album is offline, fetch the songs from the local database
          // Album details are already fetched in _checkIfAddedToLibrary method
          final box = await Hive.openBox(albumId);
          songList.value = box.values
              .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
              .whereType<MediaItem>()
              .toList();
          box.close();
        } else {
          // For Jellyfin/Subsonic, fetch tracks from the active backend
          final content = await settings.currentBackend
              .getPlaylistOrAlbumSongs(albumId: albumId);
          final tracks = (content['tracks'] as List?) ?? [];
          songList.value = tracks
              .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
              .whereType<MediaItem>()
              .toList();
          // Keep the album metadata coming from the library (album_),
          // so we don't try to rebuild it from a track-only response.
        }
      }
      checkDownloadStatus();
      isContentFetched.value = true;
    } catch (e) {
      // Handle any errors that occur during the fetch
      printERROR("Error fetching album details: $e");
    }
  }

  @override
  Future<bool> checkIfAddedToLibrary(String id) async {
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    if (server != null && server.type != ServerType.youtubeMusic) {
      isAddedToLibrary.value = false;
      return false;
    }

    final box =
        await Hive.openBox(libraryAlbumsBoxName(currentServerId()));
    isAddedToLibrary.value = box.containsKey(id);
    if (isAddedToLibrary.value) album.value = Album.fromJson(box.get(id));
    box.close();
    return isAddedToLibrary.value;
  }

  @override
  Future<bool> addNremoveFromLibrary(content, {bool add = true}) async {
    try {
      final box =
          await Hive.openBox(libraryAlbumsBoxName(currentServerId()));
      final id = content.browseId;
      if (add) {
        box.put(id, content.toJson());
        updateSongsIntoDb();
      } else {
        box.delete(id);
        final songsBox = await Hive.openBox(id);
        songsBox.deleteFromDisk();
      }
      isAddedToLibrary.value = add;

      //Update frontend
      Get.find<LibraryAlbumsController>().refreshLib();

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> updateSongsIntoDb() async {
    final songsBox = await Hive.openBox(album.value.browseId);
    await songsBox.clear();
    final songListCopy = songList.toList();
    for (int i = 0; i < songListCopy.length; i++) {
      await songsBox.put(i, MediaItemBuilder.toJson(songListCopy[i]));
    }
    await songsBox.close();
  }

  @override
  void onClose() {
    tempListContainer.clear();
    _animationController.dispose();
    Get.find<HomeScreenController>().whenHomeScreenOnTop();
    super.onClose();
  }

  @override
  Future<void> deleteMultipleSongs(List<MediaItem> songs) async {}

  @override
  void fetchPlaylistDetails(Playlist? playlist_, String playlistId) {}

  @override
  void syncPlaylistSongs() {}
}
