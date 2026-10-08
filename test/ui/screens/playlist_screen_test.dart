import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Playlist/playlist_screen.dart';
import 'package:doudou/ui/screens/Playlist/playlist_screen_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

class _TestPlayerController extends PlayerController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onReady() {}
}

class _TestPlaylistController extends PlaylistScreenController {
  _TestPlaylistController(Playlist initial) {
    playlist.value = initial;
    isContentFetched.value = true;
    isDefaultPlaylist.value = false;
    isAddedToLibrary.value = false;
  }

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onClose() {}
}

Widget _wrap(Widget child) {
  return GetMaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_playlist_screen_');
    Hive.init(tempDir.path);
    appPrefs = await Hive.openBox('AppPrefs');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
    Get.put<AudioHandler>(FakeAudioHandler());
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    Get.put<ShellController>(ShellController());
    Get.put<Downloader>(Downloader());
    Get.put<PlayerController>(_TestPlayerController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
      'playlist screen top nav no longer shows the dead more_vert pill button',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final tag = key.hashCode.toString();
    final playlist = Playlist(
      title: 'Test Playlist',
      playlistId: 'PLtest',
      thumbnailUrl: '',
      isCloudPlaylist: true,
    );
    Get.put<PlaylistScreenController>(
      _TestPlaylistController(playlist),
      tag: tag,
    );

    await tester.pumpWidget(_wrap(PlaylistScreen(key: key)));
    await tester.pumpAndSettle();

    // The back button is still present in the top nav.
    expect(find.byIcon(Icons.chevron_left), findsWidgets);

    // The dead top-nav more_vert used to be an IconButton inside the pill
    // container. It has been removed, so no IconButton should carry that
    // icon anymore (the SortWidget menu uses a PopupMenuButton, not an
    // IconButton).
    expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsNothing);
  });

  testWidgets('the SortWidget additional-operations menu still works',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final tag = key.hashCode.toString();
    final playlist = Playlist(
      title: 'Test Playlist',
      playlistId: 'PLtest',
      thumbnailUrl: '',
      isCloudPlaylist: true,
    );
    Get.put<PlaylistScreenController>(
      _TestPlaylistController(playlist),
      tag: tag,
    );

    await tester.pumpWidget(_wrap(PlaylistScreen(key: key)));
    await tester.pumpAndSettle();

    // Scroll the song list up so the SortWidget row becomes visible.
    final listFinder = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byIcon(Icons.more_vert),
      200,
      scrollable: listFinder,
    );
    await tester.pumpAndSettle();

    // The functional SortWidget more_vert (a PopupMenuButton) is still there.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byType(PopupMenuButton), findsOneWidget);
  });
}
