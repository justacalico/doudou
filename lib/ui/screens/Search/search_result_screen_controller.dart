import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';
import '../../../utils/helper.dart';
import '/models/media_Item_builder.dart';
import '/ui/shell_controller.dart';
import '../Home/home_screen_controller.dart';
import '../Settings/settings_screen_controller.dart';
import '/services/backend/backend_capabilities.dart';
import '/services/backend/music_backend.dart';
import '/services/music_service.dart';
import '/ui/widgets/sort_widget.dart';

class SearchResultScreenController extends GetxController
    with GetTickerProviderStateMixin {
  final navigationRailCurrentIndex = 0.obs;
  final isResultContentFetced = false.obs;
  final isSeparatedResultContentFetced = false.obs;
  final resultContent = <String, dynamic>{}.obs;
  final separatedResultContent = <String, dynamic>{}.obs;
  final musicServices = Get.find<MusicServices>();
  MusicBackend get _backend =>
      Get.find<SettingsScreenController>().currentBackend;
  final queryString = ''.obs;
  final railItems = <String>[].obs;
  final railitemHeight = Get.size.height.obs;
  final additionalParamNext = {};
  bool continuationInProgress = false;
  TabController? tabController;
  bool isTabTransitionReversed = false;
  //ScrollContollers List
  final Map<String, ScrollController> scrollControllers = {};

  @override
  void onReady() {
    _getInitSearchResult();
    Get.find<HomeScreenController>().whenHomeScreenOnTop();
    super.onReady();
  }

  Future<void> onDestinationSelected(int value,
      {bool ignoreTabCommand = false}) async {
    if (railItems.isEmpty) {
      return;
    }

    isTabTransitionReversed = value > navigationRailCurrentIndex.value;

    isSeparatedResultContentFetced.value = false;
    navigationRailCurrentIndex.value = value;

    if (tabController != null && !ignoreTabCommand) {
      tabController?.animateTo(value);
    }

    if (value > 0 &&
        (!separatedResultContent.containsKey(railItems[value - 1]) ||
            separatedResultContent[railItems[value - 1]].isEmpty)) {
      final tabName = railItems[value - 1];
      final itemCount = (tabName == 'Songs' || tabName == 'Videos') ? 25 : 10;
      final x = await _backend.search(queryString.value,
          filter: tabName.replaceAll(" ", "_").toLowerCase(),
          limit: itemCount,
          filterParams: resultContent['searchEndpoint']?[tabName]);
      separatedResultContent[tabName] = _normalizeContentForTab(
        tabName,
        x[tabName],
      );
      additionalParamNext[tabName] = x['params'];
      isSeparatedResultContentFetced.value = true;
      final scrollController = scrollControllers[tabName];
      (scrollController)!.addListener(() {
        double maxScroll = scrollController.position.maxScrollExtent;
        double currentScroll = scrollController.position.pixels;
        if (currentScroll >= maxScroll / 2 &&
            additionalParamNext[tabName]['additionalParams'] !=
                '&ctoken=null&continuation=null') {
          if (!continuationInProgress) {
            printINFO("Acchhsk");
            continuationInProgress = true;
            getContinuationContents();
          }
        }
      });
    }
    isSeparatedResultContentFetced.value = true;
  }

  Future<void> getContinuationContents() async {
    final tabName = railItems[navigationRailCurrentIndex.value - 1];

    final x = await _backend.getSearchContinuation(
        Map<String, dynamic>.from(additionalParamNext[tabName] ?? {}));
    final list = x[tabName];
    if (list != null) {
      final toAdd = _normalizeContentForTab(tabName, list);
      (separatedResultContent[tabName] as List).addAll(toAdd);
    }
    if (x['params'] != null) additionalParamNext[tabName] = x['params'];
    separatedResultContent.refresh();

    continuationInProgress = false;
  }

  void viewAllCallback(String text) {
    onDestinationSelected(railItems.indexOf(text) + 1);
  }

  static List<MediaItem> _toMediaItemList(dynamic value) {
    if (value == null || value is! List) return [];
    final out = <MediaItem>[];
    for (final e in value) {
      if (e is MediaItem) {
        out.add(e);
      } else if (e is Map) {
        out.add(MediaItemBuilder.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<Album> _toAlbumList(dynamic value) {
    if (value == null || value is! List) return [];
    final out = <Album>[];
    for (final e in value) {
      if (e is Album) {
        out.add(e);
      } else if (e is Map) {
        out.add(Album.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<Artist> _toArtistList(dynamic value) {
    if (value == null || value is! List) return [];
    final out = <Artist>[];
    for (final e in value) {
      if (e is Artist) {
        out.add(e);
      } else if (e is Map) {
        out.add(Artist.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<Playlist> _toPlaylistList(dynamic value) {
    if (value == null || value is! List) return [];
    final out = <Playlist>[];
    for (final e in value) {
      if (e is Playlist) {
        out.add(e);
      } else if (e is Map) {
        out.add(Playlist.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  List<dynamic> _normalizeContentForTab(String tabName, dynamic value) {
    if (tabName == 'Songs' || tabName == 'Videos') {
      return _toMediaItemList(value);
    }
    if (tabName == 'Albums' || tabName == 'Singles') {
      return _toAlbumList(value);
    }
    if (tabName == 'Artists') {
      return _toArtistList(value);
    }
    if (tabName.toLowerCase().contains('playlist')) {
      return _toPlaylistList(value);
    }
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  Map<String, dynamic> _normalizeSearchResults(Map<String, dynamic> raw) {
    final normalized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'searchEndpoint' || key == 'params') {
        normalized[key] = value;
        continue;
      }
      normalized[key] = _normalizeContentForTab(key, value);
    }
    return normalized;
  }

  bool _showSearchTab(String key, BackendCapabilities caps) {
    switch (key) {
      case 'Videos':
        return caps.hasVideos;
      case 'Community playlists':
        return caps.hasCommunityPlaylists;
      case 'Featured playlists':
        return caps.hasFeaturedPlaylists;
      default:
        return true;
    }
  }

  Future<void> _getInitSearchResult() async {
    isResultContentFetced.value = false;
    resultContent.clear();
    separatedResultContent.clear();
    railItems.clear();
    additionalParamNext.clear();
    navigationRailCurrentIndex.value = 0;
    continuationInProgress = false;
    tabController?.dispose();
    tabController = null;
    for (final controller in scrollControllers.values) {
      controller.dispose();
    }
    scrollControllers.clear();

    final args = Get.arguments;
    if (args is String && args.trim().isNotEmpty) {
      queryString.value = args.trim();
      final backend = _backend;
      final rawResult = await backend.search(queryString.value);
      resultContent.value = _normalizeSearchResults(rawResult);
      final caps = backend.capabilities;
      final allKeys = resultContent.keys
          .where((element) =>
              ([
                "Songs",
                "Videos",
                "Albums",
                "Featured playlists",
                "Community playlists",
                "Artists"
              ]).contains(element) &&
              _showSearchTab(element, caps))
          .toList();
      railItems.value = List<String>.from(allKeys);
      final len =
          railItems.where((element) => element.contains("playlists")).length;
      final calH = 30 + (railItems.length + 1 - len) * 123 + len * 150.0;
      railitemHeight.value =
          calH >= railitemHeight.value ? calH : railitemHeight.value;

      //ScrollControlers for list Continuation callback implementarion
      for (String item in railItems) {
        scrollControllers[item] = ScrollController();
      }

      //Case if bottom nav used
      if (GetPlatform.isDesktop ||
          Get.find<ShellController>().useBottomNav.value) {
        // assiging init val
        for (var element in railItems) {
          separatedResultContent[element] = [];
        }

        //tab controller for v2
        tabController =
            TabController(length: railItems.length + 1, vsync: this);

        tabController?.animation?.addListener(() {
          int indexChange = tabController!.offset.round();
          int index = tabController!.index + indexChange;

          if (index != navigationRailCurrentIndex.value) {
            onDestinationSelected(index, ignoreTabCommand: true);
          }
        });
      }
      isResultContentFetced.value = true;
      return;
    }
    queryString.value = '';
    isResultContentFetced.value = true;
  }

  void onSort(SortType sortType, bool isAscending, String title) {
    if (title == "Songs" || title == "Videos") {
      final songList = separatedResultContent[title].toList();
      sortSongsNVideos(songList, sortType, isAscending);
      separatedResultContent[title] = songList;
    } else if (title.contains('playlists')) {
      final playlists = separatedResultContent[title].toList();
      sortPlayLists(playlists, sortType, isAscending);
      separatedResultContent[title] = playlists;
    } else if (title == "Artists") {
      final artistList = separatedResultContent[title].toList();
      sortArtist(artistList, sortType, isAscending);
      separatedResultContent[title] = artistList;
    } else if (title == "Albums") {
      final albumList = separatedResultContent[title].toList();
      sortAlbumNSingles(albumList, sortType, isAscending);
      separatedResultContent[title] = albumList;
    }
  }

  @override
  void onClose() {
    for (String item in railItems) {
      (scrollControllers[item])!.dispose();
    }
    Get.find<HomeScreenController>().whenHomeScreenOnTop();
    tabController?.dispose();
    super.onClose();
  }
}
