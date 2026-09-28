import 'dart:async';
import 'dart:io';

import 'package:doudou/services/song_preloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('song_preloader_test_');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  SongPreloader makePreloader(SongBytesDownloader downloader) =>
      SongPreloader(directory: dir, downloader: downloader);

  Future<void> writeBytes(
          Uri uri, File target, Map<String, String>? headers) =>
      target.writeAsBytes(const [1, 2, 3]);

  test('downloads the file and reports it complete', () async {
    final preloader = makePreloader(writeBytes);

    expect(preloader.completeFileFor('a'), isNull);
    await preloader.preload('a', 'https://example.com/a.mp3');

    final file = preloader.completeFileFor('a');
    expect(file, isNotNull);
    expect(file!.path, '${dir.path}/a.mp3');
    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(File('${dir.path}/a.mp3.part').existsSync(), isFalse);
  });

  test('passes headers through to the downloader', () async {
    Map<String, String>? captured;
    final preloader = makePreloader((uri, target, headers) async {
      captured = headers;
      await target.writeAsBytes(const [1]);
    });

    await preloader.preload('a', 'https://example.com/a.mp3',
        headers: {'User-Agent': 'test'});

    expect(captured, {'User-Agent': 'test'});
  });

  test('skips non-http urls without calling the downloader', () async {
    var calls = 0;
    final preloader = makePreloader((uri, target, headers) async {
      calls++;
    });

    await preloader.preload('a', 'file://${dir.path}/a.mp3');
    expect(calls, 0);
  });

  test('skips songs whose file is already complete', () async {
    var calls = 0;
    final preloader = makePreloader(writeBytes);
    await preloader.preload('a', 'https://example.com/a.mp3');

    final counting = SongPreloader(
        directory: dir,
        downloader: (uri, target, headers) async {
          calls++;
        });
    await counting.preload('a', 'https://example.com/a.mp3');
    expect(calls, 0);
  });

  test('a failed download leaves no complete file and cleans the part file',
      () async {
    final preloader = makePreloader((uri, target, headers) async {
      await target.writeAsBytes(const [1, 2]);
      throw const SocketException('connection lost');
    });

    await preloader.preload('a', 'https://example.com/a.mp3');

    expect(preloader.completeFileFor('a'), isNull);
    expect(File('${dir.path}/a.mp3.part').existsSync(), isFalse);
  });

  test('a failed download can be retried', () async {
    var calls = 0;
    final preloader = makePreloader((uri, target, headers) async {
      calls++;
      if (calls == 1) throw const SocketException('offline');
      await target.writeAsBytes(const [9]);
    });

    await preloader.preload('a', 'https://example.com/a.mp3');
    expect(preloader.completeFileFor('a'), isNull);

    await preloader.preload('a', 'https://example.com/a.mp3');
    expect(preloader.completeFileFor('a'), isNotNull);
    expect(calls, 2);
  });

  test('coalesces concurrent downloads for the same song', () async {
    var calls = 0;
    final preloader = makePreloader((uri, target, headers) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await target.writeAsBytes(const [1]);
    });

    final first = preloader.preload('a', 'https://example.com/a.mp3');
    final second = preloader.preload('a', 'https://example.com/a.mp3');
    await Future.wait([first, second]);

    expect(calls, 1);
  });

  test('downloads run one at a time', () async {
    final order = <String>[];
    final preloader = makePreloader((uri, target, headers) async {
      order.add('start:${uri.pathSegments.last}');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      order.add('end:${uri.pathSegments.last}');
      await target.writeAsBytes(const [1]);
    });

    await Future.wait([
      preloader.preload('a', 'https://example.com/a.mp3'),
      preloader.preload('b', 'https://example.com/b.mp3'),
    ]);

    // the second download must wait for the first to finish so prefetching
    // does not compete with the playing stream
    expect(order, [
      'start:a.mp3',
      'end:a.mp3',
      'start:b.mp3',
      'end:b.mp3',
    ]);
    expect(preloader.completeFileFor('a'), isNotNull);
    expect(preloader.completeFileFor('b'), isNotNull);
  });

  test('retainOnly deletes files outside the keep set', () async {
    final preloader = makePreloader(writeBytes);
    for (final id in ['a', 'b', 'c', 'd']) {
      await preloader.preload(id, 'https://example.com/$id.mp3');
    }

    preloader.retainOnly({'b', 'c'});
    await Future<void>.delayed(Duration.zero);

    expect(preloader.completeFileFor('a'), isNull);
    expect(preloader.completeFileFor('b'), isNotNull);
    expect(preloader.completeFileFor('c'), isNotNull);
    expect(preloader.completeFileFor('d'), isNull);
  });

  test('retainOnly keeps part files with a download still in flight',
      () async {
    final gate = Completer<void>();
    final preloader = makePreloader((uri, target, headers) async {
      await target.writeAsBytes(const [1]);
      await gate.future;
    });
    final pending = preloader.preload('a', 'https://example.com/a.mp3');
    // wait for the download to start and the part file to appear
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(File('${dir.path}/a.mp3.part').existsSync(), isTrue);

    preloader.retainOnly(const {});
    await Future<void>.delayed(Duration.zero);

    expect(File('${dir.path}/a.mp3.part').existsSync(), isTrue);

    gate.complete();
    await pending;
    expect(preloader.completeFileFor('a'), isNotNull);
  });
}
