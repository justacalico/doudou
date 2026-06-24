import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../models/album.dart';
import '../models/media_Item_builder.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';
import '../ui/widgets/sort_widget.dart';
import '../utils/server_storage.dart';

abstract class PlaylistAlbumScreenControllerBase extends GetxController {
  final MusicServices musicServices = Get.find<MusicServices>();

  final RxBool isOffline = false.obs;

  final RxList<MediaItem> songList = <MediaItem>[].obs;

  final RxBool isContentFetched = false.obs;

  final RxBool isAddedToLibrary = false.obs;

  final RxDouble scrollOffset = 0.0.obs;

  final RxBool appBarTitleVisible = false.obs;

  final RxBool isDownloaded = false.obs;

  /// Checks if the album/playlist is added to the library.
  ///
  /// [id] - The unique identifier of the album/playlist.
  ///
  /// Returns a [Future] that resolves to `true` if added to the library, otherwise `false`.
  @protected
  Future<bool> checkIfAddedToLibrary(String id);

  @protected
  void fetchAlbumDetails(Album? album_, String albumId);

  @protected
  void fetchPlaylistDetails(Playlist? playlist_, String playlistId);

  Future<void> fetchSongsfromDatabase(String id) async {
    final box = await Hive.openBox(id);
    songList.value = box.values
        .map<MediaItem?>((item) => MediaItemBuilder.fromJson(item))
        .whereType<MediaItem>()
        .toList();
    if (id != "SongDownloads") await box.close();
    songList.value =
        id == "LIBRP" ? songList.reversed.toList() : songList.toList();
    await checkDownloadStatus();
  }

  Future<void> checkDownloadStatus() async {
    bool downloaded = true;
    final boxName = songDownloadsBoxName(currentServerId());
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);
    for (MediaItem item in songList) {
      if (!box.containsKey(item.id)) {
        downloaded = false;
        break;
      }
    }
    isDownloaded.value = downloaded;
  }

  @protected
  Future<bool> addNremoveFromLibrary(dynamic content, {bool add = true});

  @protected
  void syncPlaylistSongs();

  @protected
  Future<void> updateSongsIntoDb();

  Future<void> deleteMultipleSongs(List<MediaItem> songs);

  @protected
  List<MediaItem> selectedSongs();

  void onSearch(String value, String? tag);

  void onSearchClose(String? tag);

  void onSearchStart(String? tag);

  void startAdditionalOperation(
      SortWidgetController sortWidgetController_, OperationMode mode);

  /// Selects or deselects all items.
  ///
  /// [selectAll] - A boolean indicating whether to select all (`true`) or deselect all (`false`).
  void selectAll(bool selectAll);

  void performAdditionalOperation();

  void cancelAdditionalOperation();
}
