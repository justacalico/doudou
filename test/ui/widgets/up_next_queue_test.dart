import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/ui/widgets/queue_drawer.dart';
import 'package:doudou/ui/widgets/up_next_queue.dart';
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

Widget _wrap(Widget child, {double topPadding = 0}) {
  return GetMaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(padding: EdgeInsets.only(top: topPadding)),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late Box songDownloads;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_queue_');
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
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    Get.put<ShellController>(ShellController());
    Get.put<Downloader>(Downloader());
    Get.put<PlayerController>(_TestPlayerController());
  });

  tearDown(() {
    Get.reset();
  });

  Future<double> headerTop(WidgetTester tester, Widget child,
      {double topPadding = 0}) async {
    await tester.pumpWidget(_wrap(child, topPadding: topPadding));
    await tester.pumpAndSettle();
    return tester.getTopLeft(find.text('Queue')).dy;
  }

  testWidgets('slide-up queue panel clears the status bar', (tester) async {
    final noInset = await headerTop(tester, const UpNextQueue());
    final withInset =
        await headerTop(tester, const UpNextQueue(), topPadding: 24);

    expect(withInset - noInset, moreOrLessEquals(24));
  });

  testWidgets('non-panel queue keeps its own padding under a status bar',
      (tester) async {
    final noInset =
        await headerTop(tester, const UpNextQueue(isQueueInSlidePanel: false));
    final withInset = await headerTop(
        tester, const UpNextQueue(isQueueInSlidePanel: false),
        topPadding: 24);

    expect(withInset, moreOrLessEquals(noInset));
  });

  testWidgets('queue drawer header clears the status bar', (tester) async {
    await tester.pumpWidget(_wrap(const QueueDrawer()));
    await tester.pumpAndSettle();
    final noInset = tester.getTopLeft(find.text('Up Next')).dy;

    await tester.pumpWidget(_wrap(const QueueDrawer(), topPadding: 24));
    await tester.pumpAndSettle();
    final withInset = tester.getTopLeft(find.text('Up Next')).dy;

    expect(withInset - noInset, moreOrLessEquals(24));
  });
}
