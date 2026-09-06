import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/player.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/ui/widgets/up_next_queue.dart';

import '../../fakes.dart';

class _TestPlayerController extends PlayerController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  // ignore: must_call_super
  void onReady() {}
}

class _TestShellController extends ShellController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeDownloader extends Downloader {
  _FakeDownloader() {
    songQueue = <MediaItem>[].obs;
    currentSong = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Get.testMode = true;

  late Directory tempDir;
  late Box appPrefs;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_player_');
    Hive.init(tempDir.path);
    appPrefs = await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  late PlayerController player;
  late ShellController shell;
  late Downloader downloader;

  setUp(() {
    appPrefs.clear();

    Get.put<AudioHandler>(FakeAudioHandler());
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());

    player = _TestPlayerController();
    shell = _TestShellController();
    downloader = _FakeDownloader();

    Get.put<PlayerController>(player);
    Get.put<ShellController>(shell);
    Get.put<Downloader>(downloader);
  });

  tearDown(Get.reset);

  testWidgets('Player keeps the single UpNextQueue panel', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Player(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UpNextQueue), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
  });
}
