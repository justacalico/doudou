import 'dart:io';

import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/models/server.dart';
import 'package:doudou/services/backend/backend_capabilities.dart';
import 'package:doudou/services/backend/music_backend.dart';
import 'package:doudou/services/library_sync_service.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/ui/screens/Home/home_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/utils/box_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

class _FakeBackend extends MusicBackend {
  Object? homeError;
  List<dynamic> homeResult = const [];

  @override
  BackendCapabilities get capabilities => const BackendCapabilities();

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
  Future<dynamic> getHome({int limit = 4}) async {
    final error = homeError;
    if (error != null) throw error;
    return homeResult;
  }

  @override
  Future<List<Map<String, dynamic>>> getCharts(String category,
          {String? countryCode}) async =>
      [];

  @override
  Future<Map<String, dynamic>> search(String query,
          {String? filter,
          String? scope,
          int limit = 30,
          bool ignoreSpelling = false,
          dynamic filterParams}) async =>
      {};

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
      {};

  @override
  Future<String?> getStreamUrl(String mediaItemId) async => null;

  @override
  Future<List<Playlist>> getLibraryPlaylists() async => [];

  @override
  Future<Map<String, dynamic>> getSearchContinuation(
          Map<String, dynamic> additionalParamsNext,
          {int limit = 10}) async =>
      {};
}

class _TestSettingsController extends FakeSettingsScreenController {
  _TestSettingsController(this.backend);

  final _FakeBackend backend;

  @override
  MusicBackend get currentBackend => backend;
}

void main() {
  late Directory dir;
  late Box appPrefs;
  late _FakeBackend backend;
  late _TestSettingsController settings;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_home_test_');
    Hive.init(dir.path);
    appPrefs = await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
    await appPrefs.put('checkForUpdatesOnStartup', false);
    backend = _FakeBackend();
    settings = _TestSettingsController(backend);
    Get.put<SettingsScreenController>(settings);
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<LibrarySyncService>(FakeLibrarySyncService());
  });

  tearDown(() async {
    await Get.delete<HomeScreenController>(force: true);
    await Get.delete<LibrarySyncService>(force: true);
    await Get.delete<MusicServices>(force: true);
    await Get.delete<SettingsScreenController>(force: true);
    const name = 'homeScreenData';
    if (Hive.isBoxOpen(name)) {
      await Hive.box(name).clear();
    } else {
      final box = await Hive.openBox(name);
      await box.clear();
      await box.close();
    }
  });

  HomeScreenController putController() =>
      Get.put(HomeScreenController());

  group('loadContentFromDb', () {
    test('returns false when the box is empty', () async {
      final ctrl = putController();
      expect(await ctrl.loadContentFromDb(), isFalse);
      expect(ctrl.isContentFetched.value, isFalse);
    });

    test('returns false instead of throwing on malformed cache', () async {
      final box = await Hive.openBox(homeScreenDataBoxName(0));
      // quickPicks holds the wrong type: the old cast crashed the whole load.
      await box.put('quickPicksType', 'Quick picks');
      await box.put('quickPicks', 'not-a-list');

      final ctrl = putController();
      expect(await ctrl.loadContentFromDb(), isFalse);
      expect(ctrl.isContentFetched.value, isFalse);
    });

    test('returns false on malformed section lists', () async {
      final box = await Hive.openBox(homeScreenDataBoxName(0));
      await box.put('quickPicksType', 42);
      await box.put('quickPicks', <dynamic>[]);
      await box.put('middleContent', 'garbage');
      await box.put('fixedContent', 7);

      final ctrl = putController();
      expect(await ctrl.loadContentFromDb(), isFalse);
    });

    test('loads a well-formed cache', () async {
      final box = await Hive.openBox(homeScreenDataBoxName(0));
      await box.put('quickPicksType', 'Quick picks');
      await box.put('quickPicks', <dynamic>[]);
      await box.put('middleContent', <dynamic>[]);
      await box.put('fixedContent', <dynamic>[]);

      final ctrl = putController();
      expect(await ctrl.loadContentFromDb(), isTrue);
      expect(ctrl.isContentFetched.value, isTrue);
      expect(ctrl.quickPicks.value.title, 'Quick picks');
    });
  });

  group('loadYoutubeMusicHomeFeed', () {
    test('stores content and clears networkError on success', () async {
      backend.homeResult = [
        {'title': 'shelf', 'contents': []}
      ];

      final ctrl = putController();
      ctrl.networkError.value = true;
      await ctrl.loadYoutubeMusicHomeFeed();

      expect(ctrl.youtubeMusicHomeContent, isNotEmpty);
      expect(ctrl.networkError.value, isFalse);
      expect(ctrl.isLoadingYoutubeMusicHome.value, isFalse);
    });

    test('sets networkError so the UI can offer a retry', () async {
      backend.homeError = StateError('boom');

      final ctrl = putController();
      await ctrl.loadYoutubeMusicHomeFeed();

      expect(ctrl.youtubeMusicHomeContent, isEmpty);
      expect(ctrl.networkError.value, isTrue);
      expect(ctrl.isLoadingYoutubeMusicHome.value, isFalse);
    });

    test('does nothing on a non YouTube Music server', () async {
      settings.serverType = ServerType.jellyfin;
      backend.homeError = StateError('must not be called');

      final ctrl = putController();
      await ctrl.loadYoutubeMusicHomeFeed();

      expect(ctrl.isLoadingYoutubeMusicHome.value, isFalse);
      expect(ctrl.networkError.value, isFalse);
    });
  });
}
