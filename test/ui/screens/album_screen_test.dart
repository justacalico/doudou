import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/album.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Album/album_screen.dart';
import 'package:doudou/ui/screens/Album/album_screen_controller.dart';
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

class _TestAlbumController extends AlbumScreenController {
  _TestAlbumController(Album initial, List<MediaItem> songs) {
    album.value = initial;
    songList.assignAll(songs);
    isContentFetched.value = true;
    isAddedToLibrary.value = false;
    isDownloaded.value = false;
  }

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onReady() {}

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
    tempDir = await Directory.systemTemp.createTemp('doudou_album_screen_');
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

  final album = Album(
    title: 'Test Album',
    browseId: 'MPREtest',
    artists: [
      {'name': 'Test Artist', 'id': 'UCtest'}
    ],
    year: '2024',
    thumbnailUrl: '',
  );

  final songs = List<MediaItem>.generate(
    3,
    (i) => MediaItem(
      id: 'song$i',
      title: 'Song $i',
      artist: 'Test Artist',
      album: 'Test Album',
      artUri: Uri.parse(''),
      extras: {'url': 'https://example.com/song$i.mp3'},
    ),
  );

  testWidgets(
      'album action row uses labeled Play All and Shuffle buttons instead of the old circular play button',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final tag = key.hashCode.toString();
    Get.put<AlbumScreenController>(_TestAlbumController(album, songs), tag: tag);

    await tester.pumpWidget(_wrap(AlbumScreen(key: key)));
    await tester.pumpAndSettle();

    // The redesigned action row uses labeled pill buttons.
    expect(find.widgetWithText(FilledButton, 'Play All'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Shuffle'), findsOneWidget);

    // The old white circular play button with play_arrow_rounded is gone.
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
  });

  testWidgets('album hero shows the album title and year', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final tag = key.hashCode.toString();
    Get.put<AlbumScreenController>(_TestAlbumController(album, songs), tag: tag);

    await tester.pumpWidget(_wrap(AlbumScreen(key: key)));
    await tester.pumpAndSettle();

    expect(find.text('Test Album'), findsWidgets);
    expect(find.textContaining('2024'), findsWidgets);
  });
}
