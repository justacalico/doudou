import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/components/player_mobile_bottom_bar.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/ui/widgets/up_next_queue.dart';

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

class _FakeAudioHandler extends BaseAudioHandler {}

class _FakeMusicServices extends MusicServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakePlaybackDiagnosticsService extends PlaybackDiagnosticsService {
  @override
  bool get enabled => false;
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

  late PlayerController player;
  late ShellController shell;
  late Downloader downloader;

  setUp(() {
    Get.put<AudioHandler>(_FakeAudioHandler());
    Get.put<MusicServices>(_FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(_FakePlaybackDiagnosticsService());

    player = _TestPlayerController();
    shell = _TestShellController();
    downloader = _FakeDownloader();

    Get.put<PlayerController>(player);
    Get.put<ShellController>(shell);
    Get.put<Downloader>(downloader);
  });

  tearDown(Get.reset);

  testWidgets('renders the queue button', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: PlayerMobileBottomBar(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayerMobileBottomBar), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    expect(find.byTooltip('Queue'), findsOneWidget);
  });

  testWidgets('keeps the other player controls', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: PlayerMobileBottomBar(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IconButton), findsNWidgets(5));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets('queue button opens the UpNextQueue sheet', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: PlayerMobileBottomBar(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(UpNextQueue), findsOneWidget);
  });
}
