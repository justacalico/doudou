import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'golden_image_overrides.dart';
import 'golden_path_provider.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final interLoader = FontLoader('Inter');
  for (final variant in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    interLoader.addFont(
      File('test/fonts/Inter-$variant.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await interLoader.load();

  final monoLoader = FontLoader('monospace');
  for (final variant in ['Regular', 'Bold']) {
    monoLoader.addFont(
      File('test/fonts/RobotoMono-$variant.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await monoLoader.load();

  final materialLoader = FontLoader('MaterialIcons')
    ..addFont(
      File('test/fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
  await materialLoader.load();

  final ioniconsLoader = FontLoader('packages/ionicons_plus/Ionicons')
    ..addFont(
      File('test/fonts/Ionicons.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
  await ioniconsLoader.load();

  HttpOverrides.global = GoldenHttpOverrides();
  PathProviderPlatform.instance = FakePathProviderPlatform(
      Directory.systemTemp.createTempSync('doudou_goldens_').path);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );

  await testMain();
}
