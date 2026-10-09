import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/constants/doudou_design.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/widgets/library_section_builders.dart';
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
  late Directory dir;
  late PlayerController playerController;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('section_builders_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
    Get.put<AudioHandler>(FakeAudioHandler());
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    playerController = _TestPlayerController();
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Widget buildSections() {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Builder(
                builder: (context) => buildTrackRowSection(
                  context: context,
                  title: 'Tracks',
                  subtitle: 'Track subtitle',
                  items: const [],
                  playLabel: 'Play',
                  playerController: playerController,
                ),
              ),
              Builder(
                builder: (context) => buildPlaylistRowSection(
                  context: context,
                  title: 'Playlists',
                  subtitle: 'Playlist subtitle',
                  playlists: const [],
                ),
              ),
              Builder(
                builder: (context) => buildAlbumRowSection(
                  context: context,
                  title: 'Albums',
                  subtitle: 'Album subtitle',
                  albums: const [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('section titles render without a purple accent dot',
      (tester) async {
    await tester.pumpWidget(buildSections());
    await tester.pumpAndSettle();

    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == kDoudouPurple;
      }),
      findsNothing,
    );
  });
}
