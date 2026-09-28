import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import '../models/playlist.dart';
import '../utils/helper.dart';
import '../utils/queue_shuffler.dart';
import 'music_service.dart';

/// One page of a Supermix. [playlistId] is set when the tracks came from the
/// "My Supermix" playlist YouTube Music generates on the home feed.
class SupermixResult {
  SupermixResult({required this.tracks, this.playlistId});

  final List<MediaItem> tracks;
  final String? playlistId;
}

/// Builds YouTube Music style Supermix queues.
///
/// Prefers the "My Supermix" playlist YouTube Music generates on the home
/// feed (id prefix `RDTMAK`). When that playlist is unavailable a mix is
/// built locally instead: radio pages fetched for a few of the user's
/// favourite and recently played songs are blended with the favourites
/// themselves, so the queue is mostly familiar music with new discoveries
/// thrown in. [fetchMoreTracks] keeps the mix going by rotating through the
/// seed pool so every page comes from a different song the user likes.
class SupermixService {
  SupermixService({MusicServices? musicServices})
      : _musicServices = musicServices ?? Get.find<MusicServices>();

  final MusicServices _musicServices;
  final Random _random = Random();

  static const _supermixIdPrefix = 'RDTMAK';
  static final _supermixTitlePattern =
      RegExp(r'super\s?mix', caseSensitive: false);

  static const _seedRadioLimit = 25;
  static const _seedRadioSeedCount = 3;
  static const _favouriteSampleSize = 25;
  static const _mixMaxSize = 80;

  static const _seedPoolMaxSize = 300;

  String? _nativePlaylistId;
  List<String> _seedPool = [];
  int _seedCursor = 0;
  final Set<String> _servedIds = {};
  final Map<String, dynamic> _seedContinuations = {};

  /// Finds the auto generated Supermix playlist inside parsed home feed
  /// sections, or null when the feed does not contain it.
  static Playlist? findSupermixPlaylist(List<dynamic> sections) {
    for (final section in sections) {
      final contents = section is Map ? section['contents'] : null;
      if (contents is! List) continue;
      for (final item in contents) {
        if (item is Playlist && _isSupermix(item)) return item;
      }
    }
    return null;
  }

  static bool _isSupermix(Playlist playlist) {
    final bareId = playlist.playlistId.startsWith('VL')
        ? playlist.playlistId.substring(2)
        : playlist.playlistId;
    return bareId.startsWith(_supermixIdPrefix) ||
        _supermixTitlePattern.hasMatch(playlist.title);
  }

  /// Returns the first page of the mix. [favouriteSeeds] and [recentSeeds]
  /// seed the fallback mix and drive all future continuations.
  Future<SupermixResult> fetchSupermix({
    List<MediaItem> favouriteSeeds = const [],
    List<MediaItem> recentSeeds = const [],
  }) async {
    _servedIds.clear();
    _seedContinuations.clear();
    _seedPool = _buildSeedPool(favouriteSeeds, recentSeeds);
    _seedCursor = _seedPool.isEmpty ? 0 : _random.nextInt(_seedPool.length);
    _nativePlaylistId = null;

    final native = await _fetchNativeSupermixTracks();
    if (native.isNotEmpty) {
      _servedIds.addAll(native.map((t) => t.id));
      return SupermixResult(tracks: native, playlistId: _nativePlaylistId);
    }

    final mix = await _buildSeedMix(
        favouriteSeeds: favouriteSeeds, recentSeeds: recentSeeds);
    _servedIds.addAll(mix.map((t) => t.id));
    return SupermixResult(tracks: mix);
  }

  /// Fetches the next page of the mix for endless playback. Songs already
  /// served or sitting in [excludeIds] are filtered out so the queue never
  /// repeats itself.
  Future<List<MediaItem>> fetchMoreTracks(
      {Set<String> excludeIds = const {}, int limit = _seedRadioLimit}) async {
    final excluded = {...excludeIds, ..._servedIds};

    if (_nativePlaylistId != null) {
      try {
        final fresh = (await _fetchNativeSupermixTracks())
            .where((t) => !excluded.contains(t.id))
            .toList();
        if (fresh.isNotEmpty) {
          _servedIds.addAll(fresh.map((t) => t.id));
          return fresh;
        }
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=supermix.refetch] Failed to re-read Supermix playlist: $e\n$st');
      }
    }

