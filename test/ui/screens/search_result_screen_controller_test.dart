import 'dart:io';

import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/services/backend/backend_capabilities.dart';
import 'package:doudou/services/backend/music_backend.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Search/search_result_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

class _FakeHomeScreenController extends HomeScreenController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void whenHomeScreenOnTop() {}
}

class _FakeSettingsWithBackend extends FakeSettingsScreenController {
  _FakeSettingsWithBackend(this.backend);

  final MusicBackend backend;

  @override
  MusicBackend get currentBackend => backend;
}

class _FakeBackend extends MusicBackend {
  Map<String, dynamic> searchResult = {};
  Object? searchError;
  int searchCalls = 0;

  Object? continuationError;
  Map<String, dynamic> continuationResult = {};

  @override
  BackendCapabilities get capabilities => BackendCapabilities.youtubeMusic;

  @override
  Future<Map<String, dynamic>> search(String query,
      {String? filter,
      String? scope,
      int limit = 30,
      bool ignoreSpelling = false,
      dynamic filterParams}) async {
    searchCalls++;
    final error = searchError;
    if (error != null) throw error;
    return searchResult;
  }

  @override
  Future<Map<String, dynamic>> getSearchContinuation(
      Map<String, dynamic> additionalParamsNext,
      {int limit = 10}) async {
    final error = continuationError;
    if (error != null) throw error;
    return continuationResult;
  }

  @override
  Future<dynamic> getHome({int limit = 4}) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCharts(String category,
          {String? countryCode}) async =>
      [];

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
          {String? playlistId,
          String? albumId,
          int limit = 3000,
          bool related = false,
          int suggestionsLimit = 0}) async =>
      {};

  @override
  Future<dynamic> getContentRelatedToSong(
          String videoId, String hlCode) async =>
      null;

  @override
  Future<String?> getStreamUrl(String mediaItemId) async => null;

  @override
  Future<List<Artist>> getLibraryArtists() async => [];

  @override
  Future<List<Album>> getLibraryAlbums() async => [];

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongs() async => [];

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSongs() async => [];

  @override
  Future<void> setSongFavorite(String songId, bool favorite) async {}

  @override
  Future<List<Playlist>> getLibraryPlaylists() async => [];
}

void main() {
  late Directory dir;
  late _FakeBackend backend;
  final controllers = <SearchResultScreenController>[];

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_search_result_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() {
    backend = _FakeBackend();
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<ShellController>(ShellController());
    Get.put<SettingsScreenController>(_FakeSettingsWithBackend(backend));
    Get.put<HomeScreenController>(_FakeHomeScreenController());
  });

  tearDown(() {
    for (final controller in controllers) {
      controller.onClose();
    }
    controllers.clear();
    Get.rootController.routing.args = null;
    Get.delete<HomeScreenController>(force: true);
    Get.delete<SettingsScreenController>(force: true);
    Get.delete<ShellController>(force: true);
    Get.delete<MusicServices>(force: true);
  });

  SearchResultScreenController createController(String query) {
    Get.rootController.routing.args = query;
    final controller = SearchResultScreenController();
    controllers.add(controller);
    return controller;
  }

  Future<void> pumpUntil(
      WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await tester.pump();
    }
  }

  testWidgets('finishes loading with results when search succeeds',
      (tester) async {
    backend.searchResult = {
      'Songs': <dynamic>[],
      'searchEndpoint': {'Songs': 'params'},
    };

    final controller = createController('white rabbit');
    controller.onReady();
    await pumpUntil(tester, () => controller.isResultContentFetched.value);

    expect(controller.isResultContentFetched.value, isTrue);
    expect(controller.railItems, contains('Songs'));
  });

  testWidgets('does not load forever when search throws', (tester) async {
    backend.searchError = Exception('parse boom');

    final controller = createController('randy marsh digbar');
    controller.onReady();
    await pumpUntil(tester, () => controller.isResultContentFetched.value);

    expect(controller.isResultContentFetched.value, isTrue);
    expect(controller.railItems, isEmpty);
    expect(controller.queryString.value, 'randy marsh digbar');
  });

  testWidgets('tab search failure resolves loading instead of spinning',
      (tester) async {
    backend.searchResult = {
      'Songs': <dynamic>[],
      'searchEndpoint': {'Songs': 'params'},
    };

    final controller = createController('white rabbit');
    controller.onReady();
    await pumpUntil(tester, () => controller.isResultContentFetched.value);

    backend.searchError = Exception('tab parse boom');
    await controller.onDestinationSelected(1, ignoreTabCommand: true);

    expect(controller.isSeparatedResultContentFetced.value, isTrue);
    expect(controller.separatedResultContent['Songs'], isEmpty);
  });

  testWidgets('continuation failure resets continuationInProgress',
      (tester) async {
    backend.searchResult = {
      'Songs': <dynamic>[],
      'searchEndpoint': {'Songs': 'params'},
    };

    final controller = createController('white rabbit');
    controller.onReady();
    await pumpUntil(tester, () => controller.isResultContentFetched.value);

    controller.navigationRailCurrentIndex.value = 1;
    controller.continuationInProgress = true;
    backend.continuationError = Exception('continuation boom');

    await controller.getContinuationContents();

    expect(controller.continuationInProgress, isFalse);
  });
}
