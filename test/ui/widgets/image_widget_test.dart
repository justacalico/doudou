import 'dart:convert';
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

// A valid 1x1 transparent PNG so the file image can actually decode.
final _png1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

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

  testWidgets('a downloaded song shows its saved thumbnail once checked',
      (tester) async {
    final thumbDir = Directory('${tempDir.path}/thumbnails')
      ..createSync(recursive: true);
    File('${thumbDir.path}/d.png').writeAsBytesSync(_png1x1);

    await tester.pumpWidget(
        wrap(_song('d', url: 'file:///downloads/d.m4a', artUrl: _artUrl)));
    // First frame: existence check still pending, remote art path used.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    // Once the async stat resolves the file image takes over.
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsNothing);
    final decorated = tester
        .widgetList<DecoratedBox>(find.descendant(
          of: find.byType(ImageWidget),
          matching: find.byType(DecoratedBox),
        ))
        .firstWhere((d) =>
            d.decoration is BoxDecoration &&
            (d.decoration as BoxDecoration).image != null);
    final image = (decorated.decoration as BoxDecoration).image;
    expect(image?.image, isA<FileImage>());
  });
}
