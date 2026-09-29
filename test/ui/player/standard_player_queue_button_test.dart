import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/components/standard_player.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/ui/widgets/queue_drawer.dart';
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

class _TestSettingsController extends FakeSettingsScreenController {
  _TestSettingsController(this.supportDir);

  final String supportDir;

  @override
  String get supportDirPath => supportDir;
}

MediaItem _song(String id, String title) => MediaItem(
      id: id,
      title: title,
      artUri: Uri.parse(''),
      extras: {'url': 'https://example.com/$id.mp3'},
    );

Widget _wrap(PlayerController player) {
  return GetMaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      key: player.homeScaffoldkey,
      endDrawer: const QueueDrawer(),
      body: const StandardPlayer(),
    ),
  );
}

Finder _queueButton() => find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.queue_music_rounded,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late Box songDownloads;
  late PlayerController player;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_std_player_');
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

    Get.put<AudioHandler>(FakeAudioHandler());
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(_TestSettingsController(tempDir.path));
    Get.put<ShellController>(ShellController());
    Get.put<Downloader>(Downloader());

    player = Get.put<PlayerController>(_TestPlayerController());
    player.initFlagForPlayer = false;
    player.currentQueue.assignAll([_song('a', 'A'), _song('b', 'B')]);
    player.currentSongIndex.value = 0;
    player.currentSong.value = _song('a', 'A');
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('compact player shows a queue button on desktop', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(player));
    await tester.pumpAndSettle();

    expect(_queueButton(), findsOneWidget);
  });

  testWidgets('compact queue button opens the queue drawer', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(player));
    await tester.pumpAndSettle();

    expect(player.homeScaffoldkey.currentState!.isEndDrawerOpen, isFalse);
    await tester.tap(_queueButton());
    await tester.pumpAndSettle();

    expect(player.homeScaffoldkey.currentState!.isEndDrawerOpen, isTrue);

    // UpNextQueue retries its scroll-to-current a few times on a timer.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('expanded player shows a queue button that opens the drawer',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(player));
    await tester.pumpAndSettle();

    await tester.tap(_queueButton());
    await tester.pumpAndSettle();

    expect(player.homeScaffoldkey.currentState!.isEndDrawerOpen, isTrue);

    // UpNextQueue retries its scroll-to-current a few times on a timer.
    await tester.pump(const Duration(seconds: 1));
  });
}
