import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Artists/artist_header.dart';
import 'package:doudou/ui/screens/Artists/artist_screen_controller.dart';
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

class _FakeArtistController extends ArtistScreenController {
  _FakeArtistController(Artist artist, {int songCount = 5}) {
    artist_ = artist;
    isArtistContentFetced.value = true;
    isAddedToLibrary.value = false;
    final songs = List<MediaItem>.generate(
      songCount,
      (i) => MediaItem(
        id: 's$i',
        title: 'Song $i',
        artist: artist.name,
        duration: const Duration(minutes: 3),
      ),
    );
    sepataredContent['Songs'] = {'results': songs};
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
    tempDir = await Directory.systemTemp.createTemp('doudou_artist_header_');
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

  final artist = Artist(
    name: 'Test Artist',
    browseId: 'UCtest',
    thumbnailUrl: '',
    subscribers: '1.2M',
  );

  testWidgets('narrow header shows centered name and labeled Play All button',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = _FakeArtistController(artist);
    await tester.pumpWidget(_wrap(ArtistHeader(controller: controller)));
    await tester.pumpAndSettle();

    // The artist name is rendered centered.
    expect(find.text('Test Artist'), findsOneWidget);

    // The redesigned action row uses labeled buttons, not bare IconButtons.
    expect(find.widgetWithText(FilledButton, 'Play All'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Shuffle'), findsOneWidget);

    // The old bare play_circle / shuffle IconButtons are gone.
    expect(find.byIcon(Icons.play_circle), findsNothing);
  });

  testWidgets('wide header shows the ARTIST label and the name side by side',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = _FakeArtistController(artist);
    await tester.pumpWidget(_wrap(ArtistHeader(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('Test Artist'), findsOneWidget);
    expect(find.text('ARTIST'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Play All'), findsOneWidget);
  });

  testWidgets('narrow header shows the song count stat', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = _FakeArtistController(artist, songCount: 5);
    await tester.pumpWidget(_wrap(ArtistHeader(controller: controller)));
    await tester.pumpAndSettle();

    // The stats line shows the song count from the separated content.
    expect(find.textContaining('5'), findsWidgets);
  });
}
