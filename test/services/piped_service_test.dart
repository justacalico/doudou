import 'dart:io';

import 'package:doudou/services/piped_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box appPrefs;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_piped_test_');
    Hive.init(dir.path);
    appPrefs = await Hive.openBox('AppPrefs');
  });

  tearDownAll(() async {
    await appPrefs.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    await appPrefs.clear();
  });

  group('Res', () {
    test('holds code, errorMessage and response', () {
      final res = Res(1, errorMessage: 'err', response: {'id': 'x'});
      expect(res.code, 1);
      expect(res.errorMessage, 'err');
      expect(res.response, {'id': 'x'});
    });

    test('works with only code', () {
      final res = Res(0);
      expect(res.code, 0);
      expect(res.errorMessage, isNull);
      expect(res.response, isNull);
    });
  });

  group('PipedInstance', () {
    test('stores name and apiUrl', () {
      final instance = PipedInstance(name: 'Test', apiUrl: 'https://x');
      expect(instance.name, 'Test');
      expect(instance.apiUrl, 'https://x');
    });
  });

  group('PipedServices constructor', () {
    test('is not logged in when no piped data exists', () {
      final service = PipedServices();
      expect(service.isLoggedIn, isFalse);
    });

    test('reads login state from AppPrefs', () {
      appPrefs.put('piped', {
        'isLoggedIn': true,
        'token': 'abc',
        'instApiUrl': 'https://piped.example',
      });

      final service = PipedServices();
      expect(service.isLoggedIn, isTrue);
    });
  });

  group('PipedServices.logout', () {
    test('clears stored piped data and login flag', () {
      appPrefs.put('piped', {
        'isLoggedIn': true,
        'token': 'abc',
        'instApiUrl': 'https://piped.example',
      });

      final service = PipedServices();
      expect(service.isLoggedIn, isTrue);

      service.logout();

      expect(service.isLoggedIn, isFalse);
      final stored = appPrefs.get('piped') as Map?;
      expect(stored?['isLoggedIn'], isFalse);
      expect(stored?['token'], '');
      expect(stored?['instApiUrl'], '');
    });
  });

  group('PipedServices with no instance URL', () {
    setUp(() {
      appPrefs.put('piped', {
        'isLoggedIn': false,
        'token': '',
        'instApiUrl': '',
      });
    });

    test('createPlaylist returns a failed Res', () async {
      final service = PipedServices();
      final res = await service.createPlaylist('test');
      expect(res, isA<Res>());
      expect(res.code, 0);
    });

    test('getAllPlaylists returns a failed Res', () async {
      final service = PipedServices();
      final res = await service.getAllPlaylists();
      expect(res, isA<Res>());
      expect(res.code, 0);
    });

    test('renamePlaylist returns a failed Res', () async {
      final service = PipedServices();
      final res = await service.renamePlaylist('pl', 'new');
      expect(res, isA<Res>());
      expect(res.code, 0);
    });

    test('deletePlaylist returns a failed Res', () async {
      final service = PipedServices();
      final res = await service.deletePlaylist('pl');
      expect(res, isA<Res>());
      expect(res.code, 0);
    });

    test('addToPlaylist returns a failed Res', () async {
      final service = PipedServices();
      final res = await service.addToPlaylist('pl', ['v1']);
      expect(res, isA<Res>());
      expect(res.code, 0);
    });

    test('removeFromPlaylist returns a failed Res', () async {
      final service = PipedServices();
      final res = await service.removeFromPlaylist('pl', 0);
      expect(res, isA<Res>());
      expect(res.code, 0);
    });

    test('getPlaylistSongs returns empty list on error', () async {
      final service = PipedServices();
      final songs = await service.getPlaylistSongs('pl');
      expect(songs, isEmpty);
    });
  });
}
