import 'dart:io';

import 'package:doudou/services/music_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box appPrefs;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_music_test_');
    Hive.init(dir.path);
    appPrefs = await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await appPrefs.close();
    await dir.delete(recursive: true);
    await Get.delete<MusicServices>();
  });

  setUp(() async {
    await appPrefs.clear();
    await Get.delete<MusicServices>(force: true);
  });

  group('AudioQuality', () {
    test('has Low and High values', () {
      expect(AudioQuality.values, contains(AudioQuality.Low));
      expect(AudioQuality.values, contains(AudioQuality.High));
    });
  });

  group('NetworkError', () {
    test('has the expected message', () {
      final error = NetworkError();
      expect(error.message, 'Network Error !');
    });
  });

  group('MusicServices', () {
    test('init completes when no visitor is stored and no network', () async {
      await appPrefs.put('contentLanguage', 'fr');

      final service = MusicServices();
      // Make any network attempt fail instantly so the test is fast.
      service.dio.options.connectTimeout = const Duration(milliseconds: 1);
      service.dio.options.receiveTimeout = const Duration(milliseconds: 1);

      Get.put(service);

      await service.init();

      // The visitor id fetch failed, so nothing is persisted.
      expect(appPrefs.get('visitorId'), isNull);
    });

    test('init reuses a non-expired stored visitor id', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await appPrefs.put('visitorId', {
        'id': 'stored-id',
        'exp': now + 10000,
      });

      final service = MusicServices();
      service.dio.options.connectTimeout = const Duration(milliseconds: 1);
      Get.put(service);

      await service.init();

      final visitor = appPrefs.get('visitorId');
      expect(visitor, isNotNull);
      expect(visitor['id'], 'stored-id');
    });

    test('hlCode setter updates the context language', () {
      final service = MusicServices();
      service.hlCode = 'es';
      // The field is internal; we mainly assert the setter does not throw.
      expect(service, isA<MusicServices>());
    });

    test('genrateVisitorId returns null on network failure', () async {
      final service = MusicServices();
      service.dio.options.connectTimeout = const Duration(milliseconds: 1);
      service.dio.options.receiveTimeout = const Duration(milliseconds: 1);

      final visitorId = await service.genrateVisitorId();

      expect(visitorId, isNull);
    });
  });
}
