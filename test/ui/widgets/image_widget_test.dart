import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/ui/widgets/image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class _TestSettingsController extends SettingsScreenController {
  _TestSettingsController(this._supportDir);

  final String _supportDir;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  String get supportDirPath => _supportDir;
}

// Loopback on a closed port so the image request fails fast instead of
// hanging the test on a real network call.
const _artUrl = 'http://127.0.0.1:9/art.png';

MediaItem _song(String id, {required String url, String? artUrl}) => MediaItem(
      id: id,
      title: id,
      artUri: artUrl == null ? Uri.parse('') : Uri.parse(artUrl),
      extras: {'url': url},
    );

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('image_widget_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('AppPrefs');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    Get.reset();
    Get.put<SettingsScreenController>(_TestSettingsController(tempDir.path));
  });

  Widget wrap(MediaItem song) => MaterialApp(
        home: Scaffold(body: ImageWidget(song: song, size: 48)),
      );

  testWidgets(
      'a song playing from a cache file still loads remote art when no downloaded thumbnail exists',
      (tester) async {
    await tester.pumpWidget(
        wrap(_song('a', url: 'file:///cache/a.m4a', artUrl: _artUrl)));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets(
      'a song playing from a cache file without a remote art url shows the placeholder instead of the network image',
      (tester) async {
    await tester.pumpWidget(wrap(_song('b', url: 'file:///cache/b.m4a')));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('a streamed song loads remote art', (tester) async {
    await tester.pumpWidget(
        wrap(_song('c', url: 'https://example.com/c', artUrl: _artUrl)));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
