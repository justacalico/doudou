import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/components/now_playing_play_button.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:flutter/material.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late FakeAudioHandler fakeAudio;
  late PlayerController player;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('doudou_play_button_');
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
    fakeAudio = FakeAudioHandler();

    Get.put<AudioHandler>(fakeAudio);
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());

    player = Get.put<PlayerController>(_TestPlayerController());
    player.initFlagForPlayer = false;
  });

  tearDown(() {
    Get.reset();
  });

  Widget wrap() {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: NowPlayingPlayButton(
            controller: player,
            size: 64,
            iconSize: 36,
            backgroundColor: Colors.white,
            iconColor: Colors.black,
          ),
        ),
      ),
    );
  }

  testWidgets('shows a loading indicator while a song is loading',
      (tester) async {
    player.buttonState.value = PlayButtonState.loading;

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('shows the pause icon while playing', (tester) async {
    player.buttonState.value = PlayButtonState.playing;

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the play icon while paused', (tester) async {
    player.buttonState.value = PlayButtonState.paused;

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ignores taps while loading', (tester) async {
    player.buttonState.value = PlayButtonState.loading;

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.tap(find.byType(NowPlayingPlayButton));
    await tester.pump();

    expect(fakeAudio.calls, isEmpty);
  });

  testWidgets('toggles playback on tap when not loading', (tester) async {
    player.buttonState.value = PlayButtonState.paused;
    fakeAudio.playbackState.add(PlaybackState(playing: false));

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.tap(find.byType(NowPlayingPlayButton));
    await tester.pump();

    expect(fakeAudio.calls.single.name, 'play');
  });
}