    for (var attempt = 0; attempt < 4 && _seedPool.isNotEmpty; attempt++) {
      final seedId = _seedPool[_seedCursor % _seedPool.length];
      _seedCursor++;
      final tracks = await _fetchSeedRadio(seedId, limit);
      final fresh = tracks
          .where((t) => t.id != seedId && !excluded.contains(t.id))
          .toList();
      if (fresh.isNotEmpty) {
        final ordered = shuffledSongs(fresh, random: _random);
        _servedIds.addAll(ordered.map((t) => t.id));
        // Discoveries become seeds themselves so the mix keeps branching
        // into different territory the longer it runs.
        _addSeeds(ordered.map((t) => t.id));
        return ordered;
      }
    }
    return [];
  }

  Future<String?> _findNativePlaylistId() async {
    final home = await _musicServices.getHome(limit: 25);
    return findSupermixPlaylist(home is List ? home : const [])?.playlistId;
  }

  Future<List<MediaItem>> _fetchNativeSupermixTracks() async {
    try {
      _nativePlaylistId ??= await _findNativePlaylistId();
      final playlistId = _nativePlaylistId;
      if (playlistId == null) return [];

      List<MediaItem> tracks;
      try {
        final playlist = await _musicServices.getPlaylistOrAlbumSongs(
            playlistId: playlistId, limit: 150);
        tracks = List<MediaItem>.from(playlist['tracks'] ?? []);
      } catch (e, st) {
        printWarning(
            '[RECOVERABLE][opId=supermix.browse] Playlist browse failed, trying watch playlist: $e\n$st');
        final bareId =
            playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;
        final content = await _musicServices.getWatchPlaylist(
            playlistId: bareId, limit: 100);
        tracks = List<MediaItem>.from(content['tracks'] ?? []);
      }
      return tracks.where((t) => t.id.isNotEmpty).toList();
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=supermix.native] Failed to fetch native Supermix: $e\n$st');
      return [];
    }
  }

  Future<List<MediaItem>> _fetchSeedRadio(String seedId, int limit) async {
    try {
      final content = await _musicServices.getWatchPlaylist(
          videoId: seedId,
          radio: true,
          limit: limit,
          additionalParamsNext: _seedContinuations[seedId]);
      _seedContinuations[seedId] = content['additionalParamsForNext'];
      return List<MediaItem>.from(content['tracks'] ?? []);
    } catch (e, st) {
      printWarning(
          '[RECOVERABLE][opId=supermix.seedRadio] Radio fetch failed for seed $seedId: $e\n$st');
      return [];
    }
  }

  void _addSeeds(Iterable<String> ids) {
    for (final id in ids) {
      if (id.isNotEmpty && !_seedPool.contains(id)) {
        _seedPool.add(id);
      }
    }
    if (_seedPool.length > _seedPoolMaxSize) {
      _seedPool = _seedPool.sublist(_seedPool.length - _seedPoolMaxSize);
      _seedCursor %= _seedPool.length;
    }
  }

  List<String> _buildSeedPool(
      List<MediaItem> favouriteSeeds, List<MediaItem> recentSeeds) {
    final pool = <String>[];
    final seen = <String>{};
    for (final song in [...favouriteSeeds, ...recentSeeds]) {
      if (song.id.isNotEmpty && seen.add(song.id)) pool.add(song.id);
    }
    return pool;
  }

  /// Builds a mix without a native Supermix playlist: favourites the user
  /// already loves blended with radio tracks generated from a few of them.
  Future<List<MediaItem>> _buildSeedMix({
    required List<MediaItem> favouriteSeeds,
    required List<MediaItem> recentSeeds,
  }) async {
    if (_seedPool.isEmpty) return [];

    final discovery = <MediaItem>[];
    final seedCount = _seedPool.length < _seedRadioSeedCount
        ? _seedPool.length
        : _seedRadioSeedCount;
    for (var i = 0; i < seedCount; i++) {
      final seedId = _seedPool[(_seedCursor + i) % _seedPool.length];
      discovery.addAll(await _fetchSeedRadio(seedId, _seedRadioLimit));
    }
    _seedCursor += seedCount;

    final favouritesSample = [...favouriteSeeds]..shuffle(_random);
    final pool = <MediaItem>[
      ...discovery,
      ...favouritesSample.take(_favouriteSampleSize),
    ];

    final seen = <String>{};
    final deduped = pool
        .where((t) => t.id.isNotEmpty && seen.add(t.id))
        .take(_mixMaxSize)
        .toList();
    _addSeeds(discovery.map((t) => t.id));
    if (deduped.isEmpty) {
      // No discovery tracks at all; at least play the songs the user likes.
      deduped.addAll(favouritesSample
          .where((t) => t.id.isNotEmpty)
          .take(_favouriteSampleSize));
    }
    return shuffledSongs(deduped, random: _random);
  }
}
