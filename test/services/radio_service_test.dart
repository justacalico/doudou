import 'package:audio_service/audio_service.dart';
import 'package:doudou/services/radio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

class _FakeMusicServices extends FakeMusicServices {
  Map<String, List<MediaItem>> radioTracks = {};
  List<MediaItem> Function(String seedId)? radioTrackGenerator;
  final List<String> seedRadioCalls = [];

  @override
  Future<Map<String, dynamic>> getWatchPlaylist(
      {String videoId = "",
      String? playlistId,
      int limit = 25,
      bool radio = false,
      bool shuffle = false,
      String? additionalParamsNext,
      bool onlyRelated = false}) async {
    seedRadioCalls.add(videoId.isEmpty ? 'playlist:$playlistId' : videoId);
    final tracks = radioTracks[videoId] ??
        radioTrackGenerator?.call(videoId) ??
        <MediaItem>[];
    return {'tracks': tracks, 'additionalParamsForNext': null};
  }
}

MediaItem _song(String id, {String artist = 'a'}) =>
    MediaItem(id: id, title: 'Song $id', artist: artist);

void main() {
  group('RadioService', () {
    late _FakeMusicServices music;
    late RadioService service;

    setUp(() {
      music = _FakeMusicServices();
      service = RadioService(musicServices: music);
    });

    test('initial fetch excludes the seed song', () async {
      final seed = _song('seed');
      music.radioTracks['seed'] = [seed, _song('r1'), _song('r2')];

      service.initFromSeed('seed', excludeIds: {'seed'});
      final tracks = await service.fetchInitial();

      expect(tracks.map((t) => t.id), ['r1', 'r2']);
    });

    test('initial fetch returns an empty list when the seed is unknown',
        () async {
      service.initFromSeed('seed', excludeIds: {'seed'});
      final tracks = await service.fetchInitial();
      expect(tracks, isEmpty);
    });

    test('continuation rotates through seeds and never repeats served songs',
        () async {
      final seed = _song('seed');
      music.radioTracks['seed'] = [seed, _song('a1'), _song('a2')];
      // a1 becomes a new seed and its page introduces fresh tracks.
      music.radioTracks['a1'] = [_song('b1'), _song('b2')];
      // a2 becomes a new seed and its page introduces fresh tracks.
      music.radioTracks['a2'] = [_song('c1'), _song('c2')];

      service.initFromSeed('seed', excludeIds: {'seed'});
      await service.fetchInitial();
      music.seedRadioCalls.clear();

      final first = await service.fetchMore();
      final second = await service.fetchMore();

      expect(first, isNotEmpty);
      expect(second, isNotEmpty);
      // pages came from different seeds
      expect(music.seedRadioCalls.toSet().length, greaterThan(1));
      // no overlap between pages
      final overlap = first.map((t) => t.id).toSet()
        ..retainAll(second.map((t) => t.id).toSet());
      expect(overlap, isEmpty);
      // the original seed never appears again
      expect(first.map((t) => t.id), isNot(contains('seed')));
      expect(second.map((t) => t.id), isNot(contains('seed')));
    });

    test('additional excludeIds passed to fetchMore are respected', () async {
      music.radioTracks['seed'] = [_song('r1'), _song('r2')];

      service.initFromSeed('seed', excludeIds: {'seed'});
      await service.fetchInitial();

      final more = await service.fetchMore(excludeIds: {'r2'});

      expect(more.map((t) => t.id), contains('r1'));
      expect(more.map((t) => t.id), isNot(contains('r2')));
    });

    test('playlist-based radio passes through without multi-seed rotation',
        () async {
      music.radioTracks[''] = [_song('p1'), _song('p2')];

      service.initFromPlaylist('RDAMPLabc');
      final tracks = await service.fetchInitial();

      expect(service.isPlaylistBased, isTrue);
      expect(tracks.map((t) => t.id), ['p1', 'p2']);
    });

    test('duplicate tracks are removed from a single page', () async {
      final dup = _song('dup');
      music.radioTracks['seed'] = [dup, dup, _song('other')];

      service.initFromSeed('seed', excludeIds: {'seed'});
      final tracks = await service.fetchInitial();

      expect(tracks.where((t) => t.id == 'dup').length, 1);
    });

    test('markServed prevents ids from being returned later', () async {
      music.radioTracks['seed'] = [_song('r1'), _song('r2')];

      service.initFromSeed('seed', excludeIds: {'seed'});
      service.markServed({'r1'});
      final tracks = await service.fetchInitial();

      expect(tracks.map((t) => t.id), ['r2']);
    });
  });
}
