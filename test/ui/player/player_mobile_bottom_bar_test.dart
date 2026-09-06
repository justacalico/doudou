import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/components/player_mobile_bottom_bar.dart';
import 'package:doudou/ui/player/player_controller.dart';
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

MediaItem _song(String id, String title) => MediaItem(
      id: id,
      title: title,
      extras: {'url': 'https://example.com/$id.mp3'},
    );

Widget _wrap(Widget child) {
  return MaterialApp(
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
  late Box songDownloads;
  late FakeAudioHandler fakeAudio;
  late PlayerController player;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_bottom_bar_');
    Hive.init(tempDir.path);
    appPrefs = await Hive.openBox('AppPrefs');
    songDownloads = await Hive.openBox('SongDownloads');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
    await songDownloads.clear();
    fakeAudio = FakeAudioHandler();

    Get.put<AudioHandler>(fakeAudio);
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    Get.put<ShellController>(ShellController());
    Get.put<Downloader>(Downloader());

    player = Get.put<PlayerController>(_TestPlayerController());
    player.initFlagForPlayer = false;
    player.currentQueue.assignAll([_song('a', 'A'), _song('b', 'B')]);
    player.currentSongIndex.value = 0;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('bottom bar does not render a queue button',
      (tester) async {
    await tester.pumpWidget(_wrap(const PlayerMobileBottomBar()));
    await tester.pumpAndSettle();

    final queueIcons = tester.widgetList<Icon>(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.queue_music_rounded,
      ),
    );
    expect(queueIcons, isEmpty);

    // Sanity check: the favorite button is still rendered.
    expect(
      find.byTooltip('Favorite'),
      findsOneWidget,
    );
  });
}
