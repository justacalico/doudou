import 'package:audio_service/audio_service.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/services/supermix_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

class _FakeMusicServices extends FakeMusicServices {
  List<dynamic> homeSections = [];
  Map<String, List<MediaItem>> playlistTracks = {};
  Map<String, List<MediaItem>> radioTracks = {};
  List<MediaItem> Function(String seedId)? radioTrackGenerator;
  final List<String> seedRadioCalls = [];
  int homeCalls = 0;

  @override
  Future<dynamic> getHome({int limit = 4}) async {
    homeCalls++;
    return homeSections;
  }

  @override
  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0}) async {
    return {'tracks': playlistTracks[playlistId] ?? <MediaItem>[]};
  }

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
    return {'tracks': tracks};
  }
}

MediaItem _song(String id, {String artist = 'a'}) =>
    MediaItem(id: id, title: 'Song $id', artist: artist);

Playlist _playlist(String id, String title) =>
    Playlist(title: title, playlistId: id, thumbnailUrl: '');

void main() {
  group('findSupermixPlaylist', () {
    test('finds the RDTMAK mix playlist inside home sections', () {
      final supermix = _playlist('VLRDTMAK5uy_kGQ8MIQ', 'My Supermix');
      final sections = [
        {
          'title': 'Quick picks',
          'contents': [_song('s1')]
        },
        {
          'title': 'Mixed for you',
          'contents': [
            _playlist('VLPLabc', 'Discover Mix'),
            supermix,
          ]
        },
      ];

      expect(SupermixService.findSupermixPlaylist(sections), supermix);
    });

    test('finds a bare RDTMAK id without the VL prefix', () {
      final supermix = _playlist('RDTMAK5uy_xyz', 'My Supermix');
      final sections = [
        {
          'title': 'Mixed for you',
          'contents': [supermix]
        }
      ];
      expect(SupermixService.findSupermixPlaylist(sections), supermix);
    });

    test('matches on the Supermix title when the id looks different', () {
      final supermix = _playlist('VLPLsomewhere', 'My Supermix');
      final sections = [
        {
          'contents': [supermix]
        }
      ];
      expect(SupermixService.findSupermixPlaylist(sections), supermix);
    });

    test('returns null when the feed has no supermix', () {
      final sections = [
        {
          'title': 'Mixed for you',
          'contents': [
            _playlist('VLPLabc', 'Discover Mix'),
            _song('s1'),
            null,
          ]
        }
      ];
      expect(SupermixService.findSupermixPlaylist(sections), isNull);
    });

    test('ignores malformed sections', () {
      expect(
          SupermixService.findSupermixPlaylist([
            'junk',
            {'contents': 'nope'},
            {}
          ]),
          isNull);
    });
  });

  group('fetchSupermix', () {
    late _FakeMusicServices music;
    late SupermixService service;

    setUp(() {
      music = _FakeMusicServices();
      service = SupermixService(musicServices: music);
    });

    test('serves the native Supermix playlist when there are no seeds',
        () async {
      final mixTracks = List.generate(5, (i) => _song('m$i'));
      music.homeSections = [
        {
          'contents': [_playlist('VLRDTMAK5uy_abc', 'My Supermix')]
        }
      ];
      music.playlistTracks['VLRDTMAK5uy_abc'] = mixTracks;

      final result = await service.fetchSupermix();

      expect(result.playlistId, 'VLRDTMAK5uy_abc');
      expect(result.tracks.map((t) => t.id),
          containsAll(mixTracks.map((t) => t.id)));
      // No seed based radio calls needed when the native mix exists.
      expect(music.seedRadioCalls.where((c) => !c.startsWith('playlist:')),
          isEmpty);
    });

    test('ignores the native playlist when favourites exist', () async {
      // The home feed Supermix is generic for anonymous sessions, so the
      // favourites driven mix always wins when there is something to seed
      // from.
      music.homeSections = [
        {
          'contents': [_playlist('VLRDTMAK5uy_abc', 'My Supermix')]
        }
      ];
      music.playlistTracks['VLRDTMAK5uy_abc'] =
          List.generate(5, (i) => _song('m$i'));
      final favourites = List.generate(4, (i) => _song('fav$i'));
      for (final f in favourites) {
        music.radioTracks[f.id] = [_song('d_${f.id}')];
      }

      final result = await service.fetchSupermix(favouriteSeeds: favourites);

      expect(result.playlistId, isNull);
      final ids = result.tracks.map((t) => t.id).toSet();
      expect(ids, containsAll(favourites.map((f) => f.id)));
      expect(ids.any((id) => id.startsWith('m')), isFalse);
    });

    test('builds a seed mix when the feed has no supermix', () async {
      final favourites = List.generate(4, (i) => _song('fav$i'));
      for (final f in favourites) {
        music.radioTracks[f.id] = [
          _song('d_${f.id}_1'),
          _song('d_${f.id}_2'),
          f, // the radio page includes the seed itself
        ];
      }

      final result = await service.fetchSupermix(favouriteSeeds: favourites);

      expect(result.playlistId, isNull);
      expect(result.tracks, isNotEmpty);
      final ids = result.tracks.map((t) => t.id).toSet();
      // favourites are part of the mix
      expect(ids, containsAll(favourites.map((f) => f.id)));
      // and discoveries got thrown in
      expect(ids.any((id) => id.startsWith('d_')), isTrue);
      // no duplicates
      expect(result.tracks.length, ids.length);
      // a few different seeds powered the mix
      expect(music.seedRadioCalls.toSet().length, greaterThan(1));
    });

    test('a full discovery page can never push favourites out', () async {
      final favourites = List.generate(30, (i) => _song('fav$i'));
      music.radioTrackGenerator =
          (seed) => List.generate(25, (i) => _song('d_${seed}_$i'));

      final result = await service.fetchSupermix(favouriteSeeds: favourites);

      final favCount =
          result.tracks.where((t) => t.id.startsWith('fav')).length;
      expect(favCount, 25);
    });

    test('returns nothing when there are no seeds and no native mix', () async {
      final result = await service.fetchSupermix();
      expect(result.tracks, isEmpty);
    });

    test('falls back to a favourites-only mix when radio pages are empty',
        () async {
      final favourites = List.generate(4, (i) => _song('fav$i'));

      final result = await service.fetchSupermix(favouriteSeeds: favourites);

      expect(result.tracks.map((t) => t.id).toSet(),
          favourites.map((f) => f.id).toSet());
    });
  });

  group('fetchMoreTracks', () {
    late _FakeMusicServices music;
    late SupermixService service;

    setUp(() {
      music = _FakeMusicServices();
      service = SupermixService(musicServices: music);
    });

    test('rotates through seeds and never repeats songs', () async {
      final favourites = List.generate(3, (i) => _song('fav$i'));
      var counter = 0;
      // every seed radio page serves unique songs
      music.radioTrackGenerator =
          (seed) => List.generate(4, (_) => _song('g${counter++}'));
      await service.fetchSupermix(favouriteSeeds: favourites);
      music.seedRadioCalls.clear();

      final first = await service.fetchMoreTracks();
      final second = await service.fetchMoreTracks();

      expect(first, isNotEmpty);
      expect(second, isNotEmpty);
      // each page came from a different seed
      expect(music.seedRadioCalls.toSet().length, 2);
      // pages do not repeat songs
      final overlap = first.map((t) => t.id).toSet()
        ..retainAll(second.map((t) => t.id).toSet());
      expect(overlap, isEmpty);
    });

    test('filters out ids the queue already contains', () async {
      music.radioTracks['fav0'] = [_song('d1'), _song('d2')];
      await service.fetchSupermix(favouriteSeeds: [_song('fav0')]);

      // the next radio page for the seed brings new tracks
      music.radioTracks['fav0'] = [_song('dup'), _song('fresh')];
      final more = await service.fetchMoreTracks(excludeIds: {'dup'});

      expect(more.map((t) => t.id), contains('fresh'));
      expect(more.map((t) => t.id), isNot(contains('dup')));
    });

    test('continuation pages keep sprinkling unserved favourites', () async {
      // 30 favourites: only 25 fit in the first mix, so a handful are left
      // to show up in continuation pages.
      final favourites = List.generate(30, (i) => _song('fav$i'));
      var counter = 0;
      music.radioTrackGenerator =
          (seed) => List.generate(4, (_) => _song('g${counter++}'));
      final firstMix = await service.fetchSupermix(favouriteSeeds: favourites);
      final servedFavs = firstMix.tracks
          .map((t) => t.id)
          .where((id) => id.startsWith('fav'))
          .toSet();

      final more = await service.fetchMoreTracks();

      final sprinkled =
          more.map((t) => t.id).where((id) => id.startsWith('fav')).toList();
      expect(sprinkled, isNotEmpty);
      // only favourites that were not in the first page get sprinkled
      expect(sprinkled.every((id) => !servedFavs.contains(id)), isTrue);
    });

    test('re-reads the native playlist and only serves fresh tracks', () async {
      final mixTracks = List.generate(3, (i) => _song('m$i'));
      music.homeSections = [
        {
          'contents': [_playlist('VLRDTMAK5uy_abc', 'My Supermix')]
        }
      ];
      music.playlistTracks['VLRDTMAK5uy_abc'] = mixTracks;
      await service.fetchSupermix();

      // YouTube refreshed the mix: one old song, two new ones.
      music.playlistTracks['VLRDTMAK5uy_abc'] = [
        mixTracks[0],
        _song('new1'),
        _song('new2'),
      ];
      final more = await service.fetchMoreTracks();

      expect(more.map((t) => t.id).toSet(), {'new1', 'new2'});
    });
  });
}
