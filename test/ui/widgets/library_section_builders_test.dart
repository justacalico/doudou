import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/l10n/app_localizations.dart';
import 'package:doudou/models/playling_from.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/services/music_service.dart';
import 'package:doudou/services/playback_diagnostics_service.dart';
import 'package:doudou/ui/player/player_controller.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/shell_controller.dart';
import 'package:doudou/ui/widgets/library_section_builders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../fakes.dart';

class _PlayListCall {
  _PlayListCall(this.items, this.index, this.playfrom);

  final List<MediaItem> items;
  final int index;
  final PlaylingFrom? playfrom;
}

class _TestSettingsScreenController extends FakeSettingsScreenController {
  @override
  String get supportDirPath => '/tmp';
}

class _TestPlayerController extends PlayerController {
  final radioSeeds = <MediaItem?>[];
  final playListCalls = <_PlayListCall>[];

  @override
  void onInit() {}

  @override
  void onReady() {}

  @override
  Future<void> startRadio(MediaItem? mediaItem, {String? playlistid}) async {
    radioSeeds.add(mediaItem);
  }

  @override
  Future<void> playPlayListSong(List<MediaItem> mediaItems, int index,
      {PlaylingFrom? playfrom}) async {
    playListCalls.add(_PlayListCall(mediaItems, index, playfrom));
  }
}

Widget _wrap(Widget Function(BuildContext) builder) {
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
      builder: (context) => Scaffold(body: builder(context)),
    ),
  );
}

MediaItem _song(String id, String title) => MediaItem(
      id: id,
      title: title,
      artist: 'Test Artist',
      album: 'Test Album',
      artUri: Uri.parse(''),
      extras: {'url': 'https://example.com/$id.mp3'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box appPrefs;
  late _TestPlayerController playerController;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('doudou_section_builders_');
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
    Get.reset();

    Get.put<AudioHandler>(FakeAudioHandler());
    Get.put<MusicServices>(FakeMusicServices());
    Get.put<PlaybackDiagnosticsService>(FakePlaybackDiagnosticsService());
    Get.put<SettingsScreenController>(_TestSettingsScreenController());
    Get.put<ShellController>(ShellController());
    Get.put<Downloader>(Downloader());
    playerController = _TestPlayerController();
    Get.put<PlayerController>(playerController);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('track row plays the list by default', (tester) async {
    final items = [_song('a', 'Track A'), _song('b', 'Track B')];

    await tester.pumpWidget(_wrap((context) => buildTrackRowSection(
          context: context,
          title: 'Section',
          subtitle: 'Subtitle',
          items: items,
          playLabel: 'Section',
          playerController: playerController,
        )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track B'));
    await tester.pump();

    expect(playerController.radioSeeds, isEmpty);
    expect(playerController.playListCalls, hasLength(1));
    expect(playerController.playListCalls.first.index, 1);
    expect(playerController.playListCalls.first.items, items);
  });

  testWidgets('track row starts a radio when startAsRadio is true',
      (tester) async {
    final items = [_song('a', 'Track A'), _song('b', 'Track B')];

    await tester.pumpWidget(_wrap((context) => buildTrackRowSection(
          context: context,
          title: 'Because you like',
          subtitle: 'Subtitle',
          items: items,
          playLabel: 'Because you like',
          playerController: playerController,
          startAsRadio: true,
        )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track B'));
    await tester.pump();

    expect(playerController.playListCalls, isEmpty);
    expect(playerController.radioSeeds, hasLength(1));
    expect(playerController.radioSeeds.first, items[1]);
  });

  testWidgets('fresh picks start a radio for the tapped track',
      (tester) async {
    final items = [_song('a', 'Track A'), _song('b', 'Track B')];

    await tester.pumpWidget(_wrap((context) => buildFreshPicksSection(
          context: context,
          items: items,
          playerController: playerController,
        )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track B'));
    await tester.pump();

    expect(playerController.playListCalls, isEmpty);
    expect(playerController.radioSeeds, hasLength(1));
    expect(playerController.radioSeeds.first, items[1]);
  });
}
