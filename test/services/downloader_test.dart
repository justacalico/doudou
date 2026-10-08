import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/downloader.dart';
import 'package:doudou/ui/screens/Settings/settings_screen_controller.dart';
import 'package:doudou/utils/box_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../fakes.dart';

void main() {
  late Directory dir;
  late Box downloadsBox;
  late Downloader downloader;

  MediaItem song(String id) => MediaItem(id: id, title: 'song $id');

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('doudou_downloader_test_');
    Hive.init(dir.path);
    await Hive.openBox('AppPrefs');
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    Get.put<SettingsScreenController>(FakeSettingsScreenController());
    downloadsBox = await Hive.openBox(songDownloadsBoxName(0));
    downloader = Downloader();
    downloader.debugWriteFileStream = (_) async => true;
  });

  tearDown(() async {
    await downloadsBox.clear();
    await downloadsBox.close();
    downloader.debugWriteFileStream = null;
    await Get.delete<SettingsScreenController>(force: true);
  });

  group('downloadSongList', () {
    test('returns zero failures when every song writes', () async {
      final failures =
          await downloader.downloadSongList([song('a'), song('b')]);

      expect(failures, 0);
    });

    test('counts failed writes and still processes later songs', () async {
      final attempted = <String>[];
      downloader.debugWriteFileStream = (s) async {
        attempted.add(s.id);
        return s.id != 'bad';
      };

      final failures = await downloader
          .downloadSongList([song('ok'), song('bad'), song('ok2')]);

      expect(failures, 1);
      expect(attempted, ['ok', 'bad', 'ok2']);
    });

    test('skips songs already recorded as downloaded', () async {
      await downloadsBox.put('done', {'videoId': 'done'});
      var calls = 0;
      downloader.debugWriteFileStream = (_) async {
        calls++;
        return true;
      };

      final failures =
          await downloader.downloadSongList([song('done'), song('new')]);

      expect(failures, 0);
      expect(calls, 1);
    });
  });

  group('triggerDownloadingJob', () {
    test('drains the song queue without recursion', () async {
      downloader.songQueue.addAll([song('a'), song('b')]);

      await downloader.triggerDownloadingJob();

      expect(downloader.songQueue, isEmpty);
      expect(downloader.isJobRunning.value, isFalse);
    });

    test('keeps working when songs are queued mid-job', () async {
      // Second song is enqueued while the job is already running; the loop
      // must pick it up instead of relying on a recursive re-entry.
      var writes = 0;
      downloader.debugWriteFileStream = (s) async {
        writes++;
        if (writes == 1) downloader.songQueue.add(song('late'));
        return true;
      };
      downloader.songQueue.add(song('first'));

      await downloader.triggerDownloadingJob();

      expect(writes, 2);
      expect(downloader.songQueue, isEmpty);
    });
  });
}
